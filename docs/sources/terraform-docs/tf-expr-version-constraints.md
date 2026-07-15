# Version Constraints

> **Source:** [developer.hashicorp.com/terraform/language/expressions/version-constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)
> **Added:** 2026-07-15
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-15
> **Tags:** version-constraints, required_version, provider-requirements, module-versions, pessimistic-operator, pre-release
> **Type:** documentation

Terraform accepts a specially-formatted string to constrain the versions of components. You can set version constraints on:

- Modules
- Provider requirements
- The `required_version` setting in the `terraform` block

## Version constraint syntax

A constraint is a string literal with one or more **conditions** separated by commas. Each condition is an **operator** plus a **version number**. Version numbers are dot-separated numbers (`1.2.0`), optionally with a suffix for a pre-release.

```hcl
version = "<operator> <version>"
```

Example — install 1.2.0 and newer, but older than 2.0.0:

```hcl
version = ">= 1.2.0, < 2.0.0"
```

## Operators

| Operator | Description |
|---|---|
| `=` (or no operator) | Exactly one version. **Cannot** combine with other conditions. |
| `!=` | Excludes an exact version. |
| `>`, `>=`, `<`, `<=` | Compare to a version; Terraform allows versions resolving to true. `>`/`>=` request newer, `<`/`<=` request older. |
| `~>` | Pessimistic constraint — only the **right-most** component may increment. |

`~>` examples:

- `~> 1.0.4` — allows `1.0.5`, `1.0.10`; **not** `1.1.0`.
- `~> 1.1` — allows `1.2`, `1.10`; **not** `2.0`.

## Version constraint behavior

Terraform uses versions meeting **all** applicable constraints. It checks constraints for itself, required provider plugins, and required modules. For plugins and modules it uses the **newest installed** version that qualifies; if none qualifies, it downloads the newest that does.

If it can't obtain acceptable versions of external dependencies, or lacks an acceptable version of itself, it does **not** proceed with any `plan`, `apply`, or `state` operation.

Root and child modules may all constrain the Terraform and provider versions. Terraform treats these constraints as equal and proceeds only if **all** are met.

## Specify a pre-release version

A pre-release version has a dash-introduced suffix, e.g. `1.2.0-beta`. To select one, set the exact version with `=` (or no operator). Terraform does **not** match pre-release versions on `>`, `>=`, `<`, `<=`, or `~>`.

## Best practices

**Module versions**

- Require specific versions so updates to third-party modules happen only when convenient for you.
- Specify version ranges when your org consistently uses semantic versioning for its own modules, or follows a well-defined release process that avoids unwanted updates.

**Terraform core and provider versions**

- **Reusable modules** should constrain only their **minimum** versions (e.g. `>= 0.12.0`) — avoids known incompatibilities while letting the module's user upgrade freely.
- **Root modules** should use a `~>` constraint to set both a lower and an upper bound on each provider they depend on.

---
Related: [[provider-requirements]] — the `required_providers` block where provider version constraints live. [[tf-dependency-lock]] — constraints choose an acceptable range; the lock file pins the exact provider version selected within it. [[tf-expressions]] — version constraints are a special string syntax covered under the Expressions section.
