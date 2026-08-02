# Terraform Feature History

A version-by-version catalogue of Terraform's language, CLI, and workflow
features: **when each was introduced**, and **whether it has been deprecated or
replaced**. Where a feature is OpenTofu-only (or reached OpenTofu at a different
version), that is called out explicitly.

!!! note "Version context"
    Current stable at time of writing: **Terraform 1.15.8** (1.15.0 released
    2026-04-29) and **OpenTofu 1.12.4** (1.12.0 released 2026-05-14). OpenTofu
    forked from Terraform 1.5.x in 2023 after the MPL→BSL relicense, so the two
    tools share everything up to 1.5 and diverge after. See
    [Version & Certification Facts](../research-cache/version-facts.md) and the
    [feature → learning-path coverage matrix](../research-cache/feature-coverage-matrix.md).

---

## Chronological timeline

### Foundational core (0.1–0.11, "always been there")

These primitives predate the tracked feature timeline below — they existed in
early Terraform (2014–2018) and are the bedrock every later feature builds on.
Listed here so the catalogue is complete, not because they map to a single
headline release.

| Feature | Since | Notes |
|---|---|---|
| `resource`, `provider`, `variable`, `output`, `data`, `module` blocks | early 0.x | The core block kinds. `locals` came a bit later (0.10). |
| `count` meta-argument | early 0.x | `for_each` on resources arrived with HCL2 in 0.12. |
| `lifecycle`: `create_before_destroy`, `prevent_destroy`, `ignore_changes` | early 0.x | `replace_triggered_by` added 1.2. |
| Provisioners: `local-exec`, `remote-exec`, `file`, `connection` + `null_resource` | early 0.x | "Last resort" escape hatch; `terraform_data` (1.4) replaces `null_resource`. |
| Backends & remote state; `terraform_remote_state` | 0.9 (backends) / 0.11.13 (`remote` backend) | State locking, partial config layered on later. |
| Workspaces (originally "environments") | 0.9 as `terraform env` | **Renamed to `terraform workspace` in 0.10.** |

### Pre-1.0 (the breaking-change era)

| Version | Released | Headline features | Notes |
|---|---|---|---|
| **0.11** | 2017 | Last release before HCL2. Interpolation-only syntax (`"${...}"` everywhere), no `for_each`, no rich types. | Everything below 0.12 is now historical; upgrade tooling (`0.12upgrade`) existed to migrate. |
| **0.12** | May 2019 | **HCL2**: first-class expressions, rich types (`list`, `map`, `object`, `tuple`), `for` expressions, **`dynamic` blocks**, conditional/ternary, `templatefile()` function. | The big language rewrite. `template_file` data source (external provider) effectively superseded by the built-in `templatefile()`. |
| **0.13** | Aug 2020 | **`required_providers` with source addresses** (third-party/community providers auto-installed from the registry); `count`/`for_each`/`depends_on` on **module** blocks; custom provider namespaces. | Made the community provider ecosystem possible. |
| **0.14** | Dec 2020 | **Dependency lock file** (`.terraform.lock.hcl`); `sensitive = true` on variables and outputs; concise plan diffs. | Lock file is now a committed-to-VCS staple. |
| **0.15** | Apr 2021 | Final pre-1.0 breaking changes: removed quoted type constraints (`"string"` → `string`), `list()`/`map()` → `tolist()`/`tomap()`; **experimental** `terraform test` first appears; **`-refresh-only` plan/apply mode** (0.15.4). | These were intended as the last breaking changes before 1.0. |

### 1.x (the compatibility-promise era)

From 1.0 on, HashiCorp promised state and config compatibility across the 1.x
line. Each minor release is additive.

| Version | Released | Introduced | Deprecates / replaces |
|---|---|---|---|
| **1.0** | Jun 2021 | Stability & compatibility promise for the 1.x series (not a feature release — Terraform was already production-grade). | — |
| **1.1** | Dec 2021 | **`moved` block** — refactor resource/module addresses declaratively instead of `terraform state mv`; **`cloud` block** for native Terraform Cloud/HCP integration; **`nullable`** variable argument. | Reduces need for manual `state mv`. `cloud` block is the modern alternative to a `remote` backend for HCP. |
| **1.2** | May 2022 | **`precondition` / `postcondition`** custom-condition blocks; **`replace_triggered_by`** lifecycle argument; cloud-run OPA output in CLI. | — |
| **1.3** | Sep 2022 | **Optional object-type attributes with defaults** (`optional(type, default)`) graduate from experimental; `moved` extended to third-party modules. | — |
| **1.4** | Mar 2023 | **`terraform_data`** built-in managed resource. | **Replaces `null_resource`** (no more `hashicorp/null` provider needed for the common cases). |
| **1.5** | Jun 2023 | **`import` block** (config-driven import) + **`-generate-config-out`** codegen; **`check` block** (standalone assertions); new functions **`strcontains()`** and **`plantimestamp()`**. **License change: MPL → BSL 1.1** — this triggered the OpenTofu fork. | `import` block reduces reliance on the imperative `terraform import` command. |
| **1.6** | Oct 2023 | **`terraform test` framework GA** (`.tftest.hcl`, `run` blocks, assertions). | **Replaces the experimental test feature** from 0.15. |
| **1.7** | Jan 2024 | **Test mocking** (`mock_provider`, `override_resource`/`override_data`); **`removed` block** (config-driven remove — drop from state without destroying); **`for_each` on `import` blocks** (loop imports over a map). | `removed` block replaces the "comment out + `state rm`" workaround. |
| **1.8** | Apr 2024 | **Provider-defined functions** (`provider::name::fn()`) — providers can ship their own functions; built-in provider functions **`encode_tfvars`**, **`decode_tfvars`**, **`encode_expr`** (`provider::terraform::…`). | — |
| **1.9** | Jun 2024 | **Cross-object variable validation** (a `validation` condition can now reference other variables, data sources, locals); **`templatestring()`** function. | Removes the old "validation can only reference the variable itself" limitation. |
| **1.10** | Nov 2024 | **Ephemeral resources** + ephemeral values, including **ephemeral input variables and outputs** — data that is never written to plan or state. | New primitive for short-lived secrets/tokens. |
| **1.11** | Feb 2025 | **Write-only arguments** (`*_wo` + `*_wo_version`) — send secrets to a provider without persisting them in state; **S3-native state locking GA** (lock file in the bucket). | **Deprecates DynamoDB-based S3 locking** (`dynamodb_table`); marked for removal in a future minor. |
| **1.12** | 2025 | **OCI Object Storage backend**; `terraform test -parallelism` + per-run parallel annotations; **import block `identity`** attribute (mutually exclusive with `id`); short-circuiting logical operators. | — |
| **1.13** | Aug 2025 | **Terraform Stacks in the CLI** (`terraform stacks` command, previously HCP-only); **`terraform rpcapi`** command GA (for tooling/integrators); test enhancements — **external variables inside `.tftest.hcl`** and cross-run output references, parallel teardown; much faster evaluation of high-cardinality `count`/`for_each`. | — |
| **1.14** | 2025 | **List resources** (`*.tfquery.hcl`) + **`terraform query`** command; **`actions` block** — provider-defined operations outside the CRUD lifecycle (e.g. invoke a Lambda, trigger a CDN invalidation); test-framework output improvements. | — |
| **1.15** | Apr 2026 | **Dynamic module sources** (variables in `source`/`version`) + **`const` variable attribute**; **`deprecated` attribute** on `variable`/`output`; **`convert()`** function; **`type` constraint on `output`**; functions usable inside `mock_data`/`override_resource`; S3 backend `aws login` credentials; Windows ARM64 builds. | `deprecated` gives module authors a first-class way to sunset variables/outputs. Closes several long-standing gaps to OpenTofu. |

!!! note "1.16 (unreleased, in development)"
    On `main` as of this check — **not yet a stable release**, subject to change.
    Notable entries in the 1.16 changelog: **`import` blocks inside modules**;
    a **`store` block in `terraform_data`** for ephemeral/sensitive values;
    providers can use **nested blocks as computed values**; action-trigger
    **`on_failure` modes** (`halt`/`taint`/`continue`) plus a `caller` symbol and
    before/after-destroy action events; **`workspace list -json`**; JSON output
    for `terraform state show`; `contains()` can now test for `null`; Linux
    s390x builds. Also **readable cycle errors**: the `Error: Cycle:` message
    becomes one node per line, ordered by reference rather than graph traversal,
    from a consistent starting node — same error and same fix, just legible on a
    loop spanning many nodes. Confirm against the release notes once 1.16.0 GAs.

---

## OpenTofu divergence

OpenTofu forked at Terraform 1.5.x and shipped features Terraform's
open-source CLI lacked. Version numbers below are **OpenTofu** versions. For the
full per-version OpenTofu catalogue, see
[OpenTofu Feature History](opentofu-feature-history.md).

| OpenTofu version | Feature | Terraform equivalent? |
|---|---|---|
| **1.7** | **State encryption** (client-side, with external key providers) | None in Terraform CLI as of 1.15 |
| **1.9** | **Provider `for_each`** (multiple provider instances from a collection) | None as of 1.15 |
| **1.8** | **Early variable / `.tfvars` evaluation** (variables usable in `backend`, module sources) | Partially addressed by TF 1.15 `const` + dynamic module sources |
| **1.9** | **`-exclude`** flag (and `-exclude-file`) — inverse of `-target` | None as of 1.15 |
| **1.10** | **OCI registries** for modules *and* providers; experimental **OpenTelemetry tracing** | Terraform 1.12 added an OCI **backend**, not OCI registries; no OTel in Terraform |
| **1.11** | **Ephemeral resources / write-only arguments** (parity with TF 1.10/1.11) | Yes — TF 1.10 / 1.11 |
| **1.11** | **`enabled`** — an argument in the `lifecycle` block (OpenTofu-only convenience) | None; use `count = var.x ? 1 : 0` |
| **1.12** | **Dynamic `prevent_destroy`** (expression, not just literal) | Terraform requires a literal |
| **1.12** | **`destroy = false`** lifecycle arg (drop from state without destroying) | Use the `removed` block instead |
| **1.12** | **`-json-into=FILE`** (JSON stream to file, human UI stays on stdout) | None (`-json` replaces stdout) |
| **1.12** | Concurrent provider installation; full cross-platform provider checksums at `init` | — |

!!! note "Which to pick for new work"
    2026 third-party guidance increasingly frames **OpenTofu as the lower-risk
    default for new projects** (OSI-approved MPL 2.0, Linux Foundation
    governance, full provider compatibility, plus the CLI features above).
    Staying on Terraform makes sense for teams invested in **HCP Terraform** or
    **Terraform Stacks** (Terraform-exclusive). See
    [version-facts](../research-cache/version-facts.md) for the full rationale.

---

## Deprecations & replacements — quick reference

| Deprecated / removed | Replaced by | Since |
|---|---|---|
| `template_file` data source (`hashicorp/template` provider) | Built-in **`templatefile()`** function | 0.12 |
| Quoted type constraints (`"string"`, `"list"`) | Bare types (`string`, `list(...)`) | 0.15 (removed) |
| `list()` / `map()` functions | `tolist()` / `tomap()` | 0.15 |
| `terraform env` subcommand | **`terraform workspace`** | 0.10 (renamed; old form warns) |
| `environment` key in `terraform_remote_state` | **`workspace`** key | (renamed with workspaces) |
| `null_resource` (`hashicorp/null`) for the common cases | **`terraform_data`** built-in | 1.4 |
| Experimental `terraform test` (0.15) | **GA test framework** (`.tftest.hcl`) | 1.6 |
| `terraform taint` / `untaint` commands | **`terraform apply -replace=ADDR`** (recreation shown in plan first) | ~0.15.2 |
| `terraform refresh` command | **`-refresh-only`** on `plan`/`apply` (the command is an alias for `apply -refresh-only -auto-approve`, with no way to disable the auto-approve) | 0.15.4 |
| Imperative `terraform import` command (as the only path) | **`import` block** (config-driven) | 1.5 |
| "Comment out + `terraform state rm`" workaround | **`removed` block** | 1.7 (TF) / `destroy = false` in OpenTofu 1.12 |
| DynamoDB table for S3 state locking (`dynamodb_table`) | **S3-native lock file** (`use_lockfile`) | 1.11 (GA); DynamoDB marked for removal |
| Storing secrets in provider args (persisted to state) | **Write-only arguments** (`*_wo`) / **ephemeral** values | 1.10–1.11 |

!!! warning "Terraform's compatibility promise ≠ never-deprecate"
    Within the 1.x line, existing configs keep working, but individual
    arguments (like S3 `dynamodb_table`) and provider resources get deprecated
    with warnings and eventual removal in a later minor. Watch `terraform
    validate` / `plan` output for deprecation diagnostics, and pin
    `required_version` so a surprise upgrade doesn't hit a removal.

---

## Sources

Grounded in HashiCorp release blogs (1.1–1.15), the
[Terraform CHANGELOG](https://github.com/hashicorp/terraform/blob/main/CHANGELOG.md),
OpenTofu release notes (1.7–1.12), and the project's own
[version-facts](../research-cache/version-facts.md) /
[tf115-ot112-features](../research-cache/tf115-ot112-features.md) caches.
Verified 2026-07-05 (re-audited against per-release notes — added import
`for_each` (1.7), ephemeral variables/outputs (1.10), and the `strcontains`/
`plantimestamp` functions (1.5)). Pre-1.0 feature attributions cross-checked
against the HashiCorp release history and *Terraform in Depth* Ch1–2. The 1.16
(unreleased) entry is drawn from the `main` branch
[CHANGELOG](https://github.com/hashicorp/terraform/blob/main/CHANGELOG.md) and
will change before GA.

**Scope:** this lists the *headline* language/CLI/workflow feature per release.
Each minor also adds a handful of built-in functions and small CLI flags that
are not individually enumerated here — consult the
[CHANGELOG](https://github.com/hashicorp/terraform/blob/main/CHANGELOG.md) for
the exhaustive per-version list. Treat specific patch numbers and un-blogged
minor details (1.12–1.14) as changelog snapshots, not fixed facts.
