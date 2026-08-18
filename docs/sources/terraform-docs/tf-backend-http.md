# http backend

> **Source:** [developer.hashicorp.com/terraform/language/backend/http](https://developer.hashicorp.com/terraform/language/backend/http)
> **Added:** 2026-08-18
> **Source updated:** undated language reference; captured 2026-08-18 against v1.15.x (latest)
> **Tags:** backend, http, rest, state-locking, mtls, gitlab, terraform-remote-state, credentials
> **Type:** documentation

*Developer › Terraform › Configuration Language › Backends › http · v1.15.x*

The generic backend. Every other entry in the catalogue speaks one vendor's storage API; this one defines a small **REST protocol** and lets anything implement it. That is why it matters far beyond its length: [[gitlab-tf-state]] is this backend with a GitLab URL, and any self-hosted state service is written against this contract.

> "Stores the state using a simple REST client. State will be fetched via GET, updated via POST, and purged with DELETE. The method used for updating is configurable."

## The locking protocol, in status codes

Locking is optional here in the same sense [[tf-state-backends]] means it — the backend may or may not provide it — but this page is the only one that spells out the wire behaviour a server must implement:

> "When locking support is enabled it will use LOCK and UNLOCK requests providing the lock info in the body. The endpoint should return a **423: Locked** or **409: Conflict** with the holding lock info when it's already taken, **200: OK** for success. Any other status will be considered an error. The ID of the holding lock info will be added as a query parameter to state updates requests."

So the whole of [[tf-state-locking]] reduces, on this backend, to three response codes and a body carrying the lock info. `LOCK`/`UNLOCK` are non-standard HTTP verbs, which is why `lock_method` and `unlock_method` exist — GitLab, for one, wants `POST` and `DELETE` instead.

## Configuration

```hcl
terraform {
  backend "http" {
    address        = "http://myrest.api.com/foo"
    lock_address   = "http://myrest.api.com/foo"
    unlock_address = "http://myrest.api.com/foo"
  }
}
```

As a data source:

```hcl
data "terraform_remote_state" "foo" {
  backend = "http"

  config = {
    address = "http://my.rest.api.com"
  }
}
```

Every option has an environment-variable twin, which is the point of the next callout.

| Argument | Env var | Notes |
| --- | --- | --- |
| `address` | `TF_HTTP_ADDRESS` | **Required.** The REST endpoint. |
| `update_method` | `TF_HTTP_UPDATE_METHOD` | Defaults to `POST`. |
| `lock_address` | `TF_HTTP_LOCK_ADDRESS` | **Defaults to disabled** — no address, no locking. |
| `lock_method` | `TF_HTTP_LOCK_METHOD` | Defaults to `LOCK`. |
| `unlock_address` | `TF_HTTP_UNLOCK_ADDRESS` | Defaults to disabled. |
| `unlock_method` | `TF_HTTP_UNLOCK_METHOD` | Defaults to `UNLOCK`. |
| `username` / `password` | `TF_HTTP_USERNAME` / `TF_HTTP_PASSWORD` | HTTP basic auth. |
| `skip_cert_verification` | — | Defaults to `false`. |
| `retry_max` | `TF_HTTP_RETRY_MAX` | Defaults to **2**. |
| `retry_wait_min` / `retry_wait_max` | `TF_HTTP_RETRY_WAIT_MIN` / `_MAX` | Seconds; default **1** and **30**. |

mTLS adds three more: `client_certificate_pem`, `client_private_key_pem` (required if the certificate is set) and `client_ca_certificate_pem`, each with a `TF_HTTP_*` twin.

!!! danger "Credentials here are worse than credentials elsewhere"
    > "We recommend using environment variables to supply credentials and other sensitive data. If you use `-backend-config` or hardcode these values directly in your configuration, Terraform will include these values in **both the `.terraform` subdirectory and in plan files**."

    The same leak [[tf-backend-configure]] documents in general, but it bites harder on this backend, because the credential is usually a **personal access token with API scope** rather than a scoped cloud key. [[gitlab-tf-state]] repeats the warning for its own reason: a `-backend-config` value gets cached into the plan and carried to the apply, which GitLab says can leave CI jobs unable to lock.

!!! note "Locking is off unless you address it"
    `lock_address` and `unlock_address` both default to disabled, so a minimal `http` backend with only `address` set is an **unlocked** backend that will never warn you. Compare the `s3` backend, where locking is also opt-in but at least sits behind a boolean named `use_lockfile`.

---
Related: [[tf-backend-configure]] — the `backend` block rules this one obeys, and the same credential-leak warning stated generally. · [[tf-state-locking]] — what locking means to Terraform; this page is the wire format for it. · [[tf-state-backends]] — a backend's two responsibilities, storage and an optional locking API. · [[gitlab-tf-state]] — the implementation most people meet this backend through. · [[tf-remote-state-data]] — the data-source form shown above, and the case against using it.
