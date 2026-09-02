# UE Rating Model POC - Azure ML + APIM + Monitoring

This repository contains a simple Python rating model and deployment assets for a customer-hosted POC. It is designed to demonstrate model deployment, API governance, monitoring, release management, and rollback after the model is developed by UE.

## Windows quick start

Open PowerShell from the repo root:

```powershell
. .\scripts\00_set_variables.ps1
.\scripts\01_prereqs_check.ps1
.\scripts\02_create_azure_services.ps1
.\scripts\03_deploy_aml_v1.ps1
.\scripts\04_configure_apim.ps1
.\scripts\05_test_apim_endpoint.ps1 -SubscriptionKey "<APIM subscription key>"
```

## Ownership model

- UE Data Science / Actuarial owns model logic, training, business validation, and release approval.
- UE Application teams own consuming application integration and testing.
- MSP MLOps team owns deployment execution, APIM configuration support, monitoring setup, incident response, change execution, maintenance, and rollback support within the agreed managed service.

## Important

The rating model is intentionally simple and should not be used as an actuarial production model. It is a POC model used to demonstrate the lifecycle.
