# S3 backend

> **Source:** [developer.hashicorp.com/terraform/language/backend/s3](https://developer.hashicorp.com/terraform/language/backend/s3)
> **Added:** 2026-08-18
> **Source updated:** undated language reference; captured 2026-08-17 against v1.15.x (latest); re-fetched 2026-08-19 — byte-identical, still v1.15.x
> **Tags:** backend, s3, state-locking, use_lockfile, dynamodb-deprecated, iam, workspaces, encryption, sse-c, assume-role, oidc
> **Type:** documentation

*Developer › Terraform › Configuration Language › Backends › s3 · v1.15.x*

The backend most teams use, and the one worth reading argument by argument rather than copying from a tutorial. Most of what it says is absent from the generic [[tf-backend-configure]] and [[tf-state-backends]] pages: an object path that changes under workspaces, opt-in locking with a deprecated predecessor, an IAM policy specific enough to copy, three encryption shapes, roughly forty arguments with six deprecations among them, and a worked multi-account architecture that is the strongest published case for workspaces.

> "Stores the state as a given key in a given bucket on Amazon S3. This backend also supports state locking which can be enabled by setting the `use_lockfile` argument to true."

```hcl
terraform {
  backend "s3" {
    bucket = "mybucket"
    key    = "path/to/my/key"
    region = "us-east-1"
  }
}
```

> "Note that for the access credentials we recommend using a **partial configuration**."

## Where the object actually lands

The default workspace gets exactly `key`. Everything else is prefixed:

> "Other workspaces are stored using the path `<workspace_key_prefix>/<workspace_name>/<key>`. The default workspace key prefix is **`env:`**"

So workspace `development` with `key = path/to/my/key` lands at **`env:/development/path/to/my/key`**. A literal `env:` directory with a colon in it, inherited from the pre-1.0 name for workspaces, and it is why a bucket that has seen workspaces looks so odd in the console. `workspace_key_prefix` changes it. See [[tf-state-workspaces]] and the [Workspaces](../../topics/workspaces.md) topic for what these are worth using for at all.

Compare the `gcs` backend, which has no `key` at all: state is `<prefix>/<workspace>.tfstate`, so the workspace name is *always* in the path rather than only for non-default ones.

## Reading this state from another configuration

The page documents the `terraform_remote_state` form alongside the backend itself:

```hcl
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "terraform-state-prod"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}
```

> "The `terraform_remote_state` data source will return all of the root module outputs defined in the referenced remote state (but not any outputs from nested modules unless they are explicitly output again in the root)."

Same nested-module rule as every other backend. The access consequence is in [[tf-remote-state-data]]: a reader of one output holds read access to the whole snapshot.

## Locking is opt-in, and the old way is going away

> "State locking is an **opt-in** feature of the S3 backend."

> "Locking can be enabled via S3 or DynamoDB. However, **DynamoDB-based locking is deprecated and will be removed in a future minor version**. To support migration from older versions of Terraform that only support DynamoDB-based locking, the S3 and DynamoDB arguments can be configured simultaneously."

- `use_lockfile` — "(Optional) Whether to use a lockfile for locking the state file. **Defaults to `false`**."
- `dynamodb_table`, `dynamodb_endpoint` — both **deprecated**.

Two consequences worth separating. A backend block that names neither is **silently unlocked**, exactly like the `http` backend's disabled-by-default lock addresses in [[tf-backend-http]]. And the both-at-once allowance is a migration path, not a belt-and-braces recommendation: set both, roll everyone forward, then drop DynamoDB.

!!! note "The deprecation is Terraform-only"
    OpenTofu's schema carries no deprecation on `dynamodb_table`. Telling an OpenTofu user to migrate off DynamoDB is advice they do not need. Engine differences live in **E3**; the dating of native S3 locking (Terraform 1.10 introduced, 1.11 GA; OpenTofu 1.10, about seven months later) is in [[release-feature-map]].

!!! example "🧪 Verified — the lock is a conditional write"
    Chapter 15's lab runs this backend against the local emulator with `use_lockfile = true`. A second command during an apply fails with **`412 PreconditionFailed`** on `PutObject`, and the lock object is a `<key>.tflock` sibling that exists only while the operation runs. The 412 *is* the lock: the writer sets an if-none-match precondition, and the second one loses. Full transcript in [[tf-state-locking]]; the lab is `labs/chapter15/lab2/`.

## The IAM policy is more specific than "read and write the bucket"

The page gives the statement in full. What is worth carrying:

- `s3:ListBucket` on the **bucket**, "at a minimum … able to list the path where the state is stored".
- `s3:GetObject` and `s3:PutObject` on the **key**.
- With `use_lockfile`, `s3:GetObject`, `s3:PutObject` **and `s3:DeleteObject`** on the **`.tflock` object**.

And the line that surprises people:

> "**`s3:DeleteObject` is not required on the state file, as Terraform does not delete it.**"

Terraform never removes a state object. Whatever cleans up old state is your process, not the tool — which also means a bucket policy that omits `DeleteObject` on the state key is not a limitation you will trip over.

Workspaces widen all of this to `<workspace_key_prefix>/*/<key>`, and there `s3:DeleteObject` **is** required, because deleting a workspace deletes its state.

## Encryption has three shapes

| Argument | What it is | Cost |
| --- | --- | --- |
| `encrypt` | server-side encryption of state **and lock** files | none |
| `kms_key_id` | your own KMS key by ARN | also needs `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey` on that key |
| `sse_customer_key` | SSE-C, base64, must decode to 256 bits | you hold the key |

The warning that decides where the third one lives:

> "This can also be sourced from the **`AWS_SSE_CUSTOMER_KEY`** environment variable, which is recommended due to the sensitivity of the value. **Setting it inside a terraform file will cause it to be persisted to disk in `terraform.tfstate`.**"

A key written into configuration ends up in the state it was meant to protect. That is the same leak [[tf-backend-configure]] documents for backend config generally, with a sharper edge.

## The rest of the argument surface

Four arguments get copied from tutorials. The page documents roughly forty, and several change what a real configuration looks like.

**Guardrails against the wrong account**

- `allowed_account_ids` — "List of allowed AWS account IDs to prevent potential destruction of a live environment."
- `forbidden_account_ids` — the inverse. The two conflict and cannot both be set.

This is a cheap blast-radius control that nothing else in the state material mentions. A backend pointed at the production bucket with `allowed_account_ids` set fails fast rather than writing.

**Where credentials come from**

`region` is the only required argument outside S3 storage itself. Everything else resolves through the ordinary AWS chain. `profile`, `shared_config_files` (default `~/.aws/config`) and `shared_credentials_files` (default `~/.aws/credentials`) name the files. `access_key` and `secret_key` are all-or-nothing, and `token` carries an MFA session token. `shared_credentials_file`, singular, is deprecated in favour of the plural.

**Network and transport**

`http_proxy`, `https_proxy` and `no_proxy` mirror the usual environment variables. `no_proxy` takes a domain name, an IP address, a CIDR block, or a bare `*`, and domain and IP entries may carry a port. `custom_ca_bundle` points at a certificate file, and the page notes that `ca_bundle` in the shared config file is **not** supported. `insecure` allows unverified TLS. `max_retries` defaults to `5`, and `retry_mode` is `standard` or `adaptive`.

!!! note "`use_fips_endpoint` and `use_dualstack_endpoint` are the compliance knobs"
    Both force endpoint resolution into a different address family or FIPS-validated set, and both can come from a shared config file instead of the backend block. Worth knowing they exist before someone hand-writes an `endpoints` override to reach a FIPS endpoint.

**The `skip_*` family, which is why the emulator lab works**

`skip_credentials_validation`, `skip_region_validation`, `skip_requesting_account_id` and `skip_metadata_api_check` all exist for "AWS API implementations" that lack STS, IAM or the metadata service. `skip_s3_checksum` is the fifth, for S3-compatible APIs that reject the checksum header. Chapter 15's emulator lab sets four of them, and the page confirms that is the sanctioned use rather than a workaround.

**`endpoints` overrides, and what they replaced**

`endpoints` is a single attribute holding `s3`, `iam`, `sts`, `sso` and a deprecated `dynamodb`. Each also reads from `AWS_ENDPOINT_URL_<SERVICE>`, and a bare `AWS_ENDPOINT_URL` sets a base for all services. The shared config file can do the same through `endpoint_url` on a profile, with a `services` section overriding per service.

| Deprecated | Use instead |
| --- | --- |
| `endpoint` | `endpoints.s3` |
| `force_path_style` | `use_path_style` |
| `iam_endpoint` | `endpoints.iam` |
| `sts_endpoint` | `endpoints.sts` |
| `shared_credentials_file` | `shared_credentials_files` |
| `dynamodb_table`, `dynamodb_endpoint` | `use_lockfile` |

Six deprecations on one page. Copying an S3 backend block from anything written before 2024 will pick up at least one.

## Authenticating from CI without a stored key

> "The following `assume_role_with_web_identity` configuration block is optional"

This is the argument that connects the backend to **A6** and to the forge material in **I6**: a pipeline presents an OIDC token ([[gha-oidc]], [[bitbucket-pipelines-oidc]]) and the backend assumes a role directly, so no long-lived AWS key sits in the CI system.

`role_arn` is the only required field. The token arrives as either `web_identity_token` or `web_identity_token_file`, exactly one of the two, and the file form reads `AWS_WEB_IDENTITY_TOKEN_FILE`, which is what a GitHub Actions or EKS pod identity already sets.

```hcl
terraform {
  backend "s3" {
    bucket = "example-bucket"
    key    = "path/to/state"
    region = "us-east-1"

    assume_role_with_web_identity = {
      role_arn           = "arn:aws:iam::PRODUCTION-ACCOUNT-ID:role/Terraform"
      web_identity_token = "<token value>"
    }
  }
}
```

**The plain `assume_role` block is the non-OIDC sibling**, and it carries more restriction surface than the web-identity one: `external_id`, an inline `policy` or `policy_arns` to further narrow the assumed role, `session_name`, `source_identity`, `tags` and `transitive_tag_keys`. `duration` is shared by both, written as `1h30m` or `90m`, and bounded: "Must be between 15 minutes (`15m`) and 12 hours (`12h`)."

One line is easy to miss and useful: **"Multiple `assume_role` values can be specified, and the roles will be assumed in order."** Role chaining is built in, so a hub-and-spoke setup needs no wrapper script.

## The multi-account pattern the page actually recommends

The longest section of the page is a worked architecture, not reference material. It is worth reading before designing a state layout, because it answers "one bucket or many" with a definite opinion.

The premise: "Terraform is an administrative tool that manages your infrastructure, and so ideally the infrastructure that is used by Terraform should exist outside of the infrastructure that Terraform manages."

**The shape**

- One **administrative account** holding the human IAM users, any IAM groups, and **the single S3 bucket with every workspace's state**. Set `use_lockfile = true` and a `workspace_key_prefix`.
- One **environment account** per environment, each holding an IAM role Terraform can assume.
- Each environment role trusts the administrative account, and the administrative users or groups get the converse policy allowing them to assume it.

**The split that makes it work.** The backend authenticates as the administrator's own user in the administrative account, while the provider assumes the environment role. State operations and infrastructure operations therefore run as different principals, and the workspace picks which environment:

```hcl
variable "workspace_iam_roles" {
  default = {
    staging    = "arn:aws:iam::STAGING-ACCOUNT-ID:role/Terraform"
    production = "arn:aws:iam::PRODUCTION-ACCOUNT-ID:role/Terraform"
  }
}

provider "aws" {
  # No credentials explicitly set here because they come from either the
  # environment or the global credentials file.

  assume_role = {
    role_arn = var.workspace_iam_roles[terraform.workspace]
  }
}
```

```shell
terraform workspace new staging
terraform workspace new production
terraform workspace select staging
terraform apply
```

The `default` workspace `init` creates "will not be used". If the role ARNs are shared across configurations, the page suggests sourcing them from `terraform_remote_state` instead of repeating the map.

!!! note "This is the strongest documented case for workspaces"
    [[tf-state-workspaces]] warns workspaces are a poor fit for environment separation, and the [Workspaces](../../topics/workspaces.md) topic collects the reasons. This section is the counter-example HashiCorp itself publishes, and the thing that makes it defensible is that the workspace name is not merely a state path here. It selects the **AWS account** the provider assumes into, so the isolation is real rather than nominal.

**In automation**, run the tool on an EC2 instance *in the administrative account* and give it an instance profile in place of an administrator IAM user, with cross-account delegation attached. Use "a separate EC2 instance for each target account so that its access can be limited only to the single account". The page says the same applies to ECS.

## Per-object IAM, when everyone should not be able to write production

The default of that pattern is flat: "all users can read and write states for all workspaces." The page then shows how to narrow it to one state object.

Three statements, and the third is the one people forget:

- `s3:ListBucket` on the bucket, conditioned on `s3:prefix` equal to the state path.
- `s3:GetObject` and `s3:PutObject` on the state object.
- `s3:GetObject`, `s3:PutObject` **and** `s3:DeleteObject` on `<key>.tflock`.

> "If state locking is enabled, the lock file (`<key>.tflock`) must also be included in the access controls."

A policy written before `use_lockfile` existed grants nothing on the lock object, so the operation fails at lock acquisition rather than at write. Note also the reason for reading being controlled at all: "It is also important to control access to reading the state file." State is a secrets carrier ([[tf-manage-sensitive-data]]).

## Two smaller things

**`TF_APPEND_USER_AGENT`** appends free text to the `User-Agent` on every AWS API call, "only available in Terraform v0.13.1+". The page's example tags a Jenkins agent and build ID. Useful for attributing CloudTrail entries to a specific pipeline run.

!!! warning "S3-compatible storage is best effort"
    > "Support for S3 Compatible storage providers is offered as “best effort”. HashiCorp only tests the `s3` backend against Amazon S3, so cannot offer any guarantees when using an alternate provider."

    This scopes the verified lab above and anything run against MinIO, Ceph or a cloud provider's S3 API. The behaviour observed on the emulator is evidence about the emulator. `use_lockfile` in particular depends on conditional-write support that a compatible implementation may not have, so confirm the 412 before trusting the lock in a non-AWS store.

---
Related: [[tf-backend-configure]] — the `backend` block rules, partial configuration and the credential-leak warning this page's SSE-C note sharpens. · [[tf-remote-state-data]] — the data source this page documents alongside the backend. · [[tf-manage-sensitive-data]] — why read access to a state object is itself a permission worth restricting. · [[tf-state-locking]] — what a lock means, plus the verified 412 transcript. · [[tf-state-backends]] — a backend's two responsibilities. · [[tf-backend-http]] — the other backend whose locking is off unless you configure it. · [[tf-state-workspaces]] — what the `env:` prefix is for. · [[gha-oidc]] · [[bitbucket-pipelines-oidc]] — where `assume_role_with_web_identity` gets its token.
