# Codebase Context

## Snapshot

- Public repository.
- Workflow-only repository.
- One reusable workflow file and one repository guidance file.
- No application source, package manifest, Terraform code, or tests.

## Top-Level Files

- `AGENTS.md`
  - Repository-specific operating rules.
  - Public-repo safety guidance.
  - Workflow contract notes for agents and contributors.
- `README.md`
  - Human-facing overview and usage summary.
- `docs/`
  - Reference docs for architecture, local development, troubleshooting, and agent orientation.
- `.github/workflows/terraform-baseline.yml`
  - The reusable GitHub Actions workflow.

## Entry Point

- `.github/workflows/terraform-baseline.yml`
  - Trigger: `workflow_call`
  - Job name: `baseline`
  - Runner: `ubuntu-latest`
  - Actions:
    - `aws-actions/configure-aws-credentials@v4`
    - `actions/checkout@v4`
    - `hashicorp/setup-terraform@v3`

## Workflow Inputs

- `state-key-prefix`
  - Required.
  - Used in the Terraform backend key path.
- `tfvars-file`
  - Required.
  - Validated before Terraform runs.
- `environment-slug`
  - Required.
  - Used in logs and backend key construction.
- `working-directory`
  - Optional.
  - Defaults to `.`.
  - Applies to tfvars validation and Terraform commands.
- `aws-region`
  - Optional.
  - Defaults to `us-west-2`.
- `tf_version`
  - Optional.
  - Defaults to `1.15.4`.
- `action`
  - Optional.
  - Defaults to `plan`.
  - Controls whether the workflow runs `terraform plan` or `terraform apply`.

## Workflow Secrets

- `SHARED_SERVICES_OIDC_ARN`
  - Read directly by the workflow.
  - Required for the AWS credentials step.

## Execution Order

- Log the selected environment slug.
- Configure AWS credentials with OIDC.
- Check out the repository.
- Validate that the requested tfvars file exists.
- Install the requested Terraform version.
- Run `terraform init` with backend key `"<state-key-prefix>/<environment-slug>/terraform.tfstate"`.
- Run `terraform plan` when `action == plan`.
- Run `terraform apply -auto-approve` when `action == apply`.

## Naming Conventions

- Workflow files live under `.github/workflows/`.
- Inputs use kebab-case.
- Backend state keys use `prefix/slug/terraform.tfstate`.
- The repo is intended to stay generic across consuming infrastructure repos.

## Test and Validation Pattern

- No repo-owned automated tests exist.
- Syntax validation is typically done with `actionlint` if available.
- Behavioral validation happens in a consuming repository's GitHub Actions run.

## Do Not

- Do not add AWS account IDs, role ARNs, or org-specific variable names to docs or workflow logic unless they already exist in the current implementation.
- Do not add a direct `workflow_dispatch` trigger without updating consuming repositories.
- Do not remove the tfvars existence check.
- Do not assume the workflow can run standalone in this repository.
- Do not add Terraform source files here.
