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

Mark `sensitive = true` to redact from CLI output — `terraform output <name>` then shows `<sensitive>`:

```hcl
output "database_password" {
  description = "Auto-generated password for the RDS database instance"
  value       = aws_db_instance.main.password
  sensitive   = true
}
```

Same two caveats as sensitive variables (see [[tf-manage-sensitive-data]]): the value is **still stored in state**, and **`terraform output -json` / `-raw` print it in plain text**. Adding `ephemeral` omits the output from state/plan files — at the cost of restrictions on what you can assign it. (An `ephemeral` output is allowed **only in child modules, not the root** — per [[tf-manage-sensitive-data]].)

---
Related: completes B6's value trio with [[tf-input-variables]] (inputs) and [[tf-locals]] (computed). The remote-state access purpose is the entry point for [[tf-remote-state-data]]; the `sensitive`/`ephemeral` behavior mirrors [[tf-block-variable]] and is detailed in [[tf-manage-sensitive-data]].
