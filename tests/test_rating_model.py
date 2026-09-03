from pathlib import Path
import tempfile
import joblib
from src.build_rating_model import build


def test_build_creates_loadable_artifact():
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "model"
        build("1.0.0", out)
        assert (out / "model.joblib").exists()
        assert (out / "model_metadata.json").exists()
        model = joblib.load(out / "model.joblib")
        payload = {
            "state": "NY",
            "line_of_business": "property",
            "building_value": 1250000,
            "deductible": 10000,
            "protection_class": 4,
            "years_in_business": 12,
            "prior_claims_3yr": 1,
            "sprinkler": True,
        }
        assert float(model.predict([payload])[0]) > 0
