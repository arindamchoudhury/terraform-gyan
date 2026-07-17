# A Guide to Terraform Secrets Management

> **Source:** [infisical.com/blog/terraform-secrets-management](https://infisical.com/blog/terraform-secrets-management)
> **Added:** 2026-07-17
> **Source updated:** 2026-07-10 (published; 25 min read)
> **Tags:** secrets, state, ephemeral, write-only, sensitive, oidc, dynamic-secrets, rotation, sops, vault, infisical
> **Type:** blog

An end-to-end secrets story for A6, written by an Infisical content marketer. The **Terraform mechanics restate [[tf-manage-sensitive-data]]** and add nothing new to the reference — but this post does three things the HashiCorp docs don't: it **demonstrates the state leak with an actual `grep`**, it covers the **workflow around** Terraform (secrets manager, CI OIDC, modules, dynamic secrets, rotation), and it names the **anti-patterns**. The vendor framing is real; read the product sections as claims.

!!! warning "Vendor post"
    Infisical sells the platform this post recommends. Every code example routes through the `infisical` provider. The Terraform-side facts check out against HashiCorp's docs; the **comparison table, tier claims (Enterprise/Pro), and the "Vault is operationally heavy" line are marketing positions**, recorded below as such.

## What is the problem with Terraform secrets?

The framing that makes this post worth keeping: **the leak is a side effect of Terraform working correctly.** State is plaintext JSON, every attribute of every resource goes into it, and Terraform needs it that way — state is how it computes the next diff.

The post proves it with a config that touches no cloud and no real secret:

```hcl
terraform {
  required_version = ">= 1.10"
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

resource "random_password" "db" {
  length  = 20
  special = true
}

output "db_password" {
  value     = random_password.db.result
  sensitive = true
}
```

The apply is impeccably redacted:

```console
$ terraform apply -auto-approve
random_password.db: Creating...
random_password.db: Creation complete after 0s [id=none]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

db_password = <sensitive>
```

Then the grep:

```console
$ grep -n '"result":' terraform.tfstate
35:            "result": "YBG$nq2(UQjIBVSyekYB",

$ grep -n -A1 '"db_password"' terraform.tfstate
7:    "db_password": {
8-      "value": "YBG$nq2(UQjIBVSyekYB",
```

Stored **three times** in one run: the resource attribute, the output, and a bcrypt hash of the same password. This is the concrete version of the warning in [[tf-manage-sensitive-data]] — `sensitive = true` controlled how the value was **displayed** and did nothing about how it was **stored**.

### How do secrets end up in state files?

Four routes:

- **Values you pass in** — a `password` argument on a resource, or a provider `access_key`.
- **Values Terraform generates** — `random_password` is the clearest case.
- **Values you read** — data sources record what they read so future plans are stable. If it's a secret, it's in state.
- **Outputs** — stored in state too, so an output derived from a secret is itself a secret at rest.

`sensitive = true` is not on that list, because it doesn't change any of it.

The post then splits the problem in a way the docs don't state so plainly: there are **two kinds of secret** Terraform touches — the ones it **manages** (DB passwords, API keys it sets on your infra) and the ones it **uses** (the credentials that let Terraform call your cloud and your secrets manager). Both need keeping out of state, and they need different fixes.

## Pulling secrets in at plan/apply time

The pattern to kill:

```hcl
locals {
  db_user     = "app_user"
  db_password = "correct-horse-battery-staple"   # in every clone, and in Git history
}
```

The fix is to move the value into a secrets manager and fetch it at run time. Infisical stores secrets as key-value pairs organized by **project → environment (dev/staging/prod) → folder path**; every reader, human or machine, authenticates with its own identity.

```hcl
terraform {
  required_providers {
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.16"
    }
  }
}

provider "infisical" {
  # host defaults to https://app.infisical.com; set it for self-hosted.
  auth = {
    universal = {
      # Both variables default to null, in which case the provider falls back
      # to the INFISICAL_UNIVERSAL_AUTH_* environment variables.
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    }
  }
}

data "infisical_secrets" "backend" {
  env_slug     = "dev"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/database"
}

locals {
  db_user     = data.infisical_secrets.backend.secrets["DB_USER"].value
  db_password = data.infisical_secrets.backend.secrets["DB_PASSWORD"].value
}

# An output derived from a secret must itself be sensitive, or the apply errors.
output "db_user" {
  value     = local.db_user
  sensitive = true
}
```

```console
$ terraform apply -auto-approve -var infisical_workspace_id=<project-id>
data.infisical_secrets.backend: Reading...
data.infisical_secrets.backend: Read complete after 0s

Changes to Outputs:
  + db_user = (sensitive value)

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

db_user = <sensitive>
```

`Reading...` / `Read complete` is the mid-run API call. `0 added, 0 changed, 0 destroyed` because a data source only reads.

**What the data source buys, and what it doesn't:**

| | Hardcoded | Data source |
|---|---|---|
| Where the secret lives | Your repository | The secrets manager, behind access control, an audit log, and rotation |
| What's in Git | The value itself | Coordinates only: project, environment, folder path, key name |
| How rotation works | Edit code, commit, redeploy | Rotate in the manager, then the next plan picks it up |
| **What's in state** | The value | **Still the value** |

That last row is the catch, and it's the whole reason the next section exists. This run left ~2 KB of state holding both passwords in plaintext — exactly like the `random_password` example. **Secrets-in-code is solved; secrets-in-state is not.**

## Keeping secrets out of state with ephemeral resources

Mechanics per [[tf-manage-sensitive-data]] (Terraform 1.10, `ephemeral` block). What this post adds is the **observable lifecycle difference** and the empty-state proof.

```hcl
ephemeral "infisical_secret" "db_creds" {
  name         = "DB_CREDENTIALS"
  env_slug     = "dev"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/"
}

locals {
  credentials = jsondecode(ephemeral.infisical_secret.db_creds.value)
}

provider "postgresql" {
  host     = local.credentials["host"]
  username = local.credentials["username"]
  password = local.credentials["password"]
}
```

Two changes from the data-source config: the block type is `ephemeral` where `data` was, and the type is the **singular** `infisical_secret` (one named secret) instead of the plural `infisical_secrets` (a folder). `jsondecode` unpacks the JSON value.

```console
$ terraform apply -var infisical_workspace_id=<project-id>
ephemeral.infisical_secret.db_creds: Opening...
ephemeral.infisical_secret.db_creds: Opening complete after 0s
ephemeral.infisical_secret.db_creds: Closing...
ephemeral.infisical_secret.db_creds: Closing complete after 0s

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

**`Opening...` / `Closing...` is the tell.** The data-source run said `Reading...` and kept what it read. This fetch has an end.

```console
$ grep -i password terraform.tfstate
$ grep -iE 'credential|db_creds' terraform.tfstate
$
```

Nothing. The whole state file is 181 bytes:

```json
{
  "version": 4,
  "terraform_version": "1.10.5",
  "serial": 1,
  "lineage": "565cc4d1-3241-d9aa-0f87-c89437862f48",
  "outputs": {},
  "resources": [],
  "check_results": null
}
```

Real credentials were fetched, decoded, and used to configure a provider. State has no record it happened. The data-source version of the same work left 2 KB with both values.

The constraint on ephemeral values (they flow only into other ephemeral contexts — provider config, other ephemeral resources, write-only arguments) **is the guarantee, not a limitation**: it's what lets Terraform promise the value never lands somewhere persistent. Route one into a normal resource attribute or a regular output and Terraform stops you.

Write-only arguments close the "values Terraform generates" route:

```hcl
ephemeral "random_password" "db" {
  length = 24
}

resource "aws_db_instance" "app" {
  # ...
  password_wo         = ephemeral.random_password.db.result
  password_wo_version = 1
}
```

**Rule of thumb from the post:** if a value only needs to exist for the duration of the run — to configure a provider, or to authenticate — make it ephemeral. Reach for the data source only when you genuinely need the value **materialized**, and encrypt state when you do.

## Marking variables and outputs as sensitive

Restates [[tf-manage-sensitive-data]] and [[tut-outputs]]: `sensitive` does exactly one thing — redact from display. Two limits, phrased usefully:

- **It doesn't resist a request.** `terraform output db_password` prints the value on demand.
- **It doesn't touch storage.** The grep found it in `terraform.tfstate` in plaintext.

Sometimes it isn't optional: an output derived from a sensitive value **won't apply** unless the output is also marked sensitive.

> "Treat it as display hygiene that you always turn on, layered on top of the real protections, never as a substitute for them."

## Handling provider credentials safely

This is the second kind of secret, and the post argues it's the highest-value one: whoever holds the provider credentials can usually reach everything the other secrets protect.

Environment variables are fine on a laptop:

```shell
export INFISICAL_UNIVERSAL_AUTH_CLIENT_ID=...
export INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET=...
```

In CI they become the problem again — the client secret has to be stored somewhere for the job to read, and a secret stored in your CI platform is one more standing credential. **The fix is to not have one.** GitHub Actions mints a short-lived OIDC token per job; a machine identity configured for OIDC auth accepts it as proof of who's asking.

```yaml
name: terraform-plan

on:
  pull_request:

permissions:
  id-token: write   # required for OIDC
  contents: read

jobs:
  plan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Fetch secrets from Infisical
        uses: Infisical/secrets-action@v1.0.9
        with:
          method: "oidc"
          identity-id: "your-machine-identity-id"  # public identifier, safe to commit
          project-slug: "your-project-slug"
          env-slug: "prod"

      - run: terraform init
      - run: terraform plan
```

The sequence:

1. The job starts; GitHub mints it a short-lived OIDC token, authorized by `id-token: write`.
2. The action presents that token to the secrets manager.
3. The manager checks the token's claims against the identity's binding — a subject like `repo:your-org/your-repo:ref:refs/heads/main`, so **only that repository and branch** can authenticate.
4. It hands back short-lived access; allowed secrets are injected as env vars that disappear when the job ends.

No stored secret on either side. The `identity-id` is a public identifier and safe to commit — knowing it grants nothing without a token matching the binding.

**The Terraform tie-in is the `TF_VAR_` convention.** Store a secret as `TF_VAR_db_admin_password` and the plan step reads it as `var.db_admin_password`, with nothing passed on the command line. (Precedence rules in [[tf-input-variables]].)

Cloud credentials get the same treatment: the job's OIDC token can be exchanged for a scoped AWS role via `aws-actions/configure-aws-credentials`, so there's no long-lived cloud key in GitHub either.

> "The credential should reach Terraform from the environment it runs in, never from the code it runs."

## Hardening the state backend

The honest concession, and worth quoting because it bounds the ephemeral advice: **"Ephemeral resources don't cover every case yet."** Some values land in state even when you're doing it right — a data-source read you chose because the value must persist, or a resource that returns a credential on creation (an IAM access key, say).

Four properties matter for the bucket holding state: **encrypted, versioned, locked, and readable only by the identities that run Terraform.**

```hcl
terraform {
  backend "s3" {
    bucket       = "org-terraform-state"
    key          = "network/prod.tfstate"
    region       = "us-east-1"
    use_lockfile = true   # locking: two applies can't run at once
    encrypt      = true   # encrypted at rest
    kms_key_id   = "arn:aws:kms:us-east-1:123456789012:key/abcd-1234"  # with your key, not the S3 default
  }
}
```

The block handles encryption and locking. The other two live on the bucket: enable **S3 Versioning** so an overwritten or corrupted state can be recovered, and scope the bucket IAM to the run identities only.

Other clouds: **GCS** uses a Cloud KMS key via `kms_encryption_key` with Object Versioning on the bucket; **Azure Blob** authenticates with Entra ID via `use_oidc`.

!!! danger "Backend config leaks harder than provider config"
    The provider-credentials rule applies to the backend **with greater force**: backend configuration is copied into `.terraform/` **and captured in plan files**. Backend credentials come from the environment or the CI flow above — never inline, and **never as `-backend-config` values**.

With a hardened backend, the data-source trade reads differently: the values still land in state, but state is ciphertext in a locked, versioned bucket only your run identities can open.

## Managing secrets inside reusable modules

The angle here is new relative to anything in the notes so far. A module that needs a credential has to get it from somewhere, and the obvious route multiplies the problem:

```hcl
module "service" {
  source      = "./modules/service"
  db_password = var.db_password  # every caller has to hold and pass the raw value
}
```

Every configuration using the module must obtain the password and pass it in, **and the value is recorded in that configuration's state** once the module uses it. One secret ends up copied into every stack that calls the module.

The fix — **pass coordinates, not values**:

```hcl
module "service" {
  source       = "./modules/service"
  workspace_id = var.infisical_workspace_id
  env_slug     = "prod"
  secret_path  = "/services/api"
}
```

Inside the module, the same data source (or an `ephemeral` block, for no state at all) reads the secret at that path. Callers hand over a **location**. Access is then controlled in the secrets manager rather than by who holds the variable.

## Beyond static secrets: dynamic secrets and rotation

Everything above protects a **static** secret — one value valid until someone changes it. Protecting it well still leaves it worth stealing for as long as it lives. Two ways to shrink that window: **dynamic secrets** (created on demand, expire automatically) and **rotation** (a standing credential replaced on a schedule).

### Dynamic secrets

> ❓ Vendor claim: "Dynamic secrets are an Enterprise feature."

One dynamic-secret resource per backend (`infisical_dynamic_secret_sql_database` for SQL, with variants for AWS IAM, Kubernetes, and MongoDB). For the platform to create and drop database users on demand, it must log into the database itself with an account that can manage users — the data source supplies that login, so no password appears in the file:

```hcl
data "infisical_secrets" "db" {
  env_slug     = "dev"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/"
}

locals {
  creds = jsondecode(data.infisical_secrets.db.secrets["DB_CREDENTIALS"].value)
  # Role-management DDL needs the direct endpoint, not a connection pooler.
  db_host = replace(local.creds.host, "-pooler", "")
}

resource "infisical_dynamic_secret_sql_database" "db" {
  name             = "postgres-dynamic"
  project_slug     = var.infisical_project_slug   # slug, not ID
  environment_slug = "dev"
  path             = "/"
  default_ttl      = "1h"
  max_ttl          = "4h"

  configuration = {
    client   = "postgres"
    host     = local.db_host
    port     = "5432"
    database = local.creds.database
    username = local.creds.username   # privileged account that creates users
    password = local.creds.password

    creation_statement = <<-EOT
      CREATE USER "{{username}}" WITH ENCRYPTED PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
      GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "{{username}}";
    EOT

    revocation_statement = <<-EOT
      REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM "{{username}}";
      DROP ROLE "{{username}}";
    EOT
  }
}
```

**The apply stores instructions, not a credential.** Getting one is a separate, out-of-band step: find the dynamic secret in the dashboard, click Generate, set a TTL up to `max_ttl`. The platform connects, runs `creation_statement`, and returns a username/password with an expiry; when the lease expires or is deleted, `revocation_statement` runs and the user is gone. Verifiable on the database side — a row appears in `pg_roles` per lease and vanishes at expiry.

Note the two footguns the post buries in comments: `project_slug` here takes a **slug**, and role-management DDL needs the **direct endpoint, not a connection pooler** (hence the `replace(..., "-pooler", "")`).

### Secret rotation

> ❓ Vendor claim: "Rotation is included in the Pro tier."

For systems that can't work with short-lived users and require a single standing login. **The mechanism is two database users, not one.** One is live at any moment; at rotation time the platform sets a new password on the **idle** user and switches the live secrets over to it. Nothing breaks during the swap because the previous login stays valid while consumers migrate.

Two things must exist before the apply:

- **The two database users** — create them with throwaway passwords; they get replaced the moment rotation starts.
- **An App Connection** — the platform's stored access to your database, saved once under organization settings and passed in as `connection_id`.

```hcl
resource "infisical_secret_rotation_postgres_credentials" "db" {
  name          = "postgres-rotation"
  project_id    = var.infisical_project_id   # ID, not slug
  environment   = "dev"
  secret_path   = "/database"
  connection_id = var.postgres_connection_id # the App Connection, which must exist first

  parameters = {
    username1 = "infisical_user_1"   # rotation alternates between these two roles
    username2 = "infisical_user_2"
  }

  secrets_mapping = {
    username = "POSTGRES_DB_USERNAME"  # consumers always read these keys
    password = "POSTGRES_DB_PASSWORD"
  }

  auto_rotation_enabled = true
  rotation_interval     = 30  # days
}
```

Note the inconsistency the post flags in a comment: this resource takes `project_id` (**ID**), while the dynamic-secret resource takes `project_slug` (**slug**).

```console
$ terraform apply -auto-approve \
    -var infisical_project_id=<project-id> \
    -var postgres_connection_id=<app-connection-id>

Plan: 1 to add, 0 to change, 0 to destroy.
infisical_secret_rotation_postgres_credentials.db: Creating...
infisical_secret_rotation_postgres_credentials.db: Creation complete after 1s [id=e19d74b0-0be6-432f-bf7d-65b91a571467]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

**Rotation fires immediately on creation.** The mapped secret names appear alongside the existing ones:

```
DB_PASSWORD
DB_USER
POSTGRES_DB_PASSWORD    <- new, written by rotation
POSTGRES_DB_USERNAME    <- new, written by rotation
```

The post verified it by reading the new secrets back and logging in: it worked as `infisical_user_1` with a 48-character generated password, the throwaway already replaced. **Applications never see the swap** — they read the mapped key names, get whichever login is live, and nothing redeploys when the password changes.

## Anti-patterns worth catching in review

The most reusable table in the post — a review checklist:

| Anti-pattern | Why it fails | Better pattern |
|---|---|---|
| `sensitive = true` as the only control | Redacts display, but the value still lands in state and plans | Ephemeral resources, or retrieval outside Terraform |
| Reading secret values through data sources | The payload is written into state | Ephemeral resources, or a hardened backend when you can't avoid reading values |
| Static, long-lived CI credentials | Standing blast radius and painful rotation | OIDC and short-lived identity |
| Unencrypted, unversioned, or unlocked state | Plaintext at rest, weak recovery, race conditions | KMS encryption, versioning, locking, least-privilege access |

## Choosing a Terraform secrets manager

Vendor-authored — this is the sales section. The evaluation **criteria** are reusable even if the verdicts aren't:

- An **official provider on the registry**, so the secrets platform itself is managed as code.
- **Ephemeral reads**, so fetching at plan time doesn't write to state.
- **Dynamic secrets and rotation**, so fewer standing credentials exist at all.
- **Hosting and license terms**, if self-hosting or open source is a constraint.

One framing worth keeping: **cloud KMS sits underneath everything but isn't a secrets manager.** It encrypts state and the stores themselves; key management alone gives you no access control, audit trail, or per-secret rotation.

> ❓ Vendor comparison — recorded as claimed, not verified:

| Option | What it is | With Terraform | Vendor's "worth knowing" |
|---|---|---|---|
| **Infisical** | Open-source secrets platform, cloud or self-hosted | Official provider; ephemeral reads, dynamic secrets, rotation, syncs as code | "Covers static storage, dynamic credentials, rotation, and outward syncs in one platform" |
| **HashiCorp Vault** | The long-standing enterprise incumbent, self-managed or HCP | Official provider with ephemeral resources | "Operationally heavy to run yourself. BUSL-licensed since 2023 and now part of IBM" |
| **Cloud secret managers** | AWS Secrets Manager, Azure Key Vault, Google Secret Manager | First-party providers with data sources and ephemeral resources | "Single-cloud by design; covering three clouds means running three of them" |
| **SOPS** | File encryption, not a service | Community provider decrypts committed files at plan time | "No access control, audit log, or rotation of its own" |

The post concedes the capability overlap: Infisical and Vault both issue dynamic secrets and both rotate credentials. Its own summary of the real differences — **hosting, license, and how much operating you want to do**.

### Where SOPS fits

Useful because it declines to dismiss the tool. **SOPS isn't a secrets manager, it's file encryption.** You encrypt the values inside a YAML/JSON file with an age, PGP, or cloud KMS key and commit the ciphertext. Keys stay readable and values don't, so the file lives in Git and **diffs still show what changed** — that's the property nothing else on the list has.

The post's position: SOPS is a complement, not a replacement. If your GitOps flow needs the encrypted file itself in version control, use SOPS for that file, harden the backend holding your state, and keep runtime credentials in a system that can rotate them.

## The default to change

The post's own summary, and a fair A6 checklist:

- Keep real values in a secrets manager, not in `.tf` files or `.tfvars`.
- Prefer **ephemeral resources** for anything that only needs to exist during a run — they never touch state.
- Use the **data source** when you must materialize a value, and encrypt your backend when you do.
- Treat `sensitive = true` as **display hygiene: always on, never load-bearing.**
- Keep provider credentials in the **environment**, and prefer short-lived **OIDC** in CI.
- **Encrypt, version, and lock** the backend that holds your state.
- Pass secret **references** into modules, not secret values.
- Where you can, drop standing secrets entirely with **dynamic secrets**, and rotate the ones you can't.

> "Your state file goes back to being what it should be: a record of what you built, not a list of your credentials."

---
Related: restates and demonstrates [[tf-manage-sensitive-data]] — same hide-vs-omit mechanics, but with a `grep` proving the leak and an empty 181-byte state proving the ephemeral fix. Extends [[tf-remote-state-data]]'s state-exfiltration warning to the "harden the bucket" side. The `TF_VAR_` CI convention connects to [[tf-input-variables]]'s precedence table; the redaction limits confirm [[tut-outputs]]. Feeds learning-path **A6** (secrets manager workflow, CI OIDC, module coordinate-passing, dynamic secrets/rotation, the anti-pattern table) and **I6** (backend hardening: `use_lockfile`/`encrypt`/`kms_key_id` + versioning + IAM scoping).
