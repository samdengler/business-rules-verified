#!/usr/bin/env python3
"""Render the site's home page, build/home/index.html, served at the root.

The page introduces the model with the status tiles of the progress page,
describes each part of the site with a link to it, and shows the three
questions at the top of "Decide these first".  The progress page itself is
at /progress/ (scripts/render_progress.py); links to its sections from
before it moved, such as /#found, are sent there.

Every count comes from the build: the statuses from build/status.json and
the blueprint through scripts/graph_model.py, and the requirements and
criteria from build/status.json.

  python3 scripts/render_home.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from graph_model import Model  # noqa: E402
from render_progress import CSS, decide_first, shown, tiles_html  # noqa: E402
from site_nav import AIRLINE_SITE, FAVICON, REPO, SITE_NAME, TOPBAR_CSS, topbar  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "home" / "index.html"

# The progress page's sections, which were on this page until it moved to
# /progress/.
MOVED = ["decide", "found", "today", "next", "map"]

HOME_CSS = """
.parts { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
.part { position: relative; display: flex; flex-direction: column; background: var(--surface); border: 1px solid var(--ring);
  border-radius: 10px; padding: 16px 18px 14px; transition: border-color .15s; }
.part:hover { border-color: color-mix(in srgb, var(--ready) 45%, var(--ring)); }
.part h3 { margin: 0 0 6px; font-size: 17px; color: var(--ink); }
.part h3 a, .part h3 a:visited { color: var(--ink); text-decoration: none; }
.part h3 a::after { content: ""; position: absolute; inset: 0; border-radius: 10px; }
.part h3 a:focus-visible::after { outline: 2px solid var(--ready); outline-offset: 2px; }
.part p { margin: 4px 0; color: var(--ink-2); }
.part strong { color: var(--ink); font-variant-numeric: tabular-nums; }
.part .more { position: relative; z-index: 1; display: flex; flex-wrap: wrap; gap: 4px 14px; font-size: 13.5px;
  margin-top: auto; padding-top: 10px; }
.top3 + .more { margin: 10px 0 0; font-size: 14px; }
@media (max-width: 900px) { .parts { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 600px) { .parts { grid-template-columns: minmax(0, 1fr); } }
"""


def plural(k, one, many):
    return f"<strong>{k}</strong> {one if k == 1 else many}"


def part(href, title, text, more=()):
    links = f'<p class="more">{" ".join(more)}</p>' if more else ""
    return f'<article class="part"><h3><a href="{href}">{title}</a></h3>{text}{links}</article>'


def page(m):
    show = shown(m.nodes, m.decls)
    counts = {k: sum(1 for n in show if n["status"] == k) for k in ("open", "decision")}
    in_lean = sum(1 for n in show if n["lean"])
    rules = [d for d in m.decls.values() if d.get("earsId")]
    criteria = [c for d in rules for c in d.get("criteria", [])]
    proven = sum(1 for c in criteria if c.get("status") == "proven")
    deps = sum(1 for n in m.nodes for u in n["uses"] if u in m.by)
    parts = "".join([
        part("tour/", "Guided tour",
             "<p>Start here if the model is new to you. The tour shows how much the model holds, how its areas build on "
             "each other, the decisions that reach the most cards, and one open question with the example that breaks it.</p>"),
        part("progress/", "Progress",
             f"<p>Every rule, guarantee and candidate rule with its status, grouped by area: "
             f"{plural(in_lean, 'card', 'cards')} in Lean and {plural(len(show) - in_lean, 'candidate', 'candidates')} "
             f"from the ONE Order survey. Of these, {plural(counts['open'], 'is an open question', 'are open questions')}, "
             f"and {plural(counts['decision'], 'candidate needs', 'candidates need')} a business decision.</p>",
             ['<a href="progress/#decide">Decide these first</a>', '<a href="progress/#found">Open questions</a>',
              '<a href="progress/#today">In the model today</a>', '<a href="progress/#next">Candidates</a>']),
        part("review/", "Review document",
             f"<p>The rules in plain words, a chapter per requirement: {plural(len(rules), 'requirement', 'requirements')} "
             f"with {plural(len(criteria), 'acceptance criterion', 'acceptance criteria')}, <strong>{proven}</strong> of them "
             "proven. Each criterion shows the Lean that checks it, and try-it panels run some of the rules in your browser.</p>"),
        part("graph/", "Explore",
             f"<p>How the rules depend on each other: {plural(len(m.nodes), 'card', 'cards')} in "
             f"{plural(len(m.order), 'area', 'areas')}, counting the definitions the rules rest on, with "
             f"{plural(deps, 'dependency', 'dependencies')} between them. "
             "Click a card to see what it uses and what builds on it.</p>",
             ['<a href="graph/?view=area-map">Area map</a>', '<a href="graph/?view=matrix">Matrix</a>',
              '<a href="graph/?view=all-cards">Every card</a>', '<a href="graph/?view=history">History</a>']),
        part(AIRLINE_SITE, "Verified Airline",
             "<p>A fictional airline's site, written from the model in a traveler's words. Every fee and refund on its "
             "policy pages is computed from the model, and a button shows the requirement behind each answer. The site "
             "has its own repository and reads the model's files from <code>/airline-data/</code>.</p>"),
        part(f"{REPO}/tree/main/.kiro/specs", "Specs and data",
             "<p>The requirements as specs in Kiro's format, with acceptance criteria in EARS, and the same criteria as a "
             "spreadsheet. The blueprint and the survey of ONE Order are where the candidate rules come from.</p>",
             ['<a href="ears-criteria.csv">Acceptance criteria (CSV)</a>', '<a href="blueprint/">Blueprint</a>',
              f'<a href="{REPO}/blob/main/docs/one-order-survey.md">ONE Order survey</a>']),
    ])
    moved = "|".join(MOVED)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{SITE_NAME}: airline rules checked by Lean</title>
{FAVICON}
<script>
// Links to the progress page's sections from before it moved to /progress/.
if (/^#({moved})$/.test(location.hash)) location.replace("progress/" + location.hash);
</script>
<style>{CSS}{HOME_CSS}{TOPBAR_CSS}</style>
</head>
<body>
{topbar(None, "./")}
<main>
<p class="kicker">Proof of concept · built from public IATA ONE Order material · not affiliated with IATA</p>
<h1>Rules for airline offers and orders, checked by Lean</h1>
<p class="lede">Each business rule here is written as code in Lean, a language that checks proofs.
A <strong>proven</strong> guarantee holds for every possible input, not only the cases someone thought to test.
An <strong>open question</strong> is a guarantee the rules as written do not meet. An example the build computes shows the failing case, and the business decides what the rule should do.
This page is generated from the model on every build.</p>
{tiles_html(show)}

<h2 id="parts">Ways into the model</h2>
<p class="sub">Each page shows the same model from a different side. The bar at the top links them all.</p>
<div class="parts">{parts}</div>

<h2 id="decide-top">Decide these first</h2>
<p class="sub">The three open questions and decisions with the most cards depending on them, so an answer reaches furthest.</p>
<div class="top3">{decide_first(m, "./", 3)}</div>
<p class="more"><a href="progress/#decide">See the top ten on the progress page</a></p>

<footer>Generated by <code>scripts/render_home.py</code> from the Lean build and the blueprint.
Counts are computed; nothing on this page is typed by hand.</footer>
</main>
</body>
</html>
"""


def main():
    m = Model()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(page(m))
    print(f"rendered {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
