# Arithmetic and Logical Operators

> **Source:** [developer.hashicorp.com/terraform/language/expressions/operators](https://developer.hashicorp.com/terraform/language/expressions/operators)
> **Added:** 2026-07-15
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-15
> **Tags:** operators, arithmetic, equality, comparison, logical, order-of-operations, type-conversion
> **Type:** documentation

An operator is an expression that transforms or combines other expressions. Binary operators combine two values into a third; unary operators transform a single value into one result.

Binary operators place the symbol between the two values (`1 + 2`). Unary operators place the symbol before the value (`!true`). The operator set is similar to JavaScript or Ruby.

Each operator group expects its values to be of a particular type. Terraform auto-converts when possible, or errors when conversion is impossible.

## Order of operations

When multiple operators appear together, they evaluate highest-to-lowest in this order:

1. `!`, `-` (multiplication by -1)
2. `*`, `/`, `%`
3. `+`, `-` (subtraction)
4. `>`, `>=`, `<`, `<=`
5. `==`, `!=`
6. `&&`
7. `||`

Higher levels evaluate first: `1 + 2 * 3` is read as `1 + (2 * 3)`, not `(1 + 2) * 3`. Use parentheses to override.

`?` combined with `:` is part of a conditional expression, not an operator — see [[tf-conditionals]].

## Arithmetic operators

Expect number values, produce number values:

- `a + b` — addition.
- `a - b` — subtracts `b` from `a`.
- `a * b` — multiplication.
- `a / b` — divides `a` by `b`.
- `a % b` — remainder of `a / b`. Generally useful only with whole numbers.
- `-a` — multiplies `a` by -1.

Less-common numeric operations exist as functions instead — e.g. exponents via the `pow` function.

## Equality operators

Take two values of **any** type, produce bool:

- `a == b` — `true` if `a` and `b` have the same type **and** the same value.
- `a != b` — opposite of `==`.

Both arguments must be **exactly the same type** to be equal. Recommendation: use equality only with primitive types, or apply explicit type-conversion functions to make the intended comparison type clear.

Structural-type comparisons can surprise. `var.list == []` looks like it tests for an empty list, but `[]` builds a `tuple([])`, so the two types never match. Write `length(var.list) == 0` instead.

## Comparison operators

Expect number values, produce bool:

- `a < b` — less than.
- `a <= b` — less than or equal.
- `a > b` — greater than.
- `a >= b` — greater than or equal.

## Logical operators

Expect bool values, produce bool:

- `a || b` — `true` if either is `true`.
- `a && b` — `true` if both are `true`.
- `!a` — negation.

No exclusive-OR operator. When both operands are known to be bool, XOR equals the `!=` operator.

---
Related: [[tf-expressions]] — operators are one expression kind under the Expressions overview. [[tf-expr-types]] — operator groups rely on the type system and auto-conversion. [[tf-conditionals]] — `? :` is a conditional, not an operator.
