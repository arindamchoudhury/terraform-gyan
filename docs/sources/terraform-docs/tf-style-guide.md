# Style Guide

> **Source:** [developer.hashicorp.com/terraform/language/style](https://developer.hashicorp.com/terraform/language/style)
> **Added:** 2026-07-08
> **Source updated:** undated language reference; captured 2026-07-08
> **Tags:** style, formatting, fmt, naming, file-layout, version-pinning, modules, gitignore, workflow
> **Type:** documentation

*Developer › Terraform › Configuration Language › Style Guide · v1.15.x*

> 📌 **Version note:** Captured against Terraform **1.15.x** (2026-07-08, see [[version-facts]]). This is guidance, not a language feature — stable and version-agnostic. Applies equally to OpenTofu (same HCL, same `fmt`).

HashiCorp's recommended conventions for writing, structuring, and operating Terraform. Split into two halves: **Code style** (formatting, naming, file layout) and **Workflow style** (versioning, modules, repos, secrets, testing, policy). Adopt to keep configs legible, scalable, maintainable.

## Code style

### Formatting

- **Two-space indent** per nesting level.
- **Align `=`** for consecutive single-line arguments at the same nesting level.
- **Arguments first, then nested blocks**, separated by one blank line. Empty lines group logical sets of arguments.
- **Meta-arguments first, block meta-arguments last.** Within a block: `count`/`for_each` at top (blank line after), then normal args, then nested blocks, then meta-arg blocks like `lifecycle` last.
- **Top-level blocks separated by one blank line.** Nested blocks too — except group same-type blocks (e.g. multiple `provisioner`), and block-type *families* like `root_block_device`/`ebs_block_device`/`ephemeral_block_device` on `aws_instance` may be mixed.

```hcl
resource "aws_instance" "example" {
  count = 2                       # meta-argument first

  ami           = "abc123"
  instance_type = "t2.micro"

  network_interface {
    # ...
  }

  lifecycle {                     # meta-argument block last
    create_before_destroy = true
  }
}
```

- **`terraform fmt`** formats a *subset* of these rules. `-recursive` covers subdirs. Run before every commit (Git pre-commit hook).
- **`terraform validate`** — syntactic + internal-consistency check; verifies types but *not* provider-specific value validity, and does not read state. Safe to run frequently (post-save, pre-commit, CI). See [[tf-cli-commands]] for both commands.
- VS Code: use the Terraform extension; or the Terraform Language Server (LSP) in any LSP-capable editor.

### Comments

Use `#` for both single- and multi-line comments. `//` and `/* */` work (HCL backward-compat) but are **not idiomatic** — `fmt` rewrites them. Only comment to clarify genuine complexity. (Confirms [[tf-config-syntax]]'s comment section.)

### Naming (resources, variables, outputs, locals)

- Descriptive **noun**, words separated by **underscores**. **Do not** repeat the resource type in the name (the address already includes it). Wrap type + name in double quotes.

```hcl
resource aws_instance webAPI-aws-instance {...}   # ❌ Bad
resource "aws_instance" "web_api" {...}           # ✅ Good
```

### Resource order & parameter order

Resource *definition* order doesn't affect build order (dependencies do) — order for **readability**: define data sources *before* the resource that references them ("build on itself").

Consistent parameter order within a resource:

1. `count` / `for_each` (if present)
2. Non-block parameters
3. Block parameters
4. `lifecycle` block (if any)
5. `depends_on` (if any)

**Variable** parameter order: `type` → `description` → `default` (optional) → `sensitive` (optional) → `validation` blocks.

**Output** parameter order: `type` → `description` → `value` → `sensitive` (optional).

### Variables, outputs, locals — usage

- Give **every variable** a `type` and `description`; optional ones a sensible `default`.
- Mark secrets `sensitive = true` — but note it's **still plaintext in state**, just hidden from `plan`/`apply` output.
- Use `validation` blocks only for **uniquely restrictive** requirements (beyond type checking).
- Give **every output** a `description` (and type).
- **Avoid overusing variables and locals** — expose a variable only if the value changes between deployments. Overuse hurts readability.
- Locals: define in `locals.tf` if used across files, else at the top of the file that uses it.

### File names

Recommended layout:

| File | Contents |
|---|---|
| `backend.tf` | backend configuration |
| `main.tf` | all resource + data source blocks |
| `outputs.tf` | all `output` blocks, alphabetical |
| `providers.tf` | all `provider` blocks |
| `terraform.tf` | single `terraform` block: `required_version` + `required_providers` |
| `variables.tf` | all `variable` blocks, alphabetical |
| `locals.tf` | local values |
| `override.tf` / `*_override.tf` | override defs, loaded last — use sparingly |

As the codebase grows, split resources into logical files (`network.tf`, `storage.tf`, `compute.tf`). Rule: a maintainer must immediately know where to find any definition.

### Linting

No built-in linter. Use a third-party static analyzer like **TFLint** to enforce org rules beyond `fmt`/`validate`.

### `.gitignore`

**Do not commit:** `terraform.tfstate` + `terraform.tfstate.*` backups (secrets, no VCS locking), `.terraform.tfstate.lock.info`, `.terraform/` dir, saved plan files (`-out`), any `.tfvars` with secrets.

**Always commit:** all `.tf` code, `.terraform.lock.hcl`, a `.gitignore`, a `README.md` (describes code, inputs, outputs).

### Provider aliasing

Multiple `provider` blocks for one provider (e.g. multi-region). `alias` names the non-default; select with `provider = aws.west` on a resource or `providers = { aws = aws.west }` on a module.

- Always include a **default** provider config; define all providers in one file.
- Define the **default first**; for non-default, put `alias` as the first parameter.

### Dynamic count — `count` vs `for_each`

- Near-identical resources → **`count`**.
- Some args need distinct non-integer-derived values → **`for_each`** (map/set; use `each.key`).
- Conditional creation idiom: `count = var.enable_metrics ? 1 : 0`.
- Meta-arguments add complexity — use in moderation; comment when the effect isn't obvious.

## Workflow style

### Version pinning

- Pin **providers** in `required_providers`; pin **modules** to a specific major.minor via the module `version` param (registry modules only — ignored for local).
- Set **`required_version`** in the `terraform` block for the CLI floor. (See [[provider-requirements]] for constraint operators + lock file.)

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.34.0"
    }
  }
  required_version = ">= 1.7"
}
```

### Modules

- **Repo naming:** registry requires `terraform-<PROVIDER>-<NAME>` (e.g. `terraform-aws-ec2-instance`).
- Group logically-related resources that provision together (a networking module, an application module).
- **Local modules** → `./modules/<module_name>`; prefer publishing to a registry for versioning/sharing.

### Repository structure

- Store **infra config separately from module code**; one repo per module (independent versioning + registry publish).
- Group infra config repos by logically-related resources (limits blast radius).
- **Monorepo** alternative: single source of truth, but complicates CI/CD (must target only changed dirs) and loses granular access control. HCP TF / TFE can scope a workspace to a subdirectory.

### Branching & environments

- **GitHub flow** — short-lived branches, PR review, merge, delete. HCP TF / TFE run **speculative plans** on PRs; merge triggers an apply run.
- **Multiple environments:** `main` is the source of truth. HCP TF / TFE → a **separate workspace per environment** (split large codebases across workspaces: `prod-compute`, `prod-database`, `prod-networking`). Without HCP → a **directory per environment** (`dev/`, `prod/`, `staging/`) each calling shared `modules/`, each with its own backend + vars + state.

### State sharing & secrets

- Avoid sharing full state (contains secrets). Cross-workspace references → `tfe_outputs` data source (HCP/TFE) or provider data sources (e.g. `aws_instance` lookup).
- Local CLI stores state **plaintext on disk**. HCP TF / TFE give state encryption via Vault.
- HCP/TFE: use **dynamic provider credentials**; TFE: Sentinel policy to block `local_exec`/external data. Community Edition: provider env vars + a secrets manager (Vault provider) — still plaintext in state.

### Testing & policy

- Write **`terraform test`** for modules; run as a pre-merge check / CI step. Tests validate *code behavior/logic* — distinct from `validation`/preconditions/postconditions/`check` blocks, which verify *deployed infrastructure*.
- **Policy** (HCP TF): rules enforced on runs — instance-size limits, required tags, no-Friday deploys, security/cost. Store policies in a **separate VCS repo** from Terraform code.

---
Related: [[tf-config-syntax]] — the low-level syntax these conventions sit on top of (comments, `fmt` normalization). [[provider-requirements]] — version constraints + lock file behind version pinning. [[tf-cli-commands]] — `fmt`/`validate`. [[tf-aws-manage]] — variables/outputs/modules in a real config. Feeds learning-path **B4** (reference #1's paired Style Guide), and informs B5/B6 (naming, ordering), I1 (`count`/`for_each` choice), I8 (aliasing), A2 (testing), A4 (workspaces/environments), A5 (policy).
