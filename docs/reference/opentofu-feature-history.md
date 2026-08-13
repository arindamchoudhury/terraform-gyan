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
    Current stable: **1.12.4** (1.12.0 released 2026-05-14).

!!! note "Want the exhaustive version?"
    This page lists the *headline* feature per release. For every feature,
    enhancement, and patch-release change from `1.6` through the unreleased
    `1.13`, derived directly from each version branch's `CHANGELOG.md`, see the
    [OpenTofu Release Feature Map](opentofu-release-feature-map.md). It also
    traces how single capabilities (state encryption, targeting, testing,
    installation) were widened release by release.

---

## Chronological timeline

Version numbers below are **OpenTofu** versions. "OpenTofu-only" means no
Terraform CLI equivalent as of Terraform 1.15 (or Terraform got it later).

| Version | Released | Introduced | Deprecates / replaces · notes |
|---|---|---|---|
| **1.6** | Jan 2024 | **First stable GA release** — feature-compatible with Terraform 1.5.x/1.6. Same HCL, state format, providers; adds nothing net-new beyond the fork baseline. | The drop-in migration target off Terraform 1.5.x. |
| **1.7** | Apr 2024 | **State encryption** (client-side, at rest — local passphrase + AWS KMS / GCP KMS / OpenBao key providers, AES-GCM method, plus an unannounced `unencrypted` method for migrating back out); **provider-defined functions** (`provider::name::fn()`); **`removed` block**; **loopable imports** (`for_each` on `import` blocks). | State encryption is **OpenTofu-only** (Terraform has no CLI equivalent as of 1.15). Provider-defined functions reached Terraform in 1.8; loopable imports in Terraform 1.7; `removed` in Terraform 1.7. |
| **1.8** | Jul 2024 | **Early variable / locals evaluation** — use `var`/`local` in `backend` config, module `source`, and state-encryption blocks (resolved at `tofu init`); **provider mocking + resource overrides** in `tofu test`; **`.tofu` file extension** (parsed alongside `.tf`, for OpenTofu-specific overrides). | Early evaluation is **OpenTofu-only**; Terraform 1.15 only partially closes it via `const` + dynamic module sources. The `.tofurc` CLI config file is **not** new here; it is the renamed `.terraformrc` and dates to the 1.6 fork baseline. |
| **1.9** | Jan 2025 | **Provider iteration — `for_each` on provider configurations** (one instance per region/account from a map/set); **`-exclude` flag** — inverse of `-target`, and rejected if combined with it; **`-show-sensitive`** to unmask sensitive values; `-consolidate-warnings` / `-consolidate-errors`. | Both **OpenTofu-only** as of Terraform 1.15. **Do not drive a resource's `for_each` and its provider's `for_each` from the same collection**: removing an element then removes the resource instance and the provider instance that has to destroy it in the same plan, and OpenTofu errors telling you to re-add the element first. The provider's collection must be able to outlive the resource's. `-exclude-file`/`-target-file` came in 1.10. |
| **1.10** | Jun 2025 | **OCI registries** for **both providers and modules** (`oci:` module sources; `oci_mirror` for provider plugins — reuse ECR/GAR/ACR/Docker Hub); **S3-native state locking** (lock file in the bucket, no DynamoDB); experimental **OpenTelemetry tracing** (off by default; `OTEL_*` env vars); **`-target-file` / `-exclude-file`** (file-driven targeting); **global provider plugin-cache locking** (concurrent-safe shared cache); **short-circuiting `&&` / <code>&#124;&#124;</code>**; **`pg` backend stores multiple states per database**. | OCI *registries* are OpenTofu-first (Terraform 1.12 added an OCI *backend*, not registries). **DynamoDB locking no longer required**, but note that Terraform got S3-native locking **first**, in 1.10 (Nov 2024) and GA in 1.11 (Feb 2025), ahead of this release (Jun 2025). Short-circuit operators reached Terraform in 1.12. |
| **1.11** | Dec 2025 | **Ephemeral resources + ephemeral values + write-only arguments** (`*_wo`) — secrets that never touch state or plan; **`enabled`** — a first-class on/off switch for a resource, written **inside the `lifecycle` block**. | Ephemeral/write-only reach **parity with Terraform 1.10/1.11**. `enabled` is **OpenTofu-only** (Terraform still uses `count = var.x ? 1 : 0`). Verified on 1.12.4: [[opentofu-enabled-argument]]. |
| **1.12** | May 2026 | **Dynamic `prevent_destroy`** (bind to a variable/expression, not just a literal); **`destroy = false`** lifecycle arg (drop from state without destroying the remote object); **`-json-into=FILE`** (JSON stream to a file, human UI stays on stdout); **`language` block** with a nested `compatible_with "<software>"` version constraint; **`const = true`** on input variables; **concurrent provider installation**; **full cross-platform provider checksums** (`zh:`+`h1:`) written to the lock file at `tofu init`; `local` backend writes pretty-printed JSON state. | `destroy = false` is the lifecycle-arg counterpart to Terraform's `removed` block, and **Terraform 1.16 adds the same argument**; dynamic `prevent_destroy` — Terraform requires a literal. `const` also exists in Terraform 1.15, undocumented there. The `language` block's `edition` argument is reserved and inert, mirroring Terraform's `language = TF2021`; only `compatible_with` does work. |

!!! note "1.13 (unreleased, in development)"
    On `main` as of this check — **not yet stable**, subject to change. Notable
    entries: the **`winrm` provisioner connection type is removed** (deprecated
    in 1.12; migrate to SSH); **Windows ARM64** becomes officially supported;
    **GCP KMS `additional_authenticated_data`**, **AWS KMS `encryption_context`**
    and **OpenBao `associated_data`** for the encryption key providers;
    **`cidrsubnets`** handling IPv6 prefix extensions beyond 32 bits;
    **local-exec sets `TRACEPARENT`** (W3C Trace Context) under OpenTelemetry;
    **OCI registry repository-scoped credentials**; **`tofu providers lock
    -oci-mirror`**. It is also the **final series with official 32-bit builds**.
    Confirm against the release notes once 1.13.0 GAs.

!!! warning "The MCP server is not a CLI feature"
    OpenTofu ships an [MCP server](https://github.com/opentofu/opentofu-mcp-server)
    that gives AI assistants access to the OpenTofu **Registry**, and the 1.10
    release blog promotes it. It is a **separate project with its own
    versioning**, not part of the `opentofu/opentofu` CLI, and nothing
    corresponding to it exists in the CLI repository. Do not read it as a
    feature introduced by CLI 1.10.

---

## OpenTofu-only features (vs Terraform 1.15)

Quick reference — what you get on OpenTofu that Terraform's open-source CLI
still lacks:

| Feature | OpenTofu since | Terraform status |
|---|---|---|
| State encryption (+ external key providers) | 1.7 | None |
| Early variable / locals evaluation (backend, module source, encryption) | 1.8 | Partial via `const` + dynamic module sources (1.15) |
| Provider `for_each` | 1.9 | None |
| `-exclude` (1.9); `-exclude-file` / `-target-file` (1.10) | 1.9 / 1.10 | None |
| OCI registries for providers **and** modules | 1.10 | OCI *backend* only (1.12) |
| `enabled` (`lifecycle` argument) | 1.11 | None (`count` trick) |
| Dynamic `prevent_destroy` | 1.12 | Literal only |
| `destroy = false` lifecycle arg | 1.12 | Terraform **1.16** adds it; before that, the `removed` block |
| `-json-into=FILE` | 1.12 | None (`-json` replaces stdout) |
| OpenTelemetry tracing (experimental) | 1.10 | None |
| `.tofu` file extension (OpenTofu-specific overrides of `.tf`) | 1.8 | None |
| `-show-sensitive` (unmask sensitive values) | 1.9 | None |
| `pg` backend: multiple states per database | 1.10 | None |
| `language` block with `compatible_with "<software>"` | 1.12 | None (`required_version` only) |
| `local` backend writes pretty-printed JSON state | 1.12 | None |

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
| DynamoDB table for S3 state locking (`dynamodb_table`) | **S3-native lock file** (`use_lockfile`) | 1.10 (Terraform got there first: introduced in its 1.10, GA in 1.11) |
| Storing secrets in provider args (persisted to state) | **Write-only arguments** (`*_wo`) / **ephemeral** values | 1.11 |
| `count = var.x ? 1 : 0` on/off idiom | **`enabled`** (in `lifecycle`) | 1.11 |
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
Verified 2026-07-05.

**Reconciled 2026-08-13** against the
[OpenTofu Release Feature Map](opentofu-release-feature-map.md) and the
repository. Release months are now exact, taken from the git tag dates, which
moved three of them: 1.7 to **April 2024**, 1.8 to **July 2024**, and 1.10 to
**June 2025**. Four claims were corrected: S3-native locking did **not** precede
Terraform's (Terraform introduced it in 1.10 in November 2024 and GA'd it in
1.11 in February 2025, both before OpenTofu 1.10 in June 2025); `.tofurc` is the
renamed `.terraformrc` from the 1.6 fork baseline rather than a 1.8 addition;
the MCP server is a separate repository, not a CLI 1.10 feature; and
`destroy = false` is no longer OpenTofu-only now that Terraform 1.16 has it.

The 1.13 (unreleased) entry is from the `main` branch changelog and will change
before GA. Per-release minor function/flag additions are not exhaustively
enumerated — consult the
[Release Feature Map](opentofu-release-feature-map.md) or the CHANGELOG.
