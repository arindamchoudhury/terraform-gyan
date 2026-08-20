# Target resources

> **Source:** [developer.hashicorp.com/terraform/tutorials/state/resource-targeting](https://developer.hashicorp.com/terraform/tutorials/state/resource-targeting)
> **Added:** 2026-08-20
> **Source updated:** undated tutorial (~20 min); HCP tab pins AWS provider `~> 4.4.0`; captured 2026-08-20
> **Tags:** target-flag, partial-apply, dependency-graph, count, modules, outputs, drift, exceptional-recovery
> **Type:** documentation

Fourth page of the **State** collection (footer: *Previous — Manage resource state · Next — Troubleshooting*). Repo: `github.com/hashicorp-education/learn-terraform-resource-targeting` — an S3 bucket with a `random_pet` name and four bucket objects. Needs **Terraform v1.2+** and an AWS account; both Community Edition and HCP Terraform variants captured, differing only by a `cloud` block.

!!! warning "Not free tier"
    > Some of the infrastructure in this tutorial may not qualify for the AWS free tier.

    The one page in this collection that says so. Destroy at the end.

The page's own framing of when `-target` is legitimate:

> Occasionally you may want to apply only part of a plan, such as when Terraform's state has become out of sync with your resources due to a **network failure, a problem with the upstream cloud platform, or a bug in Terraform or its providers**. […] Targeting individual resources can be useful for troubleshooting errors, but **should not be part of your normal workflow**.

Three named causes, all of them failures rather than preferences. This is the mechanics behind the one-line verdict [[core-workflow]] already carries.

## The direction rule

The single most important mechanical fact on the page, and it is stated in one sentence:

> **Resource targeting updates resources that the target depends on, but not resources that depend on it.**

Targeting walks **upstream**, never downstream. The tutorial demonstrates it by changing `random_pet.bucket_name`'s `length` from 3 to 5 and planning three ways:

| Plan | Result |
|---|---|
| `terraform plan` | `8 to add, 0 to change, 8 to destroy` — the pet, the bucket, the public-access block, all four objects |
| `terraform plan -target="random_pet.bucket_name"` | `1 to add, 0 to change, 1 to destroy` — the pet alone |
| `terraform plan -target="module.s3_bucket"` | `4 to add, 0 to change, 4 to destroy` — the module's resources **plus the pet** |

The third row is the rule in action. The page explains it directly:

> Terraform determines that `module.s3_bucket` depends on `random_pet.bucket_name`, and that the bucket name configuration has changed. Because of this dependency, Terraform will update both the upstream bucket name and the module you targeted.

So a target is not a filter over the plan — it is a **subgraph selection**, closed under the "depends on" edge in one direction only. Everything the target needs comes along; everything that needs the target is left stale. That asymmetry is exactly why the operation leaves the configuration inconsistent, and why it is a recovery tool rather than a scoping tool.

!!! note "Targeting a module targets everything in it"
    `-target="module.s3_bucket"` is a valid address and covers every resource inside. So is an indexed instance (`aws_s3_object.objects[2]`), and so is the whole collection (`aws_s3_object.objects`, which reached all four instances in the destroy step). Multiple `-target` flags in one command are allowed and additive.

## The two warnings say different things

Terraform prints one warning at plan time and a different one at apply time. Worth telling apart, because only the second one tells you what to do next.

**Plan time:**

```text
│ Warning: Resource targeting is in effect
│
│ You are creating a plan with the -target option, which means that the
│ result of this plan may not represent all of the changes requested by the
│ current configuration.
```

**Apply time:**

```text
│ Warning: Applied changes may be incomplete
│
│ The plan was created with the -target option in effect, so some changes
│ requested in the configuration may have been ignored and the output values
│ may not be fully updated. Run the following command to verify that no other
│ changes are pending:
│     terraform plan
```

Both close with the same sentence, and its final clause is the part people miss:

> Note that the `-target` option is **not suitable for routine use**, and is provided only for exceptional situations such as recovering from errors or mistakes, **or when Terraform specifically suggests to use it as part of an error message**.

Terraform sometimes prints a `-target` command in an error and means it. That is the one context where reaching for the flag is following instructions rather than improvising.

## Targeting desynchronises outputs from reality

After `terraform apply -target="random_pet.bucket_name"`:

```text
Apply complete! Resources: 1 added, 0 changed, 1 destroyed.

Outputs:

bucket_arn  = "arn:aws:s3:::learning-specially-tender-fawn"
bucket_name = "learning-optionally-violently-apparently-equal-skylark"
```

The two outputs now disagree about the same bucket. The cause is in `outputs.tf`:

```hcl
output "bucket_name" {
  description = "Randomly generated bucket name."
  value       = random_pet.bucket_name.id
}
```

`bucket_name` reads the *pet*, which was targeted and did change. `bucket_arn` reads the *bucket*, which was not targeted and did not. State is now internally inconsistent, and nothing about it is corrupt — every value is correctly recorded, they simply describe different moments.

> Because you targeted the random pet resource, Terraform updated the output value for the bucket name but not the bucket itself. Targeting resources can introduce inconsistencies, so you should only use it in troubleshooting scenarios.

The tutorial's incidental fix is worth its own line: point the output at `module.s3_bucket.s3_bucket_id` rather than at the name generator. **Output what the object reports, not what you asked for** — the same instinct that makes `aws_instance.example.id` a better output than the variable that named it.

The recovery instruction is explicit, and is the standing rule after any targeted run:

> After using resource targeting to fix problems with a Terraform project, **be sure to apply changes to the entire configuration** to ensure consistency across all resources.

The full apply that follows costs `7 to add, 0 to change, 7 to destroy` — the partial apply did not reduce the work, only deferred and fragmented it.

## Dependencies are computed per **resource**, not per **instance**

The sharpest finding, and the page flags it as surprising:

> As shown above, you can target individual instances of a collection created using the `count` or `for_each` meta-arguments. **However, Terraform calculates resource dependencies for the entire resource.** In some cases, this can lead to surprising results.

Removing `prefix` from `random_pet.object_names` (which has `count = 4`) and then targeting **one** object:

```shell
terraform apply -target="aws_s3_object.objects[2]"
```

```text
  # aws_s3_object.objects[2] must be replaced
  # random_pet.object_names[0] must be replaced
  # random_pet.object_names[1] must be replaced
  # random_pet.object_names[2] must be replaced
  # random_pet.object_names[3] must be replaced

Plan: 5 to add, 0 to change, 5 to destroy.
```

One targeted object instance dragged in **all four** name generators.

> Both `random_pet.object_name` and `aws_s3_object.object` use `count` to provision multiple resources, and each bucket object refers to the name of the same index. However, because the entire `aws_s3_bucket_objects.objects` resource depends on the entire `random_pet.object_names` resource, Terraform updated all the names.

The graph explains it. Edges are built between **resource** nodes, not between instance nodes — [[dependency-graph]] records this from the source side, where `nodeExpandPlannableResource` exists per managed resource and decides the expansion before instances get their own nodes. `objects[2] → object_names[2]` is not an edge Terraform has; `objects → object_names` is. So the upstream closure of one instance is the *whole* upstream resource.

Practical consequence: **an instance-level `-target` gives you instance-level precision downstream of the target and no precision at all upstream of it.** If the intent was to touch one object, this achieved the opposite of intended blast-radius reduction.

## `destroy -target`

Targeting works on destroy too, and the collection form takes out every instance:

```shell
terraform destroy -target="aws_s3_object.objects"   # Plan: 0 to add, 0 to change, 4 to destroy
```

Same two warnings apply. `terraform destroy` afterwards clears the remaining 8.

## Comparison worth carrying

!!! info "OpenTofu — `-exclude` is the inverse, and the two never mix"
    Terraform has only the allow-list form. **OpenTofu 1.9** added `-exclude`, the deny-list, and **1.10** added file-driven `-target-file` / `-exclude-file`. Any target-side option combined with any exclude-side option is an **error at argument parsing**, before planning begins: *"The target and exclude planning options are mutually-exclusive. Each plan must use either only the target options or only the exclude options."*

    The consequence for recovery work is that you cannot say "everything except X, but only within module Y" in one run. See [[ot-exclude-flag]].

## Defects and ageing

!!! warning "Three transcript problems"
    - **"all five of the `random_pet.object_name` resources"** — there are **four** (`count = 4`). The `5` in that sentence is the plan's total (four pets plus one object), not a count of pets.
    - **The destroy transcripts use the old resource name.** The configuration and every plan use `aws_s3_object`; the destroy output lines read `aws_s3_bucket_object.objects[N]`. `aws_s3_bucket_object` is the deprecated predecessor, so those lines are from an older recording.
    - **Bucket names drift between steps** — `learning-specially-tender-fawn`, `learning-newly-still-gibbon`, `learning-seriously-lately-hugely-pleasing-newt`, and `learning-optionally-violently-apparently-equal-skylark` all appear as "the" bucket at different points, and not in a consistent order. Randomised names make this harder to follow than the other tutorials' fixed identifiers.

    The HCP tab pins `aws ~> 4.4.0` (2022). Nothing taught here depends on the provider version — `-target` is core, not provider, behaviour.

## What it does not cover

- **`-target` on `import` or `refresh`** — only `plan`, `apply`, `destroy` are exercised.
- **Why the flag exists rather than a supported partial-apply workflow.** The page repeats "not for routine use" four times without ever naming the alternative, which is smaller state files — [[tut-organize-configuration]] and TUR Ch3's isolation argument.
- **`-target` in automation.** Nothing about CI, where the "apply the whole configuration afterwards" instruction is the part most likely to be skipped.

---
Related: [[core-workflow]] — where `-target` sits among the plan/apply flags, and the one-line verdict this page supplies the mechanics for. · [[dependency-graph]] — edges are resource-level, which is why an instance-level target pulls in a whole upstream resource. · [[ot-exclude-flag]] — OpenTofu's inverse flag and the mutual-exclusion rule. · [[tut-state-cli]] — the neighbouring page, and `-replace` as the *supported* way to act on one resource. · [[tut-troubleshooting-workflow]] — the collection's other "something went wrong" page. · [[tut-organize-configuration]] — the structural answer to wanting a smaller blast radius.
