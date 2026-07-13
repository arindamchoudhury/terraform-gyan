# `variable` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/variable](https://developer.hashicorp.com/terraform/language/block/variable)
> **Added:** 2026-07-13
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-13
> **Tags:** variables, variable-block, type-constraint, validation, sensitive, ephemeral, const, deprecated, nullable
> **Type:** documentation

The argument-level spec for the `variable` block. Where [[tf-input-variables]] is the how-to (define, reference with `var.NAME`, assign, precedence), this page is the reference: every argument, its type, default, and behavior. A `variable` block is a module's **function argument** — parameters that make a module composable and reusable without editing its source.

## The label and reserved names

`variable "<LABEL>"` — the label names the variable and must be **unique among all variables in the module**. It can be any valid identifier **except** these reserved names:

```
source, version, providers, count, for_each, lifecycle, depends_on, locals
```

## Arguments

All arguments are optional; none are mutually exclusive. Full surface:

| Argument | Purpose | Type | Default |
|---|---|---|---|
| `type` | Type constraint on the value | Type constraint | `any` |
| `default` | Default value; makes the variable optional | Expression (literal) | none |
| `description` | Documents purpose + expected value | String | none |
| `validation` | Custom rule beyond the type constraint | Block | none |
| `sensitive` | Hide value in CLI output | Boolean | `false` |
| `nullable` | Allow `null` as a value | Boolean | `true` |
| `ephemeral` | Omit value from state/plan files (v1.10+) | Boolean | `false` |
| `const` | Allow use during early ops like `init` | Boolean | `false` |
| `deprecated` | Deprecation message (v1.15+) | String | none |

### `type`

Constrains the assignable type; without it, the variable accepts **any** type. Any primitive, complex, or structural type works. Type constraints give consumers clearer intent and better error messages on invalid input.

### `default`

Sets a fallback, making the variable optional. If `type` and `default` are both set, the default must convert to that type. **`default` requires a literal value — it cannot reference other objects** in the configuration. No default → a value argument is required.

### `description`

Write it from the **module consumer's** point of view, to explain how to use the variable. For maintainer-facing commentary, use a `#` comment instead.

### `validation`

Enforces a rule in addition to the type constraint, checked **while Terraform builds the plan**. If `condition` is false, Terraform shows `error_message` and stops. Both sub-arguments are **required**:

- `condition` — expression that must evaluate to `true`.
- `error_message` — string shown when it's false.

### `sensitive`

Redacts the value in plan/apply logs, shown as `(sensitive value)`. Any **expression that references a sensitive variable becomes sensitive too**. Caveat: the value is **still recorded in state** — anyone with state access can read it.

### `nullable`

Default `true`. `nullable = false` forbids `null` (and a `null` supplied to a defaulted variable falls back to the `default`). For collection/structural types, consumers can put `null` in nested elements as long as the collection/structure itself isn't null.

### `ephemeral` (v1.10+)

Makes the value available at runtime but keeps it **out of state and plan files** — for short-lived values like tokens or session IDs. Referencing an ephemeral variable makes the referencing expression ephemeral too. Valid **contexts** to reference/set an ephemeral variable:

- an `output` block marked `ephemeral`
- another `variable` block marked `ephemeral`
- a write-only argument in a `resource` block
- an `ephemeral` resource block
- a `provider` block (to configure providers)
- a provisioner / provisioner connection config

### `const`

Default `false`. `const = true` restricts the variable to a **known, constant value** that can't depend on plan-time results. This is what lets a variable be used in module and provider **`source` and `version`** attributes, which Terraform reads at **init** before any plan exists.

### `deprecated` (v1.15+)

A message shown when the variable is **set in a root module** or when a **child-module caller passes a value** for it. This is how a published module evolves its public API without breaking consumers — deprecate + warn, then remove in a later version. (Learning-path **I5**.)

## Examples

**Set a value to a complex type** — list of objects:

```hcl
variable "docker_ports" {
  type = list(object({
    internal = number
    external = number
    protocol = string
  }))
  description = "List of port configurations for Docker containers."
  default = [
    {
      internal = 8300
      external = 8300
      protocol = "tcp"
    }
  ]
}
```

**Validation** — require an AMI-shaped string:

```hcl
variable "image_id" {
  type        = string
  description = "The ID of the machine image (AMI) to use for the server."

  validation {
    condition     = length(var.image_id) > 4 && substr(var.image_id, 0, 4) == "ami-"
    error_message = "The image_id value must be a valid AMI ID, starting with \"ami-\"."
  }
}
```

**Ephemeral** — feed short-lived AWS credentials into the provider without persisting them:

```hcl
variable "access_key" {
  description = "AWS access key"
  type        = string
  ephemeral   = true
}

variable "secret_key" {
  description = "AWS sensitive secret key."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "session_token" {
  description = "AWS session token."
  type        = string
  sensitive   = true
  ephemeral   = true
}

provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  token      = var.session_token
}
```

---
Related: argument spec behind [[tf-input-variables]] (that page is the how-to; this is the block reference — same pairing HCDocs uses under the *Variables* sidebar group). `deprecated` feeds learning-path **I5**; `const` and the validation/type surface feed **B6**.
