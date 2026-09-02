param(
  [Parameter(Mandatory=$true)][string]$SubscriptionKey
)
. .\scripts\00_set_variables.ps1
$uri = "https://$($env:UE_APIM_NAME).azure-api.net/$($env:UE_API_PATH)/score"
$body = Get-Content .\sample_request.json -Raw
$headers = @{
  "Ocp-Apim-Subscription-Key" = $SubscriptionKey
  "Content-Type" = "application/json"
  "x-demo-client" = "powershell-poc"
}
$response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -Body $body
$response | ConvertTo-Json -Depth 10
