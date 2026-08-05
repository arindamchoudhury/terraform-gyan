# Chapter 7 — Expressions, operators & built-in functions

## Learning outcomes

By the end you can:

- Read any expression and predict its type, including where Terraform auto-converts and where it refuses to.
- Reference every kind of named value (`var`, `local`, resource, `data`, `module`, `path.*`, `each`) and know that a reference *is* a dependency edge.
- Branch with the ternary safely, knowing both branches must be type-compatible but only the taken one is evaluated.
- Reach for the right function — `merge`, `lookup`, `coalesce`, `try`, `toset`, `jsonencode` — and know `try` from `coalesce`.
- Build strings with interpolation, heredocs, and template directives, and know when to `jsonencode` instead.
- Pull long content out of your `.tf` files with `file()` / `templatefile()`, anchored with `path.module`, and write the `.tftpl` template it renders.
- **Transform a list of maps into a keyed map with a `for` expression and use it to drive `for_each`.**

---

## 1. Why expressions: adding logic to a declarative language

A configuration full of literals can only ever describe one thing. The moment you want *the same code* to produce a dev environment and a prod environment, name three instances distinctly, or attach a policy only when a flag is set, you need to **compute** values rather than type them out. Expressions are how a declarative language stays DRY.

Everything to the right of an `=` is an expression — the part of HCL that *computes* rather than merely *declares*. An expression is anything that resolves to a value: a literal (`"hello"`, `5`, `true`), a reference (`var.region`), an operator chain (`var.count * 2`), a function call (`merge(a, b)`), a conditional, a `for`, or a splat. Every argument in every block is one.

!!! tip "Live-test everything in `terraform console`"
    The single most useful habit for this chapter: open the REPL with `terraform console` (`tofu console`) and type expressions against your real variables and state. It evaluates and prints the result immediately — the fastest way to build intuition for the function library, `for` transforms, and type conversion.

    ```
    > max(5, 12, 9)
    12
    > [for s in ["a", "b"] : upper(s)]
    [
      "A",
      "B",
    ]
    ```

    One gotcha: the console loads config **only at startup**. Edit a `.tf` file and you must restart the console to see the change.

---

## 2. Types and values

Every value has a type, and the type decides where the value is legal and how it converts.

**Primitives:** `string` (`"hello"`), `number` (`15` or `6.283`), `bool` (`true`/`false`).

**Complex types** group several values into one. They fall into two families, and that split predicts nearly every behavior in this section:

- **Collection** types hold **one element type** across a value of any length: `list`, `map`, `set`.
- **Structural** types hold a **fixed schema**, where each position or key carries its own type: `tuple`, `object`.

!!! info "These families are HCL's own definitions, not a teaching device"
    HCL's specification defines both, and Terraform inherits them wholesale.

    A **collection type** combines *"an arbitrary number of values of some other single type"*, in three kinds: list (ordered), map (accessed by string keys), set (unordered, distinct).

    A **structural type** is *"constructed by combining other types"*, in two kinds: an object is a set of named attributes each having its own type, and a tuple a sequence of elements each having its own type.

    The word *other* is doing real work: it names two layers, and the identity rule below has to compare both.

    The spec also fixes what makes two types **identical**, which is what the `==` pitfall at the end of this section turns on. Two collection types are identical when they share a kind and an element type. Two structural types are identical when they share a kind and their attributes or elements have identical types one-for-one.

    Anything else is a different type, and that bites harder than it sounds. `list(string)`, `list(number)`, and `set(string)` are three unrelated types. And since a tuple's elements must match one-for-one, its **length** is part of its type rather than a property of the value: `tuple([string, string])` and `tuple([string])` are as unrelated as `string` and `bool`.

| Type | Family | Ordered? | Keys | Element types |
|---|---|---|---|---|
| `tuple` | structural | yes (index from 0) | integer index | per-position, fixed length |
| `list` | collection | yes (index from 0) | integer index | one type, any length |
| `set` | collection | no | none | one type, no duplicates |
| `object` | structural | no | string labels | per-key, fixed schema |
| `map` | collection | no | string labels | one type, any size |

!!! note "Only two of the five have a literal"
    HCL gives you exactly two ways to write a complex value: brackets and braces. **Brackets always build a `tuple`. Braces always build an `object`.** There is no list literal, no set literal, and no map literal anywhere in the language. Those three types only ever arrive by conversion (`tolist`, `toset`, `tomap`), from a declared `type` constraint, or out of a provider's own schema. Every subsection below follows from that one fact.

!!! note "Why those two, and not the other three"
    A literal's text states each element's own type and exactly how many there are. That *is* a structural schema, so a `tuple` and an `object` can be read straight off the syntax with nothing inferred. A collection type needs something the text never supplies: one element type shared by every element. Finding it means **unifying** the elements, and unification needs a target type to aim at. That target only exists at a `type =` constraint, a provider schema, or an explicit `tolist`/`toset`/`tomap` call. HCL's spec states the rule outright: *"Only tuple and object values can be directly constructed via native syntax."*

    So "has a literal" and "is structural" aren't two facts that happen to line up. They're the same property. Which is also why there is no `totuple()` or `toobject()` function: the three `to*` collection converters exist precisely because those are the three types you can't write down.

The five subsections that follow each cover the **value** side: what actually produces the type, how it behaves, and where it bites. The **constraint** side (writing `type = ...` to restrict a module input) is [Ch 12](ch12-dynamic-blocks-complex-types.md); each subsection signposts its constraint form so you can connect the two halves.

### `tuple` — ordered, per-position types

What brackets actually build. Each position gets its own type, and the **length is part of the type**:

```
> type(["a", 15, true])
tuple([
    string,
    number,
    bool,
])
```

This is the mirror image of a `list`, which the next subsection covers. A list says "any number of one type"; a tuple says "exactly three elements, and here is the type of each." Nothing unifies, so a tuple is the one complex type that holds mixed values as-is.

Mostly you can ignore the distinction, because a tuple **auto-converts to a list** wherever one is expected. `join("-", ["p", "q"])` and `length(["p", "q"])` just work, and `tolist()` is rarely needed.

The exception is `==`, which never converts. Declare a variable and the trap is easy to see:

```hcl
variable "list" {
  type = list(string)
}
```

`var.list == []` is now **always** `false`. The left side is a `list(string)`, the right side is a `tuple([])`, and by the identity rule above those are simply different types. The sting is that it stays `false` even when the variable really is empty, which is the one case you wrote the comparison for. That pitfall gets its own treatment under **Type conversion** at the end of this section.

!!! note "Constraint form — `tuple([string, number])`"
    Written `tuple([<TYPE>, <TYPE>, ...])`. A value matches only if it has **exactly** that many elements, each convertible to the type at its position. Ch 12 has the schema rules.

### `list` — ordered, one element type

A sequence indexed by whole numbers from zero, holding any number of elements that all share **one** type. `list(string)` and `list(number)` are different types.

You never write a list directly. It shows up when you declare `type = list(string)` on a variable, when a resource uses `count`, or when you convert:

```
> type(tolist(["a", "b"]))
list(string)
```

Because a list holds a single element type, converting a mixed value **unifies** the elements into whichever type they all fit:

```
> tolist(["a", 15])
tolist([
  "a",
  "15",
])
```

The number quietly became a string. That is usually harmless and occasionally a real surprise. When no single type fits, the conversion fails instead of guessing: `tolist(["a", []])` has no type that both a string and an empty tuple convert to.

Index with square brackets. Note the `tolist()` here is doing real work, not decoration: without it you'd be indexing a tuple, and this subsection would be demonstrating the wrong type.

```
> tolist(["a", "b", "c"])[1]
"b"
```

!!! note "Constraint form — `list(string)`"
    Written `list(<TYPE>)`. Bare `list` means `list(any)`, a backwards-compatibility shorthand; prefer the full form. Ch 12 covers the constructor syntax and why `any` is almost always the wrong answer.

### `set` — unordered, unique, no index

A collection of unique values with no keys and no ordering. Converting to a set deduplicates:

```
> toset(["b", "a", "b"])
toset([
  "a",
  "b",
])
```

Sets have no index at all, and the error says exactly why:

```
> toset(["a", "b"])[0]

Error: Invalid index

Elements of a set are identified only by their value and don't have any
separate index or key to select with, so it's only possible to perform
operations across all elements of the set.
```

Convert to a list first with `tolist()` if you need positional access.

**Sets are the reason `toset([...])` is everywhere.** `for_each` accepts a **map**, an **object**, or a **set of strings**. It converts nothing: it inspects the type kind directly, so a list is rejected outright rather than quietly converted, and the wrapper is mandatory:

```
for_each = var.names        # var.names is list(string)

Error: Invalid for_each argument
  The given "for_each" argument value is unsuitable: the "for_each" argument
  must be a map, or set of strings, and you have provided a value of type
  list of string.
```

Read that error closely, because `toset()` isn't a magic word. It has to produce a set **of strings**. A set of anything else fails just as hard:

```
for_each = toset([1, 2])

Error: Invalid for_each set argument
  "for_each" supports maps and sets of strings, but you have provided a set
  containing type number.
```

A **tuple** is refused on the same grounds as a list, which is worth seeing given that brackets are the only thing they build:

```
for_each = ["p", "q"]

Error: Invalid for_each argument
  The given "for_each" argument value is unsuitable: the "for_each" argument
  must be a map, or set of strings, and you have provided a value of type
  tuple.
```

!!! warning "That error message under-reports what `for_each` actually accepts"
    Both the message and HashiCorp's `for_each` page say "a map, or set of strings" and never mention **objects**. The implementation checks for three kinds, map *and* set *and* object, and accepts all of them (`internal/terraform/eval_for_each.go`, verified on 1.15.8). OpenTofu's docs get this right and list all three.

    It matters here because braces build an **object**, not a map. `for_each = { a = "1", b = "2" }` works directly, with no `tomap()` anywhere. Take the error message literally and you'd think otherwise.

    Note also that "of strings" binds only to the **set**. Only keys become instance addresses, so a map or object may carry values of any type: `for_each = { a = 1, b = "x" }` plans fine even though that object holds a number and a string.

The `for_each` mechanics themselves are Ch 10.

For a **module input**, don't push the wrapper onto your callers. Declare the type and Terraform converts, and dedupes, whatever list they hand you:

```hcl
variable "names" {
  type    = set(string)
  default = ["p", "q", "p"]   # var.names is toset(["p", "q"])
}
```

!!! warning "Set ordering is only guaranteed for strings"
    Converting an unordered set into an ordered list forces an order from somewhere. For **strings** that order is lexicographical and dependable. For any other element type it is **arbitrary**, so don't read a pattern into it:

    ```
    > tolist(toset([3, 1, 2]))
    tolist([
      1,
      2,
      3,
    ])
    ```

    That came out sorted. Nothing promises it will stay that way for numbers.

    `sort()` is not the fix. It takes a `list(string)`, so numbers are converted before they are compared and you get a lexicographical order over their string forms:

    ```
    > sort(toset([10, 6, 4, 5]))
    tolist([
      "10",
      "4",
      "5",
      "6",
    ])
    ```

    `"10"` sorts before `"4"`, and the numbers come back as strings.

!!! tip "Getting numeric order anyway"
    The cleanest answer is to not create the problem. Lists preserve order, so keep the values in a list and only convert to a set at the point something demands one, such as `for_each` or a `set`-typed module input.

    When you are handed a set of numbers and genuinely need them in numeric order, pad each one to a fixed width first. `format("%09d", n)` turns `4` into `"000000004"` and `100` into `"000000100"`. Equal-width digit strings compare lexicographically the same way the numbers compare, so `sort()` gives the right answer and `tonumber()` strips the padding back off:

    ```hcl
    [for s in sort([for n in toset([10, 6, 4, 5, 100]) : format("%09d", n)]) : tonumber(s)]
    # [4, 5, 6, 10, 100]
    ```

    The padding width has to exceed your largest value. Everything else about the trick is a question of keeping the columns aligned. Floats work if you pin the precision as well as the width, because then the decimal point lands in the same column on every value:

    ```hcl
    [for s in sort([for n in [1.5, 10.25, 2.5] : format("%012.4f", n)]) : tonumber(s)]
    # [1.5, 2.5, 10.25]
    ```

    Negative numbers are where it genuinely breaks. The minus sign is just another character, so `"-000000002"` sorts before `"-000000005"` and the negatives come back in reverse. Sorting their absolute values and calling `reverse()` undoes that:

    ```hcl
    [for s in reverse(sort([for n in [-5, -2, -30] : format("%09d", -n)])) : -tonumber(s)]
    # [-30, -5, -2]
    ```

    A mixed-sign list needs the two halves separated, sorted under their own rules, and concatenated back:

    ```hcl
    locals {
      nums = [-5, 2, -30, 10, 3]
      neg  = [for n in local.nums : n if n < 0]
      pos  = [for n in local.nums : n if n >= 0]

      sorted = concat(
        [for s in reverse(sort([for n in local.neg : format("%09d", -n)])) : -tonumber(s)],
        [for s in sort([for n in local.pos : format("%09d", n)]) : tonumber(s)],
      )
      # [-30, -5, 2, 3, 10]
    }
    ```

    Both work. Neither is something you want to find in a config six months from now.

    That is the signal to stop. Either compute the order outside Terraform and pass it in as an already-sorted variable, or use a provider-defined function (Terraform 1.8+, OpenTofu 1.7+) where a provider ships a real numeric sort. The function buys correctness for every element type at the cost of a provider dependency for one sort.

    For `for_each` none of this matters. Keys are strings and set order does not affect resource addresses. Numeric order only earns the effort when you index the result or feed it somewhere that is itself ordered.

The `set*` functions (`setunion`, `setsubtract`, `setintersection`, `setproduct`) return sets too. `distinct()` is the one that looks like it should and doesn't. It returns a **list**.

!!! note "Constraint form — `set(string)`"
    Written `set(<TYPE>)`. The type `for_each` wants is specifically `set(string)`. Ch 12 covers the conversion rules in full.

### `object` — string keys, per-key types

What braces actually build. Each attribute carries its own type:

```
> type({ name = "John", age = 52 })
object({
    age: number,
    name: string,
})
```

Run `tomap()` on that same value and `52` comes back as `"52"`; the object kept it a `number`. That is the collection-versus-structural split in one example. The type output lists attributes alphabetically, which is a display convenience; an object has no ordering.

Objects are everywhere in Terraform whether you notice or not. **Every resource and data source *instance* is an object**, which is why `aws_instance.web.id` works: `aws_instance.web` is an object with an `id` attribute. Say *instance* rather than *reference*, because the meta-arguments change the shape around it, and the bare type name `aws_instance` is not a value at all. §3 has both.

Reach attributes with dot notation when the name is identifier-safe, brackets otherwise:

```
> { name = "John", age = 52 }.name
"John"
```

**Extra attributes are discarded on conversion, silently.** An object value matches an object type as long as it carries **all** the required keys; anything extra is dropped:

```
> convert({ name = "John", age = 52 }, object({ name = string }))
{
  "name" = "John"
}
```

`age` is simply gone. This is what makes a `map → object → map` round trip **lossy**, and it's worth knowing before you rely on one. A *missing* required attribute is the opposite, an error rather than a silent drop:

```
> convert({ name = "John" }, object({ name = string, age = number }))

Error: Invalid function argument

Invalid value for "value" parameter: attribute "age" is required.
```

!!! info "OpenTofu — no `convert()`, but the behavior is still reachable"
    The two blocks above use `convert(value, type)`, added in **Terraform 1.15** and absent from OpenTofu as of 1.12.4 ([open request #2630](https://github.com/opentofu/opentofu/issues/2630), filed March 2025). What's missing is the *function*, not the capability. `convert()` is an inline shortcut for the machinery that every `type =` constraint already runs, so declaring the constraint at a boundary does the identical job:

    ```hcl
    # child module — OpenTofu 1.12.4
    variable "person" {
      type = object({ name = string })
    }
    ```

    Hand that `{ name = "John", age = 52 }` and it returns `{ name = "John" }`. Same discard, same rules, no function needed.

    What OpenTofu can't do is apply an arbitrary schema **inline**, mid-expression, with no declared boundary. That is exactly what #2630 asks for, and its motivating case is coercing `jsondecode`/`yamldecode` output. Typed outputs are no help either, since `type` on an `output` is also Terraform 1.15+ and OpenTofu rejects it. For primitives and collections the fixed casters (`tostring`, `tonumber`, `tolist`, `toset`, `tomap`) cover the same ground in both tools, so the gap is specifically **object and tuple schemas**.

!!! note "Constraint form — `object({ name = string })`"
    Written `object({ <KEY> = <TYPE>, ... })`. [Ch 12](ch12-dynamic-blocks-complex-types.md) covers the schema rules and **`optional(type, default)`**, which is how an object attribute becomes genuinely optional instead of merely defaulting to `null`.

### `map` — string keys, one value type

Values identified by string labels, unordered, all sharing **one** value type. Braces build an object rather than a map, so a map arrives by conversion, by a `type = map(string)` constraint, or from a `for_each` resource:

```
> type(tomap({ name = "John", age = 52 }))
map(string)
```

`52` became `"52"`. This is the same single-type unification a list does, and for the same reason. When no single value type fits, the conversion fails outright:

```
> tomap({ name = ["a"], age = 12 })

Error: Invalid function argument

Invalid value for "v" parameter: cannot convert object to map of any single
type.
```

**Key syntax.** Strictly these are the *brace literal's* rules, so they produce an object that then converts, and they apply just as much to `object` above. They're here because `tags` is where you actually type them. Keys must be strings. Write them unquoted when they're valid identifiers, quoted otherwise (leading digits, spaces, special characters). Both `=` and `:` are valid delimiters, so `{ foo = "bar" }` and `{ "foo": "bar" }` are the same value, and Terraform normalizes on the way out:

```
> { "foo": "bar" }
{
  "foo" = "bar"
}
```

!!! tip "Prefer `=` over `:`"
    `terraform fmt` vertically aligns equals signs but ignores colons entirely. The colon form is legal, just unformatted.

To use a non-literal expression as a key, wrap it in parentheses, otherwise it's read as a bare identifier:

```hcl
tags = {
  (var.business_unit_tag_name) = "SRE"
}
```

Access with brackets, which is also the right choice whenever keys are user-supplied rather than known:

```
> tomap({ name = "John" })["name"]
"John"
```

!!! note "Constraint form — `map(string)`"
    Written `map(<TYPE>)`. Bare `map` means `map(any)`. Ch 12 covers the constructors.

### `null` — the typeless value

`null` means "absent." Setting a resource argument to `null` makes Terraform behave as if you omitted it entirely: it falls back to the argument's default, or errors if the argument is required. That makes `null` the tool for *conditionally omitting* an argument.

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  # supply a key name only if the caller gave one; otherwise omit the argument
  key_name      = var.key_name != "" ? var.key_name : null
}
```

### Type conversion — automatic, except `==`

Where an argument expects a type, Terraform **auto-converts** when it safely can: `number`/`bool` → `string`, and a `string` → number/bool when the string holds a valid representation (`"15"` ↔ `15`, `"true"` ↔ `true`).

!!! warning "Equality never auto-converts"
    The one place conversion does **not** happen is the equality operators. Prove it in the console:

    ```
    > "15" == 15
    false
    > tonumber("15") == 15
    true
    ```

    `"15"` and `15` are different types, so `==` reports `false`. Cast first. This is the single most common expression surprise, so when comparing, make the types match explicitly.

---

## 3. References — the named values

Terraform exposes a fixed set of named values. Each is an expression on its own and can be combined into larger ones.

| Reference | Refers to |
|---|---|
| `var.<NAME>` | an input variable (already conformed to its `type`) |
| `local.<NAME>` | a local value |
| `<TYPE>.<NAME>` | a managed resource (e.g. `aws_instance.web`) |
| `data.<TYPE>.<NAME>` | a data source |
| `module.<NAME>.<OUTPUT>` | a child module's output |
| `path.module` / `path.root` / `path.cwd` | filesystem paths |
| `terraform.workspace` | the current CLI workspace name |
| `count.index`, `each.key` / `each.value`, `self` | block-local values inside `count`/`for_each`/provisioners |
| `terraform.applying` | bool, `false` while planning and `true` while applying (TF 1.10) |

!!! note "`terraform.applying` — the one reference you can't print"
    Added in Terraform **1.10**, `terraform.applying` is `false` while Terraform is planning and `true` while it is applying. It exists so a config can behave differently between the two phases, most usefully to skip fetching a secret during a plan that doesn't need one.

    Proving it is awkward, because the value is **ephemeral**: it must never reach state, so Terraform refuses to let it flow anywhere persistent. Sending it to an ordinary output is rejected outright, and marking that output `ephemeral = true` only moves the complaint:

    ```
    Error: Ephemeral value not allowed
    Error: Ephemeral outputs are not allowed in context of a root module
    ```

    A `precondition` is somewhere it *may* go, so it doubles as the demonstration. Assert it is false and the plan succeeds while the apply fails:

    ```hcl
    resource "terraform_data" "probe" {
      lifecycle {
        precondition {
          condition     = !terraform.applying
          error_message = "terraform.applying was true here"
        }
      }
    }
    ```

    Ephemeral values in general are the secrets topic. Where they may be used, and the `ephemeral` resources and write-only arguments built on them, belong to **A6**.

A resource reference's *shape* depends on its meta-arguments. With neither `count` nor `for_each` it's a single **object**. With `count` it's a **tuple** of instance objects (`aws_instance.web[0].id`). With `for_each` it's an **object** keyed by your `for_each` keys, each attribute an instance object (`aws_instance.web["a"].id`).

Those are structural types, and that is worth a moment, because you will read otherwise. HashiCorp's [references page](https://developer.hashicorp.com/terraform/language/expressions/references) describes the same two shapes as collections: with `count`, "the reference's value is a *list* of objects representing its instances"; with `for_each`, "a *map* of objects". Ask Terraform and you get `tuple` and `object`. Both descriptions are usable, because the docs [say plainly](https://developer.hashicorp.com/terraform/language/expressions/types) that they use list/tuple and map/object interchangeably wherever the distinction doesn't matter, and for indexing and splat it doesn't. This chapter names the real type because §2 spent its length on the difference.

!!! note "Why the container is structural — it's §2's unification rule, with a bill attached"
    A collection needs **one** element type, and instances of a single block aren't guaranteed to share one. Give `for_each` a map whose values differ in type, and the instances diverge:

    ```hcl
    resource "terraform_data" "mixed" {
      for_each = { a = "str", b = 5 }
      input    = each.value          # string for a, number for b
    }
    ```

    ```
    > type(terraform_data.mixed)
    object({
        a: object({ id: string, input: string, output: string, ... }),
        b: object({ id: string, input: number, output: number, ... }),
    })
    ```

    Instance `a` carries `input: string`; instance `b` carries `input: number`. Two different object types under one resource block.

    A `map` **could** still hold those two, and the *how* is worth following, because it's §2's machinery. A map has one element type, so Terraform has to **unify** the two instance objects into a single type, attribute by attribute. `id` is `string` on both, so it stays. `input` is `string` on `a` and `number` on `b`, and those two meet at `string` — the `cty` docs say why: *"String is the most general type, since the other two primitive types have safe conversions to string."* So the unified element type comes out as:

    ```
    > type(tomap(terraform_data.mixed))
    map(object({ id: string, input: string, output: string, ... }))
    ```

    Every value is then converted into that type, and here is the bill:

    ```
    > terraform_data.mixed["b"].input                  # structural — preserved
    5
    > type(terraform_data.mixed["b"].input)
    number

    > tomap(terraform_data.mixed)["b"].input           # collection — coerced
    "5"
    > type(tomap(terraform_data.mixed)["b"].input)
    string
    ```

    That is the whole reason. A collection isn't *impossible* here, it's *not free* — it would quietly turn your number into a string, and `b.input * 2` would stop working. The structural type keeps every instance exactly the type it is. So Terraform hands you `tuple`/`object` for resources **unconditionally**, rather than gambling on whether one particular resource's instances happen to match.

    **All of which assumes unification can find a type at all.** When it can't, the map doesn't merely cost something — it stops existing. Give the instances values with no common type:

    ```hcl
    for_each = { a = ["x"], b = 5 }     # a tuple and a number
    ```

    ```
    > tomap(terraform_data.nounify)
    Error: Invalid function argument
    Invalid value for "v" parameter: cannot convert object to map of any single
    type.
    ```

    That is the same error the `map` subsection hit in §2, for the same reason: no single type is both a tuple and a number, so there is no map to convert to. Structural handles that case too, without complaint.

    None of it disturbs the instance-level story: the elements are still objects, which is why `[0]` and `["a"]` hand you one back.

!!! tip "Modules are the exception, and it's a reason to type your outputs"
    A **module** call with `count`/`for_each` only gets the structural treatment when Terraform can't pin the types down — and now you can see why the condition is what it is. If every output the module declares is **fully typed**, then every instance has the *same declared type*, unification has nothing to reconcile, and the collection costs nothing. So Terraform uses it. `type` on an `output` is exactly that knob (Terraform **1.15+**, Ch 6). The same module, before and after adding `type = string` to its one output:

    ```
    > type(module.c)      # count = 2, output has no type
    tuple([ object({ untyped: string }), object({ untyped: string }) ])

    > type(module.c)      # count = 2, output declares type = string
    list(object({ untyped: string }))

    > type(module.f)      # for_each, output declares type = string
    map(object({ untyped: string }))
    ```

    Tuple becomes **list**, object becomes **map**. Resources have no equivalent switch because a provider's dynamic-typed attributes can always diverge per instance, but a module's interface is yours to declare.

    Resist reading that as a reason to type your outputs. Type them for the reason Ch 6 gives — a checked, self-documenting interface. The shape change is a *consequence* of that guarantee, not a benefit on top of it, and callers almost never feel it: a tuple splats, converts, and satisfies a `list(object(...))` constraint exactly as a list does. What you gain is exactness and better errors. It earns its place here because it shows the type system deciding something on your behalf, and because it explains why the condition is "are the outputs fully typed" rather than something arbitrary.

!!! note "A resource **type** isn't a value you can traverse"
    An instance is an object, but the dotted path is not object access all the way up. The prefix is not a real object: you cannot swap dot notation for bracket notation on the fixed parts of the path, and you cannot iterate a **resource type** to reach every block of that type. There is no reflection over resource types in HCL, and splat does not rescue it — the bare type name isn't a value at all:

    ```
    > terraform_data
    Error: Invalid reference
    > terraform_data[*]
    Error: Invalid reference
    > [for r in terraform_data : r]
    Error: Invalid reference
    ```

    Be careful with the phrase "loop over all instances" — it means two different things, and only one is impossible:

    - **Every instance of *one* resource block** — **yes**. That block *is* an ordinary value: a **list** under `count`, a **map** under `for_each`. Splat reads the list form directly — `terraform_data.web[*].output` returns `["web-0", "web-1", "web-2"]`. The map form needs `values(...)` or a `for`, and its error message is misleading; §8 has the full treatment.
    - **Every resource block of a given type** across the config — **no**. To enumerate that, step outside expressions entirely: `terraform state list`, or `terraform show -json` for machine-readable output.

!!! info "A reference *is* a dependency edge"
    When one block's argument references another resource's attribute, Terraform records an **implicit dependency** and orders the graph accordingly (Ch 3, Ch 5). This is the preferred way to express ordering — reach for `depends_on` only when there's genuinely no attribute to reference (Ch 10).

**`path.*` and `terraform.workspace` are the odd ones out.** Every other named value describes *what* your config declares; these two describe *where and how it was run* — the invoking directory, the selected workspace. Bake that into the config and its meaning starts depending on the circumstances of the run. So: apart from `path.module`, use them **only in the root module**.

`terraform.workspace` shows the cost plainly. Used as a name prefix **inside** a shared module, it quietly makes that module single-use: call it twice in one config and both calls read the same workspace name, derive the same resource names, and collide. Take the prefix as an input variable instead, and let the root caller build it:

```hcl
module "app" {
  source      = "./modules/app"
  name_prefix = "app-${terraform.workspace}"   # workspace read at the ROOT, passed in
}
```

The workspace name is only the visible tip of **CLI workspaces**, an environment-isolation strategy rather than an expression feature — Ch 24 weighs it against directory-per-environment and HCP workspaces. `path.*` earns its keep through `file()` and `templatefile()`, in §7.

### Values not yet known

During `plan`, some attributes aren't decided yet. A generated ID, an assigned IP, an ARN — the remote system picks them at create time, and Terraform refuses to guess. It substitutes an **unknown value** placeholder and prints it as `(known after apply)`.

Unknown-ness spreads, but the rule is narrower than "anything touching an unknown goes unknown." An expression is unknown only when its **result actually depends on** the unknown value. Structure that Terraform can determine without the value stays known. With `terraform_data.a.id` not yet created, a plan shows:

```
+ interp = (known after apply)   # "prefix-${terraform_data.a.id}" — the text depends on the id
+ upper  = (known after apply)   # upper(terraform_data.a.id)      — the result depends on the id
+ len    = 1                     # length([terraform_data.a.id])   — depends only on the list's SIZE
```

That third line is the one worth internalizing. The list *contains* an unknown, yet its length is known: one element is one element no matter what the element turns out to be. Terraform tracks unknown-ness per value, not per expression-that-mentions-one.

This matters because the shape of a thing is often computable before its values exist — which is exactly the escape hatch for the constraint below.

Four places unknowns change behavior rather than just printing oddly:

- **`count` / `for_each` cannot be unknown at all** (see the warning below).
- **A data source with an unknown in its config** has its read **deferred to apply**, and everything it returns becomes unknown too.
- **An unknown passed to a `module` argument** makes the child's input variable unknown, propagating the problem across the boundary.
- **An unknown in an `output`'s value** makes every parent-module reference to that output unknown.

!!! warning "`count`/`for_each` cannot be unknown"
    Terraform must evaluate `count` and `for_each` *during* plan to know how many instances to put in the graph. So their values **cannot** depend on anything `(known after apply)` — no resource IDs, no computed attributes. This is the single biggest constraint on iteration, and Ch 5 §5.7 shows exactly how it fails.

    The fix follows from the rule above: key the iteration off something whose *shape* is known at plan time — input variables, locals, literals — and let the unknown values land inside the resource body instead. You can build three buckets named after a list you control while each bucket's ARN stays `(known after apply)`.

---

## 4. Operators

Operators combine or transform values. They group into arithmetic, comparison, and logical, and they evaluate in a fixed precedence.

```hcl
locals {
  availability_zones = min(var.active_azs, 3)         # clamp: never above 3
  needed_subnets     = local.availability_zones * 2   # 2 subnets per AZ
  is_big             = var.servers > 15 || var.feature_enabled
}
```

| Group | Operators | Operand type → result |
|---|---|---|
| Arithmetic | `+` `-` `*` `/` `%` and unary `-` | number → number |
| Comparison | `<` `<=` `>` `>=` | number → bool |
| Equality | `==` `!=` | any (same type) → bool |
| Logical | `&&` <code>&#124;&#124;</code> `!` | bool → bool |

**Precedence** (highest first): `!`/unary `-` → `*` `/` `%` → `+` `-` → comparison → equality → `&&` → `||`. Check it rather than trust it:

```
> 1 + 2 * 3
7
> (1 + 2) * 3
9
```

!!! tip "Parenthesize for the reader, even when it changes nothing"
    A long chain like `2 + 4 / 5 * var.m` is legal but fragile to edit. Add parentheses to make the grouping obvious — future-you will thank you.

!!! warning "`var.list == []` does not test for empty"
    An empty list literal `[]` builds a `tuple([])`, whose type never matches a `list(string)`, so the comparison is always `false` regardless of contents. Test length instead:

    ```
    > tolist([]) == []
    false
    > length(tolist([])) == 0
    true
    ```

    (Same reason as the equality-type rule in §2 — `==` compares type *and* value, and never converts.)

!!! info "`&&` and `||` short-circuit — OpenTofu 1.10, Terraform 1.12"
    Historically both sides of a logical operator were always evaluated, so a null-guard like `var.foo != null && var.foo.enabled` still **errored** when `var.foo` was null. Now the right side is skipped once the left decides the result, making that guard safe.

    **OpenTofu shipped it first, in 1.10** ("in OpenTofu v1.10 and later the logical operators are short-circuiting"); **Terraform followed in 1.12.0** (May 2025 — *"Logical binary operators can now short-circuit"*, [#36224](https://github.com/hashicorp/terraform/issues/36224)). HashiCorp's operators page still doesn't document the behavior, so the changelog is the citable source.

    Skipping is about **evaluation only**. A skipped operand is still **statically validated** — `var.foo` must still refer to a declared `variable "foo"` block, or the config fails regardless. That's the same static-vs-runtime split as the ternary in §5, and it's the one rule worth carrying across both.

---

## 5. Conditionals — the ternary

`condition ? true_value : false_value` is Terraform's `if/then/else`, and the most-used branching tool in the language.

```hcl
locals {
  bucket_name = var.name != "" ? var.name : "default-bucket"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count      = var.enable_ssm ? 1 : 0     # 1 = create, 0 = skip
  role       = aws_iam_role.main.name
  policy_arn = data.aws_iam_policy.ssm.arn
}
```

The `count = bool ? 1 : 0` idiom is *the* standard way to make a resource optional in a module — a cleaner interface than asking the caller for a number.

**Both result values must be type-compatible.** So Terraform can determine the expression's return type without knowing the condition. If they differ, it hunts for a common type and auto-converts — note the `12` comes back **quoted**, because the branches unified to `string`:

```
> true ? 12 : "hello"
"12"
```

When the result type is uncertain, be explicit: `var.x ? tostring(12) : "hello"`.

!!! warning "Both branches must be type-compatible — but only the taken branch is evaluated"
    Two separate rules, often conflated. The **type** rule doesn't care about the condition: both result values must unify to a common type, and Terraform checks that whichever way the condition goes, so it can know the expression's type up front. `true ? 1 : ["a"]` fails at plan with *"Inconsistent conditional result types"* even though the `true` branch is perfectly fine.

    "Compatible" is looser than "identical" — a `number` and a `string` unify (that's the `true ? 12 : "hello"` → `"12"` case above). A `string` and a tuple don't: `true ? "safe" : [1,2]` errors.

    A branch's **runtime** error is different. An out-of-range index, indexing a `count = 0` resource, a division by zero — these surface **only when that branch is the one selected.** The untaken branch is not evaluated, even when the condition is unknown at plan time.

    Both branches below are **strings**, so the type rule is satisfied and the only thing left to observe is evaluation:

    ```
    > true  ? "safe" : ["a","b","c"][5]      # untaken bad index → never evaluated
    "safe"
    > false ? ["a","b","c"][5] : "safe"      # same, on the other side
    "safe"
    ```

    So guard the branch you might **take**, not "both." `try` is the tool when the branch you select could itself error:

    ```hcl
    output "nat_ip" {
      # if use_instance is true, the module[0] index it TAKES must be safe
      value = var.use_instance ? try(module.nat_instance[0].ip, null) : module.nat_gateway[0].ip
    }
    ```

    Lazy evaluation arrived with **Terraform 0.12.0** (the HCL2 rewrite, May 2019). The old pre-0.12 engine really did evaluate both branches, which is where the folklore comes from — so material asserting that Terraform "evaluates both results" is describing a version that has been gone for years. Expect to meet the claim anyway; it outlived the behavior. OpenTofu inherits the modern rule, having forked well after 0.12.

The condition can be any bool expression. A cookbook of the idioms that build good conditions — `contains(...)`, `length(...) != 0`, `alltrue([for ...])`, `can(...)` — appears in the function section next, because they're what you'll feed to `validation` and `precondition` blocks (Ch 19).

---

## 6. Functions

Terraform ships a standard library of **built-in functions** you call from expressions:

```hcl
merge(var.tags, { Name = "web" })
```

What makes them different from functions in an imperative language: **they transform data, they never act.** They cannot open a socket, write a file, or call an API — all state-changing work belongs to resources and data sources. Functions only massage values into the arguments those blocks need. You **cannot define your own** in HCL, though a provider can ship functions (called `provider::<name>::<fn>(...)`).

### Call syntax, argument expansion, and sensitivity

```hcl
min(55, 3, 12)            # → 3     (variadic — any number of args)
min([55, 3, 12]...)       # → 3     expand a list into separate args with ...
```

The expansion symbol is **three periods** (`...`), not a Unicode ellipsis, and works only in function calls.

!!! warning "A sensitive argument makes the whole result sensitive"
    If an argument **is itself** marked sensitive, the call's result is sensitive too — conservatively, regardless of what the function does. Even `length` returns a redacted number. That's why a value sometimes starts printing `(sensitive value)` for no obvious reason:

    ```
    > length(sensitive({ a = "1" }))
    (sensitive value)
    > upper(var.secret)
    (sensitive value)
    ```

    But the mark is tracked **per value**, including nested ones — so a map that merely *contains* a sensitive element is not itself sensitive, and functions that don't touch that element come back clean:

    ```
    > local.baz                      # { a = var.secret, b = "dog" }
    {
      "a" = (sensitive value)
      "b" = "dog"
    }
    > keys(local.baz)                # keys don't depend on the secret VALUE
    [
      "a",
      "b",
    ]
    > values(local.baz)              # values do — the mark survives on that element
    [
      (sensitive value),
      "dog",
    ]
    ```

    Use `issensitive(expr)` to settle it rather than guessing — `issensitive(keys(local.baz))` is `false`, `issensitive(upper(var.secret))` is `true`.

    Worth knowing: the HashiCorp docs still show `keys(local.baz)` returning `(sensitive value)` for exactly this map. That example is stale — as of 1.15.6 it returns the plain key list. Sensitivity tracking got more precise, the way unknown-ness did (§3).

### Pure vs impure — and the perpetual-diff trap

Most functions are **pure**: same inputs, same output, always (`max`, `merge`, `split`). A handful are **impure** — their result changes per call (`timestamp()`, `uuid()`) or reads outside state (`file`, `templatefile`).

!!! danger "Never derive resource config from `uuid()` or `timestamp()`"
    In a declarative language, feeding an impure function into a resource argument means the value differs on every `plan` — so Terraform thinks the resource *always* needs updating. The workspace is out of date the instant `apply` finishes.

    ```hcl
    resource "aws_instance" "bad" {
      tags = { id = uuid() }    # new value every plan → forces a change forever
    }
    ```

    If you need a *stable* random or time value, use the **`random`** / **`time`** providers — they compute the value once and store it in state, so it stays put.

!!! info "Timing of `file`/`timestamp`/`uuid`"
    `file` and `templatefile` run during **initial validation**, before any plan — so they can only read files that are a static part of the configuration, never files your config generates. `timestamp()` and `uuid()` are made **unknown during plan** and resolved at **apply** (for `timestamp`, the instant apply began), so the plan and apply stay consistent.

### The library, by category

Terraform 1.15.6 ships **119** built-in functions — you learn the *skill* of finding one, not the whole list by heart. (`terraform metadata functions -json` dumps every signature; it reports 238 because each function is also exposed under a `core::` alias, so `core::max(1, 9)` and `max(1, 9)` are the same function. The alias exists to disambiguate built-ins from provider-defined functions.) The categories:

| Category | Representative functions |
|---|---|
| Numeric | [`min`](https://developer.hashicorp.com/terraform/language/functions/min) [`max`](https://developer.hashicorp.com/terraform/language/functions/max) [`abs`](https://developer.hashicorp.com/terraform/language/functions/abs) [`ceil`](https://developer.hashicorp.com/terraform/language/functions/ceil) [`floor`](https://developer.hashicorp.com/terraform/language/functions/floor) [`pow`](https://developer.hashicorp.com/terraform/language/functions/pow) [`parseint`](https://developer.hashicorp.com/terraform/language/functions/parseint) [`signum`](https://developer.hashicorp.com/terraform/language/functions/signum) |
| String | [`format`](https://developer.hashicorp.com/terraform/language/functions/format) [`join`](https://developer.hashicorp.com/terraform/language/functions/join) [`split`](https://developer.hashicorp.com/terraform/language/functions/split) [`replace`](https://developer.hashicorp.com/terraform/language/functions/replace) [`substr`](https://developer.hashicorp.com/terraform/language/functions/substr) [`lower`](https://developer.hashicorp.com/terraform/language/functions/lower)/[`upper`](https://developer.hashicorp.com/terraform/language/functions/upper)/[`title`](https://developer.hashicorp.com/terraform/language/functions/title) [`trimspace`](https://developer.hashicorp.com/terraform/language/functions/trimspace) [`startswith`](https://developer.hashicorp.com/terraform/language/functions/startswith)/[`endswith`](https://developer.hashicorp.com/terraform/language/functions/endswith)/[`strcontains`](https://developer.hashicorp.com/terraform/language/functions/strcontains) [`regex`](https://developer.hashicorp.com/terraform/language/functions/regex)/[`regexall`](https://developer.hashicorp.com/terraform/language/functions/regexall) |
| Collection | [`merge`](https://developer.hashicorp.com/terraform/language/functions/merge) [`lookup`](https://developer.hashicorp.com/terraform/language/functions/lookup) [`coalesce`](https://developer.hashicorp.com/terraform/language/functions/coalesce) [`concat`](https://developer.hashicorp.com/terraform/language/functions/concat) [`flatten`](https://developer.hashicorp.com/terraform/language/functions/flatten) [`keys`](https://developer.hashicorp.com/terraform/language/functions/keys)/[`values`](https://developer.hashicorp.com/terraform/language/functions/values) [`contains`](https://developer.hashicorp.com/terraform/language/functions/contains) [`distinct`](https://developer.hashicorp.com/terraform/language/functions/distinct) [`length`](https://developer.hashicorp.com/terraform/language/functions/length) [`toset`](https://developer.hashicorp.com/terraform/language/functions/toset) [`setproduct`](https://developer.hashicorp.com/terraform/language/functions/setproduct) [`zipmap`](https://developer.hashicorp.com/terraform/language/functions/zipmap) [`slice`](https://developer.hashicorp.com/terraform/language/functions/slice) [`sort`](https://developer.hashicorp.com/terraform/language/functions/sort) [`alltrue`](https://developer.hashicorp.com/terraform/language/functions/alltrue)/[`anytrue`](https://developer.hashicorp.com/terraform/language/functions/anytrue) [`one`](https://developer.hashicorp.com/terraform/language/functions/one) |
| Encoding | [`jsonencode`](https://developer.hashicorp.com/terraform/language/functions/jsonencode)/[`jsondecode`](https://developer.hashicorp.com/terraform/language/functions/jsondecode) [`yamlencode`](https://developer.hashicorp.com/terraform/language/functions/yamlencode)/[`yamldecode`](https://developer.hashicorp.com/terraform/language/functions/yamldecode) [`csvdecode`](https://developer.hashicorp.com/terraform/language/functions/csvdecode) [`base64encode`](https://developer.hashicorp.com/terraform/language/functions/base64encode)/[`base64decode`](https://developer.hashicorp.com/terraform/language/functions/base64decode) [`urlencode`](https://developer.hashicorp.com/terraform/language/functions/urlencode) |
| Filesystem | [`file`](https://developer.hashicorp.com/terraform/language/functions/file) [`fileexists`](https://developer.hashicorp.com/terraform/language/functions/fileexists) [`fileset`](https://developer.hashicorp.com/terraform/language/functions/fileset) [`templatefile`](https://developer.hashicorp.com/terraform/language/functions/templatefile) [`abspath`](https://developer.hashicorp.com/terraform/language/functions/abspath) [`dirname`](https://developer.hashicorp.com/terraform/language/functions/dirname)/[`basename`](https://developer.hashicorp.com/terraform/language/functions/basename) |
| Date/time | [`timestamp`](https://developer.hashicorp.com/terraform/language/functions/timestamp) [`plantimestamp`](https://developer.hashicorp.com/terraform/language/functions/plantimestamp) [`timeadd`](https://developer.hashicorp.com/terraform/language/functions/timeadd) [`timecmp`](https://developer.hashicorp.com/terraform/language/functions/timecmp) [`formatdate`](https://developer.hashicorp.com/terraform/language/functions/formatdate) |
| Hash/crypto | [`sha256`](https://developer.hashicorp.com/terraform/language/functions/sha256) [`md5`](https://developer.hashicorp.com/terraform/language/functions/md5) [`bcrypt`](https://developer.hashicorp.com/terraform/language/functions/bcrypt) [`filesha256`](https://developer.hashicorp.com/terraform/language/functions/filesha256) [`uuid`](https://developer.hashicorp.com/terraform/language/functions/uuid) [`uuidv5`](https://developer.hashicorp.com/terraform/language/functions/uuidv5) |
| IP network | [`cidrhost`](https://developer.hashicorp.com/terraform/language/functions/cidrhost) [`cidrsubnet`](https://developer.hashicorp.com/terraform/language/functions/cidrsubnet) [`cidrsubnets`](https://developer.hashicorp.com/terraform/language/functions/cidrsubnets) [`cidrnetmask`](https://developer.hashicorp.com/terraform/language/functions/cidrnetmask) |
| Type conversion | [`tostring`](https://developer.hashicorp.com/terraform/language/functions/tostring) [`tonumber`](https://developer.hashicorp.com/terraform/language/functions/tonumber) [`tobool`](https://developer.hashicorp.com/terraform/language/functions/tobool) [`tolist`](https://developer.hashicorp.com/terraform/language/functions/tolist) [`tomap`](https://developer.hashicorp.com/terraform/language/functions/tomap) [`toset`](https://developer.hashicorp.com/terraform/language/functions/toset) [`try`](https://developer.hashicorp.com/terraform/language/functions/try) [`can`](https://developer.hashicorp.com/terraform/language/functions/can) [`type`](https://developer.hashicorp.com/terraform/language/functions/type) [`sensitive`](https://developer.hashicorp.com/terraform/language/functions/sensitive)/[`nonsensitive`](https://developer.hashicorp.com/terraform/language/functions/nonsensitive) |

A few in the console to make the shapes concrete:

```
> merge({ env = "dev" }, { env = "prod", team = "sre" })   # later keys win
{
  "env" = "prod"
  "team" = "sre"
}
> split("-", "dev-web-01")
tolist([
  "dev",
  "web",
  "01",
])
> join("/", ["a", "b", "c"])
"a/b/c"
> jsonencode({ name = "web", replicas = 3 })
"{\"name\":\"web\",\"replicas\":3}"
```

!!! info "`convert()` — Terraform 1.15, Terraform-only"
    Terraform **1.15** added `convert(value, type)` for precise inline conversion to any type constraint, e.g. `convert(var.x, list(string))` — more flexible than the fixed `toType` casters. **OpenTofu has no `convert()`** as of 1.12 ([open request](https://github.com/opentofu/opentofu/issues/2630)); portable code sticks to `tostring`/`tonumber`/`tolist`/etc., which both tools have.

### `try` vs `coalesce` vs `lookup` — the three that get confused

They all appear near "default values," but they solve different problems:

| Function | Handles | Returns |
|---|---|---|
| `coalesce(a, b, ...)` | value is **null or empty** (evaluates fine) | first non-null / non-empty argument |
| `try(a, b, ...)` | expression **errors** during evaluation | first argument that evaluates without error |
| `lookup(map, key, default)` | key may be **missing** from a map | the value, or the default |

```
> coalesce(null, "", "fallback")                      # skip null AND "", take first real value
"fallback"
> try(tonumber("not-a-number"), -1)                   # tonumber ERRORS → fall through
-1
> lookup({ small = "t3.micro" }, "large", "t3.small") # key "large" MISSING → default
"t3.small"
> try(null, "x")                                      # null is a SUCCESS for try, not an error
null
```

!!! tip "Normalize once in locals; keep `try` for real errors"
    `null` is a *valid value*, not an error — `try` returns it as a success rather than moving on, so if you also want null treated as missing, wrap it: `coalesce(try(x, null), default)`. The clean pattern: normalize uncertain inputs **once, in a `locals` block**, and let the rest of the module consume predictable values.

    You'll see it claimed that every argument to `try` must share a type. Not so — `try` returns the first argument that evaluates, whatever its type:

    ```
    > try(tonumber("nope"), "a-string")
    "a-string"
    > try(tonumber("nope"), [1, 2])
    [
      1,
      2,
    ]
    ```

    Matching types is still a good idea, because whatever consumes the result has to accept every shape `try` might hand it — but it's your design constraint, not a rule Terraform enforces. `can(expr)` — which returns a bool instead of a value — belongs almost exclusively inside `validation` conditions; anywhere else you probably want `try`.

### Building conditions (the `can`/`contains`/`alltrue` cookbook)

These feed `validation` blocks (Ch 6) and pre/postconditions (Ch 19):

```hcl
condition = contains(["STAGE", "PROD"], var.environment)          # one of a set
condition = length(var.items) != 0                                # non-empty (prefer over == [])
condition = can(regex("^[a-z]+$", var.name))                      # matches a pattern (can → bool)
condition = alltrue([for v in var.instances : contains(["t3.micro", "t3.small"], v.type)])
```

`can()` turns an expression that would normally *error* (like `regex` on no match) into a plain `true`/`false`.

---

## 7. Strings and templates

String literals are the most-used and most complex literal. Two forms, both supporting embedded expressions.

**Interpolation — `${ ... }`** evaluates an expression, converts it to a string, and inserts it:

```hcl
"Hello, ${var.name}!"        # → "Hello, Juan!"
```

**Heredocs** hold multi-line strings. The indented form `<<-` trims the common leading whitespace so the block can sit inside indented HCL:

```hcl
user_data = <<-EOT
  #!/bin/bash
  echo "host: ${var.hostname}"
EOT
```

Convention: an all-caps delimiter starting `EO` (`EOT` = "end of text"). Backslash escapes are **not** interpreted in heredocs — the backslash is literal.

**Directives — `%{ ... }`** add conditionals and loops inside a template. Use the `~` strip marker to drop the surrounding whitespace so the output stays clean:

```hcl
<<-EOT
%{ for ip in aws_instance.web[*].private_ip ~}
server ${ip}
%{ endfor ~}
EOT
```

To emit a **literal** `${` or `%{`, double the first character: `$${` and `%%{`.

!!! tip "For JSON or YAML, encode — don't template"
    Hand-building JSON/YAML with string templates is error-prone and hard to extend. Build an object and let Terraform guarantee valid syntax:

    ```hcl
    locals {
      config = { name = var.name, replicas = var.replicas }
      json   = jsonencode(local.config)   # object → valid JSON string
      yaml   = yamlencode(local.config)   # object → valid YAML
    }
    ```

    For specialty documents like IAM policies, go further and use the dedicated data source (`aws_iam_policy_document`) — it enforces the document's structure and gives clearer errors than a raw string ever will.

### Templates from files — `file`, `templatefile`, and `path.*`

Long strings don't belong inline in a `.tf` file. A cloud-init script or an Nginx config is easier to read, diff, and lint as its own file. Two functions bring one in:

- **`file(path)`** returns a file's contents as a string. No substitution.
- **`templatefile(path, vars)`** is `file` plus rendering: the map you pass becomes the variables available inside the template, so `${}` interpolation and `%{}` directives work exactly as above.

This is where **`path.*`** earns its keep. A relative path would be resolved against whatever directory Terraform happened to run from, so you anchor it explicitly:

| Reference | Points at |
| --- | --- |
| `path.module` | the directory of **the module being evaluated** — use this to read files bundled *inside* a module |
| `path.root` | the directory of the **root** module (the entry point) |
| `path.cwd` | the working directory before any `-chdir` — rarely what you want |

```hcl
resource "aws_instance" "web" {
  # a static file shipped alongside the module
  user_data = file("${path.module}/files/cloud-init.txt")
}

resource "aws_instance" "app" {
  # the same, but rendered with values
  user_data = templatefile("${path.module}/templates/cloud-init.tftpl", {
    hostname = "${var.name}-app"
    services = ["nomad", "consul"]
    backups  = var.enable_backups
  })
}
```

#### Writing the template itself

The template file is where the `${}` and `%{}` syntax from earlier in this section actually lives — that's all a template is. `templates/cloud-init.tftpl`:

```bash
#!/bin/bash
hostname ${hostname}
%{ for svc in services ~}
systemctl enable ${svc}
%{ endfor ~}
```

Render it with the map above and you get:

```
#!/bin/bash
hostname web-01
systemctl enable nomad
systemctl enable consul
```

**The vars map is the template's entire world.** Inside the file you write `${hostname}` — bare. Not `${var.hostname}`: the template cannot see your variables, locals, or resources, only the keys you handed it. Both ways of forgetting that fail loudly, and the error points into the template file at the exact column:

```
# ${var.name} inside the template — "var" is read as a map key that isn't there
vars map does not contain key "var", referenced at ./templates/bad.tftpl:1,3-6

# ${missing} inside the template
vars map does not contain key "missing", referenced at ./templates/miss.tftpl:1,9-16
```

Treat that as the feature it is. A template's inputs are declared at the call site, so you can read the `templatefile` call and know everything the file is allowed to use — no hunting through the template for hidden dependencies on your config.

!!! tip "Name templates `*.tftpl`"
    Terraform renders any file regardless of extension, but `.tftpl` is the recommended convention: *"following this convention will help your editor understand the content and likely provide better editing experience as a result."* You'll also see `.tpl` in older code.

!!! tip "Iterate on templates in `terraform console`"
    Templates are fiddly in exactly one way — whitespace — and the console shows it. It prints a multi-line result as a `<<EOT` heredoc, so every stray blank line is visible. That makes it the fastest way to get `~` strip markers right, without an apply:

    ```
    > templatefile("${path.module}/templates/servers.tftpl", { xs = ["a","b"] })

    # %{ for s in xs }  — no strip markers
    <<EOT
    servers:

    - a

    - b

    EOT

    # %{ for s in xs ~} — with strip markers
    <<EOT
    servers:
    - a
    - b
    EOT
    ```

    Edit the `.tftpl`, re-run the call, look at the heredoc. The template file is read fresh each time, so unlike config changes you don't need to restart the console.

**`path.module` is almost always the right one.** It keeps a module self-contained: the file travels with the module, so the config works no matter where the caller invokes it from, or how many times. The other two reach *outside* the module and drag the run's circumstances back in (§3), each in its own way.

**`path.root`** resolves to the entry-point directory. A module reading `${path.root}/files/x` only works while the caller keeps that file there — move the module into another config and the path breaks. It's the caller's layout, not yours.

**`path.cwd` is the one that bites.** It's the directory you *invoked* Terraform from — not where the config lives — so it changes when you `cd`. Put it in a resource argument and an unchanged config plans a change purely because you ran it from somewhere else. Same config, same byte-identical file, two runs:

```
# run from the config's own directory
> path.cwd
".../scratchpad/tftest"

# same config, invoked from the parent with -chdir=tftest
> path.cwd
".../scratchpad"          ← changed
> path.root
"."                       ← stable across both
```

That's a phantom diff with no cause a reviewer can see in the code.

!!! warning "Don't use `path.module` for writing files"
    Everything above is about *reading* files that ship with the module. Terraform can also **write** them — not through a function, but with the `local` provider's **`local_file`** resource (`local_sensitive_file` for secrets):

    ```hcl
    resource "local_file" "rendered" {
      filename = "/tmp/cloud-init.yaml"
      content  = templatefile("${path.module}/templates/cloud-init.tftpl", { hostname = "web-01" })
    }
    ```

    Writing *through `path.module`* is where it goes wrong. Local and remote module sources behave differently, and several calls to the same local module share one source directory, so concurrent writes race and overwrite each other. Write to a path the caller controls instead.

    Generating files at all is an escape hatch with its own costs — `local_file` reports itself deleted on any machine where the file isn't present, so it re-creates on every fresh checkout and adds diff noise in CI. Ch 18 covers it with the other escape hatches.

!!! info "`templatestring` — for templates you don't have on disk (OpenTofu first, Terraform 1.9)"
    `templatestring(ref, vars)` renders a template that arrives as a **string at runtime** — from a variable, a local, or a data source — rather than from a file:

    ```
    > templatestring(var.tmpl, { name = "bo", xs = ["a", "b"] })
    "hi bo, count=2"
    ```

    Note the signature: the first argument is a **reference**, not a string literal. Terraform rejects a literal outright — *"templatestring is only for rendering templates retrieved dynamically from elsewhere, and so does not support providing a literal template; consider using a template string expression instead."* Which is fair: if the template is already sitting in your `.tf` file, `"${...}"` interpolation is right there.

    OpenTofu introduced it; **Terraform added it in 1.9**. The old `template_file` *data source* is deprecated — replace it with `templatefile`/`templatestring` on sight.

---

## 8. `for` expressions and splat — the milestone tools

A `for` expression builds one complex value by transforming another. The **bracket** decides the result type: `[ ]` → a tuple, `{ }` → an object.

```
> [for s in ["a", "b", "c"] : upper(s)]        # [ ] → tuple
[
  "A",
  "B",
  "C",
]
> { for s in ["foo", "bar"] : s => upper(s) }  # { } → object
{
  "bar" = "BAR"
  "foo" = "FOO"
}
```

**One name after `for`, or two.** A single name binds the **value** — whatever you're iterating, and even for a map, where you might expect the key:

```
> [for v in { a = "x", b = "y" } : v]
[
  "x",
  "y",
]
```

Add a second name and they **shift** rather than accumulate: the *first* now binds the key or index, the second binds the value. So it's `for key, value`, not `for value, key`.

```
> [for k, v in { a = "x", b = "y" } : "${k}=${v}" ]   # map/object → the key
[
  "a=x",
  "b=y",
]
> [for i, v in ["p", "q"] : "${i}:${v}" ]             # list/tuple → 0-based index
[
  "0:p",
  "1:q",
]
```

A set has neither keys nor indices, so both names land on the same element:

```
> [for k, v in toset(["p", "q"]) : "${k}:${v}" ]      # set → no key, so k is the element too
[
  "p:p",
  "q:q",
]
```

If you want a set's elements, one name is all there is.

An **`if` clause** on the end filters, dropping elements instead of transforming them:

```hcl
{for name, user in var.users : name => user if user.is_admin}   # keep admins only
```

**Ordering.** Converting an unordered type (map, object, set) into an ordered one (list, tuple) forces an implied order: maps/objects and string sets sort lexically by key/value; sets of *other* types get an arbitrary order — wrap the result in `toset()` to signal "unordered."

**Grouping mode.** An object result normally requires **unique** keys. When keys repeat, add `...` after the value expression to collect all values per key into a list:

```
> { for n, u in { am = { role = "dev" }, jb = { role = "dev" }, ps = { role = "ops" } } : u.role => n... }
{
  "dev" = [
    "am",
    "jb",
  ]
  "ops" = [
    "ps",
  ]
}
```

**Splat (`[*]`)** is shorthand for the common `for` that pulls one attribute off a list:

```
> [{ id = "i-1" }, { id = "i-2" }][*].id     # ≡ [for o in var.list : o.id]
[
  "i-1",
  "i-2",
]
```

Splat works on **lists, sets, and tuples only**. This is exactly how you loop over every instance of one resource block — but *only* when the block uses `count`, because a `count` resource is a **tuple** (§3), and a tuple is one of the three splat accepts. A `for_each` resource is an **object**, which is not, so splat does not apply:

```
> terraform_data.web[*].output        # count = 3 -> a tuple, splat works
[
  "web-0",
  "web-1",
  "web-2",
]
> terraform_data.db[*].output         # for_each -> an OBJECT, splat does not
Error: Unsupported attribute
This object does not have an attribute named "output".
```

!!! note "Why that error is so confusing"
    You'd expect "splat doesn't work on that." Instead you get *"This object does not have an attribute named `output`"* — because of splat's single-value rule below. The `for_each` value isn't a list, set, or tuple, so splat treats it as a lone value: it wraps **the whole object** in a one-element tuple, then looks for `.output` **on that object itself**. The object's attributes are your `for_each` keys, not `output`, so the complaint lands on the attribute rather than the splat.

    Note the error says "This **object**" and means it literally. That word is the tell: a `for_each` resource really is an object, which is exactly why splat can't touch it.

Two ways to get the same list from a `for_each` resource. Collapse the object down to just its values first, or skip splat and write the full `for`:

```
> values(terraform_data.db)[*].output
[
  "db-primary",
  "db-replica",
]
> [for k, v in terraform_data.db : v.output]
[
  "db-primary",
  "db-replica",
]
```

Splat has one special trick: on a non-list value it wraps it in a one-element tuple, and on `null` it yields an **empty** tuple — handy for feeding an optional variable into a `dynamic` block's `for_each` ([Ch 12](ch12-dynamic-blocks-complex-types.md)).

### The milestone: list of maps → keyed map → `for_each`

Here is the pattern B7 exists to teach. You receive a **list of objects** (order-sensitive, index-addressed) and you want to drive `for_each`, which needs a **map** (stable string keys). A `for` expression bridges them:

```hcl
variable "buckets" {
  type = list(object({
    name        = string
    versioning  = bool
  }))
  default = [
    { name = "logs",    versioning = true  },
    { name = "uploads", versioning = false },
    { name = "backups", versioning = true  },
  ]
}

locals {
  # list of objects  →  map keyed by the stable "name"
  buckets_by_name = { for b in var.buckets : b.name => b }
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets_by_name       # a map → for_each is happy
  bucket   = "${each.key}-${random_id.suffix.hex}"
}
```

The reshape itself, in the console — a list indexed by position becomes a map keyed by name:

```
> { for b in [{ name = "logs", versioning = true }, { name = "uploads", versioning = false }] : b.name => b }
{
  "logs" = {
    "name" = "logs"
    "versioning" = true
  }
  "uploads" = {
    "name" = "uploads"
    "versioning" = false
  }
}
```

!!! warning "Why not just `for_each = toset(var.buckets)` or a `count`?"
    Because both make deletion dangerous. A `count` over the list addresses instances by **position**, so removing the middle element reindexes every later one and Terraform destroys and recreates resources that didn't change (Ch 5 §5.7, Ch 10). Keying by a **stable string** via the `for`-built map means removing one entry touches only that one resource. This is the whole reason the milestone insists on a *keyed map*, not a list. The `for_each` mechanics themselves are Ch 10.

---

## 🧪 Lab: reshape a list into a keyed map and provision from it

The milestone made concrete: take a list of bucket specs, transform it into a keyed map with a `for` expression, and let `for_each` create one S3 bucket per entry — against the free local **AWS emulator** (Ch 1's [lab setup](ch01-iac-fundamentals.md#lab-setup-a-free-local-aws-docker) — Floci, MiniStack, or LocalStack). S3 is mocked reliably by every emulator.

**Start the emulator** (from the repo root; skip if already running):

```shell
docker compose -f labs/docker-compose.yml up -d      # start the emulator on :4566, detached
curl -s http://localhost:4566/_floci/health     # wait until the services read "running"
```

Write the configuration:

```hcl
# terraform.tf
terraform {
  required_version = ">= 1.15"
  required_providers {
    aws    = { source = "hashicorp/aws",    version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}
```

```hcl
# providers.tf — plain AWS block; tflocal points it at the emulator
provider "aws" {
  region = "us-east-1"
}
```

```hcl
# main.tf
variable "buckets" {
  type = list(object({
    name       = string
    versioning = bool
  }))
  default = [
    { name = "logs",    versioning = true  },
    { name = "uploads", versioning = false },
    { name = "backups", versioning = true  },
  ]
}

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  # THE for EXPRESSION: list of objects -> map keyed by stable name
  buckets_by_name = { for b in var.buckets : b.name => b }

  # a second for, in grouping mode, for an output: versioning flag -> [names]
  names_by_versioning = { for b in var.buckets : b.versioning => b.name... }
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets_by_name
  bucket   = "${each.key}-${random_id.suffix.hex}"
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = { for k, b in local.buckets_by_name : k => b if b.versioning }
  bucket   = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

output "bucket_ids" {
  value = { for k, b in aws_s3_bucket.this : k => b.id }
}

output "names_by_versioning" {
  value = local.names_by_versioning   # { "true" = ["backups","logs"], "false" = ["uploads"] }
}
```

Apply and inspect — note the resource addresses use the **names** as keys, not `[0]`/`[1]`:

```shell
tflocal init
tflocal apply -auto-approve
tflocal state list          # aws_s3_bucket.this["logs"], ["uploads"], ["backups"]
tflocal output              # bucket_ids keyed by name; names_by_versioning grouped
```

Now prove the stability the milestone is about: remove `uploads` from the list and re-plan.

```shell
# edit main.tf: delete the { name = "uploads", ... } entry, then:
tflocal plan                # plan: destroy ONLY aws_s3_bucket.this["uploads"] — the others untouched
```

That surgical plan — one resource destroyed, none reindexed — is the payoff of keying by a stable string. Verify and tear down:

```shell
awslocal s3 ls              # the emulator's buckets, minus uploads once applied
tflocal destroy -auto-approve
```

!!! warning "Emulation is not AWS"
    A green `apply` here proves your **HCL, expressions, and workflow** are correct — not that the config behaves identically on real AWS. The emulator mocks S3's API surface, not every semantic (bucket-name global uniqueness, region constraints, IAM enforcement). Validate any load-bearing config against real free-tier AWS before trusting it.

---

## Common pitfalls

- **`==` with mismatched types.** `"15" == 15` is `false`; equality never converts. Cast first.
- **`var.list == []`.** Always false — `[]` is a `tuple`, not a `list`. Use `length(...) == 0`.
- **Impure functions in config.** `uuid()`/`timestamp()` in a resource argument = perpetual diff. Use the `random`/`time` providers for stable values.
- **Ternary branch types.** Both branches must be **type-compatible** (checked unconditionally — `true ? 1 : ["a"]` errors). Runtime errors, though, only fire in the branch actually *taken*, so guard the branch you might select with `try`, not "both."
- **`for_each` on a computed value.** The map/set must be fully known at plan time — no resource IDs, nothing `(known after apply)`.
- **`count` over a list you'll edit.** Reindex-on-delete destroys unrelated resources. Build a keyed map with `for` and use `for_each`.
- **`try` where you meant `coalesce`.** `try` catches *errors*; `coalesce` catches *null/empty*. `null` is a successful result for `try`.
- **Splat on a `for_each` resource.** It's a map, not a list — splat won't apply, and the error misleadingly reads `Unsupported attribute` rather than mentioning splat. Use `values(...)[*]` first, or a full `for`. (Splat over a `count` resource works fine — that's a list.)
- **Trying to iterate a resource *type*.** `[for r in aws_instance : r]` is an `Invalid reference` — HCL has no reflection over types. Enumerate with `terraform state list` / `terraform show -json` instead.
- **Hand-templated JSON/YAML.** Use `jsonencode`/`yamlencode` (or `aws_iam_policy_document`) so the syntax is guaranteed.

---

## Exercises

1. **Recall.** Without running it, what does `"true" == true` evaluate to, and why? How do you make the comparison succeed?
2. **Apply.** Given `var.users` as a `map(object({ role = string }))`, write a `for` expression producing a map from **role → list of usernames** in that role.
3. **Apply.** Rewrite `count = length(var.names)` (over a list of names) as a `for_each` keyed by name, and explain what changes in the plan when you delete a middle name.
4. **Extend.** A module input `var.website` is an `object` defaulting to `null`. Write the `for_each` expression that produces one `dynamic "website"` block when it's set and zero when it's null. (Hint: splat.)
5. **Debug.** A colleague's plan shows a tag changing on every run despite no edits. The tag is `{ deployed_at = timestamp() }`. Explain the bug and give the fix.

---

## Summary

- Expressions add computation to a declarative language: everything right of `=` is one.
- Every value has a **type**; Terraform auto-converts widely, but **`==` never does** — cast explicitly.
- **References** name values and *create dependency edges*; `count`/`for_each` cannot reference unknown (`(known after apply)`) values.
- The **ternary** branches must be **type-compatible** (an unconditional check); a branch's runtime error only fires when that branch is taken, so guard the branch you might select with `try`.
- **Functions transform, never act.** Know `merge`/`lookup`/`coalesce`/`try`/`toset`/`jsonencode`, keep impure functions out of resource config, and reach for `try` on *errors* vs `coalesce` on *null*.
- **Strings** interpolate with `${}`, loop/branch with `%{}` directives, and structured formats should be `jsonencode`d, not hand-built. Long content lives in its own file, read with `file()`/`templatefile()` anchored at **`path.module`** so the module stays self-contained.
- The headline skill: a **`for` expression turns a list of maps into a keyed map** that drives `for_each` — stable string keys, so editing the list is surgical, not destructive.

Chapter 8 turns to **data sources** — reading infrastructure Terraform doesn't manage — which are the other common source of the values these expressions reshape.

## References

- HashiCorp Docs — [Expressions](https://developer.hashicorp.com/terraform/language/expressions) · [Types](https://developer.hashicorp.com/terraform/language/expressions/types) · [References](https://developer.hashicorp.com/terraform/language/expressions/references) · [Operators](https://developer.hashicorp.com/terraform/language/expressions/operators) · [Conditionals](https://developer.hashicorp.com/terraform/language/expressions/conditionals) · [Strings](https://developer.hashicorp.com/terraform/language/expressions/strings) · [For](https://developer.hashicorp.com/terraform/language/expressions/for) · [Splat](https://developer.hashicorp.com/terraform/language/expressions/splat) · [Function calls](https://developer.hashicorp.com/terraform/language/expressions/function-calls) · [Built-in functions](https://developer.hashicorp.com/terraform/language/functions)
- Reading notes: [[tf-expressions]], [[tf-expr-types]], [[tf-expr-type-constraints]] (constraint forms; the schema rules themselves are Ch 12), [[tf-expr-references]], [[tf-expr-operators]], [[tf-conditionals]], [[tf-expr-strings]], [[tf-expr-for]], [[tf-expr-splat]], [[tf-expr-function-calls]], [[tf-functions]] · *Terraform in Depth* Ch 4 ([[04-expressions-iterations]]) · [[tut-variables]] (console workflow)
- Primary sources for §2 — HCL [information model spec](https://github.com/hashicorp/hcl/blob/main/spec.md) (the Structural Types / Collection Types definitions and the type-identity rules quoted above) · HCL [native syntax spec](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md) ("Only tuple and object values can be directly constructed via native syntax") · `cty` [type conversion](https://github.com/zclconf/go-cty/blob/main/docs/convert.md) (unification, and the conversion charts marking tuple → set "safe+lossy") · `cty` [types](https://github.com/zclconf/go-cty/blob/main/docs/types.md)
- Version facts: [[version-facts]], [[tf115-ot112-features]], [[conditional-branch-evaluation]] (the B7 verification record: ternary evaluation, short-circuit versions, function count, sensitivity propagation, tested against 1.15.6 / OpenTofu 1.12.4; plus why only tuple and object have literals, tested against 1.15.8 with the HCL spec, the `cty` docs, and the Terraform source)
- 🧪 Lab: [Floci Facts](../research-cache/floci-facts.md) · [MiniStack Facts](../research-cache/ministack-facts.md) · [LocalStack Facts](../research-cache/localstack-facts.md)
