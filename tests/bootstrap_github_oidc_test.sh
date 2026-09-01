#!/usr/bin/env bash

set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="${repository_root}/scripts/bootstrap-github-oidc.sh"
test_directory="$(mktemp -d)"
trap 'rm -rf "${test_directory}"' EXIT

mkdir -p "${test_directory}/bin"

cat > "${test_directory}/bin/aws" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${AWS_CALL_LOG}"

command_name="$1 $2"
previous=""
for argument in "$@"; do
  if [[ "${previous}" == "--assume-role-policy-document" ]]; then
    cp "${argument#file://}" "${CAPTURED_TRUST_POLICY}"
  fi
  if [[ "${previous}" == "--policy-document" && "${command_name}" == "iam put-role-policy" ]]; then
    cp "${argument#file://}" "${CAPTURED_PERMISSION_POLICY}"
  fi
  previous="${argument}"
done

case "$1 $2" in
  "sts get-caller-identity")
    printf '163120011463\n'
    ;;
  "iam get-open-id-connect-provider")
    [[ "${OIDC_EXISTS:-false}" == "true" ]]
    ;;
  "iam get-role")
    [[ "${ROLE_EXISTS:-false}" == "true" ]]
    ;;
esac
EOF

chmod +x "${test_directory}/bin/aws"
export PATH="${test_directory}/bin:${PATH}"
export AWS_CALL_LOG="${test_directory}/aws-calls.log"
export CAPTURED_TRUST_POLICY="${test_directory}/trust-policy.json"
export CAPTURED_PERMISSION_POLICY="${test_directory}/permission-policy.json"

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
OIDC_EXISTS=false ROLE_EXISTS=false "${script_path}" \
  --region af-south-1 \
  --bucket axis-tfstate-2026 \
  --state-key axis/dev/terraform.tfstate \
  --table axis-tflocks-dev > "${test_directory}/create-output.log"

assert_called "iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com --client-id-list sts.amazonaws.com"
assert_called "iam create-role --role-name axis-dev-github-terraform"
assert_called "iam put-role-policy --role-name axis-dev-github-terraform --policy-name axis-dev-terraform-deployment"

python3 - "${CAPTURED_TRUST_POLICY}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as policy_file:
    policy = json.load(policy_file)

condition = policy["Statement"][0]["Condition"]["StringEquals"]
assert condition["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
assert condition["token.actions.githubusercontent.com:sub"] == (
    "repo:cloudenochcsis@155973884/"
    "merchant-platform-infra@1352702887:ref:refs/heads/main"
)
PY

python3 - "${CAPTURED_PERMISSION_POLICY}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as policy_file:
    policy = json.load(policy_file)

actions = set()
resources = set()
for statement in policy["Statement"]:
    statement_actions = statement.get("Action", [])
    statement_resources = statement.get("Resource", [])
    if isinstance(statement_actions, str):
        statement_actions = [statement_actions]
    if isinstance(statement_resources, str):
        statement_resources = [statement_resources]
    actions.update(statement_actions)
    resources.update(statement_resources)

assert "arn:aws:s3:::axis-tfstate-2026" in resources
assert "arn:aws:s3:::axis-tfstate-2026/axis/dev/terraform.tfstate" in resources
assert "arn:aws:s3:::axis-tfstate-2026/axis/dev/terraform.tfstate.tflock" in resources
assert "arn:aws:s3:::axis-tfstate-2026/axis/dev/*" not in resources
assert "arn:aws:dynamodb:af-south-1:163120011463:table/axis-tflocks-dev" in resources
assert "arn:aws:iam::163120011463:role/axis-dev-ecs-execution" in resources
assert "arn:aws:iam::163120011463:role/axis-dev-ecs-task" in resources
assert "arn:aws:iam::163120011463:role/axis-dev-github-terraform" not in resources
assert all(not action.endswith(":*") for action in actions)
assert "iam:PassRole" in actions
assert "acm:DescribeCertificate" in actions
assert "acm:RequestCertificate" not in actions
PY

grep -F 'AWS_REGION=af-south-1' "${test_directory}/create-output.log" > /dev/null
grep -F 'AWS_ROLE_ARN=arn:aws:iam::163120011463:role/axis-dev-github-terraform' "${test_directory}/create-output.log" > /dev/null
grep -F 'TF_BACKEND_BUCKET=axis-tfstate-2026' "${test_directory}/create-output.log" > /dev/null
grep -F 'TF_BACKEND_KEY=axis/dev/terraform.tfstate' "${test_directory}/create-output.log" > /dev/null
grep -F 'TF_BACKEND_DYNAMODB_TABLE=axis-tflocks-dev' "${test_directory}/create-output.log" > /dev/null

: > "${AWS_CALL_LOG}"
OIDC_EXISTS=true ROLE_EXISTS=true "${script_path}" \
  --region af-south-1 \
  --bucket axis-tfstate-2026 \
  --state-key axis/dev/terraform.tfstate \
  --table axis-tflocks-dev > "${test_directory}/rerun-output.log"

assert_not_called "iam create-open-id-connect-provider"
assert_not_called "iam create-role"
assert_called "iam update-assume-role-policy --role-name axis-dev-github-terraform"

printf 'GitHub OIDC bootstrap tests passed\n'
