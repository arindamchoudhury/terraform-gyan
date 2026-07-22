# Query data sources

> **Source:** [developer.hashicorp.com/terraform/tutorials/configuration-language/data-sources](https://developer.hashicorp.com/terraform/tutorials/configuration-language/data-sources?variants=terraform-workflow%3Acommunity)
> **Added:** 2026-07-22
> **Source updated:** undated tutorial (~14 min); captured 2026-07-22 (Community Edition variant)
> **Tags:** data-sources, aws_availability_zones, aws_region, aws_ami, terraform_remote_state, two-workspace, dynamic-config
> **Type:** documentation

Third **Configuration Language** tutorial, the hands-on for [[tf-data-sources]] / [[tf-block-data]]. Its whole point: **replace hard-coded, region-specific values with data-source lookups** so one config deploys to any region. Uses two separate configs — a VPC workspace and an app workspace — and wires them together with `terraform_remote_state`. Terraform 1.2+, AWS CLI + credentials. Repos: `learn-terraform-data-sources-vpc` and `learn-terraform-data-sources-app` (both under `github.com/hashicorp-education`).

> **Community Edition variant:** each config's `terraform.tf` has its `cloud { }` block commented out, so both run with the **local backend**. The HCP variant leaves `cloud` active and shares state via workspaces instead of a local tfstate path.

## Four data sources, three problems

The tutorial demonstrates four AWS/built-in data sources, each fixing a different hard-coded value.

### 1. `aws_availability_zones` — dynamic AZ list

The VPC's `azs` was a hard-coded `us-east-1a…e` list, so changing `var.aws_region` alone wouldn't actually move regions. The data source loads the current region's AZs:

```hcl
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }
}
```

Then feed it to the module: `azs = data.aws_availability_zones.available.names`. Reference pattern is `data.<NAME>.<ATTRIBUTE>`.

### 2. `aws_region` — provider's *actual* region

```hcl
data "aws_region" "current" {}

output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}
```

The VPC workspace outputs its region for the app workspace to consume.

> **Tip from the page:** you *could* output `var.aws_region` directly. But `aws_region` returns the provider's current region **no matter how it was configured** (var, env, provider block, profile). The data source is the robust choice.

Apply with `terraform apply -var aws_region=us-west-1` → 34 resources, outputs the subnet/SG IDs and region.

### 3. `terraform_remote_state` — read the other workspace's outputs

The app workspace reads the VPC workspace's root outputs from its **local** tfstate file:

```hcl
data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "../learn-terraform-data-sources-vpc/terraform.tfstate"
  }
}
```

Then consume those outputs — no hard-coded region, SGs, or subnets:

```hcl
provider "aws" {
  region = data.terraform_remote_state.vpc.outputs.aws_region
}

module "elb_http" {
  security_groups = data.terraform_remote_state.vpc.outputs.lb_security_group_ids
  subnets         = data.terraform_remote_state.vpc.outputs.public_subnet_ids
}
```

> **Root-outputs-only:** `terraform_remote_state` can load **only root-level output values** from the source workspace — not resource or module values directly. To expose one, add a matching `output` to the source workspace. (This is the security-relevant limit detailed in [[tf-remote-state-data]].) `backend = "local"` here; it also supports `remote` for HCP Terraform / Consul.

### 4. `aws_ami` — region-correct image

The app's AMI was hard-coded to a `us-east-1`-only ID. Load the right one for the current region:

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```

Then `ami = data.aws_ami.amazon_linux.id`.

## Data-source values feed functions and `count`

Data-source results are ordinary values — usable in functions and meta-arguments. The tutorial scales EC2 instances by multiplying a variable by the subnet count read from remote state:

```hcl
resource "aws_instance" "app" {
  count = var.instances_per_subnet * length(data.terraform_remote_state.vpc.outputs.private_subnet_ids)

  ami = data.aws_ami.amazon_linux.id

  subnet_id              = data.terraform_remote_state.vpc.outputs.private_subnet_ids[count.index % length(data.terraform_remote_state.vpc.outputs.private_subnet_ids)]
  vpc_security_group_ids = data.terraform_remote_state.vpc.outputs.app_security_group_ids
}
```

## Teardown order matters

> **Destroy the app workspace *before* the VPC workspace.** App resources depend on VPC resources, so destroying the VPC first makes the AWS API error. Also reuse the same `-var aws_region=us-west-1` on the VPC destroy that you used on apply.

---
Related: [[tf-data-sources]] — the concept page this tutorial exercises. [[tf-block-data]] — the argument catalog for the `data` blocks used here. [[tf-remote-state-data]] — deep dive on `terraform_remote_state`, its root-outputs limit and the security case against it. [[tut-outputs]] — the prior tutorial; the outputs consumed here via remote state are defined the same way.
