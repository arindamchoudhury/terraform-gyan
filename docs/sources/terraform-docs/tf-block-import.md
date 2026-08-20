# `import` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/import](https://developer.hashicorp.com/terraform/language/block/import)
> **Added:** 2026-08-20
> **Source updated:** undated block reference; captured 2026-08-20 against v1.15.x (latest)
> **Tags:** import-block, id, identity, for_each, provider-alias, plan-time-known, modules, block-reference
> **Type:** documentation

*Developer › Terraform › Configuration Language › Import resources › `import` block reference · v1.15.x*

The page [[tf-import]], [[tf-import-single]] and [[tf-import-generate]] all defer to, and the only one that answers what the arguments actually accept.

## Configuration model

| Argument | Type | Notes |
|---|---|---|
| **`to`** | address | **required** |
| **`id`** | string | |
| **`identity`** | map | **mutually exclusive with `id`** |
| **`for_each`** | map or set of strings | |
| **`provider`** | reference | |

`to` is the only required argument, which is worth stating plainly: an `import` block with a `to` and neither `id` nor `identity` is structurally legal per this table, though it could not identify anything.

## `id` — the answer to the question the other pages dodge

> You must specify a **string or an expression that evaluates to a string**. **The ID must be known during the plan operation.**

That settles it. Expressions **are** allowed — `each.value`, a variable, a local — and the single constraint is **plan-time knownness**. So a reference to another managed resource's attribute is out, because that value is `(known after apply)`, while anything derived from variables, locals or `for_each` keys is in.

!!! tip "This is the same plan-time-known rule as `count`/`for_each`, met in a third place"
    The path already tracks it as the constraint on `count`/`for_each` arguments (TID §4.8.4, captured from the plan side in [[05-terraform-plan]] §5.7, and hit again by OpenTofu's `issensitive()` change). It is not a rule about loops — it is a rule about **anything Terraform must resolve before it can build the plan**, and importing is squarely in that category: Terraform has to ask the provider about the object while planning.

    Practical read: you can drive imports from a `locals` map of IDs you paste in, or from `var`. You cannot import an object whose ID another resource in the same configuration is about to produce.

And the standing per-resource rule, said for the fourth time across this section:

> The value of the `id` argument depends on the type of resource you are importing. You can only import resources that are supported by the provider. **Refer to the provider documentation.**

## `identity` — an object, not a string

> The `identity` argument is an **object of key-value pairs** that uniquely identify a resource. The keys and values are specific to the resource type and provider.

```hcl
import {
  identity = {
    <KEY> = <VALUE>
  }
}
```

Mutually exclusive with `id`, stated on both arguments. [[tf-import]] supplies the reason to prefer it — an AWS `s3_bucket` is identified by `account_id` + `bucket` + `region`, because the name alone is not unique.

Note the page contradicts itself on the type: the configuration model says **map**, the prose says **object of key-value pairs**, and the Summary box under the argument says *"Data type: String"*. The first two agree and the third is wrong.

## `for_each` — with the examples that make it worth using

The path had this as a one-line "1.7 added `for_each` to import blocks". The reference shows what that buys.

**Over a map**, with `each.key` indexing the destination and `each.value` supplying the ID:

```hcl
locals {
  buckets = {
    "staging" = "bucket1"
    "uat"     = "bucket2"
    "prod"    = "bucket3"
  }
}

import {
  for_each = local.buckets
  to       = aws_s3_bucket.this[each.key]
  id       = each.value
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets
}
```

One block adopts three buckets. The destination resource's own `for_each` is driven by the **same** local, which is what keeps the addresses lined up.

**Over a list of objects, importing into module instances** — the example worth keeping, because it reaches two levels of key at once:

```hcl
locals {
  buckets = [
    { group = "one", key = "bucket1", id = "one_1" },
    { group = "one", key = "bucket2", id = "one_2" },
    { group = "two", key = "bucket1", id = "two_1" },
    { group = "two", key = "bucket2", id = "two_2" },
  ]
}

import {
  for_each = local.buckets
  id       = each.value.id
  to       = module.group[each.value.group].aws_s3_bucket.this[each.value.key]
}
```

`module.group[…].aws_s3_bucket.this[…]` — a module instance key *and* a resource instance key in one address, both computed from the loop. This is the shape a real adoption of an existing estate takes, and it is considerably beyond anything in the tutorials.

`for_each` accepts a **map or a set of strings**, same as on a resource.

## `provider` — an alias, unquoted

```hcl
provider "aws" {
  region = "us-west-1"
}

provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

import {
  id       = "i-096fba6d03d36d262"
  to       = aws_instance.web
  provider = aws.east
}

resource "aws_instance" "web" {
  # ...
}
```

The configuration model types it as a **reference**, and the example writes it unquoted as `aws.east`. (The Specification section's snippet shows `provider = "<provider>.<alias>"` **in quotes**, which would be a string rather than a reference. The example is the one to copy.)

Both `for_each` and `provider` are described as **meta-arguments** — *"built into the Terraform language"* — rather than as import-specific arguments, which is why they behave as they do elsewhere.

## Where to put the block

A placement recommendation none of the other pages give:

> You can add an `import` block to any Terraform configuration file, but we recommend either **creating an `imports.tf` file for all import configurations** or **placing each import block beside the destination resource block**.

Two coherent conventions rather than one rule. The first suits a bulk adoption you intend to delete afterwards; the second suits keeping the block permanently as the provenance record [[tf-import-single]] recommends, since the origin stays next to the thing it explains.

## Defects

!!! warning "Six problems on one reference page"
    - **The single-resource example does not parse.** Its destination block is written `resource "aws_s3_bucket" "this" {` then `}` then `  # …` then a second `}` — an extra closing brace with a stray comment between.
    - **`identity`'s Summary box says *"Data type: String"***, contradicting both the configuration model (map) and the prose (object of key-value pairs).
    - **The "Complete configuration" block declares `for_each` twice**, once as a map and once as a list. Intended to show the alternatives — the inline comments say so — but invalid HCL as printed.
    - **That same block is introduced as *"The following **module** block includes all built-in arguments"***. It is an `import` block.
    - **`provider = "<provider>.<alias>"` is quoted in the Specification** and unquoted in the example. A reference, not a string.
    - **`region = "us-westl-1"`** in the provider-alias example — no such region; `us-west-1`.

    The *content* is sound and is the authoritative answer for `id` and `identity`; it is the samples that have not been proofread.

---
Related: [[tf-import]] — the hub, and why `identity` exists. · [[tf-import-single]] — the hand-written workflow, where `to`'s instance keys and module prefix are shown. · [[tf-import-generate]] — the generation flag, still experimental. · [[tf-import-bulk]] — the query-driven route, where the IDs come from a `list` block instead of a `locals` map. · [[05-terraform-plan]] — the plan-time-known rule that `id` is subject to. · [[tf-state-remove]] — `removed`'s `from`, which takes no instance key where `to` does. · [[feature-history]] — `for_each` on `import` (1.7), `identity` (1.12).
