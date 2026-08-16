# Modules

> **Sources:** HCDocs "What is Terraform?" · Hafner, *Terraform in Depth* Ch2 §2.8 (the block) + Ch3 (full treatment) · Brikman, *Terraform: Up & Running* 3rd ed. Ch4 (the narrative refactor) · AWS Get Started "Manage infrastructure" (hands-on)

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
- **Matching interfaces make implementations swappable** (TID Ch10 §10.2.3–§10.2.4) — the network module's two topology submodules take the *same inputs* and expose the *same outputs*, so the parent selects between them with `count` as a binary toggle and hides the choice behind a `local` plus splat. The corollary from HCDocs composition is the same shape: a `join-network` module with the same outputs as a `create-network` module makes promoting an environment a one-line `source` change. Two useful sub-rules from the same section: a lower-layer module is allowed to be **incomplete on its own** if the parent completes it (the AWS internet gateway), and anything the module cannot use — spare CIDR blocks — should be **returned as an output**, not silently swallowed. ⚠️ Take the *techniques* only: the listing itself carries three measured defects, including a parent module that never actually creates the internet gateway its submodules were promised.
- **Hands-on consumption** ([[tf-aws-manage]]) — calling the registry VPC module: a versioned `module` block, `module.vpc.*` outputs feeding resources, state addressing under `module.`, and re-running `terraform init` to install a newly-added module.

## Consuming vs. authoring

Two distinct activities the sources keep separate:

| | Consuming a module | Authoring a module |
|---|---|---|
| Focus | `source`, `version`, wiring inputs/outputs | designing inputs, validation, outputs, structure |
| Provider config | in *your* root module | **removed** — child modules only declare `required_providers` |
| Reference | [[tf-aws-manage]] (registry VPC module) | TID Ch3 §3.8 (refactor Hello-World → published module) |

The §3.8 refactor is the canonical author's walkthrough: drop the `provider` block, add `instance_type` + `subnet_id` inputs (with a `validation` regex), expose ID/IP/whole-resource outputs, test via an `example/` root module (`source = "../"`), then publish as `terraform-aws-in-depth`.

## Two books, two angles on the same chapter topic

Both TID and TUR give modules a full chapter. They are complementary, and the split is clean enough to state as a rule: **read TUR for *why each feature exists*, read TID for *what the feature can do*.**

| | TUR Ch4 (Brikman, 2022) | TID Ch3 (Hafner, 2025) |
|---|---|---|
| Shape | Narrative — one running example refactored | Reference — feature by feature |
| Arrives at a feature because… | the example broke without it | it's the next thing in the API |
| Module flavors | root vs reusable only | root / shared / submodule |
| Type system, `validation`, `sensitive` | not covered | full treatment |
| Publishing | Git tags only — **never mentions a registry** | registry publishing walkthrough |
| Promotion workflow | **end to end** — tag, move staging, leave prod, roll forward | not covered |
| Locals | motivated as "don't let callers override this" | listed with the variable trio |

Three ideas TUR Ch4 states better than anywhere else in these notes:

- **"The input variables are the API of the module."** Inputs are an interface, not a convenience.
- **A variable is permission to change a value.** Its locals section rejects input variables for the port/protocol constants specifically because *"users of your module will be able to (accidentally) override these values."*
- **Prefer separate resources to inline blocks in a module** — not for correctness, but because a separate resource "can be added anywhere" while an inline block can only be added by the module that owns the resource. That is the encapsulation argument for a design choice usually presented as style.

!!! warning "TUR's Git-tag advice needs one correction"
    TUR recommends Git tags over branches and SHAs, arguing *"Git tags are as stable as a commit."* Against accidental drift that is right, and the branch warning is right. But a tag is a movable pointer — whoever controls the source repo can force-move it. Against an adversary, only a SHA pins. See the supply-chain callout in learning-path **I4** and the note in [TUR Ch4](../books/tur/chapters/04-reusable-modules.md).

## When to read which

- The consumer's side end to end, with measurements? → [Book Ch 13 — Using modules](../book/ch13-using-modules.md).
- Quick "what is a module and why"? → [[terraform-intro]].
- The `module` block mechanics in context? → TID Ch2 §2.8.
- Full treatment (flavors, the variable trio, types, validation, publishing)? → [TID Ch3](../books/tid/chapters/03-variables-modules.md).
- *Why* you'd factor code into a module at all, and how to promote versions between environments? → [TUR Ch4](../books/tur/chapters/04-reusable-modules.md).
- Actually consume a registry module hands-on? → [[tf-aws-manage]].
- Idiomatic naming / file layout / repo structure? → [[tf-style-guide]].
- Refactoring *existing* deployed resources into a module without destroying them? → neither book covers it; see [[tf-modules-refactoring]] and [[tut-move-config]].

## Sources

- [What is Terraform? (Intro)](../sources/terraform-docs/terraform-intro.md)
- [TID Ch 2 — Terraform HCL components](../books/tid/chapters/02-hcl-components.md) §2.8 — the `module` block
- [TID Ch 3 — Terraform variables and modules](../books/tid/chapters/03-variables-modules.md) — full treatment
- [TID Ch 10 — Advanced Terraform topics](../books/tid/chapters/10-advanced-topics.md#102-network-management) §10.2 — a worked reusable module: identical interfaces, computed subnetting, `count` as a topology switch
- [TUR Ch 4 — How to Create Reusable Infrastructure with Terraform Modules](../books/tur/chapters/04-reusable-modules.md) — the narrative refactor, module versioning by Git tag, the staging→production promotion workflow
- [Manage infrastructure (AWS Get Started)](../sources/terraform-tutorials/tf-aws-manage.md) — consuming the registry VPC module
- [Style Guide](../sources/terraform-docs/tf-style-guide.md) — module repo naming + structure

## Related learning-path topics

Feeds **I4 — Modules (use + author)**. Inputs/outputs/locals detail → **B6**; the type system → **B4**.
