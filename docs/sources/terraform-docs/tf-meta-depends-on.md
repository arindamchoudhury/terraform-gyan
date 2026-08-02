# `depends_on` reference

> **Source:** [developer.hashicorp.com/terraform/language/meta-arguments/depends_on](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on)
> **Added:** 2026-07-10
> **Source updated:** undated language reference; captured 2026-07-10 against v1.15.x (latest)
> **Tags:** meta-arguments, depends_on, hidden-dependencies, dag, known-after-apply, check-blocks
> **Type:** documentation

*Developer › Terraform › Configuration Language › Reference › Meta-arguments › depends_on · v1.15.x*

The per-argument reference behind [[tf-meta-arguments]]. Captured for three things the index page doesn't say: the "last resort" cost, the real block-support list, and why the value can't be an expression.

## What it's for

> "Use the `depends_on` meta-argument to handle **hidden** resource or module dependencies that Terraform **cannot automatically infer**."

You need it only when a resource or module "relies on another resource's **behavior** but does not access any of that resource's **data** in its arguments." Behavior versus data is the whole distinction. If you read an attribute, the edge already exists.

!!! warning "Terraform will never tell you a `depends_on` is missing"
    "Hidden" and "cannot infer" are the operative words. The dependency graph is built from expression references plus the `depends_on` you wrote; a dependency it cannot see does not exist to it, so there is nothing to warn about.

    Verified locally (Terraform v1.15.6): removing a `depends_on` silently drops the edge from `terraform graph`, and `terraform validate` still reports `Success! The configuration is valid.` The failure surfaces at apply, often nondeterministically, because Terraform parallelizes nodes it believes are independent. See [[dependency-graph]].

## Processing and planning consequences

`depends_on` instructs Terraform to complete **all actions on the dependency object, including read operations**, before performing operations on the object declaring the dependency. When the dependency is a whole module, it orders **every** resource and data source in that module.

!!! danger "Use it as a last resort — it degrades the plan"
    The docs are blunter than most summaries of them:

    > "You should only use `depends_on` as a **last resort** because it can cause Terraform to create more **conservative plans that replace more resources than necessary**. For example, Terraform may treat more values as unknown `(known after apply)` because it is uncertain what changes will occur on the upstream object. This is especially likely when you use `depends_on` for **modules**."

    Prefer expression references. A reference tells Terraform *which value* the dependency derives from, so it can skip planning changes when that particular value hasn't changed — even if other parts of the upstream object have planned changes. `depends_on` throws that precision away and makes the whole upstream object opaque.

    This is a stronger claim than "prefer implicit dependencies for tidiness." The cost is measurable: spurious `(known after apply)` and spurious replacements.

## Why the value can't be an expression

> "This list cannot include arbitrary expressions because the `depends_on` value must be **known before Terraform knows resource relationships** and thus **before it can safely evaluate expressions**."

It takes a list of references to resources or child modules in the same calling module — nothing else. This is the "meta-arguments are processed early" rule from TID Ch2 §2.7, stated with the actual reason: the graph has to exist before expressions can be evaluated, and `depends_on` is an input to building the graph.

## Supported blocks

The [[tf-meta-arguments]] index page names only `resource`. The real list is wider:

| Config | `depends_on` allowed in |
|---|---|
| Terraform | `check`, `data`, `ephemeral`, `module`, `output`, `resource` |
| Stacks | `component` |

The index page's block table is incomplete for `depends_on` exactly as it is for `count`. Trust the per-argument references — but not blindly, per the correction below.

!!! danger "🔄 This page's list is wrong about `check` (verified 2026-08-02)"
    A `check` block does **not** accept `depends_on`. On Terraform **1.15.8**, `terraform validate` rejects it:

    ```
    Error: Unsupported argument
    An argument named "depends_on" is not expected here.
    ```

    It cannot work by construction. `checkBlockSchema` in `internal/configs/checks.go`, read at tag **v1.15.8**, declares no attributes at all — only the nested `data` and `assert` block types:

    ```go
    var checkBlockSchema = &hcl.BodySchema{
    	Blocks: []hcl.BlockHeaderSchema{
    		{Type: "data", LabelNames: []string{"type", "name"}},
    		{Type: "assert"},
    	},
    }
    ```

    What the page must mean is `depends_on` on the **`data` block nested inside** a check, which does validate and is the pattern this note's own check-block section describes. The other five Terraform rows were re-verified and all hold: `data`, `ephemeral`, `module`, `output`, `resource`.

    So the standing rule "trust the per-argument reference over the index" holds only for *omissions*. This is the first case found where a reference page names a block that does not work. Full measured matrix in Book Ch 10 §8.

## The canonical example

The docs' own example is subtler than the usual NAT-gateway one, because the *implicit* dependency is present and still insufficient:

```hcl
resource "aws_instance" "example" {
  ami           = "ami-a1b2c3d4"
  instance_type = "t2.micro"

  # Terraform can infer from this that the instance profile must
  # be created before the EC2 instance.
  iam_instance_profile = aws_iam_instance_profile.example

  # However, if software running in this EC2 instance needs access
  # to the S3 API in order to boot properly, there is also a
  # dependency on the aws_iam_role_policy that Terraform cannot
  # automatically infer, so you must declare it explicitly:
  depends_on = [
    aws_iam_role_policy.example
  ]
}
```

The instance profile edge exists. The *policy attached to the role* edge does not, because nothing references it. Terraform reports a successful apply and the box boots without S3 access. A silent, semantic failure — not a crash.

## `depends_on` inside a `check` block

A use case the learning path doesn't cover. `check` blocks validate infrastructure outside the normal resource lifecycle, and a `data` block nested in one runs before the infrastructure exists — so the check fails on the first apply.

Adding `depends_on` to the nested `data` block defers it. Terraform prints `known after apply` instead of emitting a false warning:

```hcl
check "database_connection" {
  data "postgresql_database" "app_db" {
    name       = "application"
    depends_on = [aws_db_instance.main]
  }

  assert {
    condition     = data.postgresql_database.app_db.allow_connections
    error_message = "Database is not accepting connections"
  }
}
```

!!! note "Only works when the data block doesn't reference the resource"
    If the nested `data` block references `aws_db_instance.main` directly, then **any** change to that resource makes the check warn `known after apply` — "making your check potentially noisy and ineffective." The `depends_on` form gives you ordering without the value-level coupling.

---
Related: [[tf-meta-arguments]] — the index this details, whose block table for `depends_on` is incomplete. · [[dependency-graph]] — how to actually see the edges Terraform built, and why a missing one is invisible. · [[tf-configure-resource]] — "prefer implicit dependencies," stated without the plan-degradation reason. · [[tf-cmd-graph]] — the command that renders the graph.
