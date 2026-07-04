# Learning Path: Terraform (and OpenTofu)

> **Last updated:** 2026-07-03 — **B1 complete**: Book Ch 1 written (blends [[terraform-intro]], [[terraform-use-cases]], TID Ch1, plus 2026 web research on the IBM/HashiCorp acquisition and current OpenTofu-vs-Terraform guidance); three cross-source topic pages (IaC fundamentals, Core workflow, Providers). Initial path built 2026-07-02 from Terraform Associate 004 + Authoring/Operations Pro exam objectives, current Terraform 1.14 / OpenTofu 1.12, and the top books.
> **Current stable versions:** Terraform CLI **1.14.7** (2026-03-11, BSL 1.1) · OpenTofu **1.12.2** (2026-05, MPL 2.0)
> **Local stack:** Terraform CLI + a cloud account (AWS recommended for cert alignment); OpenTofu optional as a drop-in.
>
> **How to read this page.** Topics are the primary unit. Each topic has a "How to learn it" section that
> recommends a multi-modal path — video first, then hands-on, then depth reading, then reference docs.
> Resources serve the topics; they are not the organizing structure. Terraform and OpenTofu share HCL,
> providers, and state format — learn either; differences are called out where they matter (see E3).

---

## Resources at a glance

| Abbrev | Name | Type | URL |
|---|---|---|---|
| **TID** | *Terraform in Depth: IaC with Terraform and OpenTofu* (Hafner, Manning) | Book | manning.com/books/terraform-in-depth |
| **TUR** | *Terraform: Up & Running*, 3rd ed (Brikman, O'Reilly) | Book | oreilly.com |
| **HCDocs** | HashiCorp Developer — Terraform docs | Official docs | https://developer.hashicorp.com/terraform |
| **HCTut** | HashiCorp Developer — Terraform Tutorials (free hands-on labs) | Official interactive | https://developer.hashicorp.com/terraform/tutorials |
| **OTDocs** | OpenTofu documentation | Official docs | https://opentofu.org/docs/ |
| **Assoc** | Terraform Associate 004 study path | Official course | https://developer.hashicorp.com/terraform/tutorials/certification-004 |
| **Pro** | Terraform Authoring & Operations Pro study path | Official course | https://developer.hashicorp.com/terraform/tutorials/pro-cert |
| **KK** | KodeKloud — Terraform for Beginners / labs | Interactive labs | kodekloud.com |
| **TF2026** | Rahul Oli — *Terraform Complete Course in One Video: Beginner to Advanced* (YouTube, Apr 2026, 6h23m) | Video course | [youtu.be/l5qtFBsxZdk](https://youtu.be/l5qtFBsxZdk) |
| **Krausen** | Bryan Krausen — Terraform Associate course + practice exams | Video + practice | [krausen.io hands-on labs](https://krausen.io/course/hashicorp-certified-terraform-associate-hands-on-labs/) · [004 practice exams](https://www.udemy.com/course/terraform-associate-004-practice-exams/) |
| **TPF** | Terraform Plugin Framework docs | Official docs | https://developer.hashicorp.com/terraform/plugin/framework |
| **TG** | Terragrunt docs (Gruntwork) | Official docs | https://terragrunt.gruntwork.io/docs |

> 📌 **TUR** targets Terraform ~1.1. Core concepts (modules, state, testing philosophy) are still the best
> treatment available, but verify newer syntax (`terraform test`, `import`/`removed` blocks, Stacks) against
> current **HCDocs**.

---

## Certifications

| Cert | Provider | Level | Topics tested | Fee | Format | When to attempt |
|---|---|---|---|---|---|---|
| **Terraform Associate (004)** | HashiCorp | Intermediate exit | IaC concepts · fundamentals (providers/state) · core workflow · HCL config language · modules (use + author) · state management · infrastructure maintenance · HCP Terraform | $70.50 | 1 hr, ~57 multiple-choice, valid 2 yrs; tests Terraform 1.12 | After Intermediate |
| **Terraform Authoring & Operations Professional** | HashiCorp | Advanced exit | resource lifecycle · dynamic config & troubleshooting · collaborative workflows · modules · providers · HCP Terraform (MC only) | (see HashiCorp) | Lab-based (hands-on), AWS provider; Azure variant late 2026 | After Advanced |

> **004 replaces 003** (retired 2026-01-08). If you see 003 study material, the content is ~90% the same but
> use 004 resources where possible. The Pro exam assumes deep HCL + CLI fluency and real cloud experience.

---

## Beginner

**Goal:** Write, plan, and apply a real Terraform configuration against a cloud provider, and understand what state is.
**Estimated time:** ~30 hrs

---

### ✅ B1 — Infrastructure as Code & where Terraform fits

**What it is:** The idea of provisioning infrastructure from declarative, version-controlled files, and how Terraform (declarative, cloud-agnostic, provider-based) compares to OpenTofu, Pulumi, CloudFormation, and Ansible.

**Why you need it:** Without the mental model of *declarative + desired state + plan/apply*, every later command looks like magic; you also need to know when Terraform is the right tool vs config management.

**How to learn it:**

1. **Video — [TF2026 "Core Terraform Concepts"](https://youtu.be/l5qtFBsxZdk)** (00:00, ~40 min) — watch the "what is IaC / why Terraform" opening; build the mental picture before touching syntax.
2. **Book chapter — TID Ch 1** (~1 hr) — read the IaC framing and the Terraform-vs-OpenTofu positioning (this book covers both). (Captured notes: [[01-brief-overview]].)
3. **Reference — [HCDocs "Intro / Use Cases"](https://developer.hashicorp.com/terraform/intro)** (~20 min) — skim the official framing; note the declarative vs imperative distinction. (Captured notes: [[terraform-intro]], [[terraform-use-cases]].)

**Milestone:** You can explain in two sentences why Terraform is declarative and how it differs from Ansible and from CloudFormation.

---

### ⬜ B2 — Install, providers & your first project

**What it is:** Installing the Terraform (or OpenTofu) CLI, wiring cloud credentials, declaring a `required_providers` + `provider` block, and laying out a first working directory.

**Why you need it:** Nothing runs until the CLI, a provider plugin, and credentials are in place; project layout mistakes here cause pain forever.

**How to learn it:**

1. **Interactive — HCTut ["Install Terraform"](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) + ["Create infrastructure"](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create)** (~1 hr) — follow the AWS (or Docker) quick-start end to end in your own account.
2. **Reference — [HCDocs "Provider Requirements"](https://developer.hashicorp.com/terraform/language/providers/requirements)** (~20 min) — understand `required_providers`, source addresses, and version pinning. ([Install](https://developer.hashicorp.com/terraform/install))
3. **Book chapter — TID Ch 2** (~1 hr) — first-project walkthrough; note the `.terraform/` and lock-file layout.

**Milestone:** You can stand up a fresh directory, `terraform init` it, and provision one real resource (an S3 bucket or a Docker container) from scratch.

---

### ⬜ B3 — The core workflow: init / plan / apply / destroy

**What it is:** The four-command loop — `init` (download providers, set up backend), `plan` (compute a diff), `apply` (execute), `destroy` (tear down) — plus the dependency lock file.

**Why you need it:** This loop is the heartbeat of Terraform; the Associate exam tests it heavily and every workflow is built on it.

**How to learn it:**

1. **Interactive — HCTut ["Manage infrastructure"](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-manage) + ["Destroy infrastructure"](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-destroy)** (~45 min) — run a full modify-then-destroy cycle; read the plan output symbols (`+`, `-`, `~`, `-/+`).
2. **Video — [Krausen "Terraform Associate — Hands-On Labs" (core-workflow section)](https://krausen.io/course/hashicorp-certified-terraform-associate-hands-on-labs/)** (~40 min) — walks the plan/apply lifecycle with cert framing.
3. **Reference — [HCDocs CLI commands](https://developer.hashicorp.com/terraform/cli/commands)** (~20 min) — bookmark [`plan`](https://developer.hashicorp.com/terraform/cli/commands/plan) / [`apply`](https://developer.hashicorp.com/terraform/cli/commands/apply) flags (`-out`, `-target`, `-auto-approve`).

**Milestone:** You can read a `terraform plan` and correctly predict what each `+`/`~`/`-/+` line will do before running apply.

---

### ⬜ B4 — HCL language basics

**What it is:** HashiCorp Configuration Language — blocks, arguments, primitive/collection types, comments, and the top-level block kinds (`terraform`, `provider`, `resource`, `variable`, `output`, `locals`, `data`, `module`).

**Why you need it:** Every `.tf` file is HCL; fluency here is the difference between copying snippets and writing configuration.

**How to learn it:**

1. **Reference — [HCDocs "Configuration Syntax"](https://developer.hashicorp.com/terraform/language/syntax/configuration)** (~40 min) — read blocks/arguments/expressions; this is short and canonical.
2. **Book chapter — TID Ch 3** (~1.5 hrs) — the language deep-dive; work the examples in an editor.
3. **Interactive — rewrite your B2 project** (~1 hr) — split it into `main.tf` / `variables.tf` / `outputs.tf` by convention.

**Milestone:** You can author a multi-file HCL configuration by hand, using the correct block type for each purpose, without copy-paste.

---

### ⬜ B5 — Providers & resources

**What it is:** How the provider plugin model works, resource blocks, resource addresses, arguments vs attributes, and the resource dependency graph Terraform builds implicitly.

**Why you need it:** Resources are the unit of everything Terraform manages; understanding implicit dependencies (via attribute references) is essential to avoid ordering bugs.

**How to learn it:**

1. **Video — [TF2026 "Lifecycle & Providers" → "Resources"](https://youtu.be/l5qtFBsxZdk?t=2595)** (43:15, ~45 min) — see how a provider's resources map to real cloud APIs.
2. **Reference — [a real provider's docs (e.g. AWS provider)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)** (~ongoing) — learn to navigate the registry docs for arguments/attributes. ([Resources](https://developer.hashicorp.com/terraform/language/resources), [dependencies](https://developer.hashicorp.com/terraform/language/resources/behavior))
3. **Book chapter — TID Ch 3–4** (~1 hr) — implicit vs explicit dependencies and how the graph is derived.

**Milestone:** You can chain three resources where each references the previous one's attributes, and explain the resulting apply order without `depends_on`.

---

### ⬜ B6 — Input variables, outputs & locals

**What it is:** Parameterizing configs with `variable` (types, defaults, `.tfvars`, env vars, precedence), exposing values with `output`, and computing intermediates with `locals`.

**Why you need it:** Hard-coded configs can't be reused across environments; variables/outputs are how modules and pipelines pass data.

**How to learn it:**

1. **Interactive — HCTut ["Manage infrastructure" (input variables + outputs)](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-manage)** (~1 hr) — work the variables + outputs sections; try all variable-passing methods.
2. **Reference — [HCDocs "Input Variables"](https://developer.hashicorp.com/terraform/language/values/variables) precedence table** (~20 min) — memorize the override order (CLI > env > `.tfvars` > default). ([outputs](https://developer.hashicorp.com/terraform/language/values/outputs), [locals](https://developer.hashicorp.com/terraform/language/values/locals))
3. **Book chapter — TID Ch 3** (variables/outputs/locals) (~45 min) — when to use `locals` vs `variable`.

**Milestone:** You can parameterize your project so the same config deploys to two environments by swapping only a `.tfvars` file.

---

### ⬜ B7 — Expressions, operators & built-in functions

**What it is:** HCL expressions — references, conditionals (`? :`), `for` expressions, splat, string templates — and the built-in function library (`for_each` helpers, `lookup`, `merge`, `try`, `coalesce`, `templatefile`, etc.).

**Why you need it:** Dynamic, DRY configuration is impossible without expressions; the exam and real modules lean on them constantly.

**How to learn it:**

1. **Interactive — `terraform console`** (~1 hr) — open the REPL and experiment with `for`, `merge`, `try`, string templates against live values.
2. **Reference — [HCDocs "Functions"](https://developer.hashicorp.com/terraform/language/functions) + ["Expressions"](https://developer.hashicorp.com/terraform/language/expressions)** (~40 min) — skim the function categories; bookmark for lookup.
3. **Book chapter — TID Ch 5** (~1 hr) — expression patterns used in real configs.

**Milestone:** You can transform a list of maps into a keyed map with a `for` expression and use it to drive resource creation.

---

### ⬜ B8 — Data sources

**What it is:** `data` blocks that read existing infrastructure or provider info (AMI IDs, availability zones, existing VPCs) without managing it.

**Why you need it:** Real configs must reference things Terraform doesn't own; data sources are how you look them up at plan time.

**How to learn it:**

1. **Reference — [HCDocs "Data Sources"](https://developer.hashicorp.com/terraform/language/data-sources)** (~20 min) — the block syntax and when data is read (plan vs apply).
2. **Interactive — extend your project** (~45 min) — replace a hard-coded AMI/AZ/image with a `data` lookup.
3. **Book chapter — TID Ch 4** (data sources) (~30 min) — dependency implications of data reads.

**Milestone:** You can look up a resource you didn't create (e.g. the latest AMI or default VPC) and wire it into a managed resource.

---

### ⬜ B9 — State fundamentals

**What it is:** What `terraform.tfstate` is, why Terraform needs it (mapping config → real resources), what's in it, and why it must be protected and never hand-edited.

**Why you need it:** State is Terraform's source of truth; almost every advanced problem (drift, imports, backends, locking) is a state problem.

**How to learn it:**

1. **Video — [Krausen "Terraform Associate — Hands-On Labs" (state section)](https://krausen.io/course/hashicorp-certified-terraform-associate-hands-on-labs/)** (~30 min) — why state exists and what breaks without it.
2. **Reference — [HCDocs "State" overview](https://developer.hashicorp.com/terraform/language/state) + ["Sensitive Data in State"](https://developer.hashicorp.com/terraform/language/state/sensitive-data)** (~30 min) — note that state can hold secrets in plaintext.
3. **Book chapter — TID Ch 6** (state) (~1 hr) — anatomy of the state file; read but don't edit it.

**Milestone:** You can open a state file, explain how a resource address maps to a real cloud object, and articulate three reasons never to edit it by hand.

---

### ✅ Beginner Checkpoint

You are ready to advance when you can:
- Provision, modify, and destroy a multi-resource config against a real cloud provider from a clean directory.
- Parameterize that config with variables/outputs so it deploys to two environments.
- Read a `plan` accurately and explain what state is and why it matters.

---

## Intermediate

**Goal:** Build reusable modules, manage remote state safely, and handle real-world state operations — the level the Associate 004 exam validates.
**Estimated time:** ~45 hrs

---

### ⬜ I1 — Meta-arguments: count, for_each, depends_on

**What it is:** Creating multiple instances with `count` and `for_each`, addressing them (`[0]` vs `["key"]`), and forcing ordering with explicit `depends_on`.

**Why you need it:** Real infra needs N-of-a-thing; choosing `count` vs `for_each` correctly prevents the classic "changing the list re-creates everything" bug.

**How to learn it:**

1. **Video — [TF2026 "Loops & Dynamic Infrastructure"](https://youtu.be/l5qtFBsxZdk?t=11191)** (3:06:31, ~40 min) — see why `for_each` is safer than `count` for keyed resources.
2. **Reference — [HCDocs "count"](https://developer.hashicorp.com/terraform/language/meta-arguments/count) + ["for_each"](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) + [depends_on](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on)** (~30 min) — the addressing rules and when each is legal.
3. **Book chapter — TID Ch 5** (~1 hr) — the re-creation pitfall and how `for_each` keys avoid it.

**Milestone:** You can convert a `count`-based set of resources to `for_each` and explain why removing a middle element no longer destroys unrelated resources.

---

### ⬜ I2 — The lifecycle meta-argument

**What it is:** `lifecycle` blocks — `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by` — and how they alter the plan.

**Why you need it:** Zero-downtime replacements, protecting stateful resources, and ignoring externally-managed drift all depend on lifecycle rules.

**How to learn it:**

1. **Reference — [HCDocs "lifecycle" meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)** (~30 min) — each option and its plan effect.
2. **Interactive — experiment** (~45 min) — add `create_before_destroy` to a resource and watch the plan reorder to `+` before `-`.
3. **Book chapter — TID Ch 5** (lifecycle) (~30 min) — real use cases and gotchas.
   > 📌 OpenTofu 1.12 adds **dynamic `prevent_destroy`** (bind it to a variable); Terraform still requires a literal. See E3.

**Milestone:** You can configure a resource for zero-downtime replacement and protect a database from accidental destroy.

---

### ⬜ I3 — Dynamic blocks & complex types

**What it is:** Generating repeated nested blocks with `dynamic`, and modeling data with `object`/`map`/`list`/`set`/`tuple` and optional attributes.

**Why you need it:** Flexible modules need to emit variable numbers of nested blocks (ingress rules, tags) from typed input variables.

**How to learn it:**

1. **Reference — [HCDocs "dynamic blocks"](https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks) + ["Type Constraints"](https://developer.hashicorp.com/terraform/language/expressions/type-constraints)** (~40 min) — syntax and when `dynamic` is worth the readability cost.
2. **Interactive — build a security-group module** (~1 hr) — drive `ingress` rules from a list-of-objects variable via `dynamic`.
3. **Book chapter — TID Ch 5** (~30 min) — complex type constraints and `optional()`.

**Milestone:** You can write a module that accepts a list of rule objects and emits one nested block per rule with a `dynamic` block.

---

### ⬜ I4 — Using modules

**What it is:** Consuming modules — the registry, source addresses (registry/git/local), version constraints, passing inputs, and reading module outputs.

**Why you need it:** Almost no production config is flat; you compose from modules, and the exam tests module sourcing/versioning.

**How to learn it:**

1. **Interactive — HCTut ["Use registry modules in configuration"](https://developer.hashicorp.com/terraform/tutorials/modules/module-use)** (~45 min) — pull a registry module (e.g. AWS VPC) and wire it up.
2. **Reference — [HCDocs "Module Sources"](https://developer.hashicorp.com/terraform/language/modules/sources) + [version constraint syntax](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)** (~30 min) — `~>`, git refs, local paths.
3. **Book chapter — TUR Ch 4** (~1.5 hrs) — the classic module treatment; still the best explanation of inputs/outputs/composition.

**Milestone:** You can consume a versioned registry module, pass it inputs, and reference its outputs in your own resources.

---

### ⬜ I5 — Authoring modules

**What it is:** Writing your own modules — standard file layout, input validation, sensible outputs, composition over inheritance, and module design principles.

**Why you need it:** Reusable, testable modules are the core skill of both certs and of any real Terraform codebase.

**How to learn it:**

1. **Book chapter — TUR Ch 4 + Ch 8** (~2.5 hrs) — module design and "production-grade" module conventions.
2. **Reference — [HCDocs "Module Development"](https://developer.hashicorp.com/terraform/language/modules/develop) standards** (~40 min) — the standard module structure and publishing rules.
3. **Interactive — refactor** (~1.5 hrs) — extract your Beginner project into a reusable module with a clean input/output surface.

**Milestone:** You can package infrastructure into a module with validated inputs, documented outputs, and a README, and consume it from two callers.

---

### ⬜ I6 — Remote state & backends

**What it is:** Backends (S3+DynamoDB, HCP Terraform, GCS, azurerm), state locking, remote vs local state, and `terraform_remote_state` to share outputs.

**Why you need it:** Teams cannot share local state; remote state with locking is the baseline for any collaboration and is exam-critical.

**How to learn it:**

1. **Interactive — HCTut ["Migrate state from S3 to HCP Terraform"](https://developer.hashicorp.com/terraform/tutorials/cloud/migrate-remote-s3-backend-hcp-terraform)** (~1 hr) — migrate a local state to an S3 (or HCP) backend and observe locking.
2. **Reference — [HCDocs "Backends"](https://developer.hashicorp.com/terraform/language/backend) + ["State Locking"](https://developer.hashicorp.com/terraform/language/state/locking) + [terraform_remote_state](https://developer.hashicorp.com/terraform/language/state/remote-state-data)** (~40 min) — backend config, partial config, and lock behavior.
3. **Book chapter — TUR Ch 3** (~1.5 hrs) — the canonical remote-state + isolation discussion.

**Milestone:** You can migrate a project from local to remote state with locking and read another config's outputs via `terraform_remote_state`.

---

### ⬜ I7 — State management operations

**What it is:** The state-surgery toolkit — `import` (+ `import` blocks), `state mv`/`rm`, `refresh`, detecting and reconciling drift, and `moved`/`removed` config blocks.

**Why you need it:** Real infrastructure predates your config, gets renamed, and drifts; you must bring it under management without destroying it.

**How to learn it:**

1. **Interactive — HCTut ["Import"](https://developer.hashicorp.com/terraform/tutorials/state/state-import) + ["Manage resource drift"](https://developer.hashicorp.com/terraform/tutorials/state/resource-drift)** (~1.5 hrs) — import a manually-created resource and reconcile a deliberate drift.
2. **Reference — HCDocs [import block](https://developer.hashicorp.com/terraform/language/import), [moved](https://developer.hashicorp.com/terraform/language/moved), [removed](https://developer.hashicorp.com/terraform/language/resources/syntax#removing-resources), [`state` subcommands](https://developer.hashicorp.com/terraform/cli/commands/state)** (~45 min) — prefer config-driven `import`/`moved` over CLI surgery.
3. **Book chapter — TID Ch 6** (state operations) (~1 hr) — safe patterns and recovery.

**Milestone:** You can adopt an unmanaged cloud resource via an `import` block and rename a resource with a `moved` block — both with an empty plan afterward.

---

### ⬜ I8 — Provider configuration in depth

**What it is:** Multiple provider instances via `alias`, per-resource `provider` selection, multi-region/multi-account setups, provider version constraints, and authentication patterns.

**Why you need it:** Multi-region and multi-account deployments require aliased providers; version drift between team members causes silent breakage.

**How to learn it:**

1. **Reference — [HCDocs "Provider Configuration" + aliases](https://developer.hashicorp.com/terraform/language/providers/configuration)** (~40 min) — alias syntax and passing providers to modules.
2. **Interactive — deploy to two regions** (~1 hr) — use two aliased AWS providers in one config.
3. **Book chapter — TID Ch 4** (providers) (~30 min) — auth strategies and pinning.

**Milestone:** You can deploy the same resource to two regions from one config using aliased providers, and pin all provider versions in a lock file.

---

### ✅ Intermediate Checkpoint

You are ready to advance when you can:
- Author and consume versioned, validated modules with clean input/output surfaces.
- Run a team-safe setup: remote state, locking, pinned providers, multi-region via aliases.
- Import unmanaged resources, reconcile drift, and refactor with `moved`/`import` blocks to an empty plan.

**Certification target:** **Terraform Associate (004)** — validates B1–B9 and I1–I8 (plus intro HCP Terraform from A4). Attempt after this checkpoint using **Assoc** + **Krausen** practice exams.

---

## Advanced

**Goal:** Operate Terraform in production — tested, automated, governed, and secure — the level the Authoring & Operations Pro exam validates.
**Estimated time:** ~60 hrs

---

### ⬜ A1 — Provisioners, terraform_data & escape hatches

**What it is:** `provisioner` blocks (`local-exec`, `remote-exec`), `null_resource`/`terraform_data`, `connection` blocks — and, crucially, when *not* to use them.

**Why you need it:** Sometimes you must run a script or trigger a rebuild; you also need to recognize when a provisioner is a design smell to be replaced by a data source or provider feature.

**How to learn it:**

1. **Reference — [HCDocs "Provisioners"](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax) (incl. the "last resort" warning) + [terraform_data](https://developer.hashicorp.com/terraform/language/resources/terraform-data)** (~40 min) — read HashiCorp's own case against provisioners.
2. **Interactive — replace a provisioner** (~45 min) — take a `local-exec` hack and re-express it with `terraform_data` triggers or a data source.
3. **Book chapter — TID Ch 7 / TUR provisioners section** (~45 min) — legitimate vs illegitimate uses.

**Milestone:** You can use `terraform_data` with `triggers_replace` to force a controlled rebuild, and justify avoiding a provisioner in a given scenario.

---

### ⬜ A2 — Testing, validation & checks

**What it is:** The `terraform test` framework (`.tftest.hcl`), variable `validation` rules, `precondition`/`postcondition` blocks, and top-level `check` blocks for continuous assertions.

**Why you need it:** Untested modules break silently; the Pro exam explicitly tests validation and checks, and testing is what makes modules trustworthy.

**How to learn it:**

1. **Interactive — HCTut ["Write Terraform tests"](https://developer.hashicorp.com/terraform/tutorials/configuration-language/test)** (~1.5 hrs) — write unit + integration `.tftest.hcl` for a module.
2. **Reference — [HCDocs "Tests"](https://developer.hashicorp.com/terraform/language/tests), [Custom Conditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions), [Checks](https://developer.hashicorp.com/terraform/language/checks)** (~45 min) — the difference between validation, pre/postconditions, and checks.
3. **Book chapter — TUR Ch 9** (~2 hrs) — testing strategy (unit/integration/e2e) and Terratest for deeper Go-based testing.
   > 📌 `terraform test` post-dates TUR's main testing chapter — use HCDocs for the native framework, TUR for the strategy.

**Milestone:** You can write a `.tftest.hcl` suite that provisions a module, asserts on its outputs, and tears down — plus a `precondition` that fails a bad plan early.

---

### ⬜ A3 — Terraform in CI/CD automation

**What it is:** Running Terraform non-interactively in pipelines — `-input=false`, `-auto-approve`, saved plans (`plan -out` → `apply plan`), remote state, and PR-based plan/apply gating.

**Why you need it:** Production Terraform runs in automation, not on laptops; the Pro exam tests automation-friendly workflows.

**How to learn it:**

1. **Reference — [HCDocs "Automate Terraform" tutorial](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform)** (~40 min) — the non-interactive flag set and the plan-artifact pattern.
2. **Interactive — build a pipeline** (~2 hrs) — a GitHub Actions (or GitLab CI) workflow that runs `fmt`/`validate`/`plan` on PR and `apply` on merge.
3. **Book chapter — TUR Ch 10** (~1.5 hrs) — production CI/CD patterns and approval gates.

**Milestone:** You can build a pipeline that posts a plan on pull requests and applies a saved plan on merge, with remote state and locking.

---

### ⬜ A4 — HCP Terraform / Terraform Cloud

**What it is:** HashiCorp's managed platform — workspaces, VCS-driven and CLI-driven runs, remote execution, remote state, private module registry, and run tasks.

**Why you need it:** It's on both the Associate and Pro exams, and it's the most common way teams run Terraform at scale without building their own automation.

**How to learn it:**

1. **Interactive — HCTut ["HCP Terraform get started" track](https://developer.hashicorp.com/terraform/tutorials/cloud-get-started)** (~1.5 hrs) — connect a VCS repo, run a remote plan/apply, use remote state.
2. **Reference — [HCDocs "HCP Terraform"](https://developer.hashicorp.com/terraform/cloud-docs) [workspaces](https://developer.hashicorp.com/terraform/cloud-docs/workspaces) + [run workflow](https://developer.hashicorp.com/terraform/cloud-docs/run/remote-operations)** (~40 min) — workspace settings, variable sets, and the run lifecycle.
3. **Book chapter — TID Ch on HCP / TUR Ch 10** (~1 hr) — where managed platform fits vs self-hosted CI.
   > 📌 HCP free tier caps at **500 managed resources** (legacy free plan ended 2026-03-31).

**Milestone:** You can run a VCS-driven workspace in HCP Terraform that plans on PR, applies on merge, and stores state remotely.

---

### ⬜ A5 — Policy as Code

**What it is:** Governance guardrails — Sentinel (HashiCorp's policy language) and open-source OPA/Conftest — enforced against plans in HCP Terraform or CI.

**Why you need it:** Organizations must prevent non-compliant infra (untagged, wrong region, oversized) before apply; the Pro exam covers policy/governance.

**How to learn it:**

1. **Video — [HashiCorp "Introduction to Sentinel, Policy as Code Framework"](https://youtu.be/Vy8s7AAvU6g)** (~40 min) — what policy-as-code enforces and where it runs in the flow.
2. **Interactive — HCTut [Sentinel](https://developer.hashicorp.com/terraform/tutorials/policy/sentinel-policy) / [OPA](https://developer.hashicorp.com/terraform/tutorials/cloud/validation-enforcement) policy lab** (~1.5 hrs) — write a policy that blocks a plan violating a tagging rule.
3. **Reference — [HCDocs policy enforcement / Sentinel](https://developer.hashicorp.com/terraform/cloud-docs/policy-enforcement) + [OPA Conftest docs](https://www.conftest.dev/)** (~40 min) — Sentinel for HCP, OPA/Conftest for provider-agnostic CI.

**Milestone:** You can write a policy that fails any plan creating an untagged or oversized resource, and wire it into a run.

---

### ⬜ A6 — Secrets & sensitive data

**What it is:** Handling secrets — the `sensitive` flag, sensitive values in state, the Vault provider, and dynamic/short-lived provider credentials (OIDC into AWS/Azure/GCP).

**Why you need it:** State holds secrets in plaintext by default; long-lived cloud keys in pipelines are a top risk. The Pro exam tests sensitive-data best practices.

**How to learn it:**

1. **Reference — [HCDocs "Sensitive data in state"](https://developer.hashicorp.com/terraform/language/state/sensitive-data) + ["Dynamic Provider Credentials"](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials)** (~40 min) — why `sensitive` isn't encryption and how OIDC removes static keys.
2. **Interactive — HCTut [dynamic credentials lab](https://developer.hashicorp.com/terraform/tutorials/cloud/dynamic-credentials)** (~1.5 hrs) — configure OIDC so a pipeline assumes a role with no stored secret.
3. **Book chapter — TID secrets section / TUR secrets management** (~1 hr) — Vault integration and secret-injection patterns.

**Milestone:** You can run a pipeline that authenticates to a cloud via short-lived OIDC credentials (no static keys) and mark derived values `sensitive`.

---

### ⬜ A7 — Multi-environment & multi-account patterns

**What it is:** Structuring dev/stage/prod and multiple accounts/regions — CLI workspaces vs directory-per-env vs HCP workspaces, and DRY strategies.

**Why you need it:** Environment isolation done wrong causes cross-env blast radius; the Pro exam and every real org need a scalable layout.

**How to learn it:**

1. **Book chapter — TUR Ch 3 (isolation) + Ch 5** (~2 hrs) — file-layout / workspace tradeoffs; the definitive treatment.
2. **Reference — [HCDocs "Workspaces" (CLI)](https://developer.hashicorp.com/terraform/language/state/workspaces) vs [HCP workspaces](https://developer.hashicorp.com/terraform/cloud-docs/workspaces)** (~30 min) — understand why CLI workspaces are *not* environment isolation.
3. **Interactive — restructure** (~1.5 hrs) — lay out one module consumed by isolated dev/prod stacks with separate state.

**Milestone:** You can design an env layout where prod and dev have fully isolated state and blast radius, sharing modules but not state.

---

### ⬜ A8 — Refactoring at scale

**What it is:** Safely evolving large codebases — `moved`/`import`/`removed` blocks, module version bumps across consumers, splitting monolith state, and state migration.

**Why you need it:** Big Terraform codebases must be refactored without downtime or resource re-creation; this is a senior/Pro-level skill.

**How to learn it:**

1. **Reference — [HCDocs "Refactoring" (moved blocks)](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)** (~40 min) — config-driven refactors that keep the plan empty.
2. **Book chapter — TUR refactoring / TID Ch 6** (~1 hr) — splitting state and versioned module rollouts.
3. **Interactive — split a monolith** (~1.5 hrs) — carve one big config into two states with `moved`/`removed` and `state mv`, verifying empty plans.

**Milestone:** You can split a monolithic configuration into two independently-stated configs with no resource re-creation.

---

### ✅ Advanced Checkpoint

You are ready to advance when you can:
- Ship tested modules (`terraform test`, conditions, checks) through a PR-gated CI/CD pipeline.
- Run governed workflows in HCP Terraform with policy-as-code and OIDC (no static secrets).
- Structure multi-env/multi-account infra with isolated state and refactor at scale without re-creation.

**Certification target:** **Terraform Authoring & Operations Professional** — validates I5, A1–A8 (lifecycle, dynamic config, modules, providers, collaborative workflows, HCP). Lab-based; practice hands-on with **Pro** study path. Attempt after this checkpoint.

---

## Expert

**Goal:** Extend Terraform itself, architect it for large organizations, and master the tooling ecosystem.
**Estimated time:** ~70 hrs

---

### ⬜ E1 — Writing custom providers

**What it is:** Building a provider in Go with the Terraform Plugin Framework — schema, resources, data sources, CRUD, plan modifiers, and acceptance tests.

**Why you need it:** When no provider exists for an internal API, you write one; this is the deepest form of Terraform mastery.

**How to learn it:**

1. **Interactive — HCTut ["Implement a provider with the Plugin Framework"](https://developer.hashicorp.com/terraform/tutorials/providers-plugin-framework/providers-plugin-framework-provider)** (~4 hrs) — build a working provider against a sample API end to end.
2. **Reference — [TPF docs](https://developer.hashicorp.com/terraform/plugin/framework)** (~ongoing) — schema, resource lifecycle, plan modification, acceptance testing.
3. **Book chapter — TUR "extending Terraform" / provider dev material** (~2 hrs) — the mental model of the plugin protocol.

**Milestone:** You can build and locally install a custom provider exposing one resource with full CRUD and passing acceptance tests.

---

### ⬜ E2 — Terraform Stacks

**What it is:** Terraform Stacks — the newer construct for defining components and deployments to provision the same infrastructure across many environments/regions from one definition.

**Why you need it:** Stacks are HashiCorp's answer to multi-deployment orchestration that previously required Terragrunt or custom tooling; increasingly relevant for platform teams.

**How to learn it:**

1. **Reference — [HCDocs "Stacks" overview](https://developer.hashicorp.com/terraform/language/stacks) + configuration** (~1 hr) — components, deployments, and how Stacks differ from modules/workspaces.
2. **Interactive — HCTut [Stacks: "Deploy a Stack with HCP Terraform"](https://developer.hashicorp.com/terraform/tutorials/cloud/stacks-deploy)** (~2 hrs) — define a stack with multiple deployments and run it in HCP Terraform.
3. **Explainer — [HashiCorp "Terraform Stacks, explained"](https://www.hashicorp.com/en/blog/terraform-stacks-explained)** (~20 min) — see the deployment fan-out in practice; pair with a current Stacks demo on the [HashiCorp YouTube channel](https://www.youtube.com/@HashiCorp/search?query=terraform%20stacks).
   > 📌 Stacks is newer than both books — rely on HCDocs and verify feature availability (HCP vs CLI) as it evolves.

**Milestone:** You can define a stack with reusable components and deploy it to three environments from a single stack configuration.

---

### ⬜ E3 — OpenTofu deep dive

**What it is:** OpenTofu's divergence from Terraform — **state encryption**, provider/backend `for_each`, early variable evaluation, the `-exclude` flag, dynamic `prevent_destroy` — plus migration between the two.

**Why you need it:** OpenTofu is a genuine fork with features Terraform's open-source CLI lacks; choosing between them and migrating is a real strategic/technical decision.

**How to learn it:**

1. **Reference — [OTDocs "Migrating from Terraform"](https://opentofu.org/docs/intro/migration/) + [state encryption](https://opentofu.org/docs/language/state/encryption/)** (~1 hr) — what's OpenTofu-only and how state stays compatible.
2. **Interactive — enable state encryption** (~1 hr) — turn on OpenTofu client-side state encryption and confirm state is unreadable at rest.
3. **Book — TID (covers both)** (~1 hr) — re-read the sections contrasting the two tools with fresh eyes.

**Milestone:** You can migrate a project from Terraform to OpenTofu, enable state encryption, and list four features OpenTofu has that Terraform's open-source CLI does not.

---

### ⬜ E4 — Large-scale state & repo architecture

**What it is:** Organizing many states and many teams — Terragrunt for DRY/orchestration, monorepo vs multi-repo, dependency ordering across states, and remote-state composition.

**Why you need it:** At scale, flat repos and giant states collapse; deliberate architecture is what keeps plans fast and blast radius small.

**How to learn it:**

1. **Reference — [TG docs (Terragrunt)](https://terragrunt.gruntwork.io/docs/)** (~1.5 hrs) — DRY backends, `dependency` blocks, `run --all`, and where Terragrunt still beats native features. Terragrunt is the open-source route to strong dev/staging/prod isolation (directory-per-env, own backend/state each) — the open counterpart to proprietary HCP Terraform workspaces (see [[workspaces]]).
   > 📌 Terragrunt **1.0** shipped 2026-03-30 — first release with a backwards-compatibility commitment; `run-all` is now `run --all`. Works over both Terraform and OpenTofu.
2. **Book chapter — TUR Ch 3 + Ch 5** (~2 hrs) — state isolation and repo-structure tradeoffs at scale.
3. **Reference — [HashiCorp "Terraform mono-repo vs. multi-repo: the great debate"](https://www.hashicorp.com/en/blog/terraform-mono-repo-vs-multi-repo-the-great-debate)** (~30 min) — monorepo-vs-multirepo decisions in the wild, plus [native monorepo support](https://www.hashicorp.com/en/blog/terraform-adds-native-monorepo-support-stack-component-configurations-and-more).

**Milestone:** You can design a multi-team layout with per-component state, cross-state dependencies, and DRY backend config that keeps each plan small.

---

### ⬜ E5 — Debugging, performance & scaling

**What it is:** Diagnosing and speeding up Terraform — `TF_LOG` levels, the resource graph, `-parallelism`, provider plugin caching, `-refresh=false`, targeted plans, and large-state performance.

**Why you need it:** Slow plans and cryptic errors block whole teams; senior engineers must diagnose the graph and tune throughput.

**How to learn it:**

1. **Reference — [HCDocs "Debugging" (`TF_LOG`)](https://developer.hashicorp.com/terraform/internals/debugging) + [graph command](https://developer.hashicorp.com/terraform/cli/commands/graph)** (~40 min) — log levels and reading the dependency graph.
2. **Interactive — profile a slow plan** (~1.5 hrs) — enable the plugin cache, tune `-parallelism`, and measure the difference on a large config.
3. **Book chapter — TID troubleshooting / TUR gotchas** (~1 hr) — common failure modes and their fixes.

**Milestone:** You can diagnose a failing/slow apply from `TF_LOG` output and cut plan time on a large config via caching and parallelism tuning.

---

### ⬜ E6 — Platform engineering & self-service

**What it is:** Terraform as an internal platform — golden/opinionated modules, self-service via HCP no-code modules or an IDP (e.g. Backstage), run tasks, and org-wide drift detection.

**Why you need it:** The end state of Terraform maturity is letting product teams provision safely without writing raw HCL; this is the platform-engineering frontier.

**How to learn it:**

1. **Reference — [HCDocs "No-Code modules"](https://developer.hashicorp.com/terraform/cloud-docs/no-code-provisioning/module-design) + [Run Tasks](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/settings/run-tasks) + [private registry](https://developer.hashicorp.com/terraform/cloud-docs/registry)** (~1 hr) — the self-service building blocks.
2. **Video — [HashiCorp "Terraform for platform engineers" (Armon Dadgar)](https://www.hashicorp.com/en/resources/terraform-for-platform-engineers)** (~45 min) — how mature orgs expose Terraform to non-experts via golden modules.
3. **Interactive — publish a no-code module** (~1.5 hrs) — put a golden module in the private registry and provision it with no HCL.

**Milestone:** You can publish a governed golden module to a private registry and let another team provision it self-service with policy enforcement.

---

### ✅ Expert Checkpoint

You have mastered Terraform when you can:
- Build and ship a custom provider with the Plugin Framework.
- Architect large-scale, multi-team state with Stacks/Terragrunt and fast, small plans.
- Choose and migrate between Terraform and OpenTofu on real technical merits, and stand up a self-service platform with governance.

---

## Suggested study sequence

```
Beginner (B1–B9)        → ~30 hrs
    ↓
Intermediate (I1–I8)    → ~45 hrs  →  [Terraform Associate 004]
    ↓
Advanced (A1–A8)        → ~60 hrs  →  [Authoring & Operations Professional]
    ↓
Expert (E1–E6)          → ~70 hrs
```

**You are currently here:** Beginner — B1 done (Ch 1 written). Next up: **B2 (Install, providers & your first project)**.

---

## Sources consulted

- HashiCorp Developer — Certifications / Infrastructure Automation — https://developer.hashicorp.com/certifications/infrastructure-automation
- HashiCorp Developer — Terraform Associate 004 study path — https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-study-004
- HashiCorp Developer — Terraform Authoring & Operations Pro exam content — https://developer.hashicorp.com/terraform/tutorials/pro-cert/pro-review
- OpenTofu 1.12 release coverage (2026-05) — InfoQ
- Terraform CLI release notes (1.14.7, 2026-03)
- *Terraform in Depth* (Manning) and *Terraform: Up & Running* 3rd ed (O'Reilly) — tables of contents
