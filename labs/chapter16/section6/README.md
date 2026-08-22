# Chapter 16 §6 — `import`, the case lab1 cannot hold

`lab1/` carries section 6's main sequence: a bucket created out of band, a
draft generated with `-generate-config-out`, the defaults trap, and the clean
adoption. This directory holds the one measurement that cannot live there,
because it fails at plan time and would stop the lab from running.

```bash
docker compose -f labs/docker-compose.yml up -d
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"

cd labs/chapter16/section6/id-not-known
tflocal init
tflocal plan
```

## `id-not-known/` — `id` has to resolve at plan time

Nothing is created, so there is nothing to clean up:

```text
Error: Invalid import id argument

  on main.tf line 26, in import:
  26:   id = aws_s3_bucket.source.id

The import block "id" argument depends on resource attributes that cannot be
determined until apply, so Terraform cannot plan to import this resource.
```

Measured on **Terraform 1.15.8**. A variable, a local or `each.value` are all
legal in the same position, because all three resolve before the plan is built.
Another managed resource's attribute does not, because it is
`(known after apply)`.

`internal/terraform/eval_import.go` at that tag carries the identical
diagnostic for `identity`, so this is a rule about importing rather than about
one of the two arguments.
