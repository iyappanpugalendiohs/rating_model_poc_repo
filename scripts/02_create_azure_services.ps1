. (Join-Path $PSScriptRoot "_common.ps1")
Select-UeSubscription

Write-Host "STEP 2 - Create Azure services" -ForegroundColor Cyan
az account show --query "{Name:name,SubscriptionId:id,TenantId:tenantId}" -o table

az provider register --namespace Microsoft.MachineLearningServices --subscription $env:UE_SUBSCRIPTION_ID
az provider register --namespace Microsoft.ApiManagement --subscription $env:UE_SUBSCRIPTION_ID
az provider register --namespace Microsoft.Insights --subscription $env:UE_SUBSCRIPTION_ID

az group create --name $env:UE_RESOURCE_GROUP --location $env:UE_LOCATION --subscription $env:UE_SUBSCRIPTION_ID
if ($LASTEXITCODE -ne 0) { throw "Resource group creation failed." }

az monitor log-analytics workspace create --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_LOG_WORKSPACE --location $env:UE_LOCATION --subscription $env:UE_SUBSCRIPTION_ID
if ($LASTEXITCODE -ne 0) { throw "Log Analytics workspace creation failed." }

az ml workspace show --name $env:UE_AML_WORKSPACE --resource-group $env:UE_RESOURCE_GROUP --subscription $env:UE_SUBSCRIPTION_ID *> $null
if ($LASTEXITCODE -ne 0) {
  az ml workspace create --name $env:UE_AML_WORKSPACE --resource-group $env:UE_RESOURCE_GROUP --location $env:UE_LOCATION --subscription $env:UE_SUBSCRIPTION_ID
  if ($LASTEXITCODE -ne 0) { throw "Azure ML workspace creation failed." }
}

az apim show --name $env:UE_APIM_NAME --resource-group $env:UE_RESOURCE_GROUP --subscription $env:UE_SUBSCRIPTION_ID *> $null
if ($LASTEXITCODE -ne 0) {
  az apim create --name $env:UE_APIM_NAME --resource-group $env:UE_RESOURCE_GROUP --location $env:UE_LOCATION --publisher-email $env:UE_PUBLISHER_EMAIL --publisher-name $env:UE_PUBLISHER_NAME --sku-name Developer --subscription $env:UE_SUBSCRIPTION_ID
  if ($LASTEXITCODE -ne 0) { throw "APIM creation failed." }
}

az configure --defaults group=$env:UE_RESOURCE_GROUP workspace=$env:UE_AML_WORKSPACE location=$env:UE_LOCATION
Write-Host "Azure services created/requested in subscription $($env:UE_SUBSCRIPTION_ID)." -ForegroundColor Green
