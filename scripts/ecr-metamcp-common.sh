# Shared defaults for ecr-metamcp-*.sh scripts.
# Usage: ROOT_DIR must be set to the repo root before sourcing.
#   ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
#   source "${ROOT_DIR}/scripts/ecr-metamcp-common.sh"
#   ecr_metamcp_resolve_image_ref "${1:-}"

: "${ROOT_DIR:?ecr-metamcp-common.sh: set ROOT_DIR to repo root before sourcing}"

unalias docker 2>/dev/null || true

if [[ -n "${CONTAINER_CMD:-}" ]]; then
  :
elif command -v podman &>/dev/null; then
  CONTAINER_CMD=podman
elif command -v docker &>/dev/null; then
  CONTAINER_CMD=docker
else
  echo "Neither podman nor docker found. Install one or set CONTAINER_CMD." >&2
  return 1 2>/dev/null || exit 1
fi

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-582763096612}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-dbaas-ss-chat/metamcp}"
IMAGE_NAME_PREFIX="${IMAGE_NAME_PREFIX:-MetaMCP-dev-custom}"
DOCKERFILE="${DOCKERFILE:-Dockerfile}"
PLATFORM="${PLATFORM:-linux/amd64}"

# Sets VERSION, TAG, ECR_REGISTRY, FULL_IMAGE. Pass optional version string as $1
# or set VERSION in the environment. If unset, uses UTC timestamp + short git sha.
ecr_metamcp_resolve_image_ref() {
  local v="${VERSION:-${1:-}}"
  if [[ -z "$v" ]]; then
    v="$(date -u +%Y%m%d-%H%M%S)-$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo local)"
  fi
  VERSION="$v"
  TAG="${IMAGE_NAME_PREFIX}-${VERSION}"
  ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
  FULL_IMAGE="${ECR_REGISTRY}/${ECR_REPOSITORY}:${TAG}"
}
