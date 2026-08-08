# Publishing Modules

> **Source:** [developer.hashicorp.com/terraform/language/modules/develop/publish](https://developer.hashicorp.com/terraform/language/modules/develop/publish)
> **Added:** 2026-08-08
> **Source updated:** undated language reference; captured 2026-08-08 against v1.15.x (latest)
> **Tags:** modules, publishing, registry, versioning, module-sources, standard-module-structure
> **Type:** documentation

*Developer › Terraform › Configuration Language › Modules › Develop modules › Publish modules · v1.15.x*

The thinnest page in the Modules section, and a third of it is community-ecosystem prose. Two paragraphs carry the content.

!!! warning "This is not the page with the publishing requirements"
    The sidebar entry reads **Publish modules**, so it looks like the place to find the repository-naming rule, the semver-tag rule, and the structure requirement. It has none of them. Those live under **Registry Publishing**, a different top-level section: [Publishing Modules](https://developer.hashicorp.com/terraform/registry/modules/publish) — public GitHub repo named `terraform-<PROVIDER>-<NAME>`, adherence to the standard module structure, and at least one semver release tag optionally prefixed `v`. Already captured in `cache/search/module-repo-naming-convention.md`, and the HCP private-registry equivalents are in `cache/search/hcp-private-registry-publishing.md`.

    Worth knowing because a reader following this section's sidebar will not find them.

## Why the registry

> If you've built a module that you intend to be reused, we recommend publishing the module on the Terraform Registry. This will **version your module, generate documentation**, and more.

"Generate documentation" is the payoff [[tf-modules-structure]] describes the mechanics of — the registry reads the standard structure and builds the Inputs/Outputs tables from `description` arguments, which is why that page says the README need not restate them.

> Published modules can be easily consumed by Terraform, and **users can constrain module versions for safe and predictable updates.**

```hcl
module "consul" {
  source = "hashicorp/consul/aws"
}
```

!!! note "The example omits the very thing the sentence above it sells"
    The paragraph's selling point is that "users can constrain module versions", and the example immediately below it has no `version` argument — which means Terraform installs whatever is latest at `init` time. [[tf-modules-configuration]] is explicit that `version` "is not required, but **we highly recommend you include it**", and with no lock file for modules ([[tf-dependency-lock]]) an unpinned registry source re-resolves on every clean checkout.

    Read the snippet as showing the *address shape* — `<NAMESPACE>/<NAME>/<PROVIDER>` — and not as a config to copy.

> If you do not wish to publish your modules in the public registry, you can instead use a **private registry** to get the same benefits.

The private-registry workflow itself is [[tut-module-private-registry-share]].

## The ecosystem paragraph, and the one fact in it

Mostly promotional — community, partner and customer contributions, partners building modules "for popular or challenging use cases on their platform". The line worth extracting:

> Both types of modules have their place in the Terraform registry, **accessible to practitioners who can decide which modules best fit their requirements.**

That is the public registry's curation model stated plainly: **it hosts, it does not vet.** Partner and community modules sit side by side and the choice is the consumer's. Which is why [[tut-private-registry-add]]'s review checklist matters — owner, publication date, provision count, source repository — and why [[tf-modules]] bothers to spell out that public-registry modules are "created and maintained by HashiCorp, our partners, and the Terraform community".

## Distribution via other sources

> Although the registry is the native mechanism for distributing re-usable modules, Terraform can also install modules from various other sources. **The alternative sources do not support the first-class versioning mechanism**, but some sources have their own mechanisms for selecting particular VCS commits, etc.

That is the cleanest one-line statement of why a registry source beats a Git source for pinning, and it matches what learning-path **I4** records at length: a registry module takes `version = "6.6.1"`, which is exact *and* legible to Renovate and Dependabot, while a Git source forces a choice between a movable tag and a SHA no bot will update. "Their own mechanisms" is `?ref=`, specified in [[tf-modules-configuration]].

> We recommend that modules distributed via other protocols **still use the standard module structure** so that they can be used in a similar way as a registry module **or be published on the registry at a later time.**

Structure is a migration path, not just tidiness. A Git-sourced module that already follows [[tf-modules-structure]] can be published without rework.

---
Related: the shortest page in the Develop-modules group, after [[tf-modules-develop]], [[tf-modules-structure]], [[tf-modules-providers]] and [[tf-modules-composition]]. The actual publishing requirements are **not here** — see `cache/search/module-repo-naming-convention.md` (public) and `cache/search/hcp-private-registry-publishing.md` (private), with the hands-on in [[tut-module-private-registry-share]]. Version pinning: [[tf-modules-configuration]], [[tf-expr-version-constraints]], and the gap in [[tf-dependency-lock]]. Registry-as-host-not-gatekeeper: [[tut-private-registry-add]], [[tf-modules]]. Feeds learning-path **I5** (authoring modules) and **I4** (its registry-versus-Git argument in one sentence).
