# Workspaces

> **Sources:** Hafner, *Terraform in Depth* Ch6 §6.4.5 (`cloud` block) + §6.4.7 (CLI workspaces) · Brikman, *Terraform: Up & Running* Ch3 ("Isolation via workspaces") · HCDocs ["Workspaces"](https://developer.hashicorp.com/terraform/language/state/workspaces) · HCDocs ["Managing Workspaces"](https://developer.hashicorp.com/terraform/cli/workspaces) · HCDocs ["HCP Terraform workspaces"](https://developer.hashicorp.com/terraform/cloud-docs/workspaces) · Terraform 1.15.8 source · [Terragrunt docs](https://docs.terragrunt.com/features/units) ("Units", "AWS authentication") · [Atlantis](https://www.runatlantis.io/)

## In one paragraph

"Workspace" names two different systems, and the overlap is the single most common source of confusion in this area. **CLI workspaces** are multiple state files belonging to one configuration in one working directory: same code, same modules, same providers, same credentials, only the state differs. **HCP Terraform workspaces** are independent managed environments on a remote platform, each with its own variables, credentials, run history, and access controls. The `terraform workspace` command drives both, which is exactly why they get conflated. TID Ch6 covers each half; the learning path settles the "which should I use for dev/prod?" question later, in **A7**.

## The two meanings

| | CLI workspaces | HCP Terraform workspaces |
| --- | --- | --- |
| What it is | Several state files for one configuration | Independent environments on a managed platform |
| Shares | Code, modules, providers, backend, credentials | Nothing — each is self-contained |
| Isolates | State only | State, variables, credentials, permissions, run history |
| Configured by | Nothing; just `terraform workspace new` | `cloud` block's `workspaces` sub-block (`tags` or `name`) |
| Suitable for env isolation | **No** | Yes |

The critical asymmetry: CLI workspaces give you a second state file, *not* a second environment. Everything a real dev/prod split needs to differ stays shared: credentials, permissions, blast radius.

## What CLI workspaces buy you

Start from the constraint, because it explains why more than one state file is needed at all. A state file is the map from configuration addresses to real remote objects, and an address is unique within it. One state can therefore hold exactly one `aws_instance.web`. If you want two live copies of a configuration, you need two states. That is not a design choice, it is arithmetic.

So the real question is how you obtain the second state. Without workspaces there are two ways, and both cost something:

- **Re-point the backend.** Run `terraform init -reconfigure -backend-config=…` with a different state key every time you switch. Only one instance is reachable at a time, and the switch is a manual step nothing verifies.
- **Copy the directory.** Now the same code exists twice and has to be kept in sync by hand.

Workspaces are the third way, and HCDocs states the benefit in one line: workspaces let you **"deploy multiple distinct instances of that configuration without configuring a new backend or changing authentication credentials."** What that buys, concretely:

| Benefit | Why it follows |
| --- | --- |
| **No second setup** | Workspaces "let you create different sets of infrastructure with the same working copy of your configuration and the same plugin and module caches" (HCDocs). No extra `init`, no re-downloaded providers, no duplicated `.tf` |
| **Copies cannot drift** | There is only one configuration, so every instance is identical by construction. Directory-per-env has to achieve this with discipline; workspaces get it for free |
| **Independent locking** | Each workspace has its own state file, and the lock is taken on that file, so two workspaces can plan and apply at the same time. A single shared state serialises everyone behind one lock |
| **Contained state operations** | "When you run `terraform plan` in a new workspace, Terraform does not access existing resources in other workspaces" (HCDocs). A `destroy` in a sandbox workspace cannot reach the copy next door |
| **Creation is free** | `terraform workspace new` allocates a state slot. Nothing is provisioned, nothing is configured, nothing needs an admin |
| **The instance has a name in config** | `terraform.workspace` is known at plan time, so it can uniquify globally-unique names such as S3 buckets, and drive `count` or `for_each` |

The canonical use HCDocs gives is testing: **"A common use for multiple workspaces is to create a parallel, distinct copy of a set of infrastructure to test a set of changes before modifying production infrastructure."** In practice that generalises to a per-developer sandbox in a shared dev account, a stack per feature branch or pull request that is destroyed on merge, and the parallel fixtures an integration test harness spins up.

Read the benefit list and the isolation limits together and they describe one mechanism, not two. Workspaces make instances of a configuration cheap precisely *because* everything except state is shared. The share is the feature and the ceiling at the same time.

!!! note "Two different questions about multiple state files"
    "Why more than one state per configuration" is answered above: parallel instances of the same thing. "Why split one system across several states" is a different question, answered by blast radius, apply time, and team ownership, and workspaces are the wrong tool for it. HCDocs is blunt that workspaces are not for **system decomposition**. That second question belongs to **E4 — Large-scale state & repo architecture**.

## Why CLI workspaces are not environment isolation

"Isolation" means a mistake in one environment cannot reach another. A CLI workspace separates exactly one thing, the state file, and leaves every other channel between environments wide open.

| What a dev/prod split needs to differ | CLI workspaces | Directory-per-env, or HCP workspaces |
| --- | --- | --- |
| Configuration and module versions | **Shared.** One set of `.tf` files. You cannot run prod on last month's module while dev tries the new one | Separate — each env pins its own versions |
| Cloud credentials | **Shared.** Whatever is in your shell when you type `apply` | Separate provider config or workspace credentials |
| Backend and storage location | **Shared.** All workspace states live in one bucket under one prefix | Separate bucket, prefix, or workspace |
| Who can read the state | **Shared.** Anyone who can read one workspace's state can read every workspace's state, prod secrets included | Per-environment IAM or RBAC |
| Which environment you are about to touch | **A local file.** `.terraform/environment` inside the gitignored data dir, or `TF_WORKSPACE` | Which directory you are in, or which HCP workspace the `cloud` block names |

That last row is the one that bites. The selected workspace is not part of your configuration. It is a scrap of local state that never appears in a diff, a pull request, or a code review, so the *only* thing standing between a routine change and an unintended production apply is whether the last `terraform workspace select` you ran happened to be the right one:

```bash
terraform workspace select prod
terraform apply    # same code, same credentials, same bucket as dev
```

Nothing in the configuration marks that run as production. Forget the `select` and Terraform silently targets whichever workspace was chosen last — possibly in a different terminal session, possibly days ago.

Using `terraform.workspace` in a lookup map does not fix this. It is a runtime branch inside one shared configuration, so prod's values sit in the same file as dev's, are edited under the same review, and are applied with the same credentials. A branch is not a boundary.

!!! danger "The documented limit"
    HCDocs states it directly: **"Workspaces are not appropriate for system decomposition or deployments requiring separate credentials and access controls."** Note that this is about *credentials and access controls*, not about state layout. Separate state was never the hard part.

Which leaves the boundary from the section above: several short-lived copies of the same thing, at the same risk level, under the same credentials. The moment the copies need different permissions, they have outgrown the mechanism.

!!! note "TUR Ch3 reached the same conclusion in 2022, and explains why the misuse survives"
    [TUR Ch3](../books/tur/chapters/03-manage-state.md) demonstrates the mechanism before judging it: create `example1`, run `plan`, and Terraform proposes building the instance from scratch, because the workspace's state is empty. Then the one-line model — *"switching to a different workspace is equivalent to changing the path where your state file is stored"* — and the `env:` folder in S3 that proves it.

    Its three drawbacks map onto the table above: shared backend and credentials, invisibility in code and terminal, and error-proneness as the product of the two. Its verdict is flat: *"workspaces are not a suitable mechanism for isolating one environment from another."*

    The footnote is the part worth keeping, because it explains the persistence of the anti-pattern. HashiCorp's docs make the same point, but it is *"buried among several paragraphs of text"*, and **workspaces used to be called “environments”** — so the feature's own former name taught the misuse. That is the answer to "why does every course still show a `terraform.workspace` lookup map", and it is why **A7** carries a warning naming two current sources that still do.

## CLI workspaces

Terraform always has a workspace named **`default`**, which cannot be deleted. Commands (TID §6.4.7):

| Command | Effect |
| --- | --- |
| `terraform workspace list` | List available workspaces |
| `terraform workspace new <name>` | Create a workspace |
| `terraform workspace select <name>` | Switch to a workspace |
| `terraform workspace delete <name>` | Delete a workspace |

**Where the state goes.** The local backend keeps the default workspace at `terraform.tfstate` as usual, and every other workspace under a directory named `terraform.tfstate.d` — the constant `DefaultWorkspaceDir` in the local backend source. Remote backends that support multiple workspaces distinguish them with a path prefix instead.

**Which backends support them.** Not all do, and the docs enumerate the ten that do ([[tf-state-workspaces]]): AzureRM, Consul, COS, GCS, Kubernetes, Local, OSS, Postgres, Remote, S3. Absent from that list are **`http`** and **`oci`** (the backend added in Terraform 1.12), so "remote backend" and "supports named workspaces" are separate properties — choosing where state lives does not settle whether you can hold more than one state there.

**Reading the current workspace.** Terraform exposes it as **`terraform.workspace`**, known at **plan time**, so it is legal in `count` and `for_each`. The per-workspace lookup map is the common pattern:

```hcl
locals {
  networks = {
    production = { vpc = "vpc-…", subnets = ["subnet-…", "subnet-…"] }
    staging    = { vpc = "vpc-…", subnets = ["subnet-…"] }
    default    = { vpc = "vpc-…", subnets = ["subnet-…"] }
  }
  current_network = local.networks[terraform.workspace]
}
```

**In automation**, set **`TF_WORKSPACE`** to select a workspace non-interactively rather than calling `terraform workspace select`.

!!! note "Selection is sticky and invisible"
    `terraform workspace select` writes the chosen name to **`.terraform/environment`** (`DefaultWorkspaceFile` in the local backend), inside the gitignored data directory. It persists across commands and terminal sessions until something changes it, and `TF_WORKSPACE` overrides it when set. This is the mechanism behind the isolation limits above: the environment you are targeting lives outside your configuration entirely.

## HCP Terraform workspaces

Selected through the `cloud` block rather than created ad hoc, using **either** `tags` **or** `name` (mutually exclusive), optionally narrowed by `project`:

```hcl
terraform {
  cloud {
    organization = "acme-org"
    hostname     = "app.terraform.io"
    workspaces {
      tags = ["acme_application", "development"]
    }
  }
}
```

With `tags`, Terraform links the directory to every workspace carrying matching tags, and `terraform workspace` switches between them. With `name`, the configuration is pinned to one workspace and `terraform workspace` stops working entirely.

Beyond state, an HCP workspace owns its variables and variable sets, its credentials, its run history and run lifecycle, and its access controls. The `cloud` block also redirects `plan` and `apply` to execute remotely, though not `import` or the `state` subcommands.

!!! warning "Editing `tags` later is not symmetric"
    Adding a tag to the `cloud` block pushes that tag onto the linked workspace in HCP. Removing one does **not** remove it from the workspace — the backend only ever adds. Either edit requires a plain `terraform init` to re-discover the available workspaces. Full detail and provenance in [TID Ch6 §6.4.5](../books/tid/chapters/06-state-management.md).

## The open-source picture

HCP Terraform and Terraform Enterprise are proprietary, so an HCP workspace has no single open-source equivalent. But it is really two things bolted together, and each half has its own open answer. Splitting them makes the question answerable:

| Half of an HCP workspace | Open equivalent |
| --- | --- |
| **Isolation** — own state, own inputs, own credentials, own blast radius | **Terragrunt**, or a hand-rolled directory-per-env layout |
| **Platform** — pull-request runs, approvals, remote execution, audit trail, policy gates, cost estimation | **Atlantis**, or your ordinary CI system |

**Terragrunt covers the isolation half properly.** Its unit is "a directory containing a `terragrunt.hcl` file… the smallest deployable entity in Terragrunt", and units are "designed to be contained, and can be operated on independently of other units." Each unit carries its own state backend configuration and its own `inputs`, so per-environment values are real configuration rather than a `terraform.workspace` branch. Crucially it also supports a per-unit **`iam_role`**:

```hcl
iam_role = "arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME"
```

That is the piece CLI workspaces can never offer — different environments assuming different cloud identities — and it is what makes Terragrunt genuine isolation rather than just tidier directories. It removes the copy-paste that makes a hand-rolled directory-per-env layout painful, while keeping each environment's state, inputs, and credentials separate.

**What Terragrunt does not replace** is the platform half. There is no user model or RBAC, no run history or audit UI, no remote execution (runs happen wherever you invoke them), no policy enforcement or cost estimation, no managed drift detection. For pull-request-driven runs with approvals, the open option is **Atlantis** — self-hosted, so credentials stay with you, and it lets developers open Terraform pull requests without holding cloud credentials directly.

So the accurate framing is not "there is no open equivalent". It is that HCP sells one product where the open ecosystem gives you two tools, and you assemble them yourself.

!!! note "Where this sits in the learning path"
    Terragrunt is deep-dived in **E4 — Large-scale state & repo architecture**, not in A7. A7 deliberately stays on native Terraform primitives, because that is the scope the Pro exam tests. Reach for Terragrunt once you have many states and teams, not for a single dev/prod split. Terragrunt **1.0** (2026-03-30) was the first release with a backwards-compatibility commitment, and renamed `run-all` to `run --all`; it works over both Terraform and OpenTofu, and defaults to OpenTofu when both are on `PATH`. The line is now at **1.1.3** (2026-08-13).

    The full source-derived surface — CLI and HCL blocks, explicit stacks, the `--filter` query language, the content-addressable store — is in [[terragrunt-facts]], mined from the local `repos\terragrunt` checkout with every claim version-gated.

## When to read which

- The `terraform workspace` command surface and `terraform.workspace`? → [TID Ch6 §6.4.7](../books/tid/chapters/06-state-management.md).
- The `cloud` block, tags vs name, and `terraform login`? → [TID Ch6 §6.4.5](../books/tid/chapters/06-state-management.md).
- Why CLI workspaces are not environment isolation? → HCDocs "Workspaces", and the fuller tradeoff in **A7**.
- HCP workspace settings, variable sets, run lifecycle? → **A4**.

## Still to come

Both learning-path topics that own this subject are unstarted, so this page is currently built on TID Ch6 plus the official docs:

- **A4 — HCP Terraform / Terraform Cloud** will add workspace settings, variable sets, the run lifecycle, and health assessments.
- **A7 — Multi-environment & multi-account patterns** will add the decisive comparison, from TUR Ch3 §"Isolation via Workspaces" (p94) against §"Isolation via File Layout" (p100), plus the multi-account half from TUR Ch7.

Related: [[core-workflow]], [[tf-state-workspaces]] for the HCDocs page this leans on, [[workspaces-facts]] for the raw verified research, and the **state** topic once it graduates from the [topics backlog](index.md).
