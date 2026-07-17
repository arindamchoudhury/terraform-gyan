# B7 expressions — verified facts

Last verified: **2026-07-15** against **Terraform 1.15.6** and **OpenTofu 1.12.4** (empirical: `terraform console`/`plan` and `tofu console`). Extended **2026-07-17** with the tuple/object-literal mechanism, verified on **Terraform 1.15.8** against the HCL spec, the `cty` docs, and the local `terraform` source — that section stamps its own versions; the rows above were **not** re-run on 1.15.8.

!!! note "Scope has outgrown the filename"
    This file started as the ternary branch-evaluation investigation (below) and grew into the verification record for the whole **B7 / Ch 7** chapter. The slug stays `conditional-branch-evaluation` so existing `[[conditional-branch-evaluation]]` links keep resolving.

    **Method, and why it matters:** every row here was *run*, not recalled. The pattern across the audit was blunt — claims taken from memory, blogs, or even the official docs were repeatedly wrong; claims that were executed were right. Two HashiCorp doc examples turned out stale (`keys()` sensitivity, and the `local_file` example writing through `path.module`), one cited GitHub issue was fabricated, and several of *my own* statements of a true fact were imprecise. Re-verify before trusting any of it against a newer release.

## The question

Does `cond ? a : b` evaluate **both** result branches (so an error in the unused branch fails the whole expression), or only the selected one? Older material — including *Terraform in Depth* (Hafner, 2025) — says Terraform "evaluates both results." Tested on current Terraform, that is **no longer true** for runtime errors.

## What actually errors

| Case | Errors? | Evidence (TF 1.15.6) |
|---|---|---|
| **Type mismatch** between branches | **Always** — unconditional | `true ? 1 : ["a"]` → `Error: Inconsistent conditional result types` (true is fine; still errors) |
| Runtime error in the **untaken** branch (known condition) | **No** | `true ? "safe" : [1,2,3][5]` → `"safe"`; `false ? [1,2,3][5] : "safe"` → `"safe"` |
| Runtime error in the **taken** branch | **Yes** | `count = 0` resource, `var.use_it=false` → `... ? "safe" : terraform_data.opt[0].output` → `Error: Invalid index` |
| Runtime error in untaken branch, **unknown** condition | **No** | condition = `known after apply`, false-branch indexes a `count=0` resource → plan succeeds, `picked = (known after apply)` |
| Static reference error (undeclared var/resource) | **Yes** — but that's decode-time config invalidity, not branch evaluation | `true ? "safe" : var.nope` → `Error: Reference to undeclared input variable` |

## When it changed — Terraform 0.12.0 (verified, not recalled)

Lazy branch evaluation arrived with the **0.12.0 HCL2 expression-engine rewrite** (GA May 2019). Before 0.12, the old HIL interpolation engine evaluated *both* branches — that was the bug tracked in [hashicorp/terraform#15605](https://github.com/hashicorp/terraform/issues/15605) ("Interpolation should only evaluate one branch of a condition").

Evidence (via `gh` API, 2026-07-15):

- Issue #15605 closed **2018-10-27**, milestone **v0.12.0**.
- Closing comment from core maintainer **apparentlymart**: *"I've just verified that this is now working correctly in v0.12.0-alpha1"* — with a `terraform console` test matching this file's:

    ```
    > false ? file("nonexist") : "it was false"
    it was false
    > true ? file("nonexist") : "it was false"
    Error: Error in function call
    ```

So any source describing "both branches are evaluated" is pre-0.12 behavior (≥ 6 years stale as of 2026). A later comment (2020, v0.12.23) noted a separate edge case when a branch references a whole *resource object* (`true ? aws_security_group.test : null`) — a type/reference-resolution quirk, distinct from the runtime-index case tested here, which does **not** error on 1.15.6.

## Takeaways

- Both result branches must be **type-compatible** — this is a type check Terraform does regardless of the condition, so it fails even when the taken branch is valid.
- A branch's **runtime evaluation** error (out-of-range index, `count=0` index, division by zero, failed conversion) surfaces **only if that branch is selected**. The untaken branch is not evaluated — including when the condition is unknown at plan time.
- Practical rule: **guard the branch you might take**, not "both." `try(...)` is the tool when the branch you select could itself error (e.g. `try(module.x[0].ip, null)`), not to protect an unused branch.
- **Outdated sources:** TID (2025) and pre-1.x guidance say both branches are evaluated. Correct historically for older Terraform / the type-check framing, but not the runtime behavior on 1.15.6.

## OpenTofu — verified identical (1.12.4)

Ran the same tests in `tofu console` (OpenTofu 1.12.4, 2026-07-15): untaken bad index → `"safe"`, untaken `count=0` attribute access → `"safe"`, type mismatch → `Error: Inconsistent conditional result types`. Same behavior as Terraform. Expected — OpenTofu forked from Terraform **1.5.x**, well after the 0.12 HCL2 rewrite, so it inherited lazy branch evaluation. (Note: OpenTofu *does* differ from Terraform on `&&`/`||` short-circuit history — that's a separate feature — but the ternary behaves the same.)

---

## Related verified facts (Ch7 audit, 2026-07-15)

Same session, same method (`terraform console` / `plan` on **Terraform 1.15.6**, `tofu console` on **OpenTofu 1.12.4**).

| Claim | Verdict | Evidence |
|---|---|---|
| <code>&&</code>/<code>&#124;&#124;</code> short-circuit: OpenTofu **1.10**, Terraform **1.12.0** | **True** | OpenTofu operators docs ("v1.10 and later … short-circuiting"); TF v1.12 CHANGELOG (May 2025): *"Logical binary operators can now short-circuit"* (#36224). HashiCorp's operators **page does not document it** — cite the changelog. A skipped operand is **still statically validated**. |
| The OpenTofu short-circuit issue is `opentofu#2084` | **FALSE — fabricated** | #2084 is *"`tofu init` should warn if a provider exists with a prefix"*. Unrelated. Cite the OpenTofu docs instead. |
| "All arguments to `try` must share a type" | **FALSE** | `try(tonumber("nope"), "a-string")` → `"a-string"`; `try(tonumber("nope"), [1,2])` → `[1,2]`. A blog claim, not a Terraform rule. |
| Terraform ships "~150" functions | **FALSE — 119** | `terraform metadata functions -json` reports **238** entries = 119 real functions × 2, because each is also exposed as `core::<name>` (`core::max(1,9)` → 9). |
| `keys(map_with_one_sensitive_element)` → `(sensitive value)` (HashiCorp docs example) | **FALSE on 1.15.6** | Returns the plain key list; `issensitive(keys(local.baz))` → `false`. Sensitivity is tracked **per value**: a map *containing* a sensitive element isn't itself sensitive. But when the **argument itself** is marked, propagation is blanket — even `length(sensitive({a="1"}))` → `(sensitive value)`. The docs' example is stale. |
| `convert()` is Terraform-only | **True** | TF 1.15.6: `convert("5", number)` → `5`. OpenTofu 1.12.4: `Error: Invalid reference`. |
| Comparison operators are number-only | **True** | `"a" < "b"` → `Error: Invalid operand`; `2 < 10` → `true`. |
| Splat works on lists, sets, and tuples | **True** | `toset([{id="i-1"},{id="i-2"}])[*].id` → `tolist(["i-1","i-2"])`. |

### Second pass (same session — questions that found gaps, not just errors)

| Claim | Verdict | Evidence (TF 1.15.6) |
|---|---|---|
| There is a set literal | **False** | No set *or* list literal exists. `type(["p","q"])` → `tuple([string,string])`; `tolist(...)` → `list(string)`; `toset(...)` → `set(string)`. |
| You must `tolist()` to get a list | **False — rarely needed** | A tuple auto-converts to a list wherever one is expected: `join("-",["p","q"])` → `"p-q"`, `length(["p","q"])` → `2`. **Sets are the exception** — that's the whole reason `toset()` is idiomatic. |
| `for_each` accepts "a map or a set" | **Imprecise — map or set OF STRINGS** | `for_each = var.names` (`list(string)`) → *"must be a map, or set of strings, and you have provided a value of type list of string."* And `toset()` is not a magic word: `for_each = toset([1,2])` → *"supports maps and sets of strings, but you have provided a set containing type number."* `toset(var.names)` works. |
| Converting a mixed tuple is lossless | **False** | Lists/sets hold one element type; `tolist(["a", 1])` → `["a", "1"]` — the number silently becomes a string. |
| `templatestring(str, vars)` | **Wrong signature — it's `(ref, vars)`** | Literals are refused by design: *"templatestring is only for rendering templates retrieved dynamically from elsewhere, and so does not support providing a literal template."* A literal can't work anyway — HCL interpolates `"${name}"` at the call site first, giving the baffling *"A reference to a resource type must be followed by at least one attribute access"*. Works off `var.`/`local.`: `templatestring(var.tmpl, {...})` → `"hi bo, count=2"`. |
| A template can read `var.*` | **False — the vars map is the whole scope** | `${var.name}` in a `.tftpl` → *"vars map does not contain key \"var\", referenced at ./templates/bad.tftpl:1,3-6"* (`var` is read as a missing key). `${missing}` likewise. Errors point into the template at the column. |
| Terraform can't write files | **False** | The `local` provider's **`local_file`** resource (`local_sensitive_file` for secrets) — *"Generates a local file with the given content."* Caveat from its docs: it reports itself deleted wherever the file is absent → re-creates on fresh checkouts, diff noise in CI. Note the provider's own example writes to `${path.module}/foo.bar`, contradicting the references doc's "not recommended for write operations". |
| `path.cwd` is stable for a given config | **False** | It's the *invoking* directory: same config reports `.../scratchpad/tftest` from its own dir and `.../scratchpad` via `-chdir` from the parent. `path.root` stays `"."` in both. In a resource argument that's a phantom diff. |
| `for` loop names: a second name "also gives you the key" | **Misleading — they shift** | One name binds the **value**, even for a map: `[for v in {a="x",b="y"} : v]` → `["x","y"]`. Two names → key/index **first**: `[for k,v in {a="x",b="y"} : "${k}=${v}"]` → `["a=x","b=y"]`; `[for i,v in ["p","q"] : "${i}:${v}"]` → `["0:p","1:q"]`. A set has neither, so both bind the element → `["p:p","q:q"]`. |
| `.tftpl` is required | **False — convention only** | Terraform renders any extension (verified with `.txt`). The docs recommend `.tftpl` so editors highlight it. |

**Console is the verification tool.** `templatefile()` renders in `terraform console`, and multi-line results print as a `<<EOT` heredoc — which makes whitespace visible, so `~` strip markers can be checked without an apply. The `.tftpl` is re-read per call (no console restart); config changes still need one.

## Why only tuple and object have literals (2026-07-17, TF 1.15.8)

Second pass (row 74 above) established **that** there is no list/set/map literal. This pass establishes **why**, because the fact alone is five behaviors to memorize and the mechanism is one rule. Verified against the HCL spec, the `cty` docs, and the local `terraform` checkout at `c07e79c1c8` (`C:\opt\learn\terraform\repos\terraform`).

### The rule is specified, in as many words

HCL's native-syntax spec, §Collection Values:

> "Only tuple and object values can be directly constructed via native syntax."

> "Tuple and object values can in turn be converted to list, set and map values with other operations, which behaves as defined by the syntax-agnostic HCL information model."

So this is a **language-spec guarantee**, not a Terraform quirk or an accident of the parser. It holds for OpenTofu identically — both consume the same `hcl/v2` (TF go.mod: `github.com/hashicorp/hcl/v2 v2.24.0`).

### The two families are defined by the spec, verbatim

The collection/structural split is **HCL's own**, not a docs convention or a teaching device. Both are defined in the information model (`spec.md`, §Structural Types / §Collection Types, lines 262-300 as of 2026-07-17):

| | Definition (verbatim) | Kinds |
|---|---|---|
| **Structural** | "types that are constructed by combining other types. Each distinct combination of other types is itself a distinct type" | object ("constructed of a set of named attributes, each of which has a type"), tuple ("constructed of a sequence of elements, each of which has a type") |
| **Collection** | "types that combine together an arbitrary number of values of some other single type" | list ("ordered sequences of values of their element type"), map ("values of their element type accessed via string keys"), set ("unordered sets of distinct values of their element type") |

The spec also fixes **type identity**, which is the root of the `==` pitfall (row: `var.list == []`):

> "Two collection types are identical if they are of the same kind and have the same element type."

> "Two structural types are identical if they are of the same kind and have attributes or elements with identical types."

Consequences worth teaching: `list(string)` / `list(number)` / `set(string)` are three unrelated types ("'list of string' is a distinct type from 'set of string'"), and a **tuple's arity is part of its type**, not a property of the value — which is why `convert(["a",15,true], tuple([string,number]))` fails with *"tuple required"*.

### The mechanism — unification, and why a literal can't do it

`cty`'s `convert` docs state the causal step outright:

> "The conversions from structural types to collection types rely on type unification to identify a single element type for the final collection, and so conversion is possible only if unification is possible."

> "Unification is instead concerned with finding a single type that several other types can be converted to, without any specific preference as to what the final type is."

That is the whole answer. A **collection** type is, per `cty`'s type docs, "parameterized with a single _element type_". A **structural** type instead gives each position or key "their own type" (tuple = "a fixed number of values that may have _different_ types"; object = "a number of values of arbitrary types").

A literal's text supplies exactly the per-position/per-key types and the exact arity. That **is** a structural schema — a transcription, nothing inferred. A collection additionally needs a single element type that the syntax never states, and unification is what invents it. Unification needs a target to unify *toward*, which exists only at a `type =` constraint, a provider schema, or an explicit `to*` call. Hence: literals produce structural types because those are the only ones fully determined by the text.

**"Has a literal" and "is structural" are therefore the same predicate, not two facts that happen to line up.**

### The Terraform source corroborates it twice

`internal/lang/functions.go:275-280` — the complete `to*` set:

```go
"tostring":         funcs.MakeToFunc(cty.String),
"tonumber":         funcs.MakeToFunc(cty.Number),
"tobool":           funcs.MakeToFunc(cty.Bool),
"toset":            funcs.MakeToFunc(cty.Set(cty.DynamicPseudoType)),
"tolist":           funcs.MakeToFunc(cty.List(cty.DynamicPseudoType)),
"tomap":            funcs.MakeToFunc(cty.Map(cty.DynamicPseudoType)),
```

1. **No `totuple`, no `toobject`** — verified absent from `internal/` entirely. The two structural types are exactly the two needing no converter, because the literal already produced them. Every other type has one.
2. The three collection converters are the three built on `cty.DynamicPseudoType`, which `internal/lang/funcs/conversion.go:25-29` documents as:

    > "you can pass `cty.List(cty.DynamicPseudoType)` to mean "list of any single type", which will then cause cty to attempt to unify all of the element types when given a tuple."

    Tuple in → unify → collection out, in the source's own words. `tostring`/`tonumber`/`tobool` take concrete types and need no unification, which is why only the collection three are written this way.

The `FriendlyNameForConstraint()` of those `DynamicPseudoType` constraints is what surfaces in the error observed in console:

```
> tomap({ name = ["a"], age = 12 })
Invalid value for "v" parameter: cannot convert object to map of any single
type.
```

"of any single type" is literally the unification requirement failing — no type is both a tuple and a number.

### Precision — where the loss actually is

An earlier phrasing of mine ("collection types carry strictly less information") is **too strong at the value level**. Correct statement:

| Level | Always discarded going structural → collection? |
|---|---|
| **Type** | **Yes.** Per-position/per-key typing and the fixed arity are gone. `tuple([string,string])` → `list(string)` loses "exactly two". |
| **Value** | **No.** `cty` unification "prefer[s] lossless conversions over potentially-lossy ones". Elements already sharing a type pass through untouched. |

Value loss occurs only when unification must reach for a common type (`tolist(["a", 15])` → `["a", "15"]`, verified), or on conversion **to a set**, which the `cty` matrix marks **"safe+lossy"** unconditionally because ordering and duplicates are discarded by definition.

### Console evidence for the split (TF 1.15.8)

```
> type({ name = "John", age = 52 })
object({
    age: number,
    name: string,
})
> type(tomap({ name = "John", age = 52 }))
map(string)
```

The object **transcribes** (`52` stays a `number`); the map **unifies** (`52` → `"52"`). Same input, and the lossy step is the conversion, never the literal. Attribute order in the `type()` output is display-only — objects are unordered.

### What is NOT documented

**No stated rationale exists.** HCL's syntax-agnostic information model (`spec.md`) defines both families and their conversion rules and never explains *why* construction favors structural; it defers construction to the per-syntax specs. So the **mechanism** above is verified from three independent sources, while **design intent** is unstated anywhere. Don't write the chapter as though HashiCorp explained their motive — the mechanism is sufficient and is the documented architecture.

### `for_each` accepts map, **object**, or set of strings (2026-07-17, TF 1.15.8)

Row 76 above recorded "map or set **of strings**", taken from the error message. Running the cases shows the error message and HashiCorp's docs are both **incomplete**: an **object** is accepted too, and never mentioned by either.

The check is a direct type-kind whitelist with **no conversion attempted** (`internal/terraform/eval_for_each.go:361`):

```go
case !(ty.IsMapType() || ty.IsSetType() || ty.IsObjectType()):
```

The `set(string)` restriction is a *separate* branch (`:389`, `if ty.ElementType() != cty.String`) reached only for sets. So "of strings" binds to the set alone; maps and objects may hold any value type, because only keys become instance addresses.

Verified with `terraform_data` + `terraform plan` on 1.15.8:

| `for_each = ...` | Actual type | Result |
|---|---|---|
| `toset(["p","q"])` | `set(string)` | **accepted**, 2 instances |
| `{ a = "1", b = "2" }` | **object** | **accepted**, 2 instances |
| `{ a = 1, b = "x" }` | object, mixed values | **accepted** — value types are irrelevant |
| `{ a = { port = 80 } }` | object, nested object value | **accepted** |
| `tomap({ a = 1, b = 2 })` | `map(string)` | **accepted** |
| `var.names` declared `list(string)` | `list(string)` | **rejected** — *"must be a map, or set of strings, and you have provided a value of type list of string"* |
| `["p","q"]` (bare literal) | `tuple([string,string])` | **rejected** — *"...you have provided a value of type tuple."* |
| `toset([1,2])` | `set(number)` | **rejected** — *"supports maps and sets of strings, but you have provided a set containing type number."* |

**Teaching consequence.** Since braces build an *object*, not a map, `for_each = { a = "1" }` works with no `tomap()`. A reader told only "for_each takes a map" would wrongly conclude it needs converting. HashiCorp's [for_each page](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) says "a map or a set of strings" and states that lists/tuples are not implicitly converted to sets (paraphrased, not re-verified against raw bytes). **OpenTofu's docs are correct** and already captured in [[ot-provider-for-each]]: "must be a **map**, **object**, or **set of strings**."

!!! warning "A wrong theory I nearly wrote down"
    I first hypothesised that `for_each` rejects tuples because tuple→set is marked **safe+lossy** in the `cty` chart while object→map is **safe**, i.e. that Terraform refuses implicit *lossy* conversions here. **That is wrong.** The source performs no conversion at all — it is a flat whitelist of three type kinds. The lossy/safe distinction is real in `cty` but plays no part in this check. Read the source before explaining a behavior by a mechanism that merely *predicts* it.

### `convert()` — Terraform-only, but the capability isn't (2026-07-17)

The row above records `convert()` as Terraform-only. **True, and incomplete**: the *function* is missing from OpenTofu, not the behavior. `convert()` is an inline shortcut for the machinery every `type =` constraint already runs.

Verified on **OpenTofu 1.12.4** — a typed module input performs the identical object-schema coercion, extra attributes discarded:

```hcl
# mod/main.tf
variable "person" {
  type = object({ name = string })
}
output "person" { value = var.person }

# root: person = { name = "John", age = 52 }
# → result = { "name" = "John" }      age dropped, same as convert()
```

| | Terraform 1.15.8 | OpenTofu 1.12.4 |
|---|---|---|
| `convert(v, type)` inline | yes | **no** — `Error: Invalid reference` |
| `type` on an `output` block | yes | **no** — *"An argument named \"type\" is not expected here."* |
| `type` on a `variable` | yes | yes — does the same coercion |
| `tostring`/`tonumber`/`tobool`/`tolist`/`toset`/`tomap` | yes | yes |

So the real gap is **arbitrary object/tuple schemas applied inline**, with no declared boundary. Primitives and collections are covered in both tools by the fixed casters. In OpenTofu the boundary must be a **variable** (root or module input), since typed outputs don't exist there either.

[opentofu#2630](https://github.com/opentofu/opentofu/issues/2630) verified via the GitHub API (raw JSON, not a summarized fetch — cf. the fabricated `#2084` row above): title *"General-purpose `convert` function for converting values to conform to specific type constraints"*, **state open**, created **2025-03-25**. Its motivating case is coercing `jsondecode`/`yamldecode` output, which is exactly the no-boundary situation.

### Reference shapes — resources are structural, modules switch (2026-07-17, TF 1.15.8)

The docs (and [[tf-expr-references]], faithfully) say a `count` resource is a **list** and a `for_each` resource is a **map**. The real types are structural. Verified with `terraform_data` + `terraform console`:

| Reference | Docs say | Actual |
|---|---|---|
| resource, no meta-args | object | `object` ✓ |
| resource, `count` | list of objects | **`tuple([obj, obj])`** |
| resource, `for_each` | map of objects | **`object({ x: obj, y: obj })`** |

This is the docs' declared conflation ([[tf-expr-types]] §"More About Complex Types": lists/tuples and maps/objects are used interchangeably where the distinction is irrelevant), not an error — but Ch 7 §2 teaches the distinction, so it must name the real type.

**Why structural.** Instances of one block are not guaranteed to share a type, and a collection needs exactly one element type:

```
> type(terraform_data.mixed)     # for_each = { a = "str", b = 5 }
object({
    a: object({ input: string, output: string, ... }),
    b: object({ input: number, output: number, ... }),
})
```

`a` and `b` are **different object types**.

!!! warning "A wrong claim I made first — “no map could hold them”"
    False. A map **can** hold them; it just unifies, and unification coerces. Verified:

    ```
    > terraform_data.mixed["b"].input                # structural
    5                                                # number
    > tomap(terraform_data.mixed)["b"].input         # collection
    "5"                                              # string
    > type(tomap(terraform_data.mixed))
    map(object({ id: string, input: string, output: string, ... }))
    ```

    So the reason resources are structural is **not impossibility, it's fidelity**: a collection is available but lossy, and would silently retype `b.input` from `number` to `string`. The correct claim is "a collection is possible but not free." Caught only by *running* `tomap()` on the value instead of reasoning about it from §2's rule — the rule predicted a failure that doesn't happen.

    **How the map is reachable at all:** unification recurses per attribute. `id` is `string` on both instances. `input` is `string` vs `number`, which meet at `string` because (`cty` convert.md, verbatim) *"String is the most general type, since the other two primitive types have safe conversions to string."* Hence the element type `object({ id: string, input: string, output: string, ... })`.

    **But the original claim is true in the other case.** Unification can genuinely fail, and then no map exists:

    ```
    # for_each = { a = ["x"], b = 5 }   -> input is tuple vs number
    > tomap(terraform_data.nounify)
    Invalid value for "v" parameter: cannot convert object to map of any single
    type.
    ```

    Same error as `tomap({ name = ["a"], age = 12 })` in the map rows above. So "no map could hold them" was not nonsense — it described the *no-common-type* case while the example on screen was the *coercible* case. Two regimes, and the example decides which one you're in. State which.

For resources the structural path is **unconditional** — `internal/terraform/evaluate.go:931` (`cty.TupleVal`) and `:952` (`cty.ObjectVal`), with `:844`/`:846` returning `EmptyTupleVal`/`EmptyObjectVal`. No type check, no fallback: Terraform never gambles on whether a given resource's instances happen to match.

**Modules are different, and it's a payoff for typed outputs.** `GetModule` (`evaluate.go:~429-609`) computes `noDynamicTypes` = "the module fully defines all output types" and *does* branch on it: `cty.ListVal` / `cty.MapVal` when true, `cty.TupleVal` / `cty.ObjectVal` otherwise. That condition follows from the fidelity argument above: fully-typed outputs mean every instance has the *same declared type*, so unification has nothing to reconcile and the collection is lossless. Verified end-to-end:

| Module call | Output declaration | Actual |
|---|---|---|
| `count = 2` | `output "x" { value = ... }` | `tuple([obj, obj])` |
| `count = 2` | `output "x" { type = string, ... }` | **`list(object({...}))`** |
| `for_each` | `output "x" { type = string, ... }` | **`map(object({...}))`** |

So **`type` on an output (TF 1.15+) changes the type your callers receive**, not just the docs. That's the concrete reason behind "prefer typing the outputs of any module others consume" (Ch 6). OpenTofu has no typed outputs, so module references there stay structural.

!!! warning "Two method failures worth remembering"
    1. **Generalising from `terraform_data`.** It is the only provider-free resource, and it is *atypical*: `input`/`output`/`triggers_replace` are `dynamic`. Conclusions drawn from it about schema-driven behavior may not transfer to a normal provider resource. Here the resource answer held (the code path is unconditional), but only checking the source proved that rather than luck.
    2. **Reading the wrong function.** The `noDynamicTypes` list/map branch was found first and looked like it governed resources. It is inside **`GetModule`**. Confirm the enclosing `func` before generalising from a code fragment — the resource path is `GetResource`, ~200 lines later, and behaves differently.

### Method note — every quote above was checked against raw bytes

Each quotation in this section was **first obtained via a summarizing fetch, then re-verified against the raw file** (`curl` the `raw.githubusercontent.com` URL, `grep -F` the exact string). This mattered:

- All quotes survived the check verbatim. But the summarizer had also produced *plausible-sounding* prose around them, and there is no way to tell a summarizer's paraphrase from its quotation after the fact. **Never record a quotation taken from a summarized fetch.** Re-pull the raw file.
- **Trap: these specs hard-wrap at ~76 characters.** A naive `grep "full sentence"` on the raw file returns nothing and looks exactly like a failed verification. Normalize first (`tr '\n' ' ' | tr -s ' '`) before matching, or you will "disprove" a quote that is in fact verbatim. This produced a false negative on two quotes here before the method was corrected.
- On Windows, `curl` to `raw.githubusercontent.com` fails with `schannel: ... CRYPT_E_NO_REVOCATION_CHECK`. `--ssl-no-revoke` works around it. (Unrelated to the Norton/loopback issue that breaks provider plugin mTLS.)

Sources: [hclsyntax/spec.md](https://github.com/hashicorp/hcl/blob/main/hclsyntax/spec.md) (l.279 for the literal rule) · [hcl spec.md](https://github.com/hashicorp/hcl/blob/main/spec.md) (information model, l.262-300 for the family definitions) · [go-cty convert.md](https://github.com/zclconf/go-cty/blob/main/docs/convert.md) (l.79-101 unification, conversion charts) · [go-cty types.md](https://github.com/zclconf/go-cty/blob/main/docs/types.md) · local `terraform` @ `c07e79c1c8`. Feeds [[tf-expr-types]] and [[tf-expr-type-constraints]]; the constraint-side half is Ch 12 (I3).
