# `for_each` reference

> **Source:** [developer.hashicorp.com/terraform/language/meta-arguments/for_each](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
> **Added:** 2026-08-01
> **Source updated:** undated language reference; captured 2026-08-01 against v1.15.x (latest)
> **Tags:** meta-arguments, for_each, each.key, each.value, toset, sets, chaining, sensitive-values, impure-functions, stacks
> **Type:** documentation

The sibling of [[tf-meta-count]], and the longer of the two pages. Captured for four things `count` has no equivalent of: the **chaining** pattern, the **sensitive-value** prohibition, the **no-implicit-list-conversion** rule, and a Stacks-only block list that quietly answers an OpenTofu divergence question.

Its accepted-types sentence is also the single most-corrected claim in these notes — see the first callout.

## Usage

> "The `for_each` meta-argument accepts a **map or a set of strings** and creates an instance for each item in that map or set."

```hcl
resource "azurerm_resource_group" "rg" {
  for_each = tomap({
    a_group       = "eastus"
    another_group = "westus2"
  })

  name     = each.key
  location = each.value
}
```

```hcl
resource "aws_iam_user" "the-accounts" {
  for_each = toset(["Todd", "James", "Alice", "Dottie"])

  name = each.key
}
```

!!! danger "“a map or a set of strings” is incomplete — **objects** are accepted too"
    The implementation checks three kinds: map, set, **and object**. Verified on Terraform **1.15.8** at `internal/terraform/eval_for_each.go:361`; the error message repeats the same two-kind claim the docs make. See [[conditional-branch-evaluation]].

    Why it matters in practice: **braces build an object, not a map.** `for_each = { a = "1", b = "2" }` works with no `tomap()` at all — the page's own first example wraps an object literal in `tomap()` unnecessarily.

    **OpenTofu's docs get this right** — "must be a **map**, **object**, or **set of strings**" ([[ot-provider-for-each]]).

    Two things the correction does *not* license. The rejection of lists and tuples is real, and the page states it explicitly further down, so `toset(...)` stays mandatory for sequences. And "of strings" binds only to the **set** — a map or object may hold values of any type, since only keys become instance addresses.

`toset()` and `tomap()` are named as the "pure functions" you use to build a suitable value. Everything `for_each` iterates over "must be known before Terraform performs any remote resource operations" — the same plan-time-known constraint [[tf-meta-count]] states for `count`.

## Limitations on values

Three separate prohibitions, worth keeping distinct.

**1. Keys must be known.** Otherwise Terraform errors that `for_each` "has dependencies that cannot be determined before apply" and suggests `-target`. (`-target` is an antipattern — see [[05-terraform-plan]] — so read that suggestion as a diagnostic, not advice.)

**2. Keys cannot come from impure functions** — `uuid`, `bcrypt`, `timestamp` are named, "because Terraform defers evaluating impure functions during the main evaluation step."

**3. Sensitive values are banned outright.** Not discouraged — an error:

> "Sensitive values are not allowed because Terraform uses the value in `for_each` to identify the resource instance and **always discloses it in UI output**."

This is a clean example of the rule that instance keys are public by construction: a key appears in every plan line, every state address, every error message, so it cannot be a secret. Sensitivity is also contagious — "most functions in Terraform return a sensitive result when given an argument with any sensitive content", so `keys(local.map)` on a map with sensitive *values* yields a sensitive result even though the keys themselves aren't.

The page gives the escape hatch:

```hcl
for_each = toset([for k, v in local.map : k])
```

A `for` expression pulls only the keys out, so nothing sensitive is ever handed to a function. See [[tf-manage-sensitive-data]].

## Expressions in `for_each`

> "The `for_each` value must be a map or set with **one element per desired resource instance**. To use a sequence as the `for_each` value, you must use an expression that explicitly returns a set value, such as the `toset` function."

> "To prevent unexpected behavior during conversion, the `for_each` argument **does not implicitly convert lists or tuples to sets**."

That refusal is deliberate and is the reason `toset()` is idiomatic rather than optional. It is also the one place the docs' type story is precise: elsewhere tuples auto-convert to lists freely, and `for_each` is the exception ([[conditional-branch-evaluation]]).

For nested or combinatorial data, the page defers to the `flatten` and `setproduct` function guides rather than showing the pattern inline.

## Referring to instances

Setting `for_each` puts an `each` object in scope:

- **`each.key`** — the map key or set member for this instance.
- **`each.value`** — the map value. **For a set, `each.value` is the same as `each.key`.**

Addressing follows the same block-vs-instance split as `count`, keyed by string instead of index:

| Address | Refers to |
|---|---|
| `azurerm_resource_group.rg` / `module.web` | the block |
| `azurerm_resource_group.rg["a_group"]` / `module.web["a_group"]` | an individual instance |

Child-module resources show as `module.<NAME>[<KEY>]` in plan output; a module without `count`/`for_each` carries no key. Inside nested `provisioner`/`connection`, `self` is the **instance**. All three sentences are shared verbatim with [[tf-meta-count]].

## Chaining `for_each` between resources

The pattern with no `count` equivalent, and the most useful thing on the page.

> "Because a resource using `for_each` appears as a map of objects when used in expressions elsewhere, you can directly use one resource as the `for_each` of another in situations where there is a one-to-one relationship between two sets of objects."

```hcl
variable "vpcs" {
  type = map(object({
    cidr_block = string
  }))
}

resource "aws_vpc" "example" {
  # One VPC for each element of var.vpcs
  for_each = var.vpcs

  # each.value here is a value from var.vpcs
  cidr_block = each.value.cidr_block
}

resource "aws_internet_gateway" "example" {
  # One Internet Gateway per VPC
  for_each = aws_vpc.example

  # each.value here is a full aws_vpc object
  vpc_id = each.value.id
}

output "vpc_ids" {
  value = {
    for k, v in aws_vpc.example : k => v.id
  }

  # The VPCs aren't fully functional until their
  # internet gateways are running.
  depends_on = [aws_internet_gateway.example]
}
```

Two shifts in what `each.value` holds, in the same example: from a `var.vpcs` element in the first block, to a **whole `aws_vpc` object** in the second. The stated payoff:

> "This chain pattern explicitly and concisely declares the relationship between the internet gateway instances and the VPC instances, which tells Terraform to **expect the instance keys for both to always change together**."

That is the real argument. Writing `for_each = var.vpcs` on both blocks would produce the same keys today but leaves them independently derived; chaining makes the coupling structural.

The `output` block also shows `depends_on` used for a **semantic** readiness dependency — the IDs exist before the gateways do, so the reference alone would not wait. Exactly the hidden-dependency case from [[tf-meta-depends-on]] and [[tut-dependencies]].

!!! note "“appears as a map of objects” is the same conflation as the accepted-types sentence"
    A `for_each` block reference is an **object**, not a map ( `count` gives a **tuple**, not a list). Verified TF 1.15.8, [[conditional-branch-evaluation]]. The chaining pattern works regardless, because `for_each` accepts objects — which is precisely the acceptance the Usage section fails to mention.

## Using sets

> "The Terraform language doesn't have a literal syntax for set values, but you can use the `toset` function to explicitly convert a list of strings to a set."

```hcl
locals {
  subnet_ids = toset([
    "subnet-abcdef",
    "subnet-012345",
  ])
}

resource "aws_instance" "server" {
  for_each = local.subnet_ids

  ami           = "ami-a1b2c3d4"
  instance_type = "t2.micro"
  subnet_id     = each.key # note: each.key and each.value are the same for a set

  tags = {
    Name = "Server ${each.key}"
  }
}
```

**`toset` is lossy, and the page says so plainly:** conversion "discards the ordering of the items in the list and removes any duplicate elements. For example, `toset(["b", "a", "b"])` produces a set containing only `"a"` and `"b"` in no particular order and discards the second `"b"`."

Both losses are usually what you want here — instance identity comes from the key, so order is meaningless and duplicates would collide anyway.

Module authors can skip the conversion at the call site by typing the variable:

```hcl
variable "subnet_ids" {
  type = set(string)
}

resource "aws_instance" "server" {
  for_each = var.subnet_ids
  #...
}
```

## Choosing between `for_each` and `count`

Stated from the opposite side of [[tf-meta-count]], same substance: `for_each` "when some instance arguments must have distinct values that can't be directly derived from an integer", `count` "when you want to create nearly identical instances". Mutually exclusive in one block.

!!! danger "Neither page gives the actual reason to prefer `for_each`"
    `count` keys by **position**; `for_each` keys by **string**. Remove a middle element from a `count` list and everything after it re-indexes into a destroy-and-recreate. Remove a `for_each` key and exactly one instance is destroyed.

    Both reference pages describe the *shape* difference and stay silent on the *consequence*. TID Ch4 §4.8 is where it's taught ([[04-expressions-iterations]]).

## Supported constructs

Terraform configuration blocks:

- `data`, `ephemeral`, `module`, `resource`

**Stack** configuration blocks:

- `component`, `provider`, `removed`

Query configuration blocks:

- `list`

!!! warning "This list omits `action` **and** `import` — both documented on this same page"
    The page's own opening paragraph says "when `for_each` appears in an `action` block, Terraform invokes the action once for each member". Its Examples section then has entries titled **"Invoke an action multiple times"** and **"Import multiple resources"**, the latter pointing at the `import` block docs.

    So two supported block types are missing from the canonical list. [[tf-meta-count]] has the same defect with one omission (`action`); this page doubles it. Combined with the index page's own gaps, the rule recorded on [[meta-arguments-lifecycle]] holds: **treat every applicability list in these docs as a lower bound, and trust the page body over the page's own summary list.**

    (The heading is also misspelled "Supported **constucts**" — cosmetic, but a fair signal of how closely this section is maintained.)

!!! info "OpenTofu — `for_each` on `provider` blocks is core language there, Stacks-only here"
    This page lists `provider` under **Stack** configuration blocks. So Terraform does support multiple provider instances via `for_each`, but only inside a Stack configuration — not in ordinary root or child modules.

    **OpenTofu has had `provider for_each` in the core language since 1.9** ([[ot-provider-for-each]]), usable in any configuration with no Stacks equivalent required. This sharpens the divergence already recorded there: it isn't that Terraform lacks the capability, it's that Terraform gates it behind a different configuration surface.

## Examples

**Ephemeral resources per environment**, feeding a write-only argument:

```hcl
locals {
  environments = toset(["dev", "staging", "prod"])
}

ephemeral "random_password" "db_passwords" {
  for_each = local.environments

  length           = 16
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_instance" "databases" {
  for_each = local.environments

  identifier  = "${each.key}-database"
  db_name     = "${each.key}db"
  username    = "dbadmin"
  password_wo = ephemeral.random_password.db_passwords[each.key].result
  # …
}
```

Note the two blocks share `local.environments` rather than chaining, and the `[each.key]` lookup does the correlation manually. Terraform does not store the generated passwords; the page points at write-only arguments for capturing them. See [[tf-manage-sensitive-data]].

**Per-key module instances with differing arguments** — the case `count` cannot express, since `instance_type` varies per key:

```hcl
locals {
  instance_configs = {
    "example-instance-1" = { instance_type = "t2.micro" }
    "example-instance-2" = { instance_type = "t2.small" }
    "example-instance-3" = { instance_type = "t2.medium" }
  }
}

module "ec2_instance" {
  source   = "terraform-aws-modules/ec2-instance/aws"
  version  = "6.0.2"
  for_each = local.instance_configs

  name          = each.key
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = each.value.instance_type

  depends_on = [aws_s3_bucket.example]
}
```

**A local module instantiated per name:**

```hcl
module "bucket" {
  for_each = toset(["assets", "media"])
  source   = "./publish_bucket"
  name     = "${each.key}_bucket"
}
```

The remaining three examples defer to other pages: actions (`action` block docs), imports (`import` block docs), and query lists (`list` block docs). None of those blocks is captured in these notes yet.

---
Related: [[tf-meta-count]] — the sibling reference; shares the addressing rules verbatim and has the same summary-list defect, with one omission instead of two. · [[tf-meta-arguments]] — the index page, whose block table this one matches (unusually). · [[conditional-branch-evaluation]] — the evidence that objects are accepted and that a `for_each` block reference is an object, not a map. · [[ot-provider-for-each]] — OpenTofu's core-language `provider for_each`, which this page shows Terraform confining to Stacks. · [[04-expressions-iterations]] — TID Ch4 §4.8, where the positional-vs-keyed consequence is actually taught. · [[tf-manage-sensitive-data]] — why sensitive values can never be instance keys. · [[meta-arguments-lifecycle]] — `for_each` among the six.
