# Local Values (Use locals)

> **Source:** [developer.hashicorp.com/terraform/language/values/locals](https://developer.hashicorp.com/terraform/language/values/locals)
> **Added:** 2026-07-13
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-13
> **Tags:** locals, expressions, dry, naming, module-scope
> **Type:** documentation

The third of B6's value-block trio, alongside [[tf-input-variables]] (inputs) and outputs. A local value assigns a **name to an expression** so you can reuse it within a module instead of repeating the expression — like a function-scoped variable.

## Define locals

Add a `locals` block (any module, any valid Terraform expression). A local can reference:

- variables
- resource attributes
- function outputs
- other local values

```hcl
locals {
  # Naming convention
  resource_name = "${var.project_name}-${var.environment}"

  # Process the subnet list
  primary_public_subnet = var.subnet_ids[0]
  subnet_count          = length(var.subnet_ids)

  # Environmental deployment settings
  is_production      = var.environment == "prod"
  monitoring_enabled = var.monitoring || local.is_production
}
```

## Reference local variables

Define with the **plural** `locals` block; reference with the **singular** `local.<NAME>`:

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = local.primary_public_subnet
  monitoring    = local.monitoring_enabled

  tags = {
    Name        = local.resource_name
    Environment = var.environment
  }
}

resource "aws_security_group" "web" {
  name = "${local.resource_name}-sg"

  tags = {
    Name = "${local.resource_name}-security-group"
  }
}
```

**Scope:** a local is accessible only in the module where it's defined — **not** in other modules. To share it, pass it to a child module as an argument.

## Tradeoff

Locals cut repetition and give a meaningful name to an expression, but they can make a config **harder to read by obscuring where a value originates**. Use them when you either reuse one value in many places (change it in a single spot) or the value is the result of a complex expression — not for every intermediate.

---
Related: completes B6's value trio with [[tf-input-variables]] (inputs) and outputs. `local.` references appear across the config examples; contrast with `var.` (inputs) — locals are computed inside the module, variables are passed in.
