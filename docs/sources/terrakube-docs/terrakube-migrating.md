# Migrating to Terrakube

> **Source:** [docs.terrakube.io/user-guide/migrating-to-terrakube](https://docs.terrakube.io/user-guide/migrating-to-terrakube)
> **Added:** 2026-08-18
> **Source updated:** page footer reads "Last updated 9 months ago" (≈ November 2025); captured 2026-08-18
> **Tags:** terrakube, state-migration, remote-backend, cloud-block, hostname, state-push, workspace-importer, self-hosted, open-source
> **Type:** documentation

The page that makes Terrakube a **state option** rather than only a platform comparison. Terrakube implements the TFE v2 API (`RemoteTfeController` at `/remote/tfe/v2/`, see [[terrakube-facts]]), so the two blocks Terraform already has for HCP point at a self-hosted instance instead.

Two migration paths are offered: the **Terraform CLI**, workspace by workspace, or a **Workspaces Importer** wizard inside Terrakube that pulls from Terraform Cloud or Enterprise.

## The one argument that does the work: `hostname`

Both block forms are identical to their HCP versions apart from a single extra argument, and the page says so twice — *"It's crucial to include the `hostname` parameter"*.

```hcl
terraform {
  backend "remote" {
    hostname     = "8080-azbuilder-terrakube-q8aleg88vlc.ws-us92.gitpod.io"
    organization = "migrate-org"

    workspaces {
      name = "migrate-state"
    }
  }
}
```

```hcl
terraform {
  cloud {
    hostname     = "8080-azbuilder-terrakube-q8aleg88vlc.ws-us92.gitpod.io"
    organization = "migrate-org"
    workspaces {
      name = "migrate-state"
    }
  }
}
```

Without `hostname` both default to `app.terraform.io`, which is why the omission is the first thing that goes wrong. [[tut-cloud-migrate]] never needs the argument for exactly that reason.

## From local state

```shell
terraform state pull > tf.state
```

Then add the block above, and:

```shell
terraform login 8080-azbuilder-terrakube-q8aleg88vlc.ws-us92.gitpod.io
```

```shell
terraform init
```

```shell
terraform state push tf.state
```

Note the shape: **`state push` rather than the `init` migration prompt.** Where [[tut-cloud-migrate]] answers a question at `init` and lets Terraform copy the snapshot, this path pulls the state out by hand and pushes it into an initialized empty workspace. The [[tf-state-backends]] guards still apply to that push — differing lineage or a higher destination serial is rejected.

> "Once the migration process is completed you should see the terraform state in your storage backend (azure, aws, gcp or **minio**) depending of your configuration"

That sentence is the part worth keeping. Terrakube does not store state itself; it fronts an object store you own — including **MinIO**, which is what makes a fully local, no-cloud-account deployment possible.

## From HCP Terraform

Log in to *both* hosts, then let Terraform migrate:

```shell
terraform login app.terraform.io
```

```shell
terraform login 8080-azbuilder-terrakube-q8aleg88vlc.ws-us92.gitpod.io
```

```shell
terraform init -migrate-state
```

Here the ordinary `-migrate-state` path from [[tf-backend-configure]] does the work, because both sides speak the same API. The page also asks you to confirm a `.terraform.rc` exists in your home directory, with `plugin_cache_dir` and `disable_checkpoint` set.

## The Workspaces Importer

A wizard in the Terrakube UI: *Workspaces List › Import Workspaces*. Pick the platform (Terraform Cloud or Terraform Enterprise), pick the workflow type — **one run of the importer per workflow type** — connect a VCS provider for the version-control workflow, and supply API keys, plus the host URL for Enterprise.

What it replicates, in the page's own list:

> "name, description, Terraform version, execution mode, variables, tags and **the current state**"

So it carries the workspace configuration as well as the snapshot, which the CLI path does not. [[terrakube-facts]] adds what the docs leave out: the importer package includes a **sensitive-variable import preview**, so you can see which sensitive values would carry over before running it.

!!! warning "📌 The examples are a Gitpod URL, and the page is nine months old"
    Every `hostname` in this page is a disposable Gitpod workspace address from the authors' own demo. Substitute your instance. The footer reads *"Last updated 9 months ago"* (≈ November 2025), so it predates the **2.30.0 RBAC v2** and **2.32.0 project-level permissions** work recorded in [[terrakube-facts]] — nothing here contradicts those, but the surrounding product has moved.

---
Related: [[terrakube-facts]] — the source-derived, version-gated account of what Terrakube implements, including the TFE endpoints that make these blocks work. · [[tut-cloud-migrate]] — the same job against HCP, where `hostname` is unnecessary and `init` does the copy. · [[tf-backend-configure]] — `-migrate-state`, and the `backend`/`cloud` exclusion that applies here too. · [[tf-state-backends]] — the lineage and serial guards on the `state push` this page uses. · [[gitlab-tf-state]] — the other self-hostable answer, which speaks `http` instead of the TFE API.
