# Codebase Context

## Snapshot

- Public repository.
- Workflow-only repository.
- Contains reusable GitHub Actions workflows plus documentation.
- No application source, package manifest, Terraform source, SAM template, or repo-owned tests.

## Top-Level Structure

- `.github/workflows/`
  - Reusable workflow entry points.
  - Every workflow uses `workflow_call`.
- `AGENTS.md`
  - Repository operating rules.
  - Public-repo safety guidance.
  - Workflow contract notes for agents and contributors.
- `README.md`
  - Human-facing overview and caller examples.
- `docs/`
  - `ARCHITECTURE.md` - component map and design notes.
  - `CODEBASE_CONTEXT.md` - dense agent orientation.
  - `LOCAL_DEVELOPMENT.md` - local editing and validation guide.
  - `TROUBLESHOOTING.md` - common issue index.

## Entry Points

- `.github/workflows/terraform-plan-or-apply.yml`
  - Trigger: `workflow_call`
  - Job: `baseline`
  - Purpose: shared Terraform baseline execution.
  - Runner: `ubuntu-latest`
  - External actions:
    - `aws-actions/configure-aws-credentials@v4`
    - `actions/checkout@v4`
    - `hashicorp/setup-terraform@v3`
- `.github/workflows/sam-template-nodejs.yml`
  - Trigger: `workflow_call`
  - Job: `deploy`
  - Purpose: shared Node.js AWS SAM validation, build, and deployment.
  - Runner: `ubuntu-latest`
  - Timeout: 15 minutes
  - External actions:
    - `actions/checkout@v4`
    - `actions/setup-node@v4`
    - `aws-actions/setup-sam@v2`
    - `aws-actions/configure-aws-credentials@v4`
- `.github/workflows/sam-template-python.yml`
  - Trigger: `workflow_call`
  - Job: `deploy`
  - Purpose: shared Python AWS SAM validation, build, and deployment.
  - Runner: `ubuntu-latest`
  - Timeout: 15 minutes
  - External actions:
    - `actions/checkout@v4`
    - `actions/setup-python@v5`
    - `aws-actions/setup-sam@v2`
    - `aws-actions/configure-aws-credentials@v4`
    - `astral-sh/setup-uv@v3`

## Terraform Workflow Contract

- Inputs:
  - `state-key-prefix` - required; used in backend state key.
  - `tfvars-file` - required; validated before Terraform runs.
  - `account-nickname` - required; used in logs and backend key.
  - `working-directory` - optional; default `.`.
  - `aws-region` - optional; default `us-west-2`.
  - `tf_version` - optional; default `1.15.4`.
  - `action` - optional; default `plan`; expected values are `plan` or `apply`.
- Secret:
  - `SHARED_SERVICES_OIDC_ARN` - read directly by the workflow.
- Execution order:
  - Log environment slug.
  - Configure AWS credentials with OIDC.
  - Check out caller repository.
  - Validate `tfvars-file` inside `working-directory`.
  - Install Terraform.
  - Run `terraform init -backend-config="key=<state-key-prefix>/<account-nickname>/terraform.tfstate"`.
  - Run `terraform plan -var-file="<tfvars-file>"` when `action == plan`.
  - Run `terraform apply -auto-approve -var-file="<tfvars-file>"` when `action == apply`.

## SAM Node.js Workflow Contract

- Inputs:
  - `config-env` - required; passed to SAM CLI.
  - `stack-name` - required; used when listing stack outputs.
  - `account-nickname` - required; lookup key into `vars.BASELINE_ACCOUNT_MAPPINGS`.
  - `aws-region` - optional; default `us-west-2`.
  - `node-version` - optional; default `24`.
  - `working-directory` - optional; default `.`; working directory for SAM commands.
  - `config-file` - optional; default `samconfig.toml`.
  - `template-file` - optional; default `template.yaml`.
- Caller variables:
  - `BASELINE_ACCOUNT_MAPPINGS` - JSON object keyed by environment slug.
  - `OIDC_ROLE_NAME` - IAM role name appended to the resolved account ID.
- Execution order:
  - Check out caller repository.
  - Set up Node.js with npm cache.
  - Set up SAM CLI.
  - Configure AWS credentials from caller variables.
  - Run `npm ci`.
  - Run `npm run build`.
  - Run `sam validate`.
  - Run `sam build`.
  - Run `sam deploy --no-confirm-changeset --no-fail-on-empty-changeset`.
  - Run `sam list stack-outputs ... || true`.

## SAM Python Workflow Contract

- Inputs:
  - `config-env` - required; passed to SAM CLI.
  - `stack-name` - required; used when listing stack outputs.
  - `account-nickname` - required; lookup key into `vars.BASELINE_ACCOUNT_MAPPINGS`.
  - `aws-region` - optional; default `us-west-2`.
  - `working-directory` - optional; default `.`; working directory for SAM commands.
  - `config-file` - optional; default `samconfig.toml`.
  - `template-file` - optional; default `template.yaml`.
- Caller variables:
  - `BASELINE_ACCOUNT_MAPPINGS` - JSON object keyed by environment slug.
  - `OIDC_ROLE_NAME` - IAM role name appended to the resolved account ID.
- Execution order:
  - Check out caller repository.
  - Set up Python `3.14`.
  - Set up SAM CLI.
  - Configure AWS credentials from caller variables.
  - Install `uv`.
  - Run `uv sync`.
  - Run `sam validate`.
  - Run `sam build`.
  - Run `sam deploy --no-confirm-changeset --no-fail-on-empty-changeset`.
  - Run `sam list stack-outputs`.

## Naming Conventions

- Workflow files live under `.github/workflows/`.
- Workflow inputs use kebab-case except existing `tf_version`.
- Terraform backend state keys use `<prefix>/<slug>/terraform.tfstate`.
- SAM workflow file names include the runtime: `nodejs` or `python`.
- Caller-owned paths are passed as workflow inputs instead of hardcoded in this repository.

## Validation Pattern

- No repo-owned automated tests exist.
- Syntax validation is local with `actionlint` when available.
- Behavioral validation occurs in consuming repository GitHub Actions runs.
- Documentation changes should be checked against the workflow YAML before finalizing.

## Do Not

- Do not add AWS account IDs, static role ARNs, access keys, or tokens.
- Do not add application source, Terraform source, SAM templates, or dependency manifests to this repo unless the repository purpose changes.
- Do not assume any workflow runs standalone from this repository.
- Do not remove OIDC authentication from shared workflows.
- Do not remove the Terraform tfvars existence check.
- Do not add direct triggers such as `push`, `pull_request`, or `workflow_dispatch` to reusable workflows without revisiting the caller contract.
- Do not document behavior that only exists in consuming repositories as if it lives here.
