# `removed` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/removed](https://developer.hashicorp.com/terraform/language/block/removed)
> **Added:** 2026-07-10
> **Source updated:** undated language reference; captured 2026-07-10, re-verified 2026-08-20 — still v1.15.x (latest)
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

!!! note "Re-verified 2026-08-20 — the contradiction is still there"
    Re-fetched and diffed against the July capture. **One change in six weeks**, and it is a typo fix: *"the command specified in the **the** command argument"* lost its duplicated word in the `working_dir` description. Nothing else moved.

    In particular, problem 1 below is unchanged. The opening sentence still says the block removes a resource *"without changing the underlying infrastructure"*, and the `lifecycle` section still says *"By default, Terraform removes the resource from state **and destroys the actual resource**."* Six weeks on, the page still tells you on line one that it is safe by default when it is not.

## Three problems with this page

**1. The page contradicts itself.** Its opening sentence:

> "The `removed` block specifies a resource to remove from state **without changing the underlying infrastructure**."

Its `lifecycle` section says the default *does* destroy. Both cannot be true. The experiment agrees with the `lifecycle` section.

**2. `lifecycle` is documented as `required`** in the configuration model (`lifecycle   block | required`), but Terraform **accepts a `removed` block without it** — `terraform validate` returns `Success! The configuration is valid.` and `plan` proceeds to destroy.

!!! note "Settled 2026-08-21 in the source — it is `destroy = true`, not “ignored”"
    The open question here was whether a missing `lifecycle` means `destroy = true`, or whether Terraform ignores the `removed` block and destroys the object simply for being absent from configuration. The plan's reason line, `# (because terraform_data.keep is not in configuration)`, hinted at the latter. **It is the former.**

    `internal/configs/removed.go` at tag `v1.15.8` sets `removed.Destroy = true` *before* it iterates the block's contents looking for `lifecycle`, so an omitted `lifecycle` simply leaves the default standing. The same file shows `lifecycle` is **not** required: only `from` carries `Required: true`, and `destroy` inside `removedLifecycleBlockSchema` is an optional attribute. The docs' "required" is wrong at both 1.7 and 1.15.

**3. ~~The behavior changed across versions.~~ Corrected 2026-08-21 — it never changed.**

!!! danger "This note previously had the version history backwards"
    It read: *"So `removed` began (1.7) as forget-only, and `destroy` arrived later as an argument whose default is `true`. TID's 'mark an item removed without destroying it' was correct for the version it was written against and is now stale. This is version drift, not a book error."*

    **All of that is false.** Verified in the source: `internal/configs/removed.go` at tag **`v1.7.0`**, the release the block shipped in, already declares `Destroy bool`, already parses `lifecycle { destroy }`, and already defaults `removed.Destroy = true`. The Terraform **v1.7.0 CHANGELOG** announces the block as letting authors *"inform Terraform whether the corresponding object should be deleted or simply removed from state"* — both directions, from the first release.

    The **v1.7 documentation agreed**. Both of its examples, the resource form and the module form, were written with `destroy = false`, and it stated: *"The `destroy` argument determines whether Terraform will attempt to destroy the object managed by the resource or not."*

    **Where the error came from:** the sentence quoted below was read in isolation. It is the lead-in to that `destroy = false` example, not a description of the default.

    > "To declare that a resource was removed from Terraform configuration but that its managed object **should not be destroyed**, remove the `resource` block from your configuration and replace it with a `removed` block:"

    The clause after the comma is the half that was dropped. Consequence for the collection: **there is no version in which a bare `removed` block was safe**, so TID's phrasing was imprecise when written rather than overtaken by a change, and the current page's self-contradicting opening sentence is a live documentation bug rather than a stale leftover.

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

!!! note "Same two-position rule as a live `resource`, and the argument list is elsewhere"
    This mirrors the normal case exactly. HashiCorp's [provisioners page](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax) states it for a live resource: "Add a `connection` block to either the `provisioner` block or to the `resource` block. All provisioners in the configuration can use connection settings defined in the `resource` block. Connection settings defined in the `provisioner` block are specific to that provisioner." A `removed` block simply takes the `resource` block's role.

    Neither page carries the arguments. The **`connection` block reference** is a section of the [`resource` block reference](https://developer.hashicorp.com/terraform/language/block/resource#connection), captured in [[tf-block-resource]] — roughly 25 arguments, including the bastion and proxy sets. The standalone `/provisioners/connection` URL **redirects to** `/provisioners/syntax`; there is no separate connection page any more (checked 2026-08-02).

!!! warning "HashiCorp still recommends against provisioners"
    The page repeats the standing warning: "We recommend using configuration management tools to perform actions on the local or remote machine instead of using provisioners." → learning-path **A1**.

---
Related: [[tf-block-resource]] — holds the `connection` block's argument reference, which this page's placement rules assume but never list. · [[tf-destroy-resource]] — the how-to that points here for destroy-time operations. · [[tf-terraform-data]] — the resource used to verify the destroy-vs-forget behavior. · [[feature-history]] — `removed` arrived in v1.7.0; the `destroy` argument is later. · [[meta-arguments-lifecycle]] — `lifecycle` here is a *restricted* form, supporting only `destroy`. · [[ot-dynamic-prevent-destroy]] — OpenTofu's `destroy = false` lives on the **resource's** `lifecycle`, not on a `removed` block. ⏳ Terraform **1.16** adds the resource-level form too (rc1 as of 2026-08-13), so this stops being a divergence; through 1.15 the `removed` block is Terraform's only route ([[release-feature-map]]).
