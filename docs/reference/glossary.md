# Glossary

A running glossary of terms across all books. Each entry is attributed to its source.

## From Hafner (2025)

| Term | Meaning | Source |
| --- | --- | --- |
| **Infrastructure as Code (IaC)** | A class of technology that lets developers provision infrastructure using coding practices — version-controlled, testable, and repeatable. | Hafner Ch 1 |
| **Terraform** | An IaC tool by HashiCorp that manages infrastructure through a declarative language (HCL) and a provider-based plugin system. | Hafner Ch 1 |
| **OpenTofu** | An open-source fork of Terraform (post-v1.5.7), accepted into the Linux Foundation. Functionally a superset of the Terraform language with additional features. | Hafner Ch 1 |
| **HCL (HashiCorp Configuration Language)** | The declarative language used by Terraform to describe desired infrastructure state. Readable, concise, and used across multiple HashiCorp products. | Hafner Ch 1 |
| **Provider** | A Terraform plugin that exposes resources and data sources for a particular vendor or platform. Communicates with Terraform core via gRPC. | Hafner Ch 1 |
| **Backend** | Configures where Terraform stores its state files. Default is `local` (filesystem); other backends include S3, GCS, AzureRM. | Hafner Ch 1 |
| **Workspace** | A single deployment of a Terraform codebase — one backend + one set of input variables + one state file. Analogous to one "installation" of a program. | Hafner Ch 1 |
| **State** | Terraform's metadata about the resources it manages. Stored per workspace; used during `plan` to compare actual vs. desired infrastructure. | Hafner Ch 1 |
| **DAG (Directed Acyclic Graph)** | The data structure Terraform uses to order resource operations in a plan. Enforces dependency order; circular dependencies cause plan failures. | Hafner Ch 1 |
| **TACOS** | Terraform Automation and Collaboration Software — CI/CD platforms built specifically for Terraform (HCP Terraform, Spacelift, Scalr, env0, etc.). | Hafner Ch 1 |
| **BSL (Business Source License)** | The proprietary license HashiCorp switched to for Terraform v1.6+. Allows use but restricts building competitive products on top of it. | Hafner Ch 1 |
| **Declarative language** | A language where you describe the desired end state; the engine figures out the steps to get there. Contrast with imperative languages that specify the steps explicitly. | Hafner Ch 1 |
| **Block** | The primary language construct in Terraform HCL. Has a type, optional labels, arguments, and subblocks. Analogous to a statement in imperative languages, but acts as a noun/adjective. | Hafner Ch 2 |
| **Resource (block)** | A `resource` block that maps to one piece of infrastructure. Terraform creates, updates, or destroys the infrastructure to match the block's arguments. | Hafner Ch 2 |
| **Data source** | A read-only block that looks up existing infrastructure and exposes its attributes. Never creates or modifies anything. | Hafner Ch 2 |
| **Arguments** | Key-value assignments inside a block (`name = value`). Each argument name is unique per block. | Hafner Ch 2 |
| **Subblocks** | Nested blocks inside another block (no `=` sign). Unlike arguments, the same subblock type can appear multiple times (e.g., multiple `filter {}` blocks). | Hafner Ch 2 |
| **Attributes** | Values exported by a block for use by other blocks. Includes all arguments plus computed values (e.g., `arn`, `id`) filled in by the provider after apply. | Hafner Ch 2 |
| **Meta arguments** | Arguments available on every `resource`, `data`, or `module` block regardless of provider: `provider`, `depends_on`, `lifecycle`, `count`, `for_each`. Change how Terraform processes the block, not the infrastructure config. | Hafner Ch 2 |
| **`lifecycle` block** | A meta argument subblock that controls replacement behaviour: `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`. | Hafner Ch 2 |
| **`depends_on`** | Meta argument for explicitly declaring a dependency between two resources that don't share any attributes. | Hafner Ch 2 |
| **`terraform fmt`** | CLI command that auto-formats `.tf` files to match the Terraform style guide. Run with `-check` in CI to fail on unformatted files. | Hafner Ch 2 |
| **ClickOps** | Manually creating infrastructure via a web console. Useful for learning and exploration; doesn't scale to production. | Hafner Ch 2 |
| **`import` block** | Brings existing infrastructure into Terraform state without recreating it (v1.5+). Supersedes the `terraform import` CLI command for most use cases. | Hafner Ch 2 |
| **`moved` block** | Renames or relocates a resource in state without destroying and recreating it. Safe to leave in place permanently. | Hafner Ch 2 |
| **`removed` block** | Removes a resource from Terraform management without destroying it (v1.7+). | Hafner Ch 2 |
