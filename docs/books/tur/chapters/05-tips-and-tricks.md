# Chapter 5 — Terraform Tips and Tricks: Loops, If-Statements, Deployment, and Gotchas

> *Source: Brikman (2022), **Terraform: Up & Running**, 3rd ed., Chapter 5, pages 141–190.*
>
> The chapter that answers "how do I write a loop in a language with no loops?" Four looping constructs, three ways to fake a conditional, one zero-downtime deployment technique that it then talks you out of, and four gotchas. At fifty pages it is the longest chapter in the book, and the most reference-shaped.
>
> 📌 **Notes adapted where version-bound.** Book written 2022 against Terraform ~1.2; current stable is **1.15.8** / OpenTofu **1.12.5** ([[version-facts]]). **This chapter has aged better than any other in TUR.** It already covers `instance_refresh` and `moved` blocks, and it already argues against its own zero-downtime hack. The language content needs no corrections at all — only the AWS resources underneath it, and one piece of import advice that Terraform 1.5 superseded.

> 🔗 **See also:** [Meta-arguments and `lifecycle`](../../../topics/meta-arguments-lifecycle.md) for the `count`/`for_each`/`create_before_destroy` reference treatment.

---

## The framing

Chapter 1 argued that declarative beats procedural. This chapter is the bill for that choice:

> because declarative languages typically don't have for-loops, how do you repeat a piece of logic … without copy and paste? And if the declarative language doesn't support if-statements, how can you conditionally configure resources …? Finally, how do you express an inherently procedural idea, such as a zero-downtime deployment, in a declarative language?

The answer is a short list of primitives — `count`, `for_each`, `for`, the ternary operator, `create_before_destroy`, and the function library — used in ways that are frankly workarounds. The chapter is honest about that, and the honesty is what makes it useful.

## 1. Loops

Four constructs, each for a different scope. Getting this table right is most of the chapter:

| Construct | Loops over | Applies to |
| --- | --- | --- |
| `count` | a number | resources and modules |
| `for_each` | sets and maps | resources, **inline blocks**, modules |
| `for` expression | lists and maps | any expression producing a list or map |
| `for` string directive | lists and maps | inside a string |

### `count`

> `count` is Terraform's oldest, simplest, and most limited iteration construct: all it does is define how many copies of the resource to create.

```hcl
variable "user_names" {
  description = "Create IAM users with these names"
  type        = list(string)
  default     = ["neo", "trinity", "morpheus"]
}

resource "aws_iam_user" "example" {
  count = length(var.user_names)
  name  = var.user_names[count.index]
}
```

`count.index` is the iteration index. Once `count` is set, **the resource becomes an array**, so the reference grammar changes:

```text
<PROVIDER>_<TYPE>.<NAME>[INDEX].<ATTRIBUTE>     # one of them
<PROVIDER>_<TYPE>.<NAME>[*].<ATTRIBUTE>         # all of them, via splat
```

`count` works on modules identically since 0.13, and `module.users[*].user_arn` is the module-shaped splat.

**Two limitations**, and the second is the one that matters:

- **`count` cannot loop over inline blocks.** The ASG's `tag` blocks cannot be generated with it.
- **`count` identifies resources by position**, so removing an item from the middle of the list shifts everything after it.

The demonstration is the best thing in the section. Remove `"trinity"` from the middle of the list and the plan is not one deletion:

```text
# aws_iam_user.example[1] will be updated in-place
  ~ name = "trinity" -> "morpheus"

# aws_iam_user.example[2] will be destroyed

Plan: 0 to add, 1 to change, 1 to destroy.
```

Because index *is* identity, Terraform reads this as "rename index 1 and delete index 2".

> every time you use `count` to create a list of resources, if you remove an item from the middle of the list, Terraform will delete every resource after that item and then re-create those resources again from scratch. Ouch.

And the consequence stated plainly: you may lose availability during the apply, and if the resource is a database, you may lose the data.

### `for_each`

Introduced in 0.12 to fix exactly that.

```hcl
resource "aws_iam_user" "example" {
  for_each = toset(var.user_names)
  name     = each.value
}
```

Note `toset` — **`for_each` on a resource accepts sets and maps only, not lists.** Inside the block, `each.key` and `each.value`; with a set they are the same, so `each.key` is really for maps.

The resource becomes a **map** rather than an array, keyed by the `for_each` key. Which is the whole point:

```text
# aws_iam_user.example["trinity"] will be destroyed

Plan: 0 to add, 0 to change, 1 to destroy.
```

> This is why you should almost always prefer to use `for_each` instead of `count` to create multiple copies of a resource.

Extracting a flat list from the map takes two functions and a splat, which is the small tax for keyed identity:

```hcl
output "all_arns" {
  value = values(aws_iam_user.example)[*].arn
}
```

### `dynamic` blocks — `for_each` inside a resource

The second thing `for_each` can do, and the reason it replaces `count` rather than merely improving on it:

```hcl
dynamic "<VAR_NAME>" {
  for_each = <COLLECTION>

  content {
    [CONFIG...]
  }
}
```

Applied to the ASG's tags:

```hcl
dynamic "tag" {
  for_each = var.custom_tags

  content {
    key                 = tag.key
    value               = tag.value
    propagate_at_launch = true
  }
}
```

The iterator is named after the block (`tag.key`, `tag.value`), which is worth noticing because it reads like a coincidence and is not. With a list the key is the index; with a map it is the map key.

!!! note "Sidebar — enforcing tagging standards, and the exception that forced this section"
    The chapter's better answer for tags you want everywhere is provider-level `default_tags`:

    ```hcl
    provider "aws" {
      region = "us-east-2"

      default_tags {
        tags = {
          Owner     = "team-foo"
          ManagedBy = "Terraform"
        }
      }
    }
    ```

    It then names its own exception: resources that do not support tags, and **`aws_autoscaling_group`, which supports tags but which the chapter says does not work with `default_tags`** — *"which is why you had to do all that work in the previous section"*.

    > ❓ Unverified as of 2026-08-16: the current `aws_autoscaling_group` documentation does not mention `default_tags` in either direction, so I could not confirm whether that exception still holds. What is observable is that the resource still has its own `tag`/`tags` handling and that the `dynamic "tag"` workaround still works. Check the provider docs before relying on `default_tags` reaching an ASG.

### `for` expressions

For transforming a value rather than multiplying a resource. The chapter teaches it against Python list comprehensions, which is the right analogy.

```hcl
[for <ITEM> in <LIST> : <OUTPUT>]                       # list → list
[for <KEY>, <VALUE> in <MAP> : <OUTPUT>]                # map → list
{for <ITEM> in <LIST> : <OUT_KEY> => <OUT_VALUE>}       # list → map
{for <KEY>, <VALUE> in <MAP> : <OUT_KEY> => <OUT_VALUE>}  # map → map
```

Square brackets produce a list, curly braces plus `=>` produce a map. An `if` clause filters:

```hcl
output "short_upper_names" {
  value = [for name in var.names : upper(name) if length(name) < 5]
}
```

### The `for` string directive

Same idea inside a string, with `%{...}` instead of `${...}`:

```hcl
%{ for <ITEM> in <COLLECTION> }<BODY>%{ endfor }
%{ for <INDEX>, <ITEM> in <COLLECTION> }<BODY>%{ endfor }
```

```hcl
output "for_directive" {
  value = "%{ for name in var.names }${name}, %{ endfor }"
}
# => "neo, trinity, morpheus, "
```

The trailing comma is deliberate — it is the setup for the `if` directive later.

## 2. Conditionals

Three mechanisms, mapped to three scopes: `count` for conditional resources, `for_each`+`for` for conditional resources and inline blocks, and the `if` string directive for strings.

### If-statements with `count`

Two properties combined:

- `count = 1` creates one copy; `count = 0` creates none.
- Terraform has a ternary: `<CONDITION> ? <TRUE_VAL> : <FALSE_VAL>`.

```hcl
resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
  count = var.enable_autoscaling ? 1 : 0

  scheduled_action_name  = "${var.cluster_name}-scale-out-during-business-hours"
  min_size               = 2
  max_size               = 10
  desired_capacity       = 10
  recurrence             = "0 9 * * *"
  autoscaling_group_name = aws_autoscaling_group.example.name
}
```

This closes a loop from Chapter 4, where the scheduled actions had to live in the production root module *because* the shared module could not express "only in prod". Now they move inside, behind `enable_autoscaling`.

### If-else with `count`

Two resources with mirrored conditions — `? 1 : 0` on one, `? 0 : 1` on the other. That part is mechanical. The interesting half is reading an attribute off whichever one exists.

The obvious approach is another ternary, and the chapter rejects it as brittle: change the `count` condition later and you must remember to change the output's condition too, or get "a very confusing error when trying to access an array element that might not exist."

```hcl
output "neo_cloudwatch_policy_arn" {
  value = one(concat(
    aws_iam_user_policy_attachment.neo_cloudwatch_full_access[*].policy_arn,
    aws_iam_user_policy_attachment.neo_cloudwatch_read_only[*].policy_arn
  ))
}
```

`concat` joins the two splat results, one of which is always empty; `one` returns `null` for an empty list, the single element for a one-element list, and errors on more. So the expression stays correct no matter how the condition changes.

> 💭 (mine): `one(concat(...))` is the most transferable trick in the chapter. Any time a value comes from exactly one of several `count`-gated resources, this is the idiom, and it is self-checking — if two of them ever exist at once, `one` errors rather than silently picking.

The chapter's own verdict on the whole approach is refreshingly unromantic: *"Using `count` and built-in functions to simulate if-else-statements is a bit of a hack, but it's one that works fairly well."*

### Conditionals with `for_each` and `for`

An empty collection produces zero copies, so filtering the collection *is* the conditional:

```hcl
dynamic "tag" {
  for_each = {
    for key, value in var.custom_tags :
    key => upper(value)
    if key != "Name"
  }

  content {
    key                 = tag.key
    value               = tag.value
    propagate_at_launch = true
  }
}
```

The `if key != "Name"` filter exists because the module already sets its own `Name` tag — a real conflict, not a contrived example.

!!! tip "The rule the chapter lands on, which is easy to misremember"
    Prefer `for_each` over `count` **for creating multiple copies**. Prefer `count` over `for_each` **for conditionals**:

    > when it comes to conditional logic, setting `count` to 0 or 1 tends to be simpler than setting `for_each` to an empty or nonempty collection. Therefore, I typically recommend using `count` to conditionally create resources and modules, and using `for_each` for all other types of loops and conditionals.

    Both halves matter. The `count` reindexing hazard does not apply when the count is only ever 0 or 1, so the usual argument against `count` does not bite here.

### The `if` string directive

```hcl
%{ if <CONDITION> }<TRUEVAL>%{ endif }
%{ if <CONDITION> }<TRUEVAL>%{ else }<FALSEVAL>%{ endif }
```

Used to fix the trailing comma from the `for` directive — and the fix immediately introduces a whitespace problem, because "every whitespace you put in a HEREDOC ends up in the final string." Hence **strip markers**, `~`, which eat whitespace on the side they face:

```hcl
output "for_directive_index_if_else_strip" {
  value = <<EOF
%{~ for i, name in var.names ~}
${name}%{ if i < length(var.names) - 1 }, %{ else }.%{ endif }
%{~ endfor ~}
EOF
}
# => "neo, trinity, morpheus."
```

## 3. Zero-downtime deployment

The problem: changing the launch configuration replaces it, and the ASG updates in place to point at the new one — but **that has no effect until the ASG launches new instances**. Destroying and recreating the ASG means downtime.

The technique, in three steps:

1. Make the ASG's `name` depend on the launch configuration's name, so the ASG is replaced whenever the launch configuration changes.
2. Set `create_before_destroy = true` on the ASG.
3. Set `min_elb_capacity` to the cluster's `min_size`, so Terraform waits for that many new instances to pass ALB health checks before destroying the old ASG.

```hcl
resource "aws_autoscaling_group" "example" {
  # Explicitly depend on the launch configuration's name so each time it's
  # replaced, this ASG is also replaced
  name = "${var.cluster_name}-${aws_launch_configuration.example.name}"

  launch_configuration = aws_launch_configuration.example.name
  min_elb_capacity     = var.min_size

  lifecycle {
    create_before_destroy = true
  }
}
```

The rollout, as the chapter walks it: v1 running → Terraform creates the v2 ASG → both serve traffic simultaneously while the ALB routes between them → after `min_elb_capacity` v2 servers register, the v1 servers deregister and shut down → only v2 remains. Watchable with a one-liner:

```bash
while true; do curl http://<load_balancer_url>; sleep 1; done
```

And the rollback is free: if the new instances never register, Terraform waits up to `wait_for_capacity_timeout` (default 10 minutes), then deletes the v2 ASG and exits with an error while v1 keeps serving.

## 4. Terraform gotchas

### `count` and `for_each` have limitations

> you cannot reference any resource outputs in `count` or `for_each`.

Hardcoded values, variables, data sources and lists of resources are all fine — anything whose length is known at plan time. A resource attribute is not:

```text
Error: Invalid count argument

The "count" value depends on resource attributes that cannot be determined
until apply, so Terraform cannot predict how many instances will be created.
To work around this, use the -target argument to first apply only the
resources that the count depends on.
```

> Terraform requires that it can compute `count` and `for_each` during the plan phase, before any resources are created or modified.

Still true on both engines. Two notes the chapter cannot give you: `-target` as the suggested workaround is elsewhere described as an antipattern for exceptional recovery only, and the usual fix is to restructure so the count derives from a variable or a `local`. Reference: [[tf-meta-count]], [[tf-meta-for-each]], and the plan-time-known constraint on the [meta-arguments](../../../topics/meta-arguments-lifecycle.md) page.

### Zero-downtime deployment has limitations

The chapter dismantles its own technique, which is the most valuable page in the chapter.

- **It does not work with auto scaling policies.** More precisely, it resets the ASG to `min_size` after each deployment. Deploy at 11 a.m. and the replacement ASG comes up with 2 servers instead of the 10 the 9 a.m. scheduled action had scaled to, and stays there until the next morning.
- **The bigger issue is the shape of the solution.**

    > for important and complicated tasks like a zero-downtime deployment, you really want to use native, first-class solutions, and not workarounds that require you to haphazardly glue together `create_before_destroy`, `min_elb_capacity`, custom scripts, etc.

So the chapter tells you to undo everything it just built — restore `name = var.cluster_name`, delete `create_before_destroy` and `min_elb_capacity` — and use AWS's own mechanism:

```hcl
resource "aws_autoscaling_group" "example" {
  name = var.cluster_name

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
    }
  }
}
```

Now the plan only replaces the launch configuration; AWS performs the rolling replacement asynchronously afterwards. The stated drawback is speed — "up to 20 minutes to replace just two servers" — against which it "is entirely managed by AWS, is reasonably configurable, handles errors pretty well, and requires no workarounds."

The generalisation is the keeper, and it applies far past ASGs:

> In general, you should prefer to use first-class, native deployment options like instance refresh whenever possible.

with `aws_ecs_service`'s `deployment_minimum_healthy_percent` and `kubernetes_deployment`'s `RollingUpdate` strategy named as the equivalents.

!!! danger "The resource under all of this is gone, and its replacement has a trap"
    Every ASG example in this chapter is driven by `aws_launch_configuration`. Accounts created on or after **2024-10-01 cannot create one by any method**, and no instance type released after 2023-01-01 works in one ([[launch-configurations-eol]]). Substitute `aws_launch_template` plus a `launch_template` block.

    That substitution interacts with `instance_refresh` in a way worth knowing before you make it. From the current `aws_autoscaling_group` provider documentation:

    > "A refresh will not start when `version = "$Latest"` is configured in the `launch_template` block. To trigger the instance refresh when a launch template is changed, configure `version` to use the `latest_version` attribute of the `aws_launch_template` resource."

    So the intuitive `version = "$Latest"` silently disables the very mechanism the chapter recommends. Point `version` at `aws_launch_template.example.latest_version` instead, so the ASG's own configuration changes when the template does.

    The chapter's *argument* — prefer the platform's native deployment primitive over a Terraform-shaped workaround — is untouched by any of this.

### Valid plans can fail

`plan` succeeds, `apply` errors, because the name already belongs to something Terraform does not know about:

```text
Error: Error creating IAM User yevgeniy.brikman: EntityAlreadyExists:
User with name yevgeniy.brikman already exists.
```

> The key realization is that `terraform plan` looks **only at resources in its Terraform state file.**

Two lessons, and the first is the stronger claim:

- **After you start using Terraform, you should only use Terraform.** Manual changes both cause weird errors and void the point of IaC, "given that the code will no longer be an accurate representation of your infrastructure."
- **Use `import` for pre-existing infrastructure.** `terraform import <ADDRESS> <ID>`, where the ID is resource-specific (an IAM user's name, an EC2 instance's `i-…`), documented at the bottom of each resource's page.

!!! info "The import advice is the one part of this chapter Terraform has superseded"
    The chapter's closing note is that writing configuration by hand and importing one resource at a time "can be painful", and points at **terraformer** and **terracognita**.

    **Terraform 1.5.0 made import declarative and made config generation a built-in.** From the changelog at tag `v1.5.0` in the local checkout:

    > "Generating configuration for imported resources: in conjunction with the `import` block, this feature enables easy templating of configuration when importing existing resources into Terraform. A new flag `-generate-config-out=PATH` is added to `terraform plan`."

    ```hcl
    import {
      to = aws_iam_user.existing_user
      id = "yevgeniy.brikman"
    }
    ```

    ```bash
    terraform plan -generate-config-out=generated.tf
    ```

    Three advantages over the CLI form: the import is **visible in a plan** before it happens, it is **recorded in code** so a teammate or CI reproduces it, and the configuration is generated for you rather than hand-written. The CLI `terraform import` still works.

### Refactoring can be tricky

The chapter's sharpest warning, because the failure mode is invisible in a general-purpose language:

- **Renaming a value can cause an outage.** Change `cluster_name` from `foo` to `bar` and the ALB's and security groups' `name` parameters change, which for those resources means delete-and-recreate. No ALB means nothing routes traffic; no security group means every packet is rejected.
- **Renaming an identifier can cause an outage.** Rename `aws_security_group.instance` to `aws_security_group.cluster_instance` and *"as far as Terraform knows, you deleted the old resource and have added a completely new one."*

    The same hazard applies to renaming a module, splitting a module in two, or **adding `count` or `for_each` to a resource that did not have it**.

Four lessons:

| Lesson | What it means |
| --- | --- |
| **Always use `plan`** | Every gotcha here is visible in the plan output if you actually read it |
| **Create before destroy** | Either `create_before_destroy`, or two manual applies — add the new resource, then remove the old |
| **Refactoring may require changing state** | Never hand-edit state. Use `terraform state mv`, or a `moved` block |
| **Some parameters are immutable** | Changing them forces replacement; the resource docs say which, so check them |

```bash
terraform state mv aws_security_group.instance aws_security_group.cluster_instance
```

> If you rename an identifier and run this command, you'll know you did it right if the subsequent `terraform plan` shows no changes.

And then the reason to prefer the declarative form, which is about other people rather than about you:

> Having to remember to run CLI commands manually is error prone, especially if you refactored a module used by dozens of teams in your company, and each of those teams needs to remember to run `terraform state mv` to avoid downtime.

```hcl
moved {
  from = aws_security_group.instance
  to   = aws_security_group.cluster_instance
}
```

The plan then reports the move and `Plan: 0 to add, 0 to change, 0 to destroy.`

> 💭 (mine): a 2022 book covering `moved` blocks (Terraform 1.1, December 2021) is a genuine surprise — most material of that vintage stops at `state mv`. It is the clearest sign that this chapter was revised late in the 3rd edition's production.

!!! note "The trio is complete now, and `moved` is only one third of it"
    - **`moved`** (1.1) — the chapter has it. Rename or re-address something you still manage.
    - **`import`** (1.5) — bring an existing object under management, declaratively.
    - **`removed`** (1.7) — **stop managing** an object without destroying it, the declarative replacement for `terraform state rm`.

    All three are configuration rather than CLI invocations, which means all three are reviewable in a plan and reproducible by everyone who runs the code. That is the same argument the chapter makes for `moved` over `state mv`, extended to the other two operations. Reference: [[tf-block-removed]], [[tf-state-refactor]], and TID Ch9 §9.5–§9.6 for the refactoring taxonomy ([[09-testing-refactoring]]).

## Conclusion

The chapter's own summary is that a declarative language plus `count`, `for_each`, `for`, `create_before_destroy` and the function library has "a surprising amount of flexibility and expressive power", with a warning attached — *"let your inner hacker go wild. OK, maybe not too wild, as someone still needs to maintain your code."*

### State of the running example

By the end of Ch 5 the `webserver-cluster` module has gained: an `enable_autoscaling` boolean gating two `aws_autoscaling_schedule` resources via `count`, a `custom_tags` map rendered by a `dynamic "tag"` block that filters out `Name` and uppercases values, `ami` and `server_text` input variables threaded into the launch configuration and the User Data template, and an `instance_refresh` block on the ASG (having tried and then discarded the `create_before_destroy` + `min_elb_capacity` approach). A separate `live/global/iam` configuration holds the IAM-user loop examples.

That module is now doing three unrelated jobs, which is precisely the complaint Chapter 8 opens with when it splits it apart.

---

## Version reckoning

Short, for once. The language material in this chapter needs **no** corrections.

!!! danger "1. `aws_launch_configuration`, and the `$Latest` trap in its replacement"
    Uncreatable in accounts opened on or after 2024-10-01. Moving to `aws_launch_template` is required, and when you do, set the ASG's `launch_template.version` to the template's `latest_version` attribute — `version = "$Latest"` prevents `instance_refresh` from ever starting.

!!! info "2. Declarative import supersedes the chapter's advice"
    `import` blocks plus `terraform plan -generate-config-out=PATH` (both **1.5.0**) replace hand-written configuration and one-at-a-time `terraform import`, and make the operation plan-visible. `removed` blocks (1.7) complete the `moved`/`import`/`removed` trio.

!!! note "3. Smaller items"
    - **`m4.large`** is previous-generation; the hardcoded `ami-0fb653ca2d3203ac1` is region-locked and targets Ubuntu 20.04, whose standard support ended 2025-05-31.
    - **`default_tags` versus `aws_autoscaling_group`** — the chapter's stated exception could not be confirmed against current provider documentation, which does not discuss `default_tags` on that resource at all. Verify before relying on it.
    - **`terraformer` / `terracognita`** still exist, but the built-in generator covers the common case now.
    - **Provider `for_each`** is the loop this chapter does not have: OpenTofu **1.9** can instantiate an aliased provider configuration per element of a map or set, which is how you do "one deployment per region" without duplicating provider blocks. No Terraform equivalent ([[ot-provider-for-each]]).

!!! tip "Why this chapter aged so much better than Ch2 or Ch3"
    Because almost all of it is about **the language**, and the language has been stable since 1.0's compatibility promises. Chapters 2 and 3 teach AWS resources and a locking mechanism, both of which moved underneath them. The parts of Ch5 that did age are exactly the parts that are about AWS.

    It also helps that Brikman argues against his own technique in the zero-downtime section rather than defending it. A chapter that says "here is the workaround, now here is why you should use the platform's native mechanism instead" cannot be made wrong by the platform improving.

    Where TID covers the same ground: Ch4 §4.8–§4.10 is the reference treatment of `count`/`for_each`/`dynamic` and the plan-time-known constraint ([[04-expressions-iterations]]), and Ch6 §6.5 plus Ch9 §9.5–§9.6 handle the refactoring half ([[06-state-management]], [[09-testing-refactoring]]).

---

*Related notes:* [Meta-arguments and `lifecycle`](../../../topics/meta-arguments-lifecycle.md) · TUR Ch4 [Modules](04-reusable-modules.md), Ch3 [State](03-manage-state.md), Ch8 [Production-grade](08-production-grade.md) · TID Ch4 [[04-expressions-iterations]] · [[tf-meta-count]], [[tf-meta-for-each]], [[tf-expr-for]], [[tf-expr-splat]], [[tf-expr-dynamic-blocks]], [[tf-expr-strings]] for the reference pages · [[tf-block-removed]] and [[tf-state-refactor]] for the refactoring trio · [[tut-count]] and [[tut-for-each]] for the hands-on. Feeds learning-path **I1** (meta-arguments), **I2** (`lifecycle`), **I3** (dynamic blocks), **B7** (expressions) and **I7** (state operations).
