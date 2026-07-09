# Providers (language overview)

> **Source:** [developer.hashicorp.com/terraform/language/providers](https://developer.hashicorp.com/terraform/language/providers)
> **Added:** 2026-07-09
> **Source updated:** docs for Terraform v1.15.x (latest); no explicit page date
> **Tags:** providers, registry, provider-tiers, plugin-cache, netrc, private-registry, installation
> **Type:** documentation

The hub page for the Providers section of the language docs. The conceptual framing (what a provider is, declare-vs-configure, the ecosystem) is already covered by the [[providers]] topic page, [[provider-requirements]], and [[aws-provider]]/[[google-provider]]. Captured here for the parts those don't: the **full provider-tier table**, **installation / plugin cache**, and **private-registry `.netrc`** auth.

## What providers do (brief)

Providers are plugins Terraform uses to interact with cloud/SaaS/other APIs. Each adds a set of **resource types and/or data sources**. Every resource type is implemented by a provider — without providers Terraform manages nothing. Most wrap an infrastructure platform; some are local utilities (`random`, `null`, `time`). Distributed separately from Terraform, each with its own release cadence and version numbers. See [[providers]] for the full concept.

## How to use them (pointers)

The docs split provider usage across three pages:

- **Provider Requirements** — declare providers so Terraform can install them (`required_providers`). Captured in [[provider-requirements]].
- **The `provider` block** — configure provider settings (region, credentials). See [[aws-provider]] / [[google-provider]] for concrete argument sets.
- **Dependency Lock File** (`.terraform.lock.hcl`) — pins the exact provider versions; commit it to version control so CLI, HCP Terraform, and Enterprise all install identically.

!!! tip "Always constrain versions in production"
    The docs recommend constraining acceptable provider versions in `required_providers` so `terraform init` doesn't silently install a newer, incompatible provider. The lock file makes this reproducible.

## Provider installation

- **HCP Terraform / Terraform Enterprise** install providers as part of **every run**.
- **Terraform CLI** finds and installs providers during `init` — downloading from a registry, or loading from a local **mirror** or **cache**. Reinitialize whenever a persistent working directory's providers change.
- **Plugin cache** — set `plugin_cache_dir` in the CLI config file to share downloaded providers across working directories, saving time and bandwidth.

## Private providers and `.netrc`

For a provider **not** in a HashiCorp-hosted registry, follow-up download requests may need credentials (public registry and HCP private registry do **not**):

- By default Terraform authenticates only the *opening* request to a registry. The registry replies with follow-up URLs (download the provider, the SHASUMS file). HashiCorp-hosted registries need no extra auth for these.
- If your registry **does** require credentials on follow-up requests, supply them via a **`.netrc`** file. Terraform looks in `$HOME` by default; override the location with the **`NETRC`** environment variable. Format follows curl's `.netrc`.

## Provider tiers (Registry badges)

Who develops and maintains a provider, shown as a Registry badge:

| Tier | Who maintains it | Namespace examples |
|---|---|---|
| **Official** | Owned and maintained by HashiCorp | `hashicorp`, `IBM`, `IBM-Cloud`, `ansible` |
| **Partner Premier** | Technology partner meeting the higher partner-premier bar | third-party org |
| **Partner** | Third-party company, against its own APIs, via the HashiCorp Technology Partner Program | third-party org |
| **Community** | Individual maintainers / community members | maintainer's account, e.g. `DeviaVir/gsuite` |
| **Archived** | Formerly Official or Partner, no longer maintained (deprecated API or low interest) | `hashicorp` or third-party |

!!! note "Richer than the per-provider pages"
    [[aws-provider]] and [[google-provider]] both show only the **Official** badge. This page is where the full ladder lives — note **Partner Premier** (a tier above plain Partner) and **Archived** (a maintenance-status warning: pin off it). The namespace is the trust signal in the source address, e.g. `hashicorp/aws` (Official) vs `DeviaVir/gsuite` (Community).

## How to develop providers

Providers are written in Go using the Terraform Plugin SDK / Framework. Deferred to the learning path's **E1 — Writing custom providers**.

---
Related: [[providers]] — the cross-source concept page this overview instantiates. · [[provider-requirements]] — the `required_providers` declaration mechanics referenced here. · [[aws-provider]], [[google-provider]] — concrete Official-tier providers (the tier table generalizes their badge).
