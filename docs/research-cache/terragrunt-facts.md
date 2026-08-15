# Terragrunt Facts (source-derived)

Verified facts for **E4 — Large-scale state & repo architecture** and the Terragrunt half of
[[workspaces]]. Mined from the local checkout, not from blog posts.

_Source: `C:\opt\learn\terraform\repos\terragrunt` at commit `54c43a44c` (2026-08-13), which is
`main` and carries tags up to **v1.1.3**. Terragrunt ships its own documentation site inside the
repo (`docs/src/content/docs/`, Astro/Starlight), and that tree is what renders at
docs.terragrunt.com — so the doc pages cited here are first-party, version-controlled sources rather
than a scraped site. Last verified: 2026-08-15._

!!! warning "Version-gate anything read from `main`"
    The checkout is ahead of the newest tag. Every claim below was checked against a released tag
    (`git tag --contains`, `git log -1 --format=%ad <tag>`, or the docs' own `<Since version="…">`
    markers). Follow the same rule before writing a new claim into a chapter — see
    [[learning-path]] and the version-gating habit used for the Terraform checkout.

## Release timeline (tag dates from the checkout)

| Tag | Date | Why it matters |
|---|---|---|
| `v0.99.5` | 2026-03-26 | last pre-1.0 release |
| **`v1.0.0`** | **2026-03-30** | first release with a backwards-compatibility commitment |
| `v1.0.5` | 2026-05-18 | `azure-backend` experiment (native `azurerm` remote state); OpenTofu 1.12 support floor |
| `v1.0.8` | 2026-06-10 | `generate.hcl_fmt` attribute |
| **`v1.1.0`** | **2026-06-30** | **CAS on by default**; redesigned `catalog` TUI; stack dependencies; releases become immutable |
| `v1.1.1` | 2026-07-14 | `oci` module sources; `version-attribute` experiment for `tfr://` |
| `v1.1.2` | 2026-07-29 | `azure-backend` graduates to managing Azure Storage state; `otel-logs`, `profiling` experiments |
| `v1.1.3` | 2026-08-13 | `browse` TUI, `bounded-discovery`, `catalog-format`, `mutable-generate` dedup |

Releases are semver, and post-1.0 the compatibility surface is spelled out in
`docs/…/07-process/01-1-0-guarantees.mdx`: the CLI, HCL configurations, the run report, and `find`
output are covered; **experiments, `list`, `catalog`, raw stdout/stderr, performance, and the Go
library API are explicitly not**. That last exclusion is the practical one — `catalog` and `list`
changed shape repeatedly across 1.0.x, and the guarantees page is why that was allowed.

The changelog lives in-repo as one MDX file per change under `docs/src/data/changelog/<version>/`,
which is a convenient way to diff releases without leaving the checkout.

## Mental model: orchestrator, not provisioner

Terragrunt's own terminology page states the framing plainly: it "is designed to be an orchestrator
for OpenTofu/Terraform execution, rather than primarily provisioning infrastructure itself." It
wraps the binary, generates configuration, resolves cross-state data, and decides run order.

Vocabulary that the docs use precisely, and that a chapter should reuse rather than re-invent:

| Term | Meaning |
|---|---|
| **Unit** | one instance of infrastructure with its own state; detected by a `terragrunt.hcl` file in a directory |
| **Stack** | a collection of units; either a directory tree of units (implicit) or a `terragrunt.stack.hcl` blueprint (explicit) |
| **Component** | either a unit or a stack; `find` and `list` operate on components, `run` only on units |
| **Discovery** | filesystem scan from the cwd downward for `terragrunt.hcl` / `terragrunt.stack.hcl` |
| **Run queue** | the set of units a command will act on; `run --all` fills it with the whole stack |
| **Runner pool** | the units actually executing, dequeued subject to `--parallelism` and the DAG |
| **Dependency** | a `dependency` block — data passed from one unit to another, and an edge in the DAG |
| **Include** | overloaded on purpose-avoidance: config inclusion (`include` block) vs inclusion in the run queue |
| **Input** | an `inputs` entry, which becomes a `TF_VAR_`-prefixed environment variable before the run |
| **Feature** | a `feature` block plus `--feature` flag — a flag that changes *Terragrunt* behavior, not Terraform's |
| **Engine** | a plugin that controls exactly how a run is executed (where, with what binary) |

Two framings worth quoting in a chapter:

- **"Your current working directory is your blast radius."** In a Terragrunt project the filesystem
  maps to provisioned infrastructure, so `cd` changes what a command can touch.
- **DRY is no longer the point.** The docs say the focus "has shifted to offering more tooling for
  _orchestrating_ infrastructure," and warn that you "might miss the forest for the trees" by
  evaluating Terragrunt on DRY alone. Marketing still leads with DRY; the tool is now a scale
  orchestrator. Any chapter that introduces Terragrunt as "the DRY tool" is repeating a 2019 pitch.

!!! warning "One in-repo doc page is stale — do not copy it"
    `01-getting-started/04-terminology.md` still says stack support is "work underway to provide a
    top level artifact… via a `terragrunt.stack.hcl` file," and `07-process/03-releases.mdx` still
    opens with "as of 2026/01/27, Terragrunt is still pre-1.0." Both were true before 1.0.
    `terragrunt.stack.hcl` shipped and has its own reference section, and 1.0 released 2026-03-30.
    The reference pages are current; the narrative pages lag.

## CLI surface (v1.1.3)

Command tree, read from `internal/cli/commands/`:

| Command | Subcommands | What it does |
|---|---|---|
| `run` | — | run OpenTofu/Terraform; `--all` runs the whole queue, `--graph` runs a dependency subgraph |
| `exec` | — | run an arbitrary command in the unit's prepared working directory |
| `stack` | `generate`, `run`, `output`, `clean` | operate on `terragrunt.stack.hcl` blueprints |
| `backend` | `bootstrap`, `migrate`, `delete` | create/move/remove remote-state backend resources explicitly |
| `hcl` | `fmt`, `validate` | format and validate Terragrunt HCL |
| `dag` | `graph` | render the unit DAG |
| `find`, `list` | — | discovery, without running anything |
| `browse` | — | interactive TUI over the estate (new in 1.1.3, `browse-tui` experiment) |
| `catalog` | — | TUI to browse a module catalog and scaffold from it |
| `scaffold` | — | generate a unit from a module |
| `render` | — | render the fully-resolved configuration |
| `info` | `print`, `strict` | dump Terragrunt's own view of config / strict controls |

**Shortcut commands.** Only twelve OpenTofu/Terraform commands are forwarded bare
(`internal/cli/commands/shortcuts.go`): `init`, `validate`, `plan`, `apply`, `destroy`,
`force-unlock`, `import`, `output`, `refresh`, `show`, `state`, `test`. Everything else needs
`terragrunt run -- <cmd>`, e.g. `terragrunt run -- workspace ls`. Arguments are no longer passed
through by default — that is deliberate, from the CLI-redesign RFC ([terragrunt#3445](https://github.com/gruntwork-io/terragrunt/issues/3445)).

### The CLI redesign, and what it renamed

RFC [#3445](https://github.com/gruntwork-io/terragrunt/issues/3445) reshaped the CLI before 1.0. The
four changes that break old muscle memory and old CI scripts:

1. The `terragrunt-` prefix is gone from every flag (`--terragrunt-non-interactive` →
   `--non-interactive`).
2. Environment variables are `TG_`-prefixed, not `TERRAGRUNT_`.
3. `run-all` and `graph` are folded into `run` as `run --all` / `run --graph`.
4. The individual `*-all` commands — `plan-all`, `apply-all`, `destroy-all`, `output-all`,
   `validate-all`, `spin-up`, `tear-down` — are **removed outright**, not deprecated. They are no
   longer even available as strict controls.

Some renames are not mechanical prefix-stripping, which is the trap when migrating a pipeline:

| Old | New |
|---|---|
| `--terragrunt-debug` | `--inputs-debug` |
| `--terragrunt-exclude-dir` | `--queue-exclude-dir` |
| `--terragrunt-ignore-dependency-errors` | `--queue-ignore-errors` |
| `--terragrunt-ignore-dependency-order` | `--queue-ignore-dag-order` |
| `--terragrunt-iam-role` | `--iam-assume-role` |
| `--terragrunt-forward-tf-stdout` | `--tf-forward-stdout` |
| `--terragrunt-fail-on-state-bucket-creation` | removed; backend provisioning is now explicit via `backend bootstrap` |

That last row is the interesting one for a state chapter: Terragrunt used to create the state bucket
as a side effect of a run. Now bucket creation is its own command.

## HCL surface

Blocks (`04-reference/01-hcl/02-blocks.mdx`): `terraform`, `remote_state` (with nested `backend` and
`encryption`), `include`, `locals`, `dependency`, `dependencies`, `generate`, `catalog`, `engine`,
`feature`, `exclude`, `errors` (retry and ignore configuration), plus the stack-file blocks `unit`,
`stack`, and `autoinclude`.

Top-level attributes (`03-attributes.mdx`): `inputs`, `download_dir`, `prevent_destroy`, `iam_role`,
`iam_assume_role_duration`, `iam_assume_role_session_name`, `iam_web_identity_token`,
`terraform_binary`, `terraform_version_constraint`, `terragrunt_version_constraint`.

Notes worth carrying into a chapter:

- `inputs` are not merged into the module call; they become `TF_VAR_*` environment variables. That
  explains both the variable-precedence rules and why a typo in an input name fails silently.
- `dependency` (data, an edge in the DAG, supports `mock_outputs`) is a different block from
  `dependencies` (ordering only). Conflating them is the classic Terragrunt beginner error.
- `errors` gives per-unit retry and error-ignore policy in configuration, which is the piece
  Terraform itself has no answer for.
- `terraform.source` accepts `tfr://` registry URLs (with `tfr:///` shorthand for the public
  registry, and `TG_TF_DEFAULT_REGISTRY_HOST` to override the default host) and, since **1.1.1**,
  `oci://` sources behind the `oci` experiment. The `version` attribute — a constraint resolved
  against the registry instead of a pinned URL — is **1.1.1** behind the `version-attribute`
  experiment.
- `generate.hcl_fmt` (**1.0.8**) turns off formatting of generated files; `generate.mutable`
  (**1.1.2**, `mutable-generate` experiment) makes a generated file a real writable file instead of
  a read-only link into the CAS, which you need only when a hook patches the file in place.

## Stacks: implicit vs explicit

- **Implicit stack** = a directory tree of units. No extra file. This is what "a stack" meant before
  `terragrunt.stack.hcl` existed and is still the common case.
- **Explicit stack** = a `terragrunt.stack.hcl` blueprint that *generates* units at runtime, from
  `unit` blocks (one unit each, from a `source`, at a `path`, with `values`) and `stack` blocks
  (nested reusable multi-unit patterns).

```hcl
# terragrunt.stack.hcl
unit "vpc" {
  source = "git::git@github.com:acme/infrastructure-catalog.git//units/vpc?ref=v0.0.1"
  path   = "vpc"
  values = { vpc_name = "main", cidr = "10.0.0.0/16" }
}
```

`terragrunt stack generate` materializes that into `.terragrunt-stack/vpc/terragrunt.hcl` plus a
`terragrunt.values.hcl` holding the `values`. The generated tree is meant to be `.gitignore`d and
regenerated on demand. A directory may be a unit or a stack, never both — a `terragrunt.hcl` and a
`terragrunt.stack.hcl` in the same directory is an error, by design, so component type is never
ambiguous.

The design goal stated in the docs is that a stack file is "entirely a convenient shorthand for an
equivalent directory structure of units", so the two paradigms stay interchangeable.

`autoinclude` (the `stack-dependencies` line of work, iterated across 1.0.1 → 1.1.0) wires
dependencies between generated units without hand-writing `include` blocks in every generated unit.

## `--filter` — the query language that replaces the queue flags

`--filter` takes an expression language for targeting components, and supersedes the pile of
`--queue-include-dir` / `--queue-exclude-dir` flags:

```bash
terragrunt find --filter './prod/** | name=web'
```

Expression types: name, path glob, config attribute, negation (`!./legacy`), intersection (`|`),
union (repeat `--filter`), graph traversal (dependency/dependent walks), and Git diff expressions
("units affected by this change"). Supported on `find`, `list`, `run`, `hcl fmt`, `hcl validate`,
`stack run`, and `stack generate`.

The intended workflow is worth teaching directly: **dry-run the targeting with `find`, then reuse
the identical filter on `run`.** That is the safest answer to "apply only what my PR changed" and it
is why `find`/`list` exist as first-class commands.

## Content Addressable Store (CAS)

Introduced as the `cas` experiment and **on by default from 1.1.0**; `--no-cas` disables it per
command (`run`, `stack generate`, `stack run`, `catalog`), and `--cas-clone-depth` controls the
`git clone --depth` used for Git sources (default `1`, `-1` for full history).

Every getter resolves a source through a **cheap probe** — a low-cost remote call that yields a
cache key without downloading the payload — and skips the download entirely on a hit:

| Source | Cheap probe | Deduplication |
|---|---|---|
| Git | `git ls-remote` resolves the ref to a commit hash | native Git object hash, shared across repos |
| HTTP/HTTPS | `HEAD` reads `ETag` / `Last-Modified` | URL-scoped (the validator isn't a portable hash) |
| S3 | `HeadObject` reads checksum or `ETag` | content-addressed when a checksum exists |
| GCS | object metadata exposes MD5/CRC32C | content-addressed |
| Mercurial | `hg identify` | content-addressed |
| OpenTofu/Terraform registry | protocol resolves the archive URL | content-addressed on the immutable archive |
| OCI | `?digest=` is the key; a tag resolves to a manifest digest | content-addressed on the digest |
| SMB, local paths | none — always download/copy | content-addressed on the fetched tree |

The back half is identical for all of them: hash files into the store as blobs, record a tree, and
**hard link** into the target directory. Identical files occupy disk once regardless of how many
units use them. This is the mechanism behind the `generate.mutable` attribute above — by default a
generated file *is* a read-only link into the store.

For a chapter, this is the concrete answer to "why is Terragrunt fast on a large estate": it is not
just parallelism, it is deduplicated source fetching with a probe that avoids the fetch.

## Version compatibility with OpenTofu/Terraform

Terragrunt is genuinely dual-tool, and **defaults to OpenTofu when both are on `PATH`**
(`terraform_binary` overrides). Support floors from `docs/src/data/compatibility/compatibility.json`:

| OpenTofu | Minimum Terragrunt |
|---|---|
| 1.12.x | **1.0.5** |
| 1.11.x | 0.95.0 |
| 1.10.x | 0.82.0 |
| 1.9.x | 0.72.0 |
| 1.8.x | 0.66.0 |
| 1.6.x | 0.52.0 |

The same file carries Terraform rows. Two caveats stated in the docs: the table lists only
CI-tested combinations and real compatibility is looser, and while BSL Terraform ≥ 1.6 is listed,
**support for Terraform-specific BSL features is explicitly not guaranteed** even for listed
versions. `terraform_version_constraint` relaxes the check for untested versions. The data is also
served as JSON at `https://docs.terragrunt.com/api/v1/compatibility/{opentofu,terraform}`.

## Experiments and strict controls — the two-sided release valve

- **Experiments** (`--experiment <name>`, `TG_EXPERIMENT`) opt *in* to unfinished features. Live
  examples across 1.0.x–1.1.x: `cas` (now graduated), `oci`, `version-attribute`,
  `mutable-generate`, `stack-dependencies`, `catalog-redesign`, `azure-backend`, `otel-logs`,
  `profiling`, `browse-tui`, `bounded-discovery`, `block-iteration`,
  `optional-dependency-outputs`. Completed experiments evaluate as permanently enabled (1.0.8), so
  leaving a stale `--experiment` flag in CI is harmless rather than an error.
- **Strict controls** (`--strict-control <name>`) opt *in* to breaking changes early, before a
  deprecation becomes the default. Categories: `deprecated-commands`, `deprecated-flags`,
  `deprecated-env-vars`. `terragrunt info strict` lists them.

Together these are how a post-1.0 tool ships breaking work without breaking minor releases — a
pattern worth contrasting with Terraform's own approach in the book.

## What Terragrunt still does not do

Unchanged from [[workspaces]], and still the honest boundary: no user model or RBAC, no run history
or audit UI, no remote execution (runs happen wherever you invoke them), no policy enforcement or
cost estimation, no managed drift detection. Terragrunt covers the **isolation** half of what HCP
Terraform workspaces offer — per-unit state, per-unit `inputs`, per-unit `iam_role` — and Atlantis
covers the PR-driven-runs half. Gruntwork sells the platform half commercially (the
`09-terragrunt-scale` docs section covers Pipelines, drift detection, and Patcher), which is worth
naming so the open-source/commercial line is clear.

## Sources

- Local checkout: `C:\opt\learn\terraform\repos\terragrunt` @ `54c43a44c`, tags to `v1.1.3`
- In-repo docs: `docs/src/content/docs/` (renders as <https://docs.terragrunt.com>)
- In-repo changelog data: `docs/src/data/changelog/<version>/`
- Compatibility data: `docs/src/data/compatibility/compatibility.json`
- CLI command tree: `internal/cli/commands/`; shortcut list: `internal/cli/commands/shortcuts.go`
