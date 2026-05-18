# Chapter 1 — A Brief Overview of Terraform

> *Source: Hafner (2025), Chapter 1, pages 3–23.*
>
> A scene-setting chapter: what Terraform is and why it matters, the vocabulary used throughout the rest of the book, a walk through the basic deployment workflow, real-world use cases, and the history of the Terraform/OpenTofu fork.
>
> 📌 **Notes adapted to current versions.** The book's fork diagram shows Terraform through v1.7 and OpenTofu through v1.7. As of 2026-05-18: Terraform latest stable is **v1.15.3** (BSL licensed since v1.6); OpenTofu latest stable is **v1.12.0** (open source, Linux Foundation). Core language concepts are unchanged across these versions.

---

## 1. Infrastructure as Code

### What is IaC?

- **Infrastructure as Code (IaC)** is a class of technology that lets developers *provision infrastructure using coding practices* — version control, linters, CI/CD, tests.
- It is a natural evolution: manual config → scripts → config management (Puppet, Chef) → IaC frameworks that codify entire platforms.
- Terraform is considered *the standard* for IaC: vendor-agnostic, mature, enormous provider coverage. Alternatives include Pulumi (vendor-agnostic), CloudFormation and GCP Deployment Manager (vendor-specific).

### Why it matters

- **Repeatability** — infrastructure becomes a reusable building block. A VPC module written once gets shared, improved, and reused across teams. Improvements cascade to every consumer.
- **Reproducibility** — once in Terraform, a platform can be spun up identically as many times as needed. Per-developer ephemeral environments become cheap.
- **Collaboration** — the same Git-based workflows that govern software (branches, PRs, reviews, audit trails) now govern infrastructure.

### Software development practices applied to IaC

IaC can be versioned with Git, scanned with linters, and tested with CI/CD pipelines. Teams apply software engineering principles directly to infrastructure:

- VCS + GitHub/GitLab → audit trails, branching, PR reviews
- Linting → quality and security scanning
- CI/CD → automated testing and deployment gates

### Repeatability and shareability in practice

- A company builds a VPC module once, adds VPC endpoints and security monitoring over time, and every project using the module picks up those improvements automatically — the same as upgrading a library dependency.
- Modules are discussed in depth in Chapter 3.

### CI/CD for Terraform — TACOS

There is a whole category of CI/CD platforms built specifically for Terraform, called **TACOS** — *Terraform Automation and Collaboration Software*:

| Platform | Type |
| --- | --- |
| HCP Terraform | HashiCorp SaaS |
| Terraform Enterprise | HashiCorp self-hosted |
| Spacelift | Third-party |
| Scalr | Third-party |
| env0 | Third-party |
| Atlantis | Open source |

TACOS features: GitHub/GitLab integration, speculative plans on PRs, automatic deployment on merge, private module registries. Many teams also use general CI systems (GitHub Actions, CircleCI, Jenkins) alongside TACOS for testing, formatting, and linting.

---

## 2. Terraform Overview

### The core abstraction

Terraform's power comes from providing **one unified interface** to thousands of vendors. No matter whether you're launching cloud VMs, editing DNS records, or managing GitHub repos, you use the same language. Vendor-specific complexity lives inside providers, not in your code.

```
Your HCL code  →  Terraform Core (CLI)  →  Provider  →  Vendor API  →  Vendor Resources
```

### Key components

| Component | Role |
| --- | --- |
| **HCL** | The declarative language you write. Readable, concise, shared across HashiCorp tools. |
| **CLI / Core** | The engine. Parses HCL, resolves dependencies, coordinates providers. Can only be invoked via CLI (not as a library). |
| **Provider** | A plugin (Go, gRPC) exposing resources and data sources for one vendor. Updated independently of Terraform. |
| **Backend** | Where state is stored. Default: local filesystem. Others: S3, GCS, AzureRM, HTTP. |
| **Workspace** | One deployment of a codebase — its own backend location, variables, and state. |
| **State** | Terraform's record of what it manages. Used during `plan` to compare actual vs. desired. |

### Providers

- 3,280+ providers in the Terraform Provider Registry.
- Written in Go, communicate with Terraform Core over gRPC.
- Tend to be 1:1 with a vendor (AWS provider, GCP provider, Azure has multiple). Some are community-maintained.
- There are providers for cloud vendors, DNS, data analytics, Git repos, auth systems — even pizza delivery.
- Chapter 12 covers building custom providers.

> 💡 **gRPC and providers** — You don't need to know gRPC to use Terraform. It only becomes relevant if you're building a custom provider (Ch 12), and even then you mostly use HashiCorp's existing libraries.

### Vendors

- Terraform itself is **vendor-agnostic** — it doesn't care what kind of infrastructure it manages, as long as a provider exposes it.
- Each vendor has its own API, resources, and methodology, all abstracted behind the provider so the developer doesn't need to deal with vendor specifics.
- Vendor categories include:

  - Cloud service providers (AWS, GCP, Azure)
  - DNS providers
  - Data analytics platforms
  - Virtual machine hosts
  - Git repository services
  - Authentication systems (Okta, etc.)

- Most vendors maintain fairly up-to-date providers because Terraform is so widely adopted — it's in their interest to keep the provider current.

### Backends

- By default, state is stored on the local filesystem (`local` backend). Fine for solo development, doesn't scale to teams.
- Team-friendly backends: S3, GCS, AzureRM, open-source DBs, HTTP.
- Some backends (remote/cloud) expose additional APIs for special operations.
- Covered in depth in Chapter 6.

### Workspaces

- Think of a workspace as one *installation* of a program — independent config, independent saved data.
- A single codebase can have unlimited deployments: production, staging, feature branches, each developer's local copy.
- Each workspace gets its own slot in the backend.

---

## 3. Declarative Languages

### Declarative vs. imperative

| | Declarative | Imperative |
| --- | --- | --- |
| Focus | **End state** — what should exist | **Steps** — how to get there |
| Analogy | "I want a house like this" | "Pour foundation, then frame walls, then…" |
| Parts of speech | Nouns and adjectives | Verbs |
| Examples | Terraform HCL, Kubernetes YAML, Puppet DSL | Bash, JavaScript, Python |

In Terraform you never say "check if this machine exists, create it if not, then configure it." You describe the machine you want; Terraform figures out the steps.

Key advantage for infrastructure: **no migration scripts needed**. Define the end state, version it, and move between versions freely.

### Dependency resolution — how Terraform orders operations

Modern infrastructure has components that depend on each other (application → database → DNS record). Terraform infers these relationships from how you reference resources:

- If your application uses a connection string that comes from the database resource, Terraform knows the database must be created first — without you explicitly saying so.
- Terraform converts these relationships into a **DAG (Directed Acyclic Graph)**: a list of ordered actions with no cycles.

> 💡 The `terraform graph` command outputs the DAG in a format you can visualize with GraphViz. Useful for debugging complex plans.

### Pitfall — circular dependencies

A circular dependency (A → B → C → A) causes a deadlock: nothing can be created because everything is waiting on something else. Terraform cannot resolve circular dependencies automatically.

- This is generally a design smell in distributed systems.
- Chapter 5 covers some workarounds Terraform provides when circular dependencies are unavoidable.

---

## 4. Terraform Deployment Flow

The standard cycle: change the code, initialise, plan, review, apply. The init, plan, and apply phases are all invoked via the Terraform CLI — usually by a CI/CD system rather than a person directly.

```
  ┌────────────────┐   ┌──────┐   ┌──────┐
  │ Change Desired │──▶│ Init │──▶│ Plan │
  └────────────────┘   └──────┘   └──────┘
           ▲                          │
           │                          ▼
           │                      ┌────────┐
           │                      │ Review │
           │                      └────────┘
           │                          │
           │                          ▼
           │                      ┌───────┐
           └──────────────────────│ Apply │
                                  └───────┘

Figure 1.5  The Terraform deployment flow
```

### 4.1 Change desired

Someone needs new infrastructure, a new feature, a bug fix, or a dependency update. The code change is written first. Like any software change, it may require research and experimentation.

### 4.2 Init — `terraform init`

Downloads providers and modules; initializes the backend. Must be run:

- When first setting up a workspace.
- When adding, removing, or changing providers or modules.
- Terraform reminds you if you forget.

```bash
$ terraform init
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 4.0"...
- Installing hashicorp/aws v4.41.0...
- Installed hashicorp/aws v4.41.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl ...
Terraform has been successfully initialized!
```

> 💡 Commit `.terraform.lock.hcl` to version control so the team always resolves to the same provider versions.

To upgrade providers to the latest versions allowed by your version constraints, pass `--upgrade`:

```bash
terraform init --upgrade
```

> ⚠️ **Pitfall** — `--upgrade` ignores the lock file and re-resolves providers. Review the diff to `.terraform.lock.hcl` before committing — an unintended provider bump can change plan behaviour.

### 4.3 Plan — `terraform plan`

Calculates what changes need to be made. Three internal sub-phases:

1. **Refresh** — reads actual current state from the vendor (and any data sources in code).
2. **Compare** — compares actual state to what the code says should exist.
3. **Plan** — produces a DAG of create / update / delete / replace actions.

```bash
$ terraform plan -out tfplan
data.aws_vpc.default: Reading...
...
Plan: 1 to add, 0 to change, 0 to destroy.
```

- `-out tfplan` saves the plan to a file, so the exact calculated plan is what gets applied (no drift between plan and apply).
- Plan output shows each resource change with `+` (create), `~` (update), `-` (destroy), `-/+` (replace).
- "Known after apply" appears for attributes that can only be known once the resource exists (e.g., auto-generated IDs, ARNs).

**Reading a saved plan file** — the `.tfplan` binary is not human-readable directly. Use `terraform show`:

```bash
terraform show tfplan          # human-readable (same format as plan output)
terraform show -json tfplan    # machine-readable JSON
```

The JSON form is useful with `jq`:

```bash
terraform show -json tfplan | jq '.resource_changes[].change.actions'
```

The binary format is intentional — it includes a hash so Terraform can verify the plan wasn't tampered with between `plan` and `apply`.

### 4.4 Apply — `terraform apply`

Executes the plan: creates, updates, or destroys resources in dependency order. Terraform runs as many operations in parallel as it can.

```bash
$ terraform apply tfplan
aws_instance.hello_world: Creating...
aws_instance.hello_world: Still creating... [10s elapsed]
aws_instance.hello_world: Creation complete after 12s [id=i-01792587739c8e453]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

- If you pass a saved plan file, that exact plan is applied. If no file is passed, Terraform runs a fresh plan first.
- Outputs (values you've declared as outputs) are printed at the end.
- Terraform displays a final summary: N added, N changed, N destroyed.

---

## 5. Real-World Use Cases

A few patterns the author has seen in the wild — illustrating that Terraform is not just "cloud VMs."

### Machine learning training clusters

Spinning up an ML cluster means networking, node templates, a high-performance filesystem, object storage, IAM permissions, autoscaling (Redis + Lambda). Manually, this can take weeks. With Terraform:

- The cluster design is collaboratively built in code over time.
- Clusters can be launched and torn down in minutes, so teams pay only when training runs.

### API and web services

The standard web stack (load balancer, ECS tasks, SSL cert, DNS, database, cache, VPC subnets) is a natural fit for a Terraform module. Developers submit their service code; the module handles all the infrastructure wiring.

### Single sign-on (e.g., Okta)

Managing SSO systems (groups, users, apps, policies, roles) in Terraform gives a clear audit trail and enforces change-review processes for permission changes.

### Rapid prototyping

Terraform modules let developers start a hackathon with working infrastructure in minutes rather than days, freeing them to focus on the idea rather than the plumbing.

---

## 6. Terraform and OpenTofu

### Background

Terraform started under the **Mozilla Public License (MPL)** — open source. This drove its ecosystem: 3,000+ providers, community testing frameworks (Terratest), orchestration tools (Terragrunt), and platforms built on top of it (Spacelift, Scalr, env0).

In 2023, HashiCorp switched future Terraform releases (v1.6+) to the **Business Source License (BSL)** — shared source, not open source. The BSL allows anyone to *use* Terraform, but prohibits building products that compete with HashiCorp's own offerings on top of it.

Contributing was already declining before the license change: HashiCorp stopped reviewing external PRs to Terraform in 2021.

### Community response

A manifesto signed by 150+ companies, 11 projects, and 750+ developers demanded reconsideration. When HashiCorp didn't engage, the signatories followed through and created a fork.

### OpenTofu

- Announced 2023, forked from Terraform v1.5.7 (the last MPL release).
- Backed by Scalr, env0, Spacelift, Harness, and Gruntworks (18 dedicated developers funded for 5+ years).
- Accepted into the **Linux Foundation** (working toward CNCF membership).
- Uses a public RFC process for feature proposals.

### Version relationship

```
Terraform: v1.0 → v1.1 → v1.2 → v1.3 → v1.4 → v1.5 (MPL) → v1.6+ (BSL)
OpenTofu:                                                → v1.6 → v1.7 → … → v1.12 (current)
```

As of May 2026: Terraform is at **v1.15.3** (BSL); OpenTofu is at **v1.12.0** (open source).

### Compatibility

- OpenTofu is currently a **superset** of Terraform: code written for Terraform works in OpenTofu. The reverse is not guaranteed if you use OpenTofu-only features.
- OpenTofu may trail Terraform slightly on new features (needs to review and reimplement independently).
- Package managers (Homebrew, most Linux distros) stopped shipping Terraform at v1.5.7. OpenTofu is supported by open-source package managers.
- The `tofu` CLI has all the same subcommands as `terraform`; you can alias `terraform` → `tofu` and most things will work.

> ❓ Revisit: as OpenTofu diverges further from Terraform (later chapters), what are the practical decision criteria for choosing one over the other in a new project?

---

## 7. Summary

- IaC applies software development practices (VCS, testing, CI/CD) to infrastructure, making it repeatable, reviewable, and sharable.
- Terraform is the de facto standard IaC tool: vendor-agnostic, declarative, provider-based.
- Terraform uses a declarative language (HCL) — you describe the desired end state, and Terraform figures out the actions. No migration scripts.
- Plans are DAGs: resources are created in dependency order; circular dependencies break plans.
- The deployment workflow is always the same: `init` → `plan` → `apply`.
- HashiCorp relicensed Terraform to BSL starting v1.6; OpenTofu is the open-source fork at v1.12.0 (as of 2026-05-18), currently a superset of Terraform.

---

## 8. References

- Terraform Provider Registry — <https://registry.terraform.io/browse/providers>
- OpenTofu GitHub — <https://github.com/opentofu/opentofu>
- HashiCorp BSL license change announcement — <https://mng.bz/rKBE> (contributor docs update, 2021)
- Book source code (Manning) — <https://github.com/terraform-in-depth/terraform-in-depth>
