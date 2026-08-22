# Chapter 7 — Working with Multiple Providers

> *Source: Brikman (2022), **Terraform: Up & Running**, 3rd ed., Chapter 7, pages 221–274.*
>
> Fifty-four pages answering three questions the book has left open since Chapter 2: how do you deploy to multiple regions, to multiple accounts, and to other clouds? The mechanics take about fifteen pages. The rest is a Docker and Kubernetes crash course leading to an EKS example, and a running argument that the answer to all three questions is usually *"don't do it in one module."*
>
> 📌 **Notes adapted where version-bound.** Book written 2022 against Terraform ~1.2 and AWS provider 4.19; current stable is **1.15.8** / OpenTofu **1.12.5** ([[version-facts]]), AWS provider **6.61.0**, Kubernetes provider **3.2.1**. **The provider mechanics are unchanged and the warnings have aged well.** The Kubernetes half has aged worse than anything else in the book: the pinned EKS version is fifteen releases past end of support, the Kubernetes provider is a major behind and has deprecated both resources the chapter uses, and the ordering hack the chapter apologises for now has an official answer. All of it under [Version reckoning](#version-reckoning).

> 🔗 **See also:** [Providers](../../../topics/providers.md) for the cross-source treatment of `alias`, `configuration_aliases` and the `providers` map.

---

## The framing

One `provider "aws"` block means one region in one account. The chapter's three questions follow from that, and it works through them in order of increasing distance: another region, another account, another platform entirely.

## 1. Working with one provider

### What is a provider?

Terraform is two pieces:

- **Core** — the `terraform` binary. CLI, HCL parser and interpreter, dependency graph, state read/write. Go, one HashiCorp repo.
- **Providers** — plugins, each a separate Go binary implementing an interface core knows how to install and execute. Core talks to them over **RPC**; they talk to their platform over the network.

Each provider claims a **prefix**, and every resource and data source it exposes carries it. `aws_instance`, `aws_autoscaling_group`, `aws_ami` from the AWS provider; `azurerm_virtual_machine` from the Azure one.

> 💭 (mine): the prefix is doing more work than it looks. It is how Terraform infers which plugin to download when you have no `required_providers` block, which is exactly the "magic" the next section explains.

### How do you install providers?

Add a `provider` block, run `init`, and Terraform downloads the plugin. A footnote goes further: you can skip the `provider` block entirely and Terraform will still infer the plugin from a resource's prefix.

The magic is a two-step default. Given a provider named `foo` with no `required_providers` block, Terraform assumes hostname `registry.terraform.io` and namespace `hashicorp`, tries `registry.terraform.io/hashicorp/foo`, and installs the **latest** version it finds there.

The block that removes the guessing:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
```

Three parts, and the chapter is precise about each:

| Part | What it is |
| --- | --- |
| `LOCAL_NAME` | The name this module uses for the provider, and the name the `provider` block must match. Almost always the preferred local name (`aws`). Exists to disambiguate two providers that want the same name — the example given is two different `http` providers. |
| `source` | `[<HOSTNAME>/]<NAMESPACE>/<TYPE>`. Hostname defaults to the public registry, so `hashicorp/aws` and `registry.terraform.io/hashicorp/aws` are the same thing. You write the hostname for private registries. |
| `version` | A constraint, exact (`4.19.0`) or a range (`> 4.0, < 4.3`). Deferred to Chapter 8. |

The chapter's rule: **always include `required_providers`.** Anything outside the `hashicorp` namespace requires it, and so does any control over versions.

### How do you use providers?

Declare, then configure. Once a `provider` block is configured, *every* resource and data source with that prefix uses it — set `region = "us-east-2"` and all `aws_` resources land in us-east-2.

The AWS provider has roughly **50 configuration options** (a number that matters later in the chapter). Its documentation lives in the same registry as the `source` URL.

The question this leaves open is the one the rest of the chapter answers: what if you want *some* resources somewhere else?

## 2. Working with multiple copies of the same provider

### Multiple AWS regions

Two `provider "aws"` blocks are not enough by themselves — nothing says which is which. **`alias`** names them, and the **`provider`** meta-argument selects one:

```hcl
provider "aws" {
  region = "us-east-2"
  alias  = "region_1"
}

provider "aws" {
  region = "us-west-1"
  alias  = "region_2"
}

data "aws_region" "region_1" {
  provider = aws.region_1
}
```

The same `provider = aws.<alias>` works on resources. The chapter proves it with two `aws_region` data sources and two EC2 instances, checking the result with `availability_zone` outputs (`us-east-2a` and `us-west-1b`).

!!! warning "The AMI trap the multi-region example walks straight into"
    **AMI IDs are region-scoped.** The two `aws_instance` blocks need *different* `ami` values for the same Ubuntu 20.04 image, which the chapter calls out as tedious and error-prone — then fixes properly with one `aws_ami` data source per region:

    ```hcl
    data "aws_ami" "ubuntu_region_1" {
      provider    = aws.region_1
      most_recent = true
      owners      = ["099720109477"] # Canonical

      filter {
        name   = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
      }
    }
    ```

    The data source needs its own `provider` argument, for the same reason the instance does — a lookup runs in one region too.

#### The worked example: a cross-region RDS replica

The chapter's real demonstration, and the only place the running example advances. It turns Chapter 3's staging MySQL configuration into a `modules/data-stores/mysql` module that can be either a primary or a replica, then deploys both from one production root module.

Two new input variables carry the difference:

- `backup_retention_period` — must be > 0 on the **primary**, because RDS will not replicate without backups.
- `replicate_source_db` — set on the **secondary** to the primary's ARN, which is what makes it a replica.

The interesting part is the conditional logic, because AWS forbids setting inherited attributes on a replica:

```hcl
resource "aws_db_instance" "example" {
  # ...
  backup_retention_period = var.backup_retention_period
  replicate_source_db     = var.replicate_source_db

  # Only set these if this is not a replica
  engine   = var.replicate_source_db == null ? "mysql" : null
  db_name  = var.replicate_source_db == null ? var.db_name : null
  username = var.replicate_source_db == null ? var.db_username : null
  password = var.replicate_source_db == null ? var.db_password : null
}
```

That forces `db_name`, `db_username` and `db_password` to default to `null` in the module, which is the module-design consequence people miss: **supporting a replica makes three of your inputs optional.** The module also gains an `arn` output, since the replica needs it, and a `required_providers` block, which the next paragraph explains why.

The root module then declares two aliased providers and hands them to the two module calls:

```hcl
module "mysql_primary" {
  source    = "../../../../modules/data-stores/mysql"
  providers = { aws = aws.primary }
  # ...
  backup_retention_period = 1
}

module "mysql_replica" {
  source    = "../../../../modules/data-stores/mysql"
  providers = { aws = aws.replica }

  replicate_source_db = module.mysql_primary.arn
}
```

!!! note "`provider` (singular) versus `providers` (plural) — the distinction to memorise"
    On a **resource or data source** it is `provider = aws.primary`, a single value, because one resource deploys into exactly one provider.

    On a **module** it is `providers = { aws = aws.primary }`, a map, because a module may hold many resources using many providers. The **key** must match the local name in the module's own `required_providers` — which is the chapter's second reason for always writing that block.

Apply takes 20–30 minutes, and the outputs show endpoints in both regions.

!!! danger "Warning 1 — multiregion is hard, and aliases are not the hard part"
    The chapter is blunt that provider aliases solve the *Terraform* problem and none of the real ones: latency between regions, one writer (lower availability, higher latency) versus many writers (eventual consistency or sharding), unique ID generation once auto-increment stops working, and local data regulations. All out of scope for the book, all in scope for anyone actually going active-active.

!!! danger "Warning 2 — use aliases sparingly, and the reason is failure mode, not style"
    You build multiregion infrastructure so that one region's outage does not take you down. But **a module with an alias into both regions cannot plan or apply while either region is unreachable** — so the moment you most need to roll out a change is exactly the moment the code stops working.

    The general rule is Chapter 3's isolation argument applied to providers: manage each region in a separate module. The blast radius shrinks both for your own mistakes and for the world's.

    **When aliases *do* fit** is when the infrastructure is genuinely coupled and must deploy together. Two cases given:

    - **CloudFront + ACM.** AWS requires the TLS certificate in `us-east-1` regardless of where CloudFront itself is configured, so one module holds a primary-region provider and a second hardcoded to `us-east-1`.
    - **GuardDuty.** AWS recommends deploying it in every region you use, so one module with a `provider` block and alias per region is the honest shape.

    Beyond corner cases like these, the common use for aliases is not regions at all — it is providers that **authenticate differently**, which is the next section.

### Multiple AWS accounts

Three reasons the chapter gives for splitting environments across accounts, and they are worth keeping separate because they fail differently:

- **Isolation.** An attacker who gets into staging has *no* access to production. A developer working in staging is much less likely to break production.
- **Authentication and authorization.** Permissions granted in one account cannot leak into another, so fine-grained control gets easier rather than harder. The under-appreciated half is human error: with one account it is easy to think you are dropping tables in staging when you are in production, and separate accounts put separate authentication steps in the way.
- **Auditing and reporting.** One audit trail across environments, compliance checks, anomaly detection, and consolidated billing with per-account cost breakdown — which is how finance budgets by team without asking anyone.

!!! note "One profile, many accounts"
    A separate IAM user per account is named as an **antipattern** — that is multiple credential sets to manage. Every major cloud supports one user profile that authenticates into any account it is allowed into. On AWS the mechanism is **assuming IAM roles**.

The AWS setup is console work: **AWS Organizations** creates child accounts whose billing rolls up to the parent, and each new child automatically gets an admin IAM role assumable from the parent, named **`OrganizationAccountAccessRole`** by default. New child accounts get no root password at all; you reach them by assuming that role, or by running a password reset if you really want the root user.

> 💡 **Tip** — every AWS account needs a unique root email, and the chapter's sidebar is the workaround: Gmail (including Google Workspace on a custom domain) ignores everything after a `+`, so `example+stage@company.com` and `example+dev@company.com` are distinct to AWS and identical to your inbox.

In Terraform, "switch role" is an **`assume_role`** block on an aliased provider:

```hcl
provider "aws" {
  region = "us-east-2"
  alias  = "child"

  assume_role {
    role_arn = "arn:aws:iam::222222222222:role/OrganizationAccountAccessRole"
  }
}
```

Two `aws_caller_identity` data sources, one per provider, prove it works by printing two different account IDs.

!!! danger "Warning — cross-account IAM roles are double opt-in"
    Both accounts must agree, and forgetting either half produces the same unhelpful error:

    1. **In the account that owns the role** (the child), the role's assume role policy must trust the other account. AWS Organizations does this for `OrganizationAccountAccessRole` automatically, which is why the example works with no IAM code. **Any role you create yourself needs `sts:AssumeRole` granted explicitly.**
    2. **In the account you assume *from*** (the parent), your user needs permission to assume that role. This also worked "magically" in the book because Chapter 2 gave the user `AdministratorAccess`. A real user is not an admin and needs the permission written down.

    Then Warning 2 repeats verbatim from the region section: accounts exist to separate things, so a module that spans two accounts is working against the reason you made two accounts.

### Modules that can work with multiple providers

The section that generalises the whole chapter. Two kinds of module:

- **Reusable modules** — low-level, not applied directly, combined with other modules and resources.
- **Root modules** — high-level, combine reusable modules, and *are* the thing you run `apply` on. The chapter's definition is circular on purpose: the root module is the one you apply.

Everything so far put the `provider` blocks in the root module. Moving them into a reusable module works, and is an **antipattern** for three separate reasons:

| Problem | Why |
| --- | --- |
| **Configuration** | A `provider` block inside the module means the module owns all of that provider's configuration. Exposing it properly means exposing input variables for up to ~50 AWS provider settings — auth, region, account, endpoints, tags — which no one wants to maintain or use. |
| **Duplication** | Even if you expose them, callers combine several modules, so those settings get copy-pasted into every module call. |
| **Performance** | Each `provider` block is a separate **process** talking RPC. This scales badly, with receipts. |

!!! quote "The 125-provider story, which is the most concrete performance number in the book"
    Brikman built reusable modules for CloudTrail, AWS Config, GuardDuty, IAM Access Analyzer and Macie. Each is meant to run in every region, and AWS had about 25 regions, so each module carried **25 provider blocks**. One root module combining all five meant **125 provider blocks**, so `apply` started 125 processes making hundreds of API and RPC calls each. A single plan took **20 minutes**, the CPU thrashed, and the overloaded network stack produced intermittent API failures and sporadic apply errors.

The fix is **configuration aliases** — alias-shaped declarations that create no provider, and instead force the caller to supply one:

```hcl
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 4.0"
      configuration_aliases = [aws.parent, aws.child]
    }
  }
}
```

Inside the module, `provider = aws.parent` works exactly as before. Outside it, the caller must now pass both:

```hcl
module "multi_account_example" {
  source = "../../modules/multi-account"

  providers = {
    aws.parent = aws.parent
    aws.child  = aws.child
  }
}
```

Keys must match the configuration alias names; a missing one is an error rather than a silent fallback. The result is the contract the chapter is arguing for throughout: **the reusable module declares what it needs, the root module owns every `provider` block and passes references down.**

## 3. Working with multiple different providers

The chapter opens this section by declining to write the multicloud example readers asked for. Two reasons: multicloud is usually a bad practice (footnote to Corey Quinn's *Multi-Cloud is the Worst Practice*), and even when you are stuck with it, managing two clouds in one module is wrong for the same reason two regions in one module is wrong. For side-by-side AWS/Azure/GCP code it points at the Terratest repo's `examples` folder.

What it does instead: the **AWS provider plus the Kubernetes provider**, deploying a Dockerized app — which it argues is a fair multicloud stand-in, since Kubernetes is a cloud of its own.

### A crash course on Docker

The parts that matter for the Terraform half:

- `docker run -it ubuntu:20.04 bash` pulls from Docker Hub if the image is not local, then runs it. Containers are **isolated at userspace level** — filesystem, memory, networking — from the host and from each other.
- The demonstration: write `test.txt` inside a container, exit, and the file is neither on the host nor in the next container. `docker start -ia <ID>` re-enters the *original* container, where the file still is.
- Containers are **lightweight** — second run starts almost instantly, little CPU or memory overhead compared to a VM.
- Networking is isolated too, which is why `curl localhost:5000` fails against `docker run training/webapp` until you publish the port with `docker run -p 5000:5000`.
- Housekeeping: every `docker run` leaves a stopped container behind. `docker rm <ID>`, or `--rm` on the run.

### A crash course on Kubernetes

Kubernetes is a **Docker orchestration tool**: scheduling, auto healing, auto scaling, load balancing. Two pieces:

- **Control plane** — stores cluster state, monitors containers, coordinates, and runs the API server that `kubectl`, the dashboard and Terraform all talk to.
- **Worker nodes** — the servers that actually run containers, entirely managed by the control plane.

You deploy by writing **objects**, which record intent; the cluster runs a **reconciliation loop** that continuously works to make reality match them. Two object types carry the chapter:

- **Deployment** — declares which images to run, how many **replicas**, their settings, and the rollout strategy. If a node dies and a replica with it, the Deployment starts a replacement.
- **Service** — exposes an app as a network service; `type = "LoadBalancer"` gets you a load balancer distributing across the Deployment's replicas.

Locally: enable Kubernetes in Docker Desktop, install `kubectl`, then `kubectl config use-context docker-desktop` and `kubectl get nodes`.

The idiomatic interface is YAML plus `kubectl apply`. The chapter's argument for using Terraform instead is that raw YAML has no variables, no modules, no loops or conditionals, and no established convention for where the files live or how changes are tracked. (Helm is named as the other alternative.)

### The `k8s-app` module

A module wrapping `kubernetes_deployment` and `kubernetes_service`, with inputs `name`, `image`, `container_port`, `replicas` and `environment_variables`.

The Deployment's nesting is the part worth having written down, because it is four levels deep and each level means something different:

```hcl
resource "kubernetes_deployment" "app" {
  metadata { name = var.name }        # identifies the Deployment object

  spec {
    replicas = var.replicas

    template {                        # the Pod Template
      metadata { labels = local.pod_labels }

      spec {
        container {
          name  = var.name
          image = var.image
          port { container_port = var.container_port }

          dynamic "env" {             # Ch5's dynamic blocks, put to work
            for_each = var.environment_variables
            content {
              name  = env.key
              value = env.value
            }
          }
        }
      }
    }

    selector { match_labels = local.pod_labels }
  }
}
```

- **Pods**, not containers, are the unit — a group of containers deployed together. The chapter's example of a genuine multi-container Pod is an app container plus a metrics sidecar.
- **Labels** (`local.pod_labels`) appear in three places: on the Pod Template, in the Deployment's `selector`, and in the Service's `selector`. That is what binds the three objects together.
- **Why a `selector` at all**, when the Pod Template is right there: Kubernetes is deliberately decoupled, and a Deployment can target Pods defined elsewhere, so the targeting is always explicit.

The Service is short by comparison — `type = "LoadBalancer"`, port 80 to `target_port`, and the same `selector`.

!!! tip "The `try()` idiom, which is the most reusable line in the chapter"
    `kubernetes_service.app.status` is a deeply nested list-of-maps, and the load balancer hostname is buried inside it:

    ```hcl
    output "service_endpoint" {
      value = try(
        "http://${local.status[0]["load_balancer"][0]["ingress"][0]["hostname"]}",
        "(error parsing hostname from status)"
      )
    }
    ```

    `try(ARG1, ARG2, …)` evaluates arguments in order and returns the first that raises no error. Every one of those index lookups can fail on a status shaped slightly differently, and without `try` the failure is a confusing type error rather than a readable message.

Applied against Docker Desktop with a `kubernetes` provider pointed at `~/.kube/config` and context `docker-desktop`, `curl http://localhost` returns `Hello world!`.

The chapter then earns the extra work back with `kubectl`:

- `kubectl get deployments` shows `2/2` ready; `kubectl get pods` shows two Pods where `docker run` had one container.
- `docker kill <ID>` on one of them, and seconds later `docker ps` shows a replacement. The reconciliation loop, demonstrated rather than described.
- `kubectl get services` shows the load balancer.
- Setting `environment_variables = { PROVIDER = "Terraform" }` and re-applying makes `curl` return `Hello Terraform!` — a rolling deployment by default, tunable with a `strategy` block.

### The `eks-cluster` module

The same Kubernetes code, moved to AWS. EKS runs the control plane and (with managed node groups) the workers.

The module is mostly IAM:

- **Control plane role** — assumable by `eks.amazonaws.com`, with the managed policy `AmazonEKSClusterPolicy` attached.
- **`aws_eks_cluster`** — takes that role, a `version`, and `vpc_config.subnet_ids` from the Default VPC (the code comments that real usage wants a custom VPC with private subnets), plus an explicit `depends_on` on the policy attachment so IAM permissions outlive the cluster during destroy.
- **Node group role** — assumable by `ec2.amazonaws.com`, with three managed policies: `AmazonEKSWorkerNodePolicy`, `AmazonEC2ContainerRegistryReadOnly`, `AmazonEKS_CNI_Policy`.
- **`aws_eks_node_group`** — `scaling_config` with min/max/desired, `instance_types`, and the same `depends_on` pattern against all three attachments.

Worker node options are named: self-managed EC2 instances, **managed node groups**, and Fargate. The example uses managed node groups as the simplest.

> 💡 **Tip** — the example pins `t3.small` with a comment worth keeping: EKS pods consume ENIs, and something like `t2.micro` has so few that system services (`kube-proxy` and friends) use them all, leaving no room for your own Pods.

Wiring the two providers together is where the chapter gets uncomfortable:

```hcl
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_name
}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

module "simple_webapp" {
  source = "../../modules/services/k8s-app"
  # ... identical inputs to the local example ...
  depends_on = [module.eks_cluster]
}
```

The payoff is that the `k8s-app` module call is *unchanged* from the Docker Desktop version apart from `depends_on`. Apply takes 10–20 minutes, and `curl` against the ELB hostname prints `Hello Terraform!`. `aws eks update-kubeconfig --region <REGION> --name <CLUSTER>` points `kubectl` at the new cluster so the same inspection commands work.

!!! danger "Warning 2 — the chapter documents its own example as a hack"
    Terraform has poor support for dependency ordering **between providers**, and the Kubernetes provider's documentation says so directly:

    > When using interpolation to pass credentials to the Kubernetes provider from other resources, these resources SHOULD NOT be created in the same Terraform module where Kubernetes provider resources are also used. This will lead to intermittent and unpredictable errors which are hard to debug and diagnose. The root issue lies with the order in which Terraform itself evaluates the provider blocks vs. actual resources.

    The book's code dodges it via the `aws_eks_cluster_auth` data source, which Brikman calls *"a bit of a hack"*, and his production recommendation is the same as everywhere else in the chapter: **cluster in one module, apps in another, applied after.**

!!! warning "Warning 1 — the Kubernetes examples are deliberately minimal"
    Named as missing for real use: ingress controllers, secret envelope encryption, security groups, OIDC authentication, RBAC mapping, VPC CNI, `kube-proxy`, CoreDNS on the cluster side; secrets, volumes, liveness and readiness probes, labels, annotations, multiple ports and multiple containers on the app side; and a custom VPC with private subnets instead of the default one.

## Conclusion

The three opening questions, answered:

| Question | Mechanism |
| --- | --- |
| Multiple AWS regions? | Multiple `provider` blocks, each with its own `region` and `alias`. |
| Multiple AWS accounts? | Multiple `provider` blocks, each with its own `assume_role` and `alias`. |
| Other clouds, or Kubernetes? | Multiple `provider` blocks, one per platform. |

And then the answer that the chapter actually wants you to take away: **using multiple providers in one module is typically an antipattern.** Use each provider in its own module, keep regions, accounts and clouds isolated, limit the blast radius.

### State of the running example

The MySQL configuration from Chapter 3 becomes `modules/data-stores/mysql`, now able to be a primary or a cross-region read replica, with `db_name`/`db_username`/`db_password` optional and an `arn` output added. `live/prod/data-stores/mysql` deploys both halves through two aliased providers. Staging is left as an exercise, to be converted to the module *without* replication.

The Kubernetes work is all side material in `examples/` and `modules/services/{k8s-app,eks-cluster}` — the web server cluster is untouched.

---

## Version reckoning

The provider mechanics are unchanged. Everything downstream of them has moved, and the Kubernetes example is now the most dated code in the book.

!!! info "1. Provider iteration exists now, and it is the fix for the 125-provider story"
    The chapter's worst-case (five modules × 25 regions of hand-written `provider` blocks) is exactly what **OpenTofu 1.9's provider `for_each`** removes: an aliased `provider` block takes `for_each` and yields one instance per element, selected with `aws.by_region[each.key]`. Terraform has no equivalent **in ordinary modules**; it has the same capability only inside **Stacks** configurations ([[ot-provider-for-each]], [[tf-meta-for-each]]).

    ⚠️ The trap is the obvious usage. Drive the provider and its resources from the *same* collection and removing an element destroys the provider instance in the same plan as the resource that needs it, so the destroy cannot complete. Keep the provider's collection a superset (`setsubtract` for the resources), because the constraint is about destroy ordering rather than set arithmetic.

!!! danger "2. The EKS module cannot be applied as written"
    `version = "1.21"` is fifteen minor versions behind. Verified against the EKS release calendar on 2026-08-21:

    | | Versions |
    | --- | --- |
    | Standard support | **1.36, 1.35, 1.34** |
    | Extended support | 1.33, 1.32, 1.31 |

    The lifecycle rule is worth knowing because it decides how often you touch this code: **14 months of standard support, then 12 months of extended at an extra per-cluster-hour charge, then AWS auto-upgrades your control plane** — 26 months total, and extended support is on by default. Clusters can be rolled back to the previous minor within 7 days of an in-place upgrade.

    Two related additions since the book:

    - **`aws_eks_cluster_versions`** is a data source now, so the version need not be hardcoded at all (`aws eks describe-cluster-versions` is the CLI equivalent, and it returns the end-of-support dates).
    - **`upgrade_policy`** on `aws_eks_cluster` chooses `STANDARD` or `EXTENDED`, which is how you opt out of the extra billing.

!!! warning "3. `aws_eks_cluster` grew the two things the chapter says are missing"
    Its Warning 1 lists RBAC mapping and add-on management as reasons the example is not production-grade. Both are now arguments on the resource (checked at provider `v6.61.0`):

    - **`access_config.authentication_mode`** — `API`, `CONFIG_MAP` or `API_AND_CONFIG_MAP`. **Access entries** (`aws_eks_access_entry`, `aws_eks_access_policy_association`) replace editing the `aws-auth` ConfigMap, which is the single biggest quality-of-life change to EKS-with-Terraform since the book. The provider's own examples use `authentication_mode = "API"`.
    - **`bootstrap_self_managed_addons`** — controls whether `aws-cni`, `kube-proxy` and CoreDNS are installed at creation. Changing it forces a new cluster.
    - **EKS Auto Mode** — `compute_config`, `storage_config` and `kubernetes_network_config.elastic_load_balancing`, all three of which must be enabled together, and which require `bootstrap_self_managed_addons = false`. AWS then runs the node pools, load balancers and block storage, so the whole `aws_eks_node_group` half of the chapter's module becomes optional.

!!! warning "4. The Kubernetes provider is a major ahead, and both resources the chapter uses are deprecated"
    Current is **3.2.1** (2026-07-01) against the book's `~> 2.0`; 3.0.0 landed 2025-12-03. Verified in `kubernetes/provider.go` at `v3.2.1`, both resources are registered with a deprecation message:

    ```go
    "kubernetes_deployment": resourceKubernetesDeploymentV1("Deprecated; use kubernetes_deployment_v1."),
    "kubernetes_service":    resourceKubernetesServiceV1("Deprecated; use kubernetes_service_v1."),
    ```

    The unversioned names still work and the schemas are the same functions, so the migration is a rename. 3.0.0 did the same to most of the provider's surface, and dropped `kubernetes_pod_security_policy` because it was removed upstream.

!!! tip "5. The ordering hack has an official answer — in Stacks"
    The chapter apologises for configuring the Kubernetes provider from an EKS cluster in the same module, and quotes the provider's SHOULD NOT warning. **That warning is still in the provider docs verbatim** at `v3.2.1`, so the advice stands for ordinary configurations.

    What is new is that HashiCorp built the missing feature. In **Stacks**, HCP Terraform *"recognizes the dependency between components, and automatically defers the plan and apply steps for your components until they can complete successfully"*, and specifically *"defers initialization of your Kubernetes provider until after those values become available."* There is a HashiCorp tutorial that deploys an EKS cluster and a Kubernetes application in one Stack on exactly this mechanism. Deferred changes need provider support — the docs name **Kubernetes provider 2.32.0 or higher** as the example.

    Two caveats before treating this as the answer. It is **HCP Terraform only**, and it is a different configuration language surface (`tfcomponent.hcl` / `tfdeploy.hcl`), not something you turn on in a root module. See learning-path **E2**.

!!! note "6. Authentication: the data source still works, `exec` is what the provider recommends"
    `aws_eks_cluster_auth` still exists at provider `v6.61.0`. But the Kubernetes provider now documents **exec plugins** as the way to handle short-lived cloud tokens, since a token baked in at plan time can expire before apply finishes:

    ```hcl
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    }
    ```

    ⚠️ Its own warning: **do not mix `exec` with `token` or `client_certificate`** in one provider block — *"This leads to undefined behaviour and there is no guarantee about which credential will actually be used."*

!!! note "7. Smaller items"
    - **AWS provider** — book text and every `~> 4.0` constraint are two majors behind; current **6.61.0** (2026-08-19). The `provider "aws"` block's option count has only grown since the "roughly 50 settings" argument, which makes that argument stronger, not weaker.
    - **The AMI filter** targets Ubuntu 20.04 (focal), whose standard support ended **2025-05-31**. The `aws_ami` data-source technique is exactly right; only the filter string is stale.
    - **`training/webapp`** is still on Docker Hub with 15.7M pulls, and was last pushed **2015-05-15**. The examples run; you are running a decade-old Python 2 app to do it.
    - **The multicloud footnote** cites *"Multi-Cloud is the Worst Practice"*, which is **Corey Quinn**, Last Week in AWS, **2020-08-05** — not a Gruntwork post, though the chapter's phrasing reads like one.
    - **Kubernetes 1.22** appears in the book's `kubectl get nodes` output from Docker Desktop. Any current Docker Desktop ships something far newer; treat those transcripts as illustrative only.

!!! tip "8. What aged well, and why"
    The three warnings are the durable part of this chapter, and none of them has been touched by four years of releases:

    - *Don't put `provider` blocks in reusable modules* is now also HashiCorp's documented position ([[tf-modules-providers]]), and `configuration_aliases` is unchanged.
    - *Use aliases sparingly* survives provider `for_each` intact — OpenTofu makes the many-instances case cheap to write, but a module that cannot plan while one region is down is still a module that cannot plan while one region is down.
    - *Multiregion is hard* needed no update at all.

    What decayed is everything with a version number attached, and it decayed in proportion to how fast the underlying platform moves: HCL syntax not at all, the AWS provider moderately, EKS and the Kubernetes provider almost completely.

---

*Related notes:* [Providers](../../../topics/providers.md) · TID Ch2 §2.4 [[02-hcl-components]] · TUR Ch3 [State](03-manage-state.md) for the isolation argument this chapter keeps invoking, Ch4 [Modules](04-reusable-modules.md) for the reusable-versus-root split, Ch6 [Managing Secrets](06-managing-secrets.md) for the `assume_role` and OIDC half of cross-account auth · [[tf-provider-block]], [[tf-meta-providers]], [[tf-modules-providers]], [[provider-requirements]] for the reference treatment · [[ot-provider-for-each]] for the OpenTofu divergence · [[version-facts]], [[multi-provider-facts]]. Feeds learning-path **I8** (provider configuration in depth), **A7** (multi-account patterns), **E2** (Stacks) and **E3** (OpenTofu).
