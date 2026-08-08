# Providers Within Modules

> **Source:** [developer.hashicorp.com/terraform/language/modules/develop/providers](https://developer.hashicorp.com/terraform/language/modules/develop/providers)
> **Added:** 2026-08-08
> **Source updated:** undated language reference; captured 2026-08-08 against v1.15.x (latest)
> **Tags:** modules, providers, provider-inheritance, configuration_aliases, providers-argument, required_providers, legacy-modules, destroy-ordering
> **Type:** documentation

*Developer › Terraform › Configuration Language › Modules › Develop modules › Providers within modules · v1.15.x*

The page [[tf-meta-providers]] defers all module-author guidance to, and the canonical source for a rule that has now come up in five separate notes. The `providers` meta-argument mechanics are in [[tf-meta-providers]]; what is captured here is **why the rule exists**, what is and is not inherited, and the one limitation that no amount of `providers` wiring can work around.

## The frame

> Each resource in the configuration must be associated with one provider configuration. Provider configurations, **unlike most other concepts in Terraform, are global to an entire Terraform configuration and can be shared across module boundaries.** Provider configurations can be defined **only in a root Terraform module.**

Two ways down the tree: **implicit inheritance** or the explicit **`providers`** argument.

> A module intended to be called by one or more other modules **must not contain any provider blocks.**

!!! note "Why [[tut-no-code-provisioning]] isn't an exception"
    A no-code module declares its providers *inside itself*, which looks like a violation. It isn't: "can be defined only in a root Terraform module", and HCP launches the no-code module **as** the root module of a generated workspace. The rule is about *position in the tree*, not about file layout — a module nobody calls with a `module` block is a root module.

## The real reason — and it is not the meta-argument conflict

Every tutorial in the Modules collection cites `count`/`for_each`/`depends_on` as the reason ([[tut-module-create]], [[tut-for-each]], [[tut-no-code-provisioning]]). This page gives that as the *later, mechanical* enforcement. The underlying reason is a lifecycle one:

> Provider configurations are used for **all** operations on associated resources, including **destroying** remote objects and refreshing state. Terraform retains, as part of its state, a reference to the provider configuration that was most recently used to apply changes to each resource. When a `resource` block is removed from the configuration, **this record in the state will be used to locate the appropriate configuration** because the resource's `provider` argument (if any) will no longer be present in the configuration.

> As a consequence, you must ensure that **all resources that belong to a particular provider configuration are destroyed before you can remove that provider configuration's block** from your configuration. If Terraform finds a resource instance tracked in the state whose provider configuration block is no longer available then it will **return an error during planning**, prompting you to reintroduce the provider configuration.

!!! danger "A provider configuration must outlive every resource it manages"
    That constraint is what a module-with-its-own-provider breaks, spelled out in the Legacy section:

    > because a provider configuration is required to destroy the remote object associated with a resource instance as well as to create or update it, **a provider configuration must always stay present in the overall Terraform configuration for longer than all of the resources it manages.** If a particular module includes both resources and the provider configurations for those resources then removing the module from its caller would violate that constraint: **both the resources and their associated providers would, in effect, be removed simultaneously.**

    So deleting a `module` block that carried its own `provider` would leave orphaned state entries pointing at a configuration that no longer exists — and planning fails until you put it back.

    This also generalizes past modules. **Any** time you delete a `provider` block, check that nothing in state still references it: the plan-time error names the missing configuration and the only fix is to reintroduce it, destroy the resources, then remove both. It is the provider-side twin of the address-is-identity rule in [[tut-move-config]].

## The version history, which explains the shape of the rule

| Version | State of affairs |
|---|---|
| **v0.10 and earlier** | No way to use different provider configurations in different modules, so authors "commonly worked around this by writing `provider` blocks directly inside their modules". |
| **v0.11** | Introduced passing configurations between modules; HashiCorp "explicitly recommended against" provider blocks in child modules. The legacy pattern kept working. |
| **v0.13** | Added `for_each`, `count`, `depends_on` on `module` blocks — "the implementation of those unfortunately conflicted with the support for the legacy pattern". |

v0.13 kept the legacy pattern working *only* for module blocks that use none of the three. The error is quoted verbatim on the page:

```
Error: Module does not support count

  on main.tf line 15, in module "child":
  15:   count = 2

Module "child" cannot be used with count because it contains a nested provider
configuration for "aws", at child/main.tf:2,10-15.

This module can be made compatible with count by changing it to receive all of
its provider configurations from the calling module, by using the "providers"
argument in the calling module block.
```

> To make a module compatible with the new features, you must **remove all of the provider blocks from its definition.**

## What is inherited, and what is not

**Default configurations are inherited.** "For convenience in simple configurations, a child module automatically inherits **default** provider configurations from its parent… We recommend using this approach when a single configuration for each provider is sufficient for an entire configuration."

**Aliased configurations are never inherited.**

> Additional provider configurations (those with the `alias` argument set) are **never inherited automatically** by child modules, and so must always be passed explicitly using the `providers` map.

**Requirements are never inherited.**

> **Note:** Only provider **configurations** are inherited by child modules, **not provider source or version requirements.** Each module must declare its own provider requirements. This is especially important for **non-HashiCorp providers.**

!!! tip "Configurations flow down; requirements don't — and this is the one people get wrong"
    A child module that declares no `required_providers` still *works*, because the configuration it needs was inherited. What it loses is the **source address**, and for a non-HashiCorp provider that means Terraform falls back to assuming `hashicorp/<name>` and fails to find it, or silently resolves a different provider with the same short name.

    The page's own justification is worth keeping: each module declares requirements "so that Terraform can ensure that there is **a single version of the provider that is compatible with all modules** in the configuration, and to specify the **source address that serves as the global (module-agnostic) identifier**". Requirements are per-module inputs to one global resolution ([[provider-requirements]], [[tf-dependency-lock]]).

**The version-constraint rule for shared modules:**

> If you are writing a shared Terraform module, constrain **only the minimum required provider version using a `>=` constraint.** This should specify the minimum version containing the features your module relies on, and thus **allow a user of your module to potentially select a newer provider version** if other features are needed by other parts of their overall configuration.

Same reusable-versus-root split recorded in [[tf-expr-version-constraints]]: a shared module sets a floor, a root module sets a floor and a ceiling.

## `configuration_aliases`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 2.7.0"

      configuration_aliases = [ aws.alternate ]
    }
  }
}
```

Declares an additional configuration *name* the module expects to receive. The caller then supplies it through `providers`. Worked two-region example — root declares `aws.usw1` and `aws.usw2`, the child declares `configuration_aliases = [ aws.src, aws.dst ]`, and the call maps them:

```hcl
module "tunnel" {
  source    = "./tunnel"
  providers = {
    aws.src = aws.usw1
    aws.dst = aws.usw2
  }
}
```

> The keys of the `providers` map are provider configuration names **as expected by the child module**, and the values are the names of corresponding configurations **in the current module**.

## The scoping sentence, confirmed

> Modules implicitly inherit default providers. Setting a `providers` argument within a module block **overrides the default inheritance behavior for that provider.**

This is the corrected, **per-provider** phrasing. [[tf-meta-providers]] still carries the older, broader wording ("cancels the default behavior… the child module only has access to the provider configurations you specify"), which reads as a global inheritance kill switch and is the phrasing Terraform issue [#35781](https://github.com/hashicorp/terraform/issues/35781) was filed against — closed once *this* page was narrowed. So the two reference pages disagree, and this one is right. Evidence already cached at `cache/search/implied-empty-default-provider.md`.

## The limitation `providers` cannot solve

> **Since the association between resources and provider configurations is static, module calls using `for_each` or `count` cannot pass different provider configurations to different instances.** If you need different instances of your module to use different provider configurations then you must use a **separate module block for each distinct set of provider configurations.**

The worked example duplicates the block per region rather than iterating:

```hcl
module "bucket_w1" {
  source    = "./publish_bucket"
  providers = {
    aws.src    = aws.usw1
    google.src = google.usw1
  }
}

module "bucket_w2" {
  source    = "./publish_bucket"
  providers = {
    aws.src    = aws.usw2
    google.src = google.usw2
  }
}
```

!!! tip "This is the explicit statement of what [[tut-for-each]] inferred"
    That tutorial found that moving a `count` resource into a module lets you put `for_each` on the module block — multiplication on two axes — and noted it "buys multiplication but not multi-provider fan-out". Here is the reason in the vendor's own words: the resource-to-provider association is **static**, so one `module` block is one provider set no matter how many instances it has. Multi-region fan-out is copy-paste per region, and that is by design rather than an omission.

    Two escapes exist and neither is the ordinary CLI: **OpenTofu 1.9+** iterates provider configurations with `for_each` ([[ot-provider-for-each]]), and Terraform allows `for_each` on `provider` blocks **only inside a Stack configuration** ([[tf-meta-for-each]], **E2**). So the divergence is about which configuration surface exposes the capability, not about whether it exists.

---
Related: the page [[tf-meta-providers]] defers to, and the source of the rule cited without explanation in [[tut-module-create]], [[tut-for-each]] and [[tut-no-code-provisioning]]. `provider` block and `configuration_aliases` on the receiving side: [[tf-provider-block]]; requirements resolution: [[provider-requirements]] and [[tf-dependency-lock]]; the shared-module `>=` rule: [[tf-expr-version-constraints]]. Provider iteration where it does exist: [[ot-provider-for-each]] and [[tf-meta-for-each]]. Topic page: [[providers]], [[modules]]. Feeds learning-path **I8** (provider configuration in depth) as its module-boundary reference, **I5** (authoring modules), and sharpens **I1**'s `for_each`-on-modules note.
