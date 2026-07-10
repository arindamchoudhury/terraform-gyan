# `removed` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/removed](https://developer.hashicorp.com/terraform/language/block/removed)
> **Added:** 2026-07-10
> **Source updated:** undated language reference; captured 2026-07-10 against v1.15.x (latest)
> **Tags:** removed-block, destroy, state, refactoring, destroy-time-provisioner, connection, breaking-change
> **Type:** documentation

*Developer › Terraform › Configuration Language › State › `removed` block reference · v1.15.x*
*(The sidebar lists this page twice — also under Reference › Configuration blocks. Filed under the task section, per convention.)*

Captured because [[tf-destroy-resource]] leans on it, and because reading it exposed a **wrong claim repeated across four of our own documents**.

## The correction: `removed` destroys by default

Our notes, the learning path, and TID Ch2 §2.9 all said the `removed` block drops a resource from state **without** destroying it. On current Terraform that is **false and dangerous** — it's the description of `destroy = false`, which is the opt-*out*.

Verified on **Terraform v1.15.6** with a `terraform_data` resource (no provider plugin):

| `removed` block | `terraform plan` says | Result |
|---|---|---|
| no `lifecycle` block | `# terraform_data.keep will be destroyed` · `Plan: 0 to add, 0 to change, 1 to destroy.` | **destroyed** |
| `lifecycle { destroy = false }` | `# terraform_data.keep will no longer be managed by Terraform, but will not be destroyed` · `Plan: 0 to add, 0 to change, 0 to destroy.` + a warning | **forgotten** |
| `lifecycle { destroy = true }` | `# terraform_data.keep will be destroyed` | **destroyed** |

The docs state it plainly in the `lifecycle` section:

> "**By default, Terraform removes the resource from state and destroys the actual resource.** Set `destroy` to `false` to remove the resource from state without destroying the actual resource. This allows you to hand off management responsibilities to another tool or team after using Terraform for the initial provisioning."

!!! danger "Converting a `resource` block to a bare `removed` block will destroy the object"
    If your intent is "stop managing this, leave it running," you **must** write `lifecycle { destroy = false }`. Omitting `lifecycle` is not neutral.

## Three problems with this page

**1. The page contradicts itself.** Its opening sentence:

> "The `removed` block specifies a resource to remove from state **without changing the underlying infrastructure**."

Its `lifecycle` section says the default *does* destroy. Both cannot be true. The experiment agrees with the `lifecycle` section.

**2. `lifecycle` is documented as `required`** in the configuration model (`lifecycle   block | required`), but Terraform **accepts a `removed` block without it** — `terraform validate` returns `Success! The configuration is valid.` and `plan` proceeds to destroy.

> ❓ Unverified: whether Terraform treats a missing `lifecycle` as `destroy = true`, or ignores the `removed` block entirely and destroys the object simply because it is absent from configuration. The plan's reason line reads `# (because terraform_data.keep is not in configuration)`, which hints at the latter. Either way the observable outcome is identical: **the object is destroyed.**

**3. The behavior changed across versions.** The **v1.7.x** and **v1.11.x** docs both describe the block as:

> "To declare that a resource was removed from Terraform configuration but that its managed object **should not be destroyed** …"

So `removed` began (1.7) as forget-only, and `destroy` arrived later as an argument whose default is `true`. TID's "mark an item removed *without* destroying it" was correct for the version it was written against and is now **stale**. This is version drift, not a book error.

## Configuration model

```hcl
removed {
  from = "<resource.address>"

  lifecycle {
    destroy = <true | false>
  }

  connection {
    <connection-settings>
  }

  provisioner "<TYPE>" {
    when = destroy
    <provisioner-type-arguments>
  }
}
```

| Argument | Notes |
|---|---|
| `from` | The resource address being removed. |
| `lifecycle` | Documented as required; `destroy` is its **only** supported argument for `removed` blocks. |
| `connection` | Settings letting provisioners reach the resource *during removal*. |
| `provisioner "<TYPE>"` | Destroy-time provisioner. Must set `when = destroy`. |

## Destroy-time provisioners

A destroy-time provisioner normally lives inside the `resource` block — which you are deleting. The `removed` block is where it survives.

From the **v1.11.x** docs, stated more precisely than the current page:

> "The same referencing rules apply as in normal destroy-time provisioners, with only `count.index`, `each.key`, and `self` allowed. The provisioner **must specify `when = destroy`**, and the **`removed` block must use `destroy = true`** in order for the provisioner to execute."

So the two flags interlock: `destroy = false` forgets the object, and therefore **cannot** run a destroy-time provisioner — there is no destroy to hook.

## `connection` placement

Two valid positions, with different scope:

- **On the `removed` block** — default connection settings for *all* provisioners defined for the resource being removed.
- **On a `provisioner` block** — settings specific to that provisioner.

!!! warning "HashiCorp still recommends against provisioners"
    The page repeats the standing warning: "We recommend using configuration management tools to perform actions on the local or remote machine instead of using provisioners." → learning-path **A1**.

---
Related: [[tf-destroy-resource]] — the how-to that points here for destroy-time operations. · [[tf-terraform-data]] — the resource used to verify the destroy-vs-forget behavior. · [[feature-history]] — `removed` arrived in v1.7.0; the `destroy` argument is later. · [[meta-arguments-lifecycle]] — `lifecycle` here is a *restricted* form, supporting only `destroy`. · [[ot-dynamic-prevent-destroy]] — OpenTofu's `destroy = false` lives on the **resource's** `lifecycle`, not on a `removed` block.
