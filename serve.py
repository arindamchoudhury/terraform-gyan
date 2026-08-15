import os
import sys
import threading
from livereload import Server

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "scripts"))
import wikilinks as _wikilinks

_docs_dir = os.path.join(os.path.dirname(os.path.abspath("zensical.toml")), "docs")

# Installs the [[slug]] resolver and registers the extension. Shared with
# scripts/build_site.py so the preview and the published site render links the
# same way. Must run before importing zensical.build: Zensical's Rust side calls
# back into parse_zensical_config(), which reads DEFAULT_MARKDOWN_EXTENSIONS.
# The ```mermaid fence needs no patch — the defaults already register
# pymdownx.superfences with a mermaid custom fence.
_wikilinks.install(_docs_dir)

from zensical import build as _zensical_build

_CONFIG_FILE = os.path.abspath("zensical.toml")

# Debounce state: resets on every file-change event so rapid saves
# don't trigger multiple consecutive builds.
_build_timer = None
_build_lock = threading.Lock()


def _do_build():
    """The actual build, called after the debounce window expires."""
    _wikilinks.refresh(_docs_dir)  # pick up notes added since the last build
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
