# `locals` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/locals](https://developer.hashicorp.com/terraform/language/block/locals)
> **Added:** 2026-07-13
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-13
> **Tags:** locals, locals-block, expressions, identifiers, module-scope
> **Type:** documentation

The argument-level spec behind [[tf-locals]] (the how-to). Adds a few things the how-to leaves out: the **multiple-blocks** rule, the "at least one value" requirement, and the identifier constraint.

## Configuration model

A `locals` block assigns names to expressions — `<LOCAL_NAME> = <EXPRESSION>`, any number per block:

```hcl
locals {
  <LOCAL_NAME>       = <EXPRESSION>
  <OTHER_LOCAL_NAME> = <OTHER_EXPRESSION>
}
```

## Specification

- **Names must be valid identifiers.**
- A value can be **any valid Terraform expression**, referencing variables, resources, data sources, function outputs, or other locals.
- **You may declare multiple `locals` blocks in one module — Terraform treats them as if they were all one block.** Split them only to organize related values into visually distinct groups.
- Each `locals` block **must assign at least one value**.
- Reference values as attributes on the singular `local` object (`local.<name>`); accessible only in the defining module, not others.

## Examples

**Basic** — service metadata reused as tags:

```hcl
locals {
  service_name = "forum"
  owner        = "community-team"
  environment  = "production"
}

resource "aws_instance" "web" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"

  tags = {
    Name        = local.service_name
    Owner       = local.owner
    Environment = local.environment
  }
}
```

**Combine and transform** — a splat/`concat` list and a `common_tags` map that references other locals + variables:

```hcl
locals {
  instance_ids = concat(aws_instance.blue[*].id, aws_instance.green[*].id)

  common_tags = {
    Service     = local.service_name
    Owner       = local.owner
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

**Multiple blocks** — organize network / app / computed values separately (still one logical block to Terraform):

```hcl
locals {
  # Network configuration
  vpc_cidr = "10.0.0.0/16"
  az_count = length(data.aws_availability_zones.available.names)
}

locals {
  # Application configuration
  app_name = "${var.project_name}-${var.environment}"
  app_port = 8080
}

locals {
  # Computed values
  subnet_cidrs = [
    for i in range(local.az_count) :
    cidrsubnet(local.vpc_cidr, 8, i)
  ]
}
```

---
Related: reference spec for [[tf-locals]] (that page is the how-to; this is the block reference — same pairing HCDocs uses under the *Locals* sidebar group). Confirms the glossary's "multiple blocks, merged" note.
