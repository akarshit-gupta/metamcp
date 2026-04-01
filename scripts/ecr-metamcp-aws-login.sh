#!/usr/bin/env bash
# Refresh AWS credentials for ECR (laptop: SSO or Azure AD). Skip on EC2 with an instance role.
#
# Usage:
#   ./scripts/ecr-metamcp-aws-login.sh
#
# Optional env:
#   AWS_PROFILE (default: dbaas-app-staging)
#   AWS_SSO_LOGIN_MODE — auto (default) | sso | azure
#   AZURE_LOGIN_EXTRA — passed to aws-azure-login (default: --no-sandbox --mode gui)

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
      echo "Or: AWS_SSO_LOGIN_MODE=azure ./scripts/ecr-metamcp-aws-login.sh" >&2
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
      echo "  1) aws configure sso" >&2
      echo "  2) AWS_SSO_LOGIN_MODE=azure ./scripts/ecr-metamcp-aws-login.sh" >&2
      echo "  3) Skip this script on EC2 (instance role) or if credentials already work; run ./scripts/ecr-metamcp-build-push.sh" >&2
      exit 1
    fi
    ;;
  *)
    echo "Invalid AWS_SSO_LOGIN_MODE='${MODE}' (use auto, sso, or azure)." >&2
    exit 1
    ;;
esac

echo "OK. Next: ./scripts/ecr-metamcp-build-push.sh [VERSION]"
