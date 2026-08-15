"""
check_links.py — find internal links in the built site that point at nothing.

Usage:
    python scripts/check_links.py [site-dir] [--base /prefix/] [--quiet]

Outputs:
    One line per broken link, grouped by the page containing it.
    Exit code 1 when anything is broken, 0 when the site is clean — so it can
    gate a build.

Why this exists:
    Zensical's own "page does not exist" warning only covers markdown links
    ([text](../other.md)). It does not see hrefs produced by the wikilinks
    extension, so a mistyped [[slug]] resolves to the /sources/<slug>/ fallback
    and ships as a silent 404 that no build ever reports. Three of those were
    live in the book chapters before this script was written.

    Run it after a build, ideally a clean one:
        python -c "from zensical import build; build('zensical.toml', {'clean': True})"
        python scripts/check_links.py

    Note that a plain `zensical build` leaves [[slug]] as literal text — only
    serve.py installs the wikilink resolver — so this check is most meaningful
    against a site built the way serve.py builds it.
"""

import argparse
import collections
import os
import re
import sys
import tomllib
from urllib.parse import urlparse

HREF_RE = re.compile(r'href="([^"]+)"')
EXTERNAL_PREFIXES = ("http://", "https://", "#", "mailto:", "data:", "//")


def site_base(config_file="zensical.toml"):
    """The URL path this site deploys under, e.g. "/terraform-gyan/".

    404.html is generated with root-relative hrefs carrying that prefix (it has
    to be, since the server serves it from any depth), so without stripping the
    prefix every one of its links looks broken locally.
    """
    try:
        with open(config_file, "rb") as handle:
            url = tomllib.load(handle).get("project", {}).get("site_url", "")
    except (OSError, tomllib.TOMLDecodeError):
        return ""
    path = urlparse(url).path.strip("/")
    return f"/{path}/" if path else ""


def resolve(page_dir, site_dir, href, base_path=""):
    """Map an href to the file on disk it should hit, or None if it is external."""
    if href.startswith(EXTERNAL_PREFIXES):
        return None
    target = href.split("#")[0].split("?")[0]
    if not target:
        return None
    if base_path and target.startswith(base_path):
        target = "/" + target[len(base_path):]
    # Root-relative hrefs resolve against the site root, the rest against the
    # directory of the page that carries them.
    base = site_dir if target.startswith("/") else page_dir
    path = os.path.normpath(os.path.join(base, target.lstrip("/")))
    # Pretty URLs (no extension) and directories both mean <path>/index.html.
    if os.path.isdir(path) or not os.path.splitext(path)[1]:
        path = os.path.join(path, "index.html")
    return path


def check(site_dir, base_path=""):
    broken = collections.defaultdict(set)
    pages = 0
    for dirpath, _, filenames in os.walk(site_dir):
        for filename in filenames:
            if not filename.endswith(".html"):
                continue
            pages += 1
            page = os.path.join(dirpath, filename)
            with open(page, encoding="utf-8", errors="replace") as handle:
                html = handle.read()
            for href in set(HREF_RE.findall(html)):
                path = resolve(dirpath, site_dir, href, base_path)
                if path and not os.path.exists(path):
                    key = os.path.relpath(page, site_dir).replace(os.sep, "/")
                    broken[key].add(href)
    return pages, broken


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("site", nargs="?", default="site", help="built site directory (default: site)")
    parser.add_argument(
        "--base",
        default=None,
        help="URL path the site deploys under (default: read site_url from zensical.toml)",
    )
    parser.add_argument("--quiet", action="store_true", help="print only the summary line")
    args = parser.parse_args()

    if not os.path.isdir(args.site):
        print(f"error: no such directory: {args.site} — build the site first", file=sys.stderr)
        return 2

    base_path = args.base if args.base is not None else site_base()
    if base_path and not base_path.startswith("/"):
        base_path = "/" + base_path
    if base_path and not base_path.endswith("/"):
        base_path += "/"

    pages, broken = check(args.site, base_path)

    if not args.quiet:
        for page in sorted(broken):
            print(page)
            for href in sorted(broken[page]):
                print(f"    -> {href}")

    total = sum(len(hrefs) for hrefs in broken.values())
    print(f"{pages} pages scanned, {total} broken link(s) on {len(broken)} page(s)")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
