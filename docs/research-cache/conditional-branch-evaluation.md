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

## Takeaways

- Both result branches must be **type-compatible** — this is a type check Terraform does regardless of the condition, so it fails even when the taken branch is valid.
- A branch's **runtime evaluation** error (out-of-range index, `count=0` index, division by zero, failed conversion) surfaces **only if that branch is selected**. The untaken branch is not evaluated — including when the condition is unknown at plan time.
- Practical rule: **guard the branch you might take**, not "both." `try(...)` is the tool when the branch you select could itself error (e.g. `try(module.x[0].ip, null)`), not to protect an unused branch.
- **Outdated sources:** TID (2025) and pre-1.x guidance say both branches are evaluated. Correct historically for older Terraform / the type-check framing, but not the runtime behavior on 1.15.6.

> ❓ Not re-verified on OpenTofu 1.12 — the tool differs from Terraform on `&&`/`||` short-circuit history, so don't assume identical ternary behavior without testing. Scope claims to Terraform unless checked.
