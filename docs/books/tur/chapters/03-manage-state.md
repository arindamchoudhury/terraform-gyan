# Chapter 3 — How to Manage Terraform State

> *Source: Brikman (2022), **Terraform: Up & Running**, 3rd ed., Chapter 3, pages 81–113.*
>
> The pivot of the book. Chapter 2 built infrastructure; this chapter explains the file that let Terraform find it again, and then follows the consequences all the way out to how you lay out directories. Its argument is that **state is not an implementation detail — it is the thing that decides your project structure.**
>
> 📌 **Notes adapted where version-bound.** Book written 2022 against Terraform ~1.2; current stable is **1.15.8** / OpenTofu **1.12.5** ([[version-facts]]). This chapter has aged **better than Chapter 2 on ideas and worse on mechanics**: the isolation argument is the best statement of it anywhere in these notes, while the locking setup it teaches is now obsolete on both engines, and two of the limitations it presents as inherent have since been closed — one of them only in OpenTofu.

> 🔗 **See also:** [Workspaces](../../../topics/workspaces.md) for the CLI-versus-HCP split this chapter's workspace section only half covers.

---

## The question the chapter opens with

> You could have all sorts of infrastructure in your AWS account, deployed through a variety of mechanisms (some manually, some via Terraform, some via the CLI), so how does Terraform know which infrastructure it's responsible for?

That is the right way in. Terraform does not discover what it owns; it **remembers**.

## 1. What is Terraform state?

Every run records what it created into a state file — by default `/foo/bar/terraform.tfstate` when you run in `/foo/bar`. It is JSON, and the shape is worth reading once:

```json
{
  "version": 4,
  "terraform_version": "1.2.3",
  "serial": 1,
  "lineage": "86545604-7463-4aa5-e9e8-a2a221de98d2",
  "outputs": {},
  "resources": [
    {
      "mode": "managed",
      "type": "aws_instance",
      "name": "example",
      "provider": "provider[\"registry.terraform.io/hashicorp/aws\"]",
      "instances": [
        {
          "schema_version": 1,
          "attributes": {
            "ami": "ami-0fb653ca2d3203ac1",
            "id": "i-0bc4bbe5b84387543",
            "instance_state": "running",
            "instance_type": "t2.micro"
          }
        }
      ]
    }
  ]
}
```

The mapping is the point: `aws_instance.example` in the configuration binds to `i-0bc4bbe5b84387543` in AWS. Which yields the chapter's cleanest one-liner, and the best short definition of `plan` in the book:

> the output of the plan command is a diff between the code on your computer and the infrastructure deployed in the real world, **as discovered via IDs in the state file**.

!!! note "Sidebar — the state file is a private API"
    > The state file format is a private API that is meant only for internal use within Terraform. You should never edit the Terraform state files by hand or write code that reads them directly.

    Still the rule. What the chapter could not yet say is what to use *instead*: `terraform show -json` and `terraform output -json` are the supported machine formats, and [[tf-state]] names them as the sanctioned parse targets precisely because the file format may change between versions. The `serial` and `lineage` fields visible above are not decoration — they are the guards `terraform state push` checks before it will overwrite a remote state ([[tf-state-backends]]).

    The chapter points at `terraform import` and `terraform state` for the rare cases you must intervene. Both still exist; the **`import` block** (1.5+) and the **`moved`** and **`removed`** blocks have since made most of that work declarative and reviewable in a plan ([[tf-block-removed]], [[tf-state-refactor]]).

### The three problems that follow from state

A local state file is fine alone and breaks in three specific ways on a team. The chapter names them once and then spends the rest of the chapter on them:

| Problem | Why it bites |
| --- | --- |
| **Shared storage** | Every team member needs the same state file |
| **Locking** | Two concurrent `apply` runs race, and can corrupt state |
| **Isolation** | One state file for everything means one mistake can break everything |

## 2. Shared storage for state files

### Why not version control

The obvious answer is Git, and the chapter rejects it in three moves:

- **Manual error.** Forget to pull before, or push after, and someone runs against stale state. "It's just a matter of time."
- **Locking.** Version control gives you none.
- **Secrets.** "All data in Terraform state files is stored in plain text." An `aws_db_instance` puts the master username and password there, so committing state commits the password.

That third point is the one to carry. It is not a Git problem, it is a state problem, and it returns at the end of this chapter and again in Chapter 6.

### Backends

> A Terraform backend determines how Terraform loads and stores state.

The default is the **local** backend. Remote backends solve all three problems: automatic load-before and store-after so manual error is impossible, native locking, and encryption in transit and at rest with the store's own access controls on top.

One flag worth memorising from this section: **`-lock-timeout=<TIME>`**, so `terraform apply -lock-timeout=10m` waits ten minutes for a lock rather than failing immediately.

And one sentence that turned out to be a roadmap:

> It would be better still if Terraform natively supported encrypting secrets within the state file, but these remote backends reduce most of the security concerns.

!!! info "The wish came true — in OpenTofu, not Terraform"
    **OpenTofu 1.7 shipped client-side state encryption**: state and plan files are encrypted by OpenTofu before the backend ever sees them, with key providers for PBKDF2, AWS KMS, GCP KMS and OpenBao. Terraform has no equivalent; its answer remains "encrypt the bucket and control access to it", which is exactly the compromise Brikman describes as second-best.

    Know the exit too. OpenTofu registers an **`unencrypted`** method (since 1.7.0) so encryption is not a one-way door — it appears in no changelog or release blog, which is why it is worth writing down ([[version-facts]], [[opentofu-release-feature-map]]).

    This is the single largest state-level divergence between the engines, and the chapter's own text is the best evidence that it was a real gap rather than a novelty.

### Why S3

Six reasons, and they still hold: managed, 99.999999999% durability with 99.99% availability, encryption at rest (AES-256) and in transit (TLS), locking via DynamoDB, versioning so every revision is recoverable, and cheap.

The one to re-check is the last. "Most Terraform usage easily fitting into the AWS Free Tier" assumed the pre-2025 free tier; accounts created on or after **2025-07-15** get credits with a six-month clock instead (see the Ch2 note's reckoning). The cost is still trivial, but the mechanism is different.

### Building the backend's own infrastructure

```hcl
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-up-and-running-state"

  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = true
  }
}
```

Bucket names are globally unique across all AWS customers, so this one must be changed. And `prevent_destroy` is the chapter's **second** `lifecycle` setting after Chapter 2's `create_before_destroy` — a plan-time refusal to delete, with the honest footnote that you can always comment it out if you mean it. Deeper treatment, including the fact that `prevent_destroy` does not survive the resource block being deleted, is on the [meta-arguments](../../../topics/meta-arguments-lifecycle.md) page.

Three more resources harden it:

```hcl
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

> 💭 (mine): this is the one place in the book where the AWS code has aged *well*. The 3rd edition was written just after AWS provider 4.x split `aws_s3_bucket`'s inline settings into separate resources, so the chapter teaches the current shape. Contrast Chapter 2, where the central resource is now uncreatable.

Then the lock table:

```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-up-and-running-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

The primary key must be called **`LockID`**, "with this exact spelling and capitalization". DynamoDB earns the job because it offers "strongly consistent reads and conditional writes, which are all the ingredients you need for a distributed lock system."

!!! danger "The DynamoDB lock table is obsolete — this is the chapter's biggest mechanical drift"
    The S3 backend now locks **using S3 itself**. Set `use_lockfile = true` and delete the table:

    ```hcl
    terraform {
      backend "s3" {
        bucket       = "my-state-bucket"
        key          = "global/s3/terraform.tfstate"
        region       = "us-east-2"
        use_lockfile = true
        encrypt      = true
      }
    }
    ```

    - **Availability.** Terraform **1.11** and OpenTofu **1.10**. Sort by date rather than by version number: Terraform introduced it in 1.10 (2024-11-27) and GA'd it in 1.11 (2025-02-27), roughly seven months ahead of OpenTofu's 1.10 (June 2025).
    - **The mechanism is a conditional write.** The lock is a `.tflock` object; the second writer's `PutObject` carries an if-none-match precondition that fails with **412 PreconditionFailed**. That is the entire lock, which is why no separate service is needed ([[tf-state-locking]], verified locally against Terraform 1.15.8).
    - **The deprecation is Terraform-only.** Terraform v1.15.0 marks `dynamodb_table` `Deprecated: true` in the backend schema and emits a diagnostic saying DynamoDB locking "will be removed in a future minor version". OpenTofu's `main` carries neither the flag nor the diagnostic, so telling an OpenTofu user to migrate off DynamoDB is advice they do not yet need.

    Net effect on the chapter: `aws_dynamodb_table.terraform_locks` and the `dynamodb_table` backend argument both go away, and the two-step bootstrap below gets shorter by one resource.

### The backend block, and migration

```hcl
terraform {
  backend "<BACKEND_NAME>" {
    [CONFIG...]
  }
}
```

The chapter's S3 configuration sets `bucket`, `key`, `region`, `dynamodb_table` and `encrypt`. Two of those deserve emphasis:

- **`key`** is the path *inside* the bucket. The chapter uses `global/s3/terraform.tfstate` here and explains why later — it mirrors the directory layout.
- **`encrypt = true`** is deliberately redundant with the bucket's default encryption. Belt and braces.

`terraform init` then does its third job, after downloading providers and modules: configuring the backend. It detects the existing local state and offers to migrate it.

```text
Initializing the backend...
Acquiring state lock. This may take a few moments...
Do you want to copy existing state to the new backend?
```

After that, every `apply` brackets itself with `Acquiring state lock…` and `Releasing state lock…`, and with bucket versioning on, each run leaves a new version of the state object. The chapter has you look at both in the console, which is the right instinct: **locking and versioning are invisible until you go and see them.**

## 3. Limitations with Terraform's backends

### The chicken-and-egg bootstrap

You cannot store state in a bucket that does not exist yet, so:

1. Write the bucket and lock table, apply with the **local** backend.
2. Add the backend block, run `init`, copy the local state up.

And in reverse to tear it down — remove the backend block, `init` to pull state back down, then `destroy`. Awkward, and the chapter's consolation is fair: one bucket serves all your configurations, so this is a once-per-account cost.

### No variables or references in `backend`

```hcl
# This will NOT work. Variables aren't allowed in a backend configuration.
terraform {
  backend "s3" {
    bucket = var.bucket
    region = var.region
    key    = "example/terraform.tfstate"
  }
}
```

The consequence is the painful part, and the chapter states it precisely: every module must repeat the bucket, region and table verbatim, while **`key` must be unique per module or one module silently overwrites another's state.** Copy-paste everything except the one line you must not copy-paste.

**Partial configuration** is the sanctioned relief. Keep only `key` in code, put the rest in `backend.hcl`, and merge them at init:

```hcl
# backend.hcl
bucket       = "terraform-up-and-running-state"
region       = "us-east-2"
use_lockfile = true
encrypt      = true
```

```bash
terraform init -backend-config=backend.hcl
```

**Terragrunt** is the other answer the chapter offers: define the backend once and have the tool set `key` from the module's relative path automatically.

!!! info "OpenTofu removed this limitation; Terraform did not"
    OpenTofu **1.8** added **early variable evaluation**, so `var` and `local` references work inside `backend` (and `module` source) blocks, resolved at `tofu init` before state exists ([[ot-early-eval-backend]]). The `.tfvars` file can drive it too.

    So the chapter's second limitation is now engine-specific: on OpenTofu the copy-paste problem is solvable in the language, on Terraform it is still solved by partial configuration or by a wrapper. Worth knowing before you reach for Terragrunt purely for this reason — and worth *not* using if the module must run on both engines.

!!! note "Terragrunt's command changed name"
    The chapter (and Ch 10) uses **`run-all`**. Terragrunt's CLI redesign folded it into **`run --all`**, with `graph` similarly becoming `run --graph` ([[terragrunt-facts]]). Same behaviour, new spelling; older material and the book both predate it.

## 4. State file isolation

The framing is the best thing in the chapter:

> Just as a ship has bulkheads that act as barriers to prevent a leak in one part of the ship from immediately flooding all the others, you should have "bulkheads" built into your Terraform design.

One state file for everything means a mistake in staging can break production, and a corrupted state file breaks every environment at once. Two mechanisms are on offer, and the chapter is explicit that they are not equals:

- **Workspaces** — "useful for quick, isolated tests on the same configuration".
- **File layout** — "useful for production use cases for which you need strong separation between environments".

### Isolation via workspaces

Terraform starts in a workspace named `default`. The commands are `terraform workspace new|select|list|show`.

```bash
terraform workspace show          # default
terraform workspace new example1  # Created and switched to workspace "example1"!
terraform workspace list
terraform workspace select example1
```

The demonstration is the useful part: create `example1`, run `plan`, and Terraform proposes creating the EC2 instance **from scratch**, because it is not looking at the default workspace's state. Three workspaces produce three instances.

**How it works underneath** is one sentence, and it is the sentence to remember:

> switching to a different workspace is equivalent to **changing the path where your state file is stored**.

In the S3 bucket a new `env:` folder appears, with one subfolder per workspace, each containing the `key` path from the backend configuration. So `example1/workspaces-example/terraform.tfstate` and so on. The `default` workspace alone writes to the bare `key`.

You can also branch on the current workspace:

```hcl
resource "aws_instance" "example" {
  ami           = "ami-0fb653ca2d3203ac1"
  instance_type = terraform.workspace == "default" ? "t2.medium" : "t2.micro"
}
```

Then the three drawbacks, which are the reason the section exists:

- **One backend, one set of credentials.** Every workspace lives in the same bucket under the same access controls, so there is no security boundary between "staging" and "production" workspaces.
- **Invisible.** "A module that has been deployed in one workspace looks exactly the same as a module deployed in 10 workspaces." Nothing in the code or the terminal tells you.
- **Therefore error-prone.** Easy to forget which workspace you are in, easy to `destroy` the wrong one, and no second layer of defence when you do.

> Due to these drawbacks, workspaces are not a suitable mechanism for isolating one environment from another.

!!! tip "The book is right, and its footnote explains why the misuse persists"
    Brikman's footnote is sharper than the body text: the workspaces documentation makes the same point, but it is "buried among several paragraphs", and **workspaces used to be called “environments”** — so the name itself taught a generation the wrong use.

    Two things to add from [[workspaces-facts]] and the [Workspaces](../../../topics/workspaces.md) topic page, both of which the chapter cannot cover because it predates them:

    - **“Workspace” is two different products.** A *CLI workspace* is a named state slot in one backend and one directory, and it exists in OpenTofu (`tofu workspace`) too. An *HCP Terraform workspace* is a whole deployment with its own configuration, variables, run history and RBAC. They are not the same concept and they do not share a license — CLI workspaces ship in the BSL CLI and in MPL OpenTofu, while the HCP workspace is proprietary SaaS.
    - **What CLI workspaces are actually good for** matches the chapter exactly: short-lived throwaway copies of a stack, one per pull request or experiment, destroyed on merge.

    The path this material feeds, **A7**, carries a ⚠️ because an official tutorial *and* a popular 2026 video course both still teach `lookup(var.instance_type, terraform.workspace)` over a `{dev, staging, prod}` map. This chapter contradicted that in 2022.

### Isolation via file layout

Two requirements:

- A separate folder per environment.
- **A separate backend per environment, with different authentication and access controls.** The chapter's suggestion is a separate AWS account per environment, each with its own bucket.

The second is what makes this different from workspaces. Separate folders alone give you clarity; separate credentials give you a boundary.

Then the escalation that most readers remember: isolate by **component** as well as by environment. A VPC changes a few times a year, a web server several times a day, so managing both in one configuration risks the network topology on every app deploy.

The recommended layout:

```text
stage/          pre-production
prod/           production
mgmt/           DevOps tooling (bastion, CI)
global/         resources shared across environments (S3, IAM)
  └─ per environment:
       vpc/            network topology
       services/       apps and microservices
       data-stores/    MySQL, Redis, …
```

and inside each component, the file convention:

| File | Contents |
| --- | --- |
| `variables.tf` | input variables |
| `outputs.tf` | output variables |
| `main.tf` | resources and data sources |

Terraform itself only cares that files end in `.tf`. The convention is for humans. The chapter offers three optional extensions — `dependencies.tf` for data sources, `providers.tf` for provider blocks, and `main-xxx.tf` (`main-iam.tf`, `main-s3.tf`) when `main.tf` grows — with a good warning attached to the last one:

> if you find yourself managing a very large number of resources and struggling to break them down across many files, that might be a sign that you should break your code into smaller modules instead.

**The Chapter 2 code moves.** The web server cluster becomes `stage/services/webserver-cluster`, the S3 bucket becomes `global/s3`, and each gets a backend `key` matching its directory path — `stage/services/webserver-cluster/terraform.tfstate`. That 1:1 mapping between repository layout and state layout is the payoff, and it is why `key` was set to `global/s3/terraform.tfstate` twenty pages earlier.

> 💡 **Tip** — the chapter tells you to copy the hidden `.terraform` folder along with the files so you do not have to re-initialise. Reasonable in 2022; today `terraform init` is cheap enough that copying a directory of provider binaries between folders is more likely to confuse than to help.

**Three costs, stated honestly:**

- **Many folders means many applies.** You cannot stand up a whole environment with one command. (Terragrunt's `run --all` is the chapter's answer.)
- **Duplication.** `stage` and `prod` hold the same code. Chapter 4's modules fix this.
- **Resource dependencies break.** Code in different folders cannot use an attribute reference like `aws_db_instance.foo.address`. Which sets up the last section.

!!! note "The book's layout is one of three, and TID names the trade-off"
    TID Ch8 catalogues three root-module structures rather than recommending one, and the choice is about **blast radius versus the number of applies** ([[08-cd-deployment]]). TUR's environment-then-component tree is the most isolated and the most operationally expensive; a single root module per environment is the cheapest and the most dangerous. Neither book pretends the middle ground does not exist.

    Also worth reading alongside: [[tf-style-guide]] fixes the *file* convention TUR describes, and [[tf-modules-structure]] fixes the *module* one.

## 5. The `terraform_remote_state` data source

The problem: the web server cluster needs a MySQL database, and the database should not live in the same configuration as the thing that is redeployed daily.

```hcl
resource "aws_db_instance" "example" {
  identifier_prefix   = "terraform-up-and-running"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t2.micro"
  skip_final_snapshot = true
  db_name             = "example_database"

  username = var.db_username
  password = var.db_password
}
```

`skip_final_snapshot = true` is there so `destroy` works at all — without it, and without `final_snapshot_identifier`, teardown fails. RDS takes "roughly 10 minutes" to provision, which the chapter warns about.

### Secrets, the chapter's interim answer

```hcl
variable "db_username" {
  description = "The username for the database"
  type        = string
  sensitive   = true
}
```

No `default`, deliberately, and `sensitive = true` so plan and apply do not log it. Values arrive through the environment:

```bash
export TF_VAR_db_username="(YOUR_DB_USERNAME)"
export TF_VAR_db_password="(YOUR_DB_PASSWORD)"
```

!!! warning "`sensitive` hides the value from the terminal; it does not keep it out of state"
    The chapter says this itself two pages earlier when it argues against committing state to Git, but the two halves are never joined: the password typed into `TF_VAR_db_password` **is written to the state file in plaintext**, and the state file is now in an S3 bucket the whole team can read. The AWS provider says so flatly: *"All arguments including the username and password will be stored in the raw state as plain-text."*

    Three later mechanisms close it, none available in 2022:

    - **`manage_master_user_password = true`** — RDS generates and rotates the password in Secrets Manager, and Terraform never handles it. Cannot be combined with `password` or `password_wo`. Optional `master_user_secret_kms_key_id` for a customer-managed key.
    - **`password_wo`** — a **write-only** argument (Terraform **1.11+**), sent to the API and never persisted to state or plan.
    - **`ephemeral = true`** on the variable (1.10+) so the value itself is excluded from state and plan files ([[tf-block-variable]]).

    `manage_master_user_password` is the one to reach for on RDS specifically, because it removes the secret from your workflow rather than hiding it in transit. Chapter 6 is the book's own treatment; [[tf-manage-sensitive-data]] and [[infisical-terraform-secrets]] are the current ones.

Outputs publish the connection details:

```hcl
output "address" {
  value       = aws_db_instance.example.address
  description = "Connect to the database at this endpoint"
}

output "port" {
  value       = aws_db_instance.example.port
  description = "The port the database is listening on"
}
```

### Reading another configuration's state

```hcl
data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = "(YOUR_BUCKET_NAME)"
    key    = "stage/data-stores/mysql/terraform.tfstate"
    region = "us-east-2"
  }
}
```

Read with `data.terraform_remote_state.<NAME>.outputs.<ATTRIBUTE>`. The chapter is careful to say it is **read-only**, like every data source, so the web server code cannot damage the database's state.

!!! danger "The current docs argue against this data source, and the reason is exactly the S3 bucket you just built"
    HashiCorp's own page for it is mostly the case against ([[tf-remote-state-data]]):

    > "the state snapshot data is **a single object**, and so any user or server which has enough access to read the root module output values **will also always have access to the full state snapshot data by direct network requests**."

    Terraform hands your configuration only the `outputs` map. But the credentials that fetched it could `GET` the whole file — including, in this chapter's own example, the database password sitting in plaintext in `stage/data-stores/mysql/terraform.tfstate`. The web server cluster does not need that, and now every machine that runs it can read it.

    Two recommended alternatives:

    - **`tfe_outputs`** on HCP Terraform or Enterprise, "more secure because it does not require full access to workspace state to fetch outputs."
    - **Publish explicitly** to a store meant for sharing — SSM Parameter Store, a DNS record, a dedicated secrets manager — so shared data and state snapshots can carry different access controls.

    The chapter's mechanism still works and is still the common answer outside HCP. Read the section as *how cross-configuration data sharing was done*, and treat the access-control question as open.

### Externalising the User Data script

The inline heredoc grows a third and fourth line and becomes unpleasant, which motivates two more built-ins.

```bash
terraform console
> format("%.3f", 3.14159265359)
3.142
```

`terraform console` is **read-only**, so experimenting there cannot touch infrastructure or state. Genuinely the fastest way to learn a function.

```hcl
user_data = templatefile("user-data.sh", {
  server_port = var.server_port
  db_address  = data.terraform_remote_state.db.outputs.address
  db_port     = data.terraform_remote_state.db.outputs.port
})
```

```bash
#!/bin/bash

cat > index.html <<EOF
<h1>Hello, World</h1>
<p>DB address: ${db_address}</p>
<p>DB port: ${db_port}</p>
EOF

nohup busybox httpd -f -p ${server_port} &
```

The detail that trips people: inside the template, the only variables in scope are the ones passed in the map, so it is **`${server_port}`, not `${var.server_port}`**.

> 💡 **Tip** — the template path here is relative to the working directory, which is fine in a root module and wrong in a reusable one. Chapter 4's first gotcha fixes it to `${path.module}/user-data.sh`. Related: `templatestring()` (Terraform **1.9+**, OpenTofu-introduced) does the same for a template held in a string rather than a file.

## Conclusion

The chapter's closing argument is about risk asymmetry, and it is the sentence that justifies everything before it:

> When you're writing code for a typical app, most bugs are relatively minor and break only a small part of a single app. When you're writing code that controls your infrastructure, bugs tend to be more severe, given that they can break all of your apps — and all of your data stores, and your entire network topology, and just about everything else.

Hence more safety mechanisms than you would use in ordinary code: locking, versioned state, `prevent_destroy`, separate credentials per environment, folder boundaries. The forward pointer is the duplication those boundaries create, which is Chapter 4's modules.

### State of the running example

By the end of Ch 3 the single Chapter 2 folder has become a tree:

- **`global/s3`** — the state bucket (versioned, encrypted, public access blocked, `prevent_destroy`), the DynamoDB lock table, and two outputs. Its own state now lives in the bucket it created, at `global/s3/terraform.tfstate`.
- **`stage/data-stores/mysql`** — an `aws_db_instance`, two `sensitive` variables fed by `TF_VAR_*`, outputs `address` and `port`, state at `stage/data-stores/mysql/terraform.tfstate`.
- **`stage/services/webserver-cluster`** — the Chapter 2 cluster, now split into `main.tf`/`variables.tf`/`outputs.tf`, reading the database's outputs through `terraform_remote_state`, with its User Data moved out to `user-data.sh` and rendered by `templatefile`. State at `stage/services/webserver-cluster/terraform.tfstate`.

Still no modules, and still only one environment. `prod/` is empty until Chapter 4.

---

## Version reckoning

Ordered by how much they change what you would write today.

!!! danger "1. Drop the DynamoDB table — S3 locks itself now"
    `use_lockfile = true` replaces `dynamodb_table` and `aws_dynamodb_table.terraform_locks` entirely. Terraform **1.11** (introduced 1.10), OpenTofu **1.10**. The lock is an S3 conditional write on a `.tflock` object, failing with **412 PreconditionFailed**. `dynamodb_table` is deprecated in Terraform's schema as of v1.15.0 with removal announced; **not** deprecated in OpenTofu. ([[tf-state-locking]], [[tf-backend-configure]])

!!! warning "2. The password is in the state file, and the chapter's own bucket makes that everyone's problem"
    `sensitive = true` plus `TF_VAR_*` keeps secrets out of the code and out of the terminal, not out of state. On RDS use **`manage_master_user_password`** so AWS holds it in Secrets Manager, or **`password_wo`** (Terraform 1.11+) so it is never persisted. Then reconsider handing the whole state object to the web server configuration via `terraform_remote_state`.

!!! info "3. Two limitations are now engine-specific"
    - **Native state encryption** — OpenTofu 1.7, exactly the feature the chapter wishes for. Terraform has none, and an `unencrypted` method exists in OpenTofu as the way back out.
    - **Variables in `backend` blocks** — OpenTofu 1.8 early evaluation makes the chapter's second limitation false there. Terraform still forbids it; partial configuration remains the answer.

    Both matter when choosing an engine, and both are reasons to keep OpenTofu-only syntax out of modules that must run on Terraform.

!!! note "4. Smaller drifts"
    - **`terraform_remote_state`** now carries an official warning about full-state access, with `tfe_outputs` or explicit publication as the recommended alternatives.
    - **Terragrunt** renamed `run-all` to `run --all`.
    - **`db.t2.micro`** is previous-generation; `db.t3.micro`/`db.t4g.micro` are the current small classes, and the free-tier arithmetic changed on 2025-07-15 in any case.
    - **`import`/`moved`/`removed` blocks** now cover most of what the sidebar defers to `terraform import` and `terraform state`, declaratively and visible in a plan.
    - The **`env:` prefix** for non-default workspaces is still the S3 backend's behaviour, and is configurable via `workspace_key_prefix`.

!!! tip "What TUR Ch3 has that TID Ch6 doesn't, and vice versa"
    - **TUR argues from consequences.** State exists, therefore locking; locking is shared, therefore isolation; isolation means folders, therefore duplication, therefore modules. The bulkhead metaphor and the environment/component tree are the artifacts to lift, and nothing in TID replaces them.
    - **TID Ch6 is the reference half** ([[06-state-management]]): the tfstate JSON in detail, backend types and migration, workspaces, drift, `moved`/`removed`, `terraform_remote_state`, and state-only providers. It is where you go when you need to *do* something to state rather than decide how to lay a project out.
    - **Neither is current on locking.** TID's own text needed the same `use_lockfile` correction, which is a good reminder that the fastest-moving part of this topic is the part both books teach as settled.

---

*Related notes:* [Workspaces](../../../topics/workspaces.md) · [Meta-arguments and `lifecycle`](../../../topics/meta-arguments-lifecycle.md) · TID Ch6 [[06-state-management]] · TUR Ch2 [Getting Started](02-getting-started.md) and Ch4 [Modules](04-reusable-modules.md) · [[tf-state]], [[tf-state-purpose]], [[tf-state-backends]], [[tf-state-locking]], [[tf-backend-configure]] for the HCDocs treatment · [[tf-remote-state-data]] for the case against the last section's data source · [[ot-early-eval-backend]] for the OpenTofu divergence. Feeds learning-path **B9** (state fundamentals), **I6** (remote state & backends), **I7** (state operations) and **A7** (environment isolation).
