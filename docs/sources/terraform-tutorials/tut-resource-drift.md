# Manage resource drift

> **Source:** [developer.hashicorp.com/terraform/tutorials/state/resource-drift](https://developer.hashicorp.com/terraform/tutorials/state/resource-drift)
> **Added:** 2026-08-20
> **Source updated:** undated tutorial (~12 min); captured 2026-08-20
> **Tags:** drift, refresh-only, terraform-refresh, state, import, security-groups, out-of-band-changes, ec2
> **Type:** documentation

Sixth page of the **State** collection (footer: *Previous — Troubleshooting · Next — Lifecycle rules*), and the hands-on half of [[tf-cmd-refresh]]. Repo: `github.com/hashicorp-education/learn-terraform-drift-management`. Needs **real AWS credentials, the `awscli`, and Terraform ≥ 0.15.4** — unlike [[tut-state-import]], this one costs money and cannot be run against a local emulator, because the drift is manufactured with `aws ec2` calls.

The premise in the page's own words:

> You should not make manual changes to resources controlled by Terraform, because the state file will be out of sync, or "drift," from the real infrastructure. If your state and configuration do not match your infrastructure, Terraform will attempt to reconcile your infrastructure, which may unintentionally destroy or recreate resources.

!!! note "Drift *detection* is a paid HCP feature; drift *reconciliation* is not"
    > Drift detection is available in HCP Terraform Standard Edition.

    Worth separating. The continuous, scheduled scan that tells you drift happened is the paid product. Everything this tutorial does — noticing drift, deciding what to do with it, doing it — is CLI-only and free. What you buy is the *noticing without looking*.

## Setup

Three resources: an EC2 instance, an `aws_key_pair` built from a locally generated SSH key, and a security group opening port 22.

```shell
ssh-keygen -t rsa -C "your_email@example.com" -f ./key   # empty passphrase
aws configure get region                                  # match this in terraform.tfvars
```

```hcl
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("${path.module}/key.pub")
}

resource "aws_instance" "example" {
  ami                    = data.aws_ami.ubuntu.id
  key_name               = aws_key_pair.deployer.key_name
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg_ssh.id]
  user_data              = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y apache2
              sed -i -e 's/80/8080/' /etc/apache2/ports.conf
              echo "Hello World" > /var/www/html/index.html
              systemctl restart apache2
              EOF
  tags = {
    Name          = "terraform-learn-state-ec2"
    drift_example = "v1"
  }
}

resource "aws_security_group" "sg_ssh" {
  name = "sg_ssh"
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  // connectivity to ubuntu mirrors is required to run `apt-get update` and `apt-get install apache2`
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

`terraform apply` → `3 added`, with outputs `instance_id`, `public_ip`, `security_groups`. `terraform state list` shows four entries, the data source included:

```text
data.aws_ami.ubuntu
aws_instance.example
aws_key_pair.deployer
aws_security_group.sg_ssh
```

The same repo and the same `drift_example = "v1"` tag appear in [[tut-resource-lifecycle]], which is the sibling exercise: this tutorial *reconciles* drift, that one *ignores* it with `ignore_changes`.

## Manufacture the drift

Three AWS CLI calls, entirely outside Terraform. Create an untracked security group, open 8080 on it, then swap it onto the instance:

```shell
export SG_ID=$(aws ec2 create-security-group --group-name "sg_web" --description "allow 8080" --output text)
aws ec2 authorize-security-group-ingress --group-name "sg_web" --protocol tcp --port 8080 --cidr 0.0.0.0/0
aws ec2 modify-instance-attribute --instance-id $(terraform output -raw instance_id) --groups $SG_ID
```

PowerShell form of the first line:

```powershell
$env:SG_ID = "$(aws ec2 create-security-group --group-name "sg_web" --description "allow 8080" --output text)"
```

`modify-instance-attribute --groups` **replaces** the list rather than appending to it, which is why one command produces two kinds of drift at once: an untracked object exists, *and* a tracked object's attribute no longer matches state. SSH is now closed.

## `plan -refresh-only`: see the drift without acting on it

The tutorial states the mechanism the same way [[tf-state-purpose]] does — the refresh updates state **in memory** at the start of every plan and apply, so an ordinary plan already sees drift. `-refresh-only` is for inspecting the state update on its own:

> This is safer than the `refresh` subcommand, which automatically overwrites your state file without displaying the updates.

> The `-refresh-only` flag was introduced in Terraform 0.15.4, and is preferred over the `terraform refresh` subcommand.

Identical to [[tf-cmd-refresh]]'s reference-page advice, and this is the run that shows why:

```text
$ terraform plan -refresh-only

Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform since the last "terraform apply":

  # aws_instance.example has been changed
  ~ resource "aws_instance" "example" {
        id                     = "i-008bef01721ee7f7c"
      ~ vpc_security_group_ids = [
          + "sg-0226a51361bf1497a",
          - "sg-0b318a348a4a4e391",
        ]
        # (27 unchanged attributes hidden)
    }

This is a refresh-only plan, so Terraform will not take any actions to undo
these. If you were expecting these changes then you can apply this plan to
record the updated values in the Terraform state without changing any remote
objects.

Changes to Outputs:
  ~ security_groups = [ - [ - "sg-0b318a348a4a4e391" ], + [ + "sg-0226a51361bf1497a" ] ]
```

Two details worth keeping.

**The wording is `has been changed`, not `will be updated`.** A refresh-only plan reports the past tense — what already happened to the object — where a normal plan reports the future tense of what Terraform intends. Reading the verb tense is the fastest way to tell which kind of plan output you are looking at.

**Outputs drift too.** `security_groups` is a computed output over the instance's attribute, so accepting the refresh rewrites the output values in state as well. That is a real consequence for anything reading this state through `terraform_remote_state` ([[tf-remote-state-data]]) — a downstream configuration can consume drift it never asked for.

## `apply -refresh-only`: accept reality into state

```text
$ terraform apply -refresh-only

Would you like to update the Terraform state to reflect these detected changes?
  Terraform will write these changes to the state without modifying any real infrastructure.
  There is no undo. Only 'yes' will be accepted to confirm.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

`0 added, 0 changed, 0 destroyed` while the state file demonstrably changed — the counters count *infrastructure* actions, not state writes. The direction of effect is [[tf-cmd-refresh]]'s rule: reality wins, state is rewritten to match.

> A refresh-only operation does not attempt to modify your infrastructure to match your Terraform configuration — it only gives you the option to review and track the drift in your state file.

And the fork in the road the tutorial names explicitly:

> If you ran `terraform plan` or `terraform apply` without the `-refresh-only` flag now, Terraform would attempt to revert your manual changes.

So there are two legitimate answers to drift, and the tutorial picks the second:

1. **Revert it** — a plain `terraform apply` puts the infrastructure back to what the configuration says. Correct when the manual change was a mistake.
2. **Adopt it** — change the configuration to describe the new reality, and import whatever the manual change created. Correct when the manual change was intentional.

## Adopt: write the configuration, then import

New blocks for the manually-created group and its rule:

```hcl
resource "aws_security_group" "sg_web" {
  name        = "sg_web"
  description = "allow 8080"
}

resource "aws_security_group_rule" "sg_web" {
  type              = "ingress"
  to_port           = "8080"
  from_port         = "8080"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.sg_web.id
}
```

And the instance takes **both** groups, restoring SSH without giving up 8080:

```hcl
- vpc_security_group_ids = [aws_security_group.sg_ssh.id]
+ vpc_security_group_ids = [aws_security_group.sg_ssh.id, aws_security_group.sg_web.id]
```

Then the CLI import, one command per resource:

```shell
terraform import aws_security_group.sg_web $SG_ID
terraform import aws_security_group_rule.sg_web "$SG_ID"_ingress_tcp_8080_8080_0.0.0.0/0
```

That second ID is the best example anywhere in the tutorials of [[tut-state-import]]'s rule that **the `id` is resource-specific and only the provider docs know its shape**. `sg-04c74100cc8b9fc8c_ingress_tcp_8080_8080_0.0.0.0/0` is a five-field composite the provider assembles itself — group, type, protocol, from-port, to-port, CIDR. Nothing about the resource block hints at it.

`terraform state list` now shows six entries, the two imported ones included.

!!! note "The page's own tip: this workflow is the pre-1.5 one"
    > This tutorial uses `terraform import` to bring infrastructure under Terraform management. Terraform 1.5+ supports configuration-driven import, which lets you import multiple resources at once, review the import in your plan-and-apply workflow, and generate configuration for imported resources.

    The tutorial has not been rewritten around the block; it just points at [[tut-state-import]]. Two `import` blocks with the same `id` values would do the same job in one previewable plan, and would work in CI, which the two CLI commands do not. Treat the CLI form here as the mechanism being demonstrated, not the mechanism to use.

!!! warning "State caught up, infrastructure did not"
    > Terraform successfully associated both security groups with the instance in state. However, your instance still only allows port 8080 access because the `modify-instance-attribute` AWS CLI command detached the SSH security group.

    Import writes state; it never touches the object. The instance is still one-group-only until an ordinary apply runs.

## Reconcile

```text
$ terraform apply

  # aws_instance.example will be updated in-place
  ~ resource "aws_instance" "example" {
      ~ vpc_security_group_ids = [
          + "sg-09d0b575577f258d5",
            # (1 unchanged element hidden)
        ]
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

`0 to add` is the payoff. Because the manually-created group was imported first, Terraform recognises it as already-owned; without the import this plan would have created a *second* `sg_web` and left the original orphaned. Verification is direct — SSH in with `ssh ubuntu@$(terraform output -raw public_ip) -i key`, and `curl $(terraform output -raw public_ip):8080` returns `Hello, World`.

`terraform destroy` ends at `5 destroyed` — three from the original apply plus the two imported resources, which is the [[tut-state-import]] warning made concrete: importing hands Terraform the whole lifecycle, destruction included.

## Ageing to be aware of

!!! warning "The transcripts are from AWS provider v3.26.0"
    The `init` output shows `Installing hashicorp/aws v3.26.0`, a 2021 release. Two consequences.

    **The rule resource is no longer the recommended shape.** The AWS provider's own `aws_security_group` page now says the current best practice is one CIDR block per rule using `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule`, and warns that mixing in-line `ingress`/`egress` arguments with separate rule resources "may cause rule conflicts, perpetual differences, and result in rules being overwritten" ([`aws_security_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group); cached: `cache/web/aws-r-security-group.txt`). This configuration uses in-line blocks on `sg_ssh` and a separate `aws_security_group_rule` on `sg_web` — legal, because they are different groups, but it is the older idiom on both sides.

    **The import IDs are provider-version-specific.** A composite ID format is part of a provider's import implementation, so verify the shape against the current provider docs rather than copying the string from this page.

## What it does not cover

- **`-refresh=false`** — the opposite knob, which skips the refresh and promotes state's cached attributes to the source of truth, making all out-of-band drift invisible. See [[tf-state-purpose]].
- **`ignore_changes`** — the third answer to drift, alongside revert and adopt: keep the drift and stop planning against it. That is [[tut-resource-lifecycle]], the very next page in this collection.
- **`terraform refresh` itself** — mentioned only as the thing `-refresh-only` is safer than. The reference page goes further and deprecates it outright, with the misconfigured-credentials failure mode that empties state without a prompt ([[tf-cmd-refresh]]).

---
Related: [[tf-cmd-refresh]] — the reference this is the hands-on for; the deprecation, the `apply -refresh-only -auto-approve` equivalence, and the credentials failure mode. · [[tut-resource-lifecycle]] — the sibling exercise on the same repo and tag; the third answer to drift, `ignore_changes`. · [[tut-state-import]] — the 1.5+ replacement for this page's CLI imports, and the source of the "`id` is resource-specific" rule that the composite rule ID illustrates. · [[tf-state-purpose]] — why the attribute cache exists and what a refresh reconciles. · [[tf-remote-state-data]] — why drifted outputs matter beyond this configuration. The provider's current guidance on rule resources, which this tutorial predates, is cached at `cache/web/aws-r-security-group.txt` and has no note of its own yet.
