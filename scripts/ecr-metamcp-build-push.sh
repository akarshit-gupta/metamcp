#!/usr/bin/env bash
# Build MetaMCP Docker image and push to AWS ECR in one run (single tag for build + push).
#
# EKS (linux/amd64 workers): the image MUST be linux/amd64. Apple Silicon defaults to arm64
# if you run a plain `docker build` without platform — pods then exit 255 on amd64 nodes.
# This script defaults PLATFORM=linux/amd64 and uses Docker Buildx when available so
# --platform is applied correctly for cross-builds.
#
# Prerequisites:
#   EC2: IAM role with ECR push; leave AWS_PROFILE unset. aws sts get-caller-identity
#   Laptop: ./scripts/ecr-metamcp-aws-login.sh first (or Azure login), then export AWS_PROFILE if needed.
#
# Usage:
#   ./scripts/ecr-metamcp-build-push.sh              # VERSION = UTC date + short git sha
#   ./scripts/ecr-metamcp-build-push.sh 1.2.3
#   ./scripts/ecr-metamcp-build-push.sh --no-cache   # full rebuild, no layer cache
#   ./scripts/ecr-metamcp-build-push.sh --no-cache 1.2.3
#   VERSION=1.2.3 ./scripts/ecr-metamcp-build-push.sh
#
# Optional env:
#   AWS_PROFILE — laptop only; EC2 instance role: unset
#   SKIP_ECR_LOGIN=1 — skip get-login-password | container login (not for first ECR push)
#   DOCKER_BUILD_NO_CACHE=1 — same as --no-cache (ignore BuildKit layer cache)
#   CONTAINER_CMD — force podman or docker (default: podman if found, else docker)
#   PLATFORM — default linux/amd64 (EKS x86). Use linux/arm64 only for arm64-only clusters.
#   DOCKERFILE, AWS_ACCOUNT_ID, AWS_REGION, ECR_REPOSITORY, IMAGE_NAME_PREFIX
#
# After push, verify architecture:
#   docker buildx imagetools inspect <full-image-uri>

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
IMAGE_NAME_PREFIX="${IMAGE_NAME_PREFIX:-MetaMCP}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
PLATFORM="${PLATFORM:-linux/amd64}"

v="${VERSION:-${1:-}}" # remaining $1 after optional --no-cache flags
if [[ -z "$v" ]]; then
  v="$(date -u +%Y%m%d-%H%M%S)-$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo local)"
fi
VERSION="$v"
TAG="${IMAGE_NAME_PREFIX}-${VERSION}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
FULL_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${TAG}"

if [[ "$(uname -s)" == "Darwin" && "$(uname -m)" == "arm64" && "${PLATFORM}" == "linux/amd64" ]]; then
  echo "Note: Building linux/amd64 on Apple Silicon (qemu/binfmt). If the build fails in esbuild/tsup," >&2
  echo "      build on an linux/amd64 host (e.g. EC2) or use a remote buildx builder. Do not push a plain" >&2
  echo "      local arm64 image to EKS amd64 nodes — pods will exit 255." >&2
  echo "" >&2
fi

echo "Using ${CONTAINER_CMD} for build + push"
if [[ "${NO_CACHE}" == "1" ]]; then
  echo "Build: --no-cache (full rebuild, no layer cache)"
fi
echo "Building ${FULL_IMAGE} (platform=${PLATFORM}, Dockerfile=${DOCKERFILE}) ..."

ecr_login() {
  if [[ "${SKIP_ECR_LOGIN:-0}" != "1" ]]; then
    echo "Logging in to ECR ${ECR_REGISTRY} ..."
    if [[ -n "${AWS_PROFILE:-}" ]]; then
      export AWS_PROFILE
    fi
    aws ecr get-login-password --region "${AWS_REGION}" |
      "${CONTAINER_CMD}" login --username AWS --password-stdin "${ECR_REGISTRY}"
  fi
}

# Docker: prefer buildx + --push so --platform is honored (critical for Mac ARM -> EKS amd64).
use_docker_buildx=0
if [[ "${CONTAINER_CMD}" == "docker" ]] && docker buildx version &>/dev/null; then
  use_docker_buildx=1
fi

if [[ "${use_docker_buildx}" == "1" ]]; then
  export DOCKER_BUILDKIT=1
  ecr_login
  bx_args=(
    buildx build
    --platform "${PLATFORM}"
    -f "${DOCKERFILE}"
    -t "${FULL_IMAGE}"
    --provenance=false
    --sbom=false
    --push
  )
  [[ "${NO_CACHE}" == "1" ]] && bx_args+=(--no-cache)
  bx_args+=(.)
  docker "${bx_args[@]}"
else
  if [[ "${CONTAINER_CMD}" == "docker" ]]; then
    export DOCKER_BUILDKIT=1
    echo "Warning: docker buildx not found; using docker build. Ensure Docker 20+ and BuildKit for reliable --platform." >&2
  fi
  build_args=(
    --platform "${PLATFORM}"
    -f "${DOCKERFILE}"
    -t "${FULL_IMAGE}"
  )
  [[ "${NO_CACHE}" == "1" ]] && build_args+=(--no-cache)
  build_args+=(.)
  "${CONTAINER_CMD}" build "${build_args[@]}"
  ecr_login
  echo "Pushing ${FULL_IMAGE} ..."
  "${CONTAINER_CMD}" push "${FULL_IMAGE}"
fi

echo "Done. Helm/K8s tag:"
echo "  tag: ${TAG}"
echo "Full URI:"
echo "  ${FULL_IMAGE}"
if [[ "${use_docker_buildx}" == "1" ]]; then
  echo "Verify manifest platform (expect ${PLATFORM}):"
  echo "  docker buildx imagetools inspect ${FULL_IMAGE}"
fi
