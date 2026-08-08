# Chapter 4 — How to Create Reusable Infrastructure with Terraform Modules

> *Source: Brikman (2022), **Terraform: Up & Running**, 3rd ed., Chapter 4, pages 115–140.*
>
> The chapter that turns Chapter 3's single staging environment into a reusable module used by **both** staging and production. Six sections, in the order the problem forces: module basics → inputs → locals → outputs → gotchas → versioning. It is the book's answer to "how do I add production without copy-pasting staging?"
>
> 📌 **Notes adapted where version-bound.** Book written 2022 against Terraform ~1.1; current stable is **1.15.8** / OpenTofu **1.12.4** (see [[version-facts]]). The *ideas* here have aged well and are still the clearest treatment of module inputs/outputs/versioning available. The *AWS resources* have not — two of the chapter's central examples are now discouraged or impossible, flagged inline and summarized at the end.

> 🔗 **See also:** [Modules](../../../topics/modules.md) — this chapter is a second full-treatment source alongside TID Ch3, so the topic page can now be extended rather than backlogged.

---

## The problem, stated as a copy-paste question

Chapter 3 ended with one environment: load balancer, web server cluster, database. Real teams need at least two — staging for internal testing, production for users — "ideally nearly identical, though you might run slightly fewer/smaller servers in staging to save money."

> How do you add this production environment without having to copy and paste all of the code from staging?

The analogy the whole chapter runs on is **the function**. In a general-purpose language you extract repeated code into a function and call it from several places; in Terraform you extract it into a **module** and call it from several places. Each section then maps a language feature onto a function feature:

| Function concept | Terraform mechanism |
| --- | --- |
| Define once, call many | `module` block with `source` |
| Input parameters | `variable` blocks |
| Local intermediate values | `locals` block |
| Return values | `output` blocks |
| Library versioning | Git tags on the module repo |

Brikman's claim for why this matters is worth keeping because it is about trajectory, not syntax:

> Modules are the key ingredient to writing reusable, maintainable, and testable Terraform code. Once you start using them, there's no going back. You'll start building everything as a module … and thinking of your entire infrastructure as a collection of reusable modules.

## Module basics

The definition is the structural one:

> A Terraform module is very simple: **any set of Terraform configuration files in a folder is a module.** All of the configurations you've written so far have technically been modules … if you run `apply` directly on a module, it's referred to as a **root module**.

And the distinction the chapter actually cares about: a **reusable module** is "a module that is meant to be used within other modules" — the thing you build here.

**The refactor, mechanically:** `terraform destroy` the staging cluster, create a top-level `modules/` folder, move everything from `stage/services/webserver-cluster` into `modules/services/webserver-cluster`, then **remove the `provider` block**.

> Providers should be configured only in root modules and not in reusable modules.

Stated flatly in 2022, and the reason arrived later — the destroy-ordering argument in [[tf-modules-providers]], plus the `count`/`for_each`/`depends_on` conflict introduced in 0.13. This chapter predates the explanation but gets the rule right.

The call syntax, and both environments using it identically:

```hcl
module "<NAME>" {
  source = "<SOURCE>"

  [CONFIG ...]
}
```

```hcl
provider "aws" {
  region = "us-east-2"
}

module "webserver_cluster" {
  source = "../../../modules/services/webserver-cluster"
}
```

> Note that whenever you add a module to your Terraform configurations or modify the `source` parameter of a module, you need to run the `init` command before you run `plan` or `apply`.

Which prompts the neat summary of what `init` actually is:

> it installs providers, it configures your backends, and it downloads modules, all in one handy command.

**And then the deliberate failure.** The chapter stops before applying, because the extracted module still hardcodes every name — security groups, ALB, and the `terraform_remote_state` lookup that points at *staging's* state file. Using it twice in one AWS account produces name-conflict errors. That is the setup for the next section, and it is good pedagogy: the module is broken in exactly the way that motivates inputs.

## Module inputs

Input variables are the module's parameters. Three to start:

```hcl
variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type        = string
}

variable "db_remote_state_bucket" {
  description = "The name of the S3 bucket for the database's remote state"
  type        = string
}

variable "db_remote_state_key" {
  description = "The path for the database's remote state in S3"
  type        = string
}
```

Every hardcoded name becomes `"${var.cluster_name}-alb"`, `"${var.cluster_name}-instance"`, and so on, and the remote-state lookup becomes environment-parameterized:

```hcl
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "us-east-2"
  }
}
```

The sentence that earns the section:

> The input variables are **the API of the module**, controlling how it will behave in different environments.

A second batch makes the *size* configurable, which is where staging and production genuinely diverge — `instance_type`, `min_size`, `max_size`. Staging runs `t2.micro` with min and max both 2; production runs `m4.large` with min 2 and max 10.

!!! note "This is the concrete case for “a value your purpose fixes is not a variable”"
    The chapter's own split is a clean illustration of the rule stated abstractly in [[tut-pattern-module-creation]] and [[tut-module-create]]. `cluster_name` and the remote-state coordinates **must** vary — the module is unusable twice in one account otherwise. `instance_type` and the ASG bounds **may** vary, and are exposed because staging-versus-production cost is a real reason. Nothing else was exposed. That is minimize-inputs applied by a working example rather than asserted.

    Worth noting `m4.large` is now a previous-generation instance type; `m5`/`m6i` or a Graviton equivalent is the modern choice. The chapter warns it is outside the free tier, which is still true.

## Module locals

The motivation is a value that repeats but should **not** be configurable — the load balancer's port 80, and the "any port / any protocol / all IPs" magic values sprayed through the security groups.

> You could extract values into input variables, but then **users of your module will be able to (accidentally) override these values, which you might not want.**

That is the sharpest statement of the locals-versus-variables distinction anywhere in these notes: a variable is not just a named value, it is **permission to change it**. Same conclusion [[tut-module-use]] reaches from the caller's side with `enable_nat_gateway`.

```hcl
locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}
```

> These names are **visible only within the module**, so they will have no impact on other modules, and you **can't override these values from outside** of the module.

Read with `local.<NAME>`. The section closes with "Locals make your code easier to read and maintain, so use them often." Reference: [[tf-locals]], [[tf-block-locals]]; the hands-on with `merge()` is [[tut-locals]].

## Module outputs

The motivating problem is a good one: production wants **scheduled scaling** — scale out at 9 a.m., in at 5 p.m. — which staging does not need. Since conditional resources are Chapter 5's topic, the scheduled actions live in the production root module rather than inside the shared module.

```hcl
resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  scheduled_action_name  = "scale-out-during-business-hours"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 10
  recurrence             = "0 9 * * *"
  autoscaling_group_name = module.webserver_cluster.asg_name
}

resource "aws_autoscaling_schedule" "scale_in_at_night" {
  scheduled_action_name  = "scale-in-at-night"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 2
  recurrence             = "0 17 * * *"
  autoscaling_group_name = module.webserver_cluster.asg_name
}
```

But `autoscaling_group_name` is required and the ASG lives *inside* the module — so the module must return it:

```hcl
output "asg_name" {
  value       = aws_autoscaling_group.example.name
  description = "The name of the Auto Scaling Group"
}
```

Read as `module.<MODULE_NAME>.<OUTPUT_NAME>`.

!!! tip "The pass-through output is the pattern worth stealing"
    The ALB's DNS name is exported from the module *and then re-exported* by each environment's root module:

    ```hcl
    output "alb_dns_name" {
      value       = module.webserver_cluster.alb_dns_name
      description = "The domain name of the load balancer"
    }
    ```

    The chapter presents this as a convenience — "so you know what URL to test". It is actually the mechanism [[tut-module-use]] states as a rule: *"Terraform will not display module outputs by default. You must create a corresponding output in your root module."* A child's outputs are readable in configuration but invisible at the CLI. The book demonstrates the workaround three years before the tutorial names the constraint.

## Gotcha 1 — file paths

`templatefile` needs a relative path, and "By default, Terraform interprets the path **relative to the current working directory**." Fine in a root module, wrong in a reusable one.

The three path references, quoted:

- **`path.module`** — "the filesystem path of the module where the expression is defined."
- **`path.root`** — "the filesystem path of the root module."
- **`path.cwd`** — "the filesystem path of the current working directory. In normal use of Terraform, this is the same as `path.root`, but some advanced uses of Terraform run it from a directory other than the root module directory."

```hcl
user_data = templatefile("${path.module}/user-data.sh", {
  server_port = var.server_port
  db_address  = data.terraform_remote_state.db.outputs.address
  db_port     = data.terraform_remote_state.db.outputs.port
})
```

Same distinction [[tut-module-object-attributes]] exercises from the other direction, where the *caller* passes `${path.root}/www` and the module falls back to `${path.module}/www`. Reference: [[tf-expr-references]].

## Gotcha 2 — inline blocks

The rule first:

> If you try to use a mix of both inline blocks and separate resources … you will get errors where the configurations conflict and overwrite one another. Therefore, **you must use one or the other.** Here's my advice: **when creating a module, you should always prefer using separate resources.**

And the reason, which is an encapsulation argument rather than a correctness one:

> The advantage of using separate resources is that they **can be added anywhere**, whereas an inline block can only be added **within the module that creates a resource**. So using solely separate resources makes your module more flexible and configurable.

The payoff is demonstrated concretely: with the security group's rules moved out to `aws_security_group_rule` resources and the group's ID exported as an output, a *caller* can open an extra port for testing without the module knowing anything about it:

```hcl
resource "aws_security_group_rule" "allow_testing_inbound" {
  type              = "ingress"
  security_group_id = module.webserver_cluster.alb_security_group_id

  from_port   = 12345
  to_port     = 12345
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
```

> Had you defined even a single ingress or egress rule as an inline block, this code would not work.

Affected resource pairs the chapter names: `aws_security_group` / `aws_security_group_rule`, `aws_route_table` / `aws_route`, `aws_network_acl` / `aws_network_acl_rule`.

!!! warning "The advice is right; the resource it names has since been superseded"
    The AWS provider now documents a **third** shape and steers away from both of the chapter's options. Verified at provider **v6.54.0** (see [[dynamic-blocks-facts]]):

    > "To avoid these problems, use the current best practice of the `aws_vpc_security_group_egress_rule` and `aws_vpc_security_group_ingress_rule` resources with one CIDR block per rule."

    > "You should not use the `aws_security_group` resource with *in-line rules* … in conjunction with the `aws_vpc_security_group_egress_rule` and `aws_vpc_security_group_ingress_rule` resources **or the `aws_security_group_rule` resource.** Doing so may cause rule conflicts, perpetual differences, and result in rules being overwritten."

    So the **principle survives intact** — separate resources beat inline blocks, because separate resources can be contributed by a caller — while the specific resource type in the example is now the previous generation. Substitute `aws_vpc_security_group_ingress_rule` and the caller-extends-the-module trick works identically. Inline blocks are still supported, not deprecated.

!!! note "Sidebar — network isolation"
    The chapter is honest that its two environments are isolated in code and in resources but **not at the network level**: everything lands in the same VPC to keep examples simple. Two named risks — a mistake in staging (e.g. mangled route tables) affecting production, and an attacker who reaches one environment reaching the other.

    > outside of simple examples and experiments, you should run each environment in a separate VPC. In fact, to be extra sure, you might even run each environment in a **totally separate AWS account.**

    That is the multi-account position learning-path **A7** takes, stated in 2022.

## Module versioning

The problem with a local `source` path:

> as soon as you make a change in that folder, it will affect **both** environments on the very next deployment.

The fix is a **two-repository** split, and the metaphor is the memorable part:

- **`modules`** — "Think of each module as a *blueprint* that defines a specific part of your infrastructure."
- **`live`** — "the live infrastructure you're running in each environment (stage, prod, mgmt, etc.). Think of this as the *houses* you built from the *blueprints*."

Tag the modules repo and point each environment at a different tag:

```bash
git tag -a "v0.0.1" -m "First release of webserver-cluster module"
git push --follow-tags
```

```hcl
module "webserver_cluster" {
  source = "github.com/foo/modules//services/webserver-cluster?ref=v0.0.1"

  cluster_name           = "webservers-stage"
  db_remote_state_bucket = "(YOUR_BUCKET_NAME)"
  db_remote_state_key    = "stage/data-stores/mysql/terraform.tfstate"

  instance_type = "t2.micro"
  min_size      = 2
  max_size      = 2
}
```

"Note that the double-slash in the following Git URL is required" — the `//` sub-directory marker specified in [[tf-block-module]].

**Why tags and not the alternatives**, quoted because the reasoning is the useful bit:

> The `ref` parameter allows you to specify a particular Git commit via its sha1 hash, a branch name, or, as in this example, a specific Git tag. I generally recommend using Git tags as version numbers for modules. **Branch names are not stable**, as you always get the latest commit on a branch, which may change every time you run the `init` command, and the **sha1 hashes are not very human friendly.** Git tags are as stable as a commit (in fact, a tag is just a pointer to a commit), but they allow you to use a friendly, readable name.

!!! warning "“A tag is as stable as a commit” is the one claim here that has not aged well"
    A Git tag is a *pointer* to a commit, and pointers move. Whoever controls the source repository can force-move `v0.0.1` to different code, and your pin follows silently. That is the supply-chain exposure recorded in learning-path **I4**, where the resolution is: SHA-pin third-party modules you do not control, tag-pin modules in your own org with tag-protection rules — and accept that no update bot (Renovate or Dependabot) will move a SHA pin for you.

    Brikman's argument was about **stability against accidental drift**, and against a branch it is completely correct. It was not written against an adversary. Read the recommendation as "tags over branches, always" — which stands — rather than "tags are equivalent to commits", which is only true when nobody moves them.

    A third cost arrived later still: `?depth=1` shallow clones **reject a SHA `ref`**, so the immutable pin and the fast clone are mutually exclusive ([[tf-block-module]], `cache/search/git-module-shallow-clone-vs-sha-pin.md`).

**Semantic versioning** is recommended for the tags — MAJOR for incompatible API changes, MINOR for backward-compatible additions, PATCH for backward-compatible fixes — with the point that it "gives you a way to communicate to users of your module what kinds of changes you've made and the implications of upgrading." Note the registry later *requires* this shape (`cache/search/module-repo-naming-convention.md`).

The promotion workflow is then the whole argument for versioning: tag `v0.0.2`, point **staging only** at it, leave production on `v0.0.1`, and "if there turns out to be a bug in v0.0.2, no big deal, because it has no effect on the real users of your production environment."

!!! note "Sidebar — private repos, and the develop-locally exception"
    **Private Git repos:** use SSH auth so credentials never enter the code; each developer adds their key to `ssh-agent` and Terraform uses it automatically. URL shape `git@github.com:<OWNER>/<REPO>.git//<PATH>?ref=<VERSION>`, and the test is simply whether `git clone` of the base URL succeeds. ([[tf-block-module]] adds the constraint the book could not: **in HCP Terraform runs, SSH keys are the only supported authentication for Git module sources.**)

    **Developing modules:** versioned sources are for shared environments; while iterating on your own machine, use local file paths, "because you'll be able to make a change in the module folders and rerun the plan or apply command in the live folders immediately, rather than having to commit your code, publish a new version, and rerun `init` each time." That is the same edit-loop argument [[tut-module-create]] makes from the mechanism — local modules are referenced in place, not copied.

## Conclusion — what the chapter is really arguing

> By defining infrastructure as code in modules, you can apply **a variety of software engineering best practices** to your infrastructure. You can validate each change to a module through code reviews and automated tests, you can create semantically versioned releases of each module, and you can safely try out different versions of a module in different environments and **roll back** to previous versions if you hit a problem.

The forward pointer sets up Chapter 5: to serve multiple teams a module must be flexible — one team wants a single instance with no load balancer, another wants a dozen behind one — which needs conditionals and loops.

### State of the running example

By the end of Ch4: a `modules/services/webserver-cluster` reusable module with six input variables (`cluster_name`, `db_remote_state_bucket`, `db_remote_state_key`, `instance_type`, `min_size`, `max_size`), locals for the port/protocol constants, three outputs (`asg_name`, `alb_dns_name`, `alb_security_group_id`), separate `aws_security_group_rule` resources, and `${path.module}` on the user-data template. Called from `live/stage/...` and `live/prod/...` root modules, with production additionally defining two `aws_autoscaling_schedule` resources.

---

## Version reckoning

Three things to carry forward when reading this chapter against a current Terraform and a current AWS.

!!! danger "`aws_launch_configuration` — the running example cannot be created in a new AWS account"
    The ASG throughout Chapters 2–5 is driven by `aws_launch_configuration`. AWS's own limits, quoted in [[launch-configurations-eol]]:

    > As of **January 1, 2023**, new Amazon EC2 instance types are no longer supported in launch configurations.
    >
    > Accounts created on or after **October 1, 2024** cannot create new launch configurations using **any method (console, API, AWS CLI, or CloudFormation)**.

    The AWS provider carries a matching `!> WARNING: The use of launch configurations is discouraged in favor of launch templates.` The resource still exists in the provider, so this is an **AWS-side** blocker rather than a Terraform one — and it is absolute for a recent account, not advisory. Substitute `aws_launch_template` plus a `launch_template` block on the ASG.

    None of the chapter's *teaching* depends on it: the module boundary, the inputs, the outputs and the versioning story are all unchanged by swapping the resource.

!!! note "Two smaller drifts"
    - **`aws_security_group_rule`** is superseded by `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` (see the gotcha above). The chapter's principle is unaffected.
    - **`m4.large`** is previous-generation, and the hardcoded `ami-0fb653ca2d3203ac1` is region-locked and will eventually be deregistered — the same hazard flagged in [[tut-module-use]]. Prefer an `aws_ami` data source or an SSM parameter lookup.

!!! tip "What TUR Ch4 has that TID Ch3 doesn't, and vice versa"
    Both books devote a chapter to modules, and they are worth reading as a pair rather than as substitutes.

    - **TUR is narrative and operational.** It arrives at every feature because the running example broke without it, and it is the only source here that walks the *promotion workflow* end to end — tag, point staging at the new tag, leave production behind, roll forward when proven.
    - **TID Ch3 is reference-shaped** ([[03-variables-modules]]): the three module flavors, the full type system, `validation`, `sensitive`, and publishing to a registry — ground TUR Ch4 never covers, since it stops at Git-tag versioning and never mentions a module registry at all.
    - **Neither covers `moved`**, so neither tells you what refactoring an existing deployment into a module actually costs. That is [[tf-modules-refactoring]] and [[tut-move-config]].

---

*Related notes:* [Modules](../../../topics/modules.md) topic page · TID Ch3 [[03-variables-modules]] · [[tf-modules-develop]] and [[tf-modules-composition]] for the modern design guidance · [[tf-block-module]] for the `source` and `ref` specification · [[tut-module-create]] for the same refactor as a HashiCorp tutorial. Feeds learning-path **I4** (using modules) and **I5** (authoring modules).
