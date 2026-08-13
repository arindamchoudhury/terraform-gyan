# OpenTofu Release Feature Map (CHANGELOG-derived)

A complete, release-by-release catalogue of what each OpenTofu version
**added**, and — for capabilities that grew over several releases — **how each
version enhanced what came before**.

Derived directly from the per-branch `CHANGELOG.md` files in
`opentofu/opentofu` (branches `v1.6` through `v1.12`, plus `main` for the
unreleased 1.13), not from release notes or blog posts. Features that landed in
a *patch* release are called out, since those are easy to miss.

!!! warning "The changelog is not complete"
    Several real components are announced by no changelog entry at all. They
    are collected in [Part 3](#part-3-what-the-changelog-does-not-say), built
    by diffing the configuration schemas and the encryption registry across
    release tags rather than by reading release notes.

!!! note "Where the history starts"
    OpenTofu forked from Terraform at **1.5.x** in 2023, so everything in
    Terraform up to and including 1.5 is inherited and is *not* re-listed here.
    Read this page alongside the
    [Terraform Release Feature Map](release-feature-map.md), which covers 0.5
    through 1.16 and is where the shared foundation lives.

    OpenTofu 1.6.0 is therefore the fork's first release, matched roughly
    against Terraform 1.6, and its changelog mixes OpenTofu-original changes
    with upstream work merged before the two projects diverged.

!!! note "Version context"
    Verified 2026-08-13 against the version branches at that date. **1.12.4** is
    the newest tagged release in the 1.12 series; **1.13.0 is unreleased** and
    lives only on `main`, so those rows will change.

    Support windows stated in the changelogs: 1.11.x until **2026-08-01**,
    1.12.x until **2027-02-01**, 1.13.x until **2027-08-01**.

    For the condensed view and the Terraform comparison, see
    [OpenTofu Feature History](opentofu-feature-history.md).

---

## Part 1 — Feature threads

### State and plan encryption (OpenTofu-only)

The flagship feature with no Terraform equivalent. It arrived whole in 1.7 and
has been widened every release since.

| Version | Enhancement |
|---|---|
| 1.7 | **End-to-end state encryption** introduced. Method: AES GCM. Key providers: passphrase (PBKDF2), AWS KMS, GCP KMS, OpenBao. |
| 1.8 | Variables and other static values usable in encryption configuration, which is what makes key material injectable rather than hard-coded. |
| 1.9 | `encrypted_metadata_alias` customises the metadata key. Encryption configuration changes now auto-apply the migration instead of requiring a manual step. |
| 1.10 | **External programs as key providers.** PBKDF2 key provider supports chaining via `chain`. |
| 1.11 | New **`azure_vault`** key provider. Input variable values can be supplied during apply (when non-ephemeral values match the plan) specifically so variables can configure encryption settings. |
| 1.13 (unreleased) | `gcp_kms` accepts `additional_authenticated_data`; AWS KMS accepts `encryption_context`; OpenBao accepts `associated_data`. |

Registered components per release, from `default_registry.go` rather than from
the changelogs. The `unencrypted` method and the `external` *method* appear in
no changelog.

| Release | Key providers | Methods |
|---|---|---|
| 1.7 | `pbkdf2`, `aws_kms`, `gcp_kms`, `openbao` | `aesgcm`, **`unencrypted`** |
| 1.10 | adds `external` | adds **`external`** |
| 1.11 | adds `azure_vault` | unchanged |
| 1.12, `main` | unchanged | unchanged |

### Configuration language

| Version | Enhancement |
|---|---|
| 1.7 | **`removed` block** for dropping resources or modules from state without destroying them. **Provider-defined functions** via `provider::<name>::<fn>()`. |
| 1.8 | **Variables and locals in module sources and backend configurations** (with limitations), the "early evaluation" work. **`.tofu` file extension** for OpenTofu-specific overrides of `.tf` files. |
| 1.9 | **`for_each` on `provider` blocks**, so one aliased provider configuration can have many dynamically-chosen instances and each resource instance can select among them. Variable `validation` conditions can reference vars, data, and other objects. |
| 1.10 | **`deprecated` on input variables and output values**, warning at the call site. **Short-circuiting `&&` and `\|\|`**. `element` accepts negative indices. `moved` supports cross-type moves with automatic state migration. `removed` blocks can carry `lifecycle` and `provisioner` configuration. `module` `version` accepts `null`. |
| 1.11 | **Ephemeral values**: ephemeral input variables, output values, ephemeral resource types, and write-only attributes. **`enabled` meta-argument** in the `lifecycle` block, as a zero-or-one alternative to `count`/`for_each`. Warning when an object constructor names an attribute absent from the target type. |
| 1.12 | **Dynamic `prevent_destroy`**: the argument can refer to other symbols in the module, such as input variables. **`destroy = false`** in `lifecycle`, forgetting an object instead of destroying it. **`const = true`** on input variables, requiring a statically-evaluable value. **`language` block**, a general way to declare version constraints that separates OpenTofu's from other software's. `replace_triggered_by` fires when a referenced resource is *replaced*, not only updated. Comparing a complex value to `null` yields a sensitive result only if the whole object is sensitive, which makes such comparisons usable in `enabled`. |

!!! warning "1.11.4 broke `enabled` in one place"
    A patch release, 1.11.4, made modules containing local provider
    configurations reject `enabled`, matching the existing rule for `count`,
    `for_each`, and `depends_on`. The changelog labels this a deliberate
    breaking change in a patch, on the grounds that the original omission was a
    foot-gun.

### Functions

| Version | Functions and changes |
|---|---|
| 1.7 | `templatestring`, `base64gunzip`, `cidrcontains`, `urldecode`, `issensitive`. `nonsensitive` stops erroring on non-sensitive values. `templatefile` may recurse, to a default depth of 1024. |
| 1.10 | Built-in `terraform` provider gains `.tfvars` encode/decode functions and expression encoding. |
| 1.11 | `regex`/`regexall` accept long-form Unicode property names (`\p{Letter}`). `fileset` matches filenames containing escaped metacharacters. `issensitive` no longer returns a known result for an unknown value, which is a behaviour change that can newly fail at plan time. |
| 1.12 | `yamldecode` supports the YAML merge tag (`<<`) with sequences of mappings. |
| 1.13 (unreleased) | `cidrsubnets` supports prefix extensions beyond 32 bits on IPv6 bases. |

### Targeting and plan scope (OpenTofu-only)

| Version | Enhancement |
|---|---|
| 1.9 | **`-exclude`**, the inverse of `-target`: name what to skip, and OpenTofu skips it plus everything depending on it. |
| 1.10 | **`-target-file` and `-exclude-file`** read address lists from a file, so routinely-used targets can live in version control. OpenTofu starts recommending `-exclude` in unknown-value `count`/`for_each` errors. |
| 1.11 | The `-exclude` recommendation is extended to provider-reported unknown-value planning failures. |
| 1.11.2 | That recommendation is **reverted**. Providers were found to report unknown-value failures spuriously, so OpenTofu cannot tell when the suggestion applies. `-exclude` is still a valid manual workaround. |

### Testing

| Version | Enhancement |
|---|---|
| 1.6 | `tofu test` moves out of experimental, with `.tftest.hcl` files and `run` blocks. |
| 1.6.1 | `run` blocks can reference a previous run's module outputs. |
| 1.6.2 | A run's `locals` block can reference another run's output. |
| 1.7 | `.tfvars` files loaded from the tests folder. State file dumped when cleanup fails. |
| 1.8 | **`override_resource`, `override_data`, `override_module`**, then **`mock_provider`, `mock_resource`, `mock_data`**. A test file's `variables` block can reference variables. `tofu test -json` types documented. |
| 1.9 | Invalid override and mock fields become errors rather than warnings. `override_resource`/`override_data` supported inside a single `mock_provider`'s scope. |
| 1.10 | Remote module sources accepted when naming the module under test. `provider` blocks can refer to `run` block outputs. |
| 1.11 | `mock_provider` supports `for_each`. `variable` blocks in test files can call functions. Generated mock values follow provider schemas much more closely, so previously-tolerated invalid mocks now fail. |

### State backends

| Version | Enhancement |
|---|---|
| 1.7 | S3 backend `use_legacy_workflow` defaults to `false`, aligning credential search with the AWS CLI and SDKs, and is deprecated. Large local `terraform.tfstate` files handled much faster, because writes no longer persist to disk on every call. |
| 1.8 | S3 `use_legacy_workflow` **removed**. State persistence interval configurable via `TF_STATE_PERSIST_INTERVAL`. State files written with compact JSON, improving size and write speed. |
| 1.9 | AzureRM backend gains `timeout_seconds`, defaulting to 300. |
| 1.10 | **S3 native locking without DynamoDB.** **`pg` backend stores multiple states in one database** via `table_name` and `index_name`, with more granular locking so separate configurations sharing a database no longer conflict. `http` backend supports `tofu force-unlock`. `oss` backend honours `NO_PROXY`. S3 `skip_s3_checksum` also disables the SDK's integrity checks, for third-party S3 implementations. |
| 1.11 | S3 backend can tag state and lock objects, and supports the `eusc-de-east-1` AWS European Sovereign Cloud region. AzureRM gains `use_cli`, `use_aks_workload_identity`, `client_id_file_path`, `client_secret_file_path`, and `client_certificate`, while `endpoint`/`msi_endpoint` are deprecated and ignored. |
| 1.12 | S3 backend discovers credentials issued by `aws login`. AzureRM supports Azure DevOps/Pipelines workload identity federation, plus customer-provided and customer-managed keys for server-side encryption. **`local` backend writes pretty-printed JSON**, so state tracked in version control diffs readably. |

!!! warning "The 1.10 `pg` backend is not mixable"
    The 1.10 changelog states that its `pg` backend must not share a database
    with the `pg` backend from earlier versions, because the locking
    implementation changed and mixing versions can allow conflicting writes and
    data loss.

### Provider and module installation

| Version | Enhancement |
|---|---|
| 1.6 | Default provider namespace changes from `hashicorp` to `opentofu`. State provider addresses pointing at `registry.terraform.io` are read as `registry.opentofu.org` unless overridden. All checkpoint telemetry removed. `init` warns when two providers share a name across the `opentofu` and `hashicorp` namespaces. GPG validation is conditionally skipped for default-registry providers whose keys are missing, with `OPENTOFU_ENFORCE_GPG_VALIDATION=true` as the strict opt-in. |
| 1.7 | Automatic retries for provider installation on transient errors. `-json` on `tofu init` and `tofu get`. XDG Base Directory support. |
| 1.10 | **OCI registries as module package sources** (`oci:` addresses) and **as a provider mirror kind**. **Global provider cache made safe for concurrent processes** through file locking. Lock files carrying `registry.terraform.io` entries get the equivalent OpenTofu-rebuilt provider version selected automatically. A locally-verified `zh:` checksum is recorded alongside `h1:` when a source offers a zip without signed checksums. |
| 1.11 | `init` copies module package contents concurrently. Clearer error for a missing module sub-directory. Registry retry count and request timeout configurable in the CLI configuration, not only by environment variable. Module packages from S3 sources use AWS-standard credential discovery, including IAM roles for service accounts. |
| 1.12 | **Concurrent provider package downloads.** **`init` records a full cross-platform checksum set**, using new registry data, which removes the need for `tofu providers lock` in most workflows. `network_mirror` gains an option to trust all hashes the mirror reports. Module registries can direct package downloads to reuse the registry's own credentials instead of a separate `.netrc` entry. Checksum verification and schema loading optimised, and checksums skipped for cached providers a command will not use. |
| 1.13 (unreleased) | Per-repository transient credentials for OCI registries, for registries issuing repository-scoped tokens. `providers lock -oci-mirror`. |

### Observability, output, and CLI ergonomics

| Version | Enhancement |
|---|---|
| 1.7 | `-concise` on `tofu plan` omits refreshing-state logs. Aliases `state ls`, `state move`, `state remove`. `tofu console` works on Solaris and AIX. |
| 1.9 | **`-show-sensitive`** unmasks sensitive values in `plan`, `apply`, and other commands that return configuration or state data. `-consolidate-warnings` and `-consolidate-errors` toggle diagnostic summarisation. `tofu console` accepts multi-line expressions. Faster large-graph handling when debug logs are off, and with many submodules. Extended trace logging for the `http` backend. |
| 1.10 | **Experimental OpenTelemetry tracing**, initially for `tofu init`, sent to a collector you control. `-concise` extended to suppress progress-like messages on plan and apply. `tofu show` gains explicit `-state` and `-plan=PLANFILE` options. Plan and apply summaries count instances being **forgotten**. Richer type information in conversion errors. |
| 1.11 | `tofu show -config` and `-module=DIR` produce a machine-readable configuration summary without planning first. JSON configuration output includes variable type constraints and required-ness. Multiline strings inside lists diffed line by line. Plan UI spells out that "update in-place" reads current → planned. Lower RAM and CPU for state with thousands of instances. `stty` located via `PATH`. |
| 1.12 | **`-json-into=<outfile>`** writes machine-readable logs to a file while human-readable output stays on the terminal. `tofu destroy -suppress-forget-errors`. `tofu console -lock=false` and `-lock-timeout`. `tofu login` honours `BROWSER` on Unix. Most commands print usage on argument-parse failure, emit legacy errors as regular diagnostics, and support JSON output. Deprecation warnings for provider-marked deprecated attributes and blocks, suppressible with `-deprecation=`. |
| 1.13 (unreleased) | `local-exec` sets `TRACEPARENT` for child processes under active tracing. OpenTelemetry library logs copied into the `TF_LOG` debug stream. Windows ARM64 becomes officially supported. |

---

## Part 2 — Per-release catalogue

### 1.6.0 (January 2024)

The fork's first release. Baseline is Terraform 1.5.x, with some upstream 1.6
work merged in before divergence.

**OpenTofu-specific:**

- Default provider namespace changes from `hashicorp` to `opentofu`.
- State provider addresses referring to `registry.terraform.io` are treated as
  `registry.opentofu.org`, unless the full address is written in configuration
  or `OPENTOFU_STATEFILE_PROVIDER_ADDRESS_TRANSLATION=0`.
- All checkpoint telemetry removed.
- `cloud`/`remote` backends and `login`/`logout` no longer default to the
  `app.terraform.io` hostname; it must be given explicitly.
- Conditional GPG validation bypass for default-registry providers whose keys
  are not yet published, with `OPENTOFU_ENFORCE_GPG_VALIDATION` to force strict
  checking.
- `init` warns when two providers share a name across the `opentofu` and
  `hashicorp` namespaces, which catches an accidental switch to a fork.

**Inherited or merged from upstream:** `tofu test` out of experimental with
`.tftest.hcl` and `run` blocks; partial knowledge about unknown values;
`errored` in JSON plan output; saved remote plans on cloud backends; `import`
block `id` accepting plan-time-known expressions.

Patch additions: run blocks referencing earlier runs' module outputs (1.6.1)
and their outputs inside a `locals` block (1.6.2).

### 1.7.0 (April 2024)

The release that established OpenTofu as more than a drop-in replacement.

- **State encryption**, end to end and optional. AES GCM as the method;
  passphrase (PBKDF2), AWS KMS, GCP KMS, and OpenBao as key providers.
- **`removed` block**, removing resources or modules from state without
  destroying them.
- **Provider-defined functions**, `provider::<name>::<fn>(args)`.
- **`for_each` in `import` blocks.**
- Functions `templatestring`, `base64gunzip`, `cidrcontains`, `urldecode`,
  `issensitive`. `nonsensitive` stops erroring on already-non-sensitive values.
  `templatefile` may recurse to depth 1024.
- `import` block `to` addresses accept dynamic values in index keys.
- `-concise` on plan; `-json` on `init` and `get`; `state ls`/`move`/`remove`
  aliases; XDG base directory support; automatic retries for provider
  installation.
- Local state handling made much faster by no longer persisting on every write,
  with the noted trade-off that a hard crash mid-apply leaves no in-progress
  state file.
- `.tfvars` files loaded from the tests folder.
- S3 backend `use_legacy_workflow` defaults to `false` and is deprecated.
- 1.7.4 makes `generate-config-out` emit `jsonencode(...)` for JSON strings.

### 1.8.0 (2024)

- **Early evaluation**: variables and locals allowed in **module sources and
  backend configurations**, with limitations. This is the feature Terraform did
  not match until 1.15, and then only for module sources.
- **`.tofu` file extension**, letting a config carry OpenTofu-specific
  overrides of `.tf` files.
- **Testing mocks and overrides**: `override_resource`, `override_data`,
  `override_module`, then `mock_provider`, `mock_resource`, `mock_data`.
- Variables and static values usable in encryption configuration.
- `TF_STATE_PERSIST_INTERVAL` makes the persistence interval configurable.
- State files written with compact JSON encoding, improving size and speed.
- Provider functions included in `tofu providers schema`.
- **Breaking:** S3 backend `use_legacy_workflow` removed.

### 1.9.0 (January 2025)

- **`for_each` on `provider` blocks.** An aliased provider configuration gets
  multiple dynamically-chosen instances, and each resource instance can select
  one, which is the clean answer to multi-region duplication.
- **`-exclude` planning option**, the inverse of `-target`. Excludes the named
  objects and everything depending on them.
- **`-show-sensitive`** unmasks sensitive values across plan, apply, and other
  data-returning commands.
- `-consolidate-warnings` / `-consolidate-errors`.
- Variable `validation` can reference other variables, data sources, and locals.
- Encryption key providers accept `encrypted_metadata_alias`; encryption
  configuration changes auto-apply their migration.
- OpenTofu prompts for input variables needed during early evaluation.
- `tofu console` accepts multi-line expressions.
- Test framework: invalid override and mock fields become errors;
  `override_resource`/`override_data` work inside one `mock_provider`.
- Large-graph performance improved, both without debug logging and with many
  submodules.
- AzureRM backend `timeout_seconds`.

### 1.10.0 (2025)

The broadest release. Registry, backend, and language work all landed together.

- **OCI registries** as module package sources (`oci:`) and as a provider
  mirror kind.
- **`deprecated` on input variables and output values.**
- **S3 backend locking without DynamoDB.**
- **`pg` backend stores multiple states per database** via `table_name` and
  `index_name`, with finer-grained locking.
- **Global provider cache is concurrency-safe** where the filesystem supports
  file locking.
- **Short-circuiting `&&` and `||`** (Terraform followed in 1.12).
- **`-target-file` and `-exclude-file`** read address lists from a file.
- **Experimental OpenTelemetry tracing**, initially covering `tofu init`.
- `moved` supports cross-type moves with automatic state migration.
- `removed` blocks accept `lifecycle` and `provisioner` configuration.
- External programs as encryption key providers; PBKDF2 chaining.
- `element` accepts negative indices; `module` `version` accepts `null`.
- Built-in `terraform` provider gains `.tfvars` encoding/decoding and
  expression encoding.
- `tofu show -state` / `-plan=PLANFILE`; `-concise` on plan and apply.
- Plan and apply summaries count **forgotten** instances.
- Lock files referencing `registry.terraform.io` providers resolve to the
  equivalent OpenTofu-rebuilt version, easing direct migration.
- `http` backend supports `force-unlock`; `oss` honours `NO_PROXY`;
  `skip_s3_checksum` also disables SDK integrity checks.
- **Upgrade notes:** Linux kernel 3.2+, macOS 11+, the `ghcr.io/opentofu/opentofu`
  base-image pattern is no longer supported, the `pg` backend must not share a
  database with older versions, and Windows "symlink" now means true symbolic
  links only (junctions excluded).

### 1.11.0 (2025)

- **Ephemeral values**: ephemeral input variables and outputs, ephemeral
  resource types, and write-only attributes. Parity with Terraform 1.10 and
  1.11 in one release.
- **`enabled` meta-argument**, nested inside `lifecycle` to avoid colliding with
  existing arguments named `enabled`, for the zero-or-one case that `count` and
  `for_each` handle awkwardly.
- **`azure_vault`** encryption key provider.
- Input variable values accepted during apply, when non-ephemeral values match
  the plan, so variables can configure encryption settings.
- `tofu show -config` and `-module=DIR` summarise configuration without a plan.
  JSON configuration output gains variable type constraints and required-ness.
- `tofu validate` can validate non-root modules using `configuration_aliases`.
- `mock_provider` supports `for_each`; test `variable` blocks can call
  functions; generated mocks now follow provider schemas closely enough that
  previously-invalid mocks fail.
- Warning when an object-constructor variable value names an attribute the
  target type does not have.
- Multiline strings inside lists diffed line by line; plan UI states that
  "update in-place" reads current → planned.
- S3 backend object tagging and the `eusc-de-east-1` sovereign-cloud region;
  module packages from S3 use AWS-standard credential discovery.
- AzureRM backend gains `use_cli`, `use_aks_workload_identity`, and file-path
  client credentials; `endpoint` and `msi_endpoint` deprecated and ignored.
- Lower RAM and CPU for state with thousands of instances; concurrent module
  package copying.
- **Behaviour change:** `issensitive` no longer returns a known result for an
  unknown value, so modules feeding its result into `count`/`for_each` now fail
  at plan time.
- macOS 12 Monterey or later required; SHA-1 TLS signatures rejected.

### 1.12.0 (2026)

- **Dynamic `prevent_destroy`.** The argument can reference other symbols in the
  module, including input variables. Terraform still requires a literal.
- **`destroy = false`** in `lifecycle`, planning to forget an object rather than
  destroy it.
- **`const = true`** on input variables, requiring a statically-evaluable value.
- **`language` block**, separating OpenTofu version constraints from other
  software's.
- **`-json-into=<outfile>`**, so machine-readable logs go to a file while the
  human-readable UI stays on stdout.
- **Concurrent provider downloads** and a **full cross-platform checksum set
  recorded by `init`**, which together remove most reasons to run
  `tofu providers lock`. `network_mirror` gains a trust-all-hashes option.
- `import` blocks accept an `identity` object matching the resource type's
  identity schema, as an alternative to `id`.
- Deprecation warnings for provider-marked deprecated attributes and blocks,
  suppressible with `-deprecation=`.
- `replace_triggered_by` fires when a referenced resource is replaced, not only
  updated.
- Comparing a complex value to `null` is sensitive only when the whole object
  is, which makes such comparisons usable in `enabled`.
- `yamldecode` supports the merge tag with sequences of mappings.
- `local` backend writes pretty-printed JSON state.
- S3 backend discovers `aws login` credentials; AzureRM supports Azure
  DevOps/Pipelines workload identity federation and CPK/CMK server-side
  encryption.
- `tofu destroy -suppress-forget-errors`; `tofu console -lock=false` and
  `-lock-timeout`; `tofu login` honours `BROWSER`.
- Module registries can direct package downloads to reuse registry credentials.
- **Deprecations:** the `winrm` provisioner connection type warns and is
  slated to error in 1.13; `OPENTOFU_USER_AGENT` removed; last series
  supporting macOS 12; 32-bit builds flagged for eventual removal.

### 1.13.0 (unreleased)

!!! warning "Unreleased"
    On `main` only. Contents will change before release.

- **`winrm` connection type removed** for provisioners, as announced in 1.12.
- **Windows on ARM64** becomes an officially supported platform.
- Encryption key providers gain additional authenticated data:
  `additional_authenticated_data` (`gcp_kms`), `encryption_context` (AWS KMS),
  `associated_data` (OpenBao).
- `cidrsubnets` supports prefix extensions beyond 32 bits on IPv6 bases.
- `local-exec` sets `TRACEPARENT` in child processes under active tracing;
  OpenTelemetry library logs are copied into the `TF_LOG` debug stream.
- Per-repository transient OCI credentials; `providers lock -oci-mirror`.
- `tofu plan` drops the redundant paragraph after "No changes."
- **Final series with official 32-bit builds**; `init` on a 32-bit CPU warns
  about removal in 1.14.

---

---

## Part 3 — What the changelog does not say

Found the same way as the Terraform page's Part 3: diffing the HCL schemas in
`internal/configs` across every release tag from `v1.6.0` to `v1.12.0` plus
`main`, then checking each new name against the changelogs. For OpenTofu the
sweep was also pointed at `internal/encryption`, since the flagship feature's
key providers and methods are registered in code rather than declared in a
schema.

The sweep confirms the changelog on `removed` and `encryption` (1.7), the
mock and override vocabulary `defaults`/`outputs`/`values` (1.8), `deprecated`
(1.10), `enabled` and `ephemeral` (1.11), and `const` and `identity` (1.12).
It turns up the following, which no changelog mentions.

### Encryption components that were never announced

| Component | Since | What it is |
|---|---|---|
| **`unencrypted` method** | 1.7.0 | A registered encryption *method* that performs no encryption. The escape hatch for migrating state back out of encryption, and the thing you pair with a fallback block during rollout. Registered in `default_registry.go` from the first encryption release, mentioned in no changelog. |
| **`external` *method*** | 1.10.0 | Distinct from the external *key provider*. The 1.10 changelog announces "external programs as key providers" only; an external encryption method was registered in the same release. |

!!! note "Two entries in the tree are not features"
    The `static` and `xor` key providers appear under
    `internal/encryption/keyprovider/` from 1.7 and 1.9 respectively, but
    neither is registered in `default_registry.go`, so neither is reachable
    from configuration. They are compliance-test fixtures. The same goes for
    `dual_custody_test.go`, which is a test rather than a shipped feature.

    The user-reachable set as of `main` is therefore: key providers `pbkdf2`,
    `aws_kms`, `gcp_kms`, `azure_vault`, `openbao`, `external`; methods
    `aesgcm`, `external`, `unencrypted`.

### The `language` block is half inert

The 1.12 changelog describes the `language` block as a way to declare version
constraints separately from other software. Only part of it does that.

```hcl
language {
  edition = tofu2024              # reserved, does nothing
  compatible_with "opentofu" {    # the part that works
    # version constraint
  }
}
```

`compatible_with` takes the software name as a label, and blocks naming
software other than OpenTofu are ignored, which is the mechanism the changelog
is describing. `edition` is a placeholder: the only accepted keyword is
`tofu2024`, which is also the default. It exists so that a future edition
switch gives a useful error on older CLIs rather than "unsupported argument".

This mirrors Terraform's inert `language = TF2021` argument almost exactly.
The two differ in placement, since Terraform's is an argument inside the
`terraform` block and OpenTofu's is an argument inside a new top-level block.

!!! info "OpenTofu accepts Terraform's `language` argument and ignores it"
    `terraform { language = ... }` is still in OpenTofu's schema, so a
    configuration carrying it parses. OpenTofu then discards it completely,
    with the source giving the reason: it cannot predict how a future
    Terraform edition would use that argument. There is also a dedicated error
    for anyone who writes a `TF`-prefixed keyword into OpenTofu's own
    `language` block, telling them the module may be intended for other
    software.

### No pluggable state stores

Terraform has carried a `state_store` block for pluggable state storage in its
parser since 1.13, experiment-gated. **OpenTofu has no equivalent** anywhere in
`internal/configs` as of `main`. Backends remain a fixed built-in set. Worth
tracking, because it is the one place where Terraform has in-flight
architectural work with no OpenTofu counterpart.

### OpenTofu does not ship gated plumbing early

Terraform routinely lands a block's schema one release before announcing it,
behind `AllowExperimentalFeatures`. `action`, `list`, and `terraform query`
all appeared that way in 1.13 and became stable in 1.14.

OpenTofu's config parser does not do this. On `main`, `parser_config.go` has
**zero** `allowExperiments` uses beyond sniffing the experiments attribute
itself, and the same held at 1.11 when `enabled` and `ephemeral` shipped. A
block appearing in an OpenTofu release is a block usable in that release, which
makes dating an OpenTofu feature from the source considerably simpler than for
Terraform.

!!! note "One sweep result that is not a removal"
    The diff reports `dynamic` disappearing at 1.7. It is a file-move artifact:
    `internal/configs/util.go` and `module_merge_body.go`, which held the
    literal, were removed in that release. `dynamic` blocks are unaffected. Any
    schema sweep needs this check before a disappearance is reported as a
    removal.

---

## Reading notes

!!! note "OpenTofu's changelog convention differs from Terraform's"
    Each OpenTofu version branch keeps the whole minor series in one file with
    the newest patch on top, and patch sections are frequently empty. Security
    advisories are recorded per patch and are prominent, which Terraform's
    changelogs largely do not do. Feature additions in patch releases are much
    rarer than in Terraform, with 1.6.1, 1.6.2, and 1.7.4 the main exceptions.

!!! note "Two patch releases changed behaviour, not just fixed bugs"
    **1.11.4** made `enabled` invalid in modules containing local provider
    configurations, explicitly acknowledged in the changelog as a breaking
    change shipped in a patch. **1.11.2** reverted the 1.11.0 change that
    suggested `-exclude` on provider-reported unknown-value failures, because
    providers report those spuriously. Neither is visible from the `x.y.0`
    sections alone.

!!! info "Where OpenTofu leads and where it follows"
    Led: state encryption (1.7), early evaluation (1.8), provider `for_each`
    and `-exclude` (1.9), OCI registries, OpenTelemetry, and short-circuit
    operators (1.10), `enabled` (1.11), dynamic `prevent_destroy`,
    `destroy = false`, and `-json-into` (1.12).

    Followed: the test framework (1.6, from Terraform 1.6), mocks and overrides
    (1.8, from Terraform 1.7), provider-defined functions and `removed` (1.7,
    from Terraform 1.8 and 1.7), cross-object variable validation (1.9, from
    Terraform 1.9), `deprecated` variables and outputs (1.10, ahead of
    Terraform 1.15), ephemeral values and write-only attributes (1.11, from
    Terraform 1.10 and 1.11), and `import` `identity` (1.12, from Terraform
    1.12).

## Sources

Generated from `git show origin/v<X.Y>:CHANGELOG.md` for every version branch of
[opentofu/opentofu](https://github.com/opentofu/opentofu) (`v1.6` through
`v1.12`) plus `origin/main` for the unreleased 1.13, fetched 2026-08-13.

Part 3 comes from a different method: dumping every `Name:`/`Type:` schema
literal in `internal/configs/*.go` at each release tag and diffing consecutive
versions, plus listing the key providers and methods actually registered in
`internal/encryption/default_registry.go` per tag, so that unregistered
directories under `internal/encryption/keyprovider/` are not mistaken for
shipped features.

Per-release links:
[v1.12](https://github.com/opentofu/opentofu/blob/v1.12/CHANGELOG.md),
[v1.11](https://github.com/opentofu/opentofu/blob/v1.11/CHANGELOG.md),
[v1.10](https://github.com/opentofu/opentofu/blob/v1.10/CHANGELOG.md),
[v1.9](https://github.com/opentofu/opentofu/blob/v1.9/CHANGELOG.md),
[v1.8](https://github.com/opentofu/opentofu/blob/v1.8/CHANGELOG.md),
[v1.7](https://github.com/opentofu/opentofu/blob/v1.7/CHANGELOG.md),
[v1.6](https://github.com/opentofu/opentofu/blob/v1.6/CHANGELOG.md),
[main](https://github.com/opentofu/opentofu/blob/main/CHANGELOG.md).

Pre-fork history lives in the
[Terraform Release Feature Map](release-feature-map.md), since OpenTofu 1.6
inherits Terraform 1.5.x wholesale.
