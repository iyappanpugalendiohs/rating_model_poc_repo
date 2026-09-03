$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_common.ps1")
Select-UeSubscription

Write-Host "APIM API configuration:" -ForegroundColor Cyan
az apim api show `
    --resource-group $env:UE_RESOURCE_GROUP `
    --service-name $env:UE_APIM_NAME `
    --api-id $env:UE_API_ID `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query "{Path:path, ServiceUrl:serviceUrl, SubscriptionRequired:subscriptionRequired}" `
    -o table

Write-Host ""
Write-Host "APIM operations:" -ForegroundColor Cyan
az apim api operation list `
    --resource-group $env:UE_RESOURCE_GROUP `
    --service-name $env:UE_APIM_NAME `
    --api-id $env:UE_API_ID `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query "[].{Name:name, Method:method, UrlTemplate:urlTemplate}" `
    -o table

Write-Host ""
Write-Host "APIM named values used by the policy:" -ForegroundColor Cyan
az apim nv show `
    --resource-group $env:UE_RESOURCE_GROUP `
    --service-name $env:UE_APIM_NAME `
    --named-value-id aml-backend-base `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query "{Name:name, DisplayName:displayName, Value:value, Secret:secret}" `
    -o table

az apim nv show `
    --resource-group $env:UE_RESOURCE_GROUP `
    --service-name $env:UE_APIM_NAME `
    --named-value-id aml-endpoint-key `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query "{Name:name, DisplayName:displayName, Secret:secret}" `
    -o table

Write-Host ""
Write-Host "Azure ML endpoint scoring URI:" -ForegroundColor Cyan
az ml online-endpoint show `
    --name $env:UE_ENDPOINT_NAME `
    --resource-group $env:UE_RESOURCE_GROUP `
    --workspace-name $env:UE_AML_WORKSPACE `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query "{State:provisioning_state, ScoringUri:scoring_uri}" `
    -o table
