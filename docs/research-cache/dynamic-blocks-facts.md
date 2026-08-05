# Dynamic blocks & complex types — verified facts

Captured for **Book Ch 12 (I3)**. Every row was either measured locally or read from an
official source pinned to a release tag.

_Last verified: 2026-08-05. Terraform **1.15.8**, OpenTofu **1.12.4**. AWS provider **6.54.0** for the
documentation quotes below, **6.58.0** for the lab measurements._

---

## The canonical teaching example is one AWS now advises against

The `dynamic "ingress"` security-group block is the folklore example for dynamic blocks. It is
what *Terraform in Depth* Ch 4 §4.10 uses, and it is what the learning path's own I3 milestone
names. The AWS provider's own documentation now recommends against the inline blocks it generates.

Read from `website/docs/r/security_group.html.markdown` at tag **v6.54.0** (not `main`), so this is
the wording shipped with the release the book targets:

> "Avoid using the `ingress` and `egress` arguments of the `aws_security_group` resource to
> configure in-line rules, as they struggle with managing multiple CIDR blocks, and, due to the
> historical lack of unique IDs, tags and descriptions."

> "To avoid these problems, use the current best practice of the
> [`aws_vpc_security_group_egress_rule`] and [`aws_vpc_security_group_ingress_rule`] resources
> with one CIDR block per rule."

> "You should not use the `aws_security_group` resource with _in-line rules_ (using the `ingress`
> and `egress` arguments of `aws_security_group`) in conjunction with the
> [`aws_vpc_security_group_egress_rule`] and [`aws_vpc_security_group_ingress_rule`] resources or
> the [`aws_security_group_rule`] resource. Doing so may cause rule conflicts, perpetual
> differences, and result in rules being overwritten."

Inline blocks remain **supported**, not deprecated. But the recommended shape moved from
*one resource with N generated nested blocks* to *N resources iterated with `for_each`*. That is
resource iteration (Ch 10) replacing block iteration (Ch 12) for this specific resource type.

Source: <https://github.com/hashicorp/terraform-provider-aws/blob/v6.54.0/website/docs/r/security_group.html.markdown>

---

## Measured — type constraints

All measured with a provider-free configuration (no plugin needed), Terraform **1.15.8** and
OpenTofu **1.12.4**. Lab: `labs/chapter12/lab4`.

| Case | Result |
|---|---|
| `optional(string, "x")`, caller passes explicit `null` | Default **wins** → `"x"` |
| `variable` `default = "x"`, caller passes explicit `null`, `nullable` unset | Default **loses** → stays `null` |
| Same but `nullable = false` | Default wins → `"x"` |
| `optional(string)` with no default, attribute absent | `tostring(null)` — a **typed** null |
| `object({name=string})` given `{name, extra, another}` | Extras **silently dropped**; value is `{ "name" = "n" }` |
| `map(string)` given `{a="1", b=2}` | `tomap({a="1", b="2"})` — number coerced to string |
| `list(any)` given `["a", 1, true]` | `tolist(["a","1","true"])` — unified to `string`, silent coercion |
| `list(any)` given `["a", [], "b"]` | Rejected: *"all list elements must have the same type."* |
| `tuple([string, number])` given `["a", 1, true]` | Rejected: *"tuple required."* |

The docs' own optional-attributes example reproduces exactly, including the outer value printing
as `tolist([...])` and unsupplied optional attributes printing as `tostring(null)`.

### The `optional()` / `nullable` asymmetry

The word "default" means two different things depending on where it is written.

- A **variable** `default` is a fallback for *absence only*. An explicit `null` from the caller is
  a real value and is kept, because `nullable` defaults to `true`.
- An **`optional()` attribute** default is applied for absence *and* for an explicit `null`. It
  behaves the way `nullable = false` does, with no way to opt out.

So `optional(string, "x")` carries a guarantee that `default = "x"` on a variable does not: the
receiving module never sees `null`. This matches HashiCorp's
[Type Constraints](https://developer.hashicorp.com/terraform/language/expressions/type-constraints)
page, which states it but does not contrast it with `nullable`.

---

## Measured — OpenTofu divergence: dropped object attributes

**OpenTofu warns where Terraform is silent.** This is the practically important one, because the
failure it catches is a typo in a module input.

Same configuration, an object type constraint given an attribute the schema does not declare:

```
# Terraform 1.15.8
Success! The configuration is valid.
```

```
# OpenTofu 1.12.4
Warning: Object attribute is ignored

  on main.tf line 10, in variable "obj_extra":
  10:   default = { name = "n", extra = "dropped", another = 5 }

The object type for this variable does not include an attribute named
"extra", so this definition is unused.

(and one more similar warning elsewhere)
Success! The configuration is valid, but there were some validation warnings
as shown above.
```

Also fires at a **module call boundary**, which is the realistic case:

```
The object type for input variable "cfg" does not include an attribute named
"extra", so this definition is unused.
```

Both tools produce the identical *value* (`{ "name" = "kept" }`). Only the diagnostic differs.

---

## Measured — dynamic block limits

Lab: `labs/chapter12/lab3`. Using the built-in `terraform_data` resource.

`dynamic "lifecycle"`, `dynamic "provisioner"`, `dynamic "connection"`, and `dynamic "nonexistent"`
all produce the **same** generic error on Terraform 1.15.8:

```
Error: Unsupported block type

  on probe.tf line 3, in resource "terraform_data" "limit":
   3:   dynamic "lifecycle" {

Blocks of type "lifecycle" are not expected here.
```

The HCDocs statement — *"It is not possible to generate meta-argument blocks such as lifecycle and
provisioner blocks, since Terraform must process these before it is safe to evaluate expressions"* —
is true, but nothing in the error says so. A reader who tries it gets the same message a typo
produces, with no hint that the rule exists.

---

## Measured — a null output is dropped from state

Not an I3 fact, recorded here because it surfaced during the `nullable` measurements and belongs
to **Ch 6**.

An `output` whose value evaluates to `null` is not written to state at all:

```
$ terraform output plain
Error: Output "plain" not found

The output variable requested could not be found in the state file.
```

`terraform output -json` omits the key entirely rather than emitting `"value": null`. Measured on
1.15.8.

---

## Measured — block generation and ordering

Run against Floci on **Terraform 1.15.8**, AWS provider **6.58.0**. Labs `labs/chapter12/lab1`
and `lab2`.

**Generation works as documented.** A `list(object(...))` of three rules produces three `ingress`
blocks. `optional()` defaults are visible in the plan: rules that omitted `cidr_blocks` got
`["0.0.0.0/0"]`, and all three omitted `protocol` and got `"tcp"`. Nesting works: a map of three
lifecycle rules produced two `transition` blocks for one rule, one for another, and none for the
third, each count coming from that rule's own list.

**The zero-or-one toggle is an in-place update.** Flipping `enable_ssh` to `true` plans
`0 to add, 1 to change, 0 to destroy`, adding one element with `# (3 unchanged elements hidden)`.
No replacement.

**Ordering has two different stories, and the contrast is the finding.**

| Source | Declared | Generated | Predictable? |
|---|---|---|---|
| `list(object)` → provider **set** (`aws_security_group.ingress`) | 443, 80, 5432 | 80, 443, 5432 | No — the provider's order |
| `map(object)` → `for_each` (`aws_s3_bucket_lifecycle_configuration.rule`) | logs, tmp, everything | everything, logs, tmp | Yes — sorted key order |

The set case loses declaration order permanently, because a set has no order to preserve. The map
case is deterministic sorted-key iteration. So a map-driven dynamic block is the one whose output
order you can state in advance, which is the block-level version of the same argument Ch 10 makes
for `for_each` over `count`.

**Emulator note.** `aws_s3_bucket_lifecycle_configuration` took **55 seconds** to create on Floci
against 3 seconds for the bucket. Slow, not broken.

---

**OpenTofu re-run: no divergence.** Both labs were run again under **OpenTofu 1.12.4** (AWS
provider **6.57.1**). Every result reproduced exactly — same generated blocks, same `optional()`
defaults, same set reordering, same sorted-key map order, same 55-second create. Block generation
is tool-independent, and the set reordering is the provider's doing rather than either CLI's.

---

## Measured — a lock file is not portable between Terraform and OpenTofu

Found by running the OpenTofu pass in a directory holding Terraform's committed lock.

`.terraform.lock.hcl` entries are keyed by the **fully-qualified** provider source address,
including the registry host. Terraform records `registry.terraform.io/hashicorp/aws`; OpenTofu
resolves the identical `source = "hashicorp/aws"` to `registry.opentofu.org/hashicorp/aws`. So
one lock cannot serve both:

```
Error: Inconsistent dependency lock file

The following dependency selections recorded in the lock file are inconsistent
with the current configuration:
  - provider registry.opentofu.org/hashicorp/aws: required by this configuration
    but no version is selected
```

`tofu init -upgrade` writes OpenTofu's entry. A repo that must build under both tools cannot
share one committed lock file.

**Resolved versions drift too.** The same `~> 6.0` constraint on the same day selected AWS
provider **6.58.0** from Terraform's registry and **6.57.1** from OpenTofu's. Both satisfy the
constraint; the mirrors are not in lockstep.

This corrects a line in **Book Ch 2**, which said version constraints and the lock file "behave
the same in both tools." The format and purpose do; a written lock file does not transfer.

---

## Not verified

- Nothing outstanding for this chapter.
