# Modules

> **Sources:** HCDocs "What is Terraform?" · Hafner, *Terraform in Depth* Ch2 §2.8 (the block) + Ch3 (full treatment) · AWS Get Started "Manage infrastructure" (hands-on)

## In one paragraph

A module is a reusable, self-contained bundle of Terraform code — data sources, resources, and assets — that other configurations call like a function: inputs go in, logic runs, outputs come out. Every configuration is *already* a module (the **root module**); the value comes from factoring shared infrastructure into child modules consumed from a registry, Git, or the filesystem. HCDocs frames modules as one of the "why Terraform scales" bullets; TID Ch3 is the full mechanical treatment; [[tf-aws-manage]] shows consuming a real registry module.

## Key concepts (cross-source)

- **A module is like a function** (TID Ch3) — inputs (`variable` blocks) are the parameters, outputs (`output` blocks) are the return values, and locals (`locals` blocks) are the internal-only variables. From outside, you can only *set inputs* and *read outputs*; locals are invisible.
- **Modules ≠ providers** (TID Ch3 intro) — a module is **pure HCL** with no Go plugin, **cannot define new resource types**, and can mix resources from **multiple providers**. Providers expose low-level infra objects; modules build higher-level abstractions over systems of many objects.
- **Three flavors** (TID Ch3 §3.1):
    - **Root module** — the entry point Terraform starts from (the dir you run `init`/`apply` in); the *only* place a `provider` block is legal. `init` on a root module creates a **workspace**.
    - **Shared module** — pulled from Git or a **module registry**; public or private.
    - **Submodule** — shipped inside a parent, in its `modules/` dir; coupled to the parent.
- **The `module` block + three meta arguments** (TID Ch2 §2.8, Ch3 §3.1.1) — `source` *(required — registry / path / Git)*, `version` *(registry sources only)*, `providers` *(pass provider aliases into the child)*. A module's arguments come from its `variable` blocks; its attributes from its `output` blocks, read as `module.NAME.output`.
- **Standard file structure** (TID Ch3) — `variables.tf` / `outputs.tf` / `main.tf` / `README.md`, plus `modules/`, `templates/`, `examples/`. Convention, not enforced; one-file modules work. Style Guide details in [[tf-style-guide]].
- **Registries + publishing** (TID Ch3) — registries tie into version control and release on a Git **tag**. Name repos **`terraform-<PROVIDER>-<NAME>`**; select a submodule inside a repo with the **double-slash** `//`. The largest public registry is registry.terraform.io.
- **Hands-on consumption** ([[tf-aws-manage]]) — calling the registry VPC module: a versioned `module` block, `module.vpc.*` outputs feeding resources, state addressing under `module.`, and re-running `terraform init` to install a newly-added module.

## Consuming vs. authoring

Two distinct activities the sources keep separate:

| | Consuming a module | Authoring a module |
|---|---|---|
| Focus | `source`, `version`, wiring inputs/outputs | designing inputs, validation, outputs, structure |
| Provider config | in *your* root module | **removed** — child modules only declare `required_providers` |
| Reference | [[tf-aws-manage]] (registry VPC module) | TID Ch3 §3.8 (refactor Hello-World → published module) |

The §3.8 refactor is the canonical author's walkthrough: drop the `provider` block, add `instance_type` + `subnet_id` inputs (with a `validation` regex), expose ID/IP/whole-resource outputs, test via an `example/` root module (`source = "../"`), then publish as `terraform-aws-in-depth`.

## When to read which

- Quick "what is a module and why"? → [[terraform-intro]].
- The `module` block mechanics in context? → TID Ch2 §2.8.
- Full treatment (flavors, the variable trio, types, validation, publishing)? → [TID Ch3](../books/tid/chapters/03-variables-modules.md).
- Actually consume a registry module hands-on? → [[tf-aws-manage]].
- Idiomatic naming / file layout / repo structure? → [[tf-style-guide]].

## Sources

- [What is Terraform? (Intro)](../sources/terraform-docs/terraform-intro.md)
- [TID Ch 2 — Terraform HCL components](../books/tid/chapters/02-hcl-components.md) §2.8 — the `module` block
- [TID Ch 3 — Terraform variables and modules](../books/tid/chapters/03-variables-modules.md) — full treatment
- [Manage infrastructure (AWS Get Started)](../sources/terraform-tutorials/tf-aws-manage.md) — consuming the registry VPC module
- [Style Guide](../sources/terraform-docs/tf-style-guide.md) — module repo naming + structure

## Related learning-path topics

Feeds **I4 — Modules (use + author)**. Inputs/outputs/locals detail → **B6**; the type system → **B4**.
