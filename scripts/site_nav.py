#!/usr/bin/env python3
"""The bar at the top of every page: the site name and links to its parts.

The home page, the progress page and the other generated pages build their
bar from `topbar()`.  The site name leads to the home page
(scripts/render_home.py); Progress leads to /progress/.  Run as a script, this adds the same bar to the blueprint's pages
after leanblueprint has written them:

  python3 scripts/site_nav.py site/blueprint

The review document gets the same bar from Review/review.js and
Review/review.css, since Verso builds its own header.
"""

import re
import sys
from pathlib import Path

REPO = "https://github.com/samdengler/verified-air"
SITE_NAME = "Verified Air"

# The site's mark: a plane taking off, in the text color so it follows the
# theme.  Review/review.js repeats the path for the review document's bar.
PLANE_PATH = "M21.6 12c0-.85-.7-1.45-1.55-1.45H14.3L9.4 3.2H7.6l2.35 7.35H5.5L3.75 8.1H2.4l1.05 3.9-1.05 3.9h1.35l1.75-2.45h4.45L7.6 20.8h1.8l4.9-7.35h5.75c.85 0 1.55-.6 1.55-1.45z"
PLANE_SVG = (f'<svg class="mark" viewBox="0 0 24 24" aria-hidden="true">'
             f'<path transform="rotate(-30 12 12)" fill="currentColor" d="{PLANE_PATH}"/></svg>')

# The same plane as the browser tab's icon, in a blue that reads on light and
# dark tab bars.
FAVICON = ('<link rel="icon" href="data:image/svg+xml,'
           + "%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E"
           + f"%3Cpath transform='rotate(-30 12 12)' fill='%232a78d6' d='{PLANE_PATH}'/%3E%3C/svg%3E"
           + '">')

# Each link's path from the site root.  Explore is the dependency graph's
# page, with the area map, the matrix, every card, the history and a card's
# neighbourhood as views; it stays at graph/ so older links keep working.
# Verified Airline is the fictional airline's policy pages
# (scripts/render_airline.py), which have their own header.
LINKS = [
    ("Progress", "progress/"),
    ("Review document", "review/"),
    ("Explore", "graph/"),
    ("Verified Airline", "airline/"),
    ("GitHub", REPO),
]

# The colors fall back to the light theme, so the bar is light on pages that
# define no theme of their own, such as the blueprint's.
TOPBAR_CSS = """
.site-topbar { display: flex; align-items: center; justify-content: flex-start; gap: 24px; padding: 0 28px; height: 48px;
  box-sizing: border-box;
  background: var(--surface, #fcfcfb); border-bottom: 1px solid var(--ring, rgba(11,11,11,0.10));
  font: 14px/1.4 system-ui, -apple-system, "Segoe UI", sans-serif; flex-shrink: 0; }
.site-topbar .brand, .site-topbar .brand:visited { display: inline-flex; align-items: center; gap: 8px;
  font-weight: 650; font-size: 16px; color: var(--ink, #0b0b0b); text-decoration: none; white-space: nowrap; }
.site-topbar .brand .mark { width: 20px; height: 20px; flex: none; }
.site-topbar a { margin: 0; }
/* On a narrow screen the links scroll sideways. */
.site-topbar .site-nav { display: flex; gap: 18px; white-space: nowrap; min-width: 0; overflow-x: auto; scrollbar-width: none; }
.site-topbar .site-nav a, .site-topbar .site-nav a:visited, .site-topbar .local, .site-topbar .local:visited {
  color: var(--ink-2, #52514e); text-decoration: none; }
.site-topbar .site-nav a:hover, .site-topbar .local:hover { color: var(--ink, #0b0b0b); }
.site-topbar .site-nav a[aria-current] { color: var(--ink, #0b0b0b); font-weight: 600; }
.site-topbar .local { margin-left: auto; white-space: nowrap; }
/* On a phone the bar keeps the plane, which leads home, and drops the name. */
@media (max-width: 700px) { .site-topbar { gap: 16px; padding: 0 16px; } .site-topbar .brand .name { display: none; } }
"""


def topbar(current, root, extra=""):
    """The bar's HTML.  `root` is the relative path from the page to the site
    root; `extra` goes inside the bar after the links."""
    links = []
    for name, path in LINKS:
        href = path if path.startswith("http") else (root + path or "./")
        cur = ' aria-current="page"' if name == current else ""
        links.append(f'<a href="{href}"{cur}>{name}</a>')
    return (f'<header class="site-topbar"><a class="brand" href="{root or "./"}" aria-label="{SITE_NAME}, home">'
            f'{PLANE_SVG}<span class="name">{SITE_NAME}</span></a>'
            f'<nav class="site-nav" aria-label="Site">{"".join(links)}</nav>{extra}</header>')


BLUEPRINT_HEADER = re.compile(r"<body>\s*<header>(.*?)</header>", re.S)


def add_to_blueprint(directory):
    """Replace the header of each blueprint page with the site's bar, keeping
    the page's own table-of-contents button."""
    for page in sorted(Path(directory).glob("*.html")):
        html = page.read_text()
        if "site-topbar" in html:
            continue
        m = BLUEPRINT_HEADER.search(html)
        if not m:
            continue
        toggle = re.search(r'<svg\s+id="toc-toggle".*?</svg>', m.group(1), re.S)
        # The dependency graph's header links back to the chapters; keep that link.
        extra = '<a class="local" href="index.html">Blueprint chapters</a>' if not toggle else ""
        bar = topbar(None, "../", extra)
        if toggle:
            # The button opens the blueprint's table of contents; it stays first.
            bar = bar.replace('<header class="site-topbar">', '<header class="site-topbar">' + toggle.group(0), 1)
        html = html[:m.start()] + "<body>\n" + bar + html[m.end():]
        style = f"<style>{TOPBAR_CSS}.site-topbar #toc-toggle {{ cursor: pointer; flex-shrink: 0; }}</style>"
        html = html.replace("</head>", FAVICON + style + "</head>", 1)
        page.write_text(html)


if __name__ == "__main__":
    add_to_blueprint(sys.argv[1] if len(sys.argv) > 1 else "site/blueprint")
