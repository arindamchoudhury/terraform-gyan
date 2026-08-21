# `terraform state list` command

> **Source:** [developer.hashicorp.com/terraform/cli/commands/state/list](https://developer.hashicorp.com/terraform/cli/commands/state/list)
> **Added:** 2026-07-30
> **Source updated:** undated CLI reference; captured 2026-07-30, re-verified 2026-08-21 — still v1.15.x (latest)
> **Tags:** cli, state-list, resource-addressing, filtering, id-lookup, inspection
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Inspecting Infrastructure › `state list` · v1.15.x*

Lists the resource addresses in state. The command everyone already uses; the page has two things most people never learn about it — a defined **sort order** and a **reverse ID lookup**.

!!! note "Re-verified 2026-08-21 — byte-identical"
    Re-fetched and diffed against the July capture: **no change at all** in three weeks, unlike [[tf-block-removed]], which had drifted by a typo fix. Everything below still holds against v1.15.x.

    Two things learned about this page since, both from its neighbours rather than from it. Its filter argument is described upstream as taking a **“partial resource address”** ([[tf-cli-state-inspect]]), which is [[tf-resource-addressing]]'s incomplete-address rule under another name — and the reason a bare address here returns every instance. And it is **read-only**, so it is one of the subcommands exempt from the forced state backup that [[tf-cmd-state]] says every modifying subcommand writes.

## Usage

```
terraform state list [options] [address...]
```

No address lists everything. Addresses filter, "in resource addressing format."

!!! note "The ordering is defined, not incidental"
    > "The resources listed are sorted according to **module depth order followed alphabetically**. This means that resources that are in your immediate configuration are listed first, and resources that are more deeply nested within modules are listed last."

    So a long listing reads outward from the root. Useful when scanning a large state: anything you recognize from your own `.tf` files is at the top, and the tail is other people's modules.

| Flag | Effect |
|---|---|
| `-state=path` | Path to the state file, default `terraform.tfstate`. "Legacy option for the local backend only." |
| `-id=id` | "ID of resources to show. Ignored when unset." |

`-state` is the same legacy surface [[tf-backend-local]] documents and advises against.

## Filtering

Filtering by a resource address returns **all its instances**:

```shell
$ terraform state list aws_instance.bar
aws_instance.bar[0]
aws_instance.bar[1]
```

Filtering by a module returns that module **and its submodules**:

```shell
$ terraform state list module.elb
module.elb.aws_elb.main
module.elb.module.secgroups.aws_security_group.sg
```

## `-id` is a reverse lookup

The flag the command index never mentions. Given a **provider-assigned ID**, it tells you where that object lives in your configuration:

```shell
$ terraform state list -id=sg-1234abcd
module.elb.aws_security_group.sg
```

> "This is useful to find where in your configuration a specific resource is located."

That is the answer to a question that otherwise means grepping state by hand: *the console shows me security group `sg-1234abcd` — which Terraform resource owns it?* Pair it with the console or a CLI listing when investigating an unexpected object.

## Verified on Terraform v1.15.8

Run against the `s3` backend lab state from [[tf-backend-configure]] (two `terraform_data` resources on the local AWS emulator).

`-id` works as documented — the ID came from `terraform show -json`:

```shell
$ terraform state list -id=17568cda-b4c9-3521-3cc6-d4a7866cc433
terraform_data.slow
```

!!! warning "A miss is silent with `-id`, but an error with an address"
    The two filters fail differently, which matters in scripts.

    ```shell
    $ terraform state list -id=does-not-exist
    # no output, exit 0

    $ terraform state list terraform_data.nope
    Error: Unknown resource
    The current state contains no resource terraform_data.nope. ...
    # exit 1
    ```

    So `-id` cannot be used as an existence check by exit status — an empty result and a match both return 0. Test the *output*, not `$?`. The address form does the opposite and fails loudly, which is the behavior you usually want in CI.

!!! tip "Quote the whole flag in PowerShell"
    PowerShell splits an unquoted `-flag=value` at the `=`. Write `"-id=sg-1234abcd"`, not `-id=sg-1234abcd`.

---
Related: [[tf-cli-inspect]] — the command group this belongs to. · [[06-state-management]] §6.5.3 — where `state list` appears alongside `state rm`. · [[tf-state]] — the one-to-one mapping between these addresses and real objects. · [[tf-backend-local]] — the legacy `-state` flag. · [[tf-cmd-output]] — its sibling in the same group, with the same legacy `-state` option.
