# Terraform Learning Notes

Personal Terraform/OpenTofu study site: a learning path, a written book, reading notes per source, and topic syntheses. Built with [Zensical](https://zensical.org/), published to GitHub Pages.

Content lives in `docs/`. Everything below is about running and checking the site.

## Run it locally

**Docker** — no Python setup, fixed port:

```bash
docker compose up
```

Serves <http://localhost:8000> and live-reloads on edits under `docs/`.

**Python venv** — what the preview launcher uses:

```bash
.venv/Scripts/python.exe serve.py
```

`serve.py` needs `zensical` and `livereload` installed. It listens on `$PORT`, falling back to 8000, because port 8000 is routinely taken by Docker on this machine. `.claude/launch.json` sets `autoPort: true`, so the launcher assigns a free port and passes it through `PORT`.

## `serve.py` is not just a file server

It installs two things a plain `zensical build` does not have:

1. **The `[[slug]]` wikilink resolver.** Notes cross-reference each other by slug alone, so a note can move between course directories without breaking links. `serve.py` scans `docs/` for `<slug>.md` and patches `markdown.extensions.wikilinks.build_url` to resolve against that index. Without the patch, `[[slug]]` renders as literal text.
2. **A debounced rebuild** (5 s of quiet) plus a guard around livereload's file watcher — Docker Desktop's bind mount intermittently raises `OSError: [Errno 5]` from `stat()` on files that are readable on the host, and unguarded that kills the whole polling pass.

## Check for broken links

```bash
python scripts/check_links.py
```

Walks the built site, resolves every internal href against the page that carries it, and exits non-zero if any target is missing. Run it after a clean build:

```bash
python -c "from zensical import build; build('zensical.toml', {'clean': True})"
```

**Why this exists:** Zensical's own `page does not exist` warning covers markdown links (`[text](../other.md)`) but not hrefs produced by the wikilinks extension. A mistyped `[[slug]]` silently falls back to `/sources/<slug>/` and ships as a 404 that no build reports. Three of those were live in the TID chapters before the script existed.

The check is only meaningful against a site built **with** the wikilink resolver — a plain `zensical build` leaves the links as text, so there is nothing to check.

## Publishing

`.github/workflows/deploy.yml` builds on every push to `master` and deploys to GitHub Pages. Two things it does differently from a local build:

- **The nav is trimmed** to `Learning Path` and `Book`. The committed `zensical.toml` keeps the full nav for local use; CI rewrites a copy in its own checkout.
- **It runs plain `zensical build`**, so the wikilink resolver is absent and `[[slug]]` references reach the published pages as literal text.

Those two interact: resolving wikilinks in CI without also publishing their targets would trade literal text for dead links, since most link targets sit in the nav sections CI drops.

## Other scripts

| Script | Purpose |
|---|---|
| `scripts/fetch_page.py` | Fetch a JavaScript-rendered page and cache its text under `cache/web/` |
| `scripts/check_links.py` | Broken-internal-link check over the built site |

`cache/` and `site/` are gitignored scratch.
