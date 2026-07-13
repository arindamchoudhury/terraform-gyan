# Output data from Terraform

> **Source:** [developer.hashicorp.com/terraform/tutorials/configuration-language/outputs](https://developer.hashicorp.com/terraform/tutorials/configuration-language/outputs)
> **Added:** 2026-07-13
> **Source updated:** undated tutorial (~10 min); captured 2026-07-13
> **Tags:** outputs, terraform-output, sensitive, json, raw, state, interpolation, length
> **Type:** documentation

Fifth **Configuration Language** tutorial, the hands-on for [[tf-outputs]] / [[tf-block-output]]. On a VPC + LB + EC2 + database stack (46 resources), it defines outputs, queries them every way (`terraform output`, `-raw`, `-json`), and — the part worth memorizing — shows **exactly when `sensitive` does and doesn't redact**. Uses `git clone https://github.com/hashicorp-education/learn-terraform-outputs`; Terraform 1.2+, AWS credentials.

## Define outputs

Convention: put them in `outputs.tf`. `value` can be any expression:

```hcl
output "vpc_id" {
  description = "ID of project VPC"
  value       = module.vpc.vpc_id
}

output "lb_url" {
  description = "URL of load balancer"
  value       = "http://${module.elb_http.elb_dns_name}/"
}

output "web_server_count" {
  description = "Number of web servers provisioned"
  value       = length(module.ec2_instances.instance_ids)
}
```

`lb_url` uses string interpolation; `web_server_count` uses `length()`. Outputs live in **state**, so you must `terraform apply` to record new outputs even when **no infrastructure changes** — the plan shows `Changes to Outputs:` with `0 to add/change/destroy`.

## Query outputs

```shell
$ terraform output                 # all outputs
lb_url = "http://…/"
vpc_id = "vpc-004c2d1ba7394b3d6"
web_server_count = 4

$ terraform output lb_url          # one by name (quoted since 0.14)
"http://…/"

$ terraform output -raw lb_url     # machine-readable, unquoted
http://…/

$ curl $(terraform output -raw lb_url)
<html><body><div>Hello, world!</div></body></html>
```

Since **0.14**, Terraform wraps string outputs in quotes; **`-raw`** strips them for piping into other commands.

## Sensitive outputs — the exact redaction rules

```hcl
output "db_username" {
  description = "Database administrator username"
  value       = aws_db_instance.database.username
  sensitive   = true
}

output "db_password" {
  description = "Database administrator password"
  value       = aws_db_instance.database.password
  sensitive   = true
}
```

After apply, the aggregate output shows `db_password = <sensitive>`. But the redaction is **narrower than it looks**:

| Terraform **redacts** sensitive outputs | Terraform does **not** redact |
|---|---|
| plan / apply / destroy | `terraform output <name>` (query **by name**) |
| `terraform output` (query **all**) | `terraform output -json` |
| | a child module's output used in the root module |

So `terraform output db_password` prints `"notasecurepassword"` **in the clear** — querying by name is not redacted. And sensitive values are **stored as plain text in state** (`grep outputs terraform.tfstate` shows them). `sensitive` reduces *accidental* console exposure; it is **not** protection — secure the state file (see [[tf-manage-sensitive-data]]).

## Machine-readable JSON

```shell
$ terraform output -json
{
  "db_password":      { "sensitive": true,  "type": "string", "value": "notasecurepassword" },
  "web_server_count": { "sensitive": false, "type": "number", "value": 4 },
  …
}
```

`-json` **does not redact** sensitive values — it assumes an automation tool consumes the output. Each entry carries `sensitive`, `type`, and `value`.

`terraform destroy` removes all 46 resources at the end.

---
Related: hands-on for [[tf-outputs]] (purposes, `module.<child>.<output>`) and [[tf-block-output]] (arguments). The redaction matrix here is the concrete version of the `-json`/`-raw` leak noted in [[tf-manage-sensitive-data]] — plus the sharper by-name case. Continues the Configuration Language collection from [[tut-locals]]. Feeds learning-path **B6** (outputs, `terraform output` flags) and **A6** (sensitive-output redaction limits, plaintext state).
