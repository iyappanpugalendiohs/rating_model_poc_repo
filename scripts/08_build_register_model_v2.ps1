. (Join-Path $PSScriptRoot "_common.ps1")
Assert-Python314Venv
Select-UeSubscription

$Builder = Join-Path $RepoRoot "src\build_rating_model.py"
$Tester = Join-Path $RepoRoot "src\local_artifact_test.py"
$OutputDir = Join-Path $RepoRoot "artifacts\rating-model-v2"
$RequestFile = Join-Path $RepoRoot "sample_request.json"

Write-Host "STEP 8 - Build, validate, and register Rating Model v2" -ForegroundColor Cyan
& $PythonExe $Builder --version 2.0.0 --output-dir $OutputDir
if ($LASTEXITCODE -ne 0) { throw "Rating Model v2 build failed." }

& $PythonExe $Tester --model-dir $OutputDir --request $RequestFile
if ($LASTEXITCODE -ne 0) { throw "Rating Model v2 local artifact test failed." }

$ModelFile = Join-Path $OutputDir "model.joblib"
if (-not (Test-Path $ModelFile)) { throw "Expected model artifact was not created: $ModelFile" }

az ml model create --name $env:UE_MODEL_NAME --version 2 --path $OutputDir --type custom_model --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID --tags businessModelVersion=2.0.0 python=3.14 sklearn=1.9.0 lifecycle=POC owner=UE-Data-Science
if ($LASTEXITCODE -ne 0) { throw "Azure ML model v2 registration failed." }

az ml model show --name $env:UE_MODEL_NAME --version 2 --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID -o table
