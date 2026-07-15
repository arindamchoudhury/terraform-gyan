# Chapter 7 — Expressions, operators & built-in functions

> Everything to the right of an `=` is an **expression** — the part of HCL that *computes* rather than merely *declares*. This chapter is where a configuration stops being a static list of literals and starts adapting: choosing values with conditionals, reshaping data with `for` expressions and the function library, and building strings from templates. It closes on the milestone that expressions exist to serve — turning a list of maps into a keyed map that drives resource creation.
>
> **Blends:** HashiCorp docs (Expressions section: types, references, operators, strings, function-calls, for, splat; Conditionals; the Built-in Functions catalogue) · *Terraform in Depth* Ch 4 (Hafner) · the `terraform console` tutorial workflow · current best-practice guidance on `try`/`coalesce` and `for_each` stability.
>
> **See also:** builds on [Ch 6 — variables, outputs & locals](ch06-input-variables-outputs-locals.md) (where you assign the values this chapter computes); the `for`-produced map feeds Ch 10 (meta-arguments `count`/`for_each`, I1); complex `type` constraints and `dynamic` blocks are Ch 12 (I3). Both are forthcoming.

## Learning outcomes

By the end you can:

- Read any expression and predict its type, including where Terraform auto-converts and where it refuses to.
- Reference every kind of named value (`var`, `local`, resource, `data`, `module`, `path.*`, `each`) and know that a reference *is* a dependency edge.
- Branch with the ternary safely, knowing both branches must share a type but only the taken one is evaluated.
- Reach for the right function — `merge`, `lookup`, `coalesce`, `try`, `toset`, `jsonencode` — and know `try` from `coalesce`.
- Build strings with interpolation, heredocs, and template directives, and know when to `jsonencode` instead.
- **Transform a list of maps into a keyed map with a `for` expression and use it to drive `for_each`.**

---

## 1. Why expressions: adding logic to a declarative language

A configuration full of literals can only ever describe one thing. The moment you want *the same code* to produce a dev environment and a prod environment, name three instances distinctly, or attach a policy only when a flag is set, you need to **compute** values rather than type them out. Expressions are how a declarative language stays DRY.

An expression is anything that resolves to a value: a literal (`"hello"`, `5`, `true`), a reference (`var.region`), an operator chain (`var.count * 2`), a function call (`merge(a, b)`), a conditional, a `for`, or a splat. Every argument in every block is one.

!!! tip "Live-test everything in `terraform console`"
    The single most useful habit for this chapter: open the REPL with `terraform console` (`tofu console`) and type expressions against your real variables and state. It evaluates and prints the result immediately — the fastest way to build intuition for the function library, `for` transforms, and type conversion.

    ```
    > max(5, 12, 9)
    12
    > [for s in ["a", "b"] : upper(s)]
    ["A", "B"]
    ```

    One gotcha: the console loads config **only at startup**. Edit a `.tf` file and you must restart the console to see the change.

---

## 2. Types and values

Every value has a type, and the type decides where the value is legal and how it converts.

**Primitives:** `string` (`"hello"`), `number` (`15` or `6.283`), `bool` (`true`/`false`).

**Complex (collection / structural) types:**

| Family | Ordered? | Keys | Element types |
|---|---|---|---|
| `list` / `tuple` | yes (index from 0) | integer index | one type (`list`) / per-position (`tuple`) |
| `set` | no | none | one type, no duplicates |
| `map` / `object` | no | string labels | one type (`map`) / per-key (`object`) |

**The typeless value — `null`.** `null` means "absent." Setting a resource argument to `null` makes Terraform behave as if you omitted it entirely: it falls back to the argument's default, or errors if the argument is required. That makes `null` the tool for *conditionally omitting* an argument.

```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = "t3.micro"
  # supply a key name only if the caller gave one; otherwise omit the argument
  key_name      = var.key_name != "" ? var.key_name : null
}
```

**Accessing elements.** Square brackets index lists (`local.list[3]`) and maps (`local.map["key"]`); dot notation reaches object attributes with identifier-safe names (`local.obj.name`). Sets have **no index** — convert to a list first with `tolist()` if you need positional access. Watch it in the console:

```
> ["a", "b", "c"][1]
"b"
> { name = "John", age = 52 }.name
"John"
> tolist(toset(["b", "a", "b"]))    # set → list: deduped and sorted
tolist([
  "a",
  "b",
])
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

A resource reference's *shape* depends on its meta-arguments: with neither `count` nor `for_each` it's a single **object**; with `count` it's a **list** of instance objects (`aws_instance.web[0].id`); with `for_each` it's a **map** (`aws_instance.web["a"].id`).

!!! note "References look like objects but aren't"
    The dotted paths resemble attribute access, but you cannot treat the prefix as a real object. You cannot iterate `aws_instance` to "loop over all instances," and you cannot swap dot notation for bracket notation on the fixed parts of the path. Use them exactly as written.

!!! info "A reference *is* a dependency edge"
    When one block's argument references another resource's attribute, Terraform records an **implicit dependency** and orders the graph accordingly (Ch 3, Ch 5). This is the preferred way to express ordering — reach for `depends_on` only when there's genuinely no attribute to reference (Ch 10).

**Use `path.*` and `terraform.workspace` sparingly.** They bake *where* a config runs into the config itself, which hurts module portability. A shared module that needs a unique prefix should take it as an input variable; the root caller supplies it:

```hcl
module "app" {
  source      = "./modules/app"
  name_prefix = "app-${terraform.workspace}"   # workspace used at the ROOT, passed in
}
```

### Values not yet known

During `plan`, some attributes aren't decided yet — a generated ID, an assigned IP. Terraform fills them with an **unknown value** placeholder, rendered as `(known after apply)`. It propagates: known + unknown = unknown.

!!! warning "`count`/`for_each` cannot be unknown"
    Terraform must evaluate `count` and `for_each` *during* plan to know how many instances to graph. So their values **cannot** depend on anything `(known after apply)` — no resource IDs, no computed attributes. This is the single biggest constraint on iteration, and Ch 5 §5.7 shows exactly how it fails. The fix is to key off inputs and locals, never resource outputs.

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
| Logical | `&&` `\|\|` `!` | bool → bool |

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

!!! info "`&&` and `\|\|` short-circuit — OpenTofu 1.10, Terraform 1.12"
    Historically both sides of a logical operator were always evaluated, so a null-guard like `var.foo != null && var.foo.enabled` still **errored** when `var.foo` was null. Now the right side is skipped once the left decides the result, making that guard safe. **OpenTofu shipped it first in 1.10; Terraform followed in 1.12.** This is boolean-only — the ternary `? :` still checks both result branches (§5).

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

**Both result values must share a type.** So Terraform can determine the expression's return type without knowing the condition. If they differ, it hunts for a common type and auto-converts — note the `12` comes back **quoted**, because the branches unified to `string`:

```
> true ? 12 : "hello"
"12"
```

When the result type is uncertain, be explicit: `var.x ? tostring(12) : "hello"`.

!!! warning "Both branches must share a type — but only the taken branch is evaluated"
    Two separate rules, often conflated. The **type** rule is unconditional: both result values must be type-compatible, and Terraform checks that regardless of the condition so it can know the expression's type. `true ? 1 : ["a"]` fails at plan with *"Inconsistent conditional result types"* even though the `true` branch is perfectly fine.

    A branch's **runtime** error is different. An out-of-range index, indexing a `count = 0` resource, a division by zero — these surface **only when that branch is the one selected.** The untaken branch is not evaluated, even when the condition is unknown at plan time. Verified on Terraform 1.15.6:

    ```
    > true  ? "safe" : [1,2,3][5]      # untaken bad index → no error
    "safe"
    > false ? [1,2,3][5] : "safe"      # untaken bad index → no error
    "safe"
    ```

    So guard the branch you might **take**, not "both." `try` is the tool when the branch you select could itself error:

    ```hcl
    output "nat_ip" {
      # if use_instance is true, the module[0] index it TAKES must be safe
      value = var.use_instance ? try(module.nat_instance[0].ip, null) : module.nat_gateway[0].ip
    }
    ```

    Older material — *Terraform in Depth* (2025) and pre-1.x guidance — says Terraform "evaluates both results," so a `count = 0` index in the *unused* branch would error. That is not the behavior on current Terraform; only the type check is unconditional. (Not re-verified on OpenTofu — don't assume identical.) See [[conditional-branch-evaluation]].

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
    If any argument is a `sensitive` variable or attribute, the call's result is marked sensitive too — conservatively, regardless of the function. `keys(a_map_with_one_sensitive_value)` returns a `(sensitive value)`. Useful to know when a value mysteriously starts printing redacted.

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

There are ~150 functions; you learn the *skill* of finding one, not the whole list by heart. The categories:

| Category | Representative functions |
|---|---|
| Numeric | [`min`](https://developer.hashicorp.com/terraform/language/functions/min) [`max`](https://developer.hashicorp.com/terraform/language/functions/max) [`abs`](https://developer.hashicorp.com/terraform/language/functions/abs) [`ceil`](https://developer.hashicorp.com/terraform/language/functions/ceil) [`floor`](https://developer.hashicorp.com/terraform/language/functions/floor) [`pow`](https://developer.hashicorp.com/terraform/language/functions/pow) [`parseint`](https://developer.hashicorp.com/terraform/language/functions/parseint) [`signum`](https://developer.hashicorp.com/terraform/language/functions/signum) |
| String | [`format`](https://developer.hashicorp.com/terraform/language/functions/format) [`join`](https://developer.hashicorp.com/terraform/language/functions/join) [`split`](https://developer.hashicorp.com/terraform/language/functions/split) [`replace`](https://developer.hashicorp.com/terraform/language/functions/replace) [`substr`](https://developer.hashicorp.com/terraform/language/functions/substr) [`lower`](https://developer.hashicorp.com/terraform/language/functions/lower)/[`upper`](https://developer.hashicorp.com/terraform/language/functions/upper)/[`title`](https://developer.hashicorp.com/terraform/language/functions/title) [`trimspace`](https://developer.hashicorp.com/terraform/language/functions/trimspace) [`startswith`](https://developer.hashicorp.com/terraform/language/functions/startswith)/[`endswith`](https://developer.hashicorp.com/terraform/language/functions/endswith) [`regex`](https://developer.hashicorp.com/terraform/language/functions/regex)/[`regexall`](https://developer.hashicorp.com/terraform/language/functions/regexall) |
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
    `null` is a *valid value*, not an error — `try` returns it as a success rather than moving on, so if you also want null treated as missing, wrap it: `coalesce(try(x, null), default)`. All arguments to `try` must share a type. The clean pattern: normalize uncertain inputs **once, in a `locals` block**, and let the rest of the module consume predictable values. `can(expr)` — which returns a bool instead of a value — belongs almost exclusively inside `validation` conditions; anywhere else you probably want `try`.

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

!!! info "`templatefile` and OpenTofu's `templatestring`"
    `templatefile(path, vars)` reads a file and renders it as a template with the given variables — the standard way to produce cloud-init or config files. `templatestring(str, vars)` does the same but takes the template as a **string** (from a variable or data source) instead of a path. OpenTofu introduced `templatestring` first; **Terraform added it in 1.9**. The old `template_file` *data source* is deprecated — replace it with these on sight.

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

Add a second loop symbol to get the key (maps/objects) or index (lists), and an `if` clause to filter:

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

Splat works on **lists, sets, and tuples only** — a `for_each` resource is a *map*, so use `values(aws_instance.web)[*].id` or a full `for`. Splat has one special trick: on a non-list value it wraps it in a one-element tuple, and on `null` it yields an **empty** tuple — handy for feeding an optional variable into a `dynamic` block's `for_each` (Ch 12).

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
curl -s http://localhost:4566/_localstack/health     # wait until services read "available"
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
- **Ternary branch types.** Both branches must be **type-compatible** (checked unconditionally — `true ? 1 : ["a"]` errors). Runtime errors, though, only fire in the branch actually *taken* (verified TF 1.15.6), so guard the branch you might select with `try`, not "both."
- **`for_each` on a computed value.** The map/set must be fully known at plan time — no resource IDs, nothing `(known after apply)`.
- **`count` over a list you'll edit.** Reindex-on-delete destroys unrelated resources. Build a keyed map with `for` and use `for_each`.
- **`try` where you meant `coalesce`.** `try` catches *errors*; `coalesce` catches *null/empty*. `null` is a successful result for `try`.
- **Splat on a `for_each` resource.** It's a map, not a list — splat won't apply. Use `values(...)` first, or a full `for`.
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
- **Strings** interpolate with `${}`, loop/branch with `%{}` directives, and structured formats should be `jsonencode`d, not hand-built.
- The headline skill: a **`for` expression turns a list of maps into a keyed map** that drives `for_each` — stable string keys, so editing the list is surgical, not destructive.

Chapter 8 turns to **data sources** — reading infrastructure Terraform doesn't manage — which are the other common source of the values these expressions reshape.

## References

- HashiCorp Docs — [Expressions](https://developer.hashicorp.com/terraform/language/expressions) · [Types](https://developer.hashicorp.com/terraform/language/expressions/types) · [References](https://developer.hashicorp.com/terraform/language/expressions/references) · [Operators](https://developer.hashicorp.com/terraform/language/expressions/operators) · [Conditionals](https://developer.hashicorp.com/terraform/language/expressions/conditionals) · [Strings](https://developer.hashicorp.com/terraform/language/expressions/strings) · [For](https://developer.hashicorp.com/terraform/language/expressions/for) · [Splat](https://developer.hashicorp.com/terraform/language/expressions/splat) · [Function calls](https://developer.hashicorp.com/terraform/language/expressions/function-calls) · [Built-in functions](https://developer.hashicorp.com/terraform/language/functions)
- Reading notes: [[tf-expressions]], [[tf-expr-types]], [[tf-expr-references]], [[tf-expr-operators]], [[tf-conditionals]], [[tf-expr-strings]], [[tf-expr-for]], [[tf-expr-splat]], [[tf-expr-function-calls]], [[tf-functions]] · *Terraform in Depth* Ch 4 ([[04-expressions-iterations]]) · [[tut-variables]] (console workflow)
- Version facts: [[version-facts]], [[tf115-ot112-features]]
- 🧪 Lab: [Floci Facts](../research-cache/floci-facts.md) · [MiniStack Facts](../research-cache/ministack-facts.md) · [LocalStack Facts](../research-cache/localstack-facts.md)
