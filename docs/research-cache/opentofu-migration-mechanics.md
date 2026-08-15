# OpenTofu migration mechanics (source-derived)

How OpenTofu actually absorbs a Terraform project — what it rewrites, what it refuses to rewrite,
and what it silently stops guaranteeing. The migration guide describes the *procedure*; this is the
*mechanism*, read from the code, because two of the three behaviours below are invisible until they
surprise you.

_Source: `C:\opt\learn\terraform\repos\opentofu`, detached at `d529119038` ("Bump version to
v1.12.4", 2026-07-13); `v1.12.5` is the newest tag in the checkout. Every claim gated with
`git tag --contains`. Last verified: 2026-08-15._

## 1. State: provider addresses are translated in memory, not rewritten on disk

A Terraform state file records each resource's provider by fully-qualified address —
`registry.terraform.io/hashicorp/aws`. OpenTofu resolves providers from
`registry.opentofu.org`, so those addresses have to be reconciled. `internal/tofumigrate` does it,
and the package comment states the scope precisely:

> MigrateStateProviderAddresses can be used to update the **in-memory view** of the state to use
> registry.opentofu.org provider addresses. This only applies for providers which are *not*
> explicitly referenced in the configuration in full form.

Two consequences that matter in practice:

- **The stored state is not edited by the migration itself.** The translation is applied to a
  `DeepCopy` each time the state is loaded; the file on the backend only changes when a run writes
  a new snapshot for its own reasons.
- **An explicit `source` pin defeats it, by design.** With `random = {}` in `required_providers`,
  the state entry is rewritten to `registry.opentofu.org/hashicorp/random`. With
  `source = "registry.terraform.io/hashicorp/random"` written out in full, OpenTofu **keeps the
  terraform.io address** — the configuration is taken as a deliberate statement about which registry
  to use. That is the lever for staying on HashiCorp-built providers while running OpenTofu.

The translation runs at three call sites, so it covers the ordinary workflow: `tofu init`
(`internal/command/init.go:318`, before providers are fetched), every local run
(`internal/backend/local/backend_local.go:225`, on the input state for plan and apply), and
`tofu state show` (`internal/command/state_show.go:168`).

!!! warning "There is an off switch, and it is documented nowhere"
    ```bash
    OPENTOFU_STATEFILE_PROVIDER_ADDRESS_TRANSLATION=0
    ```
    Set to the literal string `0`, this returns the state untouched. Grepping the whole repository —
    `docs/`, `website/`, `rfc/`, every `.md` — returns **no mention of it**. It has been there since
    the mechanism landed in commit `9c789368dc` (2023-10-27, PR #773), first tagged **v1.6.0**, so it
    is available in every OpenTofu release. Worth knowing as a diagnostic: if a migration produces
    provider-address confusion, this isolates whether the translation is involved.

## 2. Lock file: entries are mirrored, and the hashes are dropped

`.terraform.lock.hcl` keys its entries by the same fully-qualified provider address, so a lock file
written by Terraform names `registry.terraform.io/hashicorp/…` providers. `Locks.UpgradeFromPredecessorProject`
(`internal/depsfile/locks.go:321`) mirrors those into OpenTofu-registry entries on first use. Three
rules, all stated in the source:

- **Only `registry.terraform.io` + the `hashicorp` namespace is treated as equivalent.** Anything
  else is left alone: *"We cannot safely make any assumption of equivalence about providers in any
  other registry or namespace."* So a third-party or self-hosted provider's lock entry is not
  touched.
- **The new entries carry the same version selection and constraints, and no hashes at all.** The
  comment is explicit that this means the lock can "be used to select the same version number but
  not to guarantee that the provider package matches what was previously installed."
- **Old entries are kept** and left for the provider installer to discard later, because the
  installer can tell whether anything in configuration or state still refers to them.

The user sees a warning, and its final sentence is the fact worth carrying into a chapter
(`internal/command/meta_dependencies.go:113`):

> **Dependency lock file entries automatically updated** — OpenTofu automatically rewrote some
> entries in your dependency lock file: `registry.terraform.io/hashicorp/aws` =>
> `registry.opentofu.org/hashicorp/aws` … The version selections were preserved, but the hashes were
> not because **the OpenTofu project's provider releases are not byte-for-byte identical**.

That answers the question people actually have about the fork's providers: same source, **different
builds**. It also means the migration has a window where provider checksums are not being verified
against a previously-recorded value — the next `init` records fresh hashes from the OpenTofu
registry, and from then on the lock is meaningful again. Anyone treating the lock file as a
supply-chain control (**I4**, **A6**) should re-record and review hashes deliberately rather than
assume continuity across the switch.

Version-gated: commit `99a0c6eb6f` (2025-05-19), first tagged **v1.10.0**. So a migration done on
1.6–1.9 had no lock-file mirroring at all.

## 3. `.tofu` files shadow their `.tf` twins — they are not merged

Existing notes describe the 1.8 `.tofu` extension as "parsed alongside `.tf`", which is true of the
directory as a whole and misleading for a same-named pair. The rule in
`internal/configs/parser_config_dir.go:289-299`:

> If the `.tf` file has a parallel `.tofu` file in the directory, we'll ignore the `.tf` file and
> only use the `.tofu` file

So `main.tf` plus `main.tofu` does **not** load both — `main.tf` is dropped entirely, and the
`.tofu` file must therefore be a complete replacement, not a patch. A differently-named file
(`extra.tofu` beside `main.tf`) loads normally. The shadowing is per base name and applies to every
pair the parser recognises:

| Terraform extension | OpenTofu twin |
|---|---|
| `.tf` | `.tofu` |
| `.tf.json` | `.tofu.json` |
| `.tftest.hcl` | `.tofutest.hcl` |
| `.tftest.json` | `.tofutest.json` |

The two test extensions are worth noting on their own — the notes had not recorded that OpenTofu's
test framework has `.tofutest.hcl` / `.tofutest.json` counterparts at all.

## What this adds up to for a migration

The migration is genuinely designed to be low-friction, and the three mechanisms above are why a
`terraform init` project keeps working under `tofu init`. But each one has a quiet edge:

1. State addresses translate **only** when the configuration has not pinned a full registry source.
2. Lock hashes **do not** carry over, and the tool says so once, in a warning that scrolls past.
3. A `.tofu` file **replaces** its `.tf` twin, so a partial override silently loses everything else
   that was in the original file.

None of these appears in the migration guide's step list. All three are checkable in a lab: migrate
a project, read the warning, then `grep registry.opentofu.org .terraform.lock.hcl` and
`tofu state show` a resource to see the translated address.

## Sources

- Local checkout `C:\opt\learn\terraform\repos\opentofu` @ `d529119038`, tags to `v1.12.5`
- `internal/tofumigrate/tofumigrate.go`; call sites in `internal/command/init.go`,
  `internal/backend/local/backend_local.go`, `internal/command/state_show.go`
- `internal/depsfile/locks.go` (`UpgradeFromPredecessorProject`), warning text in
  `internal/command/meta_dependencies.go`
- `internal/configs/parser_config_dir.go` (extension table and shadowing rule)
- Version gating: `git tag --contains` on `9c789368dc` (v1.6.0) and `99a0c6eb6f` (v1.10.0)
