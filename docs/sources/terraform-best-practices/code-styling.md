# Code styling

> **Source:** [terraform-best-practices.com/code-styling](https://www.terraform-best-practices.com/code-styling)
> **Added:** 2026-08-13
> **Source updated:** page states "Last updated 1 year ago" (so roughly mid-2025); the site gives no exact date
> **Tags:** style, formatting, fmt, pre-commit, editorconfig, terraform-docs, comments, documentation
> **Type:** documentation
> **Author:** Anton Babenko — community book, not a HashiCorp publication

!!! note "Read alongside the official style guide"
    HashiCorp's own [Style Guide](../terraform-docs/tf-style-guide.md) ([[tf-style-guide]]) covers naming, resource ordering, file layout, variable/output usage, and version pinning. **This page does not repeat any of that.** Its contribution is the *enforcement toolchain* — pre-commit, `.editorconfig`, `terraform-docs` — plus a comment convention the official guide does not state. Where the two overlap, the differences are called out below.

## Documentation expectations

The page opens with four rules about documentation rather than about code layout:

- Examples and modules should carry documentation explaining features and usage.
- **All links in `README.md` must be absolute**, so the Terraform Registry renders them correctly. This is a registry-publishing constraint, not a style preference — relative links break once the README is rendered off-repo.
- Diagrams may be [mermaid](https://mermaid.js.org/); blueprints may come from [cloudcraft.co](https://cloudcraft.co).
- Use pre-commit hooks so code is valid, formatted, and documented **before** it reaches git and human review.

## Formatting

`terraform fmt` is described as *"intentionally opinionated and non-configurable"*, which is framed as the point: a uniform format across codebases lets reviewers focus on substance rather than style. Same position as the official guide, arrived at from the reviewer's side rather than the author's.

What this page adds is the automation. Wire `fmt` into pre-commit:

```yaml
# .pre-commit-config.yaml

repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.99.4
    hooks:
      - id: terraform_fmt
```

And in CI, use `terraform fmt -check`, which *"exits with status 0 when all files are correctly formatted; otherwise, it returns a non-zero code and lists the offending files."* The stated benefit is removing merge friction rather than catching bugs.

!!! tip "Pin the hook `rev`, and expect it to age"
    `rev: v1.99.4` is a pinned tag on `antonbabenko/pre-commit-terraform`. It is the one line here that goes stale, and the page is roughly a year old — check the repository's releases before copying it verbatim.

## Editor configuration

Use an `.editorconfig` so whitespace and indentation stay consistent across editors and IDEs. **This has no equivalent in HashiCorp's style guide**, which stops at `terraform fmt` and never addresses the editor layer:

```ini
[*]
indent_style = space
indent_size = 2
trim_trailing_whitespace = true

[*.{tf,tfvars}]
indent_style = space
indent_size = 2

[Makefile]
indent_style = tab
```

The `[Makefile]` stanza is the reason to bother: `fmt` never touches non-`.tf` files, so a repo with a Makefile still needs something to stop an editor writing spaces where tabs are required.

## Documentation generation

**pre-commit** is a framework for managing multi-language pre-commit hooks, written in Python, that runs work on a developer's machine before a commit lands. With Terraform it formats, validates, **and updates documentation**.

**terraform-docs** generates module documentation in several output formats. It runs manually or via `pre-commit-terraform` hooks so docs update automatically.

The named reference implementations are the [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform) repository and [terraform-aws-vpc](https://github.com/terraform-aws-modules/terraform-aws-vpc), which already uses this setup.

## Comment style

Two rules, and the first is a real divergence worth recording.

**Use `#` for comments. Avoid `//` or block comments** (`/* */`).

```hcl
# This is a comment explaining the resource
resource "aws_instance" "this" {
  # ...
}
```

**Delimit section headers with `# -----` or `######`:**

```hcl
# --------------------------------------------------
# AWS EC2 Instance Configuration
# --------------------------------------------------

resource "aws_instance" "this" {
  # ...
}
```

!!! info "Where this differs from HashiCorp"
    HashiCorp's style guide also prefers `#`, so the two agree on the comment *character*. The **section-header convention is this page's own** — the official guide has no equivalent, and `terraform fmt` neither produces nor enforces those rules. Adopt it as a team convention if you want it; nothing in the toolchain will keep it consistent for you.

!!! warning "The page is unfinished here"
    The comment section ends with a literal `@todo: Document module versions, release, GH actions`. Module versioning, releases, and GitHub Actions are therefore **not** covered by this page despite being in scope for it. Treat the release/CI half as absent, not as advice against.

## Resources cited

- [pre-commit framework homepage](https://pre-commit.com/)
- [pre-commit-terraform](https://github.com/antonbabenko/pre-commit-terraform) — git hooks for Terraform
- Dean Wilson, [pre-commit hooks and terraform — a safety net for your repositories](https://www.unixdaemon.net/tools/pre-commit-hooks-and-terraform-a-safety-net-for-your-repositories/)

---
Related: [[tf-style-guide]] — HashiCorp's official style guide, which owns naming, ordering, file layout and version pinning; this page owns the enforcement toolchain and adds a section-header convention the official guide lacks. · [[tf-cli-commands]] — where `terraform fmt` and `terraform validate` sit in the command surface.
