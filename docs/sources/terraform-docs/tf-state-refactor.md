# Refactor Terraform state

> **Source:** [developer.hashicorp.com/terraform/language/state/refactor](https://developer.hashicorp.com/terraform/language/state/refactor)
> **Added:** 2026-07-29
> **Source updated:** undated language reference; captured 2026-07-29 against v1.15.x (latest)
> **Tags:** state, refactoring, splitting-state, removed-block, import-block, state-mv, state-pull, state-push, terraform_remote_state
> **Type:** documentation

*Developer › Terraform › Configuration Language › State › Refactor state · v1.15.x*

The **cross-configuration** refactor guide: how to move resources from one state file into another. That distinction matters. TID Ch6 §6.5 covers state surgery *within* one configuration, and [[tf-block-removed]] covers the block itself. This page is about splitting a monolith into separate configurations with separate state.

Its opening premise is a performance claim: "Terraform operations complete faster when you split configuration with large state files." Same reasoning as TID Ch6 §6.7's refresh-cost argument for splitting projects.

The whole-page rule: **refactoring means updating the configuration and the state files together.** Neither alone.

## Identify opportunities to refactor

Four triggers the page names.

- **Long applies.** Configuration grew over time. Large monolithic configuration makes plan and apply slow, and "cause unintended changes."
- **Changes to management lifecycles.** Separate frequently-updated resources from infrequently-updated ones. Simplifies operations and reduces blast radius.
- **Changes to resource ownership.** Teams split responsibility for parts of the architecture, so configuration and state get refactored to match ownership. This is TID Ch6 §6.7's Conway's-law argument, stated as an operational trigger instead.
- **Reusable module opportunity.** If you create the same set of resources in several configurations, group them into a module and reuse it.

## Plan the grouping

Three properties to group by, decided **before** you start:

- **Volatility and rate of change.** The page's example: compute may scale several times a day while networking stays static for months. Exposing long-lived infrastructure to that volatility "introduce[s] more opportunities for accidental changes."
- **Stateful vs stateless.** Managing databases separately from compute instances limits the blast radius of re-provisioning operations and protects against accidental data loss.
- **Access and team responsibility.** Splitting workspaces by team means only people familiar with a given area change it.

## Identify dependencies

Splitting breaks references. Move network resources to a new state file and the compute resources that referenced them can no longer reach them.

**Recommendation: dynamic references, not hard-coded values.** Hard-coding means manually updating configuration whenever the data changes, "which can lead to errors in your configuration or your deployed resources."

Three dynamic options, in the page's order:

1. **A resource-specific data source**, if the provider has one — e.g. `aws_vpc` to look up a VPC created by another configuration.
2. **`tfe_outputs`**, if you use HCP Terraform or Terraform Enterprise — reads outputs from another workspace.
3. **`terraform_remote_state`**, for any other remote backend or the local backend. On HCP Terraform you must explicitly declare which workspaces have access.

!!! note "The ordering is the same argument [[tf-remote-state-data]] makes"
    Data source first, `tfe_outputs` second, `terraform_remote_state` last. That page's reason is security: reading one output through `terraform_remote_state` requires credentials that can read the **entire** state snapshot. This page just lists them in that order without repeating why.

`terraform graph` is suggested for visualizing relationships and finding the dependencies you are about to sever. See [[tf-cmd-graph]].

## Migrate resources

The split by resource kind:

- **Stateless resources** — recreate them in the new configuration, if that costs no downtime and no money.
- **Stateful resources** (databases, object stores) — usually cannot be deleted and recreated, and backup/restore is complex and expensive. Move them between state files instead.

Two approaches, with a clear recommendation.

| Approach | Minimum version | Status |
|---|---|---|
| `removed` + `import` blocks | Terraform **1.7** | **Recommended.** The blocks "help keep a record of the configuration history." |
| `terraform state mv -state/-state-out` | Terraform **1.0** | "This is a legacy command." |

### Remove and import (recommended)

Starting resource, to be moved to a new state file:

```hcl
resource "aws_instance" "example" {
    instance_type = "t3.micro"
    ami           = data.aws_ami.example.id
}
```

**In the source configuration:**

1. Back up the current state.

    ```shell
    terraform state pull > terraform.tfstate.backup
    ```

2. Check which attribute your provider needs for import. For `aws_instance` that is `id`.

    ```shell
    terraform state show aws_instance.example
    ```

    ```
    ##...
    id = "i-07b510cff5f79af00"
    ##...
    ```

3. Replace each resource block with a `removed` block.

    ```diff
    - resource "aws_instance" "example" {
    -     instance_type = "t3.micro"
    -     ami           = data.aws_ami.example.id
    - }

    + removed {
    +   from = aws_instance.example
    +   lifecycle {
    +     destroy = false
    +   }
    + }
    ```

    Placement is free — the blocks "can exist anywhere in your configuration" — but the page recommends standardizing on one convention per organization. Its suggested default: put the `removed` block in the file that used to hold the `resource` block.

4. `terraform plan`, and confirm nothing is destroyed.

    ```
    # aws_instance.example will no longer be managed by Terraform, but will not be destroyed
    # (destroy = false is set in the configuration)
    . resource "aws_instance" "example" {
            id = "i-07b510cff5f79af00"
    ##...
    ```

5. `terraform apply` to drop it from state.

!!! danger "`destroy = false` is doing all the work in step 3"
    Omit that `lifecycle` block and the `removed` block **destroys the resource**. Verified on Terraform 1.15.6 in [[tf-block-removed]], which also records that our own notes and TID Ch2 §2.9 had this backwards. In a refactor the real object must survive, so the opt-out is mandatory here, not optional. The plan output in step 4 is the check: "will no longer be managed by Terraform, but will not be destroyed."

**In the destination configuration:**

1. Add the resource blocks.
2. Add an `import` block per resource.

    ```hcl
    resource "aws_instance" "example" {
        instance_type = "t3.micro"
        ami           = data.aws_ami.example.id
    }

    import {
      id = "i-07b510cff5f79af00"
      to = aws_instance.example
    }
    ```

3. `terraform plan` and confirm the import.

    ```
    # aws_instance.example will be imported
        resource "aws_instance" "example" {
    ```

4. `terraform apply`.

    ```
    Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.

    Do you want to perform these actions?
      Enter a value: yes

    aws_instance.example: Importing... [id=i-12345678901234567]
    aws_instance.example: Import complete [id=i-12345678901234567]

    Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.
    ```

Afterwards the `removed` and `import` blocks can be deleted, or kept as a record of the resource's lifecycle. TID Ch6 §6.5 makes the same call for `moved`.

!!! warning "Two sloppy details in the page's own example"
    The state backup is written to **`terraform.tfstate.backup`** — which is the exact filename the *local backend* uses for its own automatic backup of the previous state ([[tf-state]]). On a local backend that command overwrites Terraform's backup with your backup. Pick another name.

    The apply transcript also imports `i-12345678901234567`, not the `i-07b510cff5f79af00` used everywhere else on the page. Copy-paste drift in the docs, not a behavior to explain.

### Move directly with `state mv` (legacy)

The page warns three times over: `-state` and `-state-out` are "legacy options that Terraform maintains for backwards compatibility"; the approach also needs `state pull`/`state push`, and "does have some risk of corrupting your remote state"; use `removed`/`import` for any new migration.

**Prepare.** Local backend can move between two state files directly. Remote backends must download both first.

```shell
terraform state pull > source.tfstate        # run in the source config's directory
terraform state pull > destination.tfstate   # run in the destination config's directory
```

**Move**, once per resource:

```shell
terraform state mv -state source/source.tfstate -state-out destination/destination.tfstate aws_instance.example aws_instance.example
```

```
Move "aws_instance.example" to "aws_instance.example"
Successfully moved 1 object(s).
```

`-state` is the source file, `-state-out` the destination file. The last two arguments are the address to move out of the source and the address to create in the destination.

**Push both back**, if you use a remote backend:

```shell
terraform state push source.tfstate         # in the source config's directory
terraform state push destination.tfstate    # in the destination config's directory
```

The safety checks on those pushes (lineage, serial, `-force`) are in [[tf-state-backends]].

!!! tip "Quote the flags in PowerShell"
    The page uses the space form (`-state source.tfstate`), which is safe. The `=` form gets mangled by PowerShell's argument splitting, so write `-state=source.tfstate` only inside quotes.

### Verify

Six steps, and they are the point of the exercise — an empty plan on both sides is the proof the migration worked.

1. Delete the migrated resources from the source configuration.
2. `terraform plan` on the source. It must show no changes.
3. Add the migrated resources to the destination configuration.
4. `terraform plan` on the destination. It must show no changes.
5. Open pull requests for both repositories. If the review process produces a speculative plan, check that too.
6. Merge.

---
Related: [[tf-block-removed]] — the block used in step 3, and the verified proof that `destroy = false` is what stops it destroying. [[tf-state-backends]] — the `state pull`/`state push` mechanics and guards this page's legacy path depends on. [[tf-remote-state-data]] — the third dependency option, plus the security reason it is ranked third. [[tf-cmd-graph]] — the tool this page suggests for finding dependencies before you sever them. [[tf-state]] — where `terraform.tfstate.backup` comes from, which is why the backup filename here is a poor choice.
