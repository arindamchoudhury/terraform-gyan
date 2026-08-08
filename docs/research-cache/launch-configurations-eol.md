# Launch configurations — EOL facts

Last verified: **2026-08-08** against the AWS EC2 Auto Scaling user guide and the AWS provider docs on `main`.

## AWS-side limits (hard, not advisory)

Verbatim from [Auto Scaling launch configurations](https://docs.aws.amazon.com/autoscaling/ec2/userguide/launch-configurations.html):

> As of **January 1, 2023**, new Amazon EC2 instance types are no longer supported in launch configurations. This includes support for any instance types added to an AWS Region after the initial Region launch.
>
> Accounts created on or after **June 1, 2023** cannot create new launch configurations using the console.
>
> Accounts created on or after **October 1, 2024** cannot create new launch configurations using **any method (console, API, AWS CLI, or CloudFormation)**.

> Migrate to launch templates to make sure that you don't need to create new launch configurations now or in the future.

> **Note** You might be able to create a launch configuration with an instance type that is no longer supported in a Region. We recommend that you migrate to launch templates.

Also stated on that page: a launch configuration **cannot be modified after creation** — to change one you create a new launch configuration and update the Auto Scaling group.

## Terraform provider side

`aws_launch_configuration` docs on `main` carry a top-level `!>` warning:

> **WARNING:** The use of launch configurations is discouraged in favor of launch templates.

Plus a long-standing note: when pairing `aws_launch_configuration` with `aws_autoscaling_group`, prefer `name_prefix` over `name` so lifecycle changes are detected and the ASG updates correctly.

The resource still exists in the provider — it is discouraged, not removed.

## Why this matters for notes

**The AWS-side cutoff is the load-bearing fact, not the provider warning.** An account created on or after 2024-10-01 **cannot create a launch configuration at all**, so any tutorial or book chapter whose core example uses `aws_launch_configuration` is not merely stale — it is unrunnable for a reader with a recent AWS account.

The replacement is `aws_launch_template` plus an `aws_autoscaling_group` `launch_template` block. Affects *Terraform: Up & Running* 3rd ed. (Manning/O'Reilly, 2022) Chapters 2–5, whose running web-server-cluster example is built on `aws_launch_configuration`. See [[04-reusable-modules]].
