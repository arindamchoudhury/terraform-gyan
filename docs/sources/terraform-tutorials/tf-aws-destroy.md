# Destroy infrastructure (AWS Get Started)

> **Source:** [developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-destroy](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-destroy)
> **Added:** 2026-07-07
> **Source updated:** undated tutorial (~4 min); captured 2026-07-07
> **Tags:** destroy, remove-resource, terraform-destroy, plan-symbols, teardown, lifecycle
> **Type:** documentation

Fourth lesson of the AWS Get Started track. Closes the create → manage → **destroy** loop on the project from [[tf-aws-manage]]. Two ways to tear down: remove a resource from config and `apply` (surgical), or `terraform destroy` (everything). This is the `-` half of the plan-diff symbols introduced in [[tf-aws-manage]].

## Prerequisites

- Terraform CLI **1.2.0+** and the **AWS CLI**.
- The config + infrastructure from the previous tutorials in the track (the EC2 instance now living inside the VPC module).

## Two ways to destroy

Terraform destroys a resource in **either** of two situations:

1. You **remove it from configuration** and `apply` — Terraform sees a resource in state with no matching config block and plans to destroy it.
2. You run **`terraform destroy`** — destroys *everything* the workspace manages, regardless of config.

### 1. Remove a single resource (edit config + apply)

Comment out (or delete) the `aws_instance.app_server` block in `main.tf`:

```hcl
# main.tf
/*
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  vpc_security_group_ids = [module.vpc.default_security_group_id]
  subnet_id              = module.vpc.private_subnets[0]

  tags = {
    Name = var.instance_name
  }
}
*/
```

The `instance_hostname` output references the now-removed instance, so it **must** be commented out too — otherwise the config is invalid (an output referencing a resource that no longer exists):

```hcl
# outputs.tf
/*
output "instance_hostname" {
  description = "Private DNS name of the EC2 instance."
  value       = aws_instance.app_server.private_dns
}
*/
```

`apply` — the plan destroys just the instance and drops the output to `null`:

```shell
$ terraform apply
...
Plan: 0 to add, 0 to change, 1 to destroy.

Changes to Outputs:
  - instance_hostname = "ip-10-0-1-75.us-west-2.compute.internal" -> null
...
  Enter a value: yes

aws_instance.app_server: Destroying... [id=i-0226232d8b6e9eea6]
aws_instance.app_server: Still destroying... [id=..., 01m20s elapsed]
aws_instance.app_server: Destruction complete after 1m22s

Apply complete! Resources: 0 added, 0 changed, 1 destroyed.
```

- `-` in the plan = **destroy**. The output shows `oldvalue -> null` because the value it depended on is gone.
- Removing a resource from config *is* a destroy operation — this is the everyday teardown path (retiring one component while the rest of the workspace stays up).

### 2. Destroy the whole workspace (`terraform destroy`)

When you no longer need *any* of the workspace's infrastructure — decommissioning an environment, or tearing down a short-lived build/test stack:

```shell
$ terraform destroy
...
Plan: 0 to add, 0 to change, 15 to destroy.

Do you really want to destroy all resources?
  Terraform will destroy all your managed infrastructure, as shown above.
  There is no undo. Only 'yes' will be accepted to confirm.

  Enter a value: yes

module.vpc.aws_route_table_association.private[1]: Destroying...
...
module.vpc.aws_vpc.this[0]: Destroying... [id=vpc-01e157ec1af2d7314]
module.vpc.aws_vpc.this[0]: Destruction complete after 1s

Destroy complete! Resources: 15 destroyed.
```

- `terraform destroy` is effectively `terraform apply` of a plan that removes every managed resource. (Under the hood it's the same as `apply -destroy`.)
- The confirmation prompt is worded harder than a normal apply — **"There is no undo."** Destroy is irreversible; the safety gate is reading the plan before typing `yes`.
- Destruction runs in **reverse dependency order** — associations/routes first, subnets and gateways next, the VPC last — the mirror image of the creation order in [[tf-aws-manage]].
- The `data.aws_ami.ubuntu` data source is refreshed but not destroyed — data sources only read, they never manage anything to tear down.

!!! note "Two teardown verbs, two blast radii"
    - **Edit config + `apply`** → destroys *only* what you removed. Surgical; part of normal iteration.
    - **`terraform destroy`** → destroys *everything* in the workspace. Decommissioning.

    Both are gated by the same plan-then-confirm flow. Neither has an undo — the recovery story is re-running `apply` to recreate from config (which, for stateful resources like databases, does **not** bring the data back).

## Interactive lab

Free browser terminal — use the **Skip** button to jump to the third challenge to follow this lesson without a cloud account.

---
Related: closes the loop opened by [[tf-aws-create]] and continued in [[tf-aws-manage]] — same project, now torn down. The `-` and reverse-dependency-order counterpart to [[tf-aws-manage]]'s `+`/`~`/`-/+` and creation order. Demonstrates the destroy half of [[core-workflow]]. Feeds learning-path **B3** (the destroy workflow + `terraform destroy` / `apply -destroy`). Next track lesson moves to HCP Terraform for remote state + runs (path **A4**).
