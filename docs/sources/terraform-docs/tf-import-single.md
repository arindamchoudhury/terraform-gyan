# Import a single resource

> **Source:** [developer.hashicorp.com/terraform/language/import/single-resource](https://developer.hashicorp.com/terraform/language/import/single-resource)
> **Added:** 2026-08-20
> **Source updated:** undated language page; captured 2026-08-20 against v1.15.x (latest)
> **Tags:** import-block, count, for_each, instance-keys, provider-alias, modules, idempotency, resource-defaults
> **Type:** documentation

*Developer › Terraform › Configuration Language › Import resources › Import a single resource · v1.15.x*

The individual workflow written out as rules, where [[tut-state-import]] is the same workflow as a transcript. It links that tutorial itself (*"Hands-on: Try the State Import tutorial"*). The sibling for large estates is [[tf-import-bulk]].

Everything here is about **hand-writing** the configuration:

> This page describes how to manually write all of your import configuration. Refer to Generate configuration for instructions on how to generate the configuration.

## When to hand-write and when to generate

A decision rule, stated plainly and worth having:

> We recommend **manually writing the resource block when you know how to configure all or most of the resource's arguments**. Use **generated configuration when importing multiple resources or a single complex resource that you do not already have the configuration for**.

So `-generate-config-out` is not the default path — it is the fallback for resources you do not already understand. That reframes [[tut-state-import]] slightly: the tutorial generates because it is teaching the flag, not because generating is the recommended route for a Docker container.

## The destination resource block, and the defaults trap

> you must define a resource block for any resource in state **to prevent Terraform from destroying it**. The only required arguments to the resource block for an imported resource are the inline **resource type and resource label**, which form the Terraform state address.

So the strict minimum is an empty block at the right address:

```hcl
resource "aws_instance" "example" {
  name = "renderer"
}
```

But minimum is not sufficient, and the reason is the whole difficulty of adoption:

> You should include provider-specific resource arguments that have **non-default values** to prevent Terraform from destroying the imported resource on the next apply operation. **Terraform uses default values for arguments you do not include in the resource block.** If Terraform assigns default values, but the existing resource has non-default attributes, the resource in state will not match the actual infrastructure, and Terraform will plan to update the resource on the next apply.

!!! tip "This is [[tut-state-import]]'s pruning rule, arrived at from the opposite direction"
    The tutorial starts from a **generated** block containing *every* argument and tells you to prune to *"only required arguments and arguments whose values differ from defaults."* This page starts from an **empty** block and tells you to add exactly the arguments *"that have non-default values."*

    Both converge on the same target: **the configuration should name precisely the arguments whose values differ from the provider's defaults — no more, no less.** Too many and you carry noise; too few and Terraform silently substitutes a default that does not match reality. The tutorial's `env = null` disaster is the too-few case with the sharpest teeth, because `env` forces replacement rather than an in-place update.

    Note the page says Terraform will *"plan to update the resource"*, while the sentence before warns about *destroying* it. Both are reachable — which one you get depends on whether the mismatched argument forces replacement.

Meta-arguments are allowed on the destination block too, *"to modify how Terraform manages your resources once imported"* — `depends_on`, `lifecycle`, and the rest.

## The block

```hcl
import {
  to = TYPE.LABEL
  id = "<RESOURCE-ID>"
}

resource "<TYPE>" "<LABEL>" {
  # ...
}
```

- **`to`** — the destination resource address, formed from type and label.
- **`id`** — *"an identifier specific to your cloud provider."*

> Cloud providers use different methods of identifying resources. As a result, the identity depends on your cloud vendor and the kind of resource you are importing. **Refer to the provider documentation for the resource you want to import.**

Third page to say it, after [[tf-import]] and [[tut-state-import]]. There is no general rule for `id`; there is only the provider's docs.

## `to` accepts an instance key — and `removed`'s `from` does not

The finding worth carrying furthest. A destination resource using `count` or `for_each` can be imported into **one specific instance**:

```hcl
import {
  to = aws_instance.example[0]
  id = "i-abcd1234"
}

resource "aws_instance" "example" {
  count = 2
  # ...
}
```

```hcl
import {
  to = aws_instance.example["env"]
  id = "i-abcd1234"
}

resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
  for_each = {
    env = "staging"
    geo = "us"
  }
}
```

!!! warning "Asymmetry: you can adopt one instance, but you cannot forget one"
    `import`'s `to` takes `[0]` and `["env"]`. The `removed` block's `from` **explicitly cannot** — [[tf-state-remove]] quotes the rule: *"You cannot include instance keys, such as `aws_instance.example[1]`, if the resource is configured to provision multiple instances."*

    So a `count`/`for_each` resource can be **populated one instance at a time** and can only be **forgotten wholesale**. Anyone planning a staged migration in or out of Terraform should know the trip is not symmetric — the way in is per-instance, the way out is all-or-nothing.

## Two more things the `import` block accepts

**A provider alias.** Not mentioned in [[tf-import]] or in any tutorial:

```hcl
provider "aws" {
  alias  = "europe"
  region = "eu-west-1"
}

import {
  provider = aws.europe
  to       = aws_instance.example["env"]
  id       = "i-abcd1234"
}

resource "aws_instance" "example" {
  provider = aws.europe
  for_each = { env = "staging", geo = "us" }
}
```

> By default, Terraform automatically selects the default provider configuration based on the resource type, but you can configure multiple instances of the same provider with aliases and use a non-default provider configuration to import specific resources.

Directly relevant to [[tut-refresh]]'s failure mode: a resource in another region is invisible to the default provider, and this is how you point the import at the right one instead of changing the default.

**A module address.** `to` takes a `module.<NAME>` prefix, so the destination `resource` block can live in a child module:

```hcl
# main.tf
import {
  to = module.instances.aws_instance.example
  id = "i-abcd1234"
}
```

The `import` block stays in the root; only the address reaches into the module.

## Idempotency — why leaving the block in place is safe

> When you apply a configuration with import blocks, Terraform records that it **imported** the resources and that it **did not create** them.

> Because the import block is **idempotent**, applying an import action and running another plan does not generate another import action as long as that resource remains in your state. Furthermore, **attempting to import a resource into the same address more than once has no impact**.

That is the mechanism behind the recommendation both this page and [[tf-import-bulk]] give: keep the block *"as a record of the resource's origin for future module maintainers."* It costs nothing on every subsequent plan. Same disposition as a `moved` block, which is also a no-op once its `from` no longer exists ([[tut-move-config]]).

The page's steps, for the record: define the destination resource, add the `import` block, `terraform plan` and check it, then `terraform apply`. And *"if Terraform proposes any unexpected changes to the resource, update its configuration until it matches your intended settings"* — the loop [[tut-state-import]] runs twice before its plan comes out clean.

## What this page leaves to the reference

Whether `id` accepts anything other than a literal string. This page only ever shows `"i-abcd1234"`. [[tf-block-import]] answers it: *"a string or an expression that evaluates to a string"*, with the ID *"known during the plan operation"* — so `each.value`, a `var` or a `local` are fine, and another managed resource's attribute is not. The shape of **`to`** is settled here: type and label, optionally an instance key, optionally a `module.` prefix.

!!! warning "One broken code sample"
    The `count` example opens its destination block as `resource "aws_instance" "example {` — the label's closing quote is missing. It would not parse as written.

---
Related: [[tf-import]] — the hub, and the `id`-versus-`identity` distinction. · [[tf-import-bulk]] — the other workflow, for when you cannot easily obtain the IDs by hand. · [[tut-state-import]] — the same workflow as a transcript, including the pruning trap this page states as a rule. · [[tf-state-remove]] — the asymmetry: `removed`'s `from` takes no instance key, where `import`'s `to` does. · [[tut-move-config]] — `moved` blocks, idempotent and safe to leave in place for the same reason. · [[tut-refresh]] — why a provider alias on an import matters when the object is in another region.
