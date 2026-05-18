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
