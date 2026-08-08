# Standard Module Structure

> **Source:** [developer.hashicorp.com/terraform/language/modules/develop/structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
> **Added:** 2026-08-08
> **Source updated:** undated language reference; captured 2026-08-08 against v1.15.x (latest)
> **Tags:** modules, module-structure, readme, license, nested-modules, examples, registry, conventions
> **Type:** documentation

*Developer › Terraform › Configuration Language › Modules › Develop modules › Standard module structure · v1.15.x*

The layout convention for reusable modules in their own repositories. [[tut-module]] and [[tut-module-create]] both showed the file list; this page gives the rules behind it, and several of them are not guessable from the tree.

The reason it is a convention and not a preference:

> **Terraform tooling is built to understand the standard module structure** and use that structure to generate documentation, index modules for the module registry, and more.

So it is machine-readable. That is also why the registry's publishing bar includes "must adhere to the standard module structure" (`cache/search/module-repo-naming-convention.md`), and why [[tut-no-code-provisioning]] requires all resources in the repository root.

## Only the root module is required

> The list may appear long, but **everything is optional except for the root module.** Most modules don't need to do any extra work to follow the standard structure.

> **Root module.** … Terraform files must exist in the root directory of the repository. This should be the primary entrypoint for the module and **is expected to be opinionated**. For the Consul module the root module sets up a complete Consul cluster. It makes a lot of assumptions however, and we expect that **advanced users will use specific nested modules** to more carefully control what they want.

That is a two-tier design pattern stated in passing: **the root is the opinionated happy path, the nested modules are the escape hatch.** It is the structural answer to [[tut-pattern-module-creation]]'s "aim to deliver a module that works for at least 80% of use cases" — the other 20% assemble the nested modules themselves rather than forcing options into the root's variable surface.

## The files

**`main.tf`, `variables.tf`, `outputs.tf`** — "recommended filenames for a minimal module, **even if they're empty**."

> `main.tf` should be the primary entrypoint. For a simple module, this may be where all the resources are created. For a complex module, resource creation may be split into multiple files but **any nested module calls should be in the main file.**

Splitting resources across files is fine; splitting `module` blocks across files is not. A reader should be able to see the module's whole composition in one place.

**Descriptions are the documentation.**

> All variables and outputs should have **one or two sentence descriptions** that explain their purpose. This is used for documentation.

**`LICENSE`** — "If you are publishing a module publicly, **many organizations will not adopt a module unless a clear license is present.** We recommend always having a license file, **even if it is not an open source license.**"

**`README` / `README.md`** — for the root module *and any nested modules*. "The latter will be treated as markdown." Should describe the module and what it should be used for; examples belong in `examples/`.

> Consider including a **visual diagram** depicting the infrastructure resources the module may create and their relationship.

!!! warning "It says *not* to document inputs and outputs in the README — and another HashiCorp page says to"
    > The README **doesn't need to document inputs or outputs** of the module because tooling will automatically generate this.

    [[tut-pattern-module-creation]] says the opposite under "Label and document module elements": *"Document all modules. Make sure the documentation includes: **Required inputs** … **Optional inputs** … **Outputs**"*, and *"Remember to document the outputs in the module's README."*

    The reconciliation is that both pages want the same artifact by different routes. The registry generates the Inputs/Outputs tables **from the `description` arguments**, so writing those descriptions *is* documenting the interface — and duplicating the table in the README just creates a copy that goes stale. Read the guide's instruction as "your interface must be documented" and this page as "here is where that documentation actually comes from". Where the guide adds something this page doesn't: **advertise a default value**, and never default a variable whose right value differs on every use (`var.vpc_id`).

!!! tip "Use commit-specific absolute URLs in a module README"
    > If you are linking to a file or embedding an image contained in the repository itself, use a **commit-specific absolute URL** so the link won't point to the wrong version of a resource in the future.

    Non-obvious, and it bites in two ways. A relative link breaks entirely once the registry renders the README outside the repository, and a branch-relative absolute URL silently starts describing a *different version* of the module than the one the reader is looking at. Same mutable-reference problem as a Git `ref=<tag>` module source (**I4**), one layer up in the documentation.

## Nested modules

Under `modules/`. And then the rule worth knowing, because nothing enforces it:

> **Any nested module with a `README.md` is considered usable by an external user. If a README doesn't exist, it is considered for internal use only.** These are **purely advisory**; Terraform will not actively deny usage of internal modules.

**The presence of a README is the public/private marker for a submodule.** There is no `internal` keyword and no enforcement — a consumer can source `./modules/whatever` regardless. So a submodule you consider private needs its documentation kept *out*, which is an odd incentive, and a submodule you accidentally give a README to has been published.

Their purpose is the two-tier pattern again: "split complex behavior into multiple small modules that advanced users can carefully pick and choose. For example, the Consul module has a nested module for creating the Cluster that is separate from the module to setup necessary IAM policies. **This allows a user to bring in their own IAM policy choices.**"

> If a repository or package contains multiple nested modules, they should ideally be **composable by the caller**, rather than calling directly to each other and creating a deeply-nested tree of modules.

Same flat-tree argument as [[tf-modules-develop]] and [[tut-pattern-module-creation]]'s two-deep rule.

## The two source-address rules point in opposite directions

Easy to get backwards, so keep them side by side.

**Root calling its own nested module → relative path.**

> If the root module includes calls to nested modules, they should use **relative paths** like `./modules/consul-cluster` so that Terraform will consider them to be **part of the same repository or package, rather than downloading them again separately.**

**An example calling the module → the external address.**

> Because examples will often be **copied into other repositories for customization**, any `module` blocks should have their `source` set to **the address an external caller would use**, not to a relative path.

The distinguishing question is who the caller will be after the code moves. Nested calls never leave the package, so a relative path keeps them in one download. Examples are *expected* to leave, so a relative path would break the moment someone copies the block — which, per [[tut-module-use]], is exactly how people adopt a module.

Examples live in `examples/` at the repository root, "Each example may have a README to explain the goal and usage of the example." **Examples for submodules also go in the root `examples/` directory**, not beside the submodule.

## The two trees

```
$ tree minimal-module/

.
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
```

```
$ tree complete-module/

.
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
├── ...
├── modules/
│   ├── nestedA/
│   │   ├── README.md
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   ├── nestedB/
│   ├── .../
├── examples/
│   ├── exampleA/
│   │   ├── main.tf
│   ├── exampleB/
│   ├── .../
```

Described as "all optional elements and… therefore the most complex a module can become".

!!! note "The minimal tree drops `LICENSE`, which the prose recommends always having"
    [[tut-module]] and [[tut-module-create]] both show `LICENSE` in the minimal layout; this page's `minimal-module/` tree omits it while the prose above says "We recommend always having a license file, even if it is not an open source license." Take the prose — a missing licence is the stated reason organizations refuse to adopt a module.

---
Related: the layout rules behind the file lists shown in [[tut-module]] and [[tut-module-create]]. Sits under [[tf-modules-develop]] in the Develop-modules group, with [[tf-modules-configuration]] as the consumer-side counterpart. Its README-documents-nothing rule conflicts with [[tut-pattern-module-creation]]'s documentation checklist, reconciled above. Registry publishing requires this structure — see `cache/search/module-repo-naming-convention.md`; the no-code variant's root-only rule is [[tut-no-code-provisioning]]. `description` arguments: [[tf-block-variable]], [[tf-block-output]]. Broader layout conventions including `.gitignore` and repo-per-module: [[tf-style-guide]]. Feeds learning-path **I5** (authoring modules).
