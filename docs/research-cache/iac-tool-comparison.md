# IaC/config-mgmt tool comparison — verified facts

**Checked:** 2026-07-03

## Terraform vs Ansible

- **Model:** Terraform is declarative (desired end state, engine computes the plan). Ansible is imperative — playbooks are explicit step-by-step instructions, even though written in YAML.
- **Agentless is not a differentiator.** Both tools are agentless. Terraform talks to cloud provider APIs; Ansible executes over SSH (or an API) against already-running machines.
- **State.** Terraform maintains a state file and diffs it against config on every `plan`. Ansible holds no persistent state — it re-runs its steps each time (idempotency is the playbook author's responsibility, not a stored diff).
- **Primary use case.** Terraform provisions and tracks infrastructure lifecycle. Ansible configures/orchestrates already-existing systems (package installs, service config, software deploys) — the two are commonly used together (Terraform provisions, Ansible configures what Terraform created), not as strict either/or alternatives.

Sources: [Red Hat — Ansible vs. Terraform](https://www.redhat.com/en/topics/automation/ansible-vs-terraform), [Spacelift — Terraform vs. Ansible](https://spacelift.io/blog/ansible-vs-terraform)

## Terraform vs Pulumi

- **Languages.** Pulumi programs are written in general-purpose languages — Python, TypeScript, JavaScript, Go, Java, C#, or YAML. Terraform uses its own DSL, HCL.
- **Declarative vs imperative.** Sources frame this carefully: both tools are ultimately declarative in *outcome* (you still get a desired-state model and a plan/preview), but Pulumi's *authoring* style is imperative — real loops, conditionals, classes, and package management, versus HCL's limited runtime logic and reuse-only-through-modules.
- **Practical trade-off:** Pulumi programs get full IDE tooling (autocomplete, type checking, refactoring) since they're real code; HCL is more constrained but purpose-built and more widely adopted for pure infra provisioning.

Sources: [Pulumi docs — Pulumi vs. Terraform](https://www.pulumi.com/docs/iac/comparisons/terraform/), [Spacelift — Pulumi vs. Terraform](https://spacelift.io/blog/pulumi-vs-terraform)

## Terraform vs AWS CloudFormation

- Not separately re-verified this session — TID Ch1 already states CloudFormation is AWS-vendor-specific (as opposed to Terraform's multi-vendor provider model), which matches long-standing, non-version-sensitive product positioning. No new facts needed here.
