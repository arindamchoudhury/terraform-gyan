# Terraform workspaces — verified facts

**Checked:** 2026-07-04

## "Workspace" is an overloaded term

- **CLI workspace** (`terraform workspace` command) — a named, separate *state instance* living inside **one backend and one config directory**. Same code, same backend, just a different slot of state. Anyone with backend access can reach every workspace in it. Part of the CLI, so it exists in **open-source OpenTofu** (`tofu workspace`) too, not just Terraform.
- **HCP Terraform workspace** — a much richer unit: its own Terraform configuration, its own variable values, state data, run history, and settings/RBAC. Closer to "a whole deployment," and the unit HCP Terraform's role-based access control is built around. **Proprietary, not open source** — it's a feature of the HCP Terraform hosted SaaS platform (and its self-hosted twin, Terraform Enterprise), both closed-source and paid. There is no open-source equivalent of an HCP workspace; the closest open option is a directory-per-env layout with your own remote backend.

They are not the same concept, and they don't even share a license. TID Ch1 §1.2.6's intro definition ("one deployment of a codebase against a specific backend and inputs, like one installation of a program") describes the general *deployment* idea, which lines up with the HCP notion — not the narrower CLI workspace.

## Licensing of the layers (so the two workspace types don't blur)

- **Terraform CLI** — source-available, BSL 1.1 since v1.6 (not OSI open source). **OpenTofu CLI** — open source, MPL 2.0. CLI workspaces ship in both.
- **HCP Terraform** platform (workspaces, remote execution, RBAC, private registry, Sentinel policy, Stacks) — **proprietary SaaS**, run by HashiCorp (an IBM company since Dec 2024). **Terraform Enterprise** is the same platform self-hosted, also proprietary.

Source (licensing): [Terraform editions](https://developer.hashicorp.com/terraform/intro/terraform-editions), plus the OpenTofu-vs-Terraform notes in `version-facts.md`.

## CLI workspaces are NOT for long-lived dev/staging/prod

This is HashiCorp's own guidance plus broad 2026 community consensus:

- **Coarse access control** — anyone who can reach the backend can reach *all* CLI workspaces in it. Dev and prod end up sharing the same powerful credentials, so a mistake in one can obliterate another. One S3-key-prefix policy slip gives a dev prod access.
- **State isolation only, not code/config isolation** — every workspace runs identical code; workspaces isolate state, not the configuration or blast radius. Drift between environments hides inside one config.
- **HashiCorp docs:** "workspaces alone are not a suitable tool for system decomposition" — each subsystem / environment should get its own separate configuration and backend, especially across staging vs. production or across teams, where the backend belongs to that deployment with its own credentials and access controls.

### What CLI workspaces ARE good for

Short-lived, throwaway copies of a stack: a workspace per PR / feature branch / preview, destroyed on merge.

### Recommended pattern for long-lived environments

Directory-per-environment (each env its own folder, its own backend/state), or HCP Terraform workspaces with per-workspace RBAC. This is the subject of learning-path topic **A7 — Multi-environment & multi-account patterns**.

## Terragrunt — the open-source way to do env isolation + DRY

If HCP Terraform workspaces are the *proprietary* answer to multi-environment management, **Terragrunt** (Gruntwork, open source) is the *open* one. It's a thin orchestration wrapper over Terraform **or** OpenTofu — so the whole stack stays open source.

- **Isolation by directory, not by active workspace.** Each environment is its own folder with its own `backend` block, credentials, and state. Isolation is enforced by where the file lives on disk, not by remembering which CLI workspace is selected — which removes the exact "wrong workspace active → prod blast radius" failure mode that sinks CLI workspaces for dev/staging/prod.
- **DRY.** Define backend config and shared inputs once, reuse across dev/staging/prod instead of duplicating. `dependency` blocks order cross-state dependencies; `run --all` (formerly `run-all`) applies across many units with dependency ordering and blast-radius safeguards.
- **Recommended layout:** separate reusable Terraform modules from environment-specific "live" config; organize live by account → region → stack, environment-first (`environments/dev/networking`, not `networking/dev`) so `run --all` stays predictable and blast radius is one environment at a time.
- **Version:** Terragrunt **1.0 shipped 2026-03-30** — first release with an explicit backwards-compatibility commitment.

So the fully open-source stack for real environment isolation is: **OpenTofu (or Terraform CLI) + directory-per-env + Terragrunt** for the DRY/orchestration glue — no HCP Terraform required. In the learning path this is topic **E4 — Large-scale state & repo architecture** (the env-layout problem it addresses is **A7**).

Sources: [Terragrunt docs](https://terragrunt.gruntwork.io/docs/), [Spacelift — Terragrunt vs Terraform](https://spacelift.io/blog/terragrunt-vs-terraform), [Gruntwork — multiple environments with Terragrunt](https://www.gruntwork.io/blog/how-to-manage-multiple-environments-with-terraform-using-terragrunt), checked 2026-07-04.

Sources: [HCP Terraform workspaces](https://developer.hashicorp.com/terraform/cloud-docs/workspaces), [Terraform CLI workspaces](https://developer.hashicorp.com/terraform/cli/workspaces), [State: Workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces), plus 2026 practitioner writeups (Scalr, Gruntwork, OneUptime).
