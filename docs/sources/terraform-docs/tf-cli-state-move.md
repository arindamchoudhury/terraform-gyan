# Move Resources

> **Source:** [developer.hashicorp.com/terraform/cli/state/move](https://developer.hashicorp.com/terraform/cli/state/move)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest)
> **Tags:** cli, state, state-mv, state-rm, replace-provider, moved-block, refactoring, section-index
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Moving Resources › Overview · v1.15.x*

The section index for `state mv`, `state rm` and `state replace-provider`. Unlike its siblings in this collection it argues a position before listing commands: **use the language, not the CLI**, and reach for these three only when the language cannot express what you need.

## Why an address can be lost at all

> "Terraform's state associates each real-world object with a configured resource **at a specific resource address**. This is seamless when changing a resource's attributes, but Terraform will **lose track** of a resource if you change its name, move it to a different module, or **change its provider**."

Three ways to break the association, and the third is the useful one. It confirms what the parent index only implied by filing `replace-provider` under *Moving Resources* ([[tf-cli-state]]): **a provider change is an address change**, because the provider is part of what binds an object to a configured resource. Not a taxonomy quirk.

What happens when the binding breaks is stated with a shrug that is worth noticing:

> "**Usually that's fine**: Terraform will destroy the old resource, replace it with a new one (using the new resource address), and update any resources that rely on its attributes."

This is the address-is-identity rule from [[tut-move-config]] and the I7 model of state, phrased from the opposite side. Destroy-and-recreate is the *normal, correct* outcome of a renamed address. Everything in this section exists for the minority of cases where the object must survive — "where it's important to preserve an existing infrastructure object".

## The recommendation, and the reason given for it

> "For most cases we recommend using the Terraform language's **refactoring features** to document in your module exactly how the resource names have changed over time. Terraform reacts to this information automatically during planning, so **users of your module do not need to take any unusual extra steps**."

The argument is not the one this project has been recording. Elsewhere `moved` is justified by *mechanism* — the state rename happens before the plan is computed, so no destroy is proposed ([[tf-block-moved]]). Here it is justified by **audience**: a `moved` block is durable documentation that travels with the module, and it spares every consumer a manual CLI step they would otherwise have to know about and perform correctly.

That reframes the choice for module authors specifically. A `state mv` fixes your state; a `moved` block fixes everyone's.

Hands-on link: *Use Configuration to Move Resources* — [[tut-move-config]], already captured, and the page that supplies the address-is-identity demonstration.

## The three commands

| Command | The page's description | Captured |
|---|---|---|
| `state mv` | "changes which resource address in your configuration is associated with a particular real-world object. Use this to preserve an object when **renaming** a resource, or when moving a resource **into or out of a child module**." | no — used in [[tf-state-refactor]], [[tut-state-cli]] |
| `state rm` | "tells Terraform to **stop managing** a resource as part of the current working directory and workspace, **without destroying** the corresponding real-world object. (You can later use `terraform import` to start managing that resource in a different workspace or a different Terraform configuration.)" | no — see [[tf-state-remove]] for the language alternative |
| `state replace-provider` | "transfers existing resources to a new provider **without requiring them to be re-created**." | no |

Two things follow.

**`state rm` plus `import` is the documented cross-configuration handoff.** The parenthetical is the whole migration pattern in one sentence, and it matches [[tf-state-refactor]]'s modern recommendation of `removed` + `import` blocks — with the same asymmetry recorded there and in [[tf-state-remove]]: leaving is not undone by editing configuration, coming back requires an import.

!!! warning "The language-first advice stops short of the `removed` block"
    The page recommends the language's refactoring features *"for most cases"*, then lists `state rm` with no mention that the language has an equivalent for it. It does — the **`removed` block** (1.7+), which [[tf-state-remove]] says HashiCorp prefers over the command, in its own words: *"the `removed` block lets you preview the results of the operation, which makes it a safer way to remove resources."*

    So the section that argues for language features over CLI surgery names the language feature for **renaming** and omits the one for **forgetting**. Not a contradiction, an omission — but it points the reader at `state rm` where the docs elsewhere point them away from it.

---
Related: [[tf-cli-state]] — the parent index that files a provider change as a move; this page says why. · [[tf-block-moved]] — the mechanism argument for `moved`, next to this page's audience argument. · [[tut-move-config]] — the hands-on this page links, and the address-is-identity demonstration. · [[tf-state-refactor]] — the cross-configuration migration these commands serve, and where `removed` + `import` replaces `state mv`. · [[tf-state-remove]] — the language alternative to `state rm` that this page does not mention.
