# Chapter 16 §5 — `removed`, the case the other labs cannot hold

`lab3/` carries section 5's main sequence: import a bucket, forget it with
`removed` + `lifecycle { destroy = false }`, then take it back with an `import`
block. This directory holds the one measurement that cannot live there, because
it fails at `validate` and would stop the lab from running.

```bash
docker compose -f labs/docker-compose.yml up -d
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"

cd labs/chapter16/section5/removed-key
tflocal init
tflocal validate
```

## `removed-key/` — `from` refuses an instance key

No apply, no emulator resources, nothing to clean up:

```text
Error: Resource instance keys not allowed

  on main.tf line 13, in removed:
  13:   from = aws_s3_bucket.shard["a"]

Resource address must be a resource (e.g. "test_instance.foo"), not a
resource instance (e.g. "test_instance.foo[1]").
```

The `resource` block is commented out in `main.tf` on purpose: `from` has to
name an address configuration no longer declares, so leaving it live would
raise a different error and hide this one.

Measured on **Terraform 1.15.8**. The consequence section 5 draws from it: a
`count` or `for_each` resource is forgotten in full or not at all, where
`import` adopts per instance and `moved` re-keys per instance.

## `opentofu-bare/` — the same bare block, the opposite default

Run with `TF_CMD=tofu`. Apply the file as committed, then replace it with a
bare `removed` block naming `aws_s3_bucket.gone` and plan. OpenTofu **1.12.5**
forgets rather than destroys, and says so twice:

```text
Plan: 0 to add, 0 to change, 0 to destroy, 1 to forget.

Warning: Resource will be removed from the state
After this plan is applied, the resource aws_s3_bucket.gone will not be
managed anymore by OpenTofu.
In case you want to manage the resource again, you will have to import it.

Warning: Missing lifecycle from the removed block
It is recommended for each 'removed' block configured to have also the
'lifecycle' block defined. By not specifying if the resource should be
destroyed or not, could lead to unwanted behavior.
```

Terraform 1.15.8 given the identical block plans `1 to destroy` and warns about
nothing, which is the divergence section 5's danger box now carries. Clean up
with `awslocal s3 rb s3://ch16-otremoved` after the forget, since `tofu
destroy` no longer tracks it.
