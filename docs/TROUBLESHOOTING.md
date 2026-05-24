# Troubleshooting

## Local Setup

### `actionlint: command not found`

- **Symptom**: `actionlint` is unavailable when you try to validate `.github/workflows/terraform-baseline.yml`.
- **Cause**: The optional linter is not installed locally.
- **Fix**: Install `actionlint` or skip the local lint step and validate in GitHub Actions instead.

### Reusable workflow does not run from this repository

- **Symptom**: Pushing to this repository does not start the Terraform workflow.
- **Cause**: `.github/workflows/terraform-baseline.yml` is a reusable workflow with `workflow_call`, not a direct trigger.
- **Fix**: Call the workflow from a consuming repository.

## Runtime Errors

### `tfvars file not found: ...`

- **Symptom**: The run fails before Terraform starts and prints `tfvars file not found: <path>`.
- **Cause**: The `tfvars-file` path is wrong, or the path is relative to the wrong `working-directory`.
- **Fix**: Update the caller workflow inputs so the file exists from the selected working directory.

### `Configure AWS credentials` fails

- **Symptom**: The `Configure AWS credentials` step fails before Terraform runs.
- **Cause**: `SHARED_SERVICES_OIDC_ARN` is missing, the ARN is wrong, or the role lacks permissions.
- **Fix**: Make sure the caller passes the secret correctly and verify the role and permissions.

### `terraform init` backend errors

- **Symptom**: `terraform init` fails after the credential and checkout steps.
- **Cause**: The backend key inputs do not match the intended environment, or the AWS role cannot access the backend.
- **Fix**: Verify `state-key-prefix`, `environment-slug`, and the permissions attached to the assumed role.

## Workflow Behavior

### `Terraform Apply` never runs

- **Symptom**: The run stops after `Terraform Plan`.
- **Cause**: The `action` input is still set to `plan`.
- **Fix**: Set `action: apply` in the caller workflow when you want to apply changes.

### Unexpected environment or state path

- **Symptom**: The logs show the wrong environment slug or the Terraform state is written under the wrong key prefix.
- **Cause**: The caller supplied the wrong `environment-slug` or `state-key-prefix`.
- **Fix**: Correct the caller workflow inputs and rerun.
