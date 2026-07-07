# Manage infrastructure (AWS Get Started)

> **Source:** [developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-manage](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-manage)
> **Added:** 2026-07-07
> **Source updated:** undated tutorial (~10 min); captured 2026-07-07
> **Tags:** variables, outputs, modules, plan-symbols, in-place-update, replace, dependency-graph, vpc
> **Type:** documentation

Third lesson of the AWS Get Started track. Picks up the project from [[tf-aws-create]] and shows how Terraform *changes* existing infrastructure. Three moves: parametrize with **input variables**, expose data with **output values**, and pull in a **registry module** (the AWS VPC module). Along the way it introduces the plan-diff symbols (`~`, `-/+`) and the dependency-graph ordering that [[core-workflow]] describes.

> 📌 **Version note (captured 2026-07-07):** The live tutorial pins the AWS provider `~> 5.92` and the VPC module `5.19.0`. Both are behind current. As of 2026-07-07: AWS provider is on **major 6** (6.53.0, see [[version-facts]]) and the **VPC module latest is 6.6.1** (2026-04-02, see the `terraform-aws-vpc-module-version` search cache). VPC module **6.x requires AWS provider `>= 6.0`** — so if you follow [[tf-aws-create]]'s advice to pin the provider `~> 6.0`, you should also bump the module to `~> 6.0`. Staying on provider 5.x forces VPC module 5.x. The workflow (add vars → plan → apply → add module → re-init → apply) is unchanged; only the pins move.

## Prerequisites

- Terraform CLI **1.2.0+** and the **AWS CLI** installed.
- Credentials for **us-west-2** that can create an EC2 instance, VPC, and security groups.
- The config + infrastructure from [[tf-aws-create]] (the `main.tf` + `terraform.tf` already applied). This lesson mutates that project.

## Variables and outputs

Input variables parametrize a config's behavior; output values expose data about the resources you create. Together they give a Terraform workspace a **consistent interface** — a stable set of knobs to configure it and values to read back — which is what lets other automation tools integrate with it.

### Input variables

Put variable definitions in their own `variables.tf` by convention.

```hcl
# variables.tf
variable "instance_name" {
  description = "Value of the EC2 instance's Name tag."
  type        = string
  default     = "learn-terraform"
}

variable "instance_type" {
  description = "The EC2 instance's type."
  type        = string
  default     = "t2.micro"
}
```

Each variable here sets a `default`, so Terraform uses it when no value is supplied. This lets you change the instance's name/type without editing the config files.

Update `main.tf` to reference the variables instead of hard-coded values:

```hcl
# main.tf
resource "aws_instance" "app_server" {
   ami           = data.aws_ami.ubuntu.id
-  instance_type = "t2.micro"
+  instance_type = var.instance_type

  tags = {
-   Name = "learn-terraform"
+   Name = var.instance_name
  }
}
```

Variable values can be set many ways — environment variables, command-line arguments, and files on disk (the full precedence order is a B6 topic).

**Plan with a command-line variable** — preview a `t2.large` swap without applying:

```shell
$ terraform plan -var instance_type=t2.large
...
Terraform will perform the following actions:

  # aws_instance.app_server will be updated in-place
  ~ resource "aws_instance" "app_server" {
        id                          = "i-0c636e158c30e48f9"
      ~ instance_type               = "t2.micro" -> "t2.large"
      ~ public_dns                  = "ec2-34-216-162-36...compute.amazonaws.com" -> (known after apply)
      ~ public_ip                   = "34.216.162.36" -> (known after apply)
        tags                        = { "Name" = "learn-terraform" }
        # (36 unchanged attributes hidden)
        # (8 unchanged blocks hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.

Note: You didn't use the -out option to save this plan, so Terraform can't
guarantee to take exactly these actions if you run "terraform apply" now.
```

- `~` = **update in-place**. The changed attribute shows `old -> new`; dependent attributes that AWS won't assign until apply show `(known after apply)`.
- The `Note` about `-out` is Terraform warning that an unsaved plan may not match a later apply (config or real infra could drift in between). Save with `terraform plan -out=FILE` when you need that guarantee.

### Output values

Output values expose attributes from your config for other tools/workflows to consume. Define them in `outputs.tf`:

```hcl
# outputs.tf
output "instance_hostname" {
  description = "Private DNS name of the EC2 instance."
  value       = aws_instance.app_server.private_dns
}
```

Apply. The two new variables default to the same values they replaced, so the *only* real change Terraform detects is the added output — no infrastructure changes:

```shell
$ terraform apply
...
Changes to Outputs:
  + instance_hostname = "ip-172-31-35-26.us-west-2.compute.internal"

You can apply this plan to save these new output values to the Terraform state,
without changing any real infrastructure.
...
  Enter a value: yes

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:
instance_hostname = "ip-172-31-35-26.us-west-2.compute.internal"
```

Outputs are printed on every plan/apply and stored in the state file. Read them any time with `terraform output`:

```shell
$ terraform output
instance_hostname = "ip-172-31-35-26.us-west-2.compute.internal"
```

## Modules

Modules are **reusable sets of configuration** — multiple resources and data sources managed as one unit. Like providers, you can source them from the Terraform Registry, or write your own and share them internally.

### Module blocks

Add a `module` block to `main.tf` to create a VPC and its networking resources:

```hcl
# main.tf
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0" # current is 6.6.1; 6.x needs AWS provider >= 6.0

  name = "example-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a", "us-west-2b", "us-west-2c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_dns_hostnames = true
}
```

This defines a VPC `example-vpc` with two private and one public subnet. Because Terraform resolves dependencies automatically, block order doesn't matter — organize for readability.

> ⚠️ **Source error:** the tutorial prose says "two public and two private subnets," but its own config declares **2 private + 1 public** (`private_subnets` has two CIDRs, `public_subnets` one). The `terraform state list` output confirms it: `aws_subnet.private[0]`, `private[1]`, `public[0]`. Trust the config, not the sentence.

!!! note "Why the module pins `version = "5.19.0"` exactly, not `~> 5.19.0`"
    Exact pin (`= "5.19.0"`) locks one version; `~> 5.19.0` would allow any patch (`>= 5.19.0, < 5.20.0`). Modules pin exact on purpose because of an asymmetry with providers:

    **`.terraform.lock.hcl` records provider versions only — never module versions.** So a provider constraint like `~> 6.0` is still reproducible: the lock file pins the exact resolved version, and every `init` reuses it. Modules get no such backstop — the `version` string is the *only* thing pinning them.

    Consequence: with a loose module constraint, two `terraform init` runs (different machines, or the same one weeks apart) can silently pull **different** module versions, changing what the module's resources look like with no diff in your `.tf` files. An exact pin guarantees identical module code everywhere.

    | Dependency | Idiomatic style | Reproducibility comes from |
    |---|---|---|
    | provider | `~> 6.0` (recent major, bounded) | `.terraform.lock.hcl` |
    | module | `= "5.19.0"` (exact) | the `version` string itself |

    Syntax note: the operator lives **inside** the quotes — `version = "~> 5.19.0"`, never `version = ~> "5.19.0"` (parse error).

Move the EC2 instance **into** the new VPC by referencing the module's outputs:

```hcl
# main.tf
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.private_subnets[0]

  tags = {
    Name = var.instance_name
  }
}
```

Reference a module's outputs with `module.<name>.<output>` — here `module.vpc.default_security_group_id` and `module.vpc.private_subnets[0]`. This implicit reference is what makes Terraform build the VPC before the instance.

**Re-initialize** — any new module must be installed with `terraform init`:

```shell
$ terraform init
Initializing the backend...
Initializing modules...
Downloading registry.terraform.io/terraform-aws-modules/vpc/aws 5.19.0 for vpc...
- vpc in .terraform/modules/vpc
Initializing provider plugins...
- Reusing previous version of hashicorp/aws from the dependency lock file
- Using previously-installed hashicorp/aws v5.98.0
Terraform has been successfully initialized!
```

`init` on an existing workspace detects and installs any new providers **and modules**. Module versions are tracked alongside providers in `.terraform.lock.hcl`. Modules download into `.terraform/modules/`.

### Plan and apply changes

Apply to build the VPC and move the instance into it. **AWS can't move an existing EC2 instance to a new VPC**, so Terraform plans to *replace* it rather than update in place:

```shell
$ terraform apply
...
Resource actions are indicated with the following symbols:
  + create
-/+ destroy and then create replacement

  # aws_instance.app_server must be replaced
-/+ resource "aws_instance" "app_server" {
      ~ arn                         = "arn:aws:ec2:...i-0c636e158c30e48f9" -> (known after apply)
      ~ associate_public_ip_address = true -> (known after apply)
      ~ availability_zone           = "us-west-2b" -> (known after apply)
      ## ...
    }

Plan: 16 to add, 0 to change, 1 to destroy.

Changes to Outputs:
  ~ instance_hostname = "ip-172-31-35-26...internal" -> (known after apply)
...
  Enter a value: yes

aws_instance.app_server: Destroying... [id=i-0fbb487cbdf2eb6ed]
aws_instance.app_server: Destruction complete after 31s
module.vpc.aws_vpc.this[0]: Creating...
module.vpc.aws_vpc.this[0]: Creation complete after 12s [id=vpc-01e157ec1af2d7314]
## ...
aws_instance.app_server: Creation complete after 13s [id=i-0226232d8b6e9eea6]

Apply complete! Resources: 16 added, 0 changed, 1 destroyed.

Outputs:
instance_hostname = "ip-10-0-1-75.us-west-2.compute.internal"
```

The **plan-diff symbols** — the full set introduced here:

| Symbol | Meaning |
|---|---|
| `+` | create |
| `-` | destroy |
| `~` | update in-place |
| `-/+` | destroy then create a **replacement** (a forced-new attribute changed) |

Terraform ran operations in **dependency order**: destroyed the old instance, created the VPC and most related resources, then created the new instance last. It builds a **dependency graph** at plan time and, on apply, creates/updates/destroys in that order — and **in parallel where possible**.

Inspect the expanded resource set:

```shell
$ terraform state list
data.aws_ami.ubuntu
aws_instance.app_server
module.vpc.aws_default_network_acl.this[0]
module.vpc.aws_default_route_table.default[0]
module.vpc.aws_default_security_group.this[0]
module.vpc.aws_internet_gateway.this[0]
module.vpc.aws_route.public_internet_gateway[0]
module.vpc.aws_route_table.private[0]
module.vpc.aws_route_table.private[1]
module.vpc.aws_route_table.public[0]
module.vpc.aws_route_table_association.private[0]
module.vpc.aws_route_table_association.private[1]
module.vpc.aws_route_table_association.public[0]
module.vpc.aws_subnet.private[0]
module.vpc.aws_subnet.private[1]
module.vpc.aws_subnet.public[0]
module.vpc.aws_vpc.this[0]
```

Resources created **inside** a module are addressed with a `module.vpc.` prefix. Module addresses must be unique within a config; reuse the same module by giving each `module` block a distinct name (same `source`/`version`, different label).

## Interactive lab

Free browser-based terminal — use the **Skip** button to jump to the second challenge to follow this lesson without a cloud account.

---
Related: continues [[tf-aws-create]] (previous lesson) — same project, now *modified*. Demonstrates [[core-workflow]]'s plan/apply loop and dependency-graph ordering concretely, and the [[providers]] registry model applied to **modules**. Feeds learning-path **B3** (plan symbols `~`/`-/+`, `-out`), **B6** (input variables + outputs), and **I4** (using registry modules, `module.*` addressing, module versioning in the lock file).
