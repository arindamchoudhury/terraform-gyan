# CI / code-quality tooling — verified versions and OpenTofu support

The toolchain **TID Ch7** builds a makefile around. The book pins versions inline in its listings;
every one of them has moved. This file is the currency layer for that chapter, plus the answer to
the question the book never asks: **do these tools understand OpenTofu?**

_Last verified: **2026-08-15**, each against the project's own GitHub releases API._

## Current releases

| Tool | Book shows | Current | Released | Note |
|---|---|---|---|---|
| **TFLint** | (unpinned) | **v0.64.0** | 2026-07-17 | the linter binary itself |
| `tflint-ruleset-aws` | `0.29.0` / `0.30.0` | **v0.48.0** | 2026-06-29 | book's two listings disagree with each other |
| `tflint-ruleset-opa` | `0.6.0` | **v0.11.0** | 2026-07-20 | 0.11.0 added remote policy bundles (`bundle_url`) and `terraform.required_providers` |
| **Checkov** | (unpinned) | **3.3.9** | 2026-08-02 | no `v` prefix on its tags |
| **Trivy** | (unpinned) | **v0.74.0** | 2026-08-14 | absorbed tfsec; the `aquasecurity/tfsec` repo now describes itself as "Tfsec is now part of Trivy" |
| **terraform-docs** | (unpinned) | **v0.24.0** | 2026-05-10 | |
| **tenv** | (unpinned) | **v4.15.1** | 2026-07-24 | book describes tenv at its 1.x/2.x shape |
| `antonbabenko/pre-commit-terraform` | `rev: v1.88.0` | **v1.108.1** | 2026-07-24 | |
| `tofuutils/pre-commit-opentofu` | not mentioned | **v2.4.2** | 2026-06-12 | OpenTofu-named fork of the above |

## GitHub Actions in the book's workflows — every one is a major behind

| Action | Book shows | Current |
|---|---|---|
| `actions/checkout` | `@v4` | **v7.0.1** (2026-07-20) |
| `terraform-linters/setup-tflint` | `@v4` | **v6.3.0** (2026-06-30) |
| `hashicorp/setup-terraform` | `@v3` | **v4.0.1** (2026-05-12) |
| `opentofu/setup-opentofu` | `@v1` | **v2.0.2** (2026-06-29) |

The book's matrix tests engine versions `1.6`/`1.7`/`1.8` with Terraform `1.10` marked
`experimental: true`. Current stable is Terraform **1.15.8** and OpenTofu **1.12.5**
(see [[version-facts]]), so 1.10 is four minors old rather than an alpha.

## The `.tofu` blind spot

OpenTofu **1.8.0** added the `.tofu` / `.tofu.json` file extensions, and `.tofu` **takes precedence
over** a same-named `.tf` in the same directory. Verified from source rather than docs: the parser
change is commit `ab289fc0` ("OpenTofu Specific Code Override: Add support to .tofu files", #1738,
2024-06-24), and `git tag --contains` puts its earliest stable tag at **v1.8.0**. The documentation
page landed later, in 1.10 — which is why secondary sources date the feature wrong.

Third-party tooling has not followed:

| Tool | `.tofu` support | Evidence |
|---|---|---|
| **TFLint** | **No, and declined** | [#2609](https://github.com/terraform-linters/tflint/issues/2609) closed `not_planned` on 2026-07-23. TFLint loads only `*.tf` / `*.tf.json` |
| **Checkov** | **Not yet** | [PR #7401](https://github.com/bridgecrewio/checkov/pull/7401) adding `.tofu`/`.tofu.json` discovery is still **open** |
| **terraform-docs** | **No** | [#811](https://github.com/terraform-docs/terraform-docs/issues/811) open (reopened); the implementing [PR #833](https://github.com/terraform-docs/terraform-docs/pull/833) closed unmerged |

The failure mode is the dangerous kind: **silence**. A module written entirely in `.tofu` files makes
TFLint report zero issues and exit `0` without having parsed anything. In a mixed module it is worse
— the scanner lints the `.tf` file that OpenTofu itself is ignoring in favour of the `.tofu` override,
so the tool reports on code that never runs.

terraform-docs additionally breaks on OpenTofu's provider `for_each`
([#895](https://github.com/terraform-docs/terraform-docs/issues/895), open).

**Practical rule:** if you use OpenTofu, keep configuration in `.tf` files. The `.tofu` extension buys
divergence from Terraform at the cost of your entire quality toolchain.

## Testing frameworks

- Terraform's native test framework (`.tftest.hcl`, `terraform test`) shipped in **Terraform 1.6.0** —
  the book states this correctly.
- **OpenTofu has `tofu test` too**, since its first release: `internal/command/test.go` is present at
  tag **v1.6.0** in `repos/opentofu`. So the book's "OpenTofu may lag behind in features" is a claim
  about later additions, not about the framework existing. Detail belongs to Ch9 / [[terraform-testing]].

## Sources

- GitHub releases API, one call per repo, 2026-08-15
- Local checkout `C:\opt\learn\terraform\repos\opentofu` @ `d529119` for the `.tofu` tag archaeology
- `aquasecurity/tfsec` repository metadata (description: "Tfsec is now part of Trivy")
