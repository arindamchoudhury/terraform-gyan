# Input Variables (Use variables)

> **Source:** [developer.hashicorp.com/terraform/language/values/variables](https://developer.hashicorp.com/terraform/language/values/variables)
> **Added:** 2026-07-13
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-13
> **Tags:** variables, tfvars, precedence, TF_VAR, sensitive, ephemeral, validation, modules
> **Type:** documentation

The reference behind [[tf-aws-manage]]'s hands-on variables section, and B6 reference item #2. Where [[tf-aws-manage]] shows `variables.tf` + a single `-var` on the CLI, this page is the full model: how to define, reference, mark sensitive, and — the part B6 cares about — the **precedence order** across all the ways to assign a value.

A `variable` block defines the **input interface** of a module. It lets consumers pass custom values at runtime without editing the module's source. Replace any hardcoded value that changes between operations with a variable.

## Define variables

Defining a `variable` block in the **root** module lets consumers pass values in at run time; defining one in a **child** module lets a parent pass values down.

```hcl
variable "instance_type" {
  type        = string
  description = "EC2 instance type for the web server"
  default     = "t2.micro"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the web server will be deployed"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

- A variable **without a `default`** (like `subnet_id`) has no fallback — Terraform prompts the user for a value before generating a plan.
- An optional `validation` block enforces module requirements on the input. `condition` must hold; otherwise `error_message` is shown.

## Reference variable values

Reference a variable elsewhere in the config with `var.<NAME>`:

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  tags = {
    Environment = var.environment
    Name        = "${var.environment}-web-server"
  }
}
```

## Sensitive values

Set `sensitive = true` to keep Terraform from printing the value in CLI output:

```hcl
variable "database_password" {
  type        = string
  description = "Password for the RDS database instance"
  sensitive   = true
}
```

Caveat: **`sensitive` hides the value from output but Terraform still stores it in state.** To also omit it from state and plan files, add `ephemeral` — at the cost of restrictions on what values you can assign that variable.

## Assign values — precedence

Root-module variables can be set several ways. Child modules receive their inputs as arguments from the parent. Within a single file you can't reassign a variable. When the same variable name gets values from **different sources**, Terraform applies this order (highest precedence first):

| # | Source | Notes |
|---|---|---|
| 1 | `-var` / `-var-file` on the CLI, **and HCP Terraform variables** | applied in the order provided |
| 2 | `*.auto.tfvars` / `*.auto.tfvars.json` | lexical order |
| 3 | `terraform.tfvars.json` | |
| 4 | `terraform.tfvars` | |
| 5 | Environment variables (`TF_VAR_`) | |
| 6 | the variable's `default` argument | lowest precedence |

CLI and HCP Terraform values win; `default` is the last resort.

### Command-line variables

Good for one-off deployments or overriding without new files. Use `-var=<NAME>=<VALUE>`:

```shell
terraform apply -var="instance_type=t3.medium" -var="environment=prod"
terraform apply -var='subnet_ids=["subnet-12345","subnet-67890"]'
```

For complex types via CLI flags or env vars, use proper JSON to satisfy shell escaping rules. To avoid shell quoting entirely, prefer variable definition files.

### Variable definition files

`.tfvars` / `.auto.tfvars` files assign values directly by name. Ideal for per-environment configs and for keeping values in version control.

```hcl
# production.auto.tfvars
instance_type     = "t3.large"
environment       = "prod"
subnet_ids        = ["subnet-12345", "subnet-67890", "subnet-abcdef"]
enable_monitoring = true
```

Terraform **auto-loads** a definition file if it is named `*.auto.tfvars`, `*.auto.tfvars.json`, `terraform.tfvars.json`, or `terraform.tfvars`. Among auto-loaded files the precedence is: `*.auto.tfvars`/`.json` (lexical) → `terraform.tfvars.json` → `terraform.tfvars`.

A `.json` file is parsed as a JSON object with variable names as root keys:

```json
{
  "image_id": "ami-abc123",
  "availability_zone_names": ["us-west-1a", "us-west-1c"]
}
```

Any non-auto file is applied explicitly with `-var-file`:

```shell
terraform apply -var-file="production.auto.tfvars"
```

If a definition file holds sensitive values, ignore it in your VCS.

### Environment variables

Useful in CI/CD to inject values without extra files. Prefix the variable name with `TF_VAR_`:

```shell
export TF_VAR_instance_type=t3.medium
export TF_VAR_environment=staging
terraform apply
```

## Manage variables in HCP Terraform

HCP Terraform adds: assign values through **workspaces**, group variables into **sets** applied across multiple workspaces, and **access controls** limiting who can view/create variables.

## Undeclared variables

Behavior differs by *how* you assign a value with no matching `variable` block:

- **Environment variable** → silently **ignored**.
- **Variable definition file** → **warning** (catches misspellings).
- **`-var` on the CLI** → **error**.

## Variable lifecycle

Terraform evaluates most variables when it **creates the plan**. To use a variable in a module or provider `source`/`version` attribute, the variable's **`const` attribute must be set** so Terraform evaluates it during **initialization** instead — those attributes are read at init time, before a plan exists.

---
Related: reference for [[tf-aws-manage]]'s hands-on variables section (that lesson shows `variables.tf`/`outputs.tf` and one `-var`; this is the full precedence + assignment model). Precedence detail feeds learning-path **B6**. Pairs with the `variable` block reference (not yet captured) for the argument-level spec.
