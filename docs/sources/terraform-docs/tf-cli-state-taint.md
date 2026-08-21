# Recreate Resources Overview

> **Source:** [developer.hashicorp.com/terraform/cli/state/taint](https://developer.hashicorp.com/terraform/cli/state/taint)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest)
> **Tags:** cli, state, replace-flag, taint, untaint, degraded-objects, provisioners, section-index
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Forcing Re-creation (Tainting) › Overview · v1.15.x*

The section index for `-replace`, `taint` and `untaint`. Its URL and its sidebar group are both named after tainting, but **the page itself leads with `-replace` and deprecates `taint` in its closing paragraph.** The labels are stale; the content is current.

!!! note "Correcting an earlier note in this collection"
    [[tf-cli-state]] flags its parent index for routing *Re-create resources* to `cli/state/taint` without naming `-replace`, and adds that a reader following the sidebar top-down "meets the deprecated pair first". **The first half stands, the second does not.** The parent's link text and the sidebar group name are both tainting-flavoured, but the page they lead to opens on `-replace` and names `taint` only to deprecate it. What is stale here is the naming, not the guidance.

## Why replacement is a manual affair at all

The page builds the case before giving the commands, and the argument is about the **limits of what a resource is**:

> "When remote objects become damaged or degraded, such as when software running inside a virtual machine crashes but the virtual machine is still running, Terraform does not have no way to detect and respond to the problem. **This is because Terraform only directly manages the machine as a whole.**"

That is the cleanest statement in the captured docs of where the resource abstraction stops. `apply` compares the object with the configuration and acts only on mismatches — and a crashed process inside a running VM is not a mismatch. The provider reports a healthy instance because the instance *is* healthy at the layer the provider models. This is the same boundary [[tut-state-import]] runs into from the other direction, where an import reports current state but never health or intent, and the reason [[pyinfra]] and configuration-management tools exist next to Terraform rather than inside it.

**Terraform does infer degradation in two cases**, and flags those objects itself:

- a complex object "partially created in the remote system"
- "a provisioner step failed"

The second is already in the path from the provisioner side: a failed provisioner defaults to `on_failure = fail`, which taints the resource. This page is the other half of that sentence — the taint is *why* the next apply rebuilds it.

## The two workflows

**Manual — `-replace`:**

```shell
terraform apply -replace="aws_instance.example"
```

```
  # aws_instance.example will be replaced, as requested
-/+ resource "aws_instance" "example" {
```

*As requested* is the plan's way of distinguishing an operator-forced replacement from one the diff demanded.

**Inferred — tainted status:**

```
  # aws_instance.example is tainted, so must be replaced
-/+ resource "aws_instance" "example" {
```

> "Terraform applies the tainted status to objects in the state data when Terraform is able to infer that the object is in a degraded or damaged state… Terraform **replaces objects in a tainted states during the next plan or apply operation**."

So tainting is not only a command — it is a **state field Terraform sets on its own**, and the `taint` command was just a way to write it by hand. That distinction is what makes the deprecation coherent: the status stays, the manual write goes.

`untaint` is the override in the other direction, for when Terraform inferred damage and you disagree. After it, Terraform "will consider the object to be ready for use by any **downstream resource declarations**" — the phrase that matters, since a tainted object poisons what depends on it, not just itself.

## The deprecation, with the reason attached

> "You can force Terraform to mark a particular object as tainted using the `terraform taint` command, but that approach is **deprecated in favor of the `-replace=...` option, which avoids the need to create an interim state snapshot with a tainted object**."

The path and both books already say `taint` mutated state out-of-band with no plan to review ([[tut-state-cli]], [[05-terraform-plan]] §5, [Ch 3](../../book/ch03-core-workflow.md)). This is HashiCorp stating the same thing as a mechanism rather than as advice: `taint` had to **write an interim state snapshot** to record the intent, and `-replace` carries the intent through the plan instead, so state is written once, at apply, like any other change.

## Page flaws

Three in a short page, all typographical: *"Terraform does not have no way to detect"*, *"When you meed to replace an object"*, and *"objects in a tainted states"*. The same unproofread quality as [[tf-cli-state]] two levels up.

---
Related: [[tf-cli-state]] — the parent index, whose *Re-create resources* label is what this note corrects. · [[tut-state-cli]] — the hands-on `-replace`, and the tutorial that dates it to 0.15.2. · [[05-terraform-plan]] — TID Ch5's treatment of replace as a planning mode. · [[tf-cmd-state]] — where the rest of the state-writing family lives; `-replace` deliberately is not part of it. · [[tut-state-import]] — the other place the docs concede that state records existence, not health.
