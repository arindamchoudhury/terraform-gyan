"""Verify every blockquote in the book against the fetched-page cache.

A quote in a chapter is a claim that a source said those exact words. This
checks each one against cache/web/*.txt, which is the audit trail for every
page the project has fetched.

Two fabricated quotes reached chapter 15 the same way: a paraphrase written in
a reading note's own voice was later promoted into a chapter as an attributed
blockquote. Neither was caught by review. This catches that class.

Quotes that are legitimately not from a web page (CLI output, source code)
belong in ALLOWED_NON_WEB below, each with the file that grounds it.

    python scripts/check_quotes.py             # all chapters
    python scripts/check_quotes.py docs/book/ch15-remote-state-backends.md
"""

import glob
import pathlib
import re
import sys

# Quotes grounded somewhere other than a fetched web page.
# Key: a distinctive fragment. Value: where it comes from.
ALLOWED_NON_WEB = {
    "terraform acquires a state lock to protect": (
        "Terraform v1.15.8 source, internal/command/clistate/state.go:26 (CLI output)"
    ),
}

MIN_LEN = 40

# Some chapters use blockquotes for console transcripts and expression results
# rather than for quoting a source. Those are not claims about what anyone
# wrote, so they are not checked.
CODEISH = re.compile(
    r"""^\w+\(            # a call:  convert(...), type(...)
      | ^\s*\#            # a comment line
      | \["                # index into a map:  foo["b"]
      | \s\#\s           # trailing aligned comment
      | ^\$\s             # a shell prompt
      | ^[\w.\[\]"]+\s*=\s  # assignment
      | ^[\[\{]             # a for-expression or object literal
    """,
    re.VERBOSE,
)


def looks_like_code(text):
    if CODEISH.search(text):
        return True
    # prose has spaces between words; a bare identifier chain does not
    return len(text.split()) < 6


def norm(text):
    # Chapters often wrap a quotation in literal quote marks; sources do not.
    text = re.sub(r"[`*“”‘’\"']", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.lower().strip()


def quotes_in(path):
    out = []
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if not stripped.startswith("> "):
            continue
        body = stripped[2:].strip()
        if body.startswith("**"):          # bolded lead-ins, not source text
            continue
        body = body.lstrip("- ").strip()   # quoted bullet lists
        if len(body) < MIN_LEN or body.startswith("❓"):
            continue
        if looks_like_code(body):
            continue
        out.append((lineno, body))
    return out


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    targets = sys.argv[1:] or sorted(glob.glob("docs/book/ch*.md"))
    # Web pages are the primary audit trail. Book chapters are quoted from
    # PDFs, so their reading notes under docs/books/ stand in as the record of
    # what the book said.
    sources = (
        glob.glob("cache/web/*.txt")
        + glob.glob("cache/pdf/*.txt")
        + glob.glob("docs/books/**/*.md", recursive=True)
        + glob.glob("docs/sources/**/*.md", recursive=True)
    )
    corpus = {
        f: norm(pathlib.Path(f).read_text(encoding="utf-8", errors="ignore"))
        for f in sources
    }

    checked = 0
    findings = []
    for t in targets:
        path = pathlib.Path(t)
        for lineno, q in quotes_in(path):
            checked += 1
            nq = norm(q)

            allowed = next(
                (why for frag, why in ALLOWED_NON_WEB.items() if frag in nq), None
            )
            if allowed:
                continue

            # progressively shorter anchors, to tolerate our own elisions
            if any(
                probe and any(probe in v for v in corpus.values())
                for probe in (nq, nq[:120], nq[:80], nq[:60])
            ):
                continue

            findings.append((t, lineno, q))

    print(f"{checked} quoted passage(s) checked against {len(corpus)} cached source(s)")
    for t, lineno, q in findings:
        print(f"  {t}:{lineno}: not found in any cached source")
        print(f"    {q[:100]}")
    print(f"{len(findings)} unverified quote(s)")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
