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

This repository defines a parameterized, reusable GitHub Actions workflow for Terraform baseline stacks (security, networking, and future infra repos). The workflow extracts the branch-per-account CI pattern into a single DRY implementation that all consuming repositories call.

The workflow encapsulates account resolution, OIDC authentication, Terraform initialization, planning, and applying — reducing duplication across multiple infrastructure repositories.

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

Five inputs control the workflow behavior. All inputs are passed via the `with:` block in the caller workflow.

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `working-directory` | string | no | `.` | Working directory for Terraform commands. Set to `.` for flat root layout; set to a subdirectory for other layouts (e.g., `stacks/security`). |
| `state-key-prefix` | string | **yes** | — | Prefix for the Terraform state key (e.g., `security`, `networking`). Used to construct `<prefix>/<slug>/terraform.tfstate`. |
| `tfvars-path` | string | **yes** | — | Path to the directory containing per-account `.tfvars` files (e.g., `tfvars`). Used to construct `<path>/<slug>.tfvars`. |
| `tf_version` | string | no | `1.15.4` | Terraform version to install. Use semantic version strings (e.g., `1.15.4`, `1.16.0`). |
| `action` | string | no | `plan` | Terraform action to perform. Options: `plan`, `apply`. Required because reusable workflows cannot directly read the caller's `workflow_dispatch` inputs. |
| `oidc-role-name` | string | no | `GitHubActionsPushRole` | IAM role name used for OIDC authentication. Set via the `OIDC_ROLE_NAME` GitHub org variable. Consuming organizations may use custom role names. |

### Workflow Behavior

The workflow executes this sequence:

1. **Resolve account slug from branch name** — Strips the `account/` prefix from `GITHUB_REF_NAME` to identify the account.
2. **Resolve account ID** — Looks up the slug in the `BASELINE_ACCOUNT_MAPPINGS` GitHub org variable (JSON map: `{ "<slug>": "<account-id>" }`).
3. **Construct role ARN** — Builds `arn:aws:iam::<account-id>:role/<role-name>` where `<role-name>` is configured via the `OIDC_ROLE_NAME` GitHub org variable (no hardcoded ARNs).
4. **Configure AWS credentials** — Uses OIDC to assume the role; no long-lived credentials.
5. **Checkout** — Clones the repository.
6. **Setup Terraform** — Installs the specified Terraform version.
7. **Terraform Init** — Runs `terraform init -backend-config="key=<state-key-prefix>/<slug>/terraform.tfstate"`.
8. **Terraform Plan** — Runs `terraform plan -var-file="<tfvars-path>/<slug>.tfvars"` on `push` or when `action: plan`.
9. **Terraform Apply** — Runs `terraform apply -auto-approve -var-file="<tfvars-path>/<slug>.tfvars"` when `action: apply` (workflow_dispatch only).

### Permissions

The workflow requests:

- `id-token: write` — Required for OIDC credential exchange.
- `contents: read` — Required to checkout the repository.

### Error Handling

The workflow includes explicit error checks:

- **Missing `BASELINE_ACCOUNT_MAPPINGS`** — Exits with descriptive message.
- **Unknown account slug** — Exits with descriptive message.
- **Missing jq** — Exits with descriptive message.
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
      state-key-prefix: 'security'
      tfvars-path: 'tfvars'
      tf_version: '1.15.4'
      action: ${{ github.event.inputs.action || 'plan' }}
```

### Caller Workflow Triggers

Caller workflows must define:

- `push` trigger on `branches: ['*']` — Auto-triggers plan for all branches with account commits.
- `workflow_dispatch` input `action` with options `plan` and `apply` (default `plan`) — Allows manual apply via GitHub UI.

## Branch-Per-Account CI Model

This workflow implements the branch-per-account pattern across all consuming repositories:

- **Branch naming** — `account/<slug>` for each enrolled AWS account (e.g., `account/dinkapade-dev`, `account/dinkapade-prod`).
- **Push to `account/*`** → Triggers `terraform plan` automatically (preview, no apply).
- **Manual `workflow_dispatch`** → Triggers `terraform apply` (plan-only unless explicitly requested).
- **Account resolution** — Slug is resolved via `BASELINE_ACCOUNT_MAPPINGS` org variable; no hardcoded account IDs in workflow files.

## No-Hardcodes Convention

> **No AWS account IDs, role ARNs, or state key paths in workflow files.**
>
> - Account IDs belong in the `BASELINE_ACCOUNT_MAPPINGS` org variable or in per-account tfvars files.
> - Role ARNs are constructed dynamically from the account ID using the well-known role name convention.
> - State key paths are constructed dynamically from the `state-key-prefix` and account slug.
> - When adding a new account, update the org variable and tfvars — do not modify this workflow.

This convention ensures that:

1. The workflow is repo-agnostic (works for security, networking, and any future stack).
2. Account additions do not require workflow changes.
3. All hardcoded information is in configuration (org variable, tfvars), not workflow logic.

## Module Sourcing Rule

This repository contains workflow YAML only. It does not contain Terraform code or AWS resources.

If consuming repositories use custom Terraform modules, they must follow the module sourcing rule defined in cf-infra-security/AGENTS.md or cf-infra-networking/AGENTS.md.

## Security Constraints

- CI authentication must use OIDC short-lived credentials only (no long-lived static credentials).
- The `BASELINE_ACCOUNT_MAPPINGS` org variable is non-secret (account IDs and slugs are not sensitive).
- The `OIDC_ROLE_NAME` org variable is non-secret (role names are not sensitive).
- Do not add secrets or credentials to this repository.
- Role naming is configurable via `OIDC_ROLE_NAME` to support different organizational conventions. Consuming organizations must set this variable to match their IAM role naming.

## Workflow Pinning Strategy

Consuming repositories pin to `@main`:

```yaml
uses: Copper-Forge/cf-infra-reusable-workflows/.github/workflows/terraform-baseline.yml@main
```

At current org scale (few consuming repos), version tags are not needed. If the number of consuming repos grows significantly, consider introducing semver tags (e.g., `@v1.0`, `@v1.1`) and a release process. For now, `@main` is acceptable because breaking changes are rare and all consuming repos are within the same organization.

## Adding a New Account

When adding a new account to the CopperForge infrastructure:

1. Update `BASELINE_ACCOUNT_MAPPINGS` GitHub org variable with the new account slug and ID.
2. Follow the account enrollment procedures in consuming repositories (documented in their respective AGENTS.md files and docs/ADD_NEW_ACCOUNT.md).
3. Do not modify this workflow file — all account-specific configuration belongs in consumer repos.

## Related Documents

- ../cf-infra-security/AGENTS.md
- ../cf-infra-networking/AGENTS.md
- ../cf-infra-terraform-modules/AGENTS.md
