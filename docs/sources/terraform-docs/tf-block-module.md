# `module` block reference

> **Source:** [developer.hashicorp.com/terraform/language/block/module](https://developer.hashicorp.com/terraform/language/block/module)
> **Added:** 2026-08-08
> **Source updated:** undated language reference; captured 2026-08-08 against v1.15.x (latest)
> **Tags:** module-block, source, version, module-sources, subdirectory, depth, localterraform, ignore_nested_deprecations, s3, gcs, mercurial
> **Type:** documentation

*Developer › Terraform › Configuration Language › Modules › module block reference · v1.15.x*

The argument specification, and the last page in the Modules sidebar group. It absorbs what used to be the separate *Module Sources* page, so it is the exhaustive catalogue of `source` forms — local paths, registry, GitHub, Git, BitBucket, Mercurial, HTTP, S3, GCS. This note keeps the argument surface and the details that are *only* here; the consumer workflow is [[tf-modules-configuration]].

## Argument surface

```hcl
module "<LABEL>" {
  <module-specific-inputs>

  source  = "<location-of-module-sources>"
  version = "<constraint>" # only available for modules listed in a registry

  count    = <number>   # mutually exclusive with `for_each`
  for_each = { <KEY> = <VALUE> }   # map or set of strings; mutually exclusive with `count`

  providers = {
    "<provider-name-in-child-module>" = "<provider-name-from-parent-module>"
  }

  depends_on = [ <resource.address.reference> ]

  ignore_nested_deprecations = <true|false>
}
```

Seven built-in arguments; everything else is the module's own inputs, and "the module developer determines which inputs you can specify". The four meta-arguments defer to their own references ([[tf-meta-count]], [[tf-meta-for-each]], [[tf-meta-providers]], [[tf-meta-depends-on]]).

**`ignore_nested_deprecations`** is the one with no coverage elsewhere in these notes: boolean, default `false`, **Terraform v1.15+**. "If set to `true`, Terraform does not show deprecation warnings in the module call or nested modules." The suppressor for the `deprecated` argument on a child module's variables and outputs ([[tf-block-variable]], [[tf-block-output]]) — the consumer's opt-out from an author's migration notice.

## `source`

!!! danger "The page contradicts itself about `source` ten lines apart"
    > You must specify a **literal string** for the `source` value. This argument **does not support template sequences or arbitrary expressions.**

    Then, in the same section:

    > The `source` attribute **can reference constant input variables and local values.** Any input variable referenced in `source` must declare `const = true`.

    The second is current. Terraform **1.15** added dynamic module sources, and [[tf-modules-configuration]] devotes a whole section to it with three worked examples including a `local` composed from `const` variables. The first paragraph is stale pre-1.15 text that survived the rewrite.

    The `version` argument's section states the `const` rule cleanly and without the contradiction, so only `source` is affected. Both still require `terraform init` after a change.

Other `source` facts that appear only here:

- **Same source, different labels.** "You can specify the same source address in two or more separate module blocks, but you must use **unique labels** for each block." That is the mechanism [[tf-modules-providers]] requires for multi-region fan-out, since a `count`/`for_each` call cannot vary its providers.
- **Absolute local paths are discouraged.** Terraform "recognizes paths that begin with a `/` or drive letter as absolute paths" and **copies them to the local module cache as a package** — unlike relative local modules, which it references in place. "We don't recommend using absolute filesystem paths… because doing so can couple your configuration to the filesystem layout of a particular computer."
- **Sub-directories with `//`.** "Add `//` to the source path to indicate that the rest of the path after that point is a sub-directory within the package. Place any **query parameters, such as the `ref` argument… after the sub-directory segment**." So the order is `<package>//<subdir>?ref=<x>`, not the other way round:

    ```hcl
    module "vpc" {
      source = "git::https://example.com/network.git//modules/vpc?ref=v1.2.0"
    }
    ```

    And the consequence worth knowing: "Terraform extracts the **entire package** to local disk, but reads the module from the subdirectory. As a result, **modules in a sub-directory of a package can use a local path to reference another module in the same package.**" That is what makes the module-split shim in [[tf-modules-refactoring]] work — `../modules/x` resolves because the whole package is on disk.

- **`localterraform.com`.** On HCP Terraform and Terraform Enterprise, `source = "localterraform.com/<NAMESPACE>/<NAME>/<PROVIDER>"` "requests modules from the instance that the platform is running on". A generic hostname, so the same configuration resolves against whichever TFE instance runs it — the portable alternative to hard-coding an instance hostname.

## Git sources

`github.com/<ORG>/<REPO>` and `git@github.com:<ORG>/<REPO>` for GitHub, `git::<protocol>://…` generally (HTTPS recommended form is `ssh://`-prefixed "for consistency"), `bitbucket.org/…`, and `hg::` for Mercurial — which uses a **`#revision` fragment** rather than `?ref=`.

Credentials, repeated verbatim under each Git-based source:

> Terraform runs `git clone` to install modules. Terraform uses the **Git configurations set on your local system, including credentials**… For SSH connections, Terraform automatically uses your SSH keys.

> **For Terraform operations in HCP Terraform, you can only authenticate using SSH keys.**

That last constraint is easy to miss because it is buried four times rather than stated once: a private Git module source that works locally over HTTPS-with-a-token will fail in an HCP run.

Query parameters, also repeated per source:

- **`ref`** — "a branch name, full or short SHA-1 hash, or tag name to clone… Terraform defaults to the default branch referenced by `HEAD`."
- **`depth`** — shallow clone.

!!! warning "This is the page that documents the `depth`/SHA restriction — and its stated default looks wrong"
    > The `depth` parameter implements the Git `--depth` option. When the `source` argument includes the `depth` parameter, Terraform passes the `ref` argument to the `--branch` option when running the `git clone` command. As a result, **you must specify a named branch or tag known to the remote repository. You cannot use raw commit IDs.**

    Worth noting explicitly because [[tf-modules-configuration]] and `Module Sources` both describe `depth` without this caveat. It is documented — just not where a reader following the how-to pages would find it, and **no page connects it to the SHA-pinning advice** in learning-path **I4**. See `cache/search/git-module-shallow-clone-vs-sha-pin.md`.

    **But "The default is 1" cannot be right.** If `depth` defaulted to 1, every Git source would be a shallow clone and a SHA `ref` would never work — yet SHA refs are documented as supported on the same page. The vendored `go-getter` v1.8.6 gates shallow cloning on `depth > 0` and takes the full-clone-then-`checkout` branch when `depth < 1`, so an **absent** `depth` produces a full clone. Read the sentence as "1 is the value to use when you set it", not as the parameter's default.

    **The SHA restriction is now reproduced** (2026-08-08, Terraform 1.15.8, local `git init` repo): a tag `ref` with `depth=1` installs, a full-SHA `ref` with `depth=1` fails with `(note that setting 'depth' requires 'ref' to be a branch or tag name)`. Lab: `labs/chapter13/lab3` Part C, Book Ch 13. The "default is 1" reading remains an inference from the library source rather than a measurement.

## Non-VCS sources

**HTTP/HTTPS as an indirection layer** — the most under-known form. Terraform sends a `GET` with a **`terraform-get=1`** query parameter appended, and on a `200` looks for the real source address in either an **`X-Terraform-Get`** response header or an HTML `<meta name="terraform-get" content="<module-source>" />`. Credentials come from `~/.netrc`, overridable with the **`NETRC`** environment variable.

That makes a vanity URL a stable public address in front of a moving implementation — the module-source analogue of the data-only module indirection in [[tf-modules-composition]].

An HTTPS URL ending in a recognized archive extension **bypasses** the redirection and is treated as the module archive directly: `.zip`; `.bz2`, `.tar.bz2`, `.tar.tbz2`, `.tbz2`; `.gz`, `.tar.gz`, `.tgz`; `.xz`, `.tar.xz`, `.txz`. Other extensions need an explicit `archive` query parameter.

**S3** — `s3::` plus an object URL, archive only, same extension list. Credential precedence, in order:

1. `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
2. the default profile in `~/.aws/credentials`
3. on EC2, temporary credentials from the instance's IAM instance profile

Quirk: "Buckets in AWS's `us-east-1` region must use the hostname `s3.amazonaws.com`, instead of `s3-us-east-1.amazonaws.com`." And "you may be able to use the `s3::` format for other services" with S3-compatible APIs.

**GCS** — `gcs::` plus a `storage/v1` URL, authenticating via `GOOGLE_OAUTH_ACCESS_TOKEN`, `GOOGLE_APPLICATION_CREDENTIALS`, GCE default credentials, or `gcloud auth application-default login`.

## `version`

Registry sources only.

> Terraform uses the **newest installed version** of the module that meets the constraint. When an acceptable version isn't installed, Terraform **downloads the newest version** that meets the constraint. We recommend explicitly constraining the acceptable version numbers to avoid unexpected or unwanted changes.

Summary block: **"Default: Defaults to latest version available from the source."** That is the plainest statement of the unpinned-module hazard recorded in **I4** — no constraint means whatever is newest at `init`, with no lock file to record it ([[tf-dependency-lock]]).

> Modules sourced from **local file paths do not support `version`** because they're loaded from the same source repository and always share the same version as their caller.

Which is why the local module in [[tut-module-create]] carries no `version`, and part of the argument for publishing rather than vendoring.

## Editorial defects

!!! note "A cluster of small errors, consistent with a recently-restructured page"
    Beyond the `source` self-contradiction and the `depth` default above:

    - Stray backticks terminating two example strings — `source = "…?ref=v1.2.0"\`` appears twice — and one opening the S3 section (``Use the `s3:: prefix``).
    - An unbalanced quote in the `localterraform.com` example: `source = "localterraform.com/<NAMESPACE>/<NAME>/<PROVIDER>'"`.
    - "Refer to **is a** Generic hostname for more information", "many of the behaviors that apply to **ther** Git-based repositories", "Refer to the GCE documentation **for for** details", "running `gcloud auth application-default` **logincommand**", "Refer to Install modules from **a repository listed hosted on** BitBucket".

    None changes meaning, but they place this page as newer and less-reviewed than its neighbours — which fits the stale `source` paragraph surviving beside the 1.15 `const` text.

---
Related: the argument specification for the workflow in [[tf-modules-configuration]], closing the Modules sidebar group after [[tf-modules]], [[tf-modules-develop]], [[tf-modules-structure]], [[tf-modules-providers]], [[tf-modules-composition]], [[tf-modules-publish]] and [[tf-modules-refactoring]]. Meta-arguments: [[tf-meta-count]], [[tf-meta-for-each]], [[tf-meta-providers]], [[tf-meta-depends-on]]. `ignore_nested_deprecations` suppresses the `deprecated` argument in [[tf-block-variable]] / [[tf-block-output]]. Version constraint syntax: [[tf-expr-version-constraints]]; the missing module lock: [[tf-dependency-lock]]. The `//` sub-directory rule is what makes [[tf-modules-refactoring]]'s shim resolve its siblings by local path. Feeds learning-path **I4** (using modules) as its argument reference.
