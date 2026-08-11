# IaC fundamentals

> **Sources:** HCDocs "What is Terraform?" · Hafner, *Terraform in Depth* Ch1 §1.1 · Brikman, *Terraform: Up & Running* Ch1

## In one paragraph

Infrastructure as Code means defining infrastructure in human-readable, version-controlled configuration files instead of provisioning by hand, then using a consistent, repeatable workflow to apply those files. Terraform isn't the only IaC tool, but it's positioned as the standard: vendor-agnostic (unlike CloudFormation), declarative, and backed by the largest provider ecosystem. IaC matters because it lets infrastructure inherit decades of software-engineering practice — versioning, review, testing, CI/CD — that ad hoc manual configuration never had access to.

## Key concepts (cross-source)

- **Declarative, versioned config** — both sources agree config files should be human-readable, versionable, reusable, shareable. HCDocs frames this as the headline definition; TID frames it as "IaC is a natural evolution" from per-machine admin → config-management tools (Puppet, Chef, Packer) → full-platform IaC.
- **Where Terraform sits among IaC tools** — only TID names competitors explicitly: Pulumi (vendor-agnostic), CloudFormation/Deployment Manager (vendor-specific). HCDocs doesn't compare tools, just asserts Terraform's five pillars (see [[core-workflow]] and provider coverage below).
- **Software-engineering practices applied to infra** — TID §1.1.1–1.1.3 is the more detailed treatment: Git versioning, linting/security scanning, CI/CD (with the "TACOS" — Terraform Automation and Collaboration Software — coinage for purpose-built platforms like HCP Terraform, Spacelift, Scalr). HCDocs states the same idea more tersely under its "Automate changes" and "Collaborate" pillars. TUR Ch1 turns the same idea into a seven-item list of what code buys you — self-service, speed and safety, documentation, version control, validation, reuse, and *happiness*, which no other source names.
- **"IaC tool" is a category error until you split it** — only TUR imposes a taxonomy: **ad hoc scripts → configuration management → server templating → orchestration → provisioning**, with Terraform strictly in the last box. TID's "IaC evolved out of Puppet/Chef/Packer" narrative implies the same ordering without naming the boxes. Most tool arguments (*"Ansible or Terraform?"*) are arguments across two of these categories, not within one.
- **Declarative is defined by what happens on the second run** — HCDocs and TID both assert declarativeness; TUR proves it. Edit an Ansible `count` from 10 to 15 and you get 25 servers; edit Terraform's and you get `Plan: 5 to add`. From that follow the two properties the other sources take for granted: procedural code doesn't capture state (you'd need the full history of every apply to know what exists) and procedural code resists reuse.
- **Immutable infrastructure** — a single glossary line in HCDocs; in TUR it's a consequence of server templating, complete with its two costs (rebuilding an image for a trivial change is slow, and immutability ends the moment the image boots and starts writing to disk).

## Where the sources differ

- HCDocs is marketing-adjacent official framing — five crisp pillars (manage/track/automate/standardize/collaborate), no tool comparison, no history.
- TID is a practitioner's narrative — opens with a personal VPC anecdote, names competing tools, and goes deeper on *why* CI/CD-for-infra matters (TACOS terminology, the GitHub/GitLab integration pattern for speculative plans).
- TUR is a **decision document**. It states its criteria (open source, cloud-agnostic, provisioning, large community, mature, immutable, declarative, masterless, agentless, optional paid tier) and then scores seven tools against ten trade-offs. It is the only source that argues *against* Terraform anywhere — and the only one honest that you will use several tools together.
- **Currency runs the other way.** TID (2025) covers the BSL relicensing and OpenTofu; TUR (June 2022) predates both, so its "Source: Open" column for Terraform is now wrong, and two of the tools it compares have since changed owner or been forked by their own community. Read TUR for the reasoning and TID for the current state of the world.

## When to read which

- Want the fast, canonical five-pillar pitch? → HCDocs [[terraform-intro]].
- Want the "why does this matter in practice" narrative, with a named landscape of competing IaC tools? → TID Ch1 §1.1.
- Have to justify Terraform to someone, or choose between it and Ansible/Pulumi/CloudFormation? → TUR Ch1. Its procedural-vs-declarative example is the fastest way to make the distinction land.

## Sources

- [What is Terraform? (Intro)](../sources/terraform-docs/terraform-intro.md)
- [TID Ch 1 — A brief overview of Terraform](../books/tid/chapters/01-brief-overview.md)
- [TUR Ch 1 — Why Terraform](../books/tur/chapters/01-why-terraform.md)

## Open questions

> ❓ TID doesn't cover HCP Terraform in depth in Ch1 (deferred to later chapters) — revisit once Ch6/Ch7 land to see how the book's CI/CD treatment compares to HCDocs' "Collaborate" pillar.

> ❓ Nobody here scores **OpenTofu** against TUR's ten trade-offs. On paper it takes the row Terraform used to hold (open, all clouds, provisioning, immutable, declarative, DSL, masterless, agentless) — worth writing out properly when the `opentofu-divergence` topic page gets promoted.
