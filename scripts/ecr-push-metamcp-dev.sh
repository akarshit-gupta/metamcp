#!/usr/bin/env bash
# Build MetaMCP Docker image and push to AWS ECR (dbaas-ss-chat dev).
#
# Local smoke test with Podman (no push): ./scripts/podman-build-local.sh
#
# Prerequisites:
#   Authenticate your container engine to ECR before running (this script does not run aws login).
#   Example:
#     export AWS_PROFILE=dbaas-app-staging
#     aws-azure-login ...  # if your org uses it
#     aws ecr get-login-password --profile "$AWS_PROFILE" --region us-east-1 \\
#       | podman login --username AWS --password-stdin 582763096612.dkr.ecr.us-east-1.amazonaws.com
#
# Usage:
#   ./scripts/ecr-push-metamcp-dev.sh                    # VERSION = date + short git sha
#   ./scripts/ecr-push-metamcp-dev.sh 1.2.3              # tag: MetaMCP-dev-custom-1.2.3
#   VERSION=1.2.3 ./scripts/ecr-push-metamcp-dev.sh
#
# Optional env:
#   AWS_ACCOUNT_ID, AWS_REGION, ECR_REPOSITORY, IMAGE_NAME_PREFIX, DOCKERFILE, PLATFORM
#   CONTAINER_CMD — "podman" or "docker" (default: podman if installed, else docker)

set -euo pipefail

unalias docker 2>/dev/null || true

if [[ -n "${CONTAINER_CMD:-}" ]]; then
  :
elif command -v podman &>/dev/null; then
  CONTAINER_CMD=podman
elif command -v docker &>/dev/null; then
  CONTAINER_CMD=docker
else
  echo "Neither podman nor docker found. Install one or set CONTAINER_CMD." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-582763096612}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-dbaas-ss-chat/metamcp}"
IMAGE_NAME_PREFIX="${IMAGE_NAME_PREFIX:-MetaMCP-dev-custom}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
PLATFORM="${PLATFORM:-linux/amd64}"

VERSION="${VERSION:-${1:-}}"
if [[ -z "$VERSION" ]]; then
  VERSION="$(date -u +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD 2>/dev/null || echo local)"
fi

# ECR tag (alphanumeric, dots, dashes, underscores; mixed case allowed)
TAG="${IMAGE_NAME_PREFIX}-${VERSION}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${TAG}"

echo "Using ${CONTAINER_CMD} for build, push"
echo "Building ${FULL_IMAGE} (platform=${PLATFORM}, Dockerfile=${DOCKERFILE}) ..."
"${CONTAINER_CMD}" build \
  --platform "${PLATFORM}" \
  -f "${DOCKERFILE}" \
  -t "${FULL_IMAGE}" \
  .

echo "Pushing ${FULL_IMAGE} ..."
"${CONTAINER_CMD}" push "${FULL_IMAGE}"

echo "Done. Set your Helm/K8s image tag to:"
echo "  tag: ${TAG}"
echo "Full URI:"
echo "  ${FULL_IMAGE}"
