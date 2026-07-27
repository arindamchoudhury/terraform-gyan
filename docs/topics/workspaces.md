# Workspaces

> **Sources:** Hafner, *Terraform in Depth* Ch6 §6.4.5 (`cloud` block) + §6.4.7 (CLI workspaces) · HCDocs ["Workspaces"](https://developer.hashicorp.com/terraform/language/state/workspaces) · HCDocs ["HCP Terraform workspaces"](https://developer.hashicorp.com/terraform/cloud-docs/workspaces) · Terraform 1.15.8 source

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

!!! danger "The documented limit of CLI workspaces"
    HCDocs states it directly: "Workspaces are not appropriate for system decomposition or deployments requiring separate credentials and access controls." A workspace switch does not change who you are authenticating as, so nothing prevents a `terraform apply` in the `staging` workspace from reaching production infrastructure with production credentials. For genuine isolation the alternatives are directory-per-environment layouts or HCP workspaces — the comparison the learning path defers to **A7**.

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
