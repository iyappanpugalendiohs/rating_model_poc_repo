. (Join-Path $PSScriptRoot "_common.ps1")

Write-Host "STEP 1 - Check Windows/PowerShell prerequisites" -ForegroundColor Cyan
$tools = @("git", "az")
foreach ($tool in $tools) {
  $cmd = Get-Command $tool -ErrorAction SilentlyContinue
  if (-not $cmd) { throw "$tool is not installed or not in PATH." }
  Write-Host "$tool found at $($cmd.Source)" -ForegroundColor Green
}

Assert-Python314Venv
& $PythonExe --version
& $PythonExe -c "import sklearn, joblib; print('scikit-learn', sklearn.__version__); print('joblib', joblib.__version__)"

az version

if ($env:UE_TENANT_ID -and $env:UE_TENANT_ID -notlike "<*") {
  az login --tenant $env:UE_TENANT_ID
} else {
  az login
}
if ($LASTEXITCODE -ne 0) { throw "Azure login failed." }

az account list -o table
Select-UeSubscription

Write-Host "Azure subscription selected successfully:" -ForegroundColor Green
az account show --query "{Name:name,SubscriptionId:id,TenantId:tenantId,State:state}" -o table

az extension add -n ml -y
if ($LASTEXITCODE -ne 0) { throw "Azure ML CLI extension installation failed." }
az extension update -n ml

Push-Location $RepoRoot
try {
  & $PythonExe -m pytest -q
  if ($LASTEXITCODE -ne 0) { throw "Unit tests failed." }
} finally {
  Pop-Location
}
