"""
build_site.py — build the site the same way `serve.py` renders it.

Usage:
    python scripts/build_site.py [--config zensical.toml] [--clean] [--strict]

A bare `zensical build` does not resolve `[[slug]]` references — the resolver lives in
`scripts/wikilinks.py` and is installed by the caller. Use this script anywhere the output
is meant for a reader (CI deploys included), and keep `zensical build` for throwaway checks.

Exits non-zero if any `[[slug]]` matched no page; those render as plain text rather than a
broken link, but they are still mistakes worth failing on.
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import wikilinks


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--config", default="zensical.toml", help="config file (default: zensical.toml)")
    parser.add_argument("--clean", action="store_true", help="wipe the output directory first")
    parser.add_argument("--strict", action="store_true", help="fail the build on Zensical warnings")
    parser.add_argument(
        "--allow-unresolved",
        action="store_true",
        help="exit 0 even when a [[slug]] matched no page",
    )
    args = parser.parse_args()

    config = os.path.abspath(args.config)
    docs_dir = os.path.join(os.path.dirname(config), "docs")

    index = wikilinks.install(docs_dir)
    print(f"wikilink index: {len(index)} pages")

    from zensical import build

    build(config, {"clean": args.clean, "strict": args.strict})

    missing = sorted(wikilinks.unresolved())
    if missing:
        print(f"\n{len(missing)} unresolved [[wikilink]] slug(s) — rendered as plain text:")
        for slug in missing:
            print(f"    {slug}")
        if not args.allow_unresolved:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
