# Use modules in your configuration

> **Source:** [developer.hashicorp.com/terraform/language/modules/configuration](https://developer.hashicorp.com/terraform/language/modules/configuration)
> **Added:** 2026-08-08
> **Source updated:** undated language reference; captured 2026-08-08 against v1.15.x (latest)
> **Tags:** modules, module-block, source, version, git-ref, shallow-clone, const, removed-block, replace, module-outputs
> **Type:** documentation

*Developer › Terraform › Configuration Language › Modules › Use modules · v1.15.x*

The consumer half of the Modules section, after [[tf-modules]]. This is the reference behind [[tut-module-use]], and it covers a good deal that tutorial does not: Git `ref` selection, shallow clones, `const`-gated source expressions, `-replace` addressing inside modules, and removing a module without destroying it.

## The four steps

> 1. Add a `module` block to your configuration and configure the `source`, `version`, and required inputs.
> 2. If necessary, configure resources in the root module to reference outputs from the child module.
> 3. Initialize the workspace to install the module. **Terraform clones the module source configurations into a hidden subdirectory of the workspace's working directory.**
> 4. Apply the configuration to provision the module's resources.

Step 3 names what [[tut-module-use]] showed as `.terraform/modules/` — and note that for **local** modules Terraform refers to the source directory directly rather than copying, which that tutorial covers and this page does not.

## Selecting a version, and selecting a Git revision

Registry modules take `version` with a constraint ([[tf-expr-version-constraints]]). Git sources do not:

> If you are using modules hosted in GitHub, BitBucket, or another Git repository, Terraform clones and uses the **default branch referenced by HEAD**. You can add the `ref` query parameter to the location specified in the `source` argument to reference any value supported by the `git checkout` command, such as a branch, SHA-1 hash, or tag.

```hcl
module "vpc" {
  source = "git::https://example.com/vpc.git?ref=v1.2.0"
}
```

```hcl
module "storage" {
  source = "git::https://example.com/storage.git?ref=51d462976d84fdea54b47d80dcabbf680badcdb8"
}
```

An omitted `ref` means "whatever HEAD is today", which is the unpinned default worth avoiding. The tag-versus-SHA choice, and why update bots can move one but not the other, is the supply-chain callout in learning-path **I4**.

## Shallow clones — and the trap this page doesn't mention

> Add the `depth` query parameter to the `source` URL and specify how many commits the clone operation should include. The `depth` parameter adds the `--depth` option to the `git clone` command… **Setting `depth` to `1` is suitable for most cases because Terraform only uses the most recently selected commit to find the source.**

Supported for GitHub, Git, and BitBucket sources.

!!! danger "`depth` and a SHA-pinned `ref` are mutually exclusive — verified in source"
    Neither this page nor `Module Sources` says so, but a shallow clone **rejects** a commit-SHA `ref` outright. From `hashicorp/go-getter` **v1.8.6** — the version Terraform **1.15.8** vendors, confirmed from `go.mod` in the local checkout at the release commit — in `get_git.go`:

    ```go
    if depth > 0 {
        args = append(args, "--depth", strconv.Itoa(depth))
        args = append(args, "--branch", ref)
    }
    ```

    ```go
    var gitCommitIDRegex = regexp.MustCompile("^[0-9a-fA-F]{7,40}$")
    ```

    ```go
    if depth > 0 && originalRef != "" {
        if gitCommitIDRegex.MatchString(originalRef) {
            return fmt.Errorf("%w (note that setting 'depth' requires 'ref' to be a branch or tag name)", err)
        }
    }
    ```

    The mechanism is that `--depth` is passed together with `--branch <ref>`, and `git clone --branch` accepts only a branch or tag. A full clone takes the other path — `if depth < 1 && originalRef != ""` — and does a separate `checkout`, which is what lets an arbitrary SHA work at all.

    **So this is a direct trade against I4's supply-chain guidance.** SHA-pinning a third-party Git module is the answer to mutable tags; adding `depth=1` to speed up a large repository forces you back to a tag or branch. You can have the immutable pin or the shallow clone, not both. Neither docs page connects them.

    ⚠️ Read from the vendored library source, not reproduced against a live repository.

## Variables in `source` and `version`

> Terraform evaluates the value of most variables when it creates a Terraform plan. **Since Terraform installs modules when a workspace is initialized or during a "Get" operation, those variable's values will not be available.** Any input variable referenced in a module block's `source` or `version` arguments must declare `const = true`.

That sentence is the *why* behind the `const` requirement, and it is a timing argument, not a safety one: module installation happens at `init`, before plan-time evaluation exists. The dedicated section at the bottom of the page gives three shapes:

```hcl
module "consul" {
  source = var.module_source
}

variable "module_source" {
  type  = string
  const = true
}
```

Composed from several const variables through a local:

```hcl
module "vpc" {
  source = local.vpc_source
}

variable "module_repo" {
  type  = string
  const = true
}

variable "module_ref" {
  type  = string
  const = true
}

locals {
  vpc_source = "git::https://example.com/${var.module_repo}.git?ref=${var.module_ref}"
}
```

And on `version`:

```hcl
module "consul" {
  source  = "hashicorp/consul/aws"
  version = var.consul_version
}

variable "consul_version" {
  type  = string
  const = true
}
```

> The `source` and `version` expressions can only reference things that are known during configuration loading. Terraform will show an error if they reference something that is only known after a plan.

Note that a **local value** is allowed in the source position as long as everything feeding it is const — so the constraint is on the *dependency chain*, not on the syntactic form. The `const` argument itself is specified in [[tf-block-variable]]; this is Terraform **1.15**'s dynamic module sources, which learning-path **I4** already flags as a 1.15 gap-closer against OpenTofu.

## Meta-arguments on a `module` block

- **`count`** — "how many instances of a module to provision. All instances have the same configuration."
- **`for_each`** — "loop through a set of keys so that Terraform provisions similar module instances."
- **`depends_on`** — "Terraform completes all operations on the upstream resource before performing operations on the module containing the `depends_on` argument." With the implicit case stated first: "If a module definition references a resource in its arguments, Terraform identifies the implicit dependency and implements the changes in the appropriate order."
- **`provider`** — "By default, Terraform applies the default provider based on the module resource type, but you can create multiple provider configurations and use a non-default configuration for specific modules."

The page lists these without their interactions. The ones that bite are elsewhere: `count` and `for_each` cannot both be on one block, and a module using either **cannot declare a `provider` block** and must inherit ([[tut-for-each]], [[tf-meta-providers]]). The `depends_on`-on-a-module cost — more values forced to `(known after apply)`, more resources replaced — is in [[tf-meta-depends-on]].

## Referencing outputs

`module.<MODULE-NAME>.<OUTPUT-NAME>`:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"
}

resource "aws_subnet" "main" {
  vpc_id     = module.vpc.vpc_id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main"
   }
 }
```

(The stray indentation on the closing braces is the page's.) Worth noting the pin: **6.0.1**, a current major, where every tutorial in the Modules collection still pins 3.x. The reference docs are maintained; the tutorials are not.

## Installing and re-installing

> If you change the `source` argument or change the `version` argument for a module in a registry, **you must rerun `terraform init`**. For modules that are already installed, include the **`-upgrade`** flag to upgrade the module to the latest version allowed by the version constraint.

The asymmetry to hold on to: **`init` alone honours what is already installed; `-upgrade` re-resolves the constraint.** With no lock file for modules ([[tf-dependency-lock]] records providers only), that re-resolution is exactly where an untested version can arrive — the hazard learning-path **I4** answers with exact pins.

## Reprovisioning inside a module

```shell
$ terraform apply -replace=module.example.aws_instance.example
```

```shell
terraform plan -replace=module.example.module.from-child2.aws_instance.child2-inst
```

The second shows a **nested** path: "If the resource you want to replace belongs to a resource within a nested module, specify the full path to that resource, including the nested module."

> **Replacing resources is a disruptive operation.** You can only select individual resource instances with the `-replace` CLI option. Add multiple `-replace` options to replace more than one resource in a single command.

So `-replace` takes instance addresses only — no module-wide replace, no wildcards.

## Removing a module

Deleting the `module` block and applying **destroys** its resources by default. To drop them from state and leave the infrastructure alone:

```hcl
removed {
  from = module.example

  lifecycle {
    destroy = false
  }
}
```

Note the target is `module.example`, the whole module call, not an individual resource. `removed` requires **Terraform v1.7+**; before that, `terraform state rm`. The full argument surface, and the version drift in what `removed` meant across releases, is [[tf-block-removed]] — and the `destroy = false` requirement is already a danger callout in learning-path **I7**, because omitting it plans a destroy.

## Errors on the page

!!! warning "The removal section is garbled, and its closing link points at the wrong reference"
    Three defects in one short section:

    - **Wrong link target.** It closes with "Refer to **moved block reference** for more information" at the end of the section about the **`removed`** block. Should be the `removed` block reference ([[tf-block-removed]]).
    - **Stray conjunction and an unclosed backtick** in the instructions: *"Replace the module block from your configuration with a `removed` block. **And** add the lifecycle block to your removed block. Add the destroy argument and set it to `false."*
    - **A version note stranded mid-paragraph.** "Terraform v1.7 or later is required to use the `removed` block. To remove a resource in earlier versions, use the `terraform state rm` CLI command" sits inside the paragraph explaining that deleting a block destroys resources, before `removed` has been introduced at all.

!!! note "Typo carried across two pages"
    "GitHub **repositoris**" appears in the shallow-clone source list here and identically on `Module Sources`, so the two pages share a content fragment.

---
Related: the consumer half of [[tf-modules]]'s Develop/Distribute/Provision split, and the reference behind [[tut-module-use]] — which demonstrates the `module` block and output references but covers none of `ref`, `depth`, `const`, `-replace`, or `removed`. Version constraints: [[tf-expr-version-constraints]]; the absence of a module lock: [[tf-dependency-lock]]. Meta-argument interactions the page omits: [[tut-for-each]], [[tf-meta-providers]], [[tf-meta-depends-on]]. `const` argument spec: [[tf-block-variable]]. Removal semantics and version drift: [[tf-block-removed]]; moving rather than removing: [[tut-move-config]]. Feeds learning-path **I4** (its primary reference), with the `removed` half in **I7** and the shallow-clone-versus-SHA-pin trade sharpening I4's Git-sources callout.
