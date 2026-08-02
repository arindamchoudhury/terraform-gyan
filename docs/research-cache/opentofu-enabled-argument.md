# OpenTofu `enabled` — a `lifecycle` argument, not a seventh meta-argument

**Verified:** 2026-08-02, empirically against **OpenTofu v1.12.4** (windows_amd64), plus the OpenTofu docs page and the v1.11.0 release notes.

## The correction

Earlier notes in this project described `enabled` as "a seventh meta-argument" sitting alongside `count`, `for_each`, `depends_on`, `lifecycle`, `provider`, and `providers`. That is wrong about where it goes.

**`enabled` is an argument inside the `lifecycle` block.** At the resource top level it is rejected:

```hcl
resource "terraform_data" "x" {
  enabled = var.on      # ✗
  input   = "hi"
}
```

```
Error: Unsupported argument

  on main.tf line 7, in resource "terraform_data" "x":
   7:   enabled = var.on

An argument named "enabled" is not expected here.
```

The accepted form:

```hcl
resource "terraform_data" "x" {
  input = "hi"

  lifecycle {
    enabled = var.on
  }
}
```

The OpenTofu docs state this directly: "The `enabled` meta-argument, introduced in OpenTofu v1.11, provides a cleaner way to conditionally create or skip a single resource or module instance in a `lifecycle` block."

## What it does that `count = cond ? 1 : 0` does not

Measured, same config run both ways on OpenTofu 1.12.4:

| `enabled` | Apply | `terraform_data.x` evaluates to |
|---|---|---|
| `true` | `1 added` | the resource object — `terraform_data.x.output` is `"hi"` |
| `false` | `1 destroyed` | **`null`** |

Two consequences:

- **The address never gains an index.** It stays `terraform_data.x`, not `terraform_data.x[0]`. Every reference, `moved` block, and `-target` in the configuration is written once and does not change when the resource is toggled.
- **Disabled means `null`, not an empty collection.** A reference to a disabled resource is `null`, so `terraform_data.x.output` fails with *"Attempt to get attribute from null value"* rather than silently yielding an empty list. Guard with `terraform_data.x == null ? … : …`.

With the `count` idiom the reference is a tuple: present as `[obj]`, absent as `[]`, and every consumer writes `[0]`.

## Terraform status

Terraform 1.15.8 has no equivalent, in `lifecycle` or anywhere else. The `count = var.x ? 1 : 0` idiom remains the only way to make a single resource optional, and HashiCorp's own [`count` reference](https://developer.hashicorp.com/terraform/language/meta-arguments/count) endorses it.

## Sources

- OpenTofu docs — `https://opentofu.org/docs/language/meta-arguments/enabled/`
- OpenTofu v1.11.0 release notes — "If you want to conditionally deploy a resource, you no longer have to use `count = var.create_my_resource ? 1 : 0`, you can now add the new `enabled` meta-argument to your resource to conditionally deploy it." Note the release-notes example omits the enclosing `lifecycle` block that the docs page and the implementation both require.
