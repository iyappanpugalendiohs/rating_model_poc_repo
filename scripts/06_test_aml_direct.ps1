$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_common.ps1")
Select-UeSubscription

$RequestFile = Join-Path $RepoRoot "sample_request.json"
if (-not (Test-Path $RequestFile)) { throw "Sample request not found: $RequestFile" }

$ScoringUri = az ml online-endpoint show `
    --name $env:UE_ENDPOINT_NAME `
    --resource-group $env:UE_RESOURCE_GROUP `
    --workspace-name $env:UE_AML_WORKSPACE `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query scoring_uri `
    -o tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ScoringUri)) {
    throw "Unable to retrieve Azure ML scoring URI."
}

$AmlKey = az ml online-endpoint get-credentials `
    --name $env:UE_ENDPOINT_NAME `
    --resource-group $env:UE_RESOURCE_GROUP `
    --workspace-name $env:UE_AML_WORKSPACE `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query primaryKey `
    -o tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($AmlKey)) {
    throw "Unable to retrieve Azure ML endpoint key."
}

$Body = Get-Content $RequestFile -Raw
$Headers = @{
    "Authorization" = "Bearer $AmlKey"
    "Content-Type"  = "application/json"
    "x-demo-client" = "direct-aml-test"
}

Write-Host "Testing Azure ML endpoint directly:" -ForegroundColor Cyan
Write-Host $ScoringUri

$response = Invoke-RestMethod `
    -Method Post `
    -Uri $ScoringUri `
    -Headers $Headers `
    -Body $Body `
    -ContentType "application/json"

$response | ConvertTo-Json -Depth 10
