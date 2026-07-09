# AWS Provider (Registry overview)

> **Source:** [registry.terraform.io/providers/hashicorp/aws/latest/docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
> **Added:** 2026-07-09
> **Source updated:** 2026-07-08 (provider v6.54.0 published)
> **Tags:** aws, provider, registry, authentication, default_tags, credentials
> **Type:** documentation

The landing page for HashiCorp's AWS provider on the Terraform Registry. This is the provider the book's labs pin (`hashicorp/aws`, `~> 6.0`). It manages the lifecycle of AWS resources (EC2, Lambda, EKS, ECS, VPC, S3, RDS, DynamoDB, and more).

## Registry metadata

- **Tier:** Official — maintained internally by the HashiCorp AWS Provider team.
- **Source address:** `hashicorp/aws` (full: `registry.terraform.io/hashicorp/aws`).
- **Latest version:** v6.54.0, published July 8, 2026 (496 versions total).
- **Adoption:** ~6.8B downloads all-time, ~41M/week — Terraform's most-used provider.
- **Surface (current main):** ~1,678 resources, 668 data sources, 153 list resources, 10 ephemeral resources, across ~150 AWS service categories.

!!! info "Version pin"
    The book pins `version = "~> 6.0"`, which floats within the 6.x line — current is 6.54.0. Pinning the major (`~> 6.0`) is the provider's own recommended constraint; it accepts any 6.x but never a breaking 7.0. See [[provider-requirements]].

## Example usage

The canonical minimal configuration (Terraform 0.13+):

```terraform
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}
```

The `required_providers` block belongs to `terraform{}` (which provider + version), and the separate `provider "aws"` block configures it (region, credentials, etc.). Two distinct jobs — declaration vs. configuration.

## Authentication and configuration

The provider resolves credentials from these sources, **in precedence order** (first match wins):

1. **Provider block parameters** — `access_key`, `secret_key`, `token` set directly in the `provider "aws"` block.
2. **Environment variables** — `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`, `AWS_REGION`.
3. **Shared credentials file** — `~/.aws/credentials` (Linux/macOS).
4. **Shared config file** — `~/.aws/config`.
5. **Container credentials** — CodeBuild, ECS with IAM task roles.
6. **Instance profile credentials** — EC2 instances with an IAM instance profile.

!!! danger "Never hard-code credentials"
    The provider docs warn explicitly: hard-coded credentials are not recommended in any Terraform configuration and risk secret leakage if the file is ever committed to public version control. Prefer environment variables, a named profile, or (best) short-lived role credentials. This mirrors the book's own least-privilege stance.

## Key provider arguments

| Argument | Notes |
|---|---|
| `region` | (Optional) AWS region the provider operates in. Also from `AWS_REGION`. |
| `access_key` / `secret_key` | (Optional) Static credentials — avoid; prefer env/profile/role. |
| `token` | (Optional) Session token for temporary credentials. |
| `profile` | (Optional) Named profile from the shared credentials/config files. |
| `assume_role` | (Optional) Configuration block for assuming an IAM role. |
| `default_tags` | (Optional) Tags applied to **every** resource the provider manages. |
| `skip_credentials_validation` | (Optional) Bypass the STS validation call — used by local emulators. |
| `max_retries` | (Optional) Max API retry attempts; default **25**. |

!!! tip "`default_tags` and the emulator"
    `default_tags` is the provider-wide way to stamp tags on all resources without repeating a `tags` block. Note the lab emulators (Floci/LocalStack) often need `skip_credentials_validation` / `skip_requesting_account_id` — `tflocal` sets these for you, which is why the lab `provider` block stays clean. See [[project_localstack_labs]] context in the book's Ch1 lab setup.

---
Related: [[provider-requirements]] — the `required_providers` / source-address / version-constraint mechanics this page instantiates for AWS. · [[tf-aws-create]] — the Get-Started tutorial that first wires up this exact `provider "aws"` block. · [[tf-config-syntax]] — the declaration-vs-configuration (terraform{} vs provider{}) block distinction.
