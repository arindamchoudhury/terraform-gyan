# Terrakube Docs

Notes from [docs.terrakube.io](https://docs.terrakube.io/). Terrakube (`terrakube-io/terrakube`, **Apache-2.0**) is the nearest open-source shape to HCP Terraform: organizations, workspaces, a private registry, teams, and a **TFE v2-compatible API** that makes the `cloud {}` block and the `remote` backend work against a self-hosted instance.

The docs are captured only where they cover something the source cannot state better. The permission model, the ephemeral executor and the implemented API surface are all **source-derived** in [[terrakube-facts]], read from the local checkout and gated by release tag, because the docs describe them loosely.

**Source type:** official product documentation (GitBook)
**Nav mirrored from:** the rendered docs sidebar, **rung 3** — `fetch_nav.py` resolves it cleanly, with `GETTING STARTED`, `USER GUIDE`, `LEARN` and `API` as the named groups.

## User Guide

| Page | Added | File |
|---|---|---|
| Migrating to Terrakube | 2026-08-18 | [terrakube-migrating](terrakube-migrating.md) |
