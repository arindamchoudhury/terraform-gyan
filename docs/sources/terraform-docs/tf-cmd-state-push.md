# `terraform state push` command

> **Source:** [developer.hashicorp.com/terraform/cli/commands/state/push](https://developer.hashicorp.com/terraform/cli/commands/state/push)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest), behaviour verified on **v1.15.8** and against the source at tag `v1.15.8`
> **Tags:** cli, state-push, disaster-recovery, lineage, serial, force, safety-checks, backups, source-verified
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Disaster Recovery › `state push` · v1.15.x*

The last step of the repair loop, the most destructive command in the collection, and the one the family hub never lists ([[tf-cmd-state]], [[tf-cli-state-recover]]).

> "The `terraform state push` command uploads a local state file to remote state or a local state. **We only recommend using this command when you must manually modify the remote state.**"

```
terraform state push [options] PATH
```

`PATH` may be `-`, in which case the state is read from stdin: "loaded completely into memory and **verified** prior to being written". The binary is more precise — "Data from stdin is **not streamed** to the backend: it is loaded completely (until pipe close), verified, and then pushed."

## The two safety checks, verified

Both documented checks fire, and both were reproduced on **v1.15.8** against a destination state holding one resource:

| Attempt | Result |
|---|---|
| Push lineage `bbbb…` over lineage `aaaa…` | `Failed to write state: cannot import state with lineage "bbbb…" over unrelated state with lineage "aaaa…"` — **exit 1** |
| Push `serial 2` over `serial 5` | `Failed to write state: cannot import state with serial 2 over newer state with serial 5` — **exit 1** |
| Either, with `-force` | Silent success, **exit 0**. The destination went from serial 5 to serial 2 — a downgrade, applied without a word. |

A successful push prints **nothing**. The only signal is the exit status.

> "Both of these safety checks can be disabled with the `-force` flag. This is not recommended. If you disable the safety checks and are pushing state, the destination state **will be overwritten**."

!!! warning "Three exemptions the page does not mention"
    Chased into the source after the checks failed to fire on a first test. `statemgr.CheckValidImport` ([`internal/states/statemgr/migrate.go`](https://github.com/hashicorp/terraform/blob/v1.15.8/internal/states/statemgr/migrate.go), tag `v1.15.8`, the same version as the binary tested) returns early in three cases, so **no `-force` is needed to bypass the checks** in any of them:

    1. **The destination state is empty.** *"It's always okay to overwrite an empty state, regardless of its lineage/serial."* A state file with no resources counts — that is why an unrelated lineage and a lower serial both pushed cleanly in the first test, and it took reading the source to explain it rather than concluding the checks were broken on the local backend.
    2. **The destination is a legacy state** with no lineage — `SnapshotLegacy` → "anything goes".
    3. **Same lineage, same serial, identical content** is allowed; same lineage and serial with *different* content is the one remaining error — *"cannot overwrite existing state with serial N with a different state that has the same serial"*.

    Practical form of exemption 1: pushing into a workspace whose state has been emptied — say by a `destroy`, or by an earlier bad push — is unguarded. The checks protect state that has something in it.

!!! danger "`state push` writes no backup"
    [[tf-cmd-state]] says *"All `terraform state` subcommands that modify the state write backup files"* and that this "can not be disabled". **`state push` does not.** Verified on the local backend: an accepted push left no `terraform.tfstate.*.backup`, where a `state mv` in the same conditions writes one every time ([[tf-cmd-state-mv]]).

    The source agrees structurally: `internal/command/state_push.go` at `v1.15.8` contains **no reference to a backup path at all**, while `state_mv.go` parses and threads one through.

    So the command that overwrites a whole state file wholesale is the one member of the family that keeps no copy of what it replaced. Take your own copy first — and note from [[tf-cmd-state-pull]] that `terraform state pull` gives you a **format-upgraded** copy rather than the original bytes.

## Options

| Option | Notes |
|---|---|
| `-force` | Disables both safety checks. See above for the cases where they were never applied in the first place. |
| `-lock=false`, `-lock-timeout=0s` | **Documented only in the binary's help; the web page omits both**, despite this being a write. |
| `-var`, `-var-file` | The configuration is loaded to resolve the backend. |
| `-ignore-remote-version` | HCP Terraform CLI integration or the `remote` backend only. |

The binary also states a scope caveat the web page leaves out: "This command works with local state (it will overwrite the local state), but is **less useful for this use case**."

!!! bug "The encoding example is `state pull`'s, pasted"
    The UTF-8/BOM note is duplicated verbatim from [[tf-cmd-state-pull]] — including its example, which here reads `terraform state push | Set-Content terraform.tfstate`.

    That command is nonsense for `push`: it takes a **`PATH` argument**, not stdin-by-default, and a successful run prints nothing, so the pipe carries an empty stream into `Set-Content` and truncates the state file. The sensible form is the reverse direction — `terraform state pull | Set-Content terraform.tfstate`, then `terraform state push terraform.tfstate`.

    The encoding requirement itself still applies to the file you push, with the PowerShell-version caveats measured in [[tf-cmd-state-pull]].

---
Related: [[tf-cli-state-recover]] — the workflow this completes, and the only index page that lists this command. · [[tf-cmd-state-pull]] — the read half, and the source of the shared encoding note. · [[tf-cmd-state]] — the hub whose forced-backup claim this command breaks, and which omits it entirely. · [[tut-cloud-state-api]] — the HCP equivalent, where the `serial` bump this page's checks enforce is done by hand. · [[tf-state-backends]] — what a backend guarantees about the state it holds. · [[tf-state]] — `lineage` and `serial`, the two fields the checks compare.
