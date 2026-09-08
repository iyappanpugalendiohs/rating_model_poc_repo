FROM python:3.14-slim-bookworm

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    MODEL_BASE_PATH=/var/ue-model \
    PORT=8080

WORKDIR /app

COPY requirements-runtime.txt /app/requirements-runtime.txt
RUN python -m pip install --upgrade pip \
    && python -m pip install -r /app/requirements-runtime.txt

COPY server.py /app/server.py

EXPOSE 8080
CMD ["python", "/app/server.py"]
