#!/usr/bin/env bash
# Build MetaMCP and push to ECR — runs all steps in order (or skip SSO on servers).
#
# Split scripts (easier debugging):
#   1. ./scripts/ecr-metamcp-1-aws-sso-login.sh
#   2. ./scripts/ecr-metamcp-2-build.sh [VERSION]
#   3. ./scripts/ecr-metamcp-3-push-ecr.sh [same VERSION]
#
# This wrapper:
#   SKIP_AWS_SSO_LOGIN=1  — skip step 1 (EC2 with instance role, or SSO already done)
#   Same VERSION / env as the split scripts (pass optional VERSION as first arg)
#
# Optional env: AWS_PROFILE, AWS_SSO_LOGIN_MODE (auto|sso|azure), VERSION, SKIP_ECR_LOGIN, …

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ "${SKIP_AWS_SSO_LOGIN:-0}" != "1" ]]; then
  "${SCRIPT_DIR}/ecr-metamcp-1-aws-sso-login.sh"
else
  echo "Skipping AWS SSO login (SKIP_AWS_SSO_LOGIN=1)"
fi

# shellcheck source=ecr-metamcp-common.sh
source "${ROOT_DIR}/scripts/ecr-metamcp-common.sh"
ecr_metamcp_resolve_image_ref "${1:-}"
export VERSION

"${SCRIPT_DIR}/ecr-metamcp-2-build.sh"
"${SCRIPT_DIR}/ecr-metamcp-3-push-ecr.sh"
