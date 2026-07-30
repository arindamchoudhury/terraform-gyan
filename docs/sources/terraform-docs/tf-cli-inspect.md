# Inspect Infrastructure Commands Overview

> **Source:** [developer.hashicorp.com/terraform/cli/inspect](https://developer.hashicorp.com/terraform/cli/inspect)
> **Added:** 2026-07-30
> **Source updated:** undated CLI reference; captured 2026-07-30 against v1.15.x (latest)
> **Tags:** cli, inspection, graph, output, show, state-list, state-show, json, tool-integration
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Inspecting Infrastructure › Overview · v1.15.x*

The section index for the five read-only commands. No mechanics on it — it exists to name the group and say what the group is *for*. The command inventory itself is already in [[tf-cli-commands]]; what this page adds is the framing.

## The framing

> "Terraform configurations and state data include some highly structured information about the resources they manage; this includes dependency information, outputs… and more."

> "Terraform CLI includes some commands for inspecting or transforming this data. You can use these to **integrate other tools with Terraform's infrastructure data**, or just to gain a deeper or more holistic understanding of your infrastructure."

Two audiences in one sentence, and the first is the one worth noticing. These commands are the sanctioned **integration surface** — the way other software reads what Terraform knows. That is the same argument [[tf-state]] makes from the state side: the state format is explicitly allowed to change between versions, so `terraform show -json` and `terraform output -json` are the supported parse targets, not the file. This page is where those commands are grouped under that purpose.

## The five commands

| Command | What the page says it does | Captured in |
|---|---|---|
| `terraform graph` | "creates a visual representation of a configuration or a set of planned changes" | [[tf-cmd-graph]] |
| `terraform output` | gets "the values for the top-level output values of a configuration, which are often helpful when making use of the infrastructure Terraform has provisioned" | [[tf-outputs]], [[tut-outputs]] |
| `terraform show` | "generate human-readable versions of a state file or plan file, or generate **machine-readable** versions that can be integrated with other tools" | [[05-terraform-plan]] §5 |
| `terraform state list` | lists "the resources being managed by the current working directory and workspace, providing a complete or filtered list" | [[06-state-management]] §6.5.3 (in the `state rm` example) |
| `terraform state show` | prints "all of the attributes of a given resource… **including generated read-only attributes like the unique ID assigned by the cloud provider**" | [[tf-cmd-state-show]]; used in [[tf-state-refactor]] step 2 |

Two details in that table are worth pulling out.

**`output` is root-only.** "Top-level output values" — the same root-module restriction that makes [[tf-remote-state-data]] require an explicit passthrough `output` block for anything nested.

**`state show` is how you find an import ID.** The read-only attributes it prints are exactly what an `import` block needs, which is why [[tf-state-refactor]] uses it as step 2 of a migration before writing the `removed` block.

!!! note "Scope: current working directory *and* workspace"
    Both `state` subcommands are described as operating on "the current working directory **and workspace**". Nothing here reaches across workspaces — consistent with [[tf-state-workspaces]], where a plan in one workspace "does not access existing resources in other workspaces." So `state list` showing nothing may mean you are in the wrong workspace, not that nothing is managed.

---
Related: [[tf-cli-commands]] — the full command index this is a section of. · [[tf-cmd-graph]] — the one command in this group with its own note so far. · [[tf-state]] — why the `-json` forms are the supported way for other software to read Terraform's data. · [[tf-cmd-refresh]] — its sibling section, *Manually Update State*, which changes state rather than reading it.
