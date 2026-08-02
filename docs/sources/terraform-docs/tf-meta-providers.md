# `providers` reference

> **Source:** [developer.hashicorp.com/terraform/language/meta-arguments/providers](https://developer.hashicorp.com/terraform/language/meta-arguments/providers)
> **Added:** 2026-08-02
> **Source updated:** undated language reference; captured 2026-08-02 against v1.15.x (latest)
> **Tags:** meta-arguments, providers, modules, alias, configuration_aliases, inheritance, stacks
> **Type:** documentation

*Developer › Terraform › Configuration Language › REFERENCE › Meta-arguments › `providers` · v1.15.x*

The reference page for the sixth meta-argument. [[tf-meta-arguments]] summarizes it in three sentences; [[tf-provider-block]] covers the `provider` blocks it selects between and the `configuration_aliases` declaration on the receiving end. This page is the caller's side of that contract, and it is the only one of the three that states the **map semantics** and the **Stacks applicability**.

## Usage

`providers` is an optional meta-argument on a `module` block. It specifies which of the parent module's provider configurations are available inside the child module.

The value is a **map**:

- **Keys** are the provider configuration names used **inside the child module**.
- **Values** are provider configuration names **from the parent module**.

Keys and values are **unquoted references** to provider configurations. A default configuration is referenced by the provider's local name (`aws`). An alternate configuration uses `<PROVIDER>.<ALIAS>` (`aws.usw2`).

The mechanism is a **remap**, not an injection. Inside a child module, a resource either gets a default chosen from its resource type name or names an alternate with its own `provider` argument. When the module is called with a `providers` map, the configuration names used inside the module are rewritten to refer to the parent's configurations.

```hcl
provider "aws" {
  region = "us-west-1"
}

provider "aws" {
  alias  = "usw2"
  region = "us-west-2"
}

module "example" {
  source    = "./example"
  providers = {
    aws = aws.usw2
  }
}
```

AWS resources in the **root** module use the default `aws` configuration (`us-west-1`) where no provider instance is selected. The child module's `aws` is remapped to the `usw2` alias, so every AWS resource it defines lands in `us-west-2`. The child module's code never changes — it still writes plain `aws_*` resources with no `provider` argument.

## Default behavior

`providers` is **optional when the child module does not declare `configuration_aliases`**. Omit it and the child inherits **all of the parent's default provider configurations**. Default configurations are the ones without an `alias` argument.

Supplying a `providers` argument "cancels the default behavior", so that "the child module only has access to the provider configurations you specify."

!!! warning "This page's cancellation claim is stronger than the observed behavior"
    Read literally, the sentence above says any `providers` map cuts off *all* inheritance. That is the wording Terraform issue [#35781](https://github.com/hashicorp/terraform/issues/35781) was filed against and it was **closed after the docs were corrected elsewhere**: passing only `aws.other` still left the unaliased `aws` working implicitly inside the module. [Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers) now scopes the override **to that provider** — per-provider, not global.

    So this reference page still carries the un-narrowed phrasing. Treat the per-provider reading as correct, and treat `providers = {}` as a no-op rather than an inheritance kill switch. Recorded in [[tf-provider-block]] and cached at `cache/search/implied-empty-default-provider.md`.

## When to specify `providers`

Two conditions, per the page:

- Using **different default provider configurations** for a child module.
- Configuring a module that requires **multiple configurations of the same provider**.

### Changing the child's default configuration

Most re-usable modules only use default provider configurations and inherit them automatically. The argument earns its place in configurations that run several configurations of one provider — the page's example is managing resources across multiple regions of one cloud.

The payoff is stated plainly: you accommodate this **without editing the child module**. The module's code always refers to the default provider configuration, and the actual configuration behind that default differs per instance.

## Supported constructs

| Configuration | Blocks |
|---|---|
| Terraform | `module` |
| Stacks | `component`, `removed` |

The Stacks entries are new relative to [[tf-meta-arguments]], whose applicability table lists `module` only.

## Example use cases

### Modules with alternate provider configurations

"In rare cases" a single re-usable module needs **multiple configurations of the same provider**. The page's example is a module configuring connectivity between two networks, which needs both a source and a destination configuration.

Each key in the map is one of the module's own aliases; each value is a root-module configuration.

**AWS**

```hcl
provider "aws" {
  alias  = "usw1"
  region = "us-west-1"
}

provider "aws" {
  alias  = "usw2"
  region = "us-west-2"
}

module "tunnel" {
  source    = "./tunnel"
  providers = {
    aws.src = aws.usw1
    aws.dst = aws.usw2
  }
}
```

**Azure**

```hcl
provider "azurerm" {
  alias = "az1"
  features {}
}

provider "azurerm" {
  alias = "az2"
  features {}
}

module "tunnel" {
  source = "./tunnel"
  providers = {
    azurerm.src = azurerm.az1
    azurerm.dst = azurerm.az2
  }
}
```

**Non-default provider configurations are never automatically inherited**, so a module built this way *always* requires a `providers` argument. The page puts the burden on the module author: the module's documentation should specify every provider configuration name it needs.

That naming is not just documentation. The child has to declare those same aliases in `configuration_aliases` inside its `required_providers`, or Terraform errors when the module references them. See [[tf-provider-block]] for the receiving half.

## Information for module developers

The page defers all module-author guidance to [Providers Within Modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers) — a page in the **Develop modules** sidebar group, not yet captured.

---
Related: [[tf-meta-arguments]] — the index page, whose three-sentence summary this expands; its applicability table omits the Stacks blocks listed here. · [[tf-provider-block]] — the `provider` blocks and `configuration_aliases` on the receiving side, plus the implied-empty-default trap this page never mentions. · [[tf-providers]] — the provider hub over declare and configure. · [[modules]] — the module topic page, which records the `module` block's three meta arguments from TID Ch2–Ch3. · [[ot-provider-for-each]] — OpenTofu passes provider *instances* into modules from a `for_each`, generalizing the fixed alias-to-alias map here.
