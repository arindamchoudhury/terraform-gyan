# Chapter 16 §7 — what `state pull` hands you

`terraform state pull` does not print the bytes the backend holds. It
*"upgrades the local copy to the latest state file version that is compatible
with locally-installed Terraform"* on the way out, which matters when the file
you are backing up before a split was written by an older CLI.

No emulator, no provider, no `init`. The input is committed as
`state-1.9.0.json` because `terraform.tfstate*` is gitignored:

```shell
cp state-1.9.0.json terraform.tfstate
terraform state pull
```

Measured on **Terraform 1.15.8**:

```json
{
  "version": 4,
  "terraform_version": "1.15.8",
  "serial": 7,
  "lineage": "1f2e3d4c-5b6a-7980-1234-56789abcdef0",
  "outputs": {},
  "resources": [],
  "check_results": null
}
```

`terraform_version` is rewritten from `1.9.0`, and `check_results` is
materialised where the input had no such key. `serial` and `lineage` come
through untouched, which is what keeps the pull-edit-push loop legal.

Delete `terraform.tfstate` when you are done, so the file does not sit in the
working tree pretending to be real state.
