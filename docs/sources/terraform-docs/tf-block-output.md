# `output` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/output](https://developer.hashicorp.com/terraform/language/block/output)
> **Added:** 2026-07-13
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-13
> **Tags:** outputs, output-block, type, precondition, depends_on, deprecated, sensitive, ephemeral
> **Type:** documentation

Argument spec behind [[tf-outputs]] (the how-to). The reference adds the arguments the how-to skips: `type`, `depends_on`, `deprecated`, and the `precondition` block. Output label follows the same naming rules as a resource.

## Arguments

Only `value` is required; nothing is mutually exclusive.

| Argument | Purpose | Type | Required |
|---|---|---|---|
| `value` | The value Terraform returns and stores in state | Expression | **Yes** |
| `type` | Type constraint on the value | Type constraint | Optional |
| `description` | Documents purpose (write for the consumer) | String | Optional |
| `sensitive` | Hide value in CLI output | Boolean | Optional |
| `ephemeral` | Omit value from state/plan (child modules only) | Boolean | Optional |
| `depends_on` | Explicit upstream dependencies | List | Optional |
| `deprecated` | Deprecation message (child modules only) | String | Optional |
| `precondition` | Validate before exposing/storing the value | Block | Optional |

### `value` (required)

Terraform evaluates the expression, returns it as the output, and **stores it in state**. Any valid expression works.

### `type`

Constrains the output's value type; unset → accepts any type. Typing module outputs helps consumers and **improves matching between validation, plan, and apply**.

### `sensitive`

Redacts the value in plan/apply (`admin_password = (sensitive value)`). Same caveats as everywhere: **still stored in state**, and `terraform output -json`/`-raw` print it in plain text (see [[tf-manage-sensitive-data]]).

### `ephemeral` (v1.10+)

Child-modules-only — **you cannot mark a root-module output `ephemeral`.** Passes temporary values (credentials, tokens) between modules without persisting. Conditions when enabled: the value must **come from an ephemeral context**, and the output may **only be referenced in ephemeral contexts** (another child module's ephemeral output, a write-only argument, an `ephemeral` variable, an `ephemeral` resource, a `provider` block, or a provisioner/connection config).

### `depends_on`

A meta-argument — explicit upstream dependency. Terraform finishes all operations on the referenced resource before computing the output. Rarely needed; **the docs recommend a comment explaining why** when you add one.

### `deprecated` (v1.15+)

Child-modules-only. Shows the reason **when another module uses the output**. The defining module sees **no** warning — only consumers do. Suppress nested warnings for a module call with **`ignore_nested_deprecations`** in the `module` block.

### `precondition`

Validates the output before Terraform exposes it or stores it in state — evaluated when creating/applying a plan; a false `condition` throws `error_message` and stops. Both sub-arguments required (`condition`, `error_message`). This is the output-side counterpart to a variable's `validation` block. (Learning-path **A2** — custom conditions.)

## Examples

**Access a child module's output:**

```hcl
output "website_url" {
  value       = "https://${module.web_server.instance_ip_addr}"
  description = "The URL of the web server, starting with https://."
}
```

**Precondition** — refuse to expose an IP unless the security group allows HTTP/HTTPS:

```hcl
output "instance_public_ip" {
  value       = aws_instance.web.public_ip
  description = "Public IP address of the instance."

  precondition {
    condition     = length([for rule in aws_security_group.web.ingress : rule if rule.to_port == 80 || rule.to_port == 443]) > 0
    error_message = "Security group must allow HTTP (port 80) or HTTPS (port 443) ingress traffic."
  }
}
```

**Explicit dependency** (with the recommended comment):

```hcl
output "instance_ip_addr" {
  value = aws_instance.server.private_ip

  depends_on = [
    # Services are unreachable unless the security group rule is created
    # before exposing this IP address.
    aws_security_group_rule.local_access,
  ]
}
```

---
Related: argument spec for [[tf-outputs]] (that page is the how-to; this is the block reference — the pairing HCDocs uses under the *Outputs* sidebar group). `precondition` → A2 conditions; `deprecated` mirrors [[tf-block-variable]]'s (I5); `ephemeral`/`sensitive` detailed in [[tf-manage-sensitive-data]]. Completes the value-trio reference set with [[tf-block-variable]] and [[tf-block-locals]].
