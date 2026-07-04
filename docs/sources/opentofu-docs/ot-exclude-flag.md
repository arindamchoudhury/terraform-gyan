# The `-exclude` flag — negative targeting (OpenTofu)

> **Source:** [opentofu.org/docs/cli/commands/plan](https://opentofu.org/docs/cli/commands/plan/)
> **Added:** 2026-07-03
> **Source updated:** OpenTofu current docs (`-exclude` introduced in **1.9**)
> **Tags:** opentofu, cli, targeting, exclude, plan, apply, divergence
> **Type:** documentation

OpenTofu-only (since 1.9): `-exclude` is the **inverse of `-target`** — plan/apply everything **except** the given addresses and anything depending on them. Terraform's open-source CLI has no equivalent. Available on both `tofu plan` and `tofu apply`.

## The targeting options

- `-exclude=ADDRESS` — focus on resource instances that do **not** match the address and do not depend on excluded resources/modules.
- `-exclude-file=FILENAME` — same, with many addresses in a file.
- `-target=ADDRESS` / `-target-file=FILENAME` — the positive counterparts (only matching addresses + their dependencies).

**Mutually exclusive:** positive targeting (`-target`, `-target-file`) cannot be combined with negative targeting (`-exclude`, `-exclude-file`) in one command.

## Why `-exclude` over `-target`

When **one** resource/module is broken but you want to apply everything else, `-exclude` is far safer than enumerating every *other* resource with `-target`.

```bash
tofu apply -exclude=aws_instance.broken
```

## Address matching rules

- A specific instance address (`aws_instance.example[0]`) selects that instance alone; `count`/`for_each` resources require the index part.
- A whole-resource address selects all its instances.
- A module-instance address selects all resources in that module and its children.

> ⚠️ Both `-target` and `-exclude` technically accept individual instance addresses, but (due to legacy behavior) you should use **whole-resource addresses** only.

## Caveat

Targeting is for **exceptional circumstances** only (recovering from mistakes, working around limitations) — routine use causes undetected drift. Prefer splitting large configurations into smaller independently-applied ones, wired together with data sources.

---
Related: OpenTofu divergence feature for the **E3** milestone. A CLI-level counterpart to the config-level divergences [[ot-provider-for-each]] and [[ot-early-eval-backend]].
