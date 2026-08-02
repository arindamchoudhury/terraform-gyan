# Chapter 10 — Meta-arguments: `count`, `for_each`, `depends_on`

## Learning outcomes

By the end you can:

- Say what makes an argument a **meta-argument**, and why that means every provider supports it.
- Create N instances of a block with `count`, and address them with `count.index`.
- Create keyed instances with `for_each`, and address them with `each.key` / `each.value`.
- Explain the difference between a **block address** and an **instance address**, and why a block with neither meta-argument takes no index at all.
- **Predict the plan** when an element is removed from the middle of a `count` list, and prove why the same removal under `for_each` touches exactly one instance.
- **Convert a `count` set to `for_each` with `moved` blocks** and get an empty plan.
- Declare an ordering Terraform cannot infer with `depends_on`, and state the two costs of doing so.
- Multiply on two axes when `count` and `for_each` are both needed, and name the constraint that comes with it.

---

## 1. Two problems, one family of answers

Here is the first problem. You need three S3 buckets that differ only in name.

```hcl
resource "aws_s3_bucket" "assets" { bucket = "example-assets" }
resource "aws_s3_bucket" "logs"   { bucket = "example-logs" }
resource "aws_s3_bucket" "media"  { bucket = "example-media" }
```

That works, and it does not scale. Thirty buckets is thirty blocks. A change to how buckets are configured is thirty edits, and the thirty-first is the one you forget. Nothing in the language so far lets one block stand for many objects.

Here is the second problem, and it looks unrelated. Your application reads from a specific S3 bucket at boot. The bucket name lives in the application's own config file, not in Terraform. Terraform therefore has no idea the server depends on the bucket, will happily create them in parallel, and the server will sometimes boot before the bucket exists.

Both problems are about **how Terraform processes a block**, not about what the block builds. That is exactly what meta-arguments are for.

### What makes an argument "meta"

A normal resource argument comes from the provider. `bucket` exists on `aws_s3_bucket` because the AWS provider defines it. Change providers and the argument vanishes.

A meta-argument comes from Terraform core. HashiCorp's [Meta-arguments](https://developer.hashicorp.com/terraform/language/meta-arguments) page puts it this way: they are "a class of arguments built into the Terraform configuration language that control how Terraform creates and manages your infrastructure."

Two consequences follow, and both matter:

- **Every resource supports them**, regardless of which provider supplies the type. No provider implements `count`; core does.
- **They govern management, not the object.** Lifecycle, ordering, destruction behaviour, instance multiplicity. Never what the infrastructure *is*.

There are six: `count`, `for_each`, `depends_on`, `lifecycle`, `provider`, `providers`. This chapter covers the first three. `lifecycle` gets Chapter 11 to itself. `provider` and `providers` belong with provider configuration in Chapter 17.

!!! note "Meta-arguments are evaluated before almost everything else"
    Terraform builds its dependency graph from your configuration, then walks the graph evaluating expressions. Meta-arguments are an *input* to building that graph, so they are processed before the graph exists.

    That single fact explains a family of restrictions you will meet in this chapter. `count` and `for_each` values must be known before any remote operation. `depends_on` cannot take an arbitrary expression. None of these are arbitrary rules. They all fall out of "the graph has to exist before expressions can be evaluated."

---

## 2. `count` — N instances, addressed by position

`count` takes a whole number and creates that many instances of the block.

```hcl
terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

resource "aws_s3_bucket" "site" {
  count = 3

  bucket = "example-site-${count.index}"
}
```

Inside the block, `count.index` is the zero-based index of this instance. Three buckets, named `example-site-0` through `example-site-2`.

Each instance is a separate object with its own lifecycle. HashiCorp's [`count` reference](https://developer.hashicorp.com/terraform/language/meta-arguments/count) is precise about it: "Each instance has a distinct infrastructure object associated with it, and each is separately created, updated, or destroyed when the configuration is applied."

### Block address versus instance address

This distinction trips up everyone once, and then never again.

| Address | Refers to |
|---|---|
| `aws_s3_bucket.site` | the **block** — all instances, as a collection |
| `aws_s3_bucket.site[0]` | the **first instance** |
| `module.web[2]` | the third instance of a `count`-ed module |

A resource with neither `count` nor `for_each` has no instance address at all. `aws_s3_bucket.notes` *is* the object. Adding `count` to an existing block therefore changes every address it owns, which is the source of a pitfall we will hit shortly.

Both reference pages add the same footnote, and it is easy to skim past: inside nested `provisioner` or `connection` blocks, the special `self` object refers to **the current instance**, not to the block as a whole. Provisioners are Chapter 18, but the rule is worth filing now, because it is the one place where "the block" and "an instance" could plausibly be confused and Terraform resolves it in favour of the instance.

The collection form is directly usable:

```hcl
output "bucket_count" {
  value = length(aws_s3_bucket.site)      # 3 — no index, no splat
}

output "bucket_names" {
  value = aws_s3_bucket.site[*].bucket    # ["example-site-0", ...]
}
```

!!! note "`aws_s3_bucket.site` is a tuple, not a list"
    A `count` block reference evaluates to a **tuple**; a `for_each` one evaluates to an **object**. The documentation frequently calls them a list and a map, and [the types page](https://developer.hashicorp.com/terraform/language/expressions/types) admits the conflation openly.

    It almost never bites, because a tuple converts to a list wherever one is expected. It bites when a lossy conversion is forced, or when you reason from the declared type rather than the observed behaviour. Verified on Terraform 1.15.8.

    Write `[*]`, not the legacy `.*.` form. With the legacy form an index applies to the result of the whole iteration rather than to each element, which is a different operation wearing similar syntax.

### Deriving the count instead of hard-coding it

A literal `count = 3` is the least interesting use. Real configurations derive it.

```hcl
variable "instances_per_subnet" {
  type    = number
  default = 2
}

resource "aws_instance" "app" {
  count = var.instances_per_subnet * length(var.private_subnet_ids)

  ami           = var.ami_id
  instance_type = "t3.micro"
  subnet_id     = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
}
```

Two techniques here are worth stealing.

**The count is a product.** A single `count` value computed from two independent inputs: how many instances you want per subnet, and how many subnets there are. Change either one and the fleet resizes without touching the resource block. Add a subnet elsewhere in the configuration and this block grows on its own.

**Modulo does round-robin placement.** `count.index % length(subnets)` cycles instances across subnets. With two subnets, indices 0, 1, 2, 3 land on subnets 0, 1, 0, 1. This is the canonical answer to "spread N things over M buckets when all I have is an integer index."

Both operands must be known at plan time. `length(var.private_subnet_ids)` qualifies, because it comes from configuration. `length(data.aws_instances.running.ids)` might not, if that data source cannot be read until apply.

### `count` as an on/off switch

Terraform has no boolean "create this or don't." The idiom is a ternary that yields 1 or 0, and the `count` reference endorses it explicitly.

```hcl
variable "enable_logging" {
  type    = bool
  default = false
}

resource "aws_s3_bucket" "audit_log" {
  count = var.enable_logging ? 1 : 0

  bucket = "example-audit-log"
}
```

It works. It also costs you something permanent: the block is now indexed forever. Every reference is `aws_s3_bucket.audit_log[0].arn`, every `moved` block carries the `[0]`, and the resource is a one-element collection rather than an object.

!!! info "OpenTofu — `enabled`, and it is a `lifecycle` argument"
    OpenTofu 1.11 added a first-class on/off switch. It is **not** a seventh top-level meta-argument. It goes inside the `lifecycle` block:

    ```hcl
    resource "terraform_data" "x" {
      input = "hi"

      lifecycle {
        enabled = var.on        # OpenTofu ≥ 1.11 only
      }
    }
    ```

    At the resource top level OpenTofu rejects it with *"An argument named `enabled` is not expected here."* Verified on **OpenTofu 1.12.4**.

    Two differences from the `count` trick, both measured on the same config. The address stays `terraform_data.x` and never gains an index. And a disabled resource evaluates to **`null`** rather than an empty collection, so `terraform_data.x.output` fails loudly with *"Attempt to get attribute from null value"* instead of quietly producing nothing. Guard with `terraform_data.x == null ? … : …`.

    Terraform 1.15.8 has no equivalent anywhere.

---

## 3. The reindex footgun

This is the most important thing in the chapter, and neither reference page states it.

**`count` instances are keyed by position.** The state file remembers `aws_s3_bucket.site[1]`, not "the logs bucket". Position is identity.

So consider three buckets driven by a list:

```hcl
variable "bucket_names" {
  type    = list(string)
  default = ["assets", "logs", "media"]
}

resource "aws_s3_bucket" "site" {
  count = length(var.bucket_names)

  bucket = "ch10-count-${var.bucket_names[count.index]}"
}
```

After apply, state holds:

```
aws_s3_bucket.site[0] -> ch10-count-assets
aws_s3_bucket.site[1] -> ch10-count-logs
aws_s3_bucket.site[2] -> ch10-count-media
```

Now delete `"logs"` from the middle of the list. You asked to remove one bucket. Here is what Terraform actually plans, from the lab at the end of this chapter:

```
Terraform will perform the following actions:

  # aws_s3_bucket.site[1] must be replaced
-/+ resource "aws_s3_bucket" "site" {
      ~ bucket = "ch10-count-logs" -> "ch10-count-media" # forces replacement
        ## ...
    }

  # aws_s3_bucket.site[2] will be destroyed
  # (because index [2] is out of range for count)
  - resource "aws_s3_bucket" "site" {
        ## ...
    }

Plan: 1 to add, 0 to change, 2 to destroy.
```

Read that carefully. **`ch10-count-media` is destroyed and recreated, and you never touched it.**

The reason is mechanical. Index 1 used to mean the logs bucket and now means the media bucket. `bucket` is a forced-new attribute, so index 1 must be replaced to hold a different name. Index 2 no longer exists, so it is destroyed. The list shrank by one; two objects moved.

Three buckets is a toy, and the arithmetic generalises badly. Take thirty buckets at indices 0 through 29 and delete the element at index 3. Indices 0 to 2 are unchanged. Indices 3 through 28 each now hold the name that used to sit one place further along, so **twenty-six instances are replaced**. Index 29 falls out of range and is destroyed. Twenty-seven objects touched, twenty-six of which you never mentioned.

The general rule for a list of length *n* with one element removed at index *i*: **`n - 1 - i` instances are re-planned, plus one destroyed at the end.** Remove from the front and you disturb nearly everything. Remove from the very end and you disturb nothing.

Whether those re-planned instances are *replaced* or merely *updated in place* depends on the attribute the index feeds. Here it is `bucket`, which cannot be changed on a live S3 bucket, so each one is a `-/+` replacement. Feed the index into a mutable attribute instead and the same shift shows up as a `~` update. That is better, and it is still twenty-six resources changed because you deleted one.

!!! danger "This is data loss, not churn"
    "Destroy and recreate" on an S3 bucket means the objects inside it are gone. On an RDS instance it means the database is gone. On an EBS volume it means the disk is gone. Terraform will do it because you told it to, and the plan says so plainly if you read past the summary line.

    The summary line is the trap. `Plan: 1 to add, 0 to change, 2 to destroy` looks like reasonable arithmetic for "I removed one thing" if you are skimming. It isn't.

### `for_each` makes identity a name

Same three buckets, keyed by string:

```hcl
variable "bucket_names" {
  type    = set(string)
  default = ["assets", "logs", "media"]
}

resource "aws_s3_bucket" "site" {
  for_each = var.bucket_names

  bucket = "ch10-foreach-${each.key}"
}
```

State now holds:

```
aws_s3_bucket.site["assets"] -> ch10-foreach-assets
aws_s3_bucket.site["logs"]   -> ch10-foreach-logs
aws_s3_bucket.site["media"]  -> ch10-foreach-media
```

Remove `"logs"` again:

```
Terraform will perform the following actions:

  # aws_s3_bucket.site["logs"] will be destroyed
  # (because key ["logs"] is not in for_each map)
  - resource "aws_s3_bucket" "site" {
        ## ...
    }

Plan: 0 to add, 0 to change, 1 to destroy.
```

One removal, one destroy. `"media"` is untouched, because nothing about `"media"` changed. Its key is still `"media"`.

That contrast is the whole argument, and it is why the rule below is worth memorising rather than deriving each time.

!!! tip "The rule"
    Use **`for_each`** for any set of named or keyed resources. Use **`count`** only for two cases: a simple on/off switch (`? 1 : 0`), or a genuinely index-identical N where no element has a meaningful name.

    If you can say which one you'd be removing by *name*, you want `for_each`.

---

## 4. `for_each` — instances addressed by key

`for_each` takes a collection and creates one instance per element.

```hcl
resource "azurerm_resource_group" "rg" {
  for_each = {
    a_group       = "eastus"
    another_group = "westus2"
  }

  name     = each.key
  location = each.value
}
```

Inside the block you get an `each` object:

- **`each.key`** — the map key, or the set member.
- **`each.value`** — the map value. **For a set, this is the same as `each.key`.**

The map case is where the two earn their keep:

```hcl
locals {
  machines = {
    web    = { type = "t3.nano",  public = true }
    worker = { type = "t3.micro", public = false }
  }
}

resource "aws_instance" "app" {
  for_each = local.machines

  instance_type               = each.value.type
  associate_public_ip_address = each.value.public
  ami                         = var.ami_id

  tags = { Name = each.key }
}
```

| Instance | `each.key` | `each.value` | `each.value.type` |
|---|---|---|---|
| `aws_instance.app["web"]` | `"web"` | `{ type = "t3.nano", public = true }` | `"t3.nano"` |
| `aws_instance.app["worker"]` | `"worker"` | `{ type = "t3.micro", public = false }` | `"t3.micro"` |

The key names the instance. The value carries its settings. That is precisely what `count` cannot express, because an integer index carries no settings.

### What `for_each` actually accepts

The documentation says "a map or a set of strings." That is incomplete in one direction and strict in another, and both halves matter.

!!! warning "Objects are accepted; lists and tuples are not"
    The implementation accepts **map, object, and set of strings**. Braces build an *object*, not a map, so this needs no `tomap()`:

    ```hcl
    for_each = { a = "1", b = "2" }      # fine — this is an object
    ```

    Lists and tuples are rejected outright, deliberately. From the [`for_each` reference](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each): "To prevent unexpected behavior during conversion, the `for_each` argument does not implicitly convert lists or tuples to sets."

    Verified on Terraform 1.15.8:

    ```hcl
    resource "terraform_data" "x" {
      for_each = ["a", "b"]
      input    = each.key
    }
    ```

    ```
    Error: Invalid for_each argument

    The given "for_each" argument value is unsuitable: the "for_each" argument
    must be a map, or set of strings, and you have provided a value of type
    tuple.
    ```

    So `toset(...)` is mandatory for a sequence, not stylistic. Everywhere else in the language a tuple converts to a list freely. `for_each` is the exception.

    Note also that "of strings" binds only to the **set**. A map or object may hold values of any type, because only keys become instance addresses.

`toset` is lossy, by design. It "discards the ordering of the items in the list and removes any duplicate elements", so `toset(["b", "a", "b"])` is a two-element set in no particular order. Both losses are harmless here. Identity comes from the key, so order is meaningless and duplicates would collide anyway.

!!! warning "For a set, `each.key` is the member — not an index"
    A common misreading, repeated in HashiCorp's own `for_each` tutorial, is that `each.key` is the position of the item when the collection is a set. It is not. Verified on Terraform 1.15.8:

    ```hcl
    resource "terraform_data" "x" {
      for_each = toset(["alpha", "beta"])
      input    = "key=${each.key} value=${each.value}"
    }

    output "keys" {
      value = { for k, v in terraform_data.x : k => v.input }
    }
    ```

    ```
    terraform_data.x["beta"]: Creating...
    terraform_data.x["alpha"]: Creation complete after 0s
    terraform_data.x["beta"]: Creation complete after 0s

    keys = {
      "alpha" = "key=alpha value=alpha"
      "beta"  = "key=beta value=beta"
    }
    ```

    The address is `["alpha"]`, `each.key` is `"alpha"`, and `each.key == each.value`. No index appears anywhere. That is the entire reason `for_each` survives a mid-list deletion.

### Three restrictions on keys

Keys are how Terraform names instances, so they are constrained more tightly than ordinary values.

**Keys must be known before any remote operation.** Otherwise you get an error saying `for_each` "has dependencies that cannot be determined before apply", with a suggestion to use `-target`. Treat that suggestion as a diagnostic rather than advice. `-target` is an escape hatch, not a workflow.

**Keys cannot come from impure functions.** `uuid`, `bcrypt`, and `timestamp` are named explicitly, "because Terraform defers evaluating impure functions during the main evaluation step."

**Keys cannot be sensitive.** This one is an error, not a warning, and the reason is worth internalising:

> "Sensitive values are not allowed because Terraform uses the value in `for_each` to identify the resource instance and always discloses it in UI output."

An instance key appears in every plan line, every state address, and every error message. A secret cannot survive that.

Sensitivity is also contagious. The docs put it as "most functions in Terraform return a sensitive result when given an argument with any sensitive content", so `keys(local.config)` comes back sensitive when any *value* in that map is sensitive, even though the keys themselves are not. The documented escape is a `for` expression that touches only the keys:

```hcl
for_each = toset([for k, v in local.config : k])
```

### Chaining one `for_each` into another

Because a `for_each` resource is addressable as a collection, it can drive another block's `for_each` directly.

```hcl
variable "vpcs" {
  type = map(object({ cidr_block = string }))
}

resource "aws_vpc" "example" {
  for_each = var.vpcs

  cidr_block = each.value.cidr_block      # each.value is a var.vpcs element
}

resource "aws_internet_gateway" "example" {
  for_each = aws_vpc.example

  vpc_id = each.value.id                  # each.value is a whole aws_vpc object
}
```

Watch what `each.value` holds in each block. In the first it is an element of `var.vpcs`. In the second it is an entire `aws_vpc` object, attributes and all.

You could get the same keys by writing `for_each = var.vpcs` on both blocks. The docs argue for chaining anyway, and the argument is not brevity:

> "This chain pattern explicitly and concisely declares the relationship between the internet gateway instances and the VPC instances, which tells Terraform to expect the instance keys for both to always change together."

Two blocks that independently iterate the same variable happen to agree. Two chained blocks cannot disagree. That is a real difference the day someone edits one of them.

---

## 5. Converting `count` to `for_each` without destroying anything

You now know `for_each` is the better default. Most existing configurations use `count`. Converting naively destroys everything, because every address changes.

`moved` blocks (Terraform 1.1+) fix this. A `moved` block tells Terraform that an old address and a new address are the same object.

Start here:

```hcl
locals {
  bucket_names = ["assets", "logs", "media"]
}

resource "aws_s3_bucket" "site" {
  count = length(local.bucket_names)

  bucket = "ch10-migrate-${local.bucket_names[count.index]}"
}
```

Convert to this:

```hcl
locals {
  bucket_names = toset(["assets", "logs", "media"])
}

resource "aws_s3_bucket" "site" {
  for_each = local.bucket_names

  bucket = "ch10-migrate-${each.key}"
}

moved {
  from = aws_s3_bucket.site[0]
  to   = aws_s3_bucket.site["assets"]
}

moved {
  from = aws_s3_bucket.site[1]
  to   = aws_s3_bucket.site["logs"]
}

moved {
  from = aws_s3_bucket.site[2]
  to   = aws_s3_bucket.site["media"]
}
```

The bucket names deliberately do not change. The only thing moving is the address. Plan:

```
  # aws_s3_bucket.site[0] has moved to aws_s3_bucket.site["assets"]
  # aws_s3_bucket.site[1] has moved to aws_s3_bucket.site["logs"]
  # aws_s3_bucket.site[2] has moved to aws_s3_bucket.site["media"]

Plan: 0 to add, 0 to change, 0 to destroy.
```

Nothing is created, nothing is destroyed. State is rewritten to the new addresses on apply.

!!! tip "An empty plan is the proof a refactor is safe"
    This generalises well beyond this chapter. Any refactor that is supposed to change only *how the configuration is written* should produce `0 to add, 0 to change, 0 to destroy`. If it doesn't, either the refactor changed something real, or an address moved without a `moved` block to explain it.

    Get the empty plan before you apply. Never the other way round.

!!! note "`moved` blocks are config, and they are disposable"
    They live in `.tf` files and go through review like anything else, which is why they are preferable to `terraform state mv` for a planned refactor. The CLI command does the same job with no plan, no review, and no record.

    Once every environment has applied the move, the blocks can be deleted. Leaving them costs nothing but noise. Chapter 25 covers the full `moved` / `import` / `removed` family.

---

## 6. `depends_on` — the ordering Terraform cannot see

Back to the second problem from the opening.

Terraform derives ordering from **expression references**. If block A uses an attribute of block B, that reference *is* the dependency edge, and Terraform will finish B before starting A. This is the implicit, preferred kind, and it is why the language works at all.

`depends_on` exists for the case where a real dependency leaves no trace in the configuration. HashiCorp's [`depends_on` reference](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on) scopes it precisely: use it "to handle hidden resource or module dependencies that Terraform cannot automatically infer."

!!! tip "The test is one question per pair of resources"
    **Does A depend on B's behaviour while never reading B's data?**

    If yes, there is no edge and you need `depends_on`. If A reads any attribute of B, the edge already exists and you must not add one. Behaviour versus data is the entire distinction.

```hcl
resource "aws_s3_bucket" "app_data" {
  bucket = "example-app-data"
}

resource "aws_instance" "app" {
  ami           = var.ami_id
  instance_type = "t3.micro"

  # The application reads this bucket at boot. The bucket name is baked into
  # the app's own config, so nothing here references the bucket.
  depends_on = [aws_s3_bucket.app_data]
}
```

### The precise semantics

`depends_on` is stronger than "create B before A". Terraform completes **all actions on the dependency object, including read operations**, before performing any action on the dependent one.

On a `module` block it applies to every resource and data source inside that module.

The value is a list of references to resources or child modules in the same calling module, and it cannot be an arbitrary expression. The docs give the reason, and it is the "processed early" rule again:

> "This list cannot include arbitrary expressions because the `depends_on` value must be known before Terraform knows resource relationships and thus before it can safely evaluate expressions."

### The two costs

!!! danger "`depends_on` is a last resort, and it is not free"
    **Cost one: a worse plan.** The docs are blunt. Using it "can cause Terraform to create more conservative plans that replace more resources than necessary. For example, Terraform may treat more values as unknown `(known after apply)` because it is uncertain what changes will occur on the upstream object. This is especially likely when you use `depends_on` for modules."

    An expression reference tells Terraform *which value* the dependency derives from, so it can skip planning changes when that value is unchanged. `depends_on` makes the whole upstream object opaque.

    **Cost two: a slower apply.** Terraform parallelises nodes it believes independent. Every explicit edge you add serialises work that could have run concurrently.

    The first cost is the one usually quoted. The second is the one you feel on every run.

### Nothing will warn you when one is missing

This is the part worth being uncomfortable about.

The graph is built from expression references plus the `depends_on` you wrote. A dependency Terraform cannot see **does not exist** to it. There is nothing absent to report.

Verified on Terraform 1.15.6: deleting a `depends_on` removes the edge from `terraform graph`, and `terraform validate` still reports `Success! The configuration is valid.` No plan warning, no provider warning, no lint rule.

What you get instead of a warning:

- **A race.** Passes locally, fails in CI. Or fails once and succeeds on rerun. That "just run it again" behaviour is the loudest signal available.
- **A provider API error** that never mentions ordering.
- **Success that isn't.** The server boots, the apply reports complete, and the application cannot reach its bucket. A semantic failure with no crash.
- **A broken destroy.** Teardown walks the same graph in reverse, so the missing edge bites again on the way down.

You can see the edges Terraform did build:

```shell
terraform graph                          # DOT, resources and data sources
terraform graph | dot -Tpng > graph.png  # rendered, needs Graphviz
```

Implicit and explicit edges render identically. Use `graph` to *confirm* a suspicion, never to *discover* one. Chapter 30 goes deeper on reading it.

!!! tip "The apply log is a free dependency check"
    Terraform prints `Creating...` for a node the moment it starts work. So **interleaved `Creating...` lines mean Terraform believes those nodes are independent**, and a node that waits has an edge above it.

    ```
    aws_instance.example_a: Creating...
    aws_instance.example_b: Creating...
    ...
    aws_instance.example_b: Creation complete after 32s
    aws_instance.example_a: Creation complete after 33s
    aws_eip.ip: Creating...
    ```

    Both instances start in the same moment, so Terraform sees no edge between them. The Elastic IP does not start until `example_a` is complete, so there is an edge there.

    Note what the log cannot tell you. `example_b` happened to finish first, so this run does not show whether the Elastic IP was also waiting on it. Absence of a wait is only observable when the other node is *still running*. The log is good at confirming edges you expected and at exposing parallelism you did not expect. It is not a substitute for `terraform graph`.

    Destroy prints the mirror image, because teardown walks the same edges in reverse.

---

## 7. When you need both `count` and `for_each`

You cannot use both in the same `resource` or `module` block. That is a flat prohibition in both reference pages, and neither offers a way around it.

There is one, and it is clean: **move the `count` resource into a module, and put `for_each` on the module block.**

```hcl
# modules/app-tier/main.tf — count lives inside
resource "aws_instance" "app" {
  count = var.instance_count

  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_ids[count.index % length(var.subnet_ids)]
}
```

```hcl
# root main.tf — for_each lives outside
module "app_tier" {
  source   = "./modules/app-tier"
  for_each = var.projects

  instance_count = each.value.instances_per_subnet * length(each.value.subnet_ids)
  instance_type  = each.value.instance_type
  subnet_ids     = each.value.subnet_ids
  ami_id         = var.ami_id
}
```

`count` multiplies inside the module. `for_each` multiplies outside. They never share a block. Instances address as `module.app_tier["client-webapp"].aws_instance.app[0]`.

!!! warning "A module with its own provider configuration cannot take `count`, `for_each`, **or** `depends_on`"
    The constraint runs the other way round from how it is usually stated, and it covers all three meta-arguments. Verified on Terraform 1.15.8, with a child module containing `provider "aws" { region = "us-east-1" }`:

    ```
    Error: Module is incompatible with count, for_each, and depends_on

      on main.tf line 3, in module "m":
       3:   for_each = toset(["a", "b"])

    The module at module.m is a legacy module which contains its own local
    provider configurations, and so calls to it may not use the count,
    for_each, or depends_on arguments.
    ```

    Note the error fires at `terraform init`, not at `validate`, because the module has to be installed before Terraform can see inside it.

    An **empty** `provider "aws" {}` block does not trigger this. Terraform reads that as a legacy "proxy provider configuration" and only warns that the syntax is deprecated. It is a *configured* provider block that makes the module legacy.

    So the module-wrapping trick buys multiplication, not multi-provider fan-out. One `for_each` module cannot put each instance in a different region by declaring its own provider. Pass configurations in from the root with `providers = { … }` instead, which is the migration path the error itself recommends. Chapter 17 covers it.

!!! info "OpenTofu — provider iteration is core language there"
    OpenTofu has supported `for_each` on `provider` blocks since 1.9, in ordinary configurations. Terraform supports it too, but only inside a **Stack** configuration, not in root or child modules.

    The divergence is about which configuration surface you have to adopt, not about whether the capability exists. Stacks are Chapter 27.

---

## 8. Where each meta-argument is legal

!!! warning "Treat every applicability list in the docs as a lower bound"
    The block lists in HashiCorp's meta-argument pages disagree with each other, and in one case a page disagrees with itself. Confirmed as of v1.15.x:

    - The **index page** omits `data` from its `count` list while including it for `for_each`. The `count` reference page includes it.
    - The **index page** lists only `resource` for `depends_on`. Its reference page lists six block types.
    - The **`count` page's** own "Supported constructs" list omits `action`, which that page's opening paragraph and one of its use cases both describe.
    - The **`for_each` page's** list omits both `action` and `import`, each of which has its own entry in that page's examples section.

    Working rule: trust the page *body* over the page's own summary list, and check the per-argument page before concluding a meta-argument is illegal somewhere.

Best current understanding, drawn from the per-argument pages and their bodies:

| Meta-argument | Legal in |
|---|---|
| `count` | `data`, `ephemeral`, `module`, `resource`, `action`, plus `list` in query configs |
| `for_each` | `data`, `ephemeral`, `module`, `resource`, `action`, `import`, plus `list` in query configs; in Stacks also `component`, `provider`, `removed` |
| `depends_on` | `check`, `data`, `ephemeral`, `module`, `output`, `resource`; in Stacks also `component` |

Two entries in that table come from page prose rather than from a canonical list, so treat them as the weaker claims. `count` in `action` blocks is described in the `count` page's opening paragraph and in one of its use cases, and appears in no list. `for_each` in `import` blocks is the better-supported of the two: the `for_each` page describes it, and looping imports over a map is a documented 1.7 feature in its own right.

Two rules that hold everywhere:

- `count` and `for_each` are **mutually exclusive** in one block. The error names it directly: "The `count` and `for_each` meta-arguments are mutually-exclusive, only one should be used to be explicit about the number of resources to be created."
- `depends_on` composes with either, with one exception. A child module that declares its own provider configurations accepts **none** of the three, per the warning in section 7.

!!! note "One `depends_on` use case this chapter defers"
    A `data` block nested inside a `check` block runs before the infrastructure it validates exists, so the check fails on the first apply. Adding `depends_on` to that nested `data` block defers the read, and Terraform prints `known after apply` instead of a false warning. Referencing the resource directly would work for ordering but couples the check to the resource's values, which makes it warn on any change at all.

    `check` blocks belong to Chapter 19, where validation is the subject. The pattern is noted here because it is the one place `depends_on` improves signal quality rather than degrading it.

---

## 🧪 Lab: prove the reindex, then migrate away from it

This is the milestone made concrete. You will apply three buckets under `count`, remove the middle one, and read the damage in the plan. Then you will do the same under `for_each` and compare. Finally you will migrate a `count` set to `for_each` with `moved` blocks and confirm an empty plan.

Everything runs against the free local **AWS emulator** from [Chapter 1's lab setup](ch01-iac-fundamentals.md#lab-setup-a-free-local-aws-docker). S3 is on the reliable free surface.

**Start the emulator** (from the repo root; skip if already running):

```shell
docker compose -f labs/docker-compose.yml up -d      # start the emulator on :4566, detached
curl -s http://localhost:4566/_floci/health          # wait until the services read "running"
```

### Part A — `count`, and the collateral damage

The configuration is committed at `labs/chapter10/lab1/count`:

```hcl
# main.tf
terraform {
  required_version = ">= 1.15"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "bucket_names" {
  description = "Buckets to create, in order."
  type        = list(string)
  default     = ["assets", "logs", "media"]
}

resource "aws_s3_bucket" "site" {
  count = length(var.bucket_names)

  bucket = "ch10-count-${var.bucket_names[count.index]}"
}

output "addresses" {
  description = "Instance address -> bucket name."
  value       = { for i, b in aws_s3_bucket.site : "aws_s3_bucket.site[${i}]" => b.bucket }
}
```

Apply it:

```shell
tflocal init
tflocal apply
```

```
aws_s3_bucket.site[0]: Creation complete after 1s [id=ch10-count-assets]
aws_s3_bucket.site[1]: Creation complete after 1s [id=ch10-count-logs]
aws_s3_bucket.site[2]: Creation complete after 1s [id=ch10-count-media]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

addresses = {
  "aws_s3_bucket.site[0]" = "ch10-count-assets"
  "aws_s3_bucket.site[1]" = "ch10-count-logs"
  "aws_s3_bucket.site[2]" = "ch10-count-media"
}
```

Now remove the middle bucket. Do not apply; only plan.

```shell
tflocal plan -var='bucket_names=["assets","media"]'
```

```
Terraform will perform the following actions:

  # aws_s3_bucket.site[1] must be replaced
-/+ resource "aws_s3_bucket" "site" {
      ~ bucket = "ch10-count-logs" -> "ch10-count-media" # forces replacement
        ## ...
    }

  # aws_s3_bucket.site[2] will be destroyed
  # (because index [2] is out of range for count)
  - resource "aws_s3_bucket" "site" {
        ## ...
    }

Plan: 1 to add, 0 to change, 2 to destroy.

Changes to Outputs:
  ~ addresses = {
      ~ "aws_s3_bucket.site[1]" = "ch10-count-logs" -> "ch10-count-media"
      - "aws_s3_bucket.site[2]" = "ch10-count-media"
    }
```

**Answer before moving on:** you removed one bucket. Which two objects does Terraform propose to destroy, and which of them did you never mention?

The output diff gives it away. `aws_s3_bucket.site[1]` is changing from the logs bucket to the media bucket, so the media bucket has to be rebuilt at a new address.

Clean up:

```shell
tflocal destroy
```

### Part B — `for_each`, same removal

Committed at `labs/chapter10/lab1/for-each`. The only real differences are `for_each` over a `set(string)` and `each.key` in place of the index:

```hcl
variable "bucket_names" {
  description = "Buckets to create. Order is irrelevant here."
  type        = set(string)
  default     = ["assets", "logs", "media"]
}

resource "aws_s3_bucket" "site" {
  for_each = var.bucket_names

  bucket = "ch10-foreach-${each.key}"
}
```

```shell
tflocal init
tflocal apply
```

```
aws_s3_bucket.site["assets"]: Creating...
aws_s3_bucket.site["assets"]: Creation complete after 1s [id=ch10-foreach-assets]
aws_s3_bucket.site["media"]: Creation complete after 1s [id=ch10-foreach-media]
aws_s3_bucket.site["logs"]: Creation complete after 1s [id=ch10-foreach-logs]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
```

The completion order is not alphabetical, and that is expected. The three buckets have no edges between them, so Terraform creates them concurrently and they finish in whatever order the API returns. Instance keys are stable; completion order is not.

Same removal:

```shell
tflocal plan -var='bucket_names=["assets","media"]'
```

```
Terraform will perform the following actions:

  # aws_s3_bucket.site["logs"] will be destroyed
  # (because key ["logs"] is not in for_each map)
  - resource "aws_s3_bucket" "site" {
        ## ...
    }

Plan: 0 to add, 0 to change, 1 to destroy.
```

Side by side, one removal from a three-element collection:

| | `count` | `for_each` |
|---|---|---|
| To add | 1 | 0 |
| To change | 0 | 0 |
| To destroy | **2** | **1** |
| Untouched resources affected | 1 | 0 |

Note also the two different reasons Terraform prints. `because index [2] is out of range for count` versus `because key ["logs"] is not in for_each map`. The second names the thing you removed. The first names an index.

Clean up:

```shell
tflocal destroy
```

### Part C — migrate `count` to `for_each` with an empty plan

Committed at `labs/chapter10/lab2`. `main.tf` is the `count` form; `main.tf.after` is the `for_each` form with `moved` blocks. Bucket names are identical across both, so the only thing that moves is the address.

```shell
tflocal init
tflocal apply           # three buckets: ch10-migrate-{assets,logs,media}
```

Now swap in the migrated configuration and plan. Keep a copy of the original first, so you can run the lab again:

```shell
cp main.tf main.tf.before
cp main.tf.after main.tf
tflocal plan
```

Terraform prints one block per moved instance. The resource bodies between them are elided here; every attribute is unchanged:

```
Terraform will perform the following actions:

  # aws_s3_bucket.site[0] has moved to aws_s3_bucket.site["assets"]
    resource "aws_s3_bucket" "site" {
        id                          = "ch10-migrate-assets"
        tags                        = {}
        # (15 unchanged attributes hidden)

        # (4 unchanged blocks hidden)
    }

  # aws_s3_bucket.site[1] has moved to aws_s3_bucket.site["logs"]
    ## ...

  # aws_s3_bucket.site[2] has moved to aws_s3_bucket.site["media"]
    ## ...

Plan: 0 to add, 0 to change, 0 to destroy.
```

That is the milestone. The set is now keyed by name, no object was destroyed, and a future deletion from the middle costs exactly one resource.

Apply it to rewrite the addresses in state, verify, then tear down:

```shell
tflocal apply
terraform state list
```

```
aws_s3_bucket.site["assets"]
aws_s3_bucket.site["logs"]
aws_s3_bucket.site["media"]
```

```shell
tflocal destroy
```

!!! warning "Emulation is not AWS"
    A green apply here proves your HCL and your workflow, not AWS fidelity. The emulator implements API shapes, not every service behaviour, quota, or eventual-consistency wrinkle. Validate anything load-bearing against real free-tier AWS before trusting it.

    The plan arithmetic in this lab is core Terraform behaviour rather than provider behaviour, so it transfers exactly. The bucket internals in the diff do not.

!!! note "If every provider suddenly fails to load"
    On a machine where security software intercepts loopback TLS, every Terraform command that loads a provider can fail with `Failed to load plugin schemas`. That is the plugin mTLS channel being intercepted, not a problem with the provider or the emulator. Exclude `terraform.exe` and `.terraform/providers/**` from the security product's *network/SSL inspection*. As a scoped fallback for one command, `TF_DISABLE_PLUGIN_TLS=1` works, but never set it persistently: it makes the Terraform-to-plugin channel plaintext for every provider, and credentials cross that channel.

---

## Common pitfalls

- **Using `count` for a named set.** The default failure mode of this chapter. If the elements have names, use `for_each`.
- **Renaming a resource block without a `moved` block.** A resource address is its identity in state. Rename `aws_instance.app_a` to `aws_instance.app` and Terraform sees a destroy plus a create, not a rename.
- **Reading only the plan summary line.** `2 to destroy` after removing one item is the signal. The per-resource headers say which objects, and the parenthetical says why.
- **Adding `depends_on` when a reference already exists.** If A reads any attribute of B, the edge is there. A redundant `depends_on` adds the plan-quality cost for nothing.
- **`depends_on` as a safety blanket.** Sprinkling it "just in case" serialises the graph and inflates `(known after apply)`.
- **Passing a list to `for_each`.** It errors. Wrap with `toset()`, and remember that drops order and duplicates.
- **A sensitive value as a `for_each` key.** Also an error. Instance keys are always printed. Project the keys out with a `for` expression.
- **Assuming `each.key` is an index for sets.** It is the member string.
- **Expecting `count`/`for_each` to give per-instance providers.** A module that declares its own provider configurations cannot be called with `count`, `for_each`, or `depends_on` at all. It must take provider configurations from its caller.
- **Using `for_each` to separate environments.** `for_each` is for objects that share a lifecycle, and environments do not share one. Put `dev` and `prod` in one `for_each` and a single `terraform destroy` takes out both. Separate configurations or workspaces are the right tool; Chapter 24 covers the patterns.

---

## Exercises

1. **Recall.** Without looking: what does `each.value` hold when `for_each` is given a set of strings? What about a map of objects?
2. **Predict.** A `count` block manages five instances from a list. You remove the *last* element. How many objects are destroyed, and how many are replaced? Now remove the *first* element instead. Run both and check.
3. **Apply.** Take the Part A configuration and add a fourth bucket at the *end* of the list. Plan it. Explain why this direction is safe when removal from the middle is not.
4. **Apply.** Rename a `for_each` key from `"logs"` to `"audit"` without destroying the bucket. Start from Part B's configuration and notice the trap: `bucket = "ch10-foreach-${each.key}"` derives the bucket *name* from the key, so changing the key changes an attribute that forces replacement, and no `moved` block can save it. Decouple the two first, by giving the map an explicit name per key. Then a `moved { from = ...["logs"], to = ...["audit"] }` is a pure address change and plans clean. The lesson generalises: `moved` fixes addresses, never attributes.
5. **Extend.** Build the module-wrapping pattern from section 7 for real: a local module holding a `count` of buckets, called with `for_each` over two projects. Confirm the resulting addresses with `terraform state list`.
6. **Extend.** Construct a configuration with a genuine hidden dependency, verify with `terraform graph` that no edge exists, add `depends_on`, and confirm the edge appears. Then delete it again and confirm `terraform validate` still passes.

---

## Summary

- **Meta-arguments come from Terraform core**, so every resource supports them regardless of provider. They control how a block is managed, never what it builds.
- **They are processed before the dependency graph exists**, which is why their values must be known ahead of any remote operation.
- **`count` keys instances by position.** Great for an on/off switch and for index-identical N. Dangerous for named sets, because removing an element at index *i* re-plans the `n - 1 - i` instances after it, plus one destroyed at the end. Where the index feeds a forced-new attribute, those are destroy-and-recreate.
- **`for_each` keys instances by string.** Removing one key touches one instance. It accepts maps, objects, and sets of strings, never lists. Keys must be known, pure, and non-sensitive.
- **`moved` blocks convert `count` to `for_each` for free.** An empty plan is the proof the refactor is safe.
- **`depends_on` declares an ordering Terraform cannot infer**, and costs both plan precision and apply parallelism. Prefer an attribute reference wherever one exists. Nothing warns you when one is missing.
- **To multiply on two axes**, put `count` inside a module and `for_each` on the module block. That module must not declare its own provider configurations, or Terraform refuses `count`, `for_each`, and `depends_on` on the call.

---

## What's next

You can now express *how many* of a thing to build and *in what order*. Chapter 11 takes the remaining meta-argument this chapter deferred: **`lifecycle`**. That is where you control what happens when a resource must be replaced, which changes to ignore, what must never be destroyed, and what should be rebuilt when something else changes. It is also the block where the `count = cond ? 1 : 0` idiom meets its OpenTofu replacement.

---

## References

**HashiCorp docs** — [Meta-arguments](https://developer.hashicorp.com/terraform/language/meta-arguments) · [`count`](https://developer.hashicorp.com/terraform/language/meta-arguments/count) · [`for_each`](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) · [`depends_on`](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on) · [Types and values](https://developer.hashicorp.com/terraform/language/expressions/types)

**HashiCorp tutorials** — [Manage similar resources with `count`](https://developer.hashicorp.com/terraform/tutorials/configuration-language/count) · [Manage similar resources with `for_each`](https://developer.hashicorp.com/terraform/tutorials/configuration-language/for-each) · [Create resource dependencies](https://developer.hashicorp.com/terraform/tutorials/configuration-language/dependencies)

**Reading notes** — [[tf-meta-arguments]] · [[tf-meta-count]] · [[tf-meta-for-each]] · [[tf-meta-depends-on]] · [[tut-count]] · [[tut-for-each]] · [[tut-dependencies]] · [[04-expressions-iterations]] (TID Ch 4 §4.8) · [[05-terraform-plan]] (TID Ch 5)

**Topic pages** — [Meta-arguments and `lifecycle`](../topics/meta-arguments-lifecycle.md) · [The dependency graph](../topics/dependency-graph.md)

**Verified facts** — [[conditional-branch-evaluation]] (accepted types, tuple/object shapes) · [[opentofu-enabled-argument]] (OpenTofu `enabled` is a `lifecycle` argument)

**OpenTofu** — [`enabled`](https://opentofu.org/docs/language/meta-arguments/enabled/) (filed under their meta-arguments section, but written inside a `lifecycle` block) · [[ot-provider-for-each]] · [[opentofu-feature-history]]

🧪 **Lab** — [Floci Facts](../research-cache/floci-facts.md) · [MiniStack Facts](../research-cache/ministack-facts.md) · [LocalStack Facts](../research-cache/localstack-facts.md)
