# Refactor modules

> **Source:** [developer.hashicorp.com/terraform/language/modules/develop/refactoring](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
> **Added:** 2026-08-08
> **Source updated:** undated language reference; captured 2026-08-08 against v1.15.x (latest)
> **Tags:** moved-block, refactoring, resource-addresses, instance-keys, count, for_each, module-split, shim-module
> **Type:** documentation

*Developer › Terraform › Configuration Language › Modules › Develop modules › Refactor modules · v1.15.x*

The deep reference for `moved`. [[tut-move-config]] is its hands-on and already quoted this page for the removal rules; everything else here is new — instance-key moves, the `count` auto-move, cross-type limits, the module-split shim, and address scoping.

> By default, Terraform interprets a change as an instruction to **destroy the existing resource and create a new resource at the new address.**

Five use cases: move a resource or module, rename a resource, create multiple instances, rename a module call, split a module. Requires **Terraform v1.1+**; before that, `terraform state mv`.

## Whole-resource versus instance addressing

The rule that governs everything else on the page:

> Both of the addresses in this example referred to **a resource as a whole**, and so Terraform recognizes the move for **all instances** of the resource. That is, it covers both `aws_instance.a[0]` and `aws_instance.a[1]` without the need to identify each one separately.

> **When at least one of the two addresses includes an instance key**, such as `["small"]`… Terraform understands **both** addresses as referring to specific instances of a resource rather than the resource as a whole.

So a bare address moves everything under it; adding an index or key to *either* side switches the whole block into instance mode. That single toggle is what makes `count` ↔ `for_each` ↔ neither migrations expressible:

```hcl
# Both old and new configuration used "for_each", but the
# "small" element was renamed to "tiny".
moved {
  from = aws_instance.b["small"]
  to   = aws_instance.b["tiny"]
}

# The old configuration used "count" and the new configuration
# uses "for_each", with the following mappings from
# index to key:
moved {
  from = aws_instance.c[0]
  to   = aws_instance.c["small"]
}
moved {
  from = aws_instance.c[1]
  to   = aws_instance.c["tiny"]
}

# The old configuration used "count", and the new configuration
# uses neither "count" nor "for_each", and you want to keep
# only the object at index 2.
moved {
  from = aws_instance.d[2]
  to   = aws_instance.d
}
```

This is the missing piece for [[tut-count]] and [[tut-for-each]], neither of which mentions `moved` at all. The `count`-to-`for_each` migration those tutorials walk you through is a destroy-and-recreate unless you write one `moved` block per index.

!!! note "Adding `count` to a resource that didn't have it moves silently to index `0`"
    > When you add `count` to an existing resource that didn't previously have the argument, **Terraform automatically proposes moving the original object to instance `0`** unless you write a `moved` block that explicitly mentions that resource. However, we recommend writing out the corresponding `moved` block explicitly to make the change clearer to future readers of the module.

    So one common case is already free — `aws_instance.a` becomes `aws_instance.a[0]` without help. Worth knowing precisely because it sets a misleading expectation: **adding `count` is free, renaming is not**, which is the cost [[tut-count]] measured as "8 added, 0 changed, 4 destroyed". The docs still want the block written out, for the reader rather than for Terraform.

    No equivalent auto-move is documented for `for_each`, which needs a key you have to choose:

    ```hcl
    moved {
      from = aws_instance.a
      to   = aws_instance.a["small"]
    }
    ```

## What `moved` cannot do

> Each resource type has a separate schema so objects of different types are **not typically compatible**. You can always use the `moved` block to change the **name** of a resource, but **some providers also let you change an object from one resource type to another.** Refer to the provider documentation for details on which resources can move between types.

> **You cannot use the `moved` block to change a managed resource (a `resource` block) into a data resource (a `data` block).**

Two distinct limits, and the first is easy to miss: cross-**type** moves exist but are **provider-dependent**, so whether `aws_x` can become `aws_y` is a question for the provider docs, not the language docs. The managed-to-data boundary is absolute — to stop managing something and start reading it, you `removed` it from state ([[tf-block-removed]], with `lifecycle { destroy = false }`) and add a `data` block separately.

## Module-level moves

**Rename a call** — `module.a` → `module.b` — cascades to every address beneath it: "`module.a.aws_instance.example` would be treated as `module.b.aws_instance.example`", and "If this module call used `count` or `for_each` then it would apply to all of the instances, without the need to specify each one separately."

**Preserve an existing instance when adding `count` to a module call:**

```hcl
module "a" {
  source = "../modules/example"
  count  = 3
}

moved {
  from = module.a
  to   = module.a[2]
}
```

Terraform then "plans to create new objects only for `module.a[0]` and `module.a[1]`". Note the deliberate choice of index `2` — you decide which slot the survivor occupies.

## Splitting a module: the shim pattern

The most valuable section, because it solves a problem nothing else in the docs addresses — **splitting a published module without breaking its existing consumers.**

Three resources become two modules. The original module is not deleted; it becomes a shim:

> Edit the original module to no longer include any of these resources, and instead to contain **only shim configuration to migrate existing users.**

```hcl
module "x" {
  source = "../modules/x"
}

module "y" {
  source = "../modules/y"
}

moved {
  from = aws_instance.a
  to   = module.x.aws_instance.a
}

moved {
  from = aws_instance.b
  to   = module.x.aws_instance.b
}

moved {
  from = aws_instance.c
  to   = module.y.aws_instance.c
}
```

> When an existing user of the original module upgrades to the new "shim" version, Terraform notices these three `moved` blocks and behaves as if the objects associated with the three old resource addresses were originally created inside the two new modules.

New users take `x` and `y` directly; old users upgrade in place and are told the combined module is deprecated (which is what `deprecated` on variables and outputs is for, TF 1.15 — see **I5**).

!!! tip "A documented exception to module encapsulation, and the condition attached to it"
    > The multi-module refactoring situation is unusual in that it **violates the typical rule that a parent module sees its child module as a "closed box"**, unaware of exactly which resources are declared inside it. **This compromise assumes that all three of these modules are maintained by the same people and distributed together in a single module package.**

    The shim's `moved` blocks name `module.x.aws_instance.a` — a resource *inside* a child module — which is exactly the coupling [[tf-modules-composition]]'s dependency inversion exists to avoid. The docs allow it, name it as a compromise, and state the precondition: **same maintainers, same package.** Do not write cross-module `moved` blocks against someone else's module.

## Address scoping

> Terraform resolves module references in `moved` blocks **relative to the module instance they are defined in.** For example, if the original module above were already a child module named `module.original`, the reference to `module.x.aws_instance.a` would resolve as `module.original.module.x.aws_instance.a`.

> **A module may only make `moved` statements about its own objects and objects of its child modules.**

Relative resolution is why a shim works at any depth. The scoping rule is the safety limit on the encapsulation exception above — you can reach *down*, never up or sideways.

Moving into a counted module needs an explicit key:

```hcl
moved {
  from = aws_instance.example
  to   = module.new[2].aws_instance.example
}
```

## Removing and chaining

The removal rules are quoted in full in [[tut-move-config]], where they correct that tutorial's absolute phrasing: retaining historical blocks is "strongly recommended", and removal is safe only for **private** modules once you are certain every consumer has applied.

The mechanism for making that survivable over time:

> If you need to rename or move the same object **twice**, we recommend **chaining** `moved` blocks to document the full change history:

```hcl
moved {
  from = aws_instance.a
  to   = aws_instance.b
}

moved {
  from = aws_instance.b
  to   = aws_instance.c
}
```

> Recording a sequence of moves in this way allows for successful upgrades for **both** configurations with objects at `aws_instance.a` **and** configurations with objects at `aws_instance.b`. In both cases, Terraform treats the existing object as if it had been originally created as `aws_instance.c`.

That is the whole design in one example: the blocks are not a changelog you keep out of politeness, they are **the upgrade path**, and each one covers consumers arriving from a different starting version. A module's `moved` blocks accumulate for the same reason a database's migrations do.

---
Related: the reference behind [[tut-move-config]], which supplies the hands-on and already carries this page's removal rules. Its instance-key section is the piece missing from [[tut-count]] and [[tut-for-each]], whose `count`-to-`for_each` migration is a destroy-and-recreate without it. The managed-to-data boundary sends you to [[tf-block-removed]]. The shim pattern's closed-box exception is the deliberate counterpoint to [[tf-modules-composition]]'s dependency inversion, and pairs with the `deprecated` argument in [[tf-block-variable]] / [[tf-block-output]]. Imperative alternatives: [[tf-state-refactor]]. Feeds learning-path **A8** (refactoring at scale) as its primary reference, **I5** (authoring modules) for the author-side half — scoping, chaining, and the module-split shim, the fifth `modules/develop` page beside [[tf-modules-develop]], [[tf-modules-structure]], [[tf-modules-composition]] and [[tf-modules-providers]] — and **I7** (state operations).
