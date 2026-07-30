# Learning Path: Terraform (and OpenTofu)

> **Current stable versions:** Terraform CLI **1.15.8** (1.15.0 released 2026-04-29, BSL 1.1) · OpenTofu **1.12.4** (1.12.0 released 2026-05-14, MPL 2.0)
> **Local stack:** Terraform CLI + a cloud account (AWS recommended for cert alignment); OpenTofu optional as a drop-in.
>
> **How to read this page.** Topics are the primary unit. Each topic has a "How to learn it" section that
> recommends a multi-modal path — video first, then hands-on, then depth reading, then reference docs.
> Resources serve the topics; they are not the organizing structure. Terraform and OpenTofu share HCL,
> providers, and state format — learn either; differences are called out where they matter (see E3).
>
> **Status markers.** ⬜ not started · ✅ done, chapter written · 🔄 **revisit** — the chapter exists but
> later research changed or contradicted what it says, so it needs a re-read before the topic counts as
> done again. A 🔄 topic always names what changed and why, so the revisit is actionable rather than a
> vague doubt. Checkpoints still count a 🔄 topic as written.

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
| **KK** | KodeKloud — Terraform for Beginners / free labs (browser, no cloud account) | Interactive labs (free) | [free labs](https://kodekloud.com/free-labs/terraform) · [Coursera mirror (audit free)](https://www.coursera.org/learn/terraform-for-the-absolute-beginner) |
| **FCC** | freeCodeCamp — HashiCorp Terraform Associate Certification Course | Video course (free, YouTube) | youtube.com (search "freeCodeCamp Terraform Associate") |
| **CLX** | Collabnix — Terraform Hands-on Labs (init/plan/apply, beginner→advanced) | Interactive labs (free) | [collabnix.github.io/terraform](https://collabnix.github.io/terraform/) |
| **TF2026** | Rahul Oli — *Terraform Complete Course in One Video: Beginner to Advanced* (YouTube, Apr 2026, 6h23m) | Video course | [youtu.be/l5qtFBsxZdk](https://youtu.be/l5qtFBsxZdk) |
| **Krausen** | Bryan Krausen — Terraform Associate course + practice exams | Video + practice (paid) | [krausen.io hands-on labs](https://krausen.io/course/hashicorp-certified-terraform-associate-hands-on-labs/) · [004 practice exams](https://www.udemy.com/course/terraform-associate-004-practice-exams/) |
| **KL** | Krausen — *terraform-associate-labs* (free 004 labs, AWS/Azure/GitHub, runs in free Codespaces; tested TF 1.12.2) | Interactive labs (free, open-source) | [github.com/btkrausen/terraform-associate-labs](https://github.com/btkrausen/terraform-associate-labs) · local clone: `C:\opt\learn\terraform\repos\terraform-associate-labs` |
| **TPF** | Terraform Plugin Framework docs | Official docs | https://developer.hashicorp.com/terraform/plugin/framework |
| **TG** | Terragrunt docs (Gruntwork) | Official docs | https://terragrunt.gruntwork.io/docs |

!!! warning "📌 TUR targets Terraform ~1.1"
    **TUR** targets Terraform ~1.1. Core concepts (modules, state, testing philosophy) are still the best treatment available, but verify newer syntax (`terraform test`, `import`/`removed` blocks, Stacks) against current **HCDocs**.

---

## Certifications

| Cert | Provider | Level | Topics tested | Fee | Format | When to attempt |
|---|---|---|---|---|---|---|
| **Terraform Associate (004)** | HashiCorp | Intermediate exit | IaC concepts · fundamentals (providers/state) · core workflow · HCL config language · modules (use + author) · state management · infrastructure maintenance · HCP Terraform | $70.50 | 1 hr, ~57 multiple-choice, valid 2 yrs; tests Terraform 1.12 | After Intermediate |
| **Terraform Authoring & Operations Professional** | HashiCorp | Advanced exit | resource lifecycle · dynamic config & troubleshooting · collaborative workflows · modules · providers · HCP Terraform (MC only) | (see HashiCorp) | Lab-based (hands-on), AWS provider; Azure variant late 2026 | After Advanced |

!!! note "004 replaces 003"
    **004 replaces 003** (retired 2026-01-08). If you see 003 study material, the content is ~90% the same but use 004 resources where possible. The Pro exam assumes deep HCL + CLI fluency and real cloud experience.

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

!!! example "🧪 Labs (KK)"
    None — KodeKloud's IaC intro (*Challenges with Traditional IT* / *Types of IaC Tools* / *Why Terraform?*) is lecture-only. First KodeKloud lab is *HCL Basics* (→ B2/B4).

**Milestone:** You can explain in two sentences why Terraform is declarative and how it differs from Ansible and from CloudFormation.

---

### ✅ B2 — Install, providers & your first project

**What it is:** Installing the Terraform (or OpenTofu) CLI, wiring cloud credentials, declaring a `required_providers` + `provider` block, and laying out a first working directory.

**Why you need it:** Nothing runs until the CLI, a provider plugin, and credentials are in place; project layout mistakes here cause pain forever.

**How to learn it:**

1. **Interactive — HCTut ["Install Terraform"](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) + ["Create infrastructure"](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create)** (~1 hr) — follow the AWS (or Docker) quick-start end to end in your own account. (Captured notes: [[tf-install-cli]], [[tf-aws-create]].)
2. **Reference — [HCDocs "Provider Requirements"](https://developer.hashicorp.com/terraform/language/providers/requirements)** (~20 min) — understand `required_providers`, source addresses, and version pinning. ([Install](https://developer.hashicorp.com/terraform/install)) (Captured notes: [[provider-requirements]]; the version-constraint operator syntax used for pinning — `~>`, `>=`, ranges — is in [[tf-expr-version-constraints]].)
3. **Book chapter — TID Ch 2** (~1 hr) — first-project walkthrough; note the `.terraform/` and lock-file layout.

!!! example "🧪 Labs"
    - **KL:** [Lab 01 — getting started](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_01_getting_started_with_terraform) · [Lab 02 — create your first resource](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_02_create_your_first_resource). Free, runs in Codespaces.
    - **KK:** [KodeKloud free labs](https://kodekloud.com/free-labs/terraform) — *HCL Basics* (first `init`→`plan`→`apply` run) · *Version Constraints* (provider pinning + the `.terraform.lock.hcl` file).

**Milestone:** You can stand up a fresh directory, `terraform init` it, and provision one real resource (an S3 bucket or a Docker container) from scratch.

---

### ✅ B3 — The core workflow: init / plan / apply / destroy

**What it is:** The four-command loop — `init` (download providers, set up backend), `plan` (compute a diff), `apply` (execute), `destroy` (tear down) — plus the dependency lock file.

**Why you need it:** This loop is the heartbeat of Terraform; the Associate exam tests it heavily and every workflow is built on it.

**How to learn it:**

1. **Interactive — HCTut ["Manage infrastructure"](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-manage) + ["Destroy infrastructure"](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-destroy)** (~45 min) — run a full modify-then-destroy cycle; read the plan output symbols (`+`, `-`, `~`, `-/+`). (The init/validate/apply half of this loop is captured in [[tf-aws-create]]; the modify half — in-place `~` update vs `-/+` replacement, the `-out` warning, and dependency-graph ordering — is captured in [[tf-aws-manage]]; the teardown half — remove-from-config vs `terraform destroy`, the `-` symbol, and reverse-dependency destroy order — is captured in [[tf-aws-destroy]].)
2. **Video — [Krausen "Terraform Associate — Hands-On Labs" (core-workflow section)](https://krausen.io/course/hashicorp-certified-terraform-associate-hands-on-labs/)** (~40 min) — walks the plan/apply lifecycle with cert framing. Free substitutes in the callout below.
3. **Reference — [HCDocs "Dependency Lock File"](https://developer.hashicorp.com/terraform/language/files/dependency-lock)** (~25 min) — the fourth thing `init` does. Captured as [[tf-dependency-lock]]: the lock file records **providers only** (module versions are never locked — pin them with an exact constraint), `init` re-selects the locked version unless `-upgrade` forces re-resolution, and checksum verification follows a **trust-on-first-use** model. Learn to read the four kinds of lock-file diff (new provider · upgraded version · new checksums · removed provider), and know why `zh:` and `h1:` hashes coexist.
4. **Reference — [HCDocs CLI commands](https://developer.hashicorp.com/terraform/cli/commands)** (~20 min) — bookmark [`plan`](https://developer.hashicorp.com/terraform/cli/commands/plan) / [`apply`](https://developer.hashicorp.com/terraform/cli/commands/apply) flags (`-out`, `-target`, `-auto-approve`). This index is the **complete command surface** — the path teaches the four-command loop, but a complete operator also knows the everyday utilities: **`terraform fmt`** (canonical formatting), **`terraform validate`** (config-only checks), **`terraform show`** (render state/plan, `-json` for tooling), **`terraform output`** (read outputs, `-json` for scripts), **`terraform graph`** (emit the dependency graph as Graphviz — see [[tf-cmd-graph]]; full treatment in E5), **`terraform get`**, **`terraform providers`**, **`terraform version`**. The global **`terraform -chdir=DIR <cmd>`** option runs any command as if launched in `DIR` — cleaner than `cd`-ing around in scripts. The whole surface is captured as a one-row-per-command reference in [[tf-cli-commands]]; enable shell completion once with `terraform -install-autocomplete`. Five of those utilities — `graph`, `output`, `show`, `state list`, `state show` — are grouped by the docs as **Inspecting Infrastructure**, captured in [[tf-cli-inspect]] (with [[tf-cmd-output]] and [[tf-cmd-state-list]] for the two with the most surface; the latter has a **`-id=` reverse lookup** that answers "which resource owns this cloud object?"): read-only commands whose stated purpose is to "**integrate other tools with Terraform's infrastructure data**", which is the same reason [[tf-state]] names the `-json` forms as the supported parse targets rather than the state file.

!!! tip "💰 Free alternatives to the Krausen paid course (step 2)"
    Any one substitutes for step 2's paid Krausen course.

    - **KL** — [Krausen's *own* free labs repo](https://github.com/btkrausen/terraform-associate-labs) (cloned locally at `C:\opt\learn\terraform\repos\terraform-associate-labs`). Lab 01 (getting started) + Lab 05 (state/data/CLI) cover this loop; runs in free Codespaces, no local setup. **Best free match** — it's the paid course's hands-on content, open-sourced.
    - **HCTut Get Started** (step 1 above) is the official free 1:1 — it *is* the init→plan→apply→destroy walkthrough.
    - **KK** — [KodeKloud free labs](https://kodekloud.com/free-labs/terraform) / [Coursera "Terraform for the Absolute Beginner"](https://www.coursera.org/learn/terraform-for-the-absolute-beginner) run the loop **in-browser with no cloud account**. B3-relevant labs: *HCL Basics* (first `init`→`plan`→`apply`→`destroy`) + *Terraform Commands* (`fmt`/`validate`/`show`/`output` surface); the *Update and Destroy Infrastructure* lesson pairs with *HCL Basics*.
    - **FCC** — freeCodeCamp's full Terraform Associate course on YouTube (free lecture+lab video).
    - **CLX** — [Collabnix Terraform Hands-on Labs](https://collabnix.github.io/terraform/) (free, open, init-plan-apply).

!!! note "📌 Force a rebuild with `-replace`"
    To force one resource to be destroyed and recreated, use **`terraform apply -replace=ADDRESS`** (Terraform ~0.15.2+). This **supersedes the deprecated `terraform taint` / `untaint`** commands, which mutated state out-of-band; `-replace` shows the recreation in the plan first, so you review it before it happens. (See [[feature-history]].)

!!! note "📌 Lock-file checksums across platforms"
    The lock file records provider **checksums**. Use `terraform providers lock` to record hashes for *all* platforms (not just yours) so CI on Linux and a dev laptop on macOS agree. OpenTofu **1.12** does this automatically at `tofu init` (full cross-platform `zh:`+`h1:` set). Cross-platform mismatches are a classic "works on my machine" `init` failure. (See [[feature-history]], [[opentofu-feature-history]].)

    Two ways to land in that failure, per [[tf-dependency-lock]]. Installing a provider **for the first time from a filesystem or network mirror** means Terraform can only verify checksums for the platform it ran on, so it records only those — the config is then unusable elsewhere. Installing from an **origin registry with signed checksums** avoids this, because Terraform accepts the whole signed set and records every platform's hashes at once. The `h1:` entries that keep appearing in your diffs afterwards are Terraform migrating from the legacy `zh:` (zip-archive hash) to `h1:` (package-contents hash) as it sees the provider on new platforms.

!!! note "📖 Deep-dive: how the plan is actually computed"
    The four-command loop is the *what*; the *how* is the plan engine. **TID Ch 5** ("The Terraform plan") is the definitive treatment — captured as [[05-terraform-plan]]: the resource graph (DAG) Terraform builds and walks, the plan-output symbols (`+`/`-`/`~`/`-/+`, `(known after apply)`, read bottom-up), the three **planning modes** (default / destroy / refresh-only, each starting with a refresh), the two apply paths (own-plan vs saved-plan file), `-replace` vs deprecated `taint`, `-target` (an antipattern), and the graph-born pitfalls (cycles, cascading replacements, hidden deps). Cross-book synthesis in [The dependency graph](topics/dependency-graph.md) and [Core workflow](topics/core-workflow.md).

**Milestone:** You can read a `terraform plan` and correctly predict what each `+`/`~`/`-/+` line will do before running apply.

---

### ✅ B4 — HCL language basics

**What it is:** HashiCorp Configuration Language — blocks, arguments, primitive/collection types, comments, and the top-level block kinds (`terraform`, `provider`, `resource`, `variable`, `output`, `locals`, `data`, `module`).

**Why you need it:** Every `.tf` file is HCL; fluency here is the difference between copying snippets and writing configuration.

**How to learn it:**

1. **Reference — [HCDocs "Configuration Syntax"](https://developer.hashicorp.com/terraform/language/syntax/configuration)** (~40 min) — read blocks/arguments/expressions; this is short and canonical. Captured as [[tf-config-syntax]] (arguments vs blocks, labels, identifiers, comments, UTF-8/line-endings). Pair it with the official [**Style Guide**](https://developer.hashicorp.com/terraform/language/style) for idiomatic naming, file layout, and formatting conventions (guidance, not a feature — but it's what "writing it right" means), captured as [[tf-style-guide]] (formatting/`fmt`, naming, param order, file layout, `.gitignore`, version pinning, module/repo structure, secrets, testing, policy).
2. **Book chapter — TID Ch 2 §2.2 "Block syntax"** (~1.5 hrs) — the language deep-dive (block types, labels/subtypes, arguments vs subblocks, attributes, ordering, style); work the examples in an editor. (Captured notes: [[02-hcl-components]].)
3. **Interactive — rewrite your B2 project** (~1 hr) — split it into `main.tf` / `variables.tf` / `outputs.tf` by convention.

!!! note "📌 JSON-equivalent syntax"
    HCL has a **JSON-equivalent syntax** — [`*.tf.json`](https://developer.hashicorp.com/terraform/language/syntax/json) and `*.tfvars.json` are parsed the same as `.tf`/`.tfvars`. You rarely hand-write it, but it's the format machine-generated configs (codegen, other tools) emit, so recognize it. (See [[feature-history]].)

!!! note "📌 Override files"
    A file named `override.tf` or ending `_override.tf` ([HCDocs](https://developer.hashicorp.com/terraform/language/files/override)) is loaded *last* and merges its blocks into matching ones, replacing set arguments. Handy for local/temporary tweaks; use sparingly since it hides config from the primary files.

!!! example "🧪 Labs (KK)"
    [KodeKloud — **Terraform HCL** free lab](https://kodekloud.com/free-labs/terraform/terraform-hcl) — the dedicated HCL blocks/arguments lab, the exact B4 topic. (Krausen's [KL labs](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs) have **no** B4 lab — lab 01 is setup, lab 02 jumps straight to a first resource; they skip pure syntax.)

**Milestone:** You can author a multi-file HCL configuration by hand, using the correct block type for each purpose, without copy-paste.

---

### ✅ B5 — Providers & resources

**What it is:** How the provider plugin model works, resource blocks, resource addresses, arguments vs attributes, and the resource dependency graph Terraform builds implicitly.

**Why you need it:** Resources are the unit of everything Terraform manages; understanding implicit dependencies (via attribute references) is essential to avoid ordering bugs.

**How to learn it:**

1. **Video — [TF2026 "Lifecycle & Providers" → "Resources"](https://youtu.be/l5qtFBsxZdk?t=2595)** (43:15, ~45 min) — see how a provider's resources map to real cloud APIs.
2. **Reference — [a real provider's docs (e.g. AWS provider)](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)** (~ongoing) — learn to navigate the registry docs for arguments/attributes. See [[aws-provider]] and [[google-provider]] for captured overviews (example usage, credential precedence, key provider arguments) — and the [Providers topic page](topics/providers.md) for an AWS-vs-GCP config/auth comparison. For the `resource` block how-to (address, `timeouts`, meta-arg map, built-in/local-only resources) see [[tf-configure-resource]]. ([Resources](https://developer.hashicorp.com/terraform/language/resources) — captured as [[tf-resources]], [dependencies](https://developer.hashicorp.com/terraform/language/resources/behavior)) See [[tf-aws-create]] for the resource-address / type-name / implicit-reference walkthrough on a real `aws_instance`, and [[tut-resource]] (Configuration Language tutorial) for the explicit **arguments vs attributes vs meta-arguments** taxonomy plus a `random_pet` + `aws_security_group` build (`vpc_security_group_ids` as a list, reading the Registry argument reference).
3. **Book chapter — TID Ch 2 §2.4–2.5 + §2.7.3, and Ch 5 §5.1–5.2** (~1 hr) — providers and resources, then implicit vs explicit dependencies and how the graph is derived (Ch 5 is the DAG chapter). An attribute reference *is* the dependency edge; see [[dependency-graph]] for the two inputs the DAG is built from, and why nothing warns when one is missing.

!!! example "🧪 Labs"
    - **KL:** [Lab 03 — variables & dependencies](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_03_working_with_variables_and_dependencies) · [Lab 04 — managing multiple resources](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_04_managing_mulitple_resources).
    - **KK:** [KodeKloud free labs](https://kodekloud.com/free-labs/terraform) — *Terraform Providers* · *Multiple Providers* · *Resource Attributes* · *Resource Dependencies*.

**Milestone:** You can chain three resources where each references the previous one's attributes, and explain the resulting apply order without `depends_on`.

---

### ✅ B6 — Input variables, outputs & locals

**What it is:** Parameterizing configs with `variable` (types, defaults, `.tfvars`, env vars, precedence), exposing values with `output`, and computing intermediates with `locals`.

**Why you need it:** Hard-coded configs can't be reused across environments; variables/outputs are how modules and pipelines pass data.

**How to learn it:**

1. **Interactive — HCTut ["Manage infrastructure" (input variables + outputs)](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-manage)** (~1 hr) — work the variables + outputs sections; try all variable-passing methods. (Captured in [[tf-aws-manage]] — `variables.tf`/`outputs.tf` split, `-var` on the CLI, `terraform output`.) For a deeper variables-only hands-on covering **every type** (string/number/bool/list/map + structural), `.tfvars` files, multiple `validation` blocks, and live `terraform console` debugging, see [[tut-variables]] (Configuration Language collection).
2. **Reference — [HCDocs "Input Variables"](https://developer.hashicorp.com/terraform/language/values/variables) precedence table** (~20 min) — memorize the override order (CLI > env > `.tfvars` > default). (Captured in [[tf-input-variables]] — full precedence table, `sensitive`/`ephemeral`, `validation`, undeclared-variable behavior, and the `const` attribute for init-time evaluation. The argument-level spec — every `variable` argument, reserved names, type/validation/nullable/deprecated — is in [[tf-block-variable]].) ([outputs](https://developer.hashicorp.com/terraform/language/values/outputs) — captured in [[tf-outputs]]: the four purposes, `module.<child>.<output>` access, and `sensitive`/`ephemeral` outputs — with the full argument spec (`type`, `precondition`, `depends_on`, `deprecated`) in [[tf-block-output]], and the hands-on `terraform output` / `-raw` / `-json` workflow in [[tut-outputs]]; [locals](https://developer.hashicorp.com/terraform/language/values/locals) — captured in [[tf-locals]]: `locals` block vs singular `local.` reference, module-only scope, and the readability tradeoff; hands-on in [[tut-locals]] — the `merge(var.tags, local.required_tags)` minimum-tags pattern and the locals-can-be-dynamic-but-variables-must-be-literal contrast)
3. **Book chapter — TID Ch 3** (variables/outputs/locals) (~45 min) — when to use `locals` vs `variable`.

!!! note "📌 Output `type` (Terraform 1.15)"
    Terraform **1.15** added a `type` attribute to `output` blocks — outputs can now carry the same type constraints (and documentation value) variables always have. Prefer typing the outputs of any module others consume: the constraint is checked, and it documents the interface. There is a second-order effect worth knowing but **not** worth overselling: a fully-typed output set makes `module.<NAME>` a real `list`/`map` under `count`/`for_each` instead of a `tuple`/`object` (`GetModule` branches on "does the module fully define all output types"; verified 1.15.8, Ch 7 §3). Callers almost never notice, because a tuple splats, converts, and satisfies a `list(object(...))` constraint just as a list does — the gain is exactness and clearer errors, not new capability. **Resources have no such switch**, always structural (Ch 7 §3). **OpenTofu has no typed outputs** (TF-only as of OT 1.12.4). Evidence: [[conditional-branch-evaluation]]. (See [[tf115-ot112-features]]; the full `output` argument spec is in [[tf-block-output]].)

!!! note "📌 `nullable` variable argument (TF 1.1)"
    The **`nullable`** variable argument (TF 1.1) controls whether a caller may pass `null`. Set `nullable = false` to forbid it (and fall back to the `default` when `null` is supplied) — useful for required-but-defaulted inputs. (See [[feature-history]].)

!!! example "🧪 Labs"
    - **KL:** [Lab 03 — variables & dependencies](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_03_working_with_variables_and_dependencies) · [Lab 07 — local values](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_07_simplify_code_with_local_values).
    - **KK:** [KodeKloud free labs](https://kodekloud.com/free-labs/terraform) — *Variables* · *Using Variables in Terraform* · *Output Variables*.

**Milestone:** You can parameterize your project so the same config deploys to two environments by swapping only a `.tfvars` file.

---

### ✅ B7 — Expressions, operators & built-in functions

**What it is:** HCL expressions — references, conditionals (`? :`), `for` expressions, splat, string templates — and the built-in function library (`for_each` helpers, `lookup`, `merge`, `try`, `coalesce`, `templatefile`, etc.).

**Why you need it:** Dynamic, DRY configuration is impossible without expressions; the exam and real modules lean on them constantly.

**How to learn it:**

1. **Interactive — `terraform console`** (~1 hr) — open the REPL and experiment with `for`, `merge`, `try`, string templates against live values. [[tut-variables]] shows the console workflow concretely (list indexing, `slice()`, map key lookup) plus `regexall()` in validation and `${}` string interpolation. (Gotcha: the console loads config only at startup — restart to pick up edits.)
2. **Reference — [HCDocs "Functions"](https://developer.hashicorp.com/terraform/language/functions) + ["Expressions"](https://developer.hashicorp.com/terraform/language/expressions)** (~40 min) — skim the function categories; bookmark for lookup. The **conditional (ternary) `cond ? a : b`** is captured in [[tf-conditionals]] — both result values must share a type (else auto-convert; prefer explicit `tostring()`), plus the condition-building cookbook (`contains`, `length(...) != 0` over `== []`, `for` + `alltrue`/`anytrue`, and **`can()`** to turn an error-throwing expression into a bool). This page is the **exhaustive function list**, captured as [[tf-functions]] — the full built-in catalogue linked by category (numeric, string, collection, encoding, filesystem, date/time, hash/crypto, IP, type conversion, provider-defined `provider::terraform::*`), each row marking whether Stacks config (`.tfcomponent.hcl`/`.tfdeploy.hcl`) supports it, plus the `terraform console` experimentation note. The path teaches the *skill* of using functions, not each of the ~150 individually; treat [[tf-functions]] + [[feature-history]] as the complete catalogue (e.g. `strcontains`/`plantimestamp` landed in 1.5, `templatestring` in 1.9). `terraform metadata functions -json` (TF 1.4+) dumps every function's signature machine-readably — mostly for editor/language-server tooling. The **Expressions section** is captured page-by-page, mirroring the HCDocs sidebar: [[tf-expressions]] (section overview — the expression kinds and `terraform console`), [[tf-expr-types]] (types & values, `null`, auto-conversion), [[tf-expr-strings]] (string literals, heredocs, `${}`/`%{}` template interpolation & directives, whitespace stripping), [[tf-expr-references]] (referencing resources/vars/locals/`path.*`/`terraform.workspace`, plus unknown/sensitive values), [[tf-expr-operators]] (arithmetic/equality/comparison/logical + order of operations — note the `var.list == []` `tuple([])` gotcha), [[tf-expr-function-calls]] (call syntax, `...` argument expansion, sensitive-argument propagation, plan-time vs apply-time `file`/`timestamp`/`uuid`), [[tf-expr-for]] (`for` transforms, `if` filtering, grouping mode with `...`, element ordering), and [[tf-expr-splat]] (the `[*]` splat shorthand for `for`, single-value-as-list for optional `null` inputs in `dynamic` `for_each`, and the legacy `.*` form to avoid).
3. **Book chapter — TID Ch 4** (Expressions and iterations) (~1.5 hrs) — TID's dedicated expressions/functions/iteration chapter: operators, standard-library + provider-defined functions, string templates, regex, type conversion, `try`/`can`, and `for`/splat. Captured as [[04-expressions-iterations]]. (A B7-adjacent pitfall — the *plan-time-known* limit on computed values in `count`/`for_each` — is captured from the plan side in [[05-terraform-plan]] §5.7 *Calculated values and iterations*; it belongs mostly to I1.)

!!! note "📌 `convert()` (Terraform 1.15 — Terraform-only)"
    Terraform **1.15** added the `convert(value, type)` function for precise inline type conversion — cleaner than the old `tolist`/`tomap`/`toset` juggling in tricky spots. **Terraform-only — OpenTofu has no `convert()`** (open request [opentofu #2630](https://github.com/opentofu/opentofu/issues/2630), open, filed 2025-03-25). What OpenTofu lacks is the *function*, not the capability: `convert()` is an inline shortcut for the machinery every `type =` constraint already runs, so a typed **variable** (root or module input) performs the identical coercion, extra object attributes discarded and all (verified on OpenTofu 1.12.4). The `toType` casters cover primitives and collections in both tools, but they **cannot** express an object/tuple schema — so the portable answer there is a declared boundary, not a caster. OpenTofu has no typed `output` either (that's TF 1.15+), so a variable is the boundary you get. Evidence: [[conditional-branch-evaluation]]. (See [[tf115-ot112-features]].)

!!! note "📌 The type system — collection vs structural, and why only two types have a literal"
    The two families are defined by **HCL's own spec**, not by Terraform docs convention: **collection** types (`list`/`map`/`set`) "combine together an arbitrary number of values of some other single type"; **structural** types (`tuple`/`object`) are "constructed by combining other types", each position or key carrying its own type. Everything else follows. **Brackets always build a `tuple`, braces always build an `object`** — there is no list, set, or map literal anywhere in the language. A collection needs one shared element type the syntax never states, so it needs **unification**, which needs a target type to aim at: a `type =` constraint, a provider schema, or an explicit `to*` call. Hence there is no `totuple()`/`toobject()` — the three collection casters exist precisely because those are the three types you can't write down. The spec's **type-identity** rules are the root of the `var.list == []` gotcha (a `list(string)` and a `tuple([])` are simply different types) and of a tuple's length being part of its type. Ch 7 §2 covers the value side; the constraint side (`type =`, `optional()`) is **I3**. Evidence: [[conditional-branch-evaluation]].

!!! note "📌 Provider-defined functions (TF 1.8)"
    Beyond the built-ins, **provider-defined functions** (TF 1.8) let a provider ship its own functions, called as `provider::<name>::<fn>(...)` — e.g. `provider::aws::arn_parse(...)`. Available in the AWS, Google, and Kubernetes providers among others. Authoring them is E1. (See [[feature-coverage-matrix]].)

!!! note "📌 `templatestring()` (Terraform 1.9)"
    Terraform **1.9** added **`templatestring(ref, vars)`** — like `templatefile()`, but renders a template string obtained at runtime (e.g. from a data source) instead of a file on disk. (See [[feature-history]].)

!!! note "📌 Short-circuit `&&` / `||` (OpenTofu 1.10, Terraform 1.12)"
    Logical operators now **short-circuit** (`&&`/`||` stop evaluating once the result is decided), so guards like `var.x != null && var.x.enabled` no longer error on the null case. **OpenTofu shipped it first in 1.10**; **Terraform followed in 1.12**. Boolean-only — the ternary `? :` still type-checks both branches. (See [[feature-history]].)

!!! note "📌 Built-in named values"
    Learn the **built-in named values** you can reference anywhere: **`path.module`** / **`path.root`** / **`path.cwd`** (filesystem paths, e.g. for `templatefile`), **`terraform.workspace`** (current CLI workspace name), **`count.index`**, **`each.key`** / **`each.value`** (inside `count`/`for_each`), **`self`** (inside provisioners), and **`terraform.applying`** (ephemeral bool, true during apply; TF 1.10). ([HCDocs references](https://developer.hashicorp.com/terraform/language/expressions/references))

!!! example "🧪 Labs (KK)"
    None in the Basics course — KodeKloud covers functions/conditional expressions in a later section with no standalone lab; practice in `terraform console` (step 1) instead.

**Milestone:** You can transform a list of maps into a keyed map with a `for` expression and use it to drive resource creation.

---

### ✅ B8 — Data sources

**What it is:** `data` blocks that read existing infrastructure or provider info (AMI IDs, availability zones, existing VPCs) without managing it.

**Why you need it:** Real configs must reference things Terraform doesn't own; data sources are how you look them up at plan time.

**How to learn it:**

1. **Reference — [HCDocs "Data Sources"](https://developer.hashicorp.com/terraform/language/data-sources)** (~20 min) — the block syntax and when data is read (plan vs apply). Notes: [[tf-data-sources]] — the plan-vs-apply deferral rules, custom conditions, `count`/`for_each` on data blocks, aliased providers; [[tf-block-data]] — the argument catalog (which meta-arguments a `data` block takes, `lifecycle` limited to pre/postcondition).
2. **Interactive — [HCDocs "Query data sources" tutorial](https://developer.hashicorp.com/terraform/tutorials/configuration-language/data-sources)** (~45 min) — the official hands-on: replace hard-coded region/AZ/AMI with `aws_availability_zones` / `aws_region` / `aws_ami` lookups, and wire a two-workspace VPC→app stack together with `terraform_remote_state`. Notes: [[tut-data-sources]]. The `data "aws_ami"` filter pattern also appears in [[tf-aws-create]].
3. **Book chapter — TID Ch 2 §2.6 "Data sources"** (~30 min) — dependency implications of data reads. (Captured notes: [[02-hcl-components]].)

!!! note "📌 List resources + `terraform query` (TF 1.14)"
    Beyond point lookups, Terraform **1.14** added **list resources** (defined in `*.tfquery.hcl` files) and the **`terraform query`** command — you can enumerate and filter *existing* infrastructure a provider knows about, not just read one known object like a data source does. Useful for discovery/inventory ahead of an `import`. Newer than both books and the 004 exam; verify against the CHANGELOG. (See [[feature-history]].)

!!! example "🧪 Labs"
    - **KL:** [Lab 05 — state, data sources & CLI](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_05_working_with_state_data_sources_and_cli) (data-source section).
    - **KK:** [KodeKloud free labs](https://kodekloud.com/free-labs/terraform) — *Datasources*.

**Milestone:** You can look up a resource you didn't create (e.g. the latest AMI or default VPC) and wire it into a managed resource.

---

### ⬜ B9 — State fundamentals

**What it is:** What `terraform.tfstate` is, why Terraform needs it (mapping config → real resources), what's in it, and why it must be protected and never hand-edited.

**Why you need it:** State is Terraform's source of truth; almost every advanced problem (drift, imports, backends, locking) is a state problem.

**How to learn it:**

1. **Video — [Krausen "Terraform Associate — Hands-On Labs" (state section)](https://krausen.io/course/hashicorp-certified-terraform-associate-hands-on-labs/)** (~30 min) — why state exists and what breaks without it. The written version of the same argument is [HCDocs "Purpose of Terraform State"](https://developer.hashicorp.com/terraform/language/state/purpose), captured in [[tf-state-purpose]]: real-world mapping (and the abandoned AWS-tag prototype), **retained dependencies for destroy ordering** (the reason TID Ch6 §6.1 omits), the attribute cache as the explicitly optional part, and syncing/locking.
2. **Reference — [HCDocs "State" overview](https://developer.hashicorp.com/terraform/language/state) + ["Sensitive Data in State"](https://developer.hashicorp.com/terraform/language/state/sensitive-data)** (~30 min) — note that state can hold secrets in plaintext. Overview captured in [[tf-state]]: bindings between remote objects and resource instances as state's *primary* purpose, the **one-to-one mapping rule** and the two operations that break it (`terraform import`, `terraform state rm`), the no-version-control warning, and `terraform output -json` / `terraform show -json` as the supported way for external software to read a snapshot.
3. **Book chapter — TID Ch 6** (state) (~1 hr) — anatomy of the state file; read but don't edit it.

!!! example "🧪 Labs"
    - **KL:** [Lab 05 — state, data sources & CLI](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_05_working_with_state_data_sources_and_cli) (state + CLI sections).
    - **KK:** [KodeKloud free labs](https://kodekloud.com/free-labs/terraform) — *Terraform State* (purpose of state, state considerations).

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
2. **Reference — [HCDocs "Meta-arguments" index](https://developer.hashicorp.com/terraform/language/meta-arguments)** (~10 min) — what the class *is* (core-defined, not provider-defined) and the six members. Notes: [[tf-meta-arguments]].
3. **Reference — [HCDocs "count"](https://developer.hashicorp.com/terraform/language/meta-arguments/count) + ["for_each"](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) + [depends_on](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on)** (~30 min) — the addressing rules and when each is legal. Notes: [[tf-meta-depends-on]].
4. **Practice — inspect the DAG** (~20 min) — run `terraform graph` on a config with one implicit edge and one `depends_on`, then delete the `depends_on` and watch the edge vanish while `validate` still passes. Notes: [[dependency-graph]], [[tf-cmd-graph]].
5. **Book chapter — TID Ch 4 §4.8 "count and for_each"** (~1 hr) — the re-creation/reindex pitfall and how `for_each` keys avoid it; `depends_on` is Ch 2 §2.7.3. (Captured notes: [[04-expressions-iterations]]. The plan-side angle — the plan-time-known constraint (§5.7) and the resource graph the meta-args expand into (§5.2) — is in [[05-terraform-plan]].)

!!! warning "📌 `for_each` accepts a map, an **object**, or a set of strings — the error message and the docs omit the object"
    Both the *"must be a map, or set of strings"* error and [HashiCorp's `for_each` page](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) list only maps and sets of strings. The implementation checks three kinds — map, set, **and object** — and accepts all of them (`internal/terraform/eval_for_each.go:361`, verified on TF 1.15.8). **OpenTofu's docs get this right** ([[ot-provider-for-each]]: "must be a **map**, **object**, or **set of strings**"). It matters because braces build an *object*, not a map, so `for_each = { a = "1", b = "2" }` works with **no `tomap()`**. It also **converts nothing**: a `list(string)` and a bare `["p","q"]` tuple are both rejected outright (the docs are explicit that lists/tuples are not implicitly converted to sets), which is why `toset(...)` is mandatory. Finally, *"of strings"* binds only to the **set** — only keys become instance addresses, so a map/object may hold values of any type (`for_each = { a = 1, b = "x" }` plans fine). Evidence: [[conditional-branch-evaluation]].

!!! warning "`count` and `for_each` are mutually exclusive"
    You **cannot** use both in the same `resource` or `module` block. Choose by shape: `count` for nearly identical instances derived from an integer index, `for_each` when some instance arguments need distinct values an index can't produce.

    Both are legal on `data` blocks. The meta-arguments *index* page omits `data` from its `count` list, but the `count` reference page names `data`, `ephemeral`, `module`, `resource`, and `list` (query configs). Trust the per-argument reference. (See [[tf-meta-arguments]].)

!!! danger "Nothing warns you about a missing `depends_on`"
    The DAG is built from expression references plus the `depends_on` you write. A dependency Terraform can't see **does not exist** to it, so `plan`, `validate`, and the provider all stay silent. Verified on v1.15.6: deleting a `depends_on` drops the edge from `terraform graph` while `validate` still reports success.

    The failure lands at apply, usually as a **race** — passes locally, fails in CI, or fails once and succeeds on rerun. Worst case it "succeeds" and the object is semantically broken (the docs' EC2-instance-can't-reach-S3 example).

    Counterweight: `depends_on` is a **last resort**, not a safety blanket. It forces more values to `(known after apply)` and replaces more resources than necessary, especially on `module` blocks. Prefer an attribute reference wherever one exists. (See [[dependency-graph]], [[tf-meta-depends-on]].)

!!! info "📌 OpenTofu — `enabled` meta-argument (1.11)"
    **OpenTofu 1.11** adds an `enabled` meta-argument — a first-class on/off switch for a resource, cleaner than the `count = var.enabled ? 1 : 0` idiom (which forces `[0]` addressing and index churn). OpenTofu-only; in Terraform you still use the `count` trick. (See [[feature-coverage-matrix]].)

!!! example "🧪 Labs (KL)"
    [Lab 04 — managing multiple resources](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_04_managing_mulitple_resources) · [Lab 08 — deploying multiple resources with for_each](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_08_deploying_mulitple_resources_with_for_each).

**Milestone:** You can convert a `count`-based set of resources to `for_each` and explain why removing a middle element no longer destroys unrelated resources.

---

### ⬜ I2 — The lifecycle meta-argument

**What it is:** `lifecycle` blocks — `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`, plus the two condition rules (`precondition`/`postcondition` → A2) and **`action_trigger`** (→ A1) — and how each alters the plan.

**Why you need it:** Zero-downtime replacements, protecting stateful resources, and ignoring externally-managed drift all depend on lifecycle rules.

**How to learn it:**

1. **Reference — [HCDocs "lifecycle" meta-argument](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)** (~30 min) — each option and its plan effect.
2. **Interactive — experiment** (~45 min) — add `create_before_destroy` to a resource and watch the plan reorder to `+` before `-`.
3. **Book chapter — TID Ch 2 §2.7.2 "Lifecycle"** (~30 min) — the lifecycle meta-argument itself, real use cases and gotchas (Captured notes: [[02-hcl-components]]). `ignore_changes` as the fix for cascading `# forces replacement` is Ch 5 §5.7 *Cascading changes* ([[05-terraform-plan]]).

!!! note "📌 `lifecycle` has seven rules, and only takes literals"
    Beyond the classic four, `lifecycle` also holds **`precondition`** / **`postcondition`** (→ A2) and **`action_trigger`** (→ A1). Full list in [[tf-block-resource]].

    Why literals only: "Configurations defined in the `lifecycle` block affect how Terraform **constructs and traverses the dependency graph**. You can only use literal values … because Terraform processes them **before it evaluates arbitrary expressions**." The block is an *input* to graph construction. (See [[meta-arguments-lifecycle]].)

    Also note `prevent_destroy` "doesn't prevent Terraform from destroying the resource **if you remove the resource configuration**" — the guard dies with the block it guards.

!!! info "📌 OpenTofu — dynamic `prevent_destroy` (1.12)"
    OpenTofu 1.12 adds **dynamic `prevent_destroy`** (bind it to a variable); Terraform still requires a literal. See E3.

**Milestone:** You can configure a resource for zero-downtime replacement and protect a database from accidental destroy.

---

### ⬜ I3 — Dynamic blocks & complex types

**What it is:** Generating repeated nested blocks with `dynamic`, and modeling data with `object`/`map`/`list`/`set`/`tuple` and optional attributes.

**Why you need it:** Flexible modules need to emit variable numbers of nested blocks (ingress rules, tags) from typed input variables.

**How to learn it:**

1. **Reference — [HCDocs "dynamic blocks"](https://developer.hashicorp.com/terraform/language/expressions/dynamic-blocks) + ["Type Constraints"](https://developer.hashicorp.com/terraform/language/expressions/type-constraints)** (~40 min) — syntax and when `dynamic` is worth the readability cost. The dynamic-blocks page is captured as [[tf-expr-dynamic-blocks]] — full anatomy (`for_each`/`iterator`/`labels`/`content`, the `key`/`value` iterator attributes and the set-key caveat), the meta-argument-block limitation (can't generate `lifecycle`/`provisioner`), multi-level nesting with a distinct `iterator` per level, `flatten`/`setproduct` to shape `for_each`, and the "write blocks literally where possible" best practice. The Type Constraints page is captured as [[tf-expr-type-constraints]] — keywords vs constructors, primitive/collection (`list`/`map`/`set`)/structural (`object`/`tuple`) types, the similar-kinds conversion rules (lossy `map → object → map`, set ordering), why `any` is rarely right (only for opaque pass-through like `jsonencode`), and **`optional(type, default)`** attributes with top-down default application and the `? :`-with-`null` idiom to leave one unset.
2. **Interactive — build a security-group module** (~1 hr) — drive `ingress` rules from a list-of-objects variable via `dynamic`.
3. **Book chapters — TID Ch 3** (type constraints & `optional()`) **+ Ch 4 §4.10** (`dynamic` blocks) (~30 min) — the complex-type system (`object`/`map`/`list`/`set`/`tuple`, `optional()`) is in Ch3; `dynamic` blocks are in Ch4, captured as [[04-expressions-iterations]].

!!! note "📌 `dynamic` block anatomy — `content`, the label iterator, and `iterator`"
    Inside a `dynamic "X"` block the iterator variable defaults to the label (`X.value` / `X.key`) and the body must sit in a **`content {}`** sub-block. Rename the iterator with the optional **`iterator = <name>`** argument — an **unquoted** name, not a string — which is needed when **nested** `dynamic` blocks share a label so the inner one doesn't shadow the outer's keyword. Toggle a whole block on/off with `for_each = cond ? ["x"] : []`. Stable in Terraform and OpenTofu (the only recent change is OpenTofu 1.12 allowing provider-defined functions in a dynamic `for_each`, #3429). Full treatment: TID Ch4 §4.10.

!!! example "🧪 Lab (KL)"
    [Lab 06 — making code dynamic & reusable](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_06_making_code_dynamic_and_reusable) (dynamic-blocks section).

**Milestone:** You can write a module that accepts a list of rule objects and emits one nested block per rule with a `dynamic` block.

---

### ⬜ I4 — Using modules

**What it is:** Consuming modules — the registry, source addresses (registry/git/local), version constraints, passing inputs, and reading module outputs.

**Why you need it:** Almost no production config is flat; you compose from modules, and the exam tests module sourcing/versioning.

**How to learn it:**

1. **Interactive — HCTut ["Use registry modules in configuration"](https://developer.hashicorp.com/terraform/tutorials/modules/module-use)** (~45 min) — pull a registry module (e.g. AWS VPC) and wire it up. (A first taste is captured in [[tf-aws-manage]] — the `terraform-aws-modules/vpc/aws` module block, `module.<name>.<output>` references, re-`init` to install it, and `module.vpc.*` state addressing.)
2. **Reference — [HCDocs "Module Sources"](https://developer.hashicorp.com/terraform/language/modules/sources) + [version constraint syntax](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)** (~30 min) — `~>`, git refs, local paths. The version-constraints page is captured as [[tf-expr-version-constraints]] — the operators (`=`/`!=`/`>`/`>=`/`<`/`<=`/`~>`, with the `~>` right-most-increment rule), that constraints apply to modules, provider requirements, and `required_version`, the "newest installed that qualifies, else download" resolution, pre-release matching only via `=`, and the reusable-module (min-only `>=`) vs root-module (`~>` upper+lower bound) best-practice split.
3. **Book chapter — TUR Ch 4** (~1.5 hrs) — the classic module treatment; still the best explanation of inputs/outputs/composition.

!!! note "📌 Dynamic module sources (Terraform 1.15)"
    Terraform **1.15** added **dynamic module sources**: `source` and `version` can now be variables, not just string literals — so one module block can point different environments at different registries/pins instead of duplicating the block. Any variable feeding a module source must be marked `const = true` (module sources resolve at `terraform init`). OpenTofu offered this earlier; this is one of the 1.15 gap-closers. Note the exam (004, Terraform 1.12) still assumes literal sources. (See [[tf115-ot112-features]].)

!!! note "📌 `terraform modules` (TF 1.10)"
    **`terraform modules`** (TF 1.10+) prints every module declared in the config — key, source, and version — for the whole tree. Use it to audit what you depend on and to drive policy on module consumption. (See [[feature-history]].)

!!! note "📌 Governing module versions — no lock file to lean on"
    `.terraform.lock.hcl` records **providers only**. Module selections live in uncommitted `.terraform/modules/modules.json`, so a fresh clone or a clean CI runner re-resolves the constraint and can land on a version nobody tested. `terraform init -lockfile=readonly` has nothing to check. Ch3 states the hazard; the controls belong here, in three layers.

    The in-scope control here is the **exact pin**: `version = "6.6.1"` for a registry module. Enforcing that pin is **A5**; keeping pinned versions current is **A3**.

    Don't try to commit `modules.json` as a substitute. `Dir` is repo-relative so it looks portable, but it's an undocumented internal snapshot that `init` rewrites, with no readonly enforcement.

!!! warning "📌 Git module sources: immutable pin *or* automated updates, not both"
    A registry module gets both properties at once — `version = "6.6.1"` is exact, and both update bots understand it. A **Git** source forces a real choice, and this is the reason to prefer registry sources where you have one.

    **`ref=<tag>`** is what the bots can move, but a Git tag is mutable: whoever controls the source repo can force-move `v1.2.0` to different code and your "pin" follows it silently. Mitigate by trusting the publisher, or by requiring tag-protection rules on the source repo.

    **`ref=<full commit SHA>`** cannot be moved by anyone, which is the supply-chain-safe answer and mirrors the advice to SHA-pin GitHub Actions. The cost is that **no update bot will move it for you**, confirmed on both:

    - **Renovate** — not supported natively. The maintainer's reason in [discussion #31006](https://github.com/renovatebot/renovate/discussions/31006) is architectural: Renovate's HCL parser returns an AST with comments stripped, so it has nowhere to keep the version↔SHA annotation its Docker/Actions digest pinning relies on. Open request, no timeline. Worse, a global `pinDigests: true` *breaks* on Git-sourced Terraform modules ([#14790](https://github.com/renovatebot/renovate/issues/14790)); set `"terraform": { "pinDigests": false }`. A custom regex manager is the community workaround.
    - **Dependabot** — same gap, tracked at [#10787](https://github.com/dependabot/dependabot-core/issues/10787) (SHA-pinned source reports "no update needed" even when newer commits exist) and [#10926](https://github.com/dependabot/dependabot-core/issues/10926). It considers semantic versions and skips SHA refs.

    **How to choose.** Third-party module you don't control: SHA-pin and accept manual upgrades, because the mutable-tag risk is a real supply-chain exposure. Module in your own org with protected tags: pin the tag and keep the automation, since you control whether the tag can move. Either way this is a deliberate trade, not an oversight — verified 2026-07-20.

!!! example "🧪 Lab (KL)"
    [Lab 06 — making code dynamic & reusable](https://github.com/btkrausen/terraform-associate-labs/tree/main/labs/lab_06_making_code_dynamic_and_reusable) (reusable-module section).

**Milestone:** You can consume a versioned registry module, pass it inputs, and reference its outputs in your own resources.

---

### ⬜ I5 — Authoring modules

**What it is:** Writing your own modules — standard file layout, input validation, sensible outputs, composition over inheritance, and module design principles.

**Why you need it:** Reusable, testable modules are the core skill of both certs and of any real Terraform codebase.

**How to learn it:**

1. **Book chapter — TUR Ch 4 + Ch 8** (~2.5 hrs) — module design and "production-grade" module conventions.
2. **Reference — [HCDocs "Module Development"](https://developer.hashicorp.com/terraform/language/modules/develop) standards** (~40 min) — the standard module structure and publishing rules.
3. **Interactive — refactor** (~1.5 hrs) — extract your Beginner project into a reusable module with a clean input/output surface.

!!! tip "📌 Type your module's outputs, for the same reason you type its inputs"
    A module's **outputs** deserve `type` constraints as much as its inputs do (TF **1.15+**, B6): the constraint is checked, and a consumer reads your interface without reading your implementation. That is the case, and it's enough. A visible side effect is that a fully-typed output set makes `module.<NAME>` a `list`/`map` under `count`/`for_each` rather than a `tuple`/`object` (verified 1.15.8; Ch 7 §3 has the machinery) — but treat that as a curiosity, **not** a reason: auto-conversion means callers almost never notice, since a tuple splats, converts, and satisfies a `list(object(...))` constraint exactly as a list does. **OpenTofu has no typed outputs** as of 1.12.4, so a module written for both can't rely on the argument at all. Evidence: [[conditional-branch-evaluation]].

!!! note "📌 Module API deprecation (Terraform 1.15)"
    Terraform **1.15** added a **deprecation mechanism** for a module's public API: put `deprecated = "message"` on a `variable` or `output` and callers get a warning at `terraform validate`. This is how you evolve a published module's interface without breaking consumers overnight — deprecate, warn, then remove a version later. Pairs with the refactoring workflow in A8. (See [[tf115-ot112-features]]; argument specs in [[tf-block-variable]] and [[tf-block-output]]. Output-specifics: `deprecated` is **child-modules-only**, only *consumers* see the warning (not the defining module), and `ignore_nested_deprecations` on the `module` block suppresses nested warnings.)

**Milestone:** You can package infrastructure into a module with validated inputs, documented outputs, and a README, and consume it from two callers.

---

### ⬜ I6 — Remote state & backends

**What it is:** Backends (S3, HCP Terraform, GCS, azurerm), state locking, remote vs local state, and `terraform_remote_state` to share outputs.

**Why you need it:** Teams cannot share local state; remote state with locking is the baseline for any collaboration and is exam-critical.

**How to learn it:**

1. **Interactive — HCTut ["Migrate state from S3 to HCP Terraform"](https://developer.hashicorp.com/terraform/tutorials/cloud/migrate-remote-s3-backend-hcp-terraform)** (~1 hr) — migrate a local state to an S3 (or HCP) backend and observe locking. The *why* behind the migration is [HCDocs "Remote State"](https://developer.hashicorp.com/terraform/language/state/remote), captured in [[tf-state-remote]]: local state makes **freshness** and **exclusion** a human responsibility, and remote state doubles as a read-only **delegation** channel between teams, "without relying on any additional configuration store."
2. **Reference — [HCDocs "Backends"](https://developer.hashicorp.com/terraform/language/backend) + ["State Locking"](https://developer.hashicorp.com/terraform/language/state/locking) + [terraform_remote_state](https://developer.hashicorp.com/terraform/language/state/remote-state-data)** (~40 min) — backend config, partial config, and lock behavior. Beyond S3/GCS/azurerm/HCP, know the **full backend catalog** exists — `http`, `consul`, `kubernetes`, `pg` (Postgres), `oss` (Alibaba), `cos` (Tencent), plus OCI (TF 1.12) — pick per platform. Locking flags `-lock=false` / `-lock-timeout` apply to every command. The State-section framing of the same ground is [HCDocs "Manage state in remote backends"](https://developer.hashicorp.com/terraform/language/state/backends), captured in [[tf-state-backends]]: a backend's two responsibilities (storage, plus an **optional** locking API), the guarantee that a non-local backend never writes state to local disk **except** when persisting to the backend fails, and the `state push` lineage/serial guards. The dedicated locking page is captured in [[tf-state-locking]]: locking covers **every operation that could write state** (not just `apply`), happens silently with no success message, and **stops the run** if it fails to acquire. The `backend` block page itself is captured in [[tf-backend-configure]]: the three limitations (one block per configuration, **no named values**, nothing declared inside it is referenceable elsewhere), `backend` and `cloud` being mutually exclusive, the full partial-configuration surface, and the documented **`*.backendname.tfbackend`** filename convention. The default backend has its own page, captured in [[tf-backend-local]]: `path` and `workspace_dir`, and the legacy **`-state` / `-state-out` / `-backup`** flags that **switch off workspace-aware state filenames** — HashiCorp recommends against them "even if you are running Terraform in automation."

!!! example "🧪 Verified — the `s3` backend against the lab emulator"
    Run on **Terraform 1.15.8** against **Floci 1.5.33** on `:4566`, so this whole topic is exercisable with no AWS account. Full transcripts in [[tf-backend-configure]] and [[tf-state-locking]].

    - **`endpoints` is an attribute, not a block.** `endpoints { s3 = … }` fails to parse; write `endpoints = { s3 = "http://localhost:4566" }`, plus `use_path_style` and the `skip_*` flags.
    - **The documented leak is real.** `.terraform/terraform.tfstate` holds the resolved backend config as JSON *including `access_key`/`secret_key`*, and the same values are embedded in the msgpack `tfplan` entry inside a saved plan file.
    - **`use_lockfile` locking is a `<key>.tflock` sibling object**, present only while the operation runs. A concurrent command fails with `PutObject … 412 PreconditionFailed` — the conditional write *is* the lock — and prints the `Lock Info` block with the ID, holder, operation, and start time.
    - **A partial block can be completely empty.** `backend "s3" {}` plus `-backend-config="./config.s3.tfbackend"` initializes fine; the "keys set to empty values" the docs show is a style, not a requirement.

!!! note "📌 `init` backend/provider flags"
    `terraform init` isn't just first-run setup — its flags manage the backend/providers over a project's life: **`-backend-config=…`** (partial/dynamic backend config), **`-migrate-state`** (move state to a new backend), **`-reconfigure`** (ignore existing state when switching), and **`-upgrade`** (re-resolve providers and refresh the lock file within constraints). (See [[feature-history]].)
3. **Reference — [HCDocs "`terraform_remote_state` data source"](https://developer.hashicorp.com/terraform/language/state/remote-state-data)** (~25 min) — reading another config's **root** outputs, the `config` object (nested backend blocks become `=` attributes), `defaults`, and — most of the page — HashiCorp's case *against* using it. Notes: [[tf-remote-state-data]].
4. **Book chapter — TUR Ch 3** (~1.5 hrs) — the canonical remote-state + isolation discussion.

!!! note "📌 Four properties of a hardened state backend"
    Ephemeral values don't cover every case — some secrets land in state even when you're doing it right (a data-source read you chose because the value must persist, or a resource that returns a credential on creation, like an IAM access key). When a secret **has** to be in the file, protect the file. Four properties matter: **encrypted, versioned, locked, and readable only by the identities that run Terraform.** On S3 the backend block carries two of them (`encrypt = true`, `kms_key_id` with *your* key rather than the S3 default, and `use_lockfile = true`); the other two live on the bucket (enable **S3 Versioning** so a corrupted state is recoverable, and scope the bucket IAM to the run identities). GCS uses `kms_encryption_key` plus Object Versioning; Azure Blob authenticates via `use_oidc`.

    **Backend config leaks harder than provider config:** it is copied into `.terraform/` *and captured in plan files*. Backend credentials come from the environment — never inline, and never as `-backend-config` values. (See [[infisical-terraform-secrets]]; the state-encryption backend list is in [[tf-manage-sensitive-data]]; cross-links **A6**.)

    HashiCorp documents this directly ([[tf-backend-configure]]), and names the two plaintext files: **`.terraform/terraform.tfstate`** (the backend config for the working directory) and **every plan file**, each capturing that config as it stood at plan time. The consequence to plan around: **a saved plan applies with its own frozen backend config**, not current settings, so time-limited credentials baked into it can expire before the apply runs. Environment variables are read fresh at apply and are the documented fix.

!!! danger "📌 `terraform_remote_state` grants access to the *whole* state, not just outputs"
    The data source exposes only root outputs to your configuration — but "the state snapshot data is a single object, and so any user or server which has enough access to read the root module output values **will also always have access to the full state snapshot data by direct network requests**." State stores resource attributes in plaintext, secrets included. HashiCorp: "Don't use `terraform_remote_state` if any of the resources in your configuration work with data that you consider sensitive."

    Two recommended alternatives:

    - **On HCP Terraform / Enterprise — use the `tfe_outputs` data source**, which "does not require full access to workspace state to fetch outputs."
    - **Elsewhere — publish shared data explicitly** to a store with its own access controls (SSM Parameter Store, Consul KV, a Kubernetes ConfigMap, DNS records, an S3 object + `jsonencode`/`jsondecode`). Bonus: non-Terraform systems can read it too. Encapsulate the choice in a **data-only module** so you can swap strategies later.

    Also: **only root-level outputs are readable.** Nested-module outputs need an explicit passthrough `output` block in the producing config's root. (See [[tf-remote-state-data]]; cross-links **A6 (secrets)**.)

!!! warning "📌 `force-unlock` — use with care"
    When a run crashes mid-apply the state lock can be left held; **`terraform force-unlock LOCK_ID`** releases it manually (the lock ID is printed in the error). Use only after confirming no run is actually in progress — force-unlocking a live run corrupts state. (See [[feature-history]].)

    HashiCorp scopes it tighter than "no run in progress": force-unlock is for **your own lock, when automatic unlocking failed** — not a tool for clearing a colleague's stuck run. The lock ID is a **nonce** identifying one acquisition, so you cannot unlock blind and a stale ID will not release the current lock. (See [[tf-state-locking]].)

!!! note "📌 S3 native state locking"
    The S3 backend now has **native state locking** via a lock file in the bucket (`use_lockfile = true`) — the separate **DynamoDB table is no longer required** (Terraform 1.11+; OpenTofu shipped native S3 locking in 1.10). Older tutorials still show the S3+DynamoDB pairing; prefer native locking on new setups. (See [[feature-coverage-matrix]].)

!!! note "📌 OCI Object Storage backend (Terraform 1.12)"
    Terraform **1.12** added a native **OCI Object Storage backend** (Oracle Cloud), joining S3/GCS/azurerm/HCP as a first-class remote-state store. (See [[feature-history]].)

**Milestone:** You can migrate a project from local to remote state with locking and read another config's outputs via `terraform_remote_state`.

---

### ⬜ I7 — State management operations

**What it is:** The state-surgery toolkit — `import` (+ `import` blocks), `state mv`/`rm`, `refresh`, detecting and reconciling drift, and `moved`/`removed` config blocks.

**Why you need it:** Real infrastructure predates your config, gets renamed, and drifts; you must bring it under management without destroying it.

**How to learn it:**

1. **Interactive — HCTut ["Import"](https://developer.hashicorp.com/terraform/tutorials/state/state-import) + ["Manage resource drift"](https://developer.hashicorp.com/terraform/tutorials/state/resource-drift)** (~1.5 hrs) — import a manually-created resource and reconcile a deliberate drift. Try config generation: `terraform plan -generate-config-out=gen.tf` writes best-guess HCL for your `import` blocks (TF 1.5+), so you don't hand-write the config for adopted resources.
2. **Reference — HCDocs [import block](https://developer.hashicorp.com/terraform/language/import), [moved](https://developer.hashicorp.com/terraform/language/moved), [removed](https://developer.hashicorp.com/terraform/language/resources/syntax#removing-resources), [`state` subcommands](https://developer.hashicorp.com/terraform/cli/commands/state)** (~45 min) — prefer config-driven `import`/`moved` over CLI surgery. Know the full `state` toolkit: **`list`** / **`show`** (inspect), **`mv`** / **`rm`** (surgery), **`pull`** / **`push`** (read/write raw state — dangerous, backup first), and **`replace-provider`** (rewrite a provider source address in state, e.g. after a registry namespace change or a Terraform→OpenTofu move). The forget-without-destroying procedure has its own page, captured in [[tf-state-remove]]: the five steps, why HashiCorp recommends the `removed` block over `terraform state rm` (the block goes through plan, so you preview the result), and the fact that re-adopting the resource later requires an **import**, not an edit.
3. **Book chapter — TID Ch 6** (state operations) (~1 hr) — safe patterns and recovery.

!!! danger "📌 Forget a resource without destroying it — `removed` alone is NOT enough"
    Terraform's config-driven way to drop a resource from state is the `removed` block (preferred over `terraform state rm`) — but you **must** write `lifecycle { destroy = false }`. A bare `removed` block **destroys the object**.

    ```hcl
    removed {
      from = aws_instance.legacy
      lifecycle { destroy = false }   # omit this and the instance is destroyed
    }
    ```

    Verified on **v1.15.6**: without the `lifecycle` block, `plan` reports `1 to destroy`; with `destroy = false` it reports `0 to destroy` and warns "will no longer be managed by Terraform, but will not be destroyed." The `removed` block was **forget-only in v1.7**, so older material (including TID Ch2 §2.9) describes the old behavior. (See [[tf-block-removed]].)

    Two more constraints from [[tf-state-remove]]. `from` **cannot take an instance key** — `aws_instance.example[1]` is rejected, so a `count`/`for_each` resource is forgotten in full or not at all. And you must delete every reference to the resource's attributes before applying; `terraform validate` enumerates them.

    **OpenTofu 1.12** adds a lifecycle alternative — `destroy = false` on the **resource** itself — doing the same "forget, don't destroy" without a `removed` block. OpenTofu-only. (See [[tf115-ot112-features]], [[ot-dynamic-prevent-destroy]].)

!!! note "📌 `import` `identity` attribute (Terraform 1.12)"
    Terraform **1.12** added an **`identity` attribute** to `import` blocks as an alternative to `id` (the two are mutually exclusive) — for providers that identify a resource by a structured identity object rather than a single opaque ID string. (See [[feature-history]].)

!!! note "📌 `import` `for_each` (TF/OpenTofu 1.7)"
    `import` blocks take **`for_each`** (TF/OpenTofu 1.7) — loop one import block over a map to adopt many similar resources at once instead of writing a block each. (See [[feature-history]].)

!!! note "📌 `-refresh-only` drift reconcile"
    To reconcile drift without changing config, use **`-refresh-only`** mode (`terraform plan/apply -refresh-only`, since 0.15.4) — it updates state to match reality and shows what drifted, without proposing config-driven changes.

    **`terraform refresh` is deprecated outright**, not merely in spirit — the CLI reference says so in its second sentence ([[tf-cmd-refresh]]). It is "effectively an alias for `terraform apply -refresh-only -auto-approve`", and the auto-approve **cannot be switched off**. The documented hazard: with misconfigured provider credentials, "Terraform may be misled into thinking that all of the managed objects have been deleted, causing it to remove all of the tracked objects without any confirmation prompt." The docs go further than "prefer the flag" — prefer *neither*, and rely on the automatic refresh a normal plan already performs. (See [[feature-history]].)

**Milestone:** You can adopt an unmanaged cloud resource via an `import` block and rename a resource with a `moved` block — both with an empty plan afterward.

---

### ⬜ I8 — Provider configuration in depth

**What it is:** Multiple provider instances via `alias`, per-resource `provider` selection, multi-region/multi-account setups, provider version constraints, and authentication patterns.

**Why you need it:** Multi-region and multi-account deployments require aliased providers; version drift between team members causes silent breakage.

!!! note "Cover here (deferred from Ch5 §5.4)"
    Provider-wide conveniences that do not port between clouds belong in this chapter, not first-contact §5.4: AWS's `default_tags` block (stamps a tag set on **every** resource the provider manages, so you don't repeat a `tags` block) and GCP's `user_project_override` / `billing_project` (quota-project routing, which AWS has no parallel to).

!!! info "OpenTofu — one provider instance per element with `for_each` (deferred from Ch5)"
    Alongside `alias`: OpenTofu (since 1.9) lets an **aliased** `provider` block take `for_each` to spin up one instance per map/set element — e.g. one AWS region per element — without repeating the block. The default (unaliased) configuration must still be exactly one instance. Terraform has no equivalent as of 1.15; deep OpenTofu treatment is E3.

**How to learn it:**

1. **Reference — [HCDocs "`provider` block reference"](https://developer.hashicorp.com/terraform/language/block/provider)** (~40 min) — alias syntax and passing providers to modules. Captured as [[tf-provider-block]]. A module that needs a caller to hand it multiple provider configs declares **`configuration_aliases`** inside its `required_providers` — the explicit contract for the `providers = { … }` argument on the module block. (See [[feature-history]].)

    Three things this page pins down that the alias syntax alone doesn't. Configuration inherits into child modules but **`source` and `version` do not**, so every child declares its own `required_providers`. Provider arguments may use expressions over **plan-time-known values only** — input variables yes, computed attributes like `google.web.public_ip` no. And the `version` argument **inside** a `provider` block is **deprecated**; constraints belong in `required_providers`.

!!! warning "📌 Aliasing every provider block changes what your unqualified resources bind to"
    The `provider` block **without** an `alias` is the default configuration. If *every* block for a provider is aliased, Terraform invents an **implied empty default configuration**, and any resource that omits the `provider` meta-argument binds to *that* — not to any of your aliases. If the provider has required arguments, those resources fail with a "not properly configured" error. So adding `alias = "east"` to your one existing `provider "aws"` block silently reassigns every resource that never named a provider. (See [[tf-provider-block]].)

    **There is no way to suppress the implied default** — no flag, no argument. But it is **lazy**: the error fires only when a resource actually binds to it, so an empty default nothing uses is inert. Two mitigations. Keep **one unaliased `provider` block** so the default is real and configured (the documented fix). Or set **`provider =` on every** `resource`/`data`/`module`, which is airtight until someone adds a block that forgets. Note that `providers = {}` on a module block does **not** cut off inheritance of the default — passing an explicit `providers` map overrides inheritance only *for the providers you enumerate* ([terraform#35781](https://github.com/hashicorp/terraform/issues/35781), closed).
2. **Interactive — deploy to two regions** (~1 hr) — use two aliased AWS providers in one config.
3. **Book chapter — TID Ch 2 §2.4 "Providers"** (~30 min) — provider registry, `required_providers`, provider configuration, and aliases; auth strategies and pinning. (Captured notes: [[02-hcl-components]]. Authoring your own provider is E1 → TID Ch 12.)

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

**What it is:** `provisioner` blocks (`local-exec`, `remote-exec`), `null_resource`/`terraform_data`, `connection` blocks, the **`local` provider** (`local_file` / `local_sensitive_file` — writing files from a config) and the **`external`** provider — and, crucially, when *not* to use any of them.

**Why you need it:** Sometimes you must run a script, write a rendered file to disk, or trigger a rebuild; you also need to recognize when a provisioner is a design smell to be replaced by a data source or provider feature. B7 renders templates with `templatefile()` but never writes one out — `local_file` is the piece that puts a rendered template on disk, and it carries the escape-hatch costs (it re-creates on any machine where the file is absent, adding diff noise).

**How to learn it:**

1. **Reference — [HCDocs "Provisioners"](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax) (incl. the "last resort" warning) + [terraform_data](https://developer.hashicorp.com/terraform/language/resources/terraform-data)** (~40 min) — read HashiCorp's own case against provisioners. Note the knobs: **`when = destroy`** (run at teardown instead of create), **`on_failure = continue|fail`** (tolerate vs abort), and the `self` object + `connection` block for `remote-exec`. Notes: [[tf-terraform-data]].

!!! note "📌 The alternative to a provisioner is a *handoff*, and `terraform output -json` is the seam"
    HashiCorp's case against provisioners ends at "use a configuration management tool" without showing where the boundary sits. It sits at the **output**: Terraform builds the hosts and publishes their addresses as a root output; a config tool reads that output as its **inventory** and takes over. Nothing runs inside the apply.

    ```shell
    # Terraform publishes; the config tool consumes. Two runs, one seam.
    pyinfra @terraform/server_group.value.server_group_node_ips apt.packages iftop _sudo=true
    ```

    Ansible is the incumbent here (the Red Hat-certified **`cloud.terraform`** collection); [[pyinfra]] is the same idea in Python and is the smaller, clearer illustration of it. What the handoff buys over a `remote-exec`: a failed config step **isn't a tainted resource** that gets destroyed and recreated on the next apply; re-converging **doesn't need Terraform** at all (that's what the config tool's idempotence is for); and the plan stops pretending to describe work it can't diff. The cost is real and worth naming: **two tools, two runs, and an ordering dependency** that a human or CI has to enforce.

!!! warning "📌 Outputs vs. state — pick the narrower grant when wiring in a config tool"
    The two mechanisms are **not** equivalent in what they expose. pyinfra's `@terraform` connector reads **`terraform output -json`** — only what the root module deliberately published. Ansible's `terraform_provider` inventory plugin builds its inventory from the **state file** — every attribute of every resource, plaintext secrets included. Same "get the host list" job, very different blast radius: the outputs-only consumer can be granted `terraform output` without being handed the state snapshot.

    This is the **I6/A6 access-boundary rule** showing up in a new place: "who may read this state" is the real permission boundary, not "which outputs do I expose." (See [[pyinfra]] and [[tf-remote-state-data]].) And before publishing an output for a config tool to consume, recall that **`-json` bypasses `sensitive` redaction** ([[tut-outputs]]) — the consumer reads it in plaintext by design.

!!! note "`terraform_data` exists to launder a plain value into a resource address"
    `replace_triggered_by` accepts **only resource addresses** — "plain data values, such as local values and input variables, aren't valid" — because replacement is decided from the *planned operations* of the referenced resources. Since a `terraform_data` plans an action whenever its `input` changes, wrapping a variable in one turns it into something `replace_triggered_by` can legally reference:

    ```hcl
    resource "terraform_data" "replacement" { input = var.revision }

    resource "example_database" "test" {
      lifecycle { replace_triggered_by = [terraform_data.replacement] }
    }
    ```

    Distinguish the two arguments: changing **`input`** updates in place, changing **`triggers_replace`** forces replacement (and so re-runs any provisioner the resource hosts). (See [[tf-terraform-data]].)
2. **Interactive — replace a provisioner** (~45 min) — take a `local-exec` hack and re-express it with `terraform_data` triggers or a data source.
3. **Book chapter — TID Ch 10 §10.3 "Provisioners"** (+ §10.4 External provider, §10.5 Local provider) **/ TUR Ch 8** (~45 min) — legitimate vs illegitimate uses. TUR Ch 8 treats these under the exact name this topic uses — *"escape hatches"* (p305): provisioners, provisioners with `null_resource`, and the external data source. `terraform_data` and other state-only resources are Ch 6 §6.8.

!!! note "📌 `actions` block (Terraform 1.14)"
    Terraform **1.14** added the top-level **`actions` block** — provider-defined operations *outside* the normal CRUD lifecycle (e.g. invoke a Lambda, trigger a CloudFront invalidation). This is the modern, provider-native successor to abusing a provisioner or `terraform_data` for one-off side effects: the action is declared by the provider and invoked during apply (or via `-invoke`), with a count reported in the summary. Newer than both books; verify against the CHANGELOG. (See [[feature-history]].)

    **Firing them: `action_trigger`.** An `actions` block declares the operation; a **`action_trigger` block inside a resource's `lifecycle`** invokes it:

    ```hcl
    lifecycle {
      action_trigger {
        events  = [after_create]
        actions = [action.ansible_playbook.provision]
      }
    }
    ```

    `events` and `actions` are required; `condition` gates the run. **Only four events exist** — `before_create`, `after_create`, `before_update`, `after_update`. There is **no destroy event** (verified v1.15.6: `before_destroy` → `Error: No events specified`), so destroy-time work still needs a destroy-time provisioner. Beware a docs bug: the reference's spec snippet calls the argument `conditions`, which Terraform rejects as an unsupported argument — it is `condition`. (See [[tf-block-resource]].)

!!! note "📌 `encode_tfvars` / `decode_tfvars` (TF 1.8)"
    Last-resort data-shuttling: the built-in `terraform` provider ships **`provider::terraform::encode_tfvars` / `decode_tfvars` / `encode_expr`** (TF 1.8) to (de)serialize `.tfvars`/HCL expressions as strings. Handy when a provisioner must hand a generated `.tfvars` to another tool — but prefer data sources / remote state; HashiCorp flags these as last-resort. (See [[feature-history]].)

**Milestone:** You can use `terraform_data` with `triggers_replace` to force a controlled rebuild, and justify avoiding a provisioner in a given scenario.

---

### ⬜ A2 — Testing, validation & checks

**What it is:** The native `terraform test` framework (`.tftest.hcl`), variable `validation` rules, `precondition`/`postcondition` blocks, top-level `check` blocks for continuous assertions, and **Terratest** for Go-based integration/e2e testing of real deployed infrastructure.

**Why you need it:** Untested modules break silently; the Pro exam explicitly tests validation and checks, and testing is what makes modules trustworthy.

**How to learn it:**

1. **Interactive — HCTut ["Write Terraform tests"](https://developer.hashicorp.com/terraform/tutorials/configuration-language/test)** (~1.5 hrs) — write unit + integration `.tftest.hcl` for a module.
2. **Reference — [HCDocs "Tests"](https://developer.hashicorp.com/terraform/language/tests), [Custom Conditions](https://developer.hashicorp.com/terraform/language/expressions/custom-conditions), [Checks](https://developer.hashicorp.com/terraform/language/checks)** (~45 min) — the difference between validation, pre/postconditions, and checks. For the expression side of writing conditions see [[tf-conditionals]] — `can()` (wrap an error-throwing expression as a bool), **`self`** in a `postcondition`, and `each`/`count` objects in expanded-block conditions.
3. **Reference — [Terratest docs](https://terratest.gruntwork.io/docs/) + [quick start](https://terratest.gruntwork.io/docs/getting-started/quick-start/)** (~1 hr) — the Go library for deploying real infra and asserting on it. Native `terraform test` proves your *code* is right (outputs, plan, variable behavior); Terratest proves the *infrastructure works* by querying each live resource through its own API — catching the case where a provider bug makes a real resource that native tests, which only see provider-reported state, would still pass. Learn native first; reach for Terratest when you need real external-behavior checks. (See [[terraform-testing]].)
4. **Book chapter — TUR Ch 9** (~2 hrs) — testing strategy (unit/integration/e2e) and Terratest for deeper Go-based testing.

!!! note "📌 `terraform test` vs TUR"
    `terraform test` post-dates TUR's main testing chapter — use HCDocs for the native framework, TUR for the strategy.

!!! note "📌 Native `test` vs Terratest — when to use which"
    Balance the two: run **native `terraform test` on every commit** (fast, no Go, no real infra); reserve **Terratest for integration pipelines / pre-release** (slower, deploys real infra, needs Go 1.26+ and cloud creds). Terratest v2 is in development; v1 is in security-only maintenance.

!!! note "📌 Functions in test doubles (Terraform 1.15)"
    Terraform **1.15** lets you call functions inside `mock_data` and `override_resource` blocks, so test doubles can generate realistic values (GUIDs, resource IDs) instead of hard-coded constants. (See [[tf115-ot112-features]].)

!!! note "📌 Cross-object variable validation (Terraform 1.9)"
    Terraform **1.9** widened variable `validation`: a condition can now reference *other* variables, data sources, and locals (previously only the variable itself), so you can enforce cross-field rules ("if `mode = ha` then `replicas >= 2`"). The referenced values must be known at plan time. (See [[feature-history]].)

!!! note "📌 `terraform test -parallelism` (Terraform 1.12)"
    Terraform **1.12** added **`terraform test -parallelism=N`** plus per-run annotations to run independent test files/runs concurrently — meaningful when a suite provisions real infra per run. (See [[feature-history]].)

!!! note "📌 Test framework improvements (Terraform 1.13)"
    Terraform **1.13** sharpened the test framework: define **external variables directly in `.tftest.hcl`**, reference **run outputs from file-level variables** (shorter setup), and parallel teardown. (See [[feature-history]].)

!!! note "📌 `expect_failures` in `run` blocks"
    A `run` block can assert a config *should* fail: **`expect_failures = [...]`** lists the checkable objects (a variable `validation`, `precondition`, etc.) you expect to error — the test passes when they do. Essential for testing your validation logic, not just the happy path.

!!! note "📌 The `self` object in conditions"
    A **`postcondition`** validates a resource *after* it's created, so it needs to read that resource's own applied attributes. **`self`** is the resource object the enclosing `lifecycle` block sits in: `self.id`, `self.architecture`, etc. Terraform provides `self` precisely because the resource can't reference itself by its normal address (`aws_instance.app.id` inside `aws_instance.app` would be circular). Legal only where that self-reference makes sense — `precondition`/`postcondition`, and `connection`/`provisioner` blocks. A `precondition` runs *before* apply, so `self` there is limited to values already known at plan time. (See [[tf-conditionals]].)

**Milestone:** You can write a `.tftest.hcl` suite that provisions a module, asserts on its outputs, and tears down — plus a `precondition` that fails a bad plan early. Stretch: a Terratest case that deploys the module and verifies real behavior via the resource's own API.

---

### ⬜ A3 — Terraform in CI/CD automation

**What it is:** Running Terraform non-interactively in pipelines — `-input=false`, `-auto-approve`, saved plans (`plan -out` → `apply plan`), remote state, and PR-based plan/apply gating.

**Why you need it:** Production Terraform runs in automation, not on laptops; the Pro exam tests automation-friendly workflows.

**How to learn it:**

1. **Reference — [HCDocs "Automate Terraform" tutorial](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform)** (~40 min) — the non-interactive flag set and the plan-artifact pattern. Know the automation env vars: **`TF_IN_AUTOMATION`** (trims UI hints that assume a human), **`TF_INPUT=false`** (never prompt), **`TF_CLI_ARGS[_name]`** (inject flags), **`TF_DATA_DIR`**. (See [HCDocs env vars](https://developer.hashicorp.com/terraform/cli/config/environment-variables).)
2. **Interactive — build a pipeline** (~2 hrs) — a GitHub Actions (or GitLab CI) workflow that runs `fmt`/`validate`/`plan` on PR and `apply` on merge.
3. **Book chapter — TUR Ch 10** (~1.5 hrs) — production CI/CD patterns and approval gates.

!!! note "📌 Automated dependency updates (Dependabot / Renovate)"
    A pipeline gates *changes you make*. It does nothing about dependencies going stale, and exact pins turn into a frozen ratchet without something to move them. **[Dependabot](https://docs.github.com/en/code-security/dependabot/ecosystems-supported-by-dependabot/supported-ecosystems-and-repositories)** covers registry modules, publicly reachable Git repos, and private registries, plus OpenTofu `.tofu` files and `terragrunt.hcl`. **[Renovate](https://docs.renovatebot.com/modules/manager/terraform/)** covers registry modules, `GitTags`/`GithubTags` sources, `required_providers`, `required_version`, and maintains `.terraform.lock.hcl` itself. Either turns an upgrade into a PR carrying a version diff, which is what gives **module** upgrades the reviewable surface the lock file already gives providers (see I4). Renovate gotcha: it can't tell whether you want the Terraform or OpenTofu registry and defaults to `registry.terraform.io` — configure it explicitly on an OpenTofu project.

    **Neither bot updates a SHA-pinned Git module source.** Renovate can't (its HCL parser drops the comments a digest annotation would need) and Dependabot skips non-semver refs. So a module SHA-pinned for supply-chain safety is one this note cannot keep current, and it needs a manual review cadence instead. The trade-off and the per-case choice are in **I4**; Renovate users should also set `"terraform": { "pinDigests": false }` so a global digest-pinning rule doesn't error on Git sources.

!!! note "📌 Machine-readable plan/apply output"
    For machine-readable plan/apply output, `-json` replaces stdout entirely (you lose the human view). **OpenTofu 1.12**'s `-json-into=FILENAME` writes the JSON to a file while keeping the normal UI on stdout — so CI can parse the JSON *and* a human can read the log. OpenTofu-only. (See [[tf115-ot112-features]].)

!!! danger "📌 The saved plan is a secret, and it expires by itself"
    B3 teaches `plan -out=FILE` → `apply FILE`. Two disciplines belong to the pipeline that carries it.

    **Never commit a plan file.** [HCDocs](https://developer.hashicorp.com/terraform/cli/commands/plan) is explicit: "If your plan includes any sort of sensitive data, even if obscured in Terraform's terminal output, it will be saved in cleartext in the plan file." It also embeds a full prior-state snapshot and every input variable value. Move it between jobs as a **CI artifact** with short retention (`upload-artifact`/`download-artifact`, GitLab `artifacts:`), restrict who can download it, and never let it reach VCS. Same hazard class as state, so pair with **A6**.

    **Staleness is enforced for you.** The plan records the prior state's `lineage` and `serial`. `apply FILE` compares both against current state before doing anything and refuses on mismatch: *"Saved plan is stale — the state was changed by another operation after the plan was created"*, or *"Saved plan does not match the given state"* for a different lineage. Any apply landing in the gap invalidates the pending plan. Verified in `repos/terraform` at `internal/backend/local/backend_local.go:319-331`; the check dates to **v1.1.0**, so it holds everywhere you'll run. Consequence for pipeline design: a long approval window doesn't risk a wrong apply, it just guarantees a re-plan. Combine with state locking so two applies can't interleave. HCP Terraform handles this server-side with its own refusal reasons.

!!! note "📌 Making a local plan and a CI plan agree"
    Byte-identical output is the wrong goal — rendering depends on terminal width and TTY detection, and CI has no TTY. Two plans taken at different moments also *should* differ if reality drifted. What you actually want is the same **actions**.

    Compare structurally with `terraform show -json tfplan`. Per the [JSON format spec](https://developer.hashicorp.com/terraform/internals/json-format), `resource_changes[].change.actions` is a closed set — `["no-op"]`, `["create"]`, `["read"]`, `["update"]`, `["delete","create"]`, `["create","delete"]`, `["delete"]` — with `replace_paths` naming what forced a replacement. Project to `{address, actions}`, sort, hash, compare. Never dump that JSON into a build log: `before`/`after` hold real values, and `before_sensitive`/`after_sensitive` only *mark* sensitivity rather than redacting it.

    Then pin what causes illegitimate divergence. CLI version (`required_version` plus an exact version in the runner). Provider versions (committed lock file plus `init -lockfile=readonly`, B3). The lock file carrying the runner's platform hashes (`providers lock -platform=…`, B3). Module versions, which nothing locks (I4). Same backend and workspace (I6). Variable inputs, watching for a gitignored `*.auto.tfvars` or a stray `TF_VAR_*` in your shell. Cloud identity, since `AWS_PROFILE`/`AWS_REGION` differences mean CI is reading a different account altogether. And configuration that is nondeterministic by construction: `timestamp()`, `uuid()`, and `most_recent = true` data-source lookups will differ between any two runs no matter what you pin.

    When the goal is "what I reviewed is what runs", stop comparing: plan once in CI, review that artifact, apply that file. Chase local↔CI equality only to debug why CI sees something you don't, and the answer is nearly always state or credentials.

**Milestone:** You can build a pipeline that posts a plan on pull requests and applies a saved plan on merge, with remote state and locking — passing the plan as a restricted CI artifact rather than committing it, and explaining what makes `apply FILE` refuse a stale one.

---

### ⬜ A4 — HCP Terraform / Terraform Cloud

**What it is:** HashiCorp's managed platform — workspaces, VCS-driven and CLI-driven runs, remote execution, remote state, private module registry, and run tasks.

**Why you need it:** It's on both the Associate and Pro exams, and it's the most common way teams run Terraform at scale without building their own automation.

**How to learn it:**

1. **Interactive — HCTut ["HCP Terraform get started" track](https://developer.hashicorp.com/terraform/tutorials/cloud-get-started)** (~1.5 hrs) — connect a VCS repo, run a remote plan/apply, use remote state.
2. **Reference — [HCDocs "HCP Terraform"](https://developer.hashicorp.com/terraform/cloud-docs) [workspaces](https://developer.hashicorp.com/terraform/cloud-docs/workspaces) + [run workflow](https://developer.hashicorp.com/terraform/cloud-docs/run/remote-operations)** (~40 min) — workspace settings, variable sets, and the run lifecycle. Also know the platform extras: **cost estimation** (shows $ delta on a plan for supported providers), **run triggers** (one workspace's apply queues another's run), and run notifications. A **`.terraformignore`** file controls which files are excluded from the config upload on remote runs. To reach infra on a private network, HCP runs through self-hosted **agents** (the agent pool executes runs inside your network).
3. **Book chapter — TID Ch on HCP / TUR Ch 10** (~1 hr) — where managed platform fits vs self-hosted CI.

!!! note "📌 Already captured — [[workspaces]]"
    The `cloud` block half of HCP workspaces is written up in [[workspaces]] and [TID Ch6 §6.4.5](books/tid/chapters/06-state-management.md): `tags` versus `name` selection, `project`, what an HCP workspace owns beyond state, and the asymmetry when you edit `tags` later (adds are pushed to HCP, removals are not). A4 adds the platform side — workspace settings, variable sets, and the run lifecycle.

!!! note "📌 HCP's run queue is not the same guarantee as a state lock"
    A state lock is held for the duration of **one command** and released when it ends, so two people can each produce a plan against the same state and the second apply silently invalidates the first person's reviewed plan. HCP Terraform "can also detect attempts to create a new plan when an existing plan is already awaiting approval, by queuing Terraform operations in a central location" — it holds the **whole plan-then-approve cycle**, not the command. Keep the two apart when comparing HCP against a self-hosted backend: S3 with `use_lockfile` gives you the lock, not the queue. (See [[tf-state-remote]], [[tf-state-locking]].)

!!! note "📌 HCP free tier cap"
    HCP free tier caps at **500 managed resources** (legacy free plan ended 2026-03-31).

!!! note "📌 The `cloud` block (TF 1.1)"
    Wire a config to HCP with the **`cloud` block** (TF 1.1) inside `terraform {}` — it sets the org/workspace(s) for remote runs and state, and is the modern replacement for the older `remote` backend. (See [[feature-history]].)

!!! note "📌 `terraform login` / `logout`"
    Authenticate the CLI to HCP Terraform (or any private registry host) with **`terraform login`** — it runs an OAuth flow and stores a token in `~/.terraform.d/credentials.tfrc.json`; **`terraform logout`** revokes it. This is how CLI-driven runs and private-module pulls get credentials. ([HCDocs](https://developer.hashicorp.com/terraform/cli/commands/login))

!!! note "📌 Health assessments (managed drift detection)"
    **Health assessments** are HCP Terraform's managed **drift detection** + **continuous validation**: HCP periodically runs an out-of-band plan on a workspace and reports whether real infrastructure has drifted from state, and whether the config's `check` assertions still hold — without you triggering a run. Enable per-workspace (or org default); trigger an on-demand assessment from the workspace **Health** section. This is the managed counterpart to the CLI-side `-refresh-only` drift check in I7. Interactive: HCTut ["Use health assessments to detect infrastructure drift"](https://developer.hashicorp.com/terraform/tutorials/cloud/drift-detection); the combined drift-plus-policy flow is ["Detect infrastructure drift and enforce policies"](https://developer.hashicorp.com/terraform/tutorials/cloud/drift-and-policy). ([HCDocs](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/health))

**Milestone:** You can run a VCS-driven workspace in HCP Terraform that plans on PR, applies on merge, and stores state remotely.

---

### ⬜ A5 — Policy as Code

**What it is:** Governance guardrails at three layers — **plan-time policy** (Sentinel, open-source OPA/Conftest) enforced against a plan in HCP Terraform or CI; **static analysis (SAST)** of the HCL source (Checkov, Trivy/tfsec, KICS); and **cost gating** (Infracost).

**Why you need it:** Organizations must prevent non-compliant infra (untagged, wrong region, oversized) before apply; the Pro exam covers policy/governance.

**How to learn it:**

1. **Video — [HashiCorp "Introduction to Sentinel, Policy as Code Framework"](https://youtu.be/Vy8s7AAvU6g)** (~40 min) — what policy-as-code enforces and where it runs in the flow.
2. **Interactive — HCTut [Sentinel](https://developer.hashicorp.com/terraform/tutorials/policy/sentinel-policy) / [OPA](https://developer.hashicorp.com/terraform/tutorials/cloud/validation-enforcement) policy lab** (~1.5 hrs) — write a policy that blocks a plan violating a tagging rule.
3. **Reference — [HCDocs policy enforcement / Sentinel](https://developer.hashicorp.com/terraform/cloud-docs/policy-enforcement) + [OPA Conftest docs](https://www.conftest.dev/)** (~40 min) — Sentinel for HCP, OPA/Conftest for provider-agnostic CI.
4. **Interactive — run a static scanner in CI** (~45 min) — add one of the SAST scanners below to your A3 pipeline and fail the build on a deliberately misconfigured resource.

!!! note "📌 Static analysis (SAST) layer"
    Sentinel/OPA evaluate the **plan** (what Terraform *will do*). A second, complementary layer is **static analysis (SAST)** that scans the *HCL source* for insecure defaults *before* a plan — public S3 buckets, `0.0.0.0/0` ingress, unencrypted volumes — against a built-in rule library. The common tools: **[Checkov](https://www.checkov.io/)** (Prisma/Bridgecrew, largest policy set, also does terraform_plan JSON), **[Trivy](https://trivy.dev/)** (Aqua — absorbed the now-archived **tfsec**; use Trivy for new work), and **[KICS](https://kics.io/)** (Checkmarx, multi-IaC). Run one on every PR next to `fmt`/`validate`; they need no cloud creds and no state, so they're the cheapest guardrail you can add.

!!! note "📌 tflint — the correctness linter next to the security scanners"
    The SAST tools above hunt insecure defaults. **[tflint](https://github.com/terraform-linters/tflint)** is the complementary correctness/style linter: deprecated syntax, invalid provider arguments, unpinned dependencies. Two of its [terraform ruleset](https://github.com/terraform-linters/tflint-ruleset-terraform/blob/main/docs/rules/README.md) rules enforce the module pinning that I4 recommends but Terraform itself cannot check, because there is no module lock file. [`terraform_module_version`](https://github.com/terraform-linters/tflint-ruleset-terraform/blob/main/docs/rules/terraform_module_version.md) requires registry modules to carry a version, and takes `exact = true` (default `false`) to reject every constraint operator except `=`. `terraform_module_pinned_source` catches Git and Mercurial sources with no pin at all. Both are cheap PR-time checks needing no creds and no state, so they belong in the same pipeline stage as Checkov/Trivy.

!!! note "📌 Cost governance (Infracost)"
    **Cost governance** — [Infracost](https://www.infracost.io/) estimates the **$ delta** of a plan (it reads `terraform plan -json` against cloud price APIs) and posts it as a PR comment, so reviewers see cost impact before merge. It's the open, CI-native counterpart to HCP Terraform's built-in cost estimation (A4). Pair it with a policy (`infracost` has its own policy/threshold gating) to block a PR that blows a budget.

**Milestone:** You can write a policy that fails any plan creating an untagged or oversized resource, wire it into a run, and add a SAST scanner (Checkov/Trivy/KICS) plus an Infracost cost check to the PR pipeline.

---

### ⬜ A6 — Secrets & sensitive data

**What it is:** Handling secrets — the `sensitive` flag, sensitive values in state, **ephemeral values / ephemeral resources / ephemeral input variables & outputs / write-only arguments** (the modern keep-secrets-out-of-state mechanism), the Vault provider, and dynamic/short-lived provider credentials (OIDC into AWS/Azure/GCP).

**Why you need it:** State holds secrets in plaintext by default; long-lived cloud keys in pipelines are a top risk. The Pro exam tests sensitive-data best practices.

**How to learn it:**

1. **Reference — [HCDocs "Manage sensitive data"](https://developer.hashicorp.com/terraform/language/manage-sensitive-data) (umbrella) + ["Sensitive data in state"](https://developer.hashicorp.com/terraform/language/state/sensitive-data) + ["Dynamic Provider Credentials"](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials)** (~40 min) — why `sensitive` isn't encryption and how OIDC removes static keys. (Umbrella captured in [[tf-manage-sensitive-data]] — the hide-vs-omit-vs-both decision framework, the version-requirements matrix (0.15 `sensitive` / 1.10 `ephemeral` / 1.11 write-only), write-only `_wo`/`_wo_version`, and the state-encryption backends.)
2. **Reference — [HCDocs "Ephemeral values"](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral)** (~40 min) — the current best-practice for secrets. `sensitive` only hides a value in output; it's still written to state in plaintext. **Ephemeral values** (TF 1.10) exist only during a single command run and are *never* written to state or plan. **Ephemeral resources** (a block type that opens/closes a short-lived external object, e.g. fetch a token) and **write-only arguments** (TF 1.11 — resource arguments like a DB password that Terraform can write but never read back, versioned via a companion `*_wo_version` attribute) together let you pass a secret straight into a resource with nothing persisted. OpenTofu reached parity in 1.11.
3. **Interactive — HCTut [dynamic credentials lab](https://developer.hashicorp.com/terraform/tutorials/cloud/dynamic-credentials)** (~1.5 hrs) — configure OIDC so a pipeline assumes a role with no stored secret.
4. **Book chapter — TID Ch 8 §8.5 "Managing secrets" / TUR Ch 6 "Managing Secrets with Terraform"** (~1 hr) — Vault integration and secret-injection patterns.
5. **Reference — [Infisical, "A Guide to Terraform Secrets Management"](https://infisical.com/blog/terraform-secrets-management)** (~25 min) — the **end-to-end workflow** the HashiCorp reference pages leave out, captured as [[infisical-terraform-secrets]]. A **vendor post** (every example routes through the `infisical` provider), so read the product comparison as marketing — but the Terraform mechanics check out and three things here have no equivalent in the official docs: a `grep` that finds `random_password` stored **three times** in state (attribute, output, bcrypt hash) against an apply that printed `<sensitive>` throughout; the same secret fetched ephemerally leaving a **181-byte state with no trace**; and an **anti-pattern review table**. Also the vendor-neutral criteria for picking a secrets manager (official registry provider · ephemeral reads · dynamic secrets + rotation · hosting/license), the note that **cloud KMS is not a secrets manager** (no per-secret ACLs, audit, or rotation), and where **SOPS** fits (file encryption whose committed ciphertext still diffs — a complement, not a replacement).

!!! note "📌 Two kinds of secret, two different fixes"
    The framing that organizes this topic: Terraform touches secrets it **manages** (the DB passwords and API keys it sets on your infrastructure) and secrets it **uses** (the credentials that let it call your cloud and your secrets manager). The first kind is fixed *inside* the config — `ephemeral` blocks and write-only arguments. The second is fixed *outside* it: the credential should reach Terraform **from the environment it runs in, never from the code it runs**, which in CI means a short-lived OIDC token exchanged against a machine-identity binding (`repo:org/repo:ref:refs/heads/main`) rather than a stored client secret. The identity ID is public and safe to commit. The `TF_VAR_`-prefixed secret name is the tie-in — store `TF_VAR_db_admin_password` and the plan step reads `var.db_admin_password` with nothing on the command line. (See [[infisical-terraform-secrets]]; precedence in [[tf-input-variables]].)

!!! note "📌 Pass coordinates into modules, not values"
    A module input like `db_password = var.db_password` multiplies the problem: **every caller** must hold the raw value, and it lands in **each calling configuration's own state** once the module uses it — one secret copied into every stack. Pass the *location* instead (`workspace_id` / `env_slug` / `secret_path`) and let the module fetch its own value with a data source or, better, an `ephemeral` block. Access is then controlled in the secrets manager rather than by who holds the variable. (See [[infisical-terraform-secrets]].)

!!! note "📌 Dynamic secrets vs. rotation — shrinking the theft window"
    Both replace "one static value that's worth stealing for as long as it lives," and they are **not** the same mechanism. **Dynamic secrets:** the platform holds a privileged login to the backend and mints a *new user per lease* (creation statement in, revocation statement at expiry) — Terraform's apply stores only the **instructions**, and generating a lease is a separate out-of-band step, so a leaked credential is worthless within hours. **Rotation:** for systems that need a single standing login — keep **two** users, one live and one idle, set a new password on the idle one, and switch the mapped secret keys over, so consumers migrate with no downtime and nothing redeploys. Reach for rotation only when dynamic isn't possible. (See [[infisical-terraform-secrets]].)

!!! warning "📌 `sensitive` leaks through `terraform output -json` / `-raw`"
    `sensitive` redacts values in normal CLI logs and the HCP UI, but the redaction is **narrower than it looks**. It redacts on plan/apply/destroy and on `terraform output` (all). It does **not** redact when you query **by name** (`terraform output db_password` → plaintext), with `-json`, or with `-raw`, nor when a child module's output is used in the root — the flags feed automation, so they bypass redaction by design. Combined with the fact that `sensitive` values are stored in state/plan as **plain text** anyway, this is why `sensitive` alone is *hiding*, not *protecting*. Use `ephemeral` (+ write-only args) to keep a secret out of state entirely. (See [[tf-manage-sensitive-data]]; the full redaction matrix is in [[tut-outputs]].)

    **Verified on v1.15.8**, because the docs disagree with each other here. `terraform output` with no argument prints `password = <sensitive>`; `terraform output password` prints `"notasecurepassword"`. The **language** *Output Values* page claims a named query shows `<sensitive>` — that is **wrong**, and the CLI command reference has it right. Transcript in [[tf-cmd-output]]. Also settled: `terraform output` can never surface an ephemeral value, since an ephemeral output is rejected in a root module *and* a root output cannot derive from a child's ephemeral output.

!!! warning "📌 A saved plan file is as sensitive as state"
    State gets all the attention, but `terraform plan -out=FILE` produces a second plaintext artifact with the same problem. [HCDocs](https://developer.hashicorp.com/terraform/cli/commands/plan) puts it plainly: "If your plan includes any sort of sensitive data, even if obscured in Terraform's terminal output, it will be saved in cleartext in the plan file." It carries a full prior-state snapshot and every input variable value, so `sensitive` does nothing for it — the same *hiding not protecting* gap as the redaction warning above. `terraform show -json` on that file exposes the lot, with `before_sensitive`/`after_sensitive` merely *marking* which values are secret. Never commit one, never paste one into a build log. The pipeline handling is in **A3**; the durable fix is the same as for state, which is `ephemeral` and write-only arguments so the value never enters plan or state at all.

!!! danger "📌 `terraform_remote_state` is a state-exfiltration path"
    Granting a config the ability to read another workspace's **outputs** via `terraform_remote_state` necessarily grants it read access to that workspace's **entire state snapshot** — outputs and state live in one object, and anything that can fetch the outputs can fetch the object by direct network request. Secrets in that state are plaintext.

    Treat "who may read this state" as the real permission boundary, not "which outputs do I expose." On HCP Terraform use **`tfe_outputs`**, which authorizes outputs without full state access; elsewhere publish shared values to a store with its own ACLs. (See [[tf-remote-state-data]]; full treatment in **I6**.)

**Milestone:** You can run a pipeline that authenticates to a cloud via short-lived OIDC credentials (no static keys), set a resource secret via a write-only argument so it never lands in state, and explain why `sensitive` alone doesn't protect the state file. (See [[feature-coverage-matrix]].)

---

### ⬜ A7 — Multi-environment & multi-account patterns

**What it is:** Structuring dev/stage/prod and multiple accounts/regions — CLI workspaces vs directory-per-env vs HCP workspaces, and DRY strategies.

**Why you need it:** Environment isolation done wrong causes cross-env blast radius; the Pro exam and every real org need a scalable layout.

**How to learn it:**

1. **Book chapter — TUR Ch 3 (§ "Isolation via Workspaces" p94 / "Isolation via File Layout" p100) + Ch 7 "Working with Multiple Providers"** (~2 hrs) — file-layout vs workspace tradeoffs (the definitive treatment), then Ch 7 for the multi-account/multi-region half of this topic (§ "Working with Multiple AWS Accounts" p238).
2. **Reference — [HCDocs "Workspaces" (CLI)](https://developer.hashicorp.com/terraform/language/state/workspaces) vs [HCP workspaces](https://developer.hashicorp.com/terraform/cloud-docs/workspaces)** (~30 min) — understand why CLI workspaces are *not* environment isolation. In automation, **`TF_WORKSPACE`** selects the workspace non-interactively (instead of `terraform workspace select`). The CLI page is captured in [[tf-state-workspaces]], which pins down the piece the other sources leave vague: **which backends actually support named workspaces** (ten, enumerated — `http` and `oci` are not among them), so "remote backend" and "multiple states" are separate properties.
3. **Interactive — restructure** (~1.5 hrs) — lay out one module consumed by isolated dev/prod stacks with separate state.

!!! note "📌 Already captured — [[workspaces]]"
    The two meanings of "workspace" are already written up in [[workspaces]], from TID Ch6 §6.4.5 + §6.4.7 and the official docs: the CLI-vs-HCP comparison table, where each backend stores per-workspace state, `terraform.workspace` at plan time, and the documented limit that workspaces "are not appropriate for system decomposition or deployments requiring separate credentials and access controls." What remains for A7 is the *decision* — TUR Ch3's file-layout-versus-workspace tradeoff — and the multi-account half from TUR Ch7.

!!! note "📌 DRY across environments → Terragrunt (E4)"
    A7 covers isolation with **native Terraform** primitives — the scope the Pro exam tests. The DRY tooling that removes the copy-paste between per-env directories is **Terragrunt** (third-party, Gruntwork), deep-dived in **E4 — Large-scale state & repo architecture** below. Reach for it once you have many states and teams, not for a single dev/prod split.

**Milestone:** You can design an env layout where prod and dev have fully isolated state and blast radius, sharing modules but not state.

---

### ⬜ A8 — Refactoring at scale

**What it is:** Safely evolving large codebases — `moved`/`import`/`removed` blocks, module version bumps across consumers, splitting monolith state, and state migration.

**Why you need it:** Big Terraform codebases must be refactored without downtime or resource re-creation; this is a senior/Pro-level skill.

**How to learn it:**

1. **Reference — [HCDocs "Refactoring" (moved blocks)](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)** (~40 min) — config-driven refactors that keep the plan empty. Pair it with [HCDocs "Refactor Terraform state"](https://developer.hashicorp.com/terraform/language/state/refactor), captured in [[tf-state-refactor]] — the **cross-configuration** half that `moved` blocks can't do: the four refactor triggers, the three grouping properties (volatility, stateful-vs-stateless, team ownership), the three ways to keep references dynamic after the split, and the `removed` + `import` migration (**1.7+**) that HashiCorp now recommends over legacy `state mv -state/-state-out` (1.0+).
2. **Book chapter — TID Ch 9 §9.5 "Refactoring" + §9.6 "External refactoring" / TUR Ch 5 "Refactoring Can Be Tricky" (p186)** (~1 hr) — splitting state and versioned module rollouts. The state-surgery side (`terraform state mv`, moved blocks) is Ch 6 §6.5 *Manipulating state*.
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
3. **Reference — [Provider-defined functions](https://developer.hashicorp.com/terraform/plugin/framework/functions)** (~30 min) — the author side of the B7 note: expose your own `provider::<name>::<fn>()` functions from the provider (TF 1.8+), not just resources and data sources.
4. **Book chapter — TID Ch 12 "Terraform providers"** (~2 hrs) — the book's provider-authoring chapter and the mental model of the plugin protocol: §12.1 Design, §12.2 Developer environment, §12.3 Plugin Framework features, §12.4 Provider interface, §12.5 Data source, §12.6 Resources, §12.7 Functions, §12.8 Publishing.

!!! note "TUR does not cover writing providers"
    **TUR has no provider-authoring content** — verified against the book. Its Ch 7 is *"Working with Multiple Providers"* (using several providers: multiple regions/accounts/clouds), and its only "custom provider" mentions are about *downloading* one from a private registry. For authoring, use **TID Ch 12** plus the TPF docs above.

!!! note "📌 `dev_overrides` for local provider testing"
    To test a locally-built provider without publishing it, add a **`dev_overrides`** block (inside `provider_installation` in the [CLI config file](https://developer.hashicorp.com/terraform/cli/config/config-file), v0.14+) pointing at your compiled binary. It bypasses the registry, version, and lock-file checks — `terraform init` is skipped entirely. Point `TF_CLI_CONFIG_FILE` at a dev-only config so you don't disturb your normal setup. Temporary dev use only. (See [[feature-history]].)

!!! note "📌 Provider SDKs: Plugin Framework vs SDKv2"
    Two provider SDKs exist: the modern **Plugin Framework** (use for new providers) and the **legacy SDKv2** (`terraform-plugin-sdk/v2`) that most existing providers still ship on. Know SDKv2 exists — you'll read its code and may maintain it — but author new work on the Framework. ([HCDocs which-SDK](https://developer.hashicorp.com/terraform/plugin/framework-benefits))

!!! note "📌 `provider_meta` schema"
    A provider can also declare a **`provider_meta`** schema ([HCDocs internals](https://developer.hashicorp.com/terraform/internals/provider-meta)) — module-specific metadata a module passes to the provider independently of provider config, mainly so a vendor shipping both a provider and official modules can collect per-module usage stats. Niche; you'll rarely author it. (See [[feature-history]].)

!!! note "📌 Publishing a provider"
    Beyond writing it, **publishing** a provider is its own step: tag semver releases, GPG-**sign** them, and register the signing key so the registry (public or a private HCP registry) will serve it. ([HCDocs publishing](https://developer.hashicorp.com/terraform/registry/providers/publishing))

**Milestone:** You can build and locally install a custom provider exposing one resource with full CRUD and passing acceptance tests. Stretch: expose a provider-defined function callable as `provider::<name>::<fn>()`.

---

### ⬜ E2 — Terraform Stacks

**What it is:** Terraform Stacks — the newer construct for defining components and deployments to provision the same infrastructure across many environments/regions from one definition.

**Why you need it:** Stacks are HashiCorp's answer to multi-deployment orchestration that previously required Terragrunt or custom tooling; increasingly relevant for platform teams.

**How to learn it:**

1. **Reference — [HCDocs "Stacks" overview](https://developer.hashicorp.com/terraform/language/stacks) + configuration** (~1 hr) — components, deployments, and how Stacks differ from modules/workspaces. Note **deferred changes** — Stacks can plan partially when some values aren't known yet (e.g. a downstream component depends on an upstream one's not-yet-created output), then complete on a later run.
2. **Interactive — HCTut [Stacks: "Deploy a Stack with HCP Terraform"](https://developer.hashicorp.com/terraform/tutorials/cloud/stacks-deploy)** (~2 hrs) — define a stack with multiple deployments and run it in HCP Terraform.
3. **Explainer — [HashiCorp "Terraform Stacks, explained"](https://www.hashicorp.com/en/blog/terraform-stacks-explained)** (~20 min) — see the deployment fan-out in practice; pair with a current Stacks demo on the [HashiCorp YouTube channel](https://www.youtube.com/@HashiCorp/search?query=terraform%20stacks).

!!! info "Deferred actions — the real fix for an unknown `count`/`for_each`"
    The plan-time-known limitation from **B7/I1** ([§4.8.4](../books/tid/chapters/04-expressions-iterations.md#484-the-plan-time-known-limitation-important) — a `count`/`for_each` that depends on a not-yet-created attribute errors at plan) is exactly what **deferred actions** resolve. Instead of erroring, Terraform plans a *placeholder* for the unknown instances and defers their create/update to a **later apply round** — the productized version of "split the config so the dependency applies first," with no `-target` surgery.

    - **Stacks ship it in production:** a component whose inputs aren't known yet — the canonical *provision an EKS cluster, then deploy Kubernetes resources into it* — has its changes deferred, and every downstream component with it, preserving order ([Stacks EKS-deferred tutorial](https://developer.hashicorp.com/terraform/tutorials/cloud/stacks-eks-deferred)).
    - **Open-source CLI:** the same machinery is **experimental** (`plan -allow-deferral`, [PR #34651](https://github.com/hashicorp/terraform/pull/34651)), not GA as of 1.15.
    - **Terraform-exclusive** — OpenTofu has no deferred actions (see E3). This is a large part of *why* Stacks exist: they span create-then-configure boundaries a flat config can't.

!!! note "📌 Stacks is newer than both books"
    Stacks is newer than both books — rely on HCDocs and verify feature availability (HCP vs CLI) as it evolves.

**Milestone:** You can define a stack with reusable components and deploy it to three environments from a single stack configuration — and explain how **deferred changes** let a stack span a create-then-configure boundary (an unknown `count`/`for_each`) that a flat config can't.

---

### ⬜ E3 — OpenTofu deep dive

**What it is:** OpenTofu's divergence from Terraform — **state encryption**, provider/backend `for_each`, early variable evaluation, the `-exclude` flag, dynamic `prevent_destroy`, `destroy = false`, and `-json-into` — plus which gaps Terraform 1.15 closed, and migration between the two.

**Why you need it:** OpenTofu is a genuine fork with features Terraform's open-source CLI lacks; choosing between them and migrating is a real strategic/technical decision.

**How to learn it:**

1. **Reference — [OTDocs "Migrating from Terraform"](https://opentofu.org/docs/intro/migration/) + [state encryption](https://opentofu.org/docs/language/state/encryption/)** (~1 hr) — what's OpenTofu-only and how state stays compatible.
2. **Interactive — enable state encryption** (~1 hr) — turn on OpenTofu client-side state encryption and confirm state is unreadable at rest.
3. **Reference — the OpenTofu-only divergence features** (~1.5 hrs) — read one doc page per feature; each has a captured note:
    - **Provider `for_each`** (OpenTofu 1.9) — [OTDocs "Provider Configuration"](https://opentofu.org/docs/language/providers/configuration/); one provider instance per region/account from a map/set. Aliased configs only; resource `for_each` must be a *subset* of the provider's. (Notes: [[ot-provider-for-each]].)
    - **Early variable evaluation** (OpenTofu 1.8) — [OTDocs "Backend Configuration" → Variables and Locals](https://opentofu.org/docs/language/settings/backends/configuration/); reference `var`/`local` in `backend`/`provider` blocks, resolved at `tofu init`. Kills backend partial-config boilerplate. (Notes: [[ot-early-eval-backend]].)
    - **`-exclude` flag** (OpenTofu 1.9) — [OTDocs "Command: plan" → Resource Targeting](https://opentofu.org/docs/cli/commands/plan/); inverse of `-target`, mutually exclusive with `-target`. Terraform has no equivalent. **OpenTofu 1.10** added the file-driven variants **`-exclude-file`** and **`-target-file`** (read addresses from a file — cleaner for large blue/green or canary target lists in CI). (Notes: [[ot-exclude-flag]].)
    - **Dynamic `prevent_destroy`** (OpenTofu 1.12) — [OTDocs lifecycle](https://opentofu.org/docs/language/meta-arguments/lifecycle/) + [1.12 release](https://opentofu.org/blog/opentofu-1-12-0/); bind it to a variable (Terraform requires a literal). See the I5 callout. (Notes: [[ot-dynamic-prevent-destroy]].)
    - **`destroy = false` lifecycle** (OpenTofu 1.12) — [1.12 release](https://opentofu.org/blog/opentofu-1-12-0/); remove an object from state without destroying the remote object, as a lifecycle arg rather than Terraform's separate `removed` block. See the I7 callout. (See [[tf115-ot112-features]].)
    - **`-json-into=FILENAME`** (OpenTofu 1.12) — [1.12 release](https://opentofu.org/blog/opentofu-1-12-0/); write the JSON stream to a file while keeping the human UI on stdout (vs `-json`, which replaces stdout). Handy for CI that wants both. See the A3 callout. (See [[tf115-ot112-features]].)
    - **`.tofu` / `.tofurc` file extensions** (OpenTofu 1.8) — parsed alongside `.tf`/`.terraformrc`; lets a file target OpenTofu specifically (e.g. an OpenTofu-only override) without disturbing a Terraform toolchain reading the same directory. (See [[opentofu-feature-history]].)
    - **OpenTelemetry tracing** (OpenTofu 1.10, experimental) + **full cross-platform provider checksums** at `tofu init` (1.12) — see the E5 and B3 callouts. (See [[opentofu-feature-history]].)
    - **Ephemeral resources + `issensitive()` unknown-correctness** (OpenTofu 1.11) — OpenTofu 1.11 added **ephemeral resources/values** (matching Terraform 1.10) and made **`issensitive()` return an *unknown* result when its argument is unknown**. That's a **breaking change**: code that fed an `issensitive()` result into `count`/`for_each` (where unknowns are illegal — see B7/I1 §4.8.4) now **fails at plan** — key on a plan-known value instead, or don't branch on the sensitivity of an unknown. (See [[opentofu-feature-history]].)
4. **Book — TID (covers both)** (~1 hr) — re-read the sections contrasting the two tools with fresh eyes.

!!! info "📌 OpenTofu ↔ Terraform — the gap runs both ways now"
    **Terraform 1.15** (2026-04-29) closed several long-standing OpenTofu-only gaps — dynamic module sources, variable/output deprecation, output type constraints (a side effect: a fully-typed module interface makes `module.<NAME>` a `list`/`map` under `count`/`for_each` rather than a `tuple`/`object`, so **OpenTofu module references stay structural** — verified, though auto-conversion means callers rarely notice either way, [[conditional-branch-evaluation]]) — and added the net-new **`convert()`** function ([opentofu #2630](https://github.com/opentofu/opentofu/issues/2630) is still open — though what OpenTofu lacks is the *function*, not the capability: a typed `variable` boundary does the same coercion, and the gap is only *inline* arbitrary object/tuple schemas), so "OpenTofu has features Terraform lacks" is narrower than it was. What remains OpenTofu-only: state encryption, provider `for_each`, early variable evaluation, `-exclude`, dynamic `prevent_destroy`, `destroy = false`, and `-json-into`. (See [[tf115-ot112-features]], [[version-facts]].)

**Milestone:** You can migrate a project from Terraform to OpenTofu, enable state encryption, and explain the OpenTofu-only features — provider `for_each`, early variable evaluation in backend config, the `-exclude` flag, dynamic `prevent_destroy`, `destroy = false`, and `-json-into` — including *why* a resource's `for_each` must be a subset of its provider's, and which gaps Terraform 1.15 has since closed.

---

### ⬜ E4 — Large-scale state & repo architecture

**What it is:** Organizing many states and many teams — Terragrunt for DRY/orchestration, monorepo vs multi-repo, dependency ordering across states, and remote-state composition.

**Why you need it:** At scale, flat repos and giant states collapse; deliberate architecture is what keeps plans fast and blast radius small.

**How to learn it:**

1. **Reference — [TG docs (Terragrunt)](https://terragrunt.gruntwork.io/docs/)** (~1.5 hrs) — DRY backends, `dependency` blocks, `run --all`, and where Terragrunt still beats native features. Terragrunt is the open-source route to strong dev/staging/prod isolation (directory-per-env, own backend/state each) — the open counterpart to proprietary HCP Terraform workspaces (see [[workspaces]]).
2. **Book chapter — TUR Ch 3 + Ch 5** (~2 hrs) — state isolation and repo-structure tradeoffs at scale.
3. **Reference — [HashiCorp "Terraform mono-repo vs. multi-repo: the great debate"](https://www.hashicorp.com/en/blog/terraform-mono-repo-vs-multi-repo-the-great-debate)** (~30 min) — monorepo-vs-multirepo decisions in the wild, plus [native monorepo support](https://www.hashicorp.com/en/blog/terraform-adds-native-monorepo-support-stack-component-configurations-and-more).
4. **Reference — [OpenTofu OCI registries](https://opentofu.org/docs/cli/oci_registries/)** (~40 min) — distributing **providers and modules via OCI registries** (`oci://` module sources; `oci_mirror` for provider plugins), reusing existing container registries (ECR, GAR, ACR, Docker Hub) instead of a dedicated Terraform registry. OpenTofu 1.10+, OpenTofu-first. (See [[feature-coverage-matrix]].)

!!! note "📌 Terragrunt 1.0 (2026-03-30)"
    Terragrunt **1.0** shipped 2026-03-30 — first release with a backwards-compatibility commitment; `run-all` is now `run --all`. Works over both Terraform and OpenTofu.

**Milestone:** You can design a multi-team layout with per-component state, cross-state dependencies, and DRY backend config that keeps each plan small.

---

### ⬜ E5 — Debugging, performance & scaling

**What it is:** Diagnosing and speeding up Terraform — `TF_LOG` levels, the resource graph, `-parallelism`, provider plugin caching, `-refresh=false`, targeted plans, and large-state performance.

**Why you need it:** Slow plans and cryptic errors block whole teams; senior engineers must diagnose the graph and tune throughput.

**How to learn it:**

1. **Reference — [HCDocs "Debugging" (`TF_LOG`)](https://developer.hashicorp.com/terraform/internals/debugging)** (~25 min) — log levels (`TRACE`…`ERROR`), sending logs to a file with **`TF_LOG_PATH`**, splitting core vs provider logs (`TF_LOG_CORE`/`TF_LOG_PROVIDER`), and where a panic writes **`crash.log`**.
2. **Reference — [HCDocs `terraform graph`](https://developer.hashicorp.com/terraform/cli/commands/graph)** (~20 min) — the DOT output, `-type=plan|apply|plan-destroy|plan-refresh-only` for the runtime graph (provider nodes, `(expand)` nodes), `-plan=tfplan` for a saved plan, and `-draw-cycles`. Notes: [[tf-cmd-graph]], [[dependency-graph]].
3. **Interactive — diagnose a cycle** (~30 min) — write two resources that reference each other, watch `plan` fail with `Error: Cycle: …`, then run `terraform graph -type=plan -draw-cycles | dot -Tsvg > cycle.svg` and find the red edges that close the loop.
4. **Interactive — profile a slow plan** (~1.5 hrs) — enable the plugin cache, tune `-parallelism`, and measure the difference on a large config.
5. **Book chapter — TID Ch 5 §5.7 "Common pitfalls and errors" / TUR Ch 5 (the "Gotchas" half of *Tips and Tricks: Loops, If-Statements, Deployment, and Gotchas*)** (~1 hr) — common failure modes and their fixes. (TID has no dedicated troubleshooting chapter; §5.7 is the closest — captured in [[05-terraform-plan]].)

!!! tip "🔧 Diagnosing `Error: Cycle`"
    The error names the cycle's **members**, not the **edges** that close it. On a two-resource cycle that's the same thing; on a real config it isn't. `-draw-cycles` reddens the offending edges:

    ```dot
    "[root] terraform_data.a (expand)" -> "[root] terraform_data.b (expand)" [color = "red", penwidth = "2.0"]
    ```

    It requires an explicit `-type=`. Without one, `-draw-cycles` is **silently ignored** — no warning, exit 0 — and the default resources-only graph renders only *one* of the two edges, so the cycle is invisible. Verified on v1.15.6. Common causes: a `depends_on` pointing back up the chain, and `create_before_destroy` on only one resource of a mutually-referencing pair. (See [[tf-cmd-graph]].)

!!! warning "The graph shows what Terraform knows, not what's true"
    `terraform graph` renders every edge Terraform built — and a **missing hidden dependency has no edge**, so it looks identical to a resource with no dependencies. Use the graph to *confirm* a suspected ordering bug, never to *discover* one. When a plan passes locally and races in CI, suspect a missing `depends_on` (I1) before you suspect `-parallelism`. (See [[dependency-graph]].)

!!! tip "Cleaning up the noisy `terraform graph` output"
    The raw DOT carries provider, root, and `(expand)` nodes on top of your resources, so a real config's graph is hard to read. Three easier-to-read options:

    - **SVG over PNG.** `terraform graph | dot -Tsvg > graph.svg` is zoomable and searchable.
    - **Online renderer.** Paste the DOT into [edotor.net](https://edotor.net); no Graphviz install needed.
    - **Prune with InfraMap.** [`cycloidio/inframap`](https://github.com/cycloidio/inframap) (v0.8.1, actively maintained as of mid-2026) reads state or HCL and emits only the resources that matter, dropping provider and meta nodes. It auto-detects the input: `inframap generate main.tf | dot -Tsvg > graph.svg`, or a state file with `inframap generate terraform.tfstate`. Force it with `--hcl`/`--tfstate` if detection guesses wrong.

    Interactive browser viewers (Rover, Blast Radius) exist, but the well-known ones are unmaintained (Rover's last release was 2022), so check that a tool is current before relying on it. (See [[tf-cmd-graph]].)

!!! note "📌 Global provider plugin cache"
    A shared **global provider plugin cache** (`TF_PLUGIN_CACHE_DIR` / `plugin_cache_dir`) avoids re-downloading providers per project. It historically wasn't safe for concurrent `init`s; **OpenTofu 1.10** added filesystem **cache locking** (flock/LockFileEx) so parallel CI jobs can share one cache without corruption. (See [[opentofu-feature-history]].)

!!! note "📌 Provider mirrors for air-gapped setups"
    For air-gapped or locked-down environments, the CLI config's **`provider_installation`** block configures **`filesystem_mirror`** (serve providers from a local directory) and **`network_mirror`** (serve from an internal HTTPS mirror) instead of the public registry. Populate a mirror with **`terraform providers mirror DIR`**. ([HCDocs CLI config](https://developer.hashicorp.com/terraform/cli/config/config-file#provider-installation))

!!! note "📌 Checkpoint telemetry opt-out"
    The CLI phones home to HashiCorp's **Checkpoint** service for version + security-bulletin checks (this drives the "newer version available" line in `terraform version`). Only anonymous data is sent. Disable it in airgapped/privacy-sensitive setups: **`CHECKPOINT_DISABLE=1`** (env, all HashiCorp tools) or CLI-config **`disable_checkpoint = true`** (all calls) / **`disable_checkpoint_signature = true`** (keep bulletin checks, drop the anonymous signature). (See [[tf-cli-commands]].)

!!! warning "📌 `experiments` — not for production"
    The `terraform {}` block's **`experiments = [...]`** argument opts a module into pre-release language features for feedback (e.g. optional object attrs before 1.3 GA'd them). Advanced and **not for production** — it warns on every plan/apply and can break in minor/patch releases. ([HCDocs terraform block](https://developer.hashicorp.com/terraform/language/block/terraform))

!!! info "📌 OpenTofu — OpenTelemetry tracing (1.10)"
    On OpenTofu, **experimental OpenTelemetry tracing** (OpenTofu 1.10, off by default via `OTEL_*` env vars) emits spans for a run — useful for pinpointing which providers/resources dominate a slow plan/apply. Terraform has no built-in OTel equivalent. (See [[opentofu-feature-history]].)

!!! note "📌 High-cardinality perf + `rpcapi` (Terraform 1.13)"
    Terraform **1.13** made evaluation of **high-cardinality `count`/`for_each`** (hundreds+ of instances) much faster — relevant when a big config's graph is the bottleneck. For building tooling *around* Terraform, `terraform rpcapi` (1.13, GA) exposes core operations over a plugin RPC interface. (See [[feature-history]].)

**Milestone:** You can diagnose a failing/slow apply from `TF_LOG` output and cut plan time on a large config via caching and parallelism tuning.

---

### ⬜ E6 — Platform engineering & self-service

**What it is:** Terraform as an internal platform — golden/opinionated modules, self-service via HCP no-code modules or an IDP (e.g. Backstage), run tasks, and org-wide drift detection.

**Why you need it:** The end state of Terraform maturity is letting product teams provision safely without writing raw HCL; this is the platform-engineering frontier.

**How to learn it:**

1. **Reference — [HCDocs "No-Code modules"](https://developer.hashicorp.com/terraform/cloud-docs/no-code-provisioning/module-design) + [Run Tasks](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/settings/run-tasks) + [private registry](https://developer.hashicorp.com/terraform/cloud-docs/registry)** (~1 hr) — the self-service building blocks.
2. **Video — [HashiCorp "Terraform for platform engineers" (Armon Dadgar)](https://www.hashicorp.com/en/resources/terraform-for-platform-engineers)** (~45 min) — how mature orgs expose Terraform to non-experts via golden modules.
3. **Interactive — HCTut ["Create and use no-code modules"](https://developer.hashicorp.com/terraform/tutorials/cloud/no-code-provisioning)** (~1.5 hrs) — put a golden module in the private registry and let users provision it with no HCL, straight from the HCP UI.

!!! info "📌 OpenTofu — MCP server (1.10)"
    OpenTofu **1.10** ships an **MCP server** — exposes OpenTofu operations to AI agents / LLM tooling via the Model Context Protocol, an emerging building block for AI-assisted self-service IaC. OpenTofu-only. (See [[opentofu-feature-history]].)

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

**You are currently here:** Beginner — B1–B8 done (Ch 1–8 written). Next up: **B9 (State fundamentals)**.

---

## Sources consulted

- HashiCorp Developer — Certifications / Infrastructure Automation — https://developer.hashicorp.com/certifications/infrastructure-automation
- HashiCorp Developer — Terraform Associate 004 study path — https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-study-004
- HashiCorp Developer — Terraform Authoring & Operations Pro exam content — https://developer.hashicorp.com/terraform/tutorials/pro-cert/pro-review
- OpenTofu 1.12 release coverage (2026-05) — InfoQ
- Terraform CLI release notes (1.15, 2026-04-29; current patch 1.15.7)
- *Terraform in Depth* (Manning) and *Terraform: Up & Running* 3rd ed (O'Reilly) — tables of contents

---

> **Last updated:** 2026-07-17 — **Reference shapes are structural, and typed module outputs change what callers receive.** A contradiction inside Ch 7 (§2 "every resource reference is an object" vs §3 "references look like objects but aren't") turned out to be an instance-vs-container confusion: an *instance* is an object, a bare *type name* is not a value, and the container depends on the meta-argument. Chasing it found the shape line itself wrong — `count` gives a **tuple**, `for_each` an **object**, not the list/map the docs say (the docs [declare that conflation](https://developer.hashicorp.com/terraform/language/expressions/types) openly; §2 is the section that breaks it). **Why structural:** a collection needs one element type and instances aren't guaranteed to share one — `for_each = { a = "str", b = 5 }` yields `a` with `input: string` and `b` with `input: number`, two different object types no map could hold. Resources take that path unconditionally (`evaluate.go:931/952`). **The find worth keeping:** modules *do* switch. `GetModule` branches on "does the module fully define all output types", so adding `type = string` to a module's output flips `module.c` from `tuple` → **`list`** and `module.f` from `object` → **`map`** (verified, TF 1.15.8). So output `type` (1.15+) does change the type callers receive — **but measuring that turned out to deflate it**: auto-conversion means callers can't tell, since a tuple splats, converts, and satisfies a `list(object(...))` constraint exactly as a list does. Ch 6's modest "improves matching across validation, plan, and apply" was right all along, and the B6 🔄 I raised against it was **my** over-claim, not the chapter's under-claim — retracted, along with a flatly false line in I5 saying callers "feel the difference". Noted in **B6**/**I5**/**E3** as a curiosity, not a reason. Finding a real mechanism is not the same as finding it matters. Also fixed: the splat section justified itself with "a `count` resource is a list" (it's a tuple — right conclusion, wrong reason). Two method failures recorded: `terraform_data` is the only provider-free resource *and* is atypical (dynamic attributes), and the `noDynamicTypes` branch that nearly reverted a correct fix lives in `GetModule`, not the resource path. Evidence: [[conditional-branch-evaluation]].
>
> **2026-07-23** — **TID Ch6 (State management) reading note captured** ([[06-state-management]]) — the primary source for the not-yet-written **B9** (state fundamentals) and much of **I6**/**I7**. Covers: why state exists (real-world linkage / reduced complexity / performance / state-only resources), the three storage properties (resiliency/security/availability), the **tfstate JSON** field-by-field (`version` vs `terraform_version`, `serial`, `lineage`, `resources`/`outputs`/`check_results`) with the **sensitive-in-plaintext** and **root-outputs-only** rules, backends (built-in, `local` = dev-only, partial config + `-backend-config`, `cloud` block, `-migrate-state`, CLI-vs-HCP workspace overloading), safe state manipulation (`moved` 1.1 / `removed` 1.7 first → `state rm`/`replace-provider` → hand-edit last), the **four drift categories** and their fixes, `terraform_remote_state` (root outputs, `defaults`, security-vs-data-source tradeoff), and the state-only providers (`random`/`time`/`null`/`terraform_data`). **Currency correction folded in:** the book's Table 6.1 "S3 requires DynamoDB for locking" is stale — S3 native locking (`use_lockfile`) landed in **TF 1.10 / OpenTofu 1.10**, DynamoDB deprecated (see [[version-facts]], [[feature-history]]); flagged in the chapter's version callout. Glossary gained `lineage`, `serial`, State backend, Partial backend config, S3-native locking, State drift, `moved`/`removed` blocks, State-only provider, `keepers`/`triggers`. Topics backlog: **state** now has three sources (promotable once TUR's state chapters land); **refactoring** gains §6.5. Next book chapter: **B9 → docs/book/ch09** blending this note with the HCDocs state notes.
>
> **2026-07-29** — **HCDocs "State" overview captured** ([[tf-state]]) — the reference cited by **B9** step 2 now has a note behind it. Three things the book treatment doesn't state as sharply: state's *primary* purpose is storing **bindings** between remote objects and resource instances (not the file's contents); the **one-to-one mapping rule** is an invariant Terraform only guarantees while it does the creating and destroying, so `terraform import` and `terraform state rm` hand the invariant back to the operator; and `terraform output -json` / `terraform show -json` are the **supported** parse targets for external software, since the state format itself is explicitly allowed to change between versions. Glossary gained *One-to-one mapping rule*. Nav gained a **State** group mirroring the docs sidebar, which also relocated the previously-flat `removed block reference` note into it. Topics backlog **state** now names four sources. Status unchanged — **B9** stays ⬜ until the chapter is written.
>
> **2026-07-29** — **HCDocs "Purpose of Terraform State" captured** ([[tf-state-purpose]]) — the why-state-exists argument behind **B9** step 1. One reason here is **absent from TID Ch6 §6.1**, which otherwise covers the same ground: state retains each resource's most recent **dependency set**, and it does so for **destroy ordering**. Delete a resource from the configuration and the edges that would order its destruction are deleted with it, so the order must come from state. The rejected alternative (a built-in per-resource-type ordering hierarchy) would need Terraform to know ordering semantics for every resource in every provider *and* across providers. Also new: the AWS-tag mapping was a shipped early prototype, not a hypothetical; the attribute cache is "the most optional feature" of state; and `-refresh=false` + `-target` make "the cached state the record of truth", which silently disables detection of the accidental-manual drift category from Ch6 §6.6. Glossary gained *Retained dependencies*. When **B9**'s chapter is written, the dependency-retention reason should join Ch6's four. Status unchanged — **B9** stays ⬜.
>
> **2026-07-29** — **HCDocs "State Storage and Locking" captured** ([[tf-state-backends]]) — the State-section counterpart to the Backends reference in **I6** step 2. A backend has exactly two responsibilities: store state, and provide a locking API, with **locking optional and not universally supported**. The operationally useful guarantee: a non-local backend "will not persist the state anywhere on disk" — **except** when writing to the backend fails, in which case Terraform drops state locally to avoid data loss and the operator must push it manually once fixed. That exception is worth knowing for **A6**, since it leaves a plaintext state file on a machine the guarantee otherwise excludes. Also records the `state push` guards (differing lineage, higher serial, both `-force`-able) and cross-references TID Ch6 §6.3.3, where the lineage check was traced in the 1.15.8 source and found **narrower** than this page's plain "Terraform will not allow this" — empty existing state is always overwritable, a missing lineage on either side is allowed, and the check never runs during a routine plan/apply. Doc-staleness flagged: the page still lists `terraform taint` among working commands, deprecated since **v0.15.2** in favour of `apply -replace`, with no deprecation notice in the 1.15.8 CLI help. The `state push`/`pull` half also serves **I7**. Status unchanged — **I6** and **I7** stay ⬜.
>
> **2026-07-29** — **HCDocs "Refactor Terraform state" captured** ([[tf-state-refactor]]) — the **cross-configuration** refactor guide, folded into **A8** step 1 alongside the module-refactoring reference it complements. `moved` blocks relocate addresses inside one state; this page is about moving resources *between* state files, which `moved` cannot do. The recommended path is now **`removed` + `import` blocks (1.7+)**, with `terraform state mv -state/-state-out` (1.0+) explicitly labelled "a legacy command" carrying "some risk of corrupting your remote state". Also captured: the four refactor triggers, the three grouping properties (volatility, stateful-vs-stateless, team ownership), the three dynamic-reference options ranked data source → `tfe_outputs` → `terraform_remote_state` (the same ranking [[tf-remote-state-data]] justifies on security grounds), and the six-step verification where **empty plans on both sides** are the proof. Two flaws in the page's own example are flagged in the note: it writes the state backup to `terraform.tfstate.backup`, the filename the local backend uses for its own automatic backup, and the apply transcript imports a different instance ID than the rest of the page. The `destroy = false` requirement on the `removed` block is cross-linked to [[tf-block-removed]], where it was verified on 1.15.6 — omit it in a refactor and the resource you are migrating gets destroyed. Status unchanged — **A8** stays ⬜.
>
> **2026-07-30** — **HCDocs "Remove a resource from state" captured** ([[tf-state-remove]]) — the forget-without-destroying how-to, folded into **I7** step 2 and its `removed` danger callout. Two constraints this page adds that no other note had. **`from` rejects instance keys** — `"aws_instance.example[1]"` is not accepted, so a `count`/`for_each` resource is forgotten in full or not at all. And **removal is not undone by editing configuration**: resuming management requires an **import**. Also the reason HashiCorp prefers the block over `terraform state rm`, stated explicitly for the first time in the docs we've captured: the `removed` block goes through plan, so the operation can be previewed; `state rm` mutates state immediately. Worth noting this is the one State page that gets the destroy semantics right on first reading — it never claims `removed` is inherently non-destructive, unlike the block reference itself ([[tf-block-removed]]). Status unchanged — **I7** stays ⬜.
>
> **2026-07-30** — **HCDocs "State Locking" captured** ([[tf-state-locking]]) — the page [[tf-state-backends]] defers to, cited by **I6** step 2 since the path was written and now backed by a note. Sharpens three things the path stated loosely. Locking covers **every operation that could write state**, not just `apply`. It is **silent on success** — "you do not see any message that it happens" — so no output is not evidence that no lock was taken. And acquisition failure is **fatal**: "if state locking fails, Terraform does not continue." The `force-unlock` callout was scoped tighter to match the docs: it is for **your own** lock after automatic unlocking failed, not for clearing a colleague's stuck run, and the lock ID is a **nonce** for one acquisition, so a stale ID will not release the current lock. The page never mentions `-lock-timeout`, so the note pairs it with the `terraform plan` command reference (verified 2026-07-30) — under contention the choice is three-way: fail now, retry for a duration, or skip the lock. Status unchanged — **I6** stays ⬜.
>
> **2026-07-30** — **HCDocs "Workspaces" captured** ([[tf-state-workspaces]]) — the CLI-workspaces page cited by **A7** step 2, and already a primary source behind the [[workspaces]] topic page; now traceable to a note of its own. The fact worth extracting is one neither the topic page nor TID Ch6 had: the docs **enumerate the backends that support named workspaces** — AzureRM, Consul, COS, GCS, Kubernetes, Local, OSS, Postgres, Remote, S3. **`http` and `oci` are absent**, so "remote backend" and "supports multiple states" are separate properties, and a backend choice does not settle the workspace question. Folded into A7 step 2 and into the topic page's state-layout section. Also noted: the page's *Current Workspace Interpolation* heading is pre-0.12 vocabulary — `terraform.workspace` is a **named value**, usable bare in any expression, and the page's own `count` example uses it that way. Status unchanged — **A7** stays ⬜.
>
> **2026-07-30** — **HCDocs "Backend block configuration overview" captured** ([[tf-backend-configure]]) — the first reference **I6** step 2 names, and the configuration counterpart to [[tf-state-backends]]. Three things folded into the path. The **three block limitations**, of which "a `backend` block cannot refer to named values" is the one that shapes real setups — it is *why* partial configuration exists, and **OpenTofu 1.8 lifts it** ([[ot-early-eval-backend]]), making this a live Terraform/OpenTofu divergence rather than a version lag. The **leak path stated at the source**: backend config is written in plaintext to `.terraform/terraform.tfstate` **and captured into every plan file**, which yields a consequence the path had not recorded — a saved plan applies with its **own frozen backend config**, so short-lived credentials inside it can expire before the apply. And the documented **`*.backendname.tfbackend`** filename convention for `-backend-config` files, which [[06-state-management]] §6.4 shows as `backend.tfvars`; both work, but `.tfvars` misfiles backend input as variable input. Nav gained a **Backends** group mirroring the docs sidebar. Status unchanged — **I6** stays ⬜.
>
> **2026-07-30** — **HCDocs "`local` backend" captured** ([[tf-backend-local]]) — first of the per-backend pages, folded into **I6** step 2. Confirms the default backend **locks** (through system APIs), which matters because [[tf-state-locking]] says locking is optional and backend-specific. Two arguments only: `path`, and **`workspace_dir`** — the knob behind the `terraform.tfstate.d` layout [[workspaces]] traces to the source. The section worth knowing is the legacy one: **`-state` / `-state-out` / `-backup`** apply to the local backend (and to *no* backend block at all), and setting them **overrides workspace-based state filename selection entirely** — with all three set, `terraform workspace select` no longer changes which file is read or written. Also two defaulting traps: `-state` without `-state-out` overwrites the input file, and `-state` without `-backup` turns the state filename into a backup *prefix* (`-backup=-` disables backups). HashiCorp recommends against all of it "even if you are running Terraform in automation". Status unchanged — **I6** stays ⬜.
>
> **2026-07-30** — **HCDocs "Remote State" captured** ([[tf-state-remote]]) — the conceptual page behind **I6** step 1, folded in there, with its one genuinely new idea folded into **A4**. Local state makes two separate things a human responsibility, **freshness** and **exclusion**; the remote store fixes the first and locking the second, which is why the page keeps them in separate sections. Its delegation framing is the useful one: remote state is a **read-only sharing channel between configurations** "without relying on any additional configuration store" — the same team-ownership split [[tf-state-refactor]] lists as a refactoring trigger, seen from the consuming side, and the reason [[tf-remote-state-data]]'s whole-snapshot warning matters. **New to the path: HCP's run queue is not a state lock.** A state lock covers one command and is released when it ends, so two people can each plan against the same state and the second apply invalidates the first's reviewed plan; HCP "detect[s] attempts to create a new plan when an existing plan is already awaiting approval, by queuing Terraform operations in a central location", holding the whole plan-then-approve cycle. S3 with `use_lockfile` gives the lock, not the queue. Also noted: this page names `consul_keys` as the Consul reader while [[tf-remote-state-data]]'s table names `consul_key_prefix` — the provider (hashicorp/consul v2.23.0) ships both as data sources, so the pages pick different halves. Status unchanged — **I6** and **A4** stay ⬜.
>
> **2026-07-30** — **HCDocs "`terraform refresh` command" captured** ([[tf-cmd-refresh]]) — folded into **I7**'s `-refresh-only` callout, which **overstated the command's standing**: it said "deprecated-in-spirit", but the CLI reference deprecates it outright in its second sentence. Corrected. The precise facts it adds over [[05-terraform-plan]]: the command is "effectively an alias for `terraform apply -refresh-only -auto-approve`", and `-auto-approve` "is always enabled" — there is no flag that makes it prompt. It also rejects a saved plan file and any planning mode but refresh-only. The documented hazard is **misconfigured** credentials (TID frames it as credentials *expiring* mid-run): a provider that cannot see its objects reports them gone, and refresh removes them from state "without any confirmation prompt" — nothing is destroyed in the cloud, but Terraform forgets it owns anything. Standing advice goes past "use the flag": "avoid using `terraform refresh` explicitly and instead rely on Terraform's behavior of automatically refreshing existing objects as part of creating a normal plan." [[feature-history]] gained the deprecation row (0.15.4). Nav: the CLI group now mirrors the CLI sidebar's own sections (**Inspecting Infrastructure**, **Manually Update State › Inspecting State**) instead of listing commands flat. Status unchanged — **I7** stays ⬜.
>
> **2026-07-30** — **HCDocs "Inspect Infrastructure Commands Overview" captured** ([[tf-cli-inspect]]) — the section index for `graph`, `output`, `show`, `state list`, `state show`, folded into **B3** step 4 beside [[tf-cli-commands]]. Mechanics are all elsewhere; the value is the framing. These are the sanctioned **integration surface** — "you can use these to integrate other tools with Terraform's infrastructure data" — which is the CLI-side statement of the rule [[tf-state]] gives from the state side: parse `terraform show -json` / `terraform output -json`, never the state file, because the format may change between versions. Two scoping details recorded: `output` reads **top-level** outputs only (the same root-module restriction that forces passthrough blocks in [[tf-remote-state-data]]), and both `state` subcommands are scoped to the current working directory **and workspace**, so an empty `state list` can mean the wrong workspace rather than nothing managed. Also noted while checking citations: `terraform state show` has no note yet, though [[tf-state-refactor]] step 2 depends on it for finding an import ID. Status unchanged — **B3** stays ✅ (this only adds a reference).
>
> **2026-07-30** — **HCDocs "`terraform output` command" captured** ([[tf-cmd-output]]), and it settled a **contradiction between two HashiCorp pages**. The CLI reference says "Terraform does not redact sensitive values when you specify the output by name"; the language *Output Values* page says the opposite, showing `terraform output database_password` → `database_password = <sensitive>`. **Verified on v1.15.8: the CLI page is right.** `terraform output` (no argument) redacts; `terraform output password` prints `"notasecurepassword"` in the clear, as do `-raw` and `-json`. So `sensitive = true` protects the aggregate listing and nothing else. [[tf-outputs]] had faithfully copied the false claim from its source and is now corrected in place with the transcript; **[[tut-outputs]] and book Ch 6 already had it right**, so no chapter flips to 🔄. Second finding: the CLI page says ephemeral values are omitted "even if you specify an output by name", but on 1.15.8 that case is **unreachable** — an ephemeral output is rejected in a root module (`Ephemeral outputs are not allowed in context of a root module`) and a root output cannot derive from a child's ephemeral output (`Ephemeral value not allowed`), while `terraform output` reads root outputs only. Marked ❓ in the note rather than called a docs error, since the sentence may be forward-looking. Folded into **A6**'s redaction warning. Status unchanged — **B6** stays ✅, **A6** ⬜.
>
> **2026-07-30** — **HCDocs "`terraform state list` command" captured** ([[tf-cmd-state-list]]) — added to **B3** step 4 beside the inspection group. Two things the path never recorded about a command it uses constantly. The listing order is **defined**: "module depth order followed alphabetically", so your own root resources are always at the top and nested-module ones at the tail. And **`-id=` is a reverse lookup** — given a provider-assigned ID it prints the address that owns it, which is the answer to "the console shows me `sg-1234abcd`, which resource is that?" without grepping state. Verified on v1.15.8 against the emulator lab state, which also turned up an asymmetry worth knowing in scripts: **a missing `-id` is silent (no output, exit 0)** while a missing address filter is a hard `Error: Unknown resource` with exit 1 — so `-id` cannot be used as an existence check by exit status. Status unchanged — **B3** stays ✅.
>
> **2026-07-22** — **B8 gains its HCDocs "Data Sources" note** ([[tf-data-sources]]). Captured the overview page ahead of writing Ch 8: the plan-vs-apply deferral rules (a `data` block whose args depend on a resource changing this plan reads at *apply*, showing `(known after apply)`; otherwise it reads during *refresh* before planning), `depends_on` timing (0.13+; on 0.12 it forced apply-time reads), custom `precondition`/`postcondition` in `lifecycle`, `count`/`for_each` on data blocks (`data.<NAME>[<KEY>]`), aliased-provider reads, and the local-only specialized sources (`template_file`, `local_file`, `iam_policy_document`). Folded in as B8 reference #1. Note flags a likely doc typo: the page says the `count` key "starts at 1" — contradicts 0-based `count.index`, verify before relying. Also captured the **`data` block reference** ([[tf-block-data]]) — the built-in argument catalog: `count`/`for_each` (mutually exclusive; `for_each` takes a map or set of strings), `depends_on`, `provider`, and a `lifecycle` limited to `precondition`/`postcondition` (no destroy-side rules, literal values only). Topic stays ⬜ (chapter not yet written).
>
> **2026-07-22** — **Chapter 8 written — B8 (Data sources) ✅** (`docs/book/ch08-data-sources.md`). Blends the three HashiCorp data-source notes ([[tf-data-sources]], [[tf-block-data]], [[tut-data-sources]]), the `terraform_remote_state` note ([[tf-remote-state-data]]), and TID Ch 2 §2.6 ([[02-hcl-components]]) into: motivating problem (hard-coded AMI/subnet kills portability) → `data` block anatomy + `data.<TYPE>.<NAME>.<ATTR>` reference → the VPC→subnet→AMI **cascade** as dependency edges (with a Mermaid graph) → the **plan-vs-apply read-timing** rule (refresh by default; deferred to apply on a changing-resource/computed/`depends_on` argument, with a decision flowchart) → meta-arguments on data blocks (table) + `precondition`/`postcondition` → local-only sources (`aws_iam_policy_document`) → `terraform_remote_state` root-outputs-only (deep dive deferred to I6). **Lab** hits the milestone directly: create an S3 bucket out-of-band, read it + caller identity + region, build an IAM policy referencing the unmanaged bucket's ARN, apply the one managed `aws_iam_policy` — on the free emulator (S3/STS/IAM). Web-verified current pitfalls (careless `depends_on` → apply-time read + spurious re-creation; external-data-source has no timeout; secret-in-state). Flagged the HCDocs `count`-key "starts at 1" doc slip (it's 0-based). Next: **B9 (State fundamentals)** → TID Ch 5/6.
>
> **2026-07-22** — **B8 reference #2 now points at the official "Query data sources" tutorial** ([[tut-data-sources]], slot 3 of the Configuration Language tutorial series). The hands-on for B8: swap hard-coded region/AZ/AMI for `aws_availability_zones` / `aws_region` / `aws_ami`, and share a VPC workspace's outputs into an app workspace via `terraform_remote_state` (local backend, root-outputs-only, destroy app before VPC). Captured the Community-Edition variant (`cloud {}` commented out). Reinforces the [[tf-remote-state-data]] root-outputs limit from the I6 side.
>
> **2026-07-17** — **Ch 7 §2 rebuilt on the HCL spec; B7 + I1 + E3 corrected.** §2 is now one subsection per complex type (`list`/`tuple`/`set`/`map`/`object`), value-side, each signposting its constraint form to I3. The **collection vs structural** split is taken from **HCL's own spec** rather than paraphrased, and it answers *why* only tuple and object have literals: a literal's text supplies per-position types and exact arity (a structural schema), while a collection needs one shared element type the syntax never states — so it needs **unification**, which needs a target type. "Has a literal" and "is structural" are one property; hence no `totuple()`/`toobject()`. The spec's **type-identity** rules turn out to be the root of the `var.list == []` gotcha and of a tuple's length being part of its type. **Three corrections landed:** (1) **`for_each` also accepts an object** — the error message *and* HashiCorp's docs omit it, OpenTofu's docs get it right ([[ot-provider-for-each]]); it converts nothing (a `list(string)` and a bare tuple are both rejected) and *"of strings"* binds only to the set. (2) **`convert()`'s absence in OpenTofu is the function, not the capability** — a typed `variable` boundary does the identical coercion (verified on OpenTofu 1.12.4); the `toType` casters cannot express an object schema, so the old "portable code sticks to the casters" advice was wrong. (3) Two chapter examples demonstrated a type they weren't (list indexing via a tuple literal, map access via an object literal) — invisible because auto-conversion makes both *work*. All console output re-run on **Terraform 1.15.8**; every quotation re-pulled from raw bytes after the first pass took them from a summarizing fetch. Evidence: [[conditional-branch-evaluation]].
>
> **2026-07-17** — **A1 gains the provisioner-alternative seam** ([[pyinfra]], new "Tools" note course for things that sit *next to* Terraform rather than inside it). A1's scope is "when *not* to use a provisioner" and HashiCorp's answer stops at "use config management" — the notes now show the boundary: **`terraform output -json` is the seam**, Terraform publishes host addresses, a config tool reads them as its inventory, nothing runs inside the apply. Buys untainted failures (a `remote-exec` that fails taints the resource and the next apply destroys a good server) and Terraform-free re-convergence; costs two tools, two runs, and an ordering dependency. Second callout is the sharper find: **outputs vs. state is a blast-radius choice** — pyinfra's connector reads only deliberately-published outputs, while Ansible's `terraform_provider` inventory plugin reads the **whole state file**, secrets included. That's the I6/A6 access-boundary rule surfacing in a new place. pyinfra is not an IaC tool and is captured for the A1 seam only.
>
> **2026-07-17** — **A6/I6 extended from a vendor blog** ([[infisical-terraform-secrets]], new "Infisical Blog" note course — first non-official source in the notes, flagged as such at the course and note level). A6 gains reference #5 plus three callouts the HashiCorp reference pages don't cover: **two kinds of secret** (managed vs. used — in-config `ephemeral`/write-only fixes the first, CI OIDC + `TF_VAR_` fixes the second), **pass coordinates into modules, not values** (a `db_password` input copies one secret into every caller's state), and **dynamic secrets vs. rotation** (per-lease users vs. the two-user live/idle swap). I6 gains the **four properties of a hardened backend** (encrypted/versioned/locked/least-privilege) and the sharper leak: backend config is copied into `.terraform/` *and captured in plan files*, so never `-backend-config` a credential. Evidence worth keeping from the post: a `grep` finds `random_password` in state **three times** (attribute, output, bcrypt hash) after an apply that printed `<sensitive>` throughout; the ephemeral equivalent leaves a **181-byte state**. Topics backlog: **secrets-and-state** now has two sources — promotable.
>
> **2026-07-15** — **Chapter 7 written — B7 (Expressions, operators & built-in functions) ✅** (`docs/book/ch07-expressions-operators-functions.md`). Blends the HashiCorp Expressions-section notes ([[tf-expressions]], [[tf-expr-types]], [[tf-expr-references]], [[tf-expr-operators]], [[tf-expr-strings]], [[tf-expr-for]], [[tf-expr-splat]], [[tf-expr-function-calls]]), [[tf-conditionals]], [[tf-functions]], TID Ch 4 ([[04-expressions-iterations]]) and [[tut-variables]] into: types/null → references + unknown values → operators → ternary → functions → strings/templates → `for`/splat, closing on the milestone (list of maps → keyed map → `for_each`). Every key concept shows **`terraform console` output** so it's verifiable, not asserted. **Corrected a book error:** TID §4.2.5 claims the ternary "evaluates both return results" — verified false on Terraform **1.15.6** *and* OpenTofu **1.12.4**; only the *type* check is unconditional, runtime errors fire only in the branch taken. Lazy evaluation landed in **Terraform 0.12.0** (HCL2 rewrite; issue #15605 fixed in 0.12.0-alpha1) — the claim has been stale ~6 years. Evidence: [[conditional-branch-evaluation]]. **Also audited every TID chapter citation in this path against the book's TOC and fixed 8 off-by-one errors** (B4, B5, B8, I1, I2, I8, A1, A8 — plus B7/I3 earlier); citations now carry §section numbers. TID Ch 5 captured ([[05-terraform-plan]]). Next: **B8 (Data sources)** → TID Ch 2 §2.6.
