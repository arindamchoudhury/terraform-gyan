# Build and use a local module

> **Source:** [developer.hashicorp.com/terraform/tutorials/modules/module-create](https://developer.hashicorp.com/terraform/tutorials/modules/module-create)
> **Added:** 2026-08-08
> **Source updated:** undated tutorial (~15 min); captured 2026-08-08
> **Tags:** modules, local-modules, module-authoring, module-structure, provider-inheritance, module-outputs, terraform-get, s3
> **Type:** documentation

Third page of the **Modules** collection, and the first authoring one. [[tut-module]] gave the vocabulary, [[tut-module-use]] consumed registry modules; this one builds a local submodule — `modules/aws-s3-static-website-bucket` — inside the same configuration and calls it. Continues from the previous tutorial's config, or `git clone https://github.com/hashicorp-education/learn-terraform-modules-create`. Needs an AWS account, the AWS CLI, and the Terraform CLI.

The framing sentence is stronger than the usual "modules are nice":

> we recommend that every Terraform configuration be created with the assumption that it may be used as a module, because doing so will help you design your configurations to be flexible, reusable, and composable.

## Module structure — and what "typical" means

Terraform treats **any local directory named in a `module` block's `source`** as a module. The typical layout repeats [[tut-module]]'s:

```
.
├── LICENSE
├── README.md
├── main.tf
├── variables.tf
├── outputs.tf
```

The important qualification, which [[tut-module]] left implicit:

> None of these files are required, or have any special meaning to Terraform when it uses your module. You can create a module with a single `.tf` file, or use any other file structure you like.

So this is convention for humans and for the Registry, not a contract with Terraform. `LICENSE` and `README.md` are ignored by Terraform entirely; the Registry and GitHub render the README. `variables.tf` becomes the module's argument surface — **a variable with no default is a required argument**, one with a default is optional and overridable.

### Files not to distribute

- `terraform.tfstate` / `terraform.tfstate.backup` — state, not configuration.
- `.terraform/` — the modules and plugins installed for one particular working directory.
- `*.tfvars` — module inputs arrive as `module` block arguments, so a module has no use for them unless it doubles as a standalone root configuration.

> **Warning:** The files mentioned above will often include secret information such as passwords or access keys, which will become public if those files are committed to a public version control system such as GitHub.

Gitignore them. (Same ground as [[tf-style-guide]]'s `.gitignore` guidance; the state-as-secret-store problem itself is [[tf-manage-sensitive-data]] and [[infisical-terraform-secrets]].)

## The module's `main.tf`

**As rendered on the page** — four resources:

```hcl
resource "aws_s3_bucket" "s3_bucket" {
  bucket = var.bucket_name

  tags = var.tags
}

resource "aws_s3_bucket_website_configuration" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_s3_bucket_acl" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id

  acl = "public-read"
}

resource "aws_s3_bucket_policy" "s3_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource = [
          aws_s3_bucket.s3_bucket.arn,
          "${aws_s3_bucket.s3_bucket.arn}/*",
        ]
      },
    ]
  })
}
```

**This snippet does not apply on a current AWS account** — see the box below. The example repo has a corrected six-resource version.

### No `provider` block in a module

> Notice that there is no `provider` block in this configuration. When Terraform processes a `module` block, it will inherit the provider from the enclosing configuration. Because of this, we recommend that you do not include provider blocks in modules.

Stated here as a recommendation. [[tut-for-each]] found the harder version of the same rule: a module using `count` or `for_each` **cannot** declare a `provider` block and must inherit — so multiplying a module call and fanning it across providers are mutually exclusive. Provider passing at the boundary is [[tf-meta-providers]].

## Deciding the interface

The two design questions the tutorial poses, which are the actual content of this page:

**Which arguments to expose as variables.** Its worked answer: expose the index and error documents if you like, but do **not** declare a variable for the ACL, "since you must set your bucket's ACL to `public-read` to host a website". A value the module's purpose fixes is not a variable. Same principle as [[tut-module-use]]'s NAT-gateway example, from the author's side rather than the caller's.

**Which values to expose as outputs**, phrased more strongly than anywhere else in the collection:

> outputs are the only supported way for users to get information about resources configured by the module

```hcl
variable "bucket_name" {
  description = "Name of the s3 bucket. Must be unique."
  type        = string
}

variable "tags" {
  description = "Tags to set on the bucket."
  type        = map(string)
  default     = {}
}
```

```hcl
output "arn" {
  description = "ARN of the bucket"
  value       = aws_s3_bucket.s3_bucket.arn
}

output "name" {
  description = "Name (id) of the bucket"
  value       = aws_s3_bucket.s3_bucket.id
}

output "domain" {
  description = "Domain name of the bucket"
  value       = aws_s3_bucket_website_configuration.s3_bucket.website_domain
}
```

Module outputs are **read-only attributes**, reached as `module.<MODULE NAME>.<OUTPUT NAME>`.

!!! warning "The `domain` output is the wrong attribute for the job"
    `website_domain` is documented by the AWS provider as *"Domain of the website endpoint. This is used to create Route 53 alias records."* The one that gives you a URL is **`website_endpoint`** — documented simply as *"Website endpoint."* (Verified against the provider's docs source, 2026-08-08.)

    The tutorial's own destroy log proves the gap: `website_bucket_domain = "s3-website-us-west-2.amazonaws.com"`. That is the regional suffix with no bucket name in it — you cannot visit it. The page then tells you to visit `https://<YOUR BUCKET NAME>.s3-us-west-2.amazonaws.com/index.html`, hand-assembled and pointing at the **REST** endpoint rather than the website endpoint, so the `index_document` and `error_document` rules the module just configured don't apply to it.

    Both the rendered page and the example repo have this. A module whose purpose is hosting a website should output the endpoint you'd browse to — which is exactly the "consider which values to add as outputs" judgment the page is teaching.

## Calling it

```hcl
module "website_s3_bucket" {
  source = "./modules/aws-s3-static-website-bucket"

  bucket_name = "<UNIQUE BUCKET NAME>"

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
```

No `version` argument — local modules aren't versioned, which is the tradeoff [[tf-style-guide]] names when it says prefer publishing to a registry. S3 bucket names are globally unique, so `<UNIQUE BUCKET NAME>` needs replacing; the page suggests name plus date.

Root outputs re-export the module's, alongside the previous tutorial's:

```hcl
output "website_bucket_arn" {
  description = "ARN of the bucket"
  value       = module.website_s3_bucket.arn
}

output "website_bucket_name" {
  description = "Name (id) of the bucket"
  value       = module.website_s3_bucket.name
}

output "website_bucket_domain" {
  description = "Domain name of the bucket"
  value       = module.website_s3_bucket.domain
}
```

## Installing a local module

`terraform get` and `terraform init` both install modules; `init` additionally initializes backends and installs plugins. The distinction that matters for authoring:

> When installing a remote module, Terraform will download it into the `.terraform` directory in your configuration's root directory. When installing a local module, Terraform will instead refer directly to the source directory. Because of this, Terraform will automatically notice changes to local modules without having to re-run `terraform init` or `terraform get`.

So the edit-and-re-plan loop on a local module has no install step in it. That is the practical reason to develop a module locally before publishing it. (Same mechanism [[tut-module-use]] describes as a symlink.)

`terraform init` output shows the local module listed without a download line:

```shell
Initializing modules...
Downloading registry.terraform.io/terraform-aws-modules/ec2-instance/aws 4.3.0 for ec2_instances...
- ec2_instances in .terraform/modules/ec2_instances
Downloading registry.terraform.io/terraform-aws-modules/vpc/aws 3.18.1 for vpc...
- vpc in .terraform/modules/vpc
- website_s3_bucket in modules/aws-s3-static-website-bucket
```

## Upload, visit, clean up

```shell
$ aws s3 cp modules/aws-s3-static-website-bucket/www/ s3://$(terraform output -raw website_bucket_name)/ --recursive
```

`terraform output -raw` feeding a shell command is the seam worth noticing — the same pattern [[pyinfra]] uses to hand infrastructure addresses to a config-management tool ([[tut-outputs]] has the flag).

Emptying the bucket is required before destroy:

```shell
$ aws s3 rm s3://$(terraform output -raw website_bucket_name)/ --recursive
```

```shell
$ terraform destroy

Plan: 0 to add, 0 to change, 26 to destroy.

Changes to Outputs:
  - website_bucket_arn      = "arn:aws:s3:::robin-example-2021-01-25" -> null
  - website_bucket_domain   = "s3-website-us-west-2.amazonaws.com" -> null
  - website_bucket_name     = "robin-example-2021-01-25" -> null

Destroy complete! Resources: 26 destroyed.
```

26 = the previous tutorial's 22 plus this module's four. The repo's corrected module has six resources, so a real run of the repo destroys **28**.

## What's stale, and what's broken

!!! danger "The rendered module `main.tf` cannot apply on a current AWS account"
    Two AWS defaults changed after this page was written, and the page's four-resource module trips both. Verified against AWS documentation 2026-08-08.

    **1. ACLs are disabled on new buckets.** *"By default, all new buckets are created with the Bucket owner enforced setting applied and ACLs are disabled."* Under that setting, *"Requests to set or update ACLs fail"* — S3 returns `400 AccessControlListNotSupported`. So `aws_s3_bucket_acl` with `acl = "public-read"` fails against a bucket created with defaults.

    **2. Block Public Access is on by default.** *"By default, new buckets, access points, and objects don't allow public access."* `BlockPublicPolicy` causes S3 to reject a `PutBucketPolicy` whose policy allows public access — which is exactly the `Principal = "*"` policy in the module.

    The AWS provider documents the fix pattern: set `aws_s3_bucket_ownership_controls` first and hang the ACL off it with `depends_on`, and for public scenarios add an `aws_s3_bucket_public_access_block` with all four settings `false`.

!!! warning "The example repo is already fixed — the rendered page is not"
    Third page-vs-repo divergence in this collection, and the most consequential. `modules/aws-s3-static-website-bucket/main.tf` on `main` (fetched verbatim 2026-08-08) carries two resources the page never mentions, plus `depends_on` chains the page's version lacks:

    ```hcl
    resource "aws_s3_bucket_ownership_controls" "s3_bucket" {
      bucket = aws_s3_bucket.s3_bucket.id

      rule {
        object_ownership = "BucketOwnerPreferred"
      }
    }

    resource "aws_s3_bucket_public_access_block" "s3_bucket" {
      bucket = aws_s3_bucket.s3_bucket.id

      block_public_acls       = false
      block_public_policy     = false
      ignore_public_acls      = false
      restrict_public_buckets = false
    }

    resource "aws_s3_bucket_acl" "s3_bucket" {
      depends_on = [
        aws_s3_bucket_ownership_controls.s3_bucket,
        aws_s3_bucket_public_access_block.s3_bucket,
      ]

      bucket = aws_s3_bucket.s3_bucket.id

      acl = "public-read"
    }
    ```

    The `aws_s3_bucket_policy` likewise gains `depends_on = [aws_s3_bucket_acl.s3_bucket]`.

    **Clone the repo; do not copy the page.** Running the page's snippet gets you `AccessControlListNotSupported` on the ACL.

!!! note "These `depends_on` blocks are the legitimate kind"
    [[tf-meta-depends-on]] and [[tut-dependencies]] both call `depends_on` a last resort, to be replaced by an attribute reference wherever one exists. Here no attribute reference exists to replace it: the ACL doesn't consume any value produced by the ownership-controls or public-access-block resources, yet it must be applied after both. That eventual-consistency-style ordering with no data flow is the case `depends_on` is actually for — worth keeping as the counterexample to the "prefer references" rule.

!!! warning "Pins and the public-bucket pattern itself"
    Same stale pins as [[tut-module-use]] (AWS provider `~> 4.49.0`, vpc 3.18.1, ec2-instance 4.3.0 — current 6.x across the board).

    Separately: turning off all four Block Public Access settings to serve a static site is the shape AWS now steers away from. The current pattern is a private bucket behind CloudFront with an Origin Access Control, which keeps BPA fully on. The tutorial's approach still works if you disable the guards, but treat "disable four safety settings" as the signal it is — and note the irony against [[tut-module]]'s own argument that modules exist partly to stop object-storage misconfiguration.

## Next steps

Stated takeaways: created a local module, referenced it from the root configuration, configured it with input variables, and exposed data through outputs. Onward pointers are the module-design patterns guide, the object-attributes tutorial (next in the collection, captured as [[tut-module-object-attributes]]), and the module documentation.

---
Related: third in the collection after [[tut-module]] and [[tut-module-use]] — this is the author's side of the interface those two consume. Provider inheritance connects to [[tf-meta-providers]] and to [[tut-for-each]]'s harder constraint on `count`/`for_each` modules. The `depends_on` usage is the exception case for [[tf-meta-depends-on]] / [[tut-dependencies]]. Variable and output mechanics: [[tf-input-variables]], [[tf-outputs]], [[tf-block-output]]. Files-not-to-commit overlaps [[tf-style-guide]] and [[tf-manage-sensitive-data]]. Feeds learning-path **I5** (authoring modules) as its first hands-on, and **I4** by closing the use/author loop.
