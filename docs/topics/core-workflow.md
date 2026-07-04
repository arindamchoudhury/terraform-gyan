# Core workflow (Write / Plan / Apply)

> **Sources:** HCDocs "What is Terraform?" · Hafner, *Terraform in Depth* Ch1 §1.4

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

## Sources

- [What is Terraform? (Intro)](../sources/terraform-docs/terraform-intro.md)
- [TID Ch 1 — A brief overview of Terraform](../books/tid/chapters/01-brief-overview.md)
- [Create infrastructure (AWS Get Started)](../sources/terraform-tutorials/tf-aws-create.md) — hands-on init/validate/apply

## Open questions

> ❓ TID promises deeper DAG/circular-dependency debugging content in Ch5 ("The Terraform plan") — revisit this page once that chapter is captured.
