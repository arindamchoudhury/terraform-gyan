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

    4. Ordered lists silently destroyed by an interrupting block — either a
       marker that cannot interrupt the paragraph above it, or a callout sitting
       between two items. Both render as a valid page, so nothing else notices:
       the build passes, the links resolve, and the list is simply wrong. Five
       sections of learning-path.md had rotted this way before the check existed.
       See check_ordered_lists for the two shapes and the discriminator that
       separates them from the wrapped-line shape, which is fine.
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
# Escape hatch for text that must stay byte-exact — a quoted upstream changelog
# line, for instance, where linking the number would corrupt the quotation.
LINT_OK_RE = re.compile(r"<!--\s*lint-ok\b")
# Top-level ordered-list marker, and the two things that silently break one.
ORDERED_RE = re.compile(r"^(\d+)\.\s")
BULLET_RE = re.compile(r"^\s*[-*+]\s")
ANY_MARKER_RE = re.compile(r"^\s*(?:\d+\.|[-*+])\s")
ADMONITION_RE = re.compile(r"^(?:!!!|\?\?\?)\s")
HEADING_RE = re.compile(r"^#{1,6}\s")


def check_ordered_lists(lines):
    """Two CommonMark traps that silently destroy a numbered list.

    Neither shows up in a build or a link check — the page renders, just wrong —
    and both were found rotting in learning-path.md across five sections.

    1. A list marker cannot interrupt a paragraph unless it is "1.". So an item
       carrying an indented continuation paragraph, followed by the next marker
       with no blank line, swallows that marker and every item after it as lazy
       continuation text.

       Discriminator: a marker whose immediately-preceding line is non-blank is
       only a defect when a blank line has appeared since the *previous* marker.
       Without one the preceding line is a wrapped continuation of the current
       item, which renders correctly — verified against python-markdown rather
       than assumed.

    2. An unindented admonition between two items of an ordered list terminates
       it, so the following items begin a new list and the numbering restarts.
       Callouts belong after the list ends.
    """
    findings = []
    in_fence = False
    fence_marker = ""
    prev_marker = None          # line index of the previous top-level marker
    blank_since_marker = False
    section_start = 0
    markers, admonitions = [], []

    def flush():
        """Report callouts sitting between the first and last marker of a list."""
        if len(markers) >= 2:
            first, last = markers[0], markers[-1]
            for a in admonitions:
                if first < a < last:
                    findings.append(
                        (a + 1, "ERROR callout interrupts an ordered list (numbering restarts)",
                         lines[a].strip()[:90])
                    )

    for i, raw in enumerate(lines):
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

        if HEADING_RE.match(raw):           # a heading closes the current list scope
            flush()
            markers, admonitions = [], []
            prev_marker, blank_since_marker = None, False
            continue

        if ADMONITION_RE.match(raw):
            admonitions.append(i)
            continue

        m = ORDERED_RE.match(raw)
        if m:
            # "1." begins a fresh list, so anything before it belongs to the old one.
            if m.group(1) == "1" and markers:
                flush()
                markers, admonitions = [], []
            if m.group(1) != "1" and prev_marker is not None and blank_since_marker:
                prev_line = lines[i - 1] if i else ""
                if prev_line.strip() and not ANY_MARKER_RE.match(prev_line):
                    findings.append(
                        (i + 1,
                         f"ERROR item '{m.group(1)}.' cannot interrupt the paragraph above "
                         f"(needs a blank line); this and every later item collapse into it",
                         raw.strip()[:90])
                    )
            markers.append(i)
            prev_marker, blank_since_marker = i, False
            continue

        if not raw.strip():
            if prev_marker is not None:
                blank_since_marker = True
            continue

        # An unindented, non-marker paragraph ends the list. Admonition bodies are
        # indented, so they never reach here and never close a list prematurely.
        if not raw.startswith((" ", "\t")) and not ANY_MARKER_RE.match(raw):
            flush()
            markers, admonitions = [], []
            prev_marker, blank_since_marker = None, False

    flush()
    return findings


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
        all_lines = handle.read().split("\n")
    findings.extend(check_ordered_lists(all_lines))
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
            if in_fence or LINT_OK_RE.search(raw):
                continue

            if ADMONITION_ESCAPE_RE.match(raw):
                findings.append((lineno, 'ERROR escaped \\" in admonition title', raw.strip()[:90]))

            for match in BARE_REF_RE.finditer(strip_noise(raw)):
                findings.append(
                    (lineno, f"hygiene unlinked citation #{match.group(1)}", raw.strip()[:90])
                )
    return sorted(findings, key=lambda f: f[0])


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
    # Callout titles carry emoji; the Windows console defaults to cp1252 and
    # would raise UnicodeEncodeError mid-report rather than print the finding.
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

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
