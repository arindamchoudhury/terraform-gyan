# OpenTofu Docs

Notes captured from the official OpenTofu documentation and release blog at [opentofu.org/docs](https://opentofu.org/docs/).

**Source type:** official documentation
**Focus:** OpenTofu-only features that diverge from Terraform's open-source CLI (drives the E3 milestone).
**Nav mirrored from:** rung 3 — the rendered sidebar DOM (Docusaurus). There is no usable global nav payload, so the tree was read **per page** with `fetch_nav.py`; collapsed sections expand only for the page you are on. The `ot-dynamic-prevent-destroy` note comes from the release **blog**, not the docs tree, so it sits outside the sidebar grouping.

## Pages

| Feature | Since | Added | File |
|---|---|---|---|
| Provider `for_each` (multiple provider instances) | OpenTofu 1.9 | 2026-07-03 | [ot-provider-for-each](ot-provider-for-each.md) |
| Early variable evaluation in backend config | OpenTofu 1.8 | 2026-07-03 | [ot-early-eval-backend](ot-early-eval-backend.md) |
| `-exclude` flag (negative targeting) | OpenTofu 1.9 | 2026-07-03 | [ot-exclude-flag](ot-exclude-flag.md) |
| Dynamic `prevent_destroy` | OpenTofu 1.12 | 2026-07-03 | [ot-dynamic-prevent-destroy](ot-dynamic-prevent-destroy.md) |
| Dependency lock file — cross-platform checksums at `init` | OpenTofu 1.12 | 2026-07-10 | [ot-dependency-lock](ot-dependency-lock.md) |
| OpenTelemetry tracing | OpenTofu 1.10 | 2026-08-15 | [ot-otel-tracing](ot-otel-tracing.md) |
| State and plan encryption (`encryption` block, key providers, methods) | OpenTofu 1.7 | 2026-08-19 | [ot-state-encryption](ot-state-encryption.md) |
