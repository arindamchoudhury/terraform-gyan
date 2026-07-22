# Query infrastructure data (data sources)

> **Source:** [developer.hashicorp.com/terraform/language/data-sources](https://developer.hashicorp.com/terraform/language/data-sources)
> **Added:** 2026-07-22
> **Source updated:** undated language reference; captured 2026-07-22 against v1.15.x (latest)
> **Tags:** data-sources, data-block, plan-vs-apply, dependencies, custom-conditions, meta-arguments
> **Type:** documentation

*Developer › Terraform › Configuration Language › Data sources › Query infrastructure data · v1.15.x*

The overview page for the **Data sources** section. A data source **reads** infrastructure data — from a provider API, another workspace, or a function output — without creating or modifying anything. It's the counterpart to a `resource` (create/manage); see [[tf-resources]] for that side. This page is the concept + workflow; the argument-level detail lives on the *data block reference* (`block/data`, not yet captured).

## Introduction

Most providers ship data sources alongside their resources. A `data` block queries the provider and exports the result as an object you reference elsewhere. Arguments are provider-specific — check the provider docs.

The `data` block supports expressions and dynamic language features, plus a subset of Terraform's built-in **meta-arguments** (see [[tf-meta-arguments]]). Terraform can **only read** a data source — no create/update/delete.

## Data source behavior — when is the data read?

The key concept on the page: **plan phase vs apply phase.**

Terraform tries to read data sources during **planning**, but defers the read to **apply** when at least one argument depends on a value it can't predict at plan time. That happens when:

- The `data` block depends on a Terraform-managed resource that's changing in the current plan.
- Its custom conditions depend (directly or indirectly) on a resource changing in the current plan.
- An argument refers to a value that must be computed during apply.

When the read is deferred, the plan output flags it, and any resources referencing the fetched values also can't be finalized until apply.

**References to computed values** — if any argument is a computed value, Terraform waits until *all* arguments are known, defers the refresh to apply, and shows the interpolated attributes as `(known after apply)` in the plan.

**References to non-computed values** — if all arguments are already knowable, Terraform reads the data source during the **refresh** phase (which runs before planning by default). This puts real values in the plan diff.

## Specialized (local-only) data sources

Some data sources generate data that only exists during the operation, recalculated on every plan. Examples:

- `template_file` — renders a template from a file (HashiCorp `template` provider).
- `local_file` — reads a local file (HashiCorp `local` provider). See [[tf-terraform-data]]-adjacent escape-hatch notes; `local_file` is B9's write-side counterpart.
- `iam_policy_document` — renders AWS IAM policy JSON (`aws` provider).

## Requirements

Use Terraform **0.13+** to put `depends_on` on a `data` block. On 0.12 and earlier, `depends_on` on a data block forces the read to apply, which can cause unintended behavior.

## Declaring and using a data source

Type + label; reference with `data.<TYPE>.<LABEL>.<ATTRIBUTE>`. The `type` + `name` combination must be unique.

```hcl
data "aws_ami" "example" {
  # ...
}
```

Referenced as e.g. `data.aws_ami.example.id`.

**Query constraints** go in the block body (provider-specific args). Example — most recent AMI owned by the caller, filtered by tags:

```hcl
data "aws_ami" "example" {
  most_recent = true
  owners      = ["self"]
  tags = {
    Name   = "app-server"
    Tested = "true"
  }
}
```

## Dependencies

Terraform detects dependencies automatically, even indirect ones through a local value. To force ordering, add `depends_on` to the `data` block — it defers the query until after the named dependency's operations finish. See [[tf-meta-depends-on]].

## Custom condition checks

`precondition` / `postcondition` blocks inside `lifecycle` assert assumptions/guarantees. The postcondition below asserts the AMI is tagged `nomad-server`:

```hcl
data "aws_ami" "example" {
  id = var.aws_ami_id

  lifecycle {
    postcondition {
      condition     = self.tags["Component"] == "nomad-server"
      error_message = "tags[\"Component\"] must be \"nomad-server\"."
    }
  }
}
```

Conditions surface errors earlier and in context, and document intent.

## Multiple instances

`count` and `for_each` work on `data` blocks. Terraform reads and indexes each instance separately: `data.<NAME>[<KEY>]`. For `count`, `<KEY>` is a number; for `for_each`, it's the collection key — e.g. `data.azurerm_resource_group.rg["a_group"]`.

> ❓ Note: the page says the `count` key starts "at 1" — that contradicts Terraform's usual 0-based `count.index`. Treat as a likely doc typo; verify before relying on it.

## Alternate provider configurations

Point a data block at an aliased provider with the `provider` meta-argument (see [[tf-provider-block]]):

```hcl
provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "uswest1"
  region = "us-west-1"
}

data "aws_ami" "web" {
  provider = aws.uswest1
  # ...
}
```

## Complete example

Query the latest available AMI tagged `Component = web`, then feed its ID to a resource:

```hcl
data "aws_ami" "web" {
  filter {
    name   = "state"
    values = ["available"]
  }
  filter {
    name   = "tag:Component"
    values = ["web"]
  }
  most_recent = true
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.web.id
  instance_type = "t1.micro"
}
```

The `filter` blocks and `most_recent` are `aws_ami`-specific — provider docs are the source of truth for arguments.

---
Related: [[tf-resources]] — data sources are the read-only counterpart to resources. [[tf-remote-state-data]] — a specific data source (`terraform_remote_state`) that reads another config's outputs. [[tf-meta-depends-on]] — `depends_on` on a data block and its plan/apply timing cost. [[tf-provider-block]] — aliased providers referenced via the `provider` meta-argument.
