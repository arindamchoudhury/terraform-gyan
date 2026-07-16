# Conditional (ternary) branch evaluation — verified facts

Last verified: **2026-07-15** against **Terraform 1.15.6** and **OpenTofu 1.12.4** (empirical: `terraform console`/`plan` and `tofu console`). Both tools behave identically.

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
