# pyinfra

> **Source:** [github.com/pyinfra-dev/pyinfra](https://github.com/pyinfra-dev/pyinfra) · [docs.pyinfra.com](https://docs.pyinfra.com/en/3.x/)
> **Added:** 2026-07-17
> **Source updated:** v3.9.2 (released 2026-06-07); repo read 2026-07-17
> **Tags:** config-management, ansible-alternative, provisioners, terraform-output, inventory, agentless, a1
> **Type:** repository

**Not an IaC tool, and not a Terraform alternative.** pyinfra is agentless configuration management in Python — it configures machines that already exist. It's in these notes for exactly one reason: its `@terraform` connector is a two-line demonstration of the handoff that HashiCorp's own case against provisioners gestures at but never shows. Relevant to **A1** only.

MIT · 5.9k stars · v3.9.2 (2026-06-07) · Python 99% · install with `uv tool install pyinfra`.

## What it is

> "🔧 pyinfra turns Python code into shell commands and runs them on your servers. Execute ad-hoc commands and write declarative operations."

Its own positioning, which is the clearest one-liner available: **"Think ansible but Python instead of YAML, and a lot faster."**

Stated design goals:

- Super fast execution over thousands of hosts with predictable performance
- Instant debugging with realtime stdin/stdout/stderr output
- Idempotent operations that enable diffs and dry runs before making changes
- Extendable with the entire Python package ecosystem
- Agentless execution against anything with shell access
- Integrated with connectors for Docker, Terraform, Vagrant and more

Two concepts, and the CLI is just the two of them concatenated (`pyinfra INVENTORY OPERATIONS...`):

- **Inventory** — "Hosts, groups and data. Hosts are targets for pyinfra to execute commands or state changes (server via SSH, container via Docker, etc)."
- **Operations** — "Commands to execute or state to apply to the target hosts in the inventory." Two forms: **declarative** ("ensure the iftop apt package is installed") and **imperative** ("execute the uptime command").

```shell
pyinfra my-server.net exec -- echo "hello world"
pyinfra @docker/ubuntu exec -- echo "Hello world"
pyinfra @local exec -- echo "Hello world"
pyinfra my-server.net,@local,@docker/ubuntu:22.04 exec -- uptime
```

A declarative operation ad-hoc, then the same thing as a deploy file:

```shell
pyinfra @docker/ubuntu apt.packages iftop update=true _sudo=true
```

```python
from pyinfra.operations import apt

apt.packages(
    name="Ensure iftop is installed",
    packages=['iftop'],
    update=True,
    _sudo=True,
)
```

The idempotency model will read as familiar: **"Declarative state operations will not make changes unless required by diff-ing the target state against the state of the operation."** Same diff-then-converge shape as a Terraform plan, with one important difference — there is no persisted state file. The diff is computed against the **live host**, every run. That's the whole reason config management doesn't have Terraform's state problem, and also why it can't detect a resource it didn't create.

Execution model: **"Operations always iterate per host, not per group: every operation runs once for every host across all groups (deduplicated), in parallel."**

## The `@terraform` connector — the only part that matters here

> "Generate one or more SSH hosts from a Terraform output variable. The variable must be a list of hostnames or dictionaries."

It shells out to **`terraform output -json`** and treats a list-valued output as an SSH inventory. Given this output:

```json
{
  "server_group": {
    "value": {
      "server_group_node_ips": [
        "1.2.3.4",
        "1.2.3.5",
        "1.2.3.6"
      ]
    }
  }
}
```

the inventory address is the flattened JSON path:

```shell
pyinfra @terraform/server_group.value.server_group_node_ips ...
```

List entries can also be dictionaries carrying per-host connection config:

```json
{
  "server_group": {
    "value": {
      "server_group_node_ips": [
        { "ssh_hostname": "1.2.3.4", "ssh_user": "ssh-user" },
        { "ssh_hostname": "1.2.3.5", "ssh_user": "ssh-user" }
      ]
    }
  }
}
```

**That's the whole seam.** Terraform builds the hosts and publishes their addresses as an output; pyinfra reads the output and takes over. Nothing runs inside the apply.

## Why this matters for A1

A1's scope is "when *not* to use a provisioner," and HashiCorp's own answer is essentially "use a config management tool" — without showing where the boundary sits. This is what it looks like: **`terraform output -json` is the boundary.**

What that buys, against a `remote-exec` provisioner doing the same work:

- **A failed package install isn't a tainted resource.** The provisioner runs *inside* create, so its failure marks the resource tainted and the next apply destroys and recreates a perfectly good server. The handoff puts the config step outside the apply, where failing means "run it again."
- **Re-running config doesn't need Terraform at all.** A provisioner only runs at create (or `when = destroy`), so re-converging means tainting or `terraform_data` gymnastics. The config tool just runs again — that's what idempotence is for.
- **The plan stops lying.** A provisioner's work is invisible to the plan; Terraform can't diff what a shell script did. Neither tool pretends to own the other's half.

The cost is honest and worth writing down: **two tools, two runs, and a real ordering dependency between them.** The output has to exist and be current before the config run, which means either a human sequences them or CI does. That's the actual tradeoff versus a provisioner, not a free win.

## Where it sits vs. Ansible

Ansible is the incumbent by orders of magnitude, and it has the same seam — via the Red Hat-certified **`cloud.terraform`** collection (GPL-3.0+, v4.0.0, 2025-07-11), which ships:

- `terraform` module — "Manages a Terraform deployment (and plans)"
- `terraform_output` module and `tf_output` lookup plugin — "Reads state file outputs."
- `terraform_provider` inventory plugin — "Builds an inventory from Terraform state file."
- `terraform_state` inventory plugin — "Builds an inventory from resources created by cloud providers."

!!! warning "The interesting difference is *what each one reads* — outputs vs. state"
    pyinfra's connector reads **`terraform output -json`**: only what the root module **deliberately published**. Ansible's `terraform_provider` inventory plugin builds its inventory from the **state file**: every attribute of every resource, secrets included.

    This lands directly on the access-boundary warning already in these notes ([[tf-remote-state-data]], A6/I6): whatever can read state can read the plaintext secrets in it, so **"who may read this state" is the real permission boundary**. An outputs-only consumer can be granted `terraform output` without being handed the state snapshot; a state-reading inventory plugin cannot. If you're wiring a config-management tool into a Terraform pipeline, that distinction decides what credential the config runner needs.

    Not a reason to pick pyinfra over Ansible — Ansible's `terraform_output` module and `tf_output` lookup read outputs too, and it's the inventory plugin specifically that wants state. It *is* a reason to know which mechanism you reached for.

> ❓ Unverified: pyinfra's "and a lot faster" claim versus Ansible is the project's own marketing. Plausible given the architecture (Python throughout, no YAML parsing, parallel per-host execution), but no benchmark was checked.

---
Related: feeds learning-path **A1** — the concrete form of the "don't use a provisioner, hand off to config management" advice whose reference is [[tf-terraform-data]]. The outputs-vs-state distinction sharpens [[tf-remote-state-data]]'s point that reading state is the real permission boundary, and connects to [[tf-outputs]] (`terraform output -json` as a machine-readable interface) and [[tut-outputs]] (which documents that `-json` bypasses `sensitive` redaction — worth knowing before you publish an output for a config tool to consume).
