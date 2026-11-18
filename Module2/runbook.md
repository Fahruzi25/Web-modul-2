# Module 2 Runbook -- SuryaLog Cloud Containerized Stack

This runbook documents the operational workflow for building, auditing, orchestrating, and troubleshooting the containerized **SuryaLog Cloud** application stack in Module 2.

---

## 1. Prerequisites

- **Docker Engine** >= 24.0.0
- **Docker Compose** >= 2.20.0
- **GNU Make** & **curl** / **python3**

Verify your local environment:
```bash
docker --version
docker compose version
```

---

## 2. Quick Operations Guide

### A. Build Container Images
Build multi-stage images for `api`, `worker`, and `web`:
```bash
make build
# or: docker compose build
```

### B. Run Image Hygiene Audit
Audit Dockerfiles for digest pinning, non-root user, clean apt cache, and absence of hardcoded secrets:
```bash
make scan
# or: bash image_hygiene_check.sh
```

### C. Bring Up Multi-Container Stack
Start all 5 services (`db`, `cache`, `api`, `worker`, `web`) in background:
```bash
make up
# or: docker compose up -d
```

Check service status and container health:
```bash
docker compose ps
```

### D. Run Smoke Test & Verification
Execute automated API smoke tests (`/healthz`, `/summary`, `/readings`):
```bash
make test
```
Expected output:
```
[*] Testing GET /healthz ... 200 OK
[*] Testing GET /summary ... 200 OK
[*] Testing GET /readings ... 200 OK
=== 3/3 SMOKE TESTS PASSED ===
```

### E. Verify Seed SQL Metrics
Query `/summary` and verify exact deterministic aggregates:
```bash
curl -s http://localhost:8080/summary | python3 -m json.tool
```
Expected payload:
```json
{
  "rows": 240,
  "plants": 10,
  "total_kwh": 231.20,
  "mean_irradiance": 1.83,
  "peak_hour": 12,
  "peak_kwh": 3.42,
  "cached": false
}
```

### F. Registry Push Operations (GHCR)
Tag and push images to GitHub Container Registry:
```bash
make push REGISTRY=ghcr.io/username
```

### G. Teardown Stack & Clean Resources
Stop containers and remove network/volume resources:
```bash
make down
# or: docker compose down -v
```

---

## 3. Troubleshooting & Failure Recovery

| Issue / Symptom | Root Cause | Remediation |
|---|---|---|
| `api` container dies with `psycopg.OperationalError` | Postgres `db` container not ready | `compose.yaml` uses `depends_on: db: condition: service_healthy`. Check `docker compose logs db`. |
| Port 8080 or 80 already in use | Local host service bound to port | Stop local process (`sudo systemctl stop nginx`) or change port mapping in `compose.yaml`. |
| `/summary` returns empty or `rows: 0` | Seed SQL init script failed | Ensure `sample-readings.sql` is mounted to `/docker-entrypoint-initdb.d/`. Run `make down` with `-v` to reset database volume. |
| `Permission denied` inside container | Non-root `appuser` lacking access | Verify `chown -R appuser:appgroup /app` in `docker/api.Dockerfile`. |
