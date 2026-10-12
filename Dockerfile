# syntax=docker/dockerfile:1

ARG PYTHON_IMAGE=python:3.12-slim-trixie@sha256:a6e34c598f2467ed0e9a8d349809fcd8b5c603269512df273a0bb1784edc11b1

# hadolint ignore=DL3006
FROM ${PYTHON_IMAGE} AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_INPUT=1

RUN python -m venv /opt/venv

WORKDIR /build

COPY app/requirements.txt ./
RUN --mount=type=cache,target=/root/.cache/pip \
    /opt/venv/bin/pip install --only-binary=:all: -r requirements.txt

# hadolint ignore=DL3006
FROM ${PYTHON_IMAGE} AS runtime

ARG VERSION=dev
ARG REVISION=unknown
ARG CREATED=unknown

LABEL org.opencontainers.image.title="sample-app" \
      org.opencontainers.image.description="Greeting web application served by gunicorn" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.created="${CREATED}" \
      org.opencontainers.image.source="https://github.com/chaliahmadmehmood/dwp-devops-assessment" \
      org.opencontainers.image.licenses="MIT"


ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8080 \
    WEB_CONCURRENCY=2

RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app \
       --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin app

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY app/app.py ./

USER 10001:10001

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import os, urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/healthz' % os.environ['PORT'], timeout=2)"]

CMD ["gunicorn", \
     "--worker-tmp-dir", "/dev/shm", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "app:app"]
