"""Simple demonstration rating model for Azure ML Managed Online Endpoint POC.

This is not an actuarial production model. It is intentionally simple so the
POC can demonstrate packaging, deployment, API governance, monitoring, release
management, and rollback.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Dict


@dataclass(frozen=True)
class RatingInput:
    state: str
    line_of_business: str
    building_value: float
    deductible: float
    protection_class: int
    years_in_business: int
    prior_claims_3yr: int
    sprinkler: bool


STATE_FACTORS = {
    "NY": 1.18,
    "NJ": 1.12,
    "PA": 1.05,
    "CA": 1.30,
    "TX": 1.22,
    "DEFAULT": 1.10,
}

LOB_FACTORS = {
    "property": 1.00,
    "general_liability": 1.16,
    "package": 1.24,
}


def _to_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"true", "1", "yes", "y"}
    return bool(value)


def validate(payload: Dict[str, Any]) -> RatingInput:
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

    building_value = float(payload["building_value"])
    deductible = float(payload["deductible"])
    protection_class = int(payload["protection_class"])
    years_in_business = int(payload["years_in_business"])
    prior_claims_3yr = int(payload["prior_claims_3yr"])

    if building_value <= 0:
        raise ValueError("building_value must be greater than zero")
    if deductible < 0:
        raise ValueError("deductible cannot be negative")
    if protection_class < 1 or protection_class > 10:
        raise ValueError("protection_class must be between 1 and 10")
    if years_in_business < 0:
        raise ValueError("years_in_business cannot be negative")
    if prior_claims_3yr < 0:
        raise ValueError("prior_claims_3yr cannot be negative")

    return RatingInput(
        state=str(payload["state"]).upper(),
        line_of_business=str(payload["line_of_business"]).lower(),
        building_value=building_value,
        deductible=deductible,
        protection_class=protection_class,
        years_in_business=years_in_business,
        prior_claims_3yr=prior_claims_3yr,
        sprinkler=_to_bool(payload["sprinkler"]),
    )


def score_policy(payload: Dict[str, Any], model_version: str = "1.0.0") -> Dict[str, Any]:
    """Return a deterministic sample premium and rating factors."""
    item = validate(payload)

    base_rate = 0.0042
    base_premium = item.building_value * base_rate

    state_factor = STATE_FACTORS.get(item.state, STATE_FACTORS["DEFAULT"])
    lob_factor = LOB_FACTORS.get(item.line_of_business, 1.10)
    protection_factor = 1.0 + ((item.protection_class - 5) * 0.025)
    experience_factor = max(0.86, 1.0 - min(item.years_in_business, 20) * 0.007)
    claims_factor = 1.0 + (item.prior_claims_3yr * 0.12)
    sprinkler_credit = 0.92 if item.sprinkler else 1.00
    deductible_credit = max(0.88, 1.0 - (item.deductible / 100000.0))

    technical_premium = (
        base_premium
        * state_factor
        * lob_factor
        * protection_factor
        * experience_factor
        * claims_factor
        * sprinkler_credit
        * deductible_credit
    )

    minimum_premium = 750.00
    final_premium = max(minimum_premium, round(technical_premium, 2))

    if final_premium < 2500:
        risk_band = "Low"
    elif final_premium < 7500:
        risk_band = "Medium"
    else:
        risk_band = "High"

    return {
        "model_name": "ue-rating-model-poc",
        "model_version": model_version,
        "premium": final_premium,
        "risk_band": risk_band,
        "factors": {
            "state_factor": round(state_factor, 4),
            "lob_factor": round(lob_factor, 4),
            "protection_factor": round(protection_factor, 4),
            "experience_factor": round(experience_factor, 4),
            "claims_factor": round(claims_factor, 4),
            "sprinkler_credit": round(sprinkler_credit, 4),
            "deductible_credit": round(deductible_credit, 4),
        },
    }
