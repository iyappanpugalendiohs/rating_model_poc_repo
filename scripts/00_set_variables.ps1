# REQUIRED: Set the Azure subscription that will host the POC.
# Find it with: az account list -o table
$env:UE_SUBSCRIPTION_ID = "<YOUR-AZURE-SUBSCRIPTION-ID>"

# OPTIONAL: Set the tenant ID if your Azure account can access multiple Entra tenants.
# Find it with: az account show --query tenantId -o tsv
$env:UE_TENANT_ID = "<YOUR-AZURE-TENANT-ID>"

$env:UE_LOCATION = "eastus2"
$env:UE_RESOURCE_GROUP = "rg-ue-rating-model-poc"
$env:UE_AML_WORKSPACE = "mlw-ue-rating-poc"
$env:UE_APIM_NAME = "apim-ue-rating-poc-001"   # Must be globally unique.
$env:UE_LOG_WORKSPACE = "log-ue-rating-poc"
$env:UE_PUBLISHER_EMAIL = "mlops@example.com"
$env:UE_PUBLISHER_NAME = "UE MLOps POC"
$env:UE_MODEL_NAME = "ue-rating-model"
$env:UE_ENDPOINT_NAME = "ue-rating-model-endpoint"
$env:UE_API_ID = "rating-model-v1"
$env:UE_API_PATH = "rating/v1"

# For the first APIM-to-AML wiring test, keep this as false to remove client subscription-key friction.
# After the APIM endpoint returns a valid rating response, set this to true and rerun 06_configure_apim.ps1
# if you want consumer-level subscription-key enforcement for the demo.
$env:UE_APIM_SUBSCRIPTION_REQUIRED = "false"

Write-Host "Variables loaded for UE rating model POC." -ForegroundColor Green
Write-Host "Target subscription: $($env:UE_SUBSCRIPTION_ID)" -ForegroundColor Cyan
Write-Host "APIM subscription required: $($env:UE_APIM_SUBSCRIPTION_REQUIRED)" -ForegroundColor Cyan
