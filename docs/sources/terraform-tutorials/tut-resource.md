# Define infrastructure with Terraform resources

> **Source:** [developer.hashicorp.com/terraform/tutorials/configuration-language/resource](https://developer.hashicorp.com/terraform/tutorials/configuration-language/resource)
> **Added:** 2026-07-13
> **Source updated:** undated tutorial (~11 min); captured 2026-07-13
> **Tags:** resources, arguments, attributes, meta-arguments, implicit-dependency, random_pet, security-group, registry-docs
> **Type:** documentation

First tutorial of the **Configuration Language** collection (a different track from the AWS Get Started arc in [[tf-aws-create]]). It builds an EC2 instance running a PHP app, then adds a security group by reading the Registry docs. The payoff is the precise **arguments vs. attributes vs. meta-arguments** taxonomy — the distinction [[tf-aws-create]] uses implicitly but never names.

Uses `git clone https://github.com/hashicorp-education/learn-terraform-resources`. Assumes familiarity with the core workflow; needs Terraform 1.2+ and AWS credentials. Works with either **Terraform Community Edition** or **HCP Terraform** (the only difference is a `cloud` block — see the CE-vs-HCP note below).

## Resource blocks

A `resource` block represents one or more infrastructure objects. Most providers expose many resource types mapping to their API:

| Generic | AWS provider resource | AWS infrastructure |
|---|---|---|
| Resource A | `aws_instance` | EC2 instance |
| Resource B | `aws_security_group` | Security group |

**Resource ID** = `resource_type.resource_name` (e.g. `random_pet.name`), and must be **unique within a workspace**. A resource **type always starts with the provider name + underscore** — `random_pet` belongs to the `random` provider. The Registry houses each provider's docs: a resource's page has description, example usage, argument reference, and attribute reference.

## Arguments, attributes, meta-arguments

The three things a resource block deals in:

- **Arguments** configure the resource; mostly resource-specific. Provider marks each **required or optional** — a missing required argument is an error, and Terraform won't apply.
- **Attributes** are values **exposed by an existing resource**, referenced as `resource_type.resource_name.attribute_name`. Unlike arguments (which you set), attributes are often **assigned by the cloud provider/API** at create time.
- **Meta-arguments** change a resource's *behavior* (e.g. `count` to make many). They're a **function of Terraform itself — not resource- or provider-specific**.

## The `random_pet` resource

```hcl
resource "random_pet" "name" {}
```

Generates a random pet name, used to give other resources unique names. It has four optional arguments and exposes one attribute; **no required arguments**, so an empty body is valid.

## The EC2 instance

```hcl
resource "aws_instance" "web" {
  ami                    = "ami-a0cfeed8"
  instance_type          = "t2.micro"
  user_data              = file("init-script.sh")

  tags = {
    Name = random_pet.name.id
  }
}
```

- `ami` + `instance_type` → a `t2.micro` from image `ami-a0cfeed8` (deploys to **us-west-2**; change the AMI for another region).
- `user_data = file("init-script.sh")` — the `file()` function returns the script's contents.
- `tags.Name = random_pet.name.id` references the `random_pet`'s `id` **attribute**. This creates an **implicit dependency** — Terraform can't create the instance until it has the pet name. (Same implicit-reference mechanism [[tf-aws-create]] shows on the AMI data source.)

`terraform apply` → `Plan: 2 to add` (the pet + the instance). The `domain-name` output resolves, but visiting it fails: **port 80 isn't open yet**.

## Add a security group from the Registry docs

Open the AWS provider docs, search `security_group`, read `aws_security_group`, then write:

```hcl
resource "aws_security_group" "web-sg" {
  name = "${random_pet.name.id}-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

Then wire it into the instance. The `aws_instance` argument reference says `vpc_security_group_ids` takes a **list of IDs**, so wrap the attribute in brackets:

```hcl
+ vpc_security_group_ids = [aws_security_group.web-sg.id]
```

`terraform apply` → `Plan: 1 to add, 1 to change` (add the SG, update the instance). The app is now reachable over **http** (not https). `terraform output application-url` reprints the endpoint; the PHP app can take ~10 minutes to come up.

## Cleanup and next steps

`terraform destroy` → `3 destroyed` (instance, SG, pet). Follow-ons the tutorial points to: **resource dependencies**, **query data sources** (dynamic AMI IDs), and **functions / dynamic expressions**.

!!! note "Community Edition vs HCP Terraform"
    The whole tutorial works identically on either. For HCP Terraform you uncomment a `cloud` block in `terraform.tf` (`organization` + `workspaces { name = … }`), and `terraform init` creates the workspace remotely; state, execution, and outputs live in the HCP workspace instead of locally. Credentials come from an HCP **variable set** rather than local AWS config.

---
Related: config-language companion to [[tf-aws-create]] (AWS Get Started) — both build an `aws_instance`, but this one names the **arguments/attributes/meta-arguments** taxonomy and adds a security group + `random_pet`. Feeds learning-path **B5** (resource block, implicit dependencies, reading Registry argument/attribute references). The `count` meta-argument mention points at **I1**.
