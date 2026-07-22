# `data` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/data](https://developer.hashicorp.com/terraform/language/block/data)
> **Added:** 2026-07-22
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-22
> **Tags:** data-sources, data-block, meta-arguments, count, for_each, depends_on, provider, lifecycle, precondition, postcondition
> **Type:** documentation

Argument spec behind [[tf-data-sources]] (the how-to). This page is the built-in argument catalog for a `data` block. Source type, provider-specific arguments, and returned attributes all depend on the provider — the reference only covers what Terraform itself adds.

## `data "<TYPE>" "<LABEL>"` — required labels

- **TYPE** — the data source type; provider developers define which exist. Terraform also ships the built-in `terraform_remote_state` (see [[tf-remote-state-data]]).
- **LABEL** — a name for the data source. Reference with `data.<TYPE>.<LABEL>.<ATTRIBUTE>`. Same naming rules as a resource.

## Built-in arguments

Everything below is a **meta-argument** (built into the language, controls *how* Terraform reads the source), not provider-specific. All optional.

| Argument | Purpose | Notes |
|---|---|---|
| provider-specific args | Query constraints | Determined by the provider; see provider docs |
| `count` | Multiple instances by number | **Mutually exclusive with `for_each`**. See [[tf-meta-arguments]] |
| `for_each` | Multiple instances by collection | **Mutually exclusive with `count`**. Accepts a **map or a set of strings** |
| `depends_on` | Explicit upstream dependency | Terraform completes all ops on the upstream resource before reading. See [[tf-meta-depends-on]] |
| `provider` | Use an aliased provider config | `provider = <provider>.<alias>` |
| `lifecycle` | `precondition` / `postcondition` only | No create/update/destroy rules — a data source is read-only |

## Complete configuration skeleton

```hcl
data "<TYPE>" "<LABEL>" {

  <PROVIDER-SPECIFIC ARGUMENTS>

  count = <NUMBER>          # count and for_each are mutually exclusive

  depends_on = [ <RESOURCE.ADDRESS.EXPRESSION> ]

  for_each = {             # or a set of strings
    <KEY> = <VALUE>
  }

  provider = <REFERENCE.TO.ALIAS>

  lifecycle {
    precondition {
      condition     = <EXPRESSION>
      error_message = "<STRING>"
    }
    postcondition {
      condition     = <EXPRESSION>
      error_message = "<STRING>"
    }
  }
}
```

## `lifecycle` — read-only subset

The `data` block's `lifecycle` supports **only** `precondition` and `postcondition` — not `create_before_destroy`, `prevent_destroy`, or `ignore_changes`, which have no meaning for a read.

- `precondition` — must return `true` **before** Terraform reads the source.
- `postcondition` — must return `true` **after** the read.

Both take a `condition` expression and an `error_message` string. See [[tf-conditionals]] for the `self`/`can()` patterns these use.

> The page notes: **only literal values are allowed in the `lifecycle` block** — Terraform processes it before evaluating arbitrary expressions for a run, because `lifecycle` config affects how the dependency graph is constructed and traversed.

> ❓ Doc inconsistency: the "Configuration model" table lists `for_each` as "map or set of strings", and the prose repeats "map or a set of strings" — but the collapsed skeleton also shows a `for_each = [ ... ]` **list** form. A list is not a valid `for_each` type; treat the list snippet as a doc slip. (OpenTofu's docs additionally accept an **object** — see the B7/I1 note in the learning path.)

---
Related: [[tf-data-sources]] — the how-to this page backs; read it first for plan-vs-apply timing. [[tf-block-resource]] — the resource-block sibling reference; `data` is the read-only subset (no `provisioner`, no destroy-side lifecycle). [[tf-meta-arguments]] — full detail on `count`/`for_each`/`provider`/`lifecycle`. [[tf-meta-depends-on]] — `depends_on` on a data block and its apply-time cost.
