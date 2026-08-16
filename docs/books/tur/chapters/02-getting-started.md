# Chapter 2 — Getting Started with Terraform

> *Source: Brikman (2022), **Terraform: Up & Running**, 3rd ed., Chapter 2, pages 39–80.*
>
> The chapter that starts the running example the rest of the book develops. It goes from an empty folder to a load-balanced Auto Scaling Group in eight steps, and it introduces almost every language construct the book uses later: providers, resources, expressions and references, input and output variables, data sources, and one `lifecycle` setting. Brikman's own framing is "in the span of about 40 pages", and the pacing is the point.
>
> 📌 **Notes adapted where version-bound.** Book written 2022 against Terraform ~1.1 and AWS provider 4.19; current stable is **1.15.8** / OpenTofu **1.12.5** ([[version-facts]]), AWS provider **6.x**. The *Terraform* teaching in this chapter has aged well and needs almost no correction. The *AWS* half has aged badly in three separate ways — the account setup, the free tier, and the launch configuration — each flagged inline and collected under [Version reckoning](#version-reckoning).

> 🔗 **See also:** [Core workflow](../../../topics/core-workflow.md) for `init`/`plan`/`apply`/`destroy` across sources, [The dependency graph](../../../topics/dependency-graph.md) for the implicit-dependency material, and [Meta-arguments and `lifecycle`](../../../topics/meta-arguments-lifecycle.md) for `create_before_destroy`.

---

## The shape of the chapter

Eight steps, each one motivated by a limitation of the previous one. Reading the list as a chain is the fastest way to remember what the chapter contains:

| Step | Added because |
| --- | --- |
| Set up an AWS account | Something has to hold the resources |
| Install Terraform | — |
| Deploy a single server | The smallest thing `apply` can create |
| Deploy a single web server | A bare instance serves nothing |
| Deploy a configurable web server | The port was hardcoded in two places |
| Deploy a cluster of web servers | One server is a single point of failure |
| Deploy a load balancer | A cluster has many IPs, users need one |
| Clean up | AWS bills for what you leave running |

Everything Chapter 3 onward does is a repair of something left broken here, so the deliberate gaps matter as much as the content.

## 1. Setting up your AWS account

The security story, compressed:

- You first sign in as the **root user**, which can do anything in the account. The only job Brikman gives it is creating a more limited user, and then switching to that user immediately.
- The limited user comes from **IAM**. A new IAM user has **no permissions at all** until a policy is attached, and an IAM Policy is "a JSON document that defines what a user is or isn't allowed to do." AWS's own predefined ones are **Managed Policies**.
- For the book's examples, attach `AdministratorAccess`, with an explicit footnote assuming you are in an account "dedicated solely to learning and testing".
- Creating the user yields an **Access Key ID** and a **Secret Access Key**, shown once and never again.

!!! warning "This is the most-aged section in the chapter, and AWS now advises against it directly"
    The book's flow is: create an IAM user, tick “Access key - Programmatic access” in the creation wizard, save a long-lived key pair, export it into your shell. All three halves of that have moved.

    **The wizard step is gone.** The current *Create an IAM user* flow has no programmatic-access checkbox. Console access is the optional credential offered at creation; access keys are a separate action taken afterward on an existing user, behind a page that asks you to justify the use case first.

    **AWS states the preference as a requirement-shaped best practice.** From [Manage access keys for IAM users](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html):

    > "As a best practice, use temporary security credentials (such as IAM roles) instead of creating long-term credentials like access keys."

    and from [Create an IAM user in your AWS account](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html):

    > "IAM best practices recommend that you require human users to use federation with an identity provider to access AWS using temporary credentials instead of using IAM users with long-term credentials."

    **What to do instead for these examples.** Either IAM Identity Center with `aws sso login` and an `AWS_PROFILE`, or no AWS account at all — the labs on this site run against a local AWS emulator on `:4566` ([[floci-facts]]), which needs no credentials and cannot generate a bill. The chapter's Terraform content is unaffected by the substitution.

    Worth keeping from the book regardless: **the account you learn in should not be an account you care about.** That is the durable half of the `AdministratorAccess` footnote.

!!! note "Sidebar — the Default VPC"
    Every AWS example in the book deploys into the **Default VPC**, "an isolated area of your AWS account that has its own virtual network and IP address space". Every AWS account created after 2013 has one per region. Delete it and you must either switch regions or recreate it, or else thread a `vpc_id`/`subnet_id` through nearly every example.

    This is why the chapter can get away with never writing a networking resource. It is also why the ALB and the EC2 Instances end up in the same public subnets, which the chapter itself calls out later.

## 2. Installing Terraform

Package manager, or download the ZIP and put the single `terraform` binary on your `PATH`:

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

```bash
choco install terraform
```

Then the credentials, which are ordinary environment variables:

```bash
export AWS_ACCESS_KEY_ID=(your access key id)
export AWS_SECRET_ACCESS_KEY=(your secret access key)
```

The book notes these "apply only to the current shell", so a new terminal needs them again. Full env-var surface is in [[terraform-env-vars]]; installation methods including the official repos are in [[tf-install-cli]].

!!! note "Sidebar — other AWS authentication options"
    Terraform "supports the same authentication mechanisms as all AWS CLI and SDK tools", so `$HOME/.aws/credentials` written by `aws configure` works, and so do **IAM roles** attached to AWS resources. That last one is the escape hatch from the warning above: on an EC2 instance, an ECS task, or a GitHub Actions runner with OIDC, there is no key to store at all.

> 💭 (mine): The PDF's rendering of `terraform`'s usage output is scrambled — the column layout collapses so each command sits beside the *wrong* description (`init` next to "Check whether the configuration is valid"). It is a text-extraction artifact, not a book error. The real primary set is `init`, `validate`, `plan`, `apply`, `destroy`; the full list is [[tf-cli-commands]].

## 3. Deploying a single server

**The language, in three sentences.** Terraform code is **HCL** in `.tf` files. It is declarative: describe what you want, Terraform works out how. It reaches platforms through **providers**, and the first step in any configuration is configuring the ones you use.

```hcl
provider "aws" {
  region = "us-east-2"
}
```

Vocabulary the chapter establishes here and never repeats: a **region** is a separate geographic area (`us-east-2` is Ohio); within it, **Availability Zones** are isolated datacenters (`us-east-2a`, `us-east-2b`). That distinction pays off twice later — subnets live in AZs, and spreading the ASG across them is what makes it survive a datacenter outage.

**Resource syntax**, the shape every later example follows:

```hcl
resource "<PROVIDER>_<TYPE>" "<NAME>" {
  [CONFIG ...]
}
```

`NAME` is an identifier used only inside the Terraform code — it is not the AWS name of anything. That distinction is why the first `apply` produces an instance with no name at all until a `tags` block is added.

```hcl
resource "aws_instance" "example" {
  ami           = "ami-0fb653ca2d3203ac1"
  instance_type = "t2.micro"
}
```

- **`ami`** — an Ubuntu 20.04 image in `us-east-2`. The chapter is upfront that "AMI IDs are different in every AWS region", so changing `region` breaks it.
- **`instance_type`** — `t2.micro`, one vCPU and 1 GB, chosen for the free tier.

!!! tip "Use the docs — the sidebar that is really advice about how to work"
    > "Terraform supports dozens of providers, each of which supports dozens of resources, and each resource has dozens of arguments. There is no way to remember them all."

    Brikman follows it with "I've been using Terraform for years, and I still refer to these docs multiple times per day". Worth keeping because it sets an expectation: fluency in Terraform is fluency in *reading provider documentation*, not in memorising arguments.

### `init`

```bash
terraform init
```

What it is for, in the chapter's words: the `terraform` binary "does not come with the code for any of the providers", so `init` scans the code, works out which providers are used, and downloads them.

- Provider code lands in **`.terraform/`**, Terraform's scratch directory. Gitignore it.
- What was downloaded is recorded in **`.terraform.lock.hcl`**, which **is** committed.
- Run it "anytime you start with new Terraform code", and note that it is **idempotent** — safe to run repeatedly.

!!! warning "The chapter never writes a `required_providers` block, and that is a real gap now"
    Nothing in Chapter 2 constrains the AWS provider version, so `init` resolves whatever the registry currently offers. In 2022 that produced 4.19; today it produces 6.x, across three major versions of breaking changes. HashiCorp's own style guide asks for the constraint explicitly ([[tf-style-guide]]), and it belongs in every configuration from the first one:

    ```hcl
    terraform {
      required_version = ">= 1.5"

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 6.0"
        }
      }
    }
    ```

    The lock file the chapter *does* commit pins the resolved version for everyone who clones the repo, so this is not a reproducibility hole so much as an unstated dependency. Reference: [[provider-requirements]], [[tf-dependency-lock]].

### `plan`

```bash
terraform plan
```

The framing worth keeping is the diff analogy: the output is "similar to the output of the `diff` command", with `+` for create, `-` for delete, `~` for modify in place. Unset values read `(known after apply)`. The footer is the summary line, `Plan: 1 to add, 0 to change, 0 to destroy.`

### `apply`

`apply` shows the same plan and asks for confirmation, which produces the chapter's practical verdict on `plan` as a separate command:

> while `plan` is available as a separate command, it's mainly useful for quick sanity checks and during code reviews … most of the time you'll run `apply` directly and review the plan output it shows you.

Type `yes`, and the resource is created with progress lines every ten seconds.

### The second apply, and where state first appears

Adding a `tags` block and re-applying produces a `~` in-place update rather than a create, and the output opens with `Refreshing state...`. The chapter's explanation is deliberately shallow, because Chapter 3 is the real treatment:

> Terraform keeps track of all the resources it already created for this set of configuration files, so it knows your EC2 Instance already exists … and it can show you a diff between what's currently deployed and what's in your Terraform code.

And it ties that back to Chapter 1's argument: producing a diff at all is a property of a **declarative** language, which a procedural one cannot offer. Full treatment of *why* state exists is [[tf-state-purpose]].

### Version control

```bash
git init
git add main.tf .terraform.lock.hcl
git commit -m "Initial commit"
```

```text
.terraform
*.tfstate
*.tfstate.backup
```

The split is the lesson: **the lock file is committed, the state file is not.** The book defers the reason for the second half to Chapter 3, and the reason for the first to Chapter 8.

## 4. Deploying a single web server

The workload is a one-liner, chosen so the chapter does not have to teach Packer:

```bash
#!/bin/bash
echo "Hello, World" > index.html
nohup busybox httpd -f -p 8080 &
```

`nohup` plus `&` so the server outlives the boot script. It runs through **User Data**, "either a shell script or cloud-init directive" that an EC2 Instance "will execute it during its very first boot".

!!! note "Sidebar — why port 8080 and not 80"
    Listening below 1024 requires root, and a compromised web server would then hand an attacker root. So run unprivileged on a high port, and put a load balancer on 80 in front of it. The chapter delivers the second half at the end of the chapter, which makes the sidebar a setup rather than an aside.

```hcl
resource "aws_instance" "example" {
  ami                    = "ami-0fb653ca2d3203ac1"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p 8080 &
              EOF

  user_data_replace_on_change = true

  tags = {
    Name = "terraform-example"
  }
}
```

Two constructs introduced by that block:

- **Heredoc** `<<-EOF … EOF` for multiline strings without `\n` escapes. The `-` is what strips the leading indentation. Reference: [[tf-expr-strings]].
- **`user_data_replace_on_change = true`**, which exists because of a mismatch between the two systems. Terraform's default is to update in place; User Data only ever runs on first boot. Without the flag, changing the script changes nothing observable, so the flag forces a replacement instead.

### The security group, and the first reference

```hcl
resource "aws_security_group" "instance" {
  name = "terraform-example-instance"

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

By default AWS allows no traffic in or out of an instance. `0.0.0.0/0` is every possible address, which the chapter explains via CIDR notation rather than assuming it.

Attaching the group requires reading a value out of another resource, which is how **expressions** get introduced. An expression is "anything that returns a value"; literals are the simplest kind; a **reference** is the useful kind. Resource attribute references have the form:

```text
<PROVIDER>_<TYPE>.<NAME>.<ATTRIBUTE>
```

so `aws_security_group.instance.id`. `ATTRIBUTE` is either an argument you set or an attribute the resource exports, and the resource's documentation is the only list of which is which. Reference: [[tf-expr-references]].

### Implicit dependencies and the graph

The consequence is the important part:

> When you add a reference from one resource to another, you create an **implicit dependency**. Terraform parses these dependencies, builds a dependency graph from them, and uses that to automatically determine in which order it should create resources.

So the security group is created before the instance, without anyone saying so. And then the payoff sentence for the whole declarative argument:

> When Terraform walks your dependency tree, it creates as many resources in parallel as it can.

```bash
terraform graph
```

The output is **DOT**, rendered with Graphviz or an online equivalent. The chapter's own footnote is the honest caveat: with dozens or hundreds of resources the graphs "become too large and messy to be useful".

!!! info "`terraform graph`'s default output is not what the book shows"
    The book's transcript contains `meta.count-boundary (EachMode fixup)` and `provider.aws (close)` — runtime implementation nodes. Current Terraform's **default** is a simplified graph, described in [[tf-cmd-graph]]:

    > "By default the result is a **simplified graph** which describes only the dependency ordering of the resources (`resource` and `data` blocks) in the configuration."

    The book's shape is now what `-type=plan` (or `plan-refresh-only`, `plan-destroy`, `apply`) produces, and the docs say those types expose "some of the implementation details of the Terraform language runtime". Also note `-draw-cycles`, which highlights cycles in colour and **requires an explicit `-type=`**. Locally verified output and node shapes are on the [dependency graph](../../../topics/dependency-graph.md) topic page.

### Replacement, and immutability

The plan shows `-/+`, and the chapter gives the rule for reading it: `-/+` means replace, and **searching the plan text for `forces replacement` tells you which attribute caused it.** Here it is `user_data`, because of the flag set above.

That is named as an instance of the **immutable infrastructure** paradigm from Chapter 1, with the cost stated plainly: users of the server experience downtime while it is replaced. Zero-downtime deployment is deferred to Chapter 5.

```bash
curl http://<EC2_INSTANCE_PUBLIC_IP>:8080
Hello, World
```

!!! warning "Inline `ingress` blocks are what the book's own Chapter 4 tells you not to write"
    Chapter 4's second gotcha is that a module must use separate rule resources rather than inline blocks, because "an inline block can only be added within the module that creates a resource" while separate resources can be contributed by a caller. The rule holds; the resource named has moved on twice. The AWS provider now steers to `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule` with one CIDR block per rule, and warns against mixing any two of the three styles on the same group ([[dynamic-blocks-facts]]).

    For a root-module example like this one, the inline block is fine. The moment this code becomes a module — which is Chapter 4 — it is not.

!!! note "Sidebar — network security"
    The examples deploy into the Default VPC's **default subnets**, which are all **public** — that is why `curl` from a home machine works at all. The production position, stated once and then relied on for the rest of the book:

    > for production systems, you should deploy all of your servers, and certainly all of your data stores, in **private subnets** … The only servers you should run in public subnets are a small number of reverse proxies and load balancers that you lock down as much as possible.

## 5. Deploying a configurable web server

The motivation is a duplicated `8080` — once in the security group, once in the User Data script. The chapter names the principle rather than just the annoyance, quoting *The Pragmatic Programmer*'s DRY: "every piece of knowledge must have a single, unambiguous, authoritative representation within a system."

### Input variables

```hcl
variable "NAME" {
  [CONFIG ...]
}
```

The five arguments the chapter documents:

| Argument | What it does |
| --- | --- |
| `description` | Documents the variable; shown in `plan`/`apply` prompts, not just in the source |
| `default` | Fallback when no value is supplied; without it, Terraform prompts interactively |
| `type` | Type constraint; absent means `any` |
| `validation` | Custom rules beyond type checking (deferred to Ch 8) |
| `sensitive` | Suppresses the value in `plan`/`apply` logs |

Types listed: `string`, `number`, `bool`, `list`, `map`, `set`, `object`, `tuple`, `any`. Constraints compose — `list(number)`, `map(string)` — and structural types are built with `object({ … })`:

```hcl
variable "object_example" {
  description = "An example of a structural type in Terraform"
  type = object({
    name    = string
    age     = number
    tags    = list(string)
    enabled = bool
  })

  default = {
    name    = "value1"
    age     = 42
    tags    = ["a", "b", "c"]
    enabled = true
  }
}
```

Setting `enabled = "invalid"` fails immediately with `This default value is not compatible with the variable's type constraint: a bool is required.` The chapter's argument for bothering: "It's always a good idea to define a type constraint to catch simple errors."

!!! info "The `variable` block has grown four arguments since the book"
    Verified against the current block reference ([[tf-block-variable]]):

    | Argument | Status |
    | --- | --- |
    | `nullable` | Not in the book. Defaults `true`; `nullable = false` forbids `null`, and a `null` passed to a defaulted variable falls back to the default |
    | `ephemeral` | **v1.10+**. Keeps the value out of state and plan files entirely — the thing `sensitive` never did |
    | `const` | Allows use during early operations such as `init` |
    | `deprecated` | **v1.15+**. A deprecation message for module consumers |

    Two corrections to the book's own five while here. **Bare `list` and `map` are backward-compatibility shorthand** for `list(any)` and `map(any)`; prefer the full form ([[tf-expr-type-constraints]]). And the book's description of `sensitive` is accurate but incomplete in a way that matters: it hides the value from CLI output, and **the value is still written to state in plaintext**. The book does say this eventually, in Chapter 6; `ephemeral` is the argument that actually closes it.

**Supplying a value** — four ways, in the order the chapter presents them:

```bash
terraform apply                          # interactive prompt, shows the description
terraform plan -var "server_port=8080"   # command line
export TF_VAR_server_port=8080           # environment variable
```

…plus `-var-file`, and a `default` in the block itself. Reference: [[tf-input-variables]], [[tut-variables]].

**Reading a value** — `var.<VARIABLE_NAME>`, and inside a string literal, **interpolation**:

```hcl
user_data = <<-EOF
            #!/bin/bash
            echo "Hello, World" > index.html
            nohup busybox httpd -f -p ${var.server_port} &
            EOF
```

That single substitution is the whole point of the section: the port now has one authoritative representation, and the security group and the boot script both derive from it.

### Output variables

```hcl
output "<NAME>" {
  value = <VALUE>
  [CONFIG ...]
}
```

Three optional arguments, and the third is the interesting one:

- **`description`** — documents what the output contains.
- **`sensitive`** — suppresses it at the end of `plan`/`apply`. Note the propagation rule the chapter states: if the output references a `sensitive` input or attribute, marking the output `sensitive` is **required**, not optional, so that exposing a secret is always deliberate.
- **`depends_on`** — the escape hatch for the case references cannot express. The book's example is exactly right: an output returning a server's IP, where the IP is useless until a security group is configured, and no reference links the two.

```hcl
output "public_ip" {
  value       = aws_instance.example.public_ip
  description = "The public IP address of the web server"
}
```

Outputs print after `apply`, and can be read without applying:

```bash
terraform output
terraform output public_ip
```

The scripting use case the chapter suggests — `apply`, then `terraform output public_ip`, then `curl` it as a smoke test — is a good one, with one wrinkle it does not mention.

> 💡 **Tip** — bare `terraform output public_ip` prints the value **with quotes** (`"54.174.13.5"`), which is wrong for shell interpolation; use `terraform output -raw public_ip` for a single value, or `-json` for anything structured ([[tf-cmd-output]]).

## 6. Deploying a cluster of web servers

The motivation is stated in one line: "a single server is a single point of failure." An **Auto Scaling Group** handles launching a cluster, health-checking it, replacing failures, and resizing with load.

### The launch configuration

```hcl
resource "aws_launch_configuration" "example" {
  image_id        = "ami-0fb653ca2d3203ac1"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
              #!/bin/bash
              echo "Hello, World" > index.html
              nohup busybox httpd -f -p ${var.server_port} &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}
```

The migration from `aws_instance` is almost mechanical, and the differences are worth memorising because they are pure friction:

| `aws_instance` | `aws_launch_configuration` |
| --- | --- |
| `ami` | `image_id` |
| `vpc_security_group_ids` | `security_groups` |
| `tags` supported | not supported (tag the ASG instead) |
| `user_data_replace_on_change` | not needed (ASGs launch new instances anyway) |

!!! danger "The book already knew this resource was the wrong one"
    Brikman's own footnote:

    > "These days, you should actually be using a launch template (and the `aws_launch_template` resource) with ASGs rather than a launch configuration. However, I've stuck with the launch configuration in the examples in this book as it is convenient for teaching some of the concepts in the zero-downtime deployment section of Chapter 5."

    That was a pedagogical choice in 2022. It is now a hard blocker, because AWS closed the door ([[launch-configurations-eol]]):

    > As of **January 1, 2023**, new Amazon EC2 instance types are no longer supported in launch configurations.
    >
    > Accounts created on or after **October 1, 2024** cannot create new launch configurations using **any method (console, API, AWS CLI, or CloudFormation)**.

    So the running example from here to Chapter 5 cannot be applied in a recent AWS account. Substitute `aws_launch_template` plus a `launch_template` block on the ASG. Nothing in this chapter's *teaching* depends on the choice.

### `create_before_destroy`

The reason it is there is a genuinely instructive deadlock, and it is the chapter's only `lifecycle` setting:

1. Launch configurations are **immutable**, so any change to one forces a replacement.
2. Terraform's default replacement order is delete-then-create.
3. The ASG holds a reference to the old launch configuration, so the delete cannot happen.

`create_before_destroy = true` inverts the order — create the replacement, repoint references at it, then delete the old one. Reference: [[tf-meta-lifecycle]], [[tut-resource-lifecycle]], and the [meta-arguments](../../../topics/meta-arguments-lifecycle.md) topic page.

> 💭 (mine): this is a better introduction to `create_before_destroy` than a definition would be, because it arrives as the only way out of a deadlock rather than as an option on a list. Chapter 5 then reuses the same setting for zero-downtime deploys, which is why the book kept launch configurations at all.

### The ASG

```hcl
resource "aws_autoscaling_group" "example" {
  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = data.aws_subnets.default.ids

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}
```

`propagate_at_launch` is what pushes the tag onto the instances rather than leaving it on the group.

### Data sources

`vpc_zone_identifier` needs subnet IDs, and hardcoding them "won't be maintainable or portable". Which is the opening for the chapter's last major construct:

> A data source represents a piece of read-only information that is fetched from the provider … every time you run Terraform. Adding a data source to your Terraform configurations does **not create anything new**; it's just a way to query the provider's APIs for data.

```hcl
data "<PROVIDER>_<TYPE>" "<NAME>" {
  [CONFIG ...]
}
```

with reads through `data.<PROVIDER>_<TYPE>.<NAME>.<ATTRIBUTE>` — the resource reference syntax with a `data.` prefix. The arguments are "typically **search filters**", not settings, which is the mental shift that makes data sources click.

```hcl
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
```

Note the chain: the second data source depends on the first, through exactly the same implicit-dependency mechanism as resources. Reference: [[tf-block-data]], [[tf-data-sources]], [[tut-data-sources]].

Spreading instances across subnets is not incidental — "Each subnet lives in an isolated AWS AZ", so multi-subnet placement is what makes the cluster survive a datacenter outage.

## 7. Deploying a load balancer

The problem: a cluster has many IPs and users need one. The chapter's survey of AWS's options:

| Type | Layer | Best for |
| --- | --- | --- |
| **ALB** — Application Load Balancer | L7 | HTTP and HTTPS |
| **NLB** — Network Load Balancer | L4 | TCP, UDP, TLS; scales faster, designed for tens of millions of requests/sec |
| **CLB** — Classic Load Balancer | L4 + L7 | Legacy; predates both, far fewer features |

"Most applications these days should use either the ALB or the NLB", and an HTTP app with no extreme performance requirement gets the ALB.

!!! info "AWS now lists four types, and calls the Classic previous-generation"
    The [Elastic Load Balancing user guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/userguide/what-is-load-balancing.html) names **three current-generation** load balancers — Application, Network, and **Gateway** — and separates the Classic out:

    > "Classic Load Balancers are the previous generation of load balancers from Elastic Load Balancing. We recommend that you migrate to a current generation load balancer."

    The **Gateway Load Balancer** (GWLB) is the one the book omits: an L3 gateway that transparently routes traffic through fleets of third-party virtual appliances — firewalls, intrusion detection, deep packet inspection. It existed in 2022 and simply is not in the chapter, which is a gap rather than a drift.

    The book's ALB-versus-NLB advice is unchanged and still correct.

### The three pieces of an ALB

- **Listener** — listens on a port and protocol.
- **Listener rule** — routes requests matching paths or hostnames to target groups.
- **Target group** — the servers that receive requests; also runs the health checks and only forwards to healthy nodes.

```hcl
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}
```

The ALB is not one server: "AWS automatically scales the number of load balancer servers up and down based on traffic and handles failover", which is why it takes a list of subnets.

```hcl
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  # By default, return a simple 404 page
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}
```

The ALB needs its own security group, because "by default, all AWS resources, including ALBs, don't allow any incoming or outgoing traffic". Inbound 80 so users can reach it; **outbound everything**, so it can run health checks — that second half is the part people forget.

```hcl
resource "aws_lb_target_group" "asg" {
  name     = "terraform-asg-example"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
```

### Wiring the ASG to the target group

The chapter poses this as a question with a wrong answer attached: you *could* attach a static list of instances with `aws_lb_target_group_attachment`, but "with an ASG, Instances can launch or terminate at any time, so a static list won't work". The right answer is the first-class integration:

```hcl
resource "aws_autoscaling_group" "example" {
  # ...
  target_group_arns = [aws_lb_target_group.asg.arn]
  health_check_type = "ELB"
}
```

!!! tip "The `health_check_type = “ELB”` line is the setting worth remembering"
    The default is `"EC2"`, which "considers an Instance unhealthy only if the AWS hypervisor says the VM is completely down or unreachable." `"ELB"` delegates to the target group's HTTP check instead, so instances are replaced when they stop *serving* — out of memory, crashed process, wedged application — not only when they stop existing.

    A running-but-useless server is the common failure. The default does not catch it.

```hcl
resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg.arn
  }
}
```

`public_ip` is then replaced by the ALB's DNS name, since the individual instance IPs stopped being the interesting thing:

```hcl
output "alb_dns_name" {
  value       = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}
```

### The demonstration that earns the chapter

Terminate an instance from the console by hand and keep hitting the ALB URL. Every request still returns 200, because the ALB stops routing to the dead node — and a short time later the ASG notices it is below `min_size` and launches a replacement. The chapter's word for this is **self-healing**, and it is the first thing in the book that could not have been demonstrated with a single `aws_instance`.

## 8. Cleanup

```bash
terraform destroy
```

- No undo. The confirmation prompt is the only guard, and it lists everything first.
- "you should rarely, if ever, run `destroy` in a production environment."
- It uses the same dependency graph in reverse, "using as much parallelism as possible".
- Destroy the *resources*, keep the *code* — later chapters continue this example. That is the IaC payoff stated as a workflow: everything about those resources is in code, so `terraform apply` recreates them.

Reference: [[tf-destroy-resource]] for the three distinct ways an object leaves your infrastructure, of which `destroy` is only one; [[tf-aws-destroy]] for the same step as a tutorial.

## Conclusion

The chapter's own summary is four claims, and each maps onto a section above: the declarative language describes what you want; `plan` catches mistakes before they land; variables, references and dependencies remove duplication and make code configurable; and you have only scratched the surface. Chapter 3 explains how Terraform tracks what it created "and the profound impact that has on how you should structure your Terraform code", which is the sentence that makes Chapter 3 the pivot of the book.

### State of the running example

By the end of Ch 2, one root module in one folder containing: a `provider "aws"` block on `us-east-2`; one input variable `server_port` (number, default 8080); two security groups (`instance` on `var.server_port`, `alb` on 80 in / all out), both with inline rules; two data sources (`aws_vpc.default`, `aws_subnets.default`); an `aws_launch_configuration` with the busybox User Data and `create_before_destroy = true`; an `aws_autoscaling_group` sized 2–10 across the default subnets, ELB-health-checked and registered to a target group; an `aws_lb` plus listener, listener rule and target group; and one output, `alb_dns_name`.

No modules, no remote state, no environments. Chapter 3 adds the backend, Chapter 4 turns all of this into a module.

---

## Version reckoning

Five things to carry forward when reading this chapter against current AWS and current Terraform. Only the first is a blocker.

!!! danger "1. `aws_launch_configuration` — the example cannot be applied in a recent AWS account"
    Accounts created on or after **2024-10-01** cannot create launch configurations by any method, and no instance type released after **2023-01-01** works in one ([[launch-configurations-eol]]). Substitute `aws_launch_template` with a `launch_template` block on the ASG. This affects every chapter from 2 to 5.

!!! warning "2. The AWS account setup is against AWS's own current guidance"
    IAM user plus long-lived access keys plus `AdministratorAccess`, exported into a shell. AWS now recommends federation with temporary credentials for human users, and the console flow no longer offers programmatic access as a creation-time checkbox. Use IAM Identity Center, or run the examples against the local emulator ([[floci-facts]]) and skip the account entirely.

!!! info "3. The free tier the chapter budgets against no longer exists for new accounts"
    The book says the Free Tier "for the first year" covers these examples, with `t2.micro` inside it. AWS restructured on **2025-07-15**:

    - Accounts created **before** that date stay on the legacy program — 12-month trials, short-term trials, and always-free services. The book's assumption holds for them.
    - Accounts created **on or after** it get a **free plan**: $100 in credits at sign-up plus up to $100 more for completing activities, and the plan "expires after 6 months or when you exhaust your credits, whichever comes first."

    Practical effect: a new reader following the chapter today is spending credits with a six-month clock, not consuming a 12-month allowance. `terraform destroy` at the end of each session matters more than it used to. Sources: [AWS Free Tier update](https://aws.amazon.com/blogs/aws/aws-free-tier-update-new-customers-can-get-started-and-explore-aws-with-up-to-200-in-credits/), [Choosing a plan](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html).

!!! note "4. The AMI is doubly stale"
    `ami-0fb653ca2d3203ac1` is an Ubuntu 20.04 image, and it is region-locked to `us-east-2`. **Ubuntu 20.04 LTS reached end of standard support on 31 May 2025** and moved to ESM under Ubuntu Pro (through May 2030). Hardcoded AMI IDs are also eventually deregistered outright. Prefer an `aws_ami` data source with an owner filter, or an SSM public parameter lookup — the chapter has just taught data sources, so the fix is available by the time you need it. Sources: [Ubuntu release cycle](https://ubuntu.com/about/release-cycle), [Ubuntu 20.04 LTS](https://ubuntu.com/20-04).

!!! note "5. Three smaller Terraform-side drifts"
    - **`terraform graph`** now defaults to a simplified resources-only graph; the book's transcript is today's `-type=plan` output ([[tf-cmd-graph]]).
    - **The `variable` block** gained `nullable`, `ephemeral` (1.10+), `const` and `deprecated` (1.15+); bare `list`/`map` are compat shorthand for `list(any)`/`map(any)` ([[tf-block-variable]], [[tf-expr-type-constraints]]).
    - **Inline security-group rules** are now the third-choice style behind `aws_vpc_security_group_ingress_rule` / `aws_vpc_security_group_egress_rule`, and mixing styles on one group causes perpetual diffs ([[dynamic-blocks-facts]]).

!!! tip "What TUR Ch 2 has that the reference sources don't"
    The whole chapter is one worked example where **each construct arrives because the previous version broke**. Variables arrive because a port was duplicated. Data sources arrive because subnet IDs would otherwise be hardcoded. `create_before_destroy` arrives because a replacement deadlocked. Nothing is introduced as an item on a list.

    That is the opposite of TID Ch 2 ([[02-hcl-components]]), which is a systematic tour of block types, and of the HCDocs pages, which are per-construct references. Read TUR for *why each thing exists*, then the references for the arguments TUR never mentions — and note that TUR Ch 2 never covers `required_providers`, `locals`, `count`/`for_each`, or `terraform fmt`/`validate`, all of which a first configuration ought to have.

---

*Related notes:* [Core workflow](../../../topics/core-workflow.md) · [The dependency graph](../../../topics/dependency-graph.md) · [Meta-arguments and `lifecycle`](../../../topics/meta-arguments-lifecycle.md) · [Providers](../../../topics/providers.md) · TID Ch2 [[02-hcl-components]] · TUR Ch4 [Modules](04-reusable-modules.md) · [[tf-block-resource]], [[tf-block-variable]], [[tf-block-output]], [[tf-block-data]], [[tf-meta-lifecycle]] for the block references · [[tf-aws-create]] and [[tf-aws-destroy]] for the same first-deploy loop as a HashiCorp tutorial. Feeds learning-path **B2**, **B3**, **B4**, **B5**, **B6**, **B8** and **I2**.
