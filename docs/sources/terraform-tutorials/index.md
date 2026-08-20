# HashiCorp Terraform Tutorials

Notes from the official hands-on tutorials at [developer.hashicorp.com/terraform/tutorials](https://developer.hashicorp.com/terraform/tutorials). These are the interactive companions to the conceptual [HashiCorp Terraform Docs](../terraform-docs/index.md) notes. Organized by **tutorial collection**, mirroring the source site.

**Source type:** official interactive tutorials

## AWS Get Started

| Page | Added | File |
|---|---|---|
| Install Terraform | 2026-07-04 | [tf-install-cli](tf-install-cli.md) |
| Create infrastructure | 2026-07-04 | [tf-aws-create](tf-aws-create.md) |
| Manage infrastructure | 2026-07-07 | [tf-aws-manage](tf-aws-manage.md) |
| Destroy infrastructure | 2026-07-07 | [tf-aws-destroy](tf-aws-destroy.md) |

## Configuration Language

| Page | Added | File |
|---|---|---|
| Define resources | 2026-07-13 | [tut-resource](tut-resource.md) |
| Customize with variables | 2026-07-13 | [tut-variables](tut-variables.md) |
| Query data sources | 2026-07-22 | [tut-data-sources](tut-data-sources.md) |
| Simplify with locals | 2026-07-13 | [tut-locals](tut-locals.md) |
| Output data | 2026-07-13 | [tut-outputs](tut-outputs.md) |
| Create resource dependencies | 2026-08-01 | [tut-dependencies](tut-dependencies.md) |
| Manage similar resources with `count` | 2026-08-01 | [tut-count](tut-count.md) |
| Manage similar resources with `for_each` | 2026-08-01 | [tut-for-each](tut-for-each.md) |

## State

Nav order mirrors the collection sidebar, resolved at **rung 3** (rendered nav DOM) with `fetch_nav.py` on 2026-08-20. Full sidebar, in order: *1 Import · 2 Migrate state · 3 Manage resource state · 4 Target resources · 5 Troubleshooting · 6 Resource drift · 7 Lifecycle rules · 8 Version state · 9 Refresh state · 10 Console · 11 Move resources*. Three are still uncaptured — **Target resources** (`state/resource-targeting`), **Refresh state** (`state/refresh`), **Console** (`state/console`). *Move resources* is the same page as [tut-move-config](tut-move-config.md), which the site also files under Modules and which is listed there.

| Page | Added | File |
|---|---|---|
| Import (Import Terraform configuration) | 2026-08-20 | [tut-state-import](tut-state-import.md) |
| Migrate state to HCP Terraform | 2026-08-18 | [tut-cloud-migrate](tut-cloud-migrate.md) |
| Manage resource state (Manage resources in Terraform state) | 2026-08-20 | [tut-state-cli](tut-state-cli.md) |
| Troubleshooting (Troubleshoot Terraform) | 2026-08-20 | [tut-troubleshooting-workflow](tut-troubleshooting-workflow.md) |
| Manage resource drift | 2026-08-20 | [tut-resource-drift](tut-resource-drift.md) |
| Lifecycle rules (Manage resource lifecycle) | 2026-08-03 | [tut-resource-lifecycle](tut-resource-lifecycle.md) |
| Version state (Version remote state with the HCP Terraform API) | 2026-08-18 | [tut-cloud-state-api](tut-cloud-state-api.md) |

## Modules

| Page | Added | File |
|---|---|---|
| Terraform modules (Modules overview) | 2026-08-08 | [tut-module](tut-module.md) |
| Use modules (Use registry modules in configuration) | 2026-08-08 | [tut-module-use](tut-module-use.md) |
| Create a module (Build and use a local module) | 2026-08-08 | [tut-module-create](tut-module-create.md) |
| Object attributes (Customize modules with object attributes) | 2026-08-08 | [tut-module-object-attributes](tut-module-object-attributes.md) |
| Share modules in the private registry | 2026-08-08 | [tut-module-private-registry-share](tut-module-private-registry-share.md) |
| Add from the public registry (Add public providers and modules) | 2026-08-08 | [tut-private-registry-add](tut-private-registry-add.md) |
| Refactor configuration (Refactor monolithic Terraform configuration) | 2026-08-08 | [tut-organize-configuration](tut-organize-configuration.md) |
| Create modules (Module creation — recommended pattern) | 2026-08-08 | [tut-pattern-module-creation](tut-pattern-module-creation.md) |
| Move resources (Use configuration to move resources) | 2026-08-08 | [tut-move-config](tut-move-config.md) |
| No-code modules (Create and use no-code modules) | 2026-08-08 | [tut-no-code-provisioning](tut-no-code-provisioning.md) |
