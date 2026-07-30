# Remote State

> **Source:** [developer.hashicorp.com/terraform/language/state/remote](https://developer.hashicorp.com/terraform/language/state/remote)
> **Added:** 2026-07-30
> **Source updated:** undated language reference; captured 2026-07-30 against v1.15.x (latest)
> **Tags:** state, remote-state, delegation, locking, hcp-terraform, consul, decomposition
> **Type:** documentation

*Developer › Terraform › Configuration Language › State › Remote state · v1.15.x*

The conceptual page for *why* state goes remote. No configuration on it — mechanics are in [[tf-backend-configure]] and [[tf-state-backends]], and the data source in [[tf-remote-state-data]]. Two arguments, both about teams.

## The problem local state creates

> "each user must make sure they always have the latest state data before running Terraform and make sure that nobody else runs Terraform at the same time."

Two separate burdens carried by humans: **freshness** and **exclusion**. A remote store solves the first; locking solves the second, which is why the page treats them as separate sections rather than one benefit.

Supported stores named here: HCP Terraform, HashiCorp Consul, Amazon S3, Azure Blob Storage, Google Cloud Storage, Alibaba Cloud OSS, "and more." Remote state "is implemented by a backend or by HCP Terraform, both of which you can configure in your configuration's root module."

## Delegation and teamwork

The framing worth taking from this page. Remote state is not only durability — it is a **read-only sharing channel between configurations**, and therefore between teams.

> "Remote state allows you to share output values with other configurations. This allows your infrastructure to be decomposed into smaller components."

> "remote state also allows teams to share infrastructure resources in a read-only way **without relying on any additional configuration store**."

The example is a core-infrastructure team owning machines and networking, exposing VPC IDs, subnet IDs, and NAT instance IDs for other teams' configurations to consume. That is the same team-ownership split [[tf-state-refactor]] lists as a refactoring trigger, seen from the consuming side.

"Without relying on any additional configuration store" is the honest statement of the tradeoff. You get the channel free because the state already exists. [[tf-remote-state-data]] then spends most of its length arguing you should usually pay for a real store anyway, because reading one output through `terraform_remote_state` grants read access to the **entire** state snapshot.

This page's own hedge points the same way, and names a concrete pair:

> "you may prefer to use more general stores… if your environment has HashiCorp Consul then you can have one Terraform configuration that writes to Consul using `consul_key_prefix` and then another that consumes those values using the `consul_keys` data source."

!!! note "A small mismatch with the data-source page's table"
    [[tf-remote-state-data]]'s alternatives table lists Consul as `consul_key_prefix` resource → **`consul_key_prefix`** data source. This page names **`consul_keys`** as the reader instead. Checked against the registry (hashicorp/consul **v2.23.0**, 2026-07-30): the provider ships **both** as data sources, so the pages simply pick different halves. Not a contradiction, but if you follow one table you will not find the other's name in it.

## Locking and teamwork

> "For **fully-featured** remote backends, Terraform can also use state locking to prevent concurrent runs of Terraform against the same state."

"Fully-featured" is doing the qualifying that [[tf-state-locking]] states plainly: locking is optional and per-backend, and [[tf-state-workspaces]] enumerates which backends carry the related capabilities.

!!! info "HCP Terraform's locking is a different kind of thing"
    > "a commercial offering that supports an even stronger locking concept that can also detect attempts to create a new plan when an existing plan is already awaiting approval, by **queuing Terraform operations in a central location**."

    Worth separating from state locking, because it solves a problem state locks cannot. A state lock is held for the duration of one command; it is released the moment a `plan` finishes. So two people can both produce plans against the same state, and the second apply silently invalidates the first person's reviewed plan.

    HCP's run queue holds the *whole* plan-then-approve cycle, not the command. That is a run-lifecycle guarantee, and it is the one genuinely new idea on this page. Learning-path **A4** owns it.

---
Related: [[tf-state-purpose]] — the same syncing/locking argument from the purpose side. · [[tf-state-backends]] — what a backend is responsible for. · [[tf-backend-configure]] — how you actually configure one. · [[tf-remote-state-data]] — the data source this page points to for usage, and the security case against it. · [[tf-state-refactor]] — decomposition into smaller components, from the refactoring side. · [[tf-state-locking]] — the state-lock mechanics HCP's run queue sits above.
