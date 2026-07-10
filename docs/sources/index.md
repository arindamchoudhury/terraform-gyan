# Sources

Log of all captured sources, organised by course.

## 1. HashiCorp Terraform Docs

| Title | Type | Added | Tags | URL |
|---|---|---|---|---|
| [What is Terraform? (Intro)](terraform-docs/terraform-intro.md) | documentation | 2026-07-02 | iac, providers, workflow, state, modules | [url](https://developer.hashicorp.com/terraform/intro) |
| [Terraform Use Cases](terraform-docs/terraform-use-cases.md) | documentation | 2026-07-03 | iac, use-cases, sentinel, kubernetes, hcp-terraform | [url](https://developer.hashicorp.com/terraform/intro/use-cases) |
| [Provider Requirements](terraform-docs/provider-requirements.md) | documentation | 2026-07-05 | providers, required_providers, source-address, version-constraints, lock-file | [url](https://developer.hashicorp.com/terraform/language/providers/requirements) |
| [Terraform CLI Overview (command index)](terraform-docs/tf-cli-commands.md) | documentation | 2026-07-07 | cli, commands, reference, chdir, autocomplete, checkpoint | [url](https://developer.hashicorp.com/terraform/cli/commands) |
| [Configuration Syntax](terraform-docs/tf-config-syntax.md) | documentation | 2026-07-08 | hcl, syntax, arguments, blocks, identifiers, comments | [url](https://developer.hashicorp.com/terraform/language/syntax/configuration) |
| [Style Guide](terraform-docs/tf-style-guide.md) | documentation | 2026-07-08 | style, formatting, fmt, naming, file-layout, version-pinning, modules | [url](https://developer.hashicorp.com/terraform/language/style) |
| [Create and manage resources (overview)](terraform-docs/tf-resources.md) | documentation | 2026-07-09 | resources, resource-block, meta-arguments, apply, workflow, data-sources | [url](https://developer.hashicorp.com/terraform/language/resources) |
| [Providers (language overview)](terraform-docs/tf-providers.md) | documentation | 2026-07-09 | providers, registry, provider-tiers, plugin-cache, netrc, private-registry | [url](https://developer.hashicorp.com/terraform/language/providers) |
| [Configure a resource](terraform-docs/tf-configure-resource.md) | documentation | 2026-07-09 | resources, timeouts, meta-arguments, terraform_data, local-only-resources, dependencies | [url](https://developer.hashicorp.com/terraform/language/resources/configure) |
| [Dependency Lock File](terraform-docs/tf-dependency-lock.md) | documentation | 2026-07-10 | lock-file, providers, checksums, trust-on-first-use, hashing-schemes, providers-lock | [url](https://developer.hashicorp.com/terraform/language/files/dependency-lock) |
| [`provider` block reference](terraform-docs/tf-provider-block.md) | documentation | 2026-07-10 | providers, provider-block, alias, configuration_aliases, default-configuration, modules | [url](https://developer.hashicorp.com/terraform/language/block/provider) |

## 2. OpenTofu Docs

| Title | Type | Added | Tags | URL |
|---|---|---|---|---|
| [Provider `for_each`](opentofu-docs/ot-provider-for-each.md) | documentation | 2026-07-03 | opentofu, providers, for_each | [url](https://opentofu.org/docs/language/providers/configuration/) |
| [Early variable eval in backend config](opentofu-docs/ot-early-eval-backend.md) | documentation | 2026-07-03 | opentofu, backend, early-evaluation | [url](https://opentofu.org/docs/language/settings/backends/configuration/) |
| [`-exclude` flag](opentofu-docs/ot-exclude-flag.md) | documentation | 2026-07-03 | opentofu, cli, targeting | [url](https://opentofu.org/docs/cli/commands/plan/) |
| [Dynamic `prevent_destroy`](opentofu-docs/ot-dynamic-prevent-destroy.md) | documentation | 2026-07-03 | opentofu, lifecycle, prevent_destroy | [url](https://opentofu.org/blog/opentofu-1-12-0/) |
| [Dependency Lock File](opentofu-docs/ot-dependency-lock.md) | documentation | 2026-07-10 | opentofu, lock-file, checksums, hashing-schemes, h1, zh | [url](https://opentofu.org/docs/language/files/dependency-lock/) |

## 3. HashiCorp Terraform Tutorials

| Title | Type | Added | Tags | URL |
|---|---|---|---|---|
| [Install Terraform](terraform-tutorials/tf-install-cli.md) | documentation | 2026-07-04 | install, cli, setup, getting-started | [url](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) |
| [Create infrastructure](terraform-tutorials/tf-aws-create.md) | documentation | 2026-07-04 | first-project, provider, resource, data-source, init, apply, state | [url](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create) |
| [Manage infrastructure](terraform-tutorials/tf-aws-manage.md) | documentation | 2026-07-07 | variables, outputs, modules, plan-symbols, replace, vpc | [url](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-manage) |
| [Destroy infrastructure](terraform-tutorials/tf-aws-destroy.md) | documentation | 2026-07-07 | destroy, remove-resource, teardown, plan-symbols | [url](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-destroy) |

## 4. Terraform Registry

| Title | Type | Added | Tags | URL |
|---|---|---|---|---|
| [AWS Provider (overview)](terraform-registry/aws-provider.md) | documentation | 2026-07-09 | aws, provider, registry, authentication, default_tags, credentials | [url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) |
| [Google Cloud Provider (overview)](terraform-registry/google-provider.md) | documentation | 2026-07-09 | gcp, google, provider, registry, authentication, adc, impersonation | [url](https://registry.terraform.io/providers/hashicorp/google/latest/docs) |
