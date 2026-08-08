# Create and use no-code modules

> **Source:** [developer.hashicorp.com/terraform/tutorials/modules/no-code-provisioning](https://developer.hashicorp.com/terraform/tutorials/modules/no-code-provisioning)
> **Added:** 2026-08-08
> **Source updated:** undated tutorial (~14 min); captured 2026-08-08
> **Tags:** no-code-modules, hcp-terraform, self-service, platform-engineering, ephemeral-resources, write-only-arguments, variable-sets, module-versioning
> **Type:** documentation

Tenth and final entry in the **Modules** sidebar — the tutorial every earlier page kept pointing at. Requires **HCP Terraform Standard edition** and an AWS account. You fork `terraform-aws-rds`, review it as the module *author*, publish it no-code-ready, then switch personas and consume it as a *user* who never writes a line of HCL.

> No-code provisioning in HCP Terraform lets users deploy infrastructure resources without writing Terraform configuration. … removes the dependency on infrastructure teams or ticketing systems to give developers their required resources.

!!! tip "This is the only maintained page in the collection"
    Eight of the other nine pages carry pins from 2022 (AWS provider 4.x, vpc module 3.x). This one uses **ephemeral resources** (Terraform 1.10), **write-only arguments** (Terraform 1.11), and `postgres16`. It has been kept current, and it is the only page here whose configuration would be worth copying as-is.

## No-code modules invert two module rules

**Rule one: declare providers *inside* the module.** [[tut-module-create]] says "we recommend that you do not include provider blocks in modules"; [[tut-for-each]] found that it is a hard constraint once `count`/`for_each` is on the module block. This page reverses it, and explains exactly why the reversal is safe:

```hcl
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      HashiCorpLearnTutorial = "no-code-provisioning"
    }
  }
}

provider "random" {}
```

> The main difference between no-code modules and ordinary modules is that the no-code workflow requires declaring provider configuration within the module itself. Authors of standard modules usually avoid including the provider configuration within the module because it makes the module incompatible with the `for_each`, `count`, and `depends_on` meta-arguments. **Since users will not reference no-code modules in written configuration, there is no risk of this conflict.**

That is the cleanest statement of the rule *and* its exception anywhere in the collection: the provider-block prohibition was never about providers, it was about meta-arguments. Remove the possibility of a `module` block and the prohibition evaporates. The consequence lands immediately: HCP launches a fresh workspace per provision, so **the organization must arrange automatic provider credentials** for those workspaces.

**Rule two: all resources live in the repository root.**

> No-code modules must follow standard module structure and define all resources in the root repository of the directory. This lets HCP Terraform inspect the module, generate documentation, track resource usage, and parse submodules and examples.

## Design: fewer decisions, not more flexibility

> Because no-code ready modules target users who are unfamiliar with Terraform and infrastructure management, **reduce the number of decisions the user needs to make.** A well-designed no-code module is scoped to a specific use case and limits the number of variables a user needs to configure.

The RDS module exposes **three** variables, only two of them required:

```hcl
variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-2"
}

variable "db_name" {
  description = "Unique name to assign to RDS instance."
  type        = string
}

variable "db_username" {
  description = "RDS root username."
  type        = string
}
```

Everything else is fixed in the module: `engine`, `engine_version`, `instance_class`, `allocated_storage` are hardcoded "to satisfy organizational requirements", the security group opens exactly one ingress rule, and a parameter group forces `log_connections = 1`.

This is [[tut-pattern-module-creation]]'s "minimize inputs" and [[tut-module-create]]'s "a value your module's purpose fixes is not a variable" pushed to their limit — here the *user* cannot override anything you did not expose, because there is no configuration file for them to edit.

!!! note "Two things in this module I would not copy"
    **`publicly_accessible = true`** on the RDS instance, in a module whose stated job is to "codify your infrastructure standards". The security group narrows ingress, but the instance still gets a public endpoint.

    **`cidr_blocks = ["192.80.0.0/16"]`**, described in the prose as "a hypothetical internal VPN". `192.80.0.0/16` is **public** address space — the RFC 1918 private ranges are `10.0.0.0/8`, `172.16.0.0/12`, and `192.168.0.0/16`. Almost certainly `192.168.0.0/16` was meant.

## The secrets pattern is the good part

```hcl
ephemeral "random_password" "db_password" {
  length = 16
}

locals {
  # Increment db_password_version to update the DB password and store the new
  # password in SSM.
  db_password_version = 1
}

resource "aws_db_instance" "education" {
  identifier             = "${var.db_name}-${random_pet.random.id}"
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  engine                 = "postgres"
  engine_version         = "16"
  username               = var.db_username
  password_wo            = ephemeral.random_password.db_password.result
  password_wo_version    = local.db_password_version
  db_subnet_group_name   = aws_db_subnet_group.education.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.education.name
  publicly_accessible    = true
  skip_final_snapshot    = true
}

resource "aws_ssm_parameter" "secret" {
  name             = "/education/database/${var.db_name}/password/master"
  description      = "Password for RDS database."
  type             = "SecureString"
  value_wo         = ephemeral.random_password.db_password.result
  value_wo_version = local.db_password_version
}
```

Three mechanisms working together, each already covered in **A6** ([[tf-manage-sensitive-data]], [[infisical-terraform-secrets]]) — this is the worked example those notes describe in the abstract.

- **Ephemeral resource** (Terraform **1.10**+) — "Terraform does not store ephemeral resources in its state or plan files." So the generated password never becomes a state artifact, unlike `random_password`, which [[infisical-terraform-secrets]] showed appearing in state *three times*.
- **Write-only arguments** (Terraform **1.11**+) — "only available during the current operation, and Terraform does not store write-only argument values in state or plan files."
- **`_version` companions** — because the value isn't stored, Terraform cannot diff it. Incrementing `password_wo_version` is how you tell it the value changed. The tutorial threads **one local** (`local.db_password_version`) into both `password_wo_version` and `value_wo_version` so the database and the SSM copy rotate in the same apply. That shared-local trick is the detail worth stealing.

> By setting the password with an ephemeral resource and write-only arguments, Terraform does not store your database password, and **the only way to retrieve that password is by querying the AWS SSM parameter.**

## Publishing it no-code-ready

Repository must be named `terraform-<provider>-<name>` — hence renaming the fork to `terraform-aws-rds` — with releases from tags or branches. Tag-based here:

```shell
$ git tag 1.0.0
$ git push --tags
```

Registry → **Publish → Module** → VCS provider → repo → **check "Add Module to no-code provision allowlist"** → **Publish module**. The module gains a **No-Code Ready** badge and a **Provision Workspace** button.

Then **Configure Settings → Edit versions and variable options**, which is where the governance actually lives:

- **Pin the module version** no-code provisioning will deploy (`1.0.0 (latest)`). This is not automatic — see the update flow below.
- **Add dropdown options for a variable.** The tutorial constrains `db_username` to `education`. A no-code variable can be turned from a free-text field into a closed set, which is real input validation at the UI layer rather than in HCL.

## Credentials: a project plus a scoped variable set

Create a **project** named `No-Code`, then a variable set `No Code Credentials` scoped to *"Apply to specific projects and workspaces"* → that project, holding:

| Type | Variable name | Sensitive |
|---|---|---|
| Environment variable | `AWS_ACCESS_KEY_ID` | No |
| Environment variable | `AWS_SECRET_ACCESS_KEY` | Yes |

Plus `AWS_SESSION_TOKEN` for temporary credentials. The project is the unit that makes this work — every workspace no-code provisioning creates lands in it and inherits the set.

!!! note "Static keys here; the page's own next-steps point past them"
    Long-lived `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` in a variable set is the simplest thing that works, and the page closes by pointing at **dynamic credentials** for no-code modules instead. That is the A6 position too — OIDC over static keys — so treat the variable set as the tutorial's shortcut, not the recommendation.

## Consuming it

**Provision workspace** → fill the variables (`db_name = nocode`, `db_username = education` from the dropdown) → workspace settings: name, **project**, and **apply method**. Auto-apply applies successful runs automatically including the first; manual apply plans and waits for approval.

The constraint that defines the whole model:

> Because you cannot interact with the Terraform configuration for the workspace, **you can only change the infrastructure by editing the variable values or by updating to a different version of the module. You cannot directly apply configuration changes to existing no-code workspaces.**

So a no-code workspace's entire change surface is *(variables) × (module version)*. Everything else requires the module author to ship a release.

## Updating: version selection is a deliberate act

Add a variable and use it:

```hcl
variable "db_encrypted" {
  description = "Encrypt the database storage"
  type = bool
}
```

```hcl
  storage_encrypted = var.db_encrypted
```

Commit, `git tag 1.0.1`, `git push origin main --tags`. Then the part worth noting:

> **HCP Terraform will continue to use version 1.0.0 of the module until you configure it to use the new version.**

Pushing a tag publishes the version; it does not roll it out. You select `1.0.1 (latest)` in **Configure Settings → Edit version and variable options**, and only then does each consuming workspace show *"a no-code module version update is available"* with a **View update** button. The user supplies the new variable and clicks **Save configuration & start plan**, then **Confirm & apply**.

!!! warning "The tutorial's own upgrade is a breaking one, and it doesn't say so"
    `variable "db_encrypted"` is declared with **no default**, so every existing workspace must answer a prompt before it can run again. [[tut-module-object-attributes]] exists to make exactly this unnecessary — its argument for `optional()` was that optional attributes *"make it easier for you to ship new module versions without changing the variables that module users need to define"*.

    `default = false` would have made 1.0.1 a silent, safe upgrade; `default = true` would have made it a safe upgrade that also improves the security posture. Reading the two pages together, this one demonstrates the additive change done the breaking way — useful as a contrast, not as a template. The blast radius is larger in the no-code model than in HCL, because the people who must answer the prompt are by definition the ones who don't write Terraform.

## Cleanup

**Workspace Settings → Destruction and Deletion → Queue destroy plan**; HCP auto-applies it. Then optionally delete the workspace, the `No-Code` project, the variable set, and the module.

## Smaller defects

!!! note "Two text errors"
    - A sentence in the write-only section runs off the rails: *"Terraform can then make a plan diff and notify the provider that a write-only argument has a new value. update the write-only argument as well."* — a dangling fragment left from an edit.
    - *"any variable sets sets in your organization"* — doubled word.

    Seven HCP UI screenshots not captured, on the same reasoning as [[tut-module-private-registry-share]] and [[tut-private-registry-add]]: dated shots of a UI that has moved on.

## Next steps

Stated takeaway: published and used a no-code module, and reviewed the design recommendations and requirements for one. Onward pointers are the no-code provisioning docs, optional object attributes for modules, OPA policy enforcement plus drift detection, and **dynamic credentials for no-code modules**. This closes the Modules collection; the sidebar's next entry is the *Provision* collection.

---
Related: last entry in the Modules sidebar, and the destination the collection kept pointing at from [[tut-module]] onward. It **inverts** [[tut-module-create]]'s no-provider-blocks rule and explains why the rule existed — the meta-argument conflict [[tut-for-each]] measured. Its variable minimalism is [[tut-pattern-module-creation]]'s scoping advice at its strictest, and its no-default upgrade is the counterexample to [[tut-module-object-attributes]]'s `optional()` argument. Publishing mechanics: [[tut-module-private-registry-share]]; enabling no-code on a *curated public* module instead: [[tut-private-registry-add]]. The ephemeral/write-only secrets pattern is the worked version of [[tf-manage-sensitive-data]] and [[infisical-terraform-secrets]]. Feeds learning-path **E6** (platform engineering — its named hands-on), **A6** (a real ephemeral + write-only + `_version` example), and **A4** (registry settings, projects, variable sets).
