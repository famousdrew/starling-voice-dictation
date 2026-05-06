# Start Starling
# Usage: .\run.ps1

if (-not (Test-Path ".venv\Scripts\python.exe")) {
    Write-Host "No .venv found. Run .\setup.ps1 first." -ForegroundColor Red
    exit 1
}

& .venv\Scripts\python.exe -m starling
