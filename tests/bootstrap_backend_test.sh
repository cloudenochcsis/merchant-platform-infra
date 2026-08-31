#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="${repository_root}/scripts/bootstrap-backend.sh"
test_directory="$(mktemp -d)"
trap 'rm -rf "${test_directory}"' EXIT

mkdir -p "${test_directory}/bin"

cat > "${test_directory}/bin/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${AWS_CALL_LOG}"

case "$1 $2" in
  "sts get-caller-identity")
    printf '123456789012\n'
    ;;
  "s3api head-bucket"|"dynamodb describe-table")
    [[ "${BACKEND_RESOURCES_EXIST:-false}" == "true" ]]
    ;;
esac
EOF

chmod +x "${test_directory}/bin/aws"
export PATH="${test_directory}/bin:${PATH}"
export AWS_CALL_LOG="${test_directory}/aws-calls.log"

assert_called() {
  local expected="$1"
  grep -F -- "$expected" "${AWS_CALL_LOG}" > /dev/null || {
    printf 'Expected AWS call containing: %s\n' "$expected" >&2
    exit 1
  }
}

assert_not_called() {
  local unexpected="$1"
  if grep -F -- "$unexpected" "${AWS_CALL_LOG}" > /dev/null; then
    printf 'Unexpected AWS call containing: %s\n' "$unexpected" >&2
    exit 1
  fi
}

: > "${AWS_CALL_LOG}"
BACKEND_RESOURCES_EXIST=false "${script_path}" \
  --bucket axis-demo-state \
  --table axis-demo-locks \
  --region eu-west-1 > "${test_directory}/create-output.log"

assert_called "sts get-caller-identity"
assert_called "s3api create-bucket --bucket axis-demo-state --region eu-west-1 --create-bucket-configuration LocationConstraint=eu-west-1"
assert_called "s3api put-bucket-versioning --bucket axis-demo-state --versioning-configuration Status=Enabled --region eu-west-1"
assert_called "s3api put-bucket-encryption --bucket axis-demo-state"
assert_called "s3api put-public-access-block --bucket axis-demo-state"
assert_called "dynamodb create-table --table-name axis-demo-locks"
assert_called "--billing-mode PAY_PER_REQUEST"
assert_called "--sse-specification Enabled=true"
assert_called "dynamodb wait table-exists --table-name axis-demo-locks --region eu-west-1"
assert_called "dynamodb update-continuous-backups --table-name axis-demo-locks --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true --region eu-west-1"

: > "${AWS_CALL_LOG}"
BACKEND_RESOURCES_EXIST=true "${script_path}" \
  --bucket axis-demo-state \
  --table axis-demo-locks \
  --region eu-west-1 > "${test_directory}/existing-output.log"

assert_not_called "s3api create-bucket"
assert_not_called "dynamodb create-table"
assert_called "s3api put-bucket-versioning"
assert_called "dynamodb update-continuous-backups"

: > "${AWS_CALL_LOG}"
BACKEND_RESOURCES_EXIST=false "${script_path}" \
  --bucket axis-us-east-state \
  --table axis-us-east-locks \
  --region us-east-1 > "${test_directory}/us-east-output.log"

assert_called "s3api create-bucket --bucket axis-us-east-state --region us-east-1"
assert_not_called "LocationConstraint=us-east-1"

printf 'bootstrap backend tests passed\n'
