# Create and manage resources (overview)

> **Source:** [developer.hashicorp.com/terraform/language/resources](https://developer.hashicorp.com/terraform/language/resources)
> **Added:** 2026-07-09
> **Source updated:** docs for Terraform v1.15.x (latest); no explicit page date
> **Tags:** resources, resource-block, meta-arguments, apply, workflow, data-sources
> **Type:** documentation

The hub page for the Resources section of the language docs. Short — it defines a resource and frames the create/manage workflow, linking out to the detailed sub-pages. Most of this is already covered in depth by [[tf-config-syntax]] (block anatomy), [[tf-aws-create]] (a real `aws_instance`), and the book's Ch3/Ch5. Captured here for the canonical framing and the precise apply-operations list.

## What a resource is

A **resource** is any infrastructure object Terraform creates and manages — virtual networks, compute instances, or higher-level objects like DNS records. Which resource *types* exist depends on the **providers** installed; a provider is a plugin offering a collection of resource types for one platform. See [[aws-provider]] for a concrete provider, [[provider-requirements]] for how providers are declared.

## The workflow

1. **Write the resource configuration** — add a `resource` block and set its arguments. Most arguments are resource-specific and control its behavior. A subset are **meta-arguments** (Terraform-specific: `count`, `for_each`, `depends_on`, `lifecycle`, `provider`) that control *how* Terraform creates and manages the resource, not the resource itself.
2. **Initialize the workspace** — `terraform init` downloads/installs the providers and modules the config references. Reinitialize after changing providers or modules in an existing project.
3. **Apply the configuration** — `terraform apply` reconciles config, real infrastructure, and state.

## What `apply` does (canonical list)

On apply, Terraform performs exactly these operations:

- **Creates** resources in the config that don't yet exist as real objects.
- **Destroys** resources that exist in state but no longer exist in config.
- **Updates in place** resources whose arguments changed and *can* be patched.
- **Destroys and re-creates** resources whose arguments changed but *cannot* be updated in place due to remote-API limitations (forced replacement).
- **Updates the state file** so config, real infrastructure, and state all match.

!!! note "Maps directly onto the plan symbols"
    These five operations are the same four plan symbols the book teaches in Ch3, plus the state write: create = `+`, destroy = `-`, update-in-place = `~`, destroy-and-recreate = `-/+`. See the plan-symbol table in [[tf-aws-manage]] and book Ch3. "Cannot be updated in place due to remote API limitations" is the docs' phrasing for a **forced-new** attribute.

## Managing resources over time

As needs change, the docs point to four management moves (each its own sub-page):

- **Creating modules** — collect resources into reusable modules.
- **Refactoring modules** — move and rename resources (the `moved` block).
- **Remove a resource from state** — drop it from state *without* destroying the real object (the `removed` block / `state rm`).
- **Destroy a resource** — remove from state *and* destroy the real object.

Providers also expose **data sources** — read existing infrastructure without provisioning anything. See [[tf-aws-create]] for a data-source (`aws_ami`) in use.

---
Related: [[tf-config-syntax]] — the low-level block/argument syntax a `resource` block is made of. · [[tf-aws-create]] — a resource + data source applied against real AWS. · [[tf-aws-manage]] — the plan symbols and in-place-vs-replace behavior this page's apply list describes. · [[aws-provider]] — the provider that supplies the resource types.
