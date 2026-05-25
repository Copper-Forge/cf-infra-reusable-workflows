# Troubleshooting

## Local Setup

### `actionlint: command not found`

- **Symptom**: `actionlint` is unavailable when you try to validate `.github/workflows/*.yml`.
- **Cause**: The optional linter is not installed locally.
- **Fix**: Install `actionlint` or use a consuming repository workflow run for validation.

### Reusable workflows do not run from this repository

- **Symptom**: Pushing to this repository does not start Terraform or SAM workflow runs.
- **Cause**: The workflows use `workflow_call`, not direct triggers.
- **Fix**: Invoke the workflow from a consuming repository.

## Terraform Workflow

### `Missing shared tfvars object: ...`

- **Symptom**: The run fails before Terraform setup and prints the shared S3 URI.
- **Cause**: The shared tfvars source was not uploaded to
  `s3://copperforge-terraform-inputs/<environment-slug>/terraform.tfvars`, or
  the role cannot read it.
- **Fix**: Re-run the shared-services upload script in dry-run mode, upload the
  corrected file, verify the S3 object exists, and rerun the workflow.

### `Missing stack tfvars object: ...`

- **Symptom**: The run fails before Terraform setup and prints the stack S3 URI.
- **Cause**: The consuming repository did not upload
  `s3://copperforge-terraform-inputs/<environment-slug>/<stack-repository>/<stack-name>/terraform.tfvars`,
  or the caller passed the wrong `stack-repository` or `stack-name`.
- **Fix**: Re-run the stack upload script, verify the caller workflow inputs, and
  confirm the object exists in S3 before retrying.

### `Configure AWS credentials` fails in Terraform workflow

- **Symptom**: The Terraform workflow fails before checkout or Terraform commands complete.
- **Cause**: `SHARED_SERVICES_OIDC_ARN` is missing, the ARN is wrong, or the role lacks permissions.
- **Fix**: Make sure the caller passes the secret correctly and verify the role trust policy and permissions.

### `terraform init` backend errors

- **Symptom**: `terraform init` fails after credential configuration and checkout.
- **Cause**: The backend key inputs do not match the intended environment, the caller changed the state namespace during a directory move, or the AWS role cannot access the backend.
- **Fix**: Preserve the existing `state-key-prefix`, verify `environment-slug`, and confirm permissions attached to the assumed role.

### `Terraform Apply` never runs

- **Symptom**: The run stops after `Terraform Plan`.
- **Cause**: The `action` input is still set to `plan`.
- **Fix**: Set `action: apply` in the caller workflow when the caller intends to run apply behavior.

## SAM Workflows

### `fromJSON(vars.BASELINE_ACCOUNT_MAPPINGS)[inputs.environment-slug]` resolves incorrectly

- **Symptom**: The SAM workflow fails during `Configure AWS credentials (OIDC)`.
- **Cause**: `BASELINE_ACCOUNT_MAPPINGS` is missing, is not valid JSON, or does not contain the selected `environment-slug`.
- **Fix**: Verify the caller repository or organization variable is valid JSON and includes the environment slug key.

### `vars.OIDC_ROLE_NAME` is empty or wrong

- **Symptom**: The SAM workflow builds an invalid role ARN or cannot assume the target role.
- **Cause**: The caller variable `OIDC_ROLE_NAME` is missing or does not match the IAM role name in the target account.
- **Fix**: Set the caller variable to the IAM role name expected by the target account trust policy.

### `npm ci` fails

- **Symptom**: The Node.js SAM workflow fails during `Install dependencies`.
- **Cause**: The caller repository is missing a compatible `package-lock.json`, or package installation fails.
- **Fix**: Check the caller repository's Node.js dependency files and verify they support `npm ci`.

### `npm run build` fails

- **Symptom**: The Node.js SAM workflow fails during `Build`.
- **Cause**: The caller repository does not define a `build` script, or the build script fails.
- **Fix**: Add or fix the caller repository's `build` script and required source files.

### `uv sync` fails

- **Symptom**: The Python SAM workflow fails during `Install dependencies`.
- **Cause**: The caller repository does not contain dependency files compatible with `uv sync`, or dependency resolution fails.
- **Fix**: Check the caller repository's Python dependency files and lock state.

### `SAM validate` cannot find config or template files

- **Symptom**: The workflow fails with a SAM CLI message about a missing config file or template file.
- **Cause**: `sam-directory`, `config-file`, or `template-file` does not match the caller repository layout.
- **Fix**: Align those caller inputs with the location of `samconfig.toml` and the SAM template.

### `SAM deploy` reports no changes

- **Symptom**: The run reports an empty changeset but does not fail.
- **Cause**: Both SAM workflows pass `--no-fail-on-empty-changeset`.
- **Fix**: No fix is required if the stack is already up to date.

## Shared Workflow Behavior

### Unexpected environment or target account

- **Symptom**: Logs show the wrong environment slug, state path, or assumed account.
- **Cause**: The caller supplied the wrong `environment-slug`, `state-key-prefix`, `stack-repository`, `stack-name`, or account mapping.
- **Fix**: Correct the caller workflow inputs or variables and rerun.
