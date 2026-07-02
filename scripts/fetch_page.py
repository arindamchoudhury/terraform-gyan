"""
fetch_page.py — fetch a JavaScript-rendered page and save its text content to cache.

Usage:
    python fetch_page.py <url> [--slug <slug>] [--out <cache-dir>] [--timeout <ms>]

Outputs:
    Saves extracted text to <cache-dir>/<slug>.txt (default cache dir: ../cache/web)
    Prints the saved file path to stdout on success.

Requirements:
    pip install playwright
    Uses the system Chrome installation — no separate browser download needed.
"""

import argparse
import re
import sys
from pathlib import Path

CHROME_PATH = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
DEFAULT_CACHE_DIR = Path(__file__).parent.parent / "cache" / "web"

# JS that returns innerText of the container holding the next-slide button.
# Used once per card to capture the currently visible slide.
_CAROUSEL_SLIDE_TEXT_JS = """
() => {
    const btn = document.querySelector('[aria-label="Go to next slide"]');
    if (!btn) return '';
    let el = btn.parentElement;
    for (let i = 0; i < 10; i++) {
        if (!el || el === document.body) return '';
        if (el.offsetHeight > 100 && el.offsetWidth > 200) break;
        el = el.parentElement;
    }
    return el ? el.innerText.trim() : '';
}
"""


def slugify(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r"[^\w\s-]", "", text)
    text = re.sub(r"[\s_]+", "-", text)
    text = re.sub(r"-+", "-", text)
    return text[:80].strip("-")


def slug_from_url(url: str) -> str:
    url = re.sub(r"https?://", "", url)
    url = re.sub(r"[#?].*$", "", url)
    url = re.sub(r"[^\w]+", "-", url)
    return url[:80].strip("-")


def expand_all_interactive(page) -> None:
    """Click every interactive element that might reveal hidden content.

    Uses combined CSS selectors (one CDP call per action type) to avoid
    per-selector roundtrip latency on analytics-heavy SPAs where each CDP
    call can stall 30-40s waiting for Chrome's main thread.
    """

    # 1. All collapsed accordion / expandable triggers — one combined query.
    #    IMPORTANT: only target trigger elements (buttons, headers), NOT body/container
    #    divs. Clicking container divs after opening a header re-closes the accordion.
    expand_combined = (
        "button[aria-expanded='false'], "
        "[role='button'][aria-expanded='false'], "
        "summary, "
        "button[class*='accordion__header'], "
        "button[class*='accordion-header'], "
        "[class*='accordion__header']:not([aria-expanded='true']), "
        "[class*='accordion-header']:not([aria-expanded='true']), "
        "[class*='card__header'], "
        "[class*='card-header'], "
        "[class*='item__header'], "
        "[class*='item-header'], "
        "[class*='panel-heading']"
    )
    try:
        elements = page.query_selector_all(expand_combined)
        clicked = 0
        for el in elements:
            try:
                if el.is_visible():
                    el.click()
                    page.wait_for_timeout(200)
                    clicked += 1
            except Exception:
                pass
        if clicked:
            print(f"Clicked {clicked} expand trigger(s)", file=sys.stderr)
    except Exception:
        pass

    # 2. All tab triggers — one combined query.
    tab_combined = (
        "[role='tab'], "
        ".blocks-tabs__header-item, "
        "[class*='tab__button'], "
        "[class*='tab-button'], "
        "[class*='tab__item'], "
        "[class*='tab-item']"
    )
    try:
        tabs = page.query_selector_all(tab_combined)
        clicked = 0
        for tab in tabs:
            try:
                if tab.is_visible():
                    tab.click()
                    page.wait_for_timeout(300)
                    clicked += 1
            except Exception:
                pass
        if clicked:
            print(f"Clicked {clicked} tab(s)", file=sys.stderr)
    except Exception:
        pass

    page.wait_for_timeout(500)


def extract_tab_panels(page) -> str:
    """Extract text from all tab panels, including CSS-hidden ones.

    Tab widgets (exclusive: only one panel visible at a time) leave all but
    the last-clicked panel hidden when the page is extracted via inner_text().
    This function temporarily un-hides each panel to read its text, then
    restores the original visibility.
    """
    try:
        panels = page.evaluate("""
        () => {
            const selectors = [
                '[role="tabpanel"]',
                '.blocks-tabs__content-item',
                '[class*="tab__panel"]',
                '[class*="tab-panel"]',
                '[class*="tabpanel"]',
                '.tabbed-block',
            ];
            const seen = new Set();
            const allResults = [];
            for (const sel of selectors) {
                const els = Array.from(document.querySelectorAll(sel));
                if (els.length < 2) continue;
                const groupResults = [];
                for (const el of els) {
                    if (seen.has(el)) continue;
                    seen.add(el);
                    // Save state
                    const prevDisplay = el.style.display;
                    const prevVisibility = el.style.visibility;
                    const hadHidden = el.hasAttribute('hidden');
                    const prevAriaHidden = el.getAttribute('aria-hidden');
                    // Force visible — cover display:none, visibility:hidden, hidden attr, aria-hidden
                    el.style.display = 'block';
                    el.style.visibility = 'visible';
                    el.removeAttribute('hidden');
                    el.removeAttribute('aria-hidden');
                    const text = (el.innerText || el.textContent || '').trim();
                    // Restore state
                    el.style.display = prevDisplay;
                    el.style.visibility = prevVisibility;
                    if (hadHidden) el.setAttribute('hidden', '');
                    if (prevAriaHidden !== null) el.setAttribute('aria-hidden', prevAriaHidden);
                    if (text.length > 30) groupResults.push(text);
                }
                if (groupResults.length >= 2) allResults.push(...groupResults);
            }
            return allResults;
        }
        """)
    except Exception:
        return ""

    if not panels:
        return ""

    print(f"Tab panels: captured {len(panels)} panel(s)", file=sys.stderr)
    return "\n\n=== Tab Panels ===\n\n" + "\n\n---\n\n".join(panels)


def extract_carousel_cards(page) -> str:
    """Walk through flashcard carousels (next-slide button pattern) and collect all cards.

    Google Cloud training uses a carousel where each card has a front (question)
    and a flippable back (answer). Cards 2-N are hidden by CSS until navigated to.
    This function navigates through every card, flips each one, and returns all text.
    """
    # Only run if a carousel navigation button exists (evaluate avoids slow CDP DOM call)
    try:
        has_carousel = page.evaluate("() => !!document.querySelector(\"[aria-label='Go to next slide']\")")
    except Exception:
        has_carousel = False
    if not has_carousel:
        return ""

    cards = []
    seen = set()

    for _ in range(30):  # safety cap
        # Capture the currently visible card (front side)
        text = page.evaluate(_CAROUSEL_SLIDE_TEXT_JS)
        key = text[:80]
        if key in seen:
            break  # wrapped back to start
        seen.add(key)

        # Flip to the back side — click all visible flip buttons in the slide
        try:
            for btn in page.query_selector_all(".flashcard-side-flip__btn"):
                if btn.is_visible():
                    btn.click()
                    page.wait_for_timeout(400)
                    break  # one click flips the card; stop after first visible hit
        except Exception:
            pass

        # Capture the back side
        text_back = page.evaluate(_CAROUSEL_SLIDE_TEXT_JS)
        if text_back[:80] not in seen:
            seen.add(text_back[:80])
            cards.append(text_back)
        else:
            cards.append(text)  # back was same as front (no flip); keep front

        # Navigate to the next card
        try:
            btn = page.query_selector("[aria-label='Go to next slide']")
            if btn and btn.is_visible():
                btn.click()
                page.wait_for_timeout(700)
            else:
                break
        except Exception:
            break

    if not cards:
        return ""

    print(f"Carousel: captured {len(cards)} card(s)", file=sys.stderr)
    separator = "\n\n--- next card ---\n\n"
    return "\n\n=== Knowledge Check Cards ===\n\n" + separator.join(cards)


def extract_images(page, base_url: str) -> str:
    """Collect URLs of meaningful content images (diagrams, screenshots).

    Skips tiny images (icons, bullets) and data-URI blobs.
    Returns a formatted block to append to the cache file, or '' if none found.
    """
    try:
        imgs = page.evaluate(
            """(baseUrl) => {
                const results = [];
                const seen = new Set();
                for (const img of document.querySelectorAll('img')) {
                    const src = img.currentSrc || img.src || '';
                    if (!src || src.startsWith('data:') || seen.has(src)) continue;
                    // Skip tiny images (icons/bullets/UI chrome)
                    const w = img.naturalWidth || img.width || 0;
                    const h = img.naturalHeight || img.height || 0;
                    if (w < 200 || h < 100) continue;
                    seen.add(src);
                    results.push({src, alt: img.alt || '', w, h});
                }
                return results;
            }""",
            base_url,
        )
    except Exception:
        return ""

    if not imgs:
        return ""

    lines = ["\n\n=== Images ===\n"]
    for img in imgs:
        alt = img["alt"] or "diagram"
        lines.append(f"![]({img['src']})")
        lines.append(f"*{alt} ({img['w']}×{img['h']})*\n")
    print(f"Images: captured {len(imgs)} image(s)", file=sys.stderr)
    return "\n".join(lines)


def fetch(url: str, slug: str, out_dir: Path, timeout_ms: int) -> Path:
    from playwright.sync_api import sync_playwright

    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / f"{slug}.txt"

    with sync_playwright() as p:
        browser = p.chromium.launch(
            executable_path=CHROME_PATH,
            headless=True,
            args=[
                "--no-sandbox",
                "--disable-dev-shm-usage",
                "--disable-background-networking",
                "--disable-default-apps",
                "--disable-sync",
                "--disable-translate",
                "--disable-extensions",
                "--metrics-recording-only",
                "--no-first-run",
                "--safebrowsing-disable-auto-update",
            ],
        )
        page = browser.new_page()

        import time as _time
        def _ts(label):
            print(f"[t={_time.monotonic():.1f}] {label}", file=sys.stderr)

        _ts("goto start")
        try:
            page.goto(url, wait_until="domcontentloaded", timeout=timeout_ms)
        except Exception as e:
            print(f"goto timed out or failed: {e}", file=sys.stderr)
        _ts("goto done")

        try:
            page.wait_for_function(
                """() => {
                    const body = document.body.innerText.toLowerCase();
                    return body.length > 200 && !body.includes('your content is loading');
                }""",
                timeout=timeout_ms,
            )
        except Exception as e:
            print(f"Wait timed out or failed: {e}", file=sys.stderr)
        _ts("wait_for_function done")

        page.wait_for_timeout(1000)
        _ts("initial wait done")

        # Collect carousel/flashcard content (hidden-by-CSS slides)
        carousel_text = extract_carousel_cards(page)
        _ts("carousel done")

        # Collect all tab panel content (hidden panels excluded from innerText)
        tab_panel_text = extract_tab_panels(page)
        _ts("tab panels done")

        # Collect content image URLs (diagrams, screenshots)
        image_block = extract_images(page, url)
        _ts("images done")

        # Extract main visible content via JS evaluate — avoids slow CDP DOM calls
        # (DOM.querySelectorAll blocks on Chrome's main thread for ~750s on analytics-
        # heavy SPAs; Runtime.evaluate runs in a separate V8 context and returns fast).
        content = ""
        selectors = ["main", "article", "[role='main']", "#content", ".content", ".lesson", ".slide", "body"]
        try:
            result = page.evaluate("""
                (selectors) => {
                    for (const sel of selectors) {
                        const el = document.querySelector(sel);
                        if (el) {
                            const text = el.innerText || '';
                            if (text.trim().length > 200) {
                                return { selector: sel, text: text };
                            }
                        }
                    }
                    return null;
                }
            """, selectors)
            if result:
                content = result["text"]
                print(f"Extracted from: {result['selector']}", file=sys.stderr)
        except Exception as e:
            print(f"Content extraction failed: {e}", file=sys.stderr)
        _ts("content extracted")

        # Assemble content before any cleanup — browser.close() and
        # playwright.stop() both hang ~13 min on analytics-heavy SPAs.
        # os._exit() here skips both; OS cleans up the browser process.
        if carousel_text:
            content = content + "\n\n" + carousel_text
        if tab_panel_text:
            content = content + "\n\n" + tab_panel_text
        if image_block:
            content = content + image_block

        if not content.strip():
            print("WARNING: extracted content is empty.", file=sys.stderr)
            import os as _os
            _os._exit(1)

        out_file.write_text(content, encoding="utf-8")
        print(f"Saved {len(content)} chars to: {out_file}", file=sys.stderr)
        print(str(out_file))
        import os as _os
        _os._exit(0)

    return out_file  # unreachable; kept for type-checker


def main():
    parser = argparse.ArgumentParser(description="Fetch a JS-rendered page to text cache.")
    parser.add_argument("url", help="URL to fetch")
    parser.add_argument("--slug", help="Cache file slug (auto-derived from URL if omitted)")
    parser.add_argument("--out", help="Output cache directory", default=str(DEFAULT_CACHE_DIR))
    parser.add_argument("--timeout", type=int, default=30000, help="Page load timeout in ms (default: 30000)")
    args = parser.parse_args()

    slug = args.slug or slug_from_url(args.url)
    out_dir = Path(args.out)
    out_file = fetch(args.url, slug, out_dir, args.timeout)
    print(str(out_file))


if __name__ == "__main__":
    main()
