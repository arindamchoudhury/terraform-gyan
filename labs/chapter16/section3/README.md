# Chapter 16 §3 — module addresses, and the parsers that disagree

Two module calls against the same child module: `module.shards` with `count = 2`,
and `module.solo` with no `count`. Six buckets in all. Everything section 3 says
about module paths was measured here on **Terraform 1.15.8** with AWS provider
**6.61.0** against the Floci emulator.

```bash
docker compose -f labs/docker-compose.yml up -d
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"

cd labs/chapter16/section3
tflocal init
tflocal apply
```

## The measurements

A bare module path expands, and the index narrows it:

```shell
terraform state list module.shards          # all four buckets, both instances
terraform state list 'module.shards[0]'     # the two in instance 0
```

A resource spec after an un-indexed multi-instance module path matches nothing,
and each parser says so differently:

```shell
terraform state list 'module.shards.aws_s3_bucket.one'      # Error: Unknown resource
terraform state rm -dry-run 'module.shards.aws_s3_bucket.one'   # Would have removed nothing.
tflocal plan -destroy -target 'module.shards.aws_s3_bucket.one' # No changes.
```

The controls, on the same state:

```shell
terraform state list 'module.shards[0].aws_s3_bucket.one'        # one bucket
terraform state list 'module.solo.aws_s3_bucket.one'             # one bucket, no index needed
tflocal plan -destroy -target 'module.shards[0].aws_s3_bucket.one'  # 1 to destroy
tflocal plan -destroy -target 'module.shards'                       # 4 to destroy
```

`module.solo` is the contrast that matters: omitting the index is fine when the
module call has only one instance, so the failure is about multiple instances,
not about module paths in general.

`state rm -dry-run` is used throughout rather than `state rm`, so the state
survives the walkthrough. Finish with `tflocal destroy`.

## One bare address, four answers

`bare-address/` is the configuration behind section 3's four-row table: two
instances of one resource, then `state list`, `state show`, `plan -target` and
`state rm` each given the bare `aws_s3_bucket.shard`. It has its own README
with the expected output at every step, and its bucket names are unique so it
can be applied alongside everything else here.

## The block address rules

Two more configurations, each measuring what one refactoring block does with an
address that has no instance key. Both were run on **Terraform 1.15.8**.

`import-bare/` is a failing plan. The `to` argument must name an instance when
the target resource uses `count` or `for_each`:

```text
Error: Invalid import 'to' expression

  on main.tf line 15, in import:
  15:   to = aws_s3_bucket.shard

The target resource is using for_each.
```

`moved-bare/` is the opposite. Apply it once with the resource named `old` and
no `moved` block, then rename the resource to `new` and add the block the file
carries. Both instances move, keys intact, with nothing else in the plan:

```text
  # aws_s3_bucket.old["a"] has moved to aws_s3_bucket.new["a"]
  # aws_s3_bucket.old["b"] has moved to aws_s3_bucket.new["b"]
Plan: 0 to add, 0 to change, 0 to destroy.
```

The third block, `removed`, rejects an instance key outright, and that
measurement lives in `../lab3/keytest.tf` where section 5 uses it.
