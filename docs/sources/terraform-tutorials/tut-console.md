# Develop configuration with the console

> **Source:** [developer.hashicorp.com/terraform/tutorials/state/console](https://developer.hashicorp.com/terraform/tutorials/state/console)
> **Added:** 2026-08-20
> **Source updated:** undated tutorial (~13 min); transcripts show AWS provider v5.14.0 and a bucket stamped `20230831`; captured 2026-08-20
> **Tags:** terraform-console, repl, jsonencode, jsondecode, state-lock, outputs, json, s3-bucket-policy, expressions
> **Type:** documentation

Tenth page of the **State** collection (footer: *Previous — Refresh state · Next — Move resources*), and the last one to capture. Repo: `github.com/hashicorp-education/learn-terraform-console` — a public-read S3 bucket. Needs **Terraform v1.1+**, an AWS account, and the AWS CLI 2.0+, though nothing in the exercise actually invokes `aws`. Carries the same *"may not qualify for the AWS free tier"* warning as [[tut-resource-targeting]] and [[tut-refresh]].

The console appears in [[tut-variables]] as a lookup tool for list indexing and `slice()`. This page uses it for something else: **authoring**. Every expression is tried in the REPL first and pasted into the configuration second.

> The Terraform console is an interpreter that you can use to evaluate Terraform expressions and explore your Terraform project's state. […] The Terraform console command **does not modify your state, configuration files, or resources**. It provides a safe way to interactively inspect your existing project's state and evaluate Terraform expressions before incorporating them into your configuration.

## It reads state, and it locks state

Typing a resource address prints the whole object as the provider last reported it:

```text
$ terraform console
> aws_s3_bucket.data
{
  "acl" = tostring(null)
  "arn" = "arn:aws:s3:::hashilearn-20230831161653870900000001"
  "cors_rule" = tolist([])
  "grant" = toset([
    {
      "permissions" = toset([ "FULL_CONTROL" ])
      "type" = "CanonicalUser"
    },
  ])
  "tags" = tomap(null) /* of string */
  "timeouts" = null /* object */
}
```

Note what the renderings carry. `tostring(null)`, `tolist([])`, `toset([…])`, `tomap(null) /* of string */`, `null /* object */` — the console prints **cty type information alongside the value**, which `terraform show` does not. An empty list and an empty set look identical in most output; here they do not, and that difference decides whether `contains()` or an index works on them. It is the cheapest way to answer "what type is this attribute really?" without reading the provider schema.

!!! warning "The console takes the state lock"
    > The Terraform console **locks your project's state file, so you cannot plan or apply changes while the console is running**. Exit the console with `<Ctrl-D>` or `exit`.

    A read-only command that is nevertheless exclusive. Two practical consequences. A forgotten console session in another terminal is a plausible cause of a lock error on a plan — worth checking before reaching for [[tf-cmd-force-unlock]]. And the try-then-apply loop cannot overlap: exit, apply, reopen.

    Pair this with the gotcha already recorded in **B7**: the console loads configuration **at startup only**, so it does not see edits made while it is open. Between them, the console is a snapshot in both directions — it cannot see your new configuration, and nothing else can write state while it holds the lock.

## Non-interactive: pipe the expression in

```shell
echo 'jsondecode(file("bucket_policy.json"))' | terraform console
```

`terraform console` reads from stdin, so a single expression can be evaluated without a session. That makes it scriptable — usable in a `Makefile` target, or to answer one question in a shell pipeline — and it sidesteps the locking problem, since the process exits immediately.

## The pattern worth taking: decode to author, encode to submit

The real subject of the tutorial. AWS wants an IAM policy as a **JSON string**; you want to write it in HCL so you get syntax checking and interpolation. The page's framing:

> AWS policies are defined as JSON documents. As a result, the `aws_bucket_policy` resource expects policies as a JSON string. **Using HCL to dynamically generate the policy JSON string enables you to leverage HCL's benefits, such as syntax checking and string interpolation.**

Step one — take the vendor's JSON example and turn it into HCL, in the console:

```shell
echo 'jsondecode(file("bucket_policy.json"))' | terraform console
```

```text
{
  "Statement" = [
    {
      "Action" = [ "s3:GetObject", "s3:GetObjectVersion", ]
      "Effect" = "Allow"
      "Principal" = "*"
      "Resource" = [ "<BUCKET_ARN>/*", ]
      "Sid" = "PublicRead"
    },
  ]
  "Version" = "2012-10-17"
}
```

Step two — paste that HCL into a `jsonencode()` call, replacing the placeholder with a real reference:

```hcl
resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.data.id

  policy = jsonencode({
    "Statement" = [
      {
        "Action" = [
          "s3:GetObject",
          "s3:GetObjectVersion",
        ]
        "Effect"    = "Allow"
        "Principal" = "*"
        "Resource" = [
          "${aws_s3_bucket.data.arn}/*",
        ]
        "Sid" = "PublicRead"
      },
    ]
    "Version" = "2012-10-17"
  })
}
```

`<BUCKET_ARN>` becomes `${aws_s3_bucket.data.arn}` — a real dependency edge, which a hand-edited JSON string could never be. The round trip is `jsondecode` once at authoring time, `jsonencode` on every plan.

**The plan renders `jsonencode` structurally**, which is why this is not merely a stylistic preference:

```text
  + policy = jsonencode(
        {
          + Statement = [
              + {
                  + Action    = [ + "s3:GetObject", + "s3:GetObjectVersion", ]
                  + Effect    = "Allow"
                  + Resource  = [ + "arn:aws:s3:::hashilearn-2023.../*", ]
                }
            ]
          + Version   = "2012-10-17"
        }
    )
```

Terraform special-cases `jsonencode` in the diff renderer and expands the structure rather than printing one opaque string. A policy written as a here-doc string would diff as an unreadable blob; this one diffs line by line.

## Verifying an output's shape before committing to it

The same try-then-paste method applied to outputs:

> Systems you integrate with may expect a specific JSON data structure. Use the console to verify that the JSON created matches the required format before you add the output value to your configuration.

```text
> jsonencode({ arn = aws_s3_bucket.data.arn, id = aws_s3_bucket.data.id, region = aws_s3_bucket.data.region })
"{\"arn\":\"arn:aws:s3:::hashilearn-...\",\"id\":\"hashilearn-...\",\"region\":\"us-west-2\"}"
```

The escaping is the console being honest — `jsonencode` returns a **string**, so the console shows it as one.

The nuance is what happens next. Having confirmed the shape, the output is defined as a **plain map**, *not* as `jsonencode(...)`:

```hcl
output "bucket_details" {
  description = "S3 bucket details."
  value = {
    arn    = aws_s3_bucket.data.arn,
    region = aws_s3_bucket.data.region,
    id     = aws_s3_bucket.data.id
  }
}
```

```shell
$ terraform output -json bucket_details
{"arn":"arn:aws:s3:::hashilearn-...","id":"hashilearn-...","region":"us-west-2"}
```

> When you include the `-json` flag in your Terraform output commands, Terraform converts maps and lists to the equivalent JSON data structures.

So `jsonencode` was the **verification** tool, not the implementation. Encoding inside the output would have produced a JSON-string-inside-JSON on `terraform output -json` — doubly escaped and useless to the consumer. Keep the output structured and let `-json` do the conversion at the boundary. Same principle as [[tf-cmd-output]] and [[tf-cli-inspect]]: the machine-readable form is a flag on the command, not a transformation baked into the configuration.

## Incidental: the read-during-apply plan symbol

The first apply shows a symbol that appears nowhere else in the collection:

```text
 <= read (data resources)

  # data.aws_s3_objects.data will be read during apply
  # (config refers to values not yet known)
 <= data "aws_s3_objects" "data" {
```

`<=` marks a data source that cannot be read at plan time because its arguments depend on something not yet created — here, the bucket. Deferred to apply. The page never mentions it.

## Defects and ageing

!!! warning "The page names the wrong function"
    > Finally, it uses the **`jsondecode()`** function to convert the policy back into JSON for use by AWS.

    It uses **`jsonencode()`**, as the configuration block immediately above that sentence shows. The two are exact opposites, and this is the one sentence in the tutorial summarising the whole technique.

    Two smaller ones. The prose calls the resource **`aws_bucket_policy`**; it is `aws_s3_bucket_policy`. And the reviewed `main.tf` excerpt omits `aws_s3_bucket_ownership_controls.data` and `data.aws_s3_objects.data`, both of which appear in the apply transcript and one of which is named in a `depends_on` in the shown code.

!!! note "Version context"
    Transcripts run **AWS provider v5.14.0** and a bucket created `2023-08-31`. The HCP tab contradicts itself: its `terraform.tf` pins `version = "~> 5.14.0"` while the `init` transcript beneath it installs **v4.10.0**.

    Nothing taught here is provider-specific — `console`, `jsonencode`/`jsondecode`, `file()` and `output -json` are all core.

## What it does not cover

- **`terraform console -plan`** and the `-state=` / `-var` options — the console is only ever launched bare.
- **Evaluating against a plan rather than state**, which is the case that matters when a value is `(known after apply)`.
- **`try()` / `can()`** — the two functions the console is most useful for developing, since their whole purpose is surviving an expression that might fail. [[tf-functions]] and [[tf-conditionals]] cover them.
- **Anything about state**, despite its placement in the State collection. Reading state is the console's *input*, not its subject.

---
Related: [[tut-variables]] — the other console exercise; lookup and validation rather than authoring. · [[tf-functions]] — the full built-in list, including `jsonencode`/`jsondecode`/`file`. · [[tf-expressions]] — the language surface the console evaluates. · [[tf-cmd-output]] · [[tf-cli-inspect]] — `-json` as a flag at the boundary, which is why the output stays a map. · [[tf-cmd-force-unlock]] — for when the lock a forgotten console session left behind outlives it. · [[tut-troubleshooting-workflow]] — the `for_each`/splat type confusion the console would have settled in seconds.
