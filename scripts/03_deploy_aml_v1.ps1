. .\scripts\00_set_variables.ps1
az configure --defaults group=$env:UE_RESOURCE_GROUP workspace=$env:UE_AML_WORKSPACE location=$env:UE_LOCATION
az ml online-endpoint create --file azureml\endpoint.yml
az ml online-deployment create --file azureml\deployment-v1.yml --all-traffic
az ml online-endpoint invoke --name $env:UE_ENDPOINT_NAME --request-file sample_request.json
$uri = az ml online-endpoint show --name $env:UE_ENDPOINT_NAME --query scoring_uri -o tsv
$key = az ml online-endpoint get-credentials --name $env:UE_ENDPOINT_NAME --query primaryKey -o tsv
Write-Host "Scoring URI: $uri" -ForegroundColor Green
Write-Host "Endpoint key captured. Store in Key Vault or APIM named value; do not commit it to GitHub." -ForegroundColor Yellow
