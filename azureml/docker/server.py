from __future__ import annotations

import json
import logging
import os
import platform
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

import joblib
import pandas as pd

try:
    from azureml.ai.monitoring import Collector
except Exception as exc:  # Local execution can still be useful without Azure's MDC runtime.
    Collector = None
    _collector_import_error = str(exc)
else:
    _collector_import_error = None

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(message)s",
)
logger = logging.getLogger("ue-rating-server")

MODEL_BASE_PATH = Path(os.getenv("MODEL_BASE_PATH", "/var/ue-model"))
PORT = int(os.getenv("PORT", "8080"))

model = None
metadata: dict[str, Any] = {}
inputs_collector = None
outputs_collector = None


def _collector_error(collection_name: str):
    def handler(exc: Exception) -> None:
        # Do not break production scoring because monitoring collection failed.
        logger.error(
            "model_data_collection_error collection=%s error=%s",
            collection_name,
            exc,
        )
    return handler


def find_model_file() -> Path:
    matches = list(MODEL_BASE_PATH.rglob("model.joblib"))
    if not matches:
        raise FileNotFoundError(
            f"model.joblib was not found under MODEL_BASE_PATH={MODEL_BASE_PATH}"
        )
    return matches[0]


def load_model() -> None:
    global model, metadata

    model_path = find_model_file()
    logger.info("loading_model path=%s", model_path)
    model = joblib.load(model_path)

    metadata_path = model_path.with_name("model_metadata.json")
    if metadata_path.exists():
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    else:
        metadata = {
            "model_name": "ue-rating-model",
            "model_version": "unknown",
        }

    logger.info(
        "model_loaded model_name=%s model_version=%s python=%s",
        metadata.get("model_name", "ue-rating-model"),
        metadata.get("model_version", "unknown"),
        platform.python_version(),
    )


def initialize_collectors() -> None:
    global inputs_collector, outputs_collector

    if Collector is None:
        logger.warning(
            "model_data_collector_sdk_unavailable error=%s",
            _collector_import_error,
        )
        return

    # These names MUST match deployment YAML data_collector.collections.
    inputs_collector = Collector(
        name="model_inputs",
        on_error=_collector_error("model_inputs"),
    )
    outputs_collector = Collector(
        name="model_outputs",
        on_error=_collector_error("model_outputs"),
    )
    logger.info("model_data_collectors_initialized collections=model_inputs,model_outputs")


def unwrap_request(payload: Any) -> dict[str, Any]:
    """Return one feature dictionary while tolerating common request wrappers."""
    if not isinstance(payload, dict):
        raise ValueError("Request body must be a JSON object.")

    # Common wrapper: {"data": {...}}
    if isinstance(payload.get("data"), dict):
        return dict(payload["data"])

    # Common wrapper: {"input_data": {...}}
    if isinstance(payload.get("input_data"), dict):
        return dict(payload["input_data"])

    return dict(payload)


def scoring_features(payload: dict[str, Any]) -> dict[str, Any]:
    # Remove request metadata that should not become model features.
    excluded = {
        "correlation_id",
        "request_id",
        "x_correlation_id",
        "model_version",
    }
    return {k: v for k, v in payload.items() if k not in excluded}


def monitoring_features(features: dict[str, Any]) -> dict[str, Any]:
    """Keep tabular scalar values for model monitoring."""
    result: dict[str, Any] = {}
    for key, value in features.items():
        if value is None or isinstance(value, (str, int, float, bool)):
            result[key] = value
        else:
            # The current POC model uses flat scalar features. For nested production
            # payloads, define a formal flattening/preprocessing contract instead.
            result[key] = json.dumps(value, sort_keys=True)
    return result


def risk_band(premium: float) -> str:
    # POC display-only band; UE owns actual business/actuarial interpretation.
    if premium < 3000:
        return "Low"
    if premium < 6000:
        return "Medium"
    return "High"


def score_request(payload: dict[str, Any]) -> dict[str, Any]:
    if model is None:
        raise RuntimeError("Model has not been loaded.")

    features = scoring_features(unwrap_request(payload))
    if not features:
        raise ValueError("No model input features were supplied.")

    correlation_context = None
    if inputs_collector is not None:
        input_df = pd.DataFrame([monitoring_features(features)])
        correlation_context = inputs_collector.collect(input_df)

    # The V5 POC model is a scikit-learn pipeline that accepts a list of dictionaries.
    prediction = model.predict([features])
    premium = round(float(prediction[0]), 2)
    band = risk_band(premium)

    # For regression prediction drift, collect the numerical prediction as model output.
    if outputs_collector is not None:
        output_df = pd.DataFrame([{"premium": premium}])
        outputs_collector.collect(output_df, correlation_context)

    return {
        "status": "success",
        "model_name": metadata.get("model_name", "ue-rating-model"),
        "model_version": metadata.get("model_version", "unknown"),
        "python_runtime": platform.python_version(),
        "premium": premium,
        "risk_band": band,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "UERatingModel/6"

    def _send_json(self, status_code: int, body: dict[str, Any]) -> None:
        raw = json.dumps(body).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, fmt: str, *args: Any) -> None:
        logger.info("http " + fmt, *args)

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, {"status": "alive"})
            return

        if self.path == "/ready":
            self._send_json(
                200 if model is not None else 503,
                {
                    "status": "ready" if model is not None else "not_ready",
                    "model_version": metadata.get("model_version", "unknown"),
                    "python_runtime": platform.python_version(),
                    "model_data_collection_sdk": Collector is not None,
                    "collectors_initialized": bool(inputs_collector and outputs_collector),
                },
            )
            return

        self._send_json(404, {"error": "not_found"})

    def do_POST(self) -> None:
        if self.path != "/score":
            self._send_json(404, {"error": "not_found"})
            return

        start = time.perf_counter()
        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(content_length)
            payload = json.loads(raw.decode("utf-8"))
            result = score_request(payload)
            result["latency_ms"] = round((time.perf_counter() - start) * 1000, 2)

            logger.info(
                "score_success model_version=%s premium=%s latency_ms=%s",
                result.get("model_version"),
                result.get("premium"),
                result.get("latency_ms"),
            )
            self._send_json(200, result)
        except (ValueError, json.JSONDecodeError) as exc:
            logger.warning("score_bad_request error=%s", exc)
            self._send_json(400, {"status": "error", "message": str(exc)})
        except Exception as exc:
            logger.exception("score_failure")
            self._send_json(500, {"status": "error", "message": str(exc)})


def main() -> int:
    logger.info("python_version=%s executable=%s", sys.version, sys.executable)
    load_model()
    initialize_collectors()

    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    logger.info("server_started port=%s model_base_path=%s", PORT, MODEL_BASE_PATH)
    server.serve_forever()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
