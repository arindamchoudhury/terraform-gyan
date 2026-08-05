# Dynamic blocks & complex types — verified facts

Captured for **Book Ch 12 (I3)**. Every row was either measured locally or read from an
official source pinned to a release tag.

_Last verified: 2026-08-05. Terraform **1.15.8**, OpenTofu **1.12.4**, AWS provider **6.54.0**._

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

## Not verified

- Whether `dynamic` block generation itself behaves identically under OpenTofu — the provider
  plugin could not be loaded on this machine at capture time (Norton intercepts the loopback
  mTLS handshake; see [[env_norton_breaks_terraform_plugin_mtls]]). Everything above is either
  provider-free or documentary.
