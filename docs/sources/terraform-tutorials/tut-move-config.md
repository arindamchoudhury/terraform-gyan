# Use configuration to move resources

> **Source:** [developer.hashicorp.com/terraform/tutorials/modules/move-config](https://developer.hashicorp.com/terraform/tutorials/modules/move-config)
> **Added:** 2026-08-08
> **Source updated:** undated tutorial (~14 min); captured 2026-08-08
> **Tags:** moved-block, refactoring, state, module-extraction, resource-addresses, rename, terraform-1.3
> **Type:** documentation

Last page of the **Modules** collection, and the one that makes every earlier page survivable in a live system. [[tut-pattern-module-creation]] said how to scope modules; this one shows how to get existing resources *into* them without destroying anything. `git clone https://github.com/hashicorp-education/learn-terraform-move`. Both Community Edition and HCP Terraform variants captured; the only difference is a `cloud` block.

The premise, in the page's own words:

> When you move existing resources from a parent to a child module, your Terraform resource IDs will change. Because of this, you must let Terraform know that you intend to move resources rather than replace them, or Terraform will destroy and recreate your resources with the new ID.

An address **is** an identity in state ([[tf-state-purpose]]). Change the address and Terraform sees a different object. This is the same mechanism [[tut-count]] hit when a rename cost "8 added, 0 changed, 4 destroyed" — except that tutorial never named the fix, and this one is the fix.

## Setup

Start: a registry VPC module, a **local** `modules/security_group` module opening port 8080, and a bare `aws_instance.example` in the root. `terraform apply` → **24 resources**, and `curl $(terraform output -raw public_ip):8080` returns `Hello World`.

## The refactor, and what it costs without `moved`

Two changes at once, which is what makes the exercise realistic:

1. **Extract** the AMI data source and the EC2 instance from the root into a new local `modules/compute`, parameterized by `var.security_group` and `var.public_subnets`.
2. **Replace** the hand-written local security-group module with the registry's `terraform-aws-modules/security-group/aws`.

```hcl
module "web_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.13.0"

  vpc_id = module.vpc.vpc_id

  use_name_prefix = false

  name        = "terraform-learn-move-sg"
  description = "Security Group managed by Terraform"

  ingress_with_cidr_blocks = [
    {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = "0.0.0.0/0"
    }
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

module "ec2_instance" {
  source         = "./modules/compute"
  security_group = module.web_security_group.security_group_id
  public_subnets = module.vpc.public_subnets
}
```

Plan the refactor with no `moved` blocks and Terraform reads it as a wholesale replacement:

```
  # aws_instance.example will be destroyed
  # (because aws_instance.example is not in configuration)

  # module.ec2_instance.aws_instance.example will be created

  # module.security_group.aws_security_group.sg_8080 will be destroyed
  # (because aws_security_group.sg_8080 is not in configuration)

  ...

Plan: 4 to add, 0 to change, 4 to destroy.

Changes to Outputs:
  ~ public_ip = "18.119.128.83" -> (known after apply)
```

The reason line — **"because X is not in configuration"** — is the diagnostic to recognize. It means an address in state has no matching block, which is what Terraform sees whether you deleted a resource or merely renamed it. The output flipping to `(known after apply)` is the giveaway that the instance is genuinely being replaced.

## `moved` blocks

```hcl
moved {
  from = module.security_group.aws_security_group.sg_8080
  to   = module.web_security_group.aws_security_group.this[0]
}

moved {
  from = module.security_group.aws_security_group_rule.ingress_rule
  to   = module.web_security_group.aws_security_group_rule.ingress_with_cidr_blocks[0]
}

moved {
  from = module.security_group.aws_security_group_rule.egress_rule
  to   = module.web_security_group.aws_security_group_rule.egress_with_cidr_blocks[0]
}

moved {
  from = aws_instance.example
  to   = module.ec2_instance.aws_instance.example
}
```

Things worth noting about the shape of these:

- They live in the **root** `main.tf` yet name addresses *inside* modules on both sides. A `moved` block is written where the refactor is being made, not where the resource lives.
- The targets carry **`[0]` index keys**, because the registry module puts its resources under `count`. You have to know the destination module's internal addressing, which usually means reading the plan you were trying to avoid, or the module source.
- The tutorial does not use `terraform state mv` anywhere. The whole point is that the move is **declared in configuration**, reviewable in a plan and in a pull request — versus [[tf-state-refactor]]'s imperative `state mv`, which leaves no record.

## The result is not a no-op — and that's the lesson

```
  # aws_instance.example has moved to module.ec2_instance.aws_instance.example
    resource "aws_instance" "example" {
        id = "i-04783269f41a67c2e"
        # (30 unchanged attributes hidden)
    }

  # module.web_security_group.aws_security_group.this[0] will be updated in-place
  # (moved from module.security_group.aws_security_group.sg_8080)
  ~ resource "aws_security_group" "this" {
        id   = "sg-0f17c41383a0d2134"
      ~ tags = {
          + "Name" = "terraform-learn-move-sg"
        }
      + timeouts {
          + create = "10m"
          + delete = "15m"
        }
    }

  # module.web_security_group.aws_security_group_rule.ingress_with_cidr_blocks[0] will be updated in-place
  # (moved from module.security_group.aws_security_group_rule.ingress_rule)
  ~ resource "aws_security_group_rule" "ingress_with_cidr_blocks" {
      ~ description = "HTTP" -> "Ingress Rule"
        id          = "sgrule-201621573"
    }

Plan: 0 to add, 3 to change, 0 to destroy.
```

!!! tip "A move between two *different implementations* is a move plus an update"
    Four resources moved and the plan reports **3 to change**, not zero. The page explains it in one line:

    > The security group and its rules were updated in-place when they moved because the new module includes default values for some attributes that the old module did not.

    `moved` preserves **identity**, not **configuration**. The old hand-written module and the registry module describe the same objects differently — different `description` strings, a `Name` tag, `timeouts` defaults — so the move lands the resource under a new address whose desired state differs from what is deployed.

    That distinction is the practical one for a real refactor. **Extracting your own code into a module is normally a clean move** (the EC2 instance shows as `has moved to` with no change symbol at all). **Swapping a homegrown module for a registry one is a move *and* a config change**, and both arrive in the same apply. Review the `~` lines, not just the destroy count — a zero-destroy plan is not the same as a zero-impact plan.

The instance's own line has no action symbol: `has moved to`, `id` unchanged, "(30 unchanged attributes hidden)". That's what a pure move looks like.

## Renaming a whole module

One block moves everything inside it:

```hcl
moved {
  from = module.vpc
  to   = module.learn_vpc
}
```

Two details:

- **`terraform init` is required after renaming a module call**, because the install key changes — `Downloading … for learn_vpc` / `- learn_vpc in .terraform/modules/learn_vpc`. Renaming is not a plan-only operation.
- The apply is genuinely empty: `Plan: 0 to add, 0 to change, 0 to destroy`, with per-resource lines like `# module.vpc.aws_eip.nat[0] has moved to module.learn_vpc.aws_eip.nat[0]`. A module-level `moved` cascades to every address beneath it, index keys included.

## Keeping the blocks

> **We strongly recommend you retain all `moved` blocks in your configuration as a record of your changes. Removing a `moved` block plans to delete that existing resource instead of moving it.**

!!! note "The reference page is more precise about *when* you may remove one"
    The tutorial states this absolutely. [Refactoring](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) qualifies it, verified 2026-08-08:

    > "Removing a `moved` block is a breaking change because any configurations that refer to the old address will plan to delete the existing object instead of move it."
    >
    > "It can be safe to remove `moved` blocks when you are **maintaining private modules within an organization** and you are **certain that all users have successfully run `terraform apply`** with your new module version."
    >
    > "We strongly recommend that you retain all historical `moved` blocks from earlier versions of your modules to preserve the upgrade path for users of any previous version."

    So the rule is about **who else's state still holds the old address**. A published module keeps its `moved` blocks forever, because you cannot know which version a consumer is upgrading from — this is the migration half of the module-API story whose deprecation half is `deprecated` on variables and outputs ([[tut-pattern-module-creation]], I5). A private module can shed them once every consumer has applied. A root module you alone apply is the easiest case, and even there the blocks are free documentation of what happened.

## Notes on versions and scope

!!! warning "Prerequisite is stricter than the feature"
    The tutorial requires **Terraform v1.3+** and pins `required_version = ">= 1.3.0"`, but `moved` itself needs only **v1.1**: *"Terraform v1.1 and later is required to use `moved` blocks to explicitly refactor module addresses."* Nothing on the page depends on a 1.3 feature, so don't read the prerequisite as a `moved` requirement.

    Stale pins as usual: AWS provider `4.31.0`, vpc module `3.14.4`, security-group module `4.13.0` (current 6.x across the board), and an `ubuntu-focal-20.04` AMI filter. The security-group reference does use the post-v4.0 output name `security_group_id`, so it avoids the `this_` trap recorded in `cache/search/aws-modules-current-versions.md` and hit by [[tut-count]].

!!! note "What it doesn't cover"
    `moved` with `count`/`for_each` index keys as a *source* — the page points at the reference docs for that — and the `removed` block, which is the other config-driven state operation ([[tf-block-removed]], and the `lifecycle { destroy = false }` requirement recorded in **I7**). Also nothing on cross-*state* moves; `moved` works within one state file, so splitting a state into directories still needs [[tf-state-refactor]]'s machinery, which is exactly the migration tax [[tut-organize-configuration]] flagged and skipped.

## Next steps

Stated takeaway: built infrastructure, refactored it into modules, and used `moved` to update resource addresses safely. Onward pointers are the `moved` reference docs (including `for_each`/`count` usage), the local-module tutorial, the state-management tutorial, and the resource-lifecycle tutorial. This is the last page of the Modules collection; the sidebar's next entry is no-code modules.

---
Related: closes the Modules collection begun at [[tut-module]]. It is the operational answer to [[tut-pattern-module-creation]]'s scoping advice — rescoping a module is a state operation, not just an edit. Names the fix [[tut-count]] needed and never mentioned. Contrast [[tf-state-refactor]]'s imperative `state mv` and remove-and-import flows; contrast [[tf-block-removed]] for dropping resources rather than relocating them. Addresses-as-identity is [[tf-state-purpose]] and [[tf-cmd-state-list]]. Feeds learning-path **I7** (state operations — its hands-on for `moved`) and **A8** (refactoring at scale), and completes **I5**'s module-API-evolution story alongside `deprecated`.
