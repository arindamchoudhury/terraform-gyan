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
| [`count` reference](terraform-docs/tf-meta-count.md) | documentation | 2026-08-01 | meta-arguments, count, count.index, instance-addressing, conditional-creation, tuple, action-blocks | [url](https://developer.hashicorp.com/terraform/language/meta-arguments/count) |
| [`depends_on` reference](terraform-docs/tf-meta-depends-on.md) | documentation | 2026-07-10 | meta-arguments, depends_on, hidden-dependencies, dag, known-after-apply, check-blocks | [url](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on) |
| [`for_each` reference](terraform-docs/tf-meta-for-each.md) | documentation | 2026-08-01 | meta-arguments, for_each, each.key, each.value, toset, sets, chaining, sensitive-values, stacks | [url](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) |
| [`lifecycle` reference](terraform-docs/tf-meta-lifecycle.md) | documentation | 2026-08-03 | meta-arguments, lifecycle, create_before_destroy, prevent_destroy, ignore_changes, replace_triggered_by, precondition, postcondition, action_trigger, state | [url](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle) |
| [`providers` reference](terraform-docs/tf-meta-providers.md) | documentation | 2026-08-02 | meta-arguments, providers, modules, alias, configuration_aliases, inheritance, stacks | [url](https://developer.hashicorp.com/terraform/language/meta-arguments/providers) |
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
| [Output Values (Use outputs)](terraform-docs/tf-outputs.md) | documentation | 2026-07-13 | outputs, output-block, module-outputs, sensitive, ephemeral, remote-state | [url](https://developer.hashicorp.com/terraform/language/values/outputs) |
| [`output` block reference](terraform-docs/tf-block-output.md) | documentation | 2026-07-13 | output-block, type, precondition, depends_on, deprecated, sensitive, ephemeral | [url](https://developer.hashicorp.com/terraform/language/block/output) |
| [Conditional Expressions](terraform-docs/tf-conditionals.md) | documentation | 2026-07-13 | conditionals, ternary, can, self, precondition, postcondition, alltrue | [url](https://developer.hashicorp.com/terraform/language/expressions/conditionals) |
| [Expressions (section overview)](terraform-docs/tf-expressions.md) | documentation | 2026-07-14 | expressions, functions, references, console, overview | [url](https://developer.hashicorp.com/terraform/language/expressions) |
| [Types and Values](terraform-docs/tf-expr-types.md) | documentation | 2026-07-14 | types, values, primitives, collections, null, literals, type-conversion | [url](https://developer.hashicorp.com/terraform/language/expressions/types) |
| [Strings and Templates](terraform-docs/tf-expr-strings.md) | documentation | 2026-07-14 | strings, heredoc, interpolation, template-directives, escape-sequences, whitespace-strip | [url](https://developer.hashicorp.com/terraform/language/expressions/strings) |
| [References to Named Values](terraform-docs/tf-expr-references.md) | documentation | 2026-07-14 | references, named-values, resource-attributes, path, workspace, sensitive, unknown-values | [url](https://developer.hashicorp.com/terraform/language/expressions/references) |
| [Arithmetic and Logical Operators](terraform-docs/tf-expr-operators.md) | documentation | 2026-07-15 | operators, arithmetic, equality, comparison, logical, order-of-operations, type-conversion | [url](https://developer.hashicorp.com/terraform/language/expressions/operators) |
| [Function Calls](terraform-docs/tf-expr-function-calls.md) | documentation | 2026-07-15 | function-calls, built-in-functions, argument-expansion, sensitive, pure-functions, plan-time | [url](https://developer.hashicorp.com/terraform/language/expressions/function-calls) |
| [`for` Expressions](terraform-docs/tf-expr-for.md) | documentation | 2026-07-15 | for-expressions, transform, filtering, grouping, element-ordering, type-conversion | [url](https://developer.hashicorp.com/terraform/language/expressions/for) |
| [Splat Expressions](terraform-docs/tf-expr-splat.md) | documentation | 2026-07-15 | splat, for-expressions, single-value-as-list, dynamic-blocks, legacy-splat, for_each | [url](https://developer.hashicorp.com/terraform/language/expressions/splat) |
| [`dynamic` Blocks](terraform-docs/tf-expr-dynamic-blocks.md) | documentation | 2026-07-15 | dynamic-blocks, nested-blocks, for_each, iterator, multi-level-nesting, module-abstraction | [url](https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks) |
| [Type Constraints](terraform-docs/tf-expr-type-constraints.md) | documentation | 2026-07-15 | type-constraints, primitive-types, collection-types, structural-types, any, optional-attributes, type-conversion | [url](https://developer.hashicorp.com/terraform/language/expressions/type-constraints) |
| [Version Constraints](terraform-docs/tf-expr-version-constraints.md) | documentation | 2026-07-15 | version-constraints, required_version, provider-requirements, module-versions, pessimistic-operator, pre-release | [url](https://developer.hashicorp.com/terraform/language/expressions/version-constraints) |
| [Built-in Functions (catalogue)](terraform-docs/tf-functions.md) | documentation | 2026-07-15 | functions, built-in-functions, provider-defined-functions, terraform-console, stacks, function-catalogue | [url](https://developer.hashicorp.com/terraform/language/functions) |
| [Query infrastructure data (data sources)](terraform-docs/tf-data-sources.md) | documentation | 2026-07-22 | data-sources, data-block, plan-vs-apply, dependencies, custom-conditions, meta-arguments | [url](https://developer.hashicorp.com/terraform/language/data-sources) |
| [`data` block reference](terraform-docs/tf-block-data.md) | documentation | 2026-07-22 | data-sources, data-block, meta-arguments, count, for_each, depends_on, lifecycle, precondition, postcondition | [url](https://developer.hashicorp.com/terraform/language/block/data) |
| [State (overview)](terraform-docs/tf-state.md) | documentation | 2026-07-29 | state, tfstate, backends, state-locking, terraform-state-cli, json-output, import | [url](https://developer.hashicorp.com/terraform/language/state) |
| [Purpose of Terraform State](terraform-docs/tf-state-purpose.md) | documentation | 2026-07-29 | state, tfstate, dependencies, destroy-ordering, refresh, performance, state-locking, import | [url](https://developer.hashicorp.com/terraform/language/state/purpose) |
| [State Storage and Locking](terraform-docs/tf-state-backends.md) | documentation | 2026-07-29 | state, backends, state-locking, state-pull, state-push, lineage, serial, sensitive-data | [url](https://developer.hashicorp.com/terraform/language/state/backends) |
| [Refactor Terraform state](terraform-docs/tf-state-refactor.md) | documentation | 2026-07-29 | state, refactoring, splitting-state, removed-block, import-block, state-mv, state-pull, state-push | [url](https://developer.hashicorp.com/terraform/language/state/refactor) |
| [Remove a resource from state](terraform-docs/tf-state-remove.md) | documentation | 2026-07-30 | state, removed-block, destroy, state-rm, import, forget | [url](https://developer.hashicorp.com/terraform/language/state/remove) |
| [State Locking](terraform-docs/tf-state-locking.md) | documentation | 2026-07-30 | state, state-locking, lock, force-unlock, lock-id, backends | [url](https://developer.hashicorp.com/terraform/language/state/locking) |
| [Workspaces](terraform-docs/tf-state-workspaces.md) | documentation | 2026-07-30 | state, workspaces, terraform-workspace, backends, terraform.workspace, hcp-workspaces | [url](https://developer.hashicorp.com/terraform/language/state/workspaces) |
| [Backend block configuration overview](terraform-docs/tf-backend-configure.md) | documentation | 2026-07-30 | backend, backend-block, partial-configuration, backend-config, tfbackend, init, migrate-state, credentials | [url](https://developer.hashicorp.com/terraform/language/backend) |
| [`local` backend](terraform-docs/tf-backend-local.md) | documentation | 2026-07-30 | backend, local-backend, workspace-dir, state-flag, backup, legacy-flags, terraform_remote_state | [url](https://developer.hashicorp.com/terraform/language/backend/local) |
| [Remote State](terraform-docs/tf-state-remote.md) | documentation | 2026-07-30 | state, remote-state, delegation, locking, hcp-terraform, consul, decomposition | [url](https://developer.hashicorp.com/terraform/language/state/remote) |
| [`terraform refresh` command](terraform-docs/tf-cmd-refresh.md) | documentation | 2026-07-30 | cli, refresh, refresh-only, deprecated, drift, state, auto-approve | [url](https://developer.hashicorp.com/terraform/cli/commands/refresh) |
| [Inspect Infrastructure Commands Overview](terraform-docs/tf-cli-inspect.md) | documentation | 2026-07-30 | cli, inspection, graph, output, show, state-list, state-show, json, tool-integration | [url](https://developer.hashicorp.com/terraform/cli/inspect) |
| [`terraform output` command](terraform-docs/tf-cmd-output.md) | documentation | 2026-07-30 | cli, output, json, raw, sensitive, ephemeral, root-module, automation | [url](https://developer.hashicorp.com/terraform/cli/commands/output) |
| [`terraform show` command](terraform-docs/tf-cmd-show.md) | documentation | 2026-07-30 | cli, show, json, plan-file, state, schema-version, sensitive | [url](https://developer.hashicorp.com/terraform/cli/commands/show) |
| [`terraform state list` command](terraform-docs/tf-cmd-state-list.md) | documentation | 2026-07-30 | cli, state-list, resource-addressing, filtering, id-lookup, inspection | [url](https://developer.hashicorp.com/terraform/cli/commands/state/list) |
| [`terraform state show` command](terraform-docs/tf-cmd-state-show.md) | documentation | 2026-07-30 | cli, state-show, resource-addressing, for-each, quoting, powershell, human-readable | [url](https://developer.hashicorp.com/terraform/cli/commands/state/show) |
| [Modules overview (Configuration Language)](terraform-docs/tf-modules.md) | documentation | 2026-08-08 | modules, root-module, child-module, module-sources, registry, module-workflow | [url](https://developer.hashicorp.com/terraform/language/modules) |
| [Use modules in your configuration (Configuration Language)](terraform-docs/tf-modules-configuration.md) | documentation | 2026-08-08 | modules, module-block, source, version, git-ref, shallow-clone, const, removed-block, replace | [url](https://developer.hashicorp.com/terraform/language/modules/configuration) |
| [Creating Modules (Configuration Language)](terraform-docs/tf-modules-develop.md) | documentation | 2026-08-08 | modules, module-design, abstraction, composition, module-structure, refactoring, no-code-modules | [url](https://developer.hashicorp.com/terraform/language/modules/develop) |
| [Standard Module Structure (Configuration Language)](terraform-docs/tf-modules-structure.md) | documentation | 2026-08-08 | modules, module-structure, readme, license, nested-modules, examples, registry, conventions | [url](https://developer.hashicorp.com/terraform/language/modules/develop/structure) |
| [Providers Within Modules (Configuration Language)](terraform-docs/tf-modules-providers.md) | documentation | 2026-08-08 | modules, providers, provider-inheritance, configuration_aliases, providers-argument, required_providers, legacy-modules, destroy-ordering | [url](https://developer.hashicorp.com/terraform/language/modules/develop/providers) |
| [Module Composition (Configuration Language)](terraform-docs/tf-modules-composition.md) | documentation | 2026-08-08 | modules, composition, dependency-inversion, object-types, structural-typing, preconditions, multi-cloud, data-only-modules | [url](https://developer.hashicorp.com/terraform/language/modules/develop/composition) |
| [Publishing Modules (Configuration Language)](terraform-docs/tf-modules-publish.md) | documentation | 2026-08-08 | modules, publishing, registry, versioning, module-sources, standard-module-structure | [url](https://developer.hashicorp.com/terraform/language/modules/develop/publish) |
| [Refactor modules (Configuration Language)](terraform-docs/tf-modules-refactoring.md) | documentation | 2026-08-08 | moved-block, refactoring, resource-addresses, instance-keys, count, for_each, module-split, shim-module | [url](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) |
| [`module` block reference (Configuration Language)](terraform-docs/tf-block-module.md) | documentation | 2026-08-08 | module-block, source, version, module-sources, subdirectory, depth, localterraform, ignore_nested_deprecations | [url](https://developer.hashicorp.com/terraform/language/block/module) |

## 2. OpenTofu Docs

| Title | Type | Added | Tags | URL |
|---|---|---|---|---|
| [Provider `for_each`](opentofu-docs/ot-provider-for-each.md) | documentation | 2026-07-03 | opentofu, providers, for_each | [url](https://opentofu.org/docs/language/providers/configuration/) |
| [Early variable eval in backend config](opentofu-docs/ot-early-eval-backend.md) | documentation | 2026-07-03 | opentofu, backend, early-evaluation | [url](https://opentofu.org/docs/language/settings/backends/configuration/) |
| [`-exclude` flag](opentofu-docs/ot-exclude-flag.md) | documentation | 2026-07-03 | opentofu, cli, targeting | [url](https://opentofu.org/docs/cli/commands/plan/) |
| [Dynamic `prevent_destroy`](opentofu-docs/ot-dynamic-prevent-destroy.md) | documentation | 2026-07-03 | opentofu, lifecycle, prevent_destroy | [url](https://opentofu.org/blog/opentofu-1-12-0/) |
| [Dependency Lock File](opentofu-docs/ot-dependency-lock.md) | documentation | 2026-07-10 | opentofu, lock-file, checksums, hashing-schemes, h1, zh | [url](https://opentofu.org/docs/language/files/dependency-lock/) |
| [OpenTelemetry Tracing](opentofu-docs/ot-otel-tracing.md) | documentation | 2026-08-15 | opentofu, observability, opentelemetry, otel, tracing, performance, debugging | [url](https://opentofu.org/docs/internals/tracing/) |

## 3. HashiCorp Terraform Tutorials

| Title | Type | Added | Tags | URL |
|---|---|---|---|---|
| [Install Terraform](terraform-tutorials/tf-install-cli.md) | documentation | 2026-07-04 | install, cli, setup, getting-started | [url](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) |
| [Create infrastructure](terraform-tutorials/tf-aws-create.md) | documentation | 2026-07-04 | first-project, provider, resource, data-source, init, apply, state | [url](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create) |
| [Manage infrastructure](terraform-tutorials/tf-aws-manage.md) | documentation | 2026-07-07 | variables, outputs, modules, plan-symbols, replace, vpc | [url](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-manage) |
| [Destroy infrastructure](terraform-tutorials/tf-aws-destroy.md) | documentation | 2026-07-07 | destroy, remove-resource, teardown, plan-symbols | [url](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-destroy) |
| [Define resources (Configuration Language)](terraform-tutorials/tut-resource.md) | documentation | 2026-07-13 | resources, arguments, attributes, meta-arguments, implicit-dependency, security-group | [url](https://developer.hashicorp.com/terraform/tutorials/configuration-language/resource) |
| [Customize with variables (Configuration Language)](terraform-tutorials/tut-variables.md) | documentation | 2026-07-13 | variables, types, list, map, tfvars, validation, interpolation, terraform-console, slice, regexall | [url](https://developer.hashicorp.com/terraform/tutorials/configuration-language/variables) |
| [Query data sources (Configuration Language)](terraform-tutorials/tut-data-sources.md) | documentation | 2026-07-22 | data-sources, aws_availability_zones, aws_region, aws_ami, terraform_remote_state, two-workspace | [url](https://developer.hashicorp.com/terraform/tutorials/configuration-language/data-sources) |
| [Simplify with locals (Configuration Language)](terraform-tutorials/tut-locals.md) | documentation | 2026-07-13 | locals, merge, dynamic-expressions, resource-tags, dry | [url](https://developer.hashicorp.com/terraform/tutorials/configuration-language/locals) |
| [Output data (Configuration Language)](terraform-tutorials/tut-outputs.md) | documentation | 2026-07-13 | outputs, terraform-output, sensitive, json, raw, state | [url](https://developer.hashicorp.com/terraform/tutorials/configuration-language/outputs) |
| [Create resource dependencies (Configuration Language)](terraform-tutorials/tut-dependencies.md) | documentation | 2026-08-01 | dependencies, depends_on, implicit-dependencies, explicit-dependencies, dag, destroy-order, modules | [url](https://developer.hashicorp.com/terraform/tutorials/configuration-language/dependencies) |
| [Manage similar resources with `count` (Configuration Language)](terraform-tutorials/tut-count.md) | documentation | 2026-08-01 | count, count.index, modulo, splat, legacy-splat, refactoring, moved-block, scaling | [url](https://developer.hashicorp.com/terraform/tutorials/configuration-language/count) |
| [Manage resource lifecycle (State)](terraform-tutorials/tut-resource-lifecycle.md) | documentation | 2026-08-03 | lifecycle, prevent_destroy, create_before_destroy, ignore_changes, drift, deposed, plan-symbols, state | [url](https://developer.hashicorp.com/terraform/tutorials/state/resource-lifecycle) |
| [Manage similar resources with `for_each` (Configuration Language)](terraform-tutorials/tut-for-each.md) | documentation | 2026-08-01 | for_each, each.key, each.value, module-wrapping, count-and-for-each, provider-inheritance, for-expressions | [url](https://developer.hashicorp.com/terraform/tutorials/configuration-language/for-each) |
| [Modules overview (Modules)](terraform-tutorials/tut-module.md) | documentation | 2026-08-08 | modules, root-module, child-module, encapsulation, re-use, module-sources, best-practices | [url](https://developer.hashicorp.com/terraform/tutorials/modules/module) |
| [Use registry modules in configuration (Modules)](terraform-tutorials/tut-module-use.md) | documentation | 2026-08-08 | modules, module-block, source, version, module-outputs, count-on-module, terraform-get, registry | [url](https://developer.hashicorp.com/terraform/tutorials/modules/module-use) |
| [Build and use a local module (Modules)](terraform-tutorials/tut-module-create.md) | documentation | 2026-08-08 | modules, local-modules, module-authoring, module-structure, provider-inheritance, module-outputs, terraform-get, s3 | [url](https://developer.hashicorp.com/terraform/tutorials/modules/module-create) |
| [Customize modules with object attributes (Modules)](terraform-tutorials/tut-module-object-attributes.md) | documentation | 2026-08-08 | modules, object-attributes, optional, list-of-objects, dynamic-blocks, module-api, cors, s3 | [url](https://developer.hashicorp.com/terraform/tutorials/modules/module-object-attributes) |
| [Share modules in the private registry (Modules)](terraform-tutorials/tut-module-private-registry-share.md) | documentation | 2026-08-08 | modules, private-registry, hcp-terraform, publishing, semver, vcs, tag-based-publishing, branch-based-publishing | [url](https://developer.hashicorp.com/terraform/tutorials/modules/module-private-registry-share) |
| [Add public providers and modules to your private registry (Modules)](terraform-tutorials/tut-private-registry-add.md) | documentation | 2026-08-08 | modules, providers, private-registry, hcp-terraform, curation, no-code-modules, governance | [url](https://developer.hashicorp.com/terraform/tutorials/modules/private-registry-add) |
| [Refactor monolithic Terraform configuration (Modules)](terraform-tutorials/tut-organize-configuration.md) | documentation | 2026-08-08 | code-organization, monolith, state-separation, workspaces, directories, hidden-dependency, blast-radius, multi-environment | [url](https://developer.hashicorp.com/terraform/tutorials/modules/organize-configuration) |
| [Module creation — recommended pattern (Modules)](terraform-tutorials/tut-pattern-module-creation.md) | documentation | 2026-08-08 | modules, module-design, scoping, encapsulation, privileges, volatility, mvp, nested-modules, collaboration, governance | [url](https://developer.hashicorp.com/terraform/tutorials/modules/pattern-module-creation) |
| [Use configuration to move resources (Modules)](terraform-tutorials/tut-move-config.md) | documentation | 2026-08-08 | moved-block, refactoring, state, module-extraction, resource-addresses, rename, terraform-1.3 | [url](https://developer.hashicorp.com/terraform/tutorials/modules/move-config) |
| [Create and use no-code modules (Modules)](terraform-tutorials/tut-no-code-provisioning.md) | documentation | 2026-08-08 | no-code-modules, hcp-terraform, self-service, platform-engineering, ephemeral-resources, write-only-arguments, variable-sets, module-versioning | [url](https://developer.hashicorp.com/terraform/tutorials/modules/no-code-provisioning) |
| [Migrate state to HCP Terraform (State)](terraform-tutorials/tut-cloud-migrate.md) | documentation | 2026-08-18 | state, migration, hcp-terraform, cloud-block, terraform-login, remote-operations, workspaces, init | [url](https://developer.hashicorp.com/terraform/tutorials/state/cloud-migrate) |

## 4. Terraform Registry

| Title | Type | Added | Tags | URL |
|---|---|---|---|---|
| [AWS Provider (overview)](terraform-registry/aws-provider.md) | documentation | 2026-07-09 | aws, provider, registry, authentication, default_tags, credentials | [url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) |
| [Google Cloud Provider (overview)](terraform-registry/google-provider.md) | documentation | 2026-07-09 | gcp, google, provider, registry, authentication, adc, impersonation | [url](https://registry.terraform.io/providers/hashicorp/google/latest/docs) |

## 5. Infisical Blog

Vendor blog — Terraform mechanics are checkable, product comparisons are marketing. See the [course overview](infisical-blog/index.md).

| Title | Type | Added | Tags | URL |
|---|---|---|---|---|
| [A Guide to Terraform Secrets Management](infisical-blog/infisical-terraform-secrets.md) | blog | 2026-07-17 | secrets, state, ephemeral, write-only, oidc, dynamic-secrets, rotation, sops | [url](https://infisical.com/blog/terraform-secrets-management) |

## 6. Tools

Tools that sit next to Terraform rather than inside it. See the [course overview](tools/index.md).

| Title | Type | Added | Tags | URL |
|---|---|---|---|---|
| [pyinfra](tools/pyinfra.md) | repository | 2026-07-17 | config-management, ansible-alternative, provisioners, terraform-output, inventory, a1 | [url](https://github.com/pyinfra-dev/pyinfra) |

## 7. Terraform Best Practices

Anton Babenko's community book at [terraform-best-practices.com](https://www.terraform-best-practices.com/). Not a HashiCorp publication — see the [course overview](terraform-best-practices/index.md) for the caveats.

| Title | Type | Added | Tags | URL |
|---|---|---|---|---|
| [Code styling](terraform-best-practices/code-styling.md) | documentation | 2026-08-13 | style, formatting, fmt, pre-commit, editorconfig, terraform-docs, comments | [url](https://www.terraform-best-practices.com/code-styling) |
