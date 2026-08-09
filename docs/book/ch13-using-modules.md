# Chapter 13 — Using modules

## Learning outcomes

By the end you can:

- Explain why every configuration you have written so far was already a module, and what a `module` block adds.
- Name the seven arguments a `module` block defines itself, and say what happens to every other argument you write in one.
- Read a `source` address of any kind, and say where the package comes from, which sub-directory is used, and what pins it.
- Choose a version constraint for a registry module, and say exactly what `~> 4.1` will and will not install.
- Explain why the same commit produces different module versions on two machines, and name the three controls that stop it.
- Predict which of `init` and `init -upgrade` re-resolves a module, for both registry and Git sources.
- Compose a module `source` from variables under Terraform 1.15, and say why those variables need `const = true`.
- Reference a child module's outputs, and explain why `terraform output` cannot see them.
- Audit every module a configuration depends on from the command line.

---

## 1. Everything you have written is already a module

Chapter 12 left you able to write a configuration that takes typed inputs and generates the blocks a provider needs. That is a module worth reusing. This chapter is about the other side of the transaction: being the caller.

Start with the definition, because it is broader than most people expect. HashiCorp's [Modules overview tutorial](https://developer.hashicorp.com/terraform/tutorials/modules/module) puts it structurally: *"A Terraform module is a set of Terraform configuration files in a single directory."* The [language reference's Modules overview](https://developer.hashicorp.com/terraform/language/modules) puts it semantically: *"A module is a collection of resources that Terraform manages together."*

Both are official and both are true. The directory is the mechanism. The resources managed together are the thing. The structural definition is the one that produces the surprise: a directory with one `.tf` file in it is a module, so there is no "before modules" state you graduate out of.

Three names follow from that.

**Root module** — the directory you run `terraform` commands in. Its files are read directly, and it is the only place a `provider` block belongs.

**Child module** — a module called from another one, through a `module` block.

**Submodule** — a module shipped *inside* another module, conventionally in its `modules/` directory. It is coupled to its parent and is not usually consumed on its own. The `//` syntax in section 3 is how you would reach one anyway.

A root module can call the same child several times, and a child can call children of its own. Nesting has no hard limit and does have a practical one: past two levels deep, working out which module set a given argument becomes genuinely hard.

The mechanical fact underneath is the one to hold on to. Terraform reads the `.tf` files in **one** directory. It does not walk subdirectories, and it does not pick up a `modules/` folder because of its name. A `module` block is the only thing that makes Terraform read another directory at all.

### The problem that makes you want one

Chapter 6 gave you variables, so you can already parameterise a configuration. Suppose you now need staging and production, nearly identical, with production running larger and more of everything.

Copy the directory and you have solved it for today. What you have actually bought is a duplicate. Every fix now has to be made twice, and the two copies drift apart in exactly the ways nobody notices until an incident. The Modules overview tutorial lists the failure modes plainly: navigating the files gets harder, a change in one section has unintended consequences elsewhere, duplication across environments means every update lands in each copy, and sharing between teams degenerates into copy-paste, which it calls *"error prone and hard to maintain"*.

The function analogy is the right one, and it is the frame *Terraform: Up & Running* runs its whole module chapter on. In a general-purpose language you extract repeated code into a function and call it from several places. Here you extract it into a module and call it from several places.

| Function concept | Terraform mechanism |
|---|---|
| Define once, call many times | `module` block with `source` |
| Parameters | `variable` blocks in the child |
| Local intermediate values | `locals` in the child |
| Return values | `output` blocks in the child |
| Library versioning | `version` on a registry source, or a Git `ref` |

There is a second argument for modules that has nothing to do with tidiness, and it is the stronger one. Object storage has a large configuration surface, and misconfigured buckets are a recurring incident class. A module is where you encode the correct settings once, so that every caller gets them without deciding anything. The tutorial's worked example is one module for the organisation's public website buckets and another for its private logging buckets. When the correct settings change, they change in one place.

There is a third benefit that this chapter cannot deliver on its own. A shared module in a registry is what lets a team with no Terraform expertise provision infrastructure inside your organisation's standards, either by calling the module or through HCP Terraform's no-code provisioning. That is the self-service argument, and it needs the registry side of the story. Chapter 21 covers HCP Terraform and Chapter 31 covers platform engineering and self-service.

!!! note "Consuming and authoring are different skills, and this chapter is only the first"
    The language reference organises the whole modules section around three phases: **Develop** a module, **Distribute** it, then **Provision** with it. This chapter is Provision, the caller's side: finding a module, pinning it, passing it inputs, reading its outputs, and knowing what it installed.

    Chapter 14 is Develop and Distribute. The input variables stop being arguments you fill in and become an interface you are responsible for, the directory layout starts mattering because a registry enforces it, and the repository naming convention `terraform-<PROVIDER>-<NAME>` becomes a requirement rather than a curiosity. The two chapters share vocabulary and almost nothing else.

---

## 2. The `module` block

The calling convention is small enough to state in one sentence. A `module` block takes `source`, optionally `version`, up to four meta-arguments, and one 1.15 opt-out. **Every other argument in the block is an input variable for the module.**

```hcl
module "logs" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.1"

  bucket     = "acme-app-logs"          # from here down, the module's own inputs
  versioning = { enabled = true }
  tags       = { Purpose = "audit" }
}
```

The full argument surface, from the [`module` block reference](https://developer.hashicorp.com/terraform/language/block/module):

| Argument | Required | Notes |
|---|---|---|
| `source` | **yes** | Where the module comes from. Section 3. |
| `version` | no | **Registry sources only.** Section 4. |
| `count` | no | Mutually exclusive with `for_each`. |
| `for_each` | no | Mutually exclusive with `count`. |
| `depends_on` | no | Applies to every resource inside the module. |
| `providers` | no | Maps the caller's provider configurations onto the child's. Chapter 17. |
| `ignore_nested_deprecations` | no | Terraform **1.15+**. Suppresses deprecation warnings raised by the module. |

The label after `module` is yours. It is how you address the call everywhere else: `module.logs`, `module.logs.s3_bucket_arn`, `module.logs.aws_s3_bucket.this[0]` in state.

Which inputs a module accepts is not your decision. The reference is blunt about it: *"the module developer determines which inputs you can specify"*. A required input you omit is an error. An optional input you omit falls back to the module's own default, which you cannot see from the call site. That asymmetry is the first thing that makes reading a module's documentation non-optional.

!!! info "`ignore_nested_deprecations` — the consumer's opt-out, new in 1.15"
    A module author can mark a variable or an output `deprecated`, which raises a warning in every configuration that still uses it. Setting `ignore_nested_deprecations = true` on the `module` block silences those warnings for that call and everything nested below it. Default is `false`.

    Use it to keep a noisy CI log readable while an upgrade is scheduled, not to make the notice go away permanently. The `deprecated` argument itself is Chapter 14.

---

## 3. Where a module comes from

`source` is the only required argument, and it carries more meaning than any other string in a Terraform configuration. It decides what gets downloaded, where it is cached, whether `version` is even legal, and what pins the thing you end up running.

### The source catalogue

| Form | Example | `version` allowed? | Pinned by |
|---|---|---|---|
| Local path | `./modules/data-bucket` | no | the containing repository |
| Registry | `terraform-aws-modules/vpc/aws` | **yes** | `version` constraint |
| Private registry | `app.terraform.io/acme/vpc/aws` | **yes** | `version` constraint |
| Generic instance registry | `localterraform.com/acme/vpc/aws` | **yes** | `version` constraint |
| GitHub shorthand | `github.com/acme/terraform-aws-vpc` | no | `?ref=` |
| Generic Git | `git::https://example.com/vpc.git` | no | `?ref=` |
| Git over SSH | `git@github.com:acme/modules.git` | no | `?ref=` |
| BitBucket | `bitbucket.org/acme/modules` | no | `?ref=` |
| Mercurial | `hg::https://example.com/vpc` | no | `#revision` |
| HTTP indirection | `https://modules.acme.internal/vpc` | no | whatever it redirects to |
| Archive over HTTPS | `https://example.com/vpc.zip` | no | the URL |
| S3 | `s3::https://bucket.s3.amazonaws.com/vpc.zip` | no | the object |
| GCS | `gcs::https://www.googleapis.com/storage/v1/b/acme/o/vpc.zip` | no | the object |

Two entries in that table are worth spelling out because they are easy to miss.

**A local path is not versioned, and that is the point.** The [`module` block reference](https://developer.hashicorp.com/terraform/language/block/module) states the rule directly: modules sourced from local file paths *"do not support `version` because they're loaded from the same source repository and always share the same version as their caller"*. Whatever the commit of the calling repository is, that is the version of the module.

**`localterraform.com` is a generic hostname.** On HCP Terraform and Terraform Enterprise it resolves to whichever instance is running the configuration. Use it instead of hard-coding an instance hostname when the same configuration has to run on more than one instance.

### The `//` sub-directory marker

Most real module repositories hold several modules. The double slash says where the module is inside the package:

```hcl
module "vpc" {
  source = "git::https://example.com/network.git//modules/vpc?ref=v1.2.0"
}
```

Order matters. The package address comes first, then `//`, then the sub-directory, and query parameters go **after** the sub-directory. Writing `?ref=v1.2.0` before the `//` is a common way to get a confusing failure.

The consequence is more interesting than the syntax. Terraform extracts the **entire package** to disk and then reads the module from the sub-directory. So a module inside a package can reference a sibling module in the same package by a local path, and that path resolves. That is what makes it possible to split a large module into pieces without publishing every piece separately.

!!! note "Same source, different labels is legal and sometimes necessary"
    You may point two `module` blocks at the identical `source`, as long as the labels differ. That is an ordinary way to get two of something with different inputs, and it is also the workaround when `count` or `for_each` will not do, because a multiplied module call cannot vary its provider configurations. Chapter 17 covers that constraint.

!!! warning "Absolute local paths behave differently from relative ones"
    A path beginning with `/` or a drive letter is treated as an absolute path, and Terraform **copies it into the module cache as a package** rather than referencing it in place. The reference discourages the form outright, because *"doing so can couple your configuration to the filesystem layout of a particular computer"*. Relative paths do not have that problem and are what you want inside a repository.

### The HTTP form is an indirection layer

The HTTP source is under-used and worth knowing. Terraform sends a `GET` to the URL with a `terraform-get=1` query parameter appended. On a `200` it looks for the real source address in an `X-Terraform-Get` response header, or in an HTML `<meta name="terraform-get" content="...">` tag. Credentials come from `~/.netrc`, and the `NETRC` environment variable overrides its location.

That gives you a stable vanity address in front of a moving implementation. `https://modules.acme.internal/vpc` can point at a Git repository today and a registry tomorrow, with no change in any consumer.

An HTTPS URL ending in a recognised archive extension skips the redirection and is treated as the archive itself. Recognised extensions are `.zip`, the `bz2` family, the `gz` family, and the `xz` family. Anything else needs an explicit `archive` query parameter.

### Credentials

Terraform runs `git clone` and uses the Git configuration already on your machine, including credentials and SSH keys. There is one constraint that is stated repeatedly in the reference and still gets missed, because it is never given a heading of its own: *"For Terraform operations in HCP Terraform, you can only authenticate using SSH keys."* A private Git module source that works locally over HTTPS with a token will fail in an HCP run.

S3 sources resolve credentials in a fixed order: the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables, then the default profile in `~/.aws/credentials`, then an EC2 instance profile. GCS sources use `GOOGLE_OAUTH_ACCESS_TOKEN`, `GOOGLE_APPLICATION_CREDENTIALS`, GCE default credentials, or `gcloud auth application-default login`.

---

## 4. Pinning, and the lock file that does not exist

`version` is optional. Treating it as optional is the single most expensive habit in this chapter.

### What a constraint selects

A version constraint is a string of comma-separated conditions, each an operator plus a version number. The operators, from the [Version Constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints) page:

| Operator | Meaning |
|---|---|
| `=` or no operator | Exactly one version. Cannot be combined with other conditions. |
| `!=` | Excludes an exact version. |
| `>`, `>=`, `<`, `<=` | Ordinary comparisons. |
| `~>` | Pessimistic. Only the right-most component named may increment. |

`~>` is the one people get wrong, and the rule is mechanical rather than semantic. `~> 1.0.4` allows `1.0.5` and `1.0.10`, and does not allow `1.1.0`. `~> 1.1` allows `1.2` and `1.10`, and does not allow `2.0`. The number of components you write decides which one is allowed to move.

Pre-release versions such as `1.2.0-beta` are only ever selected by an exact `=`. No comparison or pessimistic operator will match one.

The resolution rule matters as much as the syntax. Terraform uses the **newest installed** version that satisfies the constraint, and downloads the newest satisfying version only when nothing acceptable is installed. Held together with the absence of a module lock file, that sentence is the whole hazard.

### Measured: the same commit, two different modules

Here is the resolution rule playing out. All of this is Terraform **1.15.8** against the public registry on 2026-08-08, using `terraform-aws-modules/s3-bucket/aws`.

Start with an exact pin, `version = "4.1.0"`:

```
Initializing modules...
Downloading registry.terraform.io/terraform-aws-modules/s3-bucket/aws 4.1.0 for logs...
```

Now loosen the constraint in the configuration to `version = "~> 4.1"` and run `terraform init` again:

```
Initializing modules...
```

Nothing. The installed `4.1.0` still satisfies `~> 4.1`, so it is kept. `.terraform/modules/modules.json` confirms it:

```json
{"Key": "logs", "Source": "registry.terraform.io/terraform-aws-modules/s3-bucket/aws",
 "Version": "4.1.0", "Dir": ".terraform/modules/logs"}
```

Add `-upgrade` and the constraint is re-resolved:

```
Upgrading modules...
Downloading registry.terraform.io/terraform-aws-modules/s3-bucket/aws 4.11.0 for logs...
```

```json
{"Key": "logs", "Source": "registry.terraform.io/terraform-aws-modules/s3-bucket/aws",
 "Version": "4.11.0", "Dir": ".terraform/modules/logs"}
```

Now the part that is not a footnote. Copy the **same `main.tf`**, with the same `~> 4.1`, into an empty directory and run a plain `terraform init` with no flags:

```
Downloading registry.terraform.io/terraform-aws-modules/s3-bucket/aws 4.11.0 for logs...
```

Two machines, one commit, one constraint. One is running `4.1.0` and the other `4.11.0`. Neither printed a warning, and nothing in the repository records which is which.

!!! danger "`.terraform.lock.hcl` records providers only. Modules are not locked."
    The dependency lock file pins provider versions and their checksums. It has no module section and never has had one. The record of which module version was selected lives in `.terraform/modules/modules.json`, which sits inside `.terraform/` and is therefore not committed.

    So a fresh clone re-resolves. A clean CI runner re-resolves. A colleague who deleted `.terraform` to fix something else re-resolves. `terraform init -lockfile=readonly` has nothing to check, because there is nothing to check against.

    Do not try to commit `modules.json` as a substitute. Its `Dir` fields are repository-relative so it looks portable, but it is an undocumented internal snapshot that `init` rewrites, and no flag makes Terraform treat it as authoritative.

Leaving `version` out entirely is the same hazard with the brakes off. The reference's summary line for the argument is *"Defaults to latest version available from the source."* Measured on the same module on the same day, an unpinned `source` resolved to **5.15.4** while `~> 4.1` resolved to **4.11.0**. That is a whole major version, arriving without a diff.

### Three layers of control

**Pin exactly.** `version = "4.11.0"` for a registry module. Not a range, not `~>`. This is the layer that belongs to you, in the configuration, today.

**Enforce the pin.** A policy that rejects a plan containing an unpinned or range-pinned module is Chapter 22's material. Policy is what makes the convention survive contact with a team.

**Keep pins current.** An exact pin that nobody moves becomes an old exact pin. Update automation and a scheduled upgrade job are Chapter 20's material.

Each layer is useless without the others. An exact pin with no upgrade process is how a configuration ends up three majors behind, and a range constraint with excellent automation is how an untested version reaches production on a Tuesday.

!!! tip "Two different best practices, and which side of the call you are on decides"
    The Version Constraints page gives opposite advice in two places, and both are right.

    For **the modules you consume**, require specific versions, so that a third party's release schedule is not your deployment schedule.

    For **the constraints inside a reusable module you write**, constrain only the minimum, for example `required_version = ">= 1.15"`. A module that pins an upper bound on Terraform or on a provider forces every consumer to wait for you. Root modules are where the `~>` upper bound belongs.

### Git sources: an immutable pin or a shallow clone, not both

Git sources have no `version` argument. Revision selection is a query parameter on the source address:

```hcl
module "vpc" {
  source = "git::https://example.com/vpc.git?ref=v1.2.0"
}
```

Omit `ref` and you get whatever the default branch's `HEAD` points at on the day `init` runs. That is the unpinned default, and it is worse than an unpinned registry module, because at least a registry version number is a number.

`ref` accepts anything `git checkout` accepts: a branch, a tag, or a commit SHA. The choice between the last two is a real trade, and it is the reason to prefer a registry source when you have one.

**A tag is a pointer, and pointers move.** *Terraform: Up & Running* recommends tags over branches and argues that *"Git tags are as stable as a commit"*. Against accidental drift that is correct, and the warning about branches is correct: a branch gives you a different commit every time you re-resolve. But a tag can be force-moved by anyone who controls the source repository, and your pin follows silently. Section 8's lab measures exactly that.

**A SHA cannot be moved by anyone.** That is the supply-chain-safe answer, and it mirrors the standard advice to pin GitHub Actions by digest. It costs you two things.

The first cost is automation. No update bot will move a SHA pin for you, confirmed on both of the common ones. Renovate does not support it natively, and the maintainer's reason in [discussion #31006](https://github.com/renovatebot/renovate/discussions/31006) is architectural: its HCL parser strips comments, so there is nowhere to store the version-to-SHA annotation that its Docker and Actions digest pinning relies on. A global `pinDigests: true` actively breaks on Git-sourced Terraform modules ([issue #14790](https://github.com/renovatebot/renovate/issues/14790)), so set `"terraform": { "pinDigests": false }`. Dependabot has the same gap, tracked at [#10787](https://github.com/dependabot/dependabot-core/issues/10787) and [#10926](https://github.com/dependabot/dependabot-core/issues/10926); it considers semantic versions and skips SHA refs.

The second cost is shallow clones, and no documentation page connects it to the pinning advice.

!!! danger "`depth` and a SHA `ref` are mutually exclusive"
    `?depth=1` is the documented way to avoid cloning a large repository's entire history. The [`module` block reference](https://developer.hashicorp.com/terraform/language/block/module) carries the restriction: *"you must specify a named branch or tag known to the remote repository. You cannot use raw commit IDs."* The two how-to pages that describe `depth` do not mention it.

    The mechanism is in `hashicorp/go-getter` **v1.8.6**, the version Terraform **1.15.8** vendors. When `depth > 0` it passes `--depth` together with `--branch <ref>`, and `git clone --branch` accepts only a branch or a tag. A full clone takes a different path and does a separate `checkout`, which is what lets an arbitrary SHA work at all.

    Reproduced against a real repository in Part C of this chapter's lab, with the error quoted in full.

    The same page's summary block claims `depth` defaults to `1`. That cannot be right. If it did, every Git source would be a shallow clone and a SHA `ref` would never work, yet SHA refs are documented as supported on the same page. An omitted `depth` produces a full clone. Read the sentence as "1 is the value to use when you set it".

**How to choose.** A third-party module you do not control: SHA-pin, and accept manual upgrades, because a mutable tag under someone else's control is a genuine exposure. A module in your own organisation with tag-protection rules enabled: pin the tag and keep the automation, because you control whether the tag can move. Either way it is a decision, not a default.

---

## 5. Composing a source from variables (Terraform 1.15)

Until 1.15, `source` had to be a literal string. That forced duplication: pointing staging and production at different registries or different pins meant two `module` blocks that were otherwise identical.

Terraform **1.15** added dynamic module sources. `source` and `version` can now reference input variables and local values, with one requirement:

```hcl
variable "module_source" {
  type  = string
  const = true
}

module "consul" {
  source = var.module_source
}
```

The requirement is `const = true`, and the reason is timing rather than safety. The [Use modules in your configuration](https://developer.hashicorp.com/terraform/language/modules/configuration) page states it directly: *"Since Terraform installs modules when a workspace is initialized or during a 'Get' operation, those variable's values will not be available."* Most variables are evaluated when Terraform builds a plan. Module installation happens at `init`, before any plan exists. `const = true` is a variable's promise that its value is known that early.

The constraint is on the whole dependency chain, not on the syntax. A local value is legal in the `source` position as long as everything feeding it is const:

```hcl
variable "module_repo" {
  type  = string
  const = true
}

variable "module_ref" {
  type    = string
  const   = true
  default = "v0.0.1"
}

locals {
  vpc_source = "git::${var.module_repo}//modules/vpc?ref=${var.module_ref}"
}

module "vpc" {
  source = local.vpc_source
}
```

Get the `const` wrong and the error is unusually clear. Measured on 1.15.8, with `const` removed from one of the two variables:

```
│ Error: Unknown module source
│
│   on main.tf line 45, in module "bucket":
│   45:   source = local.bucket_module
│
│ Only literal values and const variables can be evaluated during init.
```

Because these values are consumed at `init`, they can be supplied to `init` itself. `terraform init -var 'module_ref=v0.0.2'` works, and so does an auto-loaded `*.auto.tfvars` file, both measured in the lab.

!!! danger "The `module` block reference contradicts itself about `source`"
    Ten lines apart, the same page says *"You must specify a literal string for the `source` value. This argument does not support template sequences or arbitrary expressions"* and *"The `source` attribute can reference constant input variables and local values."*

    The second is current. The first is pre-1.15 text that survived a rewrite. The `version` argument's section states the `const` rule cleanly, so only `source` is affected. Both still require `terraform init` after a change.

!!! info "OpenTofu — no `const` needed, because early evaluation is general"
    OpenTofu **1.8** added early variable and locals evaluation, which lets `source`, backend configuration, and state-encryption blocks reference `var` and `local` without any opt-in marker. Terraform's `const` is the narrower 1.15 answer to the same problem.

    Measured on **OpenTofu 1.12.4** with this chapter's lab 3 configuration: the variable-composed Git source installs correctly **with or without** `const = true` on the variables. OpenTofu accepts the `const` argument rather than rejecting it, so a configuration written for Terraform 1.15 runs unchanged on OpenTofu. The reverse is not true. Strip `const` for OpenTofu and Terraform stops at `init`.

    The exam (004, Terraform 1.12) still assumes literal sources.

---

## 6. Wiring a module in

### Inputs, and the argument for not adding one

The mechanics are unremarkable. Identify the module arguments you may want to change, declare matching variables in your root module, and pass them through.

The interesting half is the negative case, and the [Use registry modules tutorial](https://developer.hashicorp.com/terraform/tutorials/modules/module-use) states it well: *"You do not need to set all module input variables with variables. For example, if your organization requires NAT gateway enabled for all VPCs, you should not use a variable to set the `enable_nat_gateway` argument."*

A variable is **permission to change a value**. Declaring one for something your policy has already decided hands that decision back to the caller, and every caller then has to be trusted to make it correctly. *Terraform: Up & Running* reaches the same conclusion from the author's side, choosing `locals` over variables for a module's port and protocol constants precisely because *"users of your module will be able to (accidentally) override these values, which you might not want."*

This applies to your root module too. A root variable that no environment ever sets differently is not configuration. It is a place for a mistake to enter.

### Outputs, and why `terraform output` cannot see them

Read a child module's output as `module.<LABEL>.<OUTPUT_NAME>`:

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"
  # ...
}

resource "aws_subnet" "main" {
  vpc_id     = module.vpc.vpc_id
  cidr_block = "10.0.1.0/24"
}
```

That reference is also what orders the two. No `depends_on` is needed or wanted. Reading an output creates the edge, exactly as reading a resource attribute does in Chapter 5.

Then there is the constraint that surprises everyone once: **module outputs are not inherited**. The tutorial states it flatly: *"Terraform will not display module outputs by default. You must create a corresponding output in your root module and set it to the module's output."*

Measured on 1.15.8, with a child module exporting `bucket_arn` and the root module deliberately re-exporting only one of its two calls:

```shell
$ terraform output raw_bucket_arn
╷
│ Error: Output "raw_bucket_arn" not found
│
│ The output variable requested could not be found in the state file.
╵
```

```shell
$ echo 'module.raw.bucket_arn' | terraform console
"arn:aws:s3:::ch13-lab1-raw"
```

The value exists, is in state, and is readable anywhere in the configuration. It is only invisible to the CLI. The fix is a pass-through output in the root module:

```hcl
output "raw_bucket_arn" {
  description = "ARN of the raw bucket, re-exported from the child module."
  value       = module.raw.bucket_arn
}
```

That pass-through is not boilerplate. Anything another system consumes, whether that is a CI job reading `terraform output -raw`, or another configuration reading this one's state (Chapter 15), has to be re-exported deliberately. The root module's outputs are the configuration's public surface, and they should be a chosen subset rather than everything a child happened to expose.

### Meta-arguments on a module call

`count`, `for_each`, and `depends_on` work on a `module` block, and Chapter 10 covered their semantics. Three things are specific to modules.

`count` and `for_each` multiply the whole module. Every resource inside is created once per instance, and addresses gain the index at the module level: `module.app["web"].aws_instance.this[0]`.

`depends_on` on a module applies to every resource and data source inside it, which makes it the bluntest tool in the language. The cost Chapter 10 measured gets worse here, because more values become `(known after apply)` across a larger blast radius. The [`depends_on` reference](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on) says so itself: this is *"especially likely when you use `depends_on` for modules"*.

A module that declares its own `provider` configuration cannot take `count`, `for_each`, **or** `depends_on`. Terraform rejects the call at `init` with a "legacy module" error. Chapter 10 measured that error; Chapter 17 covers passing provider configurations in with `providers = { ... }` instead.

### Replacing one resource inside a module

`-replace` takes full instance addresses, including nested paths:

```shell
terraform apply -replace=module.example.aws_instance.example
```

```shell
terraform plan -replace=module.example.module.from-child2.aws_instance.child2-inst
```

There is no module-wide form and no wildcard. The reference is explicit: *"You can only select individual resource instances with the `-replace` CLI option. Add multiple `-replace` options to replace more than one resource in a single command."* Replacing everything a module manages means listing every address.

---

## 7. What `init` actually installed

The install step is where most of a module's surprises live, so it is worth looking at directly.

**A module block that has never been installed stops the plan.** Measured on 1.15.8:

```shell
$ terraform plan
╷
│ Error: Module not installed
│
│   on main.tf line 2:
│    2: module "m" { source = "./modules/m" }
│
│ This module is not yet installed. Run "terraform init" to install all
│ modules required by this configuration.
╵
```

`terraform init` installs modules along with everything else. `terraform get` installs **only** modules, touching neither providers nor the backend, which makes it the faster loop when you are iterating on module wiring:

```shell
$ terraform get
- m in modules\m
```

**Installed modules land in `.terraform/modules/`.** What lands there depends on the source, and the difference is bigger than it looks. Measured on 1.15.8 with two calls to one local module:

```json
{
  "Modules": [
    { "Key": "",        "Source": "",                     "Dir": "." },
    { "Key": "curated", "Source": "./modules/data-bucket", "Dir": "modules/data-bucket" },
    { "Key": "raw",     "Source": "./modules/data-bucket", "Dir": "modules/data-bucket" }
  ]
}
```

`.terraform/modules/` contained **only** `modules.json`. No copy of the module, and no symlink either. The `Dir` field points straight back at the source path in the working directory, so a relative local module is referenced in place. The root module gets its own entry with an empty key and `Dir: "."`.

!!! warning "The tutorial says local modules are symlinked. On 1.15.8 they are not copied at all."
    The [Use registry modules tutorial](https://developer.hashicorp.com/terraform/tutorials/modules/module-use) describes local modules as symlinked into `.terraform/modules/`, and shows a directory listing with an entry per module. Measured on Terraform **1.15.8** on Windows, `.terraform/modules/` holds `modules.json` and nothing else, and `modules.json` records the relative source path directly.

    The practical consequence the tutorial draws is still exactly right, and it is what matters: **edits to a local module take effect immediately**, with no re-`init` and no `terraform get`. Verified by adding a tag to a local module and running `plan` with no re-initialisation:

    ```
      # module.curated.aws_s3_bucket.this will be updated in-place
              + "Reviewed"  = "2026-08-08"
      # module.raw.aws_s3_bucket.this will be updated in-place
              + "Reviewed"  = "2026-08-08"
    Plan: 0 to add, 2 to change, 0 to destroy.
    ```

    Note the second half of that plan. **Both** callers moved, because they share one directory. That is the local-module trade in a single line: the fastest possible edit loop, and no way to change one caller without changing the others. Versioned sources exist to break that coupling, which is the promotion workflow in section 9.

A registry source is genuinely downloaded, and `modules.json` records the resolved version:

```json
{ "Key": "logs",
  "Source": "registry.terraform.io/terraform-aws-modules/s3-bucket/aws",
  "Version": "4.11.0",
  "Dir": ".terraform/modules/logs" }
```

A Git source is cloned whole. With `source = "git::file:///.../modules-repo//modules/data-bucket?ref=v0.0.1"`, `init` reported:

```
Downloading git::file:///.../modules-repo?ref=v0.0.1 for bucket...
- bucket in .terraform\modules\bucket\modules\data-bucket
```

The package went to `.terraform/modules/bucket`, and the module was read from `modules/data-bucket` beneath it. That is the `//` rule made visible, and it is why sibling modules in one package can reference each other by local path.

### The re-installation rule

Changing `source` or `version` requires a re-`init`. Beyond that, one asymmetry governs everything in this chapter:

| Command | Registry module | Git module |
|---|---|---|
| `terraform init` | keeps the installed version if it still satisfies the constraint | keeps the installed clone; does not re-fetch |
| `terraform init -upgrade` | re-resolves the constraint, downloads the newest match | re-clones and re-resolves the `ref` |
| fresh directory, plain `init` | resolves as if nothing were installed | clones fresh |

Both halves are measured. Section 4 has the registry numbers. The Git behaviour is measured in the lab, where a force-moved tag is invisible to a plain `init` and picked up immediately by `init -upgrade`.

---

## 8. Encapsulation is also opacity

Modules hide things. That is the feature, and it is also the review problem, and both show up in the same number.

The registry-modules tutorial builds a VPC and two EC2 instances from two `module` blocks and roughly a dozen visible arguments. The apply reports **22 resources**. The page acknowledges it in passing: *"The vpc and ec2 modules define more resources than just the VPC and EC2 instances."*

The same effect at a smaller scale, measured in this chapter's lab 2. One `module` block with three arguments, applied against the emulator:

```
module.logs.data.aws_caller_identity.current
module.logs.data.aws_partition.current
module.logs.data.aws_region.current
module.logs.aws_s3_bucket.this[0]
module.logs.aws_s3_bucket_public_access_block.this[0]
module.logs.aws_s3_bucket_versioning.this[0]
```

Three resources and three data sources you did not ask for. Note the `[0]` suffixes: the module uses `count` internally on resources you never referenced, and that is entirely invisible from the call site. It becomes visible the moment you need a state address, which is exactly when you are least in the mood to discover it.

There is a second kind of opacity in the same install. The child module carries its own provider requirements, and they merge with yours. From the same `init`:

```
- Finding hashicorp/aws versions matching ">= 5.83.0, ~> 6.0"...
- Installing hashicorp/aws v6.58.0...
```

`~> 6.0` is the root module's constraint. `>= 5.83.0` came from inside the module. Every module you call gets a vote on your provider version, and Terraform proceeds only when all the constraints are satisfiable. A module upgrade that fails with an unsatisfiable provider constraint is this mechanism working correctly, and Chapter 17 goes into it.

### Audit what you actually depend on

`terraform modules` (Terraform **1.10+**) prints every module declared in the configuration, for the whole tree:

```shell
$ terraform modules

Modules declared by configuration:
.
└── "logs"[registry.terraform.io/terraform-aws-modules/s3-bucket/aws] 4.11.0 (~> 4.1)
```

Both the resolved version and the constraint that produced it. For a local module it shows the path, and for a Git module the full source address including the `ref`. There is a `-json` form for policy checks:

```json
{"format_version":"1.0","modules":[{"key":"logs","source":"registry.terraform.io/terraform-aws-modules/s3-bucket/aws","version":"4.11.0"}]}
```

It also accepts `-var` and `-var-file`, which it needs now that a `source` can be composed from const variables.

!!! info "OpenTofu — there is no `tofu modules`"
    Measured on **OpenTofu 1.12.4**: `tofu modules` returns `OpenTofu has no command named "modules".` The command is Terraform-only as of that release. On OpenTofu, read `.terraform/modules/modules.json` after an `init`, or parse the `module` blocks directly.

### Reviewing a module before you adopt it

The public registry is *"created and maintained by HashiCorp, our partners, and the Terraform community"*. That mixed provenance is the reason to look before adopting. The [private-registry curation tutorial](https://developer.hashicorp.com/terraform/tutorials/modules/private-registry-add) lists what a registry entry gives you, and the list doubles as a review checklist:

- **Version and publication date** — whether it is actively maintained.
- **The owner** — who is responsible for updates.
- **Download count** — a rough proxy for how many people would notice a breakage.
- **A link to the source repository** — where the code actually is.
- **Inputs, outputs, dependencies, and resources tabs.**

The **resources** tab is the one to open first. It tells you what the module will create before you run a plan, which is the shortest path past the 22-resources surprise.

!!! tip "Check the pins in any tutorial before copying them, including HashiCorp's own"
    The registry-modules tutorial pins AWS provider `~> 4.49.0`, `vpc` at 3.18.1, and `ec2-instance` at 4.3.0. Verified on 2026-08-08, the current versions are AWS provider 6.x, `vpc` **6.6.1**, and `ec2-instance` **6.4.0**. The reference documentation is maintained; the tutorials are not, and the same page's own reference counterpart pins a 6.x `vpc`.

    The good news is specific. Every argument and output that tutorial uses still exists at the current major of both modules, so bumping its pins is a version exercise rather than a rewrite. The bumps are not independent, though: `ec2-instance` 6.4.0 requires AWS provider `>= 6.37`, which forces `vpc` off 3.x. Upgrade all three or none.

!!! warning "Curating a module in a private registry is a recommendation, not a control"
    HCP Terraform lets you add public modules to your organisation's private registry, and the word "approved" gets attached to the result. The mechanism does not support that reading. The registry *"stores a pointer"* to the public module, the source address in configurations is unchanged, and removing a curated entry does not stop anyone: *"Users in the organization can still use the removed provider or module without changing their configurations."*

    Curation is a bookmark list with documentation attached. Enforcement is policy on the plan, which is Chapter 22. Curating a public module does buy one real capability: on HCP Terraform Standard and Premium you can enable no-code provisioning on it, which turns a community module into something a team with no Terraform knowledge can provision through the UI. That is Chapter 31's territory.

---

## 9. Versioning as a promotion workflow

Everything above is mechanism. The reason to care is that a versioned module lets two environments run different code on purpose.

With a local `source`, they cannot. As *Terraform: Up & Running* puts it, *"as soon as you make a change in that folder, it will affect both environments on the very next deployment."* Section 7's measurement is that sentence in plan output: one edit, two callers changed.

The fix is to separate the blueprint from the buildings. Module code lives in one repository and is released. Environment configurations live in another and each pins a release. The workflow then has four steps:

1. Change the module, and tag a new release, `v0.0.2`.
2. Point **staging** at `v0.0.2`. Leave production on `v0.0.1`.
3. Run staging. If `v0.0.2` is wrong, production never saw it.
4. Once proven, move production to `v0.0.2`.

Use semantic versioning for the tags, so the version number carries information: major for incompatible changes, minor for backward-compatible additions, patch for backward-compatible fixes. The registry requires that shape anyway.

Two upgrades to that advice, which was written in 2022 against a friendlier threat model. Registry sources give you a real version number and both update bots understand it, so prefer a registry over raw Git where you have the option. And a Git tag is only as immutable as the repository's tag-protection rules, which the next section measures.

---

## 10. Removing a module

Deleting a `module` block and applying **destroys** everything inside it. That is usually what you want and occasionally a disaster.

To drop the resources from state and leave the real infrastructure alone:

```hcl
removed {
  from = module.example

  lifecycle {
    destroy = false
  }
}
```

The target is `module.example`, the whole call, not an individual resource. `removed` requires Terraform **1.7+**. Omitting the `lifecycle` block plans a destroy, which is the opposite of the intent, so the block is not optional in practice.

Chapter 16 covers `removed`, `moved`, and `import` properly, as the config-driven replacements for `terraform state` surgery.

!!! warning "The removal section of the docs is garbled"
    The [Use modules in your configuration](https://developer.hashicorp.com/terraform/language/modules/configuration) page has four defects in that one short section, current as of 2026-08-08. A version note about `removed` sits stranded mid-paragraph before `removed` has been introduced. The instructions contain a stray "And" and an unclosed backtick. And the section closes by linking to the **`moved`** block reference at the end of a section about the **`removed`** block. Read it against the `removed` block reference rather than on its own.

---

## 🧪 Lab: consume a module three ways

Three parts. Part A calls a local module twice and looks at what `init` actually did. Part B pins a registry module and watches a version constraint resolve differently on two machines. Part C builds a Git module repository on your own machine, then force-moves a tag out from under a pin.

Everything runs against the free local **AWS emulator** from [Chapter 1's lab setup](ch01-iac-fundamentals.md#lab-setup-a-free-local-aws-docker). Part C needs `git`, which you already have.

**Start the emulator** (from the repo root; skip if already running):

```shell
docker compose -f labs/docker-compose.yml up -d      # start the emulator on :4566, detached
curl -s http://localhost:4566/_floci/health          # wait until the services read "running"
```

Every transcript below was captured on **Terraform 1.15.8** with **AWS provider 6.58.0** against Floci 1.5.34, on 2026-08-08. Long outputs are trimmed to the lines that carry the point, and nothing is paraphrased.

### Part A — one local module, called twice

`labs/chapter13/lab1` holds a `data-bucket` module in `modules/data-bucket`, called twice from the root with different inputs, plus one root-level resource that writes into a bucket the module owns.

```shell
cd labs/chapter13/lab1
tflocal init
```

```
Initializing modules...
- raw in modules\data-bucket
- curated in modules\data-bucket
```

Two calls, one directory. Now look at what landed in `.terraform/modules/`:

```shell
ls .terraform/modules/
cat .terraform/modules/modules.json
```

```
modules.json
```

```json
{
  "Modules": [
    { "Key": "",        "Source": "",                     "Dir": "." },
    { "Key": "curated", "Source": "./modules/data-bucket", "Dir": "modules/data-bucket" },
    { "Key": "raw",     "Source": "./modules/data-bucket", "Dir": "modules/data-bucket" }
  ]
}
```

No copy and no symlink. The relative local module is referenced where it sits.

```shell
tflocal apply -auto-approve
```

```
Plan: 9 to add, 0 to change, 0 to destroy.
...
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:

curated_bucket_arn = "arn:aws:s3:::ch13-lab1-curated"
```

Nine resources from two module blocks and one root resource. The addressing:

```shell
tflocal state list
```

```
aws_s3_object.readme
module.curated.aws_s3_bucket.this
module.curated.aws_s3_bucket_public_access_block.this
module.curated.aws_s3_bucket_server_side_encryption_configuration.this
module.curated.aws_s3_bucket_versioning.this
module.raw.aws_s3_bucket.this
module.raw.aws_s3_bucket_public_access_block.this
module.raw.aws_s3_bucket_server_side_encryption_configuration.this
module.raw.aws_s3_bucket_versioning.this
```

Root-module resources keep their plain address. Everything else is prefixed with the module call.

**Now the outputs gap.** `outputs.tf` re-exports the curated bucket's ARN and deliberately not the raw one:

```shell
tflocal output
```

```
curated_bucket_arn = "arn:aws:s3:::ch13-lab1-curated"
```

```shell
tflocal output raw_bucket_arn
```

```
╷
│ Error: Output "raw_bucket_arn" not found
│
│ The output variable requested could not be found in the state file. If you
│ recently added this to your configuration, be sure to run `terraform
│ apply`, since the state won't be updated with new output variables until
│ that command is run.
╵
```

The value is not missing. It is unexported:

```shell
echo 'module.raw.bucket_arn' | terraform console
```

```
"arn:aws:s3:::ch13-lab1-raw"
```

**Finally, edit the module and do not re-init.** Add one line to `modules/data-bucket/main.tf`, inside the `merge()` in the bucket's `tags`:

```hcl
    Reviewed  = "2026-08-08"
```

```shell
tflocal plan
```

```
  # module.curated.aws_s3_bucket.this will be updated in-place
          + "Reviewed"  = "2026-08-08"
  # module.raw.aws_s3_bucket.this will be updated in-place
          + "Reviewed"  = "2026-08-08"
Plan: 0 to add, 2 to change, 0 to destroy.
```

No `init`, no `get`, and the change is live. Both callers moved together, because they are the same directory. Remove the line again before moving on.

```shell
tflocal destroy -auto-approve
```

### Part B — a registry module, and a constraint that resolves twice

`labs/chapter13/lab2` calls `terraform-aws-modules/s3-bucket/aws`. It ships pinned to `~> 4.1`; the walkthrough starts from an exact pin so you can watch the constraint move.

Set `version = "4.1.0"` in `main.tf`, then:

```shell
cd labs/chapter13/lab2
tflocal init
```

```
Initializing modules...
Downloading registry.terraform.io/terraform-aws-modules/s3-bucket/aws 4.1.0 for logs...
```

Now loosen it to `version = "~> 4.1"` and run a plain `init` again:

```shell
tflocal init
```

```
Initializing modules...
```

Silence, and `modules.json` still says `4.1.0`. The installed version satisfies the new constraint, so nothing happens. Add `-upgrade`:

```shell
tflocal init -upgrade
```

```
Upgrading modules...
Downloading registry.terraform.io/terraform-aws-modules/s3-bucket/aws 4.11.0 for logs...
```

**The part that matters.** Copy `main.tf` alone into an empty directory and initialise it:

```shell
mkdir /tmp/fresh && cp main.tf /tmp/fresh && cd /tmp/fresh
tflocal init
```

```
Downloading registry.terraform.io/terraform-aws-modules/s3-bucket/aws 4.11.0 for logs...
```

Same file, same constraint, different module version from the one your first directory ran for the whole exercise. No warning, and nothing in the repository would have told you.

Back in `lab2`, apply and look at what one module block produced:

```shell
tflocal apply -auto-approve
tflocal state list
```

```
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

```
module.logs.data.aws_caller_identity.current
module.logs.data.aws_partition.current
module.logs.data.aws_region.current
module.logs.aws_s3_bucket.this[0]
module.logs.aws_s3_bucket_public_access_block.this[0]
module.logs.aws_s3_bucket_versioning.this[0]
```

Three data sources you never wrote, and `count` indices on resources you never multiplied. Audit the dependency:

```shell
terraform modules
```

```
Modules declared by configuration:
.
└── "logs"[registry.terraform.io/terraform-aws-modules/s3-bucket/aws] 4.11.0 (~> 4.1)
```

For contrast, delete the `version` line entirely in a scratch copy and initialise:

```
Downloading registry.terraform.io/terraform-aws-modules/s3-bucket/aws 5.15.4 for logs...
```

A whole major version, selected because you left one line out.

```shell
tflocal destroy -auto-approve
```

### Part C — a Git source, a moved tag, and a shallow clone that refuses

`labs/chapter13/lab3` builds its own module repository so nothing here needs GitHub or a network. `setup.ps1` and `setup.sh` create a throwaway Git repo in your temp directory with two tagged releases, and write `repo.auto.tfvars` pointing at it.

```shell
cd labs/chapter13/lab3
./setup.sh          # or .\setup.ps1 on Windows
```

```
Module repo: /tmp/ch13-lab3/modules-repo
module_repo = "file:///tmp/ch13-lab3/modules-repo"
```

`main.tf` composes the source from two `const = true` variables, which is the 1.15 feature from section 5:

```hcl
locals {
  bucket_module = "git::${var.module_repo}//modules/data-bucket?ref=${var.module_ref}"
}

module "bucket" {
  source = local.bucket_module
  name   = "ch13-lab3-bucket"
}
```

```shell
tflocal init
```

```
Initializing modules...
Downloading git::file:///C:/Users/arind/AppData/Local/Temp/ch13-lab3/modules-repo?ref=v0.0.1 for bucket...
- bucket in .terraform\modules\bucket\modules\data-bucket
```

The whole package went to `.terraform/modules/bucket`, and the module was read from the sub-directory named after the `//`.

```shell
tflocal apply -auto-approve
```

```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

module_version_tag = "v0.0.1"
```

```shell
tflocal plan
```

```
No changes. Your infrastructure matches the configuration.
```

**Now move the tag.** This is what a repository owner, a compromised account, or an over-enthusiastic release script can do:

```shell
cd $TMPDIR/ch13-lab3/modules-repo
git tag -f -a v0.0.1 -m "someone force-moves the tag" HEAD
cd -
```

```shell
tflocal plan
```

```
No changes. Your infrastructure matches the configuration.
```

Still clean. Nothing re-fetches on a plan, so the pin looks intact. Then someone runs an upgrade, or CI checks out fresh:

```shell
tflocal init -upgrade
tflocal plan
```

```
Upgrading modules...
Downloading git::file:///C:/Users/arind/AppData/Local/Temp/ch13-lab3/modules-repo?ref=v0.0.1 for bucket...
```

```
Changes to Outputs:
  ~ module_version_tag = "v0.0.1" -> "v0.0.2"
```

The configuration is byte-identical. `ref=v0.0.1` never changed. The code behind it did. In this lab the difference is a harmless output string; in a real module it is whatever the new commit contains.

**Then try to pin a SHA and shallow-clone at the same time.** `module_depth` appends `&depth=1` when set. First with a tag, which works:

```shell
tflocal init -upgrade -var 'module_ref=v0.0.2' -var 'module_depth=1'
```

```
Downloading git::file:///.../modules-repo?ref=v0.0.2&depth=1 for bucket...
- bucket in .terraform\modules\bucket\modules\data-bucket
```

Now with a commit SHA:

```shell
tflocal init -upgrade -var "module_ref=$(git -C $TMPDIR/ch13-lab3/modules-repo rev-parse HEAD)" -var 'module_depth=1'
```

```
╷
│ Error: Failed to download module
│
│   on main.tf line 54:
│   54: module "bucket" {
│
│ Could not download module "bucket" (main.tf:54) source code from
│ "git::file:///.../modules-repo?ref=de618717fa8d7d55935738330b562ec2a53c79d7&depth=1":
│ error downloading
│ 'file://.../modules-repo?depth=1&ref=de618717fa8d7d55935738330b562ec2a53c79d7':
│ C:\Program Files\Git\cmd\git.exe exited with 128: Cloning into
│ '.terraform\modules\bucket'...
│ fatal: Remote branch de618717fa8d7d55935738330b562ec2a53c79d7 not found in
│ upstream origin
│  (note that setting 'depth' requires 'ref' to be a branch or tag name)
╵
```

The immutable pin and the shallow clone are mutually exclusive, confirmed against a real repository rather than inferred from the library source.

**One more, on the `const` requirement.** Delete `const = true` from `module_ref` and initialise:

```
╷
│ Error: Unknown module source
│
│   on main.tf line 45, in module "bucket":
│   45:   source = local.bucket_module
│
│ Only literal values and const variables can be evaluated during init.
╵
```

Put it back, then clean up:

```shell
tflocal destroy -auto-approve
```

!!! info "OpenTofu — Part C, re-run"
    Part C was run again under **OpenTofu 1.12.4** with the same `main.tf` and the same repository. The Git source installs and the `//` sub-directory resolves identically. Two differences, both measured rather than inferred:

    - **`const = true` is not required.** OpenTofu installed the variable-composed source with the `const` lines present and with them removed. Early variable evaluation has been general since OpenTofu 1.8.
    - **`tofu modules` does not exist.** It returns `OpenTofu has no command named "modules".` Read `.terraform/modules/modules.json` instead.

    Do not share a lab directory between the two tools. `.terraform.lock.hcl` is keyed by the fully-qualified provider address, so OpenTofu rejects Terraform's lock file with `Inconsistent dependency lock file`. Use a separate directory, or `tofu init -upgrade`.

!!! warning "Emulation is not AWS"
    A green `apply` here proves your **HCL, module wiring, and version resolution** are correct. It does not prove the configuration behaves identically on real AWS. One fidelity gap showed up while writing this lab, on the Floci 1.5.34 image it was captured against: the emulator dropped tags set at bucket creation, so a configuration with tagged buckets replanned the same tag change forever. That was the emulator, not Terraform, and it is fixed in the 1.6.0 image the compose file now pins (Chapter 11's Part D traces it). The lesson outlives the bug: when a plan will not converge on an emulator, suspect the emulator's coverage of that one attribute before suspecting Terraform, and validate any load-bearing configuration against real free-tier AWS.

---

## Common pitfalls

- **Omitting `version` on a registry module.** There is no module lock file. The next fresh clone gets whatever is newest, which was a full major version away in the measurement above.
- **Assuming `.terraform.lock.hcl` covers modules.** It records providers only. Nothing pins a module except the constraint you wrote.
- **Expecting a plain `init` to pick up a new module version.** It keeps whatever is installed if the constraint still allows it. Only `-upgrade`, or an empty `.terraform/`, re-resolves.
- **Trusting a Git tag as an immutable pin.** Tags move. Use a SHA for third-party modules, or protect the tags on repositories you own.
- **Adding `?depth=1` to a SHA-pinned source.** It fails at `init` with an error about branch names, and no how-to page warns you.
- **Putting query parameters before the `//`.** The order is package, then `//subdir`, then `?ref=`.
- **Expecting `terraform output` to show a child module's outputs.** They are readable in configuration and invisible at the CLI until the root module re-exports them.
- **Declaring a root variable for a value your policy has already fixed.** A variable is permission to change something. Give that permission deliberately.
- **Using `depends_on` on a module call to fix an ordering problem.** It applies to everything inside and pushes more values to `(known after apply)`. Find the missing reference instead.
- **Editing a local module and expecting only one caller to change.** Every call to that directory moves at once. That coupling is the reason versioned sources exist.
- **Deleting a `module` block to stop managing its resources.** That destroys them. Use `removed` with `lifecycle { destroy = false }`.
- **Treating a curated private-registry entry as an enforced allowlist.** It is a bookmark. Enforcement is policy.

---

## Exercises

1. **Recall.** Name the seven arguments a `module` block defines itself. Which one is required, and which one is legal only for some sources?
2. **Recall.** `version = "~> 3.4"` is installed at `3.4.0`. Which of `3.4.9`, `3.5.0`, `4.0.0` can a `terraform init -upgrade` select?
3. **Apply.** Write the `source` address for the module in `modules/network/vpc` inside `https://git.acme.com/platform/terraform-modules.git`, pinned to tag `v2.1.0`. Then write the same address pinned to a commit SHA, and say which one a shallow clone will accept.
4. **Apply.** A child module exports `cluster_endpoint`. A CI job needs to read it with `terraform output -raw`. Write everything required to make that work.
5. **Apply.** Point staging and production at the same module repository but different releases, using one `module` block per environment and Terraform 1.15 dynamic sources. Which variables need `const = true`, and why does `version` not help you here?
6. **Extend.** Take lab 2's configuration and work out, without applying, exactly what it will create. Use `terraform modules`, the registry entry's resources tab, and a `terraform plan`. Which of the three told you the most, and which was fastest?
7. **Extend.** Your organisation wants every module pinned to an exact version. Sketch the three layers of control from section 4, and name which chapter of this book each one is built in.

---

## Summary

- **Every configuration is already a module.** The directory you run commands in is the root module. A `module` block is the only thing that makes Terraform read another directory.
- A `module` block defines **seven arguments**: `source`, `version`, `count`, `for_each`, `depends_on`, `providers`, and `ignore_nested_deprecations`. Everything else you write in it is an input variable for the module.
- **`source` decides everything else.** Local paths are referenced in place and share the caller's version. Registry sources take `version`. Git sources take `?ref=`. `//` marks a sub-directory, and query parameters go after it.
- **There is no module lock file.** `.terraform.lock.hcl` is providers only. Measured: the same commit with `~> 4.1` produced `4.1.0` on one machine and `4.11.0` on another, silently. Pin exactly, enforce the pin with policy, and keep pins current with automation.
- **`init` keeps what is installed; `-upgrade` re-resolves.** True for registry versions and for Git refs alike.
- **A Git tag is a movable pointer.** Measured: a force-moved tag changed the installed module under an unchanged `ref=v0.0.1`. A SHA cannot be moved, and costs you both update automation and `?depth=1`, which rejects commit IDs outright.
- **Terraform 1.15 allows a variable `source`**, if every variable feeding it declares `const = true`. The reason is timing: modules install at `init`, before plan-time evaluation exists. OpenTofu needs no marker, because early evaluation has been general since 1.8.
- **Module outputs are not inherited.** They are readable in configuration and invisible to `terraform output` until the root module re-exports them.
- **Encapsulation is also opacity.** Two module blocks produced 22 resources in HashiCorp's own tutorial; one produced six objects with internal `count` indices in this chapter's lab. Modules also contribute provider version constraints to your resolution.
- **`terraform modules`** (1.10+, Terraform-only) prints every declared module with its source, resolved version, and constraint, with a `-json` form for policy.
- **A versioned source is what lets staging and production differ on purpose.** Tag a release, move staging, leave production, roll forward once proven.

---

## What's next

You can now find a module, pin it so it stays found, pass it inputs, read what it returns, and say exactly what `init` put on disk. That is the consumer's half of the skill.

Chapter 14 crosses the boundary. The input variables you have been filling in become an interface you own, with everything that implies: choosing what to expose and what to fix, structuring the directory so the registry accepts it, deciding what belongs in one module and what belongs in two, and versioning releases so that the callers in this chapter can trust your tags. The design questions from Chapter 12 stop being about a single configuration and start being a public contract.

---

## References

- HashiCorp, [Modules overview](https://developer.hashicorp.com/terraform/language/modules) — the Develop / Distribute / Provision split, root and child modules, registry provenance.
- HashiCorp, [Use modules in your configuration](https://developer.hashicorp.com/terraform/language/modules/configuration) — Git `ref` selection, shallow clones, the `const` requirement, `-replace` addressing, module removal.
- HashiCorp, [`module` block reference](https://developer.hashicorp.com/terraform/language/block/module) — the argument surface, the full `source` catalogue, `//` sub-directories, `ignore_nested_deprecations`, the `depth` restriction.
- HashiCorp, [Version Constraints](https://developer.hashicorp.com/terraform/language/expressions/version-constraints) — operators, the `~>` rule, pre-release matching, the reusable-versus-root best-practice split.
- HashiCorp, [`terraform modules` command](https://developer.hashicorp.com/terraform/cli/commands/modules) — *"The `terraform modules` command requires Terraform v1.10.0 or later."*
- HashiCorp tutorials, [Modules overview](https://developer.hashicorp.com/terraform/tutorials/modules/module), [Use registry modules in configuration](https://developer.hashicorp.com/terraform/tutorials/modules/module-use), [Add public providers and modules to your private registry](https://developer.hashicorp.com/terraform/tutorials/modules/private-registry-add).
- Renovate [discussion #31006](https://github.com/renovatebot/renovate/discussions/31006) and [issue #14790](https://github.com/renovatebot/renovate/issues/14790); Dependabot [#10787](https://github.com/dependabot/dependabot-core/issues/10787) and [#10926](https://github.com/dependabot/dependabot-core/issues/10926) — why no bot moves a SHA pin.
- Reading notes: [[tf-modules]], [[tf-modules-configuration]], [[tf-block-module]], [[tf-expr-version-constraints]], [[tut-module]], [[tut-module-use]], [[tut-private-registry-add]], [[tf-dependency-lock]].
- *Terraform: Up & Running* Ch 4 (the function analogy, inputs as the module's API, the promotion workflow, Git-tag versioning), captured as [[04-reusable-modules]]; *Terraform in Depth* Ch 3 §3.1 (module flavours, the `module` block's three module-specific meta-arguments, registries), captured as [[03-variables-modules]].
- Measurements and lab configurations: `labs/chapter13/`.
- 🧪 Lab: [Floci Facts](../research-cache/floci-facts.md) · [MiniStack Facts](../research-cache/ministack-facts.md) · [LocalStack Facts](../research-cache/localstack-facts.md)
