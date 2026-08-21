# Chapter 6 — Managing Secrets with Terraform

> *Source: Brikman (2022), **Terraform: Up & Running**, 3rd ed., Chapter 6, pages 191–220.*
>
> Thirty pages built around one question the book has been dodging since Chapter 2: what goes in `username` and `password` on `aws_db_instance`? The answer comes in three layers — secret management as a field, the tools that implement it, and the three places Terraform code touches secrets. It ends by admitting that none of the three techniques it just taught keeps the secret out of the state file.
>
> 📌 **Notes adapted where version-bound.** Book written 2022 against Terraform ~1.2; current stable is **1.15.8** / OpenTofu **1.12.5** ([[version-facts]]). **The concepts are intact; the closing admission is not.** Terraform 1.10/1.11 and OpenTofu 1.11 shipped ephemeral values and write-only arguments, and the state-file issue the chapter calls open "with no clear plans for a first-class solution" was closed as completed on **2025-05-21**. Everything else that moved is AWS-side or CI-side and is collected under [Version reckoning](#version-reckoning).

> 🔗 **See also:** [Secrets and state](../../../topics/secrets-and-state.md), which synthesizes this chapter with TID Ch8 §8.5 and the HashiCorp reference pages.

---

## The framing

The chapter opens with the `aws_db_instance` block from Chapter 3 and two `"???"` placeholders where the master credentials go. Every technique in the chapter is an answer to those two lines.

Two rules, one of them shouted:

> Do not store secrets in plain text.

Four reasons, and the useful thing is that none of them is "someone might read your repo":

- Everyone with version-control access has the secret.
- Every machine that ever cloned the repo has a copy on disk. That includes CI, the VCS host, every pre-prod and prod environment, and every backup system.
- Every piece of software on any of those machines can potentially read it.
- There is no audit log and no revocation path. You cannot tell who read it, and you cannot easily make the copies stop working.

> 💭 (mine): the fourth point is the one that survives the "our repo is private" objection. Privacy is a control on *who can clone*; it is not a control on *what happens after they do*.

## 1. Secret management tools

Three axes, which together explain why "just use a password manager" is bad advice for infrastructure.

### The types of secrets you store

| Type | Belongs to | Examples |
| --- | --- | --- |
| **Personal** | an individual | website logins, SSH keys, PGP keys |
| **Customer** | your customers | their logins, PII, PHI |
| **Infrastructure** | your infrastructure | DB passwords, API keys, TLS certificates |

Most tools are built for exactly one of the three, and forcing the others in is a security problem rather than an inconvenience. The chapter's example is the sharpest statement of it anywhere in these notes:

- **Infrastructure** passwords are **encrypted** (AES, perhaps with a nonce) because you have to get the original value back to hand it to a database.
- **Customer** passwords are **hashed** (bcrypt, with a salt) because there must be *no* way to get the original value back.

Same word, opposite requirements. If your customer-password store can decrypt, it is built wrong.

### The way you store secrets

Two strategies.

**File-based stores** encrypt secrets into files that get checked into version control. That needs an encryption key, and the key is itself a secret, which is the conundrum the whole approach turns on: you cannot commit the key, and encrypting it with a second key only moves the problem. The two real exits:

- **A cloud KMS** (AWS KMS, GCP KMS, Azure Key Vault) — trust the cloud provider to hold the key and control access to it.
- **PGP keys** — encrypt to one or more developers' public keys, so only holders of the matching private keys can decrypt. Those private keys are protected by a passphrase, which lives in a personal secrets manager or a human's memory.

**Centralized stores** are web services that encrypt secrets and keep them in a data store (MySQL, PostgreSQL, DynamoDB). The encryption key is managed by the service, or by a cloud KMS underneath it.

### The interface you use

- **API** — every centralized store has one. This is what lets an app fetch a DB password at boot, and what Terraform data sources use under the hood.
- **CLI** — every file-based store works this way; most centralized ones offer a CLI too. Good for humans and for scripts.
- **UI** — web, desktop, or mobile, on some centralized stores.

### Table 6-1, reconstructed

The book's comparison table, restated. The rest of the chapter narrows to **infrastructure** secrets reached by **API or CLI**.

| Tool | Type | Storage | Interface |
| --- | --- | --- | --- |
| HashiCorp Vault | Infrastructure * | Centralized service | UI, API, CLI |
| AWS Secrets Manager | Infrastructure | Centralized service | UI, API, CLI |
| Google Secret Manager | Infrastructure | Centralized service | UI, API, CLI |
| Azure Key Vault | Infrastructure | Centralized service | UI, API, CLI |
| Confidant | Infrastructure | Centralized service | UI, API, CLI |
| Keywhiz | Infrastructure | Centralized service | API, CLI |
| sops | Infrastructure | Files | CLI |
| git-secret | Infrastructure | Files | CLI |
| 1Password | Personal | Centralized service | UI, API, CLI |
| LastPass | Personal | Centralized service | UI, API, CLI |
| Bitwarden | Personal | Centralized service | UI, API, CLI |
| KeePass | Personal | Files | UI, CLI |
| Keychain (macOS) | Personal | Files | UI, CLI |
| Credential Manager (Windows) | Personal | Files | UI, CLI |
| pass | Personal | Files | CLI |
| Active Directory, Auth0, Okta, OneLogin, Ping, AWS Cognito | Customer | Centralized service | UI, API, CLI |

\* Vault supports many secret engines; most target infrastructure secrets, a few handle customer secrets.

!!! info "Two rows have changed hands since 2022"
    - **HashiCorp Vault** was relicensed alongside Terraform, and GitHub reports no recognised open-source license on `hashicorp/vault`. The fork is **OpenBao** — MPL-2.0, repository created **2023-11-09**, now under LF Projects and an OpenSSF sandbox project, at **v2.6.2** (2026-08-18). If the reason Vault is on your shortlist is "open source", that reason now points at OpenBao.
    - **sops** left Mozilla for the **CNCF**, accepted at Sandbox level on **2023-05-17**, and lives at `getsops/sops` (**v3.13.3**, 2026-07-23). It also gained backends: the README now lists AWS KMS, GCP KMS, Azure Key Vault, HuaweiCloud KMS, **age**, and PGP. `age` is the one worth knowing, because it removes the GPG toolchain from the PGP path.

## 2. Providers — passing secrets to Terraform itself

The first place Terraform meets a secret is authenticating to a provider. The anti-pattern the chapter calls out is inline credentials:

```hcl
provider "aws" {
  region = "us-east-2"

  # DO NOT DO THIS!!!
  access_key = "(ACCESS_KEY)"
  secret_key = "(SECRET_KEY)"
}
```

It is insecure, and separately it is *impractical*: one hardcoded credential pair cannot serve different developers, a CI server, and three environments.

The split that organizes the section is **who is running Terraform**.

### Human users

Environment variables are the common answer, and every provider supports some form of them:

```bash
export AWS_ACCESS_KEY_ID=(YOUR_ACCESS_KEY_ID)
export AWS_SECRET_ACCESS_KEY=(YOUR_SECRET_ACCESS_KEY)
```

Three properties this buys: no plaintext in the code, everyone supplies their own credentials, and the values stay in memory rather than on disk.

> 💡 **Tip** — the leading space on those commands is deliberate: most shells skip history for a command that starts with a space, though bash needs `HISTCONTROL=ignoreboth` for that to be active.

That still leaves "where does the access key live between sessions?" The chapter's answer is a **personal** secrets manager, and it prefers ones with a CLI so the value never gets copy-pasted:

```bash
# 1Password CLI, as the book shows it — v1 syntax, see Version reckoning
eval $(op signin my)
export AWS_ACCESS_KEY_ID=$(op get item 'aws-dev' --fields 'id')
export AWS_SECRET_ACCESS_KEY=$(op get item 'aws-dev' --fields 'secret')
```

For AWS specifically it recommends **aws-vault**, which stores credentials in the OS keychain and hands your command *temporary* STS credentials:

```bash
aws-vault add dev
aws-vault exec dev -- terraform apply
```

The point is not convenience. `exec` means the process you launch never sees the permanent key, only a short-lived one, so the blast radius of a leak is bounded by the session. aws-vault also handles assuming roles, MFA, and console logins.

### Machine users

No human, no memorized password. The question becomes how one machine proves its identity to another with nothing stored in plaintext. Three worked answers, in increasing order of how much you should like them.

#### CircleCI with stored credentials

Create a dedicated IAM user for automation, put its access keys in a **CircleCI Context**, and reference the context from the workflow. CircleCI exposes them as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, and Terraform picks them up with no code change.

```yaml
workflows:
  deploy:
    jobs:
      - terraform_apply
    filters:
      branches:
        only:
          - main
    context:
      - example-context
```

Two drawbacks, and they are the same drawback twice: you manage the credentials by hand, so they are **permanent** and rarely rotate.

#### EC2 instance with an IAM role

If Terraform runs *inside* AWS (Jenkins on EC2), attach an IAM role. A role is an IAM entity with permissions but no permanent credentials, assumed by whoever is allowed to assume it.

Four resources, in dependency order:

```hcl
# 1. Who may assume the role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# 2. The role itself
resource "aws_iam_role" "instance" {
  name_prefix        = var.name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# 3. What the role may do — roles start with no permissions at all
resource "aws_iam_role_policy" "example" {
  role   = aws_iam_role.instance.id
  policy = data.aws_iam_policy_document.ec2_admin_permissions.json
}

# 4. The instance profile that lets EC2 hand the role to the instance
resource "aws_iam_instance_profile" "instance" {
  role = aws_iam_role.instance.name
}
```

Then `iam_instance_profile = aws_iam_instance_profile.instance.name` on the `aws_instance`.

The mechanism underneath is the **instance metadata endpoint** at `http://169.254.169.254`, reachable only from the instance itself. If a role is attached, its temporary credentials appear there, and anything built on the AWS SDK — Terraform included — finds them automatically.

!!! warning "The footnote is the most operationally useful paragraph in the chapter"
    By default the metadata endpoint is open to **every OS user on the instance**. Brikman's advice is to firewall it with `iptables`/`nftables` so only the app's own user can reach it, so code execution as some other user does not hand over the role. Better still, if the role is only needed at boot (to read a database password), **turn the endpoint off after boot** so a later intruder cannot use it at all.

Two advantages over stored credentials: nothing manual to manage, and the credentials are temporary and rotated automatically.

#### GitHub Actions with OIDC

The 2021 arrival that lets an *external* CI system get both of those advantages. Establish a trust link between the CI platform and the cloud, and no credential is ever stored.

```hcl
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}
```

The role's trust policy is where the work happens. It uses `sts:AssumeRoleWithWebIdentity`, a `Federated` principal pointing at the OIDC provider, and a **condition** that pins which repositories and branches may assume it:

```hcl
condition {
  test     = "StringEquals"
  variable = "token.actions.githubusercontent.com:sub"
  values = [
    for a in var.allowed_repos_branches :
    "repo:${a["org"]}/${a["repo"]}:ref:refs/heads/${a["branch"]}"
  ]
}
```

!!! danger "Without the condition block, every GitHub Actions user can assume your role"
    Registering the IdP trusts the whole issuer, not your repo. The chapter states this plainly, and TID Ch8 §8.5.1 makes it the section's central point: registering an IdP is *authentication*, and the trust-policy conditions are the *authorization*. The role ARN is not a secret and does not need to be. See [Ch8 notes](../../tid/chapters/08-cd-deployment.md).

The workflow side is two additions: `permissions: id-token: write` at the top, and an `aws-actions/configure-aws-credentials` step naming the role before Terraform runs.

## 3. Resources and data sources — passing secrets to your infrastructure

Back to `aws_db_instance`. Three techniques, each with the book's own advantage and drawback lists.

### Environment variables

Declare the variables with no default and `sensitive = true`, pass them to the resource, and set them through `TF_VAR_`:

```hcl
variable "db_password" {
  description = "The password for the database"
  type        = string
  sensitive   = true
}
```

```bash
export TF_VAR_db_username=(DB_USERNAME)
export TF_VAR_db_password=(DB_PASSWORD)
```

**For:** no plaintext in code; works with *any* secrets solution your company already has; easy to read back in any language; easy to mock in tests; free.

**Against:** the configuration is no longer self-contained, so every user needs out-of-band knowledge or a wrapper script; nothing in the code enforces good practice, so someone will still keep the value somewhere careless; and because secrets are not versioned with the code, it is easy to add one in staging and forget production.

### Encrypted files

Encrypt the secrets into a file, commit the ciphertext, decrypt at plan time. With AWS KMS that means creating a **customer managed key** with a key policy, giving it a human-readable alias, and encrypting through the CLI.

```hcl
data "aws_caller_identity" "self" {}

data "aws_iam_policy_document" "cmk_admin_policy" {
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions   = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.self.arn]
    }
  }
}

resource "aws_kms_key" "cmk" {
  policy = data.aws_iam_policy_document.cmk_admin_policy.json
}

resource "aws_kms_alias" "cmk" {
  name          = "alias/kms-cmk-example"
  target_key_id = aws_kms_key.cmk.id
}
```

The alias matters more than it looks. A CMK is otherwise identified only by a GUID, and `alias/kms-cmk-example` is what you type in every subsequent CLI call.

Encryption is a shell script around `aws kms encrypt` writing the ciphertext blob to `db-creds.yml.encrypted`. The plaintext `db-creds.yml` is then deleted and only the ciphertext is committed. Terraform reads it back with a data source and parses it:

```hcl
data "aws_kms_secrets" "creds" {
  secret {
    name    = "db"
    payload = file("${path.module}/db-creds.yml.encrypted")
  }
}

locals {
  db_creds = yamldecode(data.aws_kms_secrets.creds.plaintext["db"])
}
```

Then `username = local.db_creds.username` and `password = local.db_creds.password`.

The honest paragraph: **working with encrypted files is awkward.** Every edit is decrypt, edit, re-encrypt, and stay alert the whole time so no plaintext gets committed or left behind. **sops** exists to make that transparent, since `sops <FILE>` decrypts into your editor and re-encrypts on exit.

> 📌 **Version note** — Terraform still has no native sops support. The routes are the third-party provider `carlpett/sops` or, for Terragrunt users, the built-in `sops_decrypt_file` function.

**For:** no plaintext in code; secrets are versioned, packaged and tested *with* the code, which is exactly the drift the environment-variable approach suffers from; retrieval is native; works with KMS, GCP KMS or PGP; everything is in the code.

**Against:** storing is fiddly and has a learning curve; test integration needs keys and encrypted fixtures; **rotation and revocation are hard**, because the ciphertext is in Git forever and a compromised key retroactively opens every version of it; auditing tells you the key was used but not what it decrypted; KMS costs about $1–$10/month for typical use; and different teams will do it differently.

### Secret stores

Store the credentials in AWS Secrets Manager (as JSON, the recommended format), then read them back:

```hcl
data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "db-creds"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.creds.secret_string)
}
```

**For:** no plaintext in code; everything in the code with no wrapper scripts; storing is a web UI away; **rotation and revocation are first-class**, including scheduled rotation; detailed audit logs of who read what; and the tool standardizes practice across teams.

**Against:** secrets are *not* versioned with the code, so the staging-versus-production drift comes back; managed stores cost money (~$10–$25/month typical, hundreds at scale); a self-managed Vault costs both infrastructure and engineer time; retrieval is harder in automated contexts because you first have to solve machine-to-machine auth; and tests now depend on an external system.

!!! note "The two lists are mirror images, and that is the actual lesson"
    Encrypted files win on *versioned with the code* and lose on *rotation and audit*. Secret stores win on *rotation and audit* and lose on *versioned with the code*. No option wins both, so the choice is which failure mode you would rather manage.

    Environment variables sidestep the question by making it someone else's problem, which is why they are simultaneously the most flexible and the least enforceable option.

## 4. State files and plan files

The section that undoes the previous one:

> no matter which technique you use, any secrets you pass into your Terraform resources and data sources will end up in plain text in your Terraform state file!

The chapter treats this as unfixable. It cites an issue open since 2014 with no first-class solution planned, and describes the state-scrubbing workarounds as brittle and not recommended. Its guidance is therefore damage control:

- **Use a backend that encrypts.** S3, GCS and Azure Blob Storage encrypt in transit (TLS) and at rest (AES-256).
- **Control backend access as tightly as you control the secrets themselves.** If prod state lives in S3, the IAM policy should name a handful of trusted people, or only the CI server.

**Plan files have the identical problem**, and it is easier to forget because a plan file feels like output rather than data:

```bash
terraform plan -out=example.plan
terraform apply example.plan
```

Saving the plan is the right practice, because it applies exactly what you reviewed. The saved file also contains every secret in plaintext. Same two rules: encrypt it in transit and at rest, and control who can read it.

!!! danger "This is the chapter's conclusion, and it is the part that has changed"
    Everything above is still true *by default*, and it is why `sensitive = true` is a logging control rather than a security control. But "no first-class solution" is no longer the state of the world — see [Version reckoning](#version-reckoning) item 1. The workaround era ended in 2024–2025.

## Conclusion

Four takeaways, the first of which is the whole chapter: do not store secrets in plain text.

**Table 6-2 — machine users authenticating to a provider**, restated:

| | Stored credentials (CircleCI) | IAM roles (Jenkins on EC2) | OIDC (GitHub Actions) |
| --- | --- | --- | --- |
| Avoids manually managing credentials | ✗ | ✓ | ✓ |
| Avoids permanent credentials | ✗ | ✓ | ✓ |
| Works inside a cloud provider | ✓ | ✓ | ✓ |
| Works outside a cloud provider | ✓ | ✗ | ✓ |
| Widely supported as of 2022 | ✓ | ✓ | ✗ |

The shape of the argument: OIDC dominates on every row except maturity, and maturity was the only reason to choose otherwise. That last row is the one that expired.

**Table 6-3 — passing secrets to resources and data sources**, restated:

| | Environment variables | Encrypted files | Secret stores |
| --- | --- | --- | --- |
| Keeps plaintext out of code | ✓ | ✓ | ✓ |
| All secrets management defined as code | ✗ | ✓ | ✓ |
| Audit log for encryption-key access | ✗ | ✓ | ✓ |
| Audit log for individual secret access | ✗ | ✗ | ✓ |
| Rotating or revoking secrets is easy | ✗ | ✗ | ✓ |
| Standardizing practice is easy | ✗ | ✗ | ✓ |
| Secrets versioned with the code | ✗ | ✓ | ✗ |
| Storing secrets is easy | ✓ | ✗ | ✓ |
| Retrieving secrets is easy | ✓ | ✓ | ✗ |
| Integrating with automated testing is easy | ✓ | ✗ | ✗ |
| Cost | 0 | $ | $$$ |

> ❓ Revisit: both tables are reconstructions. `pdftotext` shifts this book's table columns by one row, so each value line had to be reattached to the label above it and sanity-checked against the prose (Keywhiz has no UI, sops is file-based, OIDC was new in 2021). The `✓`/`✗` glyphs in Tables 6-2 and 6-3 did not survive extraction at all and were rebuilt from the chapter's arguments. Check against printed pages 195, 219 and 220 before quoting them anywhere.

And the fourth takeaway, unchanged in spirit: whatever you do, the secret lands in state and plan files, so encrypt those and restrict access to them.

### State of the running example

Nothing. This is the only chapter after Chapter 2 that does not advance the web-server-cluster example. It uses a standalone `aws_db_instance` plus a few IAM and KMS snippets, and hands back to Chapter 7 unchanged. The Chapter 3 database module is the code it is implicitly fixing.

---

## Version reckoning

The concepts hold. One of the chapter's conclusions is now false, and most of its AWS and CI mechanics have moved.

!!! danger "1. The state-file problem has a first-class solution, and the 2014 issue is closed"
    The chapter's closing admission was accurate when printed and is not now.

    | Mechanism | Terraform | OpenTofu |
    | --- | --- | --- |
    | `sensitive` on variables and outputs | 0.15 | inherited at the fork |
    | Ephemeral values and ephemeral resources | **1.10** (2024-11-26) | **1.11.0** (2025-12-09) |
    | Write-only arguments (`*_wo`) | **1.11** (2025-02-27) | **1.11.0** (2025-12-09) |

    OpenTofu shipped all three parts in one release; Terraform split them across two.

    [hashicorp/terraform#516](https://github.com/hashicorp/terraform/issues/516), "Storing sensitive values in state files" — opened **2014-10-28**, the issue the chapter refers to — was **closed as completed on 2025-05-21**, three weeks after a maintainer pointed at write-only arguments as the answer. Roughly ten and a half years open.

    The AWS provider side, so the chapter's own example can be rewritten:

    - **`ephemeral "aws_kms_secrets"`** and **`ephemeral "aws_secretsmanager_secret_version"`** arrived in provider **5.77.0** (2024-11-21), five days before Terraform 1.10. Both of the chapter's read paths now have a form that never touches state.
    - **`password_wo` / `password_wo_version`** on `aws_db_instance` arrived in provider **5.88.0** (2025-02-20).

    So the modern version of the chapter's headline example is:

    ```hcl
    ephemeral "aws_secretsmanager_secret_version" "creds" {
      secret_id = "db-creds"
    }

    resource "aws_db_instance" "example" {
      # …
      username            = local.db_creds.username
      password_wo         = jsondecode(ephemeral.aws_secretsmanager_secret_version.creds.secret_string)["password"]
      password_wo_version = 1
    }
    ```

    Because the value is never stored, Terraform cannot diff it. That is what `password_wo_version` is for — bump it to force a re-read.

    ⚠️ **The provider docs contradict themselves here.** At tag `v6.54.0`, the `password_wo` argument description still carries the `password` sentence verbatim: *"Note that this may show up in logs, and it will be stored in the state file."* The same page's header note says the opposite, correctly. Trust the header note and the language docs ([[tf-manage-sensitive-data]]), not the argument line.

!!! info "2. Plan-file and state encryption — OpenTofu closed it, Terraform did not"
    OpenTofu **1.7** encrypts state *and plan files* client-side before the backend sees them, with key providers for PBKDF2, AWS KMS, GCP KMS and OpenBao. Terraform's answer is still the chapter's answer: encrypt the bucket, restrict access. Full treatment in [Ch3 notes](03-manage-state.md).

    This makes the chapter's plan-file advice engine-specific. On Terraform it is the only mitigation; on OpenTofu it is the fallback if you have not turned encryption on.

!!! info "3. The OIDC thumbprint dance is dead weight"
    `thumbprint_list` on `aws_iam_openid_connect_provider` is now **Optional**, and the provider documentation names the case directly: for *"Auth0, GitHub, GitLab, Google, or those using an Amazon S3-hosted JWKS endpoint"*, AWS validates against its own trusted-CA library and any configured `thumbprint_list` *"is retained in the configuration but not used for verification."* The IAM guide agrees, describing thumbprints as the fallback for IdPs whose certificates are not signed by a trusted CA.

    So the chapter's `data "tls_certificate" "github"` block and its `sha1_fingerprint` reference can both be deleted. The provider even ships a "Without A Thumbprint" example now.

    One trap worth knowing: if a `thumbprint_list` was configured and is later removed, the provider keeps using the original list rather than asking IAM to re-derive one. The clean state is having never set it. The same staleness is flagged in TID Ch8 §8.5.1, which hit it from the other direction.

!!! warning "4. Every version number in the CI examples is stale, and one whole table row flipped"
    Verified 2026-08-21 against each project's latest release:

    | Book | Current |
    | --- | --- |
    | `actions/checkout@v2` | **v7.0.1** (2026-07-20) |
    | `hashicorp/setup-terraform@v1` | **v4.0.1** (2026-05-12) |
    | `aws-actions/configure-aws-credentials@v1` | **v6.2.3** (2026-07-22) |
    | `terraform_version: 1.1.0` | 1.15.8 |

    More importantly, Table 6-2's last row — *"widely supported as of 2022"*, where OIDC scores ✗ — is the only row that argued against OIDC, and it is no longer true. GitHub Actions OIDC into AWS, Azure and GCP is ordinary practice now, and **HCP Terraform's dynamic provider credentials** generalize it: a workload identity token per run, exchanged for temporary credentials against AWS, GCP, Azure, Kubernetes, Vault or HCP, discarded when the run ends. Vault-backed dynamic credentials chain the two. Read Table 6-2 today as "OIDC unless you cannot."

!!! warning "5. `curl http://169.254.169.254/latest/meta-data/` no longer works"
    The chapter's SSH-and-curl demonstration of the metadata endpoint is IMDSv1. AWS made **IMDSv2 the default for new instance launches** (account-level setting announced 2024-03-25), and **instance types released from mid-2024 are IMDSv2-only**. Where IMDSv2 is required, an IMDSv1 request simply gets no response, and a token-less `GET` returns **401**.

    The two-step form:

    ```bash
    TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"` \
      && curl -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/
    ```

    None of this changes the *Terraform* content. The AWS SDK speaks IMDSv2 by default, so the instance-profile mechanism the section teaches works untouched — it is the demonstration that broke, not the technique. The footnote's lockdown advice is now partly a checkbox: `metadata_options { http_tokens = "required" }` on `aws_instance`, and a hop limit of 1 keeps containers off the endpoint.

!!! note "6. Tooling the chapter recommends by name"
    - **aws-vault** — `99designs/aws-vault` is **abandoned**, and its README points at the active fork **`ByteNess/aws-vault`** (v7.13.5, 2026-08-17). The commands in the chapter are unchanged in the fork.
    - **1Password CLI** — the chapter's `op` calls are v1 syntax. Current form: `op signin` without the account shorthand, `op item get <item> --fields label=<field>`, and the secret-reference URI `op read "op://vault/item/field"` for exactly the export-into-an-env-var use the chapter describes.
    - **sops provider** — `carlpett/terraform-provider-sops` reached **v1.3.0** (2025-10-07) with an **ephemeral resource**, and **v1.4.1** (2026-03-19) is current. That matters more than a version bump: the encrypted-file technique can now also keep secrets out of state, which was the one modern advantage the secret-store technique had over it.

!!! tip "7. What has not moved: the prices"
    Both of the chapter's cost figures are still exact, checked 2026-08-21 against AWS's pricing pages. **KMS**: *"$1/month (prorated hourly)"* per customer managed key, plus *"$0.03 / 10,000 requests"*. **Secrets Manager**: $0.40 per secret per month, plus $0.05 per 10,000 API calls. Its $1–$10/month and $10–$25/month estimates hold as written, four years on.

!!! note "8. The option the chapter does not have: let RDS own the password"
    `manage_master_user_password = true` on `aws_db_instance` hands the master password to RDS, which creates and rotates it in Secrets Manager and exposes it through a `master_user_secret` attribute block. It *cannot* be combined with `password` or `password_wo`, which is the point — there is no value for you to pass, so there is no value to leak.

    For the specific question this chapter opens with, this is now the shortest correct answer. The three techniques still matter for every other secret, and for providers other than AWS.

---

*Related notes:* [Secrets and state](../../../topics/secrets-and-state.md) · TID Ch8 §8.5 [Managing secrets](../../tid/chapters/08-cd-deployment.md) · TUR Ch3 [State](03-manage-state.md) for `sensitive` plus `TF_VAR_` and the S3-backend encryption setup · [[tf-manage-sensitive-data]] for the hide-vs-omit-vs-both framework and the version matrix · [[infisical-terraform-secrets]] for the `grep`-proven state leak and the coordinate-passing rule · [[tf-remote-state-data]] for state as an exfiltration path · [[version-facts]]. Feeds learning-path **A6** (secrets and sensitive data), **A3** (CI credentials), **I6** (state and backends) and **A9** (dynamic credentials).
