# Workspaces

> **Source:** [developer.hashicorp.com/terraform/language/state/workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces)
> **Added:** 2026-07-30
> **Source updated:** undated language reference; captured 2026-07-30 against v1.15.x (latest)
> **Tags:** state, workspaces, terraform-workspace, backends, terraform.workspace, hcp-workspaces
> **Type:** documentation

*Developer › Terraform › Configuration Language › State › Workspaces · v1.15.x*

The language-side page on CLI workspaces. Already the primary docs source behind the topic page [[workspaces]], which synthesizes it with TID Ch6 §6.4.5/§6.4.7 and the Terraform source. This note records what **this page alone** says, so the topic page's claims stay traceable. Read [[workspaces]] for the CLI-vs-HCP comparison, the isolation argument, and the open-source picture.

## The definition

A backend defines how Terraform executes operations and where it stores persistent data. That persistent data **belongs to a workspace**.

> "The backend initially has only one workspace containing one Terraform state associated with that configuration. Some backends support multiple named workspaces, allowing multiple states to be associated with a single configuration."

The payoff sentence, and the one [[workspaces]] builds its benefit list on:

> "The configuration still has only one backend, but you can deploy multiple distinct instances of that configuration without configuring a new backend or changing authentication credentials."

The page flags the naming collision up front: CLI workspaces "are different from workspaces in HCP Terraform", and points to *Connect to HCP Terraform* for migrating a multi-workspace configuration.

## Which backends support multiple workspaces

The page names them explicitly — ten, in its own order.

AzureRM · Consul · COS · GCS · Kubernetes · Local · OSS · Postgres · Remote · S3

!!! note "Read the list for what it omits"
    This is the enumerated answer [[tf-state-backends]] does not give and [[06-state-management]]'s backend table only partly covers. Two absences stand out against the backend catalogue: **`http`** and **`oci`** (the backend added in Terraform 1.12) are not on it. So "remote backend" and "supports named workspaces" are separate properties — picking a backend for storage does not settle whether you can have more than one state in it.

## Using workspaces

- The starting workspace is named **`default`** and **cannot be deleted**. Not having created one means you are in it.
- **Workspaces are contained.** "When you run `terraform plan` in a new workspace, Terraform does not access existing resources in other workspaces. These resources still physically exist, but you must switch workspaces to manage them."
- Create/select/list/delete mechanics live in the CLI docs, not here.

!!! danger "The documented limit, quoted in full"
    > "Workspaces are not appropriate for system decomposition or deployments requiring separate credentials and access controls."

    Marked *Important* on the page, above everything else in the section. Two prohibitions, not one. **System decomposition** — don't split one system across workspaces; that is what separate configurations are for. **Separate credentials and access controls** — the reason CLI workspaces cannot be environment isolation, argued at length in [[workspaces]].

## The current workspace in configuration

```hcl
resource "aws_instance" "example" {
  count = terraform.workspace == "default" ? 5 : 1

  # ... other arguments
}
```

```hcl
resource "aws_instance" "example" {
  tags = {
    Name = "web - ${terraform.workspace}"
  }

  # ... other arguments
}
```

Two uses, in the page's order: **branch on the workspace** (smaller cluster sizes outside `default`), and **use the name in naming or tagging**. The `count` example works because `terraform.workspace` is known at plan time, which [[06-state-management]] §6.4.7 states outright and this page leaves implicit.

!!! note "The section title is pre-0.12 phrasing"
    It is headed *Current Workspace Interpolation*, and the prose calls `terraform.workspace` an "interpolation sequence" usable "anywhere interpolations are allowed." That is 0.11-era vocabulary. In modern HCL `terraform.workspace` is a **named value** you reference directly in any expression — the `${…}` wrapper is only needed to embed it in a string, exactly as the tags example does. The first example proves the point by not using one.

---
Related: [[workspaces]] — the topic page this is a primary source for; go there for CLI-vs-HCP, the isolation limits, and Terragrunt/Atlantis as the open-source split. · [[06-state-management]] — TID Ch6 §6.4.7 for the `terraform workspace` command surface, §6.4.5 for the `cloud` block. · [[tf-state-backends]] — the backend responsibilities this page's workspace support sits on top of. · [[tf-expr-references]] — where `terraform.workspace` fits among the built-in named values.
