# `terraform refresh` command

> **Source:** [developer.hashicorp.com/terraform/cli/commands/refresh](https://developer.hashicorp.com/terraform/cli/commands/refresh)
> **Added:** 2026-07-30
> **Source updated:** undated CLI reference; captured 2026-07-30, re-verified 2026-08-21 — still v1.15.x (latest)
> **Tags:** cli, refresh, refresh-only, deprecated, drift, state, auto-approve
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Inspecting State › `refresh` · v1.15.x*

A deprecation notice with a command attached. Confirms what [[05-terraform-plan]] §5 already says about `terraform refresh`, and adds the exact equivalence and the docs' own wording for the failure mode.

!!! note "Re-verified 2026-08-21 — byte-identical, and it is now the counter-evidence in a documented pattern"
    Re-fetched and diffed against the July capture: **no change in three weeks**. The deprecation still sits in the second sentence.

    What changed is the surroundings. Two pages that route readers here have since been captured, and **neither repeats the deprecation**. [[tf-cli-state-inspect]], the section index one click above this reference, describes the command in neutral present tense and never mentions `-refresh-only`. [[tut-state-cli]]'s final exercise reconciles an out-of-band delete with a bare `terraform refresh`, no notice and no alternative. Together with [[tf-cli-state]] fronting `taint`/`untaint` for re-creation, that is three index-level pages lagging the references they point at — this page is the reference they are lagging.

    The index does supply one thing this page does not: the reason a standalone refresh still has a job at all. Refreshing happens automatically during plans and applies, *"but not when interacting with state directly"* — nothing in the `state` subcommand family refreshes ([[tf-cmd-state]]), so state read through them is as stale as the last plan left it. That is a narrower job than the command's own closing advice implies, and it does not change the advice: use `plan`, or `-refresh-only` when you mean to accept drift.

## What it does, and what it is

> "The `terraform refresh` command reads the current settings from all managed remote objects and updates the Terraform state to match. **This command is deprecated.** Instead, add the `-refresh-only` flag to `terraform apply` and `terraform plan` commands."

The direction of effect is the thing to keep straight: **"This does not modify your real remote objects, but it modifies the Terraform state."** Reality wins; state is rewritten to match.

The exact equivalence, which TID states loosely as "no approval step":

```shell
terraform refresh
# is effectively an alias for
terraform apply -refresh-only -auto-approve
```

Three consequences the page spells out. It "supports all of the same options as `terraform apply` **except** that it does not accept a saved plan file, it doesn't allow selecting a planning mode other than 'refresh only', and `-auto-approve` is always enabled."

That last one is not a default you can turn off. There is no flag that makes `terraform refresh` prompt.

## The failure mode, in the docs' own words

!!! danger "Misconfigured credentials can empty your state without a prompt"
    > "Automatically applying the effect of a refresh is risky. If you have **misconfigured credentials** for one or more providers, Terraform may be misled into thinking that all of the managed objects have been **deleted**, causing it to **remove all of the tracked objects without any confirmation prompt**."

    [[05-terraform-plan]] frames the same trap as credentials *expiring mid-refresh*; the docs frame it as credentials being *misconfigured* at the start. Same outcome either way — a provider that cannot see its objects reports them gone, and refresh believes it. Nothing is destroyed in the cloud; the damage is that Terraform forgets it owns anything, and the next plan proposes recreating all of it.

The recommended form gives you the review step back:

```shell
terraform apply -refresh-only
```

> "This alternative command will present an interactive prompt for you to confirm the detected changes."

## Version boundary, and the standing advice

`-refresh-only` for `plan` and `apply` "was introduced in Terraform **v0.15.4**." Before that, `terraform refresh` was the only way to get the behavior — which is why the command still exists rather than being removed.

The closing advice goes one step further than "use the flag instead":

> "Wherever possible, **avoid using `terraform refresh` explicitly** and instead rely on Terraform's behavior of automatically refreshing existing objects as part of creating a normal plan."

So the ordinary answer to drift is not a refresh command at all. A normal `terraform plan` already refreshes in memory and shows the drift ([[05-terraform-plan]]); `-refresh-only` is for when you want to *accept* that drift into state without changing infrastructure.

---
Related: [[05-terraform-plan]] — TID Ch5 on planning modes, `-refresh=false`, and this command's deprecation. · [[tf-state-purpose]] — why state caches attributes and what a refresh reconciles. · [[tf-cli-commands]] — where `refresh` sits in the command index. · [[feature-history]] — the deprecation row and the 0.15.4 boundary.
