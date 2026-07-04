# Create infrastructure (AWS Get Started)

> **Source:** [developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create)
> **Added:** 2026-07-04
> **Source updated:** undated tutorial (~14 min); captured 2026-07-04
> **Tags:** first-project, provider, resource, data-source, init, plan, apply, state, fmt, validate
> **Type:** documentation

Second lesson of the AWS Get Started track. The complete first project: write config, set credentials, `init`, `validate`, `apply` an EC2 instance, then inspect state. This is the hands-on version of the Write→Plan→Apply loop from [[terraform-intro]] and [[01-brief-overview]].

> 📌 **Version note (updated 2026-07-04):** The live tutorial still shows `terraform v1.12.0` and pins the AWS provider `~> 5.92`. Both are behind current. As of 2026-07-04: Terraform CLI is **1.15.7** (see [[version-facts]]) and the **AWS provider is on major 6** — 6.0 went GA in 2026, latest is **6.53.0** (2026-07-01). The config blocks below are bumped to `~> 6.0` accordingly. The workflow (write → fmt → init → validate → apply → inspect state) is unchanged; only the pins move. If you copy the tutorial verbatim you'll get provider 5.x, which still works — but a fresh project should pin `~> 6.0`.

## Prerequisites

- Terraform CLI **1.2.0+** and the **AWS CLI** installed.
- An AWS account with credentials that can create an EC2 instance, VPC, and security groups in **us-west-2**.
- Resources qualify for the AWS free tier. Run the **Destroy** lesson afterward to avoid charges.

## Write configuration

`.tf` files are plain-text HCL. Terraform loads *all* `.tf` files in the working directory and resolves dependencies automatically, so file organization and order are your choice. Config is organized into blocks: `terraform` (configure Terraform itself), `provider`, and the `resource`/`data` blocks that make up infrastructure.

### The `terraform` block

Convention: put it in a dedicated `terraform.tf`.

```hcl
# terraform.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0" # tutorial pins ~> 5.92; 6.0 is GA, bump for new projects
    }
  }

  required_version = ">= 1.2"
}
```

- Providers are binary plugins, versioned/distributed separately from Terraform (see [[providers]]). `required_providers` sets version constraints.
- `source = "hashicorp/aws"` is shorthand for `registry.terraform.io/hashicorp/aws` — hostname (optional) / namespace / name.
- `version = "~> 6.0"` means major 6, any minor ≥ 0 (i.e. `>= 6.0, < 7.0`). Without a constraint, Terraform grabs the newest provider — pin it so an untested version doesn't slip in. (The tutorial's `~> 5.92` = major 5, minor ≥ 92; use `~> 6.0` now that provider 6 is GA.)
- `required_version = ">= 1.2"` constrains the Terraform CLI version — a floor, not a pin. Check yours with `terraform -version` (current stable 1.15.7).

!!! note "Why `>= 1.2` and not `>= 1.15`?"
    `required_version` is a **floor** — the *minimum* CLI version your config needs — not "whatever's newest." This config uses only basic blocks (`terraform`, `provider`, `data`, `resource`), all present since Terraform 1.0, so `>= 1.2` is honest and maximally compatible. Writing `>= 1.15` would be wrong here: it locks out everyone on 1.2–1.14 for no reason, since nothing in the config needs a 1.15 feature. Only raise the floor when you actually use something newer (dynamic module sources, output `type`, `convert()`, …).

    This is the opposite discipline from the **provider** pin:

    | Constraint | Style | Why |
    |---|---|---|
    | `required_version` (CLI) | floor: `>= X` at the lowest feature you use | don't gratuitously exclude older-but-fine CLIs |
    | provider `version` | recent major, bounded: `~> 6.0` | provider majors have breaking changes; block an untested newer major |

    Over-pinning the floor bites hardest with **modules**: a module declaring `>= 1.15` can't be consumed by a team still on 1.14, even if it needs nothing from 1.15.

### `main.tf` — provider, data source, resource

```hcl
# main.tf
provider "aws" {
  region = "us-west-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"

  tags = {
    Name = "learn-terraform"
  }
}
```

**Provider block** — configures options for all resources of that provider (here, `region`). The block label (`aws`) matches the name in `required_providers`. You can have multiple provider blocks for multiple providers, or multiple instances of one provider (e.g. different regions — see I8). The AWS provider authenticates the same way the AWS CLI does; set credentials as env vars:

```shell
$ export AWS_ACCESS_KEY_ID=
$ export AWS_SECRET_ACCESS_KEY=
$ aws configure list          # verify
```

**Data source** — `data` blocks *query* the provider for info without managing it. Here it fetches the latest matching Ubuntu AMI so the ID isn't hard-coded (stale-proofing). Reference its attributes via `data.<type>.<name>.<attr>` → `data.aws_ami.ubuntu.id`.

**Resource** — `resource` blocks *create/manage* infrastructure. First line = resource type + name; the type prefix (`aws_`) is the provider. Type + name = the **resource address** (`aws_instance.app_server`), used to reference it elsewhere. The `ami` argument references the data source's `id` — this implicit reference is what makes Terraform read the AMI before creating the instance (see the VPC→subnet→instance dependency logic in [[core-workflow]]). `t2.micro` is free-tier.

## Format & validate

```shell
$ terraform fmt        # rewrite files to canonical style; prints changed filenames
$ terraform validate   # syntax + internal consistency check
Success! The configuration is valid.
```

`validate` catches mistyped resource names or unsupported arguments before you touch real infrastructure.

## Initialize

```shell
$ terraform init
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 6.0"...
- Installing hashicorp/aws v6.53.0...
- Installed hashicorp/aws v6.53.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. ...
Terraform has been successfully initialized!
```

`init` downloads providers into a hidden `.terraform/` dir and writes **`.terraform.lock.hcl`** pinning exact provider versions for reproducibility. Commit the lock file.

## Apply

`apply` runs in two steps: build an execution plan, show it, then execute on `yes`.

```shell
$ terraform apply
data.aws_ami.ubuntu: Reading...
data.aws_ami.ubuntu: Read complete after 1s [id=ami-0026a04369a3093cc]

  # aws_instance.app_server will be created
  + resource "aws_instance" "app_server" {
      + ami           = "ami-0026a04369a3093cc"
      + instance_type = "t2.micro"
      + tags          = { + "Name" = "learn-terraform" }
      # ... many attributes (known after apply) ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Enter a value: yes

aws_instance.app_server: Creating...
aws_instance.app_server: Creation complete after 14s [id=i-0c636e158c30e48f9]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

- Plan output is Git-diff-like: `+` = create. Attributes shown as `(known after apply)` can't be resolved until the resource exists.
- Reviewing the plan before `yes` is the safety gate — cancel here if it shows something unexpected.

## Inspect state

`apply` writes **`terraform.tfstate`** — Terraform's record of real infrastructure, used to build future plans.

```shell
$ terraform state list
data.aws_ami.ubuntu
aws_instance.app_server

$ terraform show          # full state dump
```

- The data source is tracked in state too, even though it's not a managed resource.
- Plans are computed by comparing three things: last-known state, current config, and fresh data from providers.
- State can hold **sensitive data in plaintext** (passwords, keys) — store it securely, restrict access. Local by default; remote state via HCP Terraform (or another backend) is the team-scale answer (see B9, I6, and the [[workspaces]] cache for the CLI-vs-HCP distinction).

## Interactive lab

The tutorial offers a free browser-based interactive terminal to run the whole thing without a cloud account.

---
Related: extends [[tf-install-cli]] (the previous lesson) into a real project. The hands-on counterpart to [[terraform-intro]] and [[01-brief-overview]] §1.4 — same init/plan/apply loop, run for real. Demonstrates the [[core-workflow]] and [[providers]] topics concretely. Feeds learning-path **B2** (first project), **B3** (core workflow), **B5** (providers/resources), **B8** (data sources), **B9** (state).
