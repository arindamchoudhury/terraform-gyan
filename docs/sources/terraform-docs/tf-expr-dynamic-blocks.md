# `dynamic` Blocks

> **Source:** [developer.hashicorp.com/terraform/language/expressions/dynamic-blocks](https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks)
> **Added:** 2026-07-15
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-15
> **Tags:** dynamic-blocks, nested-blocks, for_each, iterator, multi-level-nesting, module-abstraction
> **Type:** documentation

Inside top-level blocks (resources, etc.), expressions usually work only in `name = expression` argument assignments. But some resource types have **repeatable nested blocks** representing related/embedded objects. Those nested blocks are normally written as literal blocks:

```hcl
resource "aws_elastic_beanstalk_environment" "tfenvtest" {
  name = "tf-test-name" # can use expressions here

  setting {
    # but the "setting" block is always a literal block
  }
}
```

A `dynamic` block constructs repeatable nested blocks dynamically. Supported inside `resource`, `data`, `provider`, and `provisioner` blocks:

```hcl
resource "aws_elastic_beanstalk_environment" "tfenvtest" {
  name                = "tf-test-name"
  application         = aws_elastic_beanstalk_application.tftest.name
  solution_stack_name = "64bit Amazon Linux 2018.03 v2.11.4 running Go 1.12.6"

  dynamic "setting" {
    for_each = var.settings
    content {
      namespace = setting.value["namespace"]
      name      = setting.value["name"]
      value     = setting.value["value"]
    }
  }
}
```

A `dynamic` block acts like a `for` expression, but produces **nested blocks** instead of a complex typed value. It iterates a complex value and generates one nested block per element.

## Anatomy

- **Label** (`"setting"`) — the kind of nested block to generate.
- **`for_each`** — the complex value to iterate. Accepts any collection or structural value, so you can feed it a `for` or splat expression to transform an existing collection.
- **`iterator`** (optional) — name of the temporary variable for the current element. Defaults to the block label.
- **`labels`** (optional) — list of strings giving the generated blocks' labels, in order. Can use the iterator variable.
- **`content`** — the body of each generated block. Can use the iterator variable.

The iterator object has two attributes:

- **`key`** — map key or list index of the current element. If `for_each` produces a **set**, `key` equals `value` and should not be used.
- **`value`** — the current element's value.

### Example: the `labels` argument

Most nested block types take **no label** (`setting {}`, `ingress {}`), so `labels` is rarely needed — that's why the HCDocs page doesn't demonstrate it. It matters only when the nested block you're generating expects a label of its own, i.e. `block "somelabel" { ... }`.

Concrete case (from Terraform maintainer *apparentlymart* on [HashiCorp Discuss — "Labels in dynamic block"](https://discuss.hashicorp.com/t/labels-in-dynamic-block/21461)): the `testing_assertions` data source has an `equal` nested block that expects **one** label. A `dynamic "equal"` block sets that label per iteration from the map key via `labels = [equal.key]`:

```hcl
locals {
  test_assertions = {
    contents = {
      statement = "has the expected content"
      got       = jsondecode(data.http.terraform_disco.body)
      want = {
        "modules.v1" : "${module.mut.base_url}/modules/v1"
      }
    }
    content_type = {
      statement = "has JSON content type"
      got       = data.http.terraform_disco.response_headers["content-type"]
      want      = "application/json"
    }
  }
}

data "testing_assertions" "terraform_disco" {
  subject = "Terraform discovery document"

  dynamic "equal" {
    for_each = local.test_assertions
    labels   = [equal.key]
    content {
      statement = equal.value.statement
      got       = equal.value.got
      want      = equal.value.want
    }
  }
}
```

This generates two labeled blocks — `equal "contents" { ... }` and `equal "content_type" { ... }` — one per map entry, each block's label taken from `equal.key`. `labels` is a **list** because a block type can require more than one label (you'd supply one list element per label position, in order).

## Limits

A `dynamic` block can only generate arguments/blocks that belong to the resource type, data source, provider, or provisioner being configured. It **cannot** generate meta-argument blocks like `lifecycle` or `provisioner` — Terraform must process those before it's safe to evaluate expressions.

`for_each` must be a collection with one element per desired block. To build blocks from a nested data structure or combinations across multiple structures, derive a suitable value first — see the `flatten` and `setproduct` functions.

## Multi-level nested block structures

Generate multiple nesting levels by nesting `dynamic` blocks inside the `content` of another. Given:

```hcl
variable "load_balancer_origin_groups" {
  type = map(object({
    origins = set(object({
      hostname = string
    }))
  }))
}
```

Generate a block per origin group, and nested blocks per origin within each group:

```hcl
dynamic "origin_group" {
  for_each = var.load_balancer_origin_groups
  content {
    name = origin_group.key

    dynamic "origin" {
      for_each = origin_group.value.origins
      content {
        hostname = origin.value.hostname
      }
    }
  }
}
```

Watch the iterator symbol per level: `origin_group.value` is the outer element, `origin.value` is the inner. When a nested block shares a type name with a parent, use the `iterator` argument to pick a distinct symbol and keep the two clear.

## Best practices

Overusing `dynamic` blocks makes configuration hard to read. Use them **only** to hide detail behind a clean interface for a reusable module. Write nested blocks out literally where possible.

If you find yourself defining most of a resource's arguments/blocks from directly-corresponding input-variable attributes, the module may not be a useful abstraction. Better to have the calling module define the resource and pass info into yours. (See "When to Write a Module" and "Module Composition.")

---
Related: [[tf-expr-for]] — a `dynamic` block is the block-producing analog of a `for` expression; `for`/splat can feed its `for_each`. [[tf-expr-splat]] — `value[*]` on an optional-`null` object is the idiom for a zero-or-one `dynamic` block. [[tf-expressions]] — dynamic blocks are covered under the Expressions overview.
