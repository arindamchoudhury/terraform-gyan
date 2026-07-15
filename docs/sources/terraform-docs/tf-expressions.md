# Expressions

> **Source:** [developer.hashicorp.com/terraform/language/expressions](https://developer.hashicorp.com/terraform/language/expressions)
> **Added:** 2026-07-14
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-14
> **Tags:** expressions, functions, references, console, overview
> **Type:** documentation

Section overview. Expressions refer to or compute values in a configuration. Simplest are literal values (`"hello"`, `5`); the language also allows references to data exported by resources, arithmetic, conditional evaluation, and built-in functions.

## Where they apply

Expressions can be used in many places, but some contexts limit which constructs are allowed — e.g. requiring a literal value of a particular type, or forbidding references to resource attributes. Each language feature's own docs state its restrictions.

## Experimenting

Run `terraform console` to open the expression console and try expression behavior interactively.

## The subsections

The rest of the section documents each feature of the expression syntax:

- **Types and Values** — the data types expressions resolve to, and the literal syntaxes for values of those types.
- **Strings and Templates** — string literal syntaxes, including interpolation sequences and template directives.
- **References to Values** — how to refer to named values like variables and resource attributes.
- **Operators** — arithmetic, comparison, and logical operators.
- **Function Calls** — syntax for calling built-in functions.
- **Conditional Expressions** — `<CONDITION> ? <TRUE VAL> : <FALSE VAL>`, choosing between two values on a bool condition. See [[tf-conditionals]].
- **For Expressions** — `[for s in var.list : upper(s)]`, transforming one complex-type value into another.
- **Splat Expressions** — `var.list[*].id`, extracting simpler collections from more complicated expressions.
- **Dynamic Blocks** — creating multiple repeatable nested blocks within a resource or other construct.
- **Validate your configuration** — verify variable conditions, `check` blocks, and resource pre/postconditions.
- **Type Constraints** — syntax for referring to a *type* rather than a value of that type; input variables expect this in their `type` argument.
- **Version Constraints** — syntax of the special strings defining allowed software versions, used in several places.

---
Related: parent index for [[tf-conditionals]] (the only child captured so far). The condition-building idioms live in [[tf-conditionals]]; `type` constraint syntax is referenced by [[tf-block-variable]].
