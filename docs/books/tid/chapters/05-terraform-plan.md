# Chapter 5 — The Terraform plan

> *Source: Hafner (2025), **Terraform in Depth**, Chapter 5, pages 123–166.*
>
> Terraform is more than a language — it's an **engine** that reads your code, compares it to the real infrastructure, and computes a plan to reconcile the two. This chapter is the most theoretical in the book: it explains the **directed acyclic graph (DAG)** Terraform builds internally, then walks the whole **plan → review → apply** cycle in detail — planning modes, the ways to feed input variables, apply options, and a catalogue of the **graph-related pitfalls** that bite real users.
>
> 📌 **Notes adapted where version-bound.** Book written 2025; current stable is Terraform CLI **1.15.7** / OpenTofu **1.12.3** — see [[version-facts]]. Version facts flagged inline: `-replace` (v0.15.2, supersedes deprecated `taint`), the `terraform graph` apply-mode change at v1.7.0, and the OpenTofu-only `-exclude` flag. Conceptual content — the DAG, plan/apply mechanics, the pitfalls — is unaffected.

> 🔗 **See also:** deepens learning-path **B3** (init/plan/apply/destroy), **B7** (computed-value limits on expressions), **I1** (`count`/`for_each` must be known at plan time), **I2** (`ignore_changes` to stop replacements), and **E5** (`terraform graph` / DAG deep-dive). Builds on Ch4's [[dependency-graph]]; leads into Ch6 [[state-management]].

---

## 5.1 Directed acyclic graphs

The central insight behind IaC: **infrastructure and its relationships can be modelled as a DAG**. Terraform isn't unique here — most declarative languages use DAGs to decide *what* to do and *in what order*.

### 5.1.1 What a DAG is

A **graph** is a set of **nodes** (resources) joined by **edges** (connections/relationships). Real-world examples: org charts, family trees, social graphs. Two properties matter:

- **Directed vs undirected** — a directed edge points one way. In IaC the direction encodes a **dependency** (A must exist before B).
- **Acyclic vs cyclic** — an acyclic graph has no loops. Terraform's graph *must* be acyclic; a cycle is a hard error (see §5.7).

So Terraform's model is specifically a **directed *acyclic* graph**: ordered dependencies, no circular relationships.

### 5.1.2 The running example — a TLS dev CA

The chapter's worked module (Listing 5.1) builds a throwaway **certificate authority** with the `tls` provider — handy when you need certs during development instead of Let's Encrypt / AWS ACM. Every resource in it forms a DAG:

```hcl
resource "tls_private_key" "ca_key" {          # references no other resource (edge: provider only)
  algorithm = "ED25519"
}

resource "tls_self_signed_cert" "ca_cert" {    # depends on ca_key
  private_key_pem   = tls_private_key.ca_key.private_key_pem
  is_ca_certificate = true

  subject {
    common_name  = "dev-ca.example.com"
    organization = "Dev CA"
  }

  validity_period_hours = 24
  allowed_uses          = ["cert_signing", "crl_signing", "digital_signature"]
}

resource "tls_private_key" "child_key" {       # references no other resource either — one per domain
                                               # (edges: provider + var.domains, via for_each)
  for_each  = var.domains                       # set(string) of domains
  algorithm = "ECDSA"
}

resource "tls_cert_request" "child_request" {  # CSR per domain, depends on child_key
  for_each        = var.domains
  private_key_pem = tls_private_key.child_key[each.value].private_key_pem

  subject {
    common_name = each.value
  }
}

resource "tls_locally_signed_cert" "child_certificate" {  # signed by the CA
  for_each           = var.domains
  cert_request_pem   = tls_cert_request.child_request[each.value].cert_request_pem
  ca_private_key_pem = tls_private_key.ca_key.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca_cert.cert_pem

  validity_period_hours = 12
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
}
```

The `var.domains` these resources fan out over is a `set(string)`:

```hcl
variable "domains" {
  type    = set(string)
  default = ["alice.example.com", "bob.example.com", "charlie.example.com"]
}
```

> 📁 Runnable version (fills in `terraform.tf`, passes `terraform validate` on Terraform 1.15.8 / tls 4.3.0): [`docs/examples/TID/chapter5`](../../../examples/TID/chapter5/main.tf).

Every resource has an edge to the `tls` **provider** node, so no resource is edge-free. But looking only at **resource-to-resource** references, exactly two reference no *other resource*: `ca_key` (only a constant `algorithm`) and `child_key` (its inputs are the `var.domains` variable, via `for_each`, plus a constant — a variable, not a resource). The other three each reference another resource's attribute. No cycles → a valid DAG.

> 💭 (mine): the key edges are the **attribute references** (`tls_private_key.ca_key.private_key_pem` etc.). Same rule as Ch4's [[dependency-graph]] — referencing an attribute *is* the dependency; nothing else declares it.
>
> Don't call `ca_key`/`child_key` "roots": in the actual `terraform graph`, `root` is the single **sink** node every leaf connects up to, and these two are the opposite end (sources). They aren't even symmetric — `child_key` carries an extra `var.domains` edge from its `for_each` that `ca_key` doesn't. The only thing they share is referencing no *resource*.

---

## 5.2 The Terraform resource graph

Internally Terraform calls its DAG the **resource graph** — the central data structure every operation revolves around. State is essentially a snapshot of that graph. Because it's directed + acyclic, there's a defined order and no legal cycles.

### 5.2.1 Node types

The resource graph has **three** node types:

| Node | What it is |
| --- | --- |
| **Resource** | Maps to one resource *instance* in code. With `count`/`for_each`, each instance is its own node. Despite the name, **data sources are Resource nodes too**. |
| **Provider Configuration** | One per provider *configuration*. Every resource has a direct edge to exactly one. Multiple configs (e.g. two AWS regions via `alias`) each get their own node. |
| **Resource Meta** | A grouping node used when `count > 1`. Mostly cosmetic — for convenience and prettier graph rendering. |

This is Terraform's internal view — you won't think about it daily, but it makes debugging (§5.7) far easier.

!!! warning "🔄 Doesn't match the current implementation (verified 2026-07-20, against Terraform **v1.15.8**)"
    Recorded above as the book states it. Checked against the Terraform source at tag `v1.15.8` (`repos/terraform`), the three-type model does not hold: the plan graph also has variable, local, output, check, action, and module expansion/close nodes; the `count > 1` "Resource Meta" node corresponds to `nodeExpandPlannableResource`, which exists for **every** resource and isn't cosmetic; and modules **are** nodes (`nodeExpandModule`). The **Provider Configuration** row holds up. Details and source citations in [[dependency-graph]].

### 5.2.2 The `terraform graph` command

`terraform graph` emits the graph as a **GraphViz `.dot` file** on stdout. Pair it with the open-source **`dot`** CLI (from [graphviz.org](https://graphviz.org/download/)) to render an image:

| Output | Command |
| --- | --- |
| dot file | `terraform graph > graph.dot` |
| SVG | <code>terraform graph &#124; dot -Tsvg > graph.svg</code> |
| PNG | <code>terraform graph &#124; dot -Tpng > graph.png</code> |

Use `-type` to pick the mode: `plan` (default, simplified), `plan-refresh-only`, `plan-destroy`, or `apply`.

- The **`apply`** graph shows every individual resource being created (much more detail than `plan`), but it needs a **saved plan file** — otherwise a bug renders an empty graph:

    ```bash
    terraform plan -out create.tfplan
    terraform graph -type=apply -plan=create.tfplan | dot -Tpng > graph.png
    ```

- 📌 **Version note (book claim):** before **Terraform v1.7.0** the apply-mode graph produced much noisier output; v1.7.0+ is cleaner. Both are still diagrams *of the plan* — `apply` mode just shows how Terraform will execute it.

Beyond debugging (spotting non-obvious dependencies, finding circular deps), the rendered graph is a quick **architecture diagram** to share with other teams. Full treatment of `terraform graph` is in learning-path **E5** ([[tf-cmd-graph]]).

### 5.2.3 Modules disappear in the graph

There is **no module node**. Modules organise *code*, not the runtime graph — Terraform flattens module boundaries and adds only the underlying resources. Counterintuitive consequence:

> ⚠️ **Pitfall** — if module B "depends on" module A, a resource in B can still be created **before** a resource in A, as long as the resource-level dependencies allow it. Module boundaries don't serialize execution.

---

## 5.3 Plan

The **plan** stage is where the real work happens: Terraform builds the resource graph from your code, walks it to find differences against state, and produces a new graph of the **actions** needed to converge.

- `terraform plan` runs it. `terraform plan -out=example.tfplan` **saves** the plan to apply later.
- A plan you don't save is a **speculative plan** — one you don't intend to apply (common in dev, testing, PR checks; more in Ch7).

**Reading plan output (Listing 5.2).** Actions are marked with symbols:

| Symbol | Meaning |
| --- | --- |
| `+` | create |
| `-` | destroy |
| `~` | update in place |
| `-/+` | destroy then re-create (replace) |

- **`(known after apply)`** — value Terraform can't compute until apply.
- **`(sensitive value)`** — hidden because the attribute is sensitive.
- **Order matters, read bottom-up:** except in destroy mode, resources at the **bottom** of the output have no dependencies and are created **first**; resources at the **top** are deepest in the dependency tree and created **last**. (Terminal output is commonly read bottom-to-top for this reason.)
- Ends with a summary: `Plan: 11 to add, 0 to change, 0 to destroy.`
- Without `-out`, Terraform warns it "can't guarantee to take exactly these actions" — the printed text is only a *representation*; the real saved `.tfplan` is **binary**, readable only via `terraform show` / `terraform graph`.

### Planning modes

Three modes, same mechanics, different outcomes:

| Mode | How | What it does |
| --- | --- | --- |
| **default** | (no flag) | Reconcile infra to code. Used ~all the time. |
| **destroy** | `terraform plan -destroy -out=destroy.tfplan` | Tear down everything in this configuration (all `-` actions). |
| **refresh-only** | `terraform plan -refresh-only` | Update state from reality only; make **no** infra changes. |

- **Every plan starts with a refresh** — the `Refreshing state...` lines look up each resource by ID to detect drift. (Not visible on the very first plan since there's nothing in state yet.)
- **Destroy order is reversed:** resources are destroyed in the *opposite* order they were created — you can't delete a VPC before its subnets. (Create order and destroy order are the same DAG walked in opposite directions.)
- **refresh-only** is the safe way to reconcile state after out-of-band changes / to detect drift. Because default and destroy modes already refresh, this mode is niche. In Listing 5.5, editing the org name and running `-refresh-only` reports **"No changes"** — it ignores code edits by design, only syncing state to real infra.

### Replace (previously `taint`)

To force a specific resource to be destroyed and re-created, plan with **`-replace`**:

```bash
terraform plan -replace 'tls_private_key.child_key["charilie.example.com"]'
```

- Quote the address in **single quotes** so the shell doesn't mangle the `[...]`.
- Repeatable — pass `-replace` multiple times to replace several resources in one plan.
- The replacement's **repercussions cascade**: in Listing 5.4, replacing one child key forces **3** resources to be replaced (the key, its CSR, and its signed cert) because each references the previous. `Plan: 3 to add, 0 to change, 3 to destroy.` Reviewing the plan first is the whole point.

!!! note "📌 `-replace` supersedes `terraform taint`"
    `-replace` landed in **Terraform v0.15.2**. Before that you used **`terraform taint`**, which is now **deprecated**. `taint` mutated state *immediately* and out-of-band — you couldn't preview the effects. `-replace` shows the recreation in a plan first, so you review before anything changes. No good reason to use `taint`. (See [[feature-history]].)

### Resource targeting (`-target`)

`-target` restricts the plan to specific resources (plus anything they depend on) and nothing else.

> ⚠️ **Antipattern warning (author is emphatic):** resource targeting is for **exceptional** cases only — mainly recovering from a state that Terraform can't otherwise plan (e.g. someone changed a resource manually). A module that *requires* `-target` to work is a design smell. Terraform sometimes suggests `-target` in error messages; treat that as a sign of a deeper problem, not a fix. Batching a slow change with `-target` usually means the project is too large and should be split (Ch9).

!!! info "OpenTofu — the `-exclude` flag (OpenTofu 1.9)"
    OpenTofu added a **`-exclude`** flag (OpenTofu **1.9**) — the inverse of `-target`: plan/apply *everything except* the named addresses. Terraform has **no `-exclude`** as of 1.14 (only the new `terraform query` / list-resources feature landed there). `-target` and `-exclude` are mutually exclusive. Portable code should avoid depending on either. (See [[version-facts]], [[feature-coverage-matrix]].)

### Disabling refresh (`-refresh=false`)

Skips the refresh phase — the opposite of `-refresh-only`.

> 🚨 **Danger** — the plan then runs on possibly-stale state, so expect failed applies. The only semi-defensible use is a dev environment where *you* are the sole actor — and even then automation could change things underneath you.

### `terraform refresh` command (deprecated)

`terraform refresh` updates state from reality with **no approval step** — extremely dangerous, and **deprecated** (kept only for backward compatibility). Classic failure: if provider credentials expire mid-refresh, Terraform may read resources as **missing** and **delete them from state**, so the next run tries to re-create them.

- **Use `terraform apply -refresh-only` instead** — same effect, but it shows what it will change and asks for approval first, so you can validate and work around errors.

### Reviewing plan files with `terraform show`

`terraform show <plan-file>` renders a saved binary `.tfplan` back into human-readable text. Secondary superpower: **`-json`** converts the plan to JSON, ideal for programmatically reviewing plans (policy checks, tooling) in any language.

---

## 5.4 Root-level module input variables

The most common way to shape a plan is via **root-module input variables** — the inputs that make one config produce different environments. Four ways to set them:

### Interactive

Default behaviour: Terraform **prompts** for any variable that lacks a value (no default, not otherwise set). Fine for quick testing, bad for pipelines. Disable with **`-input=false`** so missing inputs **error** instead of hanging — effectively required in automation.

### Variable flag (`-var`)

```bash
terraform plan -var 'vpc=vpc-01234567890abcdef' -var 'num_instances=2'
```

Repeatable; shareable via shell history. Downsides: shell-quoting differences (Linux vs Windows) and **poor handling of complex types** — you end up hand-escaping JSON-like blobs with no editor support.

### Variable files (`.tfvars`)

Best way to *store* values. A `.tfvars` file is stripped-down HCL — **no blocks, just `key = value`**, literals only (no functions/transforms), but any type (objects, maps) works cleanly:

```hcl
# Production Data
vpc           = "vpc-01234567890abcdef"
num_instances = 2
```

- JSON variant (`.tfvars.json`) exists for machine-generated files; **JSON has no comments** and no trailing commas.
- Terraform picks the parser by **file extension**, so the extension is strict.
- Load with **`-var-file=production.tfvars`** (repeatable). Some names load **automatically**:

| Extension | Format | Loaded |
| --- | --- | --- |
| `*.tfvars` | HCL | via `-var-file` |
| `*.auto.tfvars` | HCL | automatically |
| `terraform.tfvars` | HCL | automatically |
| `*.tfvars.json` | JSON | via `-var-file` |
| `*.auto.tfvars.json` | JSON | automatically |
| `terraform.tfvars.json` | JSON | automatically |

- Benefit: files live in version control, reviewable via PR, fewer typos. **Never** put secrets in them (they land in source control).

### Environment variables (`TF_VAR_`)

Prefix `TF_VAR_` + the variable name, matching case: variable `num_instances` → `TF_VAR_num_instances`. Mostly used for **provider authentication** secrets passed by CI/CD, not general config.

### Input precedence

When a variable is set multiple ways, Terraform takes the **first match** from highest to lowest:

1. **`-var` / `-var-file`** (highest; last one on the command line wins for a repeated variable)
2. **`*.auto.tfvars` / `*.auto.tfvars.json`** (in lexical order)
3. **`terraform.tfvars.json`**
4. **`terraform.tfvars`**
5. **Environment variables** (`TF_VAR_*`)
6. Otherwise: the variable's **default**, else **prompt** (or **error** if `-input=false`)

> 💡 **Tip** — pick one method (e.g. always variable files) and stick to it. Most "why won't my change take effect?" confusion is a higher-precedence source silently overriding you. Matches the [[tf-input-variables]] precedence table from B6.

### A note on secrets and inputs

**Every** method can leak: `-var` → shell history; `.tfvars` → version control; env vars → logs. Interactive is safest but unautomatable. Two real fixes:

- **CI/CD secret stores** — GitHub Actions secrets, or Terraform-specific platforms (Spacelift, Scalr, Env0, HCP Terraform) that mask sensitive values in logs.
- **A secrets manager** (Vault, AWS/GCP/Azure Secret Manager) — pass a **path** to the secret instead of the value. Orchestrators (Kubernetes, ECS) can inject the secret so Terraform never sees it; if Terraform must read it, use a data source.

---

## 5.5 Apply

Apply walks the plan's graph and makes the changes. Feeding a saved plan (Listing 5.8) shows resources created in dependency order — independent private keys all at once, then CSRs, then the CA cert, then the signed child certs. Each `Creation complete` line reports the new provider-assigned **ID**. Ends with `Apply complete! Resources: 11 added, 0 changed, 0 destroyed.`

### Plan + apply in one command

`terraform apply` with **no plan file** runs its own plan, prints it, and asks for confirmation. It accepts all the same flags as `plan` (variable inputs, `-target`, `-destroy`, `-refresh-only`).

- **`-auto-approve`** skips the confirmation. Risky — no chance to catch a bad plan before infra changes. Even `plan` then `apply -auto-approve` (without a saved file in between) can diverge if something changed out-of-band. Whether to auto-approve in CI/CD is a team judgement call (Ch7).

### Using a plan file

`terraform apply plan.tfplan` applies a **saved** plan — the standard automation pattern, since it separates plan (reviewable) from apply. With a plan file Terraform does **not** re-prompt (it assumes you already reviewed). Extension is arbitrary; `.tfplan` is the de-facto convention.

### Destroy

`terraform destroy` is an **alias for `terraform apply -destroy`**. It takes no plan file — it runs a destroy-mode plan then applies it, asking for confirmation by default.

- `-auto-approve` is common for local dev destroys but still risky in shared accounts.
- 🚨 **Best defence:** manage production via centralized CI/CD and **remove direct logins** to prod from your laptop — if you can't reach the infra, you can't accidentally destroy it.

---

## 5.6 Apply and plan options

Flags shared by both commands; rarely daily-use.

### Parallelism (`-parallelism=n`)

By default Terraform runs up to **10** actions concurrently (an "action" = a provider call: create/update/delete/read). `-parallelism=n` changes it. Raising it rarely helps much — real limits are:

- **Dependencies** — bottleneck resources (VPC before subnets) serialize work regardless.
- **API rate limits** — out of your control; providers already back off and retry.

The genuinely useful direction is **lower** it for debugging: with 10 things logging at once, output is unreadable. Combine low parallelism + verbose logs:

```bash
TF_LOG=debug terraform plan -parallelism=1
```

### Locking (`-lock=false`)

Most operations **lock** the state via the backend so only one process can use it — this prevents two concurrent applies from corrupting state. Terraform manages locks well on its own.

- `-lock=false` disables it — almost always a bad idea. The one legitimate case is **speculative plans** (Ch6): a plan you'll never apply, so there's no corruption risk. Automation generating speculative runs commonly disables locking.

### JSON

The Terraform **CLI is the engine** — there's no separate SDK. For automation, most commands can emit **JSON** (`-json`) for easy parsing. Deep dive in Ch11.

### Formatting flags

Output-only, no behavioural change:

- `-compact-warnings` — trims warning text.
- `-no-color` — strips ANSI color (for systems that don't render it).

---

## 5.7 Common pitfalls and errors

Most of these stem from the resource graph — powerful, but with sharp edges.

### Circular dependencies

A cycle (A → B → C → A) is illegal in a DAG; Terraform errors immediately. Demonstrated with the **`null_resource`** (a NOOP resource from the `null` provider, useful for testing) whose `triggers` reference each other:

```
$ terraform plan
Error: Cycle: null_resource.alpha, null_resource.bravo, null_resource.charlie
```

The error **names every resource in the cycle** — enough to start debugging. **Fix:** break one edge. Often two resources merely *share a value*; route it through a **variable or local** instead of a resource attribute:

```hcl
variable "build_id" {        # a single input drives the rebuild...
  default = null
  type    = string
}

resource "null_resource" "alpha" {
  triggers = { rebuild = var.build_id }   # ...instead of referencing charlie.id
}
# bravo, charlie: same pattern — no more cycle
```

Cycles are rare in practice; when they appear, it usually signals architecture that needs simplifying.

### Cascading changes

Because everything's a graph, a change to one resource can ripple downstream — and some changes replace (destroy + re-create) rather than update in place. In Listing 5.12, flipping the CA key algorithm `ECDSA → ED25519` re-creates the CA key, the CA cert, and **every** child cert: `Plan: 5 to add, 0 to change, 5 to destroy.` Three mitigations:

- **Review plans**, watching for **`# forces replacement`** and `-/+`.
- If a resource you want to keep is being replaced, find the triggering attribute and add it to **`ignore_changes`** in a `lifecycle` block (see I2, [[meta-arguments-lifecycle]]) so it stops forcing replacement.
- Reduce dependency chains where feasible (often an architecture review, not a quick fix).

### Hidden dependencies

The mirror image: infra that depends on other infra with **no code link** (no attribute passed between them), so Terraform may create things in the wrong order. Sometimes harmless (microservices that retry until peers are up); sometimes fatal (a NAT Gateway that can't launch before its Internet Gateway). **Fix:** declare the edge explicitly with **`depends_on`**.

> 💭 (mine): this is the exact *opposite* advice to cascading changes — one section says "fewer dependencies," this says "add an explicit one." That's the perennial balancing act: simpler is easier to reason about, but real systems need the edges Terraform can't infer. Ties directly to the "nothing warns you about a missing `depends_on`" danger in learning-path I1 ([[dependency-graph]]).

### Always-detected changes (eternal drift)

No matter how often you apply, Terraform keeps detecting a change — a **provider bug** where the provider doesn't round-trip a value cleanly against its API. Common shapes:

- int → float (`45` → `45.0`)
- bool → string
- list re-ordering
- mixed-case → lowercase
- missing argument → empty string / `0`

Much rarer now thanks to a maturing plugin framework. **Workaround:** match your input to whatever the API returns (lowercase if it lowercases, pre-sort the list), then file a bug against the provider.

### Calculated values and iterations

A hard limit: **`count` and `for_each` values must be known at plan time** and **cannot depend on values known only after apply** (a resource ID, an IP, etc.). Terraform needs them to build the graph nodes before it can plan past that point.

- Trap (Listing 5.13): a `local` used in `count` derives from an `aws_route53_record` attribute → Terraform can't plan.

    ```hcl
    locals {
      use_eip = endswith("example.com", aws_route53_record.name)  # depends on a resource → BAD
    }
    resource "aws_eip" "example" {
      count = local.use_eip ? 1 : 0    # error: value not known at plan time
    }
    ```

- Fix (Listing 5.14): derive from the **input variable** instead, which *is* known at plan time.

    ```hcl
    locals {
      use_eip = endswith("example.com", var.domain)   # depends on a variable → OK
    }
    ```

- Same rule for `for_each`: if any key/value comes from a resource attribute, it fails. If you know the *count*, fall back to `count` + index. **Don't** work around it with `-target` bootstrapping — it makes the module un-runnable without extra choreography. Refactor instead. (This is the plan-time-known constraint behind learning-path **B7** and **I1**.)

### Failed state updates

State didn't get written after a change — rare, usually a crash or a backend error. Recovery depends on what changed:

- **Updates/deletes only:** run a `terraform apply -refresh-only`; Terraform notices and records the changes. Follow with a plan to confirm alignment.
- **Creates that weren't saved:** Terraform has no record they exist, so either **import** them into state, or delete them manually and then `-refresh-only`.

State management (and preventing these) is the whole of Ch6.

---

## Summary

- Terraform models infrastructure — and each plan — as a **directed acyclic graph**; state is a snapshot of it.
- The resource graph has three node types (Resource, Provider Configuration, Resource Meta); **modules are not nodes**. (🔄 Contradicted by the current source — see the correction under §5.2.1.)
- **`terraform graph`** (+ GraphViz `dot`) visualizes configs and plans; `-type=apply` needs a saved plan.
- **`terraform plan`** computes changes in three modes (default / destroy / refresh-only); read symbols `+ - ~ -/+` and the bottom-up ordering.
- **`-replace`** supersedes deprecated `taint`; `-target` is an antipattern for exceptional cases only.
- Input variables come from `-var`/`-var-file`, `.tfvars` files, and `TF_VAR_*` env vars, with a strict **precedence** order; keep secrets out of all of them.
- **`terraform apply`** runs a saved plan or generates its own; `terraform destroy` = `apply -destroy`.
- The DAG's power comes with pitfalls: **cycles, cascading replacements, hidden deps, eternal drift, plan-time-unknown `count`/`for_each`, and failed state writes**.

## References

- Terraform resource graph — <https://developer.hashicorp.com/terraform/internals/graph>
- `terraform graph` command — <https://developer.hashicorp.com/terraform/cli/commands/graph>
- `terraform plan` command — <https://developer.hashicorp.com/terraform/cli/commands/plan>
- Resource targeting (`-target`) — <https://developer.hashicorp.com/terraform/cli/commands/plan#resource-targeting>
- GraphViz — <https://graphviz.org/download/>
