# Chapter 16 — State management operations

Six configurations, one operation each, in the order the chapter teaches them,
plus `section1/` for the anatomy walkthrough that opens the chapter and
`section3/` for the module-addressing measurements.
Everything here was run end to end on **Terraform 1.15.8** with **AWS provider
6.61.0** against the Floci emulator on 2026-08-21, plus **OpenTofu 1.12.5** for
`opentofu/`. `section3/` is newer, and `lab3/` was re-run to re-verify section 3's
tables, both on 2026-08-22. Every command transcript quoted in chapter 16 comes from these
directories.

| Directory | Operation | Ends up |
|---|---|---|
| `section1/` | the three-stage state anatomy walkthrough: one bucket, then `count`, then `for_each` | applied in stages, see its own README |
| `section3/` | module addressing: `count = 2` on a module call plus a single-instance one, for the parser-disagreement table | applied, see its own README |
| `section4/` | three `moved` edge cases: both addresses declared at once, a module call renamed without a re-`init`, and the `count` auto-move that `for_each` does not get | plan-only; two of the three fail on purpose |
| `lab1/` | `import` a bucket created out of band, with and without `-generate-config-out` | `imports.tf` + a pruned `bucket.tf` |
| `lab2/` | `moved`: a rename, then a `count` → `for_each` migration; also the deletion-versus-rename diff quoted in section 1 | three `moved` blocks, empty plan |
| `lab3/` | `removed` with and without `destroy = false`, then re-import | `main.tf` + `keytest.tf` |
| `lab4/source`, `lab4/dest` | splitting one configuration into two with `removed` + `import` | empty plan on both sides |
| `lab5/` | drift: `plan -refresh-only`, revert, adopt | configuration matching the drifted tag |
| `opentofu/` | OpenTofu's resource-level `lifecycle { destroy = false }` | run with `tofu`, not `terraform` |

Each directory holds the **end state** of its lab, `section1/` included. The intermediate edits — the
bare `removed` block, the minimal `resource` block, the rename without a `moved`
block — are steps the chapter walks you through, and they are all one edit away
from what is committed here.

## Running them

```bash
docker compose -f labs/docker-compose.yml up -d
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"

cd labs/chapter16/lab1
tflocal init
tflocal apply
```

`opentofu/` runs the same way with `TF_CMD=tofu` in front, which `tflocal`
honours by substituting the binary it invokes:

```bash
TF_CMD=tofu tflocal init
TF_CMD=tofu tflocal apply
TF_CMD=tofu tflocal destroy      # forgets the bucket and exits non-zero, on purpose
```

Every lab uses the **AWS provider** rather than `terraform_data`, because the
whole chapter is about adopting, forgetting and re-adopting real remote objects,
and `terraform_data` has no remote object to adopt. S3 is the only service any
of them touches.

## Two local workarounds worth recording

**Terraform ran in a container here.** On this machine the endpoint security
software intercepts the loopback mTLS handshake between Terraform and its
provider plugins, so a direct `tflocal` fails with `Failed to load plugin
schemas`. Every transcript in chapter 16 was produced through
`labs/tf-docker.sh`, which is the documented workaround and changes nothing
about the commands themselves:

```bash
"$(git rev-parse --show-toplevel)/labs/tf-docker.sh" plan -no-color
TF_IMAGE=ghcr.io/opentofu/opentofu:1.12.5 "$(git rev-parse --show-toplevel)/labs/tf-docker.sh" plan
```

See `labs/README.md` for the full explanation, and chapter 1 for how to tell
that failure apart from a slow emulator.

**`awslocal` crashed on this machine**, with `RuntimeError: Could not determine
home directory` from the bundled AWS CLI, which is the failure chapter 1
documents. The out-of-band setup commands were therefore run as plain
`aws --endpoint-url http://localhost:4566 …`, which is exactly what `awslocal`
expands to. The chapter writes `awslocal` because that is what a reader with a
working install should type.

## Cleaning up

```bash
tflocal destroy     # in each lab directory
docker compose -f labs/docker-compose.yml down
```

Run `destroy` deliberately in `lab1/` and `lab3/`. It deletes a bucket Terraform
did not create, which is the chapter's point about what adoption commits you to.
State files, plan files, `.terraform/` directories, the generated
`docker_providers_override.tf` and every `*.backup` are gitignored.
