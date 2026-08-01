# Provider `for_each` — multiple provider instances (OpenTofu)

> **Source:** [opentofu.org/docs/language/providers/configuration](https://opentofu.org/docs/language/providers/configuration/)
> **Added:** 2026-07-03
> **Source updated:** OpenTofu current docs (feature introduced in **1.9**)
> **Tags:** opentofu, providers, for_each, multi-region, divergence
> **Type:** documentation

OpenTofu-only feature (since 1.9): iterate a provider configuration with `for_each` to get one provider instance per element — e.g. one AWS region per instance — without repeating `provider` blocks. Terraform's open-source CLI has no equivalent.

!!! info "Sharpened 2026-08-01 — Terraform *does* have it, gated behind Stacks"
    [[tf-meta-for-each]]'s **Supported constructs** section lists `provider` under **Stack** configuration blocks. So the capability exists in Terraform, but only inside a Stack configuration; ordinary root and child modules cannot use it.

    The divergence is therefore about the **configuration surface**, not the feature. OpenTofu puts provider iteration in the core language, usable anywhere; Terraform puts it behind a separate configuration type. The sentence above stays true for the CLI language, which is where a reader would look for it.

## The three OpenTofu-defined provider meta-arguments

- `alias` — additional named configurations for the same provider.
- `for_each` — multiple dynamic instances of a provider configuration.
- `version` — deprecated; use `required_providers` instead.

## `for_each` on a provider block

Only an **aliased** (alternate) provider configuration may take `for_each` — the default configuration must have exactly one instance so OpenTofu can select it automatically.

```hcl
variable "aws_regions" {
  type = map(object({
    vpc_cidr_block = string
  }))
}

provider "aws" {
  alias    = "by_region"
  for_each = var.aws_regions
  region   = each.key
}
```

- `for_each` value must be a **map**, **object**, or **set of strings**. The key/attribute name (or the set element itself) becomes the **instance key**.
- The `for_each` expression must be resolvable statically (from variables/locals) — no resource or data-source attributes.

## Selecting an instance from a resource

The provider **configuration reference is static** (so OpenTofu can wire dependencies before evaluating expressions), but the **instance key in brackets is dynamic**:

```hcl
resource "aws_vpc" "private" {
  for_each = {
    for region, config in var.aws_regions : region => config
    if config != null
  }
  provider   = aws.by_region[each.key]
  cidr_block = each.value.vpc_cidr_block
}
```

`aws.by_region["eu-west-1"]` refers to that specific instance. All instances of one resource must bind to instances of the **same** provider config block, but each can pick a different instance.

## The removal gotcha (important)

> ⚠️ A resource's `for_each` must be a **subset** of the provider's `for_each`, never identical.

OpenTofu needs a resource's provider instance to survive **at least one more plan/apply round** after the resource instance is removed, so it can destroy it. If the provider and resource share the same `for_each` collection, removing a key produces `Error: Provider instance not present` — the resource can no longer be destroyed until you re-add the key.

**Fix:** keep the provider on the full set and give the resource a subtracted set:

```hcl
provider "aws" {
  alias    = "by_region"
  for_each = var.aws_active_regions          # superset
  region   = each.key
}

resource "aws_cloudwatch_log_group" "lambda_cloudfront" {
  name     = "/aws/lambda/${each.key}.lambda"
  provider = aws.by_region[each.key]
  for_each = setsubtract(var.aws_active_regions, var.aws_disabled_regions)  # subset
}
```

To retire a region, add it to `aws_disabled_regions`; a single `plan`+`apply` then removes its resources cleanly (the provider instance still exists to do the destroy). A `null` element in a map is the other escape hatch: keeps the provider instance while dropping its resources.

---
Related: OpenTofu divergence feature for the **E3** milestone; contrasts with resource-level `for_each` in [[terraform-intro]]'s workflow. Depends on static evaluation — same constraint as [[ot-early-eval-backend]].
