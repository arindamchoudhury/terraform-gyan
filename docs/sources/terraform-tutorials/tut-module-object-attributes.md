# Customize modules with object attributes

> **Source:** [developer.hashicorp.com/terraform/tutorials/modules/module-object-attributes](https://developer.hashicorp.com/terraform/tutorials/modules/module-object-attributes)
> **Added:** 2026-08-08
> **Source updated:** undated tutorial (~17 min); captured 2026-08-08
> **Tags:** modules, object-attributes, optional, list-of-objects, dynamic-blocks, module-api, cors, s3
> **Type:** documentation

Fourth page of the **Modules** collection. [[tut-module-create]] built a module with flat scalar variables; this one refactors a similar module's variable surface into a single `object` variable with `optional()` attributes, then adds a `list(object(...))` for CORS. Requires **Terraform v1.3+** — that is the release where `optional()` gained a default argument. `git clone https://github.com/hashicorp-education/learn-terraform-module-object-attributes`. Offered in both HCP Terraform and Community Edition variants; the HCP path is the default rendering, and the Community path just comments out the `cloud` block.

The mechanics of `optional()` are already captured in [[tf-expr-type-constraints]] and worked through in Ch 12. What this page adds is the **module-API argument** for using them:

> You can make attributes within objects optional, which make it easier for you to ship new module versions without changing the variables that module users need to define.

That is the point. An optional object attribute is how a module's interface grows without a breaking change — the additive counterpart to the `deprecated` argument (TF 1.15) that removes from it.

## Starting point

The module provisions a public S3 static-website bucket, renders local files through `hashicorp/dir/template`, and uploads them as objects.

```hcl
module "template_files" {
  source  = "hashicorp/dir/template"
  version = "1.0.2"

  base_dir = var.www_path != null ? var.www_path : "${path.module}/www"
}

resource "aws_s3_object" "web" {
  for_each = var.terraform_managed_files ? module.template_files.files : {}

  bucket = aws_s3_bucket.web.id

  key          = each.key
  source       = each.value.source_path
  content      = each.value.content
  etag         = each.value.digests.md5
  content_type = each.value.content_type
}
```

(The `aws_s3_object` body is elided as `##...` on the page; the above is the example repo's, fetched verbatim 2026-08-08.)

Two idioms here that the page doesn't stop on. `base_dir` uses a `null`-check ternary to mean "caller's path, else my own" with **`path.module`** as the fallback — the module's own directory, not the caller's ([[tf-expr-references]]). And `for_each` over a **conditional expression returning an empty map** is the "provision none of these" switch, the map-shaped sibling of `count = 0`.

Six flat variables, of which four are file-related: `index_document_suffix`, `error_document_key`, `www_path`, `terraform_managed_files`.

## The refactor

Delete those four; replace with one object.

```hcl
variable "files" {
  description = "Configuration for website files."
  type = object({
    terraform_managed     = bool
    error_document_key    = optional(string, "error.html")
    index_document_suffix = optional(string, "index.html")
    www_path              = optional(string)
  })
}
```

Read the three tiers off that declaration:

- **`terraform_managed`** — not wrapped in `optional()`, so it is **required**. The variable itself has no `default`, so `files` as a whole is required too.
- **`error_document_key` / `index_document_suffix`** — `optional(type, default)`, so the module supplies the value when the caller omits it.
- **`www_path`** — bare `optional(string)`, no default, so it arrives as **`null`** and the `base_dir` ternary handles it.

References change from `var.index_document_suffix` to `var.files.index_document_suffix`, and `var.terraform_managed_files` to `var.files.terraform_managed`.

!!! note "The rename is the quiet lesson"
    `terraform_managed_files` becomes `files.terraform_managed`. The `_files` suffix existed only because a flat namespace had nowhere else to put the qualifier. Once the object supplies the namespace, the suffix is noise. The generalizable tell is a word inside a flat variable name whose only job is to mark which group the variable belongs to — that word is the object not yet declared. Note that the four variables here do *not* share a token; only `terraform_managed_files` carries the qualifier, so this is a smell about hand-rolled namespacing rather than a rule about matching prefixes.

Three caller shapes the page enumerates:

```hcl
files = {
  terraform_managed = false
}
```

```hcl
files = {
  terraform_managed = true
  www_path          = "${path.root}/www"
}
```

```hcl
files = {
  terraform_managed     = true
  www_path              = "${path.root}/www"
  index_document_suffix = "main.html"
  error_document_key    = "error.html"
}
```

Note the caller's `path.root` against the module's `path.module` — the same variable resolves against different directories depending on who sets it, which is precisely why `www_path` is worth exposing.

!!! danger "This tutorial is the perfect setup for the silent-discard footgun, and never mentions it"
    An `object(...)` constraint **discards undeclared attributes** during conversion, silently. Combine that with `optional()` and a caller's typo becomes a no-op that `terraform validate` reports as `Success!`.

    Write `wwwpath` or `www-path` instead of `www_path` in the block above and: the object constraint drops the unknown key, the declared `www_path` is absent so `optional(string)` fills `null`, the ternary falls back to `${path.module}/www`, and you silently deploy the module's built-in placeholder page instead of your site. Nothing errors.

    Misspell the **required** attribute (`terraform_managed`) and Terraform does reject the call by name. So the object constraint removes the attribute and `optional()` removes the evidence — you need both halves for the footgun, and this variable has both. Measured on 1.15.8; **OpenTofu 1.12.4 emits `Warning: Object attribute is ignored` for module calls and Terraform never does** (see Ch 12, [[tf-expr-type-constraints]]).

## A list of objects for CORS

```hcl
variable "cors_rules" {
  description = "List of CORS rules."
  type = list(object({
    allowed_headers = optional(set(string)),
    allowed_methods = set(string),
    allowed_origins = set(string),
    expose_headers  = optional(set(string)),
    max_age_seconds = optional(number)
  }))
  default = []
}
```

`default = []` makes the whole variable optional while each element still enforces `allowed_methods` and `allowed_origins`. The stated design rule is the useful part:

> This matches the behavior of the `aws_s3_bucket_cors_configuration` resource you will use to configure CORS.

The module's type constraint is deliberately a mirror of the underlying resource's own required/optional split. A module input that disagrees with the resource it wraps either rejects valid configurations or defers the error to apply.

```hcl
resource "aws_s3_bucket_cors_configuration" "web" {
  count = length(var.cors_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.web.id

  dynamic "cors_rule" {
    for_each = var.cors_rules

    content {
      allowed_headers = cors_rule.value["allowed_headers"]
      allowed_methods = cors_rule.value["allowed_methods"]
      allowed_origins = cors_rule.value["allowed_origins"]
      expose_headers  = cors_rule.value["expose_headers"]
      max_age_seconds = cors_rule.value["max_age_seconds"]
    }
  }
}
```

Two mechanisms stacked, and it's worth separating them:

- **`count` as a zero-or-one guard** on the resource, because `aws_s3_bucket_cors_configuration` with no rules is not the same as no CORS configuration at all. Ch 12's lab measured this toggle as an **in-place update** (`0 to add, 1 to change, 0 to destroy`), not a replacement.
- **`dynamic` for the nested blocks** inside it. Block iteration, not resource iteration ([[tf-expr-dynamic-blocks]]).

And the reason the `content` block can pass every attribute unconditionally:

> Since optional object attributes default to `null`, Terraform will not set values for them unless the module user specifies them.

A `null` argument is treated as unset, so `optional()` plus unconditional assignment replaces what would otherwise be five conditionals. That is the same trick [[tf-expr-type-constraints]] records as "conditionally setting an optional attribute" — here applied wholesale.

The caller:

```hcl
cors_rules = [
  {
    allowed_headers = ["*"],
    allowed_methods = ["PUT", "POST"],
    allowed_origins = ["https://test.example.com"],
    expose_headers  = ["ETag"],
    max_age_seconds = 3000
  },
  {
    allowed_methods = ["GET"],
    allowed_origins = ["*"]
  }
]
```

Two elements of different written shapes satisfying one `list(object(...))` — the second omits three attributes and gets typed nulls. Ch 7's point that a heterogeneous-looking tuple literal converts to a homogeneous `tolist([...])` under the constraint.

## Runs

The apply sequence is worth reading as a diff, not as output:

- **First apply** — `Plan: 6 to add`. Outputs include both `website_bucket_domain` (`s3-website-us-west-2.amazonaws.com`) and `website_bucket_endpoint` (`<bucket>.s3-website-us-west-2.amazonaws.com`). Site says "Nothing to see here."
- **After the object refactor** — `Plan: 3 to add, 2 to change, 0 to destroy`. Nothing is destroyed, because the refactor changed the module's *interface*, not its resource addresses. Setting `www_path` to the root `www` directory swaps the bucket contents for a Tetris-like game.
- **After adding CORS** — `Plan: 1 to add`, creating `aws_s3_bucket_cors_configuration.web[0]`. Note the `[0]` index: `count` makes it a counted resource even at one instance.

!!! tip "This module fixes what [[tut-module-create]]'s got wrong"
    The previous tutorial's module output `website_domain` and called it "Domain name of the bucket", producing a bare regional suffix with no bucket name in it. This one outputs **both** `website_bucket_domain` and `website_bucket_endpoint`, and the tutorial tells you to visit the **endpoint**. Same collection, two modules, and the later one demonstrates the output choice the earlier one muddled.

## Problems with the page

!!! warning "Page vs. repo again — and the resource counts give it away"
    The example repo's module already carries the S3 fixes described in [[tut-module-create]]: `aws_s3_bucket_ownership_controls` (`BucketOwnerPreferred`) and `aws_s3_bucket_public_access_block` with all four settings `false`, with the ACL `depends_on` naming both. Fetched verbatim 2026-08-08.

    The page's own logs predate that patch, and you can count it: `Plan: 6 to add` and a refresh listing exactly six addresses (bucket, policy, website configuration, ACL, two objects). With the repo's current module that first apply is **8**, not 6, and every later count shifts too. So the printed numbers no longer match a real run of the repo the page tells you to clone. The configuration is fine; the transcript is from an older one. Background on why the two resources are needed: `cache/search/s3-acl-bpa-defaults.md`.

!!! warning "A latent ordering hazard in this repo that the sibling repo doesn't have"
    `learn-terraform-modules-create` puts `depends_on = [aws_s3_bucket_acl.s3_bucket]` on its `aws_s3_bucket_policy`, which transitively orders the policy after the public-access block. **This repo's `aws_s3_bucket_policy.web` has no `depends_on`** and references only `aws_s3_bucket.web.arn` / `.id`.

    So there is no graph edge from `aws_s3_bucket_public_access_block.web` to the policy, and nothing forces `BlockPublicPolicy` to be turned off before `PutBucketPolicy` runs with a `Principal = "*"` statement. Whether it works depends on the order Terraform happens to pick among independent nodes. That is exactly the dependency-you-can't-express-as-a-reference case from [[tf-meta-depends-on]] — and the reason [[tut-dependencies]] treats interleaved `Creating...` lines in the log as a free dependency check.

    ⚠️ Not reproduced against AWS here; stated as a graph-level reading of the two repos, not a measured failure.

!!! note "Two rendering defects"
    **1.** The "delete these four variables" snippet lists `terraform_managed_files` **twice** — once before `www_path` and once after — so the block it tells you to delete shows five variables, not four.

    **2. The "Clean up your infrastructure" section does not show a destroy.** Under `$ terraform destroy` the page prints a plan whose only action is `+ create` on `aws_s3_bucket_cors_configuration.web[0]`, then `Plan: 1 to add, 0 to change, 0 to destroy` and `Apply complete! Resources: 1 added, 0 changed, 0 destroyed`. That is the previous step's apply transcript pasted under the destroy heading. A destroy cannot add a resource. Run the command; ignore the output shown.

!!! warning "Pins — with one exception"
    AWS provider is pinned to an exact `4.30.0` (current 6.x), and Terraform `>= 1.3` is a floor rather than a problem. The exception is worth noting because it is rare: **`hashicorp/dir/template` 1.0.2 is still the latest published version** — the Registry shows 1.0.2, published 2020-07-29 (checked 2026-08-08). Not every old pin is a stale pin.

## Next steps

Stated takeaways: grouped the file-related attributes into one object variable, added CORS through a list of objects, and — the recurring argument — objects "let you update the module without changing its required input variables". Onward pointers are the dynamic-expressions tutorial, the Module Creation recommended pattern, and the optional-object-attributes documentation. Next in the collection is sharing modules in the private registry — captured as [[tut-module-private-registry-share]].

---
Related: fourth in the Modules collection, after [[tut-module]], [[tut-module-use]] and [[tut-module-create]] — this is module-interface *design*, where the previous one was module mechanics. Reference for the type machinery: [[tf-expr-type-constraints]] (the `optional()` one- vs two-argument rule, typed nulls, top-down defaults) and [[tf-expr-dynamic-blocks]]. `count` as a zero-or-one guard and the object-discard footgun are both measured in Ch 12 ([[ch12-dynamic-blocks-complex-types]]). The unexpressed ordering edge connects to [[tf-meta-depends-on]] and [[tut-dependencies]]. S3 defaults background: [[tut-module-create]]. Feeds learning-path **I5** (authoring modules — its clearest interface-design hands-on) and reinforces **I3**.
