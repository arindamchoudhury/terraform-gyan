# Use registry modules in configuration

> **Source:** [developer.hashicorp.com/terraform/tutorials/modules/module-use](https://developer.hashicorp.com/terraform/tutorials/modules/module-use?variants=terraform-workflow%3Acommunity)
> **Added:** 2026-08-08
> **Source updated:** undated tutorial (~12 min); captured 2026-08-08
> **Tags:** modules, module-block, source, version, module-outputs, count-on-module, terraform-get, registry
> **Type:** documentation

Second page of the **Modules** collection, the first with code. Follows [[tut-module]], which supplied the vocabulary. Consumes two registry modules — `terraform-aws-modules/vpc/aws` and `terraform-aws-modules/ec2-instance/aws` — to build a VPC plus two EC2 instances, 22 resources in total. Captured in the **Terraform Community Edition** variant; the page also offers an HCP Terraform variant, which differs only in a `cloud` block and where the run executes.

Prerequisites: Terraform v1.1+, an AWS account with local credentials, and `git clone https://github.com/hashicorp-education/learn-terraform-modules-use`.

## `source` and `version`

The two arguments the Registry's example configuration sets, and the only two the `module` block itself defines:

- **`source` is required.** Given a registry-style string, Terraform searches the Terraform Registry for a match. A URL or a local path works too.
- **`version` is not required, but "we highly recommend you include it".** Without it Terraform loads the **latest** version. The tutorial pins exact version numbers throughout.

Everything else in a `module` block is passed through as an **input variable** for the module. That is the whole calling convention.

!!! warning "“Not required” understates it — there is no lock file to catch you"
    `.terraform.lock.hcl` records **providers only**. A module selection lives in `.terraform/modules/modules.json`, which is not committed, so an unpinned `source` re-resolves on every fresh clone and every clean CI runner. The recommendation to pin is not a style preference; it is the only control that exists. See [[tf-dependency-lock]] and [[tf-expr-version-constraints]] for the constraint operators.

## The configuration

`terraform.tf` — the self-configuration block, with the HCP Terraform `cloud` block commented out for the Community Edition path:

```hcl
terraform {
  /* Uncomment this block to use HCP Terraform for this tutorial
  cloud {
    organization = "organization-name"
    workspaces {
      name = "learn-terraform-module-use"
    }
  }
  */

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.49.0"
    }
  }
  required_version = ">= 1.1.0"
}
```

`main.tf` — provider plus two module calls:

```hcl
provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      hashicorp-learn = "module-use"
    }
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.18.1"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = var.vpc_azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  enable_nat_gateway = var.vpc_enable_nat_gateway

  tags = var.vpc_tags
}

module "ec2_instances" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.3.0"

  count = 2
  name  = "my-ec2-cluster-${count.index}"

  ami                    = "ami-0c5204531f799e0c6"
  instance_type          = "t3.micro"
  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.public_subnets[0]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
```

Three things the page calls out about the second block:

- **`count` is a meta-argument on the `module` block**, here creating two instances. This is the same mechanism [[tut-for-each]] leans on when it moves a `count` resource into a module so `for_each` can go on the module block. Both instances come from one call.
- **`vpc_security_group_ids` and `subnet_id` reference the other module's outputs**, which is what orders the two calls. No `depends_on` anywhere; the reference is the dependency ([[tut-dependencies]]).
- Required vs optional inputs: you must supply every required argument, and omitted optional ones fall back to the module's own defaults.

## Root variables — and when *not* to add one

The recommended pattern: identify the module arguments you may want to change later, declare matching variables in `variables.tf` with sensible defaults, and pass them into the `module` block.

```hcl
variable "vpc_name" {
  description = "Name of VPC"
  type        = string
  default     = "example-vpc"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_azs" {
  description = "Availability zones for VPC"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "vpc_private_subnets" {
  description = "Private subnets for VPC"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "vpc_public_subnets" {
  description = "Public subnets for VPC"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "vpc_enable_nat_gateway" {
  description = "Enable NAT gateway for VPC"
  type        = bool
  default     = true
}

variable "vpc_tags" {
  description = "Tags to apply to resources created by VPC module"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}
```

The sharper half of that advice is the negative case, and it is easy to skim past:

> You do not need to set all module input variables with variables. For example, if your organization requires NAT gateway enabled for all VPCs, you should not use a variable to set the `enable_nat_gateway` argument.

A variable is a *permission to vary*. Declaring one for a value policy has already fixed hands that decision to the caller. Note the tutorial then does exactly what it warns against — `vpc_enable_nat_gateway` is a variable, defaulted `true`.

## Module outputs are not inherited

```hcl
output "vpc_public_subnets" {
  description = "IDs of the VPC's public subnets"
  value       = module.vpc.public_subnets
}

output "ec2_instance_public_ips" {
  description = "Public IP addresses of EC2 instances"
  value       = module.ec2_instances[*].public_ip
}
```

Reference a child module's output as `module.MODULE_NAME.OUTPUT_NAME`. The constraint worth remembering:

> Terraform will not display module outputs by default. You must create a corresponding output in your root module and set it to the module's output.

So a child module's outputs are readable inside the configuration but invisible at the CLI until the root module re-exports them. (Root-module output mechanics: [[tf-outputs]], with the `terraform output` / `-raw` / `-json` workflow in [[tut-outputs]].)

`module.ec2_instances[*].public_ip` is a splat over a **counted module call**, not over a resource — the modern `[*]` form, correctly used here, unlike the legacy `.*.` in [[tut-count]]. Because this module does not type its outputs, `module.ec2_instances` is a **tuple** rather than a list; the splat works either way (see [[conditional-branch-evaluation]] for why the container type differs and why callers can't tell).

## Apply

```shell
$ terraform init
Initializing the backend...
##...
Terraform has been successfully initialized!
```

```shell
$ terraform apply

Plan: 22 to add, 0 to change, 0 to destroy.
...
  Enter a value: yes

Apply complete! Resources: 22 added, 0 changed, 0 destroyed.

Outputs:

ec2_instance_public_ips = [
  "54.245.140.252",
  "34.219.48.47",
]
vpc_public_subnets = [
  "subnet-0cb9ff659ba66a7dd",
  "subnet-0c2788b6ffb0611c0",
]
```

**22 resources from four `module` arguments' worth of visible config.** The page flags this plainly: "The vpc and ec2 modules define more resources than just the VPC and EC2 instances." That ratio is the encapsulation benefit and the review problem in the same number.

## How module installation works

- First use of a new module requires **`terraform init` or `terraform get`** — either installs it.
- Installed modules land in **`.terraform/modules/`** inside the working directory.
- **Local modules are symlinked**, not copied. So edits to a local module take effect immediately, with no re-init and no re-`get`.

```
.terraform/modules/
├── ec2_instances
├── modules.json
└── vpc
```

The `modules.json` sitting beside them is the unversioned, uncommitted record of what got resolved — the reason the pinning warning above matters.

## Destroy

```shell
$ terraform destroy

Plan: 0 to add, 0 to change, 22 to destroy.

Changes to Outputs:
  - ec2_instance_public_ips = [
      - "54.245.140.252",
      - "34.219.48.47",
    ] -> null
  - vpc_public_subnets      = [
      - "subnet-0cb9ff659ba66a7dd",
      - "subnet-0c2788b6ffb0611c0",
    ] -> null

  Enter a value: yes

Destroy complete! Resources: 22 destroyed.
```

HCP Terraform users also delete the `learn-terraform-module-use` workspace afterwards.

## Staleness — pins are years old, but the interface is not

!!! warning "Every pin on this page is stale; nothing it teaches is broken"
    Verified 2026-08-08 against the Terraform Registry API and the modules' source at their current tags.

    | Pinned here | Current | Note |
    |---|---|---|
    | AWS provider `~> 4.49.0` | 6.x | — |
    | `vpc` **3.18.1** | **6.6.1** (2026-04-02) | 6.x requires AWS provider `>= 6.0` |
    | `ec2-instance` **4.3.0** | **6.4.0** (2026-03-26) | requires Terraform `>= 1.5.7`, AWS provider `>= 6.37` |

    **The good news is the specific one:** every argument and output this tutorial uses still exists at the current major version. Checked at `vpc` v6.6.1 — inputs `name`, `cidr`, `azs`, `private_subnets`, `public_subnets`, `enable_nat_gateway`, `tags` all present; outputs `public_subnets` and `default_security_group_id` both present. Checked at `ec2-instance` v6.4.0 — inputs `name`, `ami`, `instance_type`, `vpc_security_group_ids`, `subnet_id`, `tags` all present. So bumping the pins is a version exercise, not a rewrite. Contrast [[tut-count]], where the rendered snippet references an output name that no longer exists.

    Note the coupling, though: the two module bumps are not independent of the provider bump. `ec2-instance` 6.4.0 alone forces AWS provider `>= 6.37`, which forces `vpc` off 3.x. Upgrade all three or none.

!!! note "The hardcoded AMI is the part to not copy"
    `ami = "ami-0c5204531f799e0c6"` is a literal AMI ID, which is **region-specific and eventually deregistered** — it works only in `us-west-2` and only while AWS keeps it. Current `ec2-instance` offers `ami_ssm_parameter` (verified present at v6.4.0) which resolves an AMI through SSM instead; an `aws_ami` data source with `most_recent` and an owner filter is the provider-level equivalent ([[tf-data-sources]]).

!!! warning "The page and its example repo disagree — and here the page is right"
    Rendered snippet: `name = "my-ec2-cluster-${count.index}"`. The repo's `main.tf` on `main`: `name = "my-ec2-cluster"`, with no index. Verified 2026-08-08.

    Run the repo as-is and both instances get the identical `Name` tag. AWS permits it (the `Name` tag is not unique), so nothing fails — you just get two indistinguishable instances in the console. The page's indexed form is the better one. This is the mirror image of [[tut-count]], where the repo was correct and the rendered page was stale.

## Next steps

Stated takeaways: using modules in configuration, managing module versions, configuring module input variables, and using module output values. The page points at the **Create and Use No-Code Modules** tutorial for HCP Terraform Standard Edition's private-registry path. The next tutorial in the collection builds a module for hosting a website in an S3 bucket — captured as [[tut-module-create]].

---
Related: continues [[tut-module]], which motivated modules without showing one. Same VPC-module territory as [[tf-aws-manage]], one level deeper — this one pins versions, wires module-to-module references, and re-exports outputs. `count` on a `module` block is the mechanism [[tut-for-each]] reaches for to multiply on two axes. The pinning advice is enforced by [[tf-expr-version-constraints]] and left unprotected by [[tf-dependency-lock]] (providers only). Output re-export connects to [[tf-outputs]] / [[tut-outputs]]; the splat form to [[tf-expr-splat]]. Feeds learning-path **I4** (using modules) directly, and **I5** by contrast — this is the consumer's view of an interface [[tut-module]] says you should design.
