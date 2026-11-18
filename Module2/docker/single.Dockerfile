# ============================================================================
# SuryaLog Cloud -- API Service, NAIVE SINGLE-STAGE BUILD (Module 2)
#
# This file exists ONLY as the "before" half of the size comparison in
# Example E1. It deliberately commits the pitfalls catalogued in the Pitfalls
# section, and it is NOT the image the stack runs:
#
#   * floating :latest-style tag  -- no digest pin, so the base can move
#   * build toolchain kept        -- gcc and libpq-dev ship to production
#   * apt lists never cleaned     -- cached package metadata stays in a layer
#   * COPY . before pip install   -- any source edit busts the dependency cache
#   * runs as root                -- no USER directive
#
# Build it, measure it, then read api.Dockerfile to see each fault repaired.
# ============================================================================

FROM python:3.11-slim

WORKDIR /app

# Build toolchain installed into the SAME image that will be shipped.
# No --no-install-recommends, and no cleanup of /var/lib/apt/lists.
RUN apt-get update && \
    apt-get install -y gcc libpq-dev

# Whole build context copied in BEFORE dependencies are installed, so editing
# one line of api.py invalidates this layer and every layer after it.
COPY . /app

RUN pip install -r app/requirements.txt

EXPOSE 8080

CMD ["python", "app/api.py"]
