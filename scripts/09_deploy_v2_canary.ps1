. (Join-Path $PSScriptRoot "_common.ps1")
Select-UeSubscription

$DeploymentFile = Join-Path $RepoRoot "azureml\deployment-v2.yml"
az configure --defaults group=$env:UE_RESOURCE_GROUP workspace=$env:UE_AML_WORKSPACE location=$env:UE_LOCATION

Write-Host "STEP 9 - Deploy registered Rating Model v2 to GREEN and send 10% traffic" -ForegroundColor Cyan
az ml online-deployment create --file $DeploymentFile --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID
if ($LASTEXITCODE -ne 0) { throw "Azure ML v2 green deployment failed." }

az ml online-endpoint update --name $env:UE_ENDPOINT_NAME --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID --traffic blue=90 green=10
if ($LASTEXITCODE -ne 0) { throw "Traffic update failed." }

Write-Host "Canary active: blue/v1=90%, green/v2=10%." -ForegroundColor Green
