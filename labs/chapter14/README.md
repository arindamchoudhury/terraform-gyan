# Chapter 14 — Authoring modules

Configurations for the 🧪 Lab in [Chapter 14](../../docs/book/ch14-authoring-modules.md).

Every part runs from the **example** directory, because a reusable module has no
`provider` block and cannot be applied directly. The module sits one level above the
example, so use `-chdir` rather than `cd`:

```bash
cd labs/chapter14/lab1
tflocal -chdir=examples/basic init
tflocal -chdir=examples/basic apply
tflocal -chdir=examples/basic destroy
```

| Directory | Shows |
|---|---|
| `lab1/` | Example written before the module; four resources behind one input; typed outputs, which OpenTofu 1.12.5 rejects |
| `lab2/` | Interface evolution: an object input beside the flat variable it replaces, both `deprecated` warnings, and the error you get validating the module standalone |
| `lab3/` | A one-module-two-buckets configuration split into two child modules behind a shim, with `moved` blocks keeping the consumer's plan empty |

## Reproducing the numbers in the chapter

**lab1** — `apply` reports `Resources: 4 added`. To see the OpenTofu difference, run the
same directory with `tofu`; it fails at `validate` with three `An argument named "type"
is not expected here` errors, one per typed output.

**lab2** — nothing is applied; the whole lab is `validate` and `plan` output. Terraform
reports two warnings at `validate`, OpenTofu one (the variable, not the output); both
report two at `plan`. Validating `modules/hardened-bucket` directly is an error, not a
warning, because a root module has no caller to warn.

**lab3** — the committed `modules/storage/main.tf` is the **finished** shim, with its
`moved` blocks in place. To reproduce the chapter's before-and-after, apply first, then
comment the two `moved` blocks out and plan (`2 to add, 0 to change, 2 to destroy`),
then uncomment and plan again (`0 to add, 0 to change, 0 to destroy`).

Measurements in the chapter were taken on Terraform **1.15.8** and OpenTofu **1.12.5**
against Floci on `:4566`. On a machine where endpoint security breaks the loopback
plugin handshake, run these through `labs/tf-docker.sh` instead of `tflocal` — see
[`labs/README.md`](../README.md).
