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

## Provider development

What **TID Ch12** builds on, and what **E1** needs. Versions checked 2026-08-16.

| Tool / doc | What it is | URL |
|---|---|---|
| **Plugin Framework** | The current provider SDK (`v1.19.0`, 2026-03-10); protocol 6, Go 1.25+ | https://developer.hashicorp.com/terraform/plugin/framework |
| **Plugin Testing** | `terraform-plugin-testing` (`v1.16.0`, 2026-04-23); `resource.Test`, `resource.UnitTest`, and the newer `statecheck`/`knownvalue` assertions | https://developer.hashicorp.com/terraform/plugin/testing |
| **Scaffolding template** | The repository TID Ch12 clones to start a provider; carries the release workflow, `.goreleaser.yml` and `tools/tools.go` | https://github.com/hashicorp/terraform-provider-scaffolding-framework |
| **`tfplugindocs`** | Generates provider docs from schemas and `examples/` | https://github.com/hashicorp/terraform-plugin-docs |
| **Publishing (Terraform)** | Signing-key registration and provider publication on the Terraform Registry; RSA/DSA keys only, no ECC | https://developer.hashicorp.com/terraform/registry/providers/publishing |
| **Publishing (OpenTofu)** | Provider and signing-key submissions, **via the GitHub issue forms only** | https://github.com/opentofu/registry |
| **Mastodon provider** | TID Ch12's finished project — the reference when a listing looks wrong | https://github.com/TerraformInDepth/terraform-provider-mastodon |
| **corefunc** | The book's example of a functions-only provider — "utilities that should have been Terraform core functions", built on the Plugin Framework, also usable as a Go library. Community-maintained (northwood-labs), not HashiCorp | https://github.com/northwood-labs/terraform-provider-corefunc |

## Secrets management

The tools **TUR Ch6** names, with what they are today. Versions checked 2026-08-21.

| Tool / doc | What it is | URL |
|---|---|---|
| **Manage sensitive data** | The HashiCorp umbrella page: hide vs omit vs both, and the version matrix for `sensitive` / ephemeral / write-only | https://developer.hashicorp.com/terraform/language/manage-sensitive-data |
| **Write-only arguments** | The `_wo` / `_wo_version` reference; the mechanism that closed the plaintext-in-state problem | https://developer.hashicorp.com/terraform/language/resources/ephemeral/write-only |
| **Dynamic provider credentials** | HCP Terraform mints a workload identity token per run and exchanges it for temporary AWS/GCP/Azure/Kubernetes/Vault/HCP credentials | https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials |
| **sops** | File encryption with a KMS or `age` key, editable in place; left Mozilla for the CNCF (Sandbox, 2023-05-17), now `v3.13.3` | https://github.com/getsops/sops |
| `carlpett/sops` provider | The Terraform side of sops; **v1.3.0 added an ephemeral resource**, so decrypted values need not enter state. `v1.4.1` current | https://github.com/carlpett/terraform-provider-sops |
| **aws-vault** | Stores AWS keys in the OS keychain and hands commands temporary STS credentials. `99designs/aws-vault` is abandoned; the maintained fork is ByteNess (`v7.13.5`) | https://github.com/ByteNess/aws-vault |
| **1Password CLI** | `op item get … --fields label=…` and `op read "op://vault/item/field"`; the book's `op get item` calls are v1 syntax | https://www.1password.dev/cli/reference/ |
| **OpenBao** | MPL-2.0 fork of Vault under LF Projects / OpenSSF, after Vault's relicensing. `v2.6.2` | https://github.com/openbao/openbao |
| **AWS Secrets Manager pricing** | $0.40 per secret per month, $0.05 per 10,000 API calls — the numbers TUR Ch6 quotes, still exact | https://aws.amazon.com/secrets-manager/pricing/ |
| **AWS KMS pricing** | $1/month per customer managed key, $0.03 per 10,000 requests | https://aws.amazon.com/kms/pricing/ |
| **GitHub OIDC in AWS** | Creating the IAM OIDC identity provider; thumbprints are now the fallback for IdPs outside AWS's trusted-CA library | https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_create_oidc.html |
| **EC2 instance metadata** | The IMDSv1 vs IMDSv2 request forms, and what a token-less GET returns when IMDSv2 is required | https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instancedata-data-retrieval.html |

## Kubernetes & EKS with Terraform

What **TUR Ch7** builds on, with current status. Versions checked 2026-08-21; details in [multi-provider facts](../research-cache/multi-provider-facts.md).

| Tool / doc | What it is | URL |
|---|---|---|
| **Kubernetes provider** | Now on **3.x** (`v3.2.1`); 3.0.0 deprecated the unversioned resource names in favour of `_v1` | https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs |
| **Kubernetes provider — exec plugins** | The documented way to feed short-lived cloud tokens (`aws eks get-token`); never mix with `token` | https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs#exec-plugins |
| **EKS version lifecycle** | Standard/extended support lists, the release calendar, and the 14+12-month rule | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |
| **`aws_eks_cluster`** | Access entries, EKS Auto Mode, `bootstrap_self_managed_addons`, `upgrade_policy` | https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster |
| **Stacks — declare providers** | Provider `for_each` in Stacks, and which providers support deferred changes | https://developer.hashicorp.com/terraform/language/stacks/component/declare-providers |
| **Stacks — EKS deferred-changes tutorial** | Deploys a cluster and an app in one Stack; the official answer to TUR Ch7's ordering hack | https://developer.hashicorp.com/terraform/tutorials/cloud/stacks-eks-deferred |
| **Multi-Cloud is the Worst Practice** | Corey Quinn, Last Week in AWS, 2020-08-05 — the footnote TUR Ch7 hangs its multicloud refusal on | https://www.lastweekinaws.com/blog/multi-cloud-is-the-worst-practice/ |

## Testing

What **TUR Ch9** and **TID Ch9** build on. Status checked 2026-08-21; version detail in [terraform-testing](../research-cache/terraform-testing.md) and [terratest-facts](../research-cache/terratest-facts.md).

| Tool / doc | What it is | URL |
|---|---|---|
| **`terraform test`** | The native framework TUR Ch9 predates: HCL `.tftest.hcl` files, `run` blocks, mocks. GA in 1.6.0 | https://developer.hashicorp.com/terraform/language/tests |
| **Mocking in tests** | `mock_provider`, `override_resource`, `override_data` — apply-mode tests with no cloud account | https://developer.hashicorp.com/terraform/language/tests/mocking |
| **Terratest** | The Go library the chapter teaches. Now **v1.0.1**, with v2 betas splitting it into 16 modules; bare `terraform.Apply`-style calls are deprecated in favour of `…Context` forms | https://github.com/gruntwork-io/terratest |
| **cloud-nuke** | Gruntwork's sandbox cleaner; the `--older-than 48h` cron the chapter recommends | https://github.com/gruntwork-io/cloud-nuke |
| **aws-nuke** | `rebuy-de/aws-nuke` is archived (2024-10-15); the maintained fork is ekristen's | https://github.com/ekristen/aws-nuke |
| **Open Policy Agent** | The Rego policy engine behind the chapter's plan-testing example (`terraform show -json` → `opa eval`) | https://www.openpolicyagent.org/ |
| **Goss** | YAML-defined server validation; the liveliest of the three server-testing tools the chapter compares | https://github.com/goss-org/goss |
| **Chef InSpec** | Still Apache-2.0 at the source, but **5.0+ requires accepting the Chef EULA** and a license ID to run | https://github.com/inspec/inspec |
