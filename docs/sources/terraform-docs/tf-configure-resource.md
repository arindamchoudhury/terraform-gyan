# Configure a resource

> **Source:** [developer.hashicorp.com/terraform/language/resources/configure](https://developer.hashicorp.com/terraform/language/resources/configure)
> **Added:** 2026-07-09
> **Source updated:** docs for Terraform v1.15.x (latest); no explicit page date
> **Tags:** resources, resource-block, timeouts, meta-arguments, terraform_data, local-only-resources, dependencies
> **Type:** documentation

The how-to for the `resource` block, one level below the [[tf-resources]] overview. The block basics (type + name → address, provider-specific arguments, implicit vs explicit dependencies) are already covered by [[tf-config-syntax]], [[tf-aws-create]], and the [[providers]]/book Ch3. Captured here for what those don't: the **`timeouts` block**, the **meta-argument map**, and **built-in / local-only resources**.

## The three configuration steps

1. **Declare** a `resource` block with a **type** and a local **name**. Type + name form the state **address** (`aws_instance.web`).
2. **Configure provider-specific arguments** — most of the block body; the resource type's docs say which are required. Values can be hard-coded or built from expressions.
3. **Configure Terraform meta-arguments** — built-in arguments that control *how* Terraform manages the resource, usable with any type.

```terraform
resource "aws_instance" "web" {
  ami           = "ami-a1b2c3d4"   # provider-specific
  instance_type = "t2.micro"       # provider-specific
}
```

!!! note "`terraform_data` is the one native resource type"
    Almost every resource type comes from a provider. The exception is `terraform_data`, built into Terraform itself (see built-in resources below).

## Operation timeouts

Some resource types support a **`timeouts` child block** to bound how long Terraform waits per operation before erroring. It's per-resource-type — check the provider docs for which operations are configurable. Convention:

- A child block named `timeouts`.
- One nested argument per configurable operation (`create`, `update`, `delete`, …).
- Each takes a **duration string**: `"60m"`, `"10s"`, `"2h"`.

```terraform
resource "aws_db_instance" "example" {
  # ...
  timeouts {
    create = "60m"
    delete = "2h"
  }
}
```

!!! note "`timeouts` looks like a meta-argument but isn't"
    The `timeouts` block is defined by the *provider/resource type*, not by Terraform core — so it only exists where the provider implements it, and the operations vary by type. Don't assume every resource has it.

## Meta-argument map (with forward references)

The page surveys the meta-arguments; each gets full treatment later in the learning path:

- **`precondition` / `postcondition`** blocks — assumptions and guarantees about the resource; catch misconfigurations early and in context. → learning-path **A2 (validation & checks)**.
- **`provider`** — pick a non-default provider configuration (alias) when multiple are declared. Terraform otherwise infers the provider from the resource type prefix. → **I8 (provider config in depth)**; alias mechanics in [[providers]].
- **`depends_on`** — explicit dependency when Terraform can't infer one from expression references (e.g. a hidden ordering like an IAM policy that must exist first). → **I1 (meta-arguments)**.
- **`replace_triggered_by`** (a `lifecycle` rule) — force-replace this resource when a referenced resource/attribute changes. → **I2 (lifecycle)**.

Prefer **implicit** dependencies (attribute references) — Terraform builds the order automatically and in parallel where possible. Reach for `depends_on` only for dependencies it can't see. This confirms the book's Ch3 rule.

## Built-in and local-only resources

Special resource types that program actions without touching real infrastructure:

- **`terraform_data`** — implements the standard resource lifecycle but takes no action itself. The modern replacement for the `null_resource` pattern. → **A1 (provisioners, `terraform_data` & escape hatches)**.
- **Local-only resources** — compute values and store them in state; no cloud object is created. Destroying one just drops it from state. They use the built-in `terraform.io/builtin/terraform` provider. Examples:
    - `tls_private_key` — generate a TLS private key.
    - `tls_self_signed_cert` — issue a self-signed cert.
    - `random_id` — generate a random ID (e.g. for unique resource names).

!!! warning "Local-only ≠ secret-safe"
    A `tls_private_key` or generated password computed by a local-only resource is **stored in plaintext in state**. That's the same state-secrets caveat the book raises — local-only resources are convenient, not a secrets solution. → **A6 (secrets & sensitive data)**.

---
Related: [[tf-resources]] — the overview this page details. · [[tf-config-syntax]] — the block/argument syntax underneath. · [[tf-aws-create]] — a real `aws_instance` with provider args + implicit deps. · [[providers]] — provider-alias selection via the `provider` meta-argument.
