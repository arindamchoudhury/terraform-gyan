# Core workflow (Write / Plan / Apply)

> **Sources:** HCDocs "What is Terraform?" · Hafner, *Terraform in Depth* Ch1 §1.4 + Ch5 (plan/apply mechanics) · Brikman, *Terraform: Up & Running* Ch2 (the loop as a beginner first meets it)

## In one paragraph

Both sources describe the same three-ish stage loop: write configuration describing desired infrastructure, compute a plan (diff against reality), then apply it on approval. HCDocs names it **Write → Plan → Apply**; TID expands the front and back into a five-box flow — **change desired → init → plan → review → apply** — because init (downloading providers/modules, setting up the backend) is a real, separately-observable phase that HCDocs's three-word version glosses over.

## Key concepts (cross-source)

- **Plan is a diff, not just an action** — HCDocs: "builds an execution plan of what it will create, update, or destroy, by diffing existing infrastructure against your configuration." TID breaks this into three explicit subphases: **Refresh** (read real state + data sources) → **Compare** (diff against code) → **Plan** (build the DAG of actions). Same idea, TID's version is more implementation-precise.
- **Dependency-correct ordering** — HCDocs gives the VPC-resize-plus-VM-count example (recreate VPC before scaling VMs). TID names the underlying data structure explicitly: a **DAG (directed acyclic graph)**, and notes circular dependencies break the model and need manual workarounds — a caveat HCDocs doesn't mention at the intro level.
- **Init as a distinct, necessary phase** — TID-only concept at this level of detail: `terraform init` initializes the backend, then installs providers/modules from the registry. HCDocs's three-stage framing folds this implicitly into "Write."

## Where the sources differ

- HCDocs: three stages, framed as a *feature* of the tool ("why Terraform"). No CLI output shown.
- TID: five-box flow, framed as an *operational* sequence a developer actually runs, with real `terraform init` / `terraform plan` / `terraform apply` CLI transcripts and plan-symbol semantics (`+`, `(known after apply)`).

## When to read which

- Want the conceptual pitch? → HCDocs [[terraform-intro]].
- Want to see the actual CLI output and understand the refresh/compare/plan subphases? → TID Ch1 §1.4.
- Want to run the loop for real (init/validate/apply on an EC2 instance)? → [[tf-aws-create]].
- Never run it before, and want each command to arrive with a reason attached? → TUR Ch2.

## What TID Ch5 adds: the plan/apply engine in detail

Ch1's five-box flow is the overview; **Ch5** is the mechanics ([TID Ch5](../books/tid/chapters/05-terraform-plan.md)):

- **Three planning modes** — **default** (reconcile), **destroy** (`-destroy`, all `-`), **refresh-only** (`-refresh-only`, state-only, ignores code edits). Every default/destroy plan **starts with a refresh**; destroy walks the DAG in **reverse**.
- **Two apply paths** — `terraform apply` with **no** plan file runs its own plan + asks to confirm; `terraform apply plan.tfplan` applies a **saved** plan with no re-prompt (the automation pattern). `terraform destroy` = `terraform apply -destroy`.
- **`-replace`** (0.15.2) supersedes deprecated `taint` (0.4.0, April 2015) for forced recreation — six years apart, which is why so much older material still teaches `taint`; **`-target`** is an antipattern for exceptional recovery only. OpenTofu 1.9 adds an inverse, **`-exclude`**, which Terraform has no equivalent for and which cannot be combined with `-target` in the same run ([[opentofu-release-feature-map]]).

## What TUR Ch2 adds: the workflow as lived rather than described

[TUR Ch2](../books/tur/chapters/02-getting-started.md) is the only source here that runs the loop **repeatedly on one growing configuration**, so it shows things a single-pass tutorial cannot.

- **`plan` as a separate command is mostly optional.** Brikman's verdict is blunter than either other source: because `apply` shows the same plan and prompts, `plan` "is mainly useful for quick sanity checks and during code reviews" and "most of the time you'll run `apply` directly". TID Ch5 supplies what that leaves out — the saved-plan-file path, which is the automation case where `plan` is not optional at all.
- **Reading the diff is taught as a skill, not a symbol table.** The rule to carry: `-/+` means replace, and **grep the plan output for `forces replacement`** to learn which attribute caused it. The other sources list what the symbols mean; only TUR tells you what to do when you see one you didn't expect.
- **`init` is idempotent, and the trigger for re-running it is stated.** "Anytime you start with new Terraform code" — and Ch4 adds the other trigger, adding or changing a `module` source. TID's five-box flow names init as a phase; TUR names when you touch it.
- **The second apply is where state enters the story.** Adding a `tags` block produces `Refreshing state...` and a `~` in-place update rather than a create — the first observable evidence that Terraform remembers, which is exactly the hook the chapter uses to hand off to TUR Ch3.
- **Destroy is part of the loop, not an appendix.** `destroy` walks the same graph in reverse with the same parallelism, and the chapter's framing is that destroying the *resources* while keeping the *code* is the IaC payoff, since `apply` rebuilds them.

## Sources

- [What is Terraform? (Intro)](../sources/terraform-docs/terraform-intro.md)
- [TID Ch 1 — A brief overview of Terraform](../books/tid/chapters/01-brief-overview.md)
- [TID Ch 5 — The Terraform plan](../books/tid/chapters/05-terraform-plan.md) — planning modes, apply paths, plan-symbol semantics
- [TUR Ch 2 — Getting Started with Terraform](../books/tur/chapters/02-getting-started.md) — the loop run repeatedly on one growing configuration
- [Create infrastructure (AWS Get Started)](../sources/terraform-tutorials/tf-aws-create.md) — hands-on init/validate/apply
