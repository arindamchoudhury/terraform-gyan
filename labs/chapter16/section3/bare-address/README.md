# Section 3 — one bare address, four answers

The configuration is two instances of one resource, so `aws_s3_bucket.shard`
without an instance key names a **set of two**. Each command below is given
exactly that address. Measured on **Terraform 1.15.8** with AWS provider
**6.61.0** against the Floci emulator.

```bash
docker compose -f labs/docker-compose.yml up -d
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"

cd labs/chapter16/section3/bare-address
tflocal init
tflocal apply
```

`terraform state list` confirms the starting point:

```text
aws_s3_bucket.shard["a"]
aws_s3_bucket.shard["b"]
```

## 1. `state list` filters to both instances

```shell
terraform state list aws_s3_bucket.shard
```

```text
aws_s3_bucket.shard["a"]
aws_s3_bucket.shard["b"]
```

## 2. `state show` refuses

```shell
terraform state show aws_s3_bucket.shard
```

```text
No instance found for the given address!

This command requires that the address references one specific instance.
To view the available instances, use "terraform state list". Please modify
the address to reference a specific instance.
```

Under OpenTofu the same refusal arrives through the diagnostic renderer, as a
boxed `Error: No instance found for the given address` with no exclamation
mark. Run it with `TF_CMD=tofu tflocal` after a `tofu init` in a fresh copy of
this directory, since a state written by Terraform 1.15.8 is newer than
OpenTofu 1.12.5 will open.

## 3. `-target` takes the whole set

```shell
tflocal plan -destroy -target aws_s3_bucket.shard
```

```text
  # aws_s3_bucket.shard["a"] will be destroyed
  # aws_s3_bucket.shard["b"] will be destroyed
Plan: 0 to add, 0 to change, 2 to destroy.
```

Plan only. Nothing is applied, so the buckets are still there for step 4.

## 4. `state rm` removes both, without asking

`-dry-run` first, which is the preview the command does not otherwise offer:

```shell
terraform state rm -dry-run aws_s3_bucket.shard
```

```text
Would remove aws_s3_bucket.shard["a"]
Would remove aws_s3_bucket.shard["b"]
```

Then the real thing:

```shell
terraform state rm aws_s3_bucket.shard
```

```text
Removed aws_s3_bucket.shard["a"]
Removed aws_s3_bucket.shard["b"]
Successfully removed 2 resource instance(s).
```

No prompt, no plan, and `terraform state list` now prints nothing.

## Cleaning up

Step 4 leaves both buckets running and untracked, which is the point of it, so
`tflocal destroy` has nothing left to destroy. Delete them directly:

```shell
awslocal s3 rb s3://ch16-parsers-a
awslocal s3 rb s3://ch16-parsers-b
```

The other way back is an `import` block per instance, which is section 5's
"Getting back in" and the reason forgetting is reversible only by re-adopting.
Stop after step 3 and `tflocal destroy` works normally.
