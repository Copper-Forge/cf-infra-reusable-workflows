# Local Development

## Prerequisites

- Git
- A local editor that can edit YAML
- Optional: `actionlint` for workflow syntax checks
- Optional: access to a consuming repository if you want to validate the workflow end-to-end

## Local Setup

1. Clone this repository.
2. Open `AGENTS.md` and read the repository rules before editing.
3. Inspect `.github/workflows/terraform-baseline.yml`.
4. Make your documentation or workflow change.
5. Review the diff before you consider the change complete.

## How to Validate

- Run `actionlint .github/workflows/terraform-baseline.yml` if `actionlint` is installed.
- Open the workflow in a consuming repository if you want to validate the reusable workflow path.
- Confirm the caller workflow passes the required inputs:
  - `state-key-prefix`
  - `tfvars-file`
  - `environment-slug`
- Confirm the caller provides `SHARED_SERVICES_OIDC_ARN` in its secret context.

## How to Run

- This repository does not have a standalone local runtime.
- The workflow only runs when a consuming repository calls it with `workflow_call`.
- To observe the full behavior, run the reusable workflow from a consuming repository and review the GitHub Actions logs.

## Interpreting Results

- `actionlint` passes:
  - The YAML syntax is valid.
- GitHub Actions run reaches `Validate tfvars file`:
  - The caller is invoking the reusable workflow correctly.
- `tfvars file not found: ...`:
  - The path is wrong or `working-directory` is not what the caller expects.
- `Configure AWS credentials` fails:
  - The secret or role ARN is missing or invalid.
- `Terraform Init` fails:
  - The backend key inputs or AWS permissions need review.

## Testing Notes

- There are no repository-defined unit or integration tests.
- Treat the calling repository's workflow run as the integration test for this repo.
