# GitLab-managed Terraform/OpenTofu state

> **Source:** [docs.gitlab.com/user/infrastructure/iac/terraform_state](https://docs.gitlab.com/user/infrastructure/iac/terraform_state/)
> **Added:** 2026-08-18
> **Source updated:** undated (GitLab docs carry a collapsed "History" block rather than a date); captured 2026-08-18
> **Tags:** gitlab, state, http-backend, state-locking, ci-cd, permissions, glab, opentofu, secrets, disaster-recovery
> **Type:** documentation

The only one of the three big forges that stores Terraform state itself. It is not a new backend type: GitLab implements the REST protocol in [[tf-backend-http]], so the configuration is `backend "http" {}` pointed at a project API path. Every tier has it — *"Tier: Free, Premium, Ultimate · Offering: GitLab.com, GitLab Self-Managed, GitLab Dedicated"*.

The docs are now written **OpenTofu-first** (the sidebar entry is "OpenTofu state", the wrapper CLI is `gitlab-tofu`, and `gitlab-terraform` survives as the older name), while the feature and the page title still cover both.

The pitch, in the page's own list: encryption at rest, built-in versioning, **the GitLab permission model instead of a second authentication system**, and access from both CI/CD jobs and a local machine.

## Configure it

The backend block carries nothing at all:

```hcl
terraform {
  backend "http" {
  }
}
```

Everything else comes from the CI job — GitLab's OpenTofu CI/CD component generates `gitlab-tofu init`, `validate` and `plan`, with `apply` as a manual job.

The equivalent by hand, which is also what the migration path uses:

```shell
PROJECT_ID="<gitlab-project-id>"
TF_USERNAME="<gitlab-username>"
TF_PASSWORD="<gitlab-personal-access-token>"
TF_ADDRESS="https://gitlab.com/api/v4/projects/${PROJECT_ID}/terraform/state/old-state-name"

tofu init \
  -backend-config=address=${TF_ADDRESS} \
  -backend-config=lock_address=${TF_ADDRESS}/lock \
  -backend-config=unlock_address=${TF_ADDRESS}/lock \
  -backend-config=username=${TF_USERNAME} \
  -backend-config=password=${TF_PASSWORD} \
  -backend-config=lock_method=POST \
  -backend-config=unlock_method=DELETE \
  -backend-config=retry_wait_min=5
```

Read that against [[tf-backend-http]]'s defaults and the shape of the integration is visible. The state lives at `…/projects/<ID>/terraform/state/<NAME>`, the lock is the **same path plus `/lock`**, and the protocol's default `LOCK`/`UNLOCK` verbs are replaced by `POST`/`DELETE`. `retry_wait_min=5` is a GitLab-specific nicety, not a protocol requirement.

!!! warning "Use environment variables in CI, not `-backend-config`"
    > "To customize your `init` and override the OpenTofu configuration, use environment variables instead of the `init -backend-config=...` approach. When you use `-backend-config`, the configuration is: **Cached in the output of the plan command. Usually passed forward to the apply command.** This configuration can lead to problems like being unable to lock the state files in CI jobs."

    So GitLab reaches the same conclusion as [[tf-backend-configure]] and [[tf-backend-http]] — backend config is copied into `.terraform/` and into plan files — but names a **functional** consequence rather than only a disclosure one. The `TF_HTTP_*` variables are the fix.

## Permissions are the access-control model

This is what a forge-native backend buys, and the page states the levels twice:

| Action | Minimum role |
| --- | --- |
| Lock, unlock, write (`tofu apply`) | **Maintainer** or Owner |
| Read (`tofu plan -lock=false`) | **Developer**, Maintainer or Owner |
| Read state in another project as a data source | Developer, Maintainer or Owner |
| Get a state version by serial | Developer, Maintainer or Owner |
| Remove a state version, remove a state, lock or unlock | **Maintainer** or Owner |

There is no bucket policy and no IAM here. "Who can apply" is the same question as "who is a Maintainer", which is the whole appeal — and, as the next callout shows, the whole problem.

!!! danger "Every Developer can download the state, which means every secret in it"
    > "Terraform state files might contain sensitive information such as passwords private keys, API tokens, and database connection strings. In GitLab, **any user with the Developer role or higher can download and view Terraform state files** for projects where they are members."

    The page's mitigations, in its own order of preference:

    - **Ultimate only** — a **custom role** that copies Developer but excludes the **`admin_terraform_state`** permission. GitLab is explicit that Premium and Free have no equivalent: those customers *"do not have access to this mitigation option"*.
    - **OpenTofu users** — turn on state and plan encryption, which the OpenTofu CI/CD component supports natively. That is [OpenTofu's State and Plan Encryption](https://opentofu.org/docs/language/state/encryption/), and this is a concrete deployment of it: on Terraform there is no equivalent, so a Terraform-on-GitLab project simply keeps a readable-by-Developers state.
    - Everyone else — restrict project membership, keep state in a **separate project** with its own member list, reference secrets from Vault or Secrets Manager instead of storing them, and audit who holds Developer.

    One correction the page makes to a common belief, worth quoting because it matches [[tf-manage-sensitive-data]]: marking a variable `sensitive` *"prevents values from appearing in the CLI output and plan files, though they remain in the state file."*

!!! warning "Plan artifacts are readable by Guests by default"
    > "OpenTofu `plan.json` or `plan.cache` files are not encrypted and might contain sensitive data like passwords, access tokens, or certificates. By default, users with the **Guest** role can access your plan files."

    Fixes named: `access: 'developer'` on the artifact, disable public pipelines, encrypt plan output, make the project private. Same hazard class as never committing a plan file.

## Disaster recovery — the bootstrap trap

The one section that has no counterpart in any cloud-backend page, and the reason not to put *everything* here:

> "OpenTofu state files are encrypted with the **Lockbox** Ruby gem when at rest on disk and in object storage. The encryption uses a key derived from the **`db_key_base`** application setting. Because of this encryption approach, **the instance must be available to decrypt a state file**."

> "If GitLab hosts OpenTofu modules or other dependencies required to bootstrap itself, these dependencies become inaccessible when the instance is offline."

So the state for the infrastructure that runs GitLab must not live in that GitLab. The page's advice: host or back up dependencies separately, or use a second instance with no shared points of failure.

Self-Managed also has two prerequisites: an administrator must set up state storage, and the project must have **Settings › General › Visibility, project features, permissions › Infrastructure** switched on.

## Migrating in

The migration is ordinary Terraform — [[tf-backend-configure]]'s `-migrate-state` path — done from a local terminal rather than from CI. Initialize against the old backend first, then re-init against the new address:

```shell
glab opentofu init <old_state_name>
```

```shell
glab opentofu init <new-state-name> -- -migrate-state
```

The prompt is the familiar one, and here both sides are `http`:

```
  Pre-existing state was found while migrating the previous "http" backend to the
  newly configured "http" backend. No existing state was found in the newly
  configured "http" backend. Do you want to copy this state to the new "http"
  backend? Enter "yes" to copy and "no" to start with an empty state.
```

For a local working copy against an existing state, the UI hands you the whole command: *Operate › Terraform states*, then **Copy Terraform init command** from the row's actions menu.

!!! note "Not on clustered deployments with local storage"
    > "On clustered deployments of GitLab, you should not use local storage. A **split state** can occur across nodes, making subsequent OpenTofu executions inconsistent. Instead, use a remote storage resource."

    This is about how the GitLab instance stores what it holds, not about your backend block — an operator-side prerequisite that a user of the feature cannot see.

## Reading another project's state

The `http` data source with basic auth:

```hcl
data "terraform_remote_state" "example" {
  backend = "http"

  config = {
    address  = var.example_remote_state_address
    username = var.example_username
    password = var.example_access_token
  }
}
```

`address` is `https://gitlab.com/api/v4/projects/<TARGET-PROJECT-ID>/terraform/state/<TARGET-STATE-NAME>`. The credential pair differs by caller: a **personal access token with `api` scope** alongside your username, or — in CI — the literal username **`gitlab-ci-token`** with `${CI_JOB_TOKEN}` as the password. GitLab suggests putting the values in an unversioned `example.auto.tfvars`.

The full-state access warning in [[tf-remote-state-data]] applies unchanged, and it is sharper here: the credential that reads one output is a token that can read the whole state through the same API.

## Operating on state without Terraform

`glab` wraps the state API, so the surgery that needs `terraform state push` elsewhere is a CLI call here:

```shell
glab opentofu state download <your_state_name> <your_serial>
glab opentofu state delete   <your_state_name> <version_serial_number>
glab opentofu state lock     <your_state_name>
glab opentofu state unlock   <your_state_name>
```

Versions are addressed by **serial**, which is the same counter [[ch09-state-fundamentals]] measures and [[tut-cloud-state-api]] increments by hand against HCP. Each command also has a `curl` and (for some) a UI equivalent.

`TF_PLAN_CACHE` renames the plan file that `gitlab-tofu plan` writes; the page warns that `-out=<filename>` is overridden by the wrapper and must not be used.

---
Related: [[tf-backend-http]] — the protocol GitLab implements; read it first, this page is one deployment of it. · [[tf-backend-configure]] — `-migrate-state`, partial configuration, and the credential-leak warning restated here with a functional consequence. · [[tf-remote-state-data]] — the cross-project read, and why the token that does it sees everything. · [OpenTofu State and Plan Encryption](https://opentofu.org/docs/language/state/encryption/) — the mitigation GitLab recommends for state secrets, available only to OpenTofu users. · [[tf-manage-sensitive-data]] — `sensitive` hides output, not state, which this page confirms. · [[tut-cloud-migrate]] — the same migration against HCP Terraform, for comparison of what a managed backend asks of you.
