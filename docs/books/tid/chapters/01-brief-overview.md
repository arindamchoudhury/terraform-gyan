# Chapter 1 — A brief overview of Terraform

> *Source: Hafner (2025), **Terraform in Depth**, Chapter 1, pages 3–23.*
>
> A scene-setting chapter: what IaC is, the shape of Terraform's core components (language, CLI, providers, vendors, backends, workspaces), declarative vs. imperative languages, the init/plan/apply deployment flow, real-world use cases, and the Terraform → OpenTofu fork story.
>
> 📌 **Notes adapted where version-bound.** The book was written in 2025 against Terraform pre-1.6 BSL cutover context. Current stable is Terraform CLI **1.15.7** (1.15 released 2026-04-29, BSL 1.1) and OpenTofu **1.12.3** (1.12 released 2026-05-14, MPL 2.0) — see [[version-facts]] for the full divergence list (state encryption, provider `for_each`, early variable evaluation, `-exclude`, dynamic `prevent_destroy`). The chapter's conceptual content (IaC, declarative model, init/plan/apply) is unaffected by version drift.

> 🔗 **See also:** [IaC fundamentals](../../../topics/iac-fundamentals.md), [Core workflow](../../../topics/core-workflow.md), and [Providers](../../../topics/providers.md), each synthesizing this chapter with [[terraform-intro]].

---

## 1.1 Infrastructure as code

- **IaC** = a class of technology letting developers provision infrastructure using coding practices. Terraform isn't the only IaC tool — Pulumi is another vendor-agnostic framework; AWS CloudFormation and GCP Deployment Manager are vendor-specific. Terraform is "the standard" per the author: mature, broad coverage, not locked to one vendor, and uses its own declarative language rather than bolting onto general-purpose or data-only (YAML) languages.
- IaC is framed as the natural next step after configuration-management tools (Puppet, Chef) and image-builders (Packer) — those configure/build machines; IaC frameworks codify and repeatedly deploy entire platforms.

### 1.1.1 Software development practices with IaC

Because IaC is code, it inherits software engineering practices: versioning with Git, linting for quality/security, CI/CD pipelines, PR review gates, audit trails. This is presented as the core reason IaC scales better than "system admins working on machines directly."

### 1.1.2 Repeatability and shareability

- Terraform achieves repeatability through **modules** (full treatment: Ch 3).
- The pitch: wrap infra research/config into a reusable module once, other teams build on it without redoing the labor; improvements to the module cascade to every consumer.

### 1.1.3 Continuous integration and deployment

- **TACOS** — Terraform Automation and Collaboration Software — the informal industry term for CI/CD platforms purpose-built for running Terraform (HCP Terraform, Terraform Enterprise, Spacelift, Scalr). They integrate with GitHub/GitLab to auto-publish modules from tags, run speculative plans on PRs, and manage merge-triggered deploys.
- Common pattern: pair a Terraform-specific system with a general CI/CD tool (GitHub Actions, CircleCI, Jenkins) — the general tool handles broader job types (test/format/lint) alongside other project results.
- Full CI/CD treatment is Ch 7.

## 1.2 Terraform overview

Terraform's core value proposition: **one language for thousands of vendors.** The Terraform Core (inside the CLI) translates HCL into calls against **providers**, which each wrap a vendor's API.

> There are currently more than 3,280 providers in the Terraform Provider Registry (per the book, 2025 figure).

### 1.2.1 Terraform language

- **HCL** (HashiCorp Configuration Language) — designed for readability, declarative (define end state, not steps).
- HCL is shared across HashiCorp products (Packer, Nomad, Consul) but each exposes its own resources/functions and structural quirks — this book covers the Terraform flavor specifically.

### 1.2.2 Terraform CLI and core

The CLI is the only way to invoke Terraform core — unlike compiled languages (Go, C) you don't get a standalone binary from your config; it's closer to Python/Node needing an interpreter. CI/CD systems (HCP Terraform, Spacelift) wrap the CLI rather than reimplementing core.

### 1.2.3 Providers

- A **provider** = plugin supplying data sources, resources, and functions for one vendor. Written in Go, communicates with Terraform core over **gRPC**.
- One-to-one with a vendor generally (AWS provider, GCP provider); some vendors ship multiple (Azure).
- You don't need gRPC knowledge to *use* Terraform — only relevant if authoring a custom provider (Ch 12).

### 1.2.4 Vendors

Terraform itself is vendor-agnostic — it only cares that a provider exists. Examples of provider categories: cloud, DNS, data analytics, VM hosts, git repos, auth systems — plus novelty ones (pizza delivery, McDonald's ice-cream-machine status).

### 1.2.5 Backends

- **Backend** = where a workspace's state is stored. Default is **local** (state on your filesystem) — fine solo, doesn't scale to teams.
- Non-local backends: object storage (S3, GCS, AzureRM), open-source databases, even a generic HTTP backend for custom services.
- **Remote** and **cloud** backends go further — they expose APIs Terraform can call to run operations remotely, not just store state.
- Full backend treatment: Ch 6.

### 1.2.6 Workspaces

A **workspace** = one deployment of a codebase against a specific backend + input variables — analogous to "one installation of a program." A single codebase can have unlimited workspaces (prod, staging, ephemeral feature branches) sharing a backend, each with its own state slot.

## 1.3 Declarative languages

- **Declarative** = define the desired end state; the engine computes the plan to get there. Terraform's plans are **directed acyclic graphs (DAGs)** — ordered action lists. (Deeper DAG/debugging treatment: Ch 5.)
- Declarative languages dominate config-management/IaC: Terraform HCL, Kubernetes YAML, CloudFormation YAML, Puppet's DSL.

### 1.3.1 Declarative vs. imperative languages

> One-line framing: declarative languages primarily use **nouns and adjectives**; imperative languages primarily use **verbs**.

With Terraform you never write "check if this machine exists, create it if not, then configure it" (imperative) — you describe the machine you want and Terraform derives the actions. This removes the need for migration scripts and makes moving between versions/states easier.

### 1.3.2 Dependency resolution

Terraform infers ordering **implicitly** from value references — if the application config reads a value from the database resource, Terraform knows the database must be created first. No explicit `depends_on` needed for this case; the reference itself defines the edge in the DAG.

### 1.3.3 Pitfalls of declarative languages

- Biggest pitfall: **circular dependencies** — a cycle in the resource graph (e.g. resource 2 → 4 → 3 → 2) cannot be resolved automatically; some manual workaround is required. Terraform's tools for handling unavoidable circular cases are covered in Ch 5.
- Circular dependencies are generally frowned upon in distributed systems design, but come up in practice.

## 1.4 Terraform deployment flow

The flow: **change desired → init → plan → review → apply.** init/plan/apply are all CLI-driven, though usually invoked by a CI/CD system rather than a human directly.

### 1.4.1 Change desired

Scope varies — new project from scratch, feature addition, bugfix, dependency bump. Workflow shape varies by team; may require research/experimentation before writing code.

### 1.4.2 Init

`terraform init` — initializes the backend, then installs providers/modules referenced in the config (from the public registry or a private one if configured).

```bash
$ terraform init
Initializing the backend...
Initializing provider plugins...
- Finding HashiCorp/aws versions matching "~> 4.0"...
- Installing HashiCorp/aws v4.41.0...
- Installed HashiCorp/aws v4.41.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control
repository so that Terraform can guarantee to make the same selections by
default when you run "terraform init" in the future.

Terraform has been successfully initialized!
```

> 💡 Providers are cryptographically signed so you know who published them. Re-run `init` whenever you change modules or backend config.

### 1.4.3 Plan

`terraform plan` has three internal subphases:

- **Refresh** — read real infrastructure state from the vendor + any data sources, to catch drift since the last run.
- **Compare** — diff refreshed state against what the code expects.
- **Plan** — build the DAG of actions needed to reconcile the two.

```bash
$ terraform plan -out tfplan
data.aws_vpc.default: Reading...
data.aws_ami.ubuntu: Reading...
...
Terraform will perform the following actions:

  # aws_instance.hello_world will be created
  + resource "aws_instance" "hello_world" {
      + ami           = "ami-0cb81cb394fc2e305"
      + instance_type = "t3.micro"
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

- `+` / `~` / `-` symbols mark create/update/destroy actions; some attribute values show `(known after apply)` when they can't be resolved until the resource actually exists.
- `terraform graph` can output the plan's DAG for visualization (e.g. via GraphViz) — same information as the plan text, shown as a dependency diagram.

### 1.4.4 Apply

`terraform apply <planfile>` executes the plan's actions in dependency order. If no plan file is supplied, Terraform computes one fresh as part of the apply.

```bash
$ terraform apply tfplan
aws_instance.hello_world: Creating...
aws_instance.hello_world: Still creating... [10s elapsed]
aws_instance.hello_world: Creation complete after 12s [id=i-01792587739c8e453]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:
aws_instance_arn = "arn:aws:ec2:us-east-2:966612157092:instance/i-01792587739c8e453"
```

Terraform parallelizes independent operations where the DAG allows, so apply is close to as fast as the underlying vendor APIs allow.

## 1.5 What are people using this for?

Four real-world use-case sketches from the author's experience — narrower and more anecdotal than the [[terraform-use-cases]] official doc, which is broader (9 scenarios) but less personal.

### 1.5.1 Machine learning training

Renting GPU/compute clusters from cloud vendors for ML training. Terraform benefits: (1) the code itself is the collaborative design artifact — start simple, iterate (e.g. add autoscaling later); (2) clusters can be spun up/torn down in moments, so idle-cluster cost is minimized. A typical cluster needs networking, machine templates, a high-perf filesystem, high-reliability model storage, IAM permissions, plus a Redis queue + Lambda for autoscaling triggers.

### 1.5.2 API and web services

The classic stack — load balancers, app "task" instances, TLS certs, DNS records, cache layer, database — all sitting on network layers (subnets, NAT, private/public split). Wrapping this in a module lets application developers consume infrastructure without understanding its internals.

### 1.5.3 Single sign-on authentication structure

Managing SSO systems (e.g. Okta) as Terraform-managed resources: users, group membership, groups, policies, applications. Benefit is less about repeatability and more about **auditability and change control** — Terraform-managed SSO makes it easy to enforce multi-approver review on permission changes, with a source-control audit trail.

### 1.5.4 Rapid prototyping

For hackathons/startups: reusable modules maintained by domain experts let a team skip the "spend a day standing up infra basics" tax and focus on the actual idea being tested.

## 1.6 Terraform and OpenTofu

The fork story, chapter's own framing:

### 1.6.1 HashiCorp's history with open source

Terraform started under MPL (open source). HashiCorp built a large ecosystem this way (community providers, docs tooling, testing frameworks, third-party modules). Around 2021 HashiCorp updated its contributor docs to state it would not review external PRs to Terraform — an early signal of the shift the book traces.

### 1.6.2 HashiCorp license changes

- Aug 2023: HashiCorp announced relicensing Terraform (and Nomad, Consul, Vault, others) from MPL to **BSL** (Business Source License) starting with Terraform 1.6.
- BSL = "shared source": code stays publicly viewable/auditable, but usage is restricted — specifically prohibits "offering the licensed work to third parties on a hosted or embedded basis which is competitive with HashiCorp's products." Individual/company internal use remains permitted.
- Terraform *providers* and many individual HashiCorp libraries remained MPL — only the core products moved to BSL.

### 1.6.3 Community reactions

- A manifesto (Aug 2023) asked HashiCorp to reconsider — signed by 150+ companies, 11 software projects, 750+ individual developers — explicitly threatening a fork if HashiCorp didn't engage.
- Concern centered on Terraform's dependence on third-party-built providers and tooling (e.g. Gruntworks' Terratest/Terragrunt) — community felt the shift undercut the ecosystem that made Terraform valuable in the first place.

### 1.6.4 OpenTofu fork

- HashiCorp didn't respond to the manifesto → **OpenTofu** was announced as the fork.
- Backed by Scalr, env0, Spacelift, and Harness committing ~18 dedicated developers for 5+ years; Gruntworks also committed support.
- OpenTofu joined the **Linux Foundation** (working toward CNCF) specifically so it isn't subject to a single company's control; runs a public RFC process for feature proposals.

### 1.6.5 OpenTofu and Terraform compatibility

- OpenTofu has stayed compatible with Terraform-written code, while also implementing long-requested community features Terraform lacks — making OpenTofu a **superset** of the Terraform language.
- Trade-off: easy to move Terraform → OpenTofu; moving back can be harder if you've adopted OpenTofu-only features. OpenTofu also lags slightly on brand-new Terraform features since it has to independently re-implement them.

> 🔗 The specific feature-diff list is superseded by [[version-facts]] (state encryption, provider `for_each`, early variable evaluation, `-exclude`, dynamic `prevent_destroy`) — see also learning path topic **E3 — OpenTofu deep dive**.

### 1.6.6 Using OpenTofu

- OpenTofu is a drop-in replacement — same commands, and `tofu` can be aliased to `terraform`.
- Post-relicense, several open-source package managers (Homebrew included) stopped shipping Terraform versions beyond **v1.5.7**; OpenTofu remained available through those channels.
- The book states nearly every example works with both tools unless explicitly called out, particularly in the testing/CI-CD chapters where real differences emerge.

---

## Summary

- IaC lets software-engineering practices (versioning, linting, CI/CD) apply to infrastructure.
- Declarative languages define the end state; the engine computes how to get there.
- Terraform is built on HCL; plans are DAGs (ordered actions, no circular dependencies allowed).
- Core workflow: **init** (fetch providers/modules) → **plan** (refresh, compare, plan) → **apply** (execute the DAG).
- HashiCorp's move away from open source (BSL, starting Terraform 1.6) produced the **OpenTofu** fork — mostly interchangeable today, with differences called out through the book.

---
Related: [[terraform-intro]] and [[terraform-use-cases]] — this chapter's §1.1–1.2 covers the same IaC/provider/workflow ground as the official intro docs, in more narrative/anecdotal form; §1.5 is a personal-experience companion to the official use-cases page's 9 scenarios. Feeds the **B1 — Infrastructure as Code** milestone.
