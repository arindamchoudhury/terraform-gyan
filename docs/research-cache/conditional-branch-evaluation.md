# Conditional (ternary) branch evaluation — verified facts

Last verified: **2026-07-15** against **Terraform 1.15.6** (empirical: `terraform console` + `terraform plan`).

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

> ❓ Not re-verified on OpenTofu 1.12 — the tool differs from Terraform on `&&`/`||` short-circuit history, so don't assume identical ternary behavior without testing. Scope claims to Terraform unless checked.
