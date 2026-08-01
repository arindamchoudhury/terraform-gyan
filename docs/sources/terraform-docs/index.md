# HashiCorp Terraform Docs

Notes captured from the official Terraform documentation at [developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform).

**Source type:** official documentation
**Version tracked:** v1.15.x (latest at first capture)
**Nav mirrored from:** rung 1 — the site's `__NEXT_DATA__` payload (`props.pageProps.layoutProps.sidebarNavDataLevels`). Breadcrumbs on this site disagree with the sidebar and must not be used for grouping.

## Pages

| Page | Added | File |
|---|---|---|
| What is Terraform? (Intro / Overview) | 2026-07-02 | [terraform-intro](terraform-intro.md) |
| Terraform Use Cases | 2026-07-03 | [terraform-use-cases](terraform-use-cases.md) |
| Provider Requirements | 2026-07-05 | [provider-requirements](provider-requirements.md) |
| Terraform CLI Overview (command index) | 2026-07-07 | [tf-cli-commands](tf-cli-commands.md) |
| Configuration Syntax (HCL native syntax) | 2026-07-08 | [tf-config-syntax](tf-config-syntax.md) |
| Style Guide | 2026-07-08 | [tf-style-guide](tf-style-guide.md) |
| Create and manage resources (overview) | 2026-07-09 | [tf-resources](tf-resources.md) |
| Providers (language overview) | 2026-07-09 | [tf-providers](tf-providers.md) |
| Configure a resource | 2026-07-09 | [tf-configure-resource](tf-configure-resource.md) |
| Dependency Lock File | 2026-07-10 | [tf-dependency-lock](tf-dependency-lock.md) |
| `provider` block reference | 2026-07-10 | [tf-provider-block](tf-provider-block.md) |
| Meta-arguments (index) | 2026-07-10 | [tf-meta-arguments](tf-meta-arguments.md) |
| `count` reference | 2026-08-01 | [tf-meta-count](tf-meta-count.md) |
| `depends_on` reference | 2026-07-10 | [tf-meta-depends-on](tf-meta-depends-on.md) |
| `terraform graph` command | 2026-07-10 | [tf-cmd-graph](tf-cmd-graph.md) |
| `terraform_data` resource reference | 2026-07-10 | [tf-terraform-data](tf-terraform-data.md) |
| The `terraform_remote_state` data source | 2026-07-10 | [tf-remote-state-data](tf-remote-state-data.md) |
| Destroy a resource | 2026-07-10 | [tf-destroy-resource](tf-destroy-resource.md) |
| `removed` block reference | 2026-07-10 | [tf-block-removed](tf-block-removed.md) |
| `resource` block reference | 2026-07-10 | [tf-block-resource](tf-block-resource.md) |
| Input Variables (Use variables) | 2026-07-13 | [tf-input-variables](tf-input-variables.md) |
| `variable` block reference | 2026-07-13 | [tf-block-variable](tf-block-variable.md) |
| Manage sensitive data | 2026-07-13 | [tf-manage-sensitive-data](tf-manage-sensitive-data.md) |
| Local Values (Use locals) | 2026-07-13 | [tf-locals](tf-locals.md) |
| `locals` block reference | 2026-07-13 | [tf-block-locals](tf-block-locals.md) |
| Output Values (Use outputs) | 2026-07-13 | [tf-outputs](tf-outputs.md) |
| `output` block reference | 2026-07-13 | [tf-block-output](tf-block-output.md) |
| Conditional Expressions | 2026-07-13 | [tf-conditionals](tf-conditionals.md) |
| Expressions (section overview) | 2026-07-14 | [tf-expressions](tf-expressions.md) |
| Types and Values | 2026-07-14 | [tf-expr-types](tf-expr-types.md) |
| Strings and Templates | 2026-07-14 | [tf-expr-strings](tf-expr-strings.md) |
| References to Named Values | 2026-07-14 | [tf-expr-references](tf-expr-references.md) |
| Arithmetic and Logical Operators | 2026-07-15 | [tf-expr-operators](tf-expr-operators.md) |
| Function Calls | 2026-07-15 | [tf-expr-function-calls](tf-expr-function-calls.md) |
| `for` Expressions | 2026-07-15 | [tf-expr-for](tf-expr-for.md) |
| Splat Expressions | 2026-07-15 | [tf-expr-splat](tf-expr-splat.md) |
| `dynamic` Blocks | 2026-07-15 | [tf-expr-dynamic-blocks](tf-expr-dynamic-blocks.md) |
| Type Constraints | 2026-07-15 | [tf-expr-type-constraints](tf-expr-type-constraints.md) |
| Version Constraints | 2026-07-15 | [tf-expr-version-constraints](tf-expr-version-constraints.md) |
| Built-in Functions (catalogue) | 2026-07-15 | [tf-functions](tf-functions.md) |
| Query infrastructure data (data sources) | 2026-07-22 | [tf-data-sources](tf-data-sources.md) |
| `data` block reference | 2026-07-22 | [tf-block-data](tf-block-data.md) |
| State (overview) | 2026-07-29 | [tf-state](tf-state.md) |
| Purpose of Terraform State | 2026-07-29 | [tf-state-purpose](tf-state-purpose.md) |
| State Storage and Locking (remote backends) | 2026-07-29 | [tf-state-backends](tf-state-backends.md) |
| Refactor Terraform state (split across configs) | 2026-07-29 | [tf-state-refactor](tf-state-refactor.md) |
| Remove a resource from state (forget, don't destroy) | 2026-07-30 | [tf-state-remove](tf-state-remove.md) |
| State Locking (`-lock`, `force-unlock`) | 2026-07-30 | [tf-state-locking](tf-state-locking.md) |
| Workspaces (CLI workspaces, `terraform.workspace`) | 2026-07-30 | [tf-state-workspaces](tf-state-workspaces.md) |
| Backend block configuration overview | 2026-07-30 | [tf-backend-configure](tf-backend-configure.md) |
| `local` backend (`path`, `workspace_dir`, legacy `-state` flags) | 2026-07-30 | [tf-backend-local](tf-backend-local.md) |
| Remote State (delegation, locking, HCP run queue) | 2026-07-30 | [tf-state-remote](tf-state-remote.md) |
| `terraform refresh` command (deprecated) | 2026-07-30 | [tf-cmd-refresh](tf-cmd-refresh.md) |
| Inspect Infrastructure Commands Overview | 2026-07-30 | [tf-cli-inspect](tf-cli-inspect.md) |
| `terraform output` command (sensitive redaction verified) | 2026-07-30 | [tf-cmd-output](tf-cmd-output.md) |
| `terraform show` command (`-json`, schema precondition) | 2026-07-30 | [tf-cmd-show](tf-cmd-show.md) |
| `terraform state list` command (`-id` reverse lookup) | 2026-07-30 | [tf-cmd-state-list](tf-cmd-state-list.md) |
| `terraform state show` command (PowerShell quoting corrected) | 2026-07-30 | [tf-cmd-state-show](tf-cmd-state-show.md) |
