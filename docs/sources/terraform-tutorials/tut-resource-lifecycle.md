# Manage resource lifecycle

> **Source:** [developer.hashicorp.com/terraform/tutorials/state/resource-lifecycle](https://developer.hashicorp.com/terraform/tutorials/state/resource-lifecycle)
> **Added:** 2026-08-03
> **Source updated:** undated tutorial (8 min); captured 2026-08-03
> **Tags:** lifecycle, prevent_destroy, create_before_destroy, ignore_changes, drift, deposed, plan-symbols, state
> **Type:** documentation

Seventh tutorial in the **State** collection (sidebar: between *Resource drift* and *Version state*), and the hands-on companion to [[tf-meta-lifecycle]]. Three exercises, one per rule: `prevent_destroy`, `create_before_destroy`, `ignore_changes`. Repo: `github.com/hashicorp-education/learn-terraform-lifecycle-management`. AWS credentials and the `awscli` required.

Its framing of what `lifecycle` is for is the clearest one-liner in the docs set:

> "Instead of Terraform managing operations in the built-in dependency graph, lifecycle arguments help minimize potential downtime based on your resource needs as well as protect specific resources from changing or impacting infrastructure."

!!! warning "📌 Version note — the tutorial is old"
    Prerequisite is stated as "**Terraform CLI, version 0.14 or later**" and the `init` transcript installs **`hashicorp/aws` v3.26.0** (released January 2021). Current is Terraform 1.15.8 and AWS provider 6.x. Nothing in the three lifecycle rules has changed, but the transcripts do not match what you will see — see the two output-format divergences flagged below.

## The starting configuration

One EC2 instance plus one security group. The instance's `user_data` installs Apache and rewrites its port to 8080; the security group opens 8080 inbound.

```hcl
resource "aws_instance" "example" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg_web.id]

  user_data = <<-EOF
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

resource "aws_security_group" "sg_web" {
  name = "sg_web"

  ingress {
    from_port   = "8080"
    to_port     = "8080"
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

The `vpc_security_group_ids` reference is the only edge between the two, and it matters for the second exercise. The instance **depends on** the security group.

## `prevent_destroy` — what the rejection actually looks like

```hcl
lifecycle {
  prevent_destroy = true
}
```

`terraform destroy` then fails at plan time, after refresh:

```
╷
│ Error: Instance cannot be destroyed
│
│   on main.tf line 31:
│   31: resource "aws_instance" "example" {
│
│ Resource aws_instance.example has lifecycle.prevent_destroy set, but the
│ plan calls for this resource to be destroyed. To avoid this error and
│ continue with the plan, either disable lifecycle.prevent_destroy or reduce
│ the scope of the plan using the -target flag.
```

Two things worth taking from the message. It is an **error, not a prompt** — there is no override flag, only editing the config or narrowing the plan. And Terraform's own suggested escape hatch is **`-target`**, which is the one place the docs endorse a flag they otherwise discourage.

The tutorial restates the caveat [[tf-meta-lifecycle]] explains: enabling `prevent_destroy` "does not prevent Terraform from destroying the resource if you **comment out or remove** the configuration." Commenting out is the phrasing that makes the failure mode concrete — it is the thing you do while debugging, not a deliberate deletion.

Its stated use case is narrower than "protect the database": *"useful in situations where a change to an attribute would force a replacement and create downtime."* Guarding against **replacement**, not against `terraform destroy`.

## `create_before_destroy` — the plan symbol flips

The exercise swaps the whole stack from port 8080 to port 80: the security group's `from_port`/`to_port` change, the instance's `sed` line is dropped from `user_data`, and `prevent_destroy` is replaced by `create_before_destroy = true`.

Changing `user_data` forces replacement of the instance. The plan legend is the artifact worth memorizing:

```
  ~ update in-place
+/- create replacement and then destroy

  # aws_instance.example must be replaced
+/- resource "aws_instance" "example" {

  # aws_security_group.sg_web will be updated in-place
  ~ resource "aws_security_group" "sg_web" {

Plan: 1 to add, 1 to change, 1 to destroy.
```

**`+/-` is the create-before-destroy symbol; the default is `-/+`.** Read the order literally — the symbol is the operation sequence. Confirmed in source at tag **v1.15.8**: `internal/command/jsonformat/plan.go:688` emits `"+/- create replacement and then destroy"`. Nothing else in the plan announces that CBD is active, so the symbol is the check.

Also read the counts: `1 to add, 1 to change, 1 to destroy` for what is a **single** replacement plus one in-place update. A replacement is always two lines in the summary.

The apply order confirms the mechanism end to end:

```
aws_security_group.sg_web: Modifications complete after 22s
aws_instance.example: Creating…
aws_instance.example: Creation complete after 1m14s [id=i-0b2fd8a0df19c215d]
aws_instance.example (940b3833): Destroying... [id=i-099bb19ca402a6761]
aws_instance.example: Destruction complete after 41s
```

New instance up before the old one goes down. The security group is modified first, because the instance depends on it.

!!! note "The parenthesized hex is the deposed key — and the modern output names it"
    `aws_instance.example (940b3833)` is not an instance index. During a create-before-destroy replacement the old object is **deposed**: moved aside in state under a generated key so both objects can exist at once, then destroyed. The key is how Terraform addresses it.

    Current Terraform prints this differently. `internal/command/views/hook_ui.go` (three call sites, read at tag **v1.15.8**) formats it as:

    ```go
    dispAddr = fmt.Sprintf("%s (deposed object %s)", dispAddr, dk)
    ```

    So on any current version the line reads `aws_instance.example (deposed object 940b3833): Destroying...`. The tutorial's bare-parenthesis form is from the older CLI it was written against. If a deposed object survives a failed apply it stays in state and the next plan will destroy it, which is the main operational cost of CBD. The tutorial never mentions it. **It will not appear in `terraform state list`** — that command prints one address per resource instance, taken from the *current* object only (`internal/command/state_list.go`, tag v1.15.8), so a deposed object gets no line. Use `terraform show -json` and look for `deposed_key`. See [[tf-state]], [[tf-cmd-state-list]].

!!! warning "CBD propagated to the security group here, invisibly"
    [[tf-meta-lifecycle]] records that `create_before_destroy` propagates along dependency edges: `aws_instance.example` depends on `aws_security_group.sg_web`, so Terraform enables CBD on the security group too and writes it to state — even though the tutorial never puts a `lifecycle` block there.

    It has no visible effect in this run because the security group is only **updated in-place**, and CBD changes nothing about an in-place update. Had the port change forced the security group to be replaced instead, `sg_web` would have been replaced create-first, with the name collision that implies (both objects want `name = "sg_web"`, and AWS security group names are unique per VPC). The tutorial's example is safe by accident of the AWS provider supporting in-place ingress updates.

!!! note "One typo in the tutorial's diff"
    The `create_before_destroy` step's code block silently renames the tag `drift_example` → **`Drift_example`**, and the next section goes back to `drift_example`. Nothing else in the tutorial mentions it and the transcripts use the lowercase form throughout. Use `drift_example`.

## `ignore_changes` — drift the tag, then keep the drift

The best part of the tutorial, because it creates real drift out of band rather than describing it.

```bash
aws ec2 create-tags --resources $(terraform output -raw instance_id) --tags Key=drift_example,Value=v2
```

Then:

```hcl
lifecycle {
  create_before_destroy = true
  ignore_changes        = [tags]
}
```

`terraform apply` reports **`0 added, 0 changed, 0 destroyed`**, and `terraform state show aws_instance.example` shows `"drift_example" = "v2"`.

Two things this demonstrates that prose cannot.

- **State is refreshed to the real value, not frozen at the configured one.** The tutorial says it plainly: the apply "will refresh your state file with **v2** instead of overwriting your tag with **v1** as written in your configuration." `ignore_changes` suppresses the *plan to update*, not the *read*. Config keeps saying `v1`, state and reality say `v2`, and Terraform is content.
- **This is the update half of the rule in [[tf-meta-lifecycle]]** — arguments are considered when planning a create, ignored when planning an update. Had the instance been replaced after this point, it would have come back with `v1`, because create still honors the configured value.

`aws ec2 create-tags` is also reusable beyond this exercise: it is the cheapest way to manufacture drift on an instance without leaving the terminal, which makes it the right setup step for any refresh or drift experiment. See [[tf-cmd-refresh]].

## What the tutorial does not cover

`replace_triggered_by`, `precondition`/`postcondition`, and `action_trigger` are absent — the exercise predates all three. Its "Next steps" points to the Drift Management tutorial, the Import tutorial, and the [[tf-meta-lifecycle]] reference.

---
Related: [[tf-meta-lifecycle]] — the reference this is the hands-on for; the state semantics and CBD propagation that explain what the transcripts show. · [[meta-arguments-lifecycle]] — the cross-source topic page. · [[tf-cmd-state-show]] — the command that proves the ignored drift landed in state. · [[tf-cmd-refresh]] — the refresh half of the same drift story. · [[tf-state]] — deposed objects live there until destroyed. · [[tut-dependencies]] — the implicit dependency (`vpc_security_group_ids`) that orders this tutorial's apply.
