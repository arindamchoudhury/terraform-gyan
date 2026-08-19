# gcs backend

> **Source:** [developer.hashicorp.com/terraform/language/backend/gcs](https://developer.hashicorp.com/terraform/language/backend/gcs)
> **Added:** 2026-08-18
> **Source updated:** undated language reference; captured 2026-08-18 against v1.15.x (latest)
> **Tags:** backend, gcs, state-locking, prefix, adc, impersonation, cmek, csek, storage_custom_endpoint
> **Type:** documentation

*Developer › Terraform › Configuration Language › Backends › gcs · v1.15.x*

The Google counterpart to [[tf-backend-s3]]. Read them together: the differences are small in number and each one changes something you would write.

> "Stores the state as an object in a configurable prefix in a pre-existing bucket on Google Cloud Storage (GCS). **The bucket must exist prior to configuring the backend.**"

> "**This backend supports state locking.**"

No opt-in, no argument to remember. That single sentence is the biggest divergence from S3, where locking is off until you set `use_lockfile`.

```hcl
terraform {
  backend "gcs" {
    bucket = "tf-state-prod"
    prefix = "terraform/state"
  }
}
```

!!! warning "Versioning is a recommendation on both clouds, and automatic on neither"
    > "Warning! It is highly recommended that you enable **Object Versioning** on the GCS bucket to allow for state recovery in the case of accidental deletions and human error."

    Word for word the same advice as the S3 page's Bucket Versioning warning. Neither backend turns it on; both assume the bucket was created by someone else, which is exactly why the bootstrap configuration in `labs/chapter15/lab2/bootstrap` exists.

## There is no `key`

The whole addressing model is `prefix` plus workspace:

> "`prefix` - (Optional) GCS prefix inside the bucket. Named states for workspaces are stored in an object called **`<prefix>/<name>.tfstate`**."

So the default workspace is `<prefix>/default.tfstate`, and the workspace name is in the path *always* — not only for non-default workspaces as with S3's `env:` prefix. Verified in the lab: with `prefix = "terraform/state"`, the object is `terraform/state/default.tfstate`.

!!! example "🧪 Verified — locking is a 412 on the object generation"
    Chapter 15's lab runs this backend against a local GCP emulator. A second command during an apply is refused with:

    ```
    writing "gs://tf-state-lab/terraform/state/default.tflock" failed:
    googleapi: Error 412: ifGenerationMatch: 1787133258314 != 0, conditionNotMet
    ```

    A `.tflock` object written with `ifGenerationMatch: 0` — "create only if this does not exist". Mechanically the same idea as the S3 backend's `412 PreconditionFailed`, in Google's spelling. Both clouds implement distributed state locking as one conditional object write; neither runs a lock service. Lab: `labs/chapter15/lab3/`.

## Authentication, in four situations

The page organises this better than most, by *where Terraform is running*:

- **Your workstation** — install the Google Cloud SDK and use Application Default Credentials. "User ADCs do expire and you can refresh them by running `gcloud auth application-default login`."
- **On Google Cloud** — attach a service account to the instance or cluster; "make sure that the scope of the VM/Cluster is set to `cloud-platform`".
- **Outside Google Cloud** — a service-account key file plus `GOOGLE_APPLICATION_CREDENTIALS`.
- **Impersonation** — `impersonate_service_account`, which needs `roles/iam.serviceAccountTokenCreator` on the target, with `impersonate_service_account_delegates` for a chain.

`access_token` is the fourth way in: a raw OAuth 2.0 bearer token, and "if both are specified, `access_token` will be used over the `credentials` field."

!!! note "The eventual-consistency trap is stated here and nowhere else"
    > "IAM Changes to buckets are eventually consistent and may take upto a few minutes to take effect. **Terraform will return 403 errors till it is eventually consistent.**"

    So a 403 immediately after granting access is not necessarily a wrong policy. Wait before debugging.

## Encryption: the two kinds behave differently at migration time

Both are available — `encryption_key` for customer-**supplied** (CSEK, 32 bytes base64) and `kms_encryption_key` for customer-**managed** (CMEK, Cloud KMS). The difference the page spends most of its length on is what happens when you change them.

| | Customer-supplied (CSEK) | Customer-managed (CMEK / KMS) |
| --- | --- | --- |
| Who holds the key | you | Google, in Cloud KMS |
| Changing or removing it | **Terraform cannot migrate the state automatically** | Terraform migrates it |
| What you must do | rewrite the object first (`gsutil rewrite` / `gcloud cp`) to strip the old key, *then* `terraform init -migrate-state` | nothing extra, but the change only lands on the **first write after migration** |
| Reading via `terraform_remote_state` | key required | not required — "decryption occurs automatically within GCS" |

The reason for the asymmetry is stated plainly: "Google does not store customer-supplied encryption keys, any requests sent to the Cloud Storage API must supply them instead… At the time of state migration, the backend configuration loses the old key's details and Terraform cannot use the key during the migration process."

Consequence worth planning around: after a CMEK change, **do not delete the old key** until every state file encrypted with it has been written again, because the first write is what re-encrypts.

The blanket warning applies to both:

> "Take care of your encryption keys because state data encrypted with a lost or deleted key is not recoverable."

## `storage_custom_endpoint`

> "A URL containing three parts: the protocol, the DNS name pointing to a **Private Service Connect** endpoint, and the path for the Cloud Storage API (`/storage/v1/b`)"

Documented for PSC, where the point is keeping state traffic off the public internet. It is a plain URL override, which is why Chapter 15's lab can point it at a local emulator — that use is this project's finding, not a documented promise.

---
Related: [[tf-backend-s3]] — the same job on AWS; read the two together for `key`-versus-`prefix`, opt-in-versus-default locking, and two spellings of a conditional write. · [[tf-backend-configure]] — partial configuration and the credential-leak warning this page repeats verbatim. · [[tf-state-locking]] — what a lock protects. · [[tf-state-workspaces]] — why the workspace name is in every object path here. · [[tf-remote-state-data]] — the data-source form, and why KMS keys are not needed to read.
