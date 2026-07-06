# Provider Requirements

> **Source:** [developer.hashicorp.com/terraform/language/providers/requirements](https://developer.hashicorp.com/terraform/language/providers/requirements)
> **Added:** 2026-07-05
> **Source updated:** undated language reference; captured 2026-07-05
> **Tags:** providers, required_providers, source-address, version-constraints, lock-file, registry
> **Type:** documentation

*Developer › Terraform › Configuration Language › Configure providers › Provider requirements · v1.15.x*

!!! info "Hands-on"
    Try the [Lock and Upgrade Provider Versions](https://developer.hashicorp.com/terraform/tutorials/configuration-language/provider-versioning) tutorial.

Note layout mirrors the source page's own section order. The `provider` block (auth/config) and `alias`/multi-instance detail live on the separate [Provider Configuration](https://developer.hashicorp.com/terraform/language/providers/configuration) page (learning-path **I8**).

> 📌 **Version note:** Captured against Terraform CLI **1.15.7** (2026-07-05, see [[version-facts]]). `required_providers` semantics are stable back to v0.13; the v0.12 backward-compat rules are the last section.

## Overview

Terraform relies on plugins called providers to interact with remote systems. A configuration must **declare which providers it requires** so Terraform can install and use them. This page is about that declaration.

Setup is three steps: (1) declare in `required_providers`, (2) add a top-level `provider` block for auth/config, (3) run `terraform init` to install and lock.

## Require providers

The `required_providers` block goes inside the top-level `terraform` block. Each entry maps a **local name** (the key) to an object with `source` and `version`:

```hcl
terraform {
  required_providers {
    mycloud = {
      source  = "mycorp/mycloud"
      version = "~> 1.0"
    }
  }
}
```

- **Local name** (key) — module-local identifier; unique within the module; used everywhere else (resource-type prefixes, `provider` blocks).
- **`source`** — the provider's global address (where to download it).
- **`version`** — version constraint; optional but recommended.

## Names and Addresses

### Local Names

Users may pick *any* local name, but nearly every provider has a **preferred local name** it uses as the prefix for all its resource types — so `aws_instance` implies the `aws` local name. Keep local name = type unless you must disambiguate.

### Source Addresses

Format:

```
[<HOSTNAME>/]<NAMESPACE>/<TYPE>
```

- **Hostname** (optional) — registry host; defaults to `registry.terraform.io` when omitted.
- **Namespace** — the publisher/org in the registry (e.g. `hashicorp`).
- **Type** — short name of the target platform; usually the provider's preferred local name.

All three explicit = the **fully-qualified address**, e.g. `registry.terraform.io/hashicorp/http`. Common short forms: `hashicorp/aws`, `mycorp/mycloud`.

### Handling Local Name Conflicts

Two providers sharing a type name (both `http`, different namespaces) need distinct local names — use compound names like `hashicorp-http` and `mycorp-http`.

## Version Constraints

`version` uses the standard constraint operators:

| Constraint | Meaning |
|---|---|
| `>= 1.0` | at least 1.0 |
| `~> 1.0.4` | pessimistic: allows 1.0.5, 1.0.6 … but **not** 1.1.0 |
| `~> 1.0` | allows 1.x but not 2.0 |
| (omitted) | any version — **not recommended** |

### Best Practices for Provider Versions

- A **root module** (the dir where you run `terraform apply`) should also pin a **maximum** version — pin the range you tested.
- A **reusable/child module** should specify only a **minimum**, so it doesn't force every caller to upgrade in lockstep.
- Constraints from the root and all child modules are **intersected** — the selected version must satisfy every module that requires the provider.

**Lock file.** `terraform init` resolves versions against the constraints, then records the exact selections + checksums in `.terraform.lock.hcl`. Running locally, plan/apply use the versions **in the lock file**, not the newest allowed by the constraint. HCP Terraform / Terraform Enterprise install providers on **every run** using the locked versions when the lock file exists. (Cross-platform checksum detail — see [[tf-aws-create]] and the B3 lock-file callouts.)

!!! note "Do you need `-upgrade`?"
    `init` picks a version satisfying **both** the constraint **and** the lock — so whether a plain `terraform init` upgrades depends on which one binds.

    **Locked version still satisfies the new constraint** → plain `init` keeps the locked one; run **`terraform init -upgrade`** to move up.

    - Locked `5.10.0`, constraint `~> 5.0`, `5.20.0` released, you want it → `terraform init -upgrade`.
    - Constraint unchanged, just chasing the newest allowed patch/minor → `-upgrade`.

    **Locked version now violates the new constraint** → plain `init` is *forced* to re-select and rewrites the lock on its own — no `-upgrade`.

    - Locked `5.10.0`, you bump `required_providers` to `~> 6.0` → `5.10.0` is illegal → `init` picks `6.x`.

    `-upgrade` = "ignore the lock, re-resolve **every** provider to newest allowed, rewrite `.terraform.lock.hcl`." Reach for it whenever the locked version is still *valid but stale*.

## Built-in Providers

Terraform ships one built-in provider, address `terraform.io/builtin/terraform`. It backs the **`terraform_remote_state`** data source. No `required_providers` entry needed to use it, though it can surface in error messages.

> ⚠️ The old `hashicorp/terraform` provider is **incompatible** with modern Terraform — do not use it. Different thing from the built-in `terraform.io/builtin/terraform`.

## In-house Providers

Distribute proprietary providers two ways:

1. **Private registry** — implement the provider registry protocol; reference via a custom hostname.
2. **Filesystem / network mirror** — drop plugin binaries in an implied local mirror directory.

Placeholder-hostname example:

```hcl
terraform {
  required_providers {
    mycloud = {
      source  = "terraform.example.com/examplecorp/ourcloud"
      version = ">= 1.0"
    }
  }
}
```

Mirror layout on disk:

```
terraform.example.com/examplecorp/ourcloud/1.0.0/linux_amd64/terraform-provider-ourcloud
```

## v0.12-Compatible Provider Requirements

v0.12.26–v0.13 **accept but ignore** the `source` argument. To write a module that works on both:

- Use only `hashicorp`-namespace providers (v0.12 can't auto-install third-party ones).
- Local name must exactly match the source type name.
- Lowercase provider names.
- Omit `source` for `hashicorp`-namespace providers.

Rarely relevant now, but explains why old modules omit `source`.

---
Related: the reference companion to [[tf-install-cli]] and [[tf-aws-create]] (which show a real `provider` block + `init` in action). Feeds learning-path **B2 — Install, providers & your first project** (this page is B2's ref #2) and **I8 — Provider configuration in depth** (aliases, multi-instance, `configuration_aliases`).
