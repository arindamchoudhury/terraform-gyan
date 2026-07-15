# `for` Expressions

> **Source:** [developer.hashicorp.com/terraform/language/expressions/for](https://developer.hashicorp.com/terraform/language/expressions/for)
> **Added:** 2026-07-15
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-15
> **Tags:** for-expressions, transform, filtering, grouping, element-ordering, type-conversion
> **Type:** documentation

A `for` expression builds a complex-type value by transforming another complex-type value. Each input element maps to one or zero output elements, transformed by an arbitrary expression.

Example — uppercase every string in a list, producing a tuple:

```hcl
[for s in var.list : upper(s)]
```

It iterates each element of `var.list`, evaluates `upper(s)` with `s` bound to each element, and builds a new tuple in the same order.

## Input types

Input (after `in`) can be a list, set, tuple, map, or object.

Optionally declare **two** temporary symbols to also get the key or index:

```hcl
[for k, v in var.map : length(k) + length(v)]
```

- Map/object — the first symbol `k` is the key / attribute name.
- List/tuple — the first symbol is the index from zero (conventionally `i` or `idx`).

```hcl
[for i, v in var.list : "${i} is ${v}"]
```

The key/index symbol is always optional. With a single symbol, it represents the element value.

## Result types

The **bracket type** decides the result type:

- `[ ]` → tuple.
- `{ }` → object; requires **two** result expressions separated by `=>`.

```hcl
{for s in var.list : s => upper(s)}
```

Produces an object mapping each original element to its uppercase version, e.g. `{ foo = "FOO", bar = "BAR", baz = "BAZ" }`.

A `for` expression alone produces only an object or a tuple, but automatic type conversion lets you use the results where lists, maps, and sets are expected.

## Filtering elements

Optional `if` clause filters elements, yielding fewer than the source:

```hcl
[for s in var.list : upper(s) if s != ""]
```

Common use — split one collection into two by criteria. Given `var.users` a map of objects with an `is_admin` attribute:

```hcl
variable "users" {
  type = map(object({
    is_admin = bool
  }))
}

locals {
  admin_users = {
    for name, user in var.users : name => user
    if user.is_admin
  }
  regular_users = {
    for name, user in var.users : name => user
    if !user.is_admin
  }
}
```

## Element ordering

Converting from unordered types (maps, objects, sets) to ordered types (lists, tuples) forces Terraform to pick an implied order:

- Maps / objects — sorted by key/attribute name, lexically.
- Sets of strings — sorted by value, lexically.
- Sets of other types — **arbitrary order that may change in future versions.** Recommendation: convert the result back to a set to signal it's unordered. Use `toset`:

```hcl
toset([for e in var.set : e.example])
```

## Grouping results

For an object result (`{ }`), the key expression must normally be **unique** across all elements, or Terraform errors.

When keys aren't unique, activate **grouping mode** by adding `...` after the value expression. The result becomes a map of lists — multiple elements per key.

```hcl
variable "users" {
  type = map(object({
    role = string
  }))
}

locals {
  users_by_role = {
    for name, user in var.users : user.role => name...
  }
}
```

Here the input maps unique usernames → role; the expression inverts it to role → list of usernames. Result is a map of lists:

```
{
  "admin":      ["ps"],
  "maintainer": ["am", "jb", "kl", "ma"],
  "viewer":     ["st", "zq"],
}
```

Element-ordering rules still apply — usernames within each role are lexically sorted.

## Repeated configuration blocks

`for` expressions build collection **values** you assign to resource arguments expecting complex values. They **cannot** dynamically generate nested **blocks**. For that, use `dynamic` blocks instead.

---
Related: [[tf-expressions]] — `for` is one expression kind under the Expressions overview. [[tf-expr-types]] — result types and the automatic conversions that make tuples/objects usable as lists/maps/sets. [[tf-expr-function-calls]] — `...` also means argument expansion in calls; here it means grouping mode.
