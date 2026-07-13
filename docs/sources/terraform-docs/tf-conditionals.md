# Conditional Expressions

> **Source:** [developer.hashicorp.com/terraform/language/expressions/conditionals](https://developer.hashicorp.com/terraform/language/expressions/conditionals)
> **Added:** 2026-07-13
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-13
> **Tags:** conditionals, ternary, expressions, can, self, precondition, postcondition, alltrue
> **Type:** documentation

The ternary operator, plus a catalogue of the expression idioms used to *build* the boolean conditions that feed variable `validation` and `precondition`/`postcondition` blocks (learning-path B7, and A2 for the condition side).

## Syntax

```hcl
condition ? true_val : false_val
```

`condition` true → `true_val`; false → `false_val`. Common idiom — supply a default for an invalid value:

```hcl
var.a == "" ? "default-a" : var.a
```

The `condition` can be any expression resolving to a bool — usually equality, comparison, or logical operators.

## Result types must match

Both result values may be any type **but must be the same type**, so Terraform can determine the expression's return type *without* knowing the condition. If they differ, Terraform tries to find a common type and **auto-converts**:

```hcl
var.example ? 12 : "hello"   # always a string — numbers convert to decimal strings
```

Auto-conversion confuses readers unfamiliar with the rules — **be explicit with type-conversion functions** when the result type is uncertain:

```hcl
var.example ? tostring(12) : "hello"
```

## Idioms for building conditions

The page doubles as a cookbook for condition expressions (validation / pre-postcondition):

**Logical / comparison operators** — `&&` (AND), `||` (OR), `!` (NOT):

```hcl
condition = var.name != "" && lower(var.name) == var.name
```

**`contains`** — value is one of an allowed set:

```hcl
condition = contains(["STAGE", "PROD"], var.environment)
```

**`length`** — require a non-empty collection. Prefer `length(...) != 0` over `== []` / `!= []`, which is ambiguous for empty collections of the same type:

```hcl
condition = length(var.items) != 0
```

**`for` + `alltrue` / `anytrue`** — assert a condition over all / any elements:

```hcl
condition = alltrue([
  for v in var.instances : contains(["t2.micro", "m3.medium"], v.type)
])
```

**`can`** — turn "does this expression succeed?" into a bool. Returns `true` if the expression evaluates without error, `false` on any error — lets you wrap functions that normally *error* (rather than return false):

```hcl
condition = can(regex("^[a-z]+$", var.name))                 # matches a pattern
condition = can(tostring(data.terraform_remote_state.example.outputs["name"]))  # convertible to string
condition = can(tolist(data.terraform_remote_state.example.outputs["items"]))   # convertible to list
condition = can(var.example.foo)                              # has attribute "foo"
condition = can(var.example[0])                               # has index 0 (clearer as length(...) > 0)
```

## Special objects in conditions

**`self`** — inside a **`postcondition`**, refers to attributes of the instance under evaluation:

```hcl
resource "aws_instance" "example" {
  instance_type = "t2.micro"
  ami           = "ami-abc123"

  lifecycle {
    postcondition {
      condition     = self.instance_state == "running"
      error_message = "EC2 instance must be running."
    }
  }
}
```

**`each` / `count`** — in `for_each`/`count` blocks, reference other resources expanded in a chain (here a `precondition` checks the matching VPC is available):

```hcl
resource "aws_internet_gateway" "example" {
  for_each = data.aws_vpc.example
  vpc_id   = each.value.id

  lifecycle {
    precondition {
      condition     = data.aws_vpc.example[each.key].state == "available"
      error_message = "VPC ${each.key} must be available."
    }
  }
}
```

## Custom condition checks

Conditions can produce **custom error messages** for several object types (e.g. a `variable` checking an image-ID format). They capture assumptions — documenting design intent for maintainers and returning errors earlier and in context for consumers. (See "Validate your configuration".)

---
Related: the boolean-building idioms here feed the `validation` block in [[tf-block-variable]] and the `precondition` block in [[tf-block-output]] / resource `postcondition`. Feeds learning-path **B7** (ternary, `can`, operators) and **A2** (custom conditions, `self` in postcondition, pre/postcondition).
