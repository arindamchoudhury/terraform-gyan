# Terraform 1.15 & OpenTofu 1.12 — new features (for learning-path coverage)

**Checked:** 2026-07-04

## Terraform 1.15 (released 2026-04-29)

- **Dynamic module sources** — the headline language change. `module` blocks can now use variables in the `source` and `version` attributes; previously these had to be string literals, forcing duplicated module blocks to point environments at different registries/pins. Comes with a new **`const` variable attribute** (`const = true`) marking a variable as usable during `terraform init` (module source resolution happens at init, so any variable feeding a module source must be const). → topic **I4** (using modules), relevant to **E4** (repo architecture / DRY).
- **Variable & output deprecation** — add `deprecated = "message"` to a `variable` or `output` block; a warning fires during `terraform validate` whenever a caller references it. A module-API lifecycle tool. → topic **I5** (authoring modules), **A8** (refactoring at scale).
- **`convert` function** — new built-in for precise inline type conversion, e.g. `convert(var.x, list(string))`. **Terraform-only — OpenTofu has no `convert()`** (open request [opentofu #2630](https://github.com/opentofu/opentofu/issues/2630); conflicts with OpenTofu's dependency analysis). Portable code uses the `toType` casters. → topic **B7** (functions). *(verified 2026-07-11)*
- **Output `type` attribute** — `output` blocks now accept a `type` constraint, same validation/documentation capability variables have had. → topic **B6** (outputs).
- **Test framework:** functions can now be used inside `mock_data` and `override_resource` blocks (generate GUIDs/IDs dynamically in test doubles). → topic **A2** (testing).
- **S3 backend** supports credentials from `aws login` (AWS CLI v2.32.0+), no long-term access keys needed in that path. → topic **I6** / **A6**.
- **Windows ARM64** native builds. → topic **B2** (install), trivial.

Sources: [HashiCorp — New in Terraform 1.15](https://www.hashicorp.com/en/blog/new-in-terraform-115-dynamic-sources-variable-deprecation-and-more), [InfoQ — Terraform 1.15](https://www.infoq.com/news/2026/06/terraform-1-15/), [Terraform CHANGELOG](https://github.com/hashicorp/terraform/blob/main/CHANGELOG.md).

## OpenTofu 1.12 (1.12.0 released 2026-05-14; current 1.12.3)

- **Dynamic `prevent_destroy`** — bind `lifecycle.prevent_destroy` to a variable/expression (Terraform requires a literal). OpenTofu-only. → already covered in **E3** + [[ot-dynamic-prevent-destroy]].
- **`destroy = false` lifecycle meta-argument** — remove an object from state **without** destroying the remote object; a simpler alternative to the old `terraform state rm` / `removed`-block workarounds. OpenTofu-only. → topic **I7** (state ops), **I2** (lifecycle). Contrast: Terraform's `removed` block also drops from state without destroying, but is a separate top-level block, not a lifecycle arg.
- **`-json-into=FILENAME`** — writes the machine-readable JSON stream to a file while leaving the normal human UI on stdout (vs `-json`, which replaces stdout). Good for CI that wants both. OpenTofu-only. → topic **A3** (CI/CD).
- **Concurrent provider installation** — parallel provider downloads for a faster `tofu init`. → topic **E5** (performance), trivial.

Sources: [OpenTofu 1.12.0 blog](https://opentofu.org/blog/opentofu-1-12-0/), [What's new in OpenTofu](https://opentofu.org/docs/intro/whats-new/), [OpenTofu CHANGELOG v1.12.3](https://github.com/opentofu/opentofu/blob/v1.12.3/CHANGELOG.md).
