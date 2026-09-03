param(
  [string]$SubscriptionKey = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_common.ps1")
Select-UeSubscription

$RequestFile = Join-Path $RepoRoot "sample_request.json"
if (-not (Test-Path $RequestFile)) { throw "Sample request not found: $RequestFile" }

$GatewayUrl = az apim show `
    --name $env:UE_APIM_NAME `
    --resource-group $env:UE_RESOURCE_GROUP `
    --subscription $env:UE_SUBSCRIPTION_ID `
    --query gatewayUrl `
    -o tsv

if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($GatewayUrl)) {
    throw "Unable to retrieve APIM gateway URL."
}

$Uri = "$GatewayUrl/$($env:UE_API_PATH)/score"
$Body = Get-Content $RequestFile -Raw

$Headers = @{
  "Content-Type" = "application/json"
  "x-demo-client" = "powershell-poc"
}

if (-not [string]::IsNullOrWhiteSpace($SubscriptionKey)) {
  $Headers["Ocp-Apim-Subscription-Key"] = $SubscriptionKey
}

Write-Host "Testing APIM endpoint:" -ForegroundColor Cyan
Write-Host $Uri

$response = Invoke-RestMethod `
  -Method Post `
  -Uri $Uri `
  -Headers $Headers `
  -Body $Body `
  -ContentType "application/json"

$response | ConvertTo-Json -Depth 10
