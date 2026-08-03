# `lifecycle` reference

> **Source:** [developer.hashicorp.com/terraform/language/meta-arguments/lifecycle](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
> **Added:** 2026-08-03
> **Source updated:** undated language reference; captured 2026-08-03 against v1.15.x (latest)
> **Tags:** meta-arguments, lifecycle, create_before_destroy, prevent_destroy, ignore_changes, replace_triggered_by, precondition, postcondition, action_trigger, state
> **Type:** documentation

*Developer › Terraform › Configuration Language › Reference › Meta-arguments › lifecycle · v1.15.x*

The per-argument reference behind [[tf-meta-arguments]], and the primary reference for learning-path **I2**. [[meta-arguments-lifecycle]] already holds the rule-by-rule survey from TID Ch2 and [[tf-block-resource]]. This note captures what only this page says: the **state** semantics, the **propagation** of `create_before_destroy` through dependencies, the exact ignore/trigger evaluation rules, and the ordering guarantees for `precondition`/`postcondition`.

## The five apply operations the block customizes

The page opens by naming what a lifecycle rule modifies. Terraform on apply:

- creates resources in configuration with no state-associated object;
- destroys resources in state but not in configuration;
- updates in-place resources whose arguments changed;
- destroys and re-creates resources whose arguments changed but that it cannot update in-place "because of remote API limitations";
- invokes actions configured to run during an apply.

The fifth item is new with the 1.14 actions work and is why `action_trigger` lives here at all.

## State — the rule that changes everything about `prevent_destroy`

This section has no counterpart in TID or in any note captured so far.

> "Except for `create_before_destroy`, Terraform does not explicitly record a resource's lifecycle rule to state."

Two consequences the page draws out.

- Removing a resource's configuration destroys the real object **even if `prevent_destroy` was enabled** — the guard lived only in the config you just deleted. This is the third of TID's three reasons to avoid `prevent_destroy`, now with the mechanism attached. Use a `removed` block with `destroy = false` instead ([[tf-block-removed]], [[tf-state-remove]]).
- Terraform records the **results** of `precondition` and `postcondition` checks to state, "but not the contents of the checks."

!!! note "Why `create_before_destroy` is the exception — confirmed in the source"
    `states.ResourceInstanceObject` carries a `CreateBeforeDestroy bool` field, serialized to state v4 as `create_before_destroy` (`internal/states/statefile/version4.go:719`, read at tag **v1.15.8**). The comment at `internal/states/instance_object.go:52` gives the reason:

    ```go
    // CreateBeforeDestroy reflects the status of the lifecycle
    // create_before_destroy option when this instance was last updated.
    // Because create_before_destroy also effects the overall ordering of the
    // destroy operations, we need to record the status to ensure a resource
    // removed from the config will still be destroyed in the same manner.
    ```

    So the exception exists for exactly the case that breaks `prevent_destroy`: a resource whose configuration is gone still has to be destroyed in the right order, and the config is no longer there to say which order that is.

## Usage — one sentence covering all rules

> "All lifecycle settings affect how Terraform constructs and traverses the dependency graph. As a result, only literal values can be used because the processing happens too early for arbitrary expression evaluation."

Same rule already recorded in [[tf-block-resource]] and [[meta-arguments-lifecycle]]. Worth noting it is stated here as covering **all** settings, not just the boolean ones.

!!! note "Measured: “literal” means “no references”, not “no expressions” (2026-08-03)"
    The boundary is narrower and wider than the word suggests. Run through `terraform validate` on **1.15.8**, with `prevent_destroy`:

    | Value | Result |
    |---|---|
    | `true` · `true && true` · `!false` | valid |
    | `local.protect` · `var.protect` · `terraform.workspace == "default"` | `Error: Variables not allowed` |
    | `alltrue([true])` | `Error: Function calls not allowed` |

    Operators over constants are accepted. **Every reference is rejected, including `local`**, which is a compile-time constant by any ordinary definition. The expression is evaluated with no scope and no function table at all, which is what "before it evaluates arbitrary expressions" amounts to in practice. Book Ch 11 §1.

## `create_before_destroy` propagates to dependencies

The one genuinely surprising behavior on the page, and it is not in TID.

- CBD is enabled on resource A but not on resource B.
- A depends on B, so Terraform **enables CBD on B implicitly and stores it to state**.
- You therefore **cannot override CBD to `false` on B**, "because that would imply dependency cycles in the graph."

!!! danger "Measured: the override is not rejected, it is silently ignored (2026-08-03)"
    "Cannot override" reads like an error. It is not. On **Terraform 1.15.8**, writing `lifecycle { create_before_destroy = false }` on the dependency plans and applies with **no error and no warning** — Terraform simply forces the flag back on. `TF_LOG=trace` is the only place it says so:

    ```
    ForcedCBDTransformer: "aws_s3_bucket.config (expand)" has CBD descendant "aws_s3_bucket.app (expand)"
    ForcedCBDTransformer: forcing create_before_destroy on for "aws_s3_bucket.config (expand)"
    ```

    **OpenTofu 1.12.4** behaves identically, same transformer name in its own package. Measured in Book Ch 11's lab (`labs/chapter11/lab2`).

    Propagation is also **transitive**, not one hop. A three-bucket chain where only the last declares the rule ends with `create_before_destroy = true` in state for all three, including the one two edges away. Measured on 1.15.8.

!!! note "The forcing pass, in the source"
    `ForcedCBDTransformer` (`internal/terraform/transform_destroy_cbd.go`, tag **v1.15.8**) walks every CBD-able vertex; if a non-CBD node has a CBD descendant it upgrades that node. Its own comment states the reason the docs compress into one clause:

    ```go
    // If this isn't naturally a CBD node, this means that an descendant is
    // and we need to auto-upgrade this node to CBD. We do this because
    // a CBD node depending on non-CBD will result in cycles.
    ```

    It runs "in the plan graph builder to ensure that `create_before_destroy` settings are properly propagated **before** constructing the planned changes." So the propagation is a plan-time graph rewrite, not an apply-time decision — which is why it is visible in the plan and recorded in state.

    Practical read: turning CBD on for one resource silently changes the replacement strategy of everything upstream of it. Since CBD is opt-in precisely because objects with unique names cannot coexist, the propagation can push a resource into a mode it cannot support. That failure surfaces at apply, from a resource you never edited.

**CBD and destroy-time provisioners.** Setting `create_before_destroy = true` "also prevents the provisioner from running" when the resource contains a provisioner that runs during destroy. Relevant to [[tf-block-removed]], which is where destroy-time provisioners go once the block is gone.

Why it stays opt-in: many remote object types have unique-name or other constraints that make old and new coexisting impossible. Some resource types offer a random-suffix option to dodge collisions, but "Terraform CLI cannot automatically activate such features," so the constraint check is yours.

## `prevent_destroy` — the argument must be present

Two precise statements beyond the familiar summary:

- "The argument must be present in the configuration" — an absent `prevent_destroy` is not the same as `false` in the docs' framing, because there is nothing in state to fall back on (see the State section above).
- It "rejects plans that would destroy the infrastructure object … and returns an error." Rejection is at plan, not apply.

The page's own caution matches TID's: enabling it "makes certain configuration changes impossible to apply and prevents the `terraform destroy` command from operating once such objects are created. Use `prevent_destroy` sparingly."

## `ignore_changes` — create vs update, and what it cannot address

The evaluation rule, stated exactly:

> "Terraform considers the arguments corresponding to the given attribute names when planning a **create** operation, but are ignored when planning an **update** operation."

So an ignored attribute still takes effect on first creation. It stops mattering only from the second plan onward. That is the behavior that makes the AMI-lookup case work: the instance is built from the looked-up AMI, and later AMI changes stop proposing replacement.

**Addressing.** The entries are "the relative address of the attributes in the resource," and index notation is allowed: `tags["Name"]`, `list[0]`. A single map key can be ignored while the rest of the map stays managed.

**Scope limit.** "Terraform only ignores attributes defined by the resource type. You can't apply `ignore_changes` to itself or to any other meta-arguments." So there is no ignoring `count`, `for_each`, `provider`, or the `lifecycle` block itself.

**`all`.** The bare keyword (not a list) means Terraform "can create and destroy the remote object but will never propose updates to it."

The framing for *why* you would use it is broader than the usual drift story: the page leads with "a resource is created with references to data that may change in the future, but should not affect the resource after its creation," and only then covers shared management with an out-of-band process.

## `replace_triggered_by` — the three trigger conditions

The reference page enumerates what counts as a change, which no other captured source does:

| Reference is to | Replacement triggers when |
|---|---|
| a resource with multiple instances | a plan to update **or replace any instance** |
| a single resource instance | a plan to update or replace **that** instance |
| a single attribute of an instance | **any change to the attribute value** |

Note the asymmetry. A resource-level or instance-level reference triggers on a *planned action*; an attribute-level reference triggers on a *value change*. That is the same distinction that explains why plain values are rejected — locals and input variables "do not have planned actions of their own." The documented workaround is `terraform_data` ([[tf-terraform-data]]).

**Inside `count` / `for_each`.** You may use `count.index` or `each.key` in the expression "to reference specific instances of other resources that are configured with the same `count` or collection" — a per-instance pairing, not a whole-resource trigger.

The page also states the reason the restriction is deliberate: allowing only managed-resource addresses "lets you modify these expressions without forcing replacement."

## `precondition` and `postcondition` — the ordering guarantees

Both take a required `condition` and `error_message`. The scheduling detail is what matters, and it differs between the two.

**`precondition`**

- Evaluated **before** the resource's own configuration arguments, and "can take precedence over argument evaluation errors." A precondition failure can therefore be the message you see instead of a confusing argument error.
- Evaluated **after** `count` and `for_each`. So it runs per instance, and `each.key` / `count.index` are available inside the condition.
- The condition "can refer to any other object in the same configuration scope unless the reference creates a cyclic dependency."

**`postcondition`**

- Evaluated "after planning and applying changes to the data source."
- "Postcondition failures prevent changes to other resources that depend on the failing resource" — a failed postcondition is a barrier in the graph, not just a report.

**Both.** A resource may hold a `precondition` and a `postcondition` together. But: *"Do not add `precondition` blocks to a `resource` block and a `data` block that represent the same object in the same configuration. Doing so may cause Terraform to ignore changes to the `data` block that result from changes in the `resource` block."* The same warning is repeated verbatim for `postcondition`.

**Supported blocks:** `data`, `ephemeral`, `resource` — for both rules.

## `action_trigger` — the argument table

`action_trigger` "directs Terraform to automatically invoke actions based on the conditions you specify."

| Argument | Meaning | Type | Required |
|---|---|---|---|
| `events` | lifecycle events that invoke the action | list | required |
| `condition` | expression that must evaluate to `true` to invoke the action | expression | optional |
| `actions` | **ordered** list of actions to trigger when `events` and `condition` are met | list | required |

`events` accepts `before_create`, `after_create`, `before_update`, `after_update`. Confirms the four-event list in [[meta-arguments-lifecycle]]: no destroy event exists.

Two details this page adds. `actions` is explicitly **ordered**, so multiple actions on one event run in list order. And `condition` gates the invocation, which is the only place an expression appears anywhere in a `lifecycle` block — a per-event runtime gate, distinct from the literal-only graph inputs.

Usable in `resource` blocks.

## `destroy`

> "Set to `false` to remove a resource from state without destroying the actual infrastructure resource. You can only use this rule in `removed` block."

Confirms [[tf-block-removed]] from the `lifecycle` side, and marks the boundary against OpenTofu, where `destroy = false` is legal on the **resource's own** `lifecycle` ([[ot-dynamic-prevent-destroy]]).

## "Supported constructs" is an empty section

The page has a **Supported constructs** heading whose entire body is:

> "Support for each `lifecycle` rule varies across Terraform configuration blocks. Refer to the reference documentation for the Terraform block you are adding to your configuration for details."

Verified twice (Playwright capture and a targeted re-fetch, 2026-08-03): there is **no table or matrix** under it. The same sentence already appears in the page's intro and again in Usage — three times in one page, with no list anywhere.

!!! warning "So `lifecycle` has no applicability list at all — not even a wrong one"
    Every other meta-argument reference at least attempts a **Supported constructs** list, and this project has logged those lists under-reporting ([[tf-meta-count]] omitting `action`) and over-reporting ([[tf-meta-depends-on]] claiming `check`). `lifecycle` skips the attempt.

    The per-rule "You can use X in …" lines scattered through the page are the only applicability data. Reassembled:

    | Rule | Blocks the page names |
    |---|---|
    | `action_trigger`, `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by` | `resource` |
    | `precondition`, `postcondition` | `data`, `ephemeral`, `resource` |
    | `destroy` | `removed` |

    This one holds up against what has already been captured. [[tf-block-data]] independently records that a `data` block's `lifecycle` supports "only `precondition` and `postcondition`" — the same split, reached from the block side — and the page's own ephemeral example exercises the `ephemeral` row. Scattered, but not wrong.

    Standing conclusion from Book Ch 10 §8 still applies to anything outside those rows: write the two lines and run `terraform validate`.

## Examples worth keeping

The `ignore_changes` and `replace_triggered_by` examples duplicate ground held elsewhere. Three do not.

**Precondition on a data source, postcondition on the resource that uses it.** The precondition validates the AMI's architecture before the instance is planned; the postcondition validates the applied instance via `self`.

```hcl
resource "aws_instance" "example" {
  instance_type = "t3.micro"
  ami           = data.aws_ami.example.id

  lifecycle {
    precondition {
      condition     = data.aws_ami.example.architecture == "x86_64"
      error_message = "The selected AMI must be for the x86_64 architecture."
    }

    postcondition {
      condition     = self.public_dns != ""
      error_message = "EC2 instance must be in a VPC that has public DNS hostnames enabled."
    }
  }
}
```

**A `postcondition` on a `data` block that reads a managed resource.** Here the check lives in the *data source*, which reads the volume attached to `aws_instance.example`:

```hcl
data "aws_ebs_volume" "example" {
  filter {
    name   = "volume-id"
    values = [aws_instance.example.root_block_device[0].volume_id]
  }

  lifecycle {
    # The EC2 instance will have an encrypted root volume.
    postcondition {
      condition     = self.encrypted
      error_message = "The server's root volume is not encrypted."
    }
  }
}
```

The failure output shows Terraform reporting the evaluated sub-expression, not just the message:

```
│ Error: Resource postcondition failed
│
│   on main.tf line 31, in data "aws_ebs_volume" "example":
│   31:       condition     = self.encrypted
│     ├────────────────
│     │ self.encrypted is false
│
│ The server's root volume is not encrypted.
```

!!! warning "The prose above this example contradicts the example"
    The page says: *"When a data resource verifies the result of a managed resource declared in the same configuration, you must define the check in a postcondition block in the resource so that Terraform waits for changes to the managed resource to complete before reading the data resource."*

    The example puts the `postcondition` in the **`data`** block, not "in the resource." The operative rule is the *postcondition* part — a `precondition` on the data block would run before the managed resource settles — and "the resource" appears to mean the data resource. Read the example, not the sentence.

**`precondition` / `postcondition` on an `ephemeral` block.** The one example that exercises a non-`resource` block, and the practical proof that ephemeral resources take `lifecycle`:

```hcl
ephemeral "aws_ssm_parameter" "database_password" {
  name = "/secrets/${var.environment}/database/password"

  lifecycle {
    precondition {
      condition     = var.environment != "prod" || var.compliance_mode == true
      error_message = "Enable compliance mode to assess production secrets."
    }

    postcondition {
      condition     = can(regex("^[A-Za-z0-9!@#$%^&*()_+=-]{16,}$", self.value))
      error_message = "Password from external source must meet security requirements."
    }
  }
}
```

`self.value` on an ephemeral resource means the postcondition can validate a fetched secret without that secret ever reaching state. See [[tf-manage-sensitive-data]].

---
Related: [[meta-arguments-lifecycle]] — the topic page this is the primary reference for; holds the TID framing and the rule-by-rule survey. · [[tf-meta-arguments]] — the index this details. · [[tf-block-resource]] — where the seven-rule list came from. · [[tf-block-removed]] — the `destroy = false` rule's only legal home in Terraform. · [[tf-state-remove]] — the sanctioned way around `prevent_destroy` not surviving config deletion. · [[tf-terraform-data]] — the wrapper that makes a plain value usable in `replace_triggered_by`. · [[ot-dynamic-prevent-destroy]] — OpenTofu lifts both the literal-only `prevent_destroy` and the `removed`-block-only `destroy = false`. · [[tf-conditionals]] — `self` and the custom-condition rules in depth. · [[tf-block-data]] — records `lifecycle` support on `data` blocks that this page's applicability lines omit.
