# `terraform state replace-provider` command

> **Source:** [developer.hashicorp.com/terraform/cli/commands/state/replace-provider](https://developer.hashicorp.com/terraform/cli/commands/state/replace-provider)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest), behaviour verified on **v1.15.8**
> **Tags:** cli, state, replace-provider, provider-source, registry, forks, opentofu-migration, auto-approve, backups
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Moving Resources › `state replace-provider` · v1.15.x*

Rewrites the provider source address recorded against resources in state. Filed under *Moving Resources* because a provider change **is** an address change ([[tf-cli-state-move]]), and it is the only command in the family that asks before acting.

```
terraform state replace-provider [options] FROM_PROVIDER_FQN TO_PROVIDER_FQN
```

> "This command will update **all resources** using the 'from' provider, setting the provider to the specified 'to' provider. This allows **changing the source** of a provider which currently has resources in state."

All-or-nothing by provider: there is no address argument, so the unit of operation is *every resource bound to that source*. Nothing else in the family works that way — the rest take resource addresses ([[tf-resource-addressing]]).

The page's example is a fork on a private registry:

```shell
terraform state replace-provider hashicorp/aws registry.acme.corp/acme/aws
```

That is the shape of every real use: a registry namespace change, a vendored fork, or a Terraform → OpenTofu move, where the binary is the same but the source address in state no longer matches what `required_providers` will resolve.

## Verified behaviour

Run on **v1.15.8** against a hand-written state holding one `null_resource` bound to `registry.terraform.io/hashicorp/null`.

**Both arguments accept the shorthand.** `hashicorp/null` matched the fully-qualified `registry.terraform.io/hashicorp/null` in state, and expanded the same way on the destination side. The page writes *FQN* in the argument names and then uses the short form in its own example; the short form is what actually works against default-registry providers.

**The output is a small plan, and it is the reason this command feels different:**

```
Terraform will perform the following actions:

  ~ Updating provider:
    - registry.terraform.io/hashicorp/null
    + registry.acme.corp/acme/null

Changing 1 resources:

  null_resource.a

Successfully replaced provider for 1 resources.
```

Every affected address is listed before anything is written. ("Changing 1 resource**s**" is a plural bug at count 1.)

!!! note "It prompts — alone in this family"
    Without `-auto-approve` the command shows the same preview and then asks:

    ```
    Do you want to make these changes?
    Only 'yes' will be accepted to continue.

    Enter a value:
    ```

    With no terminal attached it refuses rather than proceeding: `Error asking for approval: EOF`. So this command is **safe by default and needs a flag in CI**, which is the exact inverse of `terraform refresh`, where `-auto-approve` is always on and cannot be turned off ([[tf-cmd-refresh]]).

    Worth holding next to [[tf-cmd-state-mv]]: `state mv` rewrites bindings with **no preview and no prompt**, and the docs' own argument for `moved` blocks over `state mv` is precisely that a block goes through plan first ([[tf-state-remove]] makes the same case for `removed` over `state rm`). `replace-provider` already has that property built in — a preview, a list of affected addresses, and a confirmation.

**The forced backup is confirmed here in the web page's own text**, not only in the binary:

> "This command will output a backup copy of the state prior to saving any changes. **The backup cannot be disabled.** Due to the **destructive nature** of this command, backups are required."

The run wrote `terraform.tfstate.1787300382.backup`, the timestamped form measured in [[tf-cmd-state-mv]]. Note the docs inconsistency: this sentence appears on this page and on `state mv`'s **help output** but not on `state mv`'s web page, which is the more destructive of the two.

## Options

| Option | Notes |
|---|---|
| `-auto-approve` | "Skip interactive approval." Required for unattended runs — see above. |
| `-var`, `-var-file` | The configuration is loaded, so root-module variables can be supplied. Same as `state mv`. |
| `-lock=false`, `-lock-timeout=0s` | The standard state-lock pair ([[tf-state-locking]]). |
| `-ignore-remote-version` | HCP Terraform CLI integration or the `remote` backend only. |
| `-state`, `-state-out`, `-backup` | Legacy, local state only ([[tf-backend-local]]). **No `-backup-out`** here, unlike `state mv`. |

---
Related: [[tf-cli-state-move]] — the section index, and where "a provider change is an address change" is stated. · [[tf-cmd-state-mv]] — its sibling: more destructive, no preview, no prompt. · [[tf-cmd-state]] — the family hub and the backup rule this page repeats verbatim. · [[tf-cmd-refresh]] — the opposite approval default: `-auto-approve` always on and not disableable. · [[tf-provider-block]] / [[provider-requirements]] — where the source address this command rewrites is declared in configuration.
