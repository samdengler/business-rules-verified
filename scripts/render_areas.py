#!/usr/bin/env python3
"""Render a summary page for each area, build/area/<slug>/index.html.

An area is a section of the blueprint.  Its page shows its cards by status,
the areas it builds on and the areas that build on it, its open questions and
decisions with the number of cards depending on each, the open guarantees
that Lean proves for one reading of the sources, its requirements with links
to their chapters in the review document, and the IATA capabilities its
candidate cards belong to.

Everything comes from build/status.json, the blueprint and
docs/one-order-coverage.md through scripts/graph_model.py.

  python3 scripts/render_areas.py [--unpaired]

With --unpaired it lists the open theorems that have no proven `_of_`
version by name.
"""

import html
import shutil
import sys
from pathlib import Path
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parent))
from area_views import AREA_CSS  # noqa: E402
from graph_model import Model, short, slug  # noqa: E402
from render_progress import CSS as PAGE_CSS, STATUSES, chip, split_question  # noqa: E402
from render_status import blueprint_titles, humanize  # noqa: E402
from site_nav import FAVICON, SITE_NAME, TOPBAR_CSS, topbar  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "area"
esc = html.escape

CSS = """
.kicker a { color: var(--muted); }
.twocol { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0 32px; }
.deps { list-style: none; padding: 0; margin: 0; background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; }
.deps li { display: grid; grid-template-columns: minmax(0, 1.2fr) minmax(60px, 1fr) 40px; gap: 12px; align-items: center;
  padding: 8px 14px; border-top: 1px solid var(--ring); font-size: 14px; }
.deps li:first-child { border-top: none; }
.deps .b { height: 8px; border-radius: 3px; background: var(--ink-2); opacity: .55; min-width: 3px; }
.deps .k { text-align: right; font-variant-numeric: tabular-nums; color: var(--ink-2); }
.deps .back { color: var(--muted); font-size: 12px; }
.empty { color: var(--muted); font-size: 14px; background: var(--surface); border: 1px dashed var(--ring); border-radius: 10px;
  padding: 12px 16px; margin: 0; }
.card .impact { font-size: 13px; color: var(--ink); margin-top: 8px; }
.card .impact strong { font-variant-numeric: tabular-nums; }
.reading { background: var(--surface); border: 1px solid var(--ring); border-left: 4px solid var(--good); border-radius: 10px;
  padding: 14px 18px; margin-top: 10px; }
.reading h4 { margin: 0 0 4px; font-size: 15.5px; }
.reading h4 a { color: var(--ink); text-decoration: none; }
.reading h4 a:hover { text-decoration: underline; }
.reading p { margin: 6px 0; color: var(--ink-2); }
.reading .doc { color: var(--ink); background: color-mix(in srgb, var(--good) 10%, transparent); border-radius: 6px; padding: 6px 10px; }
.reading .lean { font-size: 13px; }
table.reqs { width: 100%; border-collapse: collapse; background: var(--surface); border: 1px solid var(--ring); border-radius: 10px;
  overflow: hidden; font-size: 14px; }
table.reqs th, table.reqs td { text-align: left; vertical-align: top; padding: 9px 12px; border-top: 1px solid var(--ring); }
table.reqs th { font-size: 12px; font-weight: 600; letter-spacing: .04em; text-transform: uppercase; color: var(--muted); border-top: none; }
table.reqs td.id { white-space: nowrap; font-variant-numeric: tabular-nums; color: var(--ink-2); }
table.reqs td.title a { font-weight: 600; }
table.reqs td.ears { color: var(--ink-2); }
table.reqs td.crit { white-space: nowrap; font-size: 13px; color: var(--ink-2); }
.caps { list-style: none; padding: 0; margin: 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 8px; }
.caps li { background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 10px 14px; font-size: 14px; }
.caps .name { font-weight: 600; }
.caps .more { display: block; font-size: 13px; color: var(--ink-2); margin-top: 2px; }
.areas-nav { display: flex; flex-wrap: wrap; gap: 6px 14px; font-size: 13.5px; margin-top: 14px; }
.areas-nav .lbl { color: var(--muted); }
.areas-nav a[aria-current] { color: var(--ink); font-weight: 600; text-decoration: none; }
@media (max-width: 800px) { .twocol { grid-template-columns: 1fr; } table.reqs td.ears { display: none; } }
"""

CRITERIA = [("proven", "proven"), ("example", "example only"), ("open", "open"), ("not checked", "not checked")]


def tiles(counts):
    out = []
    for k in STATUSES:
        label = STATUSES[k][0].lower()
        out.append(f'<div class="tile s-{k}"><div class="n"><span class="ico" aria-hidden="true">{STATUSES[k][1]}</span>'
                   f'{counts[k]}</div><div class="l">{label}</div></div>')
    total = sum(counts.values())
    bar = "".join(f'<span class="s-{k}" style="flex:{counts[k]}" title="{STATUSES[k][0]}: {counts[k]} of {total}"></span>'
                  for k in STATUSES if counts[k])
    return (f'<div class="tiles">{"".join(out)}</div>'
            f'<div class="bar" role="img" aria-label="Status of {total} cards">{bar}</div>')


def dep_list(m, area, rows, outward):
    if not rows:
        return ('<p class="empty">No other area builds on it.</p>' if outward
                else '<p class="empty">It builds on no other area.</p>')
    top = max(k for _, k in rows)
    items = []
    for other, k in rows:
        back = m.is_back(area, other) if outward else m.is_back(other, area)
        note = ' <span class="back">points back</span>' if back else ""
        items.append(f'<li><span><a href="../{slug(other)}/">{esc(other)}</a>{note}</span>'
                     f'<span class="b" style="width:{100 * k / top:.0f}%"></span>'
                     f'<span class="k">{k}</span></li>')
    return '<ul class="deps">' + "".join(items) + "</ul>"


def question_card(m, n):
    desc, found, question, source = split_question(n)
    imp = m.impact(n["label"])
    k = imp["count"]
    impact = (f'<strong>{k}</strong> {"card depends" if k == 1 else "cards depend"} on it, directly or through other '
              f'cards, in {len(imp["areas"])} {"area" if len(imp["areas"]) == 1 else "areas"}.'
              if k else "No card depends on it yet.")
    tag = f'<span class="tag">{esc(n["tag"])}</span>' if n.get("tag") else ""
    q = (f'<p class="found-line"><strong>Counterexample:</strong> {found}</p>' if found else "") + (
        f'<p class="question"><strong>Open point:</strong> {question}</p>' if question else "")
    return (f'<article class="card s-{n["status"]}"><header>{tag}{chip(n["status"])}</header>'
            f'<h4><a class="card-link" href="../../graph/#{quote(n["label"])}">{esc(n["title"])}</a></h4>'
            f'<p>{" ".join(desc)}</p>{q}<p class="impact">{impact}</p></article>')


def readings(m, area):
    out = []
    for n in m.area_nodes[area]:
        rs = m.readings(n)
        if not rs:
            continue
        _, _, question, _ = split_question(n)
        body = "".join(
            f'<p class="doc">{r["doc"]}</p><p class="lean">Proven as '
            f'<a href="../../review/find/?domain=Verso.Genre.Manual.doc&name={quote(r["proven"])}"><code>'
            f'{esc(r["proven"].rsplit(".", 1)[-1])}</code></a>; open as <code>{esc(r["open"].rsplit(".", 1)[-1])}</code>.</p>'
            for r in rs)
        out.append(f'<div class="reading"><h4><a href="../../graph/#{quote(n["label"])}">{esc(n["title"])}</a></h4>'
                   + (f'<p><strong>Open point:</strong> {question}</p>' if question else "")
                   + f'<p>Lean proves the guarantee for one reading of the sources. If the business settles the question '
                     f'this way, it holds for every input:</p>{body}</div>')
    return out


def requirements(m, area, titles):
    rows = []
    for r in m.requirements(area):
        counts = {}
        for c in r.get("criteria", []):
            counts[c["status"]] = counts.get(c["status"], 0) + 1
        crit = " · ".join(f"{counts[k]} {w}" for k, w in CRITERIA if counts.get(k))
        title = titles.get(r["name"], humanize(r["name"].rsplit(".", 1)[-1]))
        href = "../../review/find/?domain=Verso.Genre.Manual.section&name=" + quote(r["earsId"].lower())
        rows.append(f'<tr><td class="id">{esc(r["earsId"])}</td><td class="title"><a href="{href}">{esc(title)}</a></td>'
                    f'<td class="ears">{esc(r.get("ears") or "")}</td><td class="crit">{crit}</td></tr>')
    if not rows:
        return '<p class="empty">No requirement in this area is written in Lean yet.</p>'
    return ('<table class="reqs"><thead><tr><th>ID</th><th>Requirement</th><th>Rule</th><th>Acceptance criteria</th></tr>'
            '</thead><tbody>' + "".join(rows) + "</tbody></table>")


def capabilities(m, area):
    caps = m.capabilities(area)
    if not caps:
        return '<p class="empty">No card in this area carries an IATA capability code.</p>'
    items = []
    for code, ids in sorted(caps.items(), key=lambda kv: (-len(kv[1]), kv[0])):
        c = m.cap_names[code]
        k = len(ids)
        items.append(f'<li><code>{code}</code> <span class="name">{esc(c["name"])}</span>'
                     f'<span class="more">{k} {"card" if k == 1 else "cards"} here. '
                     f'<a href="../../graph/?view=all-cards&amp;cap={code}">Show every card with {code}</a> · '
                     f'<a href="{esc(c["url"])}">IATA\'s page</a></span></li>')
    return '<ul class="caps">' + "".join(items) + "</ul>"


def page(m, area, titles):
    counts = m.counts(area)
    n = sum(counts.values())
    in_lean = counts["modelled"] + counts["proven"] + counts["open"]
    questions = sorted((x for x in m.area_nodes[area] if x["status"] in ("open", "decision")),
                       key=lambda x: (-m.impact(x["label"])["count"], x["title"]))
    q_html = ('<div class="board">' + "".join(question_card(m, x) for x in questions) + "</div>" if questions
              else '<p class="empty">This area has no open question and nothing waiting for a decision.</p>')
    rd = readings(m, area)
    rd_html = "".join(rd) if rd else '<p class="empty">No open guarantee in this area has a proven version for one reading.</p>'
    current = ' aria-current="page"'
    nav = "".join(f'<a href="../{slug(a)}/"{current if a == area else ""}>{esc(short(a))}</a>' for a in m.order)
    lede = (f"{n} cards in the blueprint's section {esc(area)}: {in_lean} are in Lean, "
            f"{counts['open']} {'is an open question' if counts['open'] == 1 else 'are open questions'} and "
            f"{counts['decision']} {'needs' if counts['decision'] == 1 else 'need'} a business decision.")
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(area)}: {SITE_NAME}</title>
{FAVICON}
<style>{PAGE_CSS}{AREA_CSS}{CSS}{TOPBAR_CSS}</style>
</head>
<body>
{topbar("Explore", "../../")}
<main>
<p class="kicker"><a href="../../graph/">Explore</a> · area summary</p>
<h1>{esc(area)}</h1>
<p class="lede">{lede}</p>
<nav class="links" aria-label="This area elsewhere">
  <a href="../../graph/?view=all-cards&amp;area={quote(area)}">Show these cards among all cards</a>
  <a href="../../graph/?view=area-map">Area map</a>
  <a href="../../graph/?view=matrix">Dependency matrix</a>
</nav>
{tiles(counts)}
<nav class="areas-nav" aria-label="Other areas"><span class="lbl">Areas:</span>{nav}</nav>

<div class="twocol">
<section><h2 id="builds-on">Areas it builds on</h2>
<p class="sub">The number of times a card here uses a card in that area.</p>
{dep_list(m, area, m.builds_on(area), False)}</section>
<section><h2 id="built-on-by">Areas that build on it</h2>
<p class="sub">The number of times a card in that area uses a card here.</p>
{dep_list(m, area, m.built_on_by(area), True)}</section>
</div>

<h2 id="questions">Open questions and decisions</h2>
<p class="sub">Each with the number of cards that depend on it, directly or through other cards, most first. Click one to see what it
depends on and what builds on it.</p>
{q_html}

<h2 id="if-we-decide">If we decide this</h2>
<p class="sub">An open guarantee fails under some reading of the sources. For these, Lean proves a version under one reading, named
with <code>_of_</code>. The model leaves the choice of reading to the business.</p>
{rd_html}

<h2 id="requirements">Requirements</h2>
<p class="sub">The requirements whose rules or guarantees are on this area's cards. Each opens its chapter in the review document.</p>
{requirements(m, area, titles)}

<h2 id="capabilities">IATA capabilities</h2>
<p class="sub">The capabilities of IATA's Airline Retailing Maturity Index that this area's candidate cards belong to. The codes and
names are IATA's.</p>
{capabilities(m, area)}

<footer>Generated by <code>scripts/render_areas.py</code> from the Lean build and the blueprint.
Statuses and counts are computed; nothing on this page is typed by hand.</footer>
</main>
</body>
</html>
"""


def main():
    m = Model()
    titles = blueprint_titles()
    if OUT.exists():
        shutil.rmtree(OUT)
    for area in m.order:
        out = OUT / slug(area) / "index.html"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(page(m, area, titles))
    unpaired = m.unpaired_open()
    print(f"rendered build/area/: {len(m.order)} area pages; {len(m.pairs)} open guarantees have a proven version for "
          f"one reading, {len(unpaired)} have none by name" + ("" if "--unpaired" in sys.argv else " (list them with --unpaired)"))
    if "--unpaired" in sys.argv:
        for name in unpaired:
            print(f"  no _of_ version: {name}")


if __name__ == "__main__":
    main()
