# Module 2 -- Containers with Docker: Images, Registry & Compose (reference repo)

The per-module deliverable in this course is a **Git repository**, not a notebook. This folder contains the reference implementation for **Module 2**: containerizing the SuryaLog Cloud platform into a 5-service multi-container stack (`api`, `worker`, `db`, `cache`, `web`) with Docker and Docker Compose.

## Layout

```
Module2/
  Makefile                 make build / scan / up / test / push / down / clean
  compose.yaml             5-service topology (api, worker, db, cache, web)
  .dockerignore            build context exclusions
  sample-readings.sql      FIXED seed: 10 plants x 24 h = 240 rows, no RNG
  toy_container_demo.sh    rootfs tarball + JSON manifest demo script (Analysis A2)
  image_hygiene_check.sh   Dockerfile security & hygiene audit tool
  runbook.md               operational runbook (build, scan, deploy, push, verify)
  app/
    api.py                 Python REST API: /healthz, /summary, /readings
    worker.py              background aggregation worker updating Redis
    requirements.txt       pinned dependencies (psycopg, redis, requests)
    web/                   static frontend dashboard (index.html, style.css, app.js)
  docker/
    api.Dockerfile         multi-stage digest-pinned REST API Dockerfile
    worker.Dockerfile      multi-stage digest-pinned background worker Dockerfile
    web.Dockerfile         digest-pinned lightweight Nginx web server Dockerfile
    single.Dockerfile      NAIVE counter-example (Example E1/E5) -- not deployed
```

## Verified

Built and run end-to-end on **2026-09-16**, re-verified after the digest fix on
**2026-09-22**, Docker **28.3.2** (Windows + WSL2 backend). The table below is
from the 2026-09-22 run (all 5 containers healthy from a clean
`docker compose down -v` / `up -d --build` cycle):

| Check | Result |
|---|---|
| `docker build -f docker/single.Dockerfile` | **419 MB**, runs as `root` |
| `docker build -f docker/api.Dockerfile` | **149 MB**, runs as `appuser` |
| Multi-stage saving | **270 MB / 64.4 %** |
| Rebuild, no change | 1.0 s (full cache hit) |
| Rebuild after source edit, multi-stage | **2.0 s** (7 CACHED, `pip install` reused) |
| Rebuild after source edit, single-stage | **8.8 s** (2 CACHED, `pip install` re-run) |
| `bash image_hygiene_check.sh` | GREEN (exit 0) |
| `bash image_hygiene_check.sh --include-counter-example` | RED (exit 1, 3 FAILs on `single.Dockerfile`) |
| `docker compose up -d --build` | all 5 services up; `db`/`cache`/`api`/`web` healthy |
| `curl /healthz` | `{"status":"ok","database":true,"cache":true}` |
| `curl /summary` | `rows=240, plants=10, total_kwh=231.2, mean_irradiance=1.83, peak_hour=12, peak_kwh=3.42` |
| `bash toy_container_demo.sh` | produces `rootfs/` + `manifest.json` tarball |

### Notes on fixes applied while verifying

* **All four base-image digests were invalid** and had to be re-resolved against
  the registry (`python:3.11-slim`, `postgres:16-alpine`, `redis:7-alpine`,
  `nginx:1.25-alpine-slim`). Before this, `docker compose up` failed with
  `manifest unknown` and the stack could not start at all. **This note was
  written on 2026-09-16, but the re-resolved digests were never actually
  committed to `compose.yaml`/the Dockerfiles** -- re-discovered broken again
  on 2026-09-22 (still `manifest unknown` for postgres/redis) and fixed for
  real this time; the four pinned digests are listed below and were each
  confirmed with `docker manifest inspect` on 2026-09-22.

* `docker/single.Dockerfile` was added: it is referenced by Example E1/E5 in the
  module but did not previously exist.
* `image_hygiene_check.sh` now skips `single.Dockerfile` by default (it is a
  deliberate counter-example and would otherwise keep `make scan` permanently
  red); pass `--include-counter-example` to audit it.

Currently pinned (confirmed resolvable on 2026-09-22):

| Image | Digest |
|---|---|
| `python:3.11-slim` | `sha256:da047cb8f9d1d98e5c070f5300ba9f7274e33b8fc0e5be5ed88740aed1b95ba9` |
| `postgres:16-alpine` | `sha256:721873c34ceb9f8d8fc265984940dc982404c105f19ad51be9fdc5970a6080ea` |
| `redis:7-alpine` | `sha256:520775a41a63e77e06c73e35d2fd9cc15921a609516818796b4ecbb813078bc7` |
| `nginx:1.25-alpine-slim` | `sha256:22414422d1ba07234d9b784f6453b4f150c0fa573ad0b62e163da12b68488ae1` |

Digests are expected to be **re-resolved each semester** — pinning forever also
means never receiving security patches. Re-resolve with:

```bash
docker pull python:3.11-slim
docker inspect --format='{{index .RepoDigests 0}}' python:3.11-slim
```

## Quick Start

```bash
cd code/Module2
make build       # build multi-stage container images (~30 s)
make scan        # audit Dockerfiles for digest pinning, non-root, hygiene
make up          # bring up 5-container stack with Docker Compose
make test        # automated smoke test: /healthz, /summary, /readings -> 3/3 PASS
make down        # tear down containers and volume resources
```

## Prerequisites

- **Docker Engine** >= 24.0.0
- **Docker Compose** >= 2.20.0
- **Python 3** & **Make** on host (for test execution and Makefile helpers)
- No paid cloud account required.

## Seed Data -- Expected `/summary`

`sample-readings.sql` is deterministic (identical across all 10 plants). `GET /summary` must return exactly:

| Field | Value |
|---|---|
| `rows` | 240 |
| `plants` | 10 |
| `total_kwh` | 231.20 |
| `mean_irradiance` | 1.83 |
| `peak_hour` | 12 |
| `peak_kwh` | 3.42 |

## Script / Target Map

| Target | Reproduces | Notes |
|---|---|---|
| `make build` | Worked Example E1 / Case Study Step 1 | Multi-stage Docker build for images |
| `make scan` | Image Hygiene Audit / Lab 2 | Audits non-root, base digest pinning, `.dockerignore` |
| `make up` | Case Study Step 3 | Launches 5 containers with health check gates |
| `make test` | Case Study terminal transcript | Smoke tests `/healthz`, `/summary`, `/readings` |
| `toy_container_demo.sh` | Analysis Assignment A2 | Reproduces rootfs + OCI JSON manifest tarball execution |
| `make push` | Lab 3 | Tags and pushes images to container registry (GHCR) |

## Notes on Fixes Applied While Verifying

- **Dependency resolution:** Pinned `psycopg[binary]==3.1.18` in builder stage to avoid compilation errors.
- **Healthcheck dependency:** Added `condition: service_healthy` in `compose.yaml` to ensure `api` and `worker` wait for Postgres and Redis readiness before startup.

## Verified

| Module | Status | Date | Toolchain |
|---|---|---|---|
| 2 | **Verified end to end**: all 5 containers healthy, smoke test passing, hygiene audit green | 2026-09-22 | Docker 28.3.2, Python 3.11, Windows 11 host |
