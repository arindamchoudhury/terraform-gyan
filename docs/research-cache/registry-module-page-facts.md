# Registry module page — observed structure

Captured **2026-08-16** from the public Terraform Registry, by rendering the page in a browser
(the page is a JavaScript application, so a plain fetch returns an empty shell) and by reading the
same data from the registry's `v1` HTTP API.

Reference module: [`terraform-aws-modules/ec2-instance/aws`](https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/latest).
Used by Chapter 13 §9.

---

## Header strip (module page, v6.4.0)

Breadcrumb: `Modules / terraform-aws-modules / ec2-instance / v6.4.0`.

| Label on the page | Value |
|---|---|
| Provider: | `aws` |
| Downloads: | 52.7M |
| This week: | 518,859 |
| Versions: | 98 |
| Source code: | `github.com/terraform-aws-modules/terraform-aws-ec2-instance` |
| Published: | March 26, 2026 |
| Published by: | `antonbabenko` |
| Managed by: | `antonbabenko` |

`Downloads:` and `This week:` are **module-wide, not version-scoped** — the 5.8.0 page renders the
same 52.7M and 518,859. The selector drops the `(latest)` marker on an older version and the
breadcrumb reads `v5.8.0`.

Controls in the same strip: a combobox labelled **Module version** reading `Version 6.4.0 (latest)`,
a **View Source** link, and an **Examples** dropdown. Modules that have submodules also get a
**Submodules** dropdown (present on `aws-ia/vpc/aws`, absent here).

No **Verified** badge on this module. `aws-ia/vpc/aws` renders a badge reading **Partner** next to
the module name; that module's API record has `"verified": true`, while `ec2-instance`'s has
`"verified": false`.

## Tabs and their counts

`Readme · Inputs · Outputs · Dependencies · Resources`, each with a count except Readme.

| Tab | v6.4.0 (26 Mar 2026) | v5.8.0 (30 Mar 2025) |
|---|---|---|
| Inputs | 83 | 70 |
| Outputs | 30 | 27 |
| Dependencies | 1 | 1 |
| Resources | 13 | 7 |
| Provider requirement | `hashicorp/aws >= 6.37` | `hashicorp/aws >= 4.66` |

Required inputs, from the API (`root.inputs[].required`): **zero at both versions**. The Inputs tab
prints only an *Optional Inputs* heading, with the sentence *"This module has no required
variables."*

Notable defaults: `name` is `""`, `instance_type` is `"t3.micro"`, `ami` is `null`, and
`ami_ssm_parameter` defaults to
`"/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"`. The module also exposes
`ignore_ami_changes`, matching the `aws_instance.ignore_ami` entry in the resource list.

## Resources tab

Standing text: *"This is the list of resources that the module may create. The module can create zero
or more of each of these resources depending on the `count` value. The `count` value is determined at
runtime. The goal of this page is to present the types of resources that may be created."* Then
*"This list contains all the resources this plus any submodules may create. When using this module, it
may create fewer resources if you use a submodule."* Then *"This module defines 13 resources."*

The 13 are listed alphabetically by address, `aws_ebs_volume.this` first and
`aws_vpc_security_group_ingress_rule.this` last. Each entry is a bare `<code>` inside an `<li>` —
**no links** on this tab. The readme's terraform-docs table is the copy that links every resource and
data source to its provider documentation
(`registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance`, and
`.../docs/data-sources/ssm_parameter` for the data sources).

The 13 are all **managed resources**. The four data sources the module reads
(`aws_iam_policy_document.assume_role_policy`, `aws_partition.current`, `aws_ssm_parameter.this`,
`aws_subnet.this`) appear only in the terraform-docs table inside the Readme, not on this tab.

## Dependencies tab

Two sections. Module dependencies: *"This module has no external module dependencies."* Provider
Dependencies, with the standing note that providers *"will be automatically installed during
`terraform init`"*: `aws (hashicorp/aws) >= 6.37`.

## Provision Instructions panel

Right sidebar, below a **Module Downloads** panel (this week 518,859 · this month 1.0M · this year
16.8M · all time 52.7M). Text: *"Copy and paste into your Terraform configuration, insert the
variables, and run `terraform init`"*, then a **Copy configuration** button over:

```hcl
module "ec2-instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.4.0"
}
```

The pinned version tracks the version being viewed (`5.8.0` on the 5.8.0 page). The Readme's own
Usage snippets carry **no `version` argument**.

When the module has required inputs, the skeleton carries a comment counting them. `aws-ia/vpc/aws`
4.8.0 renders:

```hcl
module "vpc" {
  source  = "aws-ia/vpc/aws"
  version = "4.8.0"

  # insert the 2 required variables here
}
```

`ec2-instance` has no such line, which is the panel's own statement that nothing is required.

## Examples

The Examples dropdown links to registry-hosted pages, not to GitHub:
`/modules/terraform-aws-modules/ec2-instance/aws/latest/examples/complete` and
`.../examples/session-manager`.

An example page has its own `Readme · Inputs · Outputs` tabs (complete: Inputs 0, Outputs 54), a
*Return to module* link, a *Change example* control, and a source link pinned to the tag:
`github.com/terraform-aws-modules/terraform-aws-ec2-instance/tree/v6.4.0/examples/complete`.

Its Modules table shows every call to the module under test as `../../` with version `n/a`, plus the
real registry modules it pulls in (`terraform-aws-modules/vpc/aws ~> 6.0`,
`terraform-aws-modules/security-group/aws ~> 5.0`).

The example page has its own Provision Instructions panel, emitting the `//` sub-directory form:

```hcl
module "ec2-instance_example_complete" {
  source  = "terraform-aws-modules/ec2-instance/aws//examples/complete"
  version = "6.4.0"
}
```

**That call works**, measured 2026-08-16 with `terraform get` on Terraform 1.15.8. All twelve `../../`
calls resolved to the package root (`.terraform\modules\ec2_instance_example_complete`), while the
example's own module reads from `...\examples\complete`. This matches the
[`module` block reference](https://developer.hashicorp.com/terraform/language/block/module): *"Terraform
extracts the entire package to local disk, but reads the module from the subdirectory. As a result,
modules in a sub-directory of a package can use a local path to reference another module in the same
package."* What breaks is pasting the example's HCL into a configuration of your own, where nothing
sits above `../../`.

Pinning the example pins one package. The same run installed `vpc` **6.6.1** and `security-group`
**5.3.1** from the example's `~>` constraints — neither version named anywhere in the caller.

## The same data over HTTP

Everything above is available without the browser:

```
https://registry.terraform.io/v1/modules/terraform-aws-modules/ec2-instance/aws           # latest
https://registry.terraform.io/v1/modules/terraform-aws-modules/ec2-instance/aws/6.4.0     # pinned
https://registry.terraform.io/v1/modules/terraform-aws-modules/ec2-instance/aws/versions  # all 98
```

Useful keys: `version`, `published_at`, `downloads`, `verified`, `source`, `root.inputs[]` (with
`required`, `type`, `default`), `root.outputs[]`, `root.resources[]`, `root.provider_dependencies[]`,
`submodules[]`, `examples[]`. `root.outputs` is not alphabetised; the web page sorts it.

Re-verified 2026-08-16 against the API: 6.4.0 published `2026-03-26T19:54:48Z`, `verified: false`,
`downloads: 52717885`, 83 inputs / **0 required** / 30 outputs / 13 resources / `hashicorp/aws >= 6.37`,
no module dependencies, examples `examples/complete` and `examples/session-manager`, no submodules;
5.8.0 published `2025-03-30T16:10:59Z` with 70 / 0 / 27 / 7 and `>= 4.66`; `/versions` returns 98.
`aws-ia/vpc/aws` is at 4.8.0 with `verified: true` and renders the **Partner** badge.

The download counters are volatile and the page shows two generations of them: a fresh load paints the
server-rendered set (52.7M all time · 518,859 this week · 1.0M this month · 16.8M this year, matching
the version record's `downloads`), and a page left open long enough to re-fetch client-side showed
52.6M · 520,939 · 911,164 · 16.7M. Treat any download figure as a reading with a timestamp, never as
a stable fact.
