Write-Host "Checking local Windows/PowerShell prerequisites..." -ForegroundColor Cyan
$tools = @("git", "python", "az")
foreach ($tool in $tools) {
  $cmd = Get-Command $tool -ErrorAction SilentlyContinue
  if (-not $cmd) { Write-Warning "$tool is not installed or not in PATH." } else { Write-Host "$tool found at $($cmd.Source)" }
}
az version
az extension add -n ml -y
az extension update -n ml
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
pytest -q
