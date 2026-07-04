# Terraform workspaces — verified facts

**Checked:** 2026-07-04

## "Workspace" is an overloaded term

- **CLI workspace** (`terraform workspace` command) — a named, separate *state instance* living inside **one backend and one config directory**. Same code, same backend, just a different slot of state. Anyone with backend access can reach every workspace in it.
- **HCP Terraform workspace** — a much richer unit: its own Terraform configuration, its own variable values, state data, run history, and settings/RBAC. Closer to "a whole deployment," and the unit HCP Terraform's role-based access control is built around.

They are not the same concept. TID Ch1 §1.2.6's intro definition ("one deployment of a codebase against a specific backend and inputs, like one installation of a program") describes the general *deployment* idea, which lines up with the HCP notion — not the narrower CLI workspace.

## CLI workspaces are NOT for long-lived dev/staging/prod

This is HashiCorp's own guidance plus broad 2026 community consensus:

- **Coarse access control** — anyone who can reach the backend can reach *all* CLI workspaces in it. Dev and prod end up sharing the same powerful credentials, so a mistake in one can obliterate another. One S3-key-prefix policy slip gives a dev prod access.
- **State isolation only, not code/config isolation** — every workspace runs identical code; workspaces isolate state, not the configuration or blast radius. Drift between environments hides inside one config.
- **HashiCorp docs:** "workspaces alone are not a suitable tool for system decomposition" — each subsystem / environment should get its own separate configuration and backend, especially across staging vs. production or across teams, where the backend belongs to that deployment with its own credentials and access controls.

### What CLI workspaces ARE good for

Short-lived, throwaway copies of a stack: a workspace per PR / feature branch / preview, destroyed on merge.

### Recommended pattern for long-lived environments

Directory-per-environment (each env its own folder, its own backend/state), or HCP Terraform workspaces with per-workspace RBAC. This is the subject of learning-path topic **A7 — Multi-environment & multi-account patterns**.

Sources: [HCP Terraform workspaces](https://developer.hashicorp.com/terraform/cloud-docs/workspaces), [Terraform CLI workspaces](https://developer.hashicorp.com/terraform/cli/workspaces), [State: Workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces), plus 2026 practitioner writeups (Scalr, Gruntwork, OneUptime).
