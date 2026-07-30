# State Storage and Locking

> **Source:** [developer.hashicorp.com/terraform/language/state/backends](https://developer.hashicorp.com/terraform/language/state/backends)
> **Added:** 2026-07-29
> **Source updated:** undated language reference; captured 2026-07-29 against v1.15.x (latest)
> **Tags:** state, backends, state-locking, state-pull, state-push, lineage, serial, sensitive-data
> **Type:** documentation

*Developer › Terraform › Configuration Language › State › Manage state in remote backends · v1.15.x*

Sidebar calls it "Manage state in remote backends"; the page's own title is "State Storage and Locking". Short. Defines what a backend is responsible for, then spends most of its length on `state push` safety. Sibling of [[tf-state]] and [[tf-state-purpose]].

The one-line definition: **backends store state and provide an API for state locking. Locking is optional.**

Remote storage is transparent to the CLI. Commands including `terraform console` and the `terraform state` operations "continue to work as if the state was local."

!!! info "The page's command list is stale"
    It names `terraform taint` among the commands that keep working. That command has been **deprecated since v0.15.2** — [its own CLI docs](https://developer.hashicorp.com/terraform/cli/commands/taint) open with "This command is deprecated. Instead, add the `-replace` option to your `terraform apply` command." The reason given there is worth knowing: `taint` writes the mark into state immediately, so another user can build a plan against the tainted object before anyone reviews the effect. `apply -replace` puts the replacement in the plan where you can see it first.

    The Terraform 1.15.8 CLI help for `taint` carries **no** deprecation notice, so the command reads as current if you only run `terraform taint -help`.

## State storage

Backends decide where state lives. The `local` (default) backend writes a JSON file on disk. The Consul backend writes into Consul. Both happen to provide locking — local through system APIs, Consul through locking APIs. TID Ch6 §6.4 covers the full built-in catalog and the argument for picking by what your team already runs.

!!! success "A remote backend keeps state off local disk entirely"
    > "When using a non-local backend, Terraform will not persist the state anywhere on disk except in the case of a non-recoverable error where writing the state to the backend failed."

    The page frames this as "a major benefit": with sensitive values in state, a remote backend means that state is never written to the operator's disk. This is a concrete answer to the §6.2.2 security problem that [[tf-manage-sensitive-data]] and [[infisical-terraform-secrets]] describe. It doesn't encrypt anything, but it removes one whole copy of the plaintext — the laptop.

**The exception matters.** If persisting to the backend fails, Terraform writes state locally to prevent data loss. Recovery is manual: once the error is fixed, the operator must push that local state to the remote backend. Nothing does it automatically. A run that ends this way leaves a plaintext state file on the machine that the "never persisted to disk" guarantee otherwise rules out.

## Manual pull and push

`terraform state pull` loads remote state and writes it to stdout. Save it to a file or pipe it onward. This is the command behind reading another configuration's state from the CLI.

`terraform state push` writes state back. The page's own words: "extremely dangerous and should be avoided if possible." It overwrites the remote state. It exists for manual fixups.

Two guards run on a push:

- **Differing lineage** — lineage is a unique ID assigned to a state when it is created. A different lineage means the two states were created at different times, so you are very likely writing over a *different* state. Rejected.
- **Higher serial** — serial increases monotonically. If the destination's serial is higher, changes have happened since the snapshot you are pushing. Rejected.

`-force` bypasses both. Even then the page recommends taking a backup with `terraform state pull` first.

!!! warning "The lineage guard is narrower than this page implies"
    Read alongside TID Ch6 §6.3.3, where the check was traced in the Terraform 1.15.8 source. Two escape hatches the docs don't mention: an **empty existing state is always overwritable** regardless of lineage, and a **missing** lineage on either side yields `SnapshotLegacy`, which is also allowed as the pre-0.9 compatibility path. The check also only runs where two independently obtained snapshots meet — `state push`, backend migration, applying a saved plan, remote-backend conflict detection — never during a routine plan or apply.

    So "Terraform will not allow this" is true of the push path specifically. It is not a general guarantee that two configurations can't point at the same state file.

Ch6 §6.5.4 adds the better habit for restoring an older backup: rather than reaching for `-force`, bump the backup's `serial` by 1 so the push succeeds with every other safety check still live.

## State locking

Backends are responsible for supporting locking "if possible." Not all of them do, and each backend's own documentation states whether it does. The page defers the mechanics to the dedicated Locking page, captured in [[tf-state-locking]]: locking is automatic and silent, a failure to acquire stops the run, and `force-unlock` needs the lock ID as a nonce.

---
Related: [[tf-state-locking]] — the mechanics this page defers to. [[tf-state]] — the section overview; this page is the storage half of what that one summarizes. [[tf-state-purpose]] — argues *why* syncing and locking matter for teams; this page is the mechanism. [[tf-remote-state-data]] — reads root outputs from these same backends, and carries the full-snapshot access warning. [[tf-manage-sensitive-data]] — the sensitive-values problem that "never persisted to disk" partially addresses. [[tf-cli-commands]] — where `state pull`/`state push` sit in the command index.
