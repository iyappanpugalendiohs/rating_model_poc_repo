. .\scripts\00_set_variables.ps1
az login
az account show -o table
az provider register --namespace Microsoft.MachineLearningServices
az provider register --namespace Microsoft.ApiManagement
az provider register --namespace Microsoft.Insights
az group create --name $env:UE_RESOURCE_GROUP --location $env:UE_LOCATION
az monitor log-analytics workspace create --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_LOG_WORKSPACE --location $env:UE_LOCATION
az ml workspace create --name $env:UE_AML_WORKSPACE --resource-group $env:UE_RESOURCE_GROUP --location $env:UE_LOCATION
# APIM Developer SKU is appropriate for a POC/demo. Production should use a production SKU aligned to SLA/security requirements.
az apim create --name $env:UE_APIM_NAME --resource-group $env:UE_RESOURCE_GROUP --location $env:UE_LOCATION --publisher-email $env:UE_PUBLISHER_EMAIL --publisher-name $env:UE_PUBLISHER_NAME --sku-name Developer
az configure --defaults group=$env:UE_RESOURCE_GROUP workspace=$env:UE_AML_WORKSPACE location=$env:UE_LOCATION
Write-Host "Azure services requested. APIM creation can take 30-45 minutes." -ForegroundColor Yellow
