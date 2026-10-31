#!/usr/bin/env python3
"""Render the site's home page, build/home/index.html, served at the root.

The page is written for a reader with no context.  It says what the project
is in plain words, then works through one guarantee: the rule, the
guarantee we want from it, the example that shows the rule breaking it, and
the question it leaves for the business.  Then it points each kind of reader
to a page, shows the status tiles of the progress page with what each status
means, the three questions at the top of "Decide these first", and a card
for each part of the site.  The progress page itself is at /progress/
(scripts/render_progress.py); links to its sections from before it moved,
such as /#found, are sent there.

The worked guarantee is the tour's step 4, QUESTION in scripts/render_tour.py,
so the two pages show the same one, and the build stops when it is no longer
open.  Its text comes from the model: the rule's EARS statement, the
guarantee's blueprint card, and the example's docstring, with the result Lean
computes.  Every count comes from the build: the statuses from
build/status.json and the blueprint through scripts/graph_model.py, and the
requirements and criteria from build/status.json.

  python3 scripts/render_home.py
"""

import html
import sys
from pathlib import Path
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parent))
from graph_model import Model  # noqa: E402
from render_progress import CSS, chip, decide_first, shown, split_question, tiles_html  # noqa: E402
from render_status import blueprint_titles, humanize, plain  # noqa: E402
from render_tour import QUESTION, computed, example_of, given_when_then  # noqa: E402
from site_nav import AIRLINE_SITE, FAVICON, REPO, SITE_NAME, TOPBAR_CSS, topbar  # noqa: E402

esc = html.escape

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
.lede + .lede { margin-top: 0; }
.lede + .kicker { margin: 4px 0 0; }
.worked h2 { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 12px; }
.worked h2 .chip { font-size: 13px; font-weight: 600; }
.worked-panel { background: var(--surface); border: 1px solid var(--ring); border-radius: 12px; padding: 4px 20px;
  max-width: 920px; }
.worked-panel .row { display: grid; grid-template-columns: 190px minmax(0, 1fr); gap: 16px; padding: 12px 0;
  border-top: 1px solid var(--hair); }
.worked-panel .row:first-child { border-top: 0; }
.worked-panel .label { color: var(--muted); font-size: 12px; font-weight: 600; letter-spacing: .05em; text-transform: uppercase;
  padding-top: 3px; }
.worked-panel .row p { margin: 0 0 4px; }
.worked-panel .result { border-left: 3px solid var(--critical); padding-left: 12px; }
.worked-panel .result dl { display: grid; grid-template-columns: auto 1fr; gap: 2px 14px; margin: 0 0 4px; }
.worked-panel .result dt { color: var(--ink-2); }
.worked-panel .result dd { margin: 0; font-weight: 600; font-variant-numeric: tabular-nums; }
.worked-panel .note { color: var(--muted); font-size: 13px; }
.worked-panel .ask { background: color-mix(in srgb, var(--warning) 14%, transparent); border-radius: 8px; padding: 8px 12px; }
.cta { display: flex; flex-wrap: wrap; align-items: center; gap: 10px 20px; margin: 18px 0 0; }
.cta .button, .cta .button:visited { background: var(--ready); color: #fff; font-weight: 600; padding: 9px 16px; border-radius: 8px;
  text-decoration: none; }
.cta .button:hover { background: color-mix(in srgb, var(--ready) 88%, #000); }
.routes { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; }
.part .who { margin: 0 0 4px; font-size: 12px; font-weight: 600; letter-spacing: .05em; text-transform: uppercase; color: var(--muted); }
@media (max-width: 900px) { .parts, .routes { grid-template-columns: repeat(2, minmax(0, 1fr)); } }
@media (max-width: 600px) { .parts, .routes { grid-template-columns: minmax(0, 1fr); }
  .worked-panel .row { grid-template-columns: minmax(0, 1fr); gap: 4px; } }
"""


def plural(k, one, many):
    return f"<strong>{k}</strong> {one if k == 1 else many}"


def part(href, title, text, more=(), who=None):
    links = f'<p class="more">{" ".join(more)}</p>' if more else ""
    who = f'<p class="who">{who}</p>' if who else ""
    return f'<article class="part">{who}<h3><a href="{href}">{title}</a></h3>{text}{links}</article>'


def worked(m):
    """The tour's open guarantee, worked through: the rule, the guarantee, the
    example and what the rule gives for it, and the question it leaves."""
    decls = m.decls
    theorem = decls.get(QUESTION)
    if not theorem or theorem["status"] != "open":
        sys.exit(f"scripts/render_home.py: {QUESTION} is no longer open; choose another open question in scripts/render_tour.py")
    example = example_of(decls, theorem)
    rule = next((d for d in decls.values() if d.get("earsId") and
                 any(c["id"] in theorem["checks"] for c in d.get("criteria", []))), None)
    if not example or not rule:
        sys.exit(f"scripts/render_home.py: {QUESTION} needs an example and a rule whose criterion it checks")
    card = next(n for n in m.nodes if QUESTION in n["lean"])
    desc, _, question, _ = split_question(card)
    # The example's Then paragraph names the theorem; the computed result stands in for it.
    given = [p for p in given_when_then(example.get("docstring")) if p.startswith(("<strong>Given", "<strong>When"))]
    chapter = blueprint_titles().get(rule["name"], humanize(rule["name"].rsplit(".", 1)[-1]))
    chapter_href = "review/find/?domain=Verso.Genre.Manual.section&name=" + quote(rule["earsId"].lower())
    rows = [
        ("The rule", f"<p>{esc(plain(rule['ears']))}</p>"),
        ("The guarantee we want", f"<p>{' '.join(desc)}</p>"),
        ("An example", "".join(f"<p>{p}</p>" for p in given)),
        ("What the rule gives",
         f'<div class="result">{computed(example.get("value") or "")}'
         '<p class="note">Lean computes this result from the rule on every build.</p></div>'),
        ("The question for the business", f'<p class="ask">{question[:1].upper() + question[1:]}</p>'),
    ]
    panel = "".join(f'<div class="row"><div class="label">{k}</div><div>{v}</div></div>' for k, v in rows)
    return f"""<section class="worked">
<h2 id="example">{esc(card["title"])} {chip("open")}</h2>
<p class="sub">One guarantee from the model, worked through. It is still open: an example shows the rule as written
breaking it, so the business has to decide what the rule should say.</p>
<div class="worked-panel">{panel}</div>
<p class="cta"><a class="button" href="tour/">Take the five-step tour</a>
<a href="{chapter_href}">Read “{esc(chapter)}” in the review document</a></p>
</section>"""


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
    routes = "".join([
        part("tour/", "Take the guided tour",
             "<p>Five steps: what the model holds, how its areas build on each other, and where it needs a decision.</p>",
             who="New to the model"),
        part("progress/#decide", "Questions for the business",
             "<p>The open questions and decisions, ranked by how much of the model each answer reaches.</p>",
             who="You decide business rules"),
        part("review/", "Requirements and their checks",
             "<p>A chapter per requirement, with its acceptance criteria and the Lean that checks each one.</p>",
             who="You build airline systems"),
        part(AIRLINE_SITE, "Verified Airline",
             "<p>A fictional airline's policies, written from the model, with every fee and refund computed by it.</p>",
             who="You want a traveler's view"),
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
<h1>Formally verifying airline booking rules</h1>
<p class="lede">When you book a flight, the airline makes you an offer, and accepting it creates an order: something that is
paid for, changed, refunded and finally used. IATA, the airlines' trade association, describes how offers and orders should
work in its ONE Order standard. The standard is written in prose, and prose leaves gaps that two systems can fill
differently.</p>
<p class="lede">This project uses formal verification: each rule is written as code in <a href="https://lean-lang.org">Lean</a>,
a language that checks proofs. A guarantee that Lean proves holds in every possible case. Where the rules as written cannot meet a guarantee, the gap becomes a question for the
business, with an example that shows it.</p>
<p class="kicker">A proof of concept built from IATA's public material, not affiliated with IATA. This page is generated
from the model on every build.</p>

{worked(m)}

<h2 id="start">Where to start</h2>
<p class="sub">Each page shows the same model from a different side. Pick the one that fits what you do.</p>
<div class="routes">{routes}</div>

<h2 id="status">The model's status today</h2>
<p class="sub">The model is a set of cards: rules written in Lean, guarantees about those rules, and candidate rules taken
from IATA's public material. A proven guarantee holds for every input, and an open question is a guarantee the rules as
written do not meet. A candidate rule needs a business decision, is ready to build, or waits on other rules.</p>
{tiles_html(show)}

<h2 id="decide-top">Decide these first</h2>
<p class="sub">The three open questions and decisions with the most cards depending on them, so an answer reaches furthest.</p>
<div class="top3">{decide_first(m, "./", 3)}</div>
<p class="more"><a href="progress/#decide">See the top ten on the progress page</a></p>

<h2 id="parts">Every part of the site</h2>
<p class="sub">The bar at the top links them all.</p>
<div class="parts">{parts}</div>

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
