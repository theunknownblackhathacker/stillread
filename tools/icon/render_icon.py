# tools/icon/render_icon.py
# Renders the Stillread app icon (light, dark, tinted) at 1024×1024 with Chromium.
# Usage: python3 tools/icon/render_icon.py <output-dir>

import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

# Concept: the reader reduced to its essence. One red letter at the fixed focus point,
# framed by the reader's two guide lines with their centre notches.
VARIANTS = {
    "AppIcon-Light": {
        "bg_top": "#F8F5EF", "bg_bottom": "#EDE7DC",
        "guide": "rgba(29,31,36,0.34)", "letter": "#E2483D",
    },
    "AppIcon-Dark": {
        "bg_top": "#16181D", "bg_bottom": "#0B0C0F",
        "guide": "rgba(255,255,255,0.32)", "letter": "#FF5A4E",
    },
    # Tinted icons are greyscale; iOS applies the user's tint by luminance.
    "AppIcon-Tinted": {
        "bg_top": "#000000", "bg_bottom": "#000000",
        "guide": "rgba(255,255,255,0.45)", "letter": "#FFFFFF",
    },
}

TEMPLATE = """<!doctype html>
<html><head><meta charset="utf-8">
<style>
  html, body {{ margin: 0; padding: 0; width: 1024px; height: 1024px; overflow: hidden; }}
  svg {{ display: block; }}
</style></head>
<body>
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="{bg_top}"/>
      <stop offset="1" stop-color="{bg_bottom}"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="1024" fill="url(#bg)"/>

  <!-- Guide lines with centre notches, as in the reader -->
  <g stroke="{guide}" stroke-width="16" stroke-linecap="round" fill="none">
    <line x1="208" y1="276" x2="816" y2="276"/>
    <line x1="512" y1="276" x2="512" y2="334"/>
    <line x1="208" y1="748" x2="816" y2="748"/>
    <line x1="512" y1="748" x2="512" y2="690"/>
  </g>

  <!-- The anchor letter, its x-height centred on the focus point -->
  <text x="512" y="626" text-anchor="middle"
        font-family="Inter Display, Inter, sans-serif" font-weight="700" font-size="440"
        fill="{letter}">s</text>
</svg>
</body></html>"""


def main(out_dir: str) -> None:
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1024, "height": 1024}, device_scale_factor=1)
        for name, colors in VARIANTS.items():
            page.set_content(TEMPLATE.format(**colors))
            page.wait_for_timeout(150)
            page.screenshot(path=str(out / f"{name}.png"), omit_background=False)
            print("rendered", name)
        browser.close()


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
