# Manage similar resources with `for_each`

> **Source:** [developer.hashicorp.com/terraform/tutorials/configuration-language/for-each](https://developer.hashicorp.com/terraform/tutorials/configuration-language/for-each)
> **Added:** 2026-08-01
> **Source updated:** undated tutorial (15 min); captured 2026-08-01 (both HCP Terraform and Community Edition variants)
> **Tags:** for_each, each.key, each.value, module-wrapping, count-and-for-each, provider-inheritance, for-expressions, refactoring
> **Type:** documentation

Eighth **Configuration Language** tutorial (sidebar: between *Count* and *Functions*), and the hands-on for [[tf-meta-for-each]]. Picks up roughly where [[tut-count]] left off — same VPC / load balancer / EC2 shape, same repo family (`learn-terraform-for-each`), and the EC2 block already uses `count`.

The exercise: go from **one project** to **many projects**, each with its own VPC, by iterating a map of project configurations. Terraform v1.2+, AWS credentials.

The most valuable part is not `for_each` itself — it is the workaround for the constraint both reference pages state and neither resolves.

## Combining `count` and `for_each` by wrapping in a module

> "You will also need to update the instance resource block to assign EC2 instances to each VPC. However, the block already uses `count`. **You cannot use both `count` and `for_each` in the same block.**
>
> To solve this, you will **move the `aws_instance` resource into a module**, including the `count` argument, and then use `for_each` when referring to the module."

That is the answer to "I need N instances per project, across M projects." `count` stays inside the module; `for_each` goes on the module block. The two multiply without ever appearing in the same block.

```hcl
module "ec2_instances" {
  source     = "./modules/aws-instance"
  depends_on = [module.vpc]

  for_each = var.project

  instance_count     = each.value.instances_per_subnet * length(module.vpc[each.key].private_subnets)
  instance_type      = each.value.instance_type
  subnet_ids         = module.vpc[each.key].private_subnets[*]
  security_group_ids = [module.app_security_group[each.key].security_group_id]

  project_name = each.key
  environment  = each.value.environment
}
```

`instance_count` is the same product expression [[tut-count]] used, now scoped per project. [[tf-meta-count]] and [[tf-meta-for-each]] both state the mutual exclusion as a flat prohibition; only this tutorial shows the way around it.

!!! note "A module using `count` or `for_each` cannot declare a `provider` block"
    Stated as a bare Note in the tutorial, and it is a real constraint:

    > "You cannot include a `provider` block in modules that use `count` or `for_each`. They must **inherit provider configuration from the root module**. Resources created by the module will all use the same provider configuration."

    So the wrapping trick above buys you multiplication but not multi-provider fan-out. One `for_each` module cannot put each instance in a different region by declaring its own provider — you would pass configurations in with `providers = { … }` from the root instead. See [[tf-provider-block]] and [[tf-meta-arguments]] on `providers`.

    This is also where the OpenTofu divergence bites hardest: OpenTofu's core-language `provider for_each` ([[ot-provider-for-each]]) exists precisely to make per-instance provider configuration expressible, and Terraform confines the equivalent to Stacks ([[tf-meta-for-each]]).

## The project map

```hcl
variable "project" {
  description = "Map of project names to configuration."
  type        = map(any)

  default = {
    client-webapp = {
      public_subnets_per_vpc  = 2,
      private_subnets_per_vpc = 2,
      instances_per_subnet    = 2,
      instance_type           = "t2.micro",
      environment             = "dev"
    },
    internal-webapp = {
      public_subnets_per_vpc  = 1,
      private_subnets_per_vpc = 1,
      instances_per_subnet    = 2,
      instance_type           = "t2.nano",
      environment             = "test"
    }
  }
}
```

This single variable replaces five scalars that were deleted from `variables.tf` — `project_name`, `environment`, `public_subnets_per_vpc`, `private_subnets_per_vpc`, `instance_type`. The refactor's shape is: **scalars describing one thing → a map of records describing many.**

`map(any)` works here only because both values have identical attribute sets. `any` unifies the element type across the map, so adding a third project with an extra attribute — or omitting one — fails type conversion. `map(object({ … }))` would be the honest type, and would also give better errors.

## Iterating, and correlating instances by key

Every module block in the root gets the same `for_each = var.project`, and correlation between them is by explicit key lookup:

```hcl
module "app_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/web"
  version = "4.9.0"

  for_each = var.project

  name        = "web-server-sg-${each.key}-${each.value.environment}"
  description = "Security group for web-servers with HTTP ports open within VPC"
  vpc_id      = module.vpc[each.key].vpc_id

  ingress_cidr_blocks = module.vpc[each.key].public_subnets_cidr_blocks
}
```

> "You can differentiate between instances of resources and modules configured with `for_each` by using the keys of the map you use. In this example, using `module.vpc[each.key].vpc_id` … means that the security group for a given project will be assigned to the corresponding VPC."

Worth contrasting with the **chaining** pattern from [[tf-meta-for-each]]: chaining writes `for_each = aws_vpc.example` so the downstream block's keys are *derived from* the upstream resource. Here every block independently iterates `var.project` and re-correlates with `[each.key]`. Both produce matching keys; only chaining makes the coupling structural. The tutorial never mentions chaining, and with five blocks all keyed off one variable it is arguably the right call — but the difference is worth knowing.

The load-balancer name shows what per-key naming costs in practice:

```hcl
name = trimsuffix(substr(replace(join("-", ["lb", random_string.lb_id.result, each.key, each.value.environment]), "/[^a-zA-Z0-9-]/", ""), 0, 32), "-")
```

Four nested functions to satisfy ELB's 32-character, restricted-charset name rule. Keys become part of resource names, and names have provider-side constraints.

## Outputs: `for` expressions, not `for_each`

```hcl
output "public_dns_names" {
  description = "Public DNS names of the load balancers for each project."
  value       = { for p in sort(keys(var.project)) : p => module.elb_http[p].elb_dns_name }
}

output "vpc_arns" {
  description = "ARNs of the vpcs for each project."
  value       = { for p in sort(keys(var.project)) : p => module.vpc[p].vpc_arn }
}

output "instance_ids" {
  description = "IDs of EC2 instances."
  value       = { for p in sort(keys(var.project)) : p => module.ec2_instances[p].instance_ids }
}
```

The tutorial is explicit about the confusion it is heading off:

> "`for` and `for_each` are different features. `for_each` provisions similar resources in module and resource blocks. `for` creates a list or map by iterating over a collection."

Outputs change shape as a result — `instance_ids` goes from a flat list to a map keyed by project:

```
instance_ids = {
  "client-webapp" = [
    "i-0e915495aead026a5",
    "i-0aaaf5526ca78691c",
    "i-0aab6ac6b7b608050",
    "i-09540fa5f7a63b396",
  ]
  "internal-webapp" = [
    "i-04fc247a327dd3a52",
    "i-00aae42ee2d6f7a62",
  ]
}
```

Four instances for the two-private-subnet project, two for the one-subnet project. The `sort(keys(...))` is cosmetic — map output ordering is already deterministic — but it costs nothing.

See [[tf-expr-for]] for `for` expressions and [[tf-outputs]] for output shapes.

## Two corrections

!!! danger "“The `for_each` argument also supports lists and sets” — the list half is wrong"
    That Note sits directly under the project map, and it contradicts the reference page, which says `for_each` "does **not** implicitly convert lists or tuples to sets" and requires "an expression that explicitly returns a set value, such as the `toset` function" ([[tf-meta-for-each]]).

    Verified locally on **Terraform v1.15.8**:

    ```hcl
    resource "terraform_data" "x" {
      for_each = ["a", "b"]
      input    = each.key
    }
    ```

    ```
    Error: Invalid for_each argument

    The given "for_each" argument value is unsuitable: the "for_each" argument
    must be a map, or set of strings, and you have provided a value of type
    tuple.
    ```

    A list literal is rejected outright. Sets are supported; lists are not.

!!! danger "“each.key is the index of the item in the collection” — wrong for sets"
    The tutorial says: "When you use `for_each` with a list or set, `each.key` is the **index** of the item in the collection, and `each.value` is the value of the item."

    The reference page says `each.key` is "the map key or **set member**", and that for a set `each.value` is the same as `each.key`. Verified on **Terraform v1.15.8**:

    ```hcl
    resource "terraform_data" "x" {
      for_each = toset(["alpha", "beta"])
      input    = "key=${each.key} value=${each.value}"
    }
    ```

    ```
    terraform_data.x["alpha"]: Creation complete after 0s
    terraform_data.x["beta"]: Creation complete after 0s

    keys = {
      "alpha" = "key=alpha value=alpha"
      "beta"  = "key=beta value=beta"
    }
    ```

    `each.key` is the **member string**, the instance address is `["alpha"]`, and `each.key == each.value`. No index appears anywhere. Both halves of that sentence are wrong, and it is the sentence a reader is most likely to internalize, because it is the only place either page explains sets in terms of `each.key`.

    Related evidence on the accepted-types question: [[conditional-branch-evaluation]].

## The lifecycle warning, and the tutorial's own example

!!! warning "The tutorial argues against its own structure, in a Note"
    > "Use separate Terraform projects or workspaces instead of `for_each` to manage resource lifecycles independently. For example, if production and development environments share the same Terraform project, running `terraform destroy` will destroy both."

    Then the worked example puts a `dev` project and a `test` project in one configuration, so a single `terraform destroy` takes out both — which is exactly what the destroy log shows (`0 added, 0 changed, 75 destroyed`).

    That is fine for a tutorial and dangerous as a template. The rule to carry forward: **`for_each` is for objects that share a lifecycle.** Environments do not share a lifecycle. See [[tf-state-workspaces]] and the [Workspaces topic page](../../topics/workspaces.md) for the alternative.

## Result

```
Plan: 74 to add, 0 to change, 39 to destroy.
...
Apply complete! Resources: 74 added, 0 changed, 39 destroyed.
```

Everything from the first apply is destroyed again. Same cause as [[tut-count]]'s `8 added / 4 destroyed`: resource **addresses** changed. `module.vpc.*` became `module.vpc["client-webapp"].*`, and `aws_instance.app[0]` became `module.ec2_instances["client-webapp"].aws_instance.app[0]`. A `moved` block per address would have preserved the objects; the tutorial again never mentions them.

Two rebuilds across two consecutive tutorials, neither acknowledged as avoidable, is a pattern worth naming: **the tutorials teach refactoring without teaching state refactoring.** See [[tf-block-removed]] and TID Ch6 §6.5.

## Currency

Same pins as [[tut-count]], and equally stale — AWS provider `~> 4.22.0`, vpc module 3.14.2, security-group 4.9.0, elb 3.0.1, against current 6.x / 6.6.1 / 6.0.0 / 4.0.2 (`cache/search/aws-modules-current-versions.md`).

One difference worth recording: **this page's snippets use `module.lb_security_group[each.key].security_group_id`** — the correct, post-v4.0 output name. [[tut-count]]'s page uses `this_security_group_id` for the same module at the same pinned version. Same module, same version, two tutorial pages, one of them stale. Corroborates that the `count` page's snippet is a rendering left behind, not a real API difference.

## Next steps

The tutorial points at the [`for_each` documentation](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) ([[tf-meta-for-each]]), the [`count` tutorial](https://developer.hashicorp.com/terraform/tutorials/configuration-language/count) ([[tut-count]]), and the modules tutorial. Next in the sidebar is **Functions**.

---
Related: [[tf-meta-for-each]] — the reference this is the lab for; states the `count`/`for_each` exclusion that this tutorial works around, and contradicts this page on lists and on `each.key` for sets. · [[tut-count]] — the previous tutorial; same repo shape, same stale pins, same unacknowledged rebuild, and the `count` this one wraps in a module. · [[tf-meta-count]] — the `count` reference. · [[conditional-branch-evaluation]] — accepted-type evidence. · [[tf-expr-for]] — the `for` expressions the outputs use, which are not `for_each`. · [[tf-provider-block]] — provider inheritance, which `count`/`for_each` modules are forced into. · [[ot-provider-for-each]] — OpenTofu's answer to the per-instance provider problem. · [[tf-block-removed]] — the `moved`/`removed` family both tutorials skip.
