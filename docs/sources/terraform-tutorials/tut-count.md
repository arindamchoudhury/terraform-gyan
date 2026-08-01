# Manage similar resources with `count`

> **Source:** [developer.hashicorp.com/terraform/tutorials/configuration-language/count](https://developer.hashicorp.com/terraform/tutorials/configuration-language/count)
> **Added:** 2026-08-01
> **Source updated:** undated tutorial (10 min); captured 2026-08-01 (both HCP Terraform and Community Edition variants)
> **Tags:** count, count.index, modulo, splat, legacy-splat, refactoring, moved-block, scaling, load-balancer
> **Type:** documentation

Seventh **Configuration Language** tutorial (sidebar: between *Resource dependencies* and *For each*), and the hands-on for [[tf-meta-count]]. The same tutorial is also served at `/terraform/tutorials/0-13/count`, which is the URL [[tf-meta-arguments]] links to — the page's own footer confirms it "also appears in" the Terraform 0.13 collection.

The exercise is a **refactor**, not a greenfield build: start with two hard-coded EC2 instances, end with one `count` block whose size is computed. Terraform v1.2+, AWS credentials. Repo: `github.com/hashicorp-education/learn-terraform-count`.

## Starting point and its limitation

The initial config builds a VPC with public and private subnets, a load balancer, and **two** EC2 instances — `aws_instance.app_a` and `aws_instance.app_b`, one per private subnet. `private_subnets_per_vpc` controls the subnet count.

The stated problem is the point of the whole tutorial:

> "Currently, each private subnet only contains one EC2 instance. If you increase the `private_subnets_per_vpc` variable, Terraform won't automatically add EC2 instances, because the EC2 instance resources are hard coded."

Two hard-coded blocks cannot track a variable. That is the itch `count` scratches.

## The refactor

Three edits.

**1. Delete `aws_instance.app_b` entirely.**

**2. Rename `app_a` → `app`.**

```diff
- resource "aws_instance" "app_a" {
+ resource "aws_instance" "app" {
```

**3. Add the variable driving the count.**

```hcl
variable "instances_per_subnet" {
  description = "Number of EC2 instances in each private subnet"
  type        = number
  default     = 2
}
```

!!! danger "That rename destroys and recreates every instance — and the tutorial never mentions `moved`"
    The tutorial's own apply output gives it away: **`Apply complete! Resources: 8 added, 0 changed, 4 destroyed.`** Nothing about the infrastructure changed shape in a way that required replacement. The instances were destroyed because their **addresses** changed — `aws_instance.app_a` and `aws_instance.app_b` no longer exist, `aws_instance.app[0..3]` are new.

    A resource address is its identity in state. Rename the block and Terraform sees a deletion plus a creation, not a rename.

    **`moved` blocks (Terraform 1.1+) exist exactly for this**, and the tutorial requires 1.2+, so they were available when it was written:

    ```hcl
    moved {
      from = aws_instance.app_a
      to   = aws_instance.app[0]
    }
    ```

    Teaching a refactor without teaching the refactor-safety tool is a real omission — the reader learns that renaming resources costs a rebuild, and learns it as if that were normal. See [[tf-block-removed]] and TID Ch6 §6.5 on the `moved`/`removed` family.

## Scaling with `count`

```hcl
resource "aws_instance" "app" {
  depends_on = [module.vpc]

  count = var.instances_per_subnet * length(module.vpc.private_subnets)

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  subnet_id              = module.vpc.private_subnets[count.index % length(module.vpc.private_subnets)]
  vpc_security_group_ids = [module.app_security_group.security_group_id]

  ## ...
}
```

Two things worth taking away.

**The count is a product, not a literal.** `instances_per_subnet * length(module.vpc.private_subnets)` — one instance count derived from two independent knobs. Add a subnet and the instance count grows automatically, which is the limitation from the starting config, fixed.

**Modulo does the round-robin placement.** `count.index % length(private_subnets)` cycles instances across subnets: with 2 subnets, indices 0,1,2,3 map to subnets 0,1,0,1. This is the idiomatic answer to "spread N instances over M buckets" with a flat integer index, and it is the clearest illustration of what [[tf-meta-count]] means by "distinct values that **can't** be directly derived from an integer index" being the `for_each` case — here they *can*, so `count` fits.

Both operands must be known at plan time, per the `count` constraint in [[tf-meta-count]]. `length(module.vpc.private_subnets)` qualifies because subnet count comes from configuration, not from a post-apply attribute.

The tutorial's own gloss on `count.index`: "Each instance provisioned by the resource block with `count` will have a different incrementing value for `count.index` — starting with zero."

## Referencing the collection from the load balancer

```hcl
module "elb_http" {
  source  = "terraform-aws-modules/elb/aws"
  version = "3.0.1"

  security_groups = [module.lb_security_group.security_group_id]
  subnets         = module.vpc.public_subnets

  number_of_instances = length(aws_instance.app)
  instances           = aws_instance.app.*.id

  ## ...
}
```

And the output:

```hcl
output "instance_ids" {
  description = "IDs of EC2 instances"
  value       = aws_instance.app.*.id
}
```

The page states the addressing rule plainly:

> "The name of resources or modules provisioned with `count` refers to the entire collection. In this example, `aws_instance.app` now refers to all of the EC2 instances. You can reference individual items in collections with the same notation as list indexing."

`length(aws_instance.app)` works directly on the block reference — no index, no splat. That is the "block address vs instance address" distinction from [[tf-meta-count]] being used, not just described.

!!! warning "`aws_instance.app.*.id` is the **legacy** splat — prefer `[*]`"
    The tutorial uses the old attribute-only form `.*.` throughout. The modern form is `aws_instance.app[*].id`.

    They differ on nested indexing: with the legacy form an index applies to the **result of the whole iteration**, not to each element ([[tf-expr-splat]]). Same answer here, different answer as soon as the attribute is itself a list. The docs' own guidance is to always prefer `[*]` for consistent behavior, so treat the tutorial's syntax as period detail rather than as style to copy.

    Related pedantry from [[conditional-branch-evaluation]]: `aws_instance.app` is a **tuple**, not a list. It splats and takes `length()` exactly as a list does, which is why nothing here breaks.

## Result

```
Apply complete! Resources: 8 added, 0 changed, 4 destroyed.

Outputs:

instance_ids = [
  "i-0bc4309c117df766a",
  "i-0aaa6de2b610ae749",
  "i-035ff2723aace0f12",
  "i-02640c564d3f08152",
]
```

Four instances — 2 subnets × `instances_per_subnet = 2` — attached to the load balancer. Teardown is a plain `terraform destroy`.

## Currency

!!! warning "The page's `elb_http` snippet is out of sync with its own example repo"
    The tutorial page writes `module.app_security_group.this_security_group_id` and `module.lb_security_group.this_security_group_id`. The **`this_` prefix was dropped in security-group module v4.0**, and the tutorial pins **v4.9.0** — where `modules/web/outputs.tf` defines `security_group_id`, `security_group_vpc_id`, `security_group_owner_id`, `security_group_name`, `security_group_description`, and nothing named `this_*`.

    The example repo's `main.tf` is **correct** (`module.app_security_group.security_group_id`); only the rendered snippet is stale. So the tutorial works if you clone and edit as instructed, and breaks if you copy the page's code block into your own config.

    Verified 2026-08-01 against `raw.githubusercontent.com/terraform-aws-modules/terraform-aws-security-group/v4.9.0/modules/web/outputs.tf` and `hashicorp-education/learn-terraform-count/main/main.tf`. The snippets above are transcribed with the **repo's** name, not the page's.

!!! note "Every pin in this tutorial is several majors behind"
    | Dependency | Tutorial pins | Current (2026-08-01) |
    |---|---|---|
    | `hashicorp/aws` | `~> 4.22.0` | 6.x (see [[version-facts]]) |
    | `terraform-aws-modules/vpc/aws` | 3.14.2 | **6.6.1** |
    | `terraform-aws-modules/security-group/aws` | 4.9.0 | **6.0.0** |
    | `terraform-aws-modules/elb/aws` | 3.0.1 | **4.0.2** |

    Module versions checked against the Registry API on 2026-08-01. The pins are explicit, so the tutorial still applies as written; nothing here transfers to a current config unchanged. `aws_elb` itself is the classic load balancer — new work uses `aws_lb` / ALB.

## Next steps

The tutorial points at the [`count` documentation](https://developer.hashicorp.com/terraform/language/meta-arguments/count) ([[tf-meta-count]]), the [`for_each` tutorial](https://developer.hashicorp.com/terraform/tutorials/configuration-language/for-each), and the functions/dynamic-expressions tutorial. `for_each` is next in the sidebar and is not captured yet.

---
Related: [[tf-meta-count]] — the reference this is the lab for; supplies the plan-time-known constraint and the positional-keying pitfall the tutorial demonstrates without naming. · [[tut-dependencies]] — the previous tutorial in the collection; this config carries the same `depends_on = [module.vpc]`. · [[tf-expr-splat]] — why `.*.` here should be `[*]` in anything you write. · [[conditional-branch-evaluation]] — the block reference is a tuple, not a list. · [[tf-block-removed]] — the `moved`/`removed` family the refactor should have used. · [[meta-arguments-lifecycle]] — `count` among the six.
