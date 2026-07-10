# `terraform_data` resource reference

> **Source:** [developer.hashicorp.com/terraform/language/resources/terraform-data](https://developer.hashicorp.com/terraform/language/resources/terraform-data)
> **Added:** 2026-07-10
> **Source updated:** undated language reference; captured 2026-07-10 against v1.15.x (latest)
> **Tags:** terraform_data, built-in-resources, null_resource, replace_triggered_by, triggers_replace, provisioners, lifecycle
> **Type:** documentation

*Developer › Terraform › Configuration Language › Reference › Built-in resources › `terraform_data` resource reference · v1.15.x*

The reference behind A1's step-1 citation. [[tf-configure-resource]] introduces `terraform_data` in one line as "the modern replacement for the `null_resource` pattern"; this page is where the arguments, attributes, and the two real use cases live.

## What it is

> "The `terraform_data` resource type implements the **standard resource lifecycle**, but does not directly take any other actions."

No provider required or configured. It is always available through a **built-in provider** with the source address `terraform.io/builtin/terraform`.

Two stated purposes:

1. Storing values that need to follow a **managed resource lifecycle**.
2. Triggering **provisioners** when there is no other logical managed resource to put them in.

!!! tip "It needs no plugin download — useful for offline experiments"
    Because the provider is built in, a config using only `terraform_data` runs `init`, `plan`, and `apply` without fetching any provider. Verified while investigating the DAG (see [[dependency-graph]]): a four-resource `terraform_data` config initialized and applied with no network provider install. Handy for reproducing language behavior in isolation, and for machines where provider plugin startup is blocked (see the local Norton/mTLS issue).

## Arguments

| Argument | Meaning |
|---|---|
| `input` | *(Optional)* A value to store in the instance state. Terraform prints it in the `output` attribute after `apply`. |
| `triggers_replace` | *(Optional)* A value to store in the instance state. **Terraform replaces the resource when this value changes.** |

## Attributes

| Attribute | Meaning |
|---|---|
| `id` | A string value unique to the resource instance. |
| `output` | The computed value derived from `input`. |

!!! note "`output`'s type is preserved even when unknown"
    "In plans where `output` is unknown, Terraform returns the **same type of value** used in the `input` argument." So a plan can still type-check expressions that consume `output` before the value exists.

## Use case 1 — feeding `replace_triggered_by`

The `lifecycle` rule `replace_triggered_by` accepts only **resource addresses**, because forcing replacement is decided from the planned operations of the referenced resources.

> "Plain data values, such as **local values and input variables, aren't valid** in `replace_triggered_by`."

`terraform_data` is the documented workaround: it plans an action whenever its `input` changes, so it converts a plain value into something `replace_triggered_by` can legally reference.

```hcl
variable "revision" {
  default = 1
}

resource "terraform_data" "replacement" {
  input = var.revision
}

resource "example_database" "test" {
  lifecycle {
    replace_triggered_by = [terraform_data.replacement]
  }
}
```

Bump `var.revision` and the database is replaced. This is the indirection that makes a variable able to drive a replacement.

## Use case 2 — a container for provisioners

When a `provisioner` has no logical resource to attach to, `terraform_data` hosts it. `triggers_replace` decides when it re-runs.

```hcl
resource "aws_instance" "web" {
  # ...
}

resource "aws_instance" "database" {
  # ...
}

resource "terraform_data" "bootstrap" {
  triggers_replace = [
    aws_instance.web.id,
    aws_instance.database.id
  ]

  provisioner "local-exec" {
    command = "bootstrap-hosts.sh"
  }
}
```

Note the dependency mechanics: referencing `aws_instance.web.id` inside `triggers_replace` creates an **implicit** edge, so the bootstrap runs after both instances exist. No `depends_on` needed. Replacing either instance changes its `id`, replaces `terraform_data.bootstrap`, and re-runs the provisioner. See [[dependency-graph]].

!!! warning "This does not make provisioners a good idea"
    The page presents provisioner hosting neutrally, but HashiCorp's own provisioners page calls them a **last resort**. `terraform_data` makes the escape hatch *tidier*, not *recommended*. → learning-path **A1**.

## `triggers_replace` vs `input`

Both merely store a value in state. The difference is what a change does:

- Change `input` → the resource is **updated in place**; `output` changes.
- Change `triggers_replace` → the resource is **replaced** (`-/+`), which re-runs any provisioners it hosts.

## Versus `null_resource`

`null_resource` (from the `null` provider) did both jobs before Terraform 1.4, using a `triggers` **map**. `terraform_data` supersedes it: no provider dependency, and `triggers_replace` takes any value rather than a map of strings. Prefer `terraform_data` in new code. See [[feature-history]].

---
Related: [[tf-configure-resource]] — introduces `terraform_data` among built-in and local-only resources. · [[meta-arguments-lifecycle]] — `replace_triggered_by`, the rule this resource exists to feed. · [[dependency-graph]] — implicit edges from `triggers_replace` references; also where this resource got used to isolate language behavior from providers. · [[tf-meta-arguments]] — the meta-argument set `lifecycle` belongs to.
