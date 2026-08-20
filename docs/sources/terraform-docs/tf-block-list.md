# `list` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/tfquery/list](https://developer.hashicorp.com/terraform/language/block/tfquery/list)
> **Added:** 2026-08-20
> **Source updated:** undated block reference; captured 2026-08-20 against v1.15.x (latest)
> **Tags:** list-block, tfquery-hcl, terraform-query, bulk-import, count, for_each, include_resource, limit, block-reference
> **Type:** documentation

*Developer › Terraform › Configuration Language › `tfquery` blocks › `list` block reference · v1.15.x*

The reference behind [[tf-import-bulk]]'s query workflow. Adds four things that page does not: the file restriction, `count` alongside `for_each`, what `limit` actually does to the connection, and the fact that **one list can reference another's results**.

> You can **only** add `list` blocks to configuration files with **`.tfquery.hcl`** extensions.

A hard restriction, not a convention. The block does not exist in ordinary `.tf` files.

## Configuration model

| Argument | Type | Notes |
|---|---|---|
| **`provider`** | reference | **required** |
| **`count`** | number | mutually exclusive with `for_each` |
| **`for_each`** | map or set of strings | mutually exclusive with `count` |
| **`include_resource`** | boolean | identity-only unless `true` |
| **`limit`** | number | default **100** |
| **`config`** | block | provider-specific arguments |

Two labels, like a `resource` block: the **type** to query, and a **label** that *"must be unique in the current directory."*

## `limit` cuts the connection

The detail worth having, and it is not what "limit" usually means:

> **When the number of results reaches the specified limit, Terraform breaks the connection to the provider and stops reporting results.**

So it is a hard stop mid-stream, not a filter applied to a complete result set. You get the first N the provider happened to return, in whatever order it returned them — not "the 100 most relevant". For an adoption sweep that matters: raising `limit` is how you find out whether you were seeing everything.

> You can specify a **reference value that resolves to a number.** The default value is 100.

## `include_resource` — identities by default

> By default, Terraform returns the **resource identity** in the response, but you can set the `include_resource` argument to `true` so that the provider returns **full resource objects**.

Same as [[tf-import-bulk]] states, with the reason made explicit: identity is all an import needs, so full objects are opt-in. That page adds the cost — *"may affect performance"* — and the requirement that it be `true` before you can reference any *attribute*.

## `count` and `for_each` — the reference adds `count`

[[tf-import-bulk]] mentions meta-arguments only in passing. Both are supported, mutually exclusive, with the usual division of labour:

> The `count` argument is most suitable for creating multiple lists that are **identical or nearly identical**. The `for_each` argument is most suitable for creating multiple lists based on **attributes defined in a map or set**.

```hcl
variable "subnet_ids" {
  type = list(string)
}

list "aws_instance" "server" {
  provider = aws
  count    = length(var.subnet_ids)
}
```

```hcl
list "azurerm_resource_group" "rg" {
  provider = azurerm
  for_each = tomap({
    a_group       = "eastus"
    another_group = "westus2"
  })
}

list "aws_iam_user" "the-accounts" {
  provider = aws
  for_each = toset(["Todd", "James", "Alice", "Dottie"])
}
```

*(The `azurerm` example is printed with `provider = aws` on the page — corrected here. See Defects.)*

So a query can be fanned out the same way a resource can, and `for_each` over a `toset()` of names is the natural shape for sweeping several accounts or regions in one file.

## Alternate provider configuration

```hcl
provider "google" {
  region = "us-central1"
}

provider "google" {
  alias  = "europe"
  region = "europe-west1"
}

list "google_compute_instance" "example" {
  provider = google.europe
  # ...
}
```

Same mechanism as on the `import` block ([[tf-block-import]]), and the same reason: the objects you are looking for may not be visible to the default provider configuration.

## Lists can reference other lists

The capability nothing else captured mentions. Set `include_resource = true` on one list, and a second can read its results:

```hcl
list "aws_instance" "web" {
  provider         = aws
  include_resource = true
}

list "aws_instance" "web-bu" {
  provider = aws

  config {
    # count = list.aws_instance.web.data[0].state.length
  }
}
```

> As a result, the query returns complete resource state information to the list of results for `web`. This lets the `list.aws_instance.web-bu` block reference the `length` attribute from `web` as the value for its `count` argument.

The reference expression is `list.<type>.<label>.data[<index>].state.<attribute>` — so results arrive as a **`data` list**, each element carrying a `state` object. That is the shape to expect from `terraform query` output, and it means queries **chain**: discover one set, then size or filter a second query from what the first found.

!!! warning "That example is the most broken sample in the section"
    As printed it sets `provider = concept`, and it puts `count` **inside the `config` block**, where `count` is a top-level meta-argument. Neither is correct. The *capability* — cross-list references, and the `data[…].state.…` path — is stated in the prose and is the part to trust; the snippet is not copyable.

## Referencing syntax — the page disagrees with itself

> Use the **`list.<label>.<attribute>`** syntax to reference the list block.

But its own example uses `list.aws_instance.web.data[0].state.length` — that is `list.<type>.<label>.…`, which also matches [[tf-import-bulk]]'s statement that results are identified as **`list.<type>.<label>`**. Two sources against one, so the prose sentence here is the outlier. Use type **and** label.

## Defects

!!! warning "Seven problems, and a pattern worth noting"
    - **`list.<label>.<attribute>`** in the Specification contradicts the page's own example and [[tf-import-bulk]].
    - **`provider = concept`** in the cross-reference example — not a provider name.
    - **`count` written inside `config`** in that same example, where it is a top-level meta-argument.
    - **`list "azurerm_resource_group" "rg"` declared with `provider = aws`.**
    - **The "Complete configuration" block is malformed** — `for_each [` with no `=`, opening a bracket around `<KEY> = <VALUE>` map syntax, and `include_resource = <false>` writing a placeholder as if it were a value.
    - **`include_resource`'s Summary says *"Default: None"***, though the prose describes an identity-only default and [[tf-import-bulk]] says `false`.
    - **"attriubtes"** in the `config` description.

    Together with [[tf-block-import]]'s six, that is **two consecutive block-reference pages whose prose is authoritative and whose samples do not survive inspection**. Read these pages for the argument tables and the behavioural sentences; take working syntax from the workflow pages ([[tf-import-bulk]], [[tf-import-single]]) or from a real plan.

---
Related: [[tf-import-bulk]] — the workflow this configures, plus `terraform query`, `-generate-config-out`, and the HCP cross-workspace identity check. · [[tf-block-import]] — the sibling reference, and the same unproofread-samples problem. · [[tf-import]] — the hub, and why identities rather than IDs. · [[feature-history]] — list resources and `terraform query` at 1.14. · [[tf-meta-for-each]] — `for_each` and `count` as general meta-arguments.
