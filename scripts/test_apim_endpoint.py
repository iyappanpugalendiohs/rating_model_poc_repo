import argparse
import json
import sys
import time
from pathlib import Path

import requests

parser = argparse.ArgumentParser(description="Load-test the UE Rating Model API through APIM.")
parser.add_argument("--url", required=True)
parser.add_argument("--subscription-key", default="", help="Optional APIM subscription key. Required only if the APIM API requires subscriptions.")
parser.add_argument("--iterations", type=int, default=5)
parser.add_argument("--request", default="sample_request.json")
args = parser.parse_args()

payload_path = Path(args.request)
if not payload_path.exists():
    raise FileNotFoundError(f"Request file not found: {payload_path.resolve()}")

with payload_path.open("r", encoding="utf-8") as f:
    payload = json.load(f)

headers = {
    "Content-Type": "application/json",
    "x-demo-client": "python-test-script",
}

if args.subscription_key:
    headers["Ocp-Apim-Subscription-Key"] = args.subscription_key

for i in range(args.iterations):
    start = time.time()
    response = requests.post(args.url, headers=headers, json=payload, timeout=30)
    elapsed = round((time.time() - start) * 1000, 2)
    print(f"request={i + 1} status={response.status_code} elapsed_ms={elapsed}")
    print(response.text)
    if response.status_code >= 400:
        sys.exit(1)
