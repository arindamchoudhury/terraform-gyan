# Generating configuration

> **Source:** [developer.hashicorp.com/terraform/language/import/generating-configuration](https://developer.hashicorp.com/terraform/language/import/generating-configuration)
> **Added:** 2026-08-20
> **Source updated:** undated language page; captured 2026-08-20 against v1.15.x (latest)
> **Tags:** generate-config-out, import-block, experimental, provider-block, conflicting-arguments, plan-symbols
> **Type:** documentation

*Developer › Terraform › Configuration Language › Import resources › Generating configuration · v1.15.x*

The reference for `-generate-config-out` on `plan` — the flag [[tut-state-import]] demonstrates and [[tf-import-single]] names as the fallback route. For the `query` variant, [[tf-import-bulk]].

## It is still experimental, and this path had not recorded that

!!! danger "Experimental as of the v1.15.x docs — three years after it shipped"
    > **Experimental:** Configuration generation is available in Terraform **v1.5 as an experimental feature**. Later minor versions may contain changes to the **formatting of generated configuration** and **behavior of the `terraform plan` command using the `-generate-config-out` flag**.

    And a warning printed on every run:

    ```text
    │ Warning: Config generation is experimental
    │
    │ Generating configuration during import is currently experimental, and the
    │ generated configuration format may change in future versions.
    ```

    Nothing else captured here says this. [[tut-state-import]] uses the flag without a word about its status; [[tf-import-single]] recommends it for complex resources without qualification. The version banner on this page reads **v1.15.x (latest)**, so the label is current, not stale text from 1.5.

    Practical consequence: **do not build tooling on the output format**, and expect a minor release to change both the formatting and the command's behaviour. Fine for a one-off adoption you review by hand — which is the only use either page describes anyway.

## The workflow

The `import` block first — in its own `import.tf` or anywhere in the configuration:

```hcl
import {
  to = aws_iot_thing.bar
  id = "foo"
}
```

```shell
terraform plan -generate-config-out=generated.tf
```

> If any resources targeted by an import block **do not already exist in your configuration**, Terraform then generates and writes configuration for those resources.

And the generation is self-limiting as adoption proceeds:

> If a resource address in your state matches an import block's `to` argument, Terraform attempts to import into that resource. **In future planning, Terraform knows it doesn't need to generate configuration for resources that already exist in your state.**

Which is the same idempotency [[tf-import-single]] describes for the block itself, extended to generation: a leftover `import` block will not keep regenerating a file.

!!! warning "A provider block may be required, and it costs an `init`"
    > If your configuration **does not contain other resources for your selected provider**, you must add a `provider` block to inform Terraform which provider it should use to generate configuration. Otherwise, Terraform displays an error if it can not determine which provider to use. **If you add a new provider block to your configuration, you must run `terraform init` again.**

    Bites exactly in the greenfield adoption case — an empty repository, one `import` block, nothing else. Terraform infers the provider from the resources already present, and there are none.

## The clean plan shape

```text
  # aws_iot_thing.bar will be imported
  # (config will be generated)
    resource "aws_iot_thing" "bar" {
        arn               = "arn:aws:iot:eu-west-1:1234567890:thing/foo"
        attributes        = {}
        default_client_id = "foo"
        id                = "foo"
        name              = "foo"
        version           = 1
    }

Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
```

Two things worth noticing. The annotation is **`# (config will be generated)`**, and the resource is rendered with **no action symbol at all** — not `+`, `-`, `~`, `-/+`, or the `.` forget marker from [[tut-state-cli]]. A pure import proposes no infrastructure action, so there is nothing to mark.

And `1 to import, 0 to add, 0 to change, 0 to destroy` is what a *clean* adoption looks like. Worth holding against [[tut-state-import]]'s first generate-plan, which read `1 to import, 1 to add, 0 to change, 1 to destroy` with `# Warning: this will destroy the imported resource` — that is the same command on a resource whose generated defaults did not match reality.

## How much does it actually generate?

The page's example `generated.tf`, in full:

```hcl
resource "aws_iot_thing" "bar" {
  name = "foo"
}
```

One argument.

!!! note "❓ This sits awkwardly against the tutorial's description"
    [[tut-state-import]] states that *"the generated configuration contains **all possible arguments** for the imported resources, including those set to default values and those without values"*, and recommends pruning on that basis. This page's example is a single line, and its own prose is softer — Terraform *"produces HCL to act as a template that contains Terraform's **best guess** at the appropriate value for each resource argument."*

    Both could be describing the same behaviour on schemas of wildly different sizes — `aws_iot_thing` is small, `docker_container` is not. But "all possible arguments" and "best guess at the appropriate value" are not the same claim, and nothing captured here reconciles them. Treat the tutorial's version as the one to plan for, since a verbose draft is the case that needs work.

The recommended follow-up is the same either way:

> Starting with Terraform's generated HCL, we recommend iterating to find your ideal configuration by **removing some attributes, adjusting the value of others, and rearranging resource blocks into files and modules** as appropriate.

Note the third verb. Generation puts everything in one file; the reviewing step is also where it gets distributed into the layout you actually want.

## Limitation: generated configuration can be invalid

The page documents one failure mode, and it is not a corner case:

> Terraform generates configuration for importable resources during a plan by requesting values for resource attributes from the provider. **For certain resources with complex schemas, Terraform may not be able to construct a valid configuration from these values.**

```text
$ terraform plan -generate-config-out="generated.tf"
╷
│ Error: Conflicting configuration arguments
│
│   with aws_instance.ubuntu,
│   on g.tf line 20, in resource "aws_instance" "ubuntu":
│   20:   ipv6_address_count                   = 0
│
│ "ipv6_address_count": conflicts with ipv6_addresses
╵
```

The resource supports both arguments but permits only one. Generation, working attribute by attribute from provider values, emits both. Fix by deleting one and re-planning.

!!! danger "The failed run still writes the file — and the file then blocks the retry"
    Two rules from this page collide, and neither section mentions the other.

    > **Do not supply a path to an existing file, or Terraform throws an error.**

    > In the example above, **Terraform still generates configuration and writes it to `generated.tf`**.

    So a generation that ends in `Error: Conflicting configuration arguments` has nonetheless produced the file. Re-running the same command then fails for a *different* reason — the path already exists. The loop is: read the error, **edit the generated file in place** (which is what the page intends, since it tells you to remove one of the conflicting arguments), or delete it before re-generating.

    Same "existing path is an error" rule as `terraform query -generate-config-out` ([[tf-import-bulk]]), so it is a property of the flag rather than of either command.

## Apply

Ordinary, once the configuration is right:

```text
  # aws_iot_thing.bar will be imported
Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.

aws_iot_thing.bar: Importing... [id=foo]
aws_iot_thing.bar: Import complete [id=foo]

Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.
```

> Commit your new resource configuration to your version control system.

---
Related: [[tf-import-single]] — the hand-written route, and the rule for choosing between them. · [[tf-import-bulk]] — `-generate-config-out` on `terraform query`, which generates the `import` blocks too. · [[tf-import]] — the hub. · [[tut-state-import]] — the flag in practice, including the `env = null` case where the generated draft plans a destroy. · [[tut-state-cli]] — the other unusual plan markers, including the `.` forget symbol. · [[feature-history]] — the 1.5 date for configuration-driven import.
