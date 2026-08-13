# The dependency graph: seeing it, and its blind spot

Cross-source topic page. Sources: [[tf-cmd-graph]] (HCDocs `terraform graph`), [[tf-meta-depends-on]] (HCDocs `depends_on`), [[tut-dependencies]] (HCDocs hands-on tutorial), TID Ch2 §2.2.5 + §2.7.3, [TID Ch5 §5.1–5.2 + §5.7](../books/tid/chapters/05-terraform-plan.md) (the DAG chapter — nodes, node types, cycles), [[tf-configure-resource]] (HCDocs), plus experiments run locally against **Terraform v1.15.6**.

Feeds learning-path **B3** (plan/apply ordering), **I1** (`depends_on`), and **E5** (`terraform graph`).

## How the graph gets built

Terraform blocks have **no meaningful order**. You can write them in any order, in any file, and the plan is identical (TID Ch2 §2.2.5). Ordering comes entirely from a **DAG** that Terraform constructs during `plan`, from exactly two inputs:

1. **Expression references.** If block A uses an attribute exposed by block B, that reference *is* the dependency edge. This is the implicit, preferred kind.
2. **`depends_on`.** An edge you assert by hand, for a dependency that exists in the real world but leaves no trace in the configuration.

There is no third input. Terraform does not read provider documentation, does not know that a NAT Gateway needs an Internet Gateway, and does not inspect the cloud to discover ordering.

## The blind spot

Because the graph has only those two inputs, **a dependency Terraform cannot see does not exist**. It is not "missing" from Terraform's perspective — there is nothing to be missing.

This is worth stating plainly, because it determines what tooling can and cannot do for you:

!!! danger "Nothing will warn you about a missing `depends_on`"
    Not `plan`, not `validate`, not the provider, not `tflint` or `checkov`. Terraform has no signal that anything is absent.

    Verified (Terraform v1.15.6, `terraform_data`, no provider plugin):

    | Config | `terraform graph` edges | `terraform validate` |
    |---|---|---|
    | `nat` with `depends_on = [igw]` | `nat -> igw`, `igw -> vpc` | Success |
    | same config, `depends_on` deleted | `igw -> vpc` only | **Success** |

    The edge silently disappears and the configuration remains "valid." A resource with a forgotten hidden dependency looks exactly like a resource that genuinely has none.

The docs concede this in the definition itself: `depends_on` exists to handle "**hidden** resource or module dependencies that Terraform **cannot automatically infer**" ([[tf-meta-depends-on]]). If they could be inferred, they wouldn't be hidden.

### What you get instead of a warning

The failure moves to apply time, and takes one of these shapes:

- **A race.** Terraform parallelizes nodes it believes independent, so the outcome depends on timing. Passes locally, fails in CI. Fails once, succeeds on rerun. That "just run it again" behavior is the loudest available signal.
- **A provider API error** that doesn't obviously mention ordering.
- **Success that isn't.** The docs' own example: the EC2 instance references its instance profile (edge exists) but not the `aws_iam_role_policy` attached to the role (no edge). Terraform reports apply complete; software on the box can't reach S3. Semantic failure, no crash.
- **A broken destroy.** Teardown walks the same graph in reverse, so the missing edge bites again.

## Route 1 — `terraform graph`

The direct view. Default output is DOT covering only `resource` and `data` blocks:

```shell
terraform graph                          # simplified, resources only
terraform graph | dot -Tpng > graph.png  # render with Graphviz
```

```dot
"terraform_data.igw" -> "terraform_data.vpc";   # implicit: references vpc.output
"terraform_data.nat" -> "terraform_data.igw";   # explicit: depends_on
```

**Implicit and explicit edges render identically.** The graph won't tell you which edges you asserted by hand.

Richer views, at the cost of runtime implementation detail:

| Command | Shows |
|---|---|
| `terraform graph -type=plan` | provider nodes, `(expand)` nodes for `count`/`for_each`, provider open/close ordering |
| `terraform graph -type=apply` | the apply-time graph |
| `terraform graph -type=plan-destroy` | teardown ordering |
| `terraform graph -plan=tfplan` | graph of a **saved plan file**; implies `-type=apply` |
| `terraform graph -type=plan -draw-cycles` | cycle edges in red — requires an explicit `-type` |

On a cycle, Terraform refuses to plan at all: `Error: Cycle: terraform_data.a, terraform_data.b`. The error names the cycle's *members*; `-draw-cycles` shows which *edges* close the loop, which is what you need on a large graph.

!!! info "Terraform 1.16 renders the cycle vertically (rc1, not yet stable)"
    Through 1.15 the members print on **one line**, which is readable for the two-node case above and unreadable for a loop spanning a dozen nodes. That is the reason the `-draw-cycles` detour below exists at all.

    From 1.16 the same error prints **one node per line**, ordered by **reference** rather than graph-traversal order, and starting from a consistent node so repeated runs agree. Same error, same fix, just legible. `-draw-cycles` still wins when you need the *edges* rather than the members.

    Not in any changelog — commit `4c4adca78b` on the `v1.16` branch, found by reading the tree rather than the release notes. (See [[release-feature-map]].)

!!! warning "`-draw-cycles` needs an explicit `-type=`"
    Passing it alone is **silently ignored** — no warning, exit 0. Worse, the default resources-only graph renders only one of the two cycle edges, so the cycle is invisible rather than merely unhighlighted. Verified on v1.15.6. Always write `terraform graph -type=plan -draw-cycles`.

!!! tip "Use `graph` to confirm, never to discover"
    It faithfully renders every edge Terraform knows about. Bring the suspicion yourself — pick the two resources you think are wrongly parallel and check whether an edge exists between them.

## Route 2 — the state file

Often overlooked. Each resource instance records the dependencies Terraform used, and this is what orders the **destroy**.

Read it via `terraform show -json` rather than opening `terraform.tfstate`:

```shell
terraform show -json | python -c "
import json, sys
d = json.load(sys.stdin)
for r in d['values']['root_module']['resources']:
    print(f\"{r['address']:22} depends_on={r.get('depends_on', [])}\")
"
```

After applying the config above:

```
terraform_data.igw     depends_on=['terraform_data.vpc']
terraform_data.nat     depends_on=['terraform_data.igw', 'terraform_data.vpc']
terraform_data.vpc     depends_on=[]
```

Note `nat` records `vpc` as well as `igw` — **transitive edges are materialized**, not just direct ones.

!!! note "The field has two names"
    In the **raw state file** each instance carries a `dependencies` array. In **`terraform show -json`** the same information appears on each resource as `depends_on`. Same edges, different key — don't grep for the wrong one.

State is the right place to look when the *current* graph disagrees with what was actually applied: state holds the edges as of the last apply, `graph` holds the edges your configuration implies now.

## Route 3 — read the configuration for behavior-vs-data

The only real detection method is human, and it's a single question per resource pair:

> Does A depend on B's **behavior** while never reading B's **data**?

If yes, no edge exists and you need `depends_on`. If A reads any attribute of B, the edge is already there and you must **not** add one ([[tf-meta-depends-on]], [[tf-configure-resource]]).

## Why not just add `depends_on` everywhere

Because it is not free. The docs call it a **last resort**:

> "It can cause Terraform to create more conservative plans that **replace more resources than necessary** … Terraform may treat more values as unknown `(known after apply)` … especially likely when you use `depends_on` for **modules**."

An expression reference tells Terraform *which value* the dependency derives from, so it can skip planning changes when that value is unchanged. `depends_on` makes the entire upstream object opaque. Over-using it also serializes work the graph could have run in parallel.

There are **two distinct costs**, and only the first is usually quoted:

| Cost | Where it shows up | Source |
|---|---|---|
| Degraded plan — spurious `(known after apply)`, more resources replaced than necessary | `terraform plan` output | [[tf-meta-depends-on]] |
| Longer apply — serialized work that could have run in parallel | wall-clock apply time | [[tut-dependencies]] |

The rule that falls out: **prefer implicit references; reach for `depends_on` only when there is no attribute to reference.**

## Route 4 — read the apply log

The cheapest observation, and the one nobody bothers with. Terraform prints `Creating...` for every node the moment it starts, so **interleaved `Creating...` lines mean Terraform believes those nodes are independent**, and a node that waits has an edge.

From [[tut-dependencies]], applying two EC2 instances and an Elastic IP attached to the first:

```
aws_instance.example_a: Creating...
aws_instance.example_b: Creating...
...
aws_instance.example_a: Creation complete after 33s
aws_eip.ip: Creating...
```

Both instances start together. The Elastic IP waits for `example_a` and *not* for `example_b` — exactly the edge set the configuration declares. If you expected a wait and see interleaving instead, the edge you assumed does not exist.

**Destroy prints the mirror image.** Dependents are destroyed first, off the same edges, which is why a missing `depends_on` breaks teardown as well as setup.

## What TID Ch5 adds: the node types and cycles

TID Ch5 is the book's dedicated DAG chapter and fills in two things this page's HCDocs sources gloss:

- **The graph has exactly three node types** — **Resource** (one per instance; data sources count as Resource nodes too), **Provider Configuration** (one per provider config; every resource edges to one), and **Resource Meta** (a cosmetic grouping node when `count > 1`). See [TID Ch5 §5.2.1](../books/tid/chapters/05-terraform-plan.md).
- **Modules are *not* nodes.** Terraform flattens module boundaries into the flat resource graph, so a resource in module B can be created before one in module A if the resource-level edges allow it — module nesting does **not** serialize execution.

!!! warning "🔄 Both bullets above are wrong against the current source (checked 2026-07-20)"
    Verified against the Terraform repo at `C:\opt\learn\terraform\repos\terraform` at tag **`v1.15.8`** (the release this book targets — checked 2026-07-20; earlier drafts of this box read `main`, which carries newer nodes like policy evaluation that 1.15.8 does not have). TID's model is a teaching simplification, not the implementation:

    - **There are far more than three node types.** `graph_builder_plan.go` runs transformers that add nodes for root and module **variables**, **locals**, **outputs**, **checks**, **actions**, module **expansion** and **close**, provider **close**, and several resource flavors (expand, instance, destroy, orphan, deposed, import, forget). See `internal/terraform/node_*.go`.
    - **"Resource Meta" is not cosmetic and is not `count`-only.** The modern equivalent is `nodeExpandPlannableResource` (`node_resource_plan.go:24`), created for **every** managed resource, not just `count > 1`. It does real work — deciding the expansion — and each instance then gets its own node.
    - **Modules *are* nodes.** `nodeExpandModule` (`node_module_expand.go`) plus `nodeCloseModule`, added by `ModuleExpansionTransformer`. Its own comment: the transformer "ensures that any nodes representing objects declared within a module are dependent on the expansion node so that they will be visited only after the module expansion has been decided."

    What survives is the **consequence**, not the structure: module boundaries still don't serialize resources across modules, because ordering past expansion comes from the flat resource-level edges. The provider-edge claim also holds — `transform_provider.go:101` creates "edges from provider to provider user so that the providers will get initialized first."

    Book Ch5's node-types box is written from this verification, not from TID.

**Breaking a cycle by routing through a variable.** When two resources form a cycle only because they share a value, break the edge by moving that value into a `variable`/`local` instead of a resource attribute — the shared value survives, the resource-to-resource edge disappears:

```hcl
# cycle: alpha.triggers → charlie.id, charlie → bravo, bravo → alpha
variable "build_id" { default = null }
resource "null_resource" "alpha" {
  triggers = { rebuild = var.build_id }   # was null_resource.charlie.id
}
# bravo, charlie: same — all keyed off var.build_id, no cycle
```

Same principle as the "prefer implicit references" rule below, applied in reverse: sometimes you *want* to sever an inferred edge, and the fix is to depend on data (a variable) rather than a resource.

---
Related: [[tf-cmd-graph]] — the command reference and its DOT dialects. · [[tf-meta-depends-on]] — the hidden-dependency meta-argument, its cost, and the `check`-block pattern. · [[tut-dependencies]] — the hands-on lab, source of the apply/destroy log evidence and of the module-level `depends_on` example. · [[meta-arguments-lifecycle]] — `depends_on` among the other five meta-arguments. · [[tf-configure-resource]] — "prefer implicit dependencies," stated without the plan-degradation reason.
