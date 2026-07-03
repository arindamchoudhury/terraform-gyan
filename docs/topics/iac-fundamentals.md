# IaC fundamentals

> **Sources:** HCDocs "What is Terraform?" · Hafner, *Terraform in Depth* Ch1 §1.1

## In one paragraph

Infrastructure as Code means defining infrastructure in human-readable, version-controlled configuration files instead of provisioning by hand, then using a consistent, repeatable workflow to apply those files. Terraform isn't the only IaC tool, but it's positioned as the standard: vendor-agnostic (unlike CloudFormation), declarative, and backed by the largest provider ecosystem. IaC matters because it lets infrastructure inherit decades of software-engineering practice — versioning, review, testing, CI/CD — that ad hoc manual configuration never had access to.

## Key concepts (cross-source)

- **Declarative, versioned config** — both sources agree config files should be human-readable, versionable, reusable, shareable. HCDocs frames this as the headline definition; TID frames it as "IaC is a natural evolution" from per-machine admin → config-management tools (Puppet, Chef, Packer) → full-platform IaC.
- **Where Terraform sits among IaC tools** — only TID names competitors explicitly: Pulumi (vendor-agnostic), CloudFormation/Deployment Manager (vendor-specific). HCDocs doesn't compare tools, just asserts Terraform's five pillars (see [[core-workflow]] and provider coverage below).
- **Software-engineering practices applied to infra** — TID §1.1.1–1.1.3 is the more detailed treatment: Git versioning, linting/security scanning, CI/CD (with the "TACOS" — Terraform Automation and Collaboration Software — coinage for purpose-built platforms like HCP Terraform, Spacelift, Scalr). HCDocs states the same idea more tersely under its "Automate changes" and "Collaborate" pillars.

## Where the sources differ

- HCDocs is marketing-adjacent official framing — five crisp pillars (manage/track/automate/standardize/collaborate), no tool comparison, no history.
- TID is a practitioner's narrative — opens with a personal VPC anecdote, names competing tools, and goes deeper on *why* CI/CD-for-infra matters (TACOS terminology, the GitHub/GitLab integration pattern for speculative plans).

## When to read which

- Want the fast, canonical five-pillar pitch? → HCDocs [[terraform-intro]].
- Want the "why does this matter in practice" narrative, with a named landscape of competing IaC tools? → TID Ch1 §1.1.

## Sources

- [What is Terraform? (Intro)](../sources/terraform-docs/terraform-intro.md)
- [TID Ch 1 — A brief overview of Terraform](../books/tid/chapters/01-brief-overview.md)

## Open questions

> ❓ TID doesn't cover HCP Terraform in depth in Ch1 (deferred to later chapters) — revisit once Ch6/Ch7 land to see how the book's CI/CD treatment compares to HCDocs' "Collaborate" pillar.
