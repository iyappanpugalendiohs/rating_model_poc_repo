# UE Rating Model POC - Python 3.14 with APIM Wiring

This repository demonstrates a complete model operationalization lifecycle on Azure using:

- Python 3.14 for local model build and validation
- scikit-learn 1.9.0, which publishes CPython 3.14 wheels
- Azure Machine Learning CLI v2
- Azure ML Managed Online Endpoint
- Azure ML registered model versions
- Python 3.14 custom inference container (BYOC)
- Azure API Management
- Azure Monitor / Log Analytics / Application Insights
- GitHub Actions for validation and deployment

The sample rating model is synthetic and is only for demonstrating MLOps. In a real UE implementation, UE Data Science / Actuarial supplies the approved model or approved build process.

## Why V5 changed

V3 pinned scikit-learn 1.6.1, which does not provide a Windows CPython 3.14 wheel. pip therefore attempted a source build and failed. V5 keeps the Python 3.14 runtime and adds a stronger APIM-to-Azure-ML wiring step. The APIM script now retrieves the live Azure ML scoring URI, stores the Azure ML key as a secret APIM named value, creates or updates the APIM API backend, applies the API policy, and provides verification/test commands.

V5 also makes the Azure ML endpoint runtime explicitly Python 3.14. The Azure ML Managed Online Endpoint uses a custom container based on `python:3.14-slim-bookworm`. Azure ML still provides the managed endpoint, model mounting, traffic management, health probes, scaling, authentication, and monitoring.

## Runtime architecture

```text
Windows / GitHub Actions
Python 3.14
    |
    | build + test
    v
artifacts/rating-model-v1/model.joblib
    |
    | register
    v
Azure ML model: ue-rating-model:1
    |
    | mounted into custom container
    v
Azure ML Managed Online Endpoint
BLUE deployment
Python 3.14 BYOC container
    |
    v
APIM /rating/v1/score
    |
    v
Application
```

## Python versions and packages

Local build/test:

```text
Python          3.14
scikit-learn    1.9.0
joblib          1.6.0
requests        2.34.2
pytest          9.1.1
```

Azure ML endpoint container:

```text
Base image      python:3.14-slim-bookworm
scikit-learn    1.9.0
joblib          1.6.0
HTTP server     Python standard library ThreadingHTTPServer
Port            8080
Liveness        /health
Readiness       /ready
Scoring         /score
```

The endpoint container intentionally does not depend on `azureml-inference-server-http`; Azure ML BYOC supports custom web servers as long as the environment declares liveness, readiness, and scoring routes.

## First-time Windows / PowerShell setup

Run PowerShell from the repository root.

### 1. Configure Azure variables

Edit:

```text
scripts\00_set_variables.ps1
```

At minimum set:

```powershell
$env:UE_SUBSCRIPTION_ID = "<YOUR-SUBSCRIPTION-ID>"
$env:UE_TENANT_ID = "<YOUR-TENANT-ID>"
$env:UE_APIM_NAME = "<GLOBALLY-UNIQUE-APIM-NAME>"
```

### 2. Create the Python 3.14 virtual environment

```powershell
.\scripts\00_setup_python314.ps1
```

The script:

1. Locates Python 3.14.
2. Creates `.venv` with Python 3.14.
3. Upgrades pip.
4. Installs only prebuilt wheels.
5. Verifies Python and package versions.

You should see Python 3.14 and scikit-learn 1.9.0 in the output.

## Full POC sequence

```powershell
# Load Azure variables for the current PowerShell session
. .\scripts\00_set_variables.ps1

# Create/verify Python 3.14 virtual environment
.\scripts\00_setup_python314.ps1

# Azure login, subscription verification, ML CLI extension, unit tests
.\scripts\01_prereqs_check.ps1

# Create Azure ML workspace, Log Analytics, and APIM
.\scripts\02_create_azure_services.ps1

# -----------------------
# Rating Model Version 1
# -----------------------

# Build model.joblib locally using Python 3.14
.\scripts\03_build_model_v1.ps1

# Confirm artifact exists
Get-ChildItem .\artifacts\rating-model-v1

# Register ue-rating-model:1 in Azure ML
.\scripts\04_register_model_v1.ps1

# Build/register Python 3.14 AML environment and deploy BLUE / 100%
.\scripts\05_deploy_aml_v1.ps1

# Test Azure ML directly before APIM wiring
.\scripts\06_test_aml_direct.ps1

# Configure APIM in front of Azure ML
.\scripts\06_configure_apim.ps1

# Verify APIM backend, operation, named values and AML scoring URI
.\scripts\07_verify_apim_wiring.ps1

# Test through APIM. No key is required when UE_APIM_SUBSCRIPTION_REQUIRED is false.
.\scripts\07_test_apim_endpoint.ps1

# If you set UE_APIM_SUBSCRIPTION_REQUIRED=true, pass an APIM subscription key.
.\scripts\07_test_apim_endpoint.ps1 -SubscriptionKey "<APIM-SUBSCRIPTION-KEY>"

# -----------------------
# Rating Model Version 2
# -----------------------

# Build and register ue-rating-model:2
.\scripts\08_build_register_model_v2.ps1

# Deploy GREEN and route 10% traffic to v2
.\scripts\09_deploy_v2_canary.ps1

# Promote after validation
.\scripts\10_promote_or_rollback.ps1 -Action PromoteV2

# Or return all traffic to v1
.\scripts\10_promote_or_rollback.ps1 -Action RollbackV1
```

## Where the model is built

The build step is explicit:

```powershell
.\scripts\03_build_model_v1.ps1
```

It runs:

```text
src/build_rating_model.py
```

and creates:

```text
artifacts/
  rating-model-v1/
    model.joblib
    model_metadata.json
```

The artifact folder is intentionally empty in Git before the build. Generated model artifacts are excluded by `.gitignore`.

## Where the model is registered

```powershell
.\scripts\04_register_model_v1.ps1
```

creates:

```text
Azure ML Workspace
  Models
    ue-rating-model
      Version 1
```

V2 becomes:

```text
ue-rating-model:2
```

## Where Python 3.14 is defined for Azure ML

The reusable Azure ML environment is:

```text
azureml/environment-py314.yml
```

It builds from:

```text
azureml/docker/Dockerfile
```

The Dockerfile starts with:

```dockerfile
FROM python:3.14-slim-bookworm
```

The environment defines:

```text
/health   liveness
/ready    readiness
/score    inference
```

Both BLUE and GREEN deployments reference:

```text
azureml:ue-rating-py314:1
```

## Model mount in the Python 3.14 container

The deployments set:

```yaml
model_mount_path: /var/ue-model
```

Azure ML mounts the registered model under that path. `azureml/docker/server.py` searches the mount for `model.joblib`, loads it once at startup, and exposes `/score`.

A successful response includes the actual endpoint Python runtime:

```json
{
  "status": "success",
  "model_name": "ue-rating-model",
  "model_version": "1.0.0",
  "python_runtime": "3.14.x",
  "premium": 5190.16,
  "risk_band": "Medium"
}
```

That makes it easy to demonstrate to the customer that the deployed runtime is Python 3.14.

## How APIM is wired to Azure ML

The APIM wiring step is explicit in V5:

```powershell
.\scripts\06_configure_apim.ps1
```

The script performs these actions:

1. Reads the live Azure ML scoring URI from the managed online endpoint.
2. Converts the scoring URI into an APIM backend base URL.
3. Retrieves the Azure ML endpoint key for key-based POC authentication.
4. Stores the backend base URL as the APIM named value `aml-backend-base`.
5. Stores the Azure ML endpoint key as the secret APIM named value `aml-endpoint-key`.
6. Creates or updates the APIM API using `UE_API_ID` and `UE_API_PATH`.
7. Ensures the POST `/score` operation exists.
8. Applies the API policy from `apim\policy.xml`.
9. Outputs the final APIM endpoint URL.

The APIM policy sets:

```xml
<set-backend-service base-url="{{aml-backend-base}}" />
<set-header name="Authorization" exists-action="override">
  <value>Bearer {{aml-endpoint-key}}</value>
</set-header>
```

The calling application sends requests to APIM. APIM injects the Azure ML credential and forwards the request to the Azure ML `/score` endpoint. The client never receives or stores the Azure ML key.

For the first POC wiring test, `UE_APIM_SUBSCRIPTION_REQUIRED` defaults to `false`. After the API returns a valid rating response through APIM, change it to `true` in `scripts\00_set_variables.ps1` and rerun `06_configure_apim.ps1` if you want to demonstrate APIM consumer subscription-key enforcement.

## APIM validation commands

Test Azure ML directly:

```powershell
.\scripts\06_test_aml_direct.ps1
```

Wire APIM to Azure ML:

```powershell
.\scripts\06_configure_apim.ps1
```

Verify APIM configuration:

```powershell
.\scripts\07_verify_apim_wiring.ps1
```

Test through APIM without a subscription key:

```powershell
.\scripts\07_test_apim_endpoint.ps1
```

Test through APIM with a subscription key:

```powershell
.\scripts\07_test_apim_endpoint.ps1 -SubscriptionKey "<APIM-SUBSCRIPTION-KEY>"
```


## GitHub Actions

`.github/workflows/validate.yml` runs the model build and tests on Python 3.14.

`.github/workflows/deploy-aml.yml`:

1. Runs tests on Python 3.14.
2. Builds the model artifact.
3. Authenticates to Azure using OIDC.
4. Registers the requested Azure ML model version.
5. Builds/registers the Python 3.14 Azure ML BYOC environment.
6. Deploys BLUE or GREEN.
7. Performs an endpoint smoke test.

## Important POC note

`python:3.14-slim-bookworm` is used here to make Python 3.14 explicit and easy to demonstrate. For production, pin the base image by immutable tag/digest, scan it, publish the approved image to the customer's Azure Container Registry, and reference that approved image from the Azure ML environment.
