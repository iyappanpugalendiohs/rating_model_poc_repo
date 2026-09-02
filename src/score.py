"""Azure ML managed online endpoint scoring script."""
import json
import logging
import os
import time
from typing import Any, Dict

from rating_model import score_policy

MODEL_VERSION = "1.0.0"


def init():
    global MODEL_VERSION
    model_dir = os.environ.get("AZUREML_MODEL_DIR", "")
    metadata_path = os.path.join(model_dir, "model_metadata.json")
    if os.path.exists(metadata_path):
        with open(metadata_path, "r", encoding="utf-8") as f:
            metadata = json.load(f)
        MODEL_VERSION = metadata.get("model_version", MODEL_VERSION)
    logging.info("Rating model initialized. version=%s model_dir=%s", MODEL_VERSION, model_dir)


def _parse(raw_data: Any) -> Dict[str, Any]:
    if isinstance(raw_data, str):
        return json.loads(raw_data)
    if isinstance(raw_data, bytes):
        return json.loads(raw_data.decode("utf-8"))
    if isinstance(raw_data, dict):
        return raw_data
    raise ValueError("Unsupported request body. Expected JSON object.")


def run(raw_data: Any):
    start = time.time()
    try:
        request = _parse(raw_data)
        result = score_policy(request, model_version=MODEL_VERSION)
        result["duration_ms"] = round((time.time() - start) * 1000, 2)
        result["status"] = "success"
        return result
    except Exception as exc:  # Azure ML returns this in the response body for the POC.
        logging.exception("Scoring failed")
        return {
            "status": "error",
            "error_type": type(exc).__name__,
            "message": str(exc),
            "duration_ms": round((time.time() - start) * 1000, 2),
        }
