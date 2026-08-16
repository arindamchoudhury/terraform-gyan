# Chapter 8 — Production-Grade Terraform Code

> *Source: Brikman (2022), **Terraform: Up & Running**, 3rd ed., Chapter 8, pages 275–313.*
>
> The chapter that stops teaching Terraform and starts teaching judgement. Two-thirds of it is not about syntax at all: how long production infrastructure actually takes, a checklist of the work people forget to estimate, and the module design patterns that survive contact with a real team. The last third is escape hatches — provisioners, `null_resource`, the `external` data source.
>
> 📌 **Notes adapted where version-bound.** Book written 2022 against Terraform ~1.2; current stable is **1.15.8** / OpenTofu **1.12.5** ([[version-facts]]). One language claim in this chapter is now **false on both engines** — the limitation that motivates half its self-validation section — and two of its named tools have been superseded. The design argument is untouched.

> 🔗 **See also:** [Modules](../../../topics/modules.md) for the cross-source module treatment, and [Meta-arguments and `lifecycle`](../../../topics/meta-arguments-lifecycle.md) for where `precondition`/`postcondition` actually live.

---

## 1. Why it takes so long

The chapter opens with numbers, and they are the most-quoted thing in the book:

| Type of infrastructure | Example | Time estimate |
| --- | --- | --- |
| Managed service | Amazon RDS | 1–2 weeks |
| Self-managed distributed system (stateless) | Node.js cluster in an ASG | 2–4 weeks |
| Self-managed distributed system (stateful) | Elasticsearch cluster | 2–4 months |
| Entire architecture | apps, data stores, load balancers, monitoring | 6–36 months |

Brikman is explicit that these are drawn from working with "hundreds of companies", and that they are optimistic. The stated definition of production-grade is worth keeping because it sets the stakes rather than the standard: *"the kind of infrastructure you'd bet your company on."*

Three reasons offered for the overrun, and the third is the one that carries the chapter:

- **DevOps is in the Stone Age.** Cloud computing, IaC and DevOps are mid-to-late-2000s terms; Terraform, Docker, Packer and Kubernetes are mid-to-late-2010s tools. Immature and fast-moving, so few people have deep experience.
- **Yak shaving.** The chapter quotes Seth Godin's definition at length. The Terraform-shaped version: you go to deploy a one-character typo fix, and end up upgrading the OS across the fleet. Tight coupling and duplication make every change pull the whole tangle.
- **Essential complexity.** Borrowing Brooks's accidental-versus-essential split, the first two reasons are accidental. The essential one is that **there is a genuinely long checklist**, and most developers do not know most of it, so they estimate against the part they can see.

> 💭 (mine): the numbers age well precisely because they are about *organisational* effort, not tooling. Nothing in the last four years of Terraform releases moves "stateful distributed system" out of the months column.

## 2. The production-grade infrastructure checklist

The chapter's diagnostic is good: ask five people at your company what the requirements for going to production are, and get five different answers. The checklist exists to make that conversation explicit.

| Task | What it covers |
| --- | --- |
| Install | binaries and dependencies |
| Configure | runtime config: ports, TLS certs, service discovery, leaders/followers, replication |
| Provision | servers, load balancers, network config, firewalls, IAM |
| Deploy | rolling out the service and its updates with no downtime; blue-green, rolling, canary |
| High availability | surviving loss of processes, servers, services, datacenters, regions |
| Scalability | horizontal and vertical scaling in response to load |
| Performance | CPU, memory, disk, network, GPU; query tuning, benchmarking, load testing, profiling |
| Networking | static and dynamic IPs, ports, service discovery, firewalls, DNS, SSH, VPN |
| Security | encryption in transit and at rest, authn, authz, secrets management, server hardening |
| Metrics | availability, business, app and server metrics; observability, tracing, alerting |
| Logs | rotation on disk, aggregation to a central location |
| Data backup | scheduled backups of DBs and caches, replicated to a separate region or account |
| Cost optimization | instance types, spot and reserved, auto scaling, cleaning up unused resources |
| Documentation | code, architecture, practices, and incident playbooks |
| Tests | automated tests for the infrastructure code, run per commit and nightly |

The instruction that makes it useful is not "do all of this":

> Not every single piece of infrastructure needs every single item on the list, but you should **consciously and explicitly document which items you've implemented, which ones you've decided to skip, and why.**

The chapter's own observation is that developers know the first four rows and get caught by everything after. Networking and security are singled out as the ones that take months and are left out of plans entirely.

> 💡 **Tip** — the checklist's tool column is the only part that dates. Infracost, Terratest, OPA and tflint are still current; the Elastic Stack and Sumo Logic entries read as of their moment. Treat the *tasks* as the artifact and the tools as illustration.

## 3. Small modules

The claim is deliberately strong:

> large modules — modules that contain more than a few hundred lines of code or that deploy more than a few closely related pieces of infrastructure — should be considered **harmful**.

Six reasons, and they are not all the same kind of argument:

- **Slow.** "I've seen modules grow so large that `terraform plan` takes 20 minutes to run!"
- **Insecure.** To change anything you need permission to touch everything, so everyone ends up an admin. Straight violation of least privilege.
- **Risky.** All eggs, one basket. A typo while touching a staging frontend deletes the production database.
- **Difficult to understand.** And misunderstood infrastructure is where costly mistakes come from.
- **Difficult to review.** The sharpest version of the argument: a several-thousand-line plan does not get read, so *"no one will notice that one little red line that means your database is being deleted."*
- **Difficult to test.** Deferred to Chapter 9.

The analogy is *Clean Code*'s rule for functions — small, then smaller — and the reframing is that a 20,000-line module should read as a code smell exactly the way a 20,000-line function would.

**The worked refactor** splits the `webserver-cluster` module, which by Chapter 5 was doing three unrelated jobs, into three:

| New module | Contents |
| --- | --- |
| `modules/cluster/asg-rolling-deploy` | launch configuration, ASG, both autoscaling schedules, instance security group and its rule, both CloudWatch alarms |
| `modules/networking/alb` | `aws_lb`, listener, ALB security group and both its rules |
| `modules/services/hello-world-app` | target group, listener rule, the DB `terraform_remote_state`, the VPC and subnet data sources — and the other two modules underneath |

The first two are described as "generic, reusable, standalone"; the third is app-specific and composes them.

## 4. Composable modules

The framing is Doug McIlroy's, quoted directly:

> This is the Unix philosophy: Write programs that do one thing and do it well. Write programs to work together.

Then function composition in Ruby — `multiply(add(x, y), sub(x, y))` — and the principle that makes it work: **minimize side effects.** Read state through inputs, write results through outputs. The Terraform translation is three rules:

- pass everything in through input variables,
- return everything through output variables,
- build complicated modules by combining simpler ones.

The mechanics are the four variables added to `asg-rolling-deploy` to un-hardcode it:

```hcl
variable "subnet_ids" {
  description = "The subnet IDs to deploy to"
  type        = list(string)
}

variable "target_group_arns" {
  description = "The ARNs of ELB target groups in which to register Instances"
  type        = list(string)
  default     = []
}

variable "health_check_type" {
  description = "The type of health check to perform. Must be one of: EC2, ELB."
  type        = string
  default     = "EC2"
}

variable "user_data" {
  description = "The User Data script to run in each Instance at boot"
  type        = string
  default     = null
}
```

Each one removes a specific coupling. `subnet_ids` frees the module from the Default VPC. `target_group_arns` and `health_check_type` turn a built-in ALB into an optional integration, so the same ASG works with no load balancer, one ALB, or several NLBs. `user_data` turns a Hello-World deployer into a generic one.

> 💭 (mine): this is the clearest demonstration in the book of what a module boundary *is*. Every variable added here corresponds to a decision moved from the module to the caller, and the defaults (`[]`, `"EC2"`, `null`) are what keep the module usable without them. Compare the abstract version of the rule in [[tf-modules-develop]].

The composition itself, with the naming convention doing real work:

```hcl
module "asg" {
  source = "../../cluster/asg-rolling-deploy"

  cluster_name = "hello-world-${var.environment}"
  ami          = var.ami

  user_data = templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
    server_text = var.server_text
  })

  subnet_ids        = data.aws_subnets.default.ids
  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"
}
```

An `environment` input namespaces every resource (`hello-world-stage`, `hello-world-prod`), and the parent re-exports the children's outputs so callers see one interface. Note `${path.module}` on the template — Chapter 4's first gotcha, applied.

## 5. Testable modules

### The `examples` folder

Modules here are not root modules, so they cannot be applied directly. The chapter's answer is an `examples/` folder, and the argument for it is that one small example does three jobs at once:

- **A manual test harness** — apply and destroy it repeatedly while developing.
- **An automated test harness** — Chapter 9 builds tests on exactly this code.
- **Executable documentation** — teammates can read it, run it, and understand the module without writing anything.

The rule stated as a rule:

> Every Terraform module you have in the `modules` folder should have a corresponding example in the `examples` folder. And every example in the `examples` folder should have a corresponding test in the `test` folder.

```text
modules/
  examples/
    alb/
    asg-rolling-deploy/
      one-instance/
      auto-scaling/
      with-load-balancer/
      custom-tags/
    hello-world-app/
    mysql/
  modules/
    alb/  asg-rolling-deploy/  hello-world-app/  mysql/
  test/
    alb/  asg-rolling-deploy/  hello-world-app/  mysql/
```

And the practice worth stealing, stated plainly:

> A great practice to follow when developing a new module is to **write the example code first**, before you write even a line of module code.

The reason is design, not testing: start with the implementation and you surface with an API nobody wants; start with the example and you design the user experience, then work backwards. The chapter names this a form of TDD.

### Self-validating modules

Two built-in mechanisms in 2022, and this is where the chapter has dated.

**`validation` blocks** (Terraform 0.13+), for checks beyond the type constraint:

```hcl
variable "instance_type" {
  description = "The type of EC2 Instances to run (e.g. t2.micro)"
  type        = string

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Only free tier is allowed: t2.micro | t3.micro."
  }
}
```

`condition` is true when valid; `error_message` is what the user sees. Multiple `validation` blocks per variable are allowed, which the `min_size` example uses for a floor and a ceiling separately.

**`precondition` and `postcondition`** (Terraform 1.2+), inside `lifecycle`, for dynamic checks. The chapter's precondition replaces the hardcoded free-tier list with a live lookup:

```hcl
data "aws_ec2_instance_type" "instance" {
  instance_type = var.instance_type
}

resource "aws_launch_configuration" "example" {
  # ...
  lifecycle {
    create_before_destroy = true

    precondition {
      condition     = data.aws_ec2_instance_type.instance.free_tier_eligible
      error_message = "${var.instance_type} is not part of the AWS Free Tier!"
    }
  }
}
```

And the postcondition asserts a property of what was actually built:

```hcl
lifecycle {
  postcondition {
    condition     = length(self.availability_zones) > 1
    error_message = "You must use more than one AZ for high availability!"
  }
}
```

`self.<ATTRIBUTE>` is legal only in `postcondition`, `connection` and `provisioner` blocks. The reason is mechanical and worth knowing: the normal `aws_autoscaling_group.example.<ATTRIBUTE>` form would be a self-reference and a circular dependency, so `self` exists as the workaround.

!!! danger "The limitation that motivates this whole section is no longer true"
    The chapter's argument for reaching past `validation` is stated as a hard constraint:

    > the `condition` in a `validation` block can only reference the surrounding input variable … you can't use them to do checks across multiple variables (such as "exactly one of these two input variables must be set") or any kind of dynamic checks (such as checking that the AMI the user requested uses the x86_64 architecture).

    **Terraform 1.9.0 (26 June 2024) removed it**, verbatim from the changelog at tag `v1.9.0` in the local checkout:

    > "**Input variable validation rules can refer to other objects**: Previously input variable validation rules could refer only to the variable being validated. Now they are general expressions, similar to those elsewhere in a module, which can refer to other input variables and to other objects such as data resources." ([hashicorp/terraform#34955](https://github.com/hashicorp/terraform/pull/34955))

    **OpenTofu shipped the same thing in 1.9.0** — *"References to vars, data, etc. are now usable in variable validation"* ([opentofu#2216](https://github.com/opentofu/opentofu/pull/2216)) — so this is not an engine divergence. Both, at the same version number, for once.

    The practical consequence is that the chapter's own worked example inverts: the free-tier check against the `aws_ec2_instance_type` data source, which it presents as the thing *only* a precondition can do, is now writable as a `validation` block — and by the chapter's own preference ordering, that is where it belongs, because validations live next to the variable they validate.

    What survives: preconditions and postconditions are still the only option for assertions about **resources and data sources** rather than inputs, and `self` still works only in a postcondition. The three-way table below still has three rows; the boundary between the first two moved.

**When to use which**, as the chapter states it:

| Mechanism | Use for |
| --- | --- |
| `validation` | basic input sanitization, caught before anything is deployed. Preferred where possible, because the check sits with the variable it validates — "a more readable and maintainable API" |
| `precondition` | assumptions that must hold before changes are deployed, including checks on resources and data sources |
| `postcondition` | guarantees about the module's behaviour after changes are deployed, so consumers know it either works or errors |
| automated testing tools | everything else |

The last row deserves its reasoning, because it is the honest limit of in-language checks. The chapter's example: you want to assert that a deployed web service answers HTTP. You could try the `http` provider in a postcondition, but deployments are asynchronous and that provider has **no retry mechanism**, and an internal service may not be reachable from the runner at all. Hence OPA and Terratest in Chapter 9.

!!! info "There is a fourth mechanism now, and it is the one for the HTTP case"
    **`check` blocks** arrived in Terraform **1.5.0**, verified in the local checkout's changelog:

    > "`check` blocks for validating infrastructure: Module and configuration authors can now write independent check blocks within their configuration to validate assertions about their infrastructure."

    Two properties that matter against this chapter. A failed `check` is a **warning, not an error**, so it reports without blocking the apply — which is the right severity for a liveness assertion that may simply be slow. And a check can load a **scoped data source**, referenceable only from inside that block, which is exactly the shape the chapter wants for "make an HTTP request to the thing I just deployed".

    It does not remove the need for Terratest — there is still no retry loop — but the chapter's three-mechanism table is now a four-mechanism one, and the ordering rules are on the `checks-and-conditions` topic backlog together with the `depends_on` trap that scoped data sources hit on a first plan.

## 6. Versioned modules

Two kinds of versioning: **of the module's dependencies**, and **of the module itself**.

### The three dependency types

The chapter's principle first, and it is a good statement of why any of this matters:

> Deployments should be predictable and repeatable: if the code didn't change, then running `apply` should always produce the same result, whether you run it today or three months from now or three years from now.

**Terraform core** — `required_version`. Bare minimum is the major:

```hcl
terraform {
  required_version = ">= 1.0.0, < 2.0.0"
}
```

The chapter then argues for pinning minor and patch too, and is careful about why. Before 1.0 it was *required*, because state written by 0.12.1 could not be read by 0.12.0. After 1.0 the [v1.0 Compatibility Promises](https://developer.hashicorp.com/terraform/language/v1-compatibility-promises) make that unnecessary — but you still do not want workstations and CI drifting onto different features, and new versions have bugs you want to meet in staging.

**Providers** — `required_providers` with a major-version constraint, plus the lock file:

```hcl
terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
```

The explanation of why you *don't* pin minor and patch here is the useful part: since 0.14, `.terraform.lock.hcl` records the exact resolved version and its checksums, so committing the lock file is the pin. Upgrading is a deliberate `init -upgrade` plus a reviewed lock-file diff. The checksum half is a supply-chain control — `init` errors if a checksum changed, and signatures are verified for signed providers.

!!! note "Sidebar — lock files across operating systems"
    `init` records checksums only for the platform it ran on, so a lock file made on Linux fails `init` on a Mac. The fix is to record every platform up front:

    ```bash
    terraform providers lock \
      -platform=windows_amd64 \
      -platform=darwin_amd64 \
      -platform=darwin_arm64 \
      -platform=linux_amd64
    ```

    Still correct on Terraform. **OpenTofu 1.12 does this automatically at `tofu init`**, recording the full cross-platform hash set, which removes the failure mode rather than documenting it ([[ot-dependency-lock]]).

**Modules** — Git tags via `?ref=`, as Chapter 4 established:

```hcl
source = "git@github.com:foo/modules.git//services/hello-world-app?ref=v0.0.5"
```

### Versioning the module itself

Git tags with semantic versioning, then point each environment at a tag and promote:

```bash
git tag -a "v0.0.5" -m "Create new hello-world-app module"
git push --follow-tags
```

The payoff stated: deploy the same version — and therefore the exact same code — to production once staging proves it, and roll back by deploying an older tag.

### The registry

Requirements for the Public Terraform Registry, all four still current (`cache/search/module-repo-naming-convention.md`):

- a **public GitHub repo**,
- named `terraform-<PROVIDER>-<NAME>`,
- following the standard module structure (code in the repo root, a `README.md`, `main.tf`/`variables.tf`/`outputs.tf`),
- **semver Git tags** for releases.

```hcl
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "4.4.0"
}
```

The registry `source` is `<OWNER>/<REPO>/<PROVIDER>` with `version` as a separate argument — which is the reason to prefer it over a Git URL, since the version stops being buried in a query parameter.

!!! note "Two small corrections to this section"
    **The `<PROVIDER>` slot is the provider's real name, not the cloud's.** A module for Azure infrastructure is `terraform-azurerm-<NAME>`, because there is no `hashicorp/azure` provider. HashiCorp's own module-creation tutorial gets this wrong in its naming table (`cache/search/module-repo-naming-convention.md`).

    **"Terraform Cloud" is HCP Terraform** since 2024-04-22. The private-registry capability the chapter describes is unchanged; only the product name moved.

## 7. Beyond Terraform modules

Three escape hatches, with a consistent warning attached.

### Provisioners

`local-exec`, `remote-exec` and `file`, declared in a `provisioner` block. The `remote-exec` walkthrough is deliberately laborious — a security group opening port 22, a `tls_private_key` (with the chapter admitting the key lands in state), an `aws_key_pair`, then `connection`:

```hcl
connection {
  type        = "ssh"
  host        = self.public_ip
  user        = "ubuntu"
  private_key = tls_private_key.example.private_key_pem
}
```

The retry behaviour is worth knowing: `remote-exec` does not know when the instance is ready, so it retries the SSH connection until success or a five-minute default timeout. Semantics: provisioners are **creation-time by default**, running only on initial creation, never on later applies; `when = destroy` moves one to destroy time; multiple provisioners run top to bottom; `on_failure` takes `"continue"` or `"abort"`.

!!! tip "The provisioners-versus-User-Data sidebar is the keeper"
    Brikman's verdict is that User Data usually wins, for three reasons that are all still true:

    - `remote-exec` requires SSH or WinRM access to your servers — more to manage and less secure than User Data, which needs only the AWS API access you already have.
    - **User Data works with ASGs**, so every instance runs it at boot including auto-scaling and auto-recovery launches. "Provisioners take effect only while Terraform is running and don't work with ASGs at all."
    - User Data is visible in the EC2 console and its execution log is on the instance at `/var/log/cloud-init*.log`. Provisioners give you neither.

    The one advantage the other way: User Data is capped at **16 KB**; provisioner scripts are not.

    Deeper treatment of provisioner mechanics — `connection` placement, `self`, the three `remote-exec` script arguments, the `when = destroy` trap, `on_failure` and taint-on-failure — is TID Ch10 §10.3–§10.5 ([[10-advanced-topics]]).

### Provisioners with `null_resource`

Provisioners must live inside a resource, so when there is no natural host, the chapter uses `null_resource` — a resource that creates nothing — plus the `triggers` map to force re-creation:

```hcl
resource "null_resource" "example" {
  # Use UUID to force this null_resource to be recreated on every 'terraform apply'
  triggers = {
    uuid = uuid()
  }

  provisioner "local-exec" {
    command = "echo \"Hello, World from $(uname -smp)\""
  }
}
```

!!! warning "`null_resource` has a built-in replacement, and a supported migration"
    **`terraform_data`** (Terraform 1.4+) does the same job with no provider to install, because it ships in the built-in provider `terraform.io/builtin/terraform` ([[tf-terraform-data]]). Its two stated purposes are exactly the chapter's two uses: storing values that need a managed-resource lifecycle, and **hosting provisioners when there is no logical resource to attach them to**.

    The rename to know: `triggers` becomes **`triggers_replace`**.

    Migration is supported rather than manual — Terraform 1.9 taught the built-in provider to accept `moved` blocks from `null_resource` to `terraform_data` ([hashicorp/terraform#35163](https://github.com/hashicorp/terraform/pull/35163)), so an existing deployment moves without destroy-and-recreate.

    `null_resource` still works; it is a third-party provider you no longer need.

### The `external` data source

The protocol in two lines: Terraform passes `query` to the program as JSON on **stdin**, the program writes JSON to **stdout**, and the result appears at `data.external.<NAME>.result`.

```hcl
data "external" "echo" {
  program = ["bash", "-c", "cat /dev/stdin"]

  query = {
    foo = "bar"
  }
}
```

The caveat is the chapter's own, and it is the right note to end the escape-hatch section on:

> be conservative with your use of external data sources and all of the other Terraform "escape hatches," since they make your code **less portable and more brittle**. For example, the external data source code you just saw relies on Bash, which means you won't be able to deploy that Terraform module from Windows.

## Conclusion — the four-step process

The chapter ends with a procedure, and it is the most directly actionable thing in the book:

1. Walk the production-grade checklist and **explicitly record what you are implementing and what you are skipping**. Combine with the time-estimate table to produce a number for your boss.
2. Create `examples/` and **write the example code first**, designing the API you wish you had, one example per important permutation.
3. Create `modules/` and implement that API as small, composable modules — using Docker, Packer and Bash where they fit — **pinning all three dependency types**.
4. Create `test/` and write automated tests for each example. That is Chapter 9.

### State of the running example

By the end of Ch 8 the single `webserver-cluster` module is gone, replaced by `asg-rolling-deploy` (generic ASG with `subnet_ids`, `target_group_arns`, `health_check_type` and `user_data` inputs, plus `asg_name` and `instance_security_group_id` outputs), `alb` (generic ALB with an `alb_name` input and DNS-name, listener-ARN and security-group-ID outputs), and `hello-world-app` (composes both, adds the target group, listener rule and DB remote state, namespaced by an `environment` input). Live environments consume `hello-world-app` through a versioned Git `?ref=` source, and an `examples/` folder exists as the manual and automated test harness.

---

## Version reckoning

!!! danger "1. `validation` is no longer restricted to its own variable — on either engine"
    Terraform **1.9.0** and OpenTofu **1.9.0** both made validation conditions general expressions that can reference other variables, data sources and resources. The chapter's stated limitation, and therefore its reason for reaching for `precondition` on the free-tier check, is obsolete. Preconditions remain necessary for assertions about resources and data sources; `self` remains postcondition-only.

!!! warning "2. `null_resource` → `terraform_data`, with a supported `moved` path"
    Built-in since 1.4, no provider download, `triggers` renamed `triggers_replace`, and `moved` blocks from `null_resource` accepted since 1.9. ([[tf-terraform-data]])

!!! info "3. `check` blocks are the missing fourth mechanism"
    Terraform **1.5.0**. Warning severity rather than error, and scoped data sources usable only inside the block — the shape the chapter wants for post-deploy liveness assertions, though still without retries.

!!! note "4. Tooling and naming drift"
    - **`tfenv` → `tenv`.** The chapter's version manager, its `.terraform-version` file and its Apple Silicon `TFENV_ARCH=arm64` workaround are all superseded by **tenv**, which manages Terraform, OpenTofu *and* Terragrunt. The `.terraform-version` convention survives. (`tgswitch` for Terragrunt is likewise folded in.)
    - **`aws = "~> 4.0"`** — the AWS provider is on 6.x, three majors on.
    - **Terraform Cloud → HCP Terraform**, renamed 2024-04-22.
    - **`aws_launch_configuration`** is still at the centre of `asg-rolling-deploy`, and accounts created on or after 2024-10-01 cannot create one by any method ([[launch-configurations-eol]]). Substitute `aws_launch_template`.
    - The **Ubuntu 20.04 AMI filter** (`ubuntu-focal-20.04-amd64-server-*`) targets a release whose standard support ended 2025-05-31 — though note the chapter has finally switched from a hardcoded AMI ID to an `aws_ami` data source, which is the right pattern and makes the fix a one-line filter change.
    - **OpenTofu 1.12** records cross-platform provider checksums automatically, removing the need for the `providers lock -platform` sidebar there.

!!! tip "What TUR Ch8 has that nothing else here does"
    Two things, and both are judgement rather than mechanism.

    - **The time estimates and the checklist.** No other source in these notes attempts either. They are the artifact to lift wholesale, and the instruction to *document the skipped items and why* is what turns the checklist from a wish list into a review gate.
    - **Example-code-first as a design practice.** TID Ch9 treats examples as test fixtures ([[09-testing-refactoring]]) and [[tf-modules-develop]] states the composition rules abstractly; only TUR argues that writing the example before the module is how you avoid designing an unusable API, and only TUR insists on the modules/examples/test triple as a structural rule.

    Where it is weakest: the self-validation section is now half-wrong on the language, and the escape-hatch section is thinner than TID Ch10's treatment of the same three tools.

---

*Related notes:* [Modules](../../../topics/modules.md) · [Meta-arguments and `lifecycle`](../../../topics/meta-arguments-lifecycle.md) · TUR Ch4 [Modules](04-reusable-modules.md) and Ch3 [State](03-manage-state.md) · TID Ch10 [[10-advanced-topics]] for provisioners, `terraform_data` and the condition rules · TID Ch9 [[09-testing-refactoring]] for the testing half · [[tf-terraform-data]], [[tf-block-variable]], [[tf-conditionals]], [[tf-modules-develop]], [[tf-modules-publish]] · `cache/search/module-repo-naming-convention.md` for the registry rules. Feeds learning-path **I5** (authoring modules), **A2** (testing and custom conditions), **A1** (provisioners and escape hatches) and **I4** (module versioning).
