# Chapter 10 — How to Use Terraform as a Team

> *Source: Brikman (2022), **Terraform: Up & Running**, 3rd ed., Chapter 10, pages 375–415.*
>
> The closing chapter, and the least technical: how to get a team to adopt IaC at all, then two workflows side by side — the well-understood one for application code, and the much less understood one for infrastructure code — ending in a table that maps each step of one onto the other. It contains the book's single most quoted line, the Golden Rule of Terraform.
>
> 📌 **Notes adapted where version-bound.** Book written 2022; current stable is **1.15.8** / OpenTofu **1.12.5** ([[version-facts]]). **The process advice has aged better than anything else in the book** — the Golden Rule, the branch argument, and the CI-server-permissions warning all still hold, and the last one has only got more urgent. What moved is the tooling chapter around it: Terraform Cloud is **HCP Terraform** and now detects drift automatically, and **Terragrunt's entire CLI was redesigned** for its 1.0, which breaks every command and file-layout convention this chapter teaches. Details under [Version reckoning](#version-reckoning).

> 🔗 **See also:** [Deployment and GitOps](../../../topics/deployment-and-gitops.md), which synthesizes this chapter with TID Ch8.

---

## 1. Adopting IaC in your team

Switching to IaC is a culture and process change, not a tool change. Three pieces of advice, and the first is the one developers get wrong.

### Convince your boss

The failure mode, described from experience: a developer discovers Terraform, is thrilled, shows everyone, and the boss says no. The developer concludes everyone else is blind.

The diagnosis is that the developer sees all the benefits and none of the **costs**:

- **Skills gap** — Ops now writes code most of the day. Some engineers love that; others were hired to make changes by hand with the occasional script, and the transition means real retraining or new hires.
- **New tools** — developers get attached to tooling, *"some are nearly religious about it"*, and not everyone wants to spend the energy learning a new language.
- **Change in mindset** — direct changes (SSH in, run a command) become indirect ones (edit code, commit, let automation apply it). For simple tasks that layer of indirection genuinely *is* slower, especially while learning.
- **Opportunity cost** — the one the boss actually feels. Time spent on IaC is time not spent on the app the search team has asked about for months, the PCI audit, or last week's outage.

So the goal is not to prove IaC has value. It is to prove **IaC brings more value than anything else the team could do with that time**.

The sales framing, which is the transferable part:

| Level | What you say | Why it lands |
| --- | --- | --- |
| Features (worst) | "Terraform is declarative, popular, open source." | Nobody buys features. |
| Benefits (better) | "Your infrastructure will be easier to maintain; you can reuse existing modules; hiring is easier from a large community." | Describes the customer's new superpowers. |
| Problems (best) | "I have an idea for how to reduce our outages by half." | Solves the problem the boss is already losing sleep over. |

The technique behind the third row is listening: find the key problem your boss is working on this quarter, then check whether IaC actually solves it.

!!! quote "The heretical paragraph, and it is the most credible thing in the chapter"
    *"It might be slightly heretical for the author of a book on Terraform to say this, but not every team needs IaC."* A tiny startup with one Ops person, a prototype that may be thrown away in months, a side project for fun — managing infrastructure by hand is often the right call. And even where IaC would fit well, it may not be the highest priority.

### Work incrementally

The statistic the argument rests on: roughly **3 in 4 small IT projects** (under $1M) succeed, while only **1 in 10 large ones** (over $10M) finish on time and on budget, and **more than a third are never completed at all** (Standish Group CHAOS Manifesto, 2013).

Hence the scepticism about the "everything moves to the cloud, datacenters shut down, everyone does DevOps, in six months" mandate. The chapter claims to have watched that pattern *several dozen times* without a single success; two to three years later the migration is still running and the old datacenter is still up.

!!! warning "False incrementalism is the trap, not insufficient planning"
    Splitting work into small steps is not enough if **no step delivers value until the last one**. Rewrite the frontend but don't launch it (it needs the new backend); rewrite the backend but don't launch it (it needs the data migration); then migrate the data. All value arrives at the end — so if the project is cancelled, changed, or loses its sponsor partway through, you get **nothing** in exchange for everything you spent.

    The fix is to split work so that **every step brings its own value even if the later steps never happen.** One small, specific team migrated. One concrete problem — outages during deployment — actually solved. A quick win builds momentum, that team becomes your advocate, and the next win gets easier.

### Give your team the time to learn

The five-step death spiral this prevents, which is the most useful thing in the section because it is a *mechanism*, not a warning:

1. One enthusiast spends months writing beautiful Terraform and deploying real infrastructure with it.
2. The rest of the team never gets time to learn it.
3. An outage happens. The person on call can fix it manually in minutes, or with Terraform in hours or days because they don't know it. **They are reasonable people, so they fix it manually.**
4. The code no longer matches reality, so the next person to run Terraform gets a weird error, loses trust, and also goes manual — which widens the gap and makes the next error more likely.
5. Shortly, everyone is manual again, the codebase is unusable, and the months spent writing it are wasted.

> 💭 (mine): step 3 is the load-bearing one. The spiral is not caused by laziness or by bad code; it is caused by Terraform being *slower than the alternative for someone who has not learned it*, at the exact moment when speed matters most. Any adoption plan that does not budget learning time is relying on people behaving irrationally during an outage.

## 2. A workflow for deploying application code

Seven steps, covered quickly because the industry already agrees on them, and included so the infrastructure workflow can be mapped onto it step by step: **version control → run locally → make changes → submit for review → run automated tests → merge and release → deploy**.

The detail that matters for the comparison: **application code runs on localhost**, both manually (`ruby web-server.rb`, `curl localhost:8000`) and under test.

Release means packaging into an **immutable, versioned artifact** — a Docker image, an AMI, a `.jar`. Tag it with the commit SHA so an image maps back to exact code, or with a friendlier Git tag:

```bash
git tag -a "v0.0.4" -m "Update Hello, World text"
git push --follow-tags
```

### Deployment strategies

Assume five copies of the app are running:

| Strategy | Mechanism | Requires | Property |
| --- | --- | --- | --- |
| **Rolling with replacement** | take one down, deploy its replacement, health-check, repeat | works with fixed capacity | never more than five running; both versions live during rollout |
| **Rolling without replacement** | add one new, health-check, remove one old, repeat | flexible capacity, tolerates >5 | never fewer than five running |
| **Blue-green** | deploy five new, health-check all, shift traffic at once, remove old | flexible capacity, tolerates 10 | only one version visible to users at a time |
| **Canary** | deploy one new copy, send it live traffic, **pause**, compare against a control | flexible capacity | early warning from a small blast radius |

The canary comparison is made across CPU, memory, latency, throughput, log error rates and HTTP status codes; ideally the two are indistinguishable, and any difference cancels the rollout. The name is the coal-mine bird.

!!! tip "Canary plus feature toggles separates deployment from release"
    Wrap new features in an if-statement defaulting to off. The canary then behaves identically to the control by construction, so any difference is genuinely a problem and can trigger an automatic rollback. Later, enable the feature for employees, then 1% of users, then 10%, ramping back down through the same switch if anything breaks. **Deploying new code and releasing new features become separate events.**

### Deployment server, and promotion

Deploy from a **CI server, not a developer's laptop**, for three reasons: it forces full automation, it removes "works on my machine" differences (OS, tool versions, uncommitted changes), and it means only one machine needs production permissions instead of every developer.

Promotion is moving **the same artifact** through dev → stage → prod, testing at each stop. Same artifact everywhere means what worked in one environment probably works in the next, and rollback is deploying an older version.

## 3. A workflow for deploying infrastructure code

Same seven step names. Different content under every one.

### Use version control

**Two repos**: a `modules` repo of reusable versioned modules, and a `live` repo defining what is deployed in each environment.

The organisational pattern this enables: one infrastructure team builds a library of production-grade modules — composable APIs, documented, tested, versioned, meeting the company's security and compliance checklist — and every other team consumes it *like a service catalog*. Nobody spends months assembling infrastructure from scratch, and the Ops team stops being the bottleneck that has to deploy for everyone.

!!! quote "The Golden Rule of Terraform"
    > The main branch of the live repository should be a 1:1 representation of what's actually deployed in production.

    The chapter's own health check for it: go to your live repo, pick a few folders at random, run `terraform plan`. Always "no changes" is the goal. Occasional small diffs plus *"oh right, I tweaked that by hand"* means trouble is coming. Plans that fail with weird errors or show gigantic diffs mean the code has no relation to reality and is useless.

    Read backwards, each clause is a separate rule:

    - **"…what's actually deployed"** — never make out-of-band changes. No web console, no manual API calls, ever, once Terraform owns a resource.
    - **"…a 1:1 representation…"** — a reader should be able to scan the live repo and see what exists in which environment. The subtle way to break this is **workspaces**: the infrastructure exists but the code does not, because one copy of the code backs 3 or 30 environments. Use a folder per environment instead.
    - **"The main branch…"** — one branch should tell you what is in production, so production changes go into `main` and you only apply production from `main`.

#### The trouble with branches

The worked example is the clearest argument against branch-per-change for shared environments.

Anna changes an EC2 instance from `t2.micro` to `t2.medium` on her branch and applies it to staging. Bill, on a different branch, adds a tag — and his branch still says `t2.micro`. His plan reads:

```text
~ instance_type = "t2.medium" -> "t2.micro"
+ tags          = { + "Name" = "foo" }
```

He is about to silently undo Anna's change while she is still testing against it.

!!! danger "State locking cannot help here, and that is the point"
    Backend locking prevents two concurrent runs from corrupting one state file. This conflict has nothing to do with concurrency — Anna and Bill could be weeks apart and it would be identical. The cause is deeper:

    > Terraform is implicitly a mapping from Terraform code to infrastructure deployed in the real world. Because there's only one real world, it doesn't make much sense to have multiple branches of your Terraform code.

    Rule: **for any shared environment, always deploy from a single branch.**

### Run the code locally, and make changes

There is no localhost, so "locally" means a sandbox account: `terraform apply`, `curl`, `go test`. Iteration is the same loop as application code with one difference — infrastructure tests are slow, so invest in shortening the cycle, which is what Chapter 9's test stages are for.

### Submit changes for review

The definition of clean code the chapter borrows, from Nick Dellamaggiore: if ten engineers wrote one file, it should be *"almost indistinguishable which part was written by which person"*, achieved through code reviews and a published style guide, so that *"it's more about what you're writing and not how you write it."*

Four guideline areas worth enforcing in review:

- **Documentation.** Code says what, never why. Each module gets a README covering what it does, why it exists, how to use it and how to modify it — ideally **written before the code**, because twenty minutes on a README can save hours building the wrong thing (readme-driven development). In-code comments explain intent and design choices only, and every `variable`/`output` gets a `description`.
- **Automated tests.** All of Chapter 9, compressed to one reviewable question: *"How did you test this?"*
- **File layout.** Because file layout determines state layout, it determines isolation. Review against the folder-per-environment, folder-per-component structure.
- **Style guide.** Debate tabs versus spaces if you must; consistency is what matters. `terraform fmt` in a commit hook makes it automatic.

### Run automated tests

Everything from Chapter 9 in CI on every commit, plus one more:

> Always run plan before apply.

Since `apply` prints the plan anyway, the real instruction is **pause and read it**. Thirty seconds spent scanning a diff catches a startling number of errors. The way to make that habitual is to put the plan in the review: **Atlantis** posts `terraform plan` output as a pull-request comment automatically, and HashiCorp's paid products do the same.

### Merge and release

`git tag` again — but with no separate artifact to build, because Terraform downloads modules from Git natively:

> the repository at a specific tag is the immutable, versioned artifact you will be deploying.

### Deploy

**Tooling:** Terraform itself, plus Atlantis (plan and apply from PR comments), Terraform Cloud / Enterprise (web UI, variables, secrets, permissions), Terragrunt, or scripts.

**Strategies:** essentially none. There is no blue-green for a VPC change and no feature toggle for a database change. A few modules can do better — the `asg-rolling-deploy` from earlier chapters — but they are the exception.

!!! danger "Terraform does not roll back, and it cannot"
    An application deployment that fails health checks never receives traffic and can be automatically rolled back. A failed `terraform apply` cannot: rolling back a deleted database or a terminated server is not a thing. So plan for errors as a first-class case:

    - **Retries.** Many Terraform errors are transient and disappear on a rerun. Deployment tooling should detect known errors and retry after a pause; Terragrunt has this built in.
    - **`errored.tfstate`.** If Terraform applies successfully but cannot write state to the backend — say connectivity drops mid-apply — it writes the state to `errored.tfstate` on disk. **Make sure CI does not delete it when cleaning the workspace.** Recover with `terraform state push errored.tfstate`.
    - **Stuck locks.** A CI server that crashes mid-apply leaves the state locked forever. `terraform force-unlock <LOCK_ID>`, using the ID from the error message, and only when you are certain the lock is stale.

**Deployment server**, and the section that has aged into the most important one:

!!! danger "Infrastructure CI needs admin credentials, and CI servers are terrible places to keep them"
    Application CI needs a small fixed permission set. Infrastructure CI must be able to deploy *arbitrary* changes — databases, VPCs, whole accounts — which means **admin permissions**. And CI servers are *"notoriously hard to secure"*, accessible to every developer, and exist to execute arbitrary code. Permanent admin credentials on that machine effectively grant every developer admin, and make the CI server a very high-value target.

    Four mitigations, in increasing order of strength:

    1. **Lock the server down** — HTTPS only, authentication required, firewall, fail2ban, audit logging.
    2. **Keep it off the public internet** — private subnets, VPN-only access. The cost is that inbound webhooks stop working, so CI must poll version control instead. The chapter calls that *"a small price to pay"*.
    3. **Enforce an approval workflow** — every deployment approved by someone other than the requester, with both the code diff and the plan output visible. Two sets of eyes on every change.
    4. **Never give CI permanent or admin credentials** — temporary credentials via IAM roles or OIDC (Chapter 6), and isolate the admin credentials on a **separate locked-down worker** that CI can only poke through a narrow API: specific commands (`plan`, `apply`), specific repos, specific branches. Then an attacker who owns your CI server can still only request a deployment of code that is already in version control.

**Promotion across environments**, with one extra step application code does not need:

> Always test Terraform changes in pre-prod before prod.

The loop per environment: update to `v0.0.6` → `terraform plan` → **have a human review and approve the plan** → `apply` → test → repeat in the next environment. The approval step exists because every infrastructure change is different and mistakes are expensive, unlike app deployments which are mostly uniform and low-risk.

#### Terragrunt, and the boilerplate problem

Promotion exposes how much duplication a live repo carries. Even when every environment folder just calls one module, each copy repeats the provider configuration, the backend configuration, the input variables and the output passthroughs — dozens to hundreds of near-identical lines per environment.

Terragrunt's answer is to delete the `.tf` files from the live repo and leave one `terragrunt.hcl` per module:

```hcl
terraform {
  source = "github.com/<OWNER>/modules//data-stores/mysql?ref=v0.0.7"
}

include {
  path = find_in_parent_folders()
}

inputs = {
  db_name = "example_stage"
}
```

What `terragrunt apply` then does: read the file, pull in settings from the included parent, download the `source` into a scratch folder, generate `backend.tf`, run `init` automatically (creating the S3 bucket and DynamoDB table if missing), and run `apply`.

The backend stays DRY through one `remote_state` block per environment, whose key uses `path_relative_to_include()` so state paths mirror the live repo's folder structure.

!!! note "`dependency` blocks versus `terraform_remote_state`"
    Terragrunt's `dependency` block reads another unit's outputs directly:

    ```hcl
    dependency "mysql" {
      config_path = "../../data-stores/mysql"
    }

    inputs = {
      mysql_config = dependency.mysql.outputs
    }
    ```

    The chapter's argument for preferring it: `terraform_remote_state` is native, but it makes modules **tightly coupled**, because each module has to know how the others store state. A `dependency` block lets a module expose a generic `mysql_config` or `vpc_id` input instead, which is easier to test and reuse. Chapter 9's dependency-injection refactor is what makes that possible.

## 4. Putting it all together

Table 10-1, restated — the two workflows side by side:

| Step | Application code | Infrastructure code |
| --- | --- | --- |
| **Use version control** | `git clone`; one repo per app; **use branches** | `git clone`; `live` and `modules` repos; **don't use branches** |
| **Run the code locally** | localhost | a sandbox environment |
| **Make code changes** | change, rerun, retest | change, `apply`, `go test`, **use test stages** |
| **Submit for review** | pull request; enforce guidelines | pull request; enforce guidelines |
| **Run automated tests** | unit, integration, e2e, static analysis on CI | the same, **plus `terraform plan`** |
| **Merge and release** | `git tag`; build a versioned artifact | `git tag`; **the repo at that tag is the artifact** |
| **Deploy** | many strategies; CI server with **limited** permissions; promote the artifact; deploy automatically after merge | **limited strategies**, handle errors (retries, `errored.tfstate`); CI server with **temporary** credentials invoking a locked-down admin worker; promote, then an **approval step on the plan** before apply |

Four rows differ in a way worth memorising: branches, localhost, deployment strategies, and who holds the credentials.

### State of the running example

No new infrastructure. The live repo is restructured: `.tf` files replaced by `terragrunt.hcl` files pointing at versioned module sources, a root `terragrunt.hcl` per environment carrying the `remote_state` block, and the `hello-world-app` unit taking its database config from a `dependency` block instead of `terraform_remote_state`. Modules are tagged `v0.0.7`.

The book closes with an appendix of recommended reading — Kief Morris's *Infrastructure as Code*, the Google SRE book, *The DevOps Handbook*, *Continuous Delivery*, *Release It!* — which is a decent map of where to go next.

---

## Version reckoning

The process advice needed no updating. The tools it names all moved, and one of them moved out from under every command in the chapter.

!!! danger "1. Terragrunt's CLI was redesigned, and this chapter's examples no longer run"
    Terragrunt reached **v1.0.0 on 2026-03-30** and is at **v1.1.3** (2026-08-13). The pre-1.0 CLI redesign ([terragrunt#3445](https://github.com/gruntwork-io/terragrunt/issues/3445)) changed four things that break old muscle memory and old pipelines ([[terragrunt-facts]]):

    - **The `terragrunt-` flag prefix is gone.** The chapter's `terragrunt apply --terragrunt-log-level debug` is now `terragrunt apply --log-level debug`.
    - **Environment variables are `TG_`-prefixed**, not `TERRAGRUNT_`.
    - **`run-all` and `graph` folded into `run`** as `run --all` and `run --graph`.
    - **The `*-all` commands were removed outright** — `plan-all`, `apply-all`, `destroy-all`, `output-all`, `validate-all`, `spin-up`, `tear-down`. Removed, not deprecated.

    Some renames are not mechanical, which is the migration trap: `--terragrunt-exclude-dir` → `--queue-exclude-dir`, `--terragrunt-ignore-dependency-order` → `--queue-ignore-dag-order`, `--terragrunt-iam-role` → `--iam-assume-role`.

!!! warning "2. The file layout the chapter teaches is now the documented anti-pattern"
    The chapter puts a root `terragrunt.hcl` at `live/stage/` and includes it with a bare `find_in_parent_folders()`. Terragrunt now ships a **migration guide away from exactly that**: the root file should be renamed (`root.hcl` is the convention) because a root `terragrunt.hcl` is indistinguishable from a unit, which *"complicates Terragrunt usage, as commands like `run --all` need to be run from a directory where all child directories will be `terragrunt.hcl` files corresponding to units."*

    So the current idiom is:

    ```hcl
    include "root" {
      path = find_in_parent_folders("root.hcl")
    }
    ```

    Note both changes: the **labelled** `include "root"`, and the **argument** to `find_in_parent_folders`, which defaults to looking for `terragrunt.hcl` and therefore needs telling.

    Also gone: the chapter praises Terragrunt for creating your S3 bucket and DynamoDB table automatically during `init`. Backend provisioning is now an **explicit `terragrunt backend bootstrap`** command, and the flag that controlled the old side effect was removed.

!!! info "3. Terragrunt is no longer pitched as the DRY tool"
    Its own documentation says the focus *"has shifted to offering more tooling for orchestrating infrastructure"*, and warns you *"might miss the forest for the trees"* by evaluating it on DRY alone. The vocabulary is now **unit** (one directory with its own state), **stack** (a collection of units, either a directory tree or an explicit `terragrunt.stack.hcl` blueprint), **run queue** and **runner pool**.

    The chapter's use of Terragrunt — collapse boilerplate, promote a version across environments — is still valid and still works. It is simply the smaller half of what the tool now does. Its other framing is worth stealing: **"your current working directory is your blast radius."**

!!! warning "4. Terraform Cloud is HCP Terraform, and it now checks the Golden Rule for you"
    Renamed **effective 2024-04-22**. More than cosmetic for this chapter: the Standard edition adds **automated configuration drift detection** and **continuous validation**, which is the chapter's own "pick a few folders and run `plan`" health check, running continuously and alerting instead of waiting for someone to notice.

    The commercial terms moved too — the legacy free tier ended **2026-03-31**, and the replacement caps at **500 managed resources** ([[version-facts]]).

!!! note "5. Atlantis is alive, and now has a foundation behind it"
    Still actively developed — **v0.47.1** (2026-08-20), with OpenTofu support — and the project now describes itself as *"a Series of LF Projects, LLC"*, so it sits under Linux Foundation governance rather than being one company's tool. That answers the durability question a 2022 reader might reasonably have had about depending on it.

    The chapter's specific criticism (no versioning support, which complicates maintenance and debugging on larger projects) is a 2022 assessment and is left as the book's claim rather than re-verified here.

!!! tip "6. The market the chapter could not see yet"
    In 2022 the options were Atlantis, Terraform Cloud/Enterprise, Terragrunt or scripts. There is now a whole **CD-platform category** — TID Ch8 §8.7 surveys it feature by feature, which is the right companion read ([Ch8 notes](../../tid/chapters/08-cd-deployment.md)).

    Two additions worth knowing by name. **GitOps** as a formal model, with the four CNCF principles, gives the chapter's "main branch is 1:1 with production" rule a name and a reconciliation loop. And **Terraform Stacks** attacks the promotion problem natively: components plus deferred changes plus per-deployment configuration, instead of one folder per environment. Both are HCP-side or platform-side; neither existed here. See learning-path **A3** and **E2**.

!!! tip "7. What aged well, which is nearly all of it"
    - **The Golden Rule** — unchanged, and drift detection now enforces it rather than replacing it.
    - **Don't branch shared environments** — unchanged. S3 native locking (`use_lockfile`, Terraform 1.11 / OpenTofu 1.10) improved *state* locking and does nothing for this problem, exactly as the chapter explains.
    - **Always run plan before apply** — unchanged, and the failure mode to watch for is a plan gate that runs but cannot fail the build ([[krausen-lab-ci-facts]] found precisely that defect in a live pipeline).
    - **CI server permissions** — the strongest section, and four years of supply-chain attacks have made it more urgent. The OIDC half is now standard practice ([Ch6 notes](06-managing-secrets.md)); the isolated-admin-worker half is still rarer than it should be.
    - **`errored.tfstate` and `force-unlock`** — both still exactly as described. One addition: OpenTofu encrypts `errored.tfstate` when state encryption is configured, Terraform cannot.
    - **The adoption advice** — has no version number attached and never will.

---

*Related notes:* [Deployment and GitOps](../../../topics/deployment-and-gitops.md) · TID Ch8 [Continuous delivery](../../tid/chapters/08-cd-deployment.md) for the CD-platform market and the GitOps principles · TID Ch7 [Code quality and CI](../../tid/chapters/07-code-quality-ci.md) for the pipeline this chapter assumes · TUR Ch3 [State](03-manage-state.md) for isolation-by-file-layout, Ch6 [Managing Secrets](06-managing-secrets.md) for CI credentials, Ch8 [Production-grade](08-production-grade.md) for the module library, Ch9 [Testing](09-testing.md) for the test stages and the dependency injection this chapter's Terragrunt section depends on · [[terragrunt-facts]] for the source-derived CLI and vocabulary changes · [[krausen-lab-ci-facts]] for how plan gates fail in practice · [[version-facts]]. Feeds learning-path **A3** (CI/CD), **A4** (HCP Terraform), **E4** (repo architecture) and **A7** (environment promotion).
