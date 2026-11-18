# ============================================================================
# SuryaLog Cloud -- API Service Dockerfile (Module 2)
# Multi-stage build, digest-pinned Python base, non-root user, clean cache
# ============================================================================

# ---- STAGE 1: Builder ----
FROM python:3.11-slim@sha256:da047cb8f9d1d98e5c070f5300ba9f7274e33b8fc0e5be5ed88740aed1b95ba9 AS builder

WORKDIR /build

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc libpq-dev && \
    rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---- STAGE 2: Final Runner ----
FROM python:3.11-slim@sha256:da047cb8f9d1d98e5c070f5300ba9f7274e33b8fc0e5be5ed88740aed1b95ba9 AS runner

# Create non-root system user & group
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /bin/false appuser

WORKDIR /app

# Copy installed packages from builder stage
COPY --from=builder /install /usr/local
COPY app/ /app/app/

# Environment variables
ENV PYTHONUNBUFFERED=1 \
    PORT=8080

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')" || exit 1

CMD ["python", "app/api.py"]
