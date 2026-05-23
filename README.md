# cf-infra-reusable-workflows

GitHub reusable workflows referenced by other repositories.

`terraform-baseline.yml` is a generic Terraform runner. The caller supplies:

- The AWS role ARN to assume via OIDC.
- The state key prefix and environment slug.
- The exact tfvars file to use.

The workflow does not resolve target account IDs. Consuming repositories own target selection and can let Terraform assume into the target account using values defined in their own tfvars files.
