# `resource` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/resource](https://developer.hashicorp.com/terraform/language/block/resource)
> **Added:** 2026-07-10
> **Source updated:** undated language reference; captured 2026-07-10 against v1.15.x (latest)
> **Tags:** resource-block, lifecycle, action_trigger, actions, provisioners, connection, preconditions, docs-bug
> **Type:** documentation

*Developer › Terraform › Configuration Language › Reference › Configuration blocks › `resource` · v1.15.x*

The complete argument surface of the `resource` block. Most of it is already covered: meta-arguments in [[tf-meta-arguments]], the `lifecycle` rules in [[meta-arguments-lifecycle]], the configure workflow in [[tf-configure-resource]]. Captured for the parts that are **not** — chiefly `action_trigger`, which appears nowhere else in these notes.

## `lifecycle` has seven rules, not four

Our [[meta-arguments-lifecycle]] page lists four (`create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`). The full list from this page:

| Rule | What it does |
|---|---|
| `action_trigger` | **(new here)** invoke provider *actions* on lifecycle events |
| `create_before_destroy` | create the replacement before destroying the current object |
| `prevent_destroy` | reject destroy operations with an error |
| `ignore_changes` | list of attributes whose drift Terraform ignores |
| `replace_triggered_by` | replace when referenced resources/attributes change |
| `precondition` | condition evaluated **before** creating the resource |
| `postcondition` | condition evaluated **after** creating the resource |

`precondition` / `postcondition` are *`lifecycle` rules*, not standalone blocks — [[tf-configure-resource]] lists them among "meta-arguments" without saying where they live. → learning-path **A2**.

!!! note "Why `lifecycle` only takes literals"
    > "Configurations defined in the `lifecycle` block **affect how Terraform constructs and traverses the dependency graph**. You can only use **literal values** in the `lifecycle` block because Terraform processes them **before it evaluates arbitrary expressions** for a run."

    This is the "known early" rule from TID Ch2 §2.7, with the mechanism named: `lifecycle` is an *input* to graph construction, so it cannot depend on anything the graph would produce. (Note this is a different reason from why `replace_triggered_by` rejects plain values — that one is about *planned operations*; see [[tf-terraform-data]].)

!!! warning "`prevent_destroy` does not survive deleting the block"
    > "This rule doesn't prevent Terraform from destroying the resource **if you remove the resource configuration**."

    Independent confirmation of TID Ch2's third objection: the guard vanishes with the block it guards. Combined with the `removed`-block correction in [[tf-block-removed]], there are now two ways to destroy a `prevent_destroy` resource without ever disabling the flag.

## `action_trigger` — lifecycle hooks for provider actions

Terraform 1.14 added the top-level `actions` block (provider-defined operations outside the CRUD lifecycle). `action_trigger` is the **hook that fires them**, and it lives inside `lifecycle`. The learning path covers the `actions` block in A1 and has **zero** mentions of `action_trigger`.

```hcl
resource "aws_instance" "web" {
  # ...

  lifecycle {
    action_trigger {
      events  = [after_create]
      actions = [action.ansible_playbook.provision]
    }
  }
}

action "ansible_playbook" "provision" {
  # ...
}
```

| Argument | Notes |
|---|---|
| `events` | List of lifecycle events. **Required** to invoke an action. |
| `condition` | Expression gating whether the action runs. |
| `actions` | List of `action.<TYPE>.<LABEL>` references. **Required.** |

### Only four events exist — and none of them are destroy

Verified on **Terraform v1.15.6**: the valid events are `before_create`, `after_create`, `before_update`, `after_update`. Passing `before_destroy` or `after_destroy` is not an error about a bad keyword — Terraform reports `No events specified`, i.e. the unknown keyword yields an empty list:

```
after_create     -> Error: ... references non-existent action   (event accepted, action lookup failed)
before_update    -> Error: ... references non-existent action   (accepted)
before_destroy   -> Error: No events specified                  (rejected)
after_destroy    -> Error: No events specified                  (rejected)
```

So **`action_trigger` cannot hook destroy**. Destroy-time work still means a destroy-time provisioner, either in the resource or — once the block is deleted — inside a `removed` block with `destroy = true` ([[tf-block-removed]]).

!!! danger "Docs bug: the page calls the argument `conditions` in one place and `condition` in two others"
    The configuration model and the complete-configuration example both write `condition = <EXPRESSSION>` (with that typo). The `action_trigger` specification section writes `conditions = < true || false >`.

    Verified on v1.15.6 — **`condition` is correct**:

    ```
    condition  = true   -> parses (fails later on the non-existent action)
    conditions = true   -> Error: Unsupported argument
    ```

    Don't copy the spec snippet.

## Everything else on the page

The rest is the argument surface, and it's the most complete listing of it anywhere in the docs:

- **`resource "<TYPE>" "<LABEL>"`** plus **provider arguments** (defined by the provider, not core).
- **Meta-arguments**: `count` / `for_each` (marked **mutually exclusive**, matching [[tf-meta-arguments]]), `depends_on`, `provider`, `lifecycle`.
- **`connection`** — ~25 arguments, including the full bastion set (`bastion_host`, `bastion_port`, `bastion_user`, `bastion_private_key`, `bastion_certificate`, …) and proxy set (`proxy_scheme`, `proxy_port`, `proxy_user_name`, `proxy_user_password`), plus `type`, `user`, `password`, `host`, `port`, `timeout`, `private_key`, `certificate`, `agent`, `agent_identity`, `host_key`, `target_platform`, and WinRM's `https` / `insecure` / `use_ntlm` / `cacert`.
- **`provisioner "<TYPE>"`** — `source`, `destination`, `content`, `command`, `working_dir`, `interpreter`, `environment`, `when`, `quiet`, `inline`, `script`, `scripts`, `on_failure`, and a nested `connection`.

The page's examples cover: defining an AWS instance, `count`, `depends_on`, alternate provider configuration, `ignore_changes`, `replace_triggered_by`, custom conditions, **invoking an action**, the `file` provisioner, `local-exec` / `remote-exec`, `connection`, and provisioner failure behavior. All but "invoke an action" duplicate ground already held by [[tf-configure-resource]] and the topic pages.

---
Related: [[tf-meta-arguments]] — the six meta-arguments this block accepts. · [[meta-arguments-lifecycle]] — the `lifecycle` rules, which this page extends to seven. · [[tf-configure-resource]] — the how-to; treats `precondition`/`postcondition` as meta-arguments rather than `lifecycle` rules. · [[tf-block-removed]] — where a destroy-time provisioner goes once the `resource` block is gone. · [[tf-destroy-resource]] — the destroy half.
