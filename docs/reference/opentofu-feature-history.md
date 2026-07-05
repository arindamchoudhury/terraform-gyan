# OpenTofu Feature History

A version-by-version catalogue of OpenTofu's language, CLI, and backend
features: **when each was introduced**, and **whether it has been deprecated or
replaced**. OpenTofu-only features (no Terraform equivalent, or one that
arrived later) are marked. Companion to the
[Terraform Feature History](feature-history.md).

!!! note "Fork context"
    OpenTofu forked from **Terraform 1.5.x** in 2023 after HashiCorp's MPL→BSL
    relicense, and is now a **Linux Foundation** project under **MPL 2.0**
    (OSI-approved open source). It keeps HCL, the state-file format, and the
    provider ecosystem compatible with Terraform, so everything in the
    [foundational core and pre-1.6 timeline](feature-history.md) applies to
    OpenTofu too. This page covers what OpenTofu added **after** the fork.
    Current stable: **1.12.3** (1.12.0 released 2026-05-14).

---

## Chronological timeline

Version numbers below are **OpenTofu** versions. "OpenTofu-only" means no
Terraform CLI equivalent as of Terraform 1.15 (or Terraform got it later).

| Version | Released | Introduced | Deprecates / replaces · notes |
|---|---|---|---|
| **1.6** | Jan 2024 | **First stable GA release** — feature-compatible with Terraform 1.5.x/1.6. Same HCL, state format, providers; adds nothing net-new beyond the fork baseline. | The drop-in migration target off Terraform 1.5.x. |
| **1.7** | May 2024 | **State encryption** (client-side, at rest — local passphrase + AWS KMS / GCP KMS / OpenBao key providers); **provider-defined functions** (`provider::name::fn()`); **loopable imports** (`for_each` on `import` blocks). | State encryption is **OpenTofu-only** (Terraform has no CLI equivalent as of 1.15). Provider-defined functions reached Terraform in 1.8; loopable imports in Terraform 1.7. |
| **1.8** | Aug 2024 | **Early variable / locals evaluation** — use `var`/`local` in `backend` config, module `source`, and state-encryption blocks (resolved at `tofu init`); **provider mocking + resource overrides** in `tofu test`; **`.tofu` / `.tofurc` file extensions** (parsed alongside `.tf`). | Early evaluation is **OpenTofu-only**; Terraform 1.15 only partially closes it via `const` + dynamic module sources. |
| **1.9** | Jan 2025 | **Provider iteration — `for_each` on provider configurations** (one instance per region/account from a map/set); **`-exclude` flag** (+ `-exclude-file`) — inverse of `-target`, mutually exclusive with it. | Both **OpenTofu-only** as of Terraform 1.15. A resource's `for_each` must be a *subset* of its provider's. |
| **1.10** | Jul 2025 | **OCI registries** for **both providers and modules** (`oci://` module sources; `oci_mirror` for provider plugins — reuse ECR/GAR/ACR/Docker Hub); **S3-native state locking** (lock file in the bucket, no DynamoDB); **MCP server** for AI-assisted IaC. | S3-native locking **predates** Terraform's (which shipped it in 1.11). OCI *registries* are OpenTofu-first (Terraform 1.12 added an OCI *backend*, not registries). **DynamoDB locking no longer required.** |
| **1.11** | Dec 2025 | **Ephemeral resources + ephemeral values + write-only arguments** (`*_wo`) — secrets that never touch state or plan; **`enabled` meta-argument** — a first-class on/off switch for a resource. | Ephemeral/write-only reach **parity with Terraform 1.10/1.11**. `enabled` is **OpenTofu-only** (Terraform still uses `count = var.x ? 1 : 0`). |
| **1.12** | May 2026 | **Dynamic `prevent_destroy`** (bind to a variable/expression, not just a literal); **`destroy = false`** lifecycle arg (drop from state without destroying the remote object); **`-json-into=FILE`** (JSON stream to a file, human UI stays on stdout); **concurrent provider installation**; **OpenTelemetry tracing**. | All **OpenTofu-only** as of Terraform 1.15. `destroy = false` is the lifecycle-arg counterpart to Terraform's `removed` block; dynamic `prevent_destroy` — Terraform requires a literal. |

!!! note "1.13 (unreleased, in development)"
    On `main` as of this check — **not yet stable**, subject to change. Notable
    entries: **GCP KMS `additional_authenticated_data`** for the encryption key
    provider; **`cidrsubnets`** handling IPv6 prefix extensions beyond 32 bits;
    **local-exec sets `TRACEPARENT`** (W3C Trace Context) under OpenTelemetry;
    **OCI registry repository-scoped credentials**; **`tofu providers lock
    -oci-mirror`**. Confirm against the release notes once 1.13.0 GAs.

---

## OpenTofu-only features (vs Terraform 1.15)

Quick reference — what you get on OpenTofu that Terraform's open-source CLI
still lacks:

| Feature | OpenTofu since | Terraform status |
|---|---|---|
| State encryption (+ external key providers) | 1.7 | None |
| Early variable / locals evaluation (backend, module source, encryption) | 1.8 | Partial via `const` + dynamic module sources (1.15) |
| Provider `for_each` | 1.9 | None |
| `-exclude` / `-exclude-file` | 1.9 | None |
| OCI registries for providers **and** modules | 1.10 | OCI *backend* only (1.12) |
| `enabled` meta-argument | 1.11 | None (`count` trick) |
| Dynamic `prevent_destroy` | 1.12 | Literal only |
| `destroy = false` lifecycle arg | 1.12 | Use the `removed` block |
| `-json-into=FILE` | 1.12 | None (`-json` replaces stdout) |
| OpenTelemetry tracing | 1.12 | None |

!!! note "The gap runs both ways"
    Terraform **1.15** (2026-04-29) closed several long-standing OpenTofu-only
    gaps — dynamic module sources, variable/output `deprecated`, inline
    `convert()`, output `type` constraints. So "OpenTofu has features Terraform
    lacks" is narrower than it was, but the list above remains OpenTofu-only as
    of this check. See [version-facts](../research-cache/version-facts.md).

---

## Deprecations & replacements — quick reference

OpenTofu inherits every pre-1.6 Terraform deprecation (see the
[Terraform table](feature-history.md#deprecations-replacements-quick-reference)):
`template_file`→`templatefile()`, `null_resource`→`terraform_data`,
`terraform env`→`workspace`, quoted type constraints, etc. OpenTofu-specific:

| Deprecated / removed | Replaced by | Since |
|---|---|---|
| DynamoDB table for S3 state locking (`dynamodb_table`) | **S3-native lock file** (`use_lockfile`) | 1.10 (OpenTofu shipped this before Terraform's 1.11) |
| Storing secrets in provider args (persisted to state) | **Write-only arguments** (`*_wo`) / **ephemeral** values | 1.11 |
| `count = var.x ? 1 : 0` on/off idiom | **`enabled` meta-argument** | 1.11 |
| `terraform state rm` to forget a resource | **`destroy = false`** lifecycle arg (or the `removed` block) | 1.12 |

!!! note "Compatibility with Terraform"
    OpenTofu deliberately keeps HCL, state format, and providers compatible, so
    Terraform configs generally run unchanged. The divergence is **additive**:
    OpenTofu-only features (state encryption, provider `for_each`, `-exclude`,
    etc.) won't parse on Terraform, so a config using them is no longer portable
    back. Plan migrations at a new-project or compliance decision point rather
    than reactively.

---

## Sources

OpenTofu release blogs (1.6–1.12), the
[OpenTofu CHANGELOG](https://github.com/opentofu/opentofu/blob/main/CHANGELOG.md),
[What's new in OpenTofu](https://opentofu.org/docs/intro/whats-new/), and the
project's own [version-facts](../research-cache/version-facts.md) /
[tf115-ot112-features](../research-cache/tf115-ot112-features.md) caches.
Verified 2026-07-05. Release months for 1.6–1.11 are approximate; the 1.13
(unreleased) entry is from the `main` branch changelog and will change before
GA. Per-release minor function/flag additions are not exhaustively enumerated —
consult the CHANGELOG for the full list.
