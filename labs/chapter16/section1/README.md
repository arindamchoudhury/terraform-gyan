# Section 1 — the anatomy walkthrough

The configurations behind section 1's tour of a state entry. Unlike `lab1/`
through `lab5/`, this directory is not one operation; it is three stages you
apply in order, reading `terraform.tfstate` after each one. `main.tf` holds the
last stage, in keeping with the rest of chapter 16.

Run everything through the emulator:

```bash
docker compose -f labs/docker-compose.yml up -d
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"
cd labs/chapter16/section1
tflocal init
```

## Stage 1 — one bucket, one instance, no key

Reduce `main.tf` to this and apply:

```hcl
resource "aws_s3_bucket" "notes" {
  bucket = "ch16-moved-notes"
}
```

```bash
tflocal apply -auto-approve
```

In `terraform.tfstate`, `resources` holds one entry. Its single instance element
carries no `index_key`, because a resource without `count` or `for_each` has
exactly one instance and nothing to distinguish it from.

## Stage 2 — `count`, and keys that are numbers

Add the archive resource and apply again:

```hcl
resource "aws_s3_bucket" "archive" {
  count  = 2
  bucket = "ch16-moved-archive-${count.index}"
}
```

Its entry now holds two instance elements, keyed `0` and `1`. Note the ids:
`ch16-moved-archive-0` and `ch16-moved-archive-1`.

## Stage 3 — `for_each`, and keys that are strings

Replace the archive resource with the `for_each` form and add the two `moved`
blocks, which is what `main.tf` already contains. Apply, and read the last line:

```text
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

Three zeroes. The instance keys are now `"cold"` and `"warm"`, and the ids are
the two you noted in stage 2, unchanged. Two instance elements were rewritten in
state while the buckets themselves were never touched.

Worth seeing once, but the order matters. Make the `for_each` edit **without**
the `moved` blocks and plan it before applying anything:

```text
Plan: 2 to add, 0 to change, 2 to destroy.
```

That is the same edit reading as four operations on real buckets. Add the
`moved` blocks back and the same plan proposes nothing.

Do this at stage 3, while state still holds the `count` keys. Once stage 3 has
been applied, deleting the `moved` blocks changes nothing and Terraform reports
no differences, because the keys in state are already the ones the
configuration asks for. The blocks are a one-time instruction, not a
permanent binding.

## Cleaning up

```bash
tflocal destroy -auto-approve
```

## Provenance

Run end to end on Terraform 1.15.8 with AWS provider 6.61.0 against the Floci
emulator on 2026-08-21, through `labs/tf-docker.sh` for the reason the parent
README explains. The state excerpts quoted in section 1 come from these three
stages, and the field table there is checked against
`internal/states/statefile/version4.go` at tag `v1.15.8`.
