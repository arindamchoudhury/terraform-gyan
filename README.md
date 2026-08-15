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

## Building for a reader

**A bare `zensical build` does not resolve `[[slug]]` references** — it leaves them as literal text. The resolver lives in `scripts/wikilinks.py`, not in `zensical.toml`, because Zensical pickles `mdx_configs` to hash them and a function is not picklable. Anything whose output a person will read goes through:

```bash
python scripts/build_site.py [--clean]
```

That installs the resolver, builds, and **exits non-zero if any `[[slug]]` matched no page**. Both `serve.py` and the deploy workflow use it, so the published site and the local preview render links identically. Keep `zensical build` for throwaway checks only.

Slug resolution has two outcomes:

| `[[slug]]` | Renders as |
|---|---|
| a `<slug>.md` exists anywhere under `docs/` | `<a class="wikilink">` pointing at that page |
| nothing matches (typo, or a topic page still on the backlog) | `<span class="wikilink-missing">` — plain text, and the build fails |

The plain-text fallback is deliberate: the stock extension always emits an anchor, so a mistyped slug used to ship as a silent 404 pointing at `/sources/<slug>/`.

## `serve.py` is not just a file server

Beyond installing the resolver, it adds **a debounced rebuild** (5 s of quiet, and the slug index refreshes each time so new notes resolve without a restart) plus a **guard around livereload's file watcher** — Docker Desktop's bind mount intermittently raises `OSError: [Errno 5]` from `stat()` on files that are readable on the host, and unguarded that kills the whole polling pass.

## Check for broken links

```bash
python scripts/check_links.py
```

Walks the built site, resolves every internal href against the page that carries it, and exits non-zero if any target is missing. Run it after a clean build:

```bash
python -c "from zensical import build; build('zensical.toml', {'clean': True})"
```

**Why this exists:** Zensical's own `page does not exist` warning covers markdown links (`[text](../other.md)`) but not hrefs produced by the wikilinks extension. Three dead wikilinks were live in the TID chapters before the script existed. `build_site.py` now catches unresolvable slugs at build time, so this script is the backstop for the other half — links whose target *slug* exists but whose *page* does not.

Run it against output built by `build_site.py`; a plain `zensical build` leaves the links as text, so there is nothing to check.

## Check the Markdown source

```bash
python scripts/check_markdown.py --commits origin/master..HEAD
```

`check_links.py` walks the *built site*, so it only sees defects that survive rendering. This one reads the source and the commit messages, and catches what the other cannot:

| Finding | Severity | Why |
|---|---|---|
| Bare `#123` in a **commit message** | error (fails the run) | GitHub autolinks it against **this** repo, so a citation of an upstream issue becomes a link into `terraform-gyan`'s own empty tracker. Use `owner/repo#123` |
| Bare `#123` in a **Markdown file** | hygiene | *Not* a broken link — GitHub's docs state "Autolinked references are not created in wikis or files in a repository", and Zensical renders it as plain text. It is an unlinked number the reader cannot follow, so prefer `[#123](full-url)` |
| `\"` in an admonition title | error | Zensical passes it through verbatim, so `!!! note "the \"nines\""` renders the backslashes. Use curly quotes |

The bare-reference rule is easy to get backwards, so the severity split is deliberate: only the commit-message case is an actual broken link, and it is the only one that fails the run.

## Publishing

`.github/workflows/deploy.yml` builds on every push to `master` and deploys to GitHub Pages, via `scripts/build_site.py` so published links behave exactly like local ones.

The one difference from a local build: **the nav is trimmed** to `Learning Path` and `Book`. The committed `zensical.toml` keeps the full nav for local use; CI rewrites a copy inside its own checkout. Note what this does *not* do — **every page under `docs/` is still built and deployed**, including notes, topics and research-cache (verified: identical 183-page output either way). The trim only decides what appears in the sidebar, which is why resolving wikilinks in CI produces working links rather than 404s.

## Other scripts

| Script | Purpose |
|---|---|
| `scripts/build_site.py` | Build with the wikilink resolver installed — used locally and by CI |
| `scripts/wikilinks.py` | The `[[slug]]` index and the python-markdown patch behind it |
| `scripts/check_links.py` | Broken-internal-link check over the built site |
| `scripts/check_markdown.py` | Source-level lint: unlinked issue citations, autolinking commit messages, admonition-title escapes |
| `scripts/fetch_page.py` | Fetch a JavaScript-rendered page and cache its text under `cache/web/` |

`cache/` and `site/` are gitignored scratch.
