#!/usr/bin/env bash
# Step 3: Log in to ECR with the AWS CLI and push the image built in step 2.
#
# Use the same VERSION / first argument as step 2 so the local tag matches.
#
# Usage:
#   ./scripts/ecr-metamcp-3-push-ecr.sh
#   ./scripts/ecr-metamcp-3-push-ecr.sh 1.2.3
#   VERSION=1.2.3 ./scripts/ecr-metamcp-3-push-ecr.sh
#
# Optional env:
#   AWS_PROFILE — export before running if you use SSO / named profile (after step 1)
#   SKIP_ECR_LOGIN=1 — skip get-login-password | container login (already logged in)
#   Same image env as ecr-metamcp-common.sh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=ecr-metamcp-common.sh
source "${ROOT_DIR}/scripts/ecr-metamcp-common.sh"

ecr_metamcp_resolve_image_ref "${1:-}"

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

echo "Done. Set your Helm/K8s image tag to:"
echo "  tag: ${TAG}"
echo "Full URI:"
echo "  ${FULL_IMAGE}"
