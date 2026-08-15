"""
check_markdown.py — lint Markdown source, and commit messages, for defects the built site never shows.

Usage:
    python scripts/check_markdown.py [docs-dir] [--quiet]
    python scripts/check_markdown.py --commits origin/master..HEAD

Outputs:
    One line per finding, grouped by file (or commit). Exit code 1 when anything
    is found.

Why this exists:
    check_links.py walks the *built site*, so it only sees defects that survive
    rendering. Three classes never reach it.

    1. Bare "#123" in a COMMIT MESSAGE — a real broken link. GitHub resolves a
       bare #NNN in issues, PRs, discussions and commit messages against the
       repository being viewed, so a reference to an upstream issue renders as a
       link into this repo's own (empty) tracker. Use the cross-repository form,
       owner/repo#123, which resolves correctly.

       Scope confirmed against GitHub's own documentation, which states:
       "Autolinked references are not created in wikis or files in a repository."
       So this defect is specific to commit messages and conversations.

    2. Bare "#123" in a MARKDOWN FILE — not a broken link, because GitHub does
       not autolink inside repository files and Zensical renders it as plain
       text. It is a weak citation: an unlinked number the reader cannot follow
       or verify. Reported as hygiene, not as breakage.

    3. Escaped quotes in admonition titles. Zensical passes \\" through verbatim
       into `!!! note "..."`, `??? ...` and `=== "..."` titles, so the page shows
       a literal backslash. Use curly quotes for a quoted phrase in a title.
"""

import argparse
import collections
import os
import re
import subprocess
import sys

# Fenced code: ``` or ~~~, any indent, optional language.
FENCE_RE = re.compile(r"^\s*(`{3,}|~{3,})")
INLINE_CODE_RE = re.compile(r"`[^`]*`")
# [text](target) and [text][ref] — a #NNN in either half is already a real link.
MD_LINK_RE = re.compile(r"\[[^\]]*\]\([^)]*\)|\[[^\]]*\]\[[^\]]*\]")
AUTOLINK_RE = re.compile(r"<[^>\s]+>")
# owner/repo#123 is the cross-repository form and resolves correctly everywhere.
QUALIFIED_REF_RE = re.compile(r"[\w.-]+/[\w.-]+#\d+")
# What is left: a bare #123. Two or more digits, not an HTML entity (&#124;),
# not part of a hex colour or a word.
BARE_REF_RE = re.compile(r"(?<![&\w/-])#(\d{2,})\b")
ADMONITION_ESCAPE_RE = re.compile(r'^\s*(!!!|\?\?\?|===)\s+.*\\"')


def strip_noise(line):
    """Blank out spans where a # needs no linking."""
    line = INLINE_CODE_RE.sub(" ", line)
    line = MD_LINK_RE.sub(" ", line)
    line = AUTOLINK_RE.sub(" ", line)
    return QUALIFIED_REF_RE.sub(" ", line)


def check_file(path):
    findings = []
    in_fence = False
    fence_marker = ""
    with open(path, encoding="utf-8", errors="replace") as handle:
        for lineno, raw in enumerate(handle, 1):
            fence = FENCE_RE.match(raw)
            if fence:
                marker = fence.group(1)[0] * 3
                if not in_fence:
                    in_fence, fence_marker = True, marker
                elif marker == fence_marker:
                    in_fence = False
                continue
            if in_fence:
                continue

            if ADMONITION_ESCAPE_RE.match(raw):
                findings.append((lineno, 'ERROR escaped \\" in admonition title', raw.strip()[:90]))

            for match in BARE_REF_RE.finditer(strip_noise(raw)):
                findings.append(
                    (lineno, f"hygiene unlinked citation #{match.group(1)}", raw.strip()[:90])
                )
    return findings


def check_commits(rev_range):
    """Bare #NNN in a commit message is a genuinely broken link — GitHub autolinks it here."""
    out = subprocess.run(
        ["git", "log", "--format=%H%x00%s%x00%b%x1e", rev_range],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    if out.returncode != 0:
        print(f"error: git log failed: {out.stderr.strip()}", file=sys.stderr)
        return None
    results = collections.OrderedDict()
    for record in out.stdout.split("\x1e"):
        if not record.strip():
            continue
        sha, subject, body = (record.strip().split("\x00") + ["", ""])[:3]
        findings = []
        for lineno, line in enumerate((subject + "\n" + body).splitlines(), 1):
            for match in BARE_REF_RE.finditer(strip_noise(line)):
                findings.append(
                    (lineno, f"ERROR bare #{match.group(1)} autolinks to this repo", line.strip()[:90])
                )
        if findings:
            results[f"{sha[:9]} {subject[:60]}"] = findings
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("docs", nargs="?", default="docs", help="docs directory (default: docs)")
    parser.add_argument("--commits", metavar="RANGE", help="also scan commit messages in RANGE")
    parser.add_argument("--quiet", action="store_true", help="print only the summary line")
    args = parser.parse_args()

    if not os.path.isdir(args.docs):
        print(f"error: no such directory: {args.docs}", file=sys.stderr)
        return 2

    results = collections.OrderedDict()
    files = 0
    for dirpath, _, filenames in os.walk(args.docs):
        for filename in sorted(filenames):
            if not filename.endswith(".md"):
                continue
            files += 1
            path = os.path.join(dirpath, filename)
            findings = check_file(path)
            if findings:
                results[os.path.relpath(path).replace(os.sep, "/")] = findings

    commit_results = check_commits(args.commits) if args.commits else {}
    if commit_results is None:
        return 2
    results.update(commit_results)

    if not args.quiet:
        for path, findings in results.items():
            print(path)
            for lineno, problem, context in findings:
                print(f"    {lineno}: {problem}")
                print(f"        {context}")

    errors = sum(1 for f in results.values() for item in f if item[1].startswith("ERROR"))
    total = sum(len(f) for f in results.values())
    scope = f"{files} files" + (f" + commits in {args.commits}" if args.commits else "")
    print(f"{scope} scanned, {total} finding(s), {errors} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
