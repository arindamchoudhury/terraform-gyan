# Topics

Cross-source notes synthesizing multiple sources on the same topic.

## Active topic pages
<!-- Topic pages with ≥2 sources -->

- [IaC fundamentals](iac-fundamentals.md) — [[terraform-intro]], TID Ch1
- [Core workflow (Write/Plan/Apply)](core-workflow.md) — [[terraform-intro]], TID Ch1
- [Providers](providers.md) — [[terraform-intro]], TID Ch1 + Ch2

## Backlog

Topics to write once a second source covers them:

- **state** — currently from: [[terraform-intro]] + TID Ch2 §2.3.1 (backend/`cloud` blocks); full treatment is TID Ch6
- **modules** — currently from: [[terraform-intro]] + TID Ch2 §2.8 (the `module` block: `source`/`version`/`providers`) + [[tf-aws-manage]] (hands-on: consuming the registry VPC module, `module.*` outputs + state addressing, re-`init`); full treatment is TID Ch3
- **hcl-block-syntax** — currently from: TID Ch2 §2.2 only (blocks/labels/arguments/subblocks/attributes/ordering/style). Needs a second source (HCDocs "Configuration Syntax" not yet captured) to promote. Feeds B2.
- **meta-arguments-lifecycle** — currently from: TID Ch2 §2.7 only (`provider`, `depends_on`, `lifecycle`: `create_before_destroy`/`prevent_destroy`/`ignore_changes`/`replace_triggered_by`). Cross-links to [[ot-dynamic-prevent-destroy]]. Needs HCDocs meta-arguments docs as a second source.
- **refactoring** — currently from: TID Ch2 §2.9 only (`import`/`moved`/`removed`); full treatment is TID Ch9.
- **opentofu-divergence** — currently from: [[ot-provider-for-each]], [[ot-early-eval-backend]], [[ot-exclude-flag]], [[ot-dynamic-prevent-destroy]] (enough sources to promote to a topic page once TID's OpenTofu sections are captured — feeds E3)
