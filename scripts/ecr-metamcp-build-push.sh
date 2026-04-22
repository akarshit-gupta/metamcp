#!/usr/bin/env bash
set -euo pipefail

unalias docker 2>/dev/null || true

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

NO_CACHE=0
[[ "${DOCKER_BUILD_NO_CACHE:-0}" == "1" ]] && NO_CACHE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-cache)
      NO_CACHE=1
      shift
      ;;
    *)
      break
      ;;
  esac
done

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-582763096612}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-dbaas-ss-chat/metamcp}"
IMAGE_NAME_PREFIX="${IMAGE_NAME_PREFIX:-MetaMCP}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
PLATFORM="${PLATFORM:-linux/amd64}"

v="${VERSION:-${1:-}}"
if [[ -z "$v" ]]; then
  v="$(date -u +%Y%m%d-%H%M%S)-$(git rev-parse --short HEAD 2>/dev/null || echo local)"
fi

TAG="${IMAGE_NAME_PREFIX}-${v}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${TAG}"

echo "Building ${FULL_IMAGE} (platform=${PLATFORM})"

# ❗ REQUIRE BUILDX
if ! docker buildx version >/dev/null 2>&1; then
  echo "❌ docker buildx is required. Install/enable it." >&2
  exit 1
fi

# ✅ Ensure builder exists
docker buildx create --use --name mybuilder >/dev/null 2>&1 || true
docker buildx inspect --bootstrap

echo "Logging in to ECR..."
aws ecr get-login-password --region "${AWS_REGION}" |
  docker login --username AWS --password-stdin "${ECR_REGISTRY}"

echo "Building + pushing with buildx..."

BUILD_ARGS=(
  buildx build
  --platform "${PLATFORM}"
  -f "${DOCKERFILE}"
  -t "${FULL_IMAGE}"
  --push
  --provenance=false
  --sbom=false
)

[[ "${NO_CACHE}" == "1" ]] && BUILD_ARGS+=(--no-cache)

BUILD_ARGS+=(.)

docker "${BUILD_ARGS[@]}"

echo "✅ Done: ${FULL_IMAGE}"

echo
echo "🔍 Verifying architecture (MUST be linux/amd64):"
docker buildx imagetools inspect "${FULL_IMAGE}"