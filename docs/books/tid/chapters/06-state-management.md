# Chapter 6 — State management

> *Source: Hafner (2025), **Terraform in Depth**, Chapter 6, pages 167–206.*
>
> State is the record that lets Terraform link the resources in your code to the real objects a provider created. This chapter answers *why* a stateful engine beats a stateless one, dissects the **tfstate JSON** field by field, covers **backends** (where state lives, how to configure/migrate them, and workspaces), the safe ways to **manipulate state** (`moved`/`removed` blocks first, CLI second, hand-editing never), the four categories of **state drift** and how to fix each, reading another project's outputs with **`terraform_remote_state`**, and the **state-only providers** (`random`, `time`, `null`, `terraform_data`) that exist purely inside state.
>
> 📌 **Notes adapted where version-bound.** Book written 2025 (examples show state `version: 4`, `terraform_version: 1.5.4`); current stable is Terraform CLI **1.15.8** / OpenTofu **1.12.4** — see [[version-facts]]. Biggest correction: the book's Table 6.1 still says the **S3 backend requires DynamoDB for locking** — as of **Terraform 1.10 / OpenTofu 1.10** the S3 backend locks natively with `use_lockfile = true`, and DynamoDB-based locking is **deprecated** (see §6.4.1). Block version-gates are flagged inline (`moved` 1.1, `removed` 1.7, `terraform_data` 1.4, `import` block 1.5). Conceptual content — why state exists, the JSON structure, drift, remote state — is unchanged.

> 🔗 **See also:** owns learning-path **B9** (state fundamentals) and **I6**/**I7** (remote state, backends, state ops); touches **A6** (secrets in state), **I2** (`ignore_changes`, `replace_triggered_by`), **A1** (`terraform_data`/provisioners). Builds on Ch5's [[dependency-graph]] and [[core-workflow]]; the `import` block it defers to is Ch8. Topic pages: [[state-management]] (backlog), [[secrets-and-state]] (backlog).

---

## 6.1 Purpose of state

State is a **core design choice**, on the same level as choosing a declarative language over an imperative one — it touches every part of Terraform and comes with tradeoffs. A **stateless** system (like HTTP/REST) has no memory of past runs; every interaction is standalone. A **stateful** system remembers what happened and uses that memory to drive its next actions. Terraform is stateful: it keeps a record of every resource under its control and refreshes that record on every plan.

The upside is performance and a simpler engine; the downside is that *you* now have to store and manage that data.

### 6.1.1 Real-world linkage

The most common "why does Terraform even need state?" answer: state lets Terraform identify each resource by its **true identifier** (in AWS, the ARN) reliably, even after users touch infrastructure manually. Without state, Terraform would have to *rediscover* which real objects it owns every run.

That discovery turns out to be surprisingly hard:

- Not every resource supports **tags/descriptions** to look up.
- People change tags out of band, so tag-based identification is brittle.
- Vendors that do support tags use different search APIs — any generic solution collapses into per-provider special-casing.

### 6.1.2 Reduced complexity

Removing state wouldn't just complicate Terraform core; it would make **provider development** dramatically harder (multiple lookup paths per vendor capability). Since Terraform leans on a huge community of provider authors, anything that raises the bar to write a *good* provider weakens the whole ecosystem. Simpler is more robust: fewer edge cases, easier debugging, easier to extend.

### 6.1.3 Performance

Reading a saved identifier is always faster than auto-discovering and linking infrastructure. State also lets subcommands like `terraform graph` work off the stored data instead of a full refresh. The real payoff is **developer time** — a fast plan→change→re-plan loop keeps the mental model intact, which is a big part of what makes Terraform feel like magic.

### 6.1.4 State-only resources

Because state exists, Terraform can offer resources that live **only inside state** with no backing infrastructure. Ch5's `tls` certificate authority was one: keys, CSRs, and certs were generated locally and persisted nowhere but state — no network APIs, no files on disk. `null`, `random`, and `cloudinit` are the same shape (covered in §6.8). None of these could exist, in a useful form, without state.

---

## 6.2 Important considerations

State introduces data you must protect. When choosing *how* to store it, focus on three properties.

### 6.2.1 Resiliency

Losing or corrupting state is one of the worst positions to be in — Terraform needs state to plan an upgrade, and without it either fails or assumes it must create everything from scratch. Recovery means manually deleting real resources or re-importing them: tedious, slow, error-prone.

So evaluate a backend's **durability** (historic data loss, incident frequency, durability commitments). S3, for example, claims **eleven nines** (99.999999999%) of per-object durability — roughly 1 lost object per 100 trillion per year.

!!! warning "A resilient backend is not a backup"
    Even a perfect storage system doesn't stop **human error** — an engineer can still delete the bucket. You need reliable, *tested* backups independent of the backend's own durability.

### 6.2.2 Security

State holds **every attribute of every resource**, including ones marked `sensitive`. A leaked state file exposes your whole architecture and its secrets. "Poor security" is concrete: state access without MFA (open to brute-force / credential stuffing), or a storage bucket misconfigured for public access — both are real incidents that have happened.

Mitigations help but don't eliminate the risk: pull secrets from a manager like Vault where you can (many systems still need values passed directly), but a copy of state still maps your entire architecture to anyone who can read it. See [[secrets-and-state]].

### 6.2.3 Availability

State must be reachable to run Terraform at all. If your state store is down, you **cannot deploy** — a productivity drag on a normal day, a genuine emergency when you need to ship a fix fast.

!!! note "Availability is measured in “nines”"
    99.99% uptime = "four nines" (< ~4 min 30 s downtime/month); 99.999% = "five nines". The author treats state storage as **critical infrastructure** and wants at least four nines, backed by a vendor **SLA** with financial penalties. Avoid vendors that won't commit to an SLA or aren't transparent about outages. (`https://uptime.is/` converts percentages to real time.)

---

## 6.3 Dissecting state

State is a data structure *and* a database in one. **You should almost never edit it by hand** — Terraform gives you `import`, refresh-only plans, and the `moved`/`removed` blocks for that. But understanding its shape makes backend errors legible: a "lineage doesn't match" error, or choosing the latest of several backup versions, both make sense once you know the fields.

### 6.3.1 State as JSON

State serializes to **JSON**, and JSON is the default on-disk format for the **local backend** — which lets you read it directly. The chapter's example (Listings 6.1–6.2) applies a small child module with a `random_password` and a `check` block:

```hcl
# modules/password/main.tf
resource "random_password" "new_password" {
  length = 12
}

output "password" {
  value     = random_password.new_password.result
  sensitive = true   # random_password.result is a sensitive attribute
}

check "password_strength" {           # check block — Terraform ≥ 1.5 (book defers detail to its Ch10)
  assert {
    condition     = length(random_password.new_password.result) >= 12
    error_message = "password should be at least 12 characters long."
  }
}
```

```hcl
# root main.tf — calls it as a CHILD module, to see how modules appear in state
module "my_password" {
  source = "./modules/password"
}

output "password" {
  value     = module.my_password.password
  sensitive = true
}
```

!!! warning "Running the listing on 1.15 raises two warnings the book doesn't show"
    The book's module also declares an empty `data "null_data_source" "values" {}` so the state shows what a data source looks like. On Terraform 1.15 that emits a **deprecation warning**: the `null_data_source` was historically used to build intermediate values, and locals or the `terraform_data` resource type do the job from 1.4 onward. It still applies and still lands in state, so the listing works as written.

    The `check` block also warns at plan time: `Check block assertion known after apply`. `random_password.new_password.result` isn't known until the resource is created, so the condition can't be evaluated during the plan. The assertion runs after apply and its outcome is what `check_results` records.

`terraform init && terraform apply` writes `terraform.tfstate`. The top level has these fields:

| Field | Meaning |
| --- | --- |
| `version` | Version of the **state data-structure format** itself (currently `4`). Lets newer Terraform read and upgrade older state. |
| `terraform_version` | The Terraform version that **last wrote** the state. Mostly informational. |
| `serial` | Integer bumped **+1 on every persisted snapshot whose content differs from the previous one** — per *write*, not per apply (see below). Use it to find the newest of several backups. |
| `lineage` | A UUID-shaped random ID created the first time a snapshot is **written** at a location (not by `init`), **never changes** afterwards. Detects "wrong state for this project", though only at import/migration time (§6.3.3). |
| `resources` | List of objects for every managed **resource and data source**. |
| `outputs` | The **root-level module's** outputs (enables `terraform show` and `terraform_remote_state`). |
| `check_results` | Results of `check` blocks saved from the run (book covers checks in its Ch10). |

`check_results` is keyed by the check's **config address**, and each entry carries both a config-level status and a per-object status. A passing run of the listing writes:

```json
"check_results": [
  {
    "object_kind": "check",
    "config_addr": "module.my_password.check.password_strength",
    "status": "pass",
    "objects": [
      { "object_addr": "module.my_password.check.password_strength", "status": "pass" }
    ]
  }
]
```

!!! note "Sensitive data lands in state in plaintext"
    In the example JSON, the `random_password` `result` appears verbatim inside the resource attributes *and* again in the root `outputs` (with `"sensitive": true`). Marking an output `sensitive` only stops Terraform **displaying** it — it does **not** encrypt or omit it from the file. This is the whole reason §6.2.2 matters. (OpenTofu adds opt-in **state encryption**; Terraform's OSS CLI still has none as of 1.15.)

!!! info "`sensitive_attributes` is effectively dead"
    The book's JSON shows an empty `sensitive_attributes: []` with a margin note that the field "does not appear to be used anymore" — sensitivity now lives in the providers' schemas, not this state field.

!!! question "Why does the very first apply leave `serial` at 2, not 1?"
    Because `serial` counts state **writes**, and a single apply writes more than once. Applying the listing above produces a `serial` of 2:

    ```
    # TF_LOG=trace, abridged: timestamps, log prefixes and intervening lines removed
    NodeAbstractResourceInstance.writeResourceInstanceState: writing state object
      for module.my_password.random_password.new_password
    statemgr.Filesystem: state has changed since last snapshot, so incrementing serial to 1
    statemgr.Filesystem: writing snapshot at terraform.tfstate
    statemgr.Filesystem: state has changed since last snapshot, so incrementing serial to 2
    ```

    The first write happens **mid-graph**, the moment `random_password` finishes creating. Terraform's local-backend `StateHook.PostStateUpdate` calls `WriteState` on every state update during the walk, so a crash partway through an apply still leaves already-created resources recorded. The second write is the final snapshot taken after the graph walk closes.

    On the listing above the whole apply finishes in under a second, so both writes land ~20 ms apart and the "mid-graph" part is easy to miss. Adding a deliberately slow resource separates them. With a `random_password` plus a `time_sleep` of 60 s that depends on it, the writes fall either side of the sleep:

    | Clock | Event | `serial` |
    | --- | --- | --- |
    | 12:05:09 | `random_password` created, snapshot written | 1 |
    | 12:06:09.353 | `time_sleep` completes, snapshot written | 2 |
    | 12:06:09.362 | graph walk closes, final snapshot | 3 |

    The counter starts at **0** (`statemgr.NewStateFile` leaves `Serial` at its zero value), and the increment is guarded by a content comparison — `StatesMarshalEqual` against the previously read snapshot — so an identical snapshot writes without bumping.

    Consequences worth remembering:

    - On a local backend, a **first apply** lands at roughly *number of managed resources + 1*. A fresh directory with three `random_password` resources ends at `serial` 4.
    - Data sources do **not** contribute a bump of their own.
    - A **no-op apply** leaves `serial` untouched, because the marshalled state is unchanged.
    - Therefore `serial` is a reliable *ordering* key for "which backup is newest", but it is **not** a count of applies, and gaps in it mean nothing.
    - **Interrupting an apply writes more snapshots, not fewer.** `StateHook.Stopping` persists on the way out so a subsequent hard kill costs you less recovery work. Killing the `time_sleep` run mid-sleep left `serial` at 3 with one resource recorded.

    Verified on Terraform 1.15.8 against the matching source tag.

!!! warning "You can't read `terraform.tfstate` while an apply is running (Windows)"
    Terraform holds the state file open for the duration of the run, so any attempt to read it mid-apply fails with `PermissionError: [Errno 13] Permission denied`. Only the file's *metadata* is visible, which is enough to watch the size change as snapshots are written but not to inspect their contents. To see what an intermediate snapshot actually holds, read the `TF_LOG=trace` output instead, or interrupt the run — bearing in mind that interrupting adds a snapshot of its own.

### 6.3.2 State versions

Two different "versions" ride along with state, and they mean different things:

- **`version`** — the **format** of the data structure. As fields are added/removed/changed over Terraform's history, this bumps; Terraform stays backward-compatible and auto-upgrades older state, so it needs to know which format it's reading.
- **`terraform_version`** — the **CLI version** that last updated the file. In theory usable for version-specific bug fixes; in practice informational.

### 6.3.3 Lineage and serial

Both describe *this specific instance* of state:

- **`lineage`** (UUID) is a **safety mechanism** — the odds of two environments sharing a UUID are practically zero, so backends compare it to refuse overwriting *project A's* state with *project B's*. The comparison is narrower than that framing suggests; see below.
- **`serial`** (integer) increments on every save whose content actually differs, so it counts *writes* rather than applies (§6.3.1). Backends that version state, or a restore-from-backup flow, use it to identify the **latest** version; cloud-block backends use it to refuse overwriting a newer state with an older one.

#### How the lineage is generated

`statemgr.NewLineage` is the whole of it: it asks `hashicorp/go-uuid` for a UUID, which reads **16 bytes from `crypto/rand`** and formats them as `%x-%x-%x-%x-%x`.

No version or variant bits are set, so despite the familiar shape these are **not RFC 4122 v4 UUIDs** — they are 128 random bits wearing UUID punctuation. You can see it in any state file: a v4 UUID has `4` as the first nibble of the third group and one of `8/9/a/b` as the first nibble of the fourth. A lineage of `682e4b6c-222f-9c4f-452d-4234e738e3b3` has `9` and `4` there, satisfying neither rule. Uniqueness rests entirely on the 128 bits of CSPRNG output, not on any structure.

The value is minted **once**, when a state is first written at a given location. The local backend gets it from `NewStateFile()`; remote backends generate one in `PersistState` when they find no existing snapshot (`if s.lineage == ""`). Afterwards it is copied forward verbatim on every write, and only `serial` changes.

#### How the comparison actually happens

Everything funnels through one comparator, `SnapshotMeta.Compare`, which is a plain string comparison — no hashing, no chain of custody:

```go
case m.Lineage == "" || existing.Lineage == "":  return SnapshotLegacy    // '?'
case m.Lineage != existing.Lineage:              return SnapshotUnrelated // '!'
case m.Serial > existing.Serial:                 return SnapshotNewer     // '>'
case m.Serial < existing.Serial:                 return SnapshotOlder     // '<'
default:                                         return SnapshotEqual     // '='
```

Lineage answers "same project?", and serial then answers "which one is newer?". `CheckValidImport` builds on that: it accepts `Newer` and `Legacy`, accepts `Equal` only when the two states marshal identically, and rejects `Unrelated` with `cannot import state with lineage %q over unrelated state with lineage %q`.

!!! warning "A normal apply never compares lineage"
    This is the part the field description hides. Reading state and writing it back carries the lineage forward without ever checking it, so nothing in a routine `plan`/`apply` cycle consults the field. The comparison only runs where two **independently obtained** snapshots meet:

    | Trigger | Where | Bypass |
    | --- | --- | --- |
    | `terraform state push`, backend migration | `WriteStateForMigration` → `CheckValidImport` | `-force` skips the check entirely |
    | Applying a **saved plan** | local backend, "Saved plan does not match the given state" | none |
    | Writing a planned state update | `WritePlannedStateUpdate`, "planned state update is from an unrelated state lineage" | none |
    | Remote/cloud persist | `PersistState` compares the lineage and serial captured at read time, to detect a concurrent write | none |

    Two further escape hatches: an **empty existing state is always overwritable** regardless of lineage, and a **missing** lineage on either side yields `SnapshotLegacy`, which is also allowed (the pre-0.9 compatibility path).

    So the guard is narrower than "backends compare lineage to refuse overwriting another project's state" implies. Nothing stops two configurations pointing at the same state file during normal operation. What the check catches is importing a *foreign snapshot over an existing one*, and `-force` disables even that.

    Verified against the Terraform 1.15.8 source.

### 6.3.4 Resources, outputs, and checks

These three sections are *why state exists* — they map real infrastructure back to the code.

- **`resources`** holds both resources and data sources. Each object carries the identity triple **`module` + `type` + `name`** (always unique together — this forms the resource address), the **`provider`** it was created with (so Terraform notices a provider change), and an **`attributes`** block saving every computed attribute and user parameter. A `schema_version` (set by the provider) lets the provider migrate its own attribute layout.
- **`outputs`** is an **object, not an array**, holding only the **root module's** outputs — with each value's `type` recorded so other projects can read it via `terraform_remote_state` without the generating code. Nested-module outputs are **not** saved unless a resource consumes them.

!!! warning "Child-module outputs are not in state"
    In the example, the child module's `password` output isn't stored — only the root re-export is. If you need a nested output available cross-project, you must thread it up to a **root** output explicitly.

- **`check_results`** stores each `check` block's status (including checks from child modules) plus every individual assertion result; `null` rather than an empty array when there are no checks.

---

## 6.4 Storing state

By default Terraform uses the **local backend** — a `terraform.tfstate` file on the machine running it. It's meant only for development: a single hardware failure loses it, its security depends entirely on the host, and it's invisible to anyone else. It fails all three §6.2 considerations, which is fine because it's not for production.

!!! info "Backends became production-capable at v1.3"
    Since Terraform **v1.3**, all built-in backends *can* meet the resiliency/security/availability bar — but some need extra vendor-side config. Example: using the `s3` backend **without state locking** can easily corrupt state, so always read your backend's docs for its specific requirements.

### 6.4.1 Possible backends

Backends are **built into Terraform** and can't be added via extensions, so they share the same core functionality — they differ mainly in **where** state lives and how you authenticate. The deciding factor is usually **whatever tech your team already runs** (AWS → `s3`, Azure → `azurerm`). Specialized runners called **TACOS** (Terraform Automation and Collaboration Software) provide state + CI/CD; with those you use the `remote` or `cloud` backend. Picking a backend shouldn't consume much time — stick with what you already use.

A condensed version of the book's Table 6.1:

| Backend | Storage system | Workspaces | Notes |
| --- | --- | --- | --- |
| `local` | Local filesystem | Yes | Never use in production. |
| `azurerm` | Azure Storage | Yes | Good if you're already on Azure. |
| `consul` | Consul KV | Yes | Good for self-hosting, especially HA Consul. |
| `cos` | Tencent | Yes | If you're on Tencent. |
| `gcs` | Google Cloud Storage | Yes | If you're on GCP. |
| `http` | Custom HTTP API | No | Build your own backend over REST; avoid pre-v1.6 due to state-size limits. |
| `kubernetes` | K8s Secrets | Yes | — |
| `oss` | Alibaba Cloud | Yes | Uses Table Store for locking. |
| `pg` | PostgreSQL | Yes | State in a SQL database. |
| `s3` | AWS S3 | Yes | See the locking note below. |
| `remote` | Terraform Enterprise / TACOS | No | Being replaced by the `cloud` block. |
| `cloud` | HCP Terraform / TACOS | — | More than a backend — controls operations too (§6.4.5). |

!!! info "S3 locking no longer needs DynamoDB — the book's Table 6.1 is out of date"
    The book says the `s3` backend "requires DynamoDB for locking, which makes it unsuitable for Wasabi or other S3-emulation systems." As of **Terraform 1.10 / OpenTofu 1.10**, the S3 backend locks **natively** using S3 **conditional writes** (a `.tflock` object in the bucket), enabled with **`use_lockfile = true`** — no DynamoDB table. DynamoDB-based locking (`dynamodb_table`) is **deprecated** and slated for removal in a future minor; you can set both during migration. This also removes the Wasabi/emulator caveat, since only S3 conditional-write support is required. See [[version-facts]] and [[feature-history]].

    ```hcl
    terraform {
      backend "s3" {
        bucket       = "my-tf-state"
        key          = "prod/network.tfstate"
        region       = "us-east-1"
        use_lockfile = true      # native S3 locking; drop dynamodb_table
      }
    }
    ```

!!! danger "Never run a backend without locking"
    Two concurrent applies against unlocked state can corrupt it. Most backends lock automatically; a few (historically `s3`) need it enabled explicitly.

### 6.4.2 Configuring the backend

Regardless of backend, **read the up-to-date official docs and the changelogs on every Terraform upgrade** — the backend subsystem changes in **backward-incompatible** ways more often than most of Terraform, so confirm your config is still valid before upgrading.

The book frames setup (figure 6.1) around these themes:

- **Restrict access** (security) — only who needs it; if CI/CD runs production, developers don't need state access.
- **Enable logging** — track all access to state.
- **Configure backups** — and make sure they're reliable.
- **Enable encryption** — some backends do it automatically, others require it explicitly.
- **Configure locking** — automatic for many, explicit for some (`s3`).

!!! tip "The golden rule of backups: untested backups are worthless"
    Test restores regularly — a backup that worked last month may be broken now. It doubles as a rehearsal of your disaster-recovery posture and makes sure the team knows the drill.

### 6.4.3 Backend block

Configuration lives in a `backend` block inside the `terraform` settings block, **only in the root module** (a project has exactly one backend). Each backend has its own parameters — typically something to identify the project plus auth values; cloud-provider backends pick up the same default env vars / config files as their providers.

The chapter walks a **self-hosted Consul** example (run locally with Docker Compose), then shows the three configuration styles:

```hcl
# Full inline config — DON'T hardcode credentials like this
terraform {
  backend "consul" {
    address      = "localhost:8500"
    scheme       = "http"
    path         = "path/to/save/state"
    access_token = "01a56e2d-..."   # bad practice: secrets in code
  }
}
```

**Partial configuration** is the norm — strip out everything that varies per environment (and anything secret), leaving a near-empty block (Terraform still needs the block so it knows which backend to use):

```hcl
terraform {
  backend "consul" {
    scheme = "https"   # keep only what you want to hard-enforce
  }
}
```

Then supply the rest at init time. Precedence when methods overlap: **CLI flags beat the config file**, and a repeated CLI value uses the **last** one:

```shell
terraform init -backend-config=backend.tfvars           # a tfvars file (preferred)
terraform init -backend-config="address=localhost:8500" # CLI flag (logged/history — riskier for secrets)
```

!!! warning "Backend config is cached on disk"
    Whatever you pass gets saved under `.terraform/` so it persists across `plan`/`apply` and lets Terraform detect a backend change (to help you migrate — §6.4.6). That means **auth values passed this way now sit in `.terraform/`** too. (Book Ch7 covers keeping that secure.)

### 6.4.4 Alternative authentication methods

Every backend except `local` needs auth, and each does it differently. Three general choices, worst-to-best:

1. **Hardcode** in the block/config file — avoid; non-portable and insecure.
2. **A config file controlled outside Terraform** — common with cloud providers (AWS/Azure/GCP pick up their default credential files automatically).
3. **Environment variables** — natural fit for **CI/CD**, where secrets are usually exposed as env vars.

### 6.4.5 Cloud block

The `cloud` block is a special kind of backend. Where normal backends give Terraform access to a storage system, the cloud backend defines a **standard other services implement** — so third parties can integrate without patching Terraform. Beyond state storage it can **override `plan` and `apply` to run remotely** (but not `import` or the `state` commands), enabling **CLI-driven runs** on a third-party system while you develop locally against a shared, central config.

```hcl
terraform {
  cloud {
    organization = "acme-org"
    hostname     = "app.terraform.io"   # or e.g. acme.scalr.io
    workspaces {
      tags = ["acme_application", "development"]  # tags → terraform workspace can switch
    }
  }
}
```

Use `name` instead of `tags` to lock to a **single** workspace (disables `terraform workspace`). No credentials in the block — run **`terraform login <hostname>`** once; it saves a token to disk that Terraform reads automatically. HashiCorp's Terraform Cloud was the first `cloud`-block vendor; Scalr, Env0, and others adopted it too.

!!! info "OpenTofu — `cloud` block defaults differ"
    With HashiCorp Terraform, `organization`/`hostname` default to `app.terraform.io` (Terraform Cloud). **OpenTofu specifies no default vendor**, so you must set `hostname`/`organization` explicitly. HCL is otherwise identical.

!!! warning "`cloud`-block workspaces ≠ CLI workspaces"
    With the `cloud` block, `terraform workspace` links to **distinct HCP environments** that share nothing. Without it, workspaces are just separate state on the *same* code/modules (§6.4.7). This overloading of the word "workspace" is a constant source of confusion — if you want local-dev workspaces while also using Terraform Cloud, develop against the **local backend**.

### 6.4.6 Migrating backends

Terraform makes moving state between backends easy. Because it caches backend info under `.terraform/`, the next `terraform init` after you change the backend config **fails with a helpful error**, offering:

- **`-migrate-state`** — copy the current state to the new backend.
- **`-reconfigure`** — discard state association and start fresh with the new backend.

!!! warning "Only the current state version migrates"
    If your old backend kept multiple versions, migration copies **only the latest**. Older versions (usually just corruption backups) must be moved by hand if you want them — back them up first.

### 6.4.7 Workspaces

Workspaces are instances of one configuration that share code, plugins, and modules but keep **separate state**. Managed with `terraform workspace`:

| Command | Effect |
| --- | --- |
| `terraform workspace list` | List available workspaces. |
| `terraform workspace new <name>` | Create a workspace. |
| `terraform workspace delete <name>` | Delete a workspace. |
| `terraform workspace select <name>` | Switch to a workspace. |

Terraform exposes the current name as **`terraform.workspace`**, available at **plan time** — so it's legal in `count`/`for_each`. A common pattern is a per-workspace lookup map:

```hcl
locals {
  networks = {
    production = { vpc = "vpc-...", subnets = ["subnet-...", "subnet-..."] }
    staging    = { vpc = "vpc-...", subnets = ["subnet-..."] }
    default    = { vpc = "vpc-...", subnets = ["subnet-..."] }  # local dev default
  }
  current_network = local.networks[terraform.workspace]
}
```

!!! warning "CLI workspaces are not environment isolation"
    See §6.4.5 — the same word means two different systems. Original CLI workspaces share everything but state; HCP workspaces are fully independent. See [[workspaces]].

### 6.4.8 Upgrading backends

Backends are **not guaranteed backward-compatible** across versions — v1.3 *removed* several legacy backends that lacked state locking. Since backends ship inside the CLI, you upgrade them whenever you upgrade Terraform. Usually nothing changes, but parameters occasionally shift, so **read the upgrade notes** on every version bump.

---

## 6.5 Manipulating state

You sometimes need to change state **without changing infrastructure** — rename a resource without destroy/recreate, drop something from Terraform's control without deleting it, or bring an unmanaged resource in. Three ways, best-to-worst: **code** (`moved`/`removed` blocks), the **CLI** (`state` subcommands), and — last resort — **hand-editing**.

### 6.5.1 Backup and restore

Before touching state, back it up — manipulation is potentially destructive.

```shell
terraform state pull > my_backup.tfstate         # dump current backend state to a file
terraform state push my_backup.tfstate           # push a local file back to the backend
cat my_backup.tfstate | terraform state push -   # equivalent, via stdin
```

!!! warning "`state push` guards on lineage and serial"
    A push with a **different lineage** or a **lower serial** than the backend's is rejected. To restore an *older* backup over a newer state you must add **`-force`** — which also skips the other safety checks, so prefer bumping the backup's `serial` by 1 instead (see §6.5.4).

### 6.5.2 Code-driven changes

The **best** way to change state — it's declarative, repeatable, and lives in your code. Two blocks:

- **`moved`** (Terraform **≥ 1.1**) — tells Terraform a resource/module **changed address**, so it relocates the state entry instead of destroy+recreate. Takes `from`/`to`. Only fires while `from` still exists in state, then becomes a no-op — safe to leave in code.
- **`removed`** (Terraform **≥ 1.7**) — takes only `from` and **drops the entry from state**. Requires a nested `lifecycle { destroy = ... }` declaring whether to also destroy the real resource.

```hcl
resource "random_password" "main" {
  length = 12
}

moved {
  from = random_password.my_password   # old address
  to   = random_password.main          # new address
}

removed {
  from = aws_s3_bucket.bucket          # no longer in config
  lifecycle {
    destroy = false                    # keep the real bucket; just forget it
  }
}
```

`moved` works for **modules** too, so you can pull a resource out of the root into a child module without recreating it:

```hcl
moved {
  from = random_password.my_password
  to   = module.password.random_password.main
}
```

!!! tip "`moved` is essential for shared modules"
    Because it applies automatically in every environment consuming the module, a module author can refactor internals freely without forcing painful upgrades on users.

### 6.5.3 CLI-driven changes

The **second-best** way — better than hand-editing, for the few things code can't express.

- **`terraform state rm <address>`** — remove a resource from state **without touching real infrastructure**. (The pre-`removed`-block way to do this.) If you don't also remove it from code, the next run recreates it. Use `terraform state list` to find addresses.

```shell
$ terraform state list
module.my_password.data.null_data_source.values
module.my_password.random_password.main

$ terraform state rm module.my_password.random_password.new_password
Removed module.my_password.random_password.new_password
Successfully removed 1 resource instance(s).
```

- **`terraform state replace-provider <from> <to>`** — rewrite the provider recorded for resources in state (needed because state records the creating provider). Rare — mostly for testing a dev build of a provider, then switching back.

```shell
terraform state replace-provider hashicorp/random registry.custom_registry.io/hashicorp/random
```

!!! tip "`terraform import` / `terraform state mv` are legacy"
    Both still exist (and won't be removed soon) but there's no good reason to use them now that the **`moved` block** (relocation) and the **`import` block** (Terraform **≥ 1.5**, covered in the book's Ch8) exist. If you reach for either CLI command, reach for the block instead. See [[core-workflow]].

### 6.5.4 Manually editing

**Method of last resort** — e.g. recovering corrupted state. Flow: `terraform state pull` → edit → `terraform state push`. It's a bad idea: you lose Terraform's formatting/validation and repeatability, JSON is unforgiving (a malformed file may be unreadable), and a slip can drop a resource so Terraform recreates something that already exists.

!!! danger "If you must hand-edit state"
    Keep a backup, run the result through a **JSON validator**, **diff** against the backup to catch mistakes, and **increment `serial` by 1** so you can push *without* `-force` and keep the other safety checks live.

---

## 6.6 State drift

**Drift** = infrastructure changed outside Terraform, so state no longer matches reality. It's detected on a **refresh** — at the start of a plan, or via `terraform plan -refresh-only` (the supported replacement for the old `terraform refresh`). A normal plan will propose changes to pull reality back to your config.

But drift is usually a **symptom** — infrastructure rarely changes itself. The first question is always **what changed and why**, answered by understanding the system, reading logs, and talking to the team. The book sorts causes into four categories (figure 6.2), on two axes — machine vs human, accidental vs intentional.

### 6.6.1 Accidental manual changes

Plain human error — wrong account, wrong command. Frame it as a **systems problem**, not an individual's fault: humans err, so design for it (restrict production access, enforce CI/CD, add policy around manual changes). These are usually the **easiest** to fix — a `terraform plan` typically works out exactly how to restore the intended state.

### 6.6.2 Intentional manual changes

Someone changed infra on purpose (often an on-call engineer fixing an outage fast). Harder, because the change was *wanted* but the next Terraform run will **revert** it. Best defense is a policy that all changes go through Terraform (easier to sell with a solid pipeline). When it happens anyway, **get the change into code ASAP** — until then it's **not safe to run Terraform**, since any run reverts the fix.

### 6.6.3 Conflicting automated changes

Managed resources change in **expected** ways from other automation:

- New machine/container **images** published and picked up by data sources.
- External orchestrators adding **tags/annotations**.
- **Autoscaling** at a different task/instance count than launch.
- **Minor version** bumps (e.g. AWS RDS maintenance-window upgrades).

None are errors, but handle them deliberately — **apply** (redeploy to the new artifact) or **ignore**. `ignore_changes` exists mainly for this: ignore specific attributes so they don't churn (classic uses: artifact pointers, autoscaling desired count).

```hcl
resource "aws_instance" "main" {
  tags = {
    Name        = var.name
    Application = var.application
  }
  lifecycle {
    ignore_changes = [tags]   # tags changed out of band → don't fight them
  }
}
```

Some auto-changes need **nothing** — the RDS minor-version case settles with a `-refresh-only` plan. See [[meta-arguments-lifecycle]].

### 6.6.4 Terraform errors

The nastiest category — Terraform itself failed:

- Crashed before saving state.
- The machine/container running it errored.
- It saved a **corrupted** state.
- Backend auth expired mid-run.

Most cases leave **outdated state** — changes made but not persisted. The dangerous one: Terraform **created** a resource but never recorded it, so the next run tries to create a **brand-new** one (best case: wasted money; worst case: blocked deploy or a broken system). Fix by reading logs, identifying what got created, and either **`terraform import`**-ing it or deleting it so Terraform can safely recreate. **Corrupted** state means Terraform can't run at all — **restore from backup** (another reason to keep external backups even when the backend versions state).

---

## 6.7 Accessing state across projects

Big projects pay a **refresh cost** on every plan — hundreds/thousands of resources add up. Splitting into smaller projects speeds iteration (at the cost of coordinating between them). Slow-to-provision resources (cloud **databases** are notorious) are another reason to split. But the biggest driver is **Conway's law** — org structure mirrors system structure: as companies grow, dedicated network/security/DNS/database teams own their slices, and other teams need a way to read values like a **VPC ID** they don't manage.

### 6.7.1 `terraform_remote_state`

The usual tool — a **built-in data source** (no separate provider) that **reads another state's root-module outputs** into your code. **Read-only**; it never modifies the other state. Its backend config uses a different shape from the `backend` block: two params, `backend` (string) and `config` (object of backend-specific settings).

```hcl
data "terraform_remote_state" "rds" {
  backend = "s3"
  config = {
    bucket = var.state_bucket_name
    key    = var.rds_state_path
    region = var.state_region
  }
}

module "service" {
  source = "./modules/service"
  image  = "my_example_image"
  env = {
    rds_uri = data.terraform_remote_state.rds.outputs.rds_uri
  }
}
```

!!! warning "You can only read ROOT-level outputs"
    The source project must **expose the value as a top-level `output`**. Nested-module values aren't in state (§6.3.4), so if you need the RDS ARN, the producing project has to output it.

Use **`defaults`** to turn a **hard** dependency into a **soft** one — supply fallback values for when the remote state is missing an output or is empty (e.g. a brand-new project), so you can stand things up before the other project is ready:

```hcl
data "terraform_remote_state" "rds" {
  backend = "s3"
  config  = { bucket = var.state_bucket_name, key = var.rds_state_path, region = var.state_region }
  defaults = {
    rds_uri = null    # output exists (as null) even if the remote state lacks it
  }
}
```

### 6.7.2 Structuring for remote state

Remote state can hurt maintainability — cross-project values are hard to trace during an error, and the dependency makes code less portable. Two patterns help:

- **Treat remote-state reads like top-level variables.** Keep `terraform_remote_state` blocks in the **root** module (which mostly composes other modules) and feed the values *into* the child modules. That keeps remote-state coupling out of the reusable modules.

```hcl
data "terraform_remote_state" "network" {
  backend = "gcs"
  config  = { bucket = var.state_bucket_name, prefix = var.network_prefix }
}

module "service" {
  source     = "./modules/service"
  image      = "my_example_image"
  vpc_id     = data.terraform_remote_state.network.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}
```

- **Wrap remote-state reads in a dedicated internal module.** Works when the backend can be hardcoded (a single internal server) — good for org-internal modules, poor for open-source ones (backend config leaks). A network team can ship a module that hides the state path behind one `network_name` variable and re-exports `vpc_id`/subnets as outputs.

### 6.7.3 Alternatives to `terraform_remote_state`

Prefer alternatives first — remote-state access carries all the §6.2.2 security weight: **anyone who can read the state can read every sensitive value in it**.

- **Data sources** — look the resource up directly (e.g. query the DB instance for its IP instead of reading it from state). More standalone; downside is coverage — not everything has a data source, or the lookup isn't precise enough. (Book Ch10 covers tagging strategies that make lookups easier.)
- **Input variables** — pass the values in. More secure than sharing state, but more manual upkeep. Minimize these and prefer data sources where possible.

See [[tf-remote-state-data]] for the HCP-native `tfe_outputs` alternative (reads outputs without granting full state access).

---

## 6.8 State-only resources

Ch5's `tls` CA was a **state-only provider** — it computes values programmatically and persists them **in state**, with no third-party system, no external API, no files. This section covers the other four.

### 6.8.1 Random provider

The most-used state provider. It exists to generate random data **without regenerating it every run**. Ordinary language random functions are **impure** (§4.3.3) — a different result each call — so using one in HCL would show a change on *every* plan (perpetual drift). The `random` provider instead **persists** its randomness: it generates once, and only regenerates when its **`keepers`** map changes.

```hcl
resource "random_uuid" "example" {
  keepers = {
    name = var.name   # change var.name → regenerate the UUID
  }
}
```

The provider covers `random_integer`, `random_uuid`, `random_pet` (human-readable names like `sage-longhorn`; result in **`id`**, not `result`), `random_shuffle`, `random_bytes`, etc.

```hcl
resource "random_integer" "number" { min = 0, max = 10 }   # result in .result
resource "random_uuid" "uuid" {}                            # result in .result
resource "random_pet" "suffix" { length = 2 }               # result in .id (!)
```

**`random_password`** is special: the only resource **guaranteed** to use a cryptographic RNG, so it's safe for real passwords. Its result is marked **sensitive** (kept out of logs, warns if used as a root output). Parameters: `length` (only required field), `lower`/`numeric`/`special`/`upper` toggles, `min_*` requirements, `override_special`.

!!! danger "`random_password` still lands in state in plaintext"
    Sensitive ≠ encrypted (§6.3.1). If you generate real credentials with `random_password`, be extra careful who can read the state.

!!! tip "`random_password` reports `[id=none]`"
    Where `random_pet` puts its result in `.id`, `random_password` deliberately does not — resource IDs are echoed in plan/apply output and logs. Apply prints `Creation complete after 0s [id=none]` and the state stores the literal string `"none"`. The provider documents `id` as "A static value used internally by Terraform, this should not be referenced in configurations", so read the value from `.result` only. The state also carries a `bcrypt_hash` attribute, a bcrypt hash of the generated string (of its first 72 bytes if longer).

### 6.8.2 Time provider

Records the time of events **without** causing drift — the same problem the `timestamp()` function has (Ch4, different value each call). It generates a timestamp only on **creation** or when its **`triggers`** map changes (mirroring `random`'s `keepers`). Four resources:

| Resource | Behaviour |
| --- | --- |
| `time_static` | Records its creation time; regenerates when `triggers` changes. Result in `.rfc3339`. |
| `time_offset` | Like `time_static` but shifted by a specified offset (e.g. `offset_hours = 2`). |
| `time_rotating` | Regenerates when its configured lifespan (e.g. `rotation_days = 2`) expires. |
| `time_sleep` | **Delays execution** — insert between resources to wait (`create_duration`/`destroy_duration`). |

```hcl
resource "time_rotating" "every_two_days" {
  rotation_days = 2
}

resource "aws_instance" "rotating_machine" {
  lifecycle {
    replace_triggered_by = [time_rotating.every_two_days.id]  # rotate → replace the instance
  }
}

# Force a gap between two instances
resource "time_sleep" "delay" {
  create_duration = "2m"
  depends_on      = [aws_instance.main]
}
resource "aws_instance" "dependent" {
  depends_on = [time_sleep.delay]
}
```

### 6.8.3 Null provider

One resource, **`null_resource`**, that follows the full create/update/delete lifecycle but **does nothing** — a "no-op". Unlike other state-only resources it doesn't even generate data. Useful as a **testing scaffold** (generic CI/CD pipeline, code-gen, or custom Terraform-based tooling) that runs real Terraform quickly without touching real infra. Its `triggers` map controls recreation.

```hcl
resource "null_resource" "nothing" {
  triggers = {
    rebuild = timestamp()   # recreate every run
  }
}
```

Before **v1.4**, `null_resource` was mainly a host for custom **provisioners** (book Ch8) — now a legacy practice; today it "really does nothing", which is exactly what makes it a clean test workspace (works as a root module with no provider config).

### 6.8.4 `terraform_data`

A **built-in** resource (no provider needed), added in **Terraform v1.4** as the modern **replacement for `null_resource`**. Same idea — full lifecycle, no action — but uses **`triggers_replace`** instead of `triggers`.

```hcl
resource "terraform_data" "nothing" {
  triggers_replace = {
    rebuild = timestamp()   # like null_resource's triggers
  }
}
```

Two things it does beyond being a no-op:

- **Enable replacements that would otherwise be impossible.** `replace_triggered_by` can't reference a local or input variable directly — so route the logic through a `terraform_data` whose `triggers_replace` holds the computed local, and reference *it*:

```hcl
variable "user_input" { type = number }
locals { is_even = var.user_input % 2 == 0 }

resource "terraform_data" "local_replacement" {
  triggers_replace = { is_even = local.is_even }
}
resource "aws_instance" "myinstance" {
  lifecycle {
    replace_triggered_by = [terraform_data.local_replacement]  # local drives replacement
  }
}
```

- **Host provisioners** (book Ch8) — same role `null_resource` used to play.

!!! note "You'll still meet `null_resource` in the wild"
    `terraform_data` covers essentially everything `null_resource` does, but it's newer — the `null` provider was still installed **9M+ times in the first week of 2025**. Both work; new code should prefer `terraform_data`. See [[tf-terraform-data]].

---

## Summary

- Terraform is **stateful** to link code to real objects reliably, keep the engine (and provider dev) simpler, and keep the plan loop fast — at the cost of storing and protecting state.
- Judge a state store on **resiliency, security, availability**; treat it as critical infra with tested backups and an SLA.
- State is **JSON**: `version` (format) vs `terraform_version` (writer), `serial` (bumped per differing write, not per apply), `lineage` (immutable random ID, checked only on import/migration/saved-plan), plus `resources`/`outputs`/`check_results`. **Sensitive values sit in it in plaintext** — only root outputs are stored, and marking `sensitive` only hides display.
- **Backends** are built-in; the `local` one is dev-only. Pick by existing tech; use **partial config** + `-backend-config`; migrate with `-migrate-state`. **S3 now locks natively (`use_lockfile`, TF/OpenTofu 1.10) — DynamoDB locking is deprecated.**
- **CLI workspaces** share everything but state and expose `terraform.workspace` at plan time; **`cloud`-block workspaces are unrelated HCP environments** — don't conflate them.
- Change state safely with **`moved`** (1.1) / **`removed`** (1.7) blocks first, `terraform state` commands second, hand-editing never (and if you must: backup, validate, diff, bump `serial`).
- **Drift** falls into four buckets (accidental/intentional manual, conflicting automated, Terraform errors); fixes range from a plain `apply` to `ignore_changes` to `import`/restore-from-backup.
- **`terraform_remote_state`** reads another project's **root** outputs read-only; prefer **data sources** or input variables first, since reading state exposes all its secrets.
- **State-only providers** — `random` (persist randomness via `keepers`), `time` (timestamps without drift), `null` (`null_resource` no-op), and built-in **`terraform_data`** (the modern `null_resource`, via `triggers_replace`).

## References

- Terraform state — purpose & internals — <https://developer.hashicorp.com/terraform/language/state>
- Backend configuration — <https://developer.hashicorp.com/terraform/language/backend>
- S3 backend (`use_lockfile`, native locking) — <https://developer.hashicorp.com/terraform/language/backend/s3>
- Managing state / `terraform state` commands — <https://developer.hashicorp.com/terraform/cli/state>
- `moved` block — <https://developer.hashicorp.com/terraform/language/modules/develop/refactoring>
- `removed` block — <https://developer.hashicorp.com/terraform/language/resources/syntax#removing-resources>
- `terraform_remote_state` data source — <https://developer.hashicorp.com/terraform/language/state/remote-state-data>
- Workspaces — <https://developer.hashicorp.com/terraform/language/state/workspaces>
- `terraform_data` resource — <https://developer.hashicorp.com/terraform/language/resources/terraform-data>
- `random` provider — <https://registry.terraform.io/providers/hashicorp/random/latest/docs>
- `time` provider — <https://registry.terraform.io/providers/hashicorp/time/latest/docs>
- S3-native locking (TF/OpenTofu 1.10) — PR <https://github.com/hashicorp/terraform/pull/35661> · <https://opentofu.org/docs/language/settings/backends/s3/>
