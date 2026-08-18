# OpenID Connect in GitHub Actions

> **Source:** [docs.github.com/en/actions/concepts/security/openid-connect](https://docs.github.com/en/actions/concepts/security/openid-connect)
> **Added:** 2026-08-18
> **Source updated:** undated concept page; captured 2026-08-18
> **Tags:** github-actions, oidc, jwt, short-lived-credentials, ci-cd, trust-policy, abac, dependabot, secrets
> **Type:** documentation

Read this as the **GitHub answer to remote state**, which is an indirect one. GitHub stores no Terraform state: the backend catalogue in [[tf-backend-configure]] has no GitHub entry, and unlike [[gitlab-tf-state]] there is no `http`-protocol state service behind `github.com`. So state on GitHub means state in **S3, GCS or Azure Blob**, and the only GitHub-specific question left is how a workflow authenticates to that bucket without a long-lived key in repository secrets. This page is that mechanism.

## The problem being removed

> "These credentials are usually stored as a secret in GitHub, and the workflow presents this secret to the cloud provider every time it runs. However, using hardcoded secrets requires you to create credentials in the cloud provider and then duplicate them in GitHub as a secret."

Three benefits claimed, and the third is the one that matters for a Terraform pipeline:

- **No cloud secrets** — nothing to duplicate, nothing to rotate by hand.
- **Authentication and authorization management** — access is governed by the cloud provider's own authN/authZ, not by who can read a repository secret.
- **Rotating credentials** — *"your cloud provider issues a short-lived access token that is only valid for a single job, and then automatically expires."*

## How it works

The page's four steps, compressed:

1. Establish an **OIDC trust relationship** in the cloud provider, naming which workflows may request a token for a given role.
2. On every job, GitHub's OIDC provider **auto-generates a token**.
3. A step requests that token and presents it to the cloud provider as proof of identity.
4. The provider validates the claims and returns a **short-lived access token valid only for the duration of the job**.

The trust is one-directional and lives on the cloud side. Nothing in the repository holds a credential.

## The token, and why the claims are the security boundary

Each job gets its own JWT. The claims are what a trust policy matches on:

```json
{
  "jti": "example-id",
  "sub": "repo:octo-org/octo-repo:environment:prod",
  "environment": "prod",
  "aud": "https://github.com/octo-org",
  "ref": "refs/heads/main",
  "repository": "octo-org/octo-repo",
  "repository_owner": "octo-org",
  "repository_visibility": "private",
  "run_id": "example-run-id",
  "runner_environment": "github-hosted",
  "workflow": "example-workflow",
  "job_workflow_ref": "octo-org/octo-automation/.github/workflows/oidc.yml@refs/heads/main",
  "iss": "https://token.actions.githubusercontent.com",
  "nbf": 1632492967,
  "exp": 1632493867,
  "iat": 1632493567
}
```

> "To validate the token, the cloud provider checks if the OIDC token's **subject and other claims are a match for the conditions that were preconfigured** on the cloud role's OIDC trust definition."

!!! danger "Registering the provider is authentication; the conditions are authorization"
    The path already states this from TID Ch 8 §8.5 under **A6**: without trust-policy conditions scoping to *your* repository and workflow, any other customer of the same IdP can assume your role. This page is where the claims you scope on come from. `sub` is the usual one, but `environment`, `ref`, `repository_visibility` and `job_workflow_ref` are all available, and `job_workflow_ref` is the one that pins a **reusable workflow** rather than a repository.

!!! note "📌 The `sub` format changed for new repositories"
    > "The `sub` claim in this example uses the previous format. Repositories created after **July 15, 2026** use an **immutable default subject format that includes owner and repository IDs** (not available on GitHub Enterprise Server)."

    So a trust policy copied from an older repository's setup may not match a newly created one. Worth checking before assuming an existing `sub` condition is portable.

## Attribute-based access control from repository properties

Newer, and useful for a fleet of Terraform repositories. An organization or enterprise admin defines **custom properties** (`business_unit`, `data_classification`, `environment_tier`), marks which are included in OIDC tokens, and every token from a repository carrying that property gains a **`repo_property_*`** claim:

```json
{
  "sub": "repo:my-org/my-repo:ref:refs/heads/main",
  "repo_property_business_unit": "payments",
  "repo_property_workspace_id": "ws-abc123"
}
```

> "No workflow-level configuration changes are required."

The cloud trust policy then keys on metadata rather than a hard-coded list of repositories — which is what makes "every repository tagged `payments` may write the payments state bucket" expressible as one policy instead of one per repository. Enabled through the org/enterprise Actions OIDC settings UI or `POST /orgs/{org}/actions/oidc/customization/properties/repo`.

## Also

Custom actions authenticate with `getIDToken()` from the Actions toolkit, or a `curl` call. Dependabot can use OIDC for private registries hosted on AWS CodeArtifact, Azure DevOps Artifacts or JFrog Artifactory — any registry using username/password auth.

---
Related: [[gitlab-tf-state]] — the other forge's answer, which is to store the state itself rather than to hand you an identity. · [[bitbucket-pipelines-oidc]] — the same mechanism on Bitbucket, with a smaller claim set. · [[tf-backend-configure]] — the backend catalogue that has no GitHub entry, which is why this page is the GitHub half of remote state. · [[tf-manage-sensitive-data]] — what still lands in the state bucket once the credential problem is solved.
