# Version & Certification Facts

Verified facts captured during research. Refreshed by Phase 4 review passes.

_Last verified: 2026-07-04._

## Tooling versions

| Tool | Current stable | License | Notes |
|------|----------------|---------|-------|
| Terraform CLI | **1.15.7** (1.15.0 released 2026-04-29) | BSL 1.1 (source-available) | CLI free to provision your own infra under BSL |
| OpenTofu | **1.12.3** (1.12.0 released 2026-05-14) | MPL 2.0 (open source) | Forked from Terraform 1.5.x; Linux Foundation project |

**Terraform ↔ OpenTofu divergence.** OpenTofu forked at Terraform 1.5.x and shipped features Terraform's
open-source CLI lacked: **state encryption**, **provider `for_each`**, **early variable/`.tfvars` evaluation**,
the **`-exclude` flag**, and (1.12) **dynamic `prevent_destroy`**. **Terraform 1.15 (2026-04-29) closed some of
the gap** — it added dynamic module sources, a formal deprecation mechanism for variables/outputs, an inline
type-conversion function, output-block type constraints, and Windows ARM64 support. State encryption and the
other items above remain OpenTofu-only as of this check. HCL syntax, provider ecosystem, and state-file format
remain compatible. Both accept the same providers from the registry.

**Licensing timeline.** HashiCorp relicensed Terraform from MPL to BSL 1.1 in Aug 2023 → triggered the OpenTofu fork.
**IBM announced its $6.4B acquisition of HashiCorp in April 2024; the deal closed 27 Feb 2025** (after US/UK regulatory review) — HashiCorp (and Terraform) is now an IBM company.
HCP Terraform's legacy free managed plan ended 2026-03-31; the replacement free tier caps at **500 managed resources**.

**Provider registry scale.** 3,000+ providers milestone (HashiCorp blog); **4,000+ providers** as of 2026 per third-party trackers (registry.terraform.io/browse/providers is the live count — treat any specific number as a snapshot, not a fixed fact).

**AWS provider (hashicorp/aws).** Now on **major 6** — 6.0 went GA in 2026; latest **6.53.0** (2026-07-01). New projects pin `~> 6.0`. HashiCorp's own AWS Get Started tutorial still shows `~> 5.92` (major 5); it works but is behind. Provider versions move independently of the Terraform CLI.

**2026 OpenTofu-vs-Terraform guidance (multiple third-party comparisons, checked 2026-07-03):** OpenTofu is increasingly framed as the lower-risk default for *new* projects — OSI-approved MPL 2.0, Linux Foundation governance, full provider compatibility, plus CLI features (state encryption, provider `for_each`, early variable evaluation, `-exclude`) that Terraform's open-source CLI still lacks. Staying on Terraform still makes sense for teams already invested in HCP Terraform, Terraform **Stacks** (Terraform-exclusive, lives in HCP Terraform), or with procurement requirements naming HashiCorp specifically. Existing Terraform investment ≠ reason to migrate reactively — evaluate OpenTofu at the next new-project or compliance decision point.

## Certifications (current)

### Terraform Associate (004) — entry cert
- **Replaces 003.** 003 retired 2026-01-08; 004 first delivery 2026-01-08.
- Tests on **Terraform 1.12**. Duration **1 hour**, ~**57 questions**, **$70.50 USD**, credential valid **2 years**.
- **8 objectives:** (1) IaC concepts, (2) Terraform fundamentals (providers, state concept), (3) core workflow
  (init/plan/apply/destroy), (4) configuration language (HCL), (5) modules (use + author), (6) state management,
  (7) infrastructure maintenance, (8) HCP Terraform. No published percentage weights.

### Terraform Authoring and Operations Professional — advanced cert
- **Lab-based** (hands-on), for cloud engineers. Prereq: deep HCL + CLI knowledge, pro cloud experience.
- Currently uses the **AWS** provider; **Azure** variant in development (expected late 2026).
- **6 domains:** (1) manage resource lifecycle, (2) develop & troubleshoot dynamic configuration,
  (3) develop collaborative workflows, (4) create/maintain/use modules, (5) configure & use providers,
  (6) collaborate using HCP Terraform (multiple-choice only).

## Sources consulted
- HashiCorp Developer — Certifications / Infrastructure Automation
- HashiCorp Developer — Terraform Associate 004 study path
- HashiCorp Developer — Terraform Authoring & Operations Pro exam content list
- OpenTofu release notes (1.12, 2026-05-14) via InfoQ; current patch 1.12.3
- Terraform CLI changelog / release notes (1.15 released 2026-04-29; current patch 1.15.7) — see InfoQ "Terraform 1.15 Closes Gap to OpenTofu"
- HashiCorp blog — "Terraform ecosystem passes 3,000 providers with over 250 partners"
- Third-party OpenTofu-vs-Terraform comparisons (Encore, Scalr, devops-daily, rack2cloud), checked 2026-07-03
