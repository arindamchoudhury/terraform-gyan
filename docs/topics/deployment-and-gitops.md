# Deployment and GitOps

> **Sources:** Hafner, *Terraform in Depth* Ch8 · Brikman, *Terraform: Up & Running* Ch10 · [[terragrunt-facts]] · [[krausen-lab-ci-facts]] · [[version-facts]]

## In one paragraph

Getting infrastructure code from a laptop into production is a different problem from getting application code there, and both books arrive at the same reason: an application deployment can be rolled back and an infrastructure deployment usually cannot. From that one asymmetry everything else follows — a human approving a plan before every apply, one branch per shared environment, a versioned artifact that is just a Git tag, and a CI server that needs admin credentials and therefore must not hold them. GitOps supplies the model that makes it coherent: the repository is the desired state, and something reconciles reality against it continuously. Terraform can express the desired state and can reconcile once per run, which is exactly why a scheduler or a platform has to sit on top of it.

## Key concepts (cross-source)

- **CI is not CD.** TID opens on the distinction: CI keeps the *source code* always workable, CD keeps *changes reaching environments* regularly and safely. TUR shows it structurally instead, running the same seven-step workflow twice — application code, then infrastructure code — so each step can be compared. Its own summary of the skipping-CI temptation: *automated deployments without CI is like driving without a seatbelt.*
- **The repository is the source of truth, stated twice.** TUR: *"The main branch of the live repository should be a 1:1 representation of what's actually deployed in production."* TID: the CNCF's four GitOps principles — declarative, versioned and immutable, pulled automatically, continuously reconciled. Terraform gives you the first two almost for free; the last two are what a platform adds.
- **"Continuously" does not mean instantly.** TID quotes the CNCF directly: reconciliation *continues to happen*, not that it must be instantaneous. A nightly reconcile is still GitOps — which is what makes the model reachable with ordinary CI plus a schedule.
- **Drift is the reason the CI/CD split exists.** Terraform can detect drift (`plan`) and fix it (`apply`) but is not continuous, so reconciling only on pull requests and merges misses drift entirely. TUR's version is the manual health check: pick folders at random, run `plan`, and judge your codebase by how big the diffs are. HCP Terraform's automated drift detection is that check turned into a product.
- **Never branch a shared environment.** TUR's worked example — Anna bumps an instance type on her branch and applies to staging, Bill adds a tag from a branch that still says the old value, and his plan silently reverts her — with the reasoning that lands: *"Because there's only one real world, it doesn't make much sense to have multiple branches of your Terraform code."* State locking does not help, because the conflict is not concurrent.
- **The artifact is a Git tag.** No image to build. TUR: *"the repository at a specific tag is the immutable, versioned artifact you will be deploying."* TID makes the same tag load-bearing from the other end, since the Module Registry Protocol keys releases off `vX.Y.Z` tags.
- **Promotion plus one extra step.** Both books promote the same version dev → stage → prod. TUR adds the step application deployments do not need: **a human reviews the plan and approves before apply**, because app deployments are uniform and low-risk while every infrastructure change is different and some are unrecoverable.
- **Terraform does not roll back.** So errors are a first-class design case: retries for transient failures, `terraform state push errored.tfstate` when an apply succeeds but the state write fails, and `terraform force-unlock` for a lock orphaned by a crashed runner. TUR's operational warning worth repeating: **do not let CI clean the workspace before you have recovered `errored.tfstate`.**
- **Infrastructure CI needs admin credentials; CI servers should not hold them.** TUR's four mitigations — harden the server, keep it off the public internet, require an approver other than the requester, and isolate admin credentials on a separate locked-down worker reachable through a narrow API. TID's ranked secret hierarchy (OIDC → secret manager → orchestrator storage) is the credential half of the same argument. See [Secrets and state](secrets-and-state.md).

## Where the sources differ

- **TID argues from the platform market; TUR argues from team practice.** TID Ch8 §8.6 compares CD platforms feature by feature — state management, private registry, drift detection and correction, policy enforcement — and treats the choice as a procurement decision. TUR spends its first third on *convincing your boss and your teammates*, which no other source here attempts.
- **On repository structure they disagree in emphasis.** TUR prescribes: two repos (`live` and `modules`), one folder per environment, never workspaces, because the live repo must be readable as an inventory. TID catalogues three root-module structures — application as root, environment as root, Terragrunt — and refuses to pick, framing it as blast radius versus number of applies. TID's dealbreaker for the simplest option is the one TUR's Golden Rule implies: if every environment runs the same configuration with different `.tfvars`, you cannot say which *version* of your infrastructure any environment is on.
- **Only TUR covers adoption**, and it is the least replaceable part: the cost list a boss actually feels, features-versus-benefits-versus-problems, false incrementalism, and the five-step spiral where one manual fix during an outage begins the decay that makes the whole codebase unusable.
- **Only TID names GitOps as a model.** TUR describes a GitOps workflow without the vocabulary, which is a fair reflection of 2022.
- **Both teach Terragrunt, and both predate its 1.0.** The CLI redesign removed the `terragrunt-` flag prefix, deleted the `*-all` commands, and made the root-`terragrunt.hcl` layout an anti-pattern with its own migration guide ([[terragrunt-facts]]). TID's `run-all` and TUR's `--terragrunt-log-level` are both dead syntax.

## When to read which

- Selling the change to a team or a manager → **TUR Ch10**, first third.
- Designing the pipeline → **TID Ch8** for the platform comparison, **TUR Ch10** for the CI-permission model.
- Deciding the repo layout → both, in that order; TUR for the rule, TID for the trade-offs.
- Wondering why your pipeline never catches drift → **TID §8.3.2**, then check your plan gate can actually fail the build ([[krausen-lab-ci-facts]]).

## Sources

- [TUR Ch 10 — How to Use Terraform as a Team](../books/tur/chapters/10-terraform-as-a-team.md)
- [TID Ch 8 — Continuous delivery and deployment](../books/tid/chapters/08-cd-deployment.md)
- [TID Ch 7 — Code quality and CI](../books/tid/chapters/07-code-quality-ci.md) — the pipeline both deployment chapters assume
- [[terragrunt-facts]] · [[krausen-lab-ci-facts]] · [[version-facts]]

## Open questions

> ❓ Neither book costs out the **isolated admin worker** TUR recommends. It is the strongest control in either chapter and the rarest in practice; worth finding a published implementation that is not a vendor's own product.

> ❓ **Terraform Stacks** attacks promotion natively — components, deferred changes, per-deployment configuration — and neither book can see it. Whether it replaces the folder-per-environment rule or just relocates it is unresolved; tracked under learning-path **E2**.
