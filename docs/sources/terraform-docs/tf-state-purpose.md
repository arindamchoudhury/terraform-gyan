# Purpose of Terraform State

> **Source:** [developer.hashicorp.com/terraform/language/state/purpose](https://developer.hashicorp.com/terraform/language/state/purpose)
> **Added:** 2026-07-29
> **Source updated:** undated language reference; captured 2026-07-29 against v1.15.x (latest)
> **Tags:** state, tfstate, dependencies, destroy-ordering, refresh, performance, state-locking, import
> **Type:** documentation

*Developer › Terraform › Configuration Language › State › Purpose · v1.15.x*

The answer to "why can't Terraform just inspect the real resources on every run?" Four reasons, in the order the page gives them. Sibling of [[tf-state]], which links here for exactly this question.

The page's framing is worth keeping, because it concedes more than a defence usually does:

> "in the scenarios where Terraform may be able to get away without state, doing so would require shifting massive amounts of complexity from one place (state) to another place (the replacement concept)."

So the claim is not that stateless Terraform is impossible. It's that every replacement is worse. TID Ch6 §6.1 makes the same argument under different headings (real-world linkage, reduced complexity, performance, state-only resources).

## Mapping to the real world

Terraform needs a database to map config to reality. `resource "aws_instance" "foo"` has to resolve to instance ID `i-abcd1234` on some remote system.

**The tag approach was actually tried.** Early Terraform prototypes had no state file and used AWS tags for this mapping. It failed for a blunt reason: not all resources support tags, and not all cloud providers support tags. TID Ch6 §6.1.1 reaches the same conclusion from three angles (missing tag support, out-of-band tag edits, divergent per-vendor search APIs). This page adds that it was a shipped prototype, not a thought experiment.

The one-to-one rule appears here too, with the ambiguity spelled out: bind one remote object to several resource instances and the config-to-object mapping in state becomes ambiguous, so "Terraform may behave unexpectedly." Same operator obligation on import as in [[tf-state]] — each distinct object goes to exactly one resource instance.

## Metadata — the reason that isn't in TID Ch6

This is the part the book's §6.1 doesn't make: **state retains a copy of the most recent dependency set, and that copy exists for destroy ordering.**

The problem. Terraform normally derives dependency order from the configuration. But delete a resource from the config and there is no configuration left to derive from. Terraform can still see the state has a mapping for a resource the config no longer declares, and plan to destroy it. It cannot work out what order to destroy in — the edges lived in the deleted code.

The fix. Terraform keeps the last-known dependencies in state, so destroy order for removed resources comes from state rather than config.

The rejected alternative is instructive:

> Terraform "could know that servers must be deleted before the subnets they are a part of. The complexity for this approach quickly explodes, however: in addition to Terraform having to understand the ordering semantics of every resource for every provider, Terraform must also understand the ordering across providers."

That is the same complexity-shifting argument as the lead, applied concretely. It also matches [[tf-cmd-graph]]'s picture of the graph as config-derived rather than type-derived.

Other metadata rides along for the same reason. The page names one: a pointer to the provider configuration most recently used with a resource, which matters when several aliased providers are in play.

## Performance — the cache is the optional part

State also caches the attribute values of every resource. The page is unusually direct about this one:

> "This is the most optional feature of Terraform state and is done only as a performance improvement."

Default behavior is to sync everything. Every plan and apply queries the providers and refreshes all resources in state. That is fine for small infrastructures.

For large ones, it stops working:

- Many cloud providers offer no API to query multiple resources at once.
- Round-trip time is hundreds of milliseconds per resource.
- Providers rate-limit, so Terraform can only ask for so many resources per window.

!!! warning "`-refresh=false` promotes the cache to the source of truth"
    The page says large Terraform users "make heavy use of the `-refresh=false` flag as well as the `-target` flag" to work around the round-trip cost, and that in those scenarios "the cached state is treated as the record of truth."

    Worth naming plainly, because it inverts the usual model. Normally state is a record that gets corrected against reality on every run. Under `-refresh=false` it is the *only* input, and any drift that happened out of band is invisible to the plan. That is the accidental-manual-change drift category from TID Ch6 §6.6, made undetectable by choice.

## Syncing

By default state is a file in the working directory where Terraform ran. Fine to get started. In a team, everyone must work from the same state so operations land on the same remote objects.

Remote state is the recommended answer, and the page ties locking to it directly: a fully-featured backend gives remote locking, which stops two users running Terraform simultaneously and ensures each run starts from the most recently updated state. Same recommendation as [[tf-state]], with the collaboration rationale rather than the durability one.

---
Related: [[tf-state]] — the section overview, which defers to this page for the "why"; it covers storage, the CLI, and the JSON integration points. [[tf-cmd-graph]] — the dependency graph this page's metadata section preserves a snapshot of. [[tf-meta-depends-on]] — explicit edges, which end up in the same retained dependency set. [[tf-remote-state-data]] — reads the outputs that the syncing section's remote backends hold.
