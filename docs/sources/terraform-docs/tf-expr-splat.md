# Splat Expressions

> **Source:** [developer.hashicorp.com/terraform/language/expressions/splat](https://developer.hashicorp.com/terraform/language/expressions/splat)
> **Added:** 2026-07-15
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-15
> **Tags:** splat, for-expressions, single-value-as-list, dynamic-blocks, legacy-splat, for_each
> **Type:** documentation

A splat expression is a concise shorthand for a common `for` expression. If `var.list` is a list of objects each with an `id` attribute:

```hcl
[for o in var.list : o.id]
```

is equivalent to:

```hcl
var.list[*].id
```

The `[*]` symbol iterates every element of the list on its left and pulls the attribute named on its right from each. Extend the chain to the right to reach into complex types:

```hcl
var.list[*].interfaces[0].name
# equivalent to
[for o in var.list : o.interfaces[0].name]
```

## Splat expressions with maps

Splat applies **only to lists, sets, and tuples**. For a map or object, use a `for` expression instead.

Resources with `for_each` appear as a **map of objects**, so splat does not work on them. (See `for_each` in the resource block reference.)

## Single values as lists

Splat has special behavior on a value that **isn't** a list/set/tuple:

- Non-`null` value → transformed into a **single-element tuple**.
- `null` value → returns an **empty tuple**.

Useful for modules with optional input variables defaulting to `null`. It adapts a scalar-or-null value for Terraform features designed for collections:

```hcl
variable "website_setting" {
  type = object({
    index_document = string
    error_document = string
  })
  default = null
}

resource "aws_s3_bucket" "example" {
  # ...
  dynamic "website" {
    for_each = var.website_setting[*]
    content {
      index_document = website.value.index_document
      error_document = website.value.error_document
    }
  }
}
```

`var.website_setting[*]` yields one block if the caller sets `website`, or zero blocks if it stays `null` — exactly what the `dynamic` block's `for_each` needs.

!!! warning "Use single-value-as-list only in collection contexts"
    This behavior isn't obvious to an unfamiliar reader. Recommendation: use it only in `for_each` arguments and similar spots where the context already implies a collection. Elsewhere the meaning is unclear to future readers.

## Legacy (attribute-only) splat

Older Terraform had a variant using `.*` instead of `[*]`, still supported for backward compatibility but **not recommended** in new configs:

```hcl
var.list.*.interfaces[0].name
# equivalent to
[for o in var.list : o.interfaces][0].name
```

The difference is subtle: with the legacy form, the index `[0]` applies to the **result of the whole iteration**, not to each element. Only the attribute lookups apply per element. This confused users, so always prefer the modern `[*]` form for consistent behavior.

---
Related: [[tf-expr-for]] — splat is shorthand for a `for` expression; maps/objects and `for_each` resources require the full `for` form. [[tf-expressions]] — splat is one expression kind under the Expressions overview. [[tf-expr-references]] — splat operates on referenced collections like resource instance lists.
