#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bootstrap-backend.sh --bucket NAME --table NAME --region REGION

Example:
  ./scripts/bootstrap-backend.sh \
    --bucket my-tf-state-bucket \
    --table my-tf-locks \
    --region eu-west-1

Creates the S3 bucket and DynamoDB table used by the Terraform backend.
EOF
}

bucket_name=""
table_name=""
aws_region=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket)
      bucket_name="${2:-}"
      shift 2
      ;;
    --table)
      table_name="${2:-}"
      shift 2
      ;;
    --region)
      aws_region="${2:-}"
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

if [[ -z "${bucket_name}" || -z "${table_name}" || -z "${aws_region}" ]]; then
  usage >&2
  exit 1
fi

if ! command -v aws > /dev/null 2>&1; then
  printf 'AWS CLI is required.\n' >&2
  exit 1
fi

account_id="$(aws sts get-caller-identity --query Account --output text)"
printf 'Using AWS account %s in %s.\n' "${account_id}" "${aws_region}"

if aws s3api head-bucket --bucket "${bucket_name}" --region "${aws_region}" > /dev/null 2>&1; then
  printf 'S3 bucket already exists: %s\n' "${bucket_name}"
else
  printf 'Creating S3 bucket: %s\n' "${bucket_name}"
  if [[ "${aws_region}" == "us-east-1" ]]; then
    aws s3api create-bucket \
      --bucket "${bucket_name}" \
      --region "${aws_region}" > /dev/null
  else
    aws s3api create-bucket \
      --bucket "${bucket_name}" \
      --region "${aws_region}" \
      --create-bucket-configuration "LocationConstraint=${aws_region}" > /dev/null
  fi
fi

aws s3api put-bucket-versioning \
  --bucket "${bucket_name}" \
  --versioning-configuration "Status=Enabled" \
  --region "${aws_region}" > /dev/null

aws s3api put-bucket-encryption \
  --bucket "${bucket_name}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --region "${aws_region}" > /dev/null

aws s3api put-public-access-block \
  --bucket "${bucket_name}" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
  --region "${aws_region}" > /dev/null

if aws dynamodb describe-table \
  --table-name "${table_name}" \
  --region "${aws_region}" > /dev/null 2>&1; then
  printf 'DynamoDB table already exists: %s\n' "${table_name}"
else
  printf 'Creating DynamoDB table: %s\n' "${table_name}"
  aws dynamodb create-table \
    --table-name "${table_name}" \
    --attribute-definitions "AttributeName=LockID,AttributeType=S" \
    --key-schema "AttributeName=LockID,KeyType=HASH" \
    --billing-mode PAY_PER_REQUEST \
    --sse-specification "Enabled=true" \
    --region "${aws_region}" > /dev/null

  aws dynamodb wait table-exists \
    --table-name "${table_name}" \
    --region "${aws_region}"
fi

aws dynamodb update-continuous-backups \
  --table-name "${table_name}" \
  --point-in-time-recovery-specification "PointInTimeRecoveryEnabled=true" \
  --region "${aws_region}" > /dev/null

printf 'Terraform backend resources are ready.\n'
