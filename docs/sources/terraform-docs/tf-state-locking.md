# State Locking

> **Source:** [developer.hashicorp.com/terraform/language/state/locking](https://developer.hashicorp.com/terraform/language/state/locking)
> **Added:** 2026-07-30
> **Source updated:** undated language reference; captured 2026-07-30 against v1.15.x (latest)
> **Tags:** state, state-locking, lock, force-unlock, lock-id, backends
> **Type:** documentation

*Developer › Terraform › Configuration Language › State › Locking · v1.15.x*

The page [[tf-state-backends]] defers to for locking mechanics. Very short. Two ideas: locking is automatic and invisible, and `force-unlock` is the escape hatch you should almost never need.

## Automatic, silent, and blocking

> "If supported by your backend, Terraform will lock your state for all operations that could write state. This prevents others from acquiring the lock and potentially corrupting your state."

Three properties worth separating.

- **Scope: every operation that could write state**, not just `apply`. `plan` is in scope too — it carries `-lock` and `-lock-timeout` flags of its own.
- **Silence is the normal case.** "You do not see any message that it happens." No output does not mean no locking.
- **Failure is fatal, not a warning.** "If state locking fails, Terraform does not continue."

The only time locking surfaces in output is when it is slow: "If acquiring the lock takes longer than expected, Terraform outputs a status message."

`-lock=false` disables it "for most commands", and the page says plainly "we do not recommend it." That matches TID Ch5 §5's position in [[05-terraform-plan]]: the one defensible case is a speculative plan you will never apply.

!!! note "The retry knob is on the commands, not here"
    This page never mentions `-lock-timeout`, so read it beside the command docs. Verified on the `terraform plan` reference (2026-07-30):

    > "Unless locking is disabled with `-lock=false`, instructs Terraform to retry acquiring a lock for a period of time before returning an error. The duration syntax is a number followed by a time unit letter, such as `"3s"` for three seconds."

    So the choice under contention is three-way, not two: fail immediately (default), wait with `-lock-timeout`, or skip the lock entirely with `-lock=false`. Only the middle one is safe in a team.

## Backend support is not universal

> "Not all backends support locking. The documentation for each backend includes details on whether it supports locking or not."

The page names no backends. [[tf-state-backends]] gives the definition this rests on — a backend stores state and *optionally* provides a locking API — and the two examples it does name (`local` via system APIs, Consul via locks with health checks). For S3 specifically, locking no longer needs a DynamoDB table: `use_lockfile = true` since Terraform 1.11 and OpenTofu 1.10 (see [[feature-history]], [[06-state-management]]).

## Force unlock

`terraform force-unlock` manually releases the lock "if unlocking failed."

> "Be very careful with this command. If you unlock the state when someone else is holding the lock it could cause multiple writers."

The stated boundary: **only unlock your own lock, and only when automatic unlocking failed.** Not a tool for clearing someone else's stuck run.

The guard rail is the lock ID.

> "the `force-unlock` command requires a unique lock ID. Terraform will output this lock ID if unlocking fails. This lock ID acts as a nonce, ensuring that locks and unlocks target the correct lock."

Calling it a **nonce** is the useful detail. The ID is not a name you can look up and reuse — it identifies one specific lock acquisition. So you cannot force-unlock blind, and an ID from an older failure will not release the current lock.

---
Related: [[tf-state-backends]] — the page that defers here; defines locking as an optional backend responsibility. · [[tf-state-purpose]] — argues *why* teams need syncing and locking; this is the mechanism. · [[tf-cli-commands]] — lists `force-unlock` in the command catalogue. · [[05-terraform-plan]] — TID's take on `-lock=false` and the speculative-plan exception.
