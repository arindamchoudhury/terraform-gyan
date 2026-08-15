import glob as _glob
import os
import threading
from livereload import Server

import zensical.config as _zc


# slug -> "/rel/path/" index, rebuilt once per build() via _refresh_slug_index().
# Avoids a recursive glob per wikilink (was O(links x tree) every build).
_slug_index = {}


def _refresh_slug_index(docs_dir):
    index = {}
    for path in _glob.glob(os.path.join(docs_dir, "**", "*.md"), recursive=True):
        slug = os.path.splitext(os.path.basename(path))[0].lower()
        rel = os.path.relpath(path, docs_dir).replace("\\", "/")
        # First match wins, matching the previous glob[0] behaviour.
        index.setdefault(slug, "/" + rel[:-3] + "/")
    _slug_index.clear()
    _slug_index.update(index)


def _make_wikilink_resolver(docs_dir):
    # Resolve [[slug]] via the prebuilt slug index so notes can live in
    # course subdirectories without breaking cross-references on reorg.
    def build_url(label, base, end):
        slug = label.strip().replace(" ", "-").lower()
        return _slug_index.get(slug, f"/sources/{slug}/")
    return build_url


_docs_dir = os.path.join(os.path.dirname(os.path.abspath("zensical.toml")), "docs")

# Patch the module-level build_url in the wikilinks extension directly.
# Passing build_url via the config dict is unreliable — Zensical may not
# forward callables through its config pipeline. Patching the module function
# guarantees it's picked up regardless of how the extension is initialised.
import markdown.extensions.wikilinks as _wikilinks_ext
_wikilinks_ext.build_url = _make_wikilink_resolver(_docs_dir)

# Add [[slug]] wikilink support to the default extension set. zensical.toml
# defines no markdown_extensions of its own, so this dict is what every build
# resolves to. build_url stays out of this config on purpose: zensical pickles
# mdx_configs to hash it, and a closure isn't picklable — the module-global
# patch above carries the resolver instead.
# The ```mermaid fence needs no patch. DEFAULT_MARKDOWN_EXTENSIONS already
# registers pymdownx.superfences with a mermaid custom fence.
# Must happen before importing zensical.build so the patch is in effect when
# Rust calls back into parse_zensical_config().
_zc.DEFAULT_MARKDOWN_EXTENSIONS["wikilinks"] = {
    "base_url": "/sources/",
    "end_url": "/",
}

from zensical import build as _zensical_build

_CONFIG_FILE = os.path.abspath("zensical.toml")

# Debounce state: resets on every file-change event so rapid saves
# don't trigger multiple consecutive builds.
_build_timer = None
_build_lock = threading.Lock()


def _do_build():
    """The actual build, called after the debounce window expires."""
    _refresh_slug_index(_docs_dir)
    _zensical_build(_CONFIG_FILE, {"clean": False, "strict": False})


def build():
    """Debounced wrapper: waits 5 s of quiet before calling _do_build."""
    global _build_timer
    with _build_lock:
        if _build_timer is not None:
            _build_timer.cancel()
        _build_timer = threading.Timer(5.0, _do_build)
        _build_timer.daemon = True
        _build_timer.start()


_do_build()  # initial build on startup (immediate, not debounced)

import logging

import livereload.watcher as _lr_watcher

_lr_logger = logging.getLogger("livereload")
_orig_is_file_changed = _lr_watcher.Watcher.is_file_changed


def _is_file_changed_resilient(self, path, ignore=None):
    """is_file_changed that survives a stat() failure on one file.

    Docker Desktop's bind mount intermittently raises OSError (EIO) from
    os.path.getmtime for files that stat fine on the Windows host. Upstream
    doesn't guard that call, so the exception escapes into tornado's
    PeriodicCallback and aborts the whole polling pass — the visible symptom
    being "Exception in callback ... LiveReloadHandler.poll_tasks" and live
    reload quietly missing edits afterwards.
    """
    try:
        return _orig_is_file_changed(self, path, ignore)
    except OSError as err:
        previous = self._task_mtimes.get(path)
        if previous is not None:
            # Carry the last known mtime forward, or is_file_removed() reads the
            # missing entry as a deletion and forces a needless rebuild.
            self._new_mtimes[path] = previous
        _lr_logger.warning("skipping unreadable path %s (%s)", path, err)
        return False


_lr_watcher.Watcher.is_file_changed = _is_file_changed_resilient

server = Server()
server.watch("docs/", build)
server.watch("zensical.toml", build)
# PORT lets a launcher assign a free port; 8000 stays the default for Docker.
server.serve(root="site", port=int(os.environ.get("PORT", 8000)), host="0.0.0.0")
