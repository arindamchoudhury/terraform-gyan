# Troubleshoot Terraform

> **Source:** [developer.hashicorp.com/terraform/tutorials/state/troubleshooting-workflow](https://developer.hashicorp.com/terraform/tutorials/state/troubleshooting-workflow)
> **Added:** 2026-08-20
> **Source updated:** undated tutorial (~17 min); transcripts dated 2024-07-02; captured 2026-08-20
> **Tags:** troubleshooting, fmt, validate, cycle-error, for_each, splat, TF_LOG_CORE, TF_LOG_PROVIDER, TF_LOG_PATH, bug-reports, debugging
> **Type:** documentation

Fifth page of the **State** collection (footer: *Previous — Target resources · Next — Resource drift*), though only its second half is about state at all. Repo: `github.com/hashicorp-education/learn-terraform-troubleshooting`, a deliberately broken EC2-plus-networking configuration. Needs **Terraform 0.15.2+ and real AWS credentials**, same cost profile as [[tut-resource-drift]].

Two distinct halves. The first is a fix-the-config exercise driven by `fmt` and `validate`. The second is the part with lasting value: **how to tell whose bug it is, and how to file it**.

## The four-layer troubleshooting model

The page's own framing, and the most reusable thing on it. Four error types, ordered by **distance from the user**:

| Layer | What it is | What to do |
|---|---|---|
| **Language** | HCL, the declarative configuration language Terraform core interprets. A syntax error prints line numbers and an explanation. | Read the line number; fix the configuration. |
| **State** | The record of provisioned resources, mapping them to configuration and tracking metadata. *"If state is out of sync, Terraform may destroy or change your existing resources."* | After ruling out configuration errors, *"ensure your configuration is in sync by refreshing, importing, or replacing resources."* |
| **Core** | The application itself — interpreting configuration, managing state, constructing the dependency graph, talking to plugins. *"Errors produced at this level may be a bug."* | File against `hashicorp/terraform`. |
| **Provider** | The plugins handling authentication, API calls, and the mapping of resources to services. | File against the provider's own repository. |

The ordering is the advice. Work outward from yourself: your HCL, then your state, and only then suspect the software. Two of these layers already have their own hands-on pages in this collection — state is [[tut-resource-drift]] (refresh) and [[tut-state-import]] (import), which is exactly the "refreshing, importing, or replacing" the state row names.

## `fmt` is a parser, not just a formatter

The exercise starts by running `terraform fmt` on a configuration nobody has fixed yet:

```text
$ terraform fmt
terraform.tfvars
╷
│ Error: Invalid character
│
│   on main.tf line 52, in resource "aws_instance" "web_app":
│   52:     Name = $var.name-learn
│
│ This character is not used within the language.
╵
╷
│ Error: Invalid expression
│
│   on main.tf line 52, in resource "aws_instance" "web_app":
│   52:     Name = $var.name-learn
│
│ Expected the start of an expression, but found an invalid expression token.
╵
```

Worth reading carefully. `fmt` **reformatted `terraform.tfvars`** (the bare filename on the first line is `fmt`'s report of what it rewrote) and then **failed to parse `main.tf`**. So `fmt` is a cheaper first gate than most people treat it as: it cannot rewrite what it cannot parse, which makes it a syntax check that happens to also tidy.

The fix is ordinary interpolation:

```diff
   tags = {
-     Name = $var.name-learn
+     Name = "${var.name}-learn"
   }
```

`$var.name-learn` fails twice over — `$` outside `${}` is not a language character at all, and even read charitably `-learn` would be subtraction against an undefined symbol.

The page then draws the boundary between the two commands:

> `terraform fmt` only parses your HCL for interpolation errors or malformed resource definitions, which is why you should use `terraform validate` after formatting your configuration to check your configuration in the context of the providers' expectations.

That last clause is the operative one, and it explains the ordering of the whole exercise: `validate` needs the provider schemas, so it needs `terraform init` first.

## Cycle error

```text
$ terraform validate
╷
│ Error: Cycle: aws_security_group.sg_ping, aws_security_group.sg_8080
╵
```

Two security groups each naming the other in their in-line `ingress.security_groups`:

```hcl
resource "aws_security_group" "sg_ping" {
  name = "Allow Ping"
  ingress {
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.sg_8080.id]
  }
}
```

The tutorial's explanation is the practical one: *"AWS cannot create the security groups because their configurations each reference the other group, which would not exist yet."*

The fix is structural rather than a reordering — **move the rules out of the groups**:

```hcl
resource "aws_security_group_rule" "allow_ping" {
  type                     = "ingress"
  from_port                = -1
  to_port                  = -1
  protocol                 = "icmp"
  security_group_id        = aws_security_group.sg_ping.id
  source_security_group_id = aws_security_group.sg_8080.id
}

resource "aws_security_group_rule" "allow_8080" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sg_8080.id
  source_security_group_id = aws_security_group.sg_ping.id
}
```

> This avoids a cycle error because the provider will have AWS create both of the `aws_security_group` resources first, without interdependent rules. It will create the rules next, and attach the rules to the groups last.

The generalizable shape: **a cycle between two objects is often a cycle between two objects' *relationships*, and splitting the relationship into its own node breaks it.** Two nodes that must know about each other become three nodes in a line. The same trick appears wherever a provider offers both an in-line and a standalone form of an association.

!!! note "This is a cycle you can read; most are not"
    `Error: Cycle:` names the cycle's **members**, not the edges that close it — fine for this two-resource case, useless on a real config. `terraform graph -type=plan -draw-cycles` reddens the offending edges, and the `-type=` is mandatory or `-draw-cycles` is silently ignored. See [[tf-cmd-graph]] and [[dependency-graph]]. This tutorial is a ready-made specimen for **E5**'s "diagnose a cycle" exercise, which otherwise asks you to build one yourself.

## `validate` stops at the first error class

> Terraform does not continue validating once it catches an error.

So the exercise is iterative: fix, re-run, get the next batch. The next batch is a `for_each` misuse.

```text
│ Error: Invalid reference
│   39:   for_each               = aws_security_group.*.id
│ A reference to a resource type must be followed by at least one attribute
│ access, specifying the resource name.

│ Error: Invalid "each" attribute
│   42:   vpc_security_group_ids = [each.id]
│ The "each" object does not have an attribute named "id". The supported
│ attributes are each.key and each.value, the current key and value pair of the
│ "for_each" attribute set.
```

Two independent mistakes reported together, and the page notes the second is downstream of the first — with no valid `for_each`, the `each` object has nothing in it.

The reasoning that matters:

> the splat expression (`*`) only interpolates list types, while the `for_each` attribute is reserved for map types. A local value can return a map type.

`aws_security_group.*.id` is also not a legal splat in the first place — the legacy splat form applies to a resource *name* with `count`, not to a resource *type*. Both problems point the same way: `for_each` wants a map (or a set of strings), and the way to get one here is to build it explicitly.

```hcl
locals {
  security_groups = {
    sg_ping = aws_security_group.sg_ping.id,
    sg_8080 = aws_security_group.sg_8080.id,
  }
}
```

```diff
 resource "aws_instance" "web_app" {
-  for_each               = aws_security_group.*.id
+  for_each               = local.security_groups
-  vpc_security_group_ids = [each.id]
+  vpc_security_group_ids = [each.value]
   tags = {
-    Name = "${var.name}-learn"
+    Name = "${var.name}-learn-${each.key}"
   }
 }
```

The tag change is not incidental. Without `each.key` in the name, every instance in the set would carry an identical `Name`, which is the standard `for_each` mistake [[tut-for-each]] covers at length. `each.key` and `each.value` are the *only* two members of the `each` object, which the error message states outright — a useful thing to have quoted, because `each.id`, `each.name` and similar guesses are the common wrong reach.

## Outputs must be indexed once `for_each` is set

```text
│ Error: Missing resource instance key
│   on outputs.tf line 6, in output "instance_id":
│    6:   value       = aws_instance.web_app.id
│
│ Because aws_instance.web_app has "for_each" set, its attributes must be
│ accessed on specific instances.
│
│ For example, to correlate with indices of a referring resource, use:
│     aws_instance.web_app[each.key]
```

Three outputs, three identical errors. The fix is a `for` expression per output:

```diff
 output "instance_id" {
-  value = aws_instance.web_app.id
+  value = [for instance in aws_instance.web_app : instance.id]
 }

 output "instance_public_ip" {
-  value = aws_instance.web_app.public_ip
+  value = [for instance in aws_instance.web_app : instance.public_ip]
 }

 output "instance_name" {
-  value = aws_instance.web_app.tags
+  value = [for instance in aws_instance.web_app : instance.tags.Name]
 }
```

Iterating a `for_each` resource yields its **values**, so `instance` is the object and `instance.tags.Name` reaches into it. Note the third output also narrows from the whole `tags` map to one tag — `for` expressions reshape as well as collect.

Then `terraform validate` → `Success! The configuration is valid.` and `terraform apply` → `Plan: 8 to add`, with `instance_name = ["terraform-learn-sg_8080", "terraform-learn-sg_ping"]`, alphabetical because a map's keys iterate in lexical order.

## Bug reporting: deciding whose bug it is

The half worth keeping. The precondition is stated as a filter, not a formality:

> Once you eliminate the possibility of language misconfiguration, version mismatching, or state discrepancies, consider bringing your issue to the core Terraform team or Terraform provider community as a bug report.

**Step 1 — confirm versions.** `terraform version` prints the CLI, the platform, *and* every provider from the lock file:

```text
$ terraform version
Terraform v1.8.3
on darwin_arm64
+ provider registry.terraform.io/hashicorp/aws v5.56.1
+ provider registry.terraform.io/hashicorp/http v3.4.3

Your version of Terraform is out of date! The latest version
is 1.9.0.
```

The out-of-date line is the Checkpoint service talking, which is disableable with `CHECKPOINT_DISABLE=1` — relevant if you would rather not have the CLI phone home. The page's advice is to check the lock file before filing: *"If your lock file specifies an older version, consider updating your providers and attempting to run your operation again."*

**Step 2 — split the logs.** Terraform 0.15+ separates core from provider logging, and this is precisely what makes the layer diagnosis mechanical:

```shell
export TF_LOG_CORE=TRACE
export TF_LOG_PROVIDER=TRACE
export TF_LOG_PATH=logs.txt
```

`TF_LOG_PATH` **creates the file and appends** to it. TRACE is the level to use for a bug report: *"TRACE provides the highest level of logging and contains all the information the development teams need."*

Then run anything — the tutorial uses `terraform refresh`, which is itself the deprecated command ([[tf-cmd-refresh]]); `terraform plan` would serve the same purpose without the deprecation.

**Step 3 — read the log to find the owner.**

> In your `logs.txt` file, find the final error message and trace it back to the source. It should contain `provider-terraform-<PROVIDER-NAME>` if it is a provider issue.

That prefix is the whole test. A line reading `[DEBUG] provider: plugin process exited: path=.terraform/providers/…/terraform-provider-aws_v5.56.1_x5` is the provider's; a line reading `[TRACE] vertex "root": starting visit (*terraform.nodeCloseModule)` is core's. Then file against `hashicorp/terraform` or the provider's own repository, found through the registry listing.

**Step 4 — file it.** The core repo has a bug-report issue template to follow. The page suggests the [HashiCorp Discuss forum](https://discuss.hashicorp.com/) first if you want community input before opening an issue, and notes that *"some providers may have different suggestions for opening issues."*

**Unsetting.** `export TF_LOG_CORE=` (empty value) turns core logging off while leaving provider logging on. Environment variables clear when the shell session closes.

!!! tip "The log excerpt is a free tour of the state manager"
    The tutorial prints its `logs.txt` tail without commenting on it, and the lines are more informative than the surrounding prose:

    ```text
    [TRACE] statemgr.Filesystem: creating backup snapshot at terraform.tfstate.backup
    [TRACE] statemgr.Filesystem: state has changed since last snapshot, so incrementing serial to 10
    [TRACE] statemgr.Filesystem: writing snapshot at terraform.tfstate
    [TRACE] statemgr.Filesystem: removing lock metadata file .terraform.tfstate.lock.info
    [TRACE] statemgr.Filesystem: unlocking terraform.tfstate using fcntl flock
    ```

    Every claim [[tf-state]] makes about the local backend is visible here: the `.backup` written before the new snapshot, `serial` incremented **only because the state changed**, and the lock taken as an `fcntl` flock with a `.lock.info` metadata file beside it. Also `[TRACE] Plan is not applyable` and `[DEBUG] no planned changes, skipping apply graph check`, which is the refresh-only path short-circuiting.

## Errors in the tutorial itself

!!! warning "Three things in the page do not match its own transcripts"
    - **Line numbers disagree.** The prose says both `fmt` errors "occur on line 46" and later tells you to find the `tags` attribute "on line 46"; the transcript reports **line 52** twice. Go by what your own output says.
    - **`allow_8080` opens port 80, not 8080.** The rule resource sets `from_port = 80` and `to_port = 80` inside a group named `Allow 8080`, while the instance's `user_data` moves Apache to **8080**. Every other part of the exercise is consistent about 8080. Treat the rule as a typo rather than a subtlety.
    - **The corrected `aws_instance` block has an unbalanced brace** — the diff ends with an extra `}` after the resource's closing brace.

!!! warning "The transcripts are from mid-2024"
    `Terraform v1.8.3` with `aws v5.56.1` and log timestamps of `2024-07-02`. Two consequences.

    The AWS provider's own guidance has moved on: `aws_security_group_rule` — the resource this tutorial's central fix introduces — is no longer the recommended shape. The provider now prefers `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` with one CIDR block per rule, and warns that mixing in-line `ingress`/`egress` with separate rule resources "may cause rule conflicts, perpetual differences, and result in rules being overwritten" ([`aws_security_group`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group); cached: `cache/web/aws-r-security-group.txt`). The *cycle-breaking argument* still holds — split the association into its own resource — but the modern resource to split it into has a different name. [[tut-resource-drift]] carries the same flag from a different direction.

    And the cycle error's presentation changes in **Terraform 1.16**, which prints one node per line ordered by reference instead of the single long line shown here.

## What it does not cover

- **`TF_LOG` itself** — the tutorial jumps straight to the split `TF_LOG_CORE` / `TF_LOG_PROVIDER` variables and never mentions the combined one, nor the level ladder below TRACE, nor `crash.log`. That is the [HCDocs debugging page](https://developer.hashicorp.com/terraform/internals/debugging), cited in **E5**.
- **Reading the graph** — cycles are diagnosed by fixing the obvious two-resource case, not with `terraform graph -draw-cycles` ([[tf-cmd-graph]]).
- **The state layer of its own model** — named in the table, then never exercised. The pages that do exercise it are its own neighbours, [[tut-resource-drift]] and [[tut-state-import]].
- **`terraform console`** — the natural tool for the `for_each`/splat type confusion at the centre of this exercise, and used for exactly that in [[tut-variables]].

---
Related: [[tf-cmd-graph]] — the `-draw-cycles` route for cycles too large to read from the error text. · [[dependency-graph]] — the cross-source topic, including why the graph confirms an ordering bug but cannot discover one. · [[tut-for-each]] — `for_each`, `each.key`/`each.value`, and why the per-instance tag matters. · [[tut-resource-drift]] · [[tut-state-import]] — the state layer of this page's model, done properly. · [[tf-cmd-refresh]] — the deprecated command this tutorial casually uses to generate logs. · [[tf-state]] — every claim about the local backend that the log excerpt shows in flight. · [[terraform-env-vars]] — the debugging variables no docs page lists.
