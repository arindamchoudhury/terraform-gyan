# Providers

> **Sources:** HCDocs "What is Terraform?" · Hafner, *Terraform in Depth* Ch1 §1.2.3–1.2.4

## In one paragraph

A provider is the plugin layer that lets Terraform talk to a specific vendor's API through one consistent language. Both sources agree on the shape: HashiCorp and the community publish thousands of providers to the Terraform Registry, and Terraform core stays vendor-agnostic by delegating all vendor-specific work to the provider. TID adds the mechanical detail HCDocs skips — providers are Go binaries that speak gRPC to Terraform core — while HCDocs stays at the "why this matters" level.

## Key concepts (cross-source)

- **Vendor abstraction** — HCDocs: providers let Terraform "talk to virtually any platform or service with an accessible API." TID: same claim, illustrated with a concrete abstraction diagram (Terraform Core → gRPC → Provider → vendor API) and the observation that Terraform itself "doesn't care what kind of infrastructure it manages, as long as it has a provider that exposes it."
- **Scale of the ecosystem** — HCDocs says "thousands of providers." TID gives a specific (book-vintage, 2025) figure: **3,280+ providers** in the registry — a number that will drift and shouldn't be treated as current without re-verifying.
- **Provider ↔ vendor relationship** — TID-only detail: generally one-to-one (AWS → AWS provider), though some vendors ship multiple providers (Azure). Providers are written in Go and communicate over gRPC; authoring one requires no gRPC knowledge unless you're building a *custom* provider (deferred to TID Ch12).

## Where the sources differ

- HCDocs treats providers as one bullet inside the broader "How does Terraform work?" section — brief, illustrative.
- TID gives providers their own subsection with an architecture diagram and draws the vendor/authentication distinction out explicitly (§1.2.4 "Vendors" is a separate subsection from §1.2.3 "Providers").

## When to read which

- Quick framing of what a provider is and why it matters? → HCDocs [[terraform-intro]] or [[terraform-use-cases]] (multi-cloud section).
- Want the plugin architecture (gRPC, Go, one-to-one vendor mapping)? → TID Ch1 §1.2.3–1.2.4. For hands-on registry navigation, see learning-path **B5 — Providers & resources**.
- Want to declare and configure a provider for real (`required_providers`, `source`, version constraint, `provider` block)? → [[tf-aws-create]].

## Sources

- [What is Terraform? (Intro)](../sources/terraform-docs/terraform-intro.md)
- [TID Ch 1 — A brief overview of Terraform](../books/tid/chapters/01-brief-overview.md)
- [Create infrastructure (AWS Get Started)](../sources/terraform-tutorials/tf-aws-create.md) — hands-on `required_providers` + `provider` block

## Open questions

> ❓ TID's "3,280 providers" figure is book-vintage (2025) — re-verify against the live Terraform Registry count if this number matters for anything beyond scale-illustration.
