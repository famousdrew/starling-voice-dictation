# Starling setup script for Windows
# Run once from the repo root: .\setup.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "    ERROR: $msg" -ForegroundColor Red; exit 1 }

# ── 1. Find Python 3.12 ───────────────────────────────────────────────────────
Write-Step "Checking for Python 3.12..."
$py = $null
foreach ($candidate in @("py", "python3.12", "python")) {
    try {
        $ver = & $candidate -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>$null
        if ($ver -eq "3.12") { $py = $candidate; break }
    } catch {}
}
if (-not $py) {
    Write-Host ""
    Write-Host "  Python 3.12 not found. Install it from:" -ForegroundColor Yellow
    Write-Host "    winget install Python.Python.3.12" -ForegroundColor Yellow
    Write-Host "  or download from https://python.org/downloads" -ForegroundColor Yellow
    Write-Fail "Python 3.12 required (3.13/3.14 will not work — NeMo dependency blocks them)"
}

# If using py launcher, pin to 3.12
if ($py -eq "py") { $py = "py -3.12" }
Write-Ok "Found Python 3.12 at: $py"

# ── 2. Create venv ────────────────────────────────────────────────────────────
Write-Step "Creating virtual environment in .venv..."
if (Test-Path ".venv") {
    Write-Host "    .venv already exists, skipping creation." -ForegroundColor Yellow
} else {
    Invoke-Expression "$py -m venv .venv"
    Write-Ok ".venv created"
}

$pip  = ".venv\Scripts\pip.exe"
$python = ".venv\Scripts\python.exe"

# ── 3. Upgrade pip ────────────────────────────────────────────────────────────
Write-Step "Upgrading pip..."
& $pip install --quiet --upgrade pip
Write-Ok "pip up to date"

# ── 4. Install numpy first (must precede NeMo to avoid source build) ──────────
Write-Step "Installing numpy >= 2.0..."
& $pip install --quiet "numpy>=2.0"
Write-Ok "numpy installed"

# ── 5. Install PyTorch with CUDA ──────────────────────────────────────────────
Write-Step "Installing PyTorch with CUDA support..."
Write-Host "    (This is a large download — ~2.5 GB. Please wait.)" -ForegroundColor Yellow
& $pip install --quiet torch torchaudio --index-url https://download.pytorch.org/whl/cu128
if ($LASTEXITCODE -ne 0) {
    Write-Host "    cu128 not available, trying cu126..." -ForegroundColor Yellow
    & $pip install --quiet torch torchaudio --index-url https://download.pytorch.org/whl/cu126
}
if ($LASTEXITCODE -ne 0) {
    Write-Fail "Could not install a CUDA-enabled PyTorch. Check https://pytorch.org/get-started/locally/ for your CUDA version."
}

# Verify CUDA
$cudaOk = & $python -c "import torch; print(torch.cuda.is_available())" 2>$null
if ($cudaOk -ne "True") {
    Write-Host "    WARNING: PyTorch installed but CUDA not available." -ForegroundColor Yellow
    Write-Host "    Transcription will work but will be much slower without a GPU." -ForegroundColor Yellow
} else {
    $gpu = & $python -c "import torch; print(torch.cuda.get_device_name(0))" 2>$null
    Write-Ok "CUDA available — GPU: $gpu"
}

# ── 6. Install Starling + remaining deps ──────────────────────────────────────
Write-Step "Installing Starling and remaining dependencies..."
Write-Host "    (NeMo toolkit is another large download — ~1 GB. Please wait.)" -ForegroundColor Yellow
& $pip install --quiet -e .
if ($LASTEXITCODE -ne 0) { Write-Fail "pip install failed — see output above." }
Write-Ok "Starling installed"

# ── 7. Done ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Setup complete." -ForegroundColor Green
Write-Host "  The Parakeet model (~2.5 GB) will download on first run." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Start Starling with:" -ForegroundColor White
Write-Host "    .\run.ps1" -ForegroundColor Yellow
Write-Host ""
