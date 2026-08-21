# `terraform state pull` command

> **Source:** [developer.hashicorp.com/terraform/cli/commands/state/pull](https://developer.hashicorp.com/terraform/cli/commands/state/pull)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest), behaviour verified on **v1.15.8**
> **Tags:** cli, state-pull, disaster-recovery, state-version, jq, powershell, encoding, utf-8, bom
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Disaster Recovery › `state pull` · v1.15.x*

Step two of the repair loop in [[tf-cli-state-recover]]. Read-only, and the only command in the family whose page is mostly about **text encoding**.

```
terraform state pull [options]
```

> "This command downloads the state from its current location, **upgrades the local copy to the latest state file version** that is compatible with locally-installed Terraform, and outputs the raw format to stdout."

## It is not a faithful copy

The upgrade step is not incidental, and the page draws the consequence itself:

> "You **cannot** use this command to inspect the Terraform version of the remote state, as it will **always be converted** to the current Terraform version before output."

**Verified on v1.15.8.** A local state file written by an older version, pulled with no other change:

```json
// before — the file on disk
{ "version": 4, "terraform_version": "1.9.0", "serial": 3, "outputs": {}, "resources": [] }
```

```json
// after — what `terraform state pull` printed
{ "version": 4, "terraform_version": "1.15.8", "serial": 3, "outputs": {}, "resources": [],
  "check_results": null }
```

Two rewrites in one command: `terraform_version` is stamped to the running binary, and a field the older format lacked (`check_results`) is materialised. So `state pull > backup.json` captures a **format-upgraded** state, not a byte copy of what the backend holds. For a genuine byte-level backup, take the automatic one the modifying commands write ([[tf-cmd-state-mv]]) or copy the object out of the backend directly.

`serial` and `lineage` are preserved, which is what makes the pull-edit-push loop legal at all — [[tut-cloud-state-api]] and [[tf-state-backends]] cover the `serial` bump that a hand-edited state then needs.

## Options, and what is missing from them

Only `-var` and `-var-file`, because the configuration is loaded to resolve the backend.

**No `-lock` flags and no backup.** Both absences say the same thing: this command reads. It is the counterpart of [[tf-cmd-state-list]] and [[tf-cmd-state-show]] in a section otherwise full of writers, and it confirms the forced-backup rule's boundary from [[tf-cmd-state]] — read-only subcommands write nothing.

Stated uses: "reading values out of state (potentially pairing this command with something like `jq`)", and "if you need to make manual modifications to state".

## The encoding note, and where it is wrong

> "Terraform state files must be in **UTF-8 format without a byte order mark (BOM)**. For PowerShell on Windows, use `Set-Content` to automatically encode files in UTF-8 format. For example, run `terraform state pull | Set-Content terraform.tfstate`."

The requirement is right and worth knowing — it is why a naive `terraform state pull > file` on Windows can produce a state file Terraform will not read back. The advice is **version-dependent**, and the page does not say which PowerShell it means.

Measured on this machine, writing the same content four ways:

| Shell | piped into `Set-Content` | redirected with `>` |
|---|---|---|
| **PowerShell 7.6.5** | UTF-8, no BOM ✅ (line endings normalised to CRLF) | UTF-8, no BOM ✅ (LF preserved) |
| **Windows PowerShell 5.1** | no BOM, but **ANSI, not UTF-8** ⚠️ | **UTF-16LE with a `FF FE` BOM** ❌ |

The non-ASCII test is the one that separates them. Writing `é` through `Set-Content`:

- PowerShell 7 → `C3 A9` — correct UTF-8.
- Windows PowerShell 5.1 → `E9` — the cp1252 byte, which is not UTF-8 at all.

So:

- **On PowerShell 6+** the advice is redundant. Both forms are already UTF-8 without a BOM; `Set-Content` merely rewrites line endings.
- **On Windows PowerShell 5.1** the advice is the *lesser* of two bad options. It does avoid the UTF-16LE BOM that plain redirection produces, and for a pure-ASCII state file that is enough — but any non-ASCII value in state (a tag, a description, a name) is written in the ANSI codepage, and the resulting file is not the UTF-8 the same paragraph requires. `-Encoding UTF8` does not fix it there either, since 5.1 writes UTF-8 **with** a BOM.

!!! tip "On 5.1, bypass the shell's encoding entirely"
    Write the bytes yourself rather than trusting a default that changed between PowerShell versions:

    ```powershell
    [System.IO.File]::WriteAllText("terraform.tfstate", (terraform state pull | Out-String), (New-Object System.Text.UTF8Encoding $false))
    ```

    The `$false` argument is the BOM flag. Verified on 5.1: the same `é` comes out as `C3 A9` with no BOM. On PowerShell 7 none of this is needed.

This is the third PowerShell instruction in this collection that does not hold on the shell in front of me — after the address-quoting rows in [[tf-cmd-state-show]] and [[tf-cmd-state-mv]], both verified broken on 7. The pattern across all three: **the docs' Windows advice is written for one PowerShell generation and labelled simply "PowerShell".**

---
Related: [[tf-cli-state-recover]] — the workflow this is step two of, and the only page that documents `state push` beside it. · [[tf-cmd-state]] — the family hub, its forced-backup rule, and its `grep`/`jq` design intent. · [[tut-cloud-state-api]] — the same read-modify-write loop against HCP, including the `serial` bump. · [[tf-cmd-state-mv]] · [[tf-cmd-state-show]] — the other two pages whose PowerShell rows were verified wrong. · [[tf-state]] — the state format and its version field, which this command rewrites on the way out.
