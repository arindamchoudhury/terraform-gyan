# Google Cloud Provider (Registry overview)

> **Source:** [registry.terraform.io/providers/hashicorp/google/latest/docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
> **Added:** 2026-07-09
> **Source updated:** 2026-06-30 (provider v7.39.0 published)
> **Tags:** gcp, google, provider, registry, authentication, adc, impersonation
> **Type:** documentation

The landing page for HashiCorp's Google Cloud provider on the Terraform Registry. Manages the lifecycle of GCP resources (Compute Engine, Cloud Storage, Cloud SQL, GKE, BigQuery, Cloud Functions, and more). This is the GCP counterpart to [[aws-provider]]; the mechanics are the same (source address, version pin, provider block), so this note focuses on what's **different from AWS**.

## Registry metadata

- **Tier:** Official — collaboratively maintained by the Google Terraform team at Google **and** the Terraform team at HashiCorp. (Contrast: AWS is HashiCorp-only.)
- **Source address:** `hashicorp/google`.
- **Latest version:** v7.39.0, published June 30, 2026 (415 versions total).
- **Adoption:** ~2.2B downloads all-time, ~14.4M/week.

!!! info "Sibling providers"
    Beyond `hashicorp/google`, GCP also ships `hashicorp/google-beta` for beta/preview GCP features. Pin whichever the resource needs; many configs use both. The version line here (7.x) is a major ahead of AWS's 6.x — the two providers version independently, so pin each separately.

## Example usage

```terraform
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

provider "google" {
  project = "my-project-id"
  region  = "us-central1"
  zone    = "us-central1-c"
}
```

The **project / region / zone** trio is GCP-specific. AWS has only `region`; GCP adds a mandatory-ish default `project` (every resource lives in a project) and an optional default `zone` for zonal resources. Per-resource values override the provider default.

## Authentication

The recommended and fallback credential sources, in precedence order:

1. **Application Default Credentials (ADC) via the `gcloud` CLI** — the recommended primary method on a workstation: install `gcloud` and run `gcloud auth application-default login`. (Contrast: AWS's workstation default is `~/.aws/credentials` / a named profile.)
2. **Service account key file** — the path to, *or* the JSON contents of, a service-account key. Set via the `credentials` argument.
3. **Environment variables**, in order: `GOOGLE_CREDENTIALS` → `GOOGLE_CLOUD_KEYFILE_JSON` → `GCLOUD_KEYFILE_JSON`.
4. **Access token** — a temporary OAuth 2.0 token. Terraform **cannot renew** these; they expire (default 1 hour).
5. **Service account impersonation** — impersonate a service account for all API calls; you need `roles/iam.serviceAccountTokenCreator` on that account.

!!! danger "Prefer ADC / impersonation over key files"
    Same rule as AWS: don't hard-code or commit credentials. On GCP the idiomatic least-privilege path is ADC locally and **workload identity / impersonation** in automation, not a downloaded service-account key file. Key files are long-lived secrets — treat them like static AWS keys (avoid).

## Key provider arguments

| Argument | Notes |
|---|---|
| `project` | Default project for resources. A per-resource `project` takes precedence. |
| `region` | Default region for regional resources. Per-resource overrides win. |
| `zone` | Default zone for zonal resources. |
| `credentials` | Path to, or JSON contents of, a service-account key file. |
| `access_token` | Temporary OAuth 2.0 token (not auto-renewed; ~1h). |
| `impersonate_service_account` | Service account to impersonate for all Google API calls. |
| `user_project_override` | Controls the **quota project** used in GCP API requests. |
| `billing_project` | The quota project sent when `user_project_override` is set. |
| `request_timeout` | Duration string bounding individual HTTP requests. Default `"120s"`. |

!!! note "No `default_tags` equivalent"
    Unlike the AWS provider's `default_tags` (tag every resource provider-wide), GCP labeling is per-resource (`labels = {}`) — there's no provider-level tag-all argument. The GCP analogues to watch are `user_project_override` / `billing_project`, which have no AWS parallel and matter when the resource's project differs from the quota/billing project.

---
Related: [[aws-provider]] — the AWS counterpart; same registry/pin/provider-block mechanics, different auth model (ADC vs credentials file) and no `default_tags`. · [[provider-requirements]] — the `required_providers` / source-address / version-constraint machinery. · [[tf-resources]] — how provider resource types are declared and applied.
