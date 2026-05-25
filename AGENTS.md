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
- Avoid introducing new org variables or secrets by name in workflow documentation
- If the current workflow implementation already depends on a named secret, document it only where required for correctness
- This workflow must be generic enough to be forked, adapted, or reused in other organizations
- Keep all org-specific configuration in consuming repositories (not this reusable workflow repo)

### Before Any Commit or Push
- Review all changed files for secrets, credentials, or org-specific references
- Run `git diff` before committing
- Assume anything committed will be visible to the world

## Scope

This file defines mandatory guidance for agents and contributors working in this repository.

## Repository Purpose

This repository defines parameterized, reusable GitHub Actions workflows for CopperForge infrastructure repositories. The workflows extract shared Terraform and AWS SAM execution paths into reusable implementations that consuming repositories call with `workflow_call`.

The current workflow files are:

- `.github/workflows/terraform-baseline.yml` — Performs OIDC-based AWS authentication, validates the selected tfvars file, installs Terraform, and runs `terraform plan` or `terraform apply` based on caller input.
- `.github/workflows/sam-template-nodejs.yml` — Sets up Node.js and AWS SAM CLI, configures OIDC AWS authentication from caller variables, runs Node dependency installation/build, then runs SAM validate/build/deploy commands.
- `.github/workflows/sam-template-python.yml` — Sets up Python, `uv`, and AWS SAM CLI, configures OIDC AWS authentication from caller variables, runs Python dependency sync, then runs SAM validate/build/deploy commands.

The workflows keep environment naming generic through inputs such as `environment-slug`, `state-key-prefix`, `sam-directory`, and SAM config/template paths. Account-specific values stay in consuming repository secrets or variables.

## Workspace Companion Loading

If these companion repositories are open in the same workspace, you can use workspace-relative references in docs and plans:

- ../cf-infra-security
- ../cf-infra-networking
- ../cf-infra-terraform-modules
- ../github-agents-source-of-truth

## Reusable Workflow Contract

### File Location

- `.github/workflows/terraform-baseline.yml`
- `.github/workflows/sam-template-nodejs.yml`
- `.github/workflows/sam-template-python.yml`

### Trigger Type

`workflow_call` — these workflows are invoked by caller workflows in consuming repositories, not triggered directly.

### Terraform Workflow Inputs

These inputs control the workflow behavior. All inputs are passed via the `with:` block in the caller workflow.

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `working-directory` | string | no | `.` | Working directory for Terraform commands. Set to `.` for flat root layout; set to a subdirectory for other layouts (e.g., `stacks/security`). |
| `aws-region` | string | no | `us-west-2` | AWS region used for credential configuration and backend access. |
| `state-key-prefix` | string | **yes** | — | Prefix for the Terraform state key (e.g., `security`, `networking`). Used to construct `<prefix>/<slug>/terraform.tfstate`. |
| `tfvars-file` | string | **yes** | — | Path to the `.tfvars` file for the selected environment (for example `tfvars/dev.tfvars`). |
| `tf_version` | string | no | `1.15.4` | Terraform version to install. Use semantic version strings (e.g., `1.15.4`, `1.16.0`). |
| `action` | string | no | `plan` | Terraform action to perform. Options: `plan`, `apply`. Required because reusable workflows cannot directly read the caller's `workflow_dispatch` inputs. |
| `environment-slug` | string | **yes** | — | Environment identifier used to build the Terraform state key and label the run. |

### Terraform Workflow Secrets

The Terraform workflow currently reads the AWS role ARN from `secrets.SHARED_SERVICES_OIDC_ARN`.

### Terraform Workflow Behavior

The Terraform workflow executes this sequence:

1. **Log the selected environment** — Uses the caller-provided environment slug for traceability.
2. **Configure AWS credentials** — Uses OIDC and `secrets.SHARED_SERVICES_OIDC_ARN`; no long-lived credentials.
3. **Checkout** — Clones the repository.
4. **Validate tfvars input** — Fails early if the specified tfvars file is missing.
5. **Setup Terraform** — Installs the specified Terraform version.
6. **Terraform Init** — Runs `terraform init -backend-config="key=<state-key-prefix>/<environment-slug>/terraform.tfstate"`.
7. **Terraform Plan** — Runs `terraform plan -var-file="<tfvars-file>"` when `action: plan`.
8. **Terraform Apply** — Runs `terraform apply -auto-approve -var-file="<tfvars-file>"` when `action: apply`.

The reusable workflow does not resolve target account IDs. Consuming repositories own target selection and may let Terraform assume into the target account from values defined in their tfvars files.

### SAM Workflow Inputs

These inputs are shared by both SAM workflows unless noted.

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `config-env` | string | **yes** | — | SAM config environment passed to SAM CLI. |
| `stack-name` | string | **yes** | — | CloudFormation stack name used when listing stack outputs. |
| `environment-slug` | string | **yes** | — | Environment identifier used to look up the target account from caller variables. |
| `aws-region` | string | no | `us-west-2` | AWS region used for credential configuration and SAM commands. |
| `sam-directory` | string | no | `.` | Working directory for SAM validate/build/deploy commands. |
| `config-file` | string | no | `samconfig.toml` | SAM config file path passed to SAM CLI. |
| `template-file` | string | no | `template.yaml` | SAM template path passed to SAM CLI. |
| `node-version` | string | no | `24` | Node.js version for `sam-template-nodejs.yml` only. |

### SAM Workflow Variables

The SAM workflows currently read caller variables:

- `vars.BASELINE_ACCOUNT_MAPPINGS` — JSON mapping from `environment-slug` to account ID.
- `vars.OIDC_ROLE_NAME` — Role name used to construct the OIDC role ARN.

### SAM Node.js Workflow Behavior

The Node.js SAM workflow executes this sequence:

1. **Checkout** — Clones the caller repository.
2. **Setup Node.js** — Uses `actions/setup-node@v4` with npm cache.
3. **Setup SAM CLI** — Uses `aws-actions/setup-sam@v2`.
4. **Configure AWS credentials** — Constructs the role ARN from caller variables and uses OIDC.
5. **Install dependencies** — Runs `npm ci`.
6. **Build** — Runs `npm run build`.
7. **SAM validate** — Runs `sam validate` with caller-provided config and template inputs.
8. **SAM build** — Runs `sam build` with the same config and template inputs.
9. **SAM deploy** — Runs `sam deploy --no-confirm-changeset --no-fail-on-empty-changeset`.
10. **Output stack information** — Runs `sam list stack-outputs --stack-name <stack-name> --output json || true`.

### SAM Python Workflow Behavior

The Python SAM workflow executes this sequence:

1. **Checkout** — Clones the caller repository.
2. **Setup Python** — Uses `actions/setup-python@v5` with Python `3.14`.
3. **Setup SAM CLI** — Uses `aws-actions/setup-sam@v2`.
4. **Configure AWS credentials** — Constructs the role ARN from caller variables and uses OIDC.
5. **Install uv** — Uses `astral-sh/setup-uv@v3`.
6. **Install dependencies** — Runs `uv sync`.
7. **SAM validate** — Runs `sam validate` with caller-provided config and template inputs.
8. **SAM build** — Runs `sam build` with the same config and template inputs.
9. **SAM deploy** — Runs `sam deploy --no-confirm-changeset --no-fail-on-empty-changeset`.
10. **Output stack information** — Runs `sam list stack-outputs --stack-name <stack-name> --output json`.

### Permissions

Each workflow requests:

- `id-token: write` — Required for OIDC credential exchange.
- `contents: read` — Required to checkout the repository.

### Error Handling

The workflows include these explicit or surfaced error paths:

- **Missing tfvars file** — Exits with descriptive message before Terraform runs.
- **Missing or invalid OIDC secret** — The AWS credentials step fails before Terraform runs.
- **Missing or invalid SAM caller variables** — The SAM credentials step fails before SAM commands run.
- **Missing Node.js or Python dependency metadata** — Runtime dependency installation fails in the caller repository.
- **Terraform errors** — Propagated to GitHub Actions run logs.
- **SAM CLI errors** — Propagated to GitHub Actions run logs.

## Caller Workflow Pattern

Each consuming repository (cf-infra-security, cf-infra-networking, application repositories, etc.) defines a caller workflow that triggers one of the reusable workflows.

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
    secrets: inherit
    with:
      working-directory: '.'
      state-key-prefix: 'security'
      stack-repository: 'cf-infra-security'
      stack-name: 'security'
      environment-slug: 'dev'
      aws-region: 'us-west-2'
      tf_version: '1.15.4'
      action: plan
```

### Caller Workflow Triggers

Caller workflows define the triggering model that fits their repository. The reusable workflows do not assume branch naming or a particular environment picker shape.

## No-Hardcodes Convention

> **No AWS account IDs, organization-specific role names, or organization-specific variable names in this public workflow repository.**
>
- Account targeting belongs in consuming repositories.
- Terraform role ARNs are supplied through the caller's secret context.
- SAM account mappings and OIDC role names are supplied through caller variables currently named `BASELINE_ACCOUNT_MAPPINGS` and `OIDC_ROLE_NAME`.
- State key paths are constructed dynamically from the `state-key-prefix` and environment slug.
- When adding a new account, update the consuming repository configuration, tfvars, or caller variables — do not modify these workflows.

This convention ensures that:

1. The workflows are repo-agnostic across infrastructure and application repositories.
2. Account additions do not require workflow changes.
3. All organization-specific information stays in consumer configuration, not workflow logic.

## Module Sourcing Rule

This repository contains reusable workflow YAML only. It does not contain Terraform code, SAM templates, application source, or AWS resources.

If consuming repositories use custom Terraform modules, they must follow the module sourcing rule defined in cf-infra-security/AGENTS.md or cf-infra-networking/AGENTS.md.

## Security Constraints

- CI authentication must use OIDC short-lived credentials only (no long-lived static credentials).
- Do not add secrets or credentials to this repository.
- Consuming organizations must pass any required role ARN, account mapping, role name, and region through reusable workflow secrets, variables, or inputs.

## Workflow Pinning Strategy

Consuming repositories pin to `@main`:

```yaml
uses: Copper-Forge/cf-infra-reusable-workflows/.github/workflows/terraform-baseline.yml@main
```

Use the same pattern for SAM workflows by replacing the workflow file name. At current org scale (few consuming repos), version tags are not needed. If the number of consuming repos grows significantly, consider introducing semver tags (e.g., `@v1.0`, `@v1.1`) and a release process. For now, `@main` is acceptable because breaking changes are rare and all consuming repos are within the same organization.

## Adding a New Account

When adding a new account to the CopperForge infrastructure:

1. Update the consuming repository's tfvars, target-selection configuration, or caller variables.
2. Ensure the consuming repository passes the correct OIDC secret or variables for the selected workflow.
3. Do not modify these workflow files for account-specific configuration — that belongs in consumer repos.

## Related Documents

- README.md
- docs/ARCHITECTURE.md
- docs/CODEBASE_CONTEXT.md
- docs/LOCAL_DEVELOPMENT.md
- docs/TROUBLESHOOTING.md
- ../cf-infra-security/AGENTS.md
- ../cf-infra-networking/AGENTS.md
- ../cf-infra-terraform-modules/AGENTS.md
