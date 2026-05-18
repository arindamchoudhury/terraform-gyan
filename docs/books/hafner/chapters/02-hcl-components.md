# Chapter 2 — Terraform HCL Components

> *Source: Hafner (2025), Chapter 2, pages 24–59.*
>
> A ground-up tour of the Terraform language: starting with a complete Hello World project (AWS instance), then dissecting every component — block syntax, settings, providers, resources, data sources, meta arguments, modules, and the refactoring blocks (`import`, `moved`, `removed`).

---

## 1. Hello World — A Complete First Project

The chapter opens with a real AWS instance launch to make the language tangible before breaking it down.

### 1.1 Research and design

Before writing any code, consult:

- **AWS docs** — what parameters does the resource need?
- **AWS web console** — manually clicking through ("ClickOps") is a good learning technique even if it doesn't scale.
- **Terraform provider docs** — lists every argument, marks which are required, and shows example usage.

Minimum required arguments for `aws_instance`:

| Argument | Source |
| --- | --- |
| `ami` | Looked up dynamically via data source — new AMIs are released often, hardcoding is a security risk |
| `instance_type` | Hardcoded for now (`t3.micro`), exposed as a variable in Ch 3 |
| `subnet_id` | Looked up dynamically — hardcoding ties the code to one account |

### 1.2 Project layout

Terraform reads all `*.tf` files in a directory. Convention: split by concern.

```bash
mkdir terraform_aws_modules && cd terraform_aws_modules
git init
touch main.tf lookups.tf providers.tf   # PowerShell: New-Item main.tf, lookups.tf, providers.tf
```

| File | Contents |
| --- | --- |
| `providers.tf` | `terraform` settings block + `provider` block |
| `lookups.tf` | `data` source blocks |
| `main.tf` | `resource` blocks and `output` blocks |

### 1.3 The providers file

```hcl
# providers.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"   # typically a variable, not hardcoded
}
```

### 1.4 The lookups file

```hcl
# lookups.tf
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]   # chained from vpc lookup
  }
}

data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]   # Canonical (makers of Ubuntu)
  most_recent = true

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}
```

### 1.5 The main file

```hcl
# main.tf
resource "aws_instance" "hello_world" {
  ami           = data.aws_ami.ubuntu.id
  subnet_id     = data.aws_subnets.default.ids[0]
  instance_type = "t3.micro"   # exposed as variable in Ch 3
}
```

### 1.6 Running the project

```bash
aws configure                  # set credentials once
terraform init                 # download provider plugins
terraform plan -out tfplan     # preview changes
terraform apply tfplan         # execute the plan
```

---

## 2. Block Syntax

**Blocks are the primary language construct of Terraform** — analogous to statements in imperative languages, but as nouns/adjectives rather than verbs.

```hcl
type "label" {
  argument1 = "string"
  argument2 = 42
  argument3 = true
  argument4 = null

  subblock {
    sub_argument = "value"
  }

  subblock {                   # subblocks can repeat; arguments cannot
    sub_argument = "value"
  }
}
```

### 2.1 Block types

Terraform HCL has 12 block types:

| Block type | Purpose |
| --- | --- |
| `terraform` | Configure Terraform itself and the workspace (providers, backend) |
| `provider` | Configure a provider (credentials, region, etc.) |
| `resource` | Create and manage a piece of infrastructure |
| `data` | Read-only lookup of existing infrastructure |
| `variable` | External inputs passed into the module |
| `locals` | Internal variables scoped to a module |
| `module` | Reuse a collection of resources as a unit |
| `import` | Bring existing infrastructure into Terraform state |
| `moved` | Rename/relocate a resource without recreating it |
| `removed` | Mark a resource as removed without destroying it |
| `check` | Validate deployed infrastructure |
| `output` | Export values from a module to its caller |

> 💡 `resource` is the reason Terraform exists. Everything else supports resource blocks — providing config values, organising them into reusable units, or adjusting how Terraform manages them.

### 2.2 Labels and reference strings

Labels identify a block instance and form its reference string for use by other blocks.

| Block type | Labels | Example reference |
| --- | --- | --- |
| `terraform` | none | *(no reference; singleton)* |
| `locals` | none | *(no reference; accessed via `local.<key>`)* |
| `provider` | 1 (matches key in `required_providers`) | *(used internally via `provider` meta arg)* |
| `variable`, `output`, `module` | 1 (user-chosen) | `var.instance_type`, `module.vpn` |
| `resource`, `data` | 2 (subtype + identifier) | `aws_instance.hello_world`, `data.aws_vpc.default` |

> 💡 The `resource` prefix is dropped in `depends_on` because that arg only takes resource references — no ambiguity.

### 2.3 Arguments vs. subblocks

| | Arguments | Subblocks |
| --- | --- | --- |
| Syntax | `name = value` (with `=`) | `name { … }` (no `=`) |
| Repeatable? | No — each argument name is unique per block | Yes — same subblock type can appear multiple times |
| Purpose | Set a single value | Group related config; can stack (e.g., multiple `filter` blocks) |

### 2.4 Attributes

Blocks *export* attributes in addition to accepting arguments:

- All arguments are automatically exposed as attributes.
- Resources also expose **computed attributes** (filled in by the provider after creation, e.g., `arn`, `instance_state`).
- **Subblock contents are not exposed as attributes** — only top-level arguments are.

### 2.5 Ordering

**Block order in files does not matter.** Terraform builds the dependency graph from attribute/argument links, not from the order code is written. Blocks can live in any file in the directory.

### 2.6 Style

Terraform has an official style guide, enforced by `terraform fmt`:

```bash
terraform fmt          # auto-format all .tf files in the current directory
terraform fmt -check   # exit non-zero if any file would change (useful in CI)
```

Ordering within a block:

1. Meta arguments (e.g., `provider`, `depends_on`) — **top**
2. Block-specific arguments — grouped with blank lines between groups, equal signs aligned
3. Block-specific subblocks
4. Meta argument subblocks (e.g., `lifecycle`) — **bottom**

---

## 3. Terraform Settings Block

The `terraform` block configures the workspace itself — what providers to install, where to store state, and which version of Terraform is required.

```hcl
terraform {
  required_version = "~> 1.5"        # optional: pin Terraform/OpenTofu version

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {                      # use one of: backend OR cloud, not both
    bucket = "my-state-bucket"
    key    = "path/to/state"
    region = "us-east-1"
  }
}
```

### 3.1 Backend vs. cloud blocks

| Block | Use case |
| --- | --- |
| `backend` | Standard state storage (S3, GCS, AzureRM, Consul, HTTP, etc.). Has been in Terraform for years. |
| `cloud` | HCP Terraform / Terraform Enterprise only. Newer; supports enhanced features beyond state storage. |

If neither is defined, the **local backend** is used (state file on the local filesystem) — fine for solo development, never for production.

> ⚠️ Backends are hardcoded into Terraform — you can't write a custom backend plugin. The `http` backend lets you point at a custom REST API if needed.

### 3.2 Experiments

The `experiments` argument opts into unstable, in-development features:

```hcl
terraform {
  experiments = [module_variable_optional_attrs]   # example (now stable/removed)
}
```

- Experiments are disabled by default; Terraform warns when they're enabled.
- APIs can change between releases; experiments may be removed entirely.
- A project using an experiment is locked to a specific Terraform version — **avoid in production**.

---

## 4. Providers

Providers are to Terraform what SDKs are to other languages — they supply the resources and data sources for a specific vendor.

```
Terraform core  →  Provider plugin  →  Vendor API
```

### 4.1 Provider registry

Public providers live at [registry.terraform.io](https://registry.terraform.io/browse/providers). `terraform init` downloads them from there. The registry also hosts provider documentation — often the best place to understand a vendor's API.

> 💡 Resource names are namespaced by provider prefix: `aws_instance` → AWS provider, `linode_instance` → Linode provider. A quick way to identify which provider a resource belongs to.

### 4.2 Required providers

Always declare providers explicitly in `required_providers` — this pins the version and prevents Terraform from inferring the wrong provider:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

Terraform can infer `hashicorp/<name>` from the resource prefix, but explicit declaration is best practice — without it you can't control the version.

### 4.3 Provider configuration

The `provider` block configures the provider: **authentication** and **scoping** (region, project).

```hcl
provider "aws" {
  region = "us-west-2"
}

provider "google" {
  project = "example_project"
  region  = "us-central1"
}
```

- Many providers also accept credentials via environment variables or config files — check the provider's docs. A `provider` block is not always required.
- `provider` blocks can **only** be defined in the root module (the directory you run `terraform` in). Child modules inherit providers from the root.

### 4.4 Provider aliases — multiple connections to the same vendor

Use `alias` to have multiple configurations for the same provider (e.g., two AWS regions, two Cloudflare accounts):

```hcl
provider "aws" {
  region = "us-east-1"        # default — no alias
}

provider "aws" {
  alias  = "west"
  region = "us-west-2"        # non-default — must be explicitly selected
}

data "aws_vpc" "backup" {
  provider = aws.west         # use the aliased provider
  default  = true
}
```

Without `provider = aws.west`, a resource uses the default (no-alias) provider.

---

## 5. Resources

**Resources are the reason Terraform exists.** Each resource block maps to one piece of infrastructure — it creates, updates, or destroys that infrastructure to match the block's arguments.

```hcl
resource "aws_instance" "hello_world" {
  ami           = data.aws_ami.ubuntu.id
  subnet_id     = data.aws_subnets.default.ids[0]
  instance_type = var.instance_type
}
# Reference: aws_instance.hello_world (or resource.aws_instance.hello_world)
```

- `type` + `name` must be unique within a module.
- Arguments come from the provider — each resource type has its own set.
- Resources expose attributes (including computed ones) that other blocks can reference.

---

## 6. Data Sources

Data sources are **read-only lookups** — they search for existing infrastructure and expose its attributes. They never create or modify anything.

```hcl
data "aws_vpc" "default" {
  default = true
}
# Reference: data.aws_vpc.default.id

data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
# Reference: data.aws_ami.ubuntu.id
```

**What happens if no match is found?**

- Most data sources (like `aws_ami`) throw an error and abort the plan.
- Data sources that return lists (like `aws_subnets`) may return an empty list rather than erroring.

---

## 7. Meta Arguments

Meta arguments are **universal arguments** available on every `resource`, `data`, or `module` block. They change *how Terraform processes the block*, not the underlying infrastructure config. They are built into HCL itself, not provided by the vendor.

> ⚠️ Many meta arguments require **literal values** (hardcoded `true`/`false`, not expressions) because they are evaluated early in the planning cycle before attribute values are known.

### 7.1 `provider` — select a non-default provider alias

```hcl
data "aws_vpc" "backup" {
  provider = aws.west
  default  = true
}
```

### 7.2 `lifecycle` — control resource replacement behaviour

The `lifecycle` subblock can appear once per resource.

**`create_before_destroy`**

Default: Terraform destroys before creating the replacement. Set to `true` to invert — create the new resource first, then destroy the old one. Useful for high-availability scenarios.

> ⚠️ Many resources can't coexist (e.g., two IAM roles with the same name, two instances sharing an Elastic IP) — `create_before_destroy` will error for those.

```hcl
lifecycle {
  create_before_destroy = true
}
```

**`prevent_destroy`**

Makes any plan that would destroy this resource fail. Use sparingly — caveats:

- Takes only a literal value, so it can't be enabled for prod and disabled for dev.
- Deleting the resource block also deletes this setting, so it won't prevent destruction when the block is removed.

```hcl
lifecycle {
  prevent_destroy = true
}
```

**`ignore_changes`** *(most commonly used)*

Tells Terraform to skip updating a resource when only the listed arguments have changed. After initial creation, those fields are treated as read-only by Terraform.

```hcl
lifecycle {
  ignore_changes = [ami]      # don't replace instance when a new AMI is released
}

lifecycle {
  ignore_changes = all        # never update this resource after creation (no brackets on `all`)
}
```

Common use cases:

- AMI updates (don't replace running instances on every AMI release)
- Tags managed externally (e.g., by AWS EKS/ECS adding its own tags)

Prefer `ignore_changes` over `prevent_destroy` — it doesn't block destroy plans.

**`replace_triggered_by`**

Forces a resource replacement when another resource or attribute changes — even if that other resource doesn't feed any arguments into this one.

```hcl
resource "null_resource" "replace_instance" {
  triggers = {
    instance_type = var.instance_type
  }
}

resource "aws_instance" "hello_world" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  lifecycle {
    replace_triggered_by = [null_resource.replace_instance]
  }
}
```

> 💡 `replace_triggered_by` takes a resource reference or attribute reference — not a variable directly.

### 7.3 `depends_on` — explicit dependencies

Terraform normally infers dependencies from attribute/argument links. When two resources depend on each other but don't share any attributes, use `depends_on`:

```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_nat_gateway" "example" {
  subnet_id = aws_subnet.example.id

  depends_on = [
    aws_internet_gateway.main   # resource prefix dropped — depends_on only takes resources
  ]
}
```

When used on a `module` block, `depends_on` applies to all resources inside the module.

---

## 8. Modules

Modules are the primary code-reuse mechanism in Terraform — a directory of `.tf` files packaged as a callable unit. Covered deeply in Chapter 3; here's the `module` block syntax:

```hcl
module "vpn" {
  source  = "tedivm/dev-vpn/aws"   # registry, local path, or git ref — required
  version = "~> 1.0"              # version constraint (registry modules only)

  # Module-specific arguments (defined by the module's variable blocks):
  identifier = "my-vpn"
  subnet_ids = data.aws_subnets.default.ids
}
```

Module-specific meta arguments:

| Arg | Purpose |
| --- | --- |
| `source` | Where to download the module from. Required. |
| `version` | Version constraint when source is a registry. |
| `providers` | Map outer provider aliases to the module's expected provider names. |

Module inputs come from `variable` blocks; outputs come from `output` blocks.

---

## 9. Import, Moved, and Removed

Refactoring blocks added in later Terraform releases — useful when the state needs to be updated to reflect code changes.

### 9.1 `import` — bring existing infrastructure into Terraform (v1.5+)

```hcl
import {
  to = aws_instance.main            # which resource block to associate with
  id = "i-1234567890abcdef0"        # v1.5: must be hardcoded; v1.6+: can use variables/data
}

resource "aws_instance" "main" {
  # required arguments
}
```

- Lets you manage existing manually-created infrastructure without recreating it.
- Once imported, remove the `import` block (or leave it — idempotent after first run).
- Supercedes the `terraform import` CLI command for most use cases (plannable, reviewable, automatable).

### 9.2 `moved` — rename/relocate a resource without recreating it

```hcl
moved {
  from = module.bad_unclear_name
  to   = module.better_name
}

module "better_name" { … }
```

- Safe to leave in place permanently — if the source resource no longer exists in state, Terraform just creates a new one at the destination.
- Great for published modules that need to rename resources without breaking existing users.

### 9.3 `removed` — remove from management without destroying (v1.7+)

Marks a resource as no longer managed by this workspace — Terraform stops tracking it but does not destroy it. Covered further in Chapter 9.

---

## 10. Summary

- HCL is built around **blocks** — type, labels, arguments, subblocks, attributes.
- **12 block types**: `terraform`, `provider`, `resource`, `data`, `variable`, `locals`, `module`, `import`, `moved`, `removed`, `check`, `output`.
- `resource` is the core; everything else supports it.
- The `terraform` settings block wires up providers and the state backend.
- **Data sources** are read-only lookups; **resources** create and manage infrastructure.
- **Meta arguments** (`lifecycle`, `depends_on`, `provider`) change how Terraform processes blocks — available on every resource/data/module regardless of provider.
- `lifecycle` options: `create_before_destroy`, `prevent_destroy`, `ignore_changes`, `replace_triggered_by`.
- `terraform fmt` auto-formats code; run in CI with `-check`.
- `import`, `moved`, `removed` are refactoring blocks for managing state changes safely.

---

## 11. References

- AWS provider documentation — <https://registry.terraform.io/providers/hashicorp/aws/latest/docs>
- Terraform style guide — <https://mng.bz/RVGn>
- Terraform backend docs — <https://mng.bz/6egy>
- HTTP backend (custom backends) — <https://mng.bz/1X7Z>
- `aws_instance` resource — <https://mng.bz/VVqr>
- AWS provider authentication — <https://mng.bz/ZlZj>
