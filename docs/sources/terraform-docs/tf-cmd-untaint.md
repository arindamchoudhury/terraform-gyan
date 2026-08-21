# `terraform untaint` command

> **Source:** [developer.hashicorp.com/terraform/cli/commands/untaint](https://developer.hashicorp.com/terraform/cli/commands/untaint)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest)
> **Tags:** cli, untaint, taint, replace-flag, state, locking, legacy-flags, allow-missing
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Forcing Re-creation (Tainting) › `untaint` · v1.15.x*

The surviving half of the taint pair. `taint` is deprecated ([[tf-cli-state-taint]]); `untaint` is not, because the marker it removes is one **Terraform sets by itself**. This page is the clearest statement of that asymmetry, and it is also the fullest description of the tainted marker anywhere in the captured docs.

## What tainted means, per this page

> "Terraform has a marker called **tainted** which it uses to track that an object **might** be damaged and so a future Terraform plan **ought to** replace it."

Hedged in both halves — *might*, *ought to* — because the marker records a suspicion, not a finding.

The auto-tainting trigger is stated more narrowly here than one level up:

> "Terraform automatically marks an object as 'tainted' if an error occurs during a **multi-step 'create' action**, because Terraform can't be sure that the object was left in a fully-functional state."

[[tf-cli-state-taint]] gives two triggers — a complex object "partially created in the remote system", and a failed provisioner step. This page gives one that arguably covers both, since a provisioner is a step of the create action. Read together: **the marker is set when a create was interrupted partway**, whatever the step was.

## What the command does

> "This command will **not modify any real remote objects**, but will **modify the state** in order to remove the tainted status."

Same direction-of-effect sentence [[tf-cmd-refresh]] uses, and the reason both commands sit in this section: state moves, infrastructure does not.

```
terraform untaint [options] address
```

The address "identifies a particular **resource instance** which is currently tainted" — the strict parser, like [[tf-cmd-state-show]] and unlike `state list`'s partial-address filter. Its own example carries an instance key, `aws_instance.example[0]`, which is [[tf-resource-addressing]]'s `[N]` form.

!!! tip "You do not have to re-taint to change your mind back"
    > "If you remove the taint marker from an object but then later discover that it was degraded after all, you can create and apply a plan to replace it **without first re-tainting the object**."

    ```shell
    terraform apply -replace="aws_instance.example[0]"
    ```

    This is why the deprecation of `taint` costs nothing. The only reason to write a taint by hand was to schedule a replacement, and `-replace` schedules one directly. `untaint` survives because it answers a question `-replace` cannot: *Terraform thinks this is damaged and I disagree.*

## Options

| Option | Effect |
|---|---|
| `-allow-missing` | Succeed with **exit code 0 even if the resource is missing**. Still errors on other failures, "such as if there is a problem reading or writing the state". |
| `-lock=false` | Don't hold a state lock. "Dangerous if others might concurrently run commands against the same workspace." |
| `-lock-timeout=DURATION` | Retry acquiring the lock for a period first; `3s` syntax. |
| `-no-color` | Drop terminal formatting sequences. |
| `-ignore-remote-version` | **HCP Terraform CLI integration or the `remote` backend only.** |
| `-state`, `-state-out`, `-backup` | **Local backend only**, and named *legacy* options. |

Three of these are worth pulling out.

**`-allow-missing` makes the command idempotent for scripts.** Untainting something already gone is normally an error; this turns it into a no-op success. The exit-status carve-out is precise — it only forgives the missing resource, not a broken state read.

**Locking applies, so this is a real state write.** `-lock` / `-lock-timeout` are here for the same reason they are on `apply` ([[tf-state-locking]]) — the command takes the lock because it modifies state.

!!! warning "The backup here is optional and legacy — the forced-backup rule does not reach it"
    [[tf-cmd-state]] says every `terraform state` subcommand that modifies state **must** write a backup, and cannot be told not to. `untaint` is not a `state` subcommand. Its `-backup` is grouped with `-state`/`-state-out` as a **legacy, local-backend-only** flag that [[tf-backend-local]] records the docs as having disowned outright: *"legacy features that we've preserved for backward compatibility but that we no longer recommend."*

    So a state modification made through `untaint` gets **no automatic backup at all** on a remote backend. That is the same hole already noted for the `removed`/`moved` path, and it widens the rule: the forced backup is a property of the `terraform state` family, not of state modification.

`-ignore-remote-version` dates to **0.14.1**, alongside the remote-workspace version compatibility checks it opts out of ([[feature-history]]).

---
Related: [[tf-cli-state-taint]] — the section overview; where the deprecation of `taint` is stated with its mechanism. · [[tf-cmd-refresh]] — the other command in this collection that writes state and touches nothing remote. · [[tf-cmd-state]] — the forced-backup rule this command falls outside of. · [[tf-backend-local]] — what *legacy* means for `-state`/`-backup`, and why they do nothing on other backends. · [[tf-state-locking]] — why a state-writing command carries `-lock` flags. · [[tf-resource-addressing]] — the instance address this command demands.
