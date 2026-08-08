# Share modules in the private registry

> **Source:** [developer.hashicorp.com/terraform/tutorials/modules/module-private-registry-share](https://developer.hashicorp.com/terraform/tutorials/modules/module-private-registry-share?variants=module-workflow%3Atag)
> **Added:** 2026-08-08
> **Source updated:** undated tutorial (~8 min); captured 2026-08-08
> **Tags:** modules, private-registry, hcp-terraform, publishing, semver, vcs, tag-based-publishing, branch-based-publishing
> **Type:** documentation

Fifth page of the **Modules** collection, and the first that requires **HCP Terraform** — there is no Community Edition variant. Almost entirely a UI walkthrough: fork two repositories, tag a release, publish the module through the HCP registry, then consume it from a VCS-driven workspace. Both variants captured (`module-workflow:tag` and `module-workflow:branch`).

Scope of the private registry, stated up front:

> HCP Terraform allows users to create and confidentially share infrastructure modules within an organization using the private registry. With Terraform Enterprise, the private registry allows you to share modules within or across organizations.

So cross-organization sharing is a **Terraform Enterprise** capability, not an HCP one.

Prerequisites are heavier than the rest of the collection: a GitHub account, an HCP Terraform account, an AWS account with IAM access keys, an HCP variable set holding those credentials, and **OAuth access to GitHub configured** for the organization. The page notes that if you lack permission to configure VCS access, create a new organization for the tutorial.

## Repository naming and versioning

Fork `learn-private-module-aws-s3-webapp`, then **rename it** to `terraform-aws-s3-webapp`:

> When you publish a single module in a git repository, we recommend you follow the naming convention `terraform-<PROVIDER>-<NAME>` to make it easier for users to identify which module corresponds to which git repository.

!!! tip "The collection contradicts itself, and this page is the correct one"
    [[tut-module]] states the same best practice as *"Name your **provider** `terraform-<PROVIDER>-<NAME>`"*. This page states it correctly as a **repository** convention for publishing a module. Same collection, two pages, one of them wrong. Cross-check in `cache/search/module-repo-naming-convention.md`.

Versioning comes from git, not from anything you write:

> HCP Terraform modules should be semantically versioned, and pull their versioning information from repository release tags. To publish a module initially, at least one release tag must be present. Tags that don't look like version numbers are ignored. Version tags can optionally be prefixed with a `v`.

The tutorial creates a GitHub release tagged `1.0.0`. This matches the public-registry requirement already recorded for [[tut-module]] — semver `x.y.z`, optional `v`, at least one tag to publish.

## Tag-based vs branch-based publishing

The page's variant selector switches one step in the import flow, but the difference is more than a radio button. Verified against [Publish modules](https://developer.hashicorp.com/terraform/cloud-docs/registry/publish-modules) on 2026-08-08.

| | Tag-based | Branch-based |
|---|---|---|
| What you configure at import | *Module Tag Prefix* and *Source Directory* (both left empty here) | *Branch Name* (`main`), *Module Version* (`1.0.0`), *Source Directory* |
| Where the version comes from | the git release tag | typed into the UI |
| Publishing a new version | *"push a new release tag to its VCS repository. The registry automatically imports the new version."* | *"navigate to the module overview screen, then click the **Publish New Version** button"*, then *"Select the commit SHA that the new version will point to, and assign a new module version."* |
| Re-using a version number | n/a — the tag is the version | *"You cannot re-use an existing module version."* |
| Module testing | not available | *"You can only enable testing on modules published using branch-based publishing."* |

Two things worth carrying:

- **Branch-based publishing still pins to a commit SHA.** The branch selects *where new versions come from*; the published version points at a specific commit. So it is not the mutable-pointer hazard that a Git `ref=<tag>` source is, and it does not re-open the mutable-tag problem recorded for direct Git module sources.
- **Module testing is branch-only.** That is a real constraint on the publishing workflow you pick, and it isn't mentioned on the tutorial page at all — only in the docs.

The tutorial's own **Module Tag Prefix / Source Directory** aside is the monorepo hook: use them "when the repository contains multiple modules", which is the same ground the page's closing line points at ("You can also publish multiple modules from a single repository").

## The import flow

Registry → **Publish** dropdown → **Module** → pick the configured VCS provider → pick `terraform-aws-s3-webapp` → choose the publishing type → **Next** → on *Confirm selection*, set **Module Name** and **Provider Name** (`aws`) → **Publish module**.

The registry page then shows a **Usage Instructions** section carrying the exact `source` string to paste, which is the reliable way to get the address right.

## Consuming it

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0.0"
    }
  }
}

provider "aws" {
  region = var.region
}

module "s3-webapp" {
  source  = "app.terraform.io/hashicorp-learn/s3-webapp/aws"
  name   = var.name
  region = var.region
  prefix = var.prefix
  version = "1.0.0"
}
```

!!! danger "The stated source-address format is wrong — the code example is right"
    The page says addresses take the form `app.terraform.io/<ORGANIZATION-NAME>/terraform/<NAME>/<PROVIDER>`. That has **five** segments, with a literal `terraform` wedged in the middle. The real format is four:

    > `<HOSTNAME>/<ORGANIZATION>/<MODULE_NAME>/<PROVIDER_NAME>`

    Hostname is `app.terraform.io` for HCP SaaS, or your instance hostname on Terraform Enterprise. The docs' own example is `source = "app.terraform.io/example_corp/vpc/aws"`. ([Using private modules](https://developer.hashicorp.com/terraform/cloud-docs/registry/using), verified 2026-08-08.)

    The page's *own* module block — `app.terraform.io/hashicorp-learn/s3-webapp/aws` — is correct and contradicts its prose. Copy the block, not the sentence.

!!! warning "And the Module Name step contradicts that block too"
    The import step says to set **Module Name** to `terraform-aws-s3-webapp`. The Module Name is *"the name that appears in the registry"* and lands in the `<MODULE_NAME>` segment — so following that instruction produces `app.terraform.io/<org>/terraform-aws-s3-webapp/aws`, not the `.../s3-webapp/aws` the tutorial then tells you to use. The repository is named `terraform-aws-s3-webapp`; the **module** is `s3-webapp` with provider `aws`. Take the address from the registry page's Usage Instructions rather than from either instruction here.

Two style problems in the block, worth naming because a reader copies these shapes:

- **`version` sits last, after the inputs.** [[tf-style-guide]] puts `source` and `version` first, before any input arguments — they describe *which* module, not how to configure it.
- **The root variables carry no `type`.** `variable "region" { description = ... }` with no `type` means `any` ([[tf-input-variables]]). On a root module whose values are typed into a web form, a `type` is the only validation you get.

```hcl
variable "region" {
  description = "This is the cloud hosting region where your webapp will be deployed."
}

variable "prefix" {
  description = "This is the environment your webapp will be prefixed with. dev, qa, or prod"
}

variable "name" {
  description = "Your name to attach to the webapp address"
}
```

The page's justification for declaring them at all is worth keeping, because in a VCS-driven workspace the values come from the UI rather than from `.tfvars`:

> Although you will enter these manually in the HCP Terraform web UI, it is still a good idea to have these in your root configuration so that other teammates understand the required inputs.

Outputs work the same way, surfacing in the UI rather than a terminal:

```hcl
output "website_endpoint" {
  value = module.s3-webapp.endpoint
}
```

## Workspace, run, destroy

Create a workspace from the GitHub connection, pick the `learn-private-module-root` repo, then set `region = us-east-1`, `prefix = dev-test`, and `name` in the *Configure Terraform variables* prompt. Run from **Actions → Start new run**, confirm the plan, and visit the `website_endpoint`.

Destroy is a UI path with a deliberate guard: **Settings → Destruction and Deletion → Queue destroy plan**, then type the workspace name to confirm, then **Confirm & Apply**. The typed-name confirmation is the HCP counterpart to the CLI's `yes` prompt, applied at workspace granularity.

!!! note "No screenshots captured"
    The page carries eight UI screenshots (GitHub settings and releases, the HCP publish dropdown, the module view, the workspace variables page, the run views). They are dated captures of two UIs that have both changed since, so reproducing them here would mislead more than it helps. Follow the live UI; the flow above is the durable part.

## Staleness

AWS provider pinned `~> 4.0.0`, current 6.x — the same era as the rest of the collection. Nothing else here is version-bound: the publishing flow, the source address format, and the semver-tag rule are all still current as of 2026-08-08.

## Next steps

Stated takeaways: created and versioned a GitHub repository for the private registry, imported a module into the organization's registry, and built a root module that consumes it. Onward pointers are the private-registry documentation, the no-code modules tutorial, and publishing multiple modules from one repository. Next in the collection is adding modules from the public registry.

---
Related: fifth in the Modules collection, after [[tut-module-object-attributes]]. Corrects [[tut-module]]'s provider-vs-module naming error by stating the convention properly. The version-tag rule is the private-registry twin of the public-registry publishing bar recorded in [[tut-module]]; constraint syntax is [[tf-expr-version-constraints]], and the reason pinning matters at all is [[tf-dependency-lock]] (providers only — module selections are never locked). Style points against [[tf-style-guide]] and [[tf-input-variables]]. The workspace and VCS-driven run machinery is [[workspaces]]. Feeds learning-path **A4** (HCP Terraform — private module registry) primarily, and **I5** (authoring modules — the publish step after you have written one).
