# Meta-arguments

> **Source:** [developer.hashicorp.com/terraform/language/meta-arguments](https://developer.hashicorp.com/terraform/language/meta-arguments)
> **Added:** 2026-07-10
> **Source updated:** undated language reference; captured 2026-07-10 against v1.15.x (latest)
> **Tags:** meta-arguments, count, for_each, depends_on, lifecycle, provider, providers, modules, ephemeral
> **Type:** documentation

*Developer › Terraform › Configuration Language › Meta-arguments · v1.15.x*

The index page over the six meta-arguments. Each one links out to its own reference page; this page is the definition and the block-applicability map. [[tf-configure-resource]] already surveys the same six from the *resource* side and forward-references them into the learning path — captured here for the definition itself and for the per-block applicability, which that page doesn't give.

## What a meta-argument is

> "Meta-arguments are a class of arguments built into the Terraform configuration language that control how Terraform creates and manages your infrastructure."

Two properties define the class:

- **Built into the language, not the provider.** The provider developer determines resource-specific arguments; meta-arguments come from Terraform core, so *all* resources support them regardless of which provider supplies the type.
- **They control management, not the object.** They govern lifecycle, destruction behavior, destruction prevention, and inter-resource ordering — not what infrastructure gets made.

Applicability: usable in **any type of resource**, and **most** are usable in `module` blocks. The page doesn't enumerate which of the six are the exceptions, but the per-argument text below implies it (see the block table).

This matches the framing already recorded in Ch4 of the book — meta-arguments change how Terraform *plans* a block, not what the block builds.

## The six

### `depends_on`

Instructs Terraform to complete **all** actions on the dependency object — **including read operations** — before performing any action on the object that declares the dependency. Use it to explicitly set creation order.

The "including read operations" clause is the precise part. It's stronger than "create A before B": a `data` read on the dependency also has to finish first.

The index page omits the cost. Its reference page calls `depends_on` a **last resort** that makes plans more conservative. See [[tf-meta-depends-on]], and [[dependency-graph]] for why Terraform can never warn you that one is missing.

→ Reference: [depends_on](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on) · Hands-on: [Create resource dependencies](https://developer.hashicorp.com/terraform/tutorials/configuration-language/dependencies)

### `count`

By default Terraform configures **one** infrastructure object per `resource`, `module`, and `ephemeral` block. `count` creates and manages multiple instances of each without writing a separate block per instance.

→ Reference: [count](https://developer.hashicorp.com/terraform/language/meta-arguments/count) · Hands-on: [Manage similar resources with count](https://developer.hashicorp.com/terraform/tutorials/0-13/count)

### `for_each`

Same default-of-one starting point. `for_each` creates and manages several similar objects — the page's example is "a fixed pool of compute instances."

→ Reference: [for_each](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) · Hands-on: [Manage similar resources with for_each](https://developer.hashicorp.com/terraform/tutorials/configuration-language/for-each)

!!! note "This page's `count` block list is incomplete — `data` is missing"
    The index page says `count` applies to **resource, module, and ephemeral** blocks, while `for_each` applies to **resource, data, module, and ephemeral**. `data` appears only in the `for_each` list.

    Checked against the [`count` reference](https://developer.hashicorp.com/terraform/language/meta-arguments/count) ([[tf-meta-count]]), which states `count` is supported in **`data`, `ephemeral`, `module`, and `resource`** blocks, plus **`list`** blocks in query configurations. So the asymmetry is a docs omission on the index page, not a real restriction. Trust the per-argument reference pages over this one — though [[tf-meta-count]] has an omission of its own (`action`), so "per-argument page wins" is a rule of thumb, not a guarantee.

    The same reference adds a rule the index page never states: **you cannot use both `count` and `for_each` in the same `resource` or `module` block.**

### `lifecycle`

A **block**, not a scalar argument. It accepts a rule that customizes how Terraform performs each lifecycle stage for a resource. Support for each individual rule **varies across configuration block types** — a rule legal on `resource` isn't automatically legal elsewhere.

→ Reference: [lifecycle](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle) · Hands-on: [Manage resource lifecycle](https://developer.hashicorp.com/terraform/tutorials/state/resource-lifecycle)

### `provider`

By default Terraform derives the provider's **local name from the first word of the resource type** (`aws_instance` → `aws`) and uses that provider's **default configuration**. Declare multiple `provider` blocks and the `provider` argument on a resource selects which one it uses.

This is the resource-side counterpart to the alias mechanics in [[tf-provider-block]]. That note carries the trap this page doesn't mention: the default configuration is the unaliased `provider` block, and if *every* block is aliased Terraform invents an implied empty default that unqualified resources silently bind to.

→ Reference: [provider](https://developer.hashicorp.com/terraform/language/meta-arguments/provider)

### `providers`

By default a **child module inherits the default provider configurations of its parent**. The `providers` argument on a `module` block passes an alternate configuration in, and the module's resources are created with it.

Confirms [[tf-provider-block]] and TID Ch3 on aliased providers never being inherited. The correction already recorded in [[tf-provider-block]] still applies: an explicit `providers` map overrides inheritance only for the providers it enumerates — `providers = {}` does not disable inheritance.

→ Reference: [providers](https://developer.hashicorp.com/terraform/language/meta-arguments/providers)

## Block applicability

Corrected against the per-argument reference pages, which are the authority. The index page's own lists are shown for contrast — it undercounts at least two meta-arguments.

| Meta-argument | Supported blocks (per its reference page) | What the index page claims |
|---|---|---|
| `depends_on` | `check`, `data`, `ephemeral`, `module`, `output`, `resource` (+ `component` in Stacks) | `resource` only |
| `count` | `data`, `ephemeral`, `module`, `resource` (+ `list` in query configs) | omits `data` |
| `for_each` | `data`, `ephemeral`, `module`, `resource` | matches |
| `lifecycle` | `resource`; support **varies by rule** across other block types | "varies" |
| `provider` | `resource`, `data` | `resource` |
| `providers` | `module` | `module` |

!!! warning "The index page undercounts supported blocks"
    Two confirmed cases so far: `count` (omits `data`) and `depends_on` (names only `resource`, while its reference page lists six block types). Both were found by opening the reference page after the index looked suspicious. Assume the index is a summary, not a spec — check the per-argument page before concluding a meta-argument is illegal somewhere. Sources: [[tf-meta-depends-on]], [[tf-meta-count]].

    The reference pages are not immune either: [[tf-meta-count]]'s own **Supported constructs** list omits `action`, which its opening paragraph and one of its use cases both describe. Block-applicability claims in these docs are worth checking against the rest of the same page.

!!! info "OpenTofu — the `enabled` argument"
    OpenTofu 1.11 adds **`enabled`**, a first-class on/off switch for a resource. Terraform has no equivalent; you still write `count = var.enabled ? 1 : 0`, which forces `[0]` addressing and index churn.

    **Corrected 2026-08-02:** this box previously called `enabled` "a seventh meta-argument", which is wrong about where it goes. It is an argument **inside the `lifecycle` block** — at the resource top level OpenTofu rejects it with *"An argument named `enabled` is not expected here."* Verified empirically on **OpenTofu 1.12.4**. The address also stays unindexed, and a disabled resource evaluates to **`null`** rather than an empty collection. Evidence: [[opentofu-enabled-argument]]. See also [[opentofu-feature-history]].

---
Related: [[tf-meta-depends-on]] — the `depends_on` reference, which corrects this page's block list and adds the "last resort" cost. · [[dependency-graph]] — how to inspect the DAG these arguments build. · [[tf-configure-resource]] — surveys the same six from the resource-block side, with learning-path forward references. · [[tf-resources]] — the resources overview one level up. · [[tf-provider-block]] — the `provider` block that `provider`/`providers` select between. · [[tf-style-guide]] — meta-arguments go first in a block, meta-argument *blocks* (`lifecycle`) last. · [[opentofu-feature-history]] — OpenTofu's `enabled`.
