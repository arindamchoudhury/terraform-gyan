# Dependency Lock File

> **Source:** [developer.hashicorp.com/terraform/language/files/dependency-lock](https://developer.hashicorp.com/terraform/language/files/dependency-lock)
> **Added:** 2026-07-10
> **Source updated:** undated language reference; captured 2026-07-10 against v1.15.x (latest)
> **Tags:** lock-file, providers, checksums, trust-on-first-use, hashing-schemes, providers-lock, init
> **Type:** documentation

*Developer › Terraform › Configuration Language › Files › Dependency Lock File · v1.15.x*

!!! info "Hands-on"
    Try the [Lock and Upgrade Provider Versions](https://developer.hashicorp.com/terraform/tutorials/configuration-language/provider-versioning) tutorial.

!!! note "Feature of Terraform 0.14 and later"
    Prior versions did not track dependency selections at all. This page does not apply to them.

The canonical page for `.terraform.lock.hcl`. [[provider-requirements]] summarizes the lock file in one paragraph and the `-upgrade` decision in a callout; [[tf-aws-create]] shows one being written by a real `init`. This note covers what neither does: **what changes to the file mean**, the **two hashing schemes**, and **trust-on-first-use** checksum verification.

## What the lock file tracks

A configuration has two kinds of external dependency: **providers** and **modules**. Both are published and versioned independently of Terraform and of the configuration.

Version constraints say which versions are *potentially compatible*. After Terraform picks a specific version, it records that decision in the lock file so it can make the same decision again by default.

> ⚠️ **Only providers are locked.** The lock file does **not** record module version selections. Terraform always selects the newest available module version matching the constraint. To pin a module, use an **exact version constraint**.

## Lock file location

- Belongs to the **configuration as a whole**, not to each module. Terraform creates it in — and expects to find it in — the **current working directory**, which is the root module's directory.
- Always named **`.terraform.lock.hcl`**. The name signals it locks items Terraform caches in `.terraform/`.
- Created or updated on **every `terraform init`**.
- **Commit it to version control** so dependency changes go through code review like configuration changes.
- Uses the same low-level syntax as the Terraform language, but is **not** a Terraform configuration file — hence the `.hcl` suffix instead of `.tf`.

## Dependency installation behavior

`terraform init` considers **both** the configuration's version constraints **and** the lock file's recorded selections.

| Situation | What `init` does |
|---|---|
| No recorded selection for a provider | Selects the **newest** version matching the constraint, records it |
| Selection already recorded | Re-selects **that exact version**, even if newer exists |
| `terraform init -upgrade` | Disregards existing selections, re-selects newest matching the constraint |

When `init` changes the file it says so:

```
Terraform has made some changes to the provider dependency selections recorded
in the .terraform.lock.hcl file. Review those changes and commit them to your
version control system if they represent changes you intended to make.
```

See the `-upgrade` decision table in [[provider-requirements]] — a plain `init` is *forced* to re-select when the locked version no longer satisfies the constraint.

### Checksum verification

Every installed package must match **at least one** checksum previously recorded in the lock file. Otherwise:

```
Error: Failed to install provider

Error while installing hashicorp/azurerm v2.1.0: the current package for
registry.terraform.io/hashicorp/azurerm 2.1.0 doesn't match any of the
checksums previously recorded in the dependency lock file.
```

This is a **trust on first use** model. You verify a provider however you like (or however regulation requires) the first time you add it. From then on Terraform errors if a future `init` sees a non-matching package for that same version.

Two special considerations:

1. **Signed checksums from an origin registry.** If the registry provides cryptographically signed checksums, Terraform treats **all** signed checksums as valid as long as **one** matches. The lock file then includes checksums for your platform *and* every other available platform. `init` prints the signing key's fingerprint, e.g. `(signed by a HashiCorp partner, key ID DC9FC6B1FCE47986)`. Confirm you trust that key holder before committing the lock file.

2. **First install from a mirror.** Installing from a filesystem or network mirror means Terraform **cannot verify checksums for any platform other than the one you ran `init` on**. It records only that platform's checksums, so **the configuration becomes unusable on any other platform**. Pre-populate with `terraform providers lock` to avoid this.

## Understanding lock file changes

Terraform maintains this file automatically, so version control will show it changing. Four situations.

### 1. Dependency on a new provider

Adding a provider requirement (directly, or via an external module that has one) makes `init` select the newest matching version and record a new `provider` block:

```diff
+provider "registry.terraform.io/hashicorp/azurerm" {
+  version     = "2.30.0"
+  constraints = "~> 2.12"
+  hashes = [
+    "h1:FJwsuowaG5CIdZ0WQyFZH9r6kIJeRKts9+GcRsTz1+Y=",
+    "h1:c/ntSXrDYM1mUir2KufijYebPcwKqS9CRGd3duDSGfY=",
+    "h1:yre4Ph76g9H84MbuhZ2z5MuldjSA4FsrX6538O7PCcY=",
+    "zh:04f0a50bb2ba92f3bea6f0a9e549ace5a4c13ef0cbb6975494cac0ef7d4acb43",
+    "zh:2082e12548ebcdd6fd73580e83f626ed4ed13f8cdfd51205d8696ffe54f30734",
+    ...
+  ]
+}
```

Three pieces of information:

- **`version`** — the exact version selected, given the constraints.
- **`constraints`** — every constraint Terraform considered when selecting. **Terraform does not use this to make installation decisions.** It's recorded only to explain to a human reader how the earlier decision was made.
- **`hashes`** — checksums considered valid for that version's packages across different platforms.

### 2. New version of an existing provider

`terraform init -upgrade` may select a newer version and rewrite the existing `provider` block. `version` changes; `constraints` changes too if the configured constraint changed. Because each version has its own distribution packages, **all** the `hashes` values are typically replaced.

### 3. New provider package checksums

Sometimes only new hashes appear, nothing else changes:

```diff
   version     = "2.1.0"
   constraints = "~> 2.1.0"
   hashes = [
+    "h1:1xvaS5D8B8t6J6XmXxX8spo97tAzjhacjedFX1B47Fk=",
     "h1:EOJImaEaVThWasdqnJjfYc6/P8N/MRAq1J7avx5ZbV4=",
     "zh:0015b491cf9151235e57e35ea6b89381098e61bd923f56dffc86026d58748880",
```

This is Terraform gradually migrating between **hashing schemes**. The prefix names the scheme.

| Prefix | Name | What it hashes | Where it comes from |
|---|---|---|---|
| `zh:` | "zip hash" — legacy | SHA256 of each official **`.zip` package** indexed in the origin registry | Part of the provider **registry protocol**; used for providers installed directly from an origin registry |
| `h1:` | "hash scheme 1" — current preferred | SHA256 computed from the **contents** of the distribution package | Computable for an official `.zip`, an unpacked directory, or a recompressed `.zip` with the same files |

`zh:` is effective for verifying official release packages from a registry but **unsuitable for other installation methods**, such as filesystem mirrors using the unpacked directory layout. `h1:` works for all three because it hashes contents, not the archive.

**How the migration happens.** Terraform adds a new hash to an existing provider **only if that hash is calculated from a package that also matches one of the existing hashes**. In the example above, Terraform installed the provider for a *different platform* than the one that produced the original `h1:`, matched it against a recorded `zh:`, and only then recorded the corresponding `h1:`.

**First install pre-population.** On first install (no existing `provider` block), Terraform pre-populates `hashes` with any checksums covered by the provider developer's cryptographic signature — usually all packages, all platforms. But because the registry protocol still uses `zh:`, that initial set is mostly `zh:`, upgraded opportunistically to `h1:` as you install on new platforms.

**To stop the drip of new `h1:` hashes** — or when installing from a mirror that can't supply signed checksums — pre-populate for chosen platforms:

```shell
terraform providers lock \
  -platform=linux_arm64 \
  -platform=linux_amd64 \
  -platform=darwin_amd64 \
  -platform=windows_amd64
```

This downloads and verifies the official packages for every required provider across all four platforms, and records **both `zh:` and `h1:`** checksums for each. Future `init` calls can then verify that mirror packages match the official origin-registry packages. See the [`terraform providers lock`](https://developer.hashicorp.com/terraform/cli/commands/providers/lock) command docs.

!!! info "OpenTofu — cross-platform hashes by default"
    OpenTofu **1.12** records the full cross-platform `zh:`+`h1:` set automatically at `tofu init`, because its registry now serves `h1:` hashes for every platform. The `providers lock -platform=…` dance becomes unnecessary. The gate is that `init` must reach the origin registry directly, which is the default. Override `provider_installation` to a mirror and Terraform's behavior above returns unchanged. `h1:` itself is still per-platform in both tools. (See [[ot-dependency-lock]] and [[opentofu-feature-history]].)

### 4. Providers that are no longer required

Terraform decides whether a provider is still needed from **two sources of truth: the configuration and the state.** Remove the last dependency from **both**, and `init` deletes the provider's lock file entry.

```diff
-provider "registry.terraform.io/hashicorp/azurerm" {
-  version     = "2.30.0"
-  constraints = "~> 2.12"
-  hashes = [ ... ]
-}
```

> ⚠️ Re-adding a requirement for that provider later means Terraform treats it as **entirely new**. It will not necessarily select the same version, and it cannot verify that the checksums are unchanged.

!!! note "Stale entries from Terraform ≤ v1.0"
    In v1.0 and earlier, `init` did **not** remove now-unneeded providers from the lock file — it just ignored them. If you dropped a provider on an old CLI and then upgraded to v1.1+, you may hit `missing or corrupted provider plugins` from those stale entries. Run `terraform init` on the new version to tidy them, then retry.

---
Related: [[provider-requirements]] — declares the constraints this file resolves; its `-upgrade` callout is the operational companion to "Dependency installation behavior" here. · [[tf-providers]] — the providers hub that points at this page. · [[tf-aws-create]] — a real `init` writing a real lock file. · [[tf-cli-commands]] — where `terraform providers lock` sits in the command surface. · [[ot-dependency-lock]] — the forked OpenTofu page; identical except for 1.12's cross-platform checksum pre-population and the `OPENTOFU_ENFORCE_GPG_VALIDATION` knob. · [[opentofu-feature-history]] — OpenTofu 1.12 removes the manual cross-platform locking step.
