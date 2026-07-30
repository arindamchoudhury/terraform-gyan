# `terraform state show` command

> **Source:** [developer.hashicorp.com/terraform/cli/commands/state/show](https://developer.hashicorp.com/terraform/cli/commands/state/show)
> **Added:** 2026-07-30
> **Source updated:** undated CLI reference; captured 2026-07-30 against v1.15.x (latest)
> **Tags:** cli, state-show, resource-addressing, for-each, quoting, powershell, human-readable
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Inspecting Infrastructure › `state show` · v1.15.x*

Prints every attribute of **one** resource instance in state. The last of the five *Inspecting Infrastructure* commands to be captured, and the one [[tf-state-refactor]] step 2 depends on for finding an import ID. Most of the page is addressing and shell-quoting examples — and its PowerShell advice does not work on PowerShell 7.

## Usage

```
terraform state show [options] ADDRESS
```

The address is mandatory and "requires an address that points to a **single** resource in the state." Not a filter: one instance, or an error.

| Flag | Effect |
|---|---|
| `-state=path` | Path to the state file, default `terraform.tfstate`. "Legacy option for the local backend only." |

That is the only flag. Same legacy surface as [[tf-backend-local]], [[tf-cmd-output]], and [[tf-cmd-state-list]].

!!! warning "Explicitly not a machine interface"
    > "The output of `terraform state show` is **intended for human consumption, not programmatic consumption**. To extract state data for use in other software, use `terraform show -json` and decode the result using the documented structure."

    This is the sharpest statement of the split [[tf-cli-inspect]] frames and [[tf-state]] argues: the rendered form is unversioned and may change, the JSON form is specified. So `state show | grep id` is the wrong instinct — see [[tf-cmd-show]] for what to parse instead.

The example output shows why it earns its place anyway — the provider-assigned attributes are all there, including `id`:

```
# packet_device.worker:
resource "packet_device" "worker" {
    billing_cycle = "hourly"
    created       = "2015-12-17T00:06:56Z"
    facility      = "ewr1"
    hostname      = "prod-xyz01"
    id            = "6015bg2b-b8c4-4925-aad2-f0671d5d3b13"
    locked        = false
}
```

## Addressing the instance you want

```shell
terraform state show 'module.foo.packet_device.worker'      # inside a module
terraform state show 'packet_device.worker[0]'              # count index
terraform state show 'packet_device.worker["example"]'      # for_each key
```

The `for_each` form needs quoting, because the address itself contains double quotes. The page gives three shell variants.

## Verified on PowerShell 7.6.3 — the docs' PowerShell form fails

Tested on Terraform **v1.15.8**, PowerShell **7.6.3**, against a `terraform_data` resource with `for_each = toset(["example", "other"])`.

| Form | Result |
|---|---|
| `'terraform_data.worker[\"example\"]'` — **the page's PowerShell row** | ❌ `Error parsing instance address: terraform_data.worker[\"example\"]` |
| `'terraform_data.worker["example"]'` — single quotes, plain inner quotes | ✅ prints the resource |
| `"terraform_data.worker[`"example`"]"` — double quotes, backtick-escaped | ✅ prints the resource |
| `cmd /c 'terraform state show terraform_data.worker[\"example\"]'` — **the page's cmd.exe row** | ✅ prints the resource |

!!! danger "The page's PowerShell guidance is stale"
    The page says PowerShell needs `'packet_device.worker[\"example\"]'`. On **PowerShell 7** the backslashes are passed through literally and Terraform rejects the address:

    ```
    Error parsing instance address: terraform_data.worker[\"example\"]

    This command requires that the address references one specific instance.
    ```

    Backslash-escaping inside single quotes is Windows PowerShell 5.1-era advice, from when native-command argument passing was different. On PowerShell 7 **single quotes are already literal**, so write the address exactly as Terraform prints it:

    ```powershell
    terraform state show 'terraform_data.worker["example"]'
    ```

    The page's **cmd.exe** row is correct — verified working through `cmd /c`. Only the PowerShell row is wrong.

!!! tip "Copy the address from `terraform state list`"
    `state list` prints `terraform_data.worker["example"]` in exactly the form `state show` accepts on PowerShell 7 and on POSIX shells. Wrap it in single quotes and nothing else. See [[tf-cmd-state-list]].

---
Related: [[tf-cmd-state-list]] — produces the addresses this command consumes. · [[tf-cmd-show]] — the machine-readable path this page redirects you to. · [[tf-state-refactor]] — uses `state show` to read the `id` needed for an `import` block. · [[tf-cli-inspect]] — the command group, and its human-versus-tooling framing. · [[tf-backend-local]] — the legacy `-state` flag.
