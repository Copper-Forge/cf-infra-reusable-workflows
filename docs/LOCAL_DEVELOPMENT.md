# Local Development

## Prerequisites

- Git
- A local editor that can edit YAML and Markdown
- Optional: `actionlint` for workflow syntax checks
- Optional: access to a consuming repository for end-to-end workflow validation

## Local Setup

1. Clone this repository.
2. Open `AGENTS.md` and read the public-repository rules before editing.
3. Inspect the workflow you plan to change under `.github/workflows/`.
4. Make the documentation or workflow change.
5. Review the diff for secrets, account IDs, static role ARNs, and unintended caller-specific values.

## How to Validate

- Run `actionlint .github/workflows/*.yml` if `actionlint` is installed.
- Confirm each changed workflow still uses `on.workflow_call`.
- Confirm reusable workflow inputs in docs match the YAML.
- Confirm external action versions in docs match the YAML.
- Confirm docs do not describe files that live only in consuming repositories.

## Workflow-Specific Checks

- Terraform baseline:
  - Required inputs are `state-key-prefix`, `stack-repository`, `stack-name`, and `environment-slug`.
  - Optional inputs are `working-directory`, `aws-region`, `tf_version`, and `action`.
  - Caller secret requirement is `SHARED_SERVICES_OIDC_ARN`.
  - The workflow should download shared tfvars first, stack tfvars second, then run Terraform with the shared file before the stack file.
  - Changing `working-directory` must not require a new `state-key-prefix`.
- SAM Node.js:
  - Required inputs are `config-env`, `stack-name`, and `environment-slug`.
  - Optional inputs are `aws-region`, `node-version`, `sam-directory`, `config-file`, and `template-file`.
  - Caller variable requirements are `BASELINE_ACCOUNT_MAPPINGS` and `OIDC_ROLE_NAME`.
  - The workflow expects caller repository files needed by `npm ci`, `npm run build`, and SAM CLI commands.
- SAM Python:
  - Required inputs are `config-env`, `stack-name`, and `environment-slug`.
  - Optional inputs are `aws-region`, `sam-directory`, `config-file`, and `template-file`.
  - Caller variable requirements are `BASELINE_ACCOUNT_MAPPINGS` and `OIDC_ROLE_NAME`.
  - The workflow expects caller repository files needed by `uv sync` and SAM CLI commands.

## How to Run

- This repository does not have a standalone local runtime.
- The workflows run only when a consuming repository calls them with `workflow_call`.
- Use `actionlint` locally for syntax validation.
- Use a consuming repository workflow run when you need to observe full behavior with AWS, Terraform, SAM, or caller-owned source files.

## Interpreting Results

- `actionlint` passes:
  - The workflow YAML syntax and many GitHub Actions expressions are valid.
- GitHub Actions reaches Terraform or SAM command steps:
  - The caller successfully invoked the reusable workflow and provided enough context for setup.
- Terraform fails at `Validate tfvars file`:
  - The docs are stale. The current workflow downloads tfvars from S3 before Terraform setup.
- Terraform fails at `Download tfvars from S3`:
  - The shared or stack S3 object is missing, the caller supplied the wrong `stack-repository` or `stack-name`, or the assumed role lacks `s3:GetObject`.
- Terraform fails after downloading tfvars:
  - Review the logged S3 URIs, verify the caller preserved the existing `state-key-prefix`, and confirm the caller repository uploaded the expected shared and stack files.
- SAM fails before `SAM validate`:
  - Runtime dependencies, caller variables, or AWS credential configuration need review.
- SAM fails during validate, build, or deploy:
  - The caller-owned SAM template, samconfig, application build, or AWS permissions need review.

## Testing Notes

- There are no repository-defined unit or integration tests.
- Treat a consuming repository workflow run as integration validation for these reusable workflows.
