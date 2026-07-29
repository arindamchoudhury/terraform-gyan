# Topics

Cross-source notes synthesizing multiple sources on the same topic.

## Active topic pages
<!-- Topic pages with ≥2 sources -->

- [IaC fundamentals](iac-fundamentals.md) — [[terraform-intro]], TID Ch1
- [Core workflow (Write/Plan/Apply)](core-workflow.md) — [[terraform-intro]], TID Ch1
- [Providers](providers.md) — [[terraform-intro]], TID Ch1 + Ch2
- [Modules](modules.md) — [[terraform-intro]], TID Ch2 §2.8 + Ch3, [[tf-aws-manage]]
- [Meta-arguments and `lifecycle`](meta-arguments-lifecycle.md) — [[tf-meta-arguments]], TID Ch2 §2.7, [[tf-configure-resource]], [[ot-dynamic-prevent-destroy]], [[tf-style-guide]]
- [The dependency graph](dependency-graph.md) — [[tf-cmd-graph]], [[tf-meta-depends-on]], TID Ch2 §2.2.5 + §2.7.3, [[tf-configure-resource]]; includes locally verified experiments
- [Workspaces](workspaces.md) — TID Ch6 §6.4.5 + §6.4.7, HCDocs "Workspaces" + "HCP Terraform workspaces", Terraform 1.15.8 source; the CLI-vs-HCP distinction, pending A4/A7

## Backlog

Topics to write once a second source covers them:

- **state** — currently from: [[terraform-intro]] + TID Ch2 §2.3.1 (backend/`cloud` blocks) + **TID Ch6** (full treatment: purpose of state, tfstate JSON, backends/workspaces/migration, `moved`/`removed`, drift, `terraform_remote_state`, state-only providers) + [[tf-state]] (HCDocs State overview: bindings as the primary purpose, the one-to-one rule and how `import`/`state rm` break it, `-json` integration points) + [[tf-state-purpose]] (the four why-state-exists arguments: real-world mapping and the failed tag prototype, **retained dependencies for destroy ordering**, the attribute cache as the optional part, syncing/locking) + [[tf-state-backends]] (what a backend is responsible for, remote state never touching local disk except on write failure, the `state push` lineage/serial guards). Promotable once TUR's state chapters land — feeds B9/I6/I7.
- **hcl-block-syntax** — currently from: TID Ch2 §2.2 (blocks/labels/arguments/subblocks/attributes/ordering/style) + [[tf-config-syntax]] (HCDocs "Configuration Syntax": arguments vs blocks, identifiers, comments, encoding). Two sources now — promotable; feeds B2/B4.
- **refactoring** — currently from: TID Ch2 §2.9 + **TID Ch6 §6.5** (`moved`/`removed` blocks, `state rm`/`replace-provider`, hand-edit last-resort); full treatment is TID Ch9.
- **opentofu-divergence** — currently from: [[ot-provider-for-each]], [[ot-early-eval-backend]], [[ot-exclude-flag]], [[ot-dynamic-prevent-destroy]] (enough sources to promote to a topic page once TID's OpenTofu sections are captured — feeds E3)
- **expressions-functions** — currently from: TID Ch4 §4.2–4.7 (operators, standard-library + provider-defined functions, string templates, regex, type conversion, `try`/`can`). Feeds B7.
- **count-for_each** — currently from: TID Ch4 §4.8 (`count`/`for_each`, plan-time-known limitation, reindex footgun) + [[tf-meta-arguments]] (`count` vs `for_each` reference). Two sources — promotable; feeds I1.
- **dynamic-blocks** — currently from: TID Ch4 §4.10 (`dynamic`/`content`, label-named iterator, `[]`-vs-`["placeholder"]` toggle). Feeds I3.
- **secrets-and-state** — currently from: [[tf-manage-sensitive-data]] (hide-vs-omit-vs-both, version matrix, write-only args) + [[infisical-terraform-secrets]] (the `grep`-proven state leak, secrets-manager workflow, CI OIDC, module coordinate-passing, dynamic secrets vs rotation, anti-pattern table). Two sources — promotable; feeds A6/I6.
- **for-expression-splat** — currently from: TID Ch4 §4.9 (list/object `for`, `=>`, `if` filter, `...` grouping, splat `[*]`). Feeds B7/I3.
