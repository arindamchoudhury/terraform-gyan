# `terraform show` command

> **Source:** [developer.hashicorp.com/terraform/cli/commands/show](https://developer.hashicorp.com/terraform/cli/commands/show)
> **Added:** 2026-07-30
> **Source updated:** undated CLI reference; captured 2026-07-30 against v1.15.x (latest)
> **Tags:** cli, show, json, plan-file, state, schema-version, sensitive
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Inspecting Infrastructure › `show` · v1.15.x*

Renders a state or plan file. Short page whose useful content is the `-json` section: **what the JSON contains differs by input**, and there is a schema-freshness precondition most people never hit until it bites.

## Usage

```
terraform show [options] [file]
```

"You may use `show` with a path to either a Terraform state file or plan file. If you don't specify a file path, Terraform will show the latest state snapshot."

| Option | Effect |
|---|---|
| `-no-color` | Disable coloring. |
| `-json` | Machine-readable output from a state or plan file. Requires **v0.12 or later**. |

## `-json` returns different things for state and for plans

> "For Terraform **state** files, including when no path is provided, `terraform show -json` shows a JSON representation of the **state**."

> "For Terraform **plan** files, `terraform show -json` shows a JSON representation of the **plan, configuration, and current state**."

Three documents out of one file, not one. That matches the plan file's physical layout — the zip verified in [[tf-backend-configure]] contains `tfplan`, `tfstate`, `tfstate-prev`, and `tfconfig/` as separate entries.

**Verified on v1.15.8**, comparing top-level keys from the emulator lab:

```
# terraform show -json          (state)
['format_version', 'terraform_version', 'values']

# terraform show -json demo.tfplan   (plan)
['applyable', 'complete', 'configuration', 'errored', 'format_version',
 'output_changes', 'planned_values', 'prior_state', 'resource_changes',
 'terraform_version', 'timestamp']
```

`configuration` and `prior_state` are the extra two the page promises. Anything parsing plan JSON should target `resource_changes`; anything parsing state JSON gets `values` and nothing else.

The format itself is versioned (`format_version`) and specified separately in *JSON Output Format*, which is what makes this the supported machine interface rather than the state file — the point [[tf-state]] and [[tf-cli-inspect]] both make.

!!! danger "`-json` prints sensitive values in plain text"
    > "When using the `-json` command-line flag, any sensitive values in Terraform state will be displayed in plain text."

    Same rule as [[tf-cmd-output]]'s flags. `sensitive = true` is a display convenience in human output only; every machine-readable path bypasses it.

## The schema-freshness precondition

The paragraph worth reading twice:

> "If you updated providers that contain new schema versions since the state was written, **upgrade the state before** so that Terraform can display it with `show -json`. If you are viewing a plan, it must be created **without `-refresh=false`**. If you are viewing a state file, run `terraform refresh` first."

So `show -json` is not unconditionally available. A state written by an older provider schema, then read after a provider upgrade, needs the state brought forward first. Two consequences:

- A plan you deliberately made cheap with `-refresh=false` may not be renderable as JSON. That is a hidden cost of the flag [[05-terraform-plan]] warns about for a different reason (planning on stale state).
- The remedy the page names for a state file is a refresh.

!!! warning "The remedy names a deprecated command"
    This page says "run `terraform refresh` first". Its own CLI reference deprecates that command outright and says to use `-refresh-only` on `plan`/`apply` instead ([[tf-cmd-refresh]]). The modern equivalent is:

    ```shell
    terraform apply -refresh-only
    ```

    Same effect, with a review prompt instead of an implicit auto-approve. Treat the page's wording as stale phrasing rather than a reason to reach for the deprecated command.

---
Related: [[05-terraform-plan]] — TID Ch5 on reviewing saved plans with `show`, and on `-refresh=false`. · [[tf-cmd-refresh]] — the deprecated command this page still recommends. · [[tf-cmd-output]] — the same plain-text-on-`-json` rule for outputs. · [[tf-cli-inspect]] — the command group and its integration-surface framing. · [[tf-backend-configure]] — the verified physical contents of a plan file, which the plan JSON mirrors.
