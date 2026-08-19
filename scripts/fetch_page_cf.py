"""Fetch a Cloudflare-protected page with nodriver (Chrome over CDP).

Companion to `fetch_page.py`, which uses Playwright and is the default. Some
sites answer Playwright with a bot-check interstitial — docs.gitlab.com does
this on parts of /administration/ — and the saved cache file then contains
"Performing security verification" instead of the page. nodriver drives the
system Chrome without a webdriver flag, which those checks let through.

Usage:
    python scripts/fetch_page_cf.py <url> --slug <slug> [--timeout 60]

Output goes to cache/web/<slug>.txt, same as fetch_page.py, so the two are
interchangeable from a note-taking point of view. No credentials involved:
every page this project reads is public.
"""

import argparse
import asyncio
import pathlib
import time

NOTES_ROOT = pathlib.Path(__file__).parent.parent
CACHE_DIR = NOTES_ROOT / "cache" / "web"
# Chrome is not installed on every machine here; Edge is Chromium and speaks the
# same DevTools Protocol, so it works identically. First existing path wins.
BROWSER_CANDIDATES = (
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
)

BOT_CHECK_MARKERS = (
    "just a moment",
    "performing security verification",
    "verifying you are human",
)


def _chrome():
    for candidate in BROWSER_CANDIDATES:
        if pathlib.Path(candidate).exists():
            return candidate
    return None  # None: let nodriver find it


async def _fetch(url, slug, timeout):
    import nodriver as uc

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache_file = CACHE_DIR / f"{slug}.txt"

    browser = await uc.start(headless=False, browser_executable_path=_chrome())
    page = await browser.get(url)

    deadline = time.time() + timeout
    text = ""
    while time.time() < deadline:
        await asyncio.sleep(2)
        try:
            title = (await page.evaluate("document.title") or "").lower()
            text = await page.evaluate("document.body.innerText") or ""
        except Exception:
            continue
        blocked = any(m in title for m in BOT_CHECK_MARKERS) or any(
            m in text[:400].lower() for m in BOT_CHECK_MARKERS
        )
        if blocked:
            print(f"  [cf] challenge running... ({title[:60]})")
            continue
        if len(text) > 500:
            print(f"  content ready ({title[:60]})")
            break

    # Expand any collapsed sections before reading the final text.
    try:
        for btn in await page.query_selector_all("button[aria-expanded='false']"):
            try:
                await btn.click()
                await asyncio.sleep(0.2)
            except Exception:
                pass
        await asyncio.sleep(1)
        text = await page.evaluate("document.body.innerText") or text
    except Exception:
        pass

    browser.stop()

    if any(m in text[:400].lower() for m in BOT_CHECK_MARKERS):
        raise SystemExit(f"still blocked after {timeout}s — nothing written")

    cache_file.write_text(text, encoding="utf-8")
    print(f"Saved {len(text)} chars -> {cache_file}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("url")
    ap.add_argument("--slug", required=True)
    ap.add_argument("--timeout", type=int, default=60)
    args = ap.parse_args()
    asyncio.run(_fetch(args.url, args.slug, args.timeout))
