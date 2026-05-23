# AGENTS.md

## PUBLIC REPOSITORY CRITICAL RULES

⚠️ **This repository is PUBLIC. The following rules are non-negotiable:**

### Never Commit Secrets or Keys
- Do not commit AWS access keys, secret keys, or API tokens
- Do not commit private SSH keys or certificates
- Do not commit GitHub tokens or deploy keys
- Do not commit database passwords or connection strings
- All credentials must be managed via GitHub Secrets or org variables (non-secret only)
- Use `.gitignore` to prevent accidental commits of sensitive files

### Never Reference Organization-Specific Values
- Do not hardcode Copper-Forge org-specific account IDs, role names, or resource names in code examples
- Do not reference org variables or secrets by name in workflow documentation
- This workflow must be generic enough to be forked, adapted, or reused in other organizations
- Keep all org-specific configuration in consuming repositories (not this reusable workflow repo)

### Before Any Commit or Push
- Review all changed files for secrets, credentials, or org-specific references
- Run `git diff` before committing
- Assume anything committed will be visible to the world

## Scope

This file defines mandatory guidance for agents and contributors working in this repository.

## Repository Purpose

This repository defines a parameterized, reusable GitHub Actions workflow for Terraform baseline stacks (security, networking, and future infra repos). The workflow extracts common Terraform execution into a single DRY implementation that all consuming repositories call.

The workflow encapsulates OIDC authentication, Terraform initialization, planning, and applying while leaving organization-specific account targeting in the consuming repositories.

## Workspace Companion Loading

Open this repository in a multi-root workspace with:

- ../cf-infra-security
- ../cf-infra-networking
- ../cf-infra-terraform-modules
- ../github-agents-source-of-truth

Use workspace-relative references in all docs and plans.

## Reusable Workflow Contract

### File Location

`.github/workflows/terraform-baseline.yml`

### Trigger Type

`workflow_call` — this workflow is invoked by caller workflows in consuming repositories, not triggered directly.

### Workflow Inputs

These inputs control the workflow behavior. All inputs are passed via the `with:` block in the caller workflow.

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `working-directory` | string | no | `.` | Working directory for Terraform commands. Set to `.` for flat root layout; set to a subdirectory for other layouts (e.g., `stacks/security`). |
| `aws-role-to-assume` | string | **yes** | — | AWS role ARN to assume via OIDC before running Terraform. This role should provide backend access and any base credentials Terraform needs. |
| `aws-region` | string | no | `us-west-2` | AWS region used for credential configuration and backend access. |
| `state-key-prefix` | string | **yes** | — | Prefix for the Terraform state key (e.g., `security`, `networking`). Used to construct `<prefix>/<slug>/terraform.tfstate`. |
| `tfvars-file` | string | **yes** | — | Path to the `.tfvars` file for the selected environment (for example `tfvars/dev.tfvars`). |
| `tf_version` | string | no | `1.15.4` | Terraform version to install. Use semantic version strings (e.g., `1.15.4`, `1.16.0`). |
| `action` | string | no | `plan` | Terraform action to perform. Options: `plan`, `apply`. Required because reusable workflows cannot directly read the caller's `workflow_dispatch` inputs. |
| `environment-slug` | string | **yes** | — | Environment identifier used to build the Terraform state key and label the run. |

### Workflow Behavior

The workflow executes this sequence:

1. **Log the selected environment** — Uses the caller-provided environment slug for traceability.
2. **Configure AWS credentials** — Uses OIDC to assume the caller-provided role; no long-lived credentials.
3. **Checkout** — Clones the repository.
4. **Validate tfvars input** — Fails early if the specified tfvars file is missing.
5. **Setup Terraform** — Installs the specified Terraform version.
6. **Terraform Init** — Runs `terraform init -backend-config="key=<state-key-prefix>/<environment-slug>/terraform.tfstate"`.
7. **Terraform Plan** — Runs `terraform plan -var-file="<tfvars-file>"` when `action: plan`.
8. **Terraform Apply** — Runs `terraform apply -auto-approve -var-file="<tfvars-file>"` when `action: apply`.

The reusable workflow does not resolve target account IDs. Consuming repositories own target selection and may let Terraform assume into the target account from values defined in their tfvars files.

### Permissions

The workflow requests:

- `id-token: write` — Required for OIDC credential exchange.
- `contents: read` — Required to checkout the repository.

### Error Handling

The workflow includes explicit error checks:

- **Missing tfvars file** — Exits with descriptive message before Terraform runs.
- **Terraform errors** — Propagated to GitHub Actions run logs.

## Caller Workflow Pattern

Each consuming repository (cf-infra-security, cf-infra-networking, etc.) defines a caller workflow that triggers the reusable workflow.

### Example Caller Workflow

```yaml
# .github/workflows/baseline.yml (or networking.yml, etc.)

name: Baseline Stack Workflow

on:
  push:
    branches: ['*']
  workflow_dispatch:
    inputs:
      action:
        description: Terraform action
        type: choice
        required: false
        default: 'plan'
        options:
          - plan
          - apply

jobs:
  baseline:
    uses: Copper-Forge/cf-infra-reusable-workflows/.github/workflows/terraform-baseline.yml@main
    with:
      working-directory: '.'
      aws-role-to-assume: ${{ vars.TERRAFORM_RUNNER_ROLE_ARN }}
      aws-region: 'us-west-2'
      state-key-prefix: 'security'
      tfvars-file: 'tfvars/${{ github.event.inputs.target }}.tfvars'
      tf_version: '1.15.4'
      action: ${{ github.event.inputs.action || 'plan' }}
      environment-slug: ${{ github.event.inputs.target }}
```

### Caller Workflow Triggers

Caller workflows define the triggering model that fits their repository. The reusable workflow does not assume branch naming, account-mapping variables, or a particular environment picker shape.

## No-Hardcodes Convention

> **No AWS account IDs, organization-specific role names, or organization-specific variable names in this public workflow repository.**
>
- Account targeting belongs in consuming repositories.
- Role ARNs are passed in as generic workflow inputs by consuming repositories.
- State key paths are constructed dynamically from the `state-key-prefix` and environment slug.
- When adding a new account, update the consuming repository configuration and tfvars — do not modify this workflow.

This convention ensures that:

1. The workflow is repo-agnostic (works for security, networking, and any future stack).
2. Account additions do not require workflow changes.
3. All organization-specific information stays in consumer configuration, not workflow logic.

## Module Sourcing Rule

This repository contains workflow YAML only. It does not contain Terraform code or AWS resources.

If consuming repositories use custom Terraform modules, they must follow the module sourcing rule defined in cf-infra-security/AGENTS.md or cf-infra-networking/AGENTS.md.

## Security Constraints

- CI authentication must use OIDC short-lived credentials only (no long-lived static credentials).
- Do not add secrets or credentials to this repository.
- Consuming organizations must pass any required role ARN and region through reusable workflow inputs.

## Workflow Pinning Strategy

Consuming repositories pin to `@main`:

```yaml
uses: Copper-Forge/cf-infra-reusable-workflows/.github/workflows/terraform-baseline.yml@main
```

At current org scale (few consuming repos), version tags are not needed. If the number of consuming repos grows significantly, consider introducing semver tags (e.g., `@v1.0`, `@v1.1`) and a release process. For now, `@main` is acceptable because breaking changes are rare and all consuming repos are within the same organization.

## Adding a New Account

When adding a new account to the CopperForge infrastructure:

1. Update the consuming repository's tfvars and target-selection configuration.
2. Ensure the consuming repository passes the correct runner role ARN for backend access.
3. Do not modify this workflow file — all account-specific configuration belongs in consumer repos.

## Related Documents

- ../cf-infra-security/AGENTS.md
- ../cf-infra-networking/AGENTS.md
- ../cf-infra-terraform-modules/AGENTS.md
