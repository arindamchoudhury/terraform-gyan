# Providers

> **Sources:** HCDocs "What is Terraform?" · HCDocs "Providers" ([[tf-providers]]) · Hafner, *Terraform in Depth* Ch1 §1.2.3–1.2.4, Ch2 §2.4 · Registry provider pages [[aws-provider]], [[google-provider]]

## In one paragraph

A provider is the plugin layer that lets Terraform talk to a specific vendor's API through one consistent language. Both sources agree on the shape: HashiCorp and the community publish thousands of providers to the Terraform Registry, and Terraform core stays vendor-agnostic by delegating all vendor-specific work to the provider. TID adds the mechanical detail HCDocs skips — providers are Go binaries that speak gRPC to Terraform core — while HCDocs stays at the "why this matters" level.

## Key concepts (cross-source)

- **Vendor abstraction** — HCDocs: providers let Terraform "talk to virtually any platform or service with an accessible API." TID: same claim, illustrated with a concrete abstraction diagram (Terraform Core → gRPC → Provider → vendor API) and the observation that Terraform itself "doesn't care what kind of infrastructure it manages, as long as it has a provider that exposes it."
- **Scale of the ecosystem** — HCDocs says "thousands of providers." TID gives a specific (book-vintage, 2025) figure: **3,280+ providers** in the registry — a number that will drift and shouldn't be treated as current without re-verifying.
- **Provider ↔ vendor relationship** — TID-only detail: generally one-to-one (AWS → AWS provider), though some vendors ship multiple providers (Azure). Providers are written in Go and communicate over gRPC; authoring one requires no gRPC knowledge unless you're building a *custom* provider (deferred to TID Ch12).
- **Declare vs. configure** (TID Ch2 §2.4) — the split HCDocs's intro glosses: `required_providers` (inside `terraform`) declares *what to install* + version constraint; the separate `provider` block *configures* it (auth + scoping). Provider blocks are **root-module only**. If you omit `required_providers`, Terraform *infers* the provider from the resource name prefix under the `hashicorp` namespace (`aws_instance` → `hashicorp/aws`) — convenient but discouraged, since you lose version pinning.
- **Aliases = multiple connections** (TID Ch2 §2.4.4) — like multiple SDK clients: one default `provider` block plus named `alias` blocks (`alias = "west"`), and data/resource blocks pick one via the `provider` meta argument. This is the Terraform-CLI equivalent of what OpenTofu generalizes further with [[ot-provider-for-each]].

!!! note "Why the vendor / provider distinction exists"
    Terraform has **no formal `vendor` object** — "vendor" is TID's teaching word for the real-world service; only **provider** is a language construct. The two are kept conceptually separate because they aren't the same thing and don't map one-to-one:

    - **Vendor** = the external system/API (AWS, Cloudflare, Okta) that owns the real infrastructure. **Provider** = the Go plugin that wraps it, speaking gRPC to core (SDK analogy: AWS is the vendor, `aws` provider is Terraform's Boto3).
    - **Core is vendor-agnostic** — it only knows the provider plugin interface, never the vendor. Core builds the DAG and delegates every vendor-specific call to the provider. The provider *is* the abstraction boundary; that's the whole "one engine, pluggable everything" design.
    - **Not 1:1** — one vendor can ship many providers (Azure: `azurerm`/`azuread`/`azapi`/`azurestack`; AWS: `aws` + `awscc`); some providers wrap **no vendor at all** (utility providers `random`, `null`, `time`, `tls`, `terraform_data`); a vendor may have official *and* community providers.
    - **Independent lifecycle** — a provider is its own artifact with its own version, cadence, and registry namespace (`hashicorp/aws`). **Provider version ≠ vendor API version** — the AWS provider is on major 6 while AWS-the-service has no "v6." And the provider may be authored by the vendor, HashiCorp, *or* the community.
    - **The config split mirrors it** — `required_providers` picks the *provider* (what to install, which version); the `provider` block configures the connection to the *vendor* (credentials, region).

## Configuration & authentication across providers (AWS vs GCP)

The two Registry provider pages make the "declare vs. configure" split concrete, and show that the *configure* half is where providers genuinely differ. Same skeleton, different bodies:

- **Tier / maintenance** — both are **Official**, but AWS is HashiCorp-only while GCP is **co-maintained by Google + HashiCorp**. Providers version independently: AWS is on 6.x, GCP on 7.x (pin each separately). GCP also ships a `google-beta` sibling for preview features; AWS has `awscc` (Cloud Control) alongside `aws`.
- **Scoping arguments** — AWS's `provider` block scopes with just `region`. GCP adds a **`project` / `region` / `zone`** hierarchy (every GCP resource lives in a project; zonal resources take a zone). Per-resource values override the provider default in both.
- **Credential precedence** — different default paths:
    - **AWS** ([[aws-provider]]): provider params → env vars → `~/.aws/credentials` → `~/.aws/config` → container creds → instance profile.
    - **GCP** ([[google-provider]]): `gcloud` ADC (recommended) → service-account key file → env vars (`GOOGLE_CREDENTIALS` → `GOOGLE_CLOUD_KEYFILE_JSON` → `GCLOUD_KEYFILE_JSON`) → access token → **impersonation** (`roles/iam.serviceAccountTokenCreator`).
- **Least-privilege idiom** — same principle, different tools: AWS leans on instance profiles / OIDC roles; GCP leans on ADC + workload-identity **impersonation**. Both docs warn: never hard-code or commit credentials (static AWS keys ≈ downloaded GCP key files — avoid).
- **Provider-wide conveniences that don't port** — AWS has **`default_tags`** (tag every resource); GCP has no tag-all argument (labels are per-resource) but adds **`user_project_override` / `billing_project`** (quota-project routing) with no AWS parallel.

The lesson: the `required_providers` + `source` + version-pin mechanics are identical across providers, but the `provider` block's arguments and auth model are vendor-shaped — reading the specific provider's Registry page is non-optional.

### Trust tiers and where providers come from ([[tf-providers]])

The Registry badge tells you who maintains a provider — a trust/cadence signal encoded in the source-address namespace: **Official** (`hashicorp`, `IBM`, `ansible`), **Partner Premier**, **Partner**, **Community** (`DeviaVir/gsuite`), and **Archived** (formerly maintained, now abandoned — pin off it). Both [[aws-provider]] and [[google-provider]] are Official; the full ladder only appears on the [[tf-providers]] hub. Installation-wise: HCP/Enterprise install providers every run, CLI installs on `init` (registry, mirror, or `plugin_cache_dir` cache). A **private** (non-HashiCorp) registry may need follow-up-request credentials via a `.netrc` file (`NETRC` env var overrides its location).

### The default configuration is never absent ([[tf-provider-block]])

TID and the intro pages both present the `provider` block as the thing that configures a provider. The block reference adds the case where you *don't* write one, and it has two shapes.

- **No `provider` block at all** — Terraform assumes an **empty default configuration**. Fine for `random` or `null`; an error for any provider with required arguments.
- **Every `provider` block carries an `alias`** — Terraform creates an **implied empty default configuration**, and any resource that omits the `provider` meta-argument silently binds to it rather than to one of your aliases.

The second is the trap. Adding `alias = "east"` to a single existing `provider "aws"` block does not just name it; it *demotes* it, and every resource that never specified a provider now points at an unconfigured default. The rule to remember: **the block without an `alias` is the default**, and if none exists, an empty one is invented.

Two further constraints from the same page, both consistent with [[providers]]'s declare-vs-configure split:

- **Provider configuration inherits into child modules; `source` and `version` do not.** Each child module declares its own `required_providers` regardless. A child that needs an *aliased* config must declare `configuration_aliases = [aws.west]` — the receiving end of the caller's `providers = { aws.west = aws.west }`.
- **The `version` argument inside a `provider` block is deprecated** and will be removed. Constraints belong in `required_providers` (see [[provider-requirements]]).

## Where the sources differ

- HCDocs treats providers as one bullet inside the broader "How does Terraform work?" section — brief, illustrative.
- TID gives providers their own subsection with an architecture diagram and draws the vendor/authentication distinction out explicitly (§1.2.4 "Vendors" is a separate subsection from §1.2.3 "Providers").

## When to read which

- Quick framing of what a provider is and why it matters? → HCDocs [[terraform-intro]] or [[terraform-use-cases]] (multi-cloud section).
- Want the plugin architecture (gRPC, Go, one-to-one vendor mapping)? → TID Ch1 §1.2.3–1.2.4. For hands-on registry navigation, see learning-path **B5 — Providers & resources**.
- Want to declare and configure a provider for real (`required_providers`, `source`, version constraint, `provider` block)? → [[tf-aws-create]].

## Sources

- [What is Terraform? (Intro)](../sources/terraform-docs/terraform-intro.md)
- [Providers (language overview)](../sources/terraform-docs/tf-providers.md) — provider tiers, installation/plugin cache, private-registry `.netrc`
- [`provider` block reference](../sources/terraform-docs/tf-provider-block.md) — `alias`, implied empty default configuration, `configuration_aliases`, deprecated `version` argument
- [TID Ch 1 — A brief overview of Terraform](../books/tid/chapters/01-brief-overview.md)
- [TID Ch 2 — Terraform HCL components](../books/tid/chapters/02-hcl-components.md) §2.4 — declare/configure/alias mechanics
- [Create infrastructure (AWS Get Started)](../sources/terraform-tutorials/tf-aws-create.md) — hands-on `required_providers` + `provider` block
- [AWS Provider (Registry)](../sources/terraform-registry/aws-provider.md) — AWS auth precedence, `default_tags`, key arguments
- [Google Cloud Provider (Registry)](../sources/terraform-registry/google-provider.md) — GCP ADC/impersonation auth, `project`/`region`/`zone`, quota-project routing

## Open questions

> ❓ TID's "3,280 providers" figure is book-vintage (2025) — re-verify against the live Terraform Registry count if this number matters for anything beyond scale-illustration.
