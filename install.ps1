#Requires -Version 5.1
# Starling GUI installer for Windows
# Launch via "Install Starling.bat" (double-click) or right-click > Run with PowerShell

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$REPO = $PSScriptRoot

# ── Colours (matches the app's dark theme) ────────────────────────────────────
$C_BG     = [System.Drawing.Color]::FromArgb(15,  15,  16)
$C_CARD   = [System.Drawing.Color]::FromArgb(26,  26,  30)
$C_ACCENT = [System.Drawing.Color]::FromArgb(74,  222, 128)
$C_ADIM   = [System.Drawing.Color]::FromArgb(22,  101, 52)
$C_TEXT   = [System.Drawing.Color]::FromArgb(240, 240, 240)
$C_DIM    = [System.Drawing.Color]::FromArgb(136, 136, 136)
$C_RED    = [System.Drawing.Color]::FromArgb(248, 113, 113)
$C_LOG    = [System.Drawing.Color]::FromArgb(12,  12,  14)

# ── Form ──────────────────────────────────────────────────────────────────────
$form = New-Object System.Windows.Forms.Form
$form.Text          = "Starling Setup"
$form.ClientSize    = New-Object System.Drawing.Size(500, 440)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox   = $false
$form.BackColor     = $C_BG
$form.ForeColor     = $C_TEXT
$form.Font          = New-Object System.Drawing.Font("Segoe UI", 10)

$iconPng = Join-Path $REPO "starling\assets\icon.png"
if (Test-Path $iconPng) {
    try {
        $bmp = New-Object System.Drawing.Bitmap($iconPng)
        $form.Icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    } catch {}
}

# ── Header ────────────────────────────────────────────────────────────────────
$header           = New-Object System.Windows.Forms.Panel
$header.Dock      = [System.Windows.Forms.DockStyle]::Top
$header.Height    = 78
$header.BackColor = $C_CARD

$pic          = New-Object System.Windows.Forms.PictureBox
$pic.Size     = New-Object System.Drawing.Size(52, 52)
$pic.Location = New-Object System.Drawing.Point(20, 13)
$pic.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$pic.BackColor = $C_CARD
if (Test-Path $iconPng) {
    try { $pic.Image = [System.Drawing.Image]::FromFile($iconPng) } catch {}
}
$header.Controls.Add($pic)

$lblTitle          = New-Object System.Windows.Forms.Label
$lblTitle.Text     = "Starling"
$lblTitle.Font     = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $C_TEXT
$lblTitle.Location = New-Object System.Drawing.Point(82, 10)
$lblTitle.AutoSize = $true
$header.Controls.Add($lblTitle)

$lblSub          = New-Object System.Windows.Forms.Label
$lblSub.Text     = "Offline voice dictation for Windows"
$lblSub.ForeColor = $C_DIM
$lblSub.Location = New-Object System.Drawing.Point(84, 46)
$lblSub.AutoSize = $true
$header.Controls.Add($lblSub)

$form.Controls.Add($header)

# ── Status label ──────────────────────────────────────────────────────────────
$lblStatus          = New-Object System.Windows.Forms.Label
$lblStatus.Text     = "Click Install to begin."
$lblStatus.Location = New-Object System.Drawing.Point(20, 90)
$lblStatus.Size     = New-Object System.Drawing.Size(460, 20)
$lblStatus.ForeColor = $C_DIM
$form.Controls.Add($lblStatus)

# ── Progress bar ──────────────────────────────────────────────────────────────
$progress          = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(20, 116)
$progress.Size     = New-Object System.Drawing.Size(460, 16)
$progress.Minimum  = 0
$progress.Maximum  = 100
$progress.Style    = [System.Windows.Forms.ProgressBarStyle]::Continuous
$form.Controls.Add($progress)

# ── Log box ───────────────────────────────────────────────────────────────────
$log           = New-Object System.Windows.Forms.RichTextBox
$log.Location  = New-Object System.Drawing.Point(20, 142)
$log.Size      = New-Object System.Drawing.Size(460, 224)
$log.BackColor = $C_LOG
$log.ForeColor = $C_DIM
$log.Font      = New-Object System.Drawing.Font("Consolas", 8.5)
$log.ReadOnly  = $true
$log.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$log.ScrollBars  = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
$form.Controls.Add($log)

# ── Button ────────────────────────────────────────────────────────────────────
$btn          = New-Object System.Windows.Forms.Button
$btn.Text     = "Install"
$btn.Location = New-Object System.Drawing.Point(20, 380)
$btn.Size     = New-Object System.Drawing.Size(460, 42)
$btn.BackColor = $C_ADIM
$btn.ForeColor = $C_ACCENT
$btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btn.FlatAppearance.BorderSize = 0
$btn.Font     = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btn.Cursor   = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btn)

# ── Shared state (cross-thread via synchronized hashtable) ────────────────────
$sync = [hashtable]::Synchronized(@{
    Pct     = 0
    Status  = ""
    LogLine = ""
    Marquee = $false
    Done    = $false
    Success = $false
    Error   = ""
})

# ── Install work (runs in a background runspace) ──────────────────────────────
$installWork = {
    param([hashtable]$s, [string]$repo)

    function Step([string]$msg, [int]$pct) {
        $s.Pct     = $pct
        $s.Status  = $msg
        $s.LogLine = $msg
    }
    function Log([string]$msg) { if ($msg.Trim()) { $s.LogLine = $msg.Trim() } }

    try {
        # 1 - Locate Python 3.12
        Step "Checking for Python 3.12..." 2
        $pyCli = $null; $pyExtra = @()
        foreach ($cand in @("py", "python3.12", "python")) {
            try {
                $xtra = if ($cand -eq "py") { @("-3.12") } else { @() }
                $ver = & $cand @xtra -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
                if ($ver -eq "3.12") { $pyCli = $cand; $pyExtra = $xtra; break }
            } catch {}
        }
        if (-not $pyCli) {
            $s.Error = "Python 3.12 not found.  Run:  winget install Python.Python.3.12"
            $s.Done = $true; return
        }
        Log "Python 3.12 found  ($pyCli $($pyExtra -join ' '))"

        # 2 - Virtual environment
        Step "Creating virtual environment..." 6
        $venv   = Join-Path $repo ".venv"
        $pip    = Join-Path $venv "Scripts\pip.exe"
        $python = Join-Path $venv "Scripts\python.exe"
        if (-not (Test-Path $venv)) {
            & $pyCli @pyExtra -m venv $venv 2>&1 | ForEach-Object { Log $_ }
            if ($LASTEXITCODE -ne 0) { $s.Error = "Failed to create virtual environment."; $s.Done = $true; return }
            Log "Virtual environment created."
        } else {
            Log "Virtual environment already exists, skipping."
        }

        # 3 - pip
        Step "Upgrading pip..." 10
        & $pip install --quiet --upgrade pip 2>&1 | Out-Null

        # 4 - numpy
        Step "Installing numpy..." 14
        & $pip install --quiet "numpy>=2.0" 2>&1 | Out-Null
        Log "numpy installed."

        # 5 - PyTorch (large download - use marquee)
        Step "Installing PyTorch with CUDA (downloading ~2.5 GB, please wait)..." 18
        $s.Marquee = $true
        $torchOut = & $pip install --quiet torch torchaudio --index-url https://download.pytorch.org/whl/cu128 2>&1
        if ($LASTEXITCODE -ne 0) {
            Log "cu128 index unavailable, retrying with cu126..."
            $torchOut = & $pip install --quiet torch torchaudio --index-url https://download.pytorch.org/whl/cu126 2>&1
            if ($LASTEXITCODE -ne 0) {
                $s.Marquee = $false
                $s.Error = "PyTorch install failed.  Check your internet connection."
                $s.Done = $true; return
            }
        }
        $s.Marquee = $false

        $cudaOk = & $python -c "import torch; print(torch.cuda.is_available())" 2>$null
        if ($cudaOk -eq "True") {
            $gpu = & $python -c "import torch; print(torch.cuda.get_device_name(0))" 2>$null
            Log "PyTorch installed.  GPU: $gpu"
        } else {
            Log "PyTorch installed.  (No CUDA GPU detected - transcription will be slow.)"
        }
        Step "PyTorch ready." 56

        # 6 - Starling + NeMo (large download - use marquee)
        Step "Installing Starling and NeMo toolkit (downloading ~1 GB, please wait)..." 60
        $s.Marquee = $true
        & $pip install --quiet -e $repo 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $s.Marquee = $false
            $s.Error = "pip install failed.  See log for details."
            $s.Done = $true; return
        }
        $s.Marquee = $false
        Log "Starling and NeMo installed."
        Step "Dependencies installed." 88

        # 7 - Corrections dictionary
        Step "Installing corrections dictionary..." 90
        $corrDir = Join-Path $env:APPDATA "Starling"
        if (-not (Test-Path $corrDir)) { New-Item -ItemType Directory -Path $corrDir | Out-Null }
        $src  = Join-Path $repo "corrections.json"
        $dest = Join-Path $corrDir "corrections.json"
        if (-not (Test-Path $dest)) {
            Copy-Item $src $dest
            Log "corrections.json installed to $dest"
        } else {
            Log "corrections.json already present, skipping."
        }

        # 8 - App icon
        Step "Generating icon..." 93
        & $python -c "from starling.assets import app_icon_ico_path; app_icon_ico_path()" 2>&1 | Out-Null
        Log "Icon generated."

        # 9 - VBScript launcher + shortcuts
        Step "Creating desktop and Start Menu shortcuts..." 96
        $launcherPath = Join-Path $repo "launch.vbs"
        $runPs1       = Join-Path $repo "run.ps1"
        $vbsContent   = @"
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & "$runPs1" & """", 0, False
"@
        $vbsContent | Out-File -FilePath $launcherPath -Encoding ascii

        $icoPath = Join-Path $repo "starling\assets\icon.ico"
        $wsh = New-Object -ComObject WScript.Shell

        $desk = [System.Environment]::GetFolderPath("Desktop")
        $lnk = $wsh.CreateShortcut((Join-Path $desk "Starling.lnk"))
        $lnk.TargetPath = "wscript.exe"; $lnk.Arguments = "`"$launcherPath`""
        $lnk.WorkingDirectory = $repo; $lnk.IconLocation = $icoPath
        $lnk.Description = "Starling voice dictation"; $lnk.Save()

        $sMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
        $lnk2 = $wsh.CreateShortcut((Join-Path $sMenu "Starling.lnk"))
        $lnk2.TargetPath = "wscript.exe"; $lnk2.Arguments = "`"$launcherPath`""
        $lnk2.WorkingDirectory = $repo; $lnk2.IconLocation = $icoPath
        $lnk2.Description = "Starling voice dictation"; $lnk2.Save()

        Log "Shortcuts created on Desktop and Start Menu."
        Step "Setup complete!" 100
        $s.Success = $true

    } catch {
        $s.Error = $_.Exception.Message
    } finally {
        $s.Done = $true
    }
}

# ── Poll timer ────────────────────────────────────────────────────────────────
$timer          = New-Object System.Windows.Forms.Timer
$timer.Interval = 120

$timer.Add_Tick({
    # Flush the latest log line
    if ($sync.LogLine -ne "") {
        $log.SelectionStart  = $log.TextLength
        $log.SelectionLength = 0
        $log.SelectedText    = "$($sync.LogLine)`n"
        $log.ScrollToCaret()
        $sync.LogLine = ""
    }

    # Progress bar style (Marquee during big downloads, Continuous otherwise)
    if ($sync.Marquee -and $progress.Style -ne [System.Windows.Forms.ProgressBarStyle]::Marquee) {
        $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Marquee
        $progress.MarqueeAnimationSpeed = 25
    } elseif (-not $sync.Marquee -and $progress.Style -ne [System.Windows.Forms.ProgressBarStyle]::Continuous) {
        $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
    }

    # Progress value
    if (-not $sync.Marquee -and $sync.Pct -gt $progress.Value) {
        $progress.Value = [Math]::Min($sync.Pct, 100)
    }

    # Status text
    if ($sync.Status -ne "") { $lblStatus.Text = $sync.Status }

    # Completion
    if ($sync.Done) {
        $timer.Stop()
        if ($sync.Success) {
            $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
            $progress.Value = 100
            $lblStatus.ForeColor = $C_ACCENT
            $lblStatus.Text      = "Setup complete!  Starling is ready to use."
            $btn.Text      = "Launch Starling"
            $btn.BackColor = $C_ADIM
            $btn.ForeColor = $C_ACCENT
            $btn.Enabled   = $true
        } else {
            $progress.Style = [System.Windows.Forms.ProgressBarStyle]::Continuous
            $lblStatus.ForeColor = $C_RED
            $lblStatus.Text      = "Error: $($sync.Error)"
            $btn.Text    = "Retry"
            $btn.Enabled = $true
        }
    }
})

# ── Button ────────────────────────────────────────────────────────────────────
$btn.Add_Click({
    if ($btn.Text -eq "Launch Starling") {
        $launcher = Join-Path $REPO "launch.vbs"
        Start-Process "wscript.exe" -ArgumentList "`"$launcher`""
        $form.Close()
        return
    }

    # Start or retry installation
    $btn.Enabled  = $false
    $btn.Text     = "Installing..."
    $lblStatus.ForeColor = $C_TEXT
    $lblStatus.Text = "Starting up..."
    $log.Clear()
    $progress.Value  = 0
    $progress.Style  = [System.Windows.Forms.ProgressBarStyle]::Continuous
    $sync.Pct     = 0
    $sync.Status  = ""
    $sync.LogLine = ""
    $sync.Marquee = $false
    $sync.Done    = $false
    $sync.Success = $false
    $sync.Error   = ""

    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript($installWork).AddParameter("s", $sync).AddParameter("repo", $REPO) | Out-Null
    $ps.BeginInvoke() | Out-Null

    $timer.Start()
})

[void]$form.ShowDialog()
