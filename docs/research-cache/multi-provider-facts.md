# Multi-provider, EKS & Kubernetes-provider facts

Captured while writing TUR Ch7 notes. Last verified: **2026-08-21**.

## EKS Kubernetes version lifecycle

Source: [Understand the Kubernetes version lifecycle on EKS](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html).

- **Standard support:** 1.36, 1.35, 1.34. **Extended support:** 1.33, 1.32, 1.31.
- **14 months standard, then 12 months extended** at an extra per-cluster-hour charge, then EKS auto-upgrades the control plane. 26 months total. Extended support is **on by default** (`upgrade_policy` = `EXTENDED`).
- Auto-upgrade covers the control plane only. Managed node groups and self-managed nodes stay where they are.
- In-place upgrades can be rolled back to the previous minor **within 7 days**.

| Version | Upstream release | EKS release | End of standard | End of extended |
|---|---|---|---|---|
| 1.36 | 2026-04-22 | 2026-06-02 | 2027-08-02 | 2028-08-02 |
| 1.35 | 2025-12-17 | 2026-01-27 | 2027-03-27 | 2028-03-27 |
| 1.34 | 2025-08-27 | 2025-10-02 | 2026-12-02 | 2027-12-02 |
| 1.33 | 2025-04-23 | 2025-05-29 | 2026-07-29 | 2027-07-29 |

TUR Ch7 pins `version = "1.21"`, which is far past even extended support. `aws eks describe-cluster-versions` (and the `aws_eks_cluster_versions` data source) returns these dates programmatically.

## `aws_eks_cluster` arguments added since the book (provider `v6.61.0`)

| Argument | What it does |
|---|---|
| `access_config.authentication_mode` | `CONFIG_MAP`, `API`, `API_AND_CONFIG_MAP`. **Access entries** replace hand-editing the `aws-auth` ConfigMap; the provider's own examples use `API` |
| `bootstrap_self_managed_addons` | Install `aws-cni`, `kube-proxy`, CoreDNS at creation. Default `true`; changing forces replacement |
| `compute_config` / `storage_config` / `kubernetes_network_config.elastic_load_balancing` | **EKS Auto Mode.** All three must be enabled together, and Auto Mode requires `bootstrap_self_managed_addons = false` |
| `upgrade_policy` | `STANDARD` or `EXTENDED` support policy |
| `version` | Optional. Omitted means latest at creation, with no upgrades except EKS-triggered ones |

`aws_eks_cluster_auth` still exists as a data source. Related resources now include `aws_eks_access_entry`, `aws_eks_access_policies`, `aws_eks_addon`, `aws_eks_addon_version`, `aws_eks_cluster_versions`.

## Kubernetes provider

- Current **3.2.1** (2026-07-01). **3.0.0** released 2025-12-03; bumped Kubernetes deps to v1.33, added ValidatingAdmissionPolicy and sidecar `restart_policy`.
- 3.0.0 **deprecated the unversioned resource and data-source names** in favour of `_v1` ones. Verified in `kubernetes/provider.go` at `v3.2.1`:

  ```go
  "kubernetes_deployment": resourceKubernetesDeploymentV1("Deprecated; use kubernetes_deployment_v1."),
  "kubernetes_service":    resourceKubernetesServiceV1("Deprecated; use kubernetes_service_v1."),
  ```

  Same function, different registered name — the migration is a rename. `kubernetes_pod_security_policy` was removed upstream; use Pod Security Admission.
- **The SHOULD NOT warning TUR quotes is still in `docs/index.md` verbatim**: interpolating credentials from resources created in the same module "will lead to intermittent and unpredictable errors."
- **Exec plugins** are the documented answer for short-lived cloud tokens (`aws eks get-token`). The docs warn: *"DO NOT mix `exec` blocks with other credential attributes such as `token` or `client_certificate` … there is no guarantee about which credential will actually be used."*

## Provider iteration

- **OpenTofu 1.9**: `for_each` on an aliased `provider` block, one instance per element. Details and the destroy-ordering gotcha in [[ot-provider-for-each]].
- **Terraform**: no equivalent in ordinary modules as of 1.15. Stacks component configurations support it — *"Unlike traditional Terraform providers, Stack providers also support the `for_each` meta-argument."*

## Stacks deferred changes

Source: [Declare providers](https://developer.hashicorp.com/terraform/language/stacks/component/declare-providers) and the [EKS deferred-changes tutorial](https://developer.hashicorp.com/terraform/tutorials/cloud/stacks-eks-deferred).

- *"HCP Terraform recognizes the dependency between components, and automatically defers the plan and apply steps for your components until they can complete successfully."*
- *"HCP Terraform automatically defers initialization of your Kubernetes provider until after those values become available."*
- Requires provider support; the docs name **Kubernetes provider 2.32.0 or higher** as the example. HCP Terraform only.

## Smaller items

- `training/webapp` on Docker Hub: still active, **15,759,460 pulls**, last pushed **2015-05-15**.
- *"Multi-Cloud is the Worst Practice"* — **Corey Quinn**, Last Week in AWS, **2020-08-05** (`lastweekinaws.com/blog/multi-cloud-is-the-worst-practice/`). TUR cites it in a footnote; the Gruntwork-blog URL shape does not resolve.
- AWS provider current **6.61.0** (2026-08-19); the book targets 4.19 and constrains `~> 4.0`.
- The book's AMI filter targets Ubuntu 20.04 focal; standard support ended 2025-05-31.

## Staleness notes

Durable: the deprecation mechanism in the Kubernetes provider, the EKS 14+12-month lifecycle rule, the Stacks deferral quotes, the Docker Hub push date. Expires: the standard/extended version lists (roughly every four months), every "current release" number, and the extended-support dates as new minors land.
