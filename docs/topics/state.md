# State

> **Sources:** Hafner, *Terraform in Depth* Ch6 (and Ch2 §2.3.1) · Brikman, *Terraform: Up & Running* Ch3 · HCDocs [[tf-state]], [[tf-state-purpose]], [[tf-state-backends]], [[tf-state-locking]], [[tf-remote-state-data]] · [[terraform-intro]]

## In one paragraph

State is the record that binds a `resource` block in your configuration to an object a provider actually created. Terraform does not discover what it owns by scanning the cloud; it remembers, and a plan is a three-way comparison between the configuration, that memory, and reality. Everything difficult about Terraform at team scale follows from that one file being **shared, mutable, and full of plaintext secrets**: it has to live somewhere everyone can reach, it has to be locked so two runs cannot race, and it has to be split so one mistake cannot reach everything. The two books arrive at the same conclusions from opposite ends — TID from what state *is*, TUR from what having state *costs you* — and the fastest-moving part of the topic is the part both of them teach as settled.

## Key concepts (cross-source)

- **State is a binding, not a cache.** [[tf-state]] calls the resource-to-object mapping the primary purpose, and everything else secondary. TID §6.1 splits the rest into three named jobs — reduced complexity, performance, and state-only resources — while [[tf-state-purpose]] adds the one that decides behaviour after you delete code: **retained dependencies**, which are what order a destroy once the configuration no longer describes the relationships. TUR compresses all of it into one sentence, and it is the most quotable version: a plan is *"a diff between the code on your computer and the infrastructure deployed in the real world, as discovered via IDs in the state file."*
- **The attribute cache is the optional part.** The IDs must be in state; the attributes beside them are a performance convenience that a refresh re-reads. Worth knowing because it explains why `-refresh=false` is a speed knob with a correctness cost, and why stale attributes are a normal condition rather than corruption.
- **`lineage` and `serial` are the write guards.** TID §6.3.3 dissects them; [[tf-state-backends]] explains what they gate — `terraform state push` checks both before overwriting a remote snapshot. TUR shows them in its JSON dump without explaining them, which is a fair division of labour.
- **The file format is a private API.** Both books say so. Only the docs say what to use instead: `terraform show -json` and `terraform output -json` are the supported machine formats precisely because the file layout may change between versions ([[tf-cli-inspect]]).
- **Backends do two jobs, and the second is optional.** A backend stores state; it *may* also provide locking ([[tf-state-backends]]). That split is why "which backend" and "how do I lock" are separate questions, and why the S3 answer to the second one changed without the first one moving.
- **Everything in state is plaintext.** TUR uses it as the argument against committing state to Git; TID §6.2.2 treats it as a security consideration in its own right. The consequence neither book fully joins up is that `sensitive = true` is a *display* control, and the value still lands in the bucket the whole team can read. Write-only arguments (1.11) and `ephemeral` (1.10) are the mechanisms that actually keep a value out.

## Where the sources differ

- **TID asks what state is; TUR asks what state does to your project.** TID Ch6 is a reference chapter — JSON anatomy, backend catalogue, migration, drift taxonomy, state-only providers. TUR Ch3 is a chain of consequences: state exists → it must be shared → sharing needs locking → shared state needs isolation → isolation means directories → directories mean duplication → therefore modules. Read TUR for the *why this shapes my repo* argument; nothing in TID substitutes for it.
- **On isolation, only TUR commits to a layout.** Its environment-then-component tree (`stage/prod/mgmt/global` × `vpc/services/data-stores`, each with `variables.tf`/`outputs.tf`/`main.tf`) is a concrete recommendation with its three costs stated. TID Ch8 instead catalogues three root-module structures and frames the choice as blast radius versus number of applies, refusing to pick. The honest synthesis: TUR's layout is the most isolated and the most operationally expensive option in TID's catalogue.
- **On workspaces they agree, which is worth noting because the internet does not.** Both say CLI workspaces are for short-lived copies and not for environment isolation. TUR adds the historical explanation — the feature was once called "environments" — which is the best available answer to why the anti-pattern persists. See [Workspaces](workspaces.md) for the CLI-versus-HCP split neither book draws cleanly.
- **On locking, both are out of date, and in the same direction.** Both teach the S3 + DynamoDB pairing. `use_lockfile = true` replaced it in Terraform 1.11 and OpenTofu 1.10, implemented as an S3 conditional write whose failure mode is a **412 PreconditionFailed** on a `.tflock` object. TID's own note needed the same correction, which is the useful lesson: when two independent books teach the same mechanism as settled, that is not evidence it is current.
- **On cross-configuration data, TUR teaches the mechanism and the docs argue against it.** `terraform_remote_state` works and is still the common answer outside HCP Terraform. But [[tf-remote-state-data]] is mostly the case against it: reading one output requires credentials that can read the *entire* state snapshot by direct request, so a web tier that needs a database hostname ends up able to read the database password. `tfe_outputs` on HCP, or explicit publication to a store with its own access controls, are the recommended alternatives.

## The engine split matters more here than anywhere else

Two of the limitations TUR presents as inherent are now OpenTofu-only fixes, and both are state-adjacent:

| Gap TUR describes | Terraform | OpenTofu |
| --- | --- | --- |
| "It would be better still if Terraform natively supported encrypting secrets within the state file" | none | **client-side state encryption, 1.7** (with an `unencrypted` method as the way back out) |
| "the `backend` block does not allow you to use any variables or references" | still true; use partial configuration | **early variable evaluation, 1.8** ([[ot-early-eval-backend]]) |
| DynamoDB locking | `dynamodb_table` **deprecated** in the v1.15.0 schema, removal announced | not deprecated |

TUR's own text is the best evidence the first row was a real gap rather than a novelty: the book wished for the feature, and one engine shipped it.

## When to read which

- Need to decide how to lay out repositories and backends? → **TUR Ch3**, then TID Ch8 for the alternatives it declines to choose between.
- Need to understand what is *in* the file, or to operate on it? → **TID Ch6** ([[06-state-management]]).
- Need the rule rather than the narrative? → [[tf-state]] for the model, [[tf-state-purpose]] for why a stateless design was rejected, [[tf-state-backends]] for what a backend owes you.
- About to set up locking? → [[tf-state-locking]] and [[tf-backend-configure]], not either book.
- About to move a local state file to HCP Terraform? → [[tut-cloud-migrate]], which is the whole migration in nine minutes and needs no cloud provider account.
- About to share data between configurations? → [[tf-remote-state-data]] first, for the access-control argument, then TUR Ch3 for the mechanics.

## Sources

- [TID Ch 6 — State management](../books/tid/chapters/06-state-management.md) — the reference treatment: JSON anatomy, backends, migration, drift, state-only resources
- [TUR Ch 3 — How to Manage Terraform State](../books/tur/chapters/03-manage-state.md) — the consequences argument, the bulkhead metaphor, the file layout
- [[tf-state]] · [[tf-state-purpose]] · [[tf-state-backends]] · [[tf-state-locking]] · [[tf-backend-configure]] · [[tf-remote-state-data]] · [[tf-state-refactor]]
- [[tut-cloud-migrate]] — HCTut, the local-to-HCP migration end to end: `cloud` block, `terraform login`, the copy-state prompt at `init`
- [[terraform-intro]] — the one-paragraph version

## Open questions

> ❓ Neither book covers **`state_store`** (pluggable state storage, watch-don't-adopt per **I6**). Worth revisiting when it stabilises, since it changes what "backend" means.

> ❓ TUR's layout predates `moved` and `removed` blocks entirely, so it never costs out **refactoring an existing deployment into that tree**. TID Ch9 §9.5–§9.6 and [[tf-state-refactor]] cover the migration; nobody covers "how much does adopting the recommended layout actually cost on a live system".
