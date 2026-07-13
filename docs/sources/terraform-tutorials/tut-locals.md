# Simplify Terraform configuration with locals

> **Source:** [developer.hashicorp.com/terraform/tutorials/configuration-language/locals](https://developer.hashicorp.com/terraform/tutorials/configuration-language/locals)
> **Added:** 2026-07-13
> **Source updated:** undated tutorial (~10 min); captured 2026-07-13
> **Tags:** locals, merge, dynamic-expressions, resource-tags, dry, interpolation
> **Type:** documentation

Third **Configuration Language** tutorial, after [[tut-variables]]. Hands-on for [[tf-locals]] / [[tf-block-locals]] on the same VPC + load balancer + EC2 stack. Two moves: use a local to kill duplicated name-building, then combine a local with `merge()` to **enforce a minimum tag set while still letting users add their own**. Uses `git clone https://github.com/hashicorp-education/learn-terraform-locals`; needs Terraform 1.1+ and AWS credentials.

> A local names the result of any expression so you can reuse it — cutting duplication and giving values readable names. Like variables, locals don't change during/between runs. **Unlike input variables, locals aren't set by users** — and, the key contrast here, **locals *can* use dynamic expressions and resource arguments, where a variable's value must be literal.**

## Use a local to name resources

Resource names in `main.tf` all interpolate the same project + environment suffix. Extract it once:

```hcl
locals {
  name_suffix = "${var.resource_tags["project"]}-${var.resource_tags["environment"]}"
}
```

Then reference `local.name_suffix` everywhere:

```hcl
module "vpc"               { name = "vpc-${local.name_suffix}" }
module "app_security_group" { name = "web-sg-${local.name_suffix}" }
module "lb_security_group"  { name = "lb-sg-${local.name_suffix}" }
module "elb_http"           { name = "lb-${random_string.lb_id.result}-${local.name_suffix}" }
```

(The LB name keeps a `random_string` prefix — AWS requires unique LB names.) Block order doesn't matter, but put locals near the top for readability. Re-`apply` → no changes (values identical).

## Combine variables with locals — enforce minimum tags

The goal: guarantee every resource carries `project` + `environment` tags, even if a user overrides `resource_tags`. The pattern uses `merge()`:

Add plain variables and empty out the tag map default:

```hcl
variable "project_name" { type = string, default = "my-project" }
variable "environment"  { type = string, default = "dev" }

variable "resource_tags" {
  description = "Tags to set for all resources"
  type        = map(string)
  default     = {}        # was a populated map; now empty
}
```

Build a merged `tags` local — **required tags win because they're the second argument to `merge()`**:

```hcl
locals {
  required_tags = {
    project     = var.project_name
    environment = var.environment
  }
  tags = merge(var.resource_tags, local.required_tags)

  name_suffix = "${var.project_name}-${var.environment}"
}
```

`merge(a, b)` combines maps; later arguments override earlier keys — so a user's `resource_tags` can *add* tags but cannot drop or override `project`/`environment`. Point every resource at `tags = local.tags` (five occurrences), and expose the result:

```hcl
output "tags" {
  value = local.tags
}
```

Apply → `tags = { "environment" = "dev", "project" = "my-project" }`, no infra change.

!!! note "Tags are for teaching here — real AWS uses provider `default_tags`"
    The tutorial builds tag-merging by hand for educational value. In practice, set global tags via the **AWS provider's `default_tags`** rather than threading `local.tags` through every resource.

## Locals feed resource names → changing one recreates resources

Because `name_suffix` and `tags` drive resource **names**, changing an input that feeds them forces replacements:

```shell
$ terraform apply -var "environment=prod"
...
Plan: 17 to add, 15 to change, 17 to destroy.
  ~ tags = { ~ environment = "dev" -> "prod" }
```

`environment` flows into names via the local, so flipping `dev`→`prod` renames resources and Terraform recreates the ones whose name is forced-new. `terraform destroy` removes all 42 at the end.

## Single vs multiple `locals` blocks

All locals can live in one `locals` block or be split across several — Terraform merges them (see [[tf-block-locals]]).

---
Related: hands-on for [[tf-locals]] / [[tf-block-locals]] (the reference pair). Reinforces [[tf-input-variables]]'s "a variable default must be literal" by contrast — locals *can* be dynamic. Continues the Configuration Language collection from [[tut-variables]]. Feeds learning-path **B6** (locals for DRY, the `merge()` required-tags pattern) and touches **B7** (`merge`, interpolation).
