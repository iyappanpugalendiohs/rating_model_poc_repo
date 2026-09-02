. .\scripts\00_set_variables.ps1
# Demo update: edit model/model_metadata.json to 2.0.0 and optionally change factors in src/rating_model.py before running.
az configure --defaults group=$env:UE_RESOURCE_GROUP workspace=$env:UE_AML_WORKSPACE location=$env:UE_LOCATION
az ml online-deployment create --file azureml\deployment-v2.yml
az ml online-endpoint update --name $env:UE_ENDPOINT_NAME --traffic blue=90 green=10
Write-Host "Canary release active: blue=90, green=10" -ForegroundColor Green
