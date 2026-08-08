# Refactor monolithic Terraform configuration

> **Source:** [developer.hashicorp.com/terraform/tutorials/modules/organize-configuration](https://developer.hashicorp.com/terraform/tutorials/modules/organize-configuration)
> **Added:** 2026-08-08
> **Source updated:** undated tutorial (~18 min); captured 2026-08-08
> **Tags:** code-organization, monolith, state-separation, workspaces, directories, hidden-dependency, blast-radius, multi-environment
> **Type:** documentation

Seventh page of the **Modules** collection, and the odd one out — it contains no modules at all. It walks a single-directory, single-state configuration managing dev and prod through three stages: **monolith → separate files → separate state**, with the last stage offered as two tabs (directories or workspaces). Both tabs captured. `git clone https://github.com/hashicorp-education/learn-terraform-code-organization`, and each stage has a branch to jump to (`file-separation`, `directories`, `workspaces`).

The framing is honest about when a monolith is fine:

> Small projects may be convenient to maintain this way. However, as your infrastructure grows, restructuring your monolith into logical units will make your Terraform configurations less confusing and safer to manage.

## Stage 1 — the monolith, and its hidden dependency

The starting `main.tf` builds two S3-hosted websites, dev and prod, with a shared `random_pet` supplying a suffix for both bucket names:

```hcl
resource "random_pet" "petname" {
  length    = 3
  separator = "-"
}

resource "aws_s3_bucket" "dev" {
  bucket = "${var.dev_prefix}-${random_pet.petname.id}"

  force_destroy = true
}

resource "aws_s3_bucket" "prod" {
  bucket = "${var.prod_prefix}-${random_pet.petname.id}"

  force_destroy = true
}
```

That shared resource is the whole point of the page. **This is the best exercise in the collection**, because it demonstrates a failure rather than describing one.

!!! danger "The hidden dependency, demonstrated"
    Change `length` from 3 to 4 in `dev.tf` — a file that by then contains only development resources — and apply:

    > Note that the operation updated all five of your resources by destroying and recreating them. In this scenario, you encountered a hidden resource dependency because both bucket names rely on the same resource.

    Editing the file named `dev` destroyed production. Nothing in `dev.tf` mentions prod; the coupling lives in the *reference graph*, which does not care which file a block sits in.

    The page draws the right conclusion and names the automation case explicitly:

    > Carefully review Terraform execution plans before applying them. If an operator does not carefully review the plan output or if CI/CD pipelines automatically apply changes, you may accidentally apply breaking changes to your resources.

    This is the concrete version of the "read the plan, not just the exit code" argument, and it is why [[tut-dependencies]] treats the apply log as a free dependency check.

## Stage 2 — separate files, which is not separation

`cp main.tf dev.tf`, `mv main.tf prod.tf`, then delete the other environment's resource blocks from each. The mechanical rule that makes this work:

> Terraform loads all configuration files within a directory and appends them together, so any resources or providers with the same name in the same directory will cause a validation error.

So the shared `terraform` block, `provider` block, and `random_pet` have to be commented out of one of the two files with `/* … */`. Which leaves the arrangement the page then attacks:

> With your `prod.tf` shared resources commented out, your production environment will still inherit the value of the `random_pet` resource in your `dev.tf` file.

Two files, one directory, **one state**, and one dependency graph. File separation buys readability and nothing else. That is the honest lesson here, and it is worth holding against the instinct that splitting a big `main.tf` has made anything safer.

## Stage 3 — separate state

`-target` gets named and dismissed in a sentence:

> you can use the `terraform apply` command with the `-target` flag to scope the resources to operate on, but that approach can be risky and is not a sustainable way to manage distinct environments

Then the decision rule, which is the most quotable line on the page:

> To separate environments with potential configuration differences, use a **directory structure**. Use **workspaces** for environments that do not greatly deviate from one another, to avoid duplicating your configurations.

### Directories

Blast radius is the stated benefit: "Terraform operates only on the state and configuration in the working directory by default." Each environment directory holds its own `main.tf`, `variables.tf`, `terraform.tfvars`, and `terraform.tfstate`.

The costs are stated plainly, and they are the real ones:

> Directory-separated environments rely on duplicate Terraform code. … the directory structure runs the risk of creating drift between the environments over time. If you want to reconfigure a project with a single state file into directory-separated states, you must perform advanced state operations to move the resources.

That last clause is the migration tax: going from one state to many is `terraform state mv` work ([[tf-state-refactor]], [[tf-state-remove]]), not a file move. The exercise sidesteps it by destroying everything first — real projects cannot.

Moving into a subdirectory also breaks relative paths, which the tutorial handles with a `..`:

```hcl
- content = file("${path.module}/assets/index.html")
+ content = file("${path.module}/../assets/index.html")
```

Worth noticing that a shared `assets/` directory reached by `../` is itself a coupling between the two environments, of exactly the kind the exercise is trying to remove. It is just a benign one.

### Workspaces

Same configuration, different state. Resource names get de-environmented (`aws_s3_bucket.dev` → `aws_s3_bucket.bucket`), the two prefix variables collapse into one `prefix`, and `terraform.tfvars` splits into `dev.tfvars` and `prod.tfvars` selected with `-var-file`:

```shell
$ terraform workspace new dev
Created and switched to workspace "dev"!

$ terraform apply -var-file=dev.tfvars
```

```shell
$ terraform workspace new prod
$ terraform apply -var-file=prod.tfvars
```

The mechanics worth keeping:

- **`terraform workspace list`** marks the current one with `*`; **`new`** creates and switches; **`select`** switches.
- The apply and destroy prompts name the workspace — *"Do you want to perform these actions in workspace `dev`?"* — which is the only guard you get.
- **Local-backend state layout changes once you leave `default`.** The `default` workspace keeps `terraform.tfstate` in the root; other workspaces go to `terraform.tfstate.d/<name>/terraform.tfstate`.
- Destroying requires selecting the workspace *and* passing the matching `-var-file`, or you destroy the wrong environment with the wrong inputs.

And the cost, in the page's own words:

> you must manage your workspaces in the CLI and be aware of the workspace you are working in to avoid accidentally performing operations on the wrong environment.

!!! danger "This contradicts HashiCorp's own reference documentation"
    The tutorial presents CLI workspaces as one of "two primary methods to separate state between environments" and walks you through using them for dev and prod. The Workspaces language reference marks the opposite as **Important**, quoted in [[tf-state-workspaces]]:

    > "Workspaces are not appropriate for system decomposition or deployments requiring separate credentials and access controls."

    Dev and prod are the canonical case of *deployments requiring separate credentials and access controls*. A CLI workspace switch changes which state file you write; it does not change which AWS account you authenticate to, who is allowed to run the apply, or what a mistake costs. The tutorial's own mitigation — "be aware of the workspace you are working in" — is human vigilance standing in for an access boundary.

    The tutorial's decision rule is still useful if you read it as being about **configuration duplication**, not about isolation: workspaces avoid duplicating code across near-identical deployments. Just don't read "environments" as "prod and dev under different credentials". [[workspaces]] argues the isolation limits at length, and [[tf-style-guide]]'s multi-environment guidance lands on directory-per-environment or a workspace *per environment in HCP*, which is a different mechanism with real access controls behind it.

## Problems with the page

!!! warning "Resource counts are wrong twice over"
    The page says the first apply creates **"the 5 resources"** and that the hidden-dependency apply "updated all five of your resources". Its own prose one screen earlier describes **nine** resources (a `random_pet`, plus a bucket, ACL, website configuration, policy, and object for each of dev and prod). And the current example repo's `main.tf` defines **fifteen** — the same nine plus `aws_s3_bucket_ownership_controls` and `aws_s3_bucket_public_access_block` per environment. Verified against the repo 2026-08-08.

    The number does not change the lesson. It does mean the transcripts predate the repo, the same pattern found in [[tut-module-object-attributes]].

!!! warning "It tells you to comment out a `terraform` block the repo does not have"
    The `prod.tf` diff shows a `terraform { required_providers { aws … random … } }` block being wrapped in `/* … */`. The current repo's `main.tf` has **no `terraform` block at all**, and the repository contains only `main.tf`, `outputs.tf`, `variables.tf`, `terraform.tfvars.example`, `README.md`, and `assets/` — no `versions.tf` or `terraform.tf` either. So both providers resolve implicitly and **nothing is version-pinned**, which is its own problem in a tutorial about growing a project safely ([[provider-requirements]]).

!!! note "Three smaller inconsistencies"
    - **The `random_pet` is named two different things.** `resource "random_pet" "petname"` in the comment-out diff and in the workspaces `main.tf` references (`random_pet.petname.id`), but `resource "random_pet" "random"` in the hidden-dependency step. The repo uses `petname`.
    - **The region changes between snippets** — `us-east-1` in `terraform.tfvars.example`, `us-east-2` in `dev/terraform.tfvars` and `dev.tfvars`.
    - **The final workspaces directory listing still shows `terraform.tfvars`**, two steps after instructing `mv terraform.tfvars prod.tfvars`.

!!! note "The repo is patched for current S3 defaults; the page's snippets aren't consistent with it"
    Third repo in this collection carrying the ownership-controls plus public-access-block fix with `depends_on` chains — see [[tut-module-create]] and `cache/search/s3-acl-bpa-defaults.md` for why it is needed. The page's `aws_s3_object` snippet also carries `acl = "public-read"`, which the repo's version drops.

## Next steps

Stated takeaway: restructured a monolith managing multiple environments into directories or workspaces with their own state. Onward pointers are modules "to combat configuration drift", HCP Terraform for team state management, and remote backends with migration. Next in the collection is the module-creation recommended pattern — captured as [[tut-pattern-module-creation]].

---
Related: seventh in the Modules collection, though it teaches no modules — it makes the case *for* them by showing what a flat configuration costs. The hidden-dependency demo is the practical companion to [[tut-dependencies]] and [[dependency-graph]]. Workspace mechanics and their documented limits: [[tf-state-workspaces]] and the topic page [[workspaces]]; the migration tax of splitting one state is [[tf-state-refactor]]. Directory-per-environment versus HCP-workspace-per-environment is [[tf-style-guide]]'s recommendation. S3 background: [[tut-module-create]]. Feeds learning-path **A7** (multi-environment patterns) primarily, **I6**/**I7** (state separation and the state operations it needs), and **E4** (repo architecture at scale).
