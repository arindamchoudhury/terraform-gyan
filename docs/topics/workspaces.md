# Workspaces

> **Sources:** Hafner, *Terraform in Depth* Ch6 §6.4.5 (`cloud` block) + §6.4.7 (CLI workspaces) · HCDocs ["Workspaces"](https://developer.hashicorp.com/terraform/language/state/workspaces) · HCDocs ["HCP Terraform workspaces"](https://developer.hashicorp.com/terraform/cloud-docs/workspaces) · Terraform 1.15.8 source · [Terragrunt docs](https://docs.terragrunt.com/features/units) ("Units", "AWS authentication") · [Atlantis](https://www.runatlantis.io/)

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

The critical asymmetry: CLI workspaces give you a second state file, *not* a second environment. Everything a real dev/prod split needs to differ — credentials, permissions, blast radius — stays shared.

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

**What CLI workspaces are genuinely good for:** several short-lived copies of the same thing, at the same risk level, under the same credentials. Per-developer sandboxes in a shared dev account, a stack per feature branch, a scratch copy for testing a refactor. The moment the copies need different permissions, they have outgrown the mechanism.

## CLI workspaces

Terraform always has a workspace named **`default`**, which cannot be deleted. Commands (TID §6.4.7):

| Command | Effect |
| --- | --- |
| `terraform workspace list` | List available workspaces |
| `terraform workspace new <name>` | Create a workspace |
| `terraform workspace select <name>` | Switch to a workspace |
| `terraform workspace delete <name>` | Delete a workspace |

**Where the state goes.** The local backend keeps the default workspace at `terraform.tfstate` as usual, and every other workspace under a directory named `terraform.tfstate.d` — the constant `DefaultWorkspaceDir` in the local backend source. Remote backends that support multiple workspaces distinguish them with a path prefix instead.

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
    Terragrunt is deep-dived in **E4 — Large-scale state & repo architecture**, not in A7. A7 deliberately stays on native Terraform primitives, because that is the scope the Pro exam tests. Reach for Terragrunt once you have many states and teams, not for a single dev/prod split. Terragrunt **1.0** (2026-03-30) was the first release with a backwards-compatibility commitment, and renamed `run-all` to `run --all`; it works over both Terraform and OpenTofu.

## When to read which

- The `terraform workspace` command surface and `terraform.workspace`? → [TID Ch6 §6.4.7](../books/tid/chapters/06-state-management.md).
- The `cloud` block, tags vs name, and `terraform login`? → [TID Ch6 §6.4.5](../books/tid/chapters/06-state-management.md).
- Why CLI workspaces are not environment isolation? → HCDocs "Workspaces", and the fuller tradeoff in **A7**.
- HCP workspace settings, variable sets, run lifecycle? → **A4**.

## Still to come

Both learning-path topics that own this subject are unstarted, so this page is currently built on TID Ch6 plus the official docs:

- **A4 — HCP Terraform / Terraform Cloud** will add workspace settings, variable sets, the run lifecycle, and health assessments.
- **A7 — Multi-environment & multi-account patterns** will add the decisive comparison, from TUR Ch3 §"Isolation via Workspaces" (p94) against §"Isolation via File Layout" (p100), plus the multi-account half from TUR Ch7.

Related: [[core-workflow]], and [[state-management]] once that backlog topic is written.
