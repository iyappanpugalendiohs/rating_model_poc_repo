"""POC placeholder for customer-owned rating-model domain code.

The deployable artifact is built by build_rating_model.py as model.joblib.
Azure ML mounts that registered artifact into the Python 3.14 BYOC container,
and azureml/docker/server.py loads it for inference.
"""
