#!/usr/bin/env bash
# Build MetaMCP Docker image and push to AWS ECR in one run (single tag for build + push).
#
# Prerequisites:
#   EC2: IAM role with ECR push; leave AWS_PROFILE unset. aws sts get-caller-identity
#   Laptop: ./scripts/ecr-metamcp-aws-login.sh first (or Azure login), then export AWS_PROFILE if needed.
#
# Usage:
#   ./scripts/ecr-metamcp-build-push.sh              # VERSION = UTC date + short git sha
#   ./scripts/ecr-metamcp-build-push.sh 1.2.3
#   VERSION=1.2.3 ./scripts/ecr-metamcp-build-push.sh
#
# Optional env:
#   AWS_PROFILE — laptop only; EC2 instance role: unset
#   SKIP_ECR_LOGIN=1 — skip get-login-password | container login
#   CONTAINER_CMD — podman or docker
#   PLATFORM, DOCKERFILE, AWS_ACCOUNT_ID, AWS_REGION, ECR_REPOSITORY, IMAGE_NAME_PREFIX

set -euo pipefail

unalias docker 2>/dev/null || true

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

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

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-582763096612}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-dbaas-ss-chat/metamcp}"
IMAGE_NAME_PREFIX="${IMAGE_NAME_PREFIX:-MetaMCP-dev-custom}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
PLATFORM="${PLATFORM:-linux/amd64}"

v="${VERSION:-${1:-}}"
if [[ -z "$v" ]]; then
  v="$(date -u +%Y%m%d-%H%M%S)-$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo local)"
fi
VERSION="$v"
TAG="${IMAGE_NAME_PREFIX}-${VERSION}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${TAG}"

if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" && "${PLATFORM}" == "linux/amd64" ]]; then
  echo "Note: linux/amd64 on Apple Silicon is emulated; esbuild may fail during build. Use EC2 or PLATFORM=linux/arm64 (arm64 clusters only)." >&2
  echo "" >&2
fi

echo "Using ${CONTAINER_CMD} for build + push"
echo "Building ${FULL_IMAGE} (platform=${PLATFORM}, Dockerfile=${DOCKERFILE}) ..."
"${CONTAINER_CMD}" build \
  --platform "${PLATFORM}" \
  -f "${DOCKERFILE}" \
  -t "${FULL_IMAGE}" \
  .

if [[ "${SKIP_ECR_LOGIN:-0}" != "1" ]]; then
  echo "Logging in to ECR ${ECR_REGISTRY} ..."
  if [[ -n "${AWS_PROFILE:-}" ]]; then
    export AWS_PROFILE
  fi
  aws ecr get-login-password --region "${AWS_REGION}" |
    "${CONTAINER_CMD}" login --username AWS --password-stdin "${ECR_REGISTRY}"
fi

echo "Pushing ${FULL_IMAGE} ..."
"${CONTAINER_CMD}" push "${FULL_IMAGE}"

echo "Done. Helm/K8s tag:"
echo "  tag: ${TAG}"
echo "Full URI:"
echo "  ${FULL_IMAGE}"
