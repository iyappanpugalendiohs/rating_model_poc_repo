$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "00_set_variables.ps1")
$PythonExe = Join-Path $RepoRoot ".venv\Scripts\python.exe"

function Assert-Python314Venv {
  if (-not (Test-Path $PythonExe)) {
    throw "Python 3.14 virtual environment not found at $PythonExe. Run .\scripts\00_setup_python314.ps1 first."
  }
  $version = & $PythonExe -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
  if ($version.Trim() -ne "3.14") {
    throw "Expected Python 3.14 virtual environment. Found Python $version at $PythonExe."
  }
}

function Select-UeSubscription {
  if ([string]::IsNullOrWhiteSpace($env:UE_SUBSCRIPTION_ID) -or $env:UE_SUBSCRIPTION_ID -like "<*") {
    throw "Set UE_SUBSCRIPTION_ID in scripts\00_set_variables.ps1 before continuing."
  }
  az account set --subscription $env:UE_SUBSCRIPTION_ID
  if ($LASTEXITCODE -ne 0) { throw "Unable to select Azure subscription $($env:UE_SUBSCRIPTION_ID)." }
  $selected = az account show --query id -o tsv
  if ($selected.Trim() -ne $env:UE_SUBSCRIPTION_ID.Trim()) {
    throw "Azure subscription verification failed. Expected $($env:UE_SUBSCRIPTION_ID), active subscription is $selected."
  }
}
