# Terraform testing: native `terraform test` vs Terratest — verified facts

**Checked:** 2026-07-04

## Native `terraform test` (`.tftest.hcl`)

- Built into the Terraform/OpenTofu binary (Terraform 1.6+). Tests written in **HCL**, no Go required.
- **Proves your *code* is right** — outputs are correct, variables behave, a module produces the right plan/apply at the Terraform layer.
- **Key limitation:** it can only assert against what the *provider reports back* (the resulting state from apply). If a provider bug creates a real resource whose actual config doesn't match what you specified, native tests still **pass** — they're testing Terraform's view, not the live resource.

## Terratest (Gruntwork)

- A **Go library** for testing infrastructure code. First-class support for Terraform, Packer, Docker, Kubernetes, AWS, GCP, and more. Helper functions like `terraform.Apply`, `ApplyAndIdempotent`, plus HTTP/SSH/cloud-API helpers.
- **Proves your *infrastructure works*** — it stands up real infrastructure, then queries the concrete resource via **its own native API** (not the Terraform/provider-reported state) and asserts on real behavior (make an HTTP request to the deployed LB, SSH to the box, call the AWS API). Catches exactly the provider-bug case native tests miss.
- Full power of Go: loops, conditionals, custom assertions, external API calls.
- **Cost:** you must know Go, and tests really deploy infra (slower, costs money, needs cloud creds).

## When to use which (2026 consensus)

- Validating Terraform config values / plan correctness → **native `terraform test`**, cheap and fast.
- Testing real external behavior of deployed infra → **Terratest**.
- Recommended balance: run **native `terraform test` on every commit**; reserve **Terratest for integration pipelines / pre-release** checks.

## Versions / status

_Corrected 2026-08-15 against the local `repos\terratest` checkout — see [[terratest-facts]] for the
source-derived detail, which supersedes this section._

- **v1.0.0 released 2026-05-11**, the first stable release. This page previously read that date as
  "latest published"; it is not a rolling latest — **v1.0.1** followed on **2026-06-27**, and the v2
  betas on **2026-07-20** and **2026-08-10** (`v2.0.0-beta.2`). Requires **Go 1.26+**.
- **v2 in beta**; the v1 line is in maintenance (security fixes only, on the `v1` branch, until 12
  months after v2.0.0 GA). v2 ships under new `/v2` module paths, so pinned v1 consumers are
  unaffected.
- The API-shape claim above needs one update: `terraform.Apply` and `ApplyAndIdempotent` are the
  **deprecated** v1 names. The current forms take a context — `terraform.ApplyContext(t, ctx, opts)`,
  `terraform.ApplyAndIdempotentContext(...)` — and the bare forms are removed in v2.

Sources: [env0 — Terratest vs terraform test](https://www.env0.com/blog/terratest-vs-terraform-opentofu-test-in-depth-comparison), [Terratest docs](https://terratest.gruntwork.io/docs/), [Terratest GitHub](https://github.com/gruntwork-io/terratest), [Spacelift — how to test Terraform](https://spacelift.io/blog/terraform-test); version and API facts re-derived from the local checkout ([[terratest-facts]]).
