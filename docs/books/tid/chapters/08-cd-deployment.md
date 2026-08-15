# Chapter 8 — Continuous delivery and deployment

> *Source: Hafner (2025), **Terraform in Depth**, Chapter 8, pages 250–287.*
>
> The companion to Ch7, and the chapter's opening argument is that **CI is not CD** — a distinction the industry only recently made, and one that would have been a single chapter ten years ago. CI is about the *source code* always being workable; CD is about *changes reaching environments* regularly and safely. It covers two deliveries. **Modules** are the easy one: semantic versioning, version constraints, and registries (public, private, Artifactory). **Infrastructure** is the hard one: what a deployment actually is, environments, **GitOps** and its four CNCF principles, the three ways to structure root modules (application, per-environment, Terragrunt), **secrets** (OIDC first, then secret managers, then orchestrator storage), and finally a feature-by-feature comparison of the **CD platform** market.
>
> 📌 **Three things in this chapter have gone stale, and one was wrong when printed.** Terragrunt's `run-all` no longer exists — the CLI redesign folded it into `run --all` and removed the `*-all` commands outright (§8.4.3, verified in the source). The AWS OIDC `thumbprint_list` dance in Listing 8.13 is now dead weight for GitHub Actions (§8.5.1, and the AWS provider docs name GitHub explicitly). HCP Terraform's per-resource pricing still works the way the chapter describes but the numbers have moved and tiered (§8.7.1). And Listing 8.16's AWS secret output does not reference a real attribute (§8.5.2). Details in each section; current tooling versions in [[ci-quality-tooling-versions]] and [[version-facts]].

> 🔗 **See also:** owns learning-path **A3** (the delivery half), **I4** (version constraints and pinning), **A4** (private registries, HCP Terraform), **A5** (policy at deploy time) and **A6** (secrets). Ch7 is the CI foundation this builds on — [Ch7 notes](07-code-quality-ci.md). Terragrunt detail is in [[terragrunt-facts]]; the drift taxonomy it refers back to is Ch6 §6.6. Topic pages: `ci-quality-gates` and a new `deployment-and-gitops` entry on the [topics backlog](../../../topics/index.md).

---

## 8.1 Delivering modules

### 8.1.1 Semantic versioning and constraints

Every delivery method in the chapter is **triggered by a Git tag of the form `vX.Y.Z`**. That is not convention — it is baked into the **Terraform Module Registry Protocol**, because Terraform assumes published modules follow [Semantic Versioning 2.0](https://semver.org/).

| Field | Meaning | Upgrade expectation |
|---|---|---|
| **Patch** (`v1.0.1`) | bug fixes | safe without review |
| **Minor** (`v1.1.0`) | new features, nothing broken | should need no changes, but more code changed means more chance of new bugs |
| **Major** (`v2.0.0`) | breaks backward compatibility | expect to do work |

The payoff is **version constraints** — you declare a *range*, not a version:

| Constraint | Allows |
|---|---|
| `= 1.1.1` | only `v1.1.1` |
| `>= 1.1.0, < 2.0.0` | floor `v1.1.0`, any minor/patch, no major |
| `>= 1.1.0, < 2.0.0, != 1.3.2` | as above, excluding one known-bad release |
| `~> 1.1.0` | **pessimistic** — rightmost field only, so patches only (`>= 1.1.0, < 1.2.0`) |
| `~> 1.1` | rightmost field is minor, so minor + patch (`>= 1.1.0, < 2.0.0`) |

The `!=` row is worth remembering: excluding a single version is how you route around a bug that was introduced and then fixed, without moving your floor.

!!! tip "Module authors: constrain as loosely as you can bear"
    The advice is the opposite of the instinct. A consumer uses **many** modules at once, and the tighter each module's constraints, the more likely two of them conflict and leave no satisfiable version. So set the floor at the **lowest version that actually works** and allow everything below the next major — which is exactly `~> 1.1` (major + minor form).

    Note the asymmetry with §8.4.2, which says a *root* module should pin an **exact** version. Loose for libraries, exact for deployments. Same reasoning as any language's lockfile-versus-manifest split.

Semver only works if authors honour it, and the chapter is blunt that **there is no way to enforce it programmatically** — reviewing changes for backward-incompatibility before tagging is a cultural discipline, not a tool.

### 8.1.2 SCM-based module delivery

Terraform can source a module straight from Git, with a shortcut for GitHub:

```hcl
module "github_example" {
  source = "github.com/tedivm/terraform-aws-lambda"          # GitHub shorthand
}

module "generic_git_example" {
  source = "git@github.com:tedivm/terraform-aws-lambda.git"   # same module, generic Git
}
```

**The flaw: Git sources do not support the `version` argument.** Pinning means `?ref=`, and the `ref` form requires the *generic* Git syntax, not the GitHub shorthand:

```hcl
module "generic_git_example" {
  source = "git@github.com:tedivm/terraform-aws-lambda.git?ref=v1.0.1"
}
```

That forces a two-bad-options trade:

- **Track the default branch** — consumers get backward-incompatible changes with no review, and their code breaks at random times.
- **Pin a commit or tag** — no automatic bug fixes, and every upgrade is manual. The chapter's observation is that teams who go this way *"rarely update their module versions"* in practice.

Not a reason to never use Git sources. Small teams can absorb the trade, and pulling a **bugfix branch** directly is a normal way to test a module fix before it merges and releases.

### 8.1.3 Public software registries

Registries are old news — Perl's CPAN launched in **1995**, and every modern language has one. The Terraform registry **does not host code**; it is an *index* pointing at repositories, which is a common package-manager design.

The license change split this. HashiCorp's registry Terms of Service gained restrictions on how the index could be used, so **the OpenTofu project launched its own registry**. To publish publicly you must be on **GitHub** (GitLab and others are not supported), and you submit the repository once to each registry — after that, any new semver tag is picked up automatically.

!!! info "OpenTofu — two registries, two submissions"
    Publishing publicly now means registering the same repository **twice**: once at `registry.terraform.io` (log in → Publish → Module → pick the repo) and once with the OpenTofu registry, whose submission at the time of writing runs through a **form on GitHub**. Both then watch the repo for tags.

    The chapter's own consolation is the honest one: this only matters if you publish **open source** modules. Most module development is internal, and internal means a private registry, where the split is irrelevant.

### 8.1.4 Private registries

Most Terraform CD platforms ship a registry, and most integrate with your SCM the same way the public one does — connect, tag, done. Consumers then authenticate:

```bash
terraform login registry.example.com    # omit the host and you get HCP Terraform
```

!!! warning "The token lands in plaintext, and the CLI says so"
    `terraform login` stores the token unencrypted at `~/.terraform.d/credentials.tfrc.json`, and prints that path twice before asking you to confirm. Treat that file as a credential on every machine that runs a plan, CI runners included.

If you need to self-host, **[Terrareg](https://matthewjohn.github.io/terrareg/)** is the chapter's pick for the most popular and best-maintained open source option — more work than a commercial tool, no licence fees.

### 8.1.5 Artifactory

JFrog's **Artifactory** supports the package managers of nearly every language, so past a certain company size it is usually already installed somewhere.

Terraform modules are the awkward case: where other registries *watch* your SCM for tags, **Artifactory requires you to push releases to it**. That means the `jf` CLI, a login, and — since it is a repeated command — a makefile target (Ch7's argument, applied):

```makefile
ARTIFACTORY_NAMESPACE := your_namespace
ARTIFACTORY_TF_PROVIDER := azurerm
TAG :=

publish_artifactory:
	@if [ -z "$(TAG)" ]; then echo "Please specify a tag for release."; exit 1; fi
	jf terraform-config
	jf tf p --namespace=$(ARTIFACTORY_NAMESPACE) --provider=$(ARTIFACTORY_TF_PROVIDER) --tag=$(TAG)
```

The workflow that calls it differs from Ch7's in exactly one way — **the trigger**. Publishing happens on tags, not on every commit:

```yaml
name: Publish to Artifactory
on:
  push:
    tags:
      - "v[0-9]+.[0-9]+.[0-9]+"     # the semver shape from §8.1.1, enforced by the trigger

jobs:
  artifactory:
    runs-on: ubuntu-latest
    permissions:
      id-token: write               # lets GitHub mint an OIDC token for this job
    steps:
      - uses: actions/checkout@v4                  # ← stale; current major is v7
      - uses: jfrog/setup-jfrog-cli@v4
        env:
          JF_URL: https://registry.example.com
        with:
          oidc-provider-name: github-action-workflow
      - name: Publish Module
        run: make publish_artifactory TAG=${{ github.ref_name }}
```

Note there is **no login step** — CI authenticates by OIDC (§8.5.1) rather than carrying a JFrog credential.

---

## 8.2 Deploying infrastructure

### 8.2.1 What is a deployment?

**Every `terraform apply` is a deployment**, local or automated. But unlike shipping a software package, the artifact is not a file: it is *code + variables + state* going in, and *the environment plus a new state* coming out.

The industry aphorism the chapter leans on: deploying infrastructure is **rebuilding a plane while it is flying**. The systems being changed are in use.

Local deploys are acceptable only for a temporary environment used by exactly one developer. Beyond that they must be centralised, and the reason is sharper than "good practice":

!!! danger "State locking does not prevent people overwriting each other"
    Locking stops two runs executing **simultaneously**. It does nothing about two engineers applying **different versions of the code** in sequence — each one's apply reverts whatever the other added, because neither has the other's changes. Alice deploys, Bob deploys and removes Alice's work, Alice re-deploys and removes Bob's.

    This is the argument for a single source of truth, and it is why §8.3's GitOps exists rather than being a fashion.

### 8.2.2 Environments

An **environment** is an isolated instance of a system. The chapter's running example is "Factory Analytics" — sensors, streams, APIs, storage, alerting, all in Terraform.

- **Feature environment** — the developer applies the whole system locally with a local backend, tests in isolation, then destroys it and opens a PR. The chapter rates spinning up and tearing down entire system instances as one of Terraform's genuinely powerful abilities.
- **Staging + production** — the common startup shape. Staging is largely for *manual* testing, since automated testing belongs in CI.
- **Per-region** — driven by data-residency law as much as by latency.
- **Per-customer** — contracts requiring full isolation, and each customer then gets its own version and upgrade schedule.

**Isolation is the requirement in both directions.** Infrastructure side: separate accounts, networks, subdomains, databases. Terraform side: **its own variables and its own state**. One environment must not reach another's data, and must not *depend on* another to function.

### 8.2.3 CD

Three practices make it possible:

1. **CI first.** Everything in Ch7 is the foundation — the quality controls are what buy the confidence to deploy often.
2. **Automate fully.** Between start and finish, no manual steps. Humans in a deployment loop are a source of error and a waste of the human.
3. **Keep deployments small.** Three tiny ones a day beats one big one a week: faster, less risk, and when something breaks the cause is obvious because only one feature moved.

### 8.2.4 Deployment requirements and limitations

Three constraints that push teams to a centralised runner:

- **Access** — credentials, *and* network reachability. Terraform is not only for public cloud; private clouds need a runner that can actually route to the targets.
- **Time** — some resources are slow. A single database instance can take **up to an hour** to create.
- **Consistency** — never two deployments against one environment at once.

A hosted runner answers all three: it lives in the network you need, it queues jobs so changes apply in order, and it is highly available — so a long job does not die because a laptop slept.

---

## 8.3 GitOps

The CNCF's [four principles](https://opengitops.dev/) of a GitOps-managed system:

- **Declarative** — desired state expressed declaratively.
- **Versioned and immutable** — stored so it is immutable and versioned, retaining full history.
- **Pulled automatically** — agents pull the desired state from the source.
- **Continuously reconciled** — agents observe actual state and work to apply desired state.

!!! warning "“Continuously” does not mean instantly"
    Straight from the CNCF, and the chapter flags it because the word misleads: *"Continuous is intended to match the industry standard term: reconciliation continues to happen, not that it must be instantaneous."* A nightly reconcile is still GitOps.

Terraform satisfies the first two almost by definition. GitOps adds the two Terraform lacks: **the SCM as the source of truth** (anyone can read the repo and know what is running, and you get a changelog that doubles as an audit log), and **the deployment system pulling the config itself**. Terraform does not care how the code arrived — it just needs to be invoked in the directory. Fetching is the orchestrator's job.

### 8.3.1 GitOps development workflows

The chapter's "little secret" is that the flow is unremarkable:

1. Branch from the project repo.
2. Develop locally, spinning up temporary environments as needed.
3. Open a PR — automated tests run, **a speculative plan shows everyone what will change**, reviewers approve.
4. Merge to main.
5. Deploy from main.

Except for step 5, that is ordinary software development. The weight sits on the **pull request**, which is where CD is *enabled by* CI: the better the tests, the easier the review.

> ⚠️ The chapter's line for skipping the CI half: *automated deployments without CI is like driving without a seatbelt.*

### 8.3.2 Continuous reconciliation

If infrastructure **drifts** from the config in the SCM, the system is expected to bring it back. Terraform can *detect* drift (plan) and *fix* it (apply), but Terraform is **not continuous** — so it can only ever be a component of a continuously-reconciling system.

This is, in the chapter's view, one of the **biggest drivers of the CI/CD split**: reconciling only on pull requests and merges misses drift entirely. Most CD platforms can run the reconcile on a **schedule**.

The drift taxonomy itself is Ch6 §6.6 — this section is the delivery-side consequence of it.

### 8.3.3 GitOps and CD platforms

Deploying from a CI system like GitHub Actions is possible. Adding **continuous reconciliation and automatic drift remediation** to a CI system is where it gets hard, which is why dedicated CD platforms rose alongside GitOps and now all have deep support for it.

---

## 8.4 Project structures

The root module is the entry point: the **only** place users inject variables, and the **only** place providers are configured. The chapter's example is a three-tier application whose root wires together separate modules for CDN, load balancer, container service, database and cache. That module *can* be the root module — it doesn't have to be.

### 8.4.1 Application as root module

One codebase, one root module, one `.tfvars` per environment (`staging.tfvars`, `production.tfvars`, …). Backends are configurable on the fly, so nothing prevents it.

!!! danger "The dealbreaker: every environment runs the same code"
    Variables differ; **the configuration does not**. You lose any ability to say which *version* of your infrastructure a given environment is on. Add a feature and it lands everywhere at once. Gating behind a variable is a workaround that still ships the code to production, and it forfeits staged rollout — the thing staging exists for.

### 8.4.2 Environment as root module

One root module **per environment**, each a thin wrapper — usually a single `module` block:

```hcl
variable "logging_api_key" {
  sensitive = true                  # secrets arrive as variables, never in source control
}

module "application" {
  source  = "registry.example.com/example/aws/application"
  version = "1.1.1"                 # EXACT — not a range

  network_name = "dev_network"      # environment-specific values can be hardcoded:
  db_size      = 20                 # this workspace serves exactly one environment
  num_tasks    = 5

  logging_api_key = var.logging_api_key
}

output "application_url" {
  value = module.application.url    # anything other workspaces need must be a root output
}
```

Two benefits. **Version independence** — each environment declares its own module version, which is what makes staged rollout real. And **fewer variables** — since the root is used once, values go directly on the `module` block; only secrets need to stay variables.

The exact pin is deliberate: with no range, **upgrading an environment requires a pull request**. The version bump *is* the deployment record.

On repository layout, the author's preference is one repo for all environments of an application, since one team usually owns them all — split only when different teams run different installations.

### 8.4.3 Terragrunt

Terragrunt takes environment-as-root-module further: instead of a real root module, a small config file that points at your application module.

```bash
tenv terragrunt install                                              # tenv from Ch7 §7.2.5 covers Terragrunt too
terragrunt scaffold github.com/TerraformInDepth/three_tier_example   # generates terragrunt.hcl with input stubs
```

```hcl
terraform {
  source = "git::https://github.com/TerraformInDepth/three_tier_example?ref=v1.0.2"
}

inputs = {
  num_tasks = ""   # TODO: fill in value
  db_size   = ""   # TODO
  network   = ""   # TODO
}
```

**Terragrunt does not support version constraints** — you always name an exact module version. Given each environment refers to one module that is little burden, and kept in SCM it yields an audit trail where every version change is a commit. Same reasoning as §8.4.2's exact pin, enforced by the tool.

!!! warning "`run-all` no longer exists — verified in the source"
    The chapter teaches `terragrunt run-all plan` for running a command across every configuration. That command has been **removed**. The pre-1.0 CLI redesign ([terragrunt#3445](https://github.com/gruntwork-io/terragrunt/issues/3445)) folded it into a flag:

    ```bash
    terragrunt run --all plan       # not: terragrunt run-all plan
    ```

    Checked against the local checkout at `v1.1.3`: `git grep '"run-all"'` returns **nothing**, and there is no `run-all` under `internal/cli/commands/`. The individual `*-all` commands (`plan-all`, `apply-all`, `destroy-all`, …) were removed outright rather than deprecated, so old CI scripts fail rather than warn. Flags also lost the `terragrunt-` prefix and env vars are now `TG_`-prefixed. Full inventory in [[terragrunt-facts]].

Terragrunt is explicitly **not** a requirement for using Terraform — many teams never touch it. It earns its place when you manage many environments.

---

## 8.5 Managing secrets

GitOps wants everything in Git; secrets cannot go there. The chapter is emphatic, and the reason is not distrust of teammates:

> You have no way to track where that repository goes after it is cloned, and teams grant more access to their Git repositories than they realize — GitHub applications, for instance, often have source code access.

### 8.5.1 OpenID Connect

**The best way to store a secret is to not need one.** OIDC (OpenID Foundation, built on OAuth 2.0) removes service users and shared API keys for machine-to-machine auth, and every major cloud supports it.

The setup shape is the same everywhere:

1. The platform you are granting access *to* publishes a **provider URL** — for GitHub Actions, `https://token.actions.githubusercontent.com`.
2. You register that URL as an identity provider with your vendor.

**Authentication is not authorization**, and the chapter draws the line clearly. Registering the IdP only says "identities from this issuer are genuine." Granting them permission is a second step — an IAM role for AWS, a service principal for Azure.

!!! danger "The conditions are the security control"
    Registering the IdP trusts *the whole issuer*. Without conditions scoping the role to your specific repository and workflow, **any other customer of that IdP can assume your role** — every GitHub Actions user, in the GitHub case. The role ARN is not a secret and does not need to be; the trust policy's conditions are what hold.

    Same lesson the learning path reaches from the HCP side in **A9**, where the `sub` claim carries org/project/workspace and the trust policy conditions on it.

!!! info "The `thumbprint_list` dance is now dead weight for GitHub"
    Listing 8.13 registers the provider by deriving a SHA-1 fingerprint through `data "tls_certificate"` and passing it as `thumbprint_list`. That was standard practice; for the major IdPs it now does nothing.

    The AWS provider's own documentation for `aws_iam_openid_connect_provider` marks `thumbprint_list` **Optional** and names the exception explicitly: *"For certain OIDC identity providers (e.g., Auth0, **GitHub**, GitLab, Google, or those using an Amazon S3-hosted JWKS endpoint), AWS relies on its own library of trusted root certificate authorities (CAs) for validation instead of using any configured thumbprints. In these cases, any configured `thumbprint_list` is retained in the configuration but not used for verification."*

    AWS's IAM guide agrees from the other side: thumbprints are a **fallback** used only when the JWKS endpoint's TLS certificate is not signed by a CA in AWS's trust store. So for GitHub Actions you can drop the `tls_certificate` data source entirely.

    ⚠️ One asymmetry worth knowing before you edit an existing provider: *"if a `thumbprint_list` is initially configured and later removed, Terraform does not prompt IAM to retrieve a thumbprint the same way. Instead, it continues using the original thumbprint list."* Removing the argument does not clear the stored value.

Consuming it from a workflow, once the role exists:

```yaml
permissions:
  id-token: write        # the job cannot get an OIDC token without this
  contents: read

steps:
  - uses: actions/checkout@v4                          # ← stale; current major is v7
  - uses: aws-actions/configure-aws-credentials@v4     # exchanges the OIDC token for AWS credentials
    with:
      role-to-assume: arn:aws:iam::999999999999:role/github-actions-${{ github.repository }}
      region: us-west-2
```

GitHub Actions is one IdP among many. **Every vendor defines the `sub` claim with its own structure**, which is why you must read both sides' documentation. Spacelift, for instance, writes an OIDC token to a file each run and you point the provider at it:

```hcl
provider "aws" {
  assume_role_with_web_identity {
    role_arn                = var.aws_role_arn
    web_identity_token_file = "/mnt/workspace/spacelift.oidc"   # created by Spacelift per run
  }
}
```

### 8.5.2 Secret managers

For the services OIDC cannot cover. Secret managers are *password managers for automated processes* — AWS Secrets Manager, Azure Key Vault, self-hosted Vault — and the pattern is to store the **path**, not the value, then resolve it with a data source.

The three vendors differ in shape, which is the useful part of Listing 8.16: **AWS needs two data sources** (secret, then version), **Vault needs one** but returns an object so you index a key, and **Azure needs two** because an account can hold multiple vaults.

```hcl
# Vault — one lookup, but all secrets are objects
data "vault_generic_secret" "example" {
  path = var.vault_path
}

output "vault_secret" {
  value     = data.vault_generic_secret.example.data[var.vault_key]
  sensitive = true
}
```

> ⚠️ **Book defect** — the AWS example's output reads `data.aws_secretsmanager_secret-version.value`, which cannot work: it omits the data source name, and `.value` is not an attribute. It should be `data.aws_secretsmanager_secret_version.secret-version.secret_string` — confirmed against the provider docs, where the data source exposes **`secret_string`** (and `secret_binary`), not `value`.

Marking these outputs `sensitive` is not optional style — Terraform raises an error otherwise.

!!! danger "A secrets manager does not keep secrets out of state"
    The chapter's own warning, and it is the important caveat on this whole section: **a value pulled in by a data source is still written to state**. Centralising secrets does not protect them from anyone with state access.

    Where the resource supports it, prefer a **machine-to-machine** retrieval that never passes through Terraform — the example given is ECS accepting a Secrets Manager ARN directly and loading the secret itself. Pairs with **A6** and the `ephemeral`/write-only work in [[tf-manage-sensitive-data]].

### 8.5.3 Orchestrator settings

Last resort: store the value in the CD platform. All of them support it, and most are **write-only** — you can replace a secret but not read it back.

The problem is scale. Rotating one API key across five projects is fine; across 500 it is a job, and at that point a real secrets manager pays for itself.

And either way, **your orchestrator can read your secrets**. The chapter's cautionary case: in **2021 Travis CI disclosed** that secrets belonging to open source projects could be extracted fairly trivially. Avoid needing secrets (OIDC); where you cannot, audit their use.

---

## 8.6 CD platform features

### 8.6.1 Common features

The baseline you should expect from any orchestrator worth considering:

- GitOps-based workflows
- Role-based access control
- OIDC support
- Secret management
- **Speculative plan** support

Some get these by tight GitHub integration, others build them in.

### 8.6.2 Terraform vs. OpenTofu

The chapter names this **the biggest single difference between the two tools** — not language features, *delivery*.

HCP Terraform is how HashiCorp monetises Terraform. Competitors built their own orchestrators on Terraform and did well. The BSL relicensing explicitly forbids using Terraform to build a competing product, and those competitors responded by creating OpenTofu.

The consequence for a team choosing today:

- Want **newer HashiCorp Terraform**? You are limited to HCP Terraform or self-hosting.
- Want the **wider CD ecosystem**, or fully open source? You use OpenTofu.

### 8.6.3 State management and private registry

Platforms bundling delivery + state + registry are **TACOS** (Terraform Automation and Collaboration Software). State management is handled transparently, since the platform runs the deployments and controls the backend, with a web UI for inspecting past versions.

> ⚠️ Even with a managed backend, **take your own external backups** — the same "resilient ≠ backed up" point as Ch6 §6.2.1.

Registries are close to undifferentiated: *"at the end of the day they're really just a directory of modules."*

### 8.6.4 Drift detection and correction

Mechanically easy — detect by planning, correct by applying. Socially hard: automatically changing running systems with no human review frightens people, reasonably. So **many teams enable detection but not correction**, and platforms make that a switch, usually with a Slack notification.

### 8.6.5 IaC frameworks

Terraform is not the only IaC tool, and a platform that only speaks Terraform is a limit you will feel as the company grows — Helm for a Kubernetes shop being the obvious case. Having to negotiate a new contract for every tool discourages adopting tools at all.

The chapter's tie-breaker rule, worth keeping: **if two platforms are otherwise identical and one supports tools beyond Terraform, pick that one — even if you don't need them today.**

### 8.6.6 Policy enforcement

Ch7 covered policy on the **CI** side. This is the deploy side, and the argument for why it matters more:

Ch7's worked example blocked expensive GPU instance types. But **modules do not hardcode instance types — they expose them as input variables**. So a static scan of module source cannot see what a caller will pass. Only at deployment time do the variable values exist.

That makes **deployment-time policy strictly more powerful**, and it is why most CD platforms ship a policy engine — and why most of them chose the **same** one, OPA with Rego. Policies written for one platform largely port to another; the cost is learning Rego.

HCP Terraform was the outlier with **Sentinel** and its own language, but **in 2023 HashiCorp added native OPA support**. The chapter's conclusion follows: standardise on OPA, because it is used far beyond the Terraform ecosystem.

### 8.6.7 Infrastructure cost estimates

Showing developers the financial effect of a change, automatically and hard to ignore, encourages better decisions. **HCP Terraform builds it in; the other platforms integrate [Infracost](https://www.infracost.io/)** — a separate purchase.

Two limitations to price in:

- **Vendor coverage is narrow** — effectively AWS, Azure, Google. Anything else is invisible, and most teams use *some* other vendors, so estimates are incomplete by construction.
- **They are estimates.** Consumption-based pricing cannot be predicted from configuration: a new feature that triples bandwidth is not something a static tool can guess.

---

## 8.7 CD platform overview

> ⚠️ **The printed feature matrix (Table 8.3) did not survive text extraction** — its rows and columns interleave, so several cells cannot be attributed to a system with confidence. The table below is rebuilt from the chapter's **prose** instead, and only carries claims stated in sentences. Verify against the book before relying on any single cell.

| Platform | Open source | State backend | Registry | Terraform-only | Notes |
|---|---|---|---|---|---|
| **HCP Terraform** | No | Yes | Yes | **Yes** | Sentinel + OPA; cost estimation built in |
| **Spacelift** | No | Yes | Yes | No | Terragrunt, Helm, Ansible, CFN, Pulumi, custom |
| **Env0** | No | Yes | Yes | No | as Spacelift |
| **Scalr** | No | Yes | Yes | **Yes** | Terraform ecosystem only; CLI-driven workflows |
| **Digger** | **Yes** | No | No | Yes | GitHub-native, PR-comment driven |
| **Terrateam** | No | No | No | Yes | state/registry on the roadmap |
| **Atlantis** | **Yes** | No | No | Yes | self-hosted, GitHub-native style |
| **Terrakube** | **Yes** | Yes | Yes | Yes | self-hosted, full TACOS |
| **Harness** | No | No | No | No | general CD platform |
| **Octopus Deploy** | No | No | No | No | general CD platform |

### 8.7.1 HCP Terraform

The original TACOS (formerly Terraform Cloud), with Terraform Enterprise as its self-hosted variant. For years the default choice, helped by deep GitHub integration and HashiCorp's name.

The author declines to recommend it, for two reasons:

1. **Terraform only.** His analogy: *"I would never recommend a CI tool that only supports Java."*
2. **The pricing model.** Charging hourly per **resource in state** rather than per run, project, or user.

His worked example: a best-practice VPC — public and private subnets across three AZs with a NAT instance — is roughly **72 resources**, most of which AWS itself charges nothing for (a route in a route table is free). At the book's rate that came to about **$7.25/month per VPC**.

The critique is structural rather than about the number: it penalises resource *count*, so it pushes teams toward fewer resources even when more would reduce complexity or improve security; it bills things the cloud gives away; and it is disconnected from HashiCorp's own costs, since a resource in state is a database row, not CPU.

!!! info "📌 The model still holds — the numbers moved and tiered"
    Verified 2026-08-15 against HashiCorp's pricing page. Billing is still **resources under management**, rated hourly, exactly as the chapter describes. It is now split across three tiers:

    | Tier | Per resource / month | Rated hourly |
    |---|---|---|
    | Essentials | **$0.10** | $0.00013 |
    | Standard | **$0.47** | $0.00064 |
    | Premium | **$0.99** | $0.00135 |

    The book's ~$7.25 for 72 resources lines up with the Essentials rate (72 × $0.10 = $7.20). On **Standard** the same VPC is about **$33.84/month**, and on Premium about **$71**. So the criticism has not aged — it has scaled. The free tier now caps at **500 managed resources** ([[version-facts]]).

Its genuine standouts: **built-in cost estimation**, and deep CLI integration — with the `cloud` backend configured, developers trigger runs on HCP Terraform straight from the CLI, which runs remotely with the configured secrets.

!!! info "OpenTofu — HCP Terraform is the one platform that will not take it"
    Per the chapter's own NOTE: HCP Terraform is *"the only service that offers the closed source versions of Terraform, and it does not support OpenTofu or Terragrunt. All other commercial vendors switch to OpenTofu for v1.6 and beyond."*

    That is the practical shape of the licence split. Choosing HCP Terraform is choosing HashiCorp Terraform; choosing any other commercial platform effectively means OpenTofu from 1.6 onward.

### 8.7.2 Env0 and Spacelift

Both **official OpenTofu sponsors**, each providing five full-time developers to the project. TACOS-plus: polished UIs, good documentation, the expected GitOps flows.

Their distinguishing feature is **breadth** — Terragrunt, Helm, Ansible, CloudFormation, Pulumi, and custom systems. For a team wanting the full IaC experience with registry and state management, the chapter calls this the best option.

The catch is the licence: **do not expect new Terraform versions on either**. Both being OpenTofu sponsors, the migration path is to bring your Terraform code over and expect it to work.

On choosing between them, the honest answer: very similar products, similar support, and they collaborate on OpenTofu. Compelling features tend to reach both.

### 8.7.3 Scalr

Also an official OpenTofu sponsor (three full-time developers). Building IT tooling since 2011 before pivoting to Terraform.

Unlike Spacelift and Env0 it is **purely Terraform-ecosystem** — no Kubernetes-style deployment tools. In exchange it supports **Terraform CLI-driven workflows** the way HCP Terraform does and the others do not, which makes it the natural landing spot for a team that has built automation around HCP Terraform and wants off it.

### 8.7.4 Digger and Terrateam

A newer generation focused **only** on deployment — no private registry, no state backend (Terrateam has both on the roadmap).

What makes them interesting is using **GitHub Issues and pull requests as the user interface**: developers reply to PR comments with Terraform commands and the system runs them, gated by role-based access control so only authorised commenters are honoured.

Genuinely different, increasingly popular, and largely a matter of taste — whether you want that much of your workflow living inside GitHub.

### 8.7.5 Harness and Octopus Deploy

General **CD platforms**, not IaC tools — extensible in the way GitHub Actions is via its marketplace. Harness is an official OpenTofu sponsor (five full-time developers) and also sells feature flags, an IDP, and its own SCM; Octopus stays focused on deployment.

Their advantage is **reach beyond IaC**: releasing individual containers, pushing to physical hardware, integrating with observability. Good for estates mixing legacy and modern deployment.

Their cost is Terraform-specific features: **no private module registry and no state management**. The chapter's mitigation is that they target enterprises, where something like Artifactory is already solving that.

### 8.7.6 Atlantis and Terrakube

The two **open source, self-hosted** options. Both integrate with your SCM and support the full GitOps flow. The split mirrors §8.7.4 versus §8.7.3: **Atlantis** follows the GitHub-native, PR-driven model; **Terrakube** is a traditional TACOS with registry and state backend.

So: Terrakube for the full feature set, Atlantis for tight SCM integration.

!!! tip "Self-hosting has a licence advantage the commercial tools lost"
    HashiCorp's licence change disallowed **commercial** competing services while still permitting self-hosting. So Atlantis and Terrakube are legally free to run **both** Terraform and OpenTofu, including current Terraform versions — which the commercial platforms in §8.7.2 cannot.

!!! danger "Your deployment system must not depend on what it deploys"
    The self-hosting trade is money and control against **owning another point of failure**. The failure mode to design against: an outage that also takes down the tool you would use to fix it.

    So put the deployment system in **its own cloud account, its own network, and possibly a different region** from the infrastructure it manages.

---

## Summary

- **Module delivery is ordinary library publishing.** Semver plus constraints is the whole mechanism, and `~> 1.1` is the module author's default.
- **Infrastructure delivery is not.** The artifact is a running system, and it is in use while you change it.
- **State locking is not coordination.** It prevents concurrent runs, not two people overwriting each other's work — which is the actual argument for a single source of truth.
- **GitOps is four principles and one surprise**: the surprise is that "continuous" means *keeps happening*, not *instant*. Terraform supplies the declarative, versioned half; the orchestrator supplies pull-and-reconcile.
- **Root module structure is a versioning decision.** One root shared by all environments means every environment runs the same code; one root per environment buys independent versions and staged rollout. Loose constraints for modules, exact pins for deployments.
- **The secret hierarchy is OIDC → secret manager → orchestrator storage**, in that order, and a data source still writes the value to state.
- **Deployment-time policy beats module-time policy**, because module inputs only have values at deploy time.
- **The platform market is a licence decision as much as a feature decision** — HCP Terraform for HashiCorp Terraform, anything else for OpenTofu, self-hosted for both.

---

## References

- Semantic Versioning 2.0 — <https://semver.org/>
- OpenGitOps principles (CNCF) — <https://opengitops.dev/>
- OpenID Foundation — <https://openid.net/>
- Terrareg (self-hosted registry) — <https://matthewjohn.github.io/terrareg/>
- Infracost — <https://www.infracost.io/>
- Terragrunt CLI redesign RFC — [terragrunt#3445](https://github.com/gruntwork-io/terragrunt/issues/3445)
- `aws_iam_openid_connect_provider` (thumbprint behaviour) — [provider docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider)
- Book's example module org — <https://github.com/TerraformInDepth/>
- Current tool and action versions — [[ci-quality-tooling-versions]]
