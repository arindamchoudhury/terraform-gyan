# Terraform + OpenTofu feature → learning-path coverage matrix

**Built:** 2026-07-04 · **updated 2026-07-05** (folded in 1.9 / 1.12 / 1.14 features surfaced while writing [[feature-history]]). Terraform 1.15.7 / OpenTofu 1.12.3. Audit of the full feature surface against `learning-path.md`. ✅ = covered · ➕ = added in this audit · ⬜ = intentionally out of scope.

## Language: top-level blocks

| Feature | Topic | Status |
|---|---|---|
| `terraform` block (`required_version`, `required_providers`) | B2 | ✅ |
| `terraform { backend }` / `cloud` block | I6 / A4 | ✅ |
| `provider` block, `alias`, multiple instances | B5, I8 | ✅ |
| `resource` block | B5 | ✅ |
| `data` source block | B8 | ✅ |
| `variable` | B6 | ✅ |
| `output` | B6 | ✅ |
| `locals` | B6 | ✅ |
| `module` block | I4 | ✅ |
| `moved` block | I7 | ✅ |
| `import` block | I7 | ✅ |
| `removed` block | I7 | ✅ |
| `check` block (+ custom conditions) | A2 | ✅ |
| `ephemeral` resource block (TF 1.10 / OT 1.11) | A6 | ➕ |
| `actions` block — provider-defined side-effect ops (TF 1.14) | A1 | ➕ |
| list resources `*.tfquery.hcl` + `terraform query` (TF 1.14) | B8 | ➕ |

## Meta-arguments & lifecycle

| Feature | Topic | Status |
|---|---|---|
| `count` | I1 | ✅ |
| `for_each` | I1 | ✅ |
| `depends_on` | I1 | ✅ |
| `provider` (per-resource) | I8 | ✅ |
| `lifecycle`: `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by` | I2 | ✅ |
| `precondition` / `postcondition` | A2 | ✅ |
| dynamic `prevent_destroy` (OT 1.12, OpenTofu-only) | E3 | ✅ |
| `destroy = false` lifecycle (OT 1.12, OpenTofu-only) | I7 | ✅ |
| `enabled` meta-argument (OT 1.11, OpenTofu-only) | I1 | ➕ |

## Variables / outputs / expressions / functions

| Feature | Topic | Status |
|---|---|---|
| Variable type constraints, `default`, `validation`, `sensitive` | B6 | ✅ |
| Variable `nullable` argument (TF 1.1) | B6 | ➕ |
| Variable `deprecated` (TF 1.15) | I5 | ✅ |
| Variable `const` (TF 1.15) | I4 | ✅ |
| Output `sensitive`, `precondition`, `type` (TF 1.15) | B6 | ✅ |
| Output `deprecated` (TF 1.15) | I5 | ✅ |
| Expressions: conditionals, `for`, splat, string templates | B7 | ✅ |
| Cross-object variable `validation` (reference other vars/data/locals; TF 1.9) | A2 | ➕ |
| `templatestring()` (TF 1.9) | B7 | ➕ |
| Short-circuiting `&&` / `||` operators (TF 1.12) | B7 | ➕ |
| `dynamic` blocks + complex/optional types | I3 | ✅ |
| Built-in function library | B7 | ✅ |
| `convert()` (TF 1.15) | B7 | ✅ |
| **Provider-defined functions** `provider::x::fn()` (TF 1.8) | B7 (use) / E1 (author) | ➕ |

## State, backends, workspaces

| Feature | Topic | Status |
|---|---|---|
| State fundamentals, `terraform.tfstate` | B9 | ✅ |
| Backends (S3, GCS, azurerm, HCP) | I6 | ✅ |
| OCI Object Storage backend (TF 1.12) | I6 | ➕ |
| `import` block `identity` attribute (TF 1.12) | I7 | ➕ |
| `import` block `for_each` (TF/OT 1.7) | I7 | ➕ |
| `-refresh-only` plan/apply mode (0.15.4) | I7 | ➕ |
| State locking | I6 | ✅ |
| **Native S3 state locking** (lockfile; TF 1.11 / OT 1.10, deprecates DynamoDB) | I6 | ➕ |
| `terraform_remote_state` | I6 | ✅ |
| CLI workspaces | A7 | ✅ |
| Sensitive data in state | B9 / A6 | ✅ |
| State ops: `import`/`state mv`/`rm`/`refresh`, drift | I7 | ✅ |
| **Config generation `-generate-config-out`** (TF 1.5) | I7 | ➕ |
| State encryption (OT 1.7, OpenTofu-only) | E3 | ✅ |

## Modules

| Feature | Topic | Status |
|---|---|---|
| Module sources (registry/git/local), version constraints | I4 | ✅ |
| Dynamic module sources (TF 1.15) | I4 | ✅ |
| Authoring: layout, validation, publishing | I5 | ✅ |
| Module meta-args (count/for_each/depends_on/providers) | I4/I8 | ✅ |
| Private registry | A4 / E6 | ✅ |
| **OCI registries for modules & providers** (OT 1.10, OpenTofu-first) | E4 | ➕ |
| No-code modules (HCP) | E6 | ✅ |

## Secrets & sensitive data

| Feature | Topic | Status |
|---|---|---|
| `sensitive` flag | A6 | ✅ |
| Vault provider / secret injection | A6 | ✅ |
| Dynamic provider credentials (OIDC) | A6 | ✅ |
| **Ephemeral values / ephemeral resources** (TF 1.10 / OT 1.11) | A6 | ➕ |
| **Write-only arguments** (`*_wo` + `*_wo_version`; TF 1.11 / OT 1.11) | A6 | ➕ |

## Providers, provisioners, escape hatches

| Feature | Topic | Status |
|---|---|---|
| Provider config in depth, aliases, multi-region | I8 | ✅ |
| Provisioners (`local-exec`, `remote-exec`, `file`, `connection`) | A1 | ✅ |
| `terraform_data` / `null_resource` | A1 | ✅ |
| Writing custom providers (Plugin Framework) | E1 | ✅ |

## Testing, CI/CD, policy, collaboration

| Feature | Topic | Status |
|---|---|---|
| Native `terraform test` (`.tftest.hcl`, mocks/overrides) | A2 | ✅ |
| Functions in `mock_data`/`override_resource` (TF 1.15) | A2 | ✅ |
| `terraform test -parallelism` + parallel run annotations (TF 1.12) | A2 | ➕ |
| Terratest (Go, e2e) | A2 | ✅ |
| CI/CD automation, saved plans | A3 | ✅ |
| `-json-into` (OT 1.12, OpenTofu-only) | A3 | ✅ |
| HCP Terraform (workspaces, runs, run tasks) | A4 | ✅ |
| `cloud` block for HCP integration (TF 1.1) | A4 | ➕ |
| Policy as code (Sentinel, OPA) | A5 | ✅ |
| Multi-env / multi-account, Terragrunt | A7 / E4 | ✅ |
| Refactoring at scale | A8 | ✅ |

## Advanced / expert

| Feature | Topic | Status |
|---|---|---|
| Terraform Stacks (components, deployments) | E2 | ✅ |
| OpenTofu deep dive & migration | E3 | ✅ |
| Large-scale state & repo architecture | E4 | ✅ |
| Debugging (`TF_LOG`), performance, `-parallelism` | E5 | ✅ |
| Concurrent provider install (OT 1.12) | E5 | ✅ |
| OpenTelemetry tracing (OT 1.10, experimental, OpenTofu-only) | E5 | ➕ |
| Platform engineering / self-service | E6 | ✅ |

## OpenTofu-only, as of 2026-07-04

state encryption · provider `for_each` · early variable evaluation · `-exclude` (+ `-exclude-file`) · dynamic `prevent_destroy` · `destroy = false` · `-json-into` · `enabled` meta-argument · OCI registries (providers+modules) · external key providers · OpenTelemetry tracing. Ephemeral resources/write-only reached OpenTofu in 1.11 (parity with TF 1.10/1.11).

## Intentionally out of scope (⬜ — noted, no topic change)

Windows ARM64 builds · S3 `aws login` creds · `-target-file`/`-exclude-file` file variants (mentioned in E3) · global provider cache lock · `.tofu`/`.tofurc` file extensions · provider `provider_meta` · experiments framework.

## Sources

`version-facts.md`, `tf115-ot112-features.md`, `../reference/feature-history.md`, plus HashiCorp/OpenTofu release blogs 1.5–1.15 / 1.7–1.12 and the HCDocs + OTDocs language references (checked 2026-07-04; 1.9/1.12/1.14 rows added 2026-07-05).
