# Resources

Resources cited across the [Learning Path](../learning-path.md). Books serve topics — they are not the organizing structure.

| Abbrev | Name | Type | URL |
|---|---|---|---|
| **TID** | *Terraform in Depth: IaC with Terraform and OpenTofu* (Hafner, Manning) | Book | manning.com/books/terraform-in-depth |
| **TUR** | *Terraform: Up & Running*, 3rd ed (Brikman, O'Reilly) | Book | oreilly.com |
| **HCDocs** | HashiCorp Developer — Terraform docs | Official docs | https://developer.hashicorp.com/terraform |
| **HCTut** | HashiCorp Developer — Terraform Tutorials (free hands-on labs) | Official interactive | https://developer.hashicorp.com/terraform/tutorials |
| **OTDocs** | OpenTofu documentation | Official docs | https://opentofu.org/docs/ |
| **Assoc** | Terraform Associate 004 study path | Official course | https://developer.hashicorp.com/terraform/tutorials/certification-004 |
| **Pro** | Terraform Authoring & Operations Pro study path | Official course | https://developer.hashicorp.com/terraform/tutorials/pro-cert |
| **KK** | KodeKloud — Terraform for Beginners / labs | Interactive labs | kodekloud.com |
| **TF2026** | Rahul Oli — *Terraform Complete Course in One Video: Beginner to Advanced* (YouTube, Apr 2026, 6h23m). Companion repo of 13 lecture directories; coverage map and caveats in [[tf2026-course-facts]] | Video course | [youtu.be/l5qtFBsxZdk](https://youtu.be/l5qtFBsxZdk) · [companion repo](https://github.com/devopsforge2304/Terraform-Full-Course-2026) |
| **Krausen** | Bryan Krausen — Terraform Associate course + practice exams | Video + practice | [krausen.io hands-on labs](https://krausen.io/course/hashicorp-certified-terraform-associate-hands-on-labs/) · [004 practice exams](https://www.udemy.com/course/terraform-associate-004-practice-exams/) |
| **TPF** | Terraform Plugin Framework docs | Official docs | https://developer.hashicorp.com/terraform/plugin/framework |
| **TG** | Terragrunt docs (Gruntwork) | Official docs | https://terragrunt.gruntwork.io/docs |
| **OTel** | OpenTelemetry — OTLP exporter configuration spec (the env vars both CLIs delegate to) | Official spec | https://opentelemetry.io/docs/specs/otel/protocol/exporter/ |
| **Infisical** | Infisical blog — secrets management (vendor; read product comparisons as marketing) | Vendor blog | [infisical.com/blog](https://infisical.com/blog) |

> 📌 **TUR** targets Terraform ~1.1. Concepts remain the best available; verify newer syntax
> (`terraform test`, `import`/`removed` blocks, Stacks) against **HCDocs**.

See [version & certification facts](../research-cache/version-facts.md) for current tooling versions and exam details.

## Code-quality toolchain

The tools **TID Ch7** builds its makefile around, and the ones **A3**/**A5** wire into a pipeline. Current
releases and their OpenTofu support are tracked in
[CI / quality tooling versions](../research-cache/ci-quality-tooling-versions.md) — every version printed
in the book has moved.

| Tool | What it does | URL |
|---|---|---|
| **TFLint** | Terraform linter; plugin-based, cloud rulesets for AWS/GCP/Azure, plus an OPA plugin for custom Rego rules | https://github.com/terraform-linters/tflint |
| **Checkov** | Local IaC security scanner; custom policies in plain YAML, loadable from a shared Git repo | https://www.checkov.io/ |
| **Trivy** | Security scanner that absorbed the deprecated **tfsec**; covers more providers than Checkov | https://trivy.dev/ |
| **terraform-docs** | Generates input/output tables from the configuration; `inject` mode edits a README in place, `--output-check` gates staleness | https://github.com/terraform-docs/terraform-docs |
| **tenv** | Per-project version manager for Terraform, OpenTofu **and** Terragrunt; successor to `tfenv` | https://github.com/tofuutils/tenv |
| **pre-commit** | Framework for declaring Git pre-commit hooks in a config file | https://pre-commit.com/ |
| `pre-commit-terraform` | Published hooks for every tool above (Babenko); OpenTofu fork: `tofuutils/pre-commit-opentofu` | https://github.com/antonbabenko/pre-commit-terraform |
| **Cookiecutter** | Jinja2-templated project generator; bootstraps a module with the whole toolchain pre-configured. (TID Ch7 cites `www.cookiecutter.io`, which does not resolve) | https://cookiecutter.readthedocs.io/en/stable/ |
| **Terratest** | Go-based Terraform testing framework (Gruntwork); the alternative to native `terraform test` | https://terratest.gruntwork.io/ |
