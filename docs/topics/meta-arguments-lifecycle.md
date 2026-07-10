# Meta-arguments and `lifecycle`

Cross-source topic page. Sources: [[tf-meta-arguments]] (HCDocs meta-arguments index), TID Ch2 §2.7, [[tf-configure-resource]] (HCDocs), [[ot-dynamic-prevent-destroy]] (OpenTofu), [[tf-style-guide]] (HCDocs).

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

Two applicability facts worth holding:

- **`count` and `for_each` are mutually exclusive** in the same `resource` or `module` block.
- **`depends_on` propagates through modules.** Used in a `module` block, it applies to *all* resources inside that module (TID Ch2 §2.7.3). The HCDocs index doesn't mention this.

## The "known early" constraint

TID Ch2 supplies the rule the HCDocs index never states:

> Meta arguments are processed **very early** in planning, so many require **literal** values — or at least values known at plan time. A `true`/`false` meta argument must be *literally* `true`/`false`, never a value that depends on an attribute known only post-apply.

This single constraint explains most of the friction people hit with meta-arguments: why `prevent_destroy` can't be driven by `var.is_prod`, why `for_each` keys can't come from a computed attribute, why `replace_triggered_by` takes resource references rather than variables.

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

**`create_before_destroy`** — Terraform's default on replacement is destroy-then-create. That default is the safe one: many resources hold unique identifiers that can't be duplicated, so create-first would error. Two IAM roles can't share a name. Two instances can't share an Elastic IP. Set it `true` for high-availability cases where even brief loss hurts.

**`prevent_destroy`** — any plan that would destroy the resource fails. TID says use it *exceedingly rarely*, for three reasons:

- It takes only **literal** values, so you can't enable it for prod and disable it for dev.
- It blocks destroy plans, which breaks spinning up and tearing down temporary environments.
- **Deleting the `resource` block removes the guard along with it** — and that's one of the most common destroy paths.

It earns its keep in narrow compliance cases (logs that mustn't be deleted).

**`ignore_changes`** — the most-used rule. Takes a list of argument names; Terraform stops updating the resource when *only* those change. Classic cases: a looked-up AMI updating (don't recreate a running instance on every new image), or an orchestration system like EKS/ECS adding tags out of band.

The special value **`all`** (bare, **not** in brackets) ignores every change. TID recommends `ignore_changes` over `prevent_destroy` as the accidental-destruction guard: listing the forced-new fields keeps the resource from being recreated while still allowing other updates, and unlike `prevent_destroy` it doesn't block destroy plans.

**`replace_triggered_by`** — force replacement when *another* resource changes. Takes resource references (any change → replace) or specific attribute references. It **cannot** take a plain value: local values and input variables are invalid.

The reason isn't the "known early" rule, as it might appear. Per [[tf-terraform-data]], replacement is decided from the **planned operations** of the referenced resources — a plain value has no planned operation to inspect. The documented workaround is to wrap the value in a `terraform_data`, which plans an action whenever its `input` changes:

```hcl
resource "terraform_data" "replacement" { input = var.revision }

resource "example_database" "test" {
  lifecycle { replace_triggered_by = [terraform_data.replacement] }
}
```

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

!!! info "OpenTofu — `lifecycle` divergences"
    OpenTofu directly lifts the `prevent_destroy` limitation TID calls out:

    - **Dynamic `prevent_destroy`** (OT 1.12) — bind it to a variable or expression, so prod and dev *can* differ. Terraform still requires a literal. See [[ot-dynamic-prevent-destroy]].
    - **`destroy = false`** (OT 1.12) — stop managing a resource without deleting the real object, written as one line inside the **resource's** `lifecycle`. Terraform's nearest equivalent is a separate `removed` block that *also* carries `lifecycle { destroy = false }` — and note that a Terraform `removed` block **without** that line destroys the object. See [[tf-block-removed]].
    - **`enabled` meta-argument** (OT 1.11) — a seventh meta-argument; a first-class on/off switch, cleaner than the `count = var.x ? 1 : 0` idiom that forces `[0]` addressing and index churn. Terraform has no equivalent. See [[opentofu-feature-history]].

    `create_before_destroy`, `ignore_changes`, and `replace_triggered_by` behave identically in both tools.

## `provider` and `providers`

The two provider-selecting meta-arguments, and the pair most often confused.

- **`provider`** (singular, on a `resource`/`data` block) — picks a non-default provider configuration. By default Terraform derives the provider's local name from the **first word of the resource type** (`aws_instance` → `aws`) and uses that provider's default configuration.
- **`providers`** (plural, on a `module` block) — passes provider configurations into a child module. By default a child module **inherits the default provider configurations of its parent**; `providers = { … }` supplies alternates.

Two traps, both from [[tf-provider-block]] rather than the index page:

- The **default configuration is the unaliased `provider` block.** If every block is aliased, Terraform invents an **implied empty default configuration**, and any resource that omits the `provider` meta-argument silently binds to *that*.
- **`providers = {}` does not disable inheritance.** An explicit `providers` map overrides inheritance only for the providers it enumerates.

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
Related: [[tf-terraform-data]] — the built-in resource that makes a plain value usable in `replace_triggered_by`. · [[tf-meta-arguments]] — the HCDocs index, and the source of the six-member list. · [[tf-configure-resource]] — surveys the same set from the resource-block side. · [[ot-dynamic-prevent-destroy]] — OpenTofu's fix for the literal-only `prevent_destroy`. · [[tf-provider-block]] — the `provider` blocks that `provider`/`providers` select between. · [[tf-style-guide]] — ordering within a block. · [[providers]] — the provider topic page this one hands off to.
