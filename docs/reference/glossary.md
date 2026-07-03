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
