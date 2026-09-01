#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-github-oidc.sh --region REGION --bucket NAME --table NAME [options]

Options:
  --state-key KEY   Terraform state key (default: axis/dev/terraform.tfstate)
  --role-name NAME  GitHub deployment role name (default: axis-dev-github-terraform)
  --help, -h        Show this help message
EOF
}

aws_region=""
bucket_name=""
table_name=""
state_key="axis/dev/terraform.tfstate"
role_name="axis-dev-github-terraform"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region)
      aws_region="${2:-}"
      shift 2
      ;;
    --bucket)
      bucket_name="${2:-}"
      shift 2
      ;;
    --table)
      table_name="${2:-}"
      shift 2
      ;;
    --state-key)
      state_key="${2:-}"
      shift 2
      ;;
    --role-name)
      role_name="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${aws_region}" || -z "${bucket_name}" || -z "${table_name}" || -z "${state_key}" || -z "${role_name}" ]]; then
  usage >&2
  exit 1
fi

if ! command -v aws > /dev/null 2>&1; then
  printf 'AWS CLI is required.\n' >&2
  exit 1
fi

github_oidc_url="https://token.actions.githubusercontent.com"
github_oidc_host="token.actions.githubusercontent.com"
github_subject="repo:cloudenochcsis@155973884/merchant-platform-infra@1352702887:ref:refs/heads/main"

account_id="$(aws sts get-caller-identity --query Account --output text)"
oidc_provider_arn="arn:aws:iam::${account_id}:oidc-provider/${github_oidc_host}"
role_arn="arn:aws:iam::${account_id}:role/${role_name}"

temporary_directory="$(mktemp -d)"
trap 'rm -rf "${temporary_directory}"' EXIT
trust_policy_path="${temporary_directory}/trust-policy.json"

cat > "${trust_policy_path}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsTrust",
      "Effect": "Allow",
      "Principal": {
        "Federated": "${oidc_provider_arn}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${github_oidc_host}:aud": "sts.amazonaws.com",
          "${github_oidc_host}:sub": "${github_subject}"
        }
      }
    }
  ]
}
EOF

printf 'Using AWS account %s.\n' "${account_id}"

if aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn "${oidc_provider_arn}" > /dev/null 2>&1; then
  printf 'GitHub OIDC provider already exists.\n'
else
  printf 'Creating GitHub OIDC provider.\n'
  aws iam create-open-id-connect-provider \
    --url "${github_oidc_url}" \
    --client-id-list "sts.amazonaws.com" > /dev/null
fi

if aws iam get-role --role-name "${role_name}" > /dev/null 2>&1; then
  printf 'Updating role trust policy: %s\n' "${role_name}"
  aws iam update-assume-role-policy \
    --role-name "${role_name}" \
    --policy-document "file://${trust_policy_path}"
else
  printf 'Creating role: %s\n' "${role_name}"
  aws iam create-role \
    --role-name "${role_name}" \
    --description "Terraform deployment role for merchant-platform-infra" \
    --assume-role-policy-document "file://${trust_policy_path}" \
    --max-session-duration 3600 \
    --tags Key=Project,Value=axis Key=Environment,Value=dev > /dev/null
fi
