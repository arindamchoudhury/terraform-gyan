# Chapter 16 §8 — drift, and the three answers to it

`main.tf.before` is the configuration Terraform believes in. The committed
`main.tf` is the same file after the drift has been adopted into configuration,
which is the fourth and durable answer.

```bash
docker compose -f labs/docker-compose.yml up -d
source "$(git rev-parse --show-toplevel)/labs/lab-env.sh"

cd labs/chapter16/lab5
cp main.tf main.tf.after && cp main.tf.before main.tf
tflocal init
tflocal apply -auto-approve

awslocal s3api put-bucket-tagging --bucket ch16-drift-site \
  --tagging 'TagSet=[{Key=owner,Value=oncall-hotfix}]'
```

The tag now says `oncall-hotfix` in the emulator and `platform-team` in state.
Everything below is measured on **Terraform 1.15.8**.

## See it

`tflocal plan -refresh-only` reports the past tense, `has changed`, and takes
no action. `tflocal plan` reports the future, `will be updated in-place`, at
`Plan: 0 to add, 1 to change, 0 to destroy`.

## The three answers

| Answer | Command | Result |
|---|---|---|
| Revert | `tflocal apply -auto-approve` | the tag goes back to `platform-team` |
| Adopt into state | `tflocal apply -refresh-only -auto-approve` | `0 added, 0 changed, 0 destroyed`, and `serial` moves 1 → 2 |
| Adopt into configuration | `cp main.tf.after main.tf` then plan | `No changes` |

Read `serial` straight out of the file to see the third column's point, that a
run reporting three zeroes still wrote state:

```shell
python -c "import json;print(json.load(open('terraform.tfstate'))['serial'])"
```

## Two probes worth running while the drift is live

**`state show` does not refresh.** With the tag already changed in the
emulator, `terraform state show aws_s3_bucket.site` still reports
`"owner" = "platform-team"`. The `state` subcommands read the file; only a plan
or apply asks the provider.

**`destroy` refreshes, it just does not report.** Delete the bucket out of band
with `awslocal s3 rb s3://ch16-drift-site`, then:

```text
$ tflocal plan -destroy
No changes. No objects need to be destroyed.

$ tflocal plan -destroy -refresh=false
Plan: 0 to add, 0 to change, 1 to destroy.
```

The first run asked the provider and found the object already gone. The second
skipped the refresh and planned to delete something that no longer exists. Note
that neither prints the `Objects have changed outside of Terraform` note, which
a destroy plan suppresses.

## Section 9 uses this directory too

With the pre-drift configuration applied and no drift, the same bucket carries
section 9's measurements:

```text
$ tflocal plan -replace aws_s3_bucket.site
  # aws_s3_bucket.site will be replaced, as requested
-/+ resource "aws_s3_bucket" "site" {

$ terraform taint aws_s3_bucket.site
Resource instance aws_s3_bucket.site has been marked as tainted.

$ tflocal plan
  # aws_s3_bucket.site is tainted, so must be replaced
Plan: 1 to add, 0 to change, 1 to destroy.

$ terraform untaint aws_s3_bucket.site
Resource instance aws_s3_bucket.site has been successfully untainted.
```

`taint` prints no deprecation warning and exits zero, which is worth seeing for
yourself.

## Cleaning up

`tflocal destroy` from the directory, unless you ran the out-of-band delete
above, in which case there is nothing left to destroy and only the state file
needs removing.
