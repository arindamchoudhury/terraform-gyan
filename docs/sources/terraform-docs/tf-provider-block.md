# `provider` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/provider](https://developer.hashicorp.com/terraform/language/block/provider)
> **Added:** 2026-07-10
> **Source updated:** undated language reference; captured 2026-07-10 against v1.15.x (latest)
> **Tags:** providers, provider-block, alias, configuration_aliases, default-configuration, modules, deprecated-version
> **Type:** documentation

*Developer › Terraform › Configuration Language › Blocks › `provider` block reference · v1.15.x*

!!! info "Hands-on"
    Try the [Perform CRUD Operations with Providers](https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework) tutorial.

The block-reference page for `provider`. This is the *configure* half of the declare-vs-configure split — [[provider-requirements]] covers the *declare* half (`required_providers`), and [[tf-providers]] is the hub over both. Three earlier notes deferred alias and `configuration_aliases` detail to "the separate Provider Configuration page"; this page is where that detail now lives.

## Background

A `provider` block configures a **named provider**: a plugin letting Terraform interact with cloud providers, SaaS providers, and other APIs. Providers are distributed separately from Terraform via the public registry, each with its own release cadence, documentation, and versions. HCP Terraform users can share providers within an organization via a **private registry**. Anyone can develop a provider, use it locally, or publish it.

!!! warning "Root module only"
    Define provider configurations **in the root module**. Child modules receive their provider configurations from their parent. The docs "strongly recommend against" `provider` blocks in child modules. Confirms what [[providers]] records from TID Ch2.

## Configuration model

```hcl
provider "<PROVIDER_NAME>" {
  <PROVIDER_ARGUMENTS>

  alias   = "<ALIAS_NAME>"
  version = "<VERSION_CONSTRAINT>"  # Deprecated
}
```

`alias` and `version` are both optional, and **you cannot use both in the same block**.

| Argument | Description | Type | Required? |
|---|---|---|---|
| `provider "<NAME>"` | The provider's **local name**, as an inline block label | — | Yes |
| Provider-specific arguments | Whatever the provider developer defined | Various | Varies by provider |
| `alias` | Unique identifier for one of several configurations of the same provider | String | Optional |
| `version` | Version constraint. **Deprecated** | String | Optional |

## Provider-specific arguments

The block body holds arguments **defined by the provider itself**. A provider's registry page lists them, versioned per release. See [[aws-provider]] and [[google-provider]] for two real argument sets.

Three rules govern them:

1. **An unconfigured provider still exists.** If you don't write a `provider` block, Terraform assumes and creates an **empty default configuration**. If the provider has required arguments, Terraform errors — it cannot build the provider without them.

2. **Expressions are allowed, but only over values known before apply.** You may reference input variables and arguments you specify directly. You may **not** reference computed resource attributes such as `google.web.public_ip`. Consistent with the meta-argument "plan-time-known values" rule in the glossary.

3. **Prefer environment variables for credentials.** Many providers support shell environment variables or other alternate sources, which keeps credentials out of version-controlled configuration. The provider's own docs say which arguments support which assignment methods.

## `alias`

`alias` defines **multiple configurations for the same provider**, so individual resources, data sources, and modules can pick which one to use.

```hcl
provider "exampleName" {
  region = "us-east-1"
}

provider "exampleName" {
  alias  = "west"
  region = "us-west-1"
}
```

Reference an alias as `<PROVIDER_NAME>.<ALIAS>` in the `provider` argument of `resource`, `data`, and `module` blocks.

**Which configuration is the default.** If several aliases exist, the `provider` block **without** an `alias` argument is the default for that provider. Resources, data sources, and modules that omit the `provider` meta-argument use the default configuration matching their resource-type name.

## `version` (deprecated)

The `version` argument inside a `provider` block is **deprecated and will be removed in a future Terraform version**. Declare version constraints in the `terraform` block's `required_providers` instead. See [[provider-requirements]].

## Examples

### Basic provider configuration

Declaration and configuration are two different blocks in two different files.

`terraform.tf`

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}
```

`main.tf`

```hcl
provider "google" {
  project = "acme-app"
  region  = "us-central1"
}
```

### Multiple provider configurations

Default targets `us-east-1`; the aliased one targets `us-west-2`. Resources beginning with `aws_` use the default unless they supply `provider`.

```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}
```

### Select an alternate provider configuration

```hcl
resource "aws_instance" "foo" {
  provider = aws.west
  # …
}

resource "aws_instance" "bar" {
   # …
}
```

`foo` uses `aws.west`. `bar` uses the default `aws` configuration.

### Provider without a default configuration

!!! warning "All-aliased providers get an *implied empty* default"
    If **every** `provider` block for a provider carries an `alias`, Terraform creates an **implied empty default configuration**. Any resource omitting the `provider` meta-argument silently uses that empty configuration — and if the provider requires arguments, Terraform errors because the default is not properly configured.

```hcl
provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

resource "aws_s3_bucket" "default_provider" {
  bucket = "uses-implied-empty-config"
}
```

The bucket does not specify `provider`, so it uses the implied empty default — not `east`, not `west`. This is a quiet trap: adding an `alias` to your only `provider` block changes the meaning of every resource that didn't ask for one.

#### Can you stop Terraform creating it?

> ❓ Beyond this page. Verified 2026-07-10 against [Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers) and [terraform#35781](https://github.com/hashicorp/terraform/issues/35781); cached at `cache/search/implied-empty-default-provider.md`.

**No.** No flag, argument, or setting suppresses it. Terraform assumes an empty default configuration for any provider that is not explicitly configured, unconditionally.

But the empty default is **lazy**. This page raises the error only "when resources default to the empty configuration" — not when it is created. An implied empty default that nothing binds to is inert. The lever is **binding**, not creation. Two ways to pull it:

1. **Supply a real default.** Keep one unaliased `provider` block alongside the aliased ones. The default configuration still exists; it is yours rather than empty. This is what the docs prescribe.

2. **Name a provider on every block.** If every `resource`, `data`, and `module` sets `provider = aws.west`, nothing reaches for the default and it is never evaluated. Fragile — the next resource added without a `provider` argument silently regresses to the empty default, and it surfaces at apply.

!!! warning "`providers = {}` does not disable inheritance"
    A child module inherits only the **default** configuration; aliased configurations are never inherited and must be passed via `providers`. Passing an explicit `providers` map does **not** cut off the default. Terraform issue [#35781](https://github.com/hashicorp/terraform/issues/35781) (closed) showed that passing only `aws.other` left the unaliased `aws` working implicitly inside the module. The docs once claimed the `providers` argument "overrides all of the default inheritance behavior"; they now say it overrides it **for that provider** — per-provider, not global.

### Pass provider configurations to a child module

A root-module `provider` configuration is **implicitly passed** to child modules, so all modules use the same configuration.

`main.tf`

```hcl
provider "aws" {
  region = "us-west-2"
}

module "vpc" {
  source = "./modules/vpc"
}
```

`modules/vpc/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Main VPC"
  }
}
```

`aws_vpc.main` inherits the root's configuration and is created in `us-west-2`.

!!! note "Configuration inherits; source and version do not"
    Child modules **do not inherit provider `source` or `version` requirements**. Each child module must declare its own `required_providers`. Only the *configuration* flows down.

### Using an alternate provider configuration in a child module

To use an aliased configuration inside a child module, the child must declare the alias with **`configuration_aliases`** in its `required_providers`.

`main.tf` (root)

```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"
}

module "web-server" {
  source = "./modules/web-server"
  providers = {
    aws.west = aws.west
  }
}
```

`modules/web-server/main.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"

      configuration_aliases = [aws.west]
    }
  }
}

data "aws_ami" "amazon_linux" {
  provider = aws.west

  #...
}
```

Without the `configuration_aliases` declaration, Terraform raises an error when the module references `aws.west`. It is the explicit contract behind the `providers = { … }` argument on the `module` block — the learning path's I8 framing, now sourced.

### Provider configuration with expressions

```hcl
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-west-2"
}

locals {
  common_tags = {
    Environment = "production"
    Project     = "web-app"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
```

### Provider configuration without arguments

```hcl
provider "random" { }
```

An empty configuration for the `random` provider. You can omit the block entirely if there is nothing provider-specific to configure — the empty default is assumed either way.

---
Related: [[provider-requirements]] — the declare half (`required_providers`, `source`, version constraints); the deprecated `version` argument here points there. · [[tf-providers]] — the hub page over both halves. · [[aws-provider]], [[google-provider]] — the concrete provider-specific argument sets this page abstracts over. · [[ot-provider-for-each]] — OpenTofu generalizes `alias` into one provider instance per map element; this page's aliases are the Terraform-CLI baseline it extends. · [[tf-configure-resource]] — where the `provider` meta-argument on a resource is documented from the resource side.
