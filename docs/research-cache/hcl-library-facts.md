# HCL library facts — who ships which HCL, and what the spec actually says

Source-derived facts about `hashicorp/hcl` itself, the library both Terraform and OpenTofu embed to
parse and evaluate HCL. Used to version-gate language-level claims in the book and to settle
wording the Terraform docs paraphrase.

_Source: `C:\opt\learn\terraform\repos\hcl` at `9466647` (2026-05-14), level with `origin/main`,
which is **40 commits past the newest tag `v2.24.0`** (2025-07-07). Claims below are gated to a tag
with `git tag --contains`. Cross-checked against `repos/terraform/go.mod` and
`repos/opentofu/go.mod`. Last verified: 2026-08-15._

## The headline: Terraform and OpenTofu do not share an HCL implementation

```
# repos/terraform/go.mod
github.com/hashicorp/hcl/v2 v2.24.0

# repos/opentofu/go.mod
github.com/hashicorp/hcl/v2 v2.20.1
replace github.com/hashicorp/hcl/v2 v2.20.1 => github.com/opentofu/hcl/v2 v2.20.2-0.20251021132045-587d123c2828
```

Terraform tracks **upstream v2.24.0**. OpenTofu requires v2.20.1 and then `replace`s it with its
**own fork**, at a pseudo-version built from a commit dated **2025-10-21**. So the two tools parse
and evaluate HCL with different code, from bases four minor versions apart.

!!! warning "Correction — an earlier note reasoned from a false premise"
    [[conditional-branch-evaluation]] states that a behaviour "holds for OpenTofu identically — both
    consume the same `hcl/v2`". **They do not.** The behaviour that note describes is specified in
    `hclsyntax/spec.md`, so its *conclusion* still stands on spec grounds, but the stated reason is
    wrong and the general form of that reasoning — "same library, therefore same behaviour" — does
    not hold for these two tools. Corrected in place.

    The safe rule: a claim traceable to **`spec.md` or `hclsyntax/spec.md`** transfers to both tools,
    because OpenTofu's fork implements the same language. A claim traceable to an **implementation
    detail, bug fix, or diagnostic message** needs checking per tool.

### What upstream added after OpenTofu's base, from the CHANGELOG

Everything between `v2.20.1` (March 2024) and `v2.24.0` (July 2025), which is the window OpenTofu's
fork starts before:

| Version | Change |
|---|---|
| v2.21.0 | `ParseTraversalPartial` (traversals including `[*]`); `ext/dynblock` accepts marked values in `for_each` and transfers the marks; splat on a marked unknown no longer panics |
| v2.22.0 | an `ExprSyntaxError` for invalid references ending in a dot, rather than a vaguer failure |
| v2.23.0 | marks preserved when traversing **unknown** values; marks retained through **conditional and `for` expressions** |
| v2.24.0 | `gohcl` decodes source ranges; **invalid nested splat results detected and rejected**; unknown objects handled correctly in `Index` |

!!! note "This is an upper bound on the divergence, not a measurement of it"
    OpenTofu's fork carries roughly nineteen months of its own commits on top of v2.20.1 and may
    have back-ported any of these. That cannot be verified from this checkout — the fork is not
    cloned locally. Treat the table as *what to check*, not as a list of OpenTofu defects.

    **One row now checked, and it is back-ported.** The v2.24.0 nested-splat rejection fires
    identically on **OpenTofu 1.12.4** and **Terraform 1.15.8**, down to the wording:
    `tolist([{ a = "x" }, { a = null }])[*].a[*]` produces *"Invalid nested splat expressions"* on
    both (measured 2026-08-15 in `terraform console` and `tofu console`). So the fork is not simply
    v2.20.1 plus OpenTofu features, and a delta in the table above must be tested rather than
    assumed to be missing. The remaining rows are untested.

Two entries are user-visible in configuration language terms, which is why they are worth naming:

- **Marks through conditionals and `for` expressions (v2.23.0).** "Marks" are how Terraform tracks
  sensitivity, so this is the machinery that decides whether `sensitive` survives a `condition ? a :
  b` or a `for` projection. Commits `bbfec2d` "pass all marks through conditional expressions" and
  `b48ba6e` "pass marks through unknown ForExpr values", both first tagged **v2.23.0**.
- **Nested splat rejection (v2.24.0).** Commit `2894e4c`, first tagged v2.24.0, turns a
  previously-unrepresentable case into a diagnostic instead of an attempt to build an impossible
  list. The source comment is candid about why it is an error rather than a fix — *"we discovered
  this bad interaction after the two conflicting behaviors were both well-established so it isn't
  clear how to change them without breaking existing code"* (`hclsyntax/expression.go:1942`). The
  message a user sees:

  > **Invalid nested splat expressions** — The second level of splat expression produced elements of
  > different types, so it isn't possible to construct a valid list to represent the top-level
  > result. Consider using a for expression instead, to produce a tuple-typed result which can
  > therefore have non-homogenous element types.

## Spec facts worth citing directly

All quoted from `hclsyntax/spec.md` at `9466647`. These are the wording the Terraform docs
paraphrase, so citing the spec is stronger than citing the docs.

**Identifiers** are [`UAX #31`](https://unicode.org/reports/tr31/) `ID_Start (ID_Continue | '-')*`. The dash is a deliberate addition
outside the Unicode definition, "to allow attribute names and block type names to contain dashes,
although underscores as word separators are considered the idiomatic usage." So `my-attr` is legal
HCL and unidiomatic by the spec's own statement.

**Numeric literals** are `decimal+ ("." decimal+)? (expmark decimal+)?` — a decimal representation
of a real number with integer, fractional and exponent parts. No hex, octal or binary literal
syntax exists in the language.

**Escape sequences belong to quoted templates only.** The spec defines `\n`, `\r`, `\t`, `\"`,
`\\`, `\uNNNN` and `\UNNNNNNNN` under *quoted* template expressions, and the heredoc section
introduces no escapes at all. This **confirms** the claim already in Ch 7 that a backslash inside a
heredoc is literal.

**`<<-` strips the minimum indentation, not all of it** — measured 2026-08-15 and now written up in
[Ch 4](../book/ch04-hcl-language-basics.md), including the consequence that a single flush-left line
drops the common amount to zero and strips nothing anywhere. Identical under Terraform 1.15.8 and
OpenTofu 1.12.4. Verbatim: "any literal string at the start
of each line is analyzed to find the minimum number of leading spaces, and then that number of
prefix spaces is removed from all line-leading literal strings. The final closing marker may also
have an arbitrary number of spaces preceding it on its line." Note *spaces*, and note *literal
string* — a line beginning with an interpolation is not a literal string start.

**Interpolation escapes** are `$${` for `${` and `%%{` for `%{` — "escaped by doubling their leading
characters".

**Strip markers work at syntax level, and this is the gotcha.** `~` removes adjacent spaces from the
*template literal*, never from a value: "`${"hello" ~}${" world"}` produces `"hello world"`, and not
`"helloworld"`, because the space is not in a template literal directly adjacent to the strip
marker."

**The two splat operators differ in where a trailing index applies:**

> - `tuple.*.foo.bar[0]` is approximately equivalent to `[for v in tuple: v.foo.bar][0]`.
> - `tuple[*].foo.bar[0]` is approximately equivalent to `[for v in tuple: v.foo.bar[0]]`

The attribute-only form (`.*.`) applies the index to the **result list**; the full form (`[*]`)
applies it **inside each element**. Two further rules that have no equivalent in a `for` expression:
a splat applied to a non-collection **auto-wraps it** — `any_object.*.id` is `[any_object.id]`,
`any_number.*` is `[any_number]` — and a splat on a **null scalar yields an empty tuple**, which is
the idiomatic "possibly-null value to zero-or-one-element list" conversion. Applying a splat to a
null value that is *of* tuple, list or set type is illegal.

!!! tip "Closed in Ch 7, 2026-08-15"
    [Ch 7](../book/ch07-expressions-operators-functions.md) previously taught `[*]` and its `for`
    equivalence correctly but never mentioned the attribute-only `.*.` form, the differing
    trailing-index semantics, or the scalar and null rules. It now covers all of them, with measured
    console output rather than assertions — including the pair that makes the difference obvious:
    the same expression body returns `["x", "y"]` under `.*.` and `["x", "p"]` under `[*]`, because
    one indexes the result list and the other indexes inside each element.

## Structure of the repository, for future lookups

| Path | What lives there |
|---|---|
| `spec.md` | the syntax-agnostic **information model** — value types, the structural/collection split |
| `hclsyntax/spec.md` | the **native syntax** spec: lexical elements, expressions, templates, static analysis |
| `json/spec.md` | the JSON syntax mapping, which is what `.tf.json` files are parsed against |
| `hclsyntax/` | the native-syntax parser and evaluator; `expression.go` holds splat, conditional and `for` evaluation |
| `hclwrite/` | the code-generation and rewriting API (what `terraform fmt` and generators build on) |
| `ext/dynblock/` | the `dynamic` block implementation — a language *extension*, not core HCL |
| `ext/tryfunc/` | `try()` and `can()`, likewise an extension |
| `hcldec/`, `gohcl/`, `hclparse/`, `hclsimple/` | decoding APIs for calling applications |
| `specsuite/` | cross-implementation conformance tests |
| `didyoumean.go` | the "did you mean …?" suggestion machinery behind HCL's nicer diagnostics |

Two of these are worth knowing for their own sake: **`dynamic` blocks and `try`/`can` are `ext/`
extensions**, not part of the HCL language proper, which is why the specs above never mention them —
they are opt-in capabilities a calling application wires up. HCL likewise defines **no functions of
its own**; the function table is supplied by the host application, which is why Terraform's function
list and OpenTofu's can differ without either violating the spec.

## Sources

- Local checkout `C:\opt\learn\terraform\repos\hcl` @ `9466647` (2026-05-14), tags to `v2.24.0`
- `spec.md`, `hclsyntax/spec.md`, `CHANGELOG.md`, `hclsyntax/expression.go`
- Version pins: `repos/terraform/go.mod`, `repos/opentofu/go.mod`
- Version gating: `git tag --contains` on `bbfec2d`, `b48ba6e`, `e2f43f4` (v2.23.0) and `2894e4c` (v2.24.0)
