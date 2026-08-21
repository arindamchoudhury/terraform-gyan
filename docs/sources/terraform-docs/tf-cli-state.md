# Update Terraform State Manually Overview

> **Source:** [developer.hashicorp.com/terraform/cli/state](https://developer.hashicorp.com/terraform/cli/state)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest)
> **Tags:** cli, state, manual-state, backups, taint, state-mv, state-rm, disaster-recovery, section-index
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Overview · v1.15.x*

The section index for every CLI operation that **writes** state. It is the mirror of [[tf-cli-inspect]], which indexes the read-only commands. Like that page it carries no mechanics — it names the group, states the risk, and links out. The whole page is four short paragraphs and a list of five links.

## Introduction

The page opens by restating what state is for, then narrows to why a human would ever touch it:

> "Terraform automatically updates state when you run the `terraform plan` and `terraform apply` commands, but you may need to manually adjustment state data as a result of changes to the configuration or the real managed infrastructure."

Two things in that sentence.

**`plan` is named as a writer of state**, alongside `apply`. That is the same fact [[tut-state-cli]] closes on — refresh runs inside `plan`, `apply` and `destroy`, all of which can modify the state file. An ordinary plan is not read-only. It is worth having on the section index too, because it sets the boundary for the whole group: these commands exist for the changes the automatic path cannot make.

**The trigger is drift in either direction** — the configuration moved, or the real infrastructure did. That is the same two-sided framing [[06-state-management]] uses for its drift buckets.

The word *state data* links to [[tf-state]], not to any CLI page.

## Workflow

The warning is the substance of the page, and it is blunter than the individual command references are:

> "Modifying state data outside of normal `terraform plan` or `terraform apply` operations can cause Terraform to lose track of managed resources, leading to **increased costs, reduced productivity, or compromised security**. Make sure to keep backups of your state data if you choose to manually modify state."

Three named consequences, and *compromised security* is the one no other captured page states in this context. The backup instruction is unconditional here — no "if remote", no "if a team". [[tf-state-refactor]] operationalises it as a `terraform state pull > backup` step, and gets the filename wrong in its own example.

The five interactions the page lists, each a link into a sub-section:

| Link | Target | Covered here by |
|---|---|---|
| Inspect state | `cli/state/inspect` | [[tf-cmd-state-list]], [[tf-cmd-state-show]], [[tf-cmd-refresh]] |
| Re-create resources | `cli/state/taint` | [[tf-cli-state-taint]] |
| Move resources | `cli/state/move` | [[tf-state-refactor]] (the cross-configuration case), [[tf-block-moved]] (the config-driven alternative) |
| Import existing resources | `cli/import` | [[tf-import]] and its children, [[tf-block-import]] |
| Recover state from backup | `cli/state/recover` | [[tf-cmd-force-unlock]] (one of its three pages) |

!!! note "The naming here is tainting-flavoured; the destination is not"
    *Re-create resources* points at `cli/state/taint`, and its sub-group is named **Forcing Re-creation (Tainting)**. Neither name mentions `terraform apply -replace`, which superseded `taint`/`untaint` in 0.15.2.

    **Corrected 2026-08-21 after capturing the destination** ([[tf-cli-state-taint]]): that page **leads with `-replace`** and names `taint` only to deprecate it, so a reader clicking through does *not* land on the deprecated pair. What is stale is the URL, the link text and the group label — not the guidance behind them. Unlike [[tf-cli-state-inspect]] one sub-group over, which genuinely does describe a deprecated command as current.

## The group this page heads

The sidebar (rung 1, `__NEXT_DATA__`) gives *Manually Update State* one loose page, one command reference, and four sub-groups. This is the inventory the **I7** toolkit list has been quoting from without a source behind it:

| Sub-group | Pages | Captured |
|---|---|---|
| — | Resource Addressing (`state/resource-addressing`) | no |
| — | `state` command reference (`cli/commands/state`) | no |
| Inspecting State | Overview, `state list`, `state show`, `refresh` | 3 of 4 |
| Forcing Re-creation (Tainting) | Overview, `taint`, `untaint` | 1 of 3 |
| Moving Resources | Overview, `state mv`, `state rm`, `state replace-provider` | none |
| Disaster Recovery | Overview, `state pull`, `state push`, `force-unlock` | 1 of 4 |

Two structural facts fall out of that table.

**`state list` and `state show` are filed twice** — under *Inspecting Infrastructure* and again under *Inspecting State* here. The notes nav follows the first, matching the rule that a doubly-filed page goes under the task-oriented section.

**`replace-provider` sits under *Moving Resources***, not under a provider section. So HashiCorp classes rewriting a provider source address as a state move, which is the right mental model for it: the resources do not change, their addresses' provider half does.

!!! note "Hands-on link"
    The page's only tutorial pointer is *Manage Resources in Terraform State* — [[tut-state-cli]], already captured. That tutorial is the narrative version of exactly this index: read raw state, `-replace`, `state mv`, a `removed` block, `import`, reconcile an out-of-band delete.

## Page flaws

Three errors in four paragraphs, all in the Introduction and Workflow text: *"real-world object that correspond"*, *"you may need to manually adjustment state data"*, and *"the following state interations"*. Cosmetic, but they suggest this index was written quickly around the sub-sections rather than reviewed with them.

---
Related: [[tf-cli-inspect]] — its read-only counterpart; the two sections split the CLI's state surface between them. · [[tf-cli-commands]] — the full command index both sections sit inside. · [[tf-state]] — what the page links for *state data*. · [[tut-state-cli]] — the hands-on version of this index, and the source for `plan` writing state. · [[tf-state-remove]] — the forget-without-destroying procedure, which the language docs cover rather than this CLI section. · [[tf-state-refactor]] — where the backup instruction on this page becomes a concrete step.
