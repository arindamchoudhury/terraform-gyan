# Terraform Best Practices

Notes captured from [terraform-best-practices.com](https://www.terraform-best-practices.com/) — a community book by **Anton Babenko**, maintainer of [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform) and the [terraform-aws-modules](https://github.com/terraform-aws-modules) organisation.

**Nav mirrored from:** rung 3, rendered nav DOM (GitBook), probed 2026-08-13. The book's navigation is **flat** — ten top-level pages, no groups — so the nav here reproduces that order rather than inventing sections:

`Welcome` · `Key concepts` · `Code structure` · `Code structure examples` · `Naming conventions` · **`Code styling`** · `FAQ` · `References` · `Writing Terraform configurations` · `Workshop`

!!! warning "Community source, and parts of it are stale or unfinished"
    This is **not** a HashiCorp publication and carries no compatibility promise. Two things to keep in mind when reading:

    - Pages state their age as *"Last updated N ago"* with **no exact date**. The `code-styling` page reads "1 year ago" as of 2026-08-13, so treat pinned versions in its examples as roughly mid-2025.
    - At least one page ships a visible `@todo`, so a missing subject means *not written yet*, not *deliberately omitted*.

    Where it overlaps HashiCorp's own [Style Guide](../terraform-docs/tf-style-guide.md), prefer the official page for the rule and this book for the **tooling that enforces it** — that division is the reason to capture it at all.

## Sources

| # | Title | URL |
|---|---|---|
| 1 | [Code styling](code-styling.md) | [code-styling](https://www.terraform-best-practices.com/code-styling) |
