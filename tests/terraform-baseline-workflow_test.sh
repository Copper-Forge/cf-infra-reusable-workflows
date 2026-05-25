#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workflow_path="$repo_root/.github/workflows/terraform-baseline.yml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local needle="$1"

  if ! grep -Fq "$needle" "$workflow_path"; then
    fail "expected workflow to contain: $needle"
  fi
}

assert_not_contains() {
  local needle="$1"

  if grep -Fq "$needle" "$workflow_path"; then
    fail "expected workflow to omit: $needle"
  fi
}

assert_var_file_order() {
  local action="$1"
  local first="$2"
  local second="$3"

  local action_line
  action_line="$(grep -F "$action" "$workflow_path" || true)"
  [[ -n "$action_line" ]] || fail "expected to find command containing: $action"

  if [[ "$action_line" != *"$first"* || "$action_line" != *"$second"* ]]; then
    fail "expected $action to include both $first and $second"
  fi

  local trimmed="${action_line#*${first}}"
  [[ "$trimmed" != "$action_line" ]] || fail "expected $action to include $first"
  [[ "$trimmed" == *"$second"* ]] || fail "expected $first to appear before $second in $action"
}

assert_contains "stack-repository:"
assert_contains "stack-name:"
assert_contains "TFVARS_BUCKET: copperforge-terraform-inputs"
assert_contains 'shared_s3_uri="s3://${TFVARS_BUCKET}/${{ inputs.environment-slug }}/terraform.tfvars"'
assert_contains 'stack_s3_uri="s3://${TFVARS_BUCKET}/${{ inputs.environment-slug }}/${{ inputs.stack-repository }}/${{ inputs.stack-name }}/terraform.tfvars"'
assert_contains "Shared tfvars S3 URI:"
assert_contains "Stack tfvars S3 URI:"
assert_contains "Shared tfvars local path:"
assert_contains "Stack tfvars local path:"
assert_contains "Missing shared tfvars object:"
assert_contains "Missing stack tfvars object:"
assert_contains 'grep -Eq '\''(\(404\)|NoSuchKey|Not Found|does not exist)'\'' "${aws_error_log}"'
assert_contains 'Failed to download ${label} tfvars object: ${s3_uri}'
assert_contains "Ensure the tfvars object exists in S3 before rerunning."
assert_contains 'terraform init -backend-config="key=${{ inputs.state-key-prefix }}/${{ inputs.environment-slug }}/terraform.tfstate"'
assert_var_file_order "terraform plan" '-var-file="${TF_SHARED_TFVARS_PATH}"' '-var-file="${TF_STACK_TFVARS_PATH}"'
assert_var_file_order "terraform apply -auto-approve" '-var-file="${TF_SHARED_TFVARS_PATH}"' '-var-file="${TF_STACK_TFVARS_PATH}"'
assert_not_contains "inputs.tfvars-file"

echo "PASS: terraform baseline workflow"
