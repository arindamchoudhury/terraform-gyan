# GitLab Docs

Notes from [docs.gitlab.com](https://docs.gitlab.com/). Captured for the parts of GitLab that are a **Terraform/OpenTofu seam** — state storage, the CI/CD component that drives runs — not for GitLab generally.

**Source type:** official product documentation
**Nav mirrored from:** the docs sidebar rendered on the page (*Use GitLab › Manage your infrastructure › Infrastructure as Code*), which is **rung 3**. `fetch_nav.py` resolves rung 3 on this site to the **version selector and top-level product nav** instead (19.3 upcoming / 19.2 current), so it is not the signal to use here.

## Infrastructure as Code

| Page | Added | File |
|---|---|---|
| OpenTofu state (GitLab-managed Terraform/OpenTofu state) | 2026-08-18 | [gitlab-tf-state](gitlab-tf-state.md) |
