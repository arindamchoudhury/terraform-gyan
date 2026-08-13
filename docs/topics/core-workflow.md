# Core workflow (Write / Plan / Apply)

> **Sources:** HCDocs "What is Terraform?" · Hafner, *Terraform in Depth* Ch1 §1.4 + Ch5 (plan/apply mechanics)

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

## What TID Ch5 adds: the plan/apply engine in detail

Ch1's five-box flow is the overview; **Ch5** is the mechanics ([TID Ch5](../books/tid/chapters/05-terraform-plan.md)):

- **Three planning modes** — **default** (reconcile), **destroy** (`-destroy`, all `-`), **refresh-only** (`-refresh-only`, state-only, ignores code edits). Every default/destroy plan **starts with a refresh**; destroy walks the DAG in **reverse**.
- **Two apply paths** — `terraform apply` with **no** plan file runs its own plan + asks to confirm; `terraform apply plan.tfplan` applies a **saved** plan with no re-prompt (the automation pattern). `terraform destroy` = `terraform apply -destroy`.
- **`-replace`** (0.15.2) supersedes deprecated `taint` (0.4.0, April 2015) for forced recreation — six years apart, which is why so much older material still teaches `taint`; **`-target`** is an antipattern for exceptional recovery only. OpenTofu 1.9 adds an inverse, **`-exclude`**, which Terraform has no equivalent for and which cannot be combined with `-target` in the same run ([[opentofu-release-feature-map]]).

## Sources

- [What is Terraform? (Intro)](../sources/terraform-docs/terraform-intro.md)
- [TID Ch 1 — A brief overview of Terraform](../books/tid/chapters/01-brief-overview.md)
- [TID Ch 5 — The Terraform plan](../books/tid/chapters/05-terraform-plan.md) — planning modes, apply paths, plan-symbol semantics
- [Create infrastructure (AWS Get Started)](../sources/terraform-tutorials/tf-aws-create.md) — hands-on init/validate/apply
