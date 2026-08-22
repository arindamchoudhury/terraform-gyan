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
