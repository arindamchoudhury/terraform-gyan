# Create resource dependencies

> **Source:** [developer.hashicorp.com/terraform/tutorials/configuration-language/dependencies](https://developer.hashicorp.com/terraform/tutorials/configuration-language/dependencies)
> **Added:** 2026-08-01
> **Source updated:** undated tutorial (10 min); captured 2026-08-01 (both HCP Terraform and Community Edition variants)
> **Tags:** dependencies, depends_on, implicit-dependencies, explicit-dependencies, dag, destroy-order, modules, aws_eip
> **Type:** documentation

Sixth **Configuration Language** tutorial in the sidebar (between *Data sources* and *Count*), and the hands-on companion to [[tf-meta-depends-on]]. The concepts are already captured in [[dependency-graph]]. What this tutorial adds is **observable evidence**: apply and destroy logs where you can read the ordering and the parallelism off the timestamps. It also puts `depends_on` on a `module` block, which the reference page mentions but never demonstrates.

Terraform v1.2+, AWS credentials. Repo: `github.com/hashicorp-education/learn-terraform-dependencies`.

!!! warning "The example config is pinned to AWS provider ~> 4.17.1 and will not apply on v6+"
    `main.tf` writes the Elastic IP as `vpc = true`. That argument was **removed in AWS provider v6.0.0** — the upgrade guide says "Remove `vpc`—it is no longer supported. Use `domain` instead." The current resource docs document only `domain`, whose value is the string `"vpc"`.

    Verified 2026-08-01 against the provider's own `version-6-upgrade.html.markdown` and `r/eip.html.markdown`; cached at `cache/search/aws-eip-vpc-argument-removed.md`.

    ```hcl
    resource "aws_eip" "ip" {
      domain   = "vpc"
      instance = aws_instance.example_a.id
    }
    ```

    The tutorial's `terraform.tf` pins `version = "~> 4.17.1"`, so following it verbatim still works. The trap is copying the `aws_eip` block into a config with an unpinned provider.

## Manage implicit dependencies

Starting config: one AMI data source, two EC2 instances, one Elastic IP attached to the first instance.

```hcl
provider "aws" {
  region = var.aws_region
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "example_a" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
}

resource "aws_instance" "example_b" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
}

resource "aws_eip" "ip" {
  vpc      = true
  instance = aws_instance.example_a.id
}
```

`aws_eip.ip` references `aws_instance.example_a.id`. That reference **is** the edge. Nothing else in the config orders anything, so `example_b` is free to run in parallel with everything else.

**The apply log is the proof.** Both instances start at the same moment and the Elastic IP waits:

```
aws_instance.example_a: Creating...
aws_instance.example_b: Creating...
aws_instance.example_b: Still creating... [10s elapsed]
aws_instance.example_a: Still creating... [10s elapsed]
...
aws_instance.example_b: Creation complete after 32s [id=i-0d485fc8d11d27c87]
aws_instance.example_a: Creation complete after 33s [id=i-07c07aebe269be8a5]
aws_eip.ip: Creating...
aws_eip.ip: Creation complete after 1s [id=eipalloc-0ef86dc6fbb50ccf8]
```

Note what the log does **not** show: `aws_eip.ip` did not wait for `example_b`. Terraform serializes only along real edges. This is the concrete version of the claim in [[dependency-graph]] that over-using `depends_on` "serializes work the graph could have run in parallel" — here you can watch the parallel work happen.

The tutorial's own wording for how the edge is found: Terraform "infers when one resource depends on another by studying the resource attributes used in interpolation expressions."

## Manage explicit dependencies

The scenario is the standard hidden dependency. Software on the instance expects a specific S3 bucket. The bucket name lives in the application's own config, so nothing in the Terraform configuration references it.

```hcl
resource "aws_s3_bucket" "example" { }

resource "aws_instance" "example_c" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"

  depends_on = [aws_s3_bucket.example]
}

module "example_sqs_queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "3.3.0"

  depends_on = [aws_s3_bucket.example, aws_instance.example_c]
}
```

Two things here go beyond the reference page.

**`depends_on` on a `module` block.** [[tf-meta-depends-on]] says a module-level `depends_on` orders *every* resource and data source in that module, and warns that module-level use is where spurious `(known after apply)` is most likely. This is that argument in a real block. The module ships its own nested `data` source, and the apply log shows it read only after the whole module's dependencies were satisfied.

**A list with more than one entry.** "You can also specify multiple resources in the `depends_on` argument, and Terraform will wait until all of them have been created before creating the target resource."

Modules must be installed before apply:

```shell
terraform get
```

```
Downloading registry.terraform.io/terraform-aws-modules/sqs/aws 3.3.0 for example_sqs_queue...
- example_sqs_queue in .terraform/modules/example_sqs_queue
```

Apply log — the bucket completes first, then both dependents proceed:

```
aws_s3_bucket.example: Creating...
aws_s3_bucket.example: Creation complete after 2s [id=terraform-20220608191906096600000001]
aws_instance.example_c: Creating...
aws_instance.example_c: Still creating... [10s elapsed]
...
aws_instance.example_c: Creation complete after 42s [id=i-0fcf06245633ab00e]
module.example_sqs_queue.aws_sqs_queue.this[0]: Creating...
...
module.example_sqs_queue.aws_sqs_queue.this[0]: Creation complete after 26s
module.example_sqs_queue.data.aws_arn.this[0]: Reading...
module.example_sqs_queue.data.aws_arn.this[0]: Read complete after 0s
```

The module also waits on `aws_instance.example_c`, so the SQS queue starts only after the instance finishes — 42 seconds of serialized time bought by one line.

!!! tip "Two tips the tutorial states outright"
    - **Declaration order is irrelevant.** "The order in which resources are declared in your configuration files has no effect on the order in which Terraform creates or destroys them." Confirms TID Ch2 §2.2.5 as recorded in [[dependency-graph]].
    - **Explicit dependencies cost wall-clock time.** "Since Terraform will wait to create the dependent resource until after the specified resource is created, adding explicit dependencies can increase the length of time it takes for Terraform to create your infrastructure."

    The second tip is a *different* cost from the one [[tf-meta-depends-on]] emphasizes. The reference page warns about **plan quality** (spurious `known after apply`, spurious replacements). This tutorial warns about **apply duration**. Both are real; only the plan-quality one is usually quoted.

## Destroy resources

"Both implicit and explicit dependencies affect the order in which resources are destroyed as well as created." Teardown walks the same graph in reverse — dependents die first.

```
aws_eip.ip: Destroying... [id=eipalloc-0ef86dc6fbb50ccf8]
module.example_sqs_queue.aws_sqs_queue.this[0]: Destroying...
aws_instance.example_b: Destroying... [id=i-0d485fc8d11d27c87]
aws_eip.ip: Destruction complete after 1s
aws_instance.example_a: Destroying... [id=i-07c07aebe269be8a5]
module.example_sqs_queue.aws_sqs_queue.this[0]: Destruction complete after 2s
aws_instance.example_c: Destroying... [id=i-0fcf06245633ab00e]
...
aws_instance.example_b: Destruction complete after 30s
aws_instance.example_a: Destruction complete after 30s
aws_instance.example_c: Destruction complete after 30s
aws_s3_bucket.example: Destroying... [id=terraform-20220608191906096600000001]
aws_s3_bucket.example: Destruction complete after 1s
```

Read it against the creation order and it is an exact mirror. The Elastic IP goes before `example_a`. The SQS queue and `example_c` go before the S3 bucket they depend on. `example_b`, which depends on nothing, starts immediately.

This is the practical reason a missing `depends_on` "bites again" on teardown, as [[dependency-graph]] puts it: destroy ordering is derived from the same edges, so an edge that was never declared is absent in both directions.

## Next steps

The tutorial points at three follow-ons: the [`depends_on` docs](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on) ([[tf-meta-depends-on]]), [how Terraform uses the dependency graph](https://developer.hashicorp.com/terraform/internals/graph), and provisioning infrastructure created with Terraform.

The graph-internals page is not captured yet.

---
Related: [[tf-meta-depends-on]] — the reference page this is the lab for; carries the "last resort" plan-degradation cost that this tutorial does not mention. · [[dependency-graph]] — the cross-source synthesis, including how to *see* the edges and why a missing one is invisible; this note supplies its observable evidence. · [[tf-meta-arguments]] — `depends_on` among the other five meta-arguments. · [[tut-data-sources]] — the previous tutorial in the collection, source of the `aws_ami` data-source pattern reused here. · [[tf-configure-resource]] — "prefer implicit dependencies," stated without either cost.
