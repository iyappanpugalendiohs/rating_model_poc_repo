. (Join-Path $PSScriptRoot "_common.ps1")
Select-UeSubscription

$ModelPath = Join-Path $RepoRoot "artifacts\rating-model-v1"
$ModelFile = Join-Path $ModelPath "model.joblib"
if (-not (Test-Path $ModelFile)) {
  throw "Model artifact not found: $ModelFile. Run .\scripts\03_build_model_v1.ps1 first."
}

Write-Host "STEP 4 - Register Rating Model v1 in Azure ML" -ForegroundColor Cyan
Write-Host "Registering from: $ModelPath" -ForegroundColor DarkGray

az ml model create --name $env:UE_MODEL_NAME --version 1 --path $ModelPath --type custom_model --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID --tags businessModelVersion=1.0.0 python=3.14 sklearn=1.9.0 lifecycle=POC owner=UE-Data-Science
if ($LASTEXITCODE -ne 0) { throw "Azure ML model registration failed." }

az ml model show --name $env:UE_MODEL_NAME --version 1 --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID -o table
