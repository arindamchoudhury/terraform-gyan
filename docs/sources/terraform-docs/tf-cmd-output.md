# `terraform output` command

> **Source:** [developer.hashicorp.com/terraform/cli/commands/output](https://developer.hashicorp.com/terraform/cli/commands/output)
> **Added:** 2026-07-30
> **Source updated:** undated CLI reference; captured 2026-07-30 against v1.15.x (latest)
> **Tags:** cli, output, json, raw, sensitive, ephemeral, root-module, automation
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Inspecting Infrastructure › `output` · v1.15.x*

The command reference for reading outputs back out of state. The language side is [[tf-outputs]] and [[tf-block-output]]; the hands-on is [[tut-outputs]]. Capturing this one settled a **contradiction between two HashiCorp pages** — see the verification section.

## Usage and flags

```
terraform output [options] [NAME]
```

No argument prints every root-module output. With a `NAME`, only that value.

| Flag | Effect |
|---|---|
| `-json` | Outputs as a JSON object, one key per output. With `NAME`, only that output. Pipe into `jq`. |
| `-raw` | Converts the value to a string and prints it with no formatting. **Only `string`, `number`, `bool`.** |
| `-no-color` | Strip color. |
| `-state=path` | Path to the state file, default `terraform.tfstate`. "Legacy option for the local backend only." |

`-state` is the same legacy surface [[tf-backend-local]] documents and disowns.

**Root module only.** "The `terraform output` command only displays outputs defined in the root module." The passthrough pattern is the fix, and it is the same one [[tf-remote-state-data]] requires for sharing across configurations:

```hcl
module "loadbalancer" {
  source = "./modules/loadbalancer"
}

output "address" {
  value = module.loadbalancer.lb_address
}
```

## Use in automation

> "The `terraform output` command by default displays in a human-readable format, **which can change over time to improve clarity**."

That sentence is the reason the `-json` form exists, and it matches [[tf-state]]'s rule about parsing supported outputs rather than files.

```shell
terraform output -json instance_ips | jq -r '.[0]'
terraform output -raw lb_address
```

`-raw` "works only with values that Terraform can automatically convert to strings." For objects and collections, use `-json` with `jq`.

!!! note "`-raw` and character encoding"
    "Terraform strings are sequences of Unicode characters rather than raw bytes, so the `-raw` output will be **UTF-8 encoded** when it contains non-ASCII characters. If you need a different character encoding, use a separate command such as `iconv`."

## Sensitive and ephemeral values

The page states two rules.

> "**Note:** When using the `-json` or `-raw` command-line flags, Terraform displays sensitive values in plain text."

> "Terraform does **not** redact sensitive values when you specify the output by name."

> "However, Terraform completely **omits any ephemeral values**, even if you specify an output by name."

## Verified on Terraform v1.15.8

Run on a `terraform_data` config with a `sensitive` output, no provider plugin, local backend.

**Redaction applies to the aggregate listing only.** This resolves a straight contradiction between two HashiCorp pages.

| Command | Output |
|---|---|
| `terraform output` (no name) | `password = <sensitive>` |
| `terraform output password` | `"notasecurepassword"` |
| `terraform output -raw password` | `notasecurepassword` |
| `terraform output -json password` | `"notasecurepassword"` |

!!! danger "The language Outputs page is wrong about this"
    [[tf-outputs]]' source, *Output Values*, says: "Trying to access a sensitive output value directly in the CLI displays a redacted message instead of the actual value", and shows `terraform output database_password` → `database_password = <sensitive>`.

    **That is false on v1.15.8.** Querying by name prints the value in the clear, exactly as this CLI page says and as [[tut-outputs]] recorded from the tutorial. `sensitive = true` protects the *aggregate* listing, nothing more. Treat any named query as a plaintext read of state.

**Ephemeral outputs cannot reach this command at all.** The page's omission sentence describes a case that is unreachable in a root module on v1.15.8, because both routes to it are rejected:

```
# output "eph" { ephemeral = true, value = "..." } in the root module
Error: Ephemeral output not allowed
Ephemeral outputs are not allowed in context of a root module

# root output whose value is module.child.eph, where the child's output is ephemeral
Error: Ephemeral value not allowed
This output value is not declared as returning an ephemeral value, so it cannot be set
to a result derived from an ephemeral value.
```

Since `terraform output` reads root outputs only, and a root output can neither *be* ephemeral nor *derive from* an ephemeral value, there is no configuration on this version where the command has an ephemeral value to omit.

> ❓ Unverified: whether that sentence is forward-looking, or written for a context this test does not cover (Stacks, or a future relaxation of the root-module rule). The behavior above is what 1.15.8 does; the intent behind the sentence is not established.

---
Related: [[tf-outputs]] — the language page whose redaction claim this disproves. · [[tut-outputs]] — the tutorial that already had the redaction matrix right. · [[tf-block-output]] — the block's arguments, including `ephemeral`. · [[tf-cli-inspect]] — the command group this belongs to. · [[tf-backend-local]] — the legacy `-state` option. · [[tf-manage-sensitive-data]] — the wider sensitive-values picture, including why state itself is plaintext.
