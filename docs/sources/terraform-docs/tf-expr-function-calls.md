# Function Calls

> **Source:** [developer.hashicorp.com/terraform/language/expressions/function-calls](https://developer.hashicorp.com/terraform/language/expressions/function-calls)
> **Added:** 2026-07-15
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-15
> **Tags:** function-calls, built-in-functions, argument-expansion, sensitive, pure-functions, plan-time
> **Type:** documentation

Built-in functions transform and combine values in expressions. Like operators, but with a common syntax:

```hcl
<FUNCTION NAME>(<ARGUMENT 1>, <ARGUMENT 2>)
```

Each function expects a set number of arguments of specific types and returns a specific type. A call expression evaluates to the return value.

Some functions take a variable number of arguments — e.g. `min` takes any count of numbers and returns the smallest:

```hcl
min(55, 3453, 2)
```

Full list: see the function reference.

## Expanding function arguments

When the arguments live in a list or tuple, expand it into separate arguments by passing the value followed by `...`:

```hcl
min([55, 2453, 2]...)
```

The symbol is **three periods** (`...`), not a Unicode ellipsis (`…`). Expansion is special syntax available **only** in function calls.

## Using sensitive data as arguments

If any argument is sensitive (a `sensitive` input variable or output), the call's **result** is marked sensitive. This is conservative and holds regardless of which function is called.

Example — passing an object with a sensitive value into `keys()` yields a sensitive list:

```
> local.baz
{
  "a" = (sensitive value)
  "b" = "dog"
}

> keys(local.baz)
(sensitive value)
```

## When Terraform calls functions

Most built-ins are **pure functions** — result depends only on arguments, so timing of the call doesn't matter.

A small set interacts with outside state, so call timing matters: `file`, `templatefile`, `timestamp`, `uuid`. Skip this section if not using them.

- `file` / `templatefile` — for reading files that are a **static** part of the configuration. Terraform runs them during **initial configuration validation**, before any other actions. You cannot use them to read files your configuration generates dynamically during plan or apply.
- `timestamp` — returns current system time when called. `uuid` — returns a random result, different each call. Without special handling, both would make the applied config differ from the plan, violating the execution model. Terraform makes both produce **unknown values during plan**, resolving the real value only at **apply**. For `timestamp`, the recorded time is the instant apply began, not when the change was planned.

---
Related: [[tf-expressions]] — function calls are one expression kind under the Expressions overview. [[tf-expr-operators]] — same purpose as operators, but common call syntax. [[tf-manage-sensitive-data]] — the sensitivity-propagation rule for arguments.
