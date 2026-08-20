# Manage resources in Terraform state

> **Source:** [developer.hashicorp.com/terraform/tutorials/state/state-cli](https://developer.hashicorp.com/terraform/tutorials/state/state-cli)
> **Added:** 2026-08-20
> **Source updated:** undated tutorial (~24 min); transcripts show Terraform 1.7.0 / AWS provider v5.31.0; captured 2026-08-20
> **Tags:** state, state-mv, removed-block, replace-flag, taint, terraform-refresh, import, state-anatomy, state-list, show
> **Type:** documentation

Third page of the **State** collection (sidebar: *Import · Migrate state · **Manage resource state** · Target resources · Troubleshooting · Resource drift · Lifecycle rules · Version state · Refresh state · Console · Move resources*). Repo: `github.com/hashicorp-education/learn-terraform-state`. Requires **Terraform 1.7+** — the version the `removed` block landed in — plus an AWS account and the `awscli`. Free-tier resources, but real ones.

The longest page in the collection and the one that runs the **whole state toolkit as a single narrative**: apply, read the raw JSON, force a replacement, move a resource between two state files, forget it, import it back, reconcile an out-of-band delete, destroy. Everything it touches has a reference note of its own; what this page adds is the *sequence*, and a handful of transcripts nothing else shows.

## What the state file actually contains

The configuration is deliberately small — one `aws_security_group`, one `aws_instance`, one `aws_ami` data source — so the JSON stays readable. The page's framing of the `resources` array:

- **`mode`** — `managed` for a resource, `data` for a data source. Both live in the same array, which is why `terraform state list` shows `data.aws_ami.ubuntu` alongside the resources.
- **`type`** / **`name`** / **`provider`** — the address, plus the fully-qualified provider that owns it (`provider["registry.terraform.io/hashicorp/aws"]`).
- **`instances[].schema_version`** — `0` for the data source, `1` for the instance. Per-resource-type, and the hook for provider state upgrades.
- **`instances[].attributes`** — the flattened object as the provider last reported it.
- **`instances[].dependencies`** — `["aws_security_group.sg_8080", "data.aws_ami.ubuntu"]`.

Two observations the page makes that are worth keeping:

**Attributes are stored resolved, not as written.** *"The `security_groups` attribute, for example, is captured in plain text in state as opposed to the variable interpolated string in the configuration file."* State holds `"terraform-learn-state-sg-8080"`, not `aws_security_group.sg_8080.name`. That is the whole reason state can hold secrets ([[tf-state]]).

**Dependencies are recorded whether you wrote them or not.** *"Because your state file has a record of your dependencies, enforced by you with a `depends_on` attribute or by Terraform automatically, any changes to the dependencies will force a change to the dependent resource."* This is [[tf-state-purpose]]'s **retained dependencies** seen from the file side — the copy that survives so a destroy can be ordered after the configuration is gone.

!!! danger "Do not manually modify state files"
    > You should not manually change information in your state file in a real-world situation to avoid unnecessary drift between your Terraform configuration, state, and infrastructure. Any change in state could result in your infrastructure being destroyed and recreated at your next `terraform apply`.

    The page opens the file only to read it, and says so directly about the CLI: *"This is how you should interact with your state."* `terraform show` for the human-readable dump ([[tf-cmd-show]]), `terraform state list` for addresses only ([[tf-cmd-state-list]]) — the latter recommended *"for more complex configurations where you need to find a specific resource without parsing state with `terraform show`."*

## `-replace`, and the death of `taint`

```shell
terraform plan -replace="aws_instance.example"
terraform apply -replace="aws_instance.example"
```

```text
  # aws_instance.example will be replaced, as requested
-/+ resource "aws_instance" "example" {
Plan: 1 to add, 0 to change, 1 to destroy.
```

`will be replaced, as requested` is the tell — the plan states that *you* asked, not that the configuration diverged. Nothing in the configuration changed.

The page's own framing of when to reach for it: *"in cases of system malfunction"*, when someone changed a setting by hand, or when a provisioning script needs re-running. And the scoping argument — *"The `-replace` flag allows you to target specific resources and avoid destroying all the resources in your workspace just to fix one of them."*

> In older versions of Terraform, you may have used the `terraform taint` command to achieve a similar outcome. That command has now been deprecated in favor of the `-replace` flag, which allows for a simpler, less error-prone workflow.

Introduced in **0.15.2** (the page's Tip; [[feature-history]] dates it the same way). The reason `-replace` is less error-prone is that `taint` was a *state write* — it marked the object, and the next apply acted on the mark, so the intent and the action were two separate steps with a window between them. `-replace` is a planning option: it lives in one plan, and is visible in that plan.

The closing claim is the one worth carrying:

> Using the `terraform apply` command with the `-replace` flag is the HashiCorp-recommended process for managing resources without manually editing your state file.

## `state mv` between two state files

The exercise builds a second configuration in a `new_state/` subdirectory that reads the root's security group through `data.terraform_remote_state.root` — the cross-configuration pattern [[tf-remote-state-data]] argues against on access-control grounds, used here for convenience.

After applying it, the instance is moved into the root state:

```shell
terraform state mv -state-out=../terraform.tfstate aws_instance.example_new aws_instance.example_new
```

```text
Move "aws_instance.example_new" to "aws_instance.example_new"
Successfully moved 1 object(s).
```

Simpler than the form [[tf-state-refactor]] documents, which pulls both files first and passes `-state` *and* `-state-out`. Run from the source configuration's directory, the source state is implicit; only the destination needs naming. The last two arguments are source address and destination address, identical here because nothing collides.

> Resource names must be unique to the intended state file. The `terraform state mv` command can also rename resources to make them unique.

!!! warning "`mv` moves state, and leaves the configuration behind"
    > The move command will update the resource in state, but not in your configuration file.

    The consequence is immediate and is the most instructive plan in the tutorial:

    ```text
      # aws_instance.example_new will be destroyed
      # (because aws_instance.example_new is not in configuration)
    Plan: 0 to add, 0 to change, 1 to destroy.
    ```

    A successful move leaves the destination one plan away from destroying what it just received. The fix is manual — paste the `resource` block into the destination's configuration, then `terraform apply` returns *"No changes. Your infrastructure matches the configuration."*

    That plan line is the same one [[tut-move-config]] builds its case on: **an address is an identity**, and *"not in configuration"* is indistinguishable, to Terraform, from a deletion. `moved` avoids this entire dance, but only **within one state file** — which is exactly why this cross-file move needs `state mv` and manual configuration surgery instead. [[tf-state-refactor]] calls the two-file `state mv` form legacy and prefers `removed` + `import` for new migrations.

Back in `new_state/`, `terraform destroy` reports `Resources: 0 destroyed` — the instance left, and the security group was only ever a data source there.

## `removed` — and the plan symbol nothing else documents

The procedure is [[tf-state-remove]]'s, verbatim: comment out the `resource` block, add a `removed` block with `lifecycle { destroy = false }`.

```hcl
removed {
  from = aws_instance.example_new

  lifecycle {
    destroy = false
  }
}
```

> The `removed` block was introduced in Terraform 1.7. Previous versions of Terraform used the `terraform state rm` command to remove resources from state.

What this page adds is the **transcript**, which the reference pages describe but never show:

```text
Terraform will perform the following actions:

 # aws_instance.example_new will no longer be managed by Terraform, but will not be destroyed
 # (destroy = false is set in the configuration)
 . resource "aws_instance" "example_new" {
        id   = "i-084a99085ac1aab41"
        # (32 unchanged attributes hidden)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
╷
│ Warning: Some objects will no longer be managed by Terraform
│
│ If you apply this plan, Terraform will discard its tracking information for
│ the following objects, but it will not delete them:
│  - aws_instance.example_new
│
│ After applying this plan, Terraform will no longer manage these objects. You
│ will need to import them into Terraform to manage them again.
╵
```

Three things to keep.

**The action symbol is `.`** — a lone period, not `+`, `-`, `~` or `-/+`. It is the "forget" marker and appears in no symbol legend the plan itself prints. Worth recognising, because it is easy to read as formatting noise.

**`Plan: 0 to add, 0 to change, 0 to destroy` on a plan that changes state.** Same counter behaviour as `apply -refresh-only` in [[tut-resource-drift]] — the counters count infrastructure actions, and forgetting is not one. This is also the exact contrast [[tf-block-removed]] measured from the other side: a **bare** `removed` block, without the `lifecycle`, plans `1 to destroy`.

**The warning names the exit cost.** *"You will need to import them into Terraform to manage them again."* Not an edit, not an undo — an import.

## Import it back, and the same Tip a third time

```shell
terraform import aws_instance.example_new <INSTANCE_ID>
```

> This tutorial uses `terraform import` to bring infrastructure under Terraform management. Terraform 1.5+ supports configuration-driven import…

The **third** page in this collection carrying that identical Tip, after [[tut-resource-drift]] and this one's own re-import step. The pattern is worth naming: the collection's older pages were patched with a pointer rather than rewritten around the `import` block, so the CLI command is what you will see demonstrated even though [[tut-state-import]] is what the docs recommend.

The round trip is the useful part: `removed` with `destroy = false` → the object survives, untracked → `import` (or an `import` block) → tracked again. Forgetting is reversible, but only by re-adopting.

## `terraform refresh` — used here with no warning at all

The last exercise deletes an instance out of band and reconciles:

```shell
aws ec2 terminate-instances --instance-ids $(terraform output -raw instance_id) --region $(terraform output -raw aws_region)
terraform refresh
terraform state list   # aws_instance.example is gone from state
```

!!! danger "This contradicts its own sibling tutorial, and the command reference"
    The page introduces `terraform refresh` flatly — *"The `terraform refresh` command updates the state file when physical resources change outside of the Terraform workflow"* — with **no deprecation notice, no `-refresh-only` alternative, and no mention of the risk**.

    Two pages later in the same collection, [[tut-resource-drift]] says `-refresh-only` *"is safer than the `refresh` subcommand, which automatically overwrites your state file without displaying the updates"* and that it *"is preferred over the `terraform refresh` subcommand"*. The command reference goes further ([[tf-cmd-refresh]]): **"This command is deprecated"**, it is *"effectively an alias for `terraform apply -refresh-only -auto-approve`"* with an auto-approve that cannot be switched off, and with misconfigured provider credentials *"Terraform may be misled into thinking that all of the managed objects have been deleted, causing it to remove all of the tracked objects without any confirmation prompt."*

    In this exercise the hazard is live rather than theoretical: the whole point is that `refresh` **silently drops a resource from state**, and the transcript shows it doing so with no prompt. Run `terraform plan -refresh-only` first and `terraform apply -refresh-only` to accept — same outcome, with the review step the deprecated command cannot give you.

    Six pages later, [[tut-refresh]] exists specifically to argue the opposite of this exercise — it stages a provider misconfiguration, shows the refresh-only plan reporting a live instance as `has been deleted`, and then instructs you **not** to apply. Read that one before this one.

The follow-through is sound, though, and states the boundary clearly: *"The `terraform refresh` command does not update your configuration file."* State now says the instance is gone; the configuration still declares it; so `terraform plan` proposes to **create** it. Deleting the `resource` block and its two outputs brings all three back into agreement — `Apply complete! Resources: 0 added, 0 changed, 0 destroyed`, with only the outputs changing.

> **Note:** Terraform automatically performs a refresh during the `plan`, `apply`, and `destroy` operations. All of these commands will reconcile state by default, and have the potential to modify your state file.

That last clause is the one people miss. An ordinary `plan` can write state.

## The empty state file

After `terraform destroy`, `terraform show` prints *"The state file is empty. No resources are represented."* The file itself remains:

```json
{
  "version": 4,
  "terraform_version": "1.7.0",
  "serial": 18,
  "lineage": "0c41e079-7e11-bcb9-4c2d-050228201fa6",
  "outputs": {},
  "resources": [],
  "check_results": null
}
```

`serial` **18** after roughly eight applies — consistent with [[tf-state]]'s point that `serial` counts persisted *writes*, not applies. `lineage` survives an emptied state, which is what lets a backend still refuse a stale overwrite ([[tf-state-backends]]). `check_results` is the slot for `check` block outcomes.

## Defects and ageing

!!! warning "Transcript inconsistencies"
    - **The second configuration's resource name disagrees with its own transcript.** The prose says `new_state/` *"creates a new EC2 instance named `aws_instance.example_new`"*, but its `terraform apply` output reads `# aws_instance.example will be created`. The subsequent `state mv` uses `example_new`. Go by `example_new`.
    - **Instance IDs drift across steps** — the `new_state` apply creates `i-0bf5ee79542833739`, and every later transcript refers to `i-084a99085ac1aab41`.
    - **An unexplained output disappearance.** The `removed`-block apply reports `Changes to Outputs: - security_group = "sg-0adfd0a0ade3eebdc" -> null`, and `security_group` is absent from the outputs afterwards, although nothing in that step touched the security group or its output. The page does not comment on it. Recorded as an artifact, not as behaviour to reason from.

!!! note "Version context"
    Transcripts show **Terraform 1.7.0** and **AWS provider v5.31.0** (late 2023 / early 2024) — newer than [[tut-resource-drift]]'s v3.26.0 and [[tut-troubleshooting-workflow]]'s v5.56.1, and the freshest of the three. Nothing it teaches has been superseded, with the single exception of `terraform refresh`, which was already deprecated years before these transcripts were recorded.

## Neighbours in this collection

The whole collection is now captured. **Refresh state** (9) is [[tut-refresh]] — and it does treat `-refresh-only` properly, which is what makes this page the collection's outlier rather than its norm. **Console** (10) is [[tut-console]]; *Move resources* (11) is [[tut-move-config]], which the site also files under Modules.

---
Related: [[tf-state]] — the state model, `serial`/`lineage`, and where `state rm` sits among the subcommands. · [[tf-state-purpose]] — retained dependencies, seen here as the `dependencies` array. · [[tf-state-remove]] · [[tf-block-removed]] — the `removed` block's rules and the measured `1 to destroy` when the `lifecycle` block is omitted; this page supplies the transcript for the other case. · [[tf-state-refactor]] — the legacy two-file `state mv` and why `removed` + `import` is preferred for new migrations. · [[tut-move-config]] — `moved`, which solves the same address problem within a single state file. · [[tut-state-import]] — the 1.5+ import block this page's Tip points at. · [[tut-resource-drift]] — the sibling that treats `terraform refresh` correctly. · [[tf-cmd-refresh]] — the deprecation, the alias, and the failure mode. · [[tf-cmd-show]] · [[tf-cmd-state-list]] — the two read commands used here.
