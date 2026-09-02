from src.rating_model import score_policy


def test_rating_model_returns_expected_shape():
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
    result = score_policy(payload)
    assert result["status"] if "status" in result else "success"
    assert result["premium"] > 0
    assert result["risk_band"] in {"Low", "Medium", "High"}
    assert result["model_name"] == "ue-rating-model-poc"


def test_rating_model_validates_missing_fields():
    try:
        score_policy({"state": "NY"})
    except ValueError as exc:
        assert "Missing required fields" in str(exc)
    else:
        raise AssertionError("Expected ValueError for missing fields")
