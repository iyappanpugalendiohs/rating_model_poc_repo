. (Join-Path $PSScriptRoot "_common.ps1")
Select-UeSubscription

$EnvironmentFile = Join-Path $RepoRoot "azureml\environment-py314.yml"
$EndpointFile = Join-Path $RepoRoot "azureml\endpoint.yml"
$DeploymentFile = Join-Path $RepoRoot "azureml\deployment-v1.yml"
$RequestFile = Join-Path $RepoRoot "sample_request.json"

az configure --defaults group=$env:UE_RESOURCE_GROUP workspace=$env:UE_AML_WORKSPACE location=$env:UE_LOCATION
Write-Host "STEP 5 - Build/register Python 3.14 environment and deploy v1 to BLUE" -ForegroundColor Cyan

az ml environment create --file $EnvironmentFile --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID
if ($LASTEXITCODE -ne 0) { throw "Azure ML Python 3.14 environment creation/build failed." }

az ml online-endpoint show --name $env:UE_ENDPOINT_NAME --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID *> $null
if ($LASTEXITCODE -ne 0) {
  az ml online-endpoint create --file $EndpointFile --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID
  if ($LASTEXITCODE -ne 0) { throw "Azure ML endpoint creation failed." }
}

az ml online-deployment create --file $DeploymentFile --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID --all-traffic
if ($LASTEXITCODE -ne 0) { throw "Azure ML v1 deployment failed." }

az ml online-endpoint invoke --name $env:UE_ENDPOINT_NAME --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID --request-file $RequestFile
if ($LASTEXITCODE -ne 0) { throw "Azure ML v1 endpoint smoke test failed." }
