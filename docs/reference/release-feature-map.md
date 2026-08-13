# Release Feature Map (CHANGELOG-derived)

A complete, release-by-release catalogue of what each Terraform version
**added**, and — for the features that evolved over many releases — **how each
version enhanced what came before**.

This page is derived directly from the per-branch `CHANGELOG.md` files in
`hashicorp/terraform` (branches `v0.11` through `v1.16`), not from release blogs
or documentation. Where a feature landed in a *patch* release rather than the
`x.y.0` minor, that is called out, because those are easy to miss.

!!! note "Scope and companion pages"
    This page is exhaustive on *language, CLI, workflow, and backend* features.
    It deliberately skips bug fixes, provider/resource additions from the
    pre-0.10 monolith era, and internal SDK changes.

    For the condensed "what should I actually use" view, see
    [Terraform Feature History](feature-history.md). For the fork's timeline,
    see [OpenTofu Feature History](opentofu-feature-history.md) and its
    changelog-derived counterpart,
    [OpenTofu Release Feature Map](opentofu-release-feature-map.md), which
    picks up at the 1.5.x fork point.

    Verified 2026-08-13 against the version branches at that date. Terraform
    1.15.8 is the newest stable release; 1.16.0-rc1 (August 12, 2026) is a
    release candidate and its contents may still change.

---

## Part 1 — Feature threads

Most Terraform capabilities were not delivered whole. They arrived as a seed
feature and were widened over many releases. These tables read left-to-right as
the history of one capability.

### Configuration language

| Version | Enhancement |
|---|---|
| 0.7 | Lists and maps become first-class variable types and can be passed between modules. Data sources introduced as a new primitive. |
| 0.8 | Conditional (ternary) values. `depends_on` can reference a whole module. `output` supports `depends_on`. Terraform version constraints declarable in configuration. |
| 0.12 | **HCL2.** First-class expressions (no more interpolation-only `"${...}"`), `for` expressions, `dynamic` blocks, generalised splat operator, `null` as an "unset" value, rich/nested types with type constraints on variables, resources and modules usable as object values, string templates with conditionals and iteration. |
| 0.12.6 | `for_each` meta-argument on resources. |
| 0.13 | `count`, `for_each`, and `depends_on` on **module** blocks. `validation` blocks for input variables (graduating the 0.12.20 experiment). |
| 0.14 | `sensitive = true` on input variables, with sensitivity propagating through derived expressions. `ignore_changes` can name map keys absent from the configuration. |
| 0.15 | Provider-declared sensitive attributes propagate automatically (the `provider_sensitive_attrs` experiment concludes as default-on). `configuration_aliases` inside `required_providers` replaces empty "proxy" provider blocks. Improved conditional-expression type inference. |
| 1.1 | `nullable = false` on variables, so an explicit `null` from the caller falls back to the default. |
| 1.2 | `precondition` and `postcondition` blocks on resources, data sources, and module outputs. `replace_triggered_by` in `lifecycle`. Condition and validation error messages are evaluated as expressions, so values can be interpolated into them. |
| 1.3 | `optional(type, default)` attributes in object type constraints reach stable, replacing the experimental `defaults` function. |
| 1.5 | `check` blocks with `assert` blocks and optional scoped data sources. Unlike pre/postconditions, a failing `check` does not halt execution. |
| 1.6 | Terraform tracks *partial* knowledge about unknown values (possible collection length, whether an unknown can be null), so some operations on unknowns can now produce known results. `try`/`can` give more consistent results with unknown arguments. |
| 1.9 | Variable `validation` conditions become general expressions and can reference other variables, data sources, and locals. |
| 1.10 | **Ephemeral values.** Input variables and outputs can be `ephemeral`; ephemeral resources are re-read each phase and never persisted. `ephemeralasnull` function. `element` accepts negative indices. |
| 1.12 | Logical binary operators (`&&`, `\|\|`) short-circuit. |
| 1.15 | `output` blocks accept an explicit `type` constraint. `deprecated` attribute on `variable` and `output` blocks, producing warnings at the call site. Variables and locals usable in module `source` and `version`. `convert` function for precise inline type conversion. |
| 1.16-rc1 | `lifecycle` gains `destroy = false`. `contains()` can test for `null`. Providers can expose nested blocks as computed values. |

### Built-in functions

| Version | Functions added |
|---|---|
| 0.6 | `keys`, `values` |
| 0.7 | `sort`, `distinct`, `list`, `map` |
| 0.10 | `contains` |
| 0.12 | `jsondecode`, `csvdecode`, `templatefile`, `formatdate`, `reverse`, `strrev` |
| 0.12.2 | `range`, `yamldecode`, `yamlencode` (experimental at the time), `uuidv5` |
| 0.12.4 | `abspath` |
| 0.12.7 | `regex`, `regexall` |
| 0.12.8 | `fileset` |
| 0.12.10 | `parseint`, `cidrsubnets` |
| 0.12.17 | the `trim*` family |
| 0.12.20 | `try`, `can` |
| 0.12.21 | `setsubtract` |
| 0.13 | `sum` |
| 0.14 | `alltrue`, `anytrue`, `textencodebase64`, `textdecodebase64` |
| 0.15 | `one`, `sensitive`, `nonsensitive`; `list()` and `map()` **removed** in favour of `tolist()`/`tomap()` |
| 1.3 | `startswith`, `endswith`, `timecmp` |
| 1.5 | `strcontains`, `plantimestamp` |
| 1.8 | `issensitive`; provider-defined functions via `provider::name::fn()`; built-in provider functions `decode_tfvars`, `encode_tfvars`, `encode_expr` |
| 1.9 | `templatestring` |
| 1.10 | `ephemeralasnull` |
| 1.15 | `convert` |

### Refactoring without touching state by hand

| Version | Enhancement |
|---|---|
| 0.7 | `terraform state` command family introduced for manual state surgery. |
| 0.13 | `terraform state replace-provider`, for re-pointing existing instances at a new provider source address. |
| 1.1 | **`moved` block.** Address changes recorded in source code and applied automatically during plan, so module consumers no longer run `terraform state mv`. |
| 1.3 | `moved` blocks can describe resources moving to and from modules in separate module packages. |
| 1.7 | **`removed` block.** Drop a resource or module call from configuration and choose whether the real object is destroyed or only forgotten. Planned and applied like any other action. |
| 1.8 | `moved` can transfer a remote object between resources of **different types**, when the target provider declares it can convert from the source type. |
| 1.9 | `moved` supports `null_resource` → `terraform_data`. `removed` blocks can declare destroy-time provisioners. |
| 1.10 | `moved` block address parsing respects reserved keywords; references to resource types colliding with block names need the `resource.` prefix. |

### Importing existing infrastructure

| Version | Enhancement |
|---|---|
| 0.7 | `terraform import` command, with initial broad AWS coverage. |
| 0.8 | `import` can name a provider alias and reads provider configuration from `.tf`/`.tfvars` files. |
| 0.13 | `import` attaches the correct provider from configuration automatically, making `-provider` unnecessary (the flag is removed). Works with provider configs that reference other objects already in state. |
| 1.3 | `-allow-missing-config` removed; at minimum an empty resource block must exist. |
| 1.5 | **`import` block.** Import becomes configuration-driven and plannable. `terraform plan -generate-config-out=PATH` writes HCL for imported resources that have no configuration yet. |
| 1.6 | The `import` block `id` accepts expressions, as long as the result is a string known at plan time. |
| 1.7 | `for_each` on `import` blocks, expanding one block over many instances. |
| 1.8 | Generated configuration detects embedded JSON and emits `jsonencode(...)` instead of one opaque string. |
| 1.10 | Stricter `import` block validation surfaces more errors during `terraform validate`. |
| 1.12 | `import` blocks can import by resource **`identity`**, mutually exclusive with `id`. |
| 1.14 | New `GenerateResourceConfiguration` RPC lets providers produce more precise generated configuration. |
| 1.16-rc1 | `import` blocks are supported **inside modules**. |

### Testing

| Version | Enhancement |
|---|---|
| 0.15 | `terraform test` appears as an experiment, part of the Module Testing Experiment. |
| 1.6 | **GA, with a completely different design.** Tests live in `.tftest.hcl` files as a series of `run` blocks, each running a plan or apply against the configuration under test and asserting on the resulting plan and state. |
| 1.7 | **Mocking.** `mock_provider`, `override_resource`, `override_data`, `override_module`. Provider blocks in test files can reference test-file variables and `run` outputs. Terraform functions usable in test variables and provider blocks. `terraform.tfvars` in the test directory is loaded automatically. |
| 1.7.2 | `terraform fmt` formats `.tfmock.hcl` files. |
| 1.8 | File-level variables can refer to global variables. |
| 1.9 | Sensitive values passed to test variables retain dynamic sensitivity, not just static `sensitive = true`. Provider version constraints are no longer allowed in `.tftest.hcl` and must live in the main configuration. |
| 1.11 | `-junit-xml` reaches GA. `override_during = plan` applies mocks during unit-test (`command = plan`) runs. `state_key` on `run` blocks controls which internal state file a run uses. |
| 1.12 | `-parallelism=n` for a run's plan/apply. Runs can be annotated for parallel execution. Execution continues when an expected failure does not occur. Detailed diagnostic objects on assertion failure. `terraform init` works when tests exist but no configuration files sit directly in the directory. |
| 1.13 | External variables referenced by test files can be defined in the test file itself (and should be, or complex cases now warn). File-level `variable` blocks can reference run outputs and other variables. Teardown runs in parallel. |
| 1.14 | Expected diagnostics appear in verbose output. `prevent_destroy` is ignored during test cleanup. Experimental: `backend` blocks in `run` blocks (reuse long-lived test infrastructure), `skip_cleanup`, and a `terraform test cleanup` command. |
| 1.15 | Functions allowed inside `mock` blocks. File-level error diagnostics included in JUnit XML `skipped` elements so CI can detect them. |
| 1.16-rc1 | Terraform reports which resources were left behind when `skip_cleanup` is set. |

### Secrets that never reach state

| Version | Enhancement |
|---|---|
| 0.14 | `sensitive` input variables; sensitivity propagates through expressions; outputs derived from them must also be marked sensitive. Provisioner logging disabled when sensitive values are involved. |
| 0.15 | Provider-declared sensitive attributes redacted throughout plan output by default. `sensitive()` and `nonsensitive()` give authors manual control. |
| 1.4 | Interactive input for sensitive variables is masked in the UI. |
| 1.8 | `issensitive` function. Sensitive values tracked more accurately in state and plans, removing phantom no-change updates. |
| 1.10 | **Ephemeral resources and ephemeral values.** Re-read at each phase, never written to plan or state. |
| 1.11 | **Write-only attributes.** Providers mark attributes as write-only; their values are not persisted in state, and ephemeral values may be assigned to them. |
| 1.15 | `list_start` JSON logs record which attribute paths are sensitive. |
| 1.16-rc1 | `terraform_data` gains a `store` block that can carry ephemeral and sensitive values across plan and apply. Terraform stores planned private data for providers. |

### State storage and backends

| Version | Enhancement |
|---|---|
| 0.5 | `s3` remote state. |
| 0.6 | `swift` remote state. HTTP remote state gains `skip_cert_verification`; S3 gains `encrypt`. |
| 0.7 | `gcs` and `azure` remote state providers. |
| 0.9 | **Backends** replace "remote state": file-based configuration, setup through `terraform init`, no local caching. **State locking**, supported by local, S3 (via DynamoDB), and Consul. **State environments** (later renamed workspaces). |
| 0.10 | S3 backend gains `workspace_key_prefix`. |
| 0.11 | GCS and Manta backends gain workspaces and locking. |
| 0.12 | New `pg` (PostgreSQL) backend. Swift gains locking and workspaces. |
| 0.12.2 | New `oss` (Alibaba) backend. |
| 0.12.21 | New `cos` (Tencent) backend. |
| 0.13 | New `kubernetes` backend (state as secrets). `oss` requires a `LockID` primary key. S3 backend authentication substantially reworked. |
| 0.14 | Consul backend splits state across chunks to exceed the 512 KB KV limit, and supports force-unlock. GCS backend supports service-account impersonation. |
| 0.15 | `pg` backend locks per workspace instead of globally. AzureRM supports Azure AD users and roles. |
| 1.4 | GCS `kms_encryption_key` and `storage_custom_endpoint`. HTTP backend supports mTLS. |
| 1.5 | Local operations persist state snapshots periodically during apply, and immediately on SIGINT, shrinking the window for lost state. |
| 1.6 | Kubernetes backend splits state across multiple secrets, removing the 1 MiB ceiling. S3 backend moves to AWS SDK for Go v2 and gains `assume_role_with_web_identity`, shared config/credentials files, `custom_ca_bundle`, IMDS endpoint settings, proxy/FIPS/dualstack options, `sts_region`, `retry_mode`, and account-ID allow/forbid lists. |
| 1.10 | **S3 native state locking** arrives alongside DynamoDB locking (both locks taken). Deprecated S3 assume-role attributes removed in favour of the `assume_role` block. |
| 1.11 | S3 native locking **GA** via `use_lockfile`; DynamoDB arguments deprecated. Azure backend authentication rebuilt on the current Azure SDK, adding `use_cli`, `use_aks_workload_identity`, and file-path-based client credentials. |
| 1.12 | New **OCI Object Storage** backend. |
| 1.15 | `terraform validate` now validates the `backend` block itself: type exists, required attributes present, backend's own validation passes. S3 backend supports authentication via `aws login`. |

### Provider distribution and installation

| Version | Enhancement |
|---|---|
| 0.10 | **Providers split out of the Terraform binary.** Released independently, versioned, constrained in configuration, and installed automatically by `terraform init`. `terraform init -upgrade`. |
| 0.11 | `module` blocks gain `version` and `providers` arguments. |
| 0.12 | Provider index moves to `registry.terraform.io`. Plugin wire protocol changes, so 0.11-era plugins are incompatible. |
| 0.13 | **Hierarchical provider namespaces.** Third-party and private-registry providers install automatically, but non-`hashicorp` providers now require an explicit `source`. Trust-signature verification and display at `init`. `terraform providers mirror` builds a local filesystem mirror. Installation methods configurable per provider in the CLI config. |
| 0.13.2 | **Network mirrors**: providers served over HTTP as an alternative to origin registries. |
| 0.14 | **`.terraform.lock.hcl`** written by `init` and intended for version control. `-upgrade` restores the old always-newest behaviour. |
| 0.15 | `init -lockfile=readonly`. Lock file only rewritten when its content would change. Registry failures suggest candidate providers. `init` always verifies and always installs (the `-verify-plugins=false` and `-get-plugins=false` escape hatches are removed). |
| 1.1 | `apply` of a saved plan verifies the **whole provider package** by checksum, not just the executable. |
| 1.4 | Global plugin cache entries are ignored unless already covered by a lock-file checksum, closing the long-standing "first install from cache can't record all checksums" hole. Failure messages state why installation failed. |
| 1.8 | `terraform providers lock -enable-plugin-cache`. |
| 1.11 | Provider installation honours credentials from `.netrc` for download and shasum URLs. |
| 1.15 | `init` skips dependencies declared only in a development override, so overrides and normal installation can coexist. Installation internals refactored, changing `init` output ordering. |
| 1.16-rc1 | `dev_override` providers keep their lock entries. `init` warns when unmanaged providers may affect installation. Underscores allowed in provider source namespaces. |

### Plan and apply experience

| Version | Enhancement |
|---|---|
| 0.6 | Plan reports a count of resources to change, create, and destroy. |
| 0.10 | `-target` can reach resources in descendant modules. `.auto.tfvars` files load automatically. |
| 0.11 | `terraform apply` waits for interactive approval unless given a plan file. |
| 0.12 | Structural plan output that mirrors configuration syntax, including nested rendering inside multi-line strings and JSON. Rewritten error messages carrying source location and context. `create_before_destroy` replacements render as `+/-`. |
| 0.12.10 | `-target` emits a warning that the result is likely incomplete. |
| 0.12.18 | `-compact-warnings`. |
| 0.13 | Root-module **output changes** are treated as applyable changes rather than silently applied. |
| 0.14 | Concise diff renderer hides unchanged fields by default. The separate refresh phase disappears; resources are refreshed on demand during planning. Global `-chdir=DIR` option. |
| 0.15.2 | `-replace=ADDR` on plan and apply, upgrading an update or no-op into a replacement. `apply -destroy` for symmetry with `plan -destroy`. |
| 0.15.4 | **Drift reporting**: plan output names the changes Terraform detected outside Terraform. New `-refresh-only` planning mode as the plannable replacement for `terraform refresh`. |
| 1.1 | Deletion proposals are annotated with *why* (for example a lowered `count`). Terraform states explicitly when it re-binds an instance address because `count` was added or removed. |
| 1.2 | "Changes outside of Terraform" is filtered to attributes that actually contributed to the proposed changes. |
| 1.4 | `terraform plan` can write a plan file even when planning failed, for inspection. Plan renderer rewritten (output intended to be unchanged). |
| 1.6 | `terraform show -json` gains `errored`. Provider schemas cached globally, and schemas skipped entirely for providers that say they aren't needed, cutting memory use on large configurations. |
| 1.7 | Rejections from `postcondition` or `prevent_destroy` show the proposed change **alongside** the error instead of replacing it. `terraform graph` defaults to a simplified resources-only graph (`-type=plan` restores the old one). `terraform console -plan` evaluates against the planned new state. |
| 1.8 | Same-length lists are diffed element-by-element rather than as a whole. `show -json` exposes explicit `applyable` and `complete` flags so wrapping automation stops re-deriving them. |
| 1.9 | Graph building and state copying optimised for very large configurations. `terraform console` supports multi-line input. `terraform init -json`. |
| 1.10 | Faster evaluation with large instance counts. `-state` on plan/apply/refresh deprecated in favour of the `local` backend `path` attribute. |
| 1.13 | Filesystem functions are re-checked for consistent results during apply. Faster evaluation of high-cardinality resources. |
| 1.15 | Applying a plan file against the wrong workspace is now an explicit error. `terraform fmt` handles `.tfquery.hcl`. `state show` fails with exit code 1 when it cannot render. |
| 1.16-rc1 | `terraform graph -format=mermaid`. `terraform console -scope=<module address>`. `state show -json` and `workspace list -json`. |

### HCP Terraform, Stacks, and policy

| Version | Enhancement |
|---|---|
| 0.11.13 | `remote` backend for the CLI-driven remote workflow. |
| 0.12.21 | `terraform login` and `terraform logout`. |
| 0.13 | `remote` backend accepts `-target` for remote operations and supports `state push -force`. |
| 1.1 | **`cloud` block** as a native integration for the CLI-driven run workflow, with per-run `-var`, workspace tags, and better errors. |
| 1.1.9 | Post-plan run tasks surfaced in the CLI. |
| 1.2 | `TF_TOKEN_<hostname>` environment variables for Terraform-native service credentials, taking priority over CLI-config `credentials` blocks. `TF_CLOUD_ORGANIZATION`, `TF_CLOUD_HOSTNAME`, and `TF_WORKSPACE` fallbacks. |
| 1.3 | Pre-plan run tasks surfaced. State uploaded in the JSON integration format so external integrations can consume it. |
| 1.4 | OPA policy evaluation shown during remote runs. `workspace delete` uses the Safe Delete API unless `-force`. `localterraform.com` usable as a stand-in hostname in module and provider sources. |
| 1.6 | Remote plans can be saved with `-out`, inspected with `show`, and applied later. |
| 1.9 | OPA and Sentinel evaluations presented separately. |
| 1.13 | **`terraform stacks`** command exposes stack operations through a plugin. `terraform rpcapi` reaches GA as an integrator-facing RPC surface. |
| 1.14 | `terraform stacks -help`. Component registry source resolution (1.14.2). |
| 1.15 | Input variable validation for Stacks. |
| 1.16-rc1 | Policy plugin credentials resolved from the configured `cloud`/`remote` backend during `init`, `plan`, and `apply`. Policy evaluation summary printed for plan and apply runs. Stacks infers the hostname from `credentials.tfrc.json`. |

### Commands added over time

| Command | Since |
|---|---|
| `terraform state` (family) | 0.7 |
| `terraform console` | 0.8 |
| `terraform workspace` (renamed from `terraform env`) | 0.10 |
| `terraform login` / `terraform logout` | 0.12.21 |
| `terraform providers mirror`, `terraform state replace-provider`, `terraform version -json` | 0.13 |
| `terraform test` (experimental) | 0.15 |
| `terraform metadata functions -json` | 1.4 |
| `terraform test` (GA) | 1.6 |
| `terraform modules -json` | 1.10 |
| `terraform stacks`, `terraform rpcapi` | 1.13 |
| `terraform query` | 1.14 |

---

## Part 2 — Per-release catalogue

### 0.5.0 (May 7, 2015)

Multiple instances of one provider (multi-region). `TF_VAR_name` environment
variables. `s3` remote state. Automatic AWS retries with a configurable count.
`template_file` resource. WinRM provisioning.

### 0.6.0 (June 30, 2015)

`swift` remote state. `keys()` and `values()` functions. SSH bastion host
support and `ssh-agent` forwarding. `command/output` shows module outputs. HTTP
remote state `skip_cert_verification`; S3 remote state `encrypt`. Plan reports
change counts. String-list representation changed so an empty list is
distinguishable from a one-element list.

### 0.7.0 (August 2, 2016)

The release that made Terraform data-aware.

- **Data sources** as a new primitive, refreshed and available during planning.
- **Lists and maps as first-class types**, passable between modules.
- **`terraform state`** command family for state manipulation.
- **State import** (`terraform import`), with high initial AWS coverage.
- `terraform output -json`.
- Functions `sort`, `distinct`, `list`, `map`.
- `gcs` and `azure` remote state providers.

### 0.8.0 (December 2016)

- **`terraform console`**, an interactive interpolation REPL.
- **Terraform version constraints** declarable in configuration and modules.
- **Conditional values** (`count = "${var.env == "prod" ? 1 : 0}"`).
- `depends_on` can reference a module; `output` supports `depends_on`.
- Providers and resources are told to stop on interrupt, so cancellation is fast.
- `import` can specify a provider alias and reads provider configuration from files.

### 0.9.0 (March 2017)

The state architecture that is still current.

- **Backends**, superseding "remote state": file-based configuration, set up by
  `terraform init`, no local caching.
- **State locking**, where the backend supports it (local, S3 via DynamoDB, Consul).
- **State environments**, the feature later renamed to workspaces.
- **Destroy provisioners** (`when = destroy`).
- `TF_CLI_ARGS` / `TF_CLI_ARGS_<name>` for injecting CLI arguments.
- Data source values usable in a `count` calculation.

### 0.10.0 (August 2, 2017)

The provider split. This is the release that made the provider ecosystem
possible.

- **Providers released separately** from Terraform core, with their own
  changelogs and repositories.
- **Automatic provider installation** during `terraform init`.
- **Provider version constraints** in configuration.
- `terraform env` renamed to **`terraform workspace`**.
- `terraform init -upgrade`; `terraform init -from-module`.
- `-target` reaches into descendant modules.
- `.auto.tfvars` files auto-loaded in lexicographic order.
- `contains` function.
- S3 backend `workspace_key_prefix`.

### 0.11.0 (November 16, 2017)

- `module` blocks gain **`version`** (registry version constraints) and
  **`providers`** (explicit provider mapping into a child module).
- `terraform apply` requires **interactive approval** unless given a plan file.
- `terraform version` prints plugin versions alongside core.
- `TF_DATA_DIR` overrides the `.terraform` location.
- GCS and Manta backends gain workspaces and locking.
- Provider configuration in submodules is no longer overridden by a same-named
  parent provider.
- 0.11.13 later adds the **`remote` backend**.

### 0.12.0 (May 22, 2019)

The language rewrite. Not backward compatible; an upgrade tool and guide shipped
alongside.

**New:**

- **First-class expressions.** `ami = var.ami` instead of `ami = "${var.ami}"`.
- **`for` expressions** for building lists and maps by transform and filter.
- **`dynamic` blocks**, the official replacement for the block-as-list-of-maps
  hack.
- **Generalised splat operator**, usable on any list rather than only on
  `count`-ed resources.
- **`null`** as an argument value meaning "omitted".
- **Rich types** in variables and outputs, with type constraints checked early.
- **Resources and modules as object values** in expressions.
- **String templates** with conditionals and iteration.
- `jsondecode`, `csvdecode`, `templatefile`, `formatdate`, `reverse`, `strrev`.
- **`pg` backend**.
- `terraform validate -json`; `validate` narrowed to syntax and type checking so
  it is safe to run unattended (for example on editor save).

**Changed:** plugin wire protocol, state snapshot format, saved plan format, and
the provider index (now `registry.terraform.io`). `-var`/`-var-file` names are
validated against declared variables. JSON configuration syntax gets a
tightly-specified mapping to native syntax.

**Notable additions during the 0.12 series:** `for_each` on resources (0.12.6),
`regex`/`regexall` (0.12.7), `fileset` (0.12.8), `parseint` and `cidrsubnets`
(0.12.10), `-compact-warnings` (0.12.18), `try`/`can` and the
`variable_validation` experiment (0.12.20), `terraform login`/`logout`,
`setsubtract`, and the `cos` backend (0.12.21).

### 0.13.0 (August 10, 2020)

- **`count` and `for_each` for modules.**
- **`depends_on` for modules.**
- **Third-party provider namespaces.** Community and private-registry providers
  install automatically, at the cost of requiring an explicit `source` for any
  non-`hashicorp` provider.
- **Variable `validation` blocks** graduate from experiment.
- **`kubernetes` backend.**
- `terraform state replace-provider`, `terraform providers mirror`,
  `terraform version -json`.
- Provider trust signatures verified and displayed at `init`; installation
  methods configurable per provider in the CLI configuration.
- Root-module output changes are now applyable changes.
- `sum` function; Unicode 12 tables.
- Instances are destroyed from stored state alone, without re-evaluating
  configuration, which removes a family of destroy-time dependency cycles.
- Graph operations optimised for highly-connected configurations.
- Removals: `terraform 0.12upgrade`, `import -provider`, non-`self` references in
  destroy-time provisioners, multiple `required_providers` blocks per module.
- 0.13.2 adds **network mirrors** for provider installation.

### 0.14.0 (December 2, 2020)

- **Dependency lock file** (`.terraform.lock.hcl`) generated by `init` and meant
  to be committed.
- **`sensitive` input variables**, with sensitivity propagating through
  expressions. Outputs derived from them must be marked sensitive too.
- **Forward-compatible state**: Terraform can read and write state written by
  future versions until the format version itself changes.
- **Concise diff renderer**, hiding unchanged fields by default.
- **No separate refresh phase.** Resources are refreshed on demand during
  planning, which also fixes a family of data-source staleness bugs.
- Global **`-chdir=DIR`**.
- `alltrue`, `anytrue`, `textencodebase64`, `textdecodebase64`.
- `ignore_changes` can name map keys absent from the configuration.
- Consul backend chunks state past the 512 KB limit and supports force-unlock;
  GCS backend supports service-account impersonation.
- Experiments introduced: `module_variable_optional_attrs`,
  `provider_sensitive_attrs`.
- 0.14.1 adds remote-workspace version compatibility checks and
  `-ignore-remote-version`; 0.14.3 adds `terraform output -raw`.

### 0.15.0 (April 14, 2021)

Cleanup release: the last intended breaking changes before 1.0.

- **`configuration_aliases`** in `required_providers` replaces empty "proxy"
  provider blocks.
- **`sensitive()` / `nonsensitive()`** and the `one()` function.
- Provider-declared sensitive attributes are redacted by default (experiment
  concluded).
- `init -lockfile=readonly`.
- Windows gets UTF-8 and full virtual-terminal handling, aligning it with other
  platforms and ending support for pre-Windows-10 releases.
- `TF_LOG_CORE` and `TF_LOG_PROVIDER` split core and provider logging.
- Diagnostics gain a left margin rule and resource/provider annotations.
- **`terraform test` appears as an experiment.**
- Removals: `list()`/`map()` functions, vendor provisioners (chef, habitat,
  puppet, salt-masterless), the trailing `[DIR]` argument, `init -lock`,
  `-verify-plugins`, `-get-plugins`, `destroy -force`, `validate -var`, quoted
  type constraints, `ignore_changes = ["*"]`, the `atlas` backend.
- 0.15.2 adds **`-replace=ADDR`** and `apply -destroy`; 0.15.4 adds
  **drift reporting and `-refresh-only`**.

### 1.0.0 (June 8, 2021)

No new features by design. 1.0.0 is v0.15.5 with a
[compatibility promise](https://developer.hashicorp.com/terraform/language/v1-compatibility-promises)
attached, so the 1.x line is where additive change happens.

Later in the 1.0 series: `resource_drift` in `-json` plan logs and provider
protocol 6 support (1.0.3).

### 1.1.0 (December 8, 2021)

- **`moved` block.** Declarative refactoring, so module consumers stop running
  `terraform state mv`.
- **`cloud` block.** Native Terraform Cloud integration for the CLI-driven run
  workflow, with per-run `-var`, workspace tags, and better errors.
- **Deletion reasons** in plan output.
- `nullable` variable argument.
- Module source addresses parsed and normalised at decode time, so `init`
  reports canonical package addresses.
- `terraform console` gains a `type()` function.
- `validate` uses precise resource type information, catching more at validate
  time rather than plan time.
- `apply` of a saved plan checksums the entire provider package.
- `terraform graph` drops `-type=validate` and `-type=eval`.
- 1.1.9 surfaces post-plan run tasks.

### 1.2.0 (May 18, 2022)

- **`precondition` and `postcondition`** blocks on resources, data sources, and
  module outputs.
- **`replace_triggered_by`** lifecycle argument.
- **`TF_TOKEN_<hostname>`** credentials for Terraform-native services, taking
  priority over CLI-config `credentials` blocks.
- Condition and validation error messages evaluated as expressions.
- "Changes outside of Terraform" filtered to contributing attributes only.
- `TF_CLOUD_ORGANIZATION`, `TF_CLOUD_HOSTNAME`, `TF_WORKSPACE` fallbacks for the
  `cloud` block.
- `show -json` includes exact output types.
- AzureRM backend defaults to MSAL and supports OIDC service-principal auth.
- SSH provisioner connections work over an HTTP proxy and support newer key
  algorithms.
- TLS 1.2 minimum for Terraform's own outgoing connections; SHA-1 CA
  certificates rejected.

### 1.3.0 (September 21, 2022)

- **`optional(type, default)`** object attributes reach stable. The experimental
  `defaults` function is removed in favour of the second `optional` argument.
- `startswith`, `endswith`, `timecmp`.
- `moved` blocks work across separate module packages.
- `terraform fmt` accepts multiple target paths.
- Pre-plan run tasks surfaced; state uploaded in JSON integration format.
- Pre/postconditions are now evaluated during apply for every instance in the
  plan, including no-op ones, so failures surface in the same run that caused
  them.
- `PlanResourceChange` called on destroy for compatible providers.
- Removals: `import -allow-missing-config`; the `artifactory`, `etcd`, `etcdv3`,
  `manta`, `swift`, and legacy `azure` backends; ADAL authentication in the
  AzureRM backend.

### 1.4.0 (March 8, 2023)

- **`terraform_data`**, a built-in managed resource that replaces `null_resource`
  and can store values of any type.
- **`terraform metadata functions -json`** exports function signatures.
- `terraform plan` can save a plan file even when planning errored.
- `workspace select -or-create`.
- Sensitive interactive input is masked.
- Global provider cache entries are ignored unless already covered by a lock-file
  checksum.
- OPA policy evaluation shown for remote runs.
- `local-exec` gains `quiet`; HTTP backend gains mTLS; GCS backend gains
  `kms_encryption_key` and `storage_custom_endpoint`.
- `localterraform.com` usable in module and provider sources.
- `yamlencode` drops its experimental caveat and comes under the compatibility
  promise.
- Plan renderer rewritten (output intended to be identical).

### 1.5.0 (June 12, 2023)

- **`import` block.** Configuration-driven, plannable import, shown as part of a
  normal plan.
- **`-generate-config-out=PATH`** writes HCL for imported resources lacking
  configuration.
- **`check` blocks** with `assert` blocks and optional scoped data sources. A
  failing check does not halt execution, unlike pre/postconditions.
- `plantimestamp` and `strcontains` functions.
- State snapshots persisted periodically during apply, and immediately on
  SIGINT.
- `pg` backend reads `PG_*` environment variables.

!!! info "License change"
    Terraform 1.5.x is where HashiCorp moved from MPL 2.0 to BUSL 1.1. The
    OpenTofu fork branches from this point. The changelog does not record the
    relicense; see [version-facts](../research-cache/version-facts.md).

### 1.6.0 (October 4, 2023)

- **`terraform test` reaches GA**, with a design substantially changed from the
  experiment: `.tftest.hcl` files containing `run` blocks that plan or apply and
  assert against the resulting plan and state.
- `import` block `id` accepts plan-time-known expressions.
- Remote plans can be saved with `-out`, inspected, and applied.
- Terraform tracks partial knowledge about unknown values (possible length,
  possible nullness), enabling known results from some operations on unknowns.
- Provider schemas cached globally, and skipped entirely for providers that
  declare they don't need them.
- `show -json` gains `errored`.
- Kubernetes backend splits state across secrets, removing the 1 MiB limit.
- S3 backend rebuilt on AWS SDK for Go v2, adding web-identity assume-role,
  shared config files, custom CA bundles, IMDS endpoint controls, proxy and
  FIPS/dualstack options, `sts_region`, `retry_mode`, and account-ID guards.

### 1.7.0 (January 17, 2024)

- **Test mocking**: `mock_provider`, `override_resource`, `override_data`,
  `override_module`. Apply-mode tests no longer need real cloud credentials.
- **`removed` block.** Configuration-driven removal from state, planned and
  applied like any other action, with a choice of destroy or forget.
- **`for_each` on `import` blocks.**
- `terraform console -plan` evaluates against the planned new state.
- `terraform graph` defaults to a simplified resources-only graph.
- Rejections from `postcondition` or `prevent_destroy` show the proposed change
  alongside the error.
- Test provider blocks can use test-file variables, run outputs, and functions;
  `terraform.tfvars` in the test directory is loaded automatically.
- `nonsensitive` no longer errors on an already-non-sensitive value.
- Input variable validations restored to the state file (with cross-version
  patch guidance in the upgrade notes).

### 1.8.0 (April 10, 2024)

- **Provider-defined functions**, called as `provider::name::function()`.
- **Cross-type `moved`**: a provider can declare it converts from another
  resource type, letting a remote object move between resource types.
- `issensitive` function; `decode_tfvars`, `encode_tfvars`, `encode_expr` in the
  built-in provider.
- `show -json` exposes `applyable` and `complete` flags, so automation stops
  re-deriving them from Terraform Core's logic.
- Same-length lists diffed element-by-element.
- Generated import configuration emits `jsonencode(...)` for embedded JSON.
- `providers lock -enable-plugin-cache`.
- Sensitive values tracked more accurately in state and plans.

### 1.9.0 (June 26, 2024)

- **Variable validation can reference other objects**: other variables, data
  sources, and locals, rather than only the variable being validated.
- **`templatestring`**, the dynamic counterpart to `templatefile`.
- `removed` blocks can declare destroy-time provisioners.
- `moved` supports `null_resource` → `terraform_data`.
- `terraform init -json`.
- Test runs preserve dynamic sensitivity on variables.
- `terraform console` accepts multi-line input.
- Graph building and state copying optimised for large configurations.
- Provider version constraints no longer allowed inside `.tftest.hcl`.
- Invalid `import` blocks pointing at nonexistent modules now error instead of
  being silently ignored.

### 1.10.0 (November 27, 2024)

- **Ephemeral resources**, re-read at each evaluation phase and never persisted.
- **Ephemeral values**: input variables and outputs can be declared `ephemeral`.
- **`ephemeralasnull`** function.
- **`terraform modules -json`**, listing installed modules and whether each is
  still referenced.
- **S3 native state locking** introduced alongside DynamoDB locking; both locks
  are taken during the transition.
- `element` accepts negative indices.
- Stricter `import` block validation during `terraform validate`.
- Faster evaluation with large instance counts.
- `-state` on plan/apply/refresh deprecated in favour of the `local` backend
  `path`.
- `moved` address parsing respects reserved keywords, so some references now
  need a `resource.` prefix.

### 1.11.0 (February 27, 2025)

- **Write-only attributes.** Providers mark attributes as write-only; values are
  not persisted to state and can be supplied from ephemeral values.
- **`terraform test -junit-xml` reaches GA.**
- **S3 native state locking reaches GA** via `use_lockfile`; DynamoDB arguments
  deprecated, with both usable together during migration.
- `override_during = plan` applies test mocks during `command = plan` runs.
- `state_key` on `run` blocks selects the internal state file.
- Provider installation uses `.netrc` credentials.
- Azure backend authentication rebuilt on the current Azure SDK, adding
  `use_cli`, `use_aks_workload_identity`, and file-path client credentials.

### 1.12.0 (May 14, 2025)

- **OCI Object Storage backend.**
- **`import` block `identity`** attribute, mutually exclusive with `id`.
- **Short-circuiting logical operators.**
- `terraform test -parallelism=n`; runs annotatable for parallel execution;
  execution continues when an expected failure does not occur; detailed
  diagnostic objects on assertion failure.
- `terraform init` works when tests exist but no configuration files sit
  directly in the directory.
- Linux kernel 3.2 or later now required.
- Alpha-only experiments: `terraform rpcapi` and deferred actions
  (`plan -allow-deferral`).

### 1.13.0 (August 20, 2025)

- **`terraform stacks`** command, exposing stack operations through a plugin
  (subcommands depend on the plugin implementation).
- **`terraform rpcapi` reaches GA**, aimed at integrators rather than end users.
- Filesystem functions checked for consistent results during apply.
- Test files can define their own external variables, and file-level variable
  blocks can reference run outputs and other variables.
- Parallel teardown in tests.
- Faster evaluation of high-cardinality resources.
- `init` succeeds when a provider constraint matches at least one valid version.
- Better type-mismatch error messages; invalid static references via indexes on
  objects are now detected.

### 1.14.0 (November 19, 2025)

- **List resources** declared in `*.tfquery.hcl` files, for querying and
  filtering existing infrastructure.
- **`terraform query`**, which runs those list operations and can generate
  configuration for importing the results.
- **`actions` block.** Provider-defined operations outside the CRUD model (for
  example invoking a Lambda or a CDN invalidation), triggered through a
  resource's lifecycle or with `-invoke`.
- **`GenerateResourceConfiguration` RPC** for more precise generated
  configuration during import.
- `terraform validate -query` for offline validation of query files.
- Test verbose mode includes expected diagnostics; `prevent_destroy` ignored
  during test cleanup.
- Alpha-only experiments: `backend` blocks and `skip_cleanup` in tests, plus a
  `terraform test cleanup` command.
- Container parallelism may drop depending on the CPU bandwidth limit.

### 1.15.0 (April 29, 2026)

- **`deprecated` attribute on `variable` and `output` blocks**, warning at the
  call site.
- **Variables and locals in module `source` and `version`.** Most commands now
  accept variable values as a consequence.
- **`convert` function** for precise inline type conversion.
- **`output` blocks accept an explicit `type` constraint.**
- **`terraform validate` checks the `backend` block**: type exists, required
  attributes present, backend validation passes.
- Windows ARM64 builds (Linux s390x follows in 1.15.4).
- S3 backend authenticates via `aws login`.
- Functions allowed inside test `mock` blocks.
- Better detection of deprecated resource attributes and blocks, and
  provider-supplied deprecation messages included in warnings.
- Input variable validation for Stacks.
- PowerShell support restored for the SSH-based `file` and `remote-exec`
  provisioners.
- `init` skips dependencies declared only in a development override.
- Applying a plan file against the wrong workspace is now an explicit error.
- `terraform fmt` handles `.tfquery.hcl`.
- 1.15.5 allows a module `version` to evaluate to `null` for dynamic sources.

### 1.16.0-rc1 (August 12, 2026)

!!! warning "Release candidate"
    1.16.0 has not shipped as stable. Re-verify against the final release notes.

- **`import` blocks inside modules.**
- **`terraform_data` `store` block**, holding ephemeral and sensitive values
  across plan and apply. Terraform also now stores planned private data for
  providers.
- **`lifecycle` `destroy = false`**, preventing destruction of a resource.
- **Action trigger `on_failure` modes**: `halt`, `taint`, `continue`. Actions
  gain `before_destroy` and `after_destroy` events and a `caller` symbol.
  `-invoke` combines with `-target` to name the calling instance.
- Providers can expose nested blocks as computed values.
- **`terraform graph -format=mermaid`.**
- **`terraform console -scope=<module address>`.**
- `state show -json` and `workspace list -json`.
- `contains()` can test for `null`.
- Policy plugin credentials resolved from the configured `cloud`/`remote`
  backend; policy evaluation summary printed for plan and apply.
- Tests report which resources were left behind under `skip_cleanup`.
- Linux s390x binaries.

---

## Reading notes

!!! note "Features often land in patch releases"
    The `x.y.0` changelog is not the whole story. `for_each` on resources
    (0.12.6), `try`/`can` (0.12.20), `terraform login` (0.12.21), network
    mirrors (0.13.2), `output -raw` (0.14.3), `-replace` (0.15.2), and
    `-refresh-only` (0.15.4) all arrived mid-series. If a feature seems to
    predate the minor release you associate it with, check the patch releases.

!!! note "The compatibility promise is about configurations, not flags"
    From 1.0 onward, existing configurations keep working, but individual CLI
    flags, backend arguments, and provider attributes are still deprecated and
    removed within the 1.x line. 1.3 removed five backends; 1.10 removed the
    deprecated S3 assume-role attributes; 1.11 deprecated DynamoDB locking.
    Pin `required_version` so an upgrade does not hit a removal unannounced.

## Sources

Generated from `git show origin/v<X.Y>:CHANGELOG.md` for every version branch of
[hashicorp/terraform](https://github.com/hashicorp/terraform) (`v0.11` through
`v1.16`), fetched 2026-08-13. The `v0.11` branch changelog covers 0.5.0 through
0.11.15; releases before 0.5.0 are not recorded there and are omitted.
Per-release links: [v1.15](https://github.com/hashicorp/terraform/blob/v1.15/CHANGELOG.md),
[v1.14](https://github.com/hashicorp/terraform/blob/v1.14/CHANGELOG.md),
[v1.13](https://github.com/hashicorp/terraform/blob/v1.13/CHANGELOG.md),
[v1.12](https://github.com/hashicorp/terraform/blob/v1.12/CHANGELOG.md),
[v1.11](https://github.com/hashicorp/terraform/blob/v1.11/CHANGELOG.md),
[v1.10](https://github.com/hashicorp/terraform/blob/v1.10/CHANGELOG.md),
[v1.9](https://github.com/hashicorp/terraform/blob/v1.9/CHANGELOG.md),
[v1.8](https://github.com/hashicorp/terraform/blob/v1.8/CHANGELOG.md),
[v1.7](https://github.com/hashicorp/terraform/blob/v1.7/CHANGELOG.md),
[v1.6](https://github.com/hashicorp/terraform/blob/v1.6/CHANGELOG.md),
[v1.5](https://github.com/hashicorp/terraform/blob/v1.5/CHANGELOG.md),
[v1.4](https://github.com/hashicorp/terraform/blob/v1.4/CHANGELOG.md),
[v1.3](https://github.com/hashicorp/terraform/blob/v1.3/CHANGELOG.md),
[v1.2](https://github.com/hashicorp/terraform/blob/v1.2/CHANGELOG.md),
[v1.1](https://github.com/hashicorp/terraform/blob/v1.1/CHANGELOG.md),
[v1.0](https://github.com/hashicorp/terraform/blob/v1.0/CHANGELOG.md),
[v0.15](https://github.com/hashicorp/terraform/blob/v0.15/CHANGELOG.md),
[v0.14](https://github.com/hashicorp/terraform/blob/v0.14/CHANGELOG.md),
[v0.13](https://github.com/hashicorp/terraform/blob/v0.13/CHANGELOG.md),
[v0.12](https://github.com/hashicorp/terraform/blob/v0.12/CHANGELOG.md),
[v0.11 and earlier](https://github.com/hashicorp/terraform/blob/v0.11/CHANGELOG.md).
