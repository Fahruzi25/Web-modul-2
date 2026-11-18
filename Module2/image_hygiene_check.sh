#!/usr/bin/env bash
# ============================================================================
# Image Hygiene & Security Audit Tool -- Module 2
# Checks Dockerfiles for best practices: digest pinning, non-root, secrets, etc.
# ============================================================================

set -euo pipefail

EXIT_CODE=0

# Usage: image_hygiene_check.sh [docker-dir] [--include-counter-example]
# The flag may appear in either position.
DOCKER_DIR="docker"
INCLUDE_COUNTER=0
for arg in "$@"; do
    if [ "${arg}" = "--include-counter-example" ]; then
        INCLUDE_COUNTER=1
    else
        DOCKER_DIR="${arg}"
    fi
done

echo "================================================================="
echo "        SuryaLog Cloud -- Image Hygiene & Security Audit"
echo "================================================================="

check_file() {
    local df="$1"
    echo ""
    echo "[*] Auditing Dockerfile: ${df}"

    # Rule 1: Check base image digest pinning
    if grep -E "^FROM " "${df}" | grep -q "@sha256:"; then
        echo "  [PASS] Base image uses digest pinning (@sha256:...)"
    else
        echo "  [FAIL] Base image missing digest pinning (@sha256:...)"
        EXIT_CODE=1
    fi

    # Rule 2: Check forbidden :latest tag
    if grep -E "^FROM " "${df}" | grep -q ":latest"; then
        echo "  [FAIL] Base image uses forbidden ':latest' tag"
        EXIT_CODE=1
    else
        echo "  [PASS] Base image avoids ':latest' tag"
    fi

    # Rule 3: Check non-root USER directive (unless purely Nginx default)
    if grep -q "^USER " "${df}"; then
        echo "  [PASS] Non-root USER directive present"
    else
        if [[ "${df}" == *"web.Dockerfile"* ]]; then
            echo "  [WARN] Nginx image uses default container user (consider unprivileged port/user)"
        else
            echo "  [FAIL] Missing non-root USER directive"
            EXIT_CODE=1
        fi
    fi

    # Rule 4: Check apt cache cleanup
    if grep -q "apt-get install" "${df}"; then
        if grep -q "rm -rf /var/lib/apt/lists/\*" "${df}"; then
            echo "  [PASS] Apt cache explicitly cleaned up"
        else
            echo "  [FAIL] Apt cache not cleaned (missing rm -rf /var/lib/apt/lists/*)"
            EXIT_CODE=1
        fi
    fi

    # Rule 5: Check potential hardcoded secrets
    if grep -iE "(API_KEY|PASSWORD|SECRET_KEY)\s*=" "${df}"; then
        echo "  [FAIL] Potential hardcoded secret found in Dockerfile"
        EXIT_CODE=1
    else
        echo "  [PASS] No hardcoded secrets detected in build instructions"
    fi
}

if [ -f ".dockerignore" ]; then
    echo "[PASS] .dockerignore file exists in project root"
else
    echo "[FAIL] Missing .dockerignore file in project root"
    EXIT_CODE=1
fi

for df in "${DOCKER_DIR}"/*.Dockerfile; do
    if [ -f "${df}" ]; then
        # single.Dockerfile is the deliberately-bad counter-example used by
        # Example E1. It is expected to fail every check, so auditing it here
        # would make `make scan` permanently red. Audit it on demand instead:
        #   bash image_hygiene_check.sh --include-counter-example
        if [[ "${df}" == *"single.Dockerfile"* && "${INCLUDE_COUNTER}" -eq 0 ]]; then
            echo "[*] Skipping ${df} (counter-example; run with --include-counter-example to audit it)"
            echo ""
            continue
        fi
        check_file "${df}"
    fi
done

echo ""
echo "================================================================="
if [ ${EXIT_CODE} -eq 0 ]; then
    echo " RESULT: ALL IMAGE HYGIENE CHECKS PASSED SUCCESSFULLY [GREEN]"
else
    echo " RESULT: ONE OR MORE HYGIENE VIOLATIONS FOUND [RED]"
fi
echo "================================================================="

exit ${EXIT_CODE}
