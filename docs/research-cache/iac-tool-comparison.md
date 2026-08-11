# IaC/config-mgmt tool comparison — verified facts

**Checked:** 2026-07-03 (Libcloud added 2026-07-04; landscape-since-2022 section added 2026-08-11)

## What changed in the landscape since TUR Ch1 (June 2022)

Verified 2026-08-11 while writing the TUR Ch1 note, whose comparison tables are all dated June 2022.

| Fact | Verified value | Source |
|---|---|---|
| HashiCorp relicensing | MPL 2.0 → **BUSL 1.1 on 2023-08-10**, across Terraform, Vault, Consul, Boundary, Nomad, Waypoint, **Packer**, Vagrant. Terraform effective from 1.6. | [HashiCorp announcement](https://www.globenewswire.com/news-release/2023/08/10/2723189/0/en/HashiCorp-adopts-the-Business-Source-License-for-future-releases-of-its-products.html), [InfoQ](https://www.infoq.com/news/2023/08/hashicorp-adopts-bsl/) |
| OpenTF → OpenTofu | Manifesto 2023-08-15; fork announced 2023-08-25; now a Linux Foundation project under MPL 2.0. | same |
| Terraform Cloud rename | **HCP Terraform as of 2024-04-22**; functionality unchanged, `app.terraform.io` sources still valid. | [HCP Terraform docs](https://developer.hashicorp.com/terraform/cloud-docs) |
| Chef ownership | Acquired by **Progress Software, September 2020**. | [Progress press release](https://www.globenewswire.com/de/news-release/2020/09/08/2089870/0/en/Progress-Announces-Acquisition-of-Chef.html) |
| Puppet ownership | Acquired by **Perforce, 2022**. Nov 2024: new binaries/packages move to a private controlled location, commercial licence beyond 25 nodes. | [The New Stack](https://thenewstack.io/openvox-the-community-driven-fork-of-puppet-has-arrived/) |
| Puppet community fork | **OpenVox**, first release **2025-01-21** by Vox Pupuli; Perforce refused use of the Puppet name. Soft fork, aims to stay downstream-compatible. | [InfoWorld](https://www.infoworld.com/article/3809889/puppet-open-source-fork-openvox-arrives.html) |
| Ansible ownership | Red Hat acquired Ansible 2015; IBM acquired Red Hat 2019. With the HashiCorp deal closing 2025-02-27, **Terraform and Ansible share an owner (IBM)**. | [Red Hat](https://www.redhat.com/en/ibm), [[version-facts]] |
| CoreOS rkt | **CNCF archived 2019-08-16** (adoption moved to containerd/CRI-O); GitHub repo archived 2020-02-24. | [CNCF](https://www.cncf.io/blog/2019/08/16/cncf-archives-the-rkt-project/) |
| Apache Mesos | Nearly retired April 2021; **retired August 2025**, Attic move completed October 2025. | [Apache Attic](https://attic.apache.org/projects/mesos.html) |
| Pulumi DIY state locking | No longer paid-only: *"A basic file-based locking system is enabled by default for all DIY backends."* | [Pulumi — Using a DIY Backend](https://www.pulumi.com/docs/iac/operations/stack-management/using-a-diy-backend/) |
| Pulumi DIY checkpointing | Still limited: DIY backends keep history in `.pulumi/history/` but *"cannot transparently recover from certain kinds of partial failures"* because blob storage protocols are non-transactional. | [Pulumi — State and Backends](https://www.pulumi.com/docs/iac/concepts/state-and-backends/) |

## Terraform vs Ansible

- **Model:** Terraform is declarative (desired end state, engine computes the plan). Ansible is imperative — playbooks are explicit step-by-step instructions, even though written in YAML.
- **Agentless is not a differentiator.** Both tools are agentless. Terraform talks to cloud provider APIs; Ansible executes over SSH (or an API) against already-running machines.
- **State.** Terraform maintains a state file and diffs it against config on every `plan`. Ansible holds no persistent state — it re-runs its steps each time (idempotency is the playbook author's responsibility, not a stored diff).
- **Primary use case.** Terraform provisions and tracks infrastructure lifecycle. Ansible configures/orchestrates already-existing systems (package installs, service config, software deploys) — the two are commonly used together (Terraform provisions, Ansible configures what Terraform created), not as strict either/or alternatives.

Sources: [Red Hat — Ansible vs. Terraform](https://www.redhat.com/en/topics/automation/ansible-vs-terraform), [Spacelift — Terraform vs. Ansible](https://spacelift.io/blog/ansible-vs-terraform)

## Terraform vs Pulumi

- **Languages.** Pulumi programs are written in general-purpose languages — Python, TypeScript, JavaScript, Go, Java, C#, or YAML. Terraform uses its own DSL, HCL.
- **Declarative vs imperative.** Sources frame this carefully: both tools are ultimately declarative in *outcome* (you still get a desired-state model and a plan/preview), but Pulumi's *authoring* style is imperative — real loops, conditionals, classes, and package management, versus HCL's limited runtime logic and reuse-only-through-modules.
- **Practical trade-off:** Pulumi programs get full IDE tooling (autocomplete, type checking, refactoring) since they're real code; HCL is more constrained but purpose-built and more widely adopted for pure infra provisioning.

Sources: [Pulumi docs — Pulumi vs. Terraform](https://www.pulumi.com/docs/iac/comparisons/terraform/), [Spacelift — Pulumi vs. Terraform](https://spacelift.io/blog/pulumi-vs-terraform)

## Terraform vs AWS CloudFormation

- Not separately re-verified this session — TID Ch1 already states CloudFormation is AWS-vendor-specific (as opposed to Terraform's multi-vendor provider model), which matches long-standing, non-version-sensitive product positioning. No new facts needed here.

## Terraform vs Apache Libcloud

- **What it is.** Apache Libcloud is a Python library, open-sourced in 2009 by Cloudkick, incubated at Apache the same year, graduated to a top-level Apache project in May 2011. It's a **library**, not a standalone CLI tool or platform — you `import` it into Python code.
- **What it does.** Hides API differences across cloud providers behind one unified Python API. Covers compute/servers, block storage, object storage + CDN, load-balancer-as-a-service, DNS, and deployment. Supports 50+ public/private cloud providers.
- **Model.** Imperative, not declarative — you write Python that calls Libcloud methods to create/list/destroy resources directly, closer to using a cloud SDK than to Terraform's write→plan→apply loop. No state file, no plan/diff step, no dependency graph — the developer's code *is* the sequence of operations.
- **Relationship to Terraform.** Different category more than direct competitor: Libcloud is a low-level abstraction library you build automation *with*; Terraform is a complete IaC tool with its own workflow, state tracking, and provider ecosystem *built on top of* that kind of API-abstraction idea. In practice, teams have evaluated replacing Terraform with Libcloud for narrow scripted use cases, and some multi-cloud tooling recommends combining the two rather than choosing one exclusively.

Sources: [Apache Libcloud — official site](https://libcloud.apache.org/), [Apache Libcloud — GitHub](https://github.com/apache/libcloud), [Apache Libcloud — About](https://libcloud.apache.org/about.html)
