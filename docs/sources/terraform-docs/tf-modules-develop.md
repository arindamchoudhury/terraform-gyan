# Creating Modules

> **Source:** [developer.hashicorp.com/terraform/language/modules/develop](https://developer.hashicorp.com/terraform/language/modules/develop)
> **Added:** 2026-08-08
> **Source updated:** undated language reference; captured 2026-08-08 against v1.15.x (latest)
> **Tags:** modules, module-design, abstraction, composition, module-structure, refactoring, no-code-modules
> **Type:** documentation

*Developer › Terraform › Configuration Language › Modules › Develop modules › Overview · v1.15.x*

The author-side index, opposite [[tf-modules-configuration]]. Short, and older in style than its neighbours — the sidebar lists it as **Overview** while the page's own H1 is still **Creating Modules**, and its prose keeps the first-person "we recommend" voice that the retitled task-oriented pages around it have dropped. Most of its length is pointers to `Standard module structure`, `Providers within modules`, `Best practices for composing modules`, `Publish modules`, and `Refactor modules`.

It earns its keep on one section: **when *not* to write a module.**

## A third definition, and the one that says why

> A module is a **container for multiple resources that are used together**. You can use modules to create **lightweight abstractions, so that you can describe your infrastructure in terms of its architecture, rather than directly in terms of physical objects.**

That is now three official definitions across three pages, and they stack rather than compete:

| Source | Definition | What it establishes |
|---|---|---|
| [[tut-module]] | "a set of Terraform configuration files in a single directory" | the mechanism — hence "every configuration is already a module" |
| [[tf-modules]] | "a collection of resources that Terraform manages together" | the unit — hence scoping is a real question |
| here | "a container for multiple resources that are used together", raising the level of abstraction | the **purpose** — hence some groupings are not worth making |

Only the third gives you grounds to say a module is a *bad* module.

Root module, restated: "The `.tf` files in your working directory when you run `terraform plan` or `terraform apply` together form the root module. That module may call other modules and connect them together by **passing output values from one to input values of another**."

## Structure, in one paragraph

Modules use the same language constructs as root modules — most commonly **input variables** (accept values from the caller), **output values** (return results the caller can use elsewhere), and **resources**. To define one, "create a new directory for it and place one or more `.tf` files inside just as you would do for a root module."

> Modules can also call other modules using a `module` block, but we recommend **keeping the module tree relatively flat** and using **module composition** as an alternative to a deeply-nested tree of modules, because this makes the individual modules easier to re-use in different combinations.

Same conclusion as [[tut-pattern-module-creation]]'s "generally, do not nest primary modules more than two deep", but with the reason stated differently. The tutorial argues from error risk and redundancy; this argues from **recombination** — a flat tree of composable modules can be assembled in more ways than a deep one.

## When to write a module — the useful part

> In principle any combination of resources and other constructs can be factored out into a module, but **over-using modules can make your overall Terraform configuration harder to understand and maintain**, so we recommend moderation.

> A good module should **raise the level of abstraction by describing a new concept in your architecture** that is constructed from resource types offered by providers.

The worked example: `aws_instance` and `aws_elb` are provider resource types; a module might represent "HashiCorp Consul cluster running in AWS", which is a concept the provider does not have.

And then the test worth memorizing:

> We do not recommend writing modules that are just **thin wrappers around single other resource types**. **If you have trouble finding a name for your module that isn't the same as the main resource type inside it, that may be a sign that your module is not creating any new abstraction** and so the module is adding unnecessary complexity. Just use the resource type directly in the calling module instead.

!!! tip "Two heuristics, opposite failure modes — carry both"
    This page and [[tut-pattern-module-creation]] each give a one-line smell test, and they guard different errors:

    - **Too big** — *"If a module's function or purpose is hard to explain, the module is probably too complex."*
    - **Not an abstraction** — *"If you have trouble finding a name for your module that isn't the same as the main resource type inside it…"*

    Between them: a module should be nameable in a phrase that is **neither a paragraph nor a resource type**. That is a sharper target than either page alone.

    It also qualifies the tutorial's "aim for small and simple to start". Small is a scoping instruction, not a licence to wrap one resource — a module that is `aws_instance` plus five variables has scope but no abstraction.

!!! note "The registry's own popular modules fail the naming test, and that's informative"
    `terraform-aws-modules/ec2-instance/aws` — consumed in [[tut-module-use]] — is named for `aws_instance`, exactly what this page warns about. But at v6.4.0 it also creates an IAM instance profile, a security group, an EIP, and EBS volumes on demand (verified 2026-08-08 in `cache/search/aws-modules-current-versions.md`), so it *does* add abstraction over the bare resource type.

    So the heuristic is a **smell detector, not a rule**: it catches modules whose name reveals no new concept, and a module can fail it while still earning its keep. Treat a resource-type-shaped name as a prompt to check whether the module does anything the resource doesn't — not as a verdict.

## Two pointers worth knowing exist

**No-code ready modules** — "You can also create no-code ready modules to enable the no-code provisioning workflow in HCP Terraform… No-code ready modules have **additional requirements and considerations**." Those requirements are the inverted rules in [[tut-no-code-provisioning]]: provider blocks declared *inside* the module, and all resources in the repository root.

**Refactoring blocks** — described generically rather than by name:

> You can include refactoring blocks to record how resource names and module structure have changed from previous module versions. Terraform uses that information during planning **to reinterpret existing objects as if they had been created at the corresponding new addresses**, eliminating a separate workflow step to replace or migrate existing objects.

"Reinterpret existing objects as if they had been created at the corresponding new addresses" is the most precise one-line statement of what `moved` does — and it makes clear why the plan still showed `3 to change` in [[tut-move-config]]: reinterpreting *where* an object came from says nothing about whether its desired configuration still matches.

---
Related: the author-side counterpart to [[tf-modules-configuration]], both under [[tf-modules]]'s Develop/Distribute/Provision split. Its abstraction test complements [[tut-pattern-module-creation]]'s complexity test, and its flat-tree advice restates that page's two-deep rule from a recombination angle. No-code requirements: [[tut-no-code-provisioning]]. Refactoring blocks: [[tut-move-config]] and [[tf-block-removed]]. Hands-on for this section: [[tut-module-create]] and [[tut-module-object-attributes]]. Feeds learning-path **I5** (authoring modules) as its reference index.
