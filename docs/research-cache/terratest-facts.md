# Terratest Facts (source-derived)

Verified facts for **A2 — Testing Terraform** and the Terratest half of [[terraform-testing]].
Mined from the local checkout, not from blog posts.

_Source: `C:\opt\learn\terraform\repos\terratest`. The working tree sits at `b9650d0d` (2026-06-27,
v1.0.1-era, detached HEAD), and `origin/main` is **30 commits ahead** at `b28c2fd9` (2026-08-10),
which is where the **v2 restructure** lives. Everything below labelled v2 was read from the
`origin/main` ref via `git show origin/main:<path>`, so it is the fetched remote state, not the
checked-out tree. Terratest publishes its docs from `docs/_docs/` in the same repo (Jekyll →
terratest.gruntwork.io), so those pages are first-party. Last verified: 2026-08-15._

!!! tip "The working tree is behind — check out `main` before reading code locally"
    A `git -C repos\terratest checkout main && git pull` brings the tree to the v2 layout. Until
    then, `ls modules/` shows the **v1** package list and will contradict this note. Nothing here
    requires updating the checkout; the facts were read from `origin/main` directly.

## Version state — v1 is stable and frozen, v2 is beta

| Version | Date | Notes |
|---|---|---|
| `v0.56.0` | 2026-02-12 | last of the long-running v0.x line |
| **`v1.0.0`** | **2026-05-11** | first stable release; semver starts here |
| `v1.0.1` | 2026-06-27 | current v1 |
| `modules/*/v2.0.0-beta.1` | 2026-07-20 | first v2 beta, per-module tags |
| `modules/*/v2.0.0-beta.2` | 2026-08-10 | current v2 beta |

The versioning policy is stated in the README and is unusually explicit:

- From v1.0.0, semver holds — breaking API changes only in a major release.
- Symbols renamed or replaced in v1 stay as deprecated aliases; **removal is deferred to v2**.
- **v1 is in maintenance: security fixes only, on the `v1` branch, until 12 months after v2.0.0
  reaches GA.** v2 ships under new `/v2` module paths, so pinned v1 consumers are unaffected.

Requires **Go 1.26+** (raised at v1.0.0). Apache 2.0.

!!! warning "Correction to earlier notes"
    [[terraform-testing]] recorded "Terratest latest published **2026-05-11**". That date is
    **v1.0.0**, not a rolling latest — v1.0.1 followed on 2026-06-27 and the v2 betas on 2026-07-20
    and 2026-08-10. The rest of that note (native `terraform test` vs Terratest, and when to use
    which) still holds.

## v2 is a multi-module split, and that is the headline change

v1 is one Go module (`github.com/gruntwork-io/terratest`) containing every package. v2 breaks it
into **16 independently versioned Go modules**, each with its own `go.mod` and its own tag:

```
github.com/gruntwork-io/terratest/modules/terraform/v2
github.com/gruntwork-io/terratest/modules/core/v2
github.com/gruntwork-io/terratest/modules/aws/v2
…
```

Consequences worth knowing before writing a chapter:

- A test that only drives Terraform pulls in the Terraform helpers, not the AWS, Azure, GCP,
  Kubernetes and Helm SDKs. That is the point of the split — v1's single module dragged every cloud
  SDK into every consumer's dependency graph.
- Tags are per-module (`modules/terraform/v2.0.0-beta.2`), so modules can move at different speeds.
- Development uses a `go.work` workspace listing all sixteen. The file's own comment records why:
  it resolves the local submodules for `go build`/`go test` "without publishing anything or adding
  per-module `replace` directives", and releases are cut with **`GOWORK=off`** so the published
  modules resolve each other by version from the proxy (`scripts/check-release-mode.sh` enforces it).

### Package moves and removals in v2

Small utility packages consolidated into **`modules/core`**: `files`, `formatting`, `logger`,
`random`, `retry`, `shell`, `testing`, `teststate`.

Two directory renames drop the hyphen: `http-helper` → `httphelper`, `test-structure` →
`teststructure`, and `dns-helper` → `dnshelper`.

**Six packages were deleted outright** in commit `3444d06d`, "Remove deprecated packages": `collections`,
`environment`, `git`, `version-checker`, `slack`, `oci`. A v1 test importing any of these does not
port to v2 by changing the import path — the code is gone.

!!! warning "The published packages-overview page is behind the split"
    `docs/_docs/01_getting-started/packages-overview.md` on `origin/main` still lists `files`,
    `logger`, `random`, `retry`, `shell` as top-level packages and does not mention `core`. The
    module tree is the ground truth. It does already carry the renamed `httphelper` and
    `teststructure` names, so the page is partially updated rather than wholly stale.

## The four-variant naming convention

The single most useful thing to teach about the API. Every helper comes in up to four forms:

| Suffix | Takes `context.Context` | On error |
|---|---|---|
| `Foo` | no | calls `t.Fatal`, failing the test |
| `FooE` | no | returns `error` to the caller |
| `FooContext` | yes | calls `t.Fatal` |
| `FooContextE` | yes | returns `error` |

Two independent suffixes. **`E`** is the long-standing convention: use the bare form when any
failure should fail the test, the `E` form when you want the error back to assert on it or retry it.
**`Context`** was added in v1 so callers can plumb timeouts, cancellation and tracing through.

The migration guide is direct about the preferred call: `terraform.ApplyContext(t, ctx, opts)` over
`terraform.Apply(t, opts)`, and it recommends **`t.Context()`** (Go 1.24+) over
`context.Background()` because it ties the context's lifetime to the test.

**Verified in the source, not just the docs.** `modules/terraform/apply.go` at tag `v1.0.1` defines
both forms, with `// Deprecated: Use [ApplyContext] instead.` on each bare variant. The same file on
`origin/main` (v2) defines **only** the `*Context` variants — `Apply`, `ApplyE`, `InitAndApply`,
`ApplyAndIdempotent` and their `E` forms are gone. So the README's stated policy is exactly what the
code does, and **the v1 → v2 port is mechanically "add `ctx` to every call"**.

```go
ctx := t.Context()

defer terraform.DestroyContext(t, ctx, options)   // cleanup always runs
terraform.InitAndApplyContext(t, ctx, options)
url := terraform.OutputContext(t, ctx, options, "url")
```

## Practices the docs treat as non-negotiable

These are the parts of Terratest that are judgement rather than API, and they are what a chapter
should carry:

- **Always `defer` the destroy.** Tests deploy real resources into a real account; `defer
  terraform.DestroyContext(...)` runs even when an assertion fails. Gruntwork additionally runs
  [cloud-nuke](https://github.com/gruntwork-io/cloud-nuke) nightly in the test account, on the
  assumption that cleanup will sometimes fail anyway (CI dying mid-run, network faults).
- **Namespace every resource name.** `random.UniqueID()` returns a 6-character identifier short
  enough for resource names; interpolate it into ASG names, security group names, IAM role names.
  Two reasons: never collide with production, and never collide with a parallel test run.
- **Run in a separate account.** The docs say a completely separate AWS account, and note the
  design consequence — you must write the module so account IDs, domains and IPs are injectable,
  which is dependency injection and makes the code better anyway.
- **Assert idempotency.** `terraform.ApplyAndIdempotentContext()` applies, then applies again and
  fails the test if the second plan is non-empty. This catches provider bugs and configurations
  that quietly drift on every run.
- **Defeat Go's test cache.** Since Go 1.10 results are cached, and editing only `.tf` files leaves
  the Go code unchanged, so `go test` returns a stale pass. Use `-count=1`.
- **Raise the timeout and log to stdout.** Go's default test timeout is 10 minutes and it kills the
  process, so **even deferred cleanup does not run**. Use `-timeout 30m`. Go's `t.Log` buffers until
  the test ends, which starves CI log-inactivity watchdogs and hides hangs, so use Terratest's
  `logger.Log`, which writes to stdout immediately. Across multiple packages Go buffers even that,
  so add `-p 1`.

The canonical invocation combining all three:

```bash
go test -count=1 -timeout 30m -p 1 ./...
```

- **Stage long tests for local iteration.** The `teststructure` package splits a test into named
  stages, each of which is skipped by setting `SKIP_<stage_name>` to any non-empty value. Stages
  persist their outputs to the working directory (`SaveString`, `SaveAmiId`, and the matching
  `Load*` calls), and when any `SKIP_*` variable is set Terratest also skips copying to a temp
  folder so cached state survives between runs. This is what makes the "rebuild the AMI once,
  re-run validation twenty times" loop possible.

## `terraform.Options` — the surface you actually configure

Read from `modules/terraform/options.go` on `origin/main`. Beyond `TerraformDir`, `Vars`,
`VarFiles` and `EnvVars`, the fields worth knowing:

| Field | Why it matters |
|---|---|
| `RetryableTerraformErrors` | regexp → message map; matching apply failures are retried, with `MaxRetries` and `TimeBetweenRetries`. This is how you survive eventual consistency in cloud APIs |
| `WarningsAsErrors` | regexp map turning chosen Terraform warnings into test failures |
| `TerraformBinary` | which binary to run — the OpenTofu switch |
| `PlanFilePath` | write a plan file, or apply one; the hook for plan-only assertions |
| `Targets`, `Parallelism`, `Lock`, `LockTimeout`, `PluginDir`, `Upgrade`, `Reconfigure`, `MigrateState` | direct pass-through of the matching CLI flags |
| `MixedVars` + `VarInline()` / `VarFile()` | `-var` and `-var-file` in an arbitrary order, which plain `Vars`/`VarFiles` cannot express, since precedence depends on order |
| `SetVarsAfterVarFiles` | the simpler ordering lever for the same problem |

One documented sharp edge: Terraform cannot take `null` through the command line, so
`Vars: map[string]any{"foo": nil}` assigns the **string literal `"null"`**. Nulls nested inside
lists and maps do work.

## OpenTofu support is real and is the default in the docs

`DefaultExecutable` in `modules/terraform/cmd.go` resolves to `terraform` when that binary is on
`PATH` and **falls back to `tofu` otherwise**, so installing only OpenTofu is enough. Pin a test to
OpenTofu regardless of what else is installed with `TerraformBinary: "tofu"`. The quick-start guide
drives OpenTofu throughout and uses [mise](https://mise.jdx.dev/) to pin Go and OpenTofu versions.

## The `terragrunt` helper module tracks Terragrunt's modern CLI

`modules/terragrunt/` is a full helper set, not a token wrapper: `run.go`, `run_all.go`, `plan.go`,
`apply.go`, `destroy.go`, `output.go`, `init.go`, `validate.go`, `hcl_validate.go`, `graph.go`,
`render.go`, and the stack commands `stack_generate.go`, `stack_run.go`, `stack_output.go`,
`stack_clean.go`. The packages overview describes it as running `terragrunt apply --all` /
`destroy --all` and testing "stack configurations with dependencies" — i.e. it speaks the post-CLI-
redesign command shape recorded in [[terragrunt-facts]], including `terragrunt.stack.hcl` stacks.

That makes an E4 exercise directly testable: generate a stack, run it, assert on `stack output`.

## Project layout the docs assume

Infrastructure code in `examples/`, Go tests in `test/`, and **the tests live in their own Go
module** (`cd test && go mod init …`), so the module under test never gains a Go dependency.
`.gitignore` covers `.terraform/`, `*.tfstate`, `*.tfstate.backup`, `.terraform.lock.hcl`.

## Positioning — what Terratest is for, in its own words

The docs draw the line against `*-spec` tools (inspec, serverspec, awspec, Goss, kitchen-terraform)
this way: those verify **properties** of a single server or resource, while Terratest asks whether
the infrastructure **actually works** — make the HTTP request and check the response, write to the
database and read it back, roll a new container and confirm no downtime. It is also explicitly an
end-to-end tool used across whole systems (build an AMI with Packer, apply Terraform, exercise the
result, tear it down), and Gruntwork runs the suites nightly to catch regressions in *dependencies*
such as new Terraform versions.

That framing is the argument for keeping both tools in **A2**: native `terraform test` answers "does
the configuration produce what I said", Terratest answers "does the deployed thing behave".

## Sources

- Local checkout: `C:\opt\learn\terraform\repos\terratest`, working tree `b9650d0d` (v1.0.1-era),
  `origin/main` `b28c2fd9` (2026-08-10) for all v2 facts
- In-repo docs: `docs/_docs/` (publishes as <https://terratest.gruntwork.io/docs/>)
- API surface: `modules/terraform/{apply,options,cmd}.go`; v1/v2 diff via `git show v1.0.1:…` vs
  `git show origin/main:…`
- v2 layout: `go.work`, `modules/*/go.mod`, removal commit `3444d06d`
