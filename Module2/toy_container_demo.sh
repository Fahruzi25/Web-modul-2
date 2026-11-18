#!/usr/bin/env bash
# ============================================================================
# Toy Container Demo Script -- Module 2 Analysis Assignment A2
# Reproduces platform behaviour: "Image = rootfs tarball + JSON manifest"
# ============================================================================

set -euo pipefail

WORKDIR="$(mktemp -d)"
echo "[+] Working directory: ${WORKDIR}"
trap 'rm -rf "${WORKDIR}"' EXIT

ROOTFS="${WORKDIR}/rootfs"
mkdir -p "${ROOTFS}/bin" "${ROOTFS}/etc" "${ROOTFS}/proc" "${ROOTFS}/app"

# 1. Populate minimal rootfs payload
cat << 'EOF' > "${ROOTFS}/app/main.sh"
#!/bin/sh
echo "=========================================="
echo "Hello from Toy Container Engine!"
echo "PID inside container: $$"
echo "Hostname: $(hostname)"
echo "App directory: /app"
echo "=========================================="
EOF
chmod +x "${ROOTFS}/app/main.sh"

# 2. Write OCI-style JSON image manifest
cat << EOF > "${WORKDIR}/manifest.json"
{
  "schemaVersion": 2,
  "config": {
    "mediaType": "application/vnd.oci.image.config.v1+json",
    "digest": "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "size": 240
  },
  "layers": [
    {
      "mediaType": "application/vnd.oci.image.layer.v1.tar+gzip",
      "digest": "sha256:7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd200126d9069",
      "size": 1024
    }
  ],
  "annotations": {
    "org.opencontainers.image.title": "toy-suryalog-app",
    "org.opencontainers.image.version": "1.0.0"
  }
}
EOF

# 3. Package into tarball (.tar.gz image artifact)
IMAGE_OUT="toy-suryalog-image.tar.gz"
echo "[+] Packaging toy container image to ${IMAGE_OUT}..."
tar -czf "${IMAGE_OUT}" -C "${WORKDIR}" rootfs manifest.json

echo "[+] Image created successfully! Contents:"
tar -tzf "${IMAGE_OUT}"

echo ""
echo "[+] Simulating container execution (unpacking rootfs & executing payload)..."
if [ "$(id -u)" -eq 0 ] && command -v chroot >/dev/null 2>&1; then
    echo "[+] Running isolated with chroot..."
    chroot "${ROOTFS}" /bin/sh /app/main.sh
else
    echo "[!] Not root or chroot unavailable. Executing payload direct from rootfs tree:"
    sh "${ROOTFS}/app/main.sh"
fi

echo "[+] Toy container demo completed."
