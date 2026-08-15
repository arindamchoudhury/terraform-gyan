"""
wikilinks.py — resolve [[slug]] references against the pages that actually exist.

Notes cross-reference each other by slug alone (`[[tf-state]]`), so a note can move
between course directories without breaking every link that points at it. This module
builds a slug -> URL index over `docs/` and wires it into python-markdown.

Used by both `serve.py` (local preview) and `scripts/build_site.py` (what CI runs), so
the published site renders links the same way the local one does.

Two behaviours worth knowing:

- A slug with **no matching page** renders as plain text, not a link. The stock extension
  always emits an anchor, so a typo used to ship as a silent 404 pointing at the
  `/sources/<slug>/` fallback. Rendering it as text keeps the prose readable and makes the
  mistake visible instead of clickable.
- The index is refreshable: `serve.py` rebuilds it on every incremental build so a newly
  added note resolves without restarting the server.
"""

import glob
import os
import xml.etree.ElementTree as etree

import markdown.extensions.wikilinks as _wikilinks_ext

# slug -> "/rel/path/". Rebuilt by refresh(); read by the patched inline processor.
_slug_index: dict[str, str] = {}

# Slugs that were referenced but do not exist, collected so a build can report them.
_unresolved: set[str] = set()


def refresh(docs_dir: str) -> dict[str, str]:
    """Rescan `docs_dir` and replace the slug index. First match wins."""
    index: dict[str, str] = {}
    for path in glob.glob(os.path.join(docs_dir, "**", "*.md"), recursive=True):
        slug = os.path.splitext(os.path.basename(path))[0].lower()
        rel = os.path.relpath(path, docs_dir).replace("\\", "/")
        index.setdefault(slug, "/" + rel[:-3] + "/")
    _slug_index.clear()
    _slug_index.update(index)
    return _slug_index


def unresolved() -> set[str]:
    """Slugs referenced by a [[link]] that matched no page in the last render."""
    return set(_unresolved)


def _resolve(label: str) -> str | None:
    return _slug_index.get(label.strip().replace(" ", "-").lower())


def _handle_match(self, m, data):
    """Replacement for WikiLinksInlineProcessor.handleMatch (python-markdown 3.x).

    Same as upstream except an unknown slug yields a <span> carrying the label rather
    than an <a> pointing at a page that does not exist.
    """
    label = m.group(1).strip()
    if not label:
        return "", m.start(0), m.end(0)

    url = _resolve(label)
    if url is None:
        _unresolved.add(label)
        span = etree.Element("span")
        span.set("class", "wikilink-missing")
        span.text = label
        return span, m.start(0), m.end(0)

    _, _, html_class = self._getMeta()
    a = etree.Element("a")
    a.text = label
    a.set("href", url)
    if html_class:
        a.set("class", html_class)
    return a, m.start(0), m.end(0)


def install(docs_dir: str) -> dict[str, str]:
    """Patch python-markdown and register the extension, then return the slug index.

    Must run before `zensical.build` imports its config: Zensical's Rust side calls back
    into `parse_zensical_config()`, which reads `DEFAULT_MARKDOWN_EXTENSIONS` as the
    default whenever `zensical.toml` declares no `markdown_extensions` of its own.

    The resolver deliberately stays out of that config dict — Zensical pickles
    `mdx_configs` to hash it, and a function is not picklable. Patching module-level
    state carries it instead.
    """
    import zensical.config as zc

    refresh(docs_dir)
    _wikilinks_ext.WikiLinksInlineProcessor.handleMatch = _handle_match
    # build_url is unused now that handleMatch resolves directly, but the extension
    # still calls it during setup validation, so keep it consistent.
    _wikilinks_ext.build_url = lambda label, base, end: _resolve(label) or f"{base}{label}{end}"
    zc.DEFAULT_MARKDOWN_EXTENSIONS["wikilinks"] = {
        "base_url": "/sources/",
        "end_url": "/",
    }
    return _slug_index
