. .\scripts\00_set_variables.ps1
$scoringUri = az ml online-endpoint show --name $env:UE_ENDPOINT_NAME --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --query scoring_uri -o tsv
$endpointKey = az ml online-endpoint get-credentials --name $env:UE_ENDPOINT_NAME --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --query primaryKey -o tsv
az apim nv create --resource-group $env:UE_RESOURCE_GROUP --service-name $env:UE_APIM_NAME --named-value-id aml-scoring-uri --display-name aml-scoring-uri --value $scoringUri
az apim nv create --resource-group $env:UE_RESOURCE_GROUP --service-name $env:UE_APIM_NAME --named-value-id aml-endpoint-key --display-name aml-endpoint-key --value $endpointKey --secret true
az apim api import --resource-group $env:UE_RESOURCE_GROUP --service-name $env:UE_APIM_NAME --api-id $env:UE_API_ID --path $env:UE_API_PATH --specification-format OpenApi --specification-path apim\openapi.yaml --service-url $scoringUri
# Depending on the Azure CLI version, use one of the following policy commands. The first is preferred.
try {
  az apim api policy create --resource-group $env:UE_RESOURCE_GROUP --service-name $env:UE_APIM_NAME --api-id $env:UE_API_ID --xml-policy "@apim\policy.xml"
} catch {
  Write-Warning "If policy upload fails, open APIM > APIs > rating-model-v1 > All operations > Inbound processing and paste apim\policy.xml."
}
Write-Host "APIM API path: https://$($env:UE_APIM_NAME).azure-api.net/$($env:UE_API_PATH)/score" -ForegroundColor Green
