# Type Constraints

> **Source:** [developer.hashicorp.com/terraform/language/expressions/type-constraints](https://developer.hashicorp.com/terraform/language/expressions/type-constraints)
> **Added:** 2026-07-15
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-15
> **Tags:** type-constraints, primitive-types, collection-types, structural-types, any, optional-attributes, type-conversion
> **Type:** documentation

Module authors and provider developers use detailed type constraints to validate user values for input variables and resource arguments. More resilient module UI, at the cost of some type-system knowledge.

## Type keywords and constructors

- **Type keywords** — unquoted symbols for a static type (`string`, `bool`).
- **Type constructors** — unquoted symbols followed by parentheses carrying an argument (`list(string)`). Without the argument a constructor represents a *kind* of similar types, not one type.

Type constraints look like expressions but are special syntax. Valid only in the `type` argument of an input variable, a module output, or a `convert` function call.

## Primitive types

Simple types, not built from others, each a keyword:

- `string` — Unicode text, e.g. `"hello"`.
- `number` — whole (`15`) or fractional (`6.283185`).
- `bool` — `true` / `false`.

**Conversion of primitives:** Terraform auto-converts number/bool ↔ string when needed, as long as the string is a valid representation. `true` ↔ `"true"`, `15` ↔ `"15"`.

## Complex types

Group multiple values into one. Represented by type constructors (several have shorthand keywords). Two categories: **collection** (similar values) and **structural** (dissimilar values).

### Collection types

One element type, given as the constructor argument. All elements must be the same type. `list(string)` ≠ `list(number)`.

- **`list(...)`** — sequence indexed by consecutive whole numbers from zero. Bare `list` = `list(any)` (compat shorthand; prefer the full form).
- **`map(...)`** — values identified by string labels. Bare `map` = `map(any)`. Define with `{}`, `:`, `=`. `{ "foo": "bar" }` and `{ foo = "bar" }` are the same map. Quote keys that start with a number, contain spaces, or have special characters. Commas required between pairs on a single line; multi-line pairs go on new lines.

  !!! note "`terraform fmt` and map delimiters"
      Colons are valid key/value delimiters but `terraform fmt` ignores them. It does vertically align equals signs.

- **`set(...)`** — collection of unique values, no secondary identifiers, no ordering.

### Structural types

Require a **schema** argument specifying which types are allowed for which elements.

- **`object(...)`** — named attributes each with their own type. Schema: `{ <KEY> = <TYPE>, ... }`. A matching value must contain **all** specified keys, each matching its type. Values with **extra** keys still match, but the extra attributes are **discarded** during type conversion.
- **`tuple(...)`** — sequence indexed from zero, each element its own type. Schema: `[<TYPE>, <TYPE>, ...]`. A matching value must have **exactly** that many elements, each matching the type at its position.

Examples — `object({ name=string, age=number })` matches `{ name = "John", age = 52 }`. `object({ id=string, cidr_block=string })` matches an `aws_vpc.example_vpc` reference (extra attributes discarded). `tuple([string, number, bool])` matches `["a", 15, true]`.

### Complex type literals

The language has literals for tuple and object values ("list/tuple" literals and "map/object" literals). It has **no** way to directly represent lists, maps, or sets. Thanks to automatic conversion, the difference between similar complex types rarely matters — most docs conflate lists with tuples and maps with objects. The distinctions only matter when restricting module/resource inputs.

## Conversion of complex types

Similar kinds (list/tuple/set, map/object) are usually interchangeable, via two behaviors:

**Convert between similar kinds** when the provided value isn't the exact type:

- Objects and maps are similar. A map (or larger object) converts to an object if it has at least the required keys; extra attributes are discarded, so **map → object → map can be lossy**.
- Tuples and lists are similar. A list converts to a tuple only if it has exactly the required element count.
- Sets are almost similar to both. List/tuple → set discards duplicates and loses ordering. Set → list/tuple gives arbitrary order (lexicographical for strings; no guaranteed order for other element types).

**Convert element values** recursively, or via the primitive rules.

Example — an argument of `list(string)` given `["a", 15, true]` becomes `["a", "15", "true"]`. If the module later feeds those to arguments wanting string/number/bool, Terraform converts the 2nd and 3rd back at that point (they're valid representations).

Conversion **fails** when incompatible: `map(string)` given `{name = ["Kristy", ...], age = 12}` raises a type-mismatch — a tuple can't convert to a string.

## Dynamic types: the `any` constraint

!!! warning "`any` is rarely correct"
    Don't use `any` just to skip specifying a type. Always write an exact constraint unless truly handling dynamic data.

`any` is a placeholder for a type yet to be decided — not itself a type. Terraform tries to find a single actual type to replace `any` and produce a valid result.

Only appropriate when you pass the value straight to another system without accessing its contents — e.g. a `type = any` variable used only through `jsonencode`:

```hcl
variable "settings" {
  type = any
}

resource "aws_s3_object" "example" {
  # This is a reasonable use of "any": the module just writes
  # the given data to S3 as JSON without inspecting it further.
  content = jsonencode(var.settings)
}
```

If any part of the module accesses elements/attributes, or expects a string/number/etc., `any` is wrong — write the exact type.

### `any` with collection types

All collection elements must share a type, so `list(any)` makes Terraform find one exact element type.

- `["a", "b", "c"]` (physically `tuple([string, string, string])`) → tuple-to-list applies, all elements are strings, so `any` = `string` → `list(string)`.
- `["a", 1, "b"]` → still `list(string)` via primitive conversion; value becomes `["a", "1", "b"]`.
- `["a", [], "b"]` → **rejected**: no single type both a string and an empty tuple can convert to.

Same principle for `map(any)` and `set(any)`.

## Optional object type attributes

Normally a missing object attribute is an error. Marking it `optional` makes Terraform insert a default instead, letting the receiving module define fallback behavior.

```hcl
variable "with_optional_attribute" {
  type = object({
    a = string                # a required attribute
    b = optional(string)      # an optional attribute
    c = optional(number, 127) # an optional attribute with default value
  })
}
```

The `optional` modifier takes one or two arguments:

- **Type** (required) — the attribute's type.
- **Default** (optional) — value used when the attribute is absent. Must be compatible with the type. If omitted, the default is a `null` of the appropriate type.

An optional attribute with a **non-null** default is guaranteed never `null` in the receiving module — Terraform substitutes the default both when the caller omits the attribute **and** when the caller explicitly passes `null`. No extra null checks needed.

Defaults apply **top-down** in nested types: the `optional` default is applied first, then nested defaults are applied to it.

### Example: nested structures with optional attributes and defaults

```hcl
variable "buckets" {
  type = list(object({
    name    = string
    enabled = optional(bool, true)
    website = optional(object({
      index_document = optional(string, "index.html")
      error_document = optional(string, "error.html")
      routing_rules  = optional(string)
    }), {})
  }))
}
```

A `terraform.tfvars` with three buckets — `production` (sets routing rules), `archived` (default config but disabled, omits `website` entirely), `docs` (overrides index/error documents):

```hcl
buckets = [
  {
    name = "production"
    website = {
      routing_rules = <<-EOT
      [
        {
          "Condition" = { "KeyPrefixEquals": "img/" },
          "Redirect"  = { "ReplaceKeyPrefixWith": "images/" }
        }
      ]
      EOT
    }
  },
  {
    name = "archived"
    enabled = false
  },
  {
    name = "docs"
    website = {
      index_document = "index.txt"
      error_document = "error.txt"
    }
  },
]
```

Results:

- `production` and `docs` get `enabled = true`; `website` defaults are supplied, then `docs`'s explicit values override them.
- `archived` and `docs` get `routing_rules = null` (optional, no default supplied → `null`).
- `archived` gets its whole `website` populated from the type-constraint defaults.

### Example: conditionally setting an optional attribute

To decide dynamically whether to set an optional argument, use a conditional expression with `null` as one arm to leave it unset:

```hcl
variable "legacy_filenames" {
  type     = bool
  default  = false
  nullable = false
}

module "buckets" {
  source = "./modules/buckets"

  buckets = [
    {
      name = "maybe_legacy"
      website = {
        error_document = var.legacy_filenames ? "ERROR.HTM" : null
        index_document = var.legacy_filenames ? "INDEX.HTM" : null
      }
    },
  ]
}
```

With `var.legacy_filenames = true`, the call overrides the filenames. When `false`, it leaves them unspecified so the module's defaults apply.

---
Related: [[tf-expr-types]] — the value-side view of the same type system (types & values, `null`); this page is the constraint-side used in `type = ...`. [[tf-expr-dynamic-blocks]] — typed object/list inputs are what `dynamic` blocks iterate. [[tf-conditionals]] — `cond ? x : null` is the idiom for conditionally-unset optional attributes.
