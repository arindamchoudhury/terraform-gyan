# Inspect Terraform State Overview

> **Source:** [developer.hashicorp.com/terraform/cli/state/inspect](https://developer.hashicorp.com/terraform/cli/state/inspect)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest)
> **Tags:** cli, state, inspection, state-list, state-show, refresh, deprecated, section-index
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Inspecting State › Overview · v1.15.x*

Four sentences. The smallest page captured from this collection, and it exists to name three commands: `state list`, `state show`, `refresh`. All three already have notes ([[tf-cmd-state-list]], [[tf-cmd-state-show]], [[tf-cmd-refresh]]), so what follows is the little this adds and the one thing it gets wrong.

## What the group is

> "Terraform includes some commands for **reading and updating** state without taking any other actions."

*Reading and updating* — not inspecting, despite the section being called *Inspecting State*. The qualifier that makes the grouping coherent is **"without taking any other actions"**: nothing here touches real infrastructure. Two of the three commands are read-only and the third writes state only.

That is a different cut from *Inspecting Infrastructure* ([[tf-cli-inspect]]), where `state list` and `state show` also appear. There the criterion is *read-only*, and `refresh` is excluded; here it is *no side effects on infrastructure*, and `refresh` is included. Same two commands, two sections, two justifications.

## The three descriptions

**`state list`** shows the resource addresses for every resource "optionally filtered by **partial resource address**". That phrase is the only place in this section the incomplete-address idea is named directly — and it is exactly the behaviour [[tf-resource-addressing]] warns about, since a partial address matches all instances beneath it.

**`state show`** "displays detailed state data about **one** resource" — the arity contrast with `state list`, stated in the shortest form it appears anywhere.

**`refresh`** "updates state data to match the real-world condition of the managed resources", with the clause that earns the command its place here:

> "This is done automatically during plans and applies, **but not when interacting with state directly**."

That is the only justification any captured page gives for a standalone refresh: the `state` subcommands do not refresh, so state read through them is as stale as the last plan left it.

!!! danger "This page presents `terraform refresh` with no deprecation notice"
    Its own command reference opens with *"**This command is deprecated.** Instead, add the `-refresh-only` flag to `terraform apply` and `terraform plan`"* ([[tf-cmd-refresh]]), and spells out why: `refresh` is effectively `apply -refresh-only -auto-approve`, `-auto-approve` cannot be turned off, and misconfigured provider credentials can therefore *"remove all of the tracked objects without any confirmation prompt."*

    None of that appears here. The section index one click above the reference describes the command in neutral present tense and never mentions `-refresh-only` at all. A reader arriving from the sidebar meets the recommendation-free version first.

    This is the **third** place in this collection with the same shape: [[tut-state-cli]]'s final exercise reconciles an out-of-band delete with a bare `terraform refresh`, and [[tf-cli-state]] routes *Re-create resources* to `taint`/`untaint` without mentioning `-replace`. The pattern is consistent — the command references are current, and the pages that index them were not updated alongside.

---
Related: [[tf-cli-state]] — the parent section index; this is one of its four sub-groups. · [[tf-cli-inspect]] — the other section `state list` and `state show` are filed under, cut by *read-only* rather than by *no infrastructure side effects*. · [[tf-cmd-state-list]] · [[tf-cmd-state-show]] · [[tf-cmd-refresh]] — the three commands, all captured; the last one contradicts this page's framing of it. · [[tf-cmd-state]] — why nothing in the `state` family refreshes.
