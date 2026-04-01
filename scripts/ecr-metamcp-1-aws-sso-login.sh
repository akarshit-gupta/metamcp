#!/usr/bin/env bash
# Step 1: Refresh AWS credentials for the dev/staging profile (before ECR push).
#
# Skip on EC2 with an instance role — use ecr-metamcp-2-build.sh and ecr-metamcp-3-push-ecr.sh only.
#
# Usage:
#   ./scripts/ecr-metamcp-1-aws-sso-login.sh
#
# Optional env:
#   AWS_PROFILE (default: dbaas-app-staging)
#   AWS_SSO_LOGIN_MODE — how to log in:
#     auto  (default) — aws sso login if profile has sso_start_url; else aws-azure-login if installed;
#                     otherwise print help and exit 1
#     sso   — always aws sso login (fails if profile is not aws configure sso)
#     azure — always aws-azure-login (see AZURE_LOGIN_EXTRA)
#   AZURE_LOGIN_EXTRA — extra args for aws-azure-login (default: --no-sandbox --mode gui)

set -euo pipefail

AWS_PROFILE="${AWS_PROFILE:-dbaas-app-staging}"
export AWS_PROFILE

MODE="${AWS_SSO_LOGIN_MODE:-auto}"
AZURE_LOGIN_EXTRA="${AZURE_LOGIN_EXTRA:---no-sandbox --mode gui}"

sso_start_url="$(aws configure get sso_start_url --profile "${AWS_PROFILE}" 2>/dev/null || true)"

run_sso() {
  echo "AWS SSO login for profile: ${AWS_PROFILE}"
  aws sso login --profile "${AWS_PROFILE}"
}

run_azure() {
  if ! command -v aws-azure-login &>/dev/null; then
    echo "AWS_SSO_LOGIN_MODE=azure but aws-azure-login is not installed or not on PATH." >&2
    exit 1
  fi
  echo "Azure AD login (aws-azure-login) for profile: ${AWS_PROFILE}"
  # shellcheck disable=SC2086
  aws-azure-login ${AZURE_LOGIN_EXTRA} --profile "${AWS_PROFILE}"
}

case "${MODE}" in
  sso)
    if [[ -z "${sso_start_url}" ]]; then
      echo "Profile '${AWS_PROFILE}' is not configured for AWS SSO (missing sso_start_url)." >&2
      echo "Run: aws configure sso" >&2
      echo "Or use Azure AD: AWS_SSO_LOGIN_MODE=azure ./scripts/ecr-metamcp-1-aws-sso-login.sh" >&2
      exit 1
    fi
    run_sso
    ;;
  azure)
    run_azure
    ;;
  auto)
    if [[ -n "${sso_start_url}" ]]; then
      run_sso
    elif command -v aws-azure-login &>/dev/null; then
      echo "Profile '${AWS_PROFILE}' has no native AWS SSO; using aws-azure-login."
      run_azure
    else
      echo "Profile '${AWS_PROFILE}' is not set up for AWS SSO (no sso_start_url in ~/.aws/config)." >&2
      echo "" >&2
      echo "Pick one:" >&2
      echo "  1) Configure IAM Identity Center:  aws configure sso" >&2
      echo "  2) Use Azure AD (install aws-azure-login), then either:" >&2
      echo "       AWS_SSO_LOGIN_MODE=azure ./scripts/ecr-metamcp-1-aws-sso-login.sh" >&2
      echo "     or run: aws-azure-login --no-sandbox --mode gui --profile ${AWS_PROFILE}" >&2
      echo "  3) If credentials already work: skip this script; use SKIP_AWS_SSO_LOGIN=1 on the wrapper." >&2
      exit 1
    fi
    ;;
  *)
    echo "Invalid AWS_SSO_LOGIN_MODE='${MODE}' (use auto, sso, or azure)." >&2
    exit 1
    ;;
esac

echo "OK. Next: ./scripts/ecr-metamcp-2-build.sh [VERSION]"
echo "Then:    ./scripts/ecr-metamcp-3-push-ecr.sh [same VERSION if you passed one]"
