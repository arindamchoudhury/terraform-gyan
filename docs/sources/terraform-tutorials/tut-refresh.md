# Use refresh-only mode to sync Terraform state

> **Source:** [developer.hashicorp.com/terraform/tutorials/state/refresh](https://developer.hashicorp.com/terraform/tutorials/state/refresh)
> **Added:** 2026-08-20
> **Source updated:** undated tutorial (~10 min); HCP tab pins AWS provider `~> 4.4.0`; captured 2026-08-20
> **Tags:** refresh-only, terraform-refresh, drift, state, provider-misconfiguration, outputs, hcp-terraform, deprecated
> **Type:** documentation

Ninth page of the **State** collection (footer: *Previous — Version state · Next — Console*). Repo: `github.com/hashicorp-education/learn-terraform-refresh` — one EC2 instance and an AMI data source. Needs **Terraform v1.1+** and an AWS account, and carries the same *"may not qualify for the AWS free tier"* warning as [[tut-resource-targeting]].

This is the page [[tut-state-cli]] should have pointed at. Where that tutorial reconciles an out-of-band delete with a bare `terraform refresh` and no warning, this one exists specifically to argue against that command — and it does it by **staging the exact disaster the command reference describes**.

## The scenario is the misconfigured-credentials failure mode

Not a contrived drift. The setup is a provider misconfiguration, which the page names as the realistic trigger:

> A common error scenario that can prompt Terraform to refresh the contents of your state file is **mistakenly modifying your credentials or provider configuration**.

The instance is created in `us-east-2` (the `region` variable's default). Then a one-line `terraform.tfvars` moves the provider, and nothing else:

```hcl
region = "us-west-2"
```

The resources stay where they were. The provider now looks somewhere else.

```text
$ terraform plan -refresh-only

Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform since the last "terraform apply":

  # aws_instance.server has been deleted
  - resource "aws_instance" "server" {
      ## ...
    }

This is a refresh-only plan, so Terraform will not take any actions to undo these.
```

> Because you updated your provider for the `us-west-2` region, Terraform tries to locate the EC2 instance with the instance ID tracked in your state file but **fails to locate it since it's in a different region**. Terraform assumes that you destroyed the instance and wants to remove it from your state file.

`has been deleted` for a running instance. Nothing is wrong with the instance, nothing is wrong with the state file, and the provider is answering honestly about a region that genuinely has no such object. This is [[tf-cmd-refresh]]'s quoted hazard made reproducible:

> "If you have **misconfigured credentials** for one or more providers, Terraform may be misled into thinking that all of the managed objects have been **deleted**, causing it to remove all of the tracked objects without any confirmation prompt."

!!! danger "The tutorial's instruction is: do not apply"
    > If the modifications to your state file proposed by a `-refresh-only` plan were acceptable, you could run a `terraform apply -refresh-only` and approve the operation to overwrite your state file without modifying your infrastructure. However, in this tutorial, **refreshing your state file would drop your resources, so do not run the apply operation**.

    The only tutorial in the collection that sets up an operation and then tells you not to complete it. That refusal *is* the lesson: `terraform refresh` would have done it, unprompted, and the instance would have become unmanaged infrastructure nobody is tracking. The review step is the entire product.

    Cleanup is `rm terraform.tfvars` first, restoring the correct region, then a normal `terraform destroy`. Removing the misconfiguration is a step, not an afterthought.

## Why `-refresh-only` beats the subcommand — four reasons, one of them new

> In previous versions of Terraform, the only way to refresh your state file was by using the `terraform refresh` subcommand. However, this was less safe than the `-refresh-only` plan and apply mode since it would **automatically overwrite your state file without giving you the option to review the modifications first**. In this case, that would mean automatically dropping all of your resources from your state file.

1. **You get to review.** Same argument as [[tut-resource-drift]] and [[tf-cmd-refresh]], now with a scenario where reviewing is the difference between a corrected typo and an abandoned instance. *"It lets you avoid mistakenly removing an existing resource from state and gives you a chance to correct your configuration."*

2. **It updates outputs, and that is a feature here.** *"A refresh-only apply operation also updates outputs, if necessary. If you have any other workspaces that use the `terraform_remote_state` data source to access the outputs of the current workspace, the `-refresh-only` mode allows you to **anticipate the downstream effects**."*

    Worth pairing with [[tut-resource-drift]], which shows the same behaviour as a **hazard** — accepting drift rewrites outputs, so a downstream configuration consumes drift it never asked for. Both are true and they are the same mechanism: because the refresh-only *plan* shows the output changes before you accept them, the hazard is exactly what you are being given a chance to see. [[tf-remote-state-data]]'s consumers are the ones affected either way.

3. **It works on HCP Terraform; the subcommand does not.**

    > **Unlike the `refresh` subcommand, `-refresh-only` mode is supported in workspaces using HCP Terraform as a remote backend**, allowing your team to collaboratively review any modifications.

    Not in the CLI reference, not in the drift tutorial. For anyone on a `cloud` block ([[tut-cloud-migrate]]) the choice is already made — `terraform refresh` is not an option there at all.

4. **Deprecated, but not scheduled for removal.**

    > Though Terraform will continue to support the `refresh` subcommand in future versions, it is deprecated, and we encourage you to use the `-refresh-only` flag instead.

    A more precise statement than the reference page's bare "This command is deprecated". It is not going away, which is exactly why it keeps turning up in tutorials and courses written years apart — including [[tut-state-cli]] two pages earlier in this same collection.

## The implicit refresh, stated plainly

The opening paragraph is the clearest short statement of it anywhere in the tutorials:

> Terraform plan and apply operations run an **implicit in-memory refresh** as part of their operations, reconciling any drift from your workspace's state before creating a plan for your infrastructure changes.

And again at the end:

> In order to propose accurate changes to your infrastructure, Terraform first attempts to reconcile the resources tracked in your state file with your actual infrastructure. Terraform plan and apply operations first run an in-memory refresh to determine which changes to propose. **Once you confirm a `terraform apply`, Terraform will update your infrastructure and state file.**

Two consequences, neither spelled out here but both worth holding. A plain `terraform plan` already sees the drift — which is why [[tf-cmd-refresh]]'s closing advice is to *"avoid using `terraform refresh` explicitly and instead rely on Terraform's behavior of automatically refreshing existing objects as part of creating a normal plan."* And in-memory means the plan does not persist what it learned; [[tut-state-cli]] adds the other half, that `plan`, `apply` and `destroy` all *"have the potential to modify your state file."*

## Small things

- The provider uses **`default_tags`** to stamp `hashicorp-learn = "refresh"` on everything — the tidiest example of that argument in the collection, and unremarked by the page.
- **Version floor is `v1.1+`**, though `-refresh-only` shipped in **0.15.4** ([[tf-cmd-refresh]], [[feature-history]]). The tutorial just sets a higher bar than the feature needs.

!!! warning "One copy-paste defect"
    The HCP Terraform tab says *"Terraform will automatically create the **`learn-terraform-locals`** workspace"* — the `cloud` block directly above it names `learn-terraform-refresh`. Text lifted from the locals tutorial.

## Where this leaves the collection

Three pages of this collection touch `refresh`, and they do not agree:

| Page | Treatment |
|---|---|
| **This one** (9) | Argues against `terraform refresh` at length; stages its failure mode; tells you not to apply |
| [[tut-resource-drift]] (6) | Calls `-refresh-only` *"safer than the `refresh` subcommand"* and *"preferred"* |
| [[tut-state-cli]] (3) | Uses bare `terraform refresh`, no deprecation notice, no alternative mentioned |

So the collection is not silent on the question — one page is simply out of step with the other two. Read this one before that one.

---
Related: [[tf-cmd-refresh]] — the command reference; this tutorial is the hands-on demonstration of the failure mode it quotes. · [[tut-resource-drift]] — the other `-refresh-only` exercise, drift manufactured by hand rather than by misconfiguration, and outputs framed as a hazard rather than a preview. · [[tut-state-cli]] — the outlier that still teaches the deprecated subcommand straight. · [[tf-state-purpose]] — the attribute cache the refresh reconciles, and `-refresh=false` as the opposite knob. · [[tf-remote-state-data]] — the downstream consumers whose view of the outputs this operation can change. · [[tut-cloud-migrate]] — the `cloud` block, where `terraform refresh` is not available at all.
