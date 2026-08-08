# Add public providers and modules to your private registry

> **Source:** [developer.hashicorp.com/terraform/tutorials/modules/private-registry-add](https://developer.hashicorp.com/terraform/tutorials/modules/private-registry-add)
> **Added:** 2026-08-08
> **Source updated:** undated tutorial (~5 min); captured 2026-08-08
> **Tags:** modules, providers, private-registry, hcp-terraform, curation, no-code-modules, governance
> **Type:** documentation

Sixth page of the **Modules** collection. HCP-only and entirely UI — no Terraform configuration appears anywhere on it. Where [[tut-module-private-registry-share]] published *your* module into the private registry, this one adds *public* registry entries to it. The whole flow is: search the public registry from inside HCP, click **Add to HCP Terraform**, confirm, then later delete. Prerequisites are an HCP Terraform account and, per the page, organization owner access.

## What curation actually is

The tutorial's framing is discovery and consistency:

> HCP Terraform's private registry allows you to curate the modules and providers your organization uses, which make approved modules and providers easier to find.

> Curating public modules and providers in your private registry lets you define a list of approved components for your organization to use. It also lets your team find all documentation related to those components in one place, and makes it easier to track new releases and changes.

!!! danger "“Approved” is a label, not a control — and the page never says so"
    The word "approved" invites the reading that curation restricts what practitioners can use. It does not. The docs are explicit on both halves ([Add public providers and modules](https://developer.hashicorp.com/terraform/cloud-docs/registry/add), verified 2026-08-08):

    > The private registry **stores a pointer** to these public providers and modules so that you can view their data from within HCP Terraform. This lets you clearly **designate which public providers and modules are recommended** for the organization and makes their supporting documentation and examples centrally accessible.

    > Removing a public provider or module from a private registry does not remove it from the public Terraform Registry. **Users in the organization can still use the removed provider or module without changing their configurations.**

    Two consequences fall out of that second sentence. **Curation does not change the source address** — a curated `terraform-aws-modules/vpc/aws` is still written exactly that way, which is why removing it breaks nothing. And **curation enforces nothing**: nobody is stopped from using an uncurated module, and nothing is stopped from continuing after a curated entry is deleted.

    Enforcement is a different mechanism entirely — Sentinel or OPA policy on the `terraform` plan, which is **A5**. Read this feature as a curated bookmark list with docs attached, and set expectations accordingly.

## Reviewing before you add

The genuinely useful part of the tutorial is what it tells you to *look at* on a public registry entry, since these are the evaluation criteria for adopting any third-party component.

For a **provider**:

- Name and description; a badge marking it public.
- **Version and publication date**, "which show whether the provider is actively maintained". Older versions are selectable and reviewable.
- **The owner** responsible for maintenance and updates (HashiCorp owns `aws`).
- **The number of provisions** — "A higher number correlates with broader community adoption."
- A link to the source repository.
- Documentation and example-configuration tabs.

For a **module**:

- Name, description, public badge, version and publication date.
- **Submodules** and **Example** dropdowns.
- Tabs for README, **inputs, outputs, dependencies, and resources**.
- A side panel with the add button, an example configuration, and a download count.

The `resources` tab is the one worth singling out: it tells you what a module will actually create before you run a plan, which is the shortest path to the "22 resources from two module blocks" surprise in [[tut-module-use]].

## Removing

The module page's **Add to HCP Terraform** button becomes **Manage Module for Organization** once the item is curated, which is how you tell current state at a glance. Removal is **Manage Module for Organization → Delete module**, then type the module name (`vpc`) to confirm. Providers use **Manage Provider for Organization → Delete from organization**, then type the provider name (`aws`) and click **Remove**.

Same typed-name confirmation pattern as workspace destruction in [[tut-module-private-registry-share]]. Here it guards a bookmark, not infrastructure.

## What the docs add that the page leaves out

Five facts from [the reference page](https://developer.hashicorp.com/terraform/cloud-docs/registry/add) that materially change how you'd use this, verified 2026-08-08.

**1. The permission is narrower than "owner".** The tutorial asks for organization owner access; the docs are more precise:

> All members of an organization can view and use public providers and modules.
>
> Members on the owners team and teams with **Manage Private Registry** permissions can add and delete them from the private registry.

So curation is delegable to a platform team without handing out org ownership.

**2. It can be automated.** "You can add providers and modules through the UI as detailed below or through the **Registry Providers API** and the **Registry Modules API**." A curated list maintained by hand drifts; one maintained by API is a reviewable artifact.

**3. Terraform Enterprise needs outbound network access — including to Algolia.**

> Your Terraform Enterprise instance must allow access to `registry.terraform.io` and `https://yy0ffni7mf-dsn.algolia.net/`.

The second host is the search index. An airgapped or egress-filtered TFE install that allows only `registry.terraform.io` gets a registry search box that silently returns nothing.

**4. Terraform Enterprise can only curate GitHub-hosted, IPv4-reachable public modules.** "This is because GitHub does not support IPv6."

**5. No-code provisioning works on curated *public* modules.** The tutorial's Tip points only at creating your own no-code module. The docs say you can enable it on a public module you have added — **Manage Module for Organization → Enable no-code provisioning**, after checking the module meets the no-code requirements. It gains a **No-Code Ready** badge. HCP Terraform **Standard and Premium** editions only, and downstream users need provider credentials reachable from their new workspaces, through a global or project-scoped variable set or another workspace's outputs.

That fifth point is the one with real leverage: it turns a third-party community module into something a team with no Terraform knowledge can provision through the UI, without you writing or maintaining the module.

## No screenshots captured

Six UI screenshots on the page, including a VPC module detail view pinned at **3.11.0** — a version from 2021, against a module currently at 6.6.1. Dated captures of a UI that has changed; the flow above is the durable part.

## Next steps

Stated takeaway: search, review, add, and remove providers and modules so the private registry becomes "the source for Terraform configuration components for your organization". Onward pointers are the private-registry documentation, the private-module publishing tutorial ([[tut-module-private-registry-share]]), the no-code modules tutorial, and **cross-organization module sharing**. Next in the collection is refactoring configuration.

---
Related: sixth in the Modules collection, the counterpart to [[tut-module-private-registry-share]] — that one publishes your own module, this one curates someone else's. The evaluation criteria it lists are the practical answer to [[tut-module]]'s "use the public Terraform Registry to find useful modules". Curation not being enforcement is the boundary between **A4** and **A5**; the actual controls on module versions are the exact-pin and policy layers noted in **I4**, since [[tf-dependency-lock]] never locks modules. Feeds learning-path **A4** (private registry) primarily, with the enforcement caveat belonging to **A5** and the no-code-on-public-modules point to **E6**.
