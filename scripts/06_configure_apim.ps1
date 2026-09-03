$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_common.ps1")
Select-UeSubscription

$OpenApiFile = Join-Path $RepoRoot "apim\openapi.yaml"
$PolicyFile = Join-Path $RepoRoot "apim\policy.xml"

if (-not (Test-Path $OpenApiFile)) { throw "OpenAPI file not found: $OpenApiFile" }
if (-not (Test-Path $PolicyFile)) { throw "Policy file not found: $PolicyFile" }

$SubscriptionRequired = $false
if ($env:UE_APIM_SUBSCRIPTION_REQUIRED -and $env:UE_APIM_SUBSCRIPTION_REQUIRED.ToLower() -eq "true") {
    $SubscriptionRequired = $true
}
$SubscriptionRequiredText = $SubscriptionRequired.ToString().ToLower()

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "STEP 6 - Wire Azure API Management to Azure ML" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "API ID: $($env:UE_API_ID)"
Write-Host "API path: $($env:UE_API_PATH)"
Write-Host "APIM subscription required: $SubscriptionRequired"

# ----------------------------------------------------------
# Retrieve Azure ML scoring endpoint and key
# ----------------------------------------------------------

Write-Host ""
Write-Host "Retrieving Azure ML scoring URI..." -ForegroundColor Cyan

$ScoringUri = az ml online-endpoint show `
    --name $env:UE_ENDPOINT_NAME `
    --resource-group $env:UE_RESOURCE_GROUP `
    --workspace-name $env:UE_AML_WORKSPACE `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query scoring_uri `
    -o tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ScoringUri)) {
    throw "Unable to retrieve Azure ML scoring URI. Confirm the Azure ML endpoint exists and is Succeeded."
}

$ScoringUriObject = [System.Uri]$ScoringUri
$AmlBaseUrl = "$($ScoringUriObject.Scheme)://$($ScoringUriObject.Host)"

Write-Host "Azure ML scoring URI: $ScoringUri" -ForegroundColor DarkGray
Write-Host "Azure ML backend base: $AmlBaseUrl" -ForegroundColor DarkGray

Write-Host ""
Write-Host "Retrieving Azure ML endpoint key..." -ForegroundColor Cyan

$AmlKey = az ml online-endpoint get-credentials `
    --name $env:UE_ENDPOINT_NAME `
    --resource-group $env:UE_RESOURCE_GROUP `
    --workspace-name $env:UE_AML_WORKSPACE `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query primaryKey `
    -o tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($AmlKey)) {
    throw "Unable to retrieve Azure ML endpoint key. Confirm the endpoint uses auth_mode: key for this POC."
}

# ----------------------------------------------------------
# Create/update APIM Named Values
# ----------------------------------------------------------

function Upsert-ApimNamedValue {
    param(
        [Parameter(Mandatory=$true)][string]$NamedValueId,
        [Parameter(Mandatory=$true)][string]$DisplayName,
        [Parameter(Mandatory=$true)][string]$Value,
        [switch]$Secret
    )

    az apim nv show `
        --resource-group $env:UE_RESOURCE_GROUP `
        --service-name $env:UE_APIM_NAME `
        --named-value-id $NamedValueId `
        --subscription $env:UE_SUBSCRIPTION_ID `
        --output none 2>$null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Updating APIM named value: $NamedValueId" -ForegroundColor DarkGray

        if ($Secret) {
            az apim nv update `
                --resource-group $env:UE_RESOURCE_GROUP `
                --service-name $env:UE_APIM_NAME `
                --named-value-id $NamedValueId `
                --value $Value `
                --secret true `
                --subscription $env:UE_SUBSCRIPTION_ID `
                --output none
        }
        else {
            az apim nv update `
                --resource-group $env:UE_RESOURCE_GROUP `
                --service-name $env:UE_APIM_NAME `
                --named-value-id $NamedValueId `
                --value $Value `
                --subscription $env:UE_SUBSCRIPTION_ID `
                --output none
        }
    }
    else {
        Write-Host "Creating APIM named value: $NamedValueId" -ForegroundColor DarkGray

        if ($Secret) {
            az apim nv create `
                --resource-group $env:UE_RESOURCE_GROUP `
                --service-name $env:UE_APIM_NAME `
                --named-value-id $NamedValueId `
                --display-name $DisplayName `
                --value $Value `
                --secret true `
                --subscription $env:UE_SUBSCRIPTION_ID `
                --output none
        }
        else {
            az apim nv create `
                --resource-group $env:UE_RESOURCE_GROUP `
                --service-name $env:UE_APIM_NAME `
                --named-value-id $NamedValueId `
                --display-name $DisplayName `
                --value $Value `
                --subscription $env:UE_SUBSCRIPTION_ID `
                --output none
        }
    }

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to create/update APIM named value: $NamedValueId"
    }
}

Write-Host ""
Write-Host "Creating/updating APIM named values..." -ForegroundColor Cyan

Upsert-ApimNamedValue `
    -NamedValueId "aml-backend-base" `
    -DisplayName "Azure ML Backend Base URL" `
    -Value $AmlBaseUrl

Upsert-ApimNamedValue `
    -NamedValueId "aml-endpoint-key" `
    -DisplayName "Azure ML Endpoint Key" `
    -Value $AmlKey `
    -Secret

# ----------------------------------------------------------
# Create or update APIM API and operation
# ----------------------------------------------------------

Write-Host ""
Write-Host "Creating/updating APIM API..." -ForegroundColor Cyan

az apim api show `
    --resource-group $env:UE_RESOURCE_GROUP `
    --service-name $env:UE_APIM_NAME `
    --api-id $env:UE_API_ID `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --output none 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "API exists. Updating path, service URL and subscription setting." -ForegroundColor DarkGray

    az apim api update `
        --resource-group $env:UE_RESOURCE_GROUP `
        --service-name $env:UE_APIM_NAME `
        --api-id $env:UE_API_ID `
        --set serviceUrl=$AmlBaseUrl path=$env:UE_API_PATH subscriptionRequired=$SubscriptionRequiredText `
        --subscription $env:UE_SUBSCRIPTION_ID `
        --output none
}
else {
    Write-Host "API does not exist. Importing OpenAPI definition." -ForegroundColor DarkGray

    az apim api import `
        --resource-group $env:UE_RESOURCE_GROUP `
        --service-name $env:UE_APIM_NAME `
        --api-id $env:UE_API_ID `
        --path $env:UE_API_PATH `
        --specification-format OpenApi `
        --specification-path $OpenApiFile `
        --service-url $AmlBaseUrl `
        --subscription-required $SubscriptionRequiredText `
        --subscription $env:UE_SUBSCRIPTION_ID `
        --output none
}

if ($LASTEXITCODE -ne 0) {
    throw "APIM API create/update failed."
}

# Ensure POST /score exists even if the import did not create it.
az apim api operation show `
    --resource-group $env:UE_RESOURCE_GROUP `
    --service-name $env:UE_APIM_NAME `
    --api-id $env:UE_API_ID `
    --operation-id scoreRating `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --output none 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating POST /score operation." -ForegroundColor DarkGray

    az apim api operation create `
        --resource-group $env:UE_RESOURCE_GROUP `
        --service-name $env:UE_APIM_NAME `
        --api-id $env:UE_API_ID `
        --operation-id scoreRating `
        --display-name "Score Rating Model" `
        --method POST `
        --url-template "/score" `
        --subscription $env:UE_SUBSCRIPTION_ID `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to create APIM POST /score operation."
    }
}

# ----------------------------------------------------------
# Apply API-level policy through ARM REST
# ----------------------------------------------------------

Write-Host ""
Write-Host "Applying APIM API policy..." -ForegroundColor Cyan

$PolicyXml = Get-Content $PolicyFile -Raw
$PolicyBody = @{
    properties = @{
        format = "rawxml"
        value  = $PolicyXml
    }
} | ConvertTo-Json -Depth 10 -Compress

$PolicyUri = "https://management.azure.com/subscriptions/$($env:UE_SUBSCRIPTION_ID)/resourceGroups/$($env:UE_RESOURCE_GROUP)/providers/Microsoft.ApiManagement/service/$($env:UE_APIM_NAME)/apis/$($env:UE_API_ID)/policies/policy?api-version=2024-05-01"

az rest `
    --method put `
    --uri $PolicyUri `
    --body $PolicyBody `
    --headers "Content-Type=application/json" `
    --output none

if ($LASTEXITCODE -ne 0) {
    throw "APIM policy upload failed. Open the API policy editor in Azure portal and paste apim\policy.xml."
}

# ----------------------------------------------------------
# Output and verification
# ----------------------------------------------------------

$GatewayUrl = az apim show `
    --name $env:UE_APIM_NAME `
    --resource-group $env:UE_RESOURCE_GROUP `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query gatewayUrl `
    -o tsv

$ApimScoreUrl = "$GatewayUrl/$($env:UE_API_PATH)/score"

Write-Host ""
Write-Host "Validating APIM API backend configuration..." -ForegroundColor Cyan

az apim api show `
    --resource-group $env:UE_RESOURCE_GROUP `
    --service-name $env:UE_APIM_NAME `
    --api-id $env:UE_API_ID `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query "{Path:path, ServiceUrl:serviceUrl, SubscriptionRequired:subscriptionRequired}" `
    -o table

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "APIM is now wired to Azure ML" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host "Azure ML scoring URI: $ScoringUri"
Write-Host "APIM endpoint:        $ApimScoreUrl"
Write-Host ""
Write-Host "Next test command:" -ForegroundColor Yellow
Write-Host ".\scripts\07_test_apim_endpoint.ps1"
Write-Host ""
if ($SubscriptionRequired) {
    Write-Host "APIM subscription is required. Pass -SubscriptionKey <key> to the test script." -ForegroundColor Yellow
}
else {
    Write-Host "APIM subscription is not required for this POC wiring test." -ForegroundColor Yellow
}
