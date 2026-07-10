# Destroy a resource

> **Source:** [developer.hashicorp.com/terraform/language/resources/destroy](https://developer.hashicorp.com/terraform/language/resources/destroy)
> **Added:** 2026-07-10
> **Source updated:** undated language how-to; captured 2026-07-10 against v1.15.x (latest)
> **Tags:** destroy, removed-block, destroy-time-provisioner, target, state
> **Type:** documentation

*Developer › Terraform › Configuration Language › Resources › Destroy a resource · v1.15.x*

Short how-to sitting beside [[tf-configure-resource]] under Resources. The mechanics are already covered by [[tf-aws-destroy]] (the tutorial) and the book's Ch3. Captured for the **third** method, which the path never mentions, and for the correction it forced (see [[tf-block-removed]]).

## Three ways to destroy

1. **Remove the resource from the configuration.** On `apply`, Terraform diffs config against state and destroys the real object that no longer appears in config.
2. **`terraform destroy`** — destroy everything in the working directory, or use **`-target`** to destroy specific resources.
3. **Replace the `resource` block with a `removed` block** and add a **destroy-time provisioner**, to perform extra operations (printing a message, draining a node) as Terraform destroys it.

Method 3 is the one worth learning here. Methods 1 and 2 are already in [[tf-aws-destroy]].

## Destroy a single resource

1. Delete the `resource` block.
2. Delete any references to the resource's attributes. **`terraform validate` finds them for you.**
3. Run `terraform apply`.

Terraform destroys the real object and removes it from state.

!!! tip "`validate` as a reference-finder"
    Step 2 is the one people miss: a dangling `aws_instance.foo.id` elsewhere in the config blocks the plan. `terraform validate` is a cheap way to enumerate them before you `apply`.

## Destroy all infrastructure

`terraform destroy` tears down everything Terraform manages in the current working directory.

!!! note "`destroy` doesn't touch your configuration"
    > "The `terraform destroy` command **does not update the Terraform configuration**. As a result, you can run `terraform apply` to create new instances of the destroyed infrastructure."

    That is the difference from method 1. Deleting the block is permanent until you write it back; `terraform destroy` is a teardown of the *objects* only, so the config is still there to rebuild from. [[tf-aws-destroy]] makes the same distinction from the tutorial side.

## Configure destroy-time operations

> "You can configure Terraform to perform additional operations when destroying a resource by **replacing the `resource` block** in your configuration **with a `removed` block** and adding a **destroy-time provisioner**."

The pattern exists because a destroy-time provisioner normally lives *inside* the resource block — and you're deleting that block. The `removed` block is where it goes to survive.

!!! danger "A `removed` block destroys by default — it does not merely 'forget'"
    This page links `removed` for destroy-time operations without saying what `removed` does to the object. Per [[tf-block-removed]] and verified on **v1.15.6**:

    - `removed` with **no `lifecycle` block** → the object is **destroyed**.
    - `removed` with `lifecycle { destroy = false }` → the object is **forgotten**, not destroyed.

    Several of our notes had this backwards. See [[tf-block-removed]] for the experiment and the docs' own self-contradiction.

    For the destroy-time-provisioner pattern this is what you want — the v1.11 docs state the provisioner "must specify `when = destroy`, and the `removed` block must use `destroy = true` in order for the provisioner to execute."

## Pointers the page gives

- **Remove a resource from state** (without destroying) — a separate page; that's the `destroy = false` path.
- **Refactor modules** — for reorganizing rather than removing.

---
Related: [[tf-block-removed]] — the `removed` block reference; the destroy-vs-forget semantics live there. · [[tf-aws-destroy]] — the same teardown paths from the AWS Get Started tutorial. · [[tf-configure-resource]] — its sibling under Resources. · [[dependency-graph]] — destroy walks the graph in reverse, so a missing `depends_on` breaks teardown too.
