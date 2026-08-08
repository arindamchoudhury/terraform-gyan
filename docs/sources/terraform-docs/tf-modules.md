# Modules overview

> **Source:** [developer.hashicorp.com/terraform/language/modules](https://developer.hashicorp.com/terraform/language/modules)
> **Added:** 2026-08-08
> **Source updated:** undated language reference; captured 2026-08-08 against v1.15.x (latest)
> **Tags:** modules, root-module, child-module, module-sources, registry, module-workflow
> **Type:** documentation

*Developer › Terraform › Configuration Language › Modules › Overview · v1.15.x*

The index page of the language reference's **Modules** section — deliberately thin, and mostly a set of pointers to `Use modules`, `Develop modules`, and `Publish modules`. Worth capturing for two things: a definition that differs from the tutorials', and a three-phase frame that the rest of the section is organized around.

## The definition is not the one the tutorials give

> A module is a **collection of resources** that Terraform manages together.

Compare [[tut-module]], which is equally official:

> A Terraform module is a **set of Terraform configuration files in a single directory**.

One is semantic, one is structural, and both are true — a directory of `.tf` files is the *mechanism*, the resources managed together are the *thing*. The structural definition is what makes "every configuration is already a module" true; this one is what makes the scoping question in [[tut-pattern-module-creation]] meaningful. If a module is just a directory, "what belongs in it?" has no answer; if it is a set of resources managed together, Encapsulation/Privileges/Volatility follow.

The motivation is stated once and moves on:

> When you repeatedly provision collections of resources with similar configuration, such as networking resources for new development environments, you should write reusable modules to codify them.

## Hierarchy

- **Root module** — "Every Terraform workspace includes configuration files in its root directory. Terraform refers to this configuration as the root module."
- **Child module** — one configured through a `module` block. "When you apply a configuration, the root module calls the child module. As a result, Terraform adds the child module's resources to your workspace and manages them as part of the configuration."
- The root module can call the **same child multiple times**, and a child can call **its own nested child**.

That last sentence is the only mention of nesting on this page; the depth guidance ("generally, do not nest primary modules more than two deep") lives in [[tut-pattern-module-creation]], not here.

!!! note "“Workspace” is doing loose duty in that sentence"
    "Every Terraform workspace includes configuration files in its root directory" means the *working directory*. Terraform has two other things called workspaces — CLI workspaces and HCP workspaces ([[tf-state-workspaces]], [[workspaces]]) — and neither is what is meant. The rest of the section uses "root directory" and "configuration", which is clearer.

## Sources

Local filesystem, a Terraform registry, or VCS repositories. Two registries, with different provenance:

- **Public registry** — "created and maintained by HashiCorp, our partners, and the Terraform community. They are free to use and Terraform can download them automatically if you specify the appropriate `source` and `version` in a `module` block." Note the mixed provenance: HashiCorp, partners, and anyone. That is why the review checklist in [[tut-private-registry-add]] (owner, publication date, download count, source repo) matters before you adopt one.
- **Private registry** — HCP Terraform and Terraform Enterprise, "for sharing modules internally within your organization." Publishing into it is [[tut-module-private-registry-share]].

The full address syntax is on `Module Sources`, not here; the constraint operators are [[tf-expr-version-constraints]].

## The three-phase workflow

The frame the whole section is built on, quoted in full:

> **Develop:** Module developers collect resource configurations into a module. Modules follow a standard structure and should include documentation.
>
> **Distribute:** Terraform lets users access modules from several kinds of sources, including S3 buckets and GitHub repositories. The most common method is to publish your module to the public Terraform registry or to a private registry.
>
> **Provision:** Module consumers can use the `module` block in their configurations to call modules published to one of the supported kinds of sources.

Useful because it separates three things that get discussed as one. It also maps cleanly onto the tutorial collection: **Develop** is [[tut-module-create]], [[tut-module-object-attributes]] and [[tut-pattern-module-creation]]; **Distribute** is [[tut-module-private-registry-share]] and [[tut-private-registry-add]]; **Provision** is [[tut-module-use]]. [[tut-move-config]] belongs to none of the three — refactoring is what happens after all of them.

!!! note "What this section contains, for later capture"
    The sidebar's **Modules** group (rung 1, `__NEXT_DATA__ → sidebarNavDataLevels`, read 2026-08-08) has eight pages, of which this note is one:

    Overview · Use modules · **Develop modules** (Overview, Standard module structure, Providers within modules, Best practices for composing modules, Publish modules, Refactor modules) · module block reference.

    Two of those are already reachable through other notes — `Refactor modules` supplied the `moved`-block removal rule quoted in [[tut-move-config]], and `Publish modules` the registry naming requirements in `cache/search/module-repo-naming-convention.md` — but neither is captured as its own note yet.

---
Related: the language-reference entry point for everything the HashiCorp tutorials teach hands-on. Its definition complements [[tut-module]]'s; its Develop/Distribute/Provision split organizes the whole tutorial collection. Registry provenance and the case for reviewing before adopting: [[tut-private-registry-add]]. Private registry publishing: [[tut-module-private-registry-share]]. Version pinning: [[tf-expr-version-constraints]], with the gap it leaves in [[tf-dependency-lock]]. Feeds learning-path **I4** (using modules) and **I5** (authoring modules) as their reference index.
