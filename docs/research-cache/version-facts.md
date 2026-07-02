# Version & Certification Facts

Verified facts captured during research. Refreshed by Phase 4 review passes.

_Last verified: 2026-07-02._

## Tooling versions

| Tool | Current stable | License | Notes |
|------|----------------|---------|-------|
| Terraform CLI | **1.14.7** (2026-03-11) | BSL 1.1 (source-available) | CLI free to provision your own infra under BSL |
| OpenTofu | **1.12.2** (1.12.0 released 2026-05-14) | MPL 2.0 (open source) | Forked from Terraform 1.5.x; Linux Foundation project |

**Terraform ↔ OpenTofu divergence.** OpenTofu forked at Terraform 1.5.x and now ships features Terraform's
open-source CLI does not: **state encryption**, **provider `for_each`**, **early variable/`.tfvars` evaluation**,
the **`-exclude` flag**, and (1.12) **dynamic `prevent_destroy`**. HCL syntax, provider ecosystem, and state-file
format remain compatible. Both accept the same providers from the registry.

**Licensing timeline.** HashiCorp relicensed Terraform from MPL to BSL 1.1 in Aug 2023 → triggered the OpenTofu fork.
HCP Terraform's legacy free managed plan ended 2026-03-31; the replacement free tier caps at **500 managed resources**.

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
- OpenTofu release notes (1.12, 2026-05-14) via InfoQ
- Terraform CLI changelog / release notes (1.14.7, 2026-03)
