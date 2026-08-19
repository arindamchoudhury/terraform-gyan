# S3 backend

> **Source:** [developer.hashicorp.com/terraform/language/backend/s3](https://developer.hashicorp.com/terraform/language/backend/s3)
> **Added:** 2026-08-18
> **Source updated:** undated language reference; captured 2026-08-17 against v1.15.x (latest)
> **Tags:** backend, s3, state-locking, use_lockfile, dynamodb-deprecated, iam, workspaces, encryption, sse-c, assume-role, oidc
> **Type:** documentation

*Developer › Terraform › Configuration Language › Backends › s3 · v1.15.x*

The backend most teams use, and the one worth reading argument by argument rather than copying from a tutorial. Four things on this page are not on the generic [[tf-backend-configure]] or [[tf-state-backends]] pages, and three of them change what you would write.

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

## Authenticating from CI without a stored key

> "The following `assume_role_with_web_identity` configuration block is optional"

This is the argument that connects the backend to **A6** and to the forge material in **I6**: a pipeline presents an OIDC token ([[gha-oidc]], [[bitbucket-pipelines-oidc]]) and the backend assumes a role directly, so no long-lived AWS key sits in the CI system. The page also documents the multi-account pattern, where the backend assumes a role in the account that owns the state bucket.

---
Related: [[tf-backend-configure]] — the `backend` block rules, partial configuration and the credential-leak warning this page's SSE-C note sharpens. · [[tf-state-locking]] — what a lock means, plus the verified 412 transcript. · [[tf-state-backends]] — a backend's two responsibilities. · [[tf-backend-http]] — the other backend whose locking is off unless you configure it. · [[tf-state-workspaces]] — what the `env:` prefix is for. · [[gha-oidc]] · [[bitbucket-pipelines-oidc]] — where `assume_role_with_web_identity` gets its token.
