# Dynamic `prevent_destroy` (OpenTofu)

> **Source:** [opentofu.org/blog/opentofu-1-12-0](https://opentofu.org/blog/opentofu-1-12-0/) · [lifecycle docs](https://opentofu.org/docs/language/meta-arguments/lifecycle/)
> **Added:** 2026-07-03
> **Source updated:** OpenTofu **1.12.0** (2026-05)
> **Tags:** opentofu, lifecycle, prevent_destroy, variables, divergence
> **Type:** documentation

OpenTofu 1.12 lets `prevent_destroy` (in a resource `lifecycle` block) be **defined dynamically** from other symbols in the same module — notably **input variables**. Terraform's open-source CLI requires a **literal** `true`/`false`.

## What `prevent_destroy` does

When `true`, OpenTofu **rejects any plan that would destroy** the resource's object, as long as the argument stays in config. A safety net against accidental replacement of costly-to-reproduce objects (e.g. database instances). Lives alongside `create_before_destroy`, `ignore_changes`, and `replace_triggered_by` in the `lifecycle` block.

## What 1.12 adds

The value may now reference other values available in the same module. Example pattern: a module protects a database **by default**, but a dev consumer can switch protection off from the module block.

```hcl
variable "prevent_database_deletion" {
  type    = bool
  default = true
}

resource "aws_db_instance" "main" {
  # ...
  lifecycle {
    prevent_destroy = var.prevent_database_deletion
  }
}
```

```hcl
# dev environment can override
module "database" {
  source                     = "./modules/database"
  prevent_database_deletion  = false
}
```

This resolved a long-standing request (opentofu/opentofu#1329) to use variables in lifecycle attributes.

---
Related: OpenTofu divergence feature for the **E3** milestone; the path's **I5 — Resource lifecycle** topic already flags the literal-vs-variable distinction. One of the OpenTofu-only features listed with [[ot-provider-for-each]], [[ot-early-eval-backend]], [[ot-exclude-flag]].
