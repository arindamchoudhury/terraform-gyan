# `local` backend

> **Source:** [developer.hashicorp.com/terraform/language/backend/local](https://developer.hashicorp.com/terraform/language/backend/local)
> **Added:** 2026-07-30
> **Source updated:** undated language reference; captured 2026-07-30 against v1.15.x (latest)
> **Tags:** backend, local-backend, workspace-dir, state-flag, backup, legacy-flags, terraform_remote_state
> **Type:** documentation

*Developer › Terraform › Configuration Language › Backends › local · v1.15.x*

The default backend, and the first per-backend reference captured. Short definition, two arguments, then a long legacy section that is the real content of the page.

**Kind: Enhanced.** One line: it "stores state on the local filesystem, **locks that state using system APIs**, and **performs operations locally**." The locking claim matters — [[tf-state-locking]] says not all backends lock, and this confirms the default one does, without a lock service of any kind.

## Configuration

```hcl
terraform {
  backend "local" {
    path = "relative/path/to/terraform.tfstate"
  }
}
```

| Argument | Notes |
|---|---|
| `path` | Optional. Path to the tfstate file. Defaults to `terraform.tfstate` relative to the root module. |
| `workspace_dir` | Optional. "The path to non-default workspaces." |

`workspace_dir` is the knob behind the `terraform.tfstate.d` directory that [[workspaces]] traces to `DefaultWorkspaceDir` in the local backend source. The default workspace keeps its file at `path`; every other workspace lives under this directory.

It also works as a `terraform_remote_state` source, which is how one local configuration reads another's outputs:

```hcl
data "terraform_remote_state" "foo" {
  backend = "local"

  config = {
    path = "${path.module}/../../terraform.tfstate"
  }
}
```

The security caveat on that data source is unchanged by the backend being local — reading one output means read access to the whole snapshot ([[tf-remote-state-data]]).

## The legacy `-state` / `-state-out` / `-backup` flags

The page opens this section by disowning it: "This section describes legacy features that we've preserved for backward compatibility but that we no longer recommend."

They apply to configurations with a `backend "local"` block **or no backend block at all**, on "most commands that either read or write state snapshots."

| Flag | Effect |
|---|---|
| `-state=FILENAME` | Overrides the state filename when **reading** the prior snapshot. |
| `-state-out=FILENAME` | Overrides the state filename when **writing** new snapshots. |
| `-backup=FILENAME` | Overrides the filename the local backend would otherwise choose dynamically for backups. |

Two defaulting rules, both of which bite:

- **`-state` without `-state-out`** → the same filename is used for both, "which means Terraform will overwrite the input file if it creates a new state snapshot."
- **`-state` without `-backup`** → the `-state` filename becomes a **prefix** for the generated backup filename. `-backup=-` (a bare ASCII dash) disables backup creation entirely.

!!! warning "These flags disable workspace-aware filenames"
    > "Because these old workflows predate the introduction of the possibility of multiple workspaces, setting them **overrides Terraform's usual behavior of selecting a different state filename based on the selected workspace**. If you use all three of these options then the selected workspace has no effect on which filenames Terraform will select for state files."

    So the flags and workspaces are mutually incompatible in practice: with all three set, `terraform workspace select` changes nothing about where state is read or written, and keeping workspace states distinct becomes your job. This is a sharper interaction than [[tf-state-workspaces]] implies by simply listing Local as workspace-capable.

They exist for pre-remote-state wrapper scripts — "users would write wrapper scripts that fetch prior state before running Terraform and then save the new state after Terraform exits", with all three paths pointing into a throwaway directory for one operation.

**They have no effect on any other backend type.** That is the detail to carry into [[tf-state-refactor]]: its legacy `terraform state mv -state/-state-out` path works on state *files* you have already pulled to disk, which is why the flags apply there at all.

The page's recommendation is unambiguous, and explicitly covers CI:

> "We do not recommend using these options in new systems, **even if you are running Terraform in automation**. Instead, select a different backend which supports remote state and configure it within your root module, which ensures that everyone working on your configuration will automatically retrieve and store state in the correct shared location without any special command line options."

---
Related: [[tf-backend-configure]] — how the block itself is written and initialized; `local` is the default it names. · [[tf-state]] — where `terraform.tfstate` and `terraform.tfstate.backup` come from, the files `path` and `-backup` rename. · [[tf-state-workspaces]] — lists Local among backends supporting named workspaces; this page shows the flags that switch that off. · [[workspaces]] — the `terraform.tfstate.d` layout `workspace_dir` overrides. · [[tf-state-refactor]] — uses `-state`/`-state-out` for its legacy cross-configuration move. · [[tf-state-locking]] — the locking this backend provides through system APIs.
