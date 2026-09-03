import argparse
import json
import sys
from pathlib import Path

import joblib

parser = argparse.ArgumentParser()
parser.add_argument("--model-dir", required=True)
parser.add_argument("--request", default="sample_request.json")
args = parser.parse_args()

model_dir = Path(args.model_dir)
model = joblib.load(model_dir / "model.joblib")
metadata = json.loads((model_dir / "model_metadata.json").read_text(encoding="utf-8"))
payload = json.loads(Path(args.request).read_text(encoding="utf-8"))
premium = float(model.predict([payload])[0])
print(
    json.dumps(
        {
            "model_version": metadata["model_version"],
            "python_runtime": sys.version.split()[0],
            "scikit_learn_version": metadata.get("scikit_learn_version"),
            "premium": round(premium, 2),
        },
        indent=2,
    )
)
