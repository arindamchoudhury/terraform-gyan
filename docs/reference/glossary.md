# Glossary

Terms are appended here as book chapters are written.

<!-- term: definition (source chapter) -->

| Term | Definition | Source |
|---|---|---|
| Infrastructure as Code (IaC) | Provisioning and managing infrastructure from declarative, version-controlled configuration files instead of manual steps. | [[terraform-intro]] |
| Provider | A plugin that lets Terraform manage a platform/service through its API; thousands are published on the Terraform Registry. | [[terraform-intro]] |
| Write → Plan → Apply | The core Terraform workflow: define resources, generate an execution plan, then apply approved changes in dependency order. | [[terraform-intro]] |
| State file | Terraform's record of real infrastructure; the source of truth it diffs against configuration to decide changes. | [[terraform-intro]] |
| Resource graph | Dependency graph Terraform builds to create/modify non-dependent resources in parallel. | [[terraform-intro]] |
| Module | Reusable, configurable collection of infrastructure; sourced from the Registry or authored locally. | [[terraform-intro]] |
| Immutable infrastructure | Approach of replacing rather than mutating resources, reducing upgrade/modification complexity. | [[terraform-intro]] |
| Sentinel | HashiCorp's policy-as-code framework; enforces compliance/governance policies before Terraform applies changes. Available in Terraform Enterprise and HCP Terraform. | [[terraform-use-cases]] |
| HCP Terraform Operator | Kubernetes Operator that manages cloud and on-prem infrastructure through a Kubernetes CRD plus HCP Terraform. | [[terraform-use-cases]] |
| Consul-Terraform-Sync (NIA) | Network Infrastructure Automation tool; auto-generates Terraform config to reconfigure an SDN when a service registers with Consul. | [[terraform-use-cases]] |
| TACOS | "Terraform Automation and Collaboration Software" — informal industry term for CI/CD platforms purpose-built for running Terraform (HCP Terraform, Terraform Enterprise, Spacelift, Scalr). | TID Ch1 |
| BSL (Business Source License) | The "shared source" license HashiCorp moved Terraform to (from MPL) starting with v1.6; code stays viewable/auditable but usage is restricted, notably against competitive hosted/embedded offerings. | TID Ch1 |
| DAG (directed acyclic graph) | The data structure Terraform builds from resource dependencies to order plan actions; circular dependencies break this model and require manual workaround. | TID Ch1 |
| Workspace (CLI) | One deployment of a Terraform codebase against a specific backend + input variables — like one "installation" of a program; a codebase can have unlimited workspaces sharing a backend. | TID Ch1 |
| Provider `for_each` (OpenTofu) | OpenTofu 1.9 feature: instantiate an aliased provider config multiple times from a map/set (e.g. one per region). Resource `for_each` must be a subset of the provider's. | [[ot-provider-for-each]] |
| Early variable evaluation (OpenTofu) | OpenTofu 1.8 feature: reference `var`/`local` inside `backend`/`provider` blocks, resolved at `tofu init` before state exists. | [[ot-early-eval-backend]] |
| `-exclude` (OpenTofu) | OpenTofu 1.9 CLI flag: inverse of `-target` — plan/apply everything except the given addresses. No Terraform equivalent. | [[ot-exclude-flag]] |
| Dynamic `prevent_destroy` (OpenTofu) | OpenTofu 1.12 feature: bind the `lifecycle.prevent_destroy` flag to a variable/expression; Terraform requires a literal. | [[ot-dynamic-prevent-destroy]] |
| Block | The primary HCL construct ("noun") — a typed, optionally-labeled container of arguments and subblocks. Terraform HCL has 12 block types (`terraform`, `provider`, `resource`, `data`, `variable`, `locals`, `module`, `import`, `moved`, `removed`, `check`, `output`). | TID Ch2 |
| Argument vs. subblock | Argument = `name = value`, once per block, exports as an attribute. Subblock = nested block, no `=`, repeatable, *not* exported as an attribute. | TID Ch2 |
| Attribute (computed) | A read-only value a block exposes only after plan/apply reads it back from the provider (e.g. `aws_instance.arn`, `instance_state`); distinct from arguments, which auto-export as attributes. | TID Ch2 |
| Data source | A read-only block that looks up and exposes existing data; same shape as a resource but never creates or modifies. Dynamic-count lookups can return zero results; most single-match lookups error on no match. | TID Ch2 |
| Meta argument | An argument built into HCL (not the provider) that changes how *Terraform plans* a block rather than the infrastructure: `provider`, `depends_on`, and the `lifecycle` subblock. Processed early, so mostly requires literal / plan-time-known values. | TID Ch2 |
| `lifecycle` block | Resource subblock (once per resource) controlling management behavior: `create_before_destroy`, `prevent_destroy`, `ignore_changes` (incl. `all`), `replace_triggered_by`. | TID Ch2 |
| `required_providers` vs `provider` block | `required_providers` (inside `terraform`) declares *what to install* + version constraint; the separate `provider` block *configures* it (auth + scoping). Root-module only. | TID Ch2 |
| Provider alias | A named non-default `provider` configuration (`alias = "west"`), letting one program hold multiple connections to a vendor (regions/accounts); blocks select it via the `provider` meta argument. | TID Ch2 |
| Provider inference | Terraform guessing a missing provider from a resource's name prefix, assuming the `hashicorp` namespace (`aws_instance` → `hashicorp/aws`). Discouraged — declare providers explicitly to pin versions. | TID Ch2 |
| `terraform_data` | Built-in "state-only" resource (since Terraform 1.4) that replaces the `null_resource` pattern for `replace_triggered_by` triggers; no provider dependency, uses `triggers_replace`. | TID Ch2 |
| `import` / `moved` / `removed` blocks | Refactoring blocks: `import` (v1.5) brings existing infra under management, `moved` (v1.5) re-associates renamed/relocated state, `removed` (v1.7) drops an item from management without destroying it. | TID Ch2 |
| Dependency lock file (`.terraform.lock.hcl`) | File `init` writes recording the exact provider versions + checksums selected; plan/apply use the locked version, not the newest allowed. Commit it for reproducibility across team/CI. | Book Ch 2 |
| Source address | A provider's global address `[HOSTNAME/]NAMESPACE/TYPE` (e.g. `registry.terraform.io/hashicorp/aws`, short form `hashicorp/aws`); hostname defaults to the public registry. | Book Ch 2 |
| Version constraint (`~>`) | Pessimistic operator: `~> 6.0` allows `>= 6.0, < 7.0`; `~> 6.53.0` allows `6.53.x` but not `6.54.0`. Root modules pin a bounded major; child modules specify only a minimum. | Book Ch 2 |
| `required_version` | Floor constraint (inside `terraform`) on the *CLI* version — set to the oldest feature the config uses (e.g. `>= 1.2`), not the newest available; over-pinning locks out otherwise-compatible CLIs and module consumers. | Book Ch 2 |
| `.terraform/` directory | Hidden cache of downloaded provider/module binaries, recreated by `init`; platform-specific and disposable — never committed. | Book Ch 2 |
| Local name | The module-local key for a provider in `required_providers` (the `aws` in `aws = { … }`); doubles as the resource-type prefix (`aws_instance`). Keep it equal to the type unless two providers collide. | Book Ch 2 |
