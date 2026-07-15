# Types and Values

> **Source:** [developer.hashicorp.com/terraform/language/expressions/types](https://developer.hashicorp.com/terraform/language/expressions/types)
> **Added:** 2026-07-14
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-14
> **Tags:** types, values, primitives, collections, null, literals, type-conversion
> **Type:** documentation

Every expression result is a value; every value has a type. The type dictates where the value can be used and what transformations apply.

## Types

**Primitive types:**

- `string` — sequence of Unicode characters, like `"hello"`.
- `number` — whole (`15`) or fractional (`6.283185`).
- `bool` — `true` / `false`; usable in conditional logic.

**Complex types** (also called structural / collection types):

- `list` (or `tuple`) — ordered sequence, `["us-west-1a", "us-west-1c"]`. Elements identified by consecutive whole numbers from zero.
- `set` — collection of unique values, no secondary identifiers, no ordering.
- `map` (or `object`) — values identified by named labels, `{name = "Mabel", age = 52}`.

**The typeless value:**

- `null` — represents absence or omission. Setting a resource argument to `null` makes Terraform behave as if the argument were omitted entirely: it uses the argument's default if any, or errors if the argument is mandatory. Most useful in conditional expressions, to dynamically omit an argument when a condition isn't met.

See [[tf-expr-type-constraints]] for the detailed treatment of complex types.

## Literal Expressions

A literal expression directly represents a constant value. There is a literal syntax per type.

- **Strings** — double-quoted Unicode, `"like this"`; also a heredoc syntax. String literals are the most complex literal; escape sequences, heredoc, interpolation, and template directives are on the [[tf-expr-strings]] page.
- **Numbers** — unquoted digit sequences with or without a decimal point: `15`, `6.283185`.
- **Bools** — unquoted `true` / `false`.
- **Null** — unquoted `null`.

**Lists/Tuples** — square brackets, comma-separated: `["a", 15, true]`. Can span multiple lines for readability but always need a comma between values. A trailing comma after the final value is allowed, not required. Values can be arbitrary expressions. Tuples and lists differ in the types they allow — see [[tf-expr-type-constraints]].

**Sets** — no direct index access (sets are unordered). To access by index, convert to a list first:

```hcl
variable "example_set" {
  type    = set(string)
  default = ["foo", "bar"]
}

locals {
  example_list = tolist(var.example_set)
}

output "first_element" {
  value = local.example_list[0]
}

output "second_element" {
  value = local.example_list[1]
}
```

**Maps/Objects** — curly braces with `<KEY> = <VALUE>` pairs:

```hcl
{
  name = "John"
  age  = 52
}
```

Pairs separated by comma or line break. Values can be arbitrary expressions. Keys must be strings — unquoted if a valid identifier, quoted otherwise. Use a non-literal string expression as a key by wrapping in parens: `(var.business_unit_tag_name) = "SRE"`.

## Indices and Attributes

Access list/tuple and map/object elements with square-bracket index notation: `local.list[3]`. The bracket expression must be a whole number (list/tuple) or a string (map/object).

Map/object attributes with valid-identifier names can also use dot notation: `local.object.attrname`. When a map may contain arbitrary user-specified keys, prefer square-bracket notation: `local.map["keyname"]`.

## More About Complex Types

In most situations lists and tuples behave identically, as do maps and objects. When the distinction is irrelevant, the docs use the terms interchangeably (historical preference: "list" and "map").

Module authors and provider developers should understand the differences (and the related `set` type) — they offer different ways to restrict allowed values for input variables and resource arguments. Full details in [[tf-expr-type-constraints]].

## Type Conversion

Arguments have an expected type; the expression must produce that type. Where possible Terraform auto-converts; otherwise it raises a type mismatch error and the config must be updated. **Auto-conversion does not occur with the equality operator.**

Terraform converts `number` and `bool` to `string` when needed, and `string` → number/bool when the string holds a valid representation:

- `true` ↔ `"true"`
- `false` ↔ `"false"`
- `15` ↔ `"15"`

---
Related: parent [[tf-expressions]]. `null`-in-conditionals and auto-conversion detail confirmed in [[tf-conditionals]] (result-type matching). Complex-type restriction syntax lives in [[tf-expr-type-constraints]]; string literal detail in [[tf-expr-strings]].
