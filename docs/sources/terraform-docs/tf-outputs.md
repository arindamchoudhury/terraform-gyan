# Output Values (Use outputs)

> **Source:** [developer.hashicorp.com/terraform/language/values/outputs](https://developer.hashicorp.com/terraform/language/values/outputs)
> **Added:** 2026-07-13
> **Source updated:** v1.15.x (latest at capture); undated page, captured 2026-07-13
> **Tags:** outputs, output-block, module-outputs, sensitive, ephemeral, remote-state
> **Type:** documentation

The third value block, completing B6's trio with [[tf-input-variables]] and [[tf-locals]]. An `output` block **exposes** information — the return values of a module — where variables feed data in and locals compute inside.

## What outputs are for

Four purposes:

- **Child → parent** — a child module exposes resource attributes to its caller.
- **Root → CLI** — the root module displays values in CLI output (and the HCP Terraform workspace overview).
- **Cross-config** — other configs read root outputs via the `terraform_remote_state` data source, including HCP Terraform state sharing (see [[tf-remote-state-data]]).
- **Automation** — pass a value from a Terraform run to an external tool.

## Define outputs

```hcl
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web.id
}

output "instance_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.web.private_ip
}
```

`value` can be **any valid expression**. Terraform displays root-module outputs in the CLI after `apply`.

## Access outputs

Where you define an output determines how you read it:

- **Root module** — shown in CLI after apply; also on the HCP workspace overview.
- **Child module** — exposed to the parent, accessed as `module.<CHILD_MODULE_NAME>.<OUTPUT_NAME>`:

```hcl
module "web_server" {
  source = "./modules/web_server"
}

resource "aws_route53_record" "web" {
  # …
  records = [module.web_server.instance_ip]
}

resource "aws_cloudwatch_alarm" "web_health" {
  # …
  dimensions = {
    InstanceId = module.web_server.instance_id
  }
}
```

## Sensitive outputs

Mark `sensitive = true` to redact the value from the **aggregate** CLI listing:

```hcl
output "database_password" {
  description = "Auto-generated password for the RDS database instance"
  value       = aws_db_instance.main.password
  sensitive   = true
}
```

!!! danger "This page's redaction claim is false — verified on v1.15.8"
    The source says "Trying to access a sensitive output value directly in the CLI displays a redacted message instead of the actual value", with `terraform output database_password` → `database_password = <sensitive>`.

    **It does not.** Querying by name prints the value in the clear. Only the no-argument listing redacts:

    | Command | Output |
    |---|---|
    | `terraform output` | `password = <sensitive>` |
    | `terraform output password` | `"notasecurepassword"` |

    The CLI command reference states the opposite of this page and is the correct one: "Terraform does not redact sensitive values when you specify the output by name." [[tut-outputs]] recorded the same from the tutorial. Full transcript in [[tf-cmd-output]].

Same two caveats as sensitive variables (see [[tf-manage-sensitive-data]]): the value is **still stored in state**, and **`terraform output -json` / `-raw` print it in plain text**. Adding `ephemeral` omits the output from state/plan files — at the cost of restrictions on what you can assign it. (An `ephemeral` output is allowed **only in child modules, not the root** — per [[tf-manage-sensitive-data]].)

---
Related: completes B6's value trio with [[tf-input-variables]] (inputs) and [[tf-locals]] (computed). The remote-state access purpose is the entry point for [[tf-remote-state-data]]; the `sensitive`/`ephemeral` behavior mirrors [[tf-block-variable]] and is detailed in [[tf-manage-sensitive-data]].
