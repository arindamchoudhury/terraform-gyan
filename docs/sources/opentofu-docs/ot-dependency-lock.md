# Dependency Lock File (OpenTofu)

> **Source:** [opentofu.org/docs/language/files/dependency-lock](https://opentofu.org/docs/language/files/dependency-lock/)
> **Added:** 2026-07-10
> **Source updated:** undated language reference; captured 2026-07-10 against OpenTofu 1.12.x (latest)
> **Tags:** opentofu, lock-file, providers, checksums, hashing-schemes, h1, zh, providers-lock, divergence

> **Type:** documentation

*Docs › OpenTofu Language › Files › Dependency Lock File · 1.12.x*

OpenTofu forked this page from Terraform 1.5.x, and most of it still reads identically. [[tf-dependency-lock]] covers the shared ground: lock file location, `-upgrade` behavior, trust-on-first-use, the four kinds of lock file change, and what `zh:` and `h1:` each hash. This note records only where OpenTofu has since moved, which is the checksum pre-population behavior added in **1.12**.

## The shared definition of `h1:`

Both projects define hash scheme 1 the same way, and the wording matters for the question people usually ask about it:

> `h1:` … is one computed from the *contents* of the provider distribution package, rather than of the `.zip` archive it's contained within.

Contents, not archive. A `darwin_arm64` package contains a Mach-O binary and a `linux_amd64` package contains an ELF binary. The contents differ, so the `h1:` values differ. **`h1:` is per-platform in OpenTofu exactly as it is in Terraform.** There is no fork divergence in the scheme itself.

!!! warning "A common misreading"
    "OpenTofu's `h1:` doesn't change when you `init` on another platform" is true as an observation and false as an explanation. The lock file doesn't change because OpenTofu **already wrote every platform's `h1:` on the first `init`**, not because one `h1:` covers every platform. See the next section.

## What changed in 1.12: full cross-platform checksums at `init`

Pre-1.12 OpenTofu behaved like Terraform still does. The registry protocol supplied only `zh:` hashes, so `init` recorded the full `zh:` set plus a single `h1:` for the platform it ran on. Further `h1:` lines accrued one platform at a time, opportunistically, as colleagues ran `init` on their own machines.

From 1.12 the **OpenTofu Registry serves both `zh:` and `h1:` hashes for every platform**, and `tofu init` pre-populates all of them on first install:

> When installing a particular provider for the first time (where there is no existing `provider` block for it), OpenTofu will pre-populate the `hashes` value with all checksums reported by the registry, which usually covers all of the available packages for that provider version across all supported platforms. The OpenTofu Registry (as of OpenTofu v1.12) provides a comprehensive set of `zh` (Zip Hash) and `h1` (Hash Scheme 1) hashes.

Consequences:

- A macOS developer's committed lock file already carries the `h1:` that Linux CI needs. No verification failure, no lock file churn in the pull request.
- A global plugin cache directory and a local mirror both verify against the recorded hashes immediately, with no separate priming step.
- `tofu providers lock -platform=…` is no longer part of the routine setup. Per the 1.12 blog it is "now needed only in the situation for which it was originally intended."

## The condition that gates it

The pre-population depends on `init` reaching the origin registry directly. Verbatim from the 1.12 release blog:

> As long as your CLI configuration allows `tofu init` to install providers directly from OpenTofu Registry (which is the default), it will record the full set of checksums automatically.

Point `provider_installation` at a filesystem or network mirror and the old constraint returns, in the same words the Terraform docs use:

> If you install a provider for the first time using an alternative installation method, such as a filesystem or network mirror, OpenTofu will not be able to verify the checksums for any platform other than the one where you ran `tofu init`, and so it will not record the checksums for other platforms and so the configuration will not be usable on any other platform.

That is the case `tofu providers lock` still exists for:

```shell
tofu providers lock \
  -platform=linux_arm64 \
  -platform=linux_amd64 \
  -platform=darwin_amd64 \
  -platform=windows_amd64
```

It downloads and verifies the official packages for all required providers across all four platforms, recording both `zh:` and `h1:` for each.

!!! note "Upgrade artifact"
    The first `tofu init` after upgrading to 1.12 appends the missing `h1:` lines to lock files created by earlier versions. Expect a one-time diff that touches `hashes` only, leaving `version` and `constraints` alone. The release notes call this out so it isn't mistaken for a supply-chain event.

## `OPENTOFU_ENFORCE_GPG_VALIDATION`

A second, smaller divergence on the same page. Both tools trust every checksum a registry reports as long as one of them matches the installed package. OpenTofu lets you narrow that:

> If you wish to restrict this behavior to only providers that are signed with a cryptographic signature, you can set `OPENTOFU_ENFORCE_GPG_VALIDATION` to `true`.

Terraform has no equivalent environment variable. Note also that OpenTofu's signature line reads `(signed, key ID 0C0AF313E5FD9F80)`, without Terraform's "by a HashiCorp partner" phrasing, because the OpenTofu Registry brokers releases rather than operating a partner program.

---
Related: [[tf-dependency-lock]] — the Terraform page this forked from; read it first, since everything not listed above is unchanged. · [[opentofu-feature-history]] — places the 1.12 checksum work alongside the other divergences. · [[provider-requirements]] — the constraints this file resolves.
