#!/usr/bin/env bash
# Build MetaMCP Docker image and push to AWS ECR (dbaas-ss-chat dev).
#
# Local smoke test with Podman (no push): ./scripts/podman-build-local.sh
#
# Prerequisites (run once per session):
#   export AWS_PROFILE=dbaas-app-staging
#   aws-azure-login --no-sandbox --mode gui --profile "$AWS_PROFILE"
#   # Select role: arn:aws:iam::582763096612:role/INFRA (or your deploy role)
#
# Usage:
#   ./scripts/ecr-push-metamcp-dev.sh                    # VERSION = date + short git sha
#   ./scripts/ecr-push-metamcp-dev.sh 1.2.3              # tag: MetaMCP-dev-custom-1.2.3
#   VERSION=1.2.3 ./scripts/ecr-push-metamcp-dev.sh
#
# Optional env:
#   AWS_PROFILE (default: dbaas-app-staging)
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

AWS_PROFILE="${AWS_PROFILE:-dbaas-app-staging}"
export AWS_PROFILE

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

echo "Using AWS_PROFILE=${AWS_PROFILE}"
if ! aws sts get-caller-identity --profile "${AWS_PROFILE}" --region "${AWS_REGION}" --output text >/dev/null 2>&1; then
  echo "Error: AWS CLI cannot use profile '${AWS_PROFILE}'." >&2
  echo "  1. Log in (same terminal session):" >&2
  echo "       export AWS_PROFILE=${AWS_PROFILE}" >&2
  echo "       aws-azure-login --no-sandbox --mode gui --profile \"\${AWS_PROFILE}\"" >&2
  echo "  2. Pick a role that can push to ECR in account ${AWS_ACCOUNT_ID}." >&2
  echo "Underlying AWS error:" >&2
  aws sts get-caller-identity --profile "${AWS_PROFILE}" --region "${AWS_REGION}" 2>&1 || true
  exit 1
fi

echo "Using ${CONTAINER_CMD} for login, build, push"
echo "Logging in to ECR ${ECR_REGISTRY} ..."
aws ecr get-login-password --profile "${AWS_PROFILE}" --region "${AWS_REGION}" |
  "${CONTAINER_CMD}" login --username AWS --password-stdin "${ECR_REGISTRY}"

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
