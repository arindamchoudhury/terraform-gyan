# References to Named Values

> **Source:** [developer.hashicorp.com/terraform/language/expressions/references](https://developer.hashicorp.com/terraform/language/expressions/references)
> **Added:** 2026-07-14
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-14
> **Tags:** references, named-values, resource-attributes, path, workspace, sensitive, unknown-values, dependencies
> **Type:** documentation

Terraform exposes several kinds of named values. Each name is an expression referencing the associated value — usable standalone or combined to compute new values.

## Types of named values

- **Resources** — `<RESOURCE TYPE>.<NAME>`
- **Input variables** — `var.<NAME>`
- **Local values** — `local.<NAME>`
- **Child module outputs** — `module.<MODULE NAME>`
- **Data sources** — `data.<DATA TYPE>.<NAME>`
- **Filesystem / workspace info** — `path.*`, `terraform.workspace`
- **Block-local values** — `count.index`, `each.key`/`each.value`, `self`

!!! warning "They only look like objects"
    The dot-separated paths resemble object attribute notation but are **not** real objects. Use them exactly as written: you cannot swap in square-bracket notation for the dotted path, and you cannot iterate over the "parent object" — e.g. you cannot put `aws_instance` in a `for` expression to loop over every AWS instance resource.

### Resources

`<TYPE>.<NAME>` is a managed resource. Its value depends on `count`/`for_each`:

- neither → an **object**; attributes accessed via dot or square-bracket notation.
- `count` set → a **list** of instance objects.
- `for_each` set → a **map** of instance objects.

Any named value not matching another pattern below is interpreted as a managed-resource reference.

### Input variables

`var.<NAME>`. If the variable declares a `type` constraint, Terraform auto-converts the caller's value to conform. So a `var.` reference always produces a value conforming to the constraint. Note: for an object-typed variable, only the attributes declared in the type constraint are available elsewhere — you must declare every attribute you intend to use, even if the caller passed extras. See [[tf-expr-type-constraints]].

### Local values

`local.<NAME>`. Locals can refer to other locals — even in the same `locals` block — as long as there are no circular dependencies. See [[tf-locals]].

### Child module outputs

`module.<MODULE NAME>` represents a `module` block's results:

- neither `count`/`for_each` → an object with one attribute per child output; access via `module.<NAME>.<OUTPUT NAME>`.
- `for_each` → a map of objects keyed by the `for_each` keys, one per instance.
- `count` → a list of objects, one per instance.

### Data sources

`data.<DATA TYPE>.<NAME>` is an object for the data resource. `count` → list; `for_each` → map. The "References to Resource Attributes" rules below apply too, aside from the `data.` prefix. See [[tf-remote-state-data]].

### Filesystem and workspace info

- `path.module` — filesystem path of the module where the expression sits. **Not recommended for write operations** — local vs remote module sources behave differently, and multiple local-module invocations share one source directory (overwrites during each call → race conditions).
- `path.root` — filesystem path of the configuration's root module.
- `path.cwd` — absolute path of the original working directory before any `-chdir`. Prefer `path.root`/`path.module` where possible.
- `terraform.workspace` — name of the currently selected workspace.

Use these carefully — they carry context about *where* a config is applied, which can hurt module portability/composability. Example: `path.cwd` baked into a resource argument makes a later apply from a different directory look like a change even when the file is the same. Using `terraform.workspace` as a namespace prefix in a shared module can prevent calling that module more than once in a config.

Recommendation: aside from `path.module`, use these only in the **root** module. A shared module that needs a unique prefix should take it as an input variable; the caller supplies it (possibly from `terraform.workspace`):

```hcl
module "example" {
  # ...
  name_prefix = "app-${terraform.workspace}"
}
```

### Block-local values

Within certain block bodies, extra named values appear:

- `count.index` — in resources using `count`.
- `each.key` / `each.value` — in resources using `for_each`.
- `self` — in provisioner and connection blocks.

These "local names" are arbitrary temporary names, **not** input variables despite sometimes being called "variables" in docs. They apply to top-level config blocks only; inside `dynamic` blocks the key/value of each element are referred to differently (see [[tf-expr-dynamic-blocks]]).

## Named values and dependencies

Terraform analyzes references in block bodies to infer dependencies automatically. A resource argument referring to another managed resource creates an **implicit dependency** between the two. See [[tf-meta-depends-on]] for the explicit form.

## References to resource attributes

Most common reference type. Example resource:

```hcl
resource "aws_instance" "example" {
  ami           = "ami-abc123"
  instance_type = "t2.micro"

  ebs_block_device {
    device_name = "sda2"
    volume_size = 16
  }
  ebs_block_device {
    device_name = "sda3"
    volume_size = 20
  }
}
```

Every schema construct is referenceable:

- **Argument** — `aws_instance.example.ami`.
- **Exported attribute** — `aws_instance.example.id`.
- **Nested-block arguments via splat** — `aws_instance.example.ebs_block_device[*].device_name` gives a list of all `device_name` values (works for exported attributes too, e.g. `...ebs_block_device[*].id`).
- **Keyed nested blocks** — a block type taking a logical key, e.g. `device "foo" { size = 2 }`, is accessed by index: `aws_instance.example.device["foo"].size`. Build a map of one argument with a `for` expression: `{for k, device in aws_instance.example.device : k => device.size}`.

**With `count`** — the resource is a list of instances:

- `aws_instance.example[*].id` → list of all ids.
- `aws_instance.example[0].id` → id of the first instance.

**With `for_each`** — the resource is a map of instances:

- `aws_instance.example["a"].id` → id of the `"a"`-keyed instance.
- `[for value in aws_instance.example : value.id]` → list of all ids.
- Splat does **not** apply directly to `for_each` (splat needs a list). Convert first with `values()`: `values(aws_instance.example)[*].id`.

## Sensitive resource attributes

Provider developers can mark schema attributes as **sensitive**; Terraform renders `(sensitive value)` instead of the actual value in plans. It behaves like a `sensitive` input variable — hides the value and any derived values in plan/apply output (with some limitations, see [[tf-manage-sensitive-data]]). Using a sensitive attribute in an output requires marking that output `sensitive` too. Sensitive values are still stored in **state in cleartext** — anyone with state access sees them.

> Deriving-sensitivity (treating derived values as sensitive too) was introduced in Terraform v0.15. Earlier versions obscure the direct value but not derived values.

## Values not yet known

During planning, some attribute values are decided by the remote system and can't be populated yet (e.g. a generated unique id on creation). Terraform uses **unknown value** placeholders and handles them automatically in expressions — known + unknown = unknown. Situations where it matters:

- `count` **cannot** be unknown — it must be evaluated during plan to know how many instances to create.
- Unknown values in a data resource's config defer the read to apply; its results become unknown too.
- An unknown assigned to a `module` block argument makes the child's input variable unknown.
- An unknown in an output's `value` makes parent-module references to that output unknown.

Terraform validates unknown value types where it can, but misuse may only surface at apply, failing it. Unknown values render in plan output as `(known after apply)`.

---
Related: parent [[tf-expressions]]. Splat detail forthcoming in [[tf-expr-splat]]; `for`-expression access forthcoming in [[tf-expr-for]]. Block-local `count.index`/`each.*` from [[tf-meta-arguments]]; sensitivity from [[tf-manage-sensitive-data]]; implicit-vs-explicit deps from [[tf-meta-depends-on]].
