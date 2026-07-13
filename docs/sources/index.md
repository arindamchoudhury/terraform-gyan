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
| [Meta-arguments (index)](terraform-docs/tf-meta-arguments.md) | documentation | 2026-07-10 | meta-arguments, count, for_each, depends_on, lifecycle, provider, providers, ephemeral | [url](https://developer.hashicorp.com/terraform/language/meta-arguments) |
| [`depends_on` reference](terraform-docs/tf-meta-depends-on.md) | documentation | 2026-07-10 | meta-arguments, depends_on, hidden-dependencies, dag, known-after-apply, check-blocks | [url](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on) |
| [`terraform graph` command](terraform-docs/tf-cmd-graph.md) | documentation | 2026-07-10 | cli, graph, dag, dot, graphviz, cycles | [url](https://developer.hashicorp.com/terraform/cli/commands/graph) |
| [`terraform_data` resource reference](terraform-docs/tf-terraform-data.md) | documentation | 2026-07-10 | terraform_data, built-in-resources, null_resource, replace_triggered_by, triggers_replace, provisioners | [url](https://developer.hashicorp.com/terraform/language/resources/terraform-data) |
| [The `terraform_remote_state` data source](terraform-docs/tf-remote-state-data.md) | documentation | 2026-07-10 | state, remote-state, terraform_remote_state, tfe_outputs, data-sharing, sensitive-data | [url](https://developer.hashicorp.com/terraform/language/state/remote-state-data) |
| [Destroy a resource](terraform-docs/tf-destroy-resource.md) | documentation | 2026-07-10 | destroy, removed-block, destroy-time-provisioner, target | [url](https://developer.hashicorp.com/terraform/language/resources/destroy) |
| [`removed` block reference](terraform-docs/tf-block-removed.md) | documentation | 2026-07-10 | removed-block, destroy, state, refactoring, version-drift | [url](https://developer.hashicorp.com/terraform/language/block/removed) |
| [`resource` block reference](terraform-docs/tf-block-resource.md) | documentation | 2026-07-10 | resource-block, lifecycle, action_trigger, actions, provisioners, connection, docs-bug | [url](https://developer.hashicorp.com/terraform/language/block/resource) |
| [Input Variables (Use variables)](terraform-docs/tf-input-variables.md) | documentation | 2026-07-13 | variables, tfvars, precedence, TF_VAR, sensitive, ephemeral, validation | [url](https://developer.hashicorp.com/terraform/language/values/variables) |
| [`variable` block reference](terraform-docs/tf-block-variable.md) | documentation | 2026-07-13 | variable-block, type-constraint, validation, sensitive, ephemeral, const, deprecated, nullable | [url](https://developer.hashicorp.com/terraform/language/block/variable) |
| [Manage sensitive data](terraform-docs/tf-manage-sensitive-data.md) | documentation | 2026-07-13 | secrets, sensitive, ephemeral, write-only, state-security, encryption | [url](https://developer.hashicorp.com/terraform/language/manage-sensitive-data) |
| [Local Values (Use locals)](terraform-docs/tf-locals.md) | documentation | 2026-07-13 | locals, expressions, dry, naming, module-scope | [url](https://developer.hashicorp.com/terraform/language/values/locals) |
| [`locals` block reference](terraform-docs/tf-block-locals.md) | documentation | 2026-07-13 | locals-block, expressions, identifiers, multiple-blocks, module-scope | [url](https://developer.hashicorp.com/terraform/language/block/locals) |

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
| [Define resources (Configuration Language)](terraform-tutorials/tut-resource.md) | documentation | 2026-07-13 | resources, arguments, attributes, meta-arguments, implicit-dependency, security-group | [url](https://developer.hashicorp.com/terraform/tutorials/configuration-language/resource) |
| [Customize with variables (Configuration Language)](terraform-tutorials/tut-variables.md) | documentation | 2026-07-13 | variables, types, list, map, tfvars, validation, interpolation, terraform-console, slice, regexall | [url](https://developer.hashicorp.com/terraform/tutorials/configuration-language/variables) |
| [Simplify with locals (Configuration Language)](terraform-tutorials/tut-locals.md) | documentation | 2026-07-13 | locals, merge, dynamic-expressions, resource-tags, dry | [url](https://developer.hashicorp.com/terraform/tutorials/configuration-language/locals) |

## 4. Terraform Registry

| Title | Type | Added | Tags | URL |
|---|---|---|---|---|
| [AWS Provider (overview)](terraform-registry/aws-provider.md) | documentation | 2026-07-09 | aws, provider, registry, authentication, default_tags, credentials | [url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) |
| [Google Cloud Provider (overview)](terraform-registry/google-provider.md) | documentation | 2026-07-09 | gcp, google, provider, registry, authentication, adc, impersonation | [url](https://registry.terraform.io/providers/hashicorp/google/latest/docs) |
