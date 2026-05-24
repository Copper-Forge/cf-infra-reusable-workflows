# cf-infra-reusable-workflows

Reusable GitHub Actions workflows for CopperForge Terraform baseline stacks.

## Overview

This repository currently contains one reusable workflow, `.github/workflows/terraform-baseline.yml`.

It is invoked from consuming repositories through `workflow_call` and handles:

- OIDC-based AWS authentication
- Terraform setup, init, plan, and apply
- Early validation that the selected tfvars file exists
- Terraform state key construction from `state-key-prefix` and `environment-slug`

The repository does not contain Terraform code or infrastructure resources.

## Repository Structure

- `.github/workflows/terraform-baseline.yml` - reusable Terraform workflow
- `AGENTS.md` - repository-specific guidance for contributors and agents
- `docs/` - architecture, local development, troubleshooting, and codebase context

## Prerequisites

- Git
- A GitHub repository that can call this reusable workflow
- Optional: `actionlint` for local workflow validation

## Local Setup

1. Clone this repository.
2. Review `AGENTS.md` before editing.
3. Edit `.github/workflows/terraform-baseline.yml` or the files in `docs/`.
4. Run `actionlint .github/workflows/terraform-baseline.yml` if you have it installed.

## Usage

Example caller workflow:

```yaml
jobs:
  baseline:
    uses: Copper-Forge/cf-infra-reusable-workflows/.github/workflows/terraform-baseline.yml@main
    secrets: inherit
    with:
      working-directory: '.'
      state-key-prefix: 'security'
      tfvars-file: 'tfvars/dev.tfvars'
      environment-slug: 'dev'
      aws-region: 'us-west-2'
      tf_version: '1.15.4'
      action: plan
```

The reusable workflow currently reads the AWS role ARN from `secrets.SHARED_SERVICES_OIDC_ARN`.

## Related Docs

- [Architecture](docs/ARCHITECTURE.md)
- [Codebase Context](docs/CODEBASE_CONTEXT.md)
- [Local Development](docs/LOCAL_DEVELOPMENT.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
