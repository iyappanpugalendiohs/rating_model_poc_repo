param(
  [ValidateSet("PromoteV2", "RollbackV1")][string]$Action = "RollbackV1"
)
. (Join-Path $PSScriptRoot "_common.ps1")
Select-UeSubscription

if ($Action -eq "PromoteV2") {
  az ml online-endpoint update --name $env:UE_ENDPOINT_NAME --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID --traffic blue=0 green=100
  if ($LASTEXITCODE -ne 0) { throw "Promotion to v2 failed." }
  Write-Host "Promoted registered model v2 (green) to 100% traffic." -ForegroundColor Green
} else {
  az ml online-endpoint update --name $env:UE_ENDPOINT_NAME --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --subscription $env:UE_SUBSCRIPTION_ID --traffic blue=100 green=0
  if ($LASTEXITCODE -ne 0) { throw "Rollback to v1 failed." }
  Write-Host "Rolled back to registered model v1 (blue) at 100%." -ForegroundColor Yellow
}
