# Early variable evaluation in backend config (OpenTofu)

> **Source:** [opentofu.org/docs/language/settings/backends/configuration](https://opentofu.org/docs/language/settings/backends/configuration/)
> **Added:** 2026-07-03
> **Source updated:** OpenTofu current docs (early evaluation introduced in **1.8**)
> **Tags:** opentofu, backend, variables, early-evaluation, state, divergence
> **Type:** documentation

OpenTofu-only (since 1.8): you can reference **variables and locals** inside `provider` and `backend` blocks. These are resolved in a special **early phase during `tofu init`**, before the backend is initialized and before state is available. Terraform's open-source CLI still requires literals or `-backend-config` partials here.

## Variables and Locals in a backend block

```hcl
locals {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    region = local.region
  }
}
```

**Restrictions (all must hold):**

- May reference **only** variables and locals — no references to state data, data-source attributes, or provider-defined functions.
- Everything must resolve **during `tofu init`, before state exists** (i.e. statically determinable).
- Recommended **against** using variables for secrets/credentials here — can leak into `.terraform/` and plan files.

## Why it matters

Removes the need for backend **partial configuration** (`-backend-config=…` at `init`) just to vary things like region/bucket per environment. Config becomes more self-contained. Still, changing backend config always requires re-running `tofu init`.

## Backend config baseline (context)

- A configuration provides exactly **one** `backend` block; default backend is `local` (state file on disk).
- Backend config is written in plaintext to `.terraform/terraform.tfstate` (the local backend record, distinct from real state) and captured into saved plan files — never commit `.terraform/`.
- **Partial configuration**: omit some args and supply them at `init` via `-backend-config=PATH` (a `*.backendname.tfbackend` file), `-backend-config="KEY=VALUE"`, or interactive prompt. Later CLI options override earlier ones; merged result lands in `.terraform/`.
- Prefer **environment variables** for credentials; time-limited creds captured in a saved plan may expire before `apply`.

---
Related: OpenTofu divergence feature for the **E3** milestone. Shares the "static evaluation only" constraint that also governs [[ot-provider-for-each]]. Builds on the backend/state concepts introduced in [[terraform-intro]].
