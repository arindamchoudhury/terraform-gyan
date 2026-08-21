# `terraform state mv` command

> **Source:** [developer.hashicorp.com/terraform/cli/commands/state/mv](https://developer.hashicorp.com/terraform/cli/commands/state/mv)
> **Added:** 2026-08-21
> **Source updated:** undated CLI reference; captured 2026-08-21 against v1.15.x (latest), behaviour verified on **v1.15.8**
> **Tags:** cli, state-mv, refactoring, resource-addressing, powershell, quoting, backups, dry-run, moved-block
> **Type:** documentation

*Developer › Terraform › Terraform CLI › Manually Update State › Moving Resources › `state mv` · v1.15.x*

The CLI half of refactoring. [[tf-cli-state-move]] argues you should use `moved` blocks instead; this is the page for when you cannot. Longest command reference in the section, and the one whose web version differs most from what the binary says about itself.

> "The `terraform state mv` command changes **bindings** in Terraform state so that existing remote objects bind to new resource instances."

## Usage and the address rules

```
terraform state mv [options] SOURCE DESTINATION
```

Three constraints, and they are stricter than "any address to any address":

- Both addresses "must use **resource address syntax**" — the grammar in [[tf-resource-addressing]].
- Both must refer to "**the same kind of object**": instance → instance, whole module instance → whole module instance.
- Moving a resource or instance requires "a new address with the **same resource type**".

So `state mv` renames and relocates; it never converts. Changing `packet_device` to something else is a destroy-and-create no matter how you address it — the same limit `moved` has, from the same reason: the object's schema belongs to its type.

The page states the default behaviour it exists to override, in the clearest form the docs manage:

> "By default Terraform will understand moving or renaming a resource configuration as a request to **delete the old object and create a new object** at the new address, and so `terraform state mv` allows you to override that interpretation by **pre-emptively attaching** the existing object to the new address."

!!! danger "The race window is the real argument against doing it this way"
    > "If you are using Terraform in a collaborative environment, you must ensure that when you are using `terraform state mv` for a code refactoring purpose you **communicate carefully with your coworkers** to ensure that nobody makes any other changes between your configuration change and your `terraform state mv` command, because otherwise they might inadvertently **create a plan that will destroy the old object and create a new object** at the new address."

    A refactor done this way is two operations with a gap in between, and during that gap the repository describes a rename that state does not know about. Anyone who plans in that window gets a correct-looking destroy.

    This is the third distinct argument for `moved` blocks, and the sharpest. The mechanism argument is [[tf-block-moved]]'s (the rename happens before the plan is computed). The audience argument is [[tf-cli-state-move]]'s (a block ships to module consumers; a command does not). This is the **atomicity** argument: a `moved` block makes the rename part of the same apply as the configuration change, so no window exists. It is also the same shape of flaw that got `taint` deprecated — intent recorded in state ahead of the action, with a gap where someone else can act ([[tf-cli-state-taint]]).

## Options

| Option | Notes |
|---|---|
| `-dry-run` | The web page describes it as reporting matches "without actually **'forgetting'** any of them" — that is `state rm`'s wording, pasted. The binary's own help is correct: *"prints out what would've been moved but doesn't actually move anything."* |
| `-var 'NAME=VALUE'`, `-var-file=FILENAME` | A state command that takes **input variables**, because it loads the configuration to resolve the addresses against it. Nothing else in this family does. |
| `-lock=false`, `-lock-timeout=DURATION` | Standard state-lock pair; this command writes state, so it locks ([[tf-state-locking]]). |
| `-ignore-remote-version` | HCP Terraform CLI integration or the `remote` backend only. |
| `-state`, `-state-out`, `-backup`, `-backup-out` | **Legacy, local state only.** A remote-backend configuration "must specify a local state file with the `-state` option in order to use the `-backup` and `-backup-out` options" ([[tf-backend-local]] on what *legacy* means here). |

## The examples, in full

**Rename a resource:**

```diff
-resource "packet_device" "worker" {
+resource "packet_device" "helper" {
   # ...
 }
```

```shell
terraform state mv packet_device.worker packet_device.helper
```

**Move a resource into a module** — move the block into the child module, delete the original, then:

```shell
terraform state mv packet_device.worker module.worker.packet_device.worker
```

Renaming at the same time is allowed, since only the *type* is fixed:

```shell
terraform state mv packet_device.worker module.worker.packet_device.main
```

**Move a module into a module:**

```shell
terraform state mv module.app module.parent.module.app
```

**A `count` instance:**

```shell
terraform state mv 'packet_device.worker[0]' 'packet_device.helper[0]'
```

And the case worth remembering, because it is the one thing here `moved` is usually credited with:

```shell
terraform state mv 'packet_device.main' 'packet_device.all[0]'
```

> "A resource that doesn't use `count` or `for_each` has only a single resource instance whose address is the same as the resource itself, and so you can move **from an address not containing an index to an address containing an index, or the opposite**."

**A `for_each` instance:**

```shell
terraform state mv 'packet_device.worker["example123"]' 'packet_device.helper["example456"]'
```

## Verified: the PowerShell row is wrong here too

The page gives three shells. The PowerShell row is the same one [[tf-cmd-state-show]] records as broken, and it is broken here for the same reason — on PowerShell 7 single quotes are already literal, so the backslashes reach Terraform.

Tested on **Terraform v1.15.8, PowerShell 7, Windows**, against a hand-written state file holding `packet_device.worker["example123"]`:

| Form | Result |
|---|---|
| `'packet_device.worker[\"example123\"]'` — **the page's PowerShell row** | ❌ fails |
| `'packet_device.worker["example123"]'` — plain single quotes | ✅ `Successfully moved 1 object(s).` |

The failure is noisier than `state show`'s, because `mv` runs the address through the HCL parser:

```
│ Error: Invalid character
│   on  line 1:
│   (source code not available)
│ This character is not used within the language.

│ Error: Index value required
```

Write the address with real quotes inside single quotes. The Unix row works as printed; the cmd.exe row was not tested.

## Verified: the forced backup, and what it is actually called

The binary's help states the rule the family hub does ([[tf-cmd-state]]), in stronger words:

> "This command will output a backup copy of the state prior to saving any changes. **The backup cannot be disabled.** Due to the destructive nature of this command, backups are required."
>
> "If you're moving an item to a different state file, a backup will be created **for each state file**."

The successful move above wrote **`terraform.tfstate.1787299723.backup`** — a Unix timestamp infixed before the extension.

!!! note "So the automatic backups accumulate rather than collide"
    This corrects a guess made when [[tf-cmd-state]] was captured. Because the name carries a timestamp, an automatic backup **does not** overwrite the local backend's own `terraform.tfstate.backup`, and successive `state mv` runs do not overwrite each other. They pile up, one full copy of state per operation, and nothing prunes them.

    The hazard [[tf-state-refactor]] was flagged for stands unchanged on its own terms: writing a manual backup *to* `terraform.tfstate.backup` still collides with the local backend's file. It just does not collide with these.

## The binary documents a capability the web page does not

`terraform state mv -help` opens with the cross-state case as a headline feature:

> "This command can also move to a destination address in a **completely different state file**… it can also be used for **refactoring one configuration into multiple separately managed Terraform configurations**."

The web page never says this in prose. It surfaces only as the legacy `-state-out` flag in the options list, described as a backward-compatibility wart — and yet it is exactly the operation [[tf-state-refactor]] and [[tut-state-cli]] use, and the one thing `moved` blocks **cannot** do, since they work within a single state file. The most important remaining reason to use this command is the one its reference page leaves out.

Two smaller divergences: the help text lists `-state, state-out, and -backup` as the legacy set (missing `-backup-out`, which the web page includes), and misprints `state-out` without its leading dash.

---
Related: [[tf-cli-state-move]] — the section index, and the two other arguments for preferring `moved`. · [[tf-block-moved]] — the language feature this command exists in spite of. · [[tf-state-refactor]] — the cross-configuration migration that depends on the capability this page omits. · [[tut-state-cli]] — a shorter cross-file form, run from the source directory. · [[tf-cmd-state]] — the family hub and its backup rule, confirmed here from the binary. · [[tf-cmd-state-show]] — the same broken PowerShell advice, verified separately. · [[tf-resource-addressing]] — the address grammar both arguments must satisfy.
