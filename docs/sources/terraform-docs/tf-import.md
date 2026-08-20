# Import resources overview

> **Source:** [developer.hashicorp.com/terraform/language/import](https://developer.hashicorp.com/terraform/language/import)
> **Added:** 2026-08-20
> **Source updated:** undated language page; captured 2026-08-20 against v1.15.x (latest)
> **Tags:** import-block, resource-identity, identity-attribute, bulk-import, queries, generate-config-out, state
> **Type:** documentation

*Developer › Terraform › Configuration Language › Import resources · v1.15.x*

A **hub page**, not the block reference. Short — three sections, no code. It routes to two import workflows and defines what "uniquely identifies a resource" means, and the reference material lives in child pages this note does not cover.

That structure is itself the finding. The page has been rebuilt around a **bulk** workflow that did not exist when the State-collection tutorials were written, which is part of why those tutorials still demonstrate the CLI `terraform import` command ([[tut-state-cli]], [[tut-resource-drift]]) while the docs have moved on twice — first to the `import` block, then to query-driven discovery.

## What an import requires

> Importing unmanaged resources to your workspace requires an **import block** that specifies the unique infrastructure resource ID to import. The block also declares an **address** for the imported resource in state. Additionally, you must create a **destination resource block** that matches the address declared in the import block.

Three things, then — an `import` block, an address, and a `resource` block at that address. The same "state entry *and* configuration entry" requirement [[tut-state-import]] demonstrates, stated as a rule rather than shown.

## Two workflows

**Individual** — *"single resources or small batches"*. The page is explicit that this one depends on convenience:

> The workflow for importing single resources or small batches of resources works best **when you can easily access unique infrastructure resource IDs and other attributes from your cloud provider**.

Two variants. Write the `import` and `resource` blocks by hand and `terraform apply`; or write **only** the `import` block and run `terraform plan` with `-generate-config-out` to generate the resource blocks. That second variant is [[tut-state-import]] end to end, including the pruning it does not mention here.

**Bulk** — the newer path, and the one with no tutorial behind it:

> When you need to identify and import large sets of infrastructure resources, you can **define queries as HCL**, add the results to your Terraform configuration, and use the `terraform apply` command to import the discovered resources into your workspace.

This is the language side of **list resources** and `terraform query` (Terraform 1.14, `*.tfquery.hcl` files), which the path already tracks as a discovery mechanism ([[feature-history]]). What this page adds is that discovery and import are meant to be **one workflow**: query to find the unmanaged objects, write the results into configuration, apply to adopt them. The manual `docker inspect` / `aws ec2 describe-*` step every tutorial performs by hand is what the query replaces.

On HCP Terraform you *"can view query results and apply import configurations in the UI."*

## Resource identity — `id` or `identity`

The section that earns the page its place:

> Terraform uniquely identifies resources according to **either the ID assigned by the cloud provider or a collection of specific attributes defined by the provider**. To reference a resource identity in Terraform configuration, you can use either `id` or `identity`.

With a concrete example, which is more than [[feature-history]]'s version row gives:

> The `identity` attribute for `s3_bucket` resources available in the AWS provider, for example, uniquely identifies buckets according to the following attributes:
>
> - `account_id`
> - `bucket`
> - `region`

And the contrast: *"To reference the unique identity of an `aws_instance` resource, you can use the `id` attribute."*

So the choice is not stylistic. A bucket is not uniquely named by its name alone — the same bucket name in another account or region is a different object — and a structured identity says so, where a single opaque string cannot. An EC2 instance ID already is globally unique, so `id` suffices.

The practical rule the page gives, unchanged from [[tut-state-import]]'s version of it: **ask the provider.** *"Refer to your provider documentation for information about how to reference resource identities."*

!!! note "What this page defers"
    It never says what `id` and `identity` **accept as expressions**. [[tf-block-import]] does: `id` takes *"a string or an expression that evaluates to a string"* that must be **known during the plan operation**, and `identity` is an object of key-value pairs.

    Both are now captured: [[tf-import-bulk]] and [[tf-import-single]], along with [[tf-import-generate]] and [[tf-block-import]].

## Where this sits against what is already captured

| Question | Answer lives in |
|---|---|
| How do I adopt one resource, start to finish? | [[tut-state-import]] — the hands-on, including the `-generate-config-out` pruning trap |
| What does the block accept syntactically? | [[tf-block-import]] — `id` takes any plan-time-known string expression; `identity` is an object |
| How do I find what to adopt? | [[tf-import-bulk]] — `list` blocks and `terraform query` |
| Why does adopting break the one-to-one mapping? | [[tf-state-purpose]] |
| How do I get back out, and back in again? | [[tf-state-remove]] — forgetting is reversible only by re-importing |

---
Related: [[tut-state-import]] — the hands-on for the individual workflow; this page is the rule, that one is the transcript. · [[tf-state-purpose]] — the one-to-one mapping rule that import restores by hand. · [[tf-state-remove]] — the exit, whose re-entry is an import. · [[tf-state-refactor]] — `removed` + `import` as the preferred cross-configuration migration. · [[feature-history]] — the `identity` attribute (1.12), `for_each` on `import` (1.7), and list resources / `terraform query` (1.14). · [[tut-state-cli]] · [[tut-resource-drift]] — the tutorials still demonstrating the CLI command this page's workflows replaced.
