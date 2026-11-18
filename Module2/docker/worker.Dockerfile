# ============================================================================
# SuryaLog Cloud -- Worker Service Dockerfile (Module 2)
# Multi-stage build, digest-pinned Python base, non-root user
# ============================================================================

# ---- STAGE 1: Builder ----
FROM python:3.11-slim@sha256:da047cb8f9d1d98e5c070f5300ba9f7274e33b8fc0e5be5ed88740aed1b95ba9 AS builder

WORKDIR /build

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- STAGE 2: Final Runner ----
FROM python:3.11-slim@sha256:da047cb8f9d1d98e5c070f5300ba9f7274e33b8fc0e5be5ed88740aed1b95ba9 AS runner

RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/false appuser

WORKDIR /app

COPY --from=builder /install /usr/local
COPY app/ /app/app/

ENV PYTHONUNBUFFERED=1

RUN chown -R appuser:appgroup /app

USER appuser

CMD ["python", "app/worker.py"]
