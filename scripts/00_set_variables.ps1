# Update these values for the customer subscription before running other scripts.
$env:UE_LOCATION = "eastus2"
$env:UE_RESOURCE_GROUP = "rg-ue-rating-model-poc"
$env:UE_AML_WORKSPACE = "mlw-ue-rating-poc"
$env:UE_APIM_NAME = "apim-ue-rating-poc-001"   # Must be globally unique.
$env:UE_LOG_WORKSPACE = "log-ue-rating-poc"
$env:UE_PUBLISHER_EMAIL = "mlops@example.com"
$env:UE_PUBLISHER_NAME = "UE MLOps POC"
$env:UE_ENDPOINT_NAME = "ue-rating-model-endpoint"
$env:UE_API_ID = "rating-model-v1"
$env:UE_API_PATH = "rating/v1"
Write-Host "Variables loaded for UE rating model POC." -ForegroundColor Green
