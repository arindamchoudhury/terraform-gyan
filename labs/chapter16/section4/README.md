# Chapter 16 §4 — `moved`, six edge cases

Six small configurations, one behaviour each, behind the measurements in
section 4. All were run on **Terraform 1.15.8** with AWS provider **6.61.0**
against the Floci emulator.

Four of them are the *end* of an edit: the committed file is what you plan
**after** making a change to something already applied. Each section below
gives the starting file, so nothing has to be guessed.

```bash
docker compose -f labs/docker-compose.yml up -d
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"

cd labs/chapter16/section4/<directory>
tflocal init
```

Two of the six never reach an apply, because they fail at validation. Those are
marked. Finish any directory that did apply with `tflocal destroy`.

---

## `static-refs/` — `from` and `to` take references, not strings

No apply needed. `tflocal validate` is enough:

```shell
tflocal validate
```

```text
Error: Invalid expression

A single static variable reference is required: only attribute access and
indexing with constant keys. No calculations, function calls, template
expressions, etc are allowed here.
```

For the second half of the same rule, add a `for_each` to the `moved` block and
validate again:

```hcl
moved {
  for_each = toset(["x", "y"])
  from     = aws_s3_bucket.a[each.key]
  to       = aws_s3_bucket.b[each.key]
}
```

```text
Error: Unsupported argument
An argument named "for_each" is not expected here.
```

That is why a multi-instance migration needs one block written out per
instance, where an `import` block can be generated from a `for_each`.

## `both-declared/` — the old and new resource never coexist

No apply needed; it fails before a plan exists.

```shell
tflocal plan
```

```text
Error: Moved object still exists

This statement declares a move from aws_s3_bucket.single, but that resource
is still declared at main.tf:9,1.

Change your configuration so that this resource will be declared as
aws_s3_bucket.other instead.
```

Delete the `single` block and the plan runs: the rename **is** the edit to the
label, not an addition beside it.

## `flipped/` — a backwards block is caught, not destructive

Start from this, and apply it:

```hcl
resource "aws_s3_bucket" "notes" {
  bucket = "ch16-flip"
}
```

Then replace the file with the committed one, which renames the label to
`team_notes` and adds a `moved` block with the arguments the wrong way round.
Plan:

```text
Error: Moved object still exists

This statement declares a move from aws_s3_bucket.team_notes, but that
resource is still declared at main.tf:14,1.
```

`from` has to name an address configuration no longer declares. After a rename
that is the old label. Swap the two arguments and the same plan comes out
`0 to add, 0 to change, 0 to destroy`.

## `auto-move/` — `count` gets an automatic move, `for_each` does not

Apply the committed file as written, one bare bucket. Then make two edits in
turn, keeping the bucket name identical each time and writing **no** `moved`
block.

First, add `count = 1`:

```hcl
resource "aws_s3_bucket" "a" {
  count  = 1
  bucket = "ch16-automove"
}
```

```text
  # aws_s3_bucket.a has moved to aws_s3_bucket.a[0]
Plan: 0 to add, 0 to change, 0 to destroy.
```

Then swap `count` for a `for_each`:

```hcl
resource "aws_s3_bucket" "a" {
  for_each = toset(["small"])
  bucket   = "ch16-automove"
}
```

```text
  # aws_s3_bucket.a will be destroyed
  # aws_s3_bucket.a["small"] will be created
Plan: 1 to add, 0 to change, 1 to destroy.
```

Terraform proposes the `count` move itself because instance `0` is the only
answer available. A `for_each` key is a choice, so it will not guess one.

## `chained/` — two hops collapse into one

Start from this, and apply it:

```hcl
resource "aws_s3_bucket" "a" {
  bucket = "ch16-chain"
}
```

Then replace the file with the committed one, which declares `c` and carries
both `a → b` and `b → c`. Plan:

```text
  # aws_s3_bucket.a has moved to aws_s3_bucket.c
Plan: 0 to add, 0 to change, 0 to destroy.
```

`b` never appears. For the failure mode, replace both blocks with a pair that
point at each other and plan again:

```hcl
moved {
  from = aws_s3_bucket.d
  to   = aws_s3_bucket.e
}

moved {
  from = aws_s3_bucket.e
  to   = aws_s3_bucket.d
}
```

```text
Error: Cyclic dependency in move statements

A chain of move statements must end with an address that doesn't appear in
any other statements, and which typically also refers to an object still
declared in the configuration.
```

## `module-rename/` — renaming a module call needs a re-`init`

Start from this, and apply it. The child module is committed at `mod/`:

```hcl
module "solo" {
  source = "./mod"
  suffix = "checks"
}
```

Then replace the file with the committed one, which renames the call to `only`
and adds the `moved` block. Plan **without** re-initialising:

```text
Error: Module not installed

This module is not yet installed. Run "terraform init" to install all modules
required by this configuration.
```

The reason is visible in `.terraform/modules/modules.json`, which still reads
`{"Key":"solo","Source":"./mod","Dir":"mod"}`. The install record is keyed by
the call name, and nothing is installed under the new one. Nothing is
downloaded here either, so this applies to a local `./mod` source as much as to
a registry module. Run `tflocal init`, then plan again:

```text
  # module.solo.aws_s3_bucket.one has moved to module.only.aws_s3_bucket.one
  # module.solo.aws_s3_bucket.two has moved to module.only.aws_s3_bucket.two
Plan: 0 to add, 0 to change, 0 to destroy.
```

---

## Cleaning up

`static-refs/` and `both-declared/` never applied anything. For the rest,
`tflocal destroy` from the directory removes what they created. If you stopped
mid-sequence with an edit that has not been applied, restore the starting file
first so `destroy` can see the objects state is tracking.
