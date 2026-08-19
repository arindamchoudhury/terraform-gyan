# The `terraform_remote_state` data source

> **Source:** [developer.hashicorp.com/terraform/language/state/remote-state-data](https://developer.hashicorp.com/terraform/language/state/remote-state-data)
> **Added:** 2026-07-10
> **Source updated:** undated language reference; captured 2026-07-10 against v1.15.x (latest); re-fetched 2026-08-19 — byte-identical, still v1.15.x
> **Tags:** state, remote-state, terraform_remote_state, tfe_outputs, built-in-resources, data-sharing, sensitive-data
> **Type:** documentation

*Developer › Terraform › Configuration Language › Reference › Built-in resources › The `terraform_remote_state` data source · v1.15.x*

Reads the **root module output values** of another Terraform configuration from its state backend. The second of the two built-in resources, alongside [[tf-terraform-data]]. Both come from the built-in provider `terraform.io/builtin/terraform`, which "does not include any other resources or data sources" — that's the complete list.

Learning-path **I6** names this data source in its scope line and milestone but never teaches it. Most of this page is the argument *against* using it.

## The security problem — read this before using it

!!! danger "Reading one output requires access to the entire state snapshot"
    > "Although `terraform_remote_state` **doesn't expose** any other state snapshot information for use in configuration, the state snapshot data is **a single object**, and so any user or server which has enough access to read the root module output values **will also always have access to the full state snapshot data by direct network requests**. Don't use `terraform_remote_state` if any of the resources in your configuration work with data that you consider sensitive."

    The distinction is between what the *language* exposes and what the *reader's credentials* permit. Terraform hands you only `outputs`. But you had to be able to `GET` the whole state file to get them, so nothing stops you (or a compromised CI runner) from reading it directly. State holds resource attributes in plaintext — passwords, keys, certs.

    This is the same plaintext-state caveat that [[tf-configure-resource]] raises for local-only resources, arriving from a different direction. → learning-path **A6 (secrets & sensitive data)**.

## Two recommended alternatives

**1. On HCP Terraform / Enterprise, use `tfe_outputs` instead.**

> "We recommend using the `tfe_outputs` data source in the HCP Terraform/Enterprise Provider … The `tfe_outputs` data source is **more secure because it does not require full access to workspace state** to fetch outputs."

That single sentence is the whole reason the recommendation exists: `tfe_outputs` fetches outputs through an API that can authorize outputs separately from state.

**2. Off HCP, publish data explicitly to a separate store.**

> "Sharing data with root module outputs is convenient, but it has drawbacks … When possible, we recommend **explicitly publishing data for external consumption to a separate location** instead of accessing it via remote state. This lets you apply **different access controls** for shared information and state snapshots."

Any managed-resource / data-source pair can serve. The page's own table:

| System | Publish with | Read with |
|---|---|---|
| Amazon Route53 / Azure DNS / Google Cloud DNS / Alibaba DNS | the respective DNS record resource | normal DNS lookups, or the `dns` provider |
| Amazon S3 | `aws_s3_object` resource | `aws_s3_object` data source |
| Amazon SSM Parameter Store | `aws_ssm_parameter` resource | `aws_ssm_parameter` data source |
| Azure Automation | `azurerm_automation_variable_string` resource | same as data source |
| Google Cloud Storage | `google_storage_bucket_object` resource | `google_storage_bucket_object` + `http` data sources |
| HashiCorp Consul | `consul_key_prefix` resource | `consul_key_prefix` data source |
| HCP Terraform | normal `output`s | `tfe_outputs` data source |
| Kubernetes | `kubernetes_config_map` resource | `kubernetes_config_map` data source |
| OCI Object Storage | `oci_objectstorage_bucket` resource | `oci_objectstorage_bucket` data source |

Three design notes the page adds:

- **Non-Terraform consumers are the real advantage.** "A key advantage … is that the data can potentially also be read by systems other than Terraform, such as configuration management or scheduler systems." Publish hostnames as DNS records and your instances resolve them natively. Publish to Consul KV and Consul Template / Nomad's `template` stanza can read it. Publish a Kubernetes ConfigMap and Pods consume it.
- **Generic blob stores need encoding.** For S3/GCS-style stores, use `jsonencode()` to publish and `jsondecode()` to read structured data.
- **Hide the mechanism behind a data-only module.** "You can encapsulate the implementation details … by writing a **data-only module** containing the necessary data source configuration and any necessary post-processing such as JSON decoding." Swap the sharing strategy later by changing one module.

## Usage

```hcl
data "terraform_remote_state" "vpc" {
  backend = "remote"

  config = {
    organization = "hashicorp"
    workspaces = {
      name = "vpc-prod"
    }
  }
}

resource "aws_instance" "foo" {
  # ...
  subnet_id = data.terraform_remote_state.vpc.outputs.subnet_id
}
```

Local backend variant:

```hcl
data "terraform_remote_state" "vpc" {
  backend = "local"

  config = {
    path = "..."
  }
}
```

No `required_providers` entry, no `provider` block. It's built in.

**The backend pages carry their own worked examples**, and they are the ones to copy from because they show the exact `config` keys each backend expects. [[tf-backend-s3]] gives `bucket` + `key` + `region`, [[tf-backend-gcs]] gives `bucket` + `prefix`, and [[tf-backend-local]] gives a `path` relative to `path.module`. Both of those pages carry dated artifacts around the example, which is worth noticing before copying: the S3 one prints a flat `addresses.# = 2` attribute dump from the pre-0.12 output format, and the GCS one gives explicit `Terraform >= 0.12` and `Terraform <= 0.11` variants, the second using the dead no-`.outputs` access form.

!!! note "The read inherits the reader's backend credentials, not the writer's"
    Nothing here authenticates separately. A `terraform_remote_state` block against `s3` uses whatever AWS credentials the *consuming* configuration resolves, which is why the security warning above is about access rather than about configuration. On `gcs` this compounds with the shared-environment-variable collision in [[tf-backend-gcs]]: exporting `GOOGLE_CREDENTIALS` gives one identity to the consuming config's backend, its providers, and this data source at once.

## Arguments

| Argument | Meaning |
|---|---|
| `backend` | **(Required)** The remote backend to use. |
| `workspace` | *(Optional)* The workspace to use, if the backend supports workspaces. |
| `config` | *(Optional; object)* Backend configuration. Listed optional, but "most backends require some configuration." |
| `defaults` | *(Optional; object)* Default values for outputs, "in case the state file is empty or lacks a required output." |

!!! note "`config` takes nested backend blocks as object *attributes*"
    "If the backend configuration requires a nested block, specify it here as a normal attribute with an object value. (For example, `workspaces = { ... }` instead of `workspaces { ... }`.)"

    So the `config` object accepts any argument valid in the equivalent `terraform { backend "<TYPE>" { … } }` block, but blocks become `=` attributes. Easy to get wrong when copying a backend block.

## Attributes

- **`outputs`** *(v0.12+)* — an object containing every root-level output in the remote state. Access as `data.terraform_remote_state.vpc.outputs.subnet_id`.
- *(≤ v0.11)* each root-level output appeared as a **top-level attribute** on the data source. Old tutorials show `data.terraform_remote_state.vpc.subnet_id` with no `.outputs`. That form is dead.

## Root outputs only

> "Only the **root-level** output values from the remote state snapshot are exposed … **Resource data and output values from nested modules are not accessible**."

To expose a nested module's output, add an explicit passthrough in the producing config's root:

```hcl
module "app" {
  source = "..."
}

output "app_value" {
  value = module.app.example
}
```

Without that `output` block, `module.app.example` is invisible to any consumer. Sharing across configurations is opt-in at the root, not automatic.

---
Related: [[tf-terraform-data]] — the other built-in resource, from the same built-in provider. · [[tf-backend-s3]] · [[tf-backend-gcs]] · [[tf-backend-local]] — the three backend pages that document their own `config` shape for this data source, and whose state objects a reader must be able to fetch whole. · [[tf-style-guide]] — also recommends `tfe_outputs` for state sharing, and notes secrets sit in state in plaintext. · [[tf-configure-resource]] — the same plaintext-state caveat, via local-only resources. · [[dependency-graph]] — a `terraform_remote_state` read is a `data` block, so `depends_on` on it orders the read.
