import argparse
import json
import sys
import time
import requests

parser = argparse.ArgumentParser()
parser.add_argument("--url", required=True)
parser.add_argument("--subscription-key", required=True)
parser.add_argument("--iterations", type=int, default=5)
args = parser.parse_args()

with open("sample_request.json", "r", encoding="utf-8") as f:
    payload = json.load(f)

headers = {
    "Ocp-Apim-Subscription-Key": args.subscription_key,
    "Content-Type": "application/json",
    "x-demo-client": "python-test-script",
}

for i in range(args.iterations):
    start = time.time()
    response = requests.post(args.url, headers=headers, json=payload, timeout=10)
    elapsed = round((time.time() - start) * 1000, 2)
    print(f"request={i+1} status={response.status_code} elapsed_ms={elapsed}")
    print(response.text)
    if response.status_code >= 400:
        sys.exit(1)
