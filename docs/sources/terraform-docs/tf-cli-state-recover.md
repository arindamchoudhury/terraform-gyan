# Recover State from Backup Overview

> **Source:** [developer.hashicorp.com/terraform/cli/state/recover](https://developer.hashicorp.com/terraform/cli/state/recover)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest)
> **Tags:** cli, state, disaster-recovery, force-unlock, state-pull, state-push, backups, section-index
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Disaster Recovery › Overview · v1.15.x*

Three sentences and three commands. The section index for the case where an earlier state operation went wrong — and the page that names what the rest of this collection's forced backups are *for*.

## What the section is for

> "…recovering Terraform state from a backup after a disaster, such as **an accident when performing other state manipulation actions**."

That closes a loop the family hub opens. [[tf-cmd-state]] says every modifying `state` subcommand is forced to write a backup and you must delete them yourself; this page is the reason the rule exists. The backups measured in [[tf-cmd-state-mv]] — `terraform.tfstate.<unix-timestamp>.backup`, one per operation, accumulating — are the inputs to this workflow.

## The workflow

**1. Unlock**, if a run died holding the lock:

> "You may need to unlock Terraform when a `terraform apply` or other process unexpectedly terminates before Terraform can release its lock on the state backend. Unlocking Terraform overrides protections that prevent two processes from modifying state at the same time. **We do not recommend unlocking until you determine what caused the lock to get stuck.**"

Same position [[tf-cmd-force-unlock]] and [[tf-state-locking]] take, stated as a sequencing rule: diagnose first, unlock second. The command itself enforces this structurally by demanding the `LOCK_ID` nonce, which you can only get from the error Terraform printed.

**2. Read** — `terraform state pull` "to read the state files from the configured backend".

**3. Write** — `terraform state push` "to write state files to the configured backend".

So the documented repair loop is **pull → fix by hand → push**, with the fix step conspicuously undescribed. [[tut-cloud-state-api]] is the same loop against HCP Terraform's API instead of the CLI, and it supplies the part this page omits: a hand-edited state must have its **`serial` bumped** or the backend rejects it as stale, plus the guards [[tf-state-backends]] describes.

!!! note "This is where `state push` is documented — the family hub never lists it"
    [[tf-cmd-state]] enumerates six subcommands and leaves `state push` out, despite listing `state pull` beside it. Here both appear, as steps two and three of the only workflow either one exists for.

    Practical consequence: a reader who navigates by the `terraform state` command index will not learn that `push` exists. They have to arrive through *Disaster Recovery*.

## Page flaw

*"overrides protectionsthat prevent"* — a missing space, in the one sentence on the page carrying a real warning.

---
Related: [[tf-cmd-force-unlock]] — step one, its `LOCK_ID` requirement, and why `-force` removes only the prompt. · [[tf-state-locking]] — what the lock protects and why unlocking someone else's is not yours to do. · [[tf-cmd-state]] — the hub whose forced backups feed this section, and which omits `state push`. · [[tf-cmd-state-mv]] — where the backup filenames were measured. · [[tut-cloud-state-api]] — the same pull-fix-push loop through HCP's API, including the `serial` bump this page does not mention. · [[tf-cli-state]] — the parent index; *Recover state from backup* is its fifth link.
