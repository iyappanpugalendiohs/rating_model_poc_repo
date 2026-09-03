$RepoRoot = Split-Path -Parent $PSScriptRoot
$VenvPath = Join-Path $RepoRoot ".venv"
$VenvPython = Join-Path $VenvPath "Scripts\python.exe"
$Requirements = Join-Path $RepoRoot "requirements.txt"

Write-Host "SETUP - Python 3.14 virtual environment" -ForegroundColor Cyan

$UsePyLauncher = $false
$launcher = Get-Command py -ErrorAction SilentlyContinue
if ($launcher) {
  py -3.14 --version
  if ($LASTEXITCODE -eq 0) {
    $UsePyLauncher = $true
  }
}

if (-not $UsePyLauncher) {
  $python = Get-Command python -ErrorAction SilentlyContinue
  if (-not $python) { throw "Python is not installed or not in PATH." }
  $version = python -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
  if ($version.Trim() -ne "3.14") {
    throw "Python 3.14 was not found. Install Python 3.14 or make it available through 'py -3.14'."
  }
}

if (Test-Path $VenvPython) {
  $existing = & $VenvPython -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
  if ($existing.Trim() -ne "3.14") {
    throw "Existing .venv uses Python $existing. Delete '$VenvPath' and rerun this script."
  }
  Write-Host "Existing Python 3.14 .venv found." -ForegroundColor Green
} else {
  if ($UsePyLauncher) {
    py -3.14 -m venv $VenvPath
  } else {
    python -m venv $VenvPath
  }
  if ($LASTEXITCODE -ne 0) { throw "Unable to create Python 3.14 virtual environment." }
}

& $VenvPython -m pip install --upgrade pip
if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed." }

# Force wheel installation so pip never falls back to compiling scikit-learn from source.
& $VenvPython -m pip install --only-binary=:all: -r $Requirements
if ($LASTEXITCODE -ne 0) {
  throw "Python dependency installation failed. Confirm internet access and a supported Python 3.14 platform."
}

& $VenvPython -c "import sys, sklearn, joblib, requests, pytest; print('Python:', sys.version); print('scikit-learn:', sklearn.__version__); print('joblib:', joblib.__version__); print('requests:', requests.__version__); print('pytest:', pytest.__version__)"
if ($LASTEXITCODE -ne 0) { throw "Python 3.14 dependency verification failed." }

Write-Host "Python 3.14 environment ready: $VenvPython" -ForegroundColor Green
