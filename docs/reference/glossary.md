# Glossary

Terms are appended here as book chapters are written.

<!-- term: definition (source chapter) -->

| Term | Definition | Source |
|---|---|---|
| Infrastructure as Code (IaC) | Provisioning and managing infrastructure from declarative, version-controlled configuration files instead of manual steps. | [[terraform-intro]] |
| Provider | A plugin that lets Terraform manage a platform/service through its API; thousands are published on the Terraform Registry. | [[terraform-intro]] |
| Write → Plan → Apply | The core Terraform workflow: define resources, generate an execution plan, then apply approved changes in dependency order. | [[terraform-intro]] |
| State file | Terraform's record of real infrastructure; the source of truth it diffs against configuration to decide changes. | [[terraform-intro]] |
| Resource graph | Dependency graph Terraform builds to create/modify non-dependent resources in parallel. | [[terraform-intro]] |
| Module | Reusable, configurable collection of infrastructure; sourced from the Registry or authored locally. | [[terraform-intro]] |
| Immutable infrastructure | Approach of replacing rather than mutating resources, reducing upgrade/modification complexity. | [[terraform-intro]] |
| Sentinel | HashiCorp's policy-as-code framework; enforces compliance/governance policies before Terraform applies changes. Available in Terraform Enterprise and HCP Terraform. | [[terraform-use-cases]] |
| HCP Terraform Operator | Kubernetes Operator that manages cloud and on-prem infrastructure through a Kubernetes CRD plus HCP Terraform. | [[terraform-use-cases]] |
| Consul-Terraform-Sync (NIA) | Network Infrastructure Automation tool; auto-generates Terraform config to reconfigure an SDN when a service registers with Consul. | [[terraform-use-cases]] |
| TACOS | "Terraform Automation and Collaboration Software" — informal industry term for CI/CD platforms purpose-built for running Terraform (HCP Terraform, Terraform Enterprise, Spacelift, Scalr). | TID Ch1 |
| BSL (Business Source License) | The "shared source" license HashiCorp moved Terraform to (from MPL) starting with v1.6; code stays viewable/auditable but usage is restricted, notably against competitive hosted/embedded offerings. | TID Ch1 |
| DAG (directed acyclic graph) | The data structure Terraform builds from resource dependencies to order plan actions; circular dependencies break this model and require manual workaround. | TID Ch1 |
| Workspace (CLI) | One deployment of a Terraform codebase against a specific backend + input variables — like one "installation" of a program; a codebase can have unlimited workspaces sharing a backend. | TID Ch1 |
