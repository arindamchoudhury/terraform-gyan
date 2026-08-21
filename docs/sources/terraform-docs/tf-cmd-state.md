# `terraform state` Commands

> **Source:** [developer.hashicorp.com/terraform/cli/commands/state](https://developer.hashicorp.com/terraform/cli/commands/state)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest)
> **Tags:** cli, state, subcommands, backups, remote-state, piping, state-push
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › `state` · v1.15.x*

The hub for the `terraform state` subcommand family. Four short sections, and two of them state rules that apply to **every** subcommand rather than to any one of them — which is the reason to read it at all, since neither rule is repeated on the individual command pages.

## Usage

```
terraform state <subcommand> [options] [args]
```

The framing is the same argument [[tf-state]] makes: use the commands "instead modifying the state directly" (the page's own missing *of*).

The subcommands it lists:

| Subcommand | Captured |
|---|---|
| `state list` | [[tf-cmd-state-list]] |
| `state mv` | [[tf-cmd-state-mv]] |
| `state pull` | [[tf-cmd-state-pull]] |
| `state replace-provider` | [[tf-cmd-state-replace-provider]] |
| `state rm` | no |
| `state show` | [[tf-cmd-state-show]] |

!!! warning "The hub omits `state push`"
    Six subcommands are listed. **`terraform state push` is not among them**, although the command exists, has its own reference page — *"uploads a local state file to remote state or a local state"* — and sits in the sidebar under *Disaster Recovery* next to `state pull`, which **is** listed here.

    So the one subcommand that **overwrites** a state file wholesale is missing from the index of state subcommands. [[tut-cloud-state-api]] does the equivalent operation through the HCP API instead, and [[tf-state-refactor]] pairs `pull` with a redirect to a backup file rather than with `push`. Read the sidebar, not this list, when you need the full set.

## Backups — the rule worth knowing

> "All `terraform state` subcommands that modify the state write backup files. The path of these backup file can be controlled with `-backup`."

> "Note that backups for state modification **can not be disabled**. Due to the sensitivity of the state file, Terraform **forces** every state modification command to write a backup file. You'll have to remove these files manually if you don't want to keep them around."

Three consequences.

**Read-only subcommands write nothing.** `list` and `show` are named as the read-only case, so a `state list` leaves no residue.

**The backup is not optional and not silent.** [[tf-cli-state]] tells you to keep backups before modifying state by hand; this page says the CLI already writes one for you on this particular path. That is a narrower guarantee than it looks — it covers `terraform state <subcommand>` only. A `removed` block or a `moved` block goes through `apply`, not through these commands, so the forced backup does not apply there.

**They accumulate.** Nothing cleans them up, and each holds a full copy of a file the same page calls sensitive. A repository or a CI working directory can end up with several complete state copies from one afternoon of surgery.

!!! danger "`-backup` on PowerShell"
    Write it as `-backup path\to\file` or quote it. PowerShell splits an unquoted `-flag=value` into separate arguments, which is the same trap the address quoting in [[tf-cmd-state-show]] runs into — and here the consequence is a backup written somewhere other than where you meant.

!!! note "How this sits next to the manual backup step"
    [[tf-state-refactor]] instructs you to run `terraform state pull > terraform.tfstate.backup` before a migration, which was already flagged there for reusing the local backend's own automatic backup filename. The `state mv` that follows writes **its own** backup as well.

    **Measured afterwards** ([[tf-cmd-state-mv]]): the automatic one is named `terraform.tfstate.<unix-timestamp>.backup`, so it does not overwrite the manual file or any earlier automatic one. The three kinds of backup accumulate rather than collide — which makes the *"remove these files manually"* line above the operative half of the rule. The refactor page's filename problem is unchanged on its own terms: writing by hand to `terraform.tfstate.backup` still collides with the local backend's file.

## Remote state

> "The Terraform state subcommands all work with remote state just as if it was local state. Reads and writes may take longer than normal as **each read and each write do a full network roundtrip**."

And: "backups are still written **to disk**". So operating on a remote state file leaves local copies of it behind on whatever machine ran the command. Worth pairing with [[tf-state-backends]] on what a backend is supposed to guarantee, and with [[gitlab-tf-state]] on who can read the file — neither guarantee survives a backup sitting in a CI runner's workspace.

## Command-line friendly

The output shape is deliberate: designed for "Unix command-line tools such as `grep`, `awk`, and similar PowerShell commands", with piping recommended for "advanced filtering and modification". That is the design intent behind [[tf-cmd-state-list]]'s defined sort order — a stable, greppable line format is only useful if the order is specified.

---
Related: [[tf-cli-state]] — the section index above this page; this one adds the rules that span the family. · [[tf-cmd-state-list]] · [[tf-cmd-state-show]] — the two subcommands captured so far, both read-only and so both backup-free. · [[tf-cmd-state-mv]] — the first subcommand captured that actually writes, and where the backup rule was measured. · [[tut-state-cli]] — `state mv` and the rest of the family in one narrative. · [[tf-resource-addressing]] — the grammar every one of these subcommands parses.
