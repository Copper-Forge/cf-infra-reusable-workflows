# cf-infra-reusable-workflows

Reusable GitHub Actions workflows for CopperForge infrastructure repositories.

## Overview

This repository centralizes shared workflow logic for infrastructure repositories that need a consistent Terraform or AWS SAM execution path.

It currently provides three reusable workflows:

- `.github/workflows/terraform-baseline.yml` - Terraform init, plan, and apply for baseline stacks
- `.github/workflows/sam-template-nodejs.yml` - Node.js SAM application validation, build, and deployment
- `.github/workflows/sam-template-python.yml` - Python SAM application validation, build, and deployment

The repository contains workflow definitions and documentation only. It does not contain application source, Terraform modules, SAM templates, or AWS resources.

## Repository Structure

- `.github/workflows/` - reusable workflows invoked with `workflow_call`
- `AGENTS.md` - repository-specific guidance for contributors and agents
- `docs/` - architecture, local development, troubleshooting, and codebase context

## Prerequisites

- Git
- A GitHub repository that calls one of the reusable workflows
- Optional: `actionlint` for local workflow validation
- For Terraform callers: a caller secret named `SHARED_SERVICES_OIDC_ARN`
- For SAM callers: caller variables named `BASELINE_ACCOUNT_MAPPINGS` and `OIDC_ROLE_NAME`

## Local Setup

1. Clone this repository.
2. Review `AGENTS.md` before editing.
3. Edit workflow YAML under `.github/workflows/` or docs under `docs/`.
4. Run `actionlint .github/workflows/*.yml` if you have it installed.
5. Review the diff for secrets, account IDs, and organization-specific values before committing.

## Usage

Terraform baseline caller job:

```yaml
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

## Terraform Baseline Behavior

The Terraform reusable workflow expects callers to provide:

- `state-key-prefix` for the backend state key namespace
- `stack-repository` for the stack tfvars S3 path
- `stack-name` for the stack tfvars S3 path
- `environment-slug` for both S3 lookup and backend state key construction

The workflow downloads shared tfvars from the shared object key before it downloads
stack tfvars from the stack object key.

At runtime the workflow:

1. Downloads shared tfvars from
   `s3://copperforge-terraform-inputs/<environment-slug>/terraform.tfvars`.
2. Downloads stack tfvars from
   `s3://copperforge-terraform-inputs/<environment-slug>/<stack-repository>/<stack-name>/terraform.tfvars`.
3. Runs Terraform with `-var-file="<shared>" -var-file="<stack>"`, so the shared
   tfvars file is applied first and stack-local values override shared values.

Changing `working-directory` must not create a new backend namespace. Preserve the
existing `state-key-prefix` for a stack even when its Terraform root moves into a
subdirectory such as `networking/` or `security/`.

If either tfvars object is missing, the workflow fails before Terraform starts and
prints the missing S3 URI. Operators should dry-run the upload scripts in the source
repositories, upload the corrected file, verify the S3 object exists, and rerun the
plan. Pre-cleanup rollback is only available before Feature 07 removes tracked
placeholder tfvars files from consuming repositories.

Node.js SAM caller job:

```yaml
jobs:
  app:
    uses: Copper-Forge/cf-infra-reusable-workflows/.github/workflows/sam-template-nodejs.yml@main
    with:
      config-env: dev
      stack-name: example-app-dev
      environment-slug: dev
      sam-directory: infra/sam
      config-file: samconfig.toml
      template-file: template.yaml
```

Python SAM caller job:

```yaml
jobs:
  app:
    uses: Copper-Forge/cf-infra-reusable-workflows/.github/workflows/sam-template-python.yml@main
    with:
      config-env: dev
      stack-name: example-app-dev
      environment-slug: dev
      sam-directory: infra/sam
      config-file: samconfig.toml
      template-file: template.yaml
```

## Related Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Codebase Context](docs/CODEBASE_CONTEXT.md)
- [Local Development](docs/LOCAL_DEVELOPMENT.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
