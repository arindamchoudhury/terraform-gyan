# Backend block configuration overview

> **Source:** [developer.hashicorp.com/terraform/language/backend](https://developer.hashicorp.com/terraform/language/backend)
> **Added:** 2026-07-30
> **Source updated:** undated language reference; captured 2026-07-30 against v1.15.x (latest); re-fetched 2026-08-19 — byte-identical, still v1.15.x
> **Tags:** backend, backend-block, partial-configuration, backend-config, tfbackend, init, migrate-state, credentials
> **Type:** documentation

*Developer › Terraform › Configuration Language › Backends › Configure a backend · v1.15.x*

The **configuration** page for backends. [[tf-state-backends]] is the State-section page and answers *what a backend is responsible for*; this one answers *how you write and initialize the block*. Longest of the two by far, and most of its length goes to partial configuration and to how backend settings leak.

## The block, and its three limitations

```hcl
terraform {
  backend "remote" {
    organization = "example_corp"

    workspaces {
      name = "my-app-prod"
    }
  }
}
```

The backend type is the block **label**, and the arguments in the body are specific to that type.

> - "A configuration can only provide one backend block."
> - "A backend block cannot refer to named values (like input variables, locals, or data source attributes)."
> - "You cannot reference values declared within backend blocks elsewhere in the configuration."

The second one is the constraint people hit first — you cannot parameterize a backend with a variable. Partial configuration below is the sanctioned workaround.

!!! warning "Measured — the block has no evaluation scope at all, so `const` does not help"
    Terraform 1.15.8, 2026-08-19. The page says named values are not allowed and stops there. The implementation is stricter than "not allowed": HCL raises `Variables not allowed` when it walks the evaluation context chain and finds **no context defining any variables**, so the reference is never resolved and rejected — there is nothing to resolve it against. A function call in the same position gives the matching `Functions not allowed` / *"Functions may not be called here."*

    That matters because Terraform **1.15** added `const = true` on an input variable, which makes it usable in a `module` block's `source` and `version` ([[tf-modules-configuration]]). Reasonable to expect it to extend here. It does not:

    - `path = var.state_path` with `const = true` on the variable → `Variables not allowed`.
    - `path = local.state_path`, where the local is built from a `const` variable → `Variables not allowed`, even though that same indirection *is* accepted for a module `source`.
    - The `const` variable declaration itself is fine in both cases. Only the reference from inside the `backend` block fails.

    The two restrictions are different in kind. `const` answers *when is this value known*, which is a timing question that module installation genuinely has. The backend block never gets a scope, so timing never comes up.

!!! info "OpenTofu removes limitation two"
    Since **OpenTofu 1.8**, `backend` and `provider` blocks *can* reference variables and locals, resolved in an early phase during `tofu init` before state exists. Details and restrictions in [[ot-early-eval-backend]]. This is a real divergence, not a version lag: on Terraform 1.15 the named-value ban still holds.

**`backend` and `cloud` are mutually exclusive.** "Do not configure a backend when connecting your configuration to workspaces in HCP Terraform or Terraform Enterprise… If your configuration includes a `cloud` block, it cannot include a `backend` block." The `cloud` block half is in [[06-state-management]] §6.4.5.

**Default is `local`**, storing state as a file on disk.

**Backends are built in, and only built in.** "You cannot load additional backends as plugins." Also: "The specified backend must be available in the version of Terraform you are using" — so a backend added in a later release (`oci`, 1.12) is simply not there on an older CLI.

## Credentials, and the two files that leak them

The page's own guidance on arguments: some backends accept credentials inline, "but we do not recommend including access credentials directly in the configuration. Instead, leave credential-related arguments unset and provide them using the credentials files or environment variables that are conventional for the target system."

!!! danger "`-backend-config` is not a safe place for secrets either"
    > "We recommend using environment variables to supply credentials and other sensitive data. If you use `-backend-config` or hardcode these values directly in your configuration, Terraform will include these values in **both the `.terraform` subdirectory and in plan files**. This can leak sensitive credentials."

    Terraform writes the backend configuration in **plain text in two places**:

    - **`.terraform/terraform.tfstate`** — the backend configuration for the current working directory.
    - **Every plan file** — each one captures `.terraform/terraform.tfstate` as it was at plan time, "to ensure Terraform is applying the plan to correct set of infrastructure."

    This confirms from the source what [[infisical-terraform-secrets]] asserts about backend config leaking harder than provider config, and it is the same warning OpenTofu attaches to its early-evaluation feature.

A consequence the page draws out, easy to miss:

> "When applying a plan that you previously saved to a file, Terraform uses the backend configuration **stored in that file** instead of the current backend settings. If that configuration contains time-limited credentials, they may expire before you finish applying the plan."

So a saved plan carries its own frozen backend config. With short-lived credentials baked in, a slow review can make the plan unappliable. The fix is environment variables, which are read fresh at apply.

## Initializing

Change the backend configuration and you must run `terraform init` again before any plan, apply, or state operation.

`init` creates `.terraform/`, holding the most recent backend configuration "including any authentication parameters you provided to the Terraform CLI." Do not commit it.

!!! note "Two files named `terraform.tfstate`, and they are unrelated"
    `.terraform/terraform.tfstate` is **backend configuration**. The `terraform.tfstate` that holds your infrastructure's state is a different file, and with a remote backend it lives in the backend, not on disk. The page says it plainly: "The local backend configuration is different and entirely separate from the `terraform.tfstate` file that contains state data about your real-world infrastructure."

On a backend change Terraform offers to migrate existing state, "so you can adopt backends without losing any existing state." The page's precaution: **"Before migrating to a new backend, we strongly recommend manually backing up your state by copying your `terraform.tfstate` file to another location."**

## Partial configuration

Omit some or all required arguments from the block and supply them at init time. The minimum is an empty block naming the type:

```hcl
terraform {
  backend "consul" {}
}
```

Three ways to supply the rest.

**1. A file, via `-backend-config=PATH`.** The partial block must contain "keys set to empty values"; init populates them from matching keys in the file.

```hcl
# state.tf
terraform {
  backend "s3" {
    bucket = ""
    key    = ""
    region = ""
    profile= ""
  }
}
```

```hcl
# state.config
bucket = "your-bucket"
key    = "your-state.tfstate"
region = "eu-central-1"
profile= "Your_Profile"
```

```shell
terraform init -backend-config="./state.config"
```

The file format is "the contents of the backend block as top-level attributes, without the need to wrap it in another `terraform` or `backend` block."

!!! tip "The recommended filename is `*.backendname.tfbackend`"
    For example `config.consul.tfbackend`. "Terraform will not prevent you from using other names but following this convention will help your editor understand the content."

    Worth flagging against [[06-state-management]] §6.4, which shows `-backend-config=backend.tfvars`. That works, but `.tfvars` tells an editor this is *variable* input when it is backend input. Prefer the documented `.tfbackend` suffix.

**2. Command-line key/value pairs**, one flag per setting:

```shell
terraform init \
    -backend-config="address=demo.consul.io" \
    -backend-config="path=example_app/terraform_state" \
    -backend-config="scheme=https"
```

> "Note that many shells retain command-line flags in a history file, so this isn't recommended for secrets."

The page's own example makes the credential point concrete: the Consul backend also needs an access token, and that goes in `CONSUL_HTTP_TOKEN` or `CONSUL_HTTP_AUTH`, not in a flag.

!!! tip "Quote the whole argument in PowerShell"
    PowerShell splits unquoted `-flag=value` arguments at the `=`. Wrap the entire token, not just the value: `"-backend-config=address=demo.consul.io"`.

**3. Interactively.** Terraform prompts for the required values unless interactive input is disabled. "Terraform will not prompt for optional values."

**Merge order**, when settings come from several places: command-line options override the main configuration, and command-line options are "processed in order, with later options overriding values set by earlier options."

The merged result lands in `.terraform/`. The page states the tradeoff without softening it: "sensitive information can be omitted from version control, but it will be present in plain text on local disk when running Terraform."

For a config file holding secrets, the page's suggestion is a secure store such as Vault — "in which case it must be downloaded to the local disk before running Terraform." The secret still touches disk; only its resting place changes.

## Changing and removing a backend

You can change both the settings and the **type** — "for example from `consul` to `s3`". Terraform detects the change, requires reinitialization, and offers to migrate state.

Three behaviors worth knowing before you answer the prompts:

- **Multiple workspaces are copied together.** "If Terraform detects you have multiple workspaces, it will ask if this is what you want to do."
- **Reconfiguring the same backend still asks about migration.** Answering "no" is fine here.
- **Removing the backend block** and reinitializing prompts you to migrate state back to the default `local` backend.

!!! warning "The interactive path only exists on a *first* backend adoption"
    Measured on Terraform 1.15.8 (2026-08-19). The page describes migration as something Terraform offers, and for the first adoption it is: with no backend recorded in `.terraform/` yet, a plain `terraform init` finds the local state and prompts.

    Once a backend **is** recorded, every later change stops instead:

    ```
    Error: Backend configuration changed

    If you wish to attempt automatic migration of the state, use "terraform
    init -migrate-state".
    If you wish to store the current configuration with no changes to the
    state, use "terraform init -reconfigure".
    ```

    That covers changing the settings, changing the type, and deleting the block. So the three interactive behaviours above are what you get *after* passing `-migrate-state`, not from a bare `init`.

!!! danger "Migration copies and never cleans up"
    Also measured 2026-08-19, three runs on Terraform 1.15.8 and one on OpenTofu 1.12.5. Migrating local state onto the `s3` backend truncates `terraform.tfstate` to **0 bytes** and leaves the complete snapshot in **`terraform.tfstate.backup`**, all attributes intact. Unsetting a backend leaves the *source* file complete instead.

    Either direction leaves a full plaintext copy of the state on the disk you just moved it off, and nothing mentions it. Delete it deliberately once the new location is verified. This is the gap in the "never persisted to disk" guarantee [[tf-state-backends]] states, which describes later runs rather than the migration itself.

The `-migrate-state` and `-reconfigure` flags that automate these answers are in [[06-state-management]] §6.4.6; this page describes the interactive path only.

## Verified against a local AWS emulator

Run on **Terraform v1.15.8** against **Floci 1.5.33** on `:4566` (the book's lab emulator), with the `s3` backend and a `terraform_data` resource so no provider plugin is involved.

**The working backend block.** `endpoints` is an **attribute, not a block** — `endpoints { s3 = … }` fails with *"Blocks of type `endpoints` are not expected here. Did you mean to define argument `endpoints`?"*

```hcl
terraform {
  backend "s3" {
    bucket = "tf-state-lab"
    key    = "lab/terraform.tfstate"
    region = "us-east-1"

    access_key = "test"
    secret_key = "test"

    endpoints = {
      s3 = "http://localhost:4566"
    }

    use_path_style              = true
    use_lockfile                = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
  }
}
```

`terraform apply` wrote `lab/terraform.tfstate` into the bucket, and no `terraform.tfstate` appeared on local disk.

**The leak is exactly as documented, in both files.** `.terraform/terraform.tfstate` after init contains the *entire* resolved backend config as JSON, credentials included:

```json
"backend": { "type": "s3", "config": {
  "access_key": "test", "bucket": "tf-state-lab",
  "endpoints": { "s3": "http://localhost:4566", ... },
  "secret_key": "test", "use_lockfile": true, ... } }
```

A saved plan file is a zip of `tfplan`, `tfstate`, `tfstate-prev`, `tfconfig/`, `.terraform.lock.hcl`. The `tfplan` entry is msgpack, and the backend config sits inside it — the bytes around the key read `…access_key⸱test⸱acl⸱…bucket⸱tf-state-lab…`, with `http://localhost:4566` and `secret_key` alongside. So "plan files capture the information in `.terraform/terraform.tfstate`" means the credentials travel with the plan artifact.

**The named-value ban is enforced at parse time**, before any backend work:

```
Error: Variables not allowed
  on main.tf line 8, in terraform:
   8:     bucket = var.state_bucket
Variables may not be used here.
```

!!! warning "The page overstates what a partial block needs"
    Its file method says "The partial configuration must have a backend block containing keys set to empty values", and its example writes `bucket = ""`, `key = ""`, and so on. **Not required.** A completely empty block took the whole configuration from a `.tfbackend` file:

    ```hcl
    terraform { backend "s3" {} }
    ```

    ```shell
    terraform init -backend-config="./config.s3.tfbackend"
    ```

    Init succeeded and the apply wrote `partial/terraform.tfstate` to the bucket. The empty-keys form is one valid style, not a requirement — which matches the page's *own* later statement that the minimum is "an empty backend configuration… to specify the backend type."

---
Related: [[tf-state-backends]] — the State-section counterpart; a backend's two responsibilities and the `state pull`/`state push` guards. · [[06-state-management]] — TID Ch6 for `-migrate-state`/`-reconfigure`, the backend catalogue, and the `cloud` block. · [[ot-early-eval-backend]] — OpenTofu lifts the named-values ban this page states. · [[infisical-terraform-secrets]] — the leak path this page documents at the source. · [[tf-state-workspaces]] — which backends can hold more than one state to migrate.
