# Chapter 1 — Why Terraform

> *Source: Brikman (2022), **Terraform: Up & Running**, 3rd ed., Chapter 1, pages 1–38.*
>
> The book's argument for its own existence, in three moves: what IaC is (five tool categories, not one), what it buys you, and why Brikman's company picked Terraform over Chef, Puppet, Ansible, Pulumi, CloudFormation and OpenStack Heat. No code is deployed in this chapter — every snippet is illustrative.
>
> 📌 **Notes adapted where version-bound.** The comparison data is dated **June 2022** and the chapter is the most perishable in the book: it is a landscape survey, and the landscape moved. Terraform is no longer open source, one of the compared tools has been forked by its own community for the same reason Terraform was, two of the named runtimes are dead, and the two headline rivals of the chapter now share an owner. Concepts (the five categories, mutable vs immutable, procedural vs declarative, master/agent) are untouched by any of that. Details in [Version reckoning](#version-reckoning) at the end; current tooling versions in [[version-facts]].

> 🔗 **See also:** [IaC fundamentals](../../../topics/iac-fundamentals.md) — this chapter is the third source on that page and by far the most opinionated, so the topic page gains a "where the sources differ" entry rather than a new section of facts.

---

## What is DevOps?

The chapter opens with a failure story rather than a definition, and the story is the useful part.

Historically Dev wrote software and Ops racked hardware. Dev would "toss it over the wall" and Ops deployed by hand. That works until it doesn't:

- Manual releases get slower as the server count grows.
- Mistakes accumulate into **snowflake servers** — each subtly different from the rest, a condition called **configuration drift**.
- Bug counts and outages rise. Developers say *"it works on my machine!"*
- Ops, tired of 3 a.m. pages, cuts the release cadence to monthly, then twice a year. Release branches stop stabilizing, merges become disasters, silos form.

The modern counterweight is that Ops now spends its day in software rather than in cabling, which is where DevOps comes from. Brikman's working definition is deliberately short:

> The goal of DevOps is to make software delivery vastly more efficient.

The four values are **CAMS** — culture, automation, measurement, sharing — and the chapter openly narrows to just *automation*, which is what leads into IaC. The cited transformation results (Nordstrom, HP LaserJet, Etsy deploying 25–50×/day) come from *The DevOps Handbook* (Kim, Humble, Debois, Willis, 2016).

> 💭 (mine): configuration drift is introduced here as a *people* problem — it reappears in the mutable-vs-immutable section as a *tooling* problem, and again in TID Ch6 as a *state* problem. Same word, three layers.

## What is infrastructure as code?

The definition is broad on purpose: you write and execute code to define, deploy, update and destroy infrastructure, treating **all** of operations as software. Servers, databases, networks, logs, app config, docs, tests, deployment processes.

The taxonomy is the part of this chapter worth memorizing, because most tool arguments are really category confusions:

| Category | Examples | What it does |
| --- | --- | --- |
| Ad hoc scripts | Bash, Python, Ruby | Whatever you were doing manually, transcribed |
| Configuration management | Chef, Puppet, Ansible | Install and manage software on **existing** servers |
| Server templating | Docker, Packer, Vagrant | Build an **image** capturing a full snapshot of a machine |
| Orchestration | Kubernetes, ECS, Nomad, Docker Swarm, Marathon/Mesos | Deploy, scale, heal and route across VMs/containers |
| Provisioning | Terraform, CloudFormation, OpenStack Heat, Pulumi | Create the **servers themselves** — and databases, load balancers, subnets, certificates … |

### Ad hoc scripts

The joke lands because it's true:

> The great thing about ad hoc scripts is that you can use popular, general-purpose programming languages, and you can write the code however you want. The terrible thing about ad hoc scripts is that you can use popular, general-purpose programming languages, and you can write the code however you want.

Purpose-built IaC tools give you a concise API and impose a structure; a general-purpose language gives you neither, so every developer solves the same problem differently. Fine for eight lines that install Apache, unmaintainable across dozens of servers.

### Configuration management tools

The same Apache setup as an Ansible role, and three advantages over the script:

- **Coding conventions** — a predictable structure for docs, file layout, parameter naming, secrets.
- **Idempotence** — *"code that works correctly no matter how many times you run it."* Making the Bash version idempotent means hand-writing existence checks everywhere; most Ansible modules are idempotent by default.
- **Distribution** — built to target many remote servers. A `hosts` inventory plus a playbook configures five servers in parallel; setting `serial: 2` turns it into a rolling deployment two at a time.

```bash
ansible-playbook playbook.yml
```

### Server templating tools

Instead of configuring N servers identically, build **one image** and install it N times. Two families:

- **Virtual machines** — emulate an entire computer including hardware, via a hypervisor (VMware, VirtualBox, Parallels). Full isolation, exact reproduction across environments; the cost is a whole extra OS per VM in CPU, memory and boot time. Defined as code with Packer or Vagrant.
- **Containers** — emulate only the **user space** of an OS, via a container engine (Docker, rkt, cri-o). Boot in milliseconds with near-zero overhead; the cost is a shared kernel, so isolation is weaker.

!!! note "The kernel-space / user-space footnote is worth keeping"
    Code in **kernel space** has direct unrestricted hardware access and no safety net — a crash there takes the machine down — so it is reserved for the kernel itself. Code in **user space** reaches hardware only through OS APIs, which can enforce permissions and contain crashes. A container virtualizes the second of those, a VM virtualizes underneath both.

    Brikman's rule of thumb: containers isolate well enough for **your own** code; if you must run **third-party** code that might be actively malicious, take the VM.

The Packer example builds an AMI with PHP, Apache and the app baked in — and deliberately does **not** start Apache, because a template installs software while a *running* image is what starts it.

```bash
packer build webserver.json
```

The three templating tools are not interchangeable: Packer builds images for production servers, Vagrant builds images for developer laptops, Docker builds images of individual applications. A common composition is Packer → an AMI with the Docker Engine → containers scheduled onto that fleet.

This section is also where **immutable infrastructure** is defined, and the analogy is the memorable bit:

> The idea behind immutable infrastructure is similar [to immutable variables]: once you've deployed a server, you never make changes to it again. If you need to update something … you create a new image from your server template and you deploy it on a new server.

### Orchestration tools

Templating gives you images; orchestration answers *"now what?"* The chapter's list of six needs is a decent checklist for evaluating any orchestrator:

1. Deploy VMs/containers efficiently across hardware.
2. Roll out updates — rolling, blue-green, canary.
3. Monitor health and replace unhealthy instances (**auto healing**).
4. Scale with load (**auto scaling**).
5. Distribute traffic (**load balancing**).
6. Let instances find each other (**service discovery**).

The Kubernetes Deployment example is used to show how much a few lines of YAML buy: a Pod definition, three replicas, a `RollingUpdate` strategy with `maxSurge: 3` / `maxUnavailable: 0`, and a scheduler that places Pods for availability, resources and load, then keeps three alive forever.

```bash
kubectl apply -f example-app.yml
```

### Provisioning tools

The category Terraform is in. Config management, templating and orchestration all define *what runs on a server*; provisioning creates the server — and the database, cache, load balancer, queue, subnet, firewall rule, routing rule and TLS certificate.

```hcl
resource "aws_instance" "app" {
  instance_type     = "t2.micro"
  availability_zone = "us-east-2a"
  ami               = "ami-0fb653ca2d3203ac1"

  user_data = <<-EOF
              #!/bin/bash
              sudo service apache2 start
              EOF
}
```

Two parameters carry the argument. `ami` can point at the image the Packer template built; `user_data` starts Apache at boot. That is provisioning and server templating working together, which the chapter names as the common shape of immutable infrastructure.

## What are the benefits of infrastructure as code?

The framing question is honest — why take on more code to manage? — and the answer is that infrastructure gets to inherit software engineering.

| Benefit | The argument |
| --- | --- |
| Self-service | Deployment stops being gated on the one sysadmin who knows the incantations and has prod access. |
| Speed and safety | A computer executes the steps faster, more consistently, and without fat-fingering them. |
| Documentation | Infrastructure stops living in one person's head. IaC *is* the documentation. |
| Version control | The commit log becomes the infrastructure's history — first debugging step is `git log`, and revert is a real option. |
| Validation | Code review, automated tests and static analysis all become available. |
| Reuse | Package into modules instead of rebuilding every environment from scratch. |
| Happiness | Manual deploys are tedious, unrewarded, and only noticed when they go wrong. |

The cited 2016 *State of DevOps Report* numbers: 200× more frequent deploys, 24× faster failure recovery, 2,555× lower lead times.

The **bus factor** footnote is the one to keep: your team's bus factor is how many people you can lose before you can no longer operate the business, and *"you never want to have a bus factor of 1."*

## How does Terraform work?

The mechanical description, which is short because Terraform is short:

- Open source tool by HashiCorp, written in Go, compiled to a **single binary** per OS.
- Runs from a laptop or a build server. **No extra infrastructure to stand up.**
- Under the hood it makes API calls to **providers** (AWS, Azure, Google Cloud, DigitalOcean, OpenStack …), so it reuses both the provider's own API servers and the credentials you already have with them.
- Your `.tf` files declare what you want; `terraform apply` parses them, translates them into API calls, and issues those calls as efficiently as possible.

The example that makes the point is two resources from two clouds in one file — an EC2 instance, and a Google Cloud DNS record whose `rrdatas` references `aws_instance.example.public_ip`. One syntax, interconnected resources, two providers.

!!! quote "Sidebar — transparent portability between clouds is a red herring"
    The recurring question is whether Terraform lets you redeploy an AWS stack on Azure with a flag. Brikman's answer:

    > The reality is that you can't deploy "exactly the same infrastructure" in a different cloud provider because the cloud providers don't offer the same types of infrastructure!

    Servers, load balancers and databases differ across clouds in features, configuration, management, security, scalability, availability and observability, and plenty of functionality has no counterpart at all. Terraform's actual promise is narrower and more honest: **provider-specific code, but one language, one toolchain and one set of IaC practices across all of them.**

    Same conclusion TID Ch1 reaches by calling Terraform "vendor-agnostic" rather than "portable" ([[01-brief-overview]]).

## How does Terraform compare to other IaC tools?

The section opens with a fair complaint about tool comparisons: most of them list properties and imply you'd succeed equally with any choice, which is *"technically true but … omits a huge amount of information."* What follows is explicitly Gruntwork's decision, not a neutral survey.

Ten trade-offs, in the chapter's order.

### 1. Configuration management vs provisioning

Chef, Puppet, Ansible manage config; CloudFormation, Terraform, Heat, Pulumi provision. The line is blurry (Ansible can create a server; Terraform can run scripts on one) so pick by primary use case.

The sharpest observation: **if you use server templating, most of your configuration management need has already been met** — once the image exists, all that's left is provisioning infrastructure to run it. Without templating, the standard pairing is Terraform to provision and Ansible to configure.

### 2. Mutable vs immutable infrastructure

Config management tools default to **mutable**: tell Chef to install a new OpenSSL and it updates the existing servers in place. Over months each server accumulates a private history, and drift bugs appear that reproduce in prod but not in test.

Provisioning tools deploying Docker/Packer images default to **immutable**: a new OpenSSL means a new image, new servers, terminate the old ones. Benefits — less drift, you know exactly what's running, any previous version is redeployable, and tests are more meaningful because the artifact that passed in test is the artifact that ships.

The honesty is what makes the section good. Two costs the chapter names itself:

- Rebuilding an image and redeploying every server for a trivial change is **slow**.
- Immutability lasts only until the image runs — a live server starts writing to disk immediately, so drift resumes (mitigated, not eliminated, by deploying often).

### 3. Procedural vs declarative

The chapter's best worked example, and the one to reuse when explaining Terraform to anyone.

Ansible (procedural) and Terraform (declarative) both deploy 10 servers, and look equivalent:

```yaml
- ec2:
    count: 10
    image: ami-0fb653ca2d3203ac1
    instance_type: t2.micro
```

```hcl
resource "aws_instance" "example" {
  count         = 10
  ami           = "ami-0fb653ca2d3203ac1"
  instance_type = "t2.micro"
}
```

Now go to 15. Editing the Ansible `count` to 15 and rerunning deploys **15 more**, giving 25 — so you write a *different* template with `count: 5`. In Terraform you change `10` to `15` in the same file, and `terraform plan` reports `Plan: 5 to add, 0 to change, 0 to destroy.` Change the AMI and the same asymmetry repeats: procedural needs a third template that hunts down whatever is running; declarative edits one field.

Two consequences, stated as the problems with procedural IaC:

- **Procedural code does not fully capture the state of the infrastructure.** Reading the templates isn't enough — you need the *order* they were applied in. "To reason about an Ansible or Chef codebase, you need to know the full history of every change that has ever happened."
- **Procedural code limits reusability.** Reusable code must account for current state manually, and state changes constantly, so last week's code may no longer apply.

> Terraform codebases tend to stay small and easy to understand.

The chapter concedes Ansible has `instance_tags` / `count_tag` to find existing instances — and that doing this by hand for every resource, keyed on tags *and* image version *and* availability zone, is exactly the complexity a state file exists to remove.

### 4. General-purpose language vs DSL

Chef (Ruby) and Pulumi (JS, TypeScript, Python, Go, C#, Java …) use general-purpose languages. Terraform (HCL), Puppet (Puppet Language), Ansible/CloudFormation/Heat (YAML, plus JSON for CFN) use DSLs.

| DSL advantages | GPL advantages |
| --- | --- |
| Easier to learn — one domain, smaller language | You may already know the language |
| Clearer and more concise for the one job | Far bigger ecosystem, mature IDEs, libraries, testing tools |
| More uniform — roughly one way to do a thing | More power: loops, conditionals, abstraction, tests, integrations |

The distinction is called out as *"more of a helpful mental model than a clean, separate categorization."* Pulumi's Automation API is named as the extreme case — infrastructure code embedded inside application code.

> 💭 (mine): this table is the single best answer to "why is HCL so limited?" The limits **are** the feature being sold — there is really only one way to deploy a server in Terraform, and hundreds in Java.

### 5. Master vs masterless

Chef and Puppet default to a master server that stores state and distributes updates. It buys a central place to see everything (Chef Console, Puppet Enterprise Console) and continuous enforcement that can revert manual changes. It costs:

- **Extra infrastructure** — a server, or a cluster of them for HA.
- **Maintenance** — upgrade, back up, monitor, scale it.
- **Security** — extra ports and extra auth systems in both directions, so more attack surface.

Ansible, CloudFormation, Heat, Terraform and Pulumi are masterless — or more precisely, their "master" is infrastructure you already have. Terraform's masters are the cloud provider's API servers, authenticated with API keys you already hold; Ansible connects over SSH with keys you already hold.

### 6. Agent vs agentless

Chef and Puppet install agent software on every managed server. Three costs: **bootstrapping** (how does the agent get there in the first place?), **maintenance** (update it, keep it in sync with the master, restart it when it dies) and **security** (inbound or outbound ports on every server, plus agent authentication).

Agentless modes exist for both but read as afterthoughts, so in the wild the idiomatic Chef/Puppet setup has an agent and usually a master too. The consequence is the reason this matters at 3 a.m.:

> Each time you get a bug report at 3 a.m., you'll need to figure out whether it's a bug in your application code, or your IaC code, or the configuration management client, or the master server(s), or the way the client communicates with the master server(s) …

Terraform's agents are the ones AWS/Azure/GCP already run on their own hardware — you never see them.

### 7. Paid vs free

CloudFormation and Heat are free outright. Terraform, Chef, Puppet, Ansible and Pulumi all have free and paid versions. The only question the chapter asks is the right one: **is the free version viable for real production use, if the paid service disappeared?**

- Terraform, Chef, Puppet, Ansible — yes; paid services improve them, but you'd survive without.
- Pulumi — effectively no. Its default state backend is Pulumi Service, and the alternatives (S3, Azure Blob, GCS) lacked transactional checkpointing, concurrent state locking, and encryption in transit and at rest.

The warning behind the question is worth keeping and has aged perfectly: paid services aren't under your control. They get acquired, discontinued, or repriced — Chef, Puppet and Ansible had all been through acquisitions that changed their commercial offerings, and Pulumi's 2021 repricing raised costs ~10× for some users.

!!! info "Verified 2026-08-11 — the Pulumi self-managed-backend gap has narrowed"
    Pulumi's DIY backend docs now state: *"A basic file-based locking system is enabled by default for all DIY backends."* So **concurrent state locking is no longer a paid-only feature.**

    The checkpointing limitation survives, in gentler wording: DIY backends keep checkpoint history in `.pulumi/history/`, but *"because they are fundamentally limited by the non-transactional protocols of blob storage, they cannot transparently recover from certain kinds of partial failures."*

    Read the book's conclusion as directionally right and specifically stale. Sources: [Pulumi — State and Backends](https://www.pulumi.com/docs/iac/concepts/state-and-backends/), [Pulumi — Using a DIY Backend](https://www.pulumi.com/docs/iac/operations/stack-management/using-a-diy-backend/).

### 8. Large vs small community

Table 1-1 counts contributors, GitHub stars, community libraries and Stack Overflow questions as of **June 2022**, and Table 1-2 compares those to the first edition's September 2016 figures. The specific numbers are stale; two structural findings are not:

- Every tool compared is open source and multi-cloud **except CloudFormation**, which is closed source and AWS-only.
- Ansible and Terraform lead on popularity and were growing fastest — Terraform's registry module count had grown 24,003% and its Stack Overflow question count 10,106% since 2016.

The chapter is also upfront that the counts understate Terraform: provider code moved out into separate repos in 2017, so the main repo's contributor and star totals miss most of the ecosystem's activity.

### 9. Mature vs cutting edge

Table 1-3 pairs initial release dates with a subjective maturity rating: Chef (2009) and Puppet (2005) most mature; Terraform (2014) medium and improving, with 1.0.0 called out as the stability milestone; Pulumi (2017) youngest and least mature, visible in thinner docs, best practices and community modules.

> ⚠️ The printed table is mangled by the PDF's column alignment — the dates and versions do not line up with the tool names in the extracted text. Trust the prose, not the table.

### 10. Use of multiple tools together

The concession that undercuts the whole comparison, and is the most practically useful section:

| Combination | Example | Upside | Downside |
| --- | --- | --- | --- |
| Provisioning + config management | Terraform + Ansible | Nothing extra to run; easy to wire up (Terraform tags servers, Ansible finds them by tag) | Lots of procedural code on mutable servers; maintenance gets harder as you grow |
| Provisioning + server templating | Terraform + Packer | Nothing extra to run; immutable | VM builds are slow; Terraform's deployment strategies are limited (no native blue-green) |
| Provisioning + templating + orchestration | Terraform + Packer + Docker + Kubernetes | Fast image builds, testable locally, plus K8s auto healing/scaling/deployment strategies | Kubernetes is expensive to run and adds three abstraction layers to learn and debug |

## Conclusion

Table 1-4 is the payoff — the default shape of each tool across every axis above. Reconstructed (the PDF's version is column-shifted):

| | Chef | Puppet | Ansible | Pulumi | CloudFormation | Heat | Terraform |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Source | Open | Open | Open | Open | **Closed** | Open | Open |
| Cloud | All | All | All | All | **AWS** | All | All |
| Type | Config mgmt | Config mgmt | Config mgmt | Provisioning | Provisioning | Provisioning | Provisioning |
| Infra | Mutable | Mutable | Mutable | Immutable | Immutable | Immutable | Immutable |
| Language | Procedural | Declarative | Procedural | Declarative | Declarative | Declarative | Declarative |
| Language type | GPL | DSL | DSL | GPL | DSL | DSL | DSL |
| Master | Yes | Yes | No | No | No | No | No |
| Agent | Yes | Yes | No | No | No | No | No |
| Paid service | Optional | Optional | Optional | **Must-have** | N/A | N/A | Optional |
| Community | Large | Large | Huge | Small | Small | Small | Huge |
| Maturity | High | High | Medium | Low | Medium | Low | Medium |

And the criteria that produced the choice, stated as a shopping list rather than a verdict:

> an open source, cloud-agnostic provisioning tool with a large community, a mature codebase, and support for immutable infrastructure, a declarative language, a masterless and agentless architecture, and an optional paid service.

Terraform is *"although not perfect … the closest"* fit. The chapter ends by asking whether those are **your** criteria.

### State of the running example

Nothing deployed. The web server cluster starts in Chapter 2; the `aws_instance` and Packer snippets here are illustrations, and the AMI `ami-0fb653ca2d3203ac1` (Ubuntu 20.04, `us-east-2`) is the same hardcoded ID that recurs through the book.

---

## Version reckoning

A landscape chapter dated June 2022 needs more correction than any other chapter in this book. Grouped by how much it changes the argument.

!!! danger "Terraform is no longer open source — the first row of Table 1-4 is wrong"
    On **2023-08-10** HashiCorp relicensed from MPL 2.0 to the **Business Source License 1.1**, across Terraform, Vault, Consul, Boundary, Nomad, Waypoint, **Packer** and Vagrant. Effective for releases from Terraform **1.6** onward. Internal use to manage your own infrastructure is unaffected; embedding, redistributing or offering Terraform-as-a-service is what the license targets.

    The community response was the **OpenTofu** fork (manifesto 2023-08-15, fork announced 2023-08-25), now a Linux Foundation project under MPL 2.0. Current: Terraform **1.15.8** (BSL), OpenTofu **1.12.4** (MPL) — [[version-facts]].

    Two knock-on corrections inside this chapter:

    - **Table 1-4 needs an eighth column.** OpenTofu is open/all/provisioning/immutable/declarative/DSL/masterless/agentless — the row Terraform used to occupy exactly.
    - **"Provisioning + server templating: Terraform + Packer"** is now a **two-BSL-tool** combination, since Packer was relicensed in the same announcement. There is no widely-adopted Packer fork; the Vault equivalent is OpenBao.

!!! warning "Terraform and Ansible now have the same owner"
    The chapter's central either/or is Terraform vs Ansible. As of 2026 both are IBM's: IBM acquired Red Hat in 2019 (Red Hat acquired Ansible in 2015), and **IBM's acquisition of HashiCorp closed 2025-02-27**. Nothing technical changes, but "pick the tool with independent commercial backing" is no longer a way to choose between them.

    Ownership of the rest also moved: **Chef → Progress Software (September 2020)**, **Puppet → Perforce (2022)**.

!!! info "Puppet got its own OpenTofu — the pattern repeated"
    In November 2024 Perforce announced that new Puppet binaries and packages would ship to a *private, hardened, controlled* location, with commercial licensing beyond 25 nodes. The Vox Pupuli community forked, releasing **OpenVox** on **2025-01-21**; Perforce refused permission to use the Puppet name.

    Worth noting next to the BSL entry above, because the chapter's "open source" column silently assumed vendor behaviour stays put. Two of its seven tools have since proven otherwise, and in both cases the community fork is what preserved the property.

!!! note "Two of the named runtimes are dead"
    - **CoreOS rkt** — CNCF archived the project on **2019-08-16** (adoption moved to containerd and CRI-O); the GitHub repo was archived 2020-02-24. Read every "Docker, CoreOS rkt, or cri-o" in this chapter as "Docker, containerd, or CRI-O".
    - **Apache Mesos** — narrowly avoided the Attic in April 2021, then retired in **August 2025**, with the move completed October 2025. "Marathon/Mesos" in the orchestration list is now historical.

    Docker Swarm survives but is not where new work goes; Kubernetes and the managed services (EKS/GKE/AKS) won that category outright.

!!! note "Naming, pricing and stale tables"
    - **Terraform Cloud was renamed HCP Terraform on 2024-04-22.** Functionality unchanged, `app.terraform.io` module sources still work. Every "Terraform Cloud" in this book means HCP Terraform. Its legacy free plan ended 2026-03-31; the replacement free tier caps at 500 managed resources ([[version-facts]]).
    - **Tables 1-1 and 1-2 (community) and 1-3 (maturity) are June-2022 snapshots** and should be read only for their trend, not their values. Terraform's own maturity rating in particular predates 1.6 through 1.15 and the entire fork.
    - **Terraform's registry now carries 4,000+ providers**, against the "thousands" framing here.
    - `t2.micro`, `m4.large` and the hardcoded `ami-0fb653ca2d3203ac1` are all previous-generation or region-locked; prefer an `aws_ami` data source or SSM parameter lookup.

!!! tip "What survives untouched"
    Everything conceptual, which is most of the chapter: the five-category taxonomy, idempotence, the VM/container distinction, immutable infrastructure and its two named costs, the procedural-vs-declarative worked example, the DSL/GPL trade-off table, master-vs-masterless, agent-vs-agentless, the bus-factor argument, and the closing point that you will use several of these tools together rather than picking one. The chapter's method — decide by explicit criteria, then show which tool fits them — is also worth more than its 2022 conclusion.

---

*Related notes:* [IaC fundamentals](../../../topics/iac-fundamentals.md) topic page · TID Ch1 [[01-brief-overview]] for the same ground from a 2025 author who covers the fork · [[terraform-intro]] for the official five-pillar framing · [[iac-tool-comparison]] for the verified tool-by-tool facts behind the reckoning above · [[version-facts]] for current versions and licensing. Feeds learning-path **B1**.
