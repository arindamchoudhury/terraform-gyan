# State (overview)

> **Source:** [developer.hashicorp.com/terraform/language/state](https://developer.hashicorp.com/terraform/language/state)
> **Added:** 2026-07-29
> **Source updated:** undated language reference; captured 2026-07-29 against v1.15.x (latest)
> **Tags:** state, tfstate, backends, state-locking, terraform-state-cli, json-output, import
> **Type:** documentation

*Developer › Terraform › Configuration Language › State › Overview · v1.15.x*

The landing page for the sidebar's **State** group. Short and definitional. It sets up the sub-pages (Purpose, Manage state in remote backends, Refactor state, Remove a resource from state, Locking, Workspaces, Remote state, plus the `removed` and `moved` block references), none of which are captured yet apart from [[tf-block-removed]].

Three claims carry the page.

**What state is for.** Terraform stores state about each workspace's managed infrastructure and configuration. It uses that state to map real-world resources to configuration, track metadata, and improve performance on large infrastructures. Before any operation, Terraform refreshes to update state against the real infrastructure.

**The primary purpose is bindings.** The page states it precisely: state stores "bindings between objects in a remote system and resource instances declared in your configuration." When Terraform creates a remote object, it records that object's identity against a particular resource instance, then updates or deletes that object on future configuration changes. This is the same argument TID Ch6 §6.1.1 makes as "real-world linkage."

## Storing state

By default each workspace's state is a local file `terraform.tfstate`, with the previous state kept as `terraform.tfstate.backup`. Local storage needs no configuration. It also blocks collaboration and loses the workspace's state if the file is lost. HashiCorp recommends HCP Terraform or a remote backend.

!!! danger "Do not put state in version control"
    > "Avoid storing your state in a version control system or other storage solution that does not support Terraform state locking and secure access control, because doing so can result in data loss or exposure of secrets stored in the state file."

    Two distinct failure modes in one sentence. No locking means concurrent writes corrupt or lose state. No access control means every secret in the file is readable by everyone with repo access. See [[tf-manage-sensitive-data]] for why the secrets are there in the first place, and [[infisical-terraform-secrets]] for the `grep`-proven leak.

## Inspection and modification

State is a JSON text file. **Do not edit it directly.** Use the `terraform state` command for basic modifications ([[tf-cli-commands]]).

Two reasons the page gives for going through the CLI:

- The state commands' usage and output are structured to be friendly to Unix tools such as `grep` and `awk`.
- The CLI insulates you from format changes. The project keeps the CLI working while the state format underneath shifts.

**The one-to-one rule.** Terraform expects a one-to-one mapping between configured resource instances and remote objects. Normally Terraform guarantees it, because Terraform is the one creating each object and recording its identity, or destroying an object and removing its binding.

You break that guarantee whenever you add or remove bindings by other means — `terraform import` of an externally-created object, or `terraform state rm` to make Terraform "forget" one. After either, enforcing the rule is **your** job: manually delete the object you asked Terraform to forget, or re-import it to bind it to some other resource instance. Otherwise you get an orphaned real resource nobody manages, or two instances pointed at one object.

## Format

State snapshots are JSON. New Terraform versions are "generally backward compatible" with snapshots produced by earlier versions. But the format itself is subject to change, so software that parses or modifies state directly needs ongoing maintenance as the format evolves.

!!! tip "Parse the JSON integration points, not the state file"
    The page names the supported alternatives:

    - `terraform output -json` — the full set of root module output values, or one named output, from the latest state snapshot.
    - `terraform show -json` — the latest state snapshot in full, and also saved plan files, which include a copy of the prior state at the time the plan was made.

    The recommended automation pattern is to run one of these immediately after a successful `terraform apply`, then store the result as an artifact of the run. Other software consumes the artifact without needing to run Terraform at all.

    This is also the sanctioned way to *read* another configuration's state from the CLI, and it's a lighter grant than [[tf-remote-state-data]], which requires read access to the whole snapshot.

---
Related: [[tf-remote-state-data]] — the language-level way to read another state's outputs; this page's `-json` commands are the CLI-level equivalent. [[tf-manage-sensitive-data]] — why "exposure of secrets stored in the state file" is a real risk and not a hypothetical. [[tf-block-removed]] — one of this section's sibling pages, the safe way to drop a resource without `state rm`. [[tf-cli-commands]] — where `terraform state`, `output`, and `show` sit in the command index. [[infisical-terraform-secrets]] — demonstrates the plaintext-secret problem this page warns about.
