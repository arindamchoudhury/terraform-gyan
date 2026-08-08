# Module Composition

> **Source:** [developer.hashicorp.com/terraform/language/modules/develop/composition](https://developer.hashicorp.com/terraform/language/modules/develop/composition)
> **Added:** 2026-08-08
> **Source updated:** undated language reference; captured 2026-08-08 against v1.15.x (latest)
> **Tags:** modules, composition, dependency-inversion, object-types, structural-typing, preconditions, multi-cloud, data-only-modules
> **Type:** documentation

*Developer › Terraform › Configuration Language › Modules › Develop modules › Best practices for composing modules · v1.15.x*

Six design patterns, and the most substantial page in the Modules section. Where [[tf-modules-develop]] says *whether* to write a module and [[tf-modules-structure]] says how to lay it out, this one says how modules should relate to each other. [[tut-pattern-module-creation]] covers similar ground from an enterprise-process angle; this is the language-level treatment and it is sharper.

## Composition: flat, wired with expressions

A single root module is a flat set of resources wired by references. Introducing `module` blocks makes the configuration hierarchical, "which can potentially create a deep, complex tree of resource configurations."

> in most cases we strongly recommend keeping the module tree **flat, with only one level of child modules**, and use a technique similar to the above of using expressions to describe the relationships between the modules

```hcl
module "network" {
  source = "./modules/aws-network"

  base_cidr_block = "10.0.0.0/8"
}

module "consul_cluster" {
  source = "./modules/aws-consul-cluster"

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.subnet_ids
}
```

> Instead of a module **embedding** its dependencies, creating and managing its own copy, the module **receives** its dependencies from the root module, which can therefore connect the same modules in **different ways to produce different results.**

Note this is stricter than the "two deep" guidance in [[tut-pattern-module-creation]] — **one** level of child modules, and composition rather than nesting for everything else.

## Dependency inversion

Why `consul_cluster` takes a `vpc_id` instead of creating its own network:

> if we did that then it would be hard for the Consul cluster to coexist with other infrastructure in the same network, and so where possible we prefer to keep modules relatively small and pass in their dependencies.

The refactoring payoff is the part worth keeping:

> This dependency inversion approach also improves flexibility for future refactoring, because the `consul_cluster` module **doesn't know or care how those identifiers are obtained** by the calling module.

So the same module accepts `module.network.vpc_id` today and `data.aws_vpc.main.id` after the network moves to its own configuration — no change to the module. That is the same seam [[tf-remote-state-data]] and **I6** deal with when a system is split across states.

## Conditional creation: pass the object, don't detect it

The situation: an object already exists in some environments and must be created in others — shared dev infrastructure versus dedicated production.

> Rather than trying to write a module that **itself tries to detect whether something exists and create it if not**, we recommend applying the dependency inversion approach: making the module accept the object it needs as an argument, via an input variable.

```hcl
variable "ami" {
  type = object({
    # Declare an object using only the subset of attributes the module
    # needs. Terraform will allow any object that has at least these
    # attributes.
    id           = string
    architecture = string
  })
}
```

Then the caller decides, and either a **resource** or a **data source** satisfies the same variable:

```hcl
# In situations where the AMI will be directly managed:

resource "aws_ami_copy" "example" {
  name              = "local-copy-of-ami"
  source_ami_id     = "ami-abc123"
  source_ami_region = "eu-west-1"
}

module "example" {
  source = "./modules/example"

  ami = aws_ami_copy.example
}
```

```hcl
# Or, in situations where the AMI already exists:

data "aws_ami" "example" {
  owner = "9999933333"

  tags = {
    application = "example-app"
    environment = "dev"
  }
}

module "example" {
  source = "./modules/example"

  ami = data.aws_ami.example
}
```

> This is consistent with Terraform's declarative style: rather than creating modules with complex conditional branches, **we directly describe what should already exist and what we want Terraform to manage itself.**

> A future reader of the configuration can then directly understand what it is intending to do **without first needing to inspect the state of the remote system.**

!!! tip "The mechanism here is the one Ch 12 recorded as a footgun — and the difference is intent"
    *"Terraform will allow any object that has at least these attributes"* is the same behavior the Type Constraints page states as *"values with additional attributes are also acceptable, but the extra attributes are discarded during type conversion"* ([[tf-expr-type-constraints]]). Ch 12 measured its cost at a module boundary on 1.15.8: a caller's misspelled attribute is silently dropped, `optional()` fills the gap with a default, and `terraform validate` prints `Success!`.

    Here that exact behavior **is the feature**. Declaring only `id` and `architecture` gives you structural typing — anything shaped enough to be an AMI passes, whether it came from a `resource` or a `data` source — and that is what makes one variable accept both branches of the conditional.

    **You cannot have both.** Duck-typed inputs and typo detection are the same knob turned two ways. Worth knowing which one you are choosing: a *deliberately* partial object type is this pattern; an *accidentally* partial one is Ch 12's silent no-op. **OpenTofu 1.12.4 warns on the discard for module calls** (`Warning: Object attribute is ignored`) and Terraform never does, which makes OpenTofu slightly noisier for this pattern and slightly safer against the typo.

!!! warning "Two errors in these examples — both would fail `validate`"
    **`owner = "9999933333"`** on the `aws_ami` data source. The argument is **`owners`**, a **list**: *"owners - (Optional) List of AMI owners to limit search."* No singular `owner` argument exists. Verified against the AWS provider's docs source on `main`, 2026-08-08.

    **`data "aws_subnet_ids"`** in the dependency-inversion example. **That data source no longer exists** — its documentation page 404s in the provider repository on `main`, while `aws_subnets` returns 200. It was the pre-v4 way to list subnet IDs; `aws_subnets` (with `ids` output) replaced it. Checked 2026-08-08.

    Neither is load-bearing for the pattern, but both would stop a reader who copies the snippet.

## Assumptions and guarantees

Definitions worth keeping, because they name the two directions of a module's contract:

> **Assumption:** A condition that must be true in order for the configuration of a particular resource to be **usable**. For example, an `aws_instance` configuration can have the assumption that the given AMI will always be configured for the x86_64 CPU architecture.
>
> **Guarantee:** A characteristic or behavior of an object that **the rest of the configuration should be able to rely on.** For example, an `aws_instance` configuration can have the guarantee that an EC2 instance will be running in a network that assigns it a private DNS record.

> We recommend **validating your configuration** to help capture and test for assumptions and guarantees. This helps future maintainers understand the configuration design and intent. Configuration validation returns useful information about **errors earlier and in context.**

```hcl
output "api_base_url" {
  value = "https://${aws_instance.example.private_dns}:8433/"

  # The EC2 instance must have an encrypted root volume.
  precondition {
    condition     = data.aws_ebs_volume.example.encrypted
    error_message = "The server's root volume is not encrypted."
  }
}
```

The example puts the check on an **`output`**, which is the right place for a *guarantee* — the module asserts something about what it hands back. Assumptions belong on inputs, as `validation` blocks on variables, or as `precondition`s on the resources that consume them. The full check surface — `validation`, `precondition`, `postcondition`, `check` — is **A2**, with the argument spec in [[tf-block-output]] and [[tf-block-variable]].

Note the pairing with the previous section: an `object(...)` variable enforces *shape*, a `validation` block enforces *content*. The `ami` variable above guarantees `architecture` exists; only a validation can require it to be `x86_64`.

## Multi-cloud abstractions — build your own or not at all

> Terraform itself **intentionally does not attempt to abstract over similar services offered by different vendors**, because we want to expose the full functionality in each offering and yet unifying multiple offerings behind a single interface will tend to require a **"lowest common denominator"** approach.

That is a clear statement of a design decision people frequently expect otherwise. The offered alternative is to make the tradeoff yourself, deliberately, where vendors implement a shared concept, protocol, or open standard:

```hcl
variable "recordsets" {
  type = list(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
  }))
}
```

> we've created a lightweight abstraction in the form of a "recordset" object… If we later wanted to switch to a different DNS provider, we'd need only to **replace the `dns_records` module with a new implementation** targeting that provider, and all of the configuration that produces the recordset definitions can remain unchanged.

The DNS example composes the recordsets with a `for` expression over another module's output before passing them in:

```hcl
locals {
  fixed_recordsets = [
    {
      name = "www"
      type = "CNAME"
      ttl  = 3600
      records = [
        "webserver01",
        "webserver02",
        "webserver03",
      ]
    },
  ]
  server_recordsets = [
    for i, addr in module.webserver.public_ip_addrs : {
      name    = format("webserver%02d", i)
      type    = "A"
      records = [addr]
    }
  ]
}

module "dns_records" {
  source = "./modules/route53-dns-records"

  route53_zone_id = var.route53_zone_id
  recordsets      = concat(local.fixed_recordsets, local.server_recordsets)
}
```

The Kubernetes variant is thinner and more general: several cluster modules that differ entirely inside but **all export `hostname`**, so anything downstream takes only that.

```hcl
output "hostname" {
  value = azurerm_kubernetes_cluster.main.fqdn
}
```

**The abstraction is the agreed input/output type, not the module.** An object type for the input side, a shared output name for the output side — that is the whole mechanism, and it is why [[tut-module-object-attributes]]'s advice to mirror the wrapped resource's schema has a limit: an interface meant to span vendors must deliberately *not* mirror any one of them.

!!! note "`ttl` is required in that type but absent from `server_recordsets`"
    The `recordsets` type declares `ttl = number` without `optional()`, yet the `for`-generated A records set only `name`, `type`, and `records`. As written the `concat` would fail the type constraint. The fix is `ttl = optional(number)` ([[tf-expr-type-constraints]]) — a small illustration of exactly the interface-design point [[tut-module-object-attributes]] makes.

## Data-only modules

> It may sometimes be useful to write modules that **do not describe any new infrastructure at all**, but merely retrieve information about existing infrastructure that was created elsewhere using data sources.

> As with conventional modules, we suggest using this technique **only when the module raises the level of abstraction** in some way, in this case by **encapsulating exactly how the data is retrieved.**

```hcl
module "network" {
  source = "./modules/join-network-aws"

  environment = "production"
}

module "k8s_cluster" {
  source = "./modules/aws-k8s-cluster"

  subnet_ids = module.network.aws_subnet_ids
}
```

The point is the indirection: the module "could query the AWS API directly using `aws_vpc` and `aws_subnet_ids` data sources, or it could read saved information from a Consul cluster using `consul_keys`, or it might read the outputs directly from the state of the configuration that manages the network using `terraform_remote_state`."

> The key benefit of this approach is that the **source of this information can change over time without updating every configuration that depends on it.**

And the refactoring trick:

> if you design your data-only module with a **similar set of outputs as a corresponding management module**, you can **swap between the two** relatively easily when refactoring.

A `create-network` module and a `join-network` module with matching outputs are interchangeable, so promoting an environment from "shares the shared network" to "owns its network" is a one-line `source` change. That is the most useful idea on the page for **A7**'s multi-environment problem, and neither [[tut-organize-configuration]] nor [[tut-pattern-module-creation]] mentions it.

---
Related: the design half of the Develop-modules group, after [[tf-modules-develop]]'s "when not to" and [[tf-modules-structure]]'s layout. Its object-typed inputs are the deliberate use of the discard behavior [[tf-expr-type-constraints]] specifies and Ch 12 measured as a footgun; `optional()` mechanics are [[tut-module-object-attributes]]. Preconditions and the wider check surface: [[tf-block-output]], [[tf-block-variable]], and **A2**. Dependency inversion across state boundaries: [[tf-remote-state-data]]. Process-level counterpart: [[tut-pattern-module-creation]]. Feeds learning-path **I5** (authoring modules) as its design reference, **A7** (the swappable data-only/management module pair), and **A2** (assumptions versus guarantees as the framing for validation).
