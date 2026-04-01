#!/usr/bin/env bash
# Build MetaMCP image locally with Podman (no ECR push).
# Use this to verify the Dockerfile before ./scripts/ecr-metamcp-build-push.sh.
#
# MetaMCP needs PostgreSQL at startup (see docker-entrypoint.sh). Easiest local loop:
#   1. Start Postgres (e.g. docker compose up -d postgres from this repo, or any reachable DB).
#   2. Build: ./scripts/podman-build-local.sh
#   3. Run:   see printed `podman run` example with your DATABASE_URL / POSTGRES_*.
#
# Connecting a LibreChat pod (Kubernetes) to MetaMCP on your laptop:
#   - The pod must reach your host where ports 12008 (UI/proxy) and 12009 (backend API) are published.
#   - Examples: Kind/extraPortMapping, minikube tunnel + host IP, or run MetaMCP inside the cluster
#     (same image) instead of on the host. There is no single URL; it depends on your cluster CNI.
#   - LibreChat mcpServers url often targets the frontend on 12008, e.g.
#     http://<host-reachable-from-pod>:12008/metamcp/<endpoint>/sse
#
# Usage (from repo root):
#   ./scripts/podman-build-local.sh
#   IMAGE_TAG=mytest ./scripts/podman-build-local.sh
#   PLATFORM=linux/arm64 ./scripts/podman-build-local.sh   # native on Apple Silicon

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v podman &>/dev/null; then
  echo "podman not found. Install Podman, then retry." >&2
  exit 1
fi

DOCKERFILE="${DOCKERFILE:-Dockerfile}"
IMAGE_NAME="${IMAGE_NAME:-localhost/metamcp}"
IMAGE_TAG="${IMAGE_TAG:-MetaMCP-dev-custom-local}"
PLATFORM="${PLATFORM:-linux/amd64}"

FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

echo "=== podman build ${FULL_IMAGE} (platform=${PLATFORM}) ==="
podman build \
  --platform "${PLATFORM}" \
  -f "${DOCKERFILE}" \
  -t "${FULL_IMAGE}" \
  .

echo ""
echo "=== Build OK: ${FULL_IMAGE}"
echo ""
echo "Example run (adjust POSTGRES_* / DATABASE_URL for your DB):"
echo "  podman run --rm -p 12008:12008 -p 12009:12009 \\"
echo "    -e POSTGRES_HOST=host.containers.internal \\"
echo "    -e POSTGRES_PORT=5432 \\"
echo "    -e POSTGRES_USER=metamcp_user \\"
echo "    -e POSTGRES_PASSWORD=*** \\"
echo "    -e POSTGRES_DB=metamcp_db \\"
echo "    -e DATABASE_URL=postgresql://metamcp_user:***@host.containers.internal:5432/metamcp_db \\"
echo "    -e APP_URL=http://localhost:12008 \\"
echo "    -e NEXT_PUBLIC_APP_URL=http://localhost:12008 \\"
echo "    -e BETTER_AUTH_SECRET=change-me \\"
echo "    ${FULL_IMAGE}"
echo ""
echo "On macOS Podman Machine, host.containers.internal usually reaches the host."
echo "Health: curl -sf http://localhost:12008/health && curl -sf http://localhost:12009/health"
