# Module creation — recommended pattern

> **Source:** [developer.hashicorp.com/terraform/tutorials/modules/pattern-module-creation](https://developer.hashicorp.com/terraform/tutorials/modules/pattern-module-creation)
> **Added:** 2026-08-08
> **Source updated:** undated guide (~17 min); captured 2026-08-08
> **Tags:** modules, module-design, scoping, encapsulation, privileges, volatility, mvp, nested-modules, collaboration, governance
> **Type:** documentation

Eighth page of the **Modules** collection, and the second with no code — but where [[tut-private-registry-add]] had no code because it was a UI walkthrough, this one has none because it is an **architecture guide**. It belongs to HashiCorp's *Recommended Enterprise Patterns* series. Nothing to clone, nothing to apply.

> This guide discusses module architecture principles to help you write composable, sharable, reusable infrastructure modules. These architectural recommendations can be helpful to enterprises using any edition of Terraform. However, some features like the private registry are only present in HCP Terraform and Terraform Enterprise.

This is the page the rest of the collection has been building toward. [[tut-module-create]] asked *which arguments should be variables*; this one asks the prior question — **which resources belong in the same module at all**.

## The workflow starts with a customer, not a diagram

> The first step in creating a new module is to find an early adopter team and gather their requirements.

Then two steps: scope the requirements into modules, and build an MVP. Worth noting that the guide's first move is organizational rather than technical, and that its stated payoff is onboarding "other teams with similar requirements with minimal code alterations" — a module validated against one real consumer generalizes; a module designed in the abstract does not.

## Scoping: the three axes

The core of the page, and the most portable idea in the collection.

> Modules should be opinionated and designed to do one thing well. **If a module's function or purpose is hard to explain, the module is probably too complex.** When initially scoping your module, aim for small and simple to start.

**Encapsulation — group infrastructure that is always deployed together.** With the tension stated honestly rather than hidden: "Including more infrastructure in a module makes it easier for an end user to deploy that infrastructure but makes the module's purpose and requirements harder to understand." Ease of consumption trades against comprehensibility.

**Privileges — restrict modules to privilege boundaries.** "If infrastructure in the module is the responsibility of more than one group, using that module could accidentally violate segregation of duties."

**Volatility — separate long-lived infrastructure from short-lived.** "Database infrastructure is relatively static while teams could deploy application servers multiple times a day. Managing database infrastructure in the same module as application servers exposes infrastructure that stores state to unnecessary churn and risk."

!!! tip "Privilege and volatility are blast-radius arguments, and that's why they generalize"
    Encapsulation is the intuitive axis — it's the one every "what goes in a module?" discussion starts with. The other two are the ones worth memorizing, because they say **who can break it** and **how often it gets touched**, which is precisely what [[tut-organize-configuration]] demonstrated the hard way when one shared `random_pet` let a dev-file edit destroy production.

    The same two axes also decide **state boundaries**, not just module boundaries. A module scoped to a privilege boundary that then gets applied from a state shared with everything else has thrown the benefit away — which is why this page and A7's directory-per-environment argument are the same argument at two granularities.

## The MVP rules

> Modules, like any piece of code, are never complete.

- **"Always aim to deliver a module that works for at least 80% of use cases."**
- **"Never code for edge cases in modules. An edge case is rare. A module should be a reusable block of code."**
- **"Avoid conditional expressions in an MVP. An MVP should have a narrow scope and should not do multiple things."**
- "The module should only expose the most commonly modified arguments as variables."

Then the one rule that runs the other way:

> **Maximize outputs.** Output as much information as possible from your module MVP even if you do not currently have a use for it. This will make your module more useful for end users who will often use multiple modules, using outputs from one module as inputs for the next.

!!! note "Minimize inputs, maximize outputs — the asymmetry is deliberate"
    Every input is a promise: it must be honored, documented, tested, and kept working across versions. Every output is just a value you already computed, and the page's reason for exposing it is composition — one module's output is the next module's input, which is exactly the wiring in [[tut-module-use]].

    Read against [[tut-module-object-attributes]], "avoid conditional expressions in an MVP" is not a contradiction of `optional()` and `dynamic` blocks — it is a statement about *sequencing*. Ship narrow, add flexibility when a second real consumer asks for it, and use optional object attributes to add it **without breaking the first consumer**. That page's own argument for objects was exactly this: ship new versions "without changing the variables that module users need to define".

## The worked scoping example

A three-tier web/app application on a dedicated VPC, split by a "Terraform producer" team into six modules for a consuming application team.

[![Three-tier architecture: Route 53 and hosted zone, a VPC containing network ACL, NAT gateway, route table, a WEB autoscaling group behind a load balancer, an APP autoscaling group behind a second load balancer, plus a database and S3 bucket, with IAM alongside](assets/tut-pattern-module-creation/01-three-tier-architecture.png)](assets/tut-pattern-module-creation/01-three-tier-architecture.png)
*The scenario the six modules carve up. Note that the boxes in this diagram are AWS constructs, not module boundaries — the split below cuts across it.*

| Module | Contains | Privilege | Volatility |
|---|---|---|---|
| **Network** | network ACLs, NAT gateway (could add VPC, subnets, peering, Direct Connect) | high | low |
| **Web** | load balancer, autoscaling group (could add EC2, S3, security groups, logging) | — (encapsulated) | **high** |
| **App** | load balancer, autoscaling group, S3 buckets | — (encapsulated) | **high** |
| **Database** | RDS instance (could add storage, backups, logging) | high | low |
| **Routing** | hosted zones, Route 53, route tables | high | low |
| **Security** | IAM (could add security groups, MFA) | high | low |

The pattern that falls out: **four low-volatility, high-privilege modules and two high-volatility, encapsulated ones.** The application modules change "with each code release" and take a prebuilt AMI ID (built by Packer) as input; everything else is infrastructure the app team touches rarely and may not be allowed to touch at all.

Two details worth keeping. The producer team is expected to "import them into the private registry, and advertise their availability" — the publishing step of [[tut-module-private-registry-share]] in its organizational context. And consumers are expected to contribute back: "As the application team becomes more familiar with Terraform code, they can suggest infrastructure enhancements or changes via pull request in conjunction with releases of their application code."

## Nesting: two different things called the same thing

> A nested module is a reference to invoke another module from the current module. Nested modules can be located externally and are referred to as "child modules", or embedded inside the current workspace and are referred to as "submodules".

General rules for both:

- Document input variables, module behavior, and outputs clearly — nesting "can lead to unclear and unexpected outcomes".
- **"Generally, do not nest primary modules more than two deep."** Common utility modules, like a tagging module, are the exception.
- Consistent naming across modules so input/output parameters map cleanly.
- Nesting causes redundancy: "Variable definitions and outputs need to be defined in nested and parent modules."

**External (child) modules** — independently maintained and versioned, distributed via a registry. The hazard is stated sharply:

> A change to the nested module can affect the parent module with **no changes to the parent's calling code or version**, thereby breaking the calling code's trust.

That is an unpinned transitive dependency, and it is the same class of problem as **I4**'s "no lock file for modules" hazard, one level deeper: your caller pins *your* module, but nothing they can see pins what *you* call. The mitigations offered are backwards compatibility as a rule, documenting how parents use external modules, and distributing breaking-change notices to consumers.

**Submodules (embedded)** — versioned with the parent, so incompatibilities surface immediately because "they must be released and tested together". The cost is reuse: "The submodule cannot be invoked by another module outside of the source tree so there may be increased code duplication."

```
root-module-directory
├── README.md
├── main.tf
└── ec2-instances
    └── main.tf
```

So the choice is **shared-and-drifting versus duplicated-and-locked-together**, which is the same trade [[tut-organize-configuration]] made between workspaces and directories.

## Naming, documentation, structure

The naming convention table:

| terraform | cloud provider | function | full name |
|---|---|---|---|
| terraform | aws | consul cluster | `terraform-aws-consul_cluster` |
| terraform | aws | security module | `terraform-aws-security` |
| terraform | azure | database | `terraform-azure-database` |

!!! warning "Two problems in a three-row table"
    **`terraform-azure-database` names a provider that does not exist.** The middle segment is *"the main provider where it creates that infrastructure"* ([Publishing Modules](https://developer.hashicorp.com/terraform/registry/modules/publish)), and the Azure provider's name is **`azurerm`** — verified against the Registry API 2026-08-08, which reports `name: azurerm`, `namespace: hashicorp`. There is no `hashicorp/azure`. The correct form is `terraform-azurerm-database`, which is what every module in the registry's Azure namespace actually uses.

    **The table is internally inconsistent on separators** — `consul_cluster` with an underscore, `security` and `database` without. Public-registry modules overwhelmingly hyphenate (`terraform-aws-ec2-instance`, `terraform-google-vault`), so hyphenate.

    Third page in this collection to fumble this convention, after [[tut-module]] called it a *provider* naming rule. [[tut-module-private-registry-share]] is still the only one that states it cleanly. Cross-check: `cache/search/module-repo-naming-convention.md`.

**Documentation** splits inputs by whether they may have a default, which is a sharper framing than "required vs optional":

> **Required inputs:** These variables should be a deliberate choice. The module will fail if they are not defined. Only set defaults for variables that should have them. For example `var.vpc_id` should never have a default because the value would be different every time you use the module.
>
> **Optional inputs:** These should have a sensible default that will be acceptable in most use cases but may need adjusting. **Advertise the default value.** For example `var.elb_idle_timeout` will have a sensible default, but there is a chance that someone may need to modify it.

The `var.vpc_id` test is the useful one to carry: **if the right value differs on every use, a default is a trap, not a convenience.**

**Structure** — the recommendation is consistency rather than any particular layout ("module structure is a matter of taste"): fix a list of required `.tf` files and their contents, a `.gitignore`, a standard `terraform.tfvars.example`, a fixed directory set "even if they may be empty", and a README in every directory. Overlaps [[tf-style-guide]], which does prescribe a layout.

## Collaboration and source control

The collaboration section reads like open-source maintainer advice, which is the point ("Adopt open-source community principles within the company"). Roadmap per module; requirements prioritized by popularity; a published, curated requirement list; "Don't prioritize edge-cases"; document every decision; a contribution guide; eventually let trusted community members own modules.

The line worth pinning:

> The most common reason for not using a module is that "It does not do what I want."

Source control practice, compactly:

- Modules in version control, each with an **assigned owner**.
- **"Select either the tag-based or branch-based publishing workflow"** — the choice analyzed in [[tut-module-private-registry-share]], where the decisive difference is that only branch-based supports module testing.
- Pull-request review before release.
- A README at minimum, plus **a change log published each version**.

## Consumption workflow, and where enforcement actually lives

The final section names three HCP/TFE tools and, in doing so, closes a question [[tut-private-registry-add]] left open.

- **Private registry** — searchable, filterable browsing of your modules.
- **UI** — "less intimidating for Terraform novices and has a lower barrier to entry".
- **Configuration designer** — "functions like interactive documentation for your private modules, or very advanced autocompletion. It results in the same Terraform code you would write in a text editor, and saves time by automatically discovering variables and searching module and workspace outputs for reusable values."

And three governance patterns:

- **Devolved security** — "If each module is versioned in its own repository, repository RBAC can be used to manage who has write access, allowing relevant teams to manage related infrastructure (such as the network team owning write access on network modules)." One repo per module is what makes the Privileges scoping axis enforceable in practice.
- **Fostering a code community** — allow pull requests on all module repositories.
- **Policy enforcement** —

    > With Sentinel, you can assign policy criteria to all Terraform plans before execution. This allows for enforcement such that **only modules from the private Terraform registry can be used**.

!!! tip "This is the enforcement answer [[tut-private-registry-add]] was missing"
    That page called curated modules "approved" while the docs made clear the registry only "stores a pointer" and that removing an entry changes nobody's configuration. Here HashiCorp says plainly where the control lives: **Sentinel policy on the plan**, with "only modules from the private registry may be used" as the named example. Curation makes the approved set discoverable; policy makes it binding. That is the **A4 / A5** seam, stated by the vendor.

!!! note "Stale product naming"
    The consumption section says "Terraform Enterprise provides tools, like the private Terraform registry and configuration designer" and "The Terraform Enterprise UI", where earlier sections correctly say HCP Terraform. Both products have these features; the page is just inconsistent. The configuration designer is current — it has its own page in the HCP Terraform docs sidebar (`registry/design`).

## Next steps

Pointers are the Terraform modules documentation, the *Reuse Configuration with Modules* tutorial collection, and the no-code modules tutorial. Next in the collection is moving resources.

---
Related: eighth in the Modules collection, and the design theory behind it — [[tut-module-create]] and [[tut-module-object-attributes]] are the mechanics, this is the scoping. The Privileges and Volatility axes are the module-level statement of the blast-radius lesson [[tut-organize-configuration]] demonstrates. Publishing workflow choice and the registry: [[tut-module-private-registry-share]]; curation-versus-enforcement: [[tut-private-registry-add]]. The unpinned-transitive-dependency hazard in external nested modules extends [[tf-dependency-lock]] (providers only) and [[tf-expr-version-constraints]]. Structure and naming overlap [[tf-style-guide]]. Feeds learning-path **I5** (authoring modules — its design section), **A4**/**A5** (registry tooling and Sentinel enforcement), **A7** (the same axes at state granularity), and **E6** (platform engineering — producer/consumer teams, devolved security, code community).
