# Terrakube Facts (source-derived)

Verified facts for **A9 — Multitenancy, teams & RBAC** and the open-source-platform half of
[[workspaces]]. Mined from the local checkout, because Terrakube's permission model is stated
loosely in its docs and precisely in its entity classes.

_Source: `C:\opt\learn\terraform\repos\terrakube`. The working tree is a detached HEAD at
`de53c946` (2026-07-07, the `2.32.2` release commit); `origin/main` is ahead at `695f4474`
(2026-08-15). Everything below was read from `origin/main` with `git show origin/main:<path>`,
which needs no checkout change. Unlike [[terragrunt-facts]] and [[terratest-facts]], the docs are
**not** in this repo — docs.terrakube.io is a separate site — so this note is code-derived, and each
claim is gated by the first stable tag containing the commit. Last verified: 2026-08-15._

## What it is, and how it is built

Apache-2.0, Java/Spring Boot, four deployable components plus an identity provider:

| Component | Role |
|---|---|
| `api` | the control plane — entities, RBAC, job scheduling, the TFE-compatible API |
| `executor` | runs `terraform`/`tofu` for a job |
| `registry` | private module and provider registry |
| `ui` | React front end |
| **Dex** (external) | authentication, federating Entra ID, Cognito, GitHub, SAML, LDAP |

The API is built on **Elide**, so entity classes carry their own authorization annotations
(`@ReadPermission`, `@CreatePermission`, …) and expose both a JSON:API surface at `/api/v1` and a
**GraphQL** surface at `/graphql/api/v1`. That is why the permission model is best read from the
entities: the rules are literally on the fields.

Persistence is **PostgreSQL** or **Azure SQL** (`DataSourceType` enum, plus H2 for tests), with
schema managed by Liquibase and AWS IAM database auth available. Job scheduling uses **Quartz in
clustered mode**, which the config file explains is required because otherwise every API replica
would fire every scheduled job independently. Artifact storage — state, plans, step output, job
context — has **AWS, Azure, GCP and local** implementations.

## Version state

| Tag | Date | Why it matters |
|---|---|---|
| `2.30.0` | 2026-02-26 | **RBAC v2** — TFC-style roles |
| `2.31.x` | — | **federated credentials** (OIDC trust for CI) |
| `2.32.0` | 2026-06-25 | **project-level team permissions** |
| `2.32.1` | 2026-07-03 | |
| `2.32.2` | 2026-07-07 | current stable |
| `2.33.0-beta.9` | 2026-08-11 | current beta |

Releases are frequent and each ships betas and release candidates, so pin a tag rather than
tracking `main`.

## The permission model — three tiers, roles plus custom booleans

!!! warning "This supersedes the older “organization-wide booleans” description"
    Earlier notes here recorded that Terrakube's permissions are organization-wide booleans, with no
    project tier, so multitenancy meant one organization per tenant. That was true of the pre-2.30
    model and is **no longer accurate**. Two changes landed since: **RBAC v2** in `2.30.0`
    (2026-02-26, commit `5cfc9638`, "implement RBAC v2 with granular permissions and TFC-style UI")
    and **project-level team permissions** in `2.32.0` (commit `e99e40c9`, 2026-05-17). A tenant can
    now be a project.

Three entities carry permissions, and all three have the same shape — a `role` string plus
fine-grained booleans:

| Entity | Scope | Boolean flags |
|---|---|---|
| `Team` | organization | `manageState`, `manageCollection`, `manageJob`, `manageWorkspace`, `manageModule`, `manageProvider`, `manageVcs`, `manageTemplate`, `planJob`, `approveJob` |
| `ProjectAccess` | project | `manageState`, `manageJob`, `manageWorkspace`, `planJob`, `approveJob` |
| `Access` | workspace | `manageState`, `manageJob`, `manageWorkspace`, `planJob`, `approveJob` |

`RbacV2Service` documents the roles in its own class comment, and they are deliberately HCP-shaped:

| Role | Meaning |
|---|---|
| `admin` | full access to everything |
| `write` | plan **and** apply, manage workspace settings |
| `plan` | queue plans, **not** apply |
| `read` | read-only |
| `custom` | fall back to the fine-grained booleans |

Two behaviours worth stating exactly, because they decide what a mis-set field does:

- **For a predefined role the booleans are ignored** — the role decides everything. Only `custom`
  consults `planJob`, `approveJob` and the rest.
- **A null or blank role normalizes to `custom`**, which is what keeps pre-2.30 data working.
  So a row created before roles existed keeps behaving exactly as it did.

Reading the per-permission switches shows the roles are not a simple ladder. `canManageWorkspace`
is true for `admin` and `write`; `canManageModule`, `canManageProvider`, `canManageVcs` and
`canManageTemplate` are true for **`admin` only** — `write` cannot touch the registry, VCS
connections or templates. That is a sharper separation than HCP's workspace roles, where module
publishing is a separate organization permission anyway.

The comparison to HCP that still holds: **`manageState` is its own toggle at every tier**, where
HCP's four fixed workspace roles all read full state.

### Who may create the tiers

Read straight off the Elide annotations. `Team`, `Organization`, `Agent`, `Action` and `Federated`
all carry `@CreatePermission(expression = "user is a superuser")`, so **team and organization
creation is superuser-only** — there is no "team admin who can make sub-teams". A superuser is a
member of the group named by `TERRAKUBE_ADMIN_GROUP` (default `TERRAKUBE_ADMIN`), a single
deployment-wide setting.

Workspace and project access rows are delegated instead: `Access` and `ProjectAccess` accept
`"user is a superuser OR team manage workspace access OR team limited manage workspace access"`,
which is the hook that lets a tenant administer its own workspace grants without holding superuser.

### Identity: the team name *is* the group claim

`DexGroupServiceImpl` resolves membership by walking the `groups` claim of the JWT and comparing
each entry to the team name with **string equality**. No mapping table, no normalization. So an
Entra group `TERRAKUBE_ADMIN` or a GitHub `MyGithubOrg:TERRAKUBE_ADMIN` must be reproduced exactly
as the team's name. Membership federates by construction — and a typo in a team name silently grants
nobody anything.

The service is `@ConditionalOnProperty(… name = "type", havingValue = "DEX")`, so group resolution
is pluggable; Dex is the shipped implementation.

## Federated credentials — OIDC trust for CI, no static token

Landed in **2.31.0** (`changelog-2.31.0-federated-credentials.xml`). A `Federated` record stores an
`issuerUrl`, an `audience`, and a list of `FederatedClaim` key/value pairs. `FederatedClaimMatcher`
requires **every** configured claim to match the presented token, and a claim whose token value is a
list matches if any element equals the expected value — which is exactly the shape of a GitHub
Actions token.

This is the piece worth carrying into **A9**: it is the open-source counterpart to HCP's dynamic
credentials, pointed the other way. Rather than the platform handing short-lived cloud credentials
to a run, it lets a CI job authenticate *to the platform* with a workload identity token instead of
a long-lived API token, conditioned on issuer, audience and claims. Creating one is superuser-only.

## Run isolation: the ephemeral executor is one Kubernetes Job per run

The strongest answer Terrakube has to the shared-runner problem that governs self-hosted designs.
Configuration from `application.properties`:

- `ExecutorEphemeralNamespace` (default `terrakube`), `ExecutorEphemeralImage`,
  `ExecutorEphemeralSecret` (comma-separated list), `ExecutorReplicas`.
- Per-job overrides set through workspace or global variables, not properties:
  `EPHEMERAL_CPU_REQUEST` / `EPHEMERAL_CPU_LIMIT`, `EPHEMERAL_MEMORY_REQUEST` (and limit),
  `EPHEMERAL_CONFIG_ENVFROM_CONFIG_MAP`, and `EPHEMERAL_CONFIG_POD_ANNOTATIONS`.

That last one matters for multitenancy: pod annotations on the generated job template are what
enable **Vault Agent Injector** and **GKE Workload Identity**, so each run's pod can obtain its own
credentials from the platform's identity system rather than reading a shared secret. Combined with a
per-tenant namespace and per-tenant service account, a run boundary becomes a pod boundary.

Nuance to keep honest: the pod runs a Terrakube-provided executor image and the tenant's own
Terraform code still executes inside it, so the Atlantis warning recorded in **A9** — that a plan can
exfiltrate credentials through an `external` data source or a malicious provider — still applies
*within* whatever identity that pod holds. Ephemeral pods shrink the blast radius to one run's
credentials; they do not make a plan safe to run with a shared identity.

## It speaks the HCP Terraform API, and can import from it

`RemoteTfeController` implements the TFE v2 API under **`/remote/tfe/v2/`**, which is what makes the
`cloud {}` block and the `remote` backend work against a self-hosted Terrakube. Implemented
endpoints include `ping`, `entitlement-set`, `capacity`, organizations, workspaces (read, create,
tag), workspace **lock** and **unlock**, `state-versions` and `current-state-version`,
`configuration-versions` (including the upload `PUT`), `runs` (create, list, read, run-events) and
the run actions **apply** and **discard**, plus `relationships/remote-state-consumers`.

Two consequences: CLI-driven runs work the way they do against HCP, and `terraform_remote_state`
consumers are modelled explicitly rather than left to bucket IAM — which is the gap **A9** flagged
for the pure-CI design.

Separately, `plugin/importer/tfcloud/` is an **HCP Terraform importer**: `TfCloudController` plus a
`WorkspaceService` handling workspace lists, variables, variable sets (`VarsetListResponse`,
`VarsetSummary`), tags, state versions, and a **sensitive-variable import preview**
(`SensitiveVariableImportPreview`, `ImportedSensitiveVariable`) so a migration can show what would
carry over before it runs. The package has been developed steadily through 2025–2026; treat it as
present on `2.32.x`, and do not read the earliest commit date as its introduction, since the tree
was renamed wholesale in `c0846e4f` ("Migrate to new package").

## Private registry

The `registry` component implements the module and provider protocols directly:
`ModuleWebServiceImpl`, `ProviderWebServiceImpl`, `ReadMeWebServiceImpl` and
`WellKnownWebServiceImpl` (service discovery), with provider publishing carrying GPG public keys.
Registry objects are governed by the `manageModule` / `manageProvider` permissions, which are
**`admin`-only** under a predefined role.

Compare with the finding recorded in **A9** for the pure-git route: with git module sources, module
visibility *is* repository visibility. Terrakube instead gives a real registry whose write side is
admin-gated, and whose read side follows the organization.

## Other surfaces worth knowing

- **Custom workflows / extensions.** Templates are first-class entities (`manageTemplate`), and the
  README positions OPA and Infracost as the canonical examples of wiring policy and cost checks into
  a workflow.
- **Notifications** ship with a bounded dispatch pool, an outbox poller with 90-day retention, and
  **SSRF protection on by default** — `io.terrakube.notification.ssrf.blockPrivateNetworks=true`
  blocks private, loopback and link-local destinations, with an opt-out for deployments that
  intentionally target an internal receiver. A small detail, but it is the kind of thing a
  self-hosted platform gets wrong.
- **Both binaries.** A `TofuJsonController` serves the OpenTofu release index (Redis-cached, with a
  configurable releases URL for air-gapped installs) alongside the Terraform one, so tool choice is
  per workspace.
- **VCS coverage:** GitHub (cloud and Enterprise), GitLab (CE and EE), Bitbucket, Azure DevOps.
- **Deployment:** Helm, Docker Compose, minikube, Gitpod, dev containers.

## Sources

- Local checkout: `C:\opt\learn\terraform\repos\terrakube`, working tree `de53c946` (`2.32.2`),
  `origin/main` `695f4474` (2026-08-15) for everything read here
- Permission model: `api/src/main/java/io/terrakube/api/rs/team/Team.java`,
  `…/rs/workspace/access/Access.java`, `…/rs/project/access/ProjectAccess.java`,
  `…/plugin/security/rbac/RbacV2Service.java`
- Identity: `…/plugin/security/groups/dex/DexGroupServiceImpl.java`, `…/rs/federated/`
- Platform config: `api/src/main/resources/application.properties`
- TFE compatibility: `…/plugin/state/RemoteTfeController.java`; importer:
  `…/plugin/importer/tfcloud/`
- Version gating: `git tag --contains` on `5cfc9638` (RBAC v2 → `2.30.0`) and `e99e40c9`
  (project access → `2.32.0`)
