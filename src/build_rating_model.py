"""Build a small synthetic insurance rating model for the MLOps POC.

This script simulates the artifact UE Data Science would hand to the MLOps team.
It trains a scikit-learn model and writes an immutable model.joblib plus metadata.
It is NOT an actuarially approved production model.
"""
from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path

import joblib
import sklearn
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.feature_extraction import DictVectorizer
from sklearn.pipeline import Pipeline

STATES = ["NY", "NJ", "PA", "CA", "TX"]
LOBS = ["property", "general_liability", "package"]
STATE_FACTORS_V1 = {"NY": 1.18, "NJ": 1.12, "PA": 1.05, "CA": 1.30, "TX": 1.22}
STATE_FACTORS_V2 = {"NY": 1.16, "NJ": 1.11, "PA": 1.04, "CA": 1.28, "TX": 1.20}
LOB_FACTORS = {"property": 1.00, "general_liability": 1.16, "package": 1.24}


def technical_premium(row: dict, major_version: int) -> float:
    base_rate = 0.0042 if major_version == 1 else 0.00435
    state_factors = STATE_FACTORS_V1 if major_version == 1 else STATE_FACTORS_V2
    state_factor = state_factors[row["state"]]
    lob_factor = LOB_FACTORS[row["line_of_business"]]
    protection_factor = 1.0 + ((row["protection_class"] - 5) * 0.025)
    experience_factor = max(0.86, 1.0 - min(row["years_in_business"], 20) * 0.007)
    claims_multiplier = 0.12 if major_version == 1 else 0.10
    claims_factor = 1.0 + (row["prior_claims_3yr"] * claims_multiplier)
    sprinkler_credit = 0.92 if row["sprinkler"] else 1.00
    deductible_credit = max(0.88, 1.0 - (row["deductible"] / 100000.0))
    premium = (
        row["building_value"]
        * base_rate
        * state_factor
        * lob_factor
        * protection_factor
        * experience_factor
        * claims_factor
        * sprinkler_credit
        * deductible_credit
    )
    return max(750.0, round(premium, 2))


def make_training_data(major_version: int, rows: int = 2500):
    rng = random.Random(20260902 + major_version)
    x, y = [], []
    for _ in range(rows):
        item = {
            "state": rng.choice(STATES),
            "line_of_business": rng.choice(LOBS),
            "building_value": float(rng.randrange(250_000, 5_000_001, 25_000)),
            "deductible": float(rng.choice([2_500, 5_000, 10_000, 25_000, 50_000])),
            "protection_class": rng.randint(1, 10),
            "years_in_business": rng.randint(0, 35),
            "prior_claims_3yr": rng.randint(0, 4),
            "sprinkler": bool(rng.randint(0, 1)),
        }
        x.append(item)
        y.append(technical_premium(item, major_version))
    return x, y


def build(version: str, output_dir: Path) -> None:
    major_version = int(version.split(".")[0])
    if major_version not in (1, 2):
        raise ValueError("POC builder supports major versions 1 and 2.")

    x, y = make_training_data(major_version)
    pipeline = Pipeline(
        steps=[
            ("vectorizer", DictVectorizer(sparse=False)),
            (
                "regressor",
                GradientBoostingRegressor(
                    random_state=42,
                    n_estimators=120,
                    learning_rate=0.06,
                    max_depth=3,
                ),
            ),
        ]
    )
    pipeline.fit(x, y)

    output_dir.mkdir(parents=True, exist_ok=True)
    artifact_path = output_dir / "model.joblib"
    joblib.dump(pipeline, artifact_path)

    metadata = {
        "model_name": "ue-rating-model",
        "model_version": version,
        "aml_model_version": major_version,
        "framework": "scikit-learn",
        "python_version": sys.version.split()[0],
        "scikit_learn_version": sklearn.__version__,
        "joblib_version": joblib.__version__,
        "artifact": "model.joblib",
        "training_rows": len(x),
        "owner": "UE Data Science / Actuarial",
        "purpose": "Synthetic POC artifact to demonstrate build, registration, deployment, API governance, monitoring, release, and rollback.",
    }
    (output_dir / "model_metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")

    sample = {
        "state": "NY",
        "line_of_business": "property",
        "building_value": 1250000.0,
        "deductible": 10000.0,
        "protection_class": 4,
        "years_in_business": 12,
        "prior_claims_3yr": 1,
        "sprinkler": True,
    }
    prediction = float(pipeline.predict([sample])[0])
    print(f"Built {artifact_path}")
    print(f"Version: {version}")
    print(f"Smoke-test premium: {prediction:.2f}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True, help="Semantic version, e.g. 1.0.0 or 2.0.0")
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()
    build(args.version, Path(args.output_dir))
