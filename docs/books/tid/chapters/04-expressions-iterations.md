# Chapter 4 — Expressions and iterations

> *Source: Hafner (2025), **Terraform in Depth**, Chapter 4, pages 88–122.*
>
> Everything to the right of an `=` is an **expression**. This chapter adds *logic* to the declarative language: **operators** (math/comparison/boolean/ternary), the **function** library, **string templates**, **regular expressions**, **type conversion**, `try`/`can`, and the three ways to iterate — **`count`**, **`for_each`**, and the **`for`** expression — plus **`dynamic` blocks** and the **splat** operator. The whole chapter is framed by one running story: four teams file feature requests against the Ch2/Ch3 EC2 module, and each request is solved with one of these tools.
>
> 📌 **Notes adapted where version-bound.** Book written 2025; current stable is Terraform CLI **1.15.7** / OpenTofu **1.12.3** — see [[version-facts]]. Drift flagged inline: (1) **provider-defined functions** — OpenTofu shipped them in **1.7**, Terraform in **1.8** (the book says "both 1.8"); (2) `templatestring` — OpenTofu shipped it first, Terraform added it in **1.9.0**; (3) Terraform **1.15** added a `convert()` built-in for inline type conversion (§4.6). Conceptual content — operators, functions, iteration — is unaffected.

> 🔗 **See also:** feeds learning-path **B7** (expressions, operators, functions), **I1** (`count`/`for_each`), and **I3** (dynamic blocks & complex types). Builds on Ch3's [[modules]] and type system.

!!! note "`terraform console` — test expressions interactively"
    Every expression in this chapter can be tried in a REPL: `terraform console` (`tofu console`) opens an interface where you type functions, formulas, and expressions and see them evaluate against the current state/variables. The fastest way to build intuition for the function library and the `for`/splat forms.

---

## 4.1 Expanding our module (the running example)

The Ch2/Ch3 EC2 module succeeded, so four teams filed feature requests:

1. Give the instance **IAM permissions** to reach other AWS services (S3, etc.), self-service.
2. Enable **Session Manager** (log in without managing SSH keys).
3. Launch **multiple instances** from one module call.
4. **Name** instances so they're findable in the AWS Console.

The point of the section isn't AWS — it's that each request maps to a language feature introduced later in the chapter. The chapter's real lesson is the **research-first workflow** (Fig 4.1): a feature request looks daunting until you read the service docs + provider docs + Stack Overflow, at which point it's usually smaller than feared.

### 4.1.2 Name and tags — `merge()`

Research finding: AWS shows the **`Name` tag** in the console. Rather than a bare `name` variable, expose a general `tags` input *and* a `name_prefix` (a prefix, not a name, because request #3 wants many instances with unique names).

```hcl
variable "name_prefix" { type = string }
variable "tags" {
  type    = map(string)
  default = {}
}

resource "aws_instance" "hello_world" {
  # ...
  tags = merge(var.tags, {                       # merge user tags with our own
    Name = "${var.name_prefix}-instance"
  })
}
```

`merge(a, b, …)` combines maps; later keys win on collision. This is the standard pattern for "let the caller add tags, but always set our own."

### 4.1.3 Multiple instances — `count`

The **`count` meta parameter** (on `resource` *and* `module` blocks) takes an integer N and creates N instances of the block. Inside the block, **`count.index`** is a zero-based index unique to each instance — perfect for unique names.

```hcl
variable "instance_count" {
  type    = number
  default = 0
}

resource "aws_instance" "hello_world" {
  count         = var.instance_count
  # ...
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${count.index}"    # example-0, example-1, …
  })
}
```

`count` also works on the **`module`** block, so callers could already have launched N copies by putting `count` on the module call — but pushing it *inside* the module reduces duplicated resources (one role/profile shared, N instances).

!!! note "(mine) — book listing 4.2 has a copy-paste bug"
    The book's validation on `instance_count` reads `condition = can(parseint(tostring(var.my_integer), 10))` — it references **`var.my_integer`**, a leftover from Ch3's listing. Against a variable named `instance_count` that won't even parse. The correct pair of checks:

    ```hcl
    validation {
      condition     = can(parseint(tostring(var.instance_count), 10))
      error_message = "The instance count must be a whole number."
    }
    validation {
      condition     = var.instance_count >= 0
      error_message = "The instance count can not be negative."
    }
    ```

### 4.1.4 An IAM role — return it, don't over-configure it

Request #1 (permissions) is unbounded: AWS has thousands of services, so a module can't enumerate every policy. The design lesson: **give users a hook, not a menu.** Every instance that needs IAM requires two resources — `aws_iam_role` + `aws_iam_instance_profile` — so create those inside the module, but **output the role** so callers attach their own policies.

```hcl
data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]      # only EC2 may assume this role
    }
  }
}

resource "aws_iam_role" "main" {
  name               = "${var.name_prefix}-instance-role"   # prefix keeps it unique
  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json
}

resource "aws_iam_instance_profile" "main" {
  name = aws_iam_role.main.name
  role = aws_iam_role.main.name
}

output "aws_instance_role" {                   # the hook: callers attach policies here
  value = aws_iam_role.main
}
```

!!! note "Why a data source for the policy, not a heredoc string"
    `aws_iam_policy_document` is a **helper data source** that builds the policy JSON from HCL `statement`/`principals` blocks. It's preferred over hand-writing the JSON (or templating it) because it validates structure and follows AWS's current format — the same lesson §4.4 makes about `jsonencode` over string templates.

### 4.1.5 Session Manager — `count` as an on/off toggle

Request #2 needs an AWS-managed policy attached to the role — but only if the user wants it. Look the managed policy up with a data source, then attach it conditionally using the **ternary + `count`** idiom:

```hcl
variable "enable_systems_manager" {
  type    = bool
  default = false
}

data "aws_iam_policy" "ssm_arn" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedEC2InstanceDefaultPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  count      = var.enable_systems_manager ? 1 : 0     # 1 = create, 0 = skip
  role       = aws_iam_role.main.name
  policy_arn = data.aws_iam_policy.ssm_arn.arn
}
```

`count = bool ? 1 : 0` converts a boolean into "create this resource or don't." It's *the* most common way to make an optional feature in a module — a cleaner interface than asking the caller for a number. (Detailed in §4.2.4.)

---

## 4.2 Operators and conditionals

Operators are symbols representing an action. Terraform's let you do math, compare values, evaluate boolean logic, and branch.

### Math

| Operator | Meaning | Example | Result |
|---|---|---|---|
| `+` | addition | `5 + 4` | `9` |
| `-` | subtraction | `10 - 5` | `5` |
| `*` | multiplication | `5 * 5` | `25` |
| `/` | division | `40 / 10` | `4` |
| `%` | modulus (remainder) | `50 % 9` | `5` |

Exponents, rounding, absolute value etc. aren't operators — they're **functions** (§4.3). Common pattern: clamp a value with `min`/`max`.

```hcl
locals {
  availability_zones = min(var.active_availability_zones, 3)   # never above 3
  needed_subnets     = local.availability_zones * 2            # 2 subnets per AZ
}
```

### Comparison

| Operator | Meaning |
|---|---|
| `==` | equality |
| `!=` | inequality |
| `<` `<=` `>` `>=` | ordering |

!!! warning "Equality is type-sensitive — and does *not* auto-convert"
    Terraform coerces types in many contexts, but **the equality operators `==`/`!=` do not.** The string `"15"` and the number `15` compare **unequal**:

    ```hcl
    "15" == 15            # false  — different types
    "15" != 15            # true
    tonumber("15") == 15  # true   — cast first, then compare
    ```

    If both operands already have a declared type (two typed input variables), you can compare directly. Otherwise cast explicitly with `tonumber`/`tostring` (§4.6). This is why explicit conversion is preferred over relying on implicit coercion.

### Boolean

`||` (OR), `&&` (AND), `!` (negation) — always resolve to a boolean.

```hcl
locals {
  complex_example = var.servers > 15 || var.feature_enabled
}
```

!!! info "`&&` / `||` now short-circuit — OpenTofu 1.10, Terraform 1.12"
    A post-book change. Historically both operands were *always* evaluated, so `var.foo == null || var.foo.bar == 1` still errored when `var.foo` was null. Now the right operand is **skipped once the left decides the result**, so that null-guard is safe — a clean alternative to wrapping the access in `try()` (§4.7). **OpenTofu shipped it first in 1.10** ([#2084](https://github.com/opentofu/opentofu/issues/2084)); **Terraform followed in 1.12** ([#36224](https://github.com/hashicorp/terraform/issues/36224)). Note this is the *boolean operators* only — the **ternary `? :` still type-checks both result branches** (§4.2.4), so short-circuiting doesn't rescue an invalid untaken branch there.

### 4.2.4 Conditional (the ternary)

`condition ? true_result : false_result`. The first operand must be a boolean; the second or third is returned. It's Terraform's `if/then/else`, and the most powerful branching tool in the language. Two dominant uses:

- **Toggle a resource** — `count = var.enabled ? 1 : 0` (as in §4.1.5).
- **Switch between two modules/values** — e.g. NAT Instance vs NAT Gateway: enable one submodule with `count = var.use_nat_instance ? 1 : 0`, the other with the inverse, then pick the output the same way.

```hcl
output "nat_ip_address" {
  value = var.use_nat_instance ? module.nat_instance[0].ip : module.nat_gateway[0].ip
}
```

!!! danger "The untaken branch still has to hold up — guard optional-resource indexing with `try`"
    Terraform returns only the selected branch's value, but **both branches must be valid and type-compatible** — and the book (§4.2.5) frames this as "Terraform evaluates both results." The practical bite: if the *unused* branch references something that isn't there (e.g. `module.nat_instance[0]` when its `count` is 0, an out-of-range index), it can **error even though that branch was never returned.** (Mismatched branch types raise the separate "Inconsistent conditional result types" error.) Guard the risky side with the **`try`** function (§4.7): `try(module.nat_instance[0].ip, null)`.

### Order of operations

Highest → lowest precedence:

1. `!`, unary `-`
2. `*` `/` `%`
3. `+` `-`
4. `>` `>=` `<` `<=`
5. `==` `!=`
6. `&&`
7. `||`

!!! tip "Parenthesize for readability even when it changes nothing"
    `2 + 4 / 5 * var.multiple ? 4 : 9 - 7` is legal but unreadable and easy to break when editing. Add parentheses — `2 + ((4 / 5) * (var.multiple ? 4 : 9 - 7))` — even where they don't alter the result.

---

## 4.3 Functions

Functions have a name, take arguments, and return a value: `name(arg1, arg2, …)`. Arg counts vary — `timestamp()` takes none, `file(path)` takes one, `concat(…)` takes two or more (variadic). Arguments can themselves be expressions, resolved before the call.

**What makes Terraform functions different:** they exist to **transform data**, not to *act*. In an imperative language a function might open a socket or write a file; Terraform is declarative, so all state-changing work belongs to **resources and data sources**. Functions only massage values into the arguments those blocks need.

### 4.3.2 The standard library

Terraform ships a [standard library](https://developer.hashicorp.com/terraform/language/functions) of pure functions, grouped (for docs only) into: Numeric, String, Collection, Encoding, Filesystem, Date/Time, Hash/Crypto, IP network, Type conversion. Worth skimming the list periodically — it grows.

!!! info "OpenTofu — provider-defined functions shipped in OpenTofu 1.7, Terraform 1.8"
    Originally the standard library was the *only* source of functions. Then **providers gained the ability to ship their own**, called `provider::<name>::<function>(…)`. **OpenTofu added them in v1.7; Terraform followed in v1.8** — OpenTofu led here, so the book's "Terraform and OpenTofu v1.8" understates it by a release. Current on 1.15 / 1.12. That it took so long is a non-issue in a declarative language, where nearly all work is done by resources and data sources, not functions. See [[version-facts]].

```hcl
locals {
  is_dev    = startswith(var.environment, "dev-")   # bool: does it start with "dev-"?
  env_name  = split("-", var.environment)[1]        # "dev-web" → ["dev","web"] → "web"
  env_label = upper(local.env_name)                 # "WEB"
}
```

!!! warning "(mine) — `split` argument order (book listing 4.15 has it backwards)"
    The signature is **`split(separator, string)`** — separator **first**. The book prints `split(var.environment, "-")`, which is reversed and would split on the *value* of `var.environment`, not on `"-"`. Correct is `split("-", var.environment)`. Easy footgun to copy; verify against the [function docs](https://developer.hashicorp.com/terraform/language/functions/split).

### Pure vs. impure functions

- **Pure** — same inputs → same output, always (`max`, `merge`, `split`). Most functions.
- **Impure** — output changes each call: `timestamp()`, `uuid()`.

!!! danger "Impure functions cause perpetual diffs"
    In a declarative language, feeding an **impure** function into a resource's configuration means the value differs on every plan — so **Terraform thinks the resource always needs updating.** The workspace is out of date the instant `apply` finishes.

    ```hcl
    resource "aws_instance" "example" {
      tags = { id = uuid() }    # new value every plan → forces a change forever
    }
    ```

    Symptom: changes appear immediately after a clean apply. Fix: don't derive config from `uuid`/`timestamp`. If you need a stable random/time value, use the **`random`** and **`time`** providers (Ch6) — those store the value in state so it stays put.

---

## 4.4 Strings and templates

Ch3 introduced **interpolation** (`"${var.prefix}-service"`), fine for short strings. For large strings Terraform offers files and templates.

### 4.4.1 `file`

`file(path)` reads a file and returns its contents as a string — keeps long blobs (cloud-init scripts, configs) out of your `.tf`. Pair it with the special **`path`** object:

- `path.module` — directory of the module being evaluated (use this to read files bundled *inside* a module).
- `path.root` — directory of the root module.
- `path.cwd` — current working directory (usually, not always, `path.root`).

```hcl
resource "aws_instance" "cloud_init_file" {
  user_data = file("${path.module}/files/cloud-init.txt")
}
```

### 4.4.2 `templatefile`

`templatefile(path, vars)` is `file` **plus** interpolation and iteration. Second argument is a map whose keys become variables available inside the template — used constantly to render config files (Nginx, cloud-init) from a small set of inputs.

```hcl
resource "aws_instance" "template_file" {
  user_data = templatefile("${path.module}/templates/cloud-init.tftpl", {
    services = ["nomad", "consul"],
    backups  = var.enable_backups,
    hostname = "${var.name}-nomad"
  })
}
```

!!! info "OpenTofu — `templatestring` shipped in OpenTofu first"
    `templatestring(string, vars)` works like `templatefile` but takes the template **as a string** instead of a path, so templates can come from variables or other resources. **OpenTofu introduced it; Terraform followed in v1.9.0** — so both tools have it today, but OpenTofu led. See [[version-facts]].

### String template language

Inside a template string, two delimiter styles:

- **`${ … }`** — interpolation / expressions (math, functions, type conversion — anything except calling `templatefile`).
- **`%{ … }`** — *directives*: `if`/`else`/`endif` branches and `for`/`endfor` loops.

```text
%{ if enable_feature }
  feature_flag = 1
%{ else }
  feature_flag = 0
%{ endif }

%{ for key, value in variable_object }
${key} ${value}
%{ endfor }

%{ for value in variable_list }
${value}
%{ endfor }
```

### 4.4.4 The deprecated `template_file` data source

The old `template_file` data source (from the `template` provider) predates `templatefile`. **Deprecated — never use in new code**; replace it with `templatefile`/`templatestring` when you find it. Mentioned only because older modules still contain it.

### When NOT to use templates

!!! tip "For JSON/YAML, encode — don't template"
    If Terraform can natively produce the format, use that instead of building the string by hand. Hand-templated JSON/YAML is error-prone and hard to extend. Build an **object** and convert it:

    ```hcl
    locals {
      config_object = { name = var.name }
      json_config   = jsonencode(local.config_object)   # object → JSON string
      yaml_config   = yamlencode(local.config_object)   # object → YAML string
    }
    ```

    For specialty documents like IAM policies, go one better and use the dedicated **data sources** (`aws_iam_policy_document`, §4.1.4) — they enforce the document's structure and give clearer errors.

---

## 4.5 Regular expressions

Terraform exposes regex through three functions: **`regex`**, **`regexall`**, **`replace`**.

!!! warning "Terraform uses Go (RE2) regex syntax"
    Terraform is written in Go and uses **Go's regexp syntax**. When testing patterns on a site like [regex101](https://regex101.com), select the **Golang** flavor — PCRE features (lookahead/lookbehind, backreferences) don't exist in RE2.

### `regex` — extract or fail

`regex(pattern, string)` returns a match, and **errors** if there's no match. Return *shape* depends on capture groups:

| Capture groups | Returns |
|---|---|
| none | the matched substring (a string) |
| unnamed `(…)` | a **list** of substrings, in definition order |
| named `(?P<name>…)` | a **map** keyed by group name |

```hcl
locals {
  arn       = "arn:aws:ec2:us-west-2:123456789012:instance/i-1234567890abcdef0"
  arn_parts = regex("^\\w+:(?P<partition>\\w+):(?P<service>\\w+):(?P<region>[\\w-]*):(?P<account>\\d{12}):", local.arn)
  arn_account = local.arn_parts["account"]   # "123456789012"
}
```

You must use named **or** unnamed groups consistently — mixing them is an error.

### 4.5.2 `regexall` — every match, never errors

Like `regex` but returns **all** matches as a list (list of strings / list of lists / list of maps by the same capture-group rules). On no match it returns an **empty list** instead of erroring — which is exactly why the `validation`-block idiom uses it:

```hcl
validation {
  condition     = length(regexall("^[a-z]{2}-[a-z]*-\\d$", var.aws_region)) == 1
  error_message = "This value must match the aws region format."
}
```

### 4.5.3 `replace`

`replace(string, search, replacement)`. `search` is a literal string **unless** it's wrapped in slashes, which marks it a regex. With capture groups, the replacement can reference them — `$1`, `$2` for unnamed, `$name` (or `${name}`) for named.

```hcl
locals {
  simple_swap = replace("Hello World!", "Hello", "Goodnight")            # literal
  flexible    = replace("Hello World", "/^[a-zA-Z]*/", "Goodnight")      # regex (slashes)
}
```

---

## 4.6 Type conversion

### Implicit

Terraform auto-converts when it safely can: a numeric string where a number is wanted, `true`/`false` ↔ `"true"`/`"false"`. If it can't, it errors. The exception (again): **`==`/`!=` never auto-convert** — hence prefer explicit conversion.

```hcl
locals {
  long_pi   = 3.14159
  pi_string = substr(local.long_pi, 0, 4)   # substr wants a string → "3.14"
}
```

### 4.6.2 The `toType` functions

Every type has a caster: `tobool`, `tolist`, `tomap`, `tonumber`, `toset`, `tostring`. HashiCorp's guidance: use them mainly to **normalize module outputs** (consistent output types), and to **convert a list to a set** so it can feed `for_each` (§4.8.2).

```hcl
output "feature_enabled" {
  value = tobool(local.enable_flag)   # "true" (string) → true (bool)
}
```

!!! info "Terraform 1.15 — the `convert()` built-in"
    Terraform **1.15** added a general **`convert(value, type)`** function for precise inline conversion to any type constraint, e.g. `convert(var.x, list(string))` — more flexible than the fixed `toType` casters. See [[tf115-ot112-features]].

    **OpenTofu has no `convert()`** (as of 1.12) — it's a genuine divergence. OpenTofu still relies on the `toType` casters (`tostring`/`tonumber`/`tobool`/`tolist`/`tomap`/`toset`); a general `convert` is an open request ([opentofu #2630](https://github.com/opentofu/opentofu/issues/2630)), held up because it interacts poorly with OpenTofu's dependency analysis. The `toType` functions work in both tools and are what the book uses — portable code should prefer them.

### 4.6.3 `sensitive` and `nonsensitive`

The sensitive flag propagates: derive a value from a sensitive one and it, too, is masked — sometimes over-eagerly. Because Terraform is declarative and values are immutable, these functions **don't mutate** anything; they **return a new value** with the flag flipped.

- `sensitive(v)` — return `v` marked sensitive.
- `nonsensitive(v)` — return `v` with the mark removed.

```hcl
resource "random_uuid" "visible_uuid" {}

locals {
  sensitive_uuid = sensitive(random_uuid.visible_uuid.result)   # same value, now masked
}
```

!!! warning "Document every use of `sensitive`/`nonsensitive`"
    Needing `sensitive()` often means an input should have been declared `sensitive = true` in the first place. `nonsensitive()` risks **leaking** a value into logs — only use it when you're certain the value is safe, and leave a comment explaining why. (Masking still affects display only; the value remains plaintext in state — see [[tf-aws-manage]] and Ch3.)

---

## 4.7 `try` and `can`

Both handle expressions you expect might error.

- **`try(expr1, expr2, …)`** — returns the **first argument that doesn't error**. Classic uses: a default for a fallible expression, and safely reading an attribute of an optional (`count = 0 or 1`) resource.

    ```hcl
    output "instance_id" {
      value = try(aws_instance.main[0].id, null)   # null if no instance was created
    }
    ```

- **`can(expr)`** — runs `expr` and returns a **boolean**: `false` if it errored, `true` otherwise. Purpose-built for `validation` conditions and **little else**.

    ```hcl
    validation {
      condition     = can(tonumber(var.number_string))
      error_message = "Although this variable is a string, it is expected to be numeric."
    }
    ```

!!! tip "`can` for validation, `try` almost everywhere else — and never to hide real errors"
    If you reach for `can` outside a `validation` block, you probably want `try`. Neither should paper over a genuine bug — fix the source of the error instead. Legitimate homes: `validation` blocks, some `output` blocks; anywhere else, leave a comment justifying it.

---

## 4.8 `count` and `for_each`

Imperative `while`/`do` loops don't fit a declarative language. Terraform iterates for two purposes:

- **Create many resources from one block** → `count` / `for_each` (meta parameters).
- **Transform a collection into another** → the `for` expression (§4.9).

**At most one** of `count` / `for_each` per block — using both errors.

### `count`

Takes an integer; creates that many instances. Exposes **`count.index`** (0-based) inside the block. Simple and hard to break — good for "N identical things" and on/off toggles.

```hcl
resource "aws_instance" "instances" {
  count         = var.num_instances
  subnet_id     = var.subnet_ids[count.index % length(var.subnet_ids)]   # round-robin over subnets
  instance_type = "t3.micro"
  ami           = data.aws_ami.main.id
}
```

Toggle form: `count = var.enable_resource ? var.num_instances : 0`.

!!! danger "The `count` reindex footgun — prefer `for_each` for named sets"
    `count` instances are addressed **by position** — `aws_instance.instances[0]`, `[1]`, `[2]`. Delete or reorder an item in the **middle** of the list and every instance after it **shifts index**, so Terraform plans to **destroy and recreate** them all to match the new positions — not just the one you removed. `for_each` keys instances by a **stable string** instead, so removing one touches only that one. Rule of thumb (and this book's later chapters + the [style guide](https://developer.hashicorp.com/terraform/language/style)): use `count` only for a simple on/off (`? 1 : 0`) or a genuinely index-identical N; use **`for_each`** for any set of named/keyed resources.

### 4.8.2 `for_each`

Takes a **map**, **object**, or **set** — a collection, not an integer the way `count` does (and not a plain list; see below) — and exposes **`each`** with `each.key` and `each.value`. For a set, key and value are the same element — use whichever reads better (`each.value` when you mean the element as a value; HashiCorp's own docs example uses `each.key`). They're interchangeable for sets; just be consistent. Each instance gets its own configuration:

```hcl
locals {
  machine_configs = {
    "web_server"           = { type = "t3.nano" }
    "background_processor" = { type = "t3.micro" }
  }
}

resource "aws_instance" "for_each" {
  for_each      = local.machine_configs
  subnet_id     = var.subnet_id
  instance_type = each.value.type    # per-instance
  ami           = data.aws_ami.main.id
  tags = { Name = each.key }         # "web_server", "background_processor"
}
```

!!! note "What `each.key` / `each.value` resolve to (map case)"
    For a **map/object**, the two differ (unlike a set): `each.key` is the map key (the string label), `each.value` is the whole value that key points to — reach inside it with `each.value.<attr>`. Per the [official docs](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each): *each.key* = "the map key … corresponding to this instance"; *each.value* = "the map value corresponding to this instance."

    | Instance | `each.key` | `each.value` | `each.value.type` |
    |---|---|---|---|
    | 1 | `"web_server"` | `{ type = "t3.nano" }` | `"t3.nano"` |
    | 2 | `"background_processor"` | `{ type = "t3.micro" }` | `"t3.micro"` |

    This is *why* you reach for a map/object over a set when each instance needs distinct arguments: the key names the instance (→ `aws_instance.for_each["web_server"]`), the value carries its settings.

Passing a **list** to `for_each` errors — convert with **`toset(...)`** first (remember: dedups and drops order):

```hcl
resource "aws_vpc_endpoint" "main" {
  for_each     = toset(local.vpc_endpoints)   # ["s3","dynamodb"] → set
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
}
```

### 4.8.3 Accessing attributes

Resources/modules with `count` or `for_each` are addressed like a collection — by index (`count`) or key (`for_each`), or iterated as a whole:

```hcl
output "first_instance" {
  value = aws_instance.main[0]    # count → index; for_each → aws_instance.main["key"]
}
```

### 4.8.4 The plan-time-known limitation (important)

!!! warning "`count`/`for_each` values must be known at the *start* of plan"
    Terraform has to know how many instances a block makes **before** it reads any resource. The exact rule differs between the two, and the difference is the key to the best workaround:

    - **`count`** — the integer must be **fully known**.
    - **`for_each`** — only the **map keys** (or set members) must be known; the **map values may be `(known after apply)`**. The official [docs](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) are precise: *"The keys of the map (or all values in a set of strings) must be known values."* So the loose mental model "the whole `for_each` value must be known" over-restricts you — it's really just the keys.

    What therefore **can't** be a `count` value or a `for_each` **key**:

    - values derived from **resource attributes** (things `(known after apply)`),
    - data sources that themselves depend on resource attributes (a data source resolvable during the initial refresh is fine),
    - impure functions like `timestamp`/`uuid`.

    Hit one of these and Terraform errors at plan (*"…cannot be determined until apply … a `-target` may be needed"*). The classic trap: keying a map on a computed ID instead of a static name.

**Workarounds** (in order of preference):

- **`for_each`: key on something static, put the apply-time data in the value.** This is the single most useful fix and follows straight from the rule above. Build the map with **keys known at plan** (a name, an environment, a config-derived string) and let the **values** carry the `(known after apply)` attributes:

    ```hcl
    # ✗ errors: keys are computed instance IDs, unknown at plan
    # for_each = { for i in aws_instance.web : i.id => i }

    # ✓ works: keys are the static names you already used to build the instances;
    #   the unknown attribute (private_ip) rides in the value
    resource "aws_route53_record" "web" {
      for_each = { for name, inst in aws_instance.web : name => inst.private_ip }
      # each.key = "web-a" (known at plan)   each.value = the IP (known after apply)
    }
    ```

- **Refactor** so the count/key source is static. Best general fix.
- Store the config in an **intermediate `local`** and drive the block with **`count`** + `count.index` (only the meta-parameter must be known early; the per-instance *config* it pulls from the local can resolve later):

    ```hcl
    resource "aws_instance" "workaround" {
      count     = var.num_instances                      # simple, known early
      subnet_id = element(var.subnet_ids, count.index)   # config resolved later
    }
    ```

- Split the apply into **batches** (`-target`) so dependencies materialize first. The book calls this **"a horrible practice"** — it forfeits Terraform's automatic ordering. Avoid; refactor instead.

!!! info "OpenTofu — same rule, plus `-exclude` as an extra escape hatch"
    The limitation is **identical** in OpenTofu: `for_each` keys (and set members) must be known at plan, values may be `(known after apply)`, and `count` must be fully known — same docs wording, and 1.10/1.11 did **not** relax it (unknown-value/deferred planning is still only a proposal, [opentofu #812](https://github.com/opentofu/opentofu/issues/812)). So the static-keys workaround is the same. The one divergence is at the last-resort level: OpenTofu's error message suggests **`-exclude`** (1.9+, the inverse of `-target`) as well as `-target`, so you can apply *everything except* the not-yet-known object. Terraform's open-source CLI has `-target` only. Same "exceptional use" caveat applies.

!!! note "Where this is heading — **deferred actions** (Terraform-only)"
    The proper fix for a genuinely-unknown `count`/`for_each` is **deferred actions**: instead of erroring, Terraform plans a *placeholder* for the unknown instances and defers their create/update to a **later apply round**, so a two-phase deploy needs no `-target` surgery. It's the productized version of "split the config so the dependency applies first."

    - **Terraform Stacks** (HCP Terraform) ship this in production: a component whose inputs aren't known yet — the classic *provision an EKS cluster, then deploy Kubernetes resources into it* — has its changes deferred, and every downstream component with it, preserving order. Full treatment in **E2**.
    - In the **open-source CLI** it's still **experimental** (`terraform plan -allow-deferral`), not GA as of 1.15.
    - **OpenTofu has no equivalent** — another Terraform/Stacks-exclusive capability, reinforcing the divergence above.

---

## 4.9 The `for` expression

Transforms every item of a collection into a new collection (and can filter). Inputs: anything convertible to a list or object (list, set, tuple, map, object). Outputs: a list **or** an object.

```hcl
[for item in var.list : "prefix-${item}"]   # "for each item, make a new string"
```

### List vs. object inputs

Iterating an **object/map** gives you `key, value`; iterating a **list/set** gives you the value only.

```hcl
locals {
  object_example = [for key, value in var.object : "${key},${value}"]  # both
  list_example   = [for x in var.list : x * 2]                         # value only
}
```

### 4.9.2 List vs. object outputs

**Square brackets `[…]` → list. Curly `{…}` → object**, and an object output needs a `key => value` pair using the special **`=>`** operator.

```hcl
locals {
  as_object = { for x in var.list : x => md5(x) }   # key = item, value = its md5 hash
}
```

!!! note "(mine) — book listing 4.40 typo"
    The book prints `{ for x in var.list : s => md5(s) }` — it binds `x` but uses `s`. The bound variable must match: `{ for x in var.list : x => md5(x) }`.

### 4.9.3 Filtering

An optional trailing `if` keeps only items where the condition is true:

```hcl
locals {
  filtered_list = [for x in var.inputs  : x if x != null]      # drop nulls
  evens_only    = [for x in var.numbers : x if x % 2 == 0]     # even numbers only
}
```

### 4.9.4 Grouping mode

Append an **ellipsis `...`** after the value in an object-producing `for` to allow **repeated keys** — each key then maps to a **list** of all values contributed across iterations. Lets you invert/bucket data in one expression:

```hcl
locals {
  servers_by_subnet = {
    for server in aws_instance.main[*] : server.subnet_id => server.id...
  }   # { "subnet-abc" = ["i-1","i-2"], "subnet-def" = ["i-3"] }
}
```

### 4.9.5 Splat `[*]`

The **splat** expression is shorthand for the most common `for` — pulling one attribute out of a list of objects. Everything splat does, `for` can do; splat just removes boilerplate.

```hcl
locals {
  ids_for   = [for x in var.object_config : x.id]   # verbose
  ids_splat = var.object_config[*].id               # identical, terser
}
```

Two everyday uses:

- Collect an attribute across `count`/`for_each` instances: `module.instances[*].aws_instance_ip` → a list of IPs.
- **Wrap a single value in a one-item list**: `var.security_group_id[*]` turns a lone string into `[string]` — handy when an argument wants a list but you have one item. (Splat on `null` yields `[]`.)

---

## 4.10 Dynamic blocks

HCL **arguments** appear once per block; **subblocks** can repeat. But what if the *number* of subblocks depends on input — e.g. a security group whose ingress rules vary per caller? A **`dynamic` block** generates repeated subblocks from a collection.

It takes the **subblock name as its label**, a **`for_each`**, and a **`content`** sub-subblock holding the generated block's body.

```hcl
variable "security_group_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

resource "aws_security_group" "main" {
  name   = "${var.name}-sg"
  vpc_id = var.vpc_id

  dynamic "ingress" {                        # generates ingress { } subblocks
    for_each = var.security_group_rules
    content {
      description = ingress.value.description   # iterator named after the label
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  ingress {                                  # static and dynamic blocks can coexist
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

!!! warning "`dynamic` has the most confusing syntax in Terraform — by the book's own admission"
    Two things trip people up:

    - The iterator is **not** `each`/`count`. Each `dynamic` block **invents a new keyword named after its label** (`ingress` above), so nested dynamic blocks can reference their parents. Even experienced users look this up.
    - The body must sit inside a **`content { }`** sub-subblock, not directly under `dynamic`.

**Toggle a single block on/off** by switching `for_each` between an empty list and a one-element placeholder list — the value doesn't matter, only whether the list is non-empty:

```hcl
dynamic "ingress" {
  for_each = var.enable_public_https ? ["placeholder"] : []   # [] = no block
  content {
    description = "Enable global access to port 443 (HTTPS)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

---

## Summary

- **Every value right of `=` is an expression.** This chapter adds logic to a declarative language.
- **Operators**: math (`+ - * / %`), comparison (`== != < <= > >=`, type-sensitive, no auto-convert on `==`/`!=`), boolean (`|| && !`), and the **ternary** `c ? a : b` — which **evaluates both branches** (guard with `try`).
- **Functions transform data**, they don't act. Standard library + (since **1.8**, both tools) provider-defined functions. Beware **impure** functions (`uuid`/`timestamp`) — they cause perpetual diffs; use the `random`/`time` providers instead.
- **Strings**: `file` for static blobs, `templatefile` for interpolated/iterated ones (`${…}` expressions, `%{…}` directives), `templatestring` (OpenTofu-led, Terraform 1.9+). For JSON/YAML, **encode** with `jsonencode`/`yamlencode`, don't template.
- **Regex** via `regex` (errors on miss), `regexall` (empty list on miss — used in validation), `replace`. Go/RE2 syntax.
- **Type conversion**: implicit where safe; `toType` casters to normalize; `convert()` in Terraform 1.15 (**Terraform-only — OpenTofu has no `convert()`**); `sensitive`/`nonsensitive` return *new* flagged values.
- **`try`** returns the first non-erroring arg; **`can`** returns a boolean for `validation` conditions. Don't hide real errors.
- **Iteration**: `count` (integer, `count.index`, on/off toggles — but reindexes on middle-delete), `for_each` (map/set/object, `each.key`/`each.value`, stable keys — prefer for named sets). Both must be **known at plan start**. The `for` expression transforms collections (list `[]` or object `{}` with `=>`, `if` filter, `...` grouping); **splat `[*]`** is its shorthand. **`dynamic` blocks** generate repeated subblocks (`for_each` + `content`, label-named iterator).

---

## References

- Terraform functions (standard library): <https://developer.hashicorp.com/terraform/language/functions>
- Expressions (conditionals, `for`, splat, dynamic blocks): <https://developer.hashicorp.com/terraform/language/expressions>
- `count`: <https://developer.hashicorp.com/terraform/language/meta-arguments/count>
- `for_each`: <https://developer.hashicorp.com/terraform/language/meta-arguments/for_each>
- Dynamic blocks: <https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks>
- `templatefile` / string templates: <https://developer.hashicorp.com/terraform/language/functions/templatefile>
- Style guide (count vs for_each guidance): <https://developer.hashicorp.com/terraform/language/style>

---
Related: feeds learning-path **B7** (expressions/operators/functions), **I1** (`count`/`for_each` meta-arguments), **I3** (dynamic blocks & complex types). Builds on TID Ch3's [[modules]] and type system; the `validation` `can()` idiom continues Ch3 §3.7. Version drift tracked in [[version-facts]] and [[tf115-ot112-features]]; OpenTofu `templatestring` history in [[version-facts]]. Meta-argument semantics cross-referenced in [[meta-arguments-lifecycle]] and [[tf-meta-arguments]].
