# DevOps Interview Task (Part 1): Containerize

**This is a take-home task.** Please submit by the date given when the task was
issued.

## Overview

You are given a small web application (`app/`). A working `Dockerfile` is
provided, but it was written quickly and does **not** follow container best
practices. Your job is to refactor it into a production-quality image and push
it to a container registry.

You do **not** need to modify the application code.

## What we provide

Clone this repository into your local account.

> **Do Not** fork this repository. Clone it and re-push it into your local account.

The following is provided as part of this repository:

```text
Dockerfile            # a working but non-production Dockerfile — improve it
app/
  app.py              # a minimal Python Flask web app (do not modify)
  requirements.txt    # the app's dependencies (do not modify)
```

The application:

-   Listens on the port given by the `PORT` environment variable (default `8080`).
-   Reads a `GREETING` environment variable used in its response.
-   Exposes `GET /`, `GET /healthz`, and `GET /info`.

## Container image

The `Dockerfile` is a two-stage build producing a small, non-root runtime image.

| Practice                | Implementation                                                           |
| ----------------------- | ------------------------------------------------------------------------ |
| Pinned, minimal base    | `python:3.12-slim-trixie` pinned by digest                                |
| Multi-stage build       | Dependencies installed into a venv in `builder`; only the venv is copied |
| No build tooling        | `--only-binary=:all:`; no gcc, curl or vim in the final image            |
| Layer caching           | `requirements.txt` copied before code; BuildKit pip cache mount          |
| Non-root                | Fixed UID/GID `10001`; code is root-owned and read-only                  |
| Read-only root FS ready | No bytecode writes; gunicorn heartbeat in `/dev/shm`                     |
| Signal handling         | Exec-form `CMD`, gunicorn is PID 1 and shuts down gracefully             |
| Observability           | Logs to stdout/stderr; `HEALTHCHECK` against `/healthz`                  |
| Configuration           | `PORT` (default `8080`), `WEB_CONCURRENCY` (default `2`), `GREETING`     |
| Build context           | `.dockerignore` excludes VCS, docs and local files                       |
| Metadata                | OCI labels (version, revision, created, source, licence)                 |

### Build and run

```bash
docker build \
    --build-arg VERSION=v1 \
    --build-arg REVISION="$(git rev-parse HEAD)" \
    --build-arg CREATED="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    -t ghcr.io/chaliahmadmehmood/sample-app:v1 .

docker run --rm -p 8080:8080 -e GREETING="Hello" \
    --read-only --cap-drop ALL --security-opt no-new-privileges \
    ghcr.io/chaliahmadmehmood/sample-app:v1

curl localhost:8080/healthz
```

### Publish

```bash
echo "$GITHUB_TOKEN" | docker login ghcr.io -u chaliahmadmehmood --password-stdin
docker push ghcr.io/chaliahmadmehmood/sample-app:v1
```

Image: `ghcr.io/chaliahmadmehmood/sample-app:v1` (public).

The GitHub Actions workflow in `.github/workflows/image.yml` lints the
Dockerfile (hadolint), builds, scans (Trivy) and, on `v*.*.*` tags, publishes a
multi-arch image to GHCR using the ephemeral `GITHUB_TOKEN`.

### Known limitation

`app/requirements.txt` is out of scope and pins `gunicorn==22.0.0`, which has
known advisories fixed in 23.x. The image scan is therefore report-only; bump
the pin before production use.
