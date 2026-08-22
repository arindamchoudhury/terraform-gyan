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
    "no changes. your infrastructure still matches the configuration": (
        "Terraform v1.15.8 CLI output, measured against the emulator with the provider pointed at another region (section 8)"
    ),
    "since the last terraform apply which may have affected this plan": (
        "Terraform v1.15.8 CLI output, measured in labs/chapter16/lab5 (plan -refresh-only)"
    ),
    "does not have any error situations itself": (
        "Terraform v1.15.8 source, internal/refactoring/move_execute.go:26 (doc comment)"
    ),
    "terraform acquires a state lock to protect": (
        "Terraform v1.15.8 source, internal/command/clistate/state.go:26 (CLI output)"
    ),
    # NB: norm() strips apostrophes, so fragments here must avoid them
    "need to be cryptographically secure": (
        "Terraform v1.15.8 source, internal/states/statemgr/locker.go:146 (code comment)"
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
    # Underscores go too: markdown sources emphasise with _word_, and chapters
    # re-emphasise the same word with ** ** or drop the emphasis entirely.
    # Stripping them from both sides keeps snake_case identifiers comparable,
    # since the same collapse applies to quote and source alike.
    text = re.sub(r"[`*_“”‘’\"']", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.lower().strip()


def url_to_cache():
    """Map a source URL to the cache file holding that page.

    Reading notes under docs/sources/ carry a `**Source:**` line naming the URL,
    and their filename matches the cache slug, so the notes are the index.
    """
    index = {}
    for note in glob.glob("docs/sources/**/*.md", recursive=True):
        text = pathlib.Path(note).read_text(encoding="utf-8", errors="ignore")
        m = re.search(r"\*\*Source:\*\*\s*\[[^\]]*\]\((https?://[^)]+)\)", text)
        if not m:
            continue
        slug = pathlib.Path(note).stem
        cache = pathlib.Path("cache/web") / f"{slug}.txt"
        if cache.exists():
            index[m.group(1).rstrip("/")] = cache.as_posix()
    return index


LINK_RE = re.compile(r"\[[^\]]+\]\((https?://[^)]+)\)")


def attributed_url(lines, i):
    """The page a quote is attributed to, if the lead-in names and links one."""
    for back in range(1, 4):
        j = i - back
        if j < 0:
            break
        m = LINK_RE.search(lines[j])
        if m:
            return m.group(1).rstrip("/")
    return None


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


# Long quoted spans inside prose: *"..."* or plain "...". Short ones are
# usually a term of art rather than a citation, so only sentence-length spans
# are treated as claims about what a source wrote.
INLINE_MIN_WORDS = 8
INLINE_MIN_CHARS = 60


def _paired_spans(line):
    """Quoted spans, pairing quote marks left to right.

    A regex spanning from the first quote to the last mis-joins two separate
    quotations on one line, and treats an empty pair like `bucket = ""` as an
    opening mark. Sequential pairing avoids both.
    """
    marks = [i for i, c in enumerate(line) if c in '"“”']
    spans = []
    for a, b in zip(marks[::2], marks[1::2]):
        spans.append(line[a + 1 : b])
    return spans


def inline_quotes_in(path):
    out = []
    in_fence = False
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line.strip().startswith("```"):
            in_fence = not in_fence
            continue
        s = line.strip()
        # admonition/tab titles are quoted but are our own words, not citations
        if in_fence or s.startswith("> ") or re.match(r"^(!!!|\?\?\?|===)\s", s):
            continue
        for span in _paired_spans(line):
            body = span.strip()
            if (
                len(body) >= INLINE_MIN_CHARS
                and len(body.split()) >= INLINE_MIN_WORDS
                and not looks_like_code(body)
            ):
                out.append((lineno, body))
    return out


def check_attribution(path, corpus, index):
    """A quote introduced by a named, linked page must be in *that* page."""
    lines = path.read_text(encoding="utf-8").splitlines()
    findings = []
    for i, line in enumerate(lines):
        s = line.strip()
        if not s.startswith("> ") or s.startswith("> **"):
            continue
        body = s[2:].strip().lstrip("- ").strip()
        if len(body) < MIN_LEN or body.startswith("❓") or looks_like_code(body):
            continue
        url = attributed_url(lines, i)
        if not url or url not in index:
            continue
        cache = index[url]
        nq = norm(body)
        hay = corpus.get(cache, "")
        if not any(p and p in hay for p in (nq, nq[:120], nq[:80], nq[:60])):
            findings.append((str(path), i + 1, url, cache, body))
    return findings


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
        # changelogs are cited for version-gating claims
        + glob.glob("../repos/*/CHANGELOG.md")
    )
    corpus = {
        pathlib.Path(f).as_posix(): norm(
            pathlib.Path(f).read_text(encoding="utf-8", errors="ignore")
        )
        for f in sources
    }

    checked = 0
    findings = []
    for t in targets:
        path = pathlib.Path(t)
        for lineno, q in list(quotes_in(path)) + list(inline_quotes_in(path)):
            checked += 1
            nq = norm(q)

            allowed = next(
                (why for frag, why in ALLOWED_NON_WEB.items() if frag in nq), None
            )
            if allowed:
                continue

            # progressively shorter anchors, to tolerate our own elisions
            # A quote we elided with … cannot match end to end; check the
            # longest contiguous fragment we did reproduce.
            fragments = [f.strip() for f in re.split(r"…|\.\.\.", nq) if f.strip()]
            longest = max(fragments, key=len) if fragments else nq
            probes = (nq, longest, longest[:120], longest[:80], longest[:60])
            if any(
                probe and any(probe in v for v in corpus.values()) for probe in probes
            ):
                continue

            findings.append((t, lineno, q))

    index = url_to_cache()
    mis = []
    for t in targets:
        mis += check_attribution(pathlib.Path(t), corpus, index)

    print(f"{checked} quoted passage(s) checked against {len(corpus)} cached source(s)")
    for f, lineno, url, cache, q in mis:
        print(f"  {f}:{lineno}: attributed to {url}")
        print(f"    but not found in {cache}")
        print(f"    {q[:90]}")
    if mis:
        print(f"{len(mis)} misattributed quote(s)")
    for t, lineno, q in findings:
        print(f"  {t}:{lineno}: not found in any cached source")
        print(f"    {q[:100]}")
    print(f"{len(findings)} unverified quote(s)")
    return 1 if (findings or mis) else 0


if __name__ == "__main__":
    sys.exit(main())
