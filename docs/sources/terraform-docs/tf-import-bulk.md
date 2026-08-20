# Import existing resources in bulk

> **Source:** [developer.hashicorp.com/terraform/language/import/bulk](https://developer.hashicorp.com/terraform/language/import/bulk)
> **Added:** 2026-08-20
> **Source updated:** undated language page; captured 2026-08-20 against v1.15.x (latest)
> **Tags:** bulk-import, list-block, tfquery-hcl, terraform-query, generate-config-out, resource-identity, import-block, hcp-terraform
> **Type:** documentation

*Developer › Terraform › Configuration Language › Import resources › Import existing resources in bulk · v1.15.x*

The workflow [[tf-import]] names and no tutorial covers. This is where **list resources** stop being a discovery curiosity and become the front half of an adoption pipeline.

> For organizations with large sets of infrastructure resources, manually identifying and importing them is tedious and labor intensive, **even when using third-party tools or custom scripts**. To alleviate this burden, you can write HCL-based queries and run them with the Terraform CLI to retrieve unmanaged resources so that you can import them in bulk.

## Three steps

1. **Search** — write `list` blocks in a `.tfquery.hcl` file.
2. **Generate** — `terraform query -generate-config-out=generated.tf` writes `resource` **and** `import` blocks, identities included.
3. **Import** — copy those blocks into `main.tf` and `terraform apply`.

Then: *"you can remove the generated import block or keep it as an historical record."*

!!! warning "`-generate-config-out` is a flag on two different commands, and they are not the same operation"
    | Command | Input | Generates |
    |---|---|---|
    | `terraform plan -generate-config-out=…` | `import` blocks **you wrote** | the missing `resource` blocks ([[tut-state-import]]) |
    | `terraform query -generate-config-out=…` | `list` blocks | **both** the `resource` and the `import` blocks, with identities |

    The individual workflow needs you to already know the IDs. The bulk one is what you use when you do not — the query supplies them. Same flag name, different half of the problem.

## Version requirement

> **Terraform v1.12 or newer** is required to search for resources according to their resource identities.

!!! note "The page's v1.12 is about identities; the feature itself is 1.14 — verified in the repo"
    That Requirements line is the page's only version statement, and it is scoped to *searching by resource identity*, which is what `identity` (1.12) enabled. It never states a minimum for the `list` block or `terraform query`. Settled against the local checkout at `v1.15.8` rather than left ambiguous:

    - `internal/command/query.go` is **absent at `v1.12.0`** and **present at `v1.13.0`**, and `tfquery` already matches in `internal/configs/parser_file_matcher.go` at that tag. The code shipped in **1.13**.
    - The **1.13 changelog says nothing** about either — no mention of `query` or list resources anywhere in it.
    - The **1.14 changelog announces both** under NEW FEATURES: *"**List Resources**: List resources can be defined in `*.tfquery.hcl` files and allow querying and filterting existing infrastructure"* and *"A new Terraform command `terraform query`: Executes list operations against existing infrastructure and displays the results. The command can optionally generate configuration for importing results into Terraform."*

    So **1.14 is the announced release and the number to use** — this path's existing date is correct, and **B8** needs no revisit. The 1.13 presence is the same pattern as `state_store` ([[release-feature-map]]): in the tree, buildable, and named by no changelog until a later release.

Also stated flatly, and easy to skip past: *"Verify that the resource type you want to search for is supported. Refer to your provider documentation."* Provider coverage for list is per-resource-type, not per-provider.

## The query configuration

Two files. A standard `.tf` carrying at least a `required_providers` block, so the plugins install. And a `.tfquery.hcl` file holding the queries.

```hcl
list "aws_instance" "prod" {
  provider = aws
  limit    = 50

  config {
    region = "us-east-2"

    filter {
      name   = "tag:Name"
      values = ["prod-*", "staging-*"]
    }

    filter {
      name   = "instance-state-name"
      values = ["running"]
    }
  }
}
```

Two labels, same shape as a `resource` block: the **resource type** to query, and a **local name** for the result list.

### Arguments

- **`provider`** — **required**. Taken from the `terraform` block in `main.tf` by default, but a `provider` block declared *inside the query file* can supply an alternate configuration to point at, referenced by name here. That is how you query another region or account without touching the main configuration.
- **`config`** — a nested block of **provider-specific** query arguments. Everything inside it, `filter` included, comes from the provider's schema rather than Terraform's.
- **`include_resource`** — defaults to **false**. *"By default, Terraform retrieves only resource identities."* Set it `true` to pull all available attributes — **required if you want to reference any attribute** of a discovered resource, and *"may affect performance."*
- **`limit`** — defaults to **100 per list block**. Raise or lower it.

And a general capability worth noting: `list` blocks accept **meta-arguments**, *"for example, you can use the `count` meta-argument to create multiple instances of the resource list returned by the query."* So a query can itself be fanned out.

### Parameterizing

The query file takes **`variable`** and **`locals`** blocks, so one `.tfquery.hcl` can be reused across environments or accounts with different inputs. Together with the in-file `provider` block, the query configuration is a small, self-contained program — not just a filter expression.

## Running it

```shell
terraform query
terraform query -json
```

Each result carries, by default, a reference to the originating block formatted **`list.<type>.<label>`**, plus the **identity** of the discovered resource. Providers may add more, such as a description. `-json` gives the machine-readable form — the same `-json`-at-the-boundary convention as [[tf-cmd-output]] and [[tut-console]].

```shell
terraform query -generate-config-out=generated.tf
```

Two operational details that will bite otherwise:

!!! danger "The generated file is local-only, and refuses to be overwritten"
    > **Even when connected to HCP Terraform or Terraform Enterprise**, Terraform creates the `generated.tf` file and stores it on the local workstation when running the `terraform query` command with the `-generate-config-out` flag.

    > After generating the results file, you must **remove the file before rerunning** the command to generate a new results file. Rerunning the command when a `generated.tf` already exists at the specified path **results in an error**.

    So the bulk workflow has a local step that remote execution does not eliminate, and the iterate-on-your-query loop is `rm generated.tf` then re-run. Refusing to overwrite is the safer default — a half-reviewed generated file is exactly the thing you would not want silently replaced — but it is a manual step in a workflow otherwise pitched at scale.

## Afterwards

> You can discard the `generated.tf` file after importing your resources. You can either remove `import` blocks after you've imported them or **leave them in your configuration as a record of the resource's origin for future module maintainers**.

The same disposition question `moved` blocks have, answered the same way: harmless to keep, and the argument for keeping is provenance rather than mechanics. Someone reading the configuration in a year cannot otherwise tell an adopted resource from a created one.

## HCP Terraform

Two capabilities, and the first is the one that matters:

> **HCP Terraform uses resource identities to determine when resources are managed by another workspace.**

Configure the `cloud` block in the standard `.tf` and *"you can compare the resources Terraform discovers to resources you are already managing with Terraform"* — cross-workspace, not just cross-configuration. That is a real answer to the failure mode where a bulk import adopts something another team's workspace already owns, breaking [[tf-state-purpose]]'s one-to-one mapping in the least visible way possible: two states, one object, neither aware.

Second, queries can be run from the HCP UI once configuration is copied to the workspace, or checked into VCS first if the workspace is VCS-connected.

## What this changes about the tutorials

Every State-collection tutorial performs discovery by hand — `docker inspect --format="{{.ID}}"` in [[tut-state-import]], `aws ec2 create-security-group` then `echo $SG_ID` in [[tut-resource-drift]], `terraform output -raw instance_id` in [[tut-state-cli]]. That step is precisely what the `list` block replaces, and none of them mention it. The page it is documented on did not exist in its current form when they were written.

---
Related: [[tf-import]] — the overview naming this as one of two workflows, and the `id`-versus-`identity` distinction the query results are built on. · [[tut-state-import]] — the individual workflow, where `-generate-config-out` hangs off `plan` and generates only the `resource` blocks. · [[feature-history]] — the 1.14 date for list resources and `terraform query`, confirmed against the changelog while capturing this page. · [[tf-state-purpose]] — the one-to-one mapping that cross-workspace identity matching protects. · [[tf-cmd-output]] · [[tut-console]] — `-json` as a flag at the boundary. · [[tut-resource-drift]] · [[tut-state-cli]] — the hand-rolled discovery steps this workflow supersedes.
