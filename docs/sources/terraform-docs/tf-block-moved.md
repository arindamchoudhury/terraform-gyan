# `moved` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/moved](https://developer.hashicorp.com/terraform/language/block/moved)
> **Added:** 2026-08-20
> **Source updated:** undated block reference; captured 2026-08-20 against v1.15.x (latest)
> **Tags:** moved-block, refactoring, resource-addresses, state, block-reference
> **Type:** documentation

*Developer › Terraform › Configuration Language › `moved` block reference · v1.15.x*

The thinnest of the block references — two arguments and one paragraph. Almost everything about `moved` is already in [[tf-modules-refactoring]], which this page points to as *"Refactoring"* and which covers instance-key moves, the `count` ↔ `for_each` migration, and what `moved` cannot do. [[tut-move-config]] is the hands-on.

One thing here is genuinely new, and it is worth the visit.

## Configuration model

| Argument | Type | Required | Description |
|---|---|---|---|
| **`from`** | reference | **yes** | the resource's previous address |
| **`to`** | reference | **yes** | the new address to relocate to |

Both *"allow Terraform to select **modules, resources, and resources inside child modules**."*

```hcl
moved {
  from = aws_instance.a
  to   = aws_instance.b
}
```

## The ordering — rename first, then plan

The paragraph that earns the page its place:

> **Before creating a new plan** for the resource specified in the `to` field, Terraform **checks the state** for an existing object at the address specified in the `from` field. Terraform **renames existing objects** to the string specified in the `to` field and **then creates a plan**. The plan directs Terraform to provision the resource specified in the `from` field as the resource specified in the `to` field. **As a result, Terraform does not destroy the resource during the Terraform run.**

That is the *mechanism* behind an effect every other source states as an outcome. [[tut-move-config]] shows that a rename without `moved` costs a destroy-and-recreate, and that adding the block turns it into a no-op — but not *why*.

The why is the order of operations. The state rename happens **before** the plan is computed, so by the time Terraform diffs configuration against state, the new address already has an object bound to it and there is nothing to create. Without the block, the plan runs against a state where the new address is empty and the old one is unclaimed — which reads as one creation and one deletion, because [[tut-move-config]]'s rule holds: **an address is an identity**.

It also explains why `moved` is safe to leave in place. A block whose `from` no longer matches anything in state finds nothing to rename, and the plan proceeds unchanged.

## Where `moved` sits against `import` and `removed`

With all three block references captured, the instance-key question has a complete answer, and it is not symmetric:

| Block | Instance keys in the address? |
|---|---|
| **`import`** — `to` | **Yes.** `aws_instance.example[0]`, `aws_instance.example["env"]` ([[tf-block-import]]) |
| **`moved`** — `from` / `to` | **Yes, on either side**, and mixing index and key is how a `count` → `for_each` migration is expressed ([[tf-modules-refactoring]]) |
| **`removed`** — `from` | **No.** *"You cannot include instance keys… if the resource is configured to provision multiple instances"* ([[tf-state-remove]]) |

So `removed` is the odd one out. A multi-instance resource can be adopted per instance and rearranged per instance, but only forgotten wholesale.

## Defect

!!! warning "The types contradict each other, again"
    The configuration model types `from` and `to` as **reference**; the Specification table below it types both as **string**. The example writes them unquoted — `from = aws_instance.a` — which is a reference, so the model is right and the table is wrong.

    Third block reference in a row with a type or syntax contradiction between its own sections, after `identity` (map versus String) in [[tf-block-import]] and `include_resource` (Default: None versus false) in [[tf-block-list]]. The prose and the models hold up; the tables and samples do not.

## What this page does not cover

Everything practical, in fairness to it — it is a reference, and the how-to is elsewhere. Worth knowing which page has what: **instance-key and `count`/`for_each` moves**, **module splits and shim modules**, **what `moved` cannot do** (no cross-type moves, no `resource` → `data`), and the **removal rules** are all in [[tf-modules-refactoring]]. The single-state-file limitation is in [[tf-state-refactor]] and [[tut-state-cli]].

---
Related: [[tf-modules-refactoring]] — the deep reference; instance keys, migrations, and the limits. · [[tut-move-config]] — the hands-on, and the address-is-identity rule this page's ordering paragraph explains. · [[tf-block-import]] · [[tf-state-remove]] — the other two refactoring blocks, and the instance-key asymmetry between them. · [[tf-state-refactor]] — moving across state files, which `moved` cannot do.
