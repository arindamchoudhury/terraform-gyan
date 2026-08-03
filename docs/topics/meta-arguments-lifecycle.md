# Meta-arguments and `lifecycle`

Cross-source topic page. Sources: [[tf-meta-arguments]] (HCDocs meta-arguments index), [[tf-meta-count]], [[tf-meta-for-each]], [[tf-meta-depends-on]] and [[tf-meta-lifecycle]] (HCDocs per-argument references), [[tut-count]], [[tut-for-each]] and [[tut-resource-lifecycle]] (HCDocs hands-on), TID Ch2 §2.7, [[tf-configure-resource]] (HCDocs), [[ot-dynamic-prevent-destroy]] (OpenTofu), [[tf-style-guide]] (HCDocs).

Feeds learning-path **I1** (`count`/`for_each`/`depends_on`) and **I2** (`lifecycle`).

## What the class is

Both sources agree on the defining property, and state it almost identically.

- **HCDocs:** meta-arguments are "built into the Terraform configuration language." The provider developer determines resource-*specific* arguments; meta-arguments come from core, so **all** resources support them.
- **TID Ch2:** "Regular arguments change the *infrastructure*. Meta arguments change how *Terraform* processes a block."

The consequence is the same either way. A meta-argument is portable across every provider, because no provider implements it.

## Two framings of the membership list

The sources disagree on *how many* meta-arguments there are. They aren't contradicting each other — they're scoped differently.

| | TID Ch2 §2.7 | HCDocs index |
|---|---|---|
| `provider` | ✅ | ✅ |
| `depends_on` | ✅ | ✅ |
| `lifecycle` | ✅ | ✅ |
| `count` | — (deferred to Ch5) | ✅ |
| `for_each` | — (deferred to Ch5) | ✅ |
| `providers` | — | ✅ |

TID's Ch2 is a tour of HCL block components, so it covers the three meta-arguments that matter before modules and multi-instance resources exist. `count` and `for_each` arrive in Ch5, `providers` alongside modules. **HCDocs' six is the complete list**; TID's three is a chapter-scoped subset. Take the HCDocs list as canonical.

## Where each one is legal

The HCDocs index gives a block-applicability map, but it is **not reliable as stated** — see [[tf-meta-arguments]] for the discrepancy (the index omits `data` from its `count` list while listing it for `for_each`; the `count` reference page confirms `data` is supported). The per-argument reference pages win over the index.

!!! warning "That rule is a heuristic, not a guarantee — the reference pages have gaps too"
    [[tf-meta-count]]'s **Supported constructs** list names `data`, `ephemeral`, `module`, `resource`, and `list` (query configs). It omits **`action`** — which the same page's opening paragraph and one of its own use cases both describe as supported. So three block-applicability lists across two pages disagree with each other, and the *page body* is more reliable than the *page's own summary list*.

    Confirmed omissions so far — index page vs `count` (`data`), index page vs `depends_on` (five of six block types), `count` page vs itself (`action`), `for_each` page vs itself (**`action` and `import`**, both described in that page's own examples).

    !!! danger "Not just a lower bound — the lists err in both directions (verified 2026-08-02)"
        The working rule used to be "treat every applicability list as a lower bound." That is too generous. The `depends_on` reference page lists **`check`**, and Terraform rejects it: a `check` block accepts no arguments at all, because `checkBlockSchema` (`internal/configs/checks.go`, tag **v1.15.8**) declares only the nested `data` and `assert` blocks. The page presumably means `depends_on` on the `data` block *inside* a check.

        So the lists both under-report and over-report. The only reliable check is to write the two lines and run `terraform validate`. A full measured matrix for `count`/`for_each`/`depends_on` across ten block types is in Book Ch 10 §8.

Two applicability facts worth holding:

- **`count` and `for_each` are mutually exclusive** in the same `resource` or `module` block.
- **`depends_on` propagates through modules.** Used in a `module` block, it applies to *all* resources inside that module (TID Ch2 §2.7.3). The HCDocs index doesn't mention this.

## The "known early" constraint

TID Ch2 supplies the rule the HCDocs index never states:

> Meta arguments are processed **very early** in planning, so many require **literal** values — or at least values known at plan time. A `true`/`false` meta argument must be *literally* `true`/`false`, never a value that depends on an attribute known only post-apply.

This single constraint explains most of the friction people hit with meta-arguments: why `prevent_destroy` can't be driven by `var.is_prod`, why `for_each` keys can't come from a computed attribute, why `replace_triggered_by` takes resource references rather than variables.

## `count` — positional identity, and the `? 1 : 0` switch

[[tf-meta-count]] gives the addressing rules and the choice criterion, and its silences are as informative as its text.

**What it says.** `count` takes a whole number; each instance gets a distinct object, created/updated/destroyed separately. A `count` object appears in scope with the single attribute `count.index`, zero-based. The block and its instances are different addresses — `aws_instance.server` is the block, `aws_instance.server[0]` an instance — unlike a block with neither `count` nor `for_each`, which needs no index. Inside `provisioner`/`connection`, `self` is the *instance*. Choose `count` for "nearly identical instances", `for_each` when arguments "must have distinct values that can't be directly derived from an integer index". The two are mutually exclusive in one block.

**What it never says**, and both matter more than most of the above:

- **`count` keys instances by position.** Delete a middle element from the driving list and every later instance shifts index, so Terraform plans destroy-and-recreate for all of them. `for_each` keys by string and touches only the removed entry. The reference page's neutral "can't be directly derived from an integer index" is as close as it comes; TID Ch4 §4.8 is where this is actually taught ([[04-expressions-iterations]]).
- **A `count` block reference is a `tuple`, not a list** (and a `for_each` one is an `object`, not a map) — verified on TF 1.15.8, [[conditional-branch-evaluation]]. Auto-conversion hides this almost everywhere, which is why the docs conflate them.

**The `? 1 : 0` switch.** The page explicitly endorses `count` as a conditional (`count = var.creator ? 3 : 0`), and it is the only way to make a single resource optional in Terraform. Cost: the block is indexed forever, so every reference and every `moved` block carries `[0]`. **OpenTofu 1.11's `enabled`** is the first-class replacement, written inside the `lifecycle` block; Terraform has none ([[opentofu-enabled-argument]]).

**Two patterns from the hands-on** ([[tut-count]]), neither of which appears on the reference page:

- **The count is usually a product, not a literal.** `count = var.instances_per_subnet * length(module.vpc.private_subnets)` is a single `count` value computed from two independent inputs, so adding a subnet scales the fleet automatically. Both operands must be plan-time known, which `length()` over a configured list satisfies.
- **Modulo spreads instances over buckets.** `subnet_id = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]` round-robins four instances across two subnets. This is the canonical "N over M with a flat integer index" answer, and it is a clean illustration of where the `for_each` criterion does *not* apply: the distinct values here **can** be derived from the index.

!!! warning "Renaming a `count` block is a rebuild unless you write a `moved` block"
    A resource address *is* its identity in state. [[tut-count]]'s refactor renames `aws_instance.app_a` → `aws_instance.app` and its own apply output reads **"8 added, 0 changed, 4 destroyed"** — the infrastructure was replaced solely because the addresses changed. `moved` blocks (Terraform 1.1+) exist for exactly this and the tutorial never mentions them. Same failure mode as the positional re-indexing above, reached by a different route.

## `for_each` — keyed identity, and the three things `count` can't do

[[tf-meta-for-each]] is the longer of the two per-argument pages, and most of the extra length is capability `count` has no equivalent for.

**Chaining.** A `for_each` resource can be the `for_each` of another: `for_each = aws_vpc.example` gives one internet gateway per VPC, with `each.value` holding a whole `aws_vpc` object. The docs' argument for it is not brevity but coupling — it "tells Terraform to **expect the instance keys for both to always change together**." Deriving both from `var.vpcs` separately would produce the same keys today and leave them structurally independent.

**Sensitive values are banned as keys**, and this is an error rather than a warning: Terraform "uses the value in `for_each` to identify the resource instance and **always discloses it in UI output**." Instance keys are public by construction — they appear in every plan line, state address, and error message. Sensitivity is contagious through functions, so `keys(local.map)` on sensitive *values* is itself sensitive; the escape is a `for` expression that touches only keys, `toset([for k, v in local.map : k])`.

**No implicit list-to-set conversion.** `for_each` refuses lists and tuples outright "to prevent unexpected behavior during conversion", which is why `toset()` is mandatory rather than stylistic. This is the one place the docs' type story is strict — everywhere else a tuple converts to a list freely ([[conditional-branch-evaluation]]). `toset` is lossy by design: it discards order and dedupes, both harmless here since identity comes from the key.

**`each.key` / `each.value`**, and for a set the two are identical. Addressing is `<TYPE>.<NAME>["key"]` — the same block-vs-instance split as `count`, keyed by string rather than integer.

!!! danger "The accepted-types sentence is wrong in both reference pages' shared framing"
    HCDocs says `for_each` "accepts a map or a set of strings." The implementation accepts map, set, **and object** (`eval_for_each.go:361`, TF 1.15.8) — so `for_each = { a = "1", b = "2" }` needs no `tomap()`, because braces build an object. The same page's chaining section calls a `for_each` resource "a map of objects" when it is an **object**; `count` gives a **tuple**, not a list. **OpenTofu's docs state all three kinds correctly.** Evidence: [[conditional-branch-evaluation]], [[ot-provider-for-each]].

    The rejection of lists and tuples is *not* part of the error — that restriction is real and deliberate. Re-verified on **TF 1.15.8**: `for_each = ["a", "b"]` fails with *"the `for_each` argument must be a map, or set of strings, and you have provided a value of type tuple"* ([[tut-for-each]], whose own text claims lists are supported).

## Combining `count` and `for_each`

Both reference pages state the mutual exclusion and stop there. [[tut-for-each]] gives the only documented way around it: **move the `count`-bearing resource into a module, and put `for_each` on the module block.** `count` multiplies inside, `for_each` multiplies outside, and the two never share a block.

```hcl
module "ec2_instances" {
  source   = "./modules/aws-instance"
  for_each = var.project

  instance_count = each.value.instances_per_subnet * length(module.vpc[each.key].private_subnets)
  # …
}
```

!!! warning "A module using `count` or `for_each` cannot declare a `provider` block"
    It must inherit provider configuration from its caller, and every instance the module creates uses the same configuration. So the wrapping trick buys multiplication but **not** multi-provider fan-out — one `for_each` module cannot put each instance in a different region by declaring its own provider. Pass configurations in with `providers = { … }` instead ([[tf-provider-block]]).

    This is the constraint OpenTofu's core-language `provider for_each` removes ([[ot-provider-for-each]]); Terraform's equivalent is Stacks-only ([[tf-meta-for-each]]).

**Two ways to correlate instances across blocks.** *Chaining* (`for_each = aws_vpc.example`) derives the downstream keys from the upstream resource, so the two sets change together by construction. *Re-iterating* (`for_each = var.project` on every block, correlating with `module.vpc[each.key]`) is what [[tut-for-each]] does across five blocks keyed off one variable. Both give matching keys; only chaining makes the coupling structural.

!!! danger "`for_each` is for objects that share a lifecycle — environments do not"
    [[tut-for-each]] states the rule in a Note — "use separate Terraform projects or workspaces instead of `for_each` to manage resource lifecycles independently … running `terraform destroy` will destroy both" — and then its worked example puts a `dev` and a `test` project in one configuration, so one destroy takes out both. Good exercise, bad template. See [[tf-state-workspaces]].

## `depends_on` — the precise semantics

The HCDocs index is more exact than the usual summary. It doesn't say "create A before B" — it says Terraform completes **all actions on the dependency object, including read operations**, before performing any action on the dependent. A `data` read on the dependency has to finish first too.

Both sources, plus [[tf-configure-resource]] and the book's Ch3, converge on the same guidance: **prefer implicit dependencies.** An attribute reference *is* a dependency edge in the DAG, so Terraform derives ordering automatically and parallelizes what it can. Reach for `depends_on` only where a real dependency exists but no attribute links the two blocks.

TID's canonical example: an AWS **NAT Gateway** needs the **Internet Gateway** up first, but takes no argument referencing it — there's only ever one IGW per VPC — so the ordering must be stated.

An over-used `depends_on` serializes work the graph could have run in parallel.

## `lifecycle` — seven rules

A **subblock**, declarable **once** per resource. It's a subblock deliberately: new options can be added over time without colliding with vendor-provided argument names (TID Ch2 §2.2.3) — and that is exactly what happened, twice.

Per the [[tf-block-resource]] reference the full set is: `action_trigger`, `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`, `precondition`, `postcondition`. TID covers the middle four. The condition blocks belong to **A2**; `action_trigger` is new in the 1.14 actions work and is described below.

HCDocs adds one qualifier the book doesn't: **support for each individual rule varies across block types.** A rule legal on `resource` isn't automatically legal elsewhere.

!!! note "Why `lifecycle` accepts only literal values"
    "Configurations defined in the `lifecycle` block **affect how Terraform constructs and traverses the dependency graph**. You can only use literal values … because Terraform processes them **before it evaluates arbitrary expressions**." The `lifecycle` block is an *input* to graph construction, so it cannot depend on anything the graph produces. That is the mechanism behind TID's "known early" warning.

!!! danger "Lifecycle rules are not recorded in state — except one"
    [[tf-meta-lifecycle]] adds the fact that reframes half of this section: *"Except for `create_before_destroy`, Terraform does not explicitly record a resource's lifecycle rule to state."*

    The guard lives in the configuration and nowhere else. Delete the `resource` block and you delete `prevent_destroy` with it, which is why removing a block destroys the object regardless. TID lists that as one of three reasons to avoid `prevent_destroy`; this is the mechanism behind it. The sanctioned alternative is a `removed` block with `destroy = false` ([[tf-block-removed]], [[tf-state-remove]]).

    `create_before_destroy` is the exception because it also determines *destroy ordering*, which still has to work after the config is gone. State v4 carries it per instance as `create_before_destroy` (`internal/states/statefile/version4.go:719`, tag v1.15.8); the field comment says so directly.

    Condition rules sit in between: Terraform records the **results** of `precondition`/`postcondition` checks to state, but not the checks themselves.

**`create_before_destroy`** — Terraform's default on replacement is destroy-then-create. That default is the safe one: many resources hold unique identifiers that can't be duplicated, so create-first would error. Two IAM roles can't share a name. Two instances can't share an Elastic IP. Set it `true` for high-availability cases where even brief loss hurts.

!!! warning "Turning it on for one resource turns it on for everything upstream"
    CBD propagates along dependency edges, and you cannot switch it back off. If A has `create_before_destroy = true` and A depends on B, Terraform enables it on B implicitly and writes that to state. The docs say you cannot override B to `false`, because a CBD node depending on a non-CBD node "would imply dependency cycles in the graph" ([[tf-meta-lifecycle]]).

    Measured on **1.15.8** and **OpenTofu 1.12.4**, "cannot" means *silently ignored*, not rejected: writing `create_before_destroy = false` on B plans and applies with no error and no warning, and only `TF_LOG=trace` shows `ForcedCBDTransformer: forcing create_before_destroy on for "…"`. Lab: `labs/chapter11/lab2`.

    `ForcedCBDTransformer` (`internal/terraform/transform_destroy_cbd.go`, tag v1.15.8) does this in the **plan** graph builder, before planned changes are constructed — so it shows up in the plan, not as an apply-time surprise.

    The practical risk follows from why CBD is opt-in at all: it is only safe on resource types whose old and new objects can coexist. Propagation can push an upstream resource with a unique-name constraint into a mode it cannot support, and you never edited that resource.

    One more side effect: with `create_before_destroy = true`, a **destroy-time provisioner on that resource does not run**.

### How the three rules look at the terminal

[[tut-resource-lifecycle]] is the hands-on, and its transcripts supply the artifacts none of the reference pages show.

**`prevent_destroy` fails at plan, with no override flag.** The error names the rule and offers exactly two ways out: edit the config, or "reduce the scope of the plan using the `-target` flag." One of the few places HashiCorp recommends `-target`.

**`create_before_destroy` flips the plan symbol.** Default replacement is `-/+ destroy and then create replacement`; with CBD it becomes:

```
+/- create replacement and then destroy
```

Read the symbol literally — it is the operation order. Confirmed at tag v1.15.8 (`internal/command/jsonformat/plan.go:688`). Nothing else in the plan announces that CBD is active, so this is the check. A replacement also always shows as two numbers in the summary (`1 to add … 1 to destroy`) for one resource.

**The old object is deposed, and current output says so.** During the swap the prior object is moved aside in state under a generated key:

```
aws_instance.example (deposed object 940b3833): Destroying...
```

(The tutorial shows the older bare-parenthesis form.) If an apply fails partway, the deposed object stays in state and the next plan destroys it, which is the main operational cost of CBD and something neither the reference page nor the tutorial mentions. It does **not** show up in `terraform state list`, which prints only current objects; `terraform show -json` reports it as `deposed_key`. Verified against the v1.15.8 source. See [[tf-state]].

**`ignore_changes` refreshes state to the drifted value.** Change a tag out of band with `aws ec2 create-tags`, then apply: `0 added, 0 changed, 0 destroyed`, and `terraform state show` reports the **new** value. The rule suppresses the plan to update, not the read. Config and state legitimately disagree from then on — until a replacement, which re-creates the resource from the configured value.

**`prevent_destroy`** — any plan that would destroy the resource fails. TID says use it *exceedingly rarely*, for three reasons:

- It takes only **literal** values, so you can't enable it for prod and disable it for dev.
- It blocks destroy plans, which breaks spinning up and tearing down temporary environments.
- **Deleting the `resource` block removes the guard along with it** — and that's one of the most common destroy paths.

It earns its keep in narrow compliance cases (logs that mustn't be deleted).

**`ignore_changes`** — the most-used rule. Takes a list of argument names; Terraform stops updating the resource when *only* those change. Classic cases: a looked-up AMI updating (don't recreate a running instance on every new image), or an orchestration system like EKS/ECS adding tags out of band.

The special value **`all`** (bare, **not** in brackets) ignores every change. TID recommends `ignore_changes` over `prevent_destroy` as the accidental-destruction guard: listing the forced-new fields keeps the resource from being recreated while still allowing other updates, and unlike `prevent_destroy` it doesn't block destroy plans.

Three precision points from [[tf-meta-lifecycle]] that the summary above hides:

- **Ignored on update, honored on create.** The listed arguments are still considered when planning a *create*. They stop mattering from the second plan onward. That is exactly what makes the AMI case work — the instance is built from the looked-up AMI, and only later drift is ignored.
- **Entries are relative attribute addresses, and index notation works** — `tags["Name"]`, `list[0]`. One map key can be ignored while the rest of the map stays managed.
- **Only attributes defined by the resource type.** You cannot `ignore_changes` a meta-argument, or `lifecycle` itself. No ignoring `count`, `for_each`, or `provider`.

**`replace_triggered_by`** — force replacement when *another* resource changes. Takes resource references (any change → replace) or specific attribute references. It **cannot** take a plain value: local values and input variables are invalid.

The reason isn't the "known early" rule, as it might appear. Per [[tf-terraform-data]], replacement is decided from the **planned operations** of the referenced resources — a plain value has no planned operation to inspect. The documented workaround is to wrap the value in a `terraform_data`, which plans an action whenever its `input` changes:

```hcl
resource "terraform_data" "replacement" { input = var.revision }

resource "example_database" "test" {
  lifecycle { replace_triggered_by = [terraform_data.replacement] }
}
```

[[tf-meta-lifecycle]] enumerates what actually counts as a trigger, and the three cases are not uniform:

| Reference is to | Replacement triggers when |
|---|---|
| a resource with multiple instances | a plan to update **or replace any instance** |
| a single resource instance | a plan to update or replace **that** instance |
| a single attribute of an instance | **any change to the attribute value** |

The first two watch a *planned action*; the third watches a *value*. Inside a `count`/`for_each` block you may use `count.index` or `each.key` in the expression to pair instance-for-instance with another block on the same collection, rather than triggering on the whole resource.

**`action_trigger`** — invoke provider **actions** (Terraform 1.14) on lifecycle events. `events` and `actions` are required; `condition` gates the run.

```hcl
lifecycle {
  action_trigger {
    events  = [after_create]
    actions = [action.ansible_playbook.provision]
  }
}
```

Only four events exist — `before_create`, `after_create`, `before_update`, `after_update`. **There is no destroy event** (verified on v1.15.6; `before_destroy` yields `Error: No events specified`). Destroy-time work still means a destroy-time provisioner. See [[tf-block-resource]].

`actions` is an **ordered** list, so several actions on one event fire in list order. The optional `condition` argument gates the invocation — the one place an expression is legal anywhere inside `lifecycle`, because it is a per-event runtime gate rather than an input to graph construction ([[tf-meta-lifecycle]]).

**`precondition` / `postcondition`** belong to **A2**, but two scheduling facts belong here because they are ordering, not validation. A `precondition` runs **before** the resource's own configuration arguments are evaluated and can pre-empt an argument error, and it runs **after** `count`/`for_each`, so it evaluates per instance with `each.key`/`count.index` in scope. A failed `postcondition` **blocks changes to every resource downstream** of it. Both accept `data`, `ephemeral`, and `resource`. Do not put the same condition on a `resource` and on a `data` block representing the same object — Terraform may then ignore data-block changes caused by the resource. Detail in [[tf-meta-lifecycle]] and [[tf-conditionals]].

!!! info "OpenTofu — `lifecycle` divergences"
    OpenTofu directly lifts the `prevent_destroy` limitation TID calls out:

    - **Dynamic `prevent_destroy`** (OT 1.12) — bind it to a variable or expression, so prod and dev *can* differ. Terraform still requires a literal. See [[ot-dynamic-prevent-destroy]].
    - **`destroy = false`** (OT 1.12) — stop managing a resource without deleting the real object, written as one line inside the **resource's** `lifecycle`. Terraform's nearest equivalent is a separate `removed` block that *also* carries `lifecycle { destroy = false }` — and note that a Terraform `removed` block **without** that line destroys the object. See [[tf-block-removed]].
    - **`enabled`** (OT 1.11) — a first-class on/off switch, cleaner than the `count = var.x ? 1 : 0` idiom that forces `[0]` addressing and index churn. It is an argument **inside the `lifecycle` block**, not a seventh top-level meta-argument, and a disabled resource evaluates to `null` rather than an empty collection. Verified on OpenTofu 1.12.4: [[opentofu-enabled-argument]]. Terraform has no equivalent.

    `create_before_destroy`, `ignore_changes`, and `replace_triggered_by` behave identically in both tools.

## `provider` and `providers`

The two provider-selecting meta-arguments, and the pair most often confused.

- **`provider`** (singular, on a `resource`/`data` block) — picks a non-default provider configuration. By default Terraform derives the provider's local name from the **first word of the resource type** (`aws_instance` → `aws`) and uses that provider's default configuration.
- **`providers`** (plural, on a `module` block) — passes provider configurations into a child module. By default a child module **inherits the default provider configurations of its parent**; `providers = { … }` supplies alternates.

Two traps, both from [[tf-provider-block]] rather than the index page:

- The **default configuration is the unaliased `provider` block.** If every block is aliased, Terraform invents an **implied empty default configuration**, and any resource that omits the `provider` meta-argument silently binds to *that*.
- **`providers = {}` does not disable inheritance.** An explicit `providers` map overrides inheritance only for the providers it enumerates.

### The map is a remap, not an injection ([[tf-meta-providers]])

The `providers` reference page adds the semantics the index page leaves out. The value is a map whose **keys are configuration names used inside the child** and whose **values are configuration names in the parent**. Both sides are unquoted references — a bare local name for a default configuration, `<PROVIDER>.<ALIAS>` for an alternate.

So `providers = { aws = aws.usw2 }` does not hand the child a new provider. It rewrites what the child's own `aws` *means*. The child module keeps writing plain `aws_*` resources with no `provider` argument, and each caller decides which region that resolves to. That is the whole point of the argument: **you retarget a module without editing it.**

Two consequences worth holding onto:

- `providers` is optional **only while the child declares no `configuration_aliases`.** A module that needs two configurations of one provider — the docs' example is a tunnel with a source and a destination — always requires the argument, because non-default configurations are never inherited.
- The argument also exists on Stacks' `component` and `removed` blocks, not just on `module`. [[tf-meta-arguments]]'s applicability table lists `module` alone.

!!! warning "The reference page still carries the un-narrowed cancellation claim"
    It says supplying `providers` "cancels the default behavior" so the child "only has access to the provider configurations you specify." That is the exact wording issue [#35781](https://github.com/hashicorp/terraform/issues/35781) was filed against, and the fix landed on *Providers Within Modules* rather than here. Per-provider is the accurate reading. See [[tf-meta-providers]].

## Style

From [[tf-style-guide]]: meta-arguments go **first** in a block, then normal arguments, then subblocks, and meta-argument *blocks* (`lifecycle`) go **last**.

```hcl
resource "aws_instance" "example" {
  count = 2                       # meta-argument first

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  lifecycle {                     # meta-argument block last
    create_before_destroy = true
  }
}
```

---
Related: [[tf-meta-lifecycle]] — the `lifecycle` reference page: state semantics, CBD propagation, and the exact ignore/trigger evaluation rules. · [[tut-resource-lifecycle]] — the hands-on: plan symbols, deposed objects, and manufactured drift. · [[tf-terraform-data]] — the built-in resource that makes a plain value usable in `replace_triggered_by`. · [[tf-meta-arguments]] — the HCDocs index, and the source of the six-member list. · [[tf-configure-resource]] — surveys the same set from the resource-block side. · [[ot-dynamic-prevent-destroy]] — OpenTofu's fix for the literal-only `prevent_destroy`. · [[tf-provider-block]] — the `provider` blocks that `provider`/`providers` select between. · [[tf-meta-providers]] — the `providers` reference: map semantics, Stacks applicability, and the cancellation-claim discrepancy. · [[tf-style-guide]] — ordering within a block. · [[providers]] — the provider topic page this one hands off to.
