#!/usr/bin/env bash
# Step 2: Build the MetaMCP image (no AWS calls).
#
# Usage:
#   ./scripts/ecr-metamcp-2-build.sh              # VERSION = date + short git sha
#   ./scripts/ecr-metamcp-2-build.sh 1.2.3
#   VERSION=1.2.3 ./scripts/ecr-metamcp-2-build.sh
#
# Optional env: same as ecr-metamcp-common.sh (CONTAINER_CMD, PLATFORM, DOCKERFILE, AWS_ACCOUNT_ID, …)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ecr-metamcp-common.sh
source "${ROOT_DIR}/scripts/ecr-metamcp-common.sh"

cd "$ROOT_DIR"
ecr_metamcp_resolve_image_ref "${1:-}"

echo "Using ${CONTAINER_CMD} for build"
echo "Building ${FULL_IMAGE} (platform=${PLATFORM}, Dockerfile=${DOCKERFILE}) ..."
"${CONTAINER_CMD}" build \
  --platform "${PLATFORM}" \
  -f "${DOCKERFILE}" \
  -t "${FULL_IMAGE}" \
  .

echo "Build OK. Image tagged locally as:"
echo "  ${FULL_IMAGE}"
echo "Next: ./scripts/ecr-metamcp-3-push-ecr.sh ${VERSION}"
