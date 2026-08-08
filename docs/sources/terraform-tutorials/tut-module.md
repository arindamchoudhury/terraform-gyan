# Modules overview

> **Source:** [developer.hashicorp.com/terraform/tutorials/modules/module](https://developer.hashicorp.com/terraform/tutorials/modules/module)
> **Added:** 2026-08-08
> **Source updated:** undated tutorial (~7 min); captured 2026-08-08
> **Tags:** modules, root-module, child-module, encapsulation, re-use, module-sources, best-practices
> **Type:** documentation

First page of the **Modules** collection, and the only conceptual one — no code to run, no repo to clone. It sets up the rest of the collection ([Use modules](https://developer.hashicorp.com/terraform/tutorials/modules/module-use) is next). Read it as the *why*; the module block mechanics live in [[tf-aws-manage]] and the version-pinning rules in [[tf-expr-version-constraints]].

## The problem modules solve

There is no hard limit on how big a single configuration directory can get, so you *can* keep piling `.tf` files into one directory. The tutorial lists what happens when you do:

- Navigating and understanding the files gets harder.
- Updates get risky — a change in one section has unintended consequences elsewhere.
- Duplication grows, especially across separate dev/staging/production environments, and every update has to be made in each copy.
- Sharing config between projects and teams degenerates into copy-paste, which is "error prone and hard to maintain".
- Readers need more Terraform expertise to change anything, which slows down self-service for other teams.

## What are modules for?

Five benefits, one per problem above.

**Organize configuration** — keep related parts together. Even moderately complex infrastructure runs to hundreds or thousands of lines; modules break it into logical components.

**Encapsulate configuration** — distinct logical components prevent a change in one place from touching unrelated infrastructure, and reduce simple errors like reusing the same name for two different resources.

**Re-use configuration** — consume modules written by you, your team, or the community instead of writing everything from scratch. Sharing works in both directions.

**Provide consistency and ensure best practices** — the argument here is a security one, not just a tidiness one. Object storage (S3, GCS) has many configuration options, there have been many high-profile incidents from misconfigured buckets, and a module is where you encode the correct settings once. The worked example: one module for the org's public website buckets, another for private logging buckets. When the settings need to change, you change them in one place and every caller picks it up.

**Self service** — the HCP Terraform registry lets other teams find and reuse published, approved modules. **No-code ready modules** go further: teams with no Terraform expertise provision their own infrastructure through the HCP Terraform UI, within your org's standards and policies.

## What is a Terraform module?

> A Terraform module is a set of Terraform configuration files in a single directory.

The definition is deliberately broad. Even one directory with a single `.tf` file is a module. When you run Terraform commands directly in that directory, it is the **root module** — so *every* configuration is already part of a module, and there is no "before modules" state to graduate from.

The minimal layout shown:

```
.
├── LICENSE
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
```

!!! warning "Two small errors in the source page"
    **1. "Name your provider `terraform-<PROVIDER>-<NAME>`."** That convention names a **module repository**, not a provider — `terraform-google-vault`, `terraform-aws-ec2-instance`, where `<NAME>` is the infrastructure type and `<PROVIDER>` is the provider that creates it. Providers use a different pattern, `terraform-provider-<NAME>`. Verified against [Publishing Modules](https://developer.hashicorp.com/terraform/registry/modules/publish) on 2026-08-08; the requirement there is on the repo name, alongside "must adhere to the standard module structure" and semver release tags (`x.y.z`, optional `v` prefix).

    **2. The file tree is rooted at `.`, but the prose that follows says "when you run terraform commands from within the `minimal-module` directory".** Stale reference — no `minimal-module` directory appears anywhere on the page.

## Calling modules

Terraform commands only read the configuration files in **one** directory, normally the working directory. A `module` block is how that directory reaches others: Terraform loads and processes the called module's files when it hits the block. A module called by another configuration is a **child module** of it.

## Local and remote modules

Modules load either from the local filesystem or from a remote source. Supported remote sources: the Terraform Registry, most version control systems, HTTP URLs, and HCP Terraform / Terraform Enterprise private module registries. (Address syntax and the pinning consequences of each are out of scope here — that's `Module Sources` plus [[tf-expr-version-constraints]].)

## Module best practices

The framing: modules are Terraform's version of libraries/packages, with the same benefits, and "real-world Terraform configurations should almost always use modules".

- **Name your module `terraform-<PROVIDER>-<NAME>`.** Required to publish to the HCP Terraform or Terraform Enterprise module registries. (Source says "provider" — see the warning above.)
- **Start writing your configuration with modules in mind.** Even for modestly complex configs managed by one person, the benefit outweighs the setup cost.
- **Use local modules to organize and encapsulate your code**, even when you never publish anything. Doing it from the start cuts maintenance cost later.
- **Use the public Terraform Registry to find useful modules** rather than reimplementing common scenarios.
- **Publish and share modules with your team.** Publicly or privately. Consumers reference child modules from a root module, or deploy no-code ready modules through the HCP Terraform UI.

These overlap [[tf-style-guide]]'s Modules section, which is more prescriptive where this page is motivational: group resources that provision together, put local modules in `./modules/<module_name>`, keep infra config in a separate repo from module code (one repo per module, for independent versioning and registry publishing), and pin registry modules by `version`.

## Next steps

The stated takeaways are the three sections above: what problems modules solve, the structure of a module, and best practices for using and creating them. The page points at a separate no-code module tutorial and its reference docs for that path. The next tutorial builds and applies a configuration that uses Registry modules.

---
Related: opens the Modules collection, whose next page ("Use modules") is not yet captured. Motivation for [[tf-aws-manage]], which is where a `module` block, `module.<name>.<output>` references, and `module.vpc.*` state addressing first appear in practice. Pins and sources are governed by [[tf-expr-version-constraints]]; note that [[tf-dependency-lock]] does **not** lock module versions. [[tf-style-guide]] restates these best practices as concrete conventions. The "modules solve duplication across environments" claim is qualified by [[tut-for-each]]'s own warning against `for_each` over independently-lifecycled environments. Feeds learning-path **I4** (using modules) and **I5** (authoring modules).
