# Terraform: Up & Running — Reading Log

> Brikman, Y. (2022). *Terraform: Up & Running: Writing Infrastructure as Code*, 3rd edition. O'Reilly. ISBN 9781098116743. First release 2022-09-19.

The second book on this site, alongside [Terraform in Depth](../tid/index.md). The two are complementary rather than overlapping: TID is reference-shaped and current (2025), TUR is a single continuous worked example built across chapters — a web server cluster deployed to staging and production — and it is **three years older**, so its AWS specifics need checking against reality far more often than its ideas do.

!!! warning "The running example does not run as written"
    Every chapter from 2 onward builds on an Auto Scaling Group driven by **`aws_launch_configuration`**. AWS has since closed that door: accounts created on or after **2024-10-01 cannot create launch configurations by any method**, and no instance type released after **2023-01-01** works in one. Read the chapters for their ideas; substitute `aws_launch_template` if you actually deploy. Details and quotes: [[launch-configurations-eol]].

| Status | Chapter | Topic page(s) |
| ------ | ------- | ------------- |
| ✅ done | 1. Why Terraform | [IaC fundamentals](../../topics/iac-fundamentals.md) |
| ✅ done | 2. Getting Started with Terraform | [Core workflow](../../topics/core-workflow.md) · [Dependency graph](../../topics/dependency-graph.md) · [Meta-arguments](../../topics/meta-arguments-lifecycle.md) |
| ✅ done | 3. How to Manage Terraform State | [State](../../topics/state.md) · [Workspaces](../../topics/workspaces.md) |
| ✅ done | 4. How to Create Reusable Infrastructure with Terraform Modules | [Modules](../../topics/modules.md) |
| ✅ done | 5. Terraform Tips and Tricks: Loops, If-Statements, Deployment, and Gotchas | [Meta-arguments](../../topics/meta-arguments-lifecycle.md) — (backlog: count-for_each, dynamic-blocks, for-expression-splat, refactoring) |
| ✅ done | 6. Managing Secrets with Terraform | [Secrets and state](../../topics/secrets-and-state.md) |
| ✅ done | 7. Working with Multiple Providers | [Providers](../../topics/providers.md) |
| ✅ done | 8. Production-Grade Terraform Code | [Modules](../../topics/modules.md) — (backlog: checks-and-conditions, provisioners-and-escape-hatches, module-versioning-and-registries) |
| ⬜ todo | 9. How to Test Terraform Code | — |
| ⬜ todo | 10. How to Use Terraform as a Team | — |

## Conventions

Same as the TID log: concepts as short declarative bullets, commands in fenced blocks, `> ❓` for open questions, and a 📌 callout at the top of any chapter whose version-bound content was adapted.

Because TUR is a **narrative** book, each chapter note also records *what state the running example is in* by the end of the chapter, so a later chapter's notes make sense without re-reading the earlier ones.

## Page map

[page-map.md](page-map.md) — PDF-to-print offset and per-chapter page ranges, so a future session extracts a chapter without re-deriving boundaries.
