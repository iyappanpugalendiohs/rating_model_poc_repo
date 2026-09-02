param(
  [ValidateSet("PromoteV2", "RollbackV1")][string]$Action = "RollbackV1"
)
. .\scripts\00_set_variables.ps1
if ($Action -eq "PromoteV2") {
  az ml online-endpoint update --name $env:UE_ENDPOINT_NAME --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --traffic blue=0 green=100
  Write-Host "Promoted green/v2 to 100%." -ForegroundColor Green
} else {
  az ml online-endpoint update --name $env:UE_ENDPOINT_NAME --resource-group $env:UE_RESOURCE_GROUP --workspace-name $env:UE_AML_WORKSPACE --traffic blue=100 green=0
  Write-Host "Rolled back to blue/v1 at 100%." -ForegroundColor Yellow
}
