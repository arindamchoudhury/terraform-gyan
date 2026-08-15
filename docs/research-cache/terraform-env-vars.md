# Terraform environment variables — the source-derived catalogue

Every `TF_*` variable the Terraform CLI actually reads, taken from the code rather than the docs
page, and marked with where (if anywhere) it is documented. The docs page lists **14**; the binary
reads **more than that**, and several of the extras are the ones you reach for when something is
wrong.

_Source: `C:\opt\learn\terraform\repos\terraform` at `b9e178decf` ("Prepare before 1.15.8 release",
2026-07-08). Enumerated with `os.Getenv` / `os.LookupEnv` sweeps over `internal/` and the root
package, excluding `_test.go` files. Documentation status checked against
[the CLI environment variables page](https://developer.hashicorp.com/terraform/cli/config/environment-variables)
on 2026-08-15. Version gates via `git tag --contains`. Last verified: 2026-08-15._

!!! note "Scope"
    Test-harness variables are excluded: `TF_ACC` and the backend-specific `TF_S3_TEST`,
    `TF_CONSUL_TEST`, `TF_K8S_TEST`, `TF_OSS_TEST`, `TF_OCI_BACKEND_TEST`, `TF_AZURE_TEST`,
    `TF_COS_APPID`, `TF_CONFIGLOAD_TEST_KEEP_TMP`. They gate acceptance tests in this repository and
    do nothing in a release binary. Provider-side credential variables (`AWS_*`, `ARM_*`,
    `GOOGLE_*`) are the providers' own and are not listed here.

## On the documentation page

`TF_LOG`, `TF_LOG_PATH`, `TF_INPUT`, `TF_VAR_<name>`, `TF_CLI_ARGS`, `TF_CLI_ARGS_<name>`,
`TF_DATA_DIR`, `TF_WORKSPACE`, `TF_IN_AUTOMATION`, `TF_REGISTRY_DISCOVERY_RETRY`,
`TF_REGISTRY_CLIENT_TIMEOUT`, `TF_STATE_PERSIST_INTERVAL`, `TF_CLI_CONFIG_FILE`,
`TF_PLUGIN_CACHE_DIR` (with `TF_PLUGIN_CACHE_MAY_BREAK_DEPENDENCY_LOCK_FILE` described alongside it).

Two more are documented, just not there: **`TF_LOG_CORE` and `TF_LOG_PROVIDER`** live on the
[debugging page](https://developer.hashicorp.com/terraform/internals/debugging) (both read in
`internal/logging/logging.go`), and **`TF_TOKEN_<host>`** on the CLI-configuration credentials page
(`internal/command/cliconfig/credentials.go`).

Note where two of them are read, because it explains their reach: `TF_CLI_ARGS` is handled in
`main.go` (`EnvCLI`) and `TF_IN_AUTOMATION` in `commands.go` — both in the **root package**, before
any command runs, which is why they apply uniformly rather than per subcommand.

## Read by the CLI, absent from that page

| Variable | What the source does with it | Read in |
|---|---|---|
| `TF_DISABLE_PLUGIN_TLS` | any non-empty value **disables provider auto-mTLS** | `internal/command/meta_providers.go:35` |
| `TF_REATTACH_PROVIDERS` | attach to an already-running provider process (debugger / SDK dev flow) instead of launching one | `internal/command/meta_providers.go`, `internal/command/meta_backend.go:2183` |
| `TF_FORCE_LOCAL_BACKEND` | makes the `remote` and `cloud` backends run operations **locally** while still using the remote state | `internal/backend/remote/backend.go:255`, `internal/cloud/backend.go` |
| `TF_WARN_OUTPUT_ERRORS` | downgrades **output interpolation errors to warnings** | `internal/terraform/features.go:10` |
| `TF_ENABLE_PLUGGABLE_STATE_STORAGE` | turns on the **pluggable state storage** experiment at `init` | `internal/command/arguments/init.go:132` |
| `TF_SKIP_CREATE_DEFAULT_WORKSPACE` | suppresses creation of the `default` workspace at `init`, overriding an explicit `-create-default-workspace=true` | `internal/command/arguments/init.go:136` |
| `TF_APPEND_USER_AGENT` | appended to the `Terraform/<version>` User-Agent on outbound HTTP | `internal/httpclient/useragent.go:17` |
| `TF_CLOUD_HOSTNAME`, `TF_CLOUD_ORGANIZATION`, `TF_CLOUD_PROJECT` | supply `cloud` block settings from the environment | `internal/cloud/` |
| `TF_STACKS_*` (`HOSTNAME`, `ORGANIZATION_NAME`, `PROJECT_NAME`, `STACK_NAME`, `TOKEN`, `PLUGIN_DEV_OVERRIDE`) | Stacks-related configuration and dev overrides | Stacks packages |
| `TERRAFORM_CONFIG` | legacy predecessor of `TF_CLI_CONFIG_FILE` | `internal/command/cliconfig/` |

`TF_RUNNING_IN_GITHUB_ACTIONS`, `TF_RUNNING_IN_AZURE` and `TF_RUNNING_IN_ADO_PIPELINES` appear only
in test files in this checkout, so treat them as harness signals rather than CLI behaviour.

## The four worth knowing in detail

### `TF_DISABLE_PLUGIN_TLS` — the mTLS escape hatch, and why to be careful with it

```go
// This is not intended to be set by end-users.
var enableProviderAutoMTLS = os.Getenv("TF_DISABLE_PLUGIN_TLS") == ""
```

Terraform talks to each provider plugin over a local gRPC channel secured with **automatically
generated mutual TLS**. Any non-empty value here turns that off. The source comment says the purpose
is the plugin SDK test framework, "to reduce startup overhead when rapidly launching and killing
lots of instances of the same provider", and states plainly that it **is not intended to be set by
end-users**.

It is nonetheless the direct lever for one class of local failure: a security product that
intercepts or filters loopback traffic can break the handshake, and the symptom is
`Failed to load plugin schemas` on every provider. Use it to *confirm the diagnosis* — if disabling
mTLS makes the error vanish, the interceptor is the cause — and then fix the interceptor rather than
leaving the variable set. With it set, the plugin channel is unauthenticated and unencrypted on
loopback, which is a weaker position than the default even though the traffic never leaves the
machine.

### `TF_WARN_OUTPUT_ERRORS` — a legacy-compatibility flag in a file called "feature flags"

It lives in `internal/terraform/features.go`, whose entire contents are a comment reading "This file
holds feature flags for the next release" and one variable. When set, an output whose expression
fails to evaluate produces **warnings instead of errors**, the failure is logged at `[ERROR]` level,
and the output is recorded as **unknown** with its type preserved where the evaluator could infer
one.

The precision worth keeping: it only downgrades *interpolation* errors. The checks immediately after
it — the sensitive-output and related validations — are deliberately excluded, with the source
saying they "relate to features that were added more recently than the historical change to treat
invalid output values as errors rather than warnings." So this is a compatibility shim for
pre-0.12-era behaviour, not a general "make my outputs stop failing" switch.

### `TF_ENABLE_PLUGGABLE_STATE_STORAGE` — how to reach the `state_store` block

The schema sweep recorded in [[release-feature-map]] found a `state_store` block sitting in
`internal/configs` behind `AllowExperimentalFeatures` since 1.13, announced in no changelog. This is
the switch that turns it on: set it to any non-empty value and `init` sets `EnablePssExperiment`.
Introduced in commit `f494ff5540` (2025-07-30), first tagged **v1.14.0**.

Backend initialisation under it emits its own warnings, which say more about the feature's state
than any docs page does — for a builtin provider, *"Terraform is using a builtin provider for
initializing state storage. Terraform will be less able to detect when state migrations are required
in future init commands."*

### `TF_SKIP_CREATE_DEFAULT_WORKSPACE` — and the `init` flag it overrides

Both the variable and a `-create-default-workspace` flag on `init` arrived in commit `6b73f710f8`
(2025-10-15), first tagged **v1.15.0**. The comment explains the unusual precedence — the variable
**wins over an explicit `-create-default-workspace=true`**, because a `true` on the command line is
"indistinguishable from the default value being used". Relevant to any backend where creating the
`default` workspace costs something, and to **A7**'s workspace discussion, since it is the first
sign of Terraform treating the `default` workspace as optional.

## Method, for repeating this on another release

```bash
grep -rhoE '(os\.Getenv|os\.LookupEnv)\("(TF_|TERRAFORM_)[A-Z0-9_]*"\)' internal/ *.go --include=*.go \
  | sed -E 's/.*"(.*)".*/\1/' | sort -u
```

Then filter out anything whose only non-`_test.go` reader is a harness, and check each survivor
against the docs page. Variables read by **prefix scan** rather than by exact name (`TF_VAR_`,
`TF_CLI_ARGS_<name>`, `TF_TOKEN_<host>`) will not appear in that grep — search for the prefix string
instead. `TF_IGNORE`, which some guides mention, is **not read anywhere in this repository**; it
belongs to the config-upload library used for HCP Terraform, not to the CLI.

## Sources

- Local checkout `C:\opt\learn\terraform\repos\terraform` @ `b9e178decf` (2026-07-08, 1.15.8 prep)
- `internal/command/meta_providers.go`, `internal/command/arguments/init.go`,
  `internal/terraform/features.go`, `internal/terraform/node_output.go`,
  `internal/backend/remote/backend.go`, `internal/httpclient/useragent.go`,
  `internal/command/cliconfig/`, `main.go`, `commands.go`
- [CLI environment variables](https://developer.hashicorp.com/terraform/cli/config/environment-variables) (checked 2026-08-15)
- Version gating: `git tag --contains` on `f494ff5540` (v1.14.0) and `6b73f710f8` (v1.15.0)
