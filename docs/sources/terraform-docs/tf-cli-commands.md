# Terraform CLI Overview (command index)

> **Source:** [developer.hashicorp.com/terraform/cli/commands](https://developer.hashicorp.com/terraform/cli/commands)
> **Added:** 2026-07-07
> **Source updated:** docs for v1.15.x (latest); captured 2026-07-07
> **Tags:** cli, commands, reference, chdir, autocomplete, checkpoint, telemetry
> **Type:** documentation

The top-level reference for the `terraform` command — the full subcommand surface plus the global options and CLI behaviors (`-chdir`, tab-completion, Checkpoint telemetry) that aren't tied to any one subcommand. `terraform` with no args prints this same list. This is the index the learning path's B3 "complete command surface" callout points at.

## The command surface

`terraform [global options] <subcommand> [args]`. Inline help for any command: `terraform <cmd> -help`.

**Main commands** (the primary workflow):

| Command | Purpose |
|---|---|
| `init` | Prepare the working directory for other commands (download providers/modules, configure backend). |
| `validate` | Check whether the configuration is valid (syntax + internal consistency, no remote calls). |
| `plan` | Show changes required by the current configuration. |
| `apply` | Create or update infrastructure. |
| `destroy` | Destroy previously-created infrastructure. |

**All other commands** (less common / advanced):

| Command | Purpose |
|---|---|
| `console` | REPL for trying Terraform expressions against live values. |
| `fmt` | Reformat configuration to the canonical style. |
| `force-unlock` | Release a stuck state lock on the current workspace. |
| `get` | Install or upgrade the modules a config declares. |
| `graph` | Generate a **Graphviz** graph of the steps in an operation (the dependency graph). |
| `import` | Associate existing infrastructure with a Terraform resource in state. |
| `login` | Obtain and save credentials for a remote host (HCP Terraform / private registry). |
| `logout` | Remove locally-stored credentials for a remote host. |
| `metadata` | Metadata-related commands (e.g. `metadata functions` — the built-in function signatures as JSON). |
| `modules` | Show all modules declared in the working directory (key, source, version). |
| `output` | Show output values from the root module. |
| `providers` | Show the providers a configuration requires (and `providers lock`/`mirror`/`schema` subcommands). |
| `refresh` | Update state to match remote systems. (Superseded in spirit by `apply -refresh-only`.) |
| `show` | Show the current state or a saved plan (`-json` for machine output). |
| `state` | Advanced state management (`list`/`show`/`mv`/`rm`/`pull`/`push`/`replace-provider`). |
| `taint` | Mark a resource instance as not fully functional. **Deprecated** — use `apply -replace=ADDR`. |
| `untaint` | Remove the `tainted` mark. **Deprecated** — use `apply -replace`. |
| `version` | Show the current Terraform version (and whether a newer one is available). |
| `workspace` | CLI workspace management (`list`/`select`/`new`/`delete`). |

> The list your CLI prints may differ by version. `taint`/`untaint` still appear but are the deprecated path; prefer `-replace`.

## Global options (before the subcommand)

- `-chdir=DIR` — switch working directory before running the subcommand.
- `-help` — help output (or help for a named subcommand).
- `-version` — alias for the `version` subcommand.

### `-chdir` details

`terraform -chdir=environments/production apply` changes Terraform's working directory *before* running the subcommand, so every file it would read/write in the CWD is read/written in `DIR` instead. Cleaner than `cd`-ing in automation scripts. Two exceptions still use the *original* directory:

1. **CLI Configuration** settings are processed before `-chdir` is applied (they're not subcommand-specific).
2. **`path.cwd`** in configuration returns the original working directory, not the overridden one. Use **`path.root`** for the root module directory.

## Shell tab-completion

For `bash` or `zsh`:

```shell
$ terraform -install-autocomplete    # add completion hooks to your shell profile
$ terraform -uninstall-autocomplete  # remove them
```

Restart the shell (or re-source its profile) to activate. Covers all command names and some arguments.

## Checkpoint (upgrade + security-bulletin checks)

Terraform CLI pings HashiCorp's **Checkpoint** service to check for new versions and critical security bulletins (this is what surfaces the "a newer version is available" line in `terraform version`). Only anonymous, non-identifying info is sent (an anonymous ID to de-duplicate warnings). Both the signature and Checkpoint itself are optional.

**Disabling it** (relevant for airgapped/locked-down/privacy-sensitive environments):

- `CHECKPOINT_DISABLE=1` (any non-empty value) — env var, disables Checkpoint for **all** HashiCorp products.
- CLI-config file settings:
    - `disable_checkpoint = true` — disable Checkpoint calls entirely.
    - `disable_checkpoint_signature = true` — still check for bulletins, but don't send the anonymous signature.

---
Related: the reference behind [[tf-install-cli]]'s install step and the create/manage/destroy loop in [[tf-aws-create]] / [[tf-aws-manage]] / [[tf-aws-destroy]]. Every `terraform <cmd>` those tutorials run is one row above. Feeds learning-path **B3** (command surface) and touches I6 (`force-unlock`), I7 (`state`, `import`, `refresh`), A4 (`login`/`logout`), E5 (CLI config, Checkpoint).
