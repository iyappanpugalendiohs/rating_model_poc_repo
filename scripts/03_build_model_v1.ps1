. (Join-Path $PSScriptRoot "_common.ps1")
Assert-Python314Venv

$Builder = Join-Path $RepoRoot "src\build_rating_model.py"
$Tester = Join-Path $RepoRoot "src\local_artifact_test.py"
$OutputDir = Join-Path $RepoRoot "artifacts\rating-model-v1"
$RequestFile = Join-Path $RepoRoot "sample_request.json"

Write-Host "STEP 3 - Build Rating Model v1 locally with Python 3.14" -ForegroundColor Cyan
& $PythonExe $Builder --version 1.0.0 --output-dir $OutputDir
if ($LASTEXITCODE -ne 0) { throw "Rating Model v1 build failed." }

& $PythonExe $Tester --model-dir $OutputDir --request $RequestFile
if ($LASTEXITCODE -ne 0) { throw "Rating Model v1 local artifact test failed." }

$ModelFile = Join-Path $OutputDir "model.joblib"
if (-not (Test-Path $ModelFile)) { throw "Expected model artifact was not created: $ModelFile" }
Write-Host "Built artifact: $ModelFile" -ForegroundColor Green
