# Manage sensitive data

> **Source:** [developer.hashicorp.com/terraform/language/manage-sensitive-data](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)
> **Added:** 2026-07-13
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-13, re-fetched 2026-07-30 and byte-identical
> **Tags:** secrets, sensitive, ephemeral, write-only, state-security, encryption, provider-credentials
> **Type:** documentation

The umbrella guide for A6. Ties together the three mechanisms the path's A6 references cover separately — `sensitive`, ephemeral values, write-only arguments — with a **decision framework** (hide vs. omit vs. both) and the version-requirements matrix. Confirms the core caveat from [[tf-block-variable]] and [[tf-input-variables]]: `sensitive` redacts output but the value is **still in state**.

## Background — where secrets leak

State and plan files hold detailed infrastructure data, including attributes that can carry secrets (initial DB passwords, API tokens).

- **Local** development stores state in a **plaintext** file — including any secrets. Treat it as sensitive: keep it out of Git, and secure it.
- **Remote** state is held in memory only while actively used, and can be **encrypted at rest** — but the method depends on the backend. HCP Terraform encrypts at rest automatically and protects state with TLS in transit.

## Requirements

| Feature | Minimum Terraform |
|---|---|
| `sensitive` argument on `variable` / `output` | 0.15 |
| `ephemeral` argument on variables / child-module outputs, and the `ephemeral` block | 1.10 |
| write-only argument on a managed resource | 1.11 |

Each **provider** defines its own available `ephemeral` blocks and write-only arguments — check the registry for what yours supports.

## Decision framework

Start by asking: do you want to **hide** values from CLI/HCP UI, or **prevent Terraform from storing them entirely**?

- **Hide** → add `sensitive` to a `variable`/`output`. Redacts from CLI output and HCP UI; any expression referencing it becomes sensitive too. (Value still stored.)
- **Omit** → use ephemeral values (available at runtime, never written to state/plan). Three forms: the `ephemeral` argument on variables/child-module outputs, the `ephemeral` block, and a write-only argument on a managed resource.
- **Both** → add `sensitive` **and** `ephemeral` to a variable/child-module output: omitted from state/plan *and* redacted in output.

## Hide sensitive variables and outputs

```hcl
variable "database_password" {
  description = "Password for the database instance"
  type        = string
  sensitive   = true
}

output "connection_string" {
  description = "Database connection string"
  value       = "postgresql://${var.db_username}:${var.database_password}@${aws_db_instance.main.endpoint}/mydb"
  sensitive   = true
}
```

A sensitive output renders as `connection_string = (sensitive value)`. Terraform propagates sensitivity: a resource argument referencing `var.database_password` is redacted too (`password = (sensitive value)`).

!!! warning "`sensitive` does not protect state — and `-json`/`-raw` bypass redaction"
    Values marked `sensitive` are **stored in both state and plan files**; anyone who can read those files reads the secret. And `terraform output -json` or `terraform output -raw` prints sensitive variables/outputs **in plain text**. If you don't want the value stored at all, use ephemeral; if you must store it, secure the state (below).

!!! danger "The gap this page leaves out: a named query needs no flag at all"
    This page lists `-json` and `-raw` as the ways redaction is bypassed. There is a third, and it needs no flag. Verified on **v1.15.8** ([[tf-cmd-output]]):

    | Command | Output |
    |---|---|
    | `terraform output` | `password = <sensitive>` |
    | `terraform output password` | `"notasecurepassword"` |

    So `sensitive` protects the **aggregate listing** and the operation log, nothing more. Reading the value back is a normal, flagless command. The CLI reference states this plainly — "Terraform does not redact sensitive values when you specify the output by name" — while the language *Output Values* page claims the opposite and is wrong. Treat `sensitive` as *hiding from logs*, never as access control.

## Omit values from state and plan files

Ephemeral values are available during an operation but never written to state/plan. Because they aren't stored, **you must capture any generated value you want to keep** in another resource or output.

**Where ephemeral values may be referenced** (the allowed contexts):

- a `locals` block
- a `variable` block with `ephemeral`
- a child-module `output` block with `ephemeral`
- a managed-resource write-only argument
- an `ephemeral` block
- a `provider` block (to configure providers)
- `provisioner` and `connection` blocks

### `ephemeral` argument on a variable or output

```hcl
variable "api_token" {
  description = "Short-lived API token for provider authentication"
  type        = string
  sensitive   = true
  ephemeral   = true
}

provider "example" {
  api_token = var.api_token
}
```

An `ephemeral` output is allowed **only in child modules — not the root module**. It passes temporary values (credentials, tokens) between modules without persisting them:

```hcl
output "session_token" {
  value     = ephemeral.auth_provider.main.token
  ephemeral = true
  sensitive = true
}
```

!!! note "Both halves of the root-module restriction, verified on v1.15.8"
    The rule is tighter than "declare it in a child module." Neither route reaches the root:

    ```
    # output "eph" { ephemeral = true, ... } in the root module
    Error: Ephemeral output not allowed
    Ephemeral outputs are not allowed in context of a root module

    # root output whose value = module.child.eph, where the child's output is ephemeral
    Error: Ephemeral value not allowed
    This output value is not declared as returning an ephemeral value, so it cannot be
    set to a result derived from an ephemeral value.
    ```

    The practical consequence, since `terraform output` reads root outputs only: **an ephemeral value can never be read back through `terraform output`**. It is consumed within the run or not at all — which is exactly the point, but it also means you cannot use one to hand a credential to a wrapper script. See [[tf-cmd-output]].

### The `ephemeral` block

Declares a temporary **ephemeral resource** that exists only during the current operation — never stored. Providers define which ephemeral resources exist. Referenceable only from other ephemeral contexts (e.g. a write-only argument).

```hcl
ephemeral "random_password" "db_password" {
  length           = 16
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "example" {
  instance_class       = "db.t3.micro"
  allocated_storage    = "5"
  engine               = "postgres"
  username             = "example"
  skip_final_snapshot  = true
  publicly_accessible  = true
  db_subnet_group_name = aws_db_subnet_group.example.name
  password_wo          = ephemeral.random_password.db_password.result
  password_wo_version  = 1
}
```

Neither the write-only argument nor the ephemeral block persists — `ephemeral.random_password.db_password.result` is completely omitted from state/plan.

### Write-only arguments

Pass temporary values into a managed resource during an operation without persisting them. Provider-defined; conventionally named `_wo` with a companion `_wo_version`:

```hcl
resource "aws_db_instance" "main" {
  instance_class      = "db.t3.micro"
  allocated_storage   = "20"
  engine              = "postgres"
  username            = "admin"
  skip_final_snapshot = true

  password_wo         = ephemeral.random_password.db_password.result
  password_wo_version = 1
}
```

The provider uses `password_wo` to create the instance, then Terraform **discards it** — never in plan or state. Bump `password_wo_version` to trigger a re-read of the value.

## State security best practices

If secrets do land in state, harden it:

- store state **remotely**
- **encrypt at rest**
- **access controls** to limit who can read state
- **audit logs** to track state access over time

Backends that support encryption at rest:

- **HCP Terraform** — encrypts at rest (bring-your-own-keys supported), TLS in transit.
- **S3 backend** — encrypts at rest with the `encrypt` option; TLS in transit.
- **GCS backend** — supports customer-supplied / customer-managed encryption keys.

---
Related: umbrella over [[tf-block-variable]] and [[tf-input-variables]] (`sensitive`/`ephemeral` arguments), and the state-exfiltration angle in [[tf-remote-state-data]]. Feeds learning-path **A6** (the decision framework, write-only `_wo`/`_wo_version`, and the `-json`/`-raw` redaction bypass) and **I6** (state-encryption backends).
