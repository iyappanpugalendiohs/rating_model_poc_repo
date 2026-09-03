"""Python 3.14 scoring server for Azure ML BYOC Managed Online Endpoint.

Azure ML mounts the registered model under MODEL_BASE_PATH. The server finds
model.joblib, loads it once, and exposes liveness, readiness, and scoring routes.
"""
from __future__ import annotations

import json
import os
import sys
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

import joblib

MODEL = None
MODEL_VERSION = "unknown"
MODEL_PATH: Path | None = None
MODEL_ROOT = Path(os.environ.get("MODEL_BASE_PATH", "/var/ue-model"))
PORT = int(os.environ.get("PORT", "8080"))


def _find_model_artifact() -> Path:
    candidates = sorted(MODEL_ROOT.rglob("model.joblib"))
    if not candidates:
        raise FileNotFoundError(
            f"No model.joblib found under MODEL_BASE_PATH={MODEL_ROOT}. "
            "Verify model_mount_path and the registered Azure ML model artifact."
        )
    return candidates[0]


def load_model() -> None:
    global MODEL, MODEL_VERSION, MODEL_PATH
    MODEL_PATH = _find_model_artifact()
    MODEL = joblib.load(MODEL_PATH)

    metadata_path = MODEL_PATH.with_name("model_metadata.json")
    if metadata_path.exists():
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        MODEL_VERSION = str(metadata.get("model_version", MODEL_VERSION))

    print(
        json.dumps(
            {
                "event": "model_loaded",
                "python_version": sys.version.split()[0],
                "model_version": MODEL_VERSION,
                "model_path": str(MODEL_PATH),
            }
        ),
        flush=True,
    )


def validate(payload: dict[str, Any]) -> dict[str, Any]:
    required = [
        "state",
        "line_of_business",
        "building_value",
        "deductible",
        "protection_class",
        "years_in_business",
        "prior_claims_3yr",
        "sprinkler",
    ]
    missing = [field for field in required if field not in payload]
    if missing:
        raise ValueError(f"Missing required fields: {', '.join(missing)}")

    return {
        "state": str(payload["state"]).upper(),
        "line_of_business": str(payload["line_of_business"]).lower(),
        "building_value": float(payload["building_value"]),
        "deductible": float(payload["deductible"]),
        "protection_class": int(payload["protection_class"]),
        "years_in_business": int(payload["years_in_business"]),
        "prior_claims_3yr": int(payload["prior_claims_3yr"]),
        "sprinkler": bool(payload["sprinkler"]),
    }


def score(payload: dict[str, Any]) -> dict[str, Any]:
    if MODEL is None:
        raise RuntimeError("Model is not loaded")
    request = validate(payload)
    premium = max(750.0, round(float(MODEL.predict([request])[0]), 2))
    if premium < 2500:
        risk_band = "Low"
    elif premium < 7500:
        risk_band = "Medium"
    else:
        risk_band = "High"
    return {
        "status": "success",
        "model_name": "ue-rating-model",
        "model_version": MODEL_VERSION,
        "python_runtime": sys.version.split()[0],
        "premium": premium,
        "risk_band": risk_band,
    }


class Handler(BaseHTTPRequestHandler):
    server_version = "UE-Rating-Model/1.0"

    def _json_response(self, status: int, body: dict[str, Any]) -> None:
        raw = json.dumps(body).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def log_message(self, format: str, *args: Any) -> None:
        print(
            json.dumps(
                {
                    "event": "http_access",
                    "client": self.client_address[0],
                    "method": self.command,
                    "path": self.path,
                    "message": format % args,
                }
            ),
            flush=True,
        )

    def do_GET(self) -> None:
        if self.path == "/health":
            self._json_response(HTTPStatus.OK, {"status": "alive"})
            return
        if self.path == "/ready":
            if MODEL is None:
                self._json_response(HTTPStatus.SERVICE_UNAVAILABLE, {"status": "not_ready"})
            else:
                self._json_response(
                    HTTPStatus.OK,
                    {
                        "status": "ready",
                        "model_version": MODEL_VERSION,
                        "python_runtime": sys.version.split()[0],
                    },
                )
            return
        self._json_response(HTTPStatus.NOT_FOUND, {"error": "not_found"})

    def do_POST(self) -> None:
        if self.path != "/score":
            self._json_response(HTTPStatus.NOT_FOUND, {"error": "not_found"})
            return

        start = time.perf_counter()
        correlation_id = self.headers.get("x-correlation-id", "")
        try:
            content_length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(content_length)
            payload = json.loads(raw.decode("utf-8"))
            result = score(payload)
            result["duration_ms"] = round((time.perf_counter() - start) * 1000, 2)
            if correlation_id:
                result["correlation_id"] = correlation_id
            self._json_response(HTTPStatus.OK, result)
            print(
                json.dumps(
                    {
                        "event": "score_success",
                        "model_version": MODEL_VERSION,
                        "duration_ms": result["duration_ms"],
                        "correlation_id": correlation_id,
                    }
                ),
                flush=True,
            )
        except Exception as exc:  # noqa: BLE001 - POC server returns controlled JSON error
            duration_ms = round((time.perf_counter() - start) * 1000, 2)
            self._json_response(
                HTTPStatus.BAD_REQUEST,
                {
                    "status": "error",
                    "error_type": type(exc).__name__,
                    "message": str(exc),
                    "duration_ms": duration_ms,
                    "correlation_id": correlation_id,
                },
            )
            print(
                json.dumps(
                    {
                        "event": "score_error",
                        "error_type": type(exc).__name__,
                        "message": str(exc),
                        "duration_ms": duration_ms,
                        "correlation_id": correlation_id,
                    }
                ),
                flush=True,
            )


def main() -> None:
    load_model()
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    print(
        json.dumps(
            {
                "event": "server_started",
                "port": PORT,
                "python_version": sys.version.split()[0],
            }
        ),
        flush=True,
    )
    server.serve_forever()


if __name__ == "__main__":
    main()
