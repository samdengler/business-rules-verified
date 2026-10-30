#!/usr/bin/env python3
"""Render the guided tour, build/tour/index.html, served at /tour/.

Five steps for a business reader, each with a sentence or two and a view:
how many cards there are, how the areas build on each other, where the
decisions sit, one open question with the example that breaks it, and what
an answer to it reaches.  The page is static: every step is on the page at
once, and nothing moves.

The open question is QUESTION, the pilot's refund guarantee.  The build
stops if it is no longer open, since the tour's text would then be wrong;
pick another open guarantee with an example and a clear question.
"""

import html
import sys
from pathlib import Path
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parent))
from area_views import AREA_CSS, area_map, neighbourhood  # noqa: E402
from graph_model import Model, docstring_html, short, slug  # noqa: E402
from render_progress import CSS as PAGE_CSS, STATUSES, decide_first, split_question  # noqa: E402
from render_status import blueprint_titles, field_label, humanize, inline, parse_value  # noqa: E402
from site_nav import FAVICON, SITE_NAME, TOPBAR_CSS, topbar  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "tour" / "index.html"
QUESTION = "Rules.OfferOrder.refunds_le_payments"
WORDS = {k: v[0] for k, v in STATUSES.items()}
esc = html.escape

CSS = """
main.tour { max-width: 1180px; }
.tour .step { border-top: 1px solid var(--ring); padding: 30px 0 8px; margin-top: 30px; }
.tour .num { font-size: 13px; color: var(--muted); font-variant-numeric: tabular-nums; margin: 0 0 4px; letter-spacing: .02em; }
.tour .step h2 { margin: 0 0 8px; font-size: 22px; }
.tour .step > p { max-width: 760px; color: var(--ink-2); margin: 6px 0; }
.tour figure { margin: 16px 0 8px; background: var(--surface); border: 1px solid var(--ring); border-radius: 12px; padding: 16px;
  overflow-x: auto; }
.tour figure svg.map { min-width: 760px; }
.tour figure svg.nbh { width: 100%; height: auto; min-width: 980px; }
.tour figcaption { font-size: 13px; color: var(--ink-2); margin-top: 8px; }
.tour .more { font-size: 14px; margin: 10px 0 0; }
.tour .more a { font-weight: 600; }
.tour .ranking { margin-top: 14px; }
.example { display: grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1fr); gap: 14px; margin-top: 14px; }
.example .panel { background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 12px 16px; }
.example .panel h3 { margin: 0 0 6px; font-size: 12px; font-weight: 600; letter-spacing: .05em; text-transform: uppercase; color: var(--muted); }
.example .panel p { margin: 6px 0; }
.example dl { display: grid; grid-template-columns: auto 1fr; gap: 4px 14px; margin: 4px 0 0; }
.example dt { color: var(--ink-2); }
.example dd { margin: 0; font-weight: 600; font-variant-numeric: tabular-nums; }
.example .breaks { border-left: 4px solid var(--critical); }
.callout { background: color-mix(in srgb, var(--warning) 14%, transparent); border-radius: 8px; padding: 10px 14px; margin: 14px 0 0;
  max-width: 820px; }
.tour .ends { list-style: none; padding: 0; display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; }
.tour .ends li { background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 12px 14px; font-size: 14px;
  color: var(--ink-2); }
.tour .ends a { display: block; font-weight: 600; font-size: 15px; margin-bottom: 2px; }
@media (max-width: 760px) { .example, .tour .ends { grid-template-columns: 1fr; } }
"""


def example_of(decls, theorem):
    """The example that shows the rule breaking the guarantee: a case that
    checks one of its criteria, as render_status.py finds it."""
    checks = set(theorem.get("checks", []))
    cases = sorted((d for d in decls.values() if d["kind"] == "case" and checks & set(d.get("checks", []))),
                   key=lambda d: d["name"])
    return cases[0] if cases else None


def given_when_then(doc):
    """The example's docstring, paragraph by paragraph."""
    return [docstring_html(p) for p in (doc or "").split("\n\n") if p.strip()]


def computed(value):
    try:
        v = parse_value(value)
    except (ValueError, IndexError, KeyError, TypeError):
        return f"<p><code>{esc(value)}</code></p>"
    if isinstance(v, dict) and "record" in v:
        rows = "".join(f"<dt>{esc(field_label(k))}</dt><dd>{esc(inline(x))}</dd>" for k, x in v["record"].items())
        return f"<dl>{rows}</dl>"
    return f"<p>{esc(inline(v))}</p>"


def tiles(counts):
    out = []
    for k in STATUSES:
        out.append(f'<div class="tile s-{k}"><div class="n"><span class="ico" aria-hidden="true">{STATUSES[k][1]}</span>'
                   f'{counts[k]}</div><div class="l">{WORDS[k].lower()}</div></div>')
    total = sum(counts.values())
    bar = "".join(f'<span class="s-{k}" style="flex:{counts[k]}" title="{WORDS[k]}: {counts[k]} of {total}"></span>'
                  for k in STATUSES if counts[k])
    return (f'<div class="tiles">{"".join(out)}</div>'
            f'<div class="bar" role="img" aria-label="Status of {total} cards">{bar}</div>')


def plural(k, one, many):
    return f"{k} {one if k == 1 else many}"


def page(m):
    decls = m.decls
    theorem = decls.get(QUESTION)
    if not theorem or theorem["status"] != "open":
        sys.exit(f"scripts/render_tour.py: {QUESTION} is no longer open; choose another open question for step 4")
    card = next(n for n in m.nodes if QUESTION in n["lean"])
    example = example_of(decls, theorem)
    if not example:
        sys.exit(f"scripts/render_tour.py: no example checks a criterion of {QUESTION}")
    rule = next((d for d in decls.values() if d.get("earsId") and
                 any(c["id"] in theorem["checks"] for c in d.get("criteria", []))), None)
    chapter = blueprint_titles().get(rule["name"], humanize(rule["name"].rsplit(".", 1)[-1])) if rule else None
    chapter_href = "../review/find/?domain=Verso.Genre.Manual.section&name=" + quote(rule["earsId"].lower()) if rule else "../review/"

    counts = m.counts()
    total = sum(counts.values())
    in_lean = counts["modelled"] + counts["proven"] + counts["open"]
    desc, _, question, _ = split_question(card)
    impact = m.impact(card["label"])
    gwt = given_when_then(example.get("docstring"))
    map_svg, _ = area_map(m, WORDS, lambda a: f"../area/{slug(a)}/", marker="tour-map")
    nb_svg, _ = neighbourhood(m, card["label"], WORDS, lambda x: "../graph/#" + quote(x), up_steps=1,
                              pill_w=204, gap_x=40)
    rank_of = next((i + 1 for i, r in enumerate(m.ranking()) if r["node"]["label"] == card["label"]), None)
    areas = [short(a) for a in impact["areas"]]
    open_count = sum(1 for d in decls.values() if d["status"] == "open")

    steps = [
        ("The cards in the model, by status",
         f"""<p>The model is a set of cards: definitions and rules written in Lean, guarantees about those rules, and
         candidate rules found in IATA's public ONE Order material. The dependency graph has {total} cards in
         {len(m.order)} areas, and the build gives each one a status.</p>
         <p>{plural(in_lean, "card is", "cards are")} in Lean. {plural(counts["proven"], "guarantee is", "guarantees are")}
         proven: Lean checked a proof that holds for every input. {plural(counts["open"], "is an open question", "are open questions")},
         and {plural(counts["decision"], "candidate rule needs", "candidate rules need")} a business decision before
         {"it" if counts["decision"] == 1 else "they"} can be written.</p>
         <figure>{tiles(counts)}</figure>""",
         '<a href="../progress/">See every rule and guarantee on the progress page</a>'),
        ("How the areas build on each other",
         f"""<p>The cards fall into {len(m.order)} areas, the sections of the blueprint. The foundations sit at the top, and each
         layer builds on the ones above it. An arrow runs from an area to an area that builds on it, thicker for more
         dependencies. Click an area to read its summary.</p>
         <figure>{map_svg}<figcaption>Arrows stand for five or more dependencies. A dashed arrow points back to an area
         that comes earlier in the layers.</figcaption></figure>""",
         '<a href="../graph/?view=area-map">Open the area map</a> · <a href="../graph/?view=matrix">count the dependencies in the matrix</a>'),
        ("The decisions that reach the most cards",
         f"""<p>{plural(counts["open"], "open question", "open questions")} and {plural(counts["decision"], "candidate rule",
         "candidate rules")} wait for the business. Some sit under many other cards, so an answer to them reaches further.
         These five have the most cards depending on them, directly or through other cards.</p>
         {decide_first(m, "../", 5)}""",
         '<a href="../progress/#decide">See the top ten on the progress page</a>'),
        (esc(card["title"]),
         f"""<p>{" ".join(desc)} This guarantee is open: the rule as written does not meet it. An example shows the rule
         breaking it.</p>
         <div class="example">
           <div class="panel"><h3>The example</h3>{"".join(f"<p>{p}</p>" for p in gwt)}</div>
           <div class="panel breaks"><h3>What the rule gives</h3>{computed(example.get("value") or "")}
           <p>Lean computes this result from the rule, on every build.</p></div>
         </div>
         <p class="callout"><strong>Open point:</strong> {question}</p>""",
         f'<a href="{chapter_href}">Read {esc(chapter or "its chapter")} in the review document</a>, where you can try the rule'),
        ("The cards that depend on this question",
         f"""<p>{plural(impact["count"], "card builds", "cards build")} on this guarantee, directly or through other cards, in {plural(len(areas), "area", "areas")}: {esc(", ".join(areas))}. Whatever the business decides
         reaches each of them{f", which puts it at number {rank_of} in the ranking" if rank_of else ""}. The cards it
         uses directly are to the left; the cards that build on it are to the right, nearest first.</p>
         <figure>{nb_svg}</figure>
         <p>For some open questions, Lean already proves the guarantee under one reading of the sources. The card then shows
         that reading under <strong>If we decide this</strong>, on the Explore page and on its area's summary.
         {len(m.pairs)} of the {open_count} open guarantees have one.</p>""",
         f'<a href="../graph/#{quote(card["label"])}">Open its neighbourhood on the Explore page</a>'),
    ]
    body = "".join(
        f'<section class="step" id="step-{i}"><p class="num">Step {i} of {len(steps)}</p><h2>{head}</h2>{text}'
        f'<p class="more">{more}</p></section>'
        for i, (head, text, more) in enumerate(steps, 1))
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>A tour of the model: {SITE_NAME}</title>
{FAVICON}
<style>{PAGE_CSS}{AREA_CSS}{CSS}{TOPBAR_CSS}</style>
</head>
<body>
{topbar(None, "../")}
<main class="tour">
<p class="kicker">Guided tour · {len(steps)} steps</p>
<h1>A tour of the model in {len(steps)} steps</h1>
<p class="lede">The business rules for airline offers and orders are written in Lean, a language that checks proofs. This tour
shows how much the model holds, how its parts depend on each other, and where it needs a decision from the business. Each step
links to the page where you can look further.</p>
{body}
<section class="step" id="next">
<h2>Other pages</h2>
<ul class="ends">
  <li><a href="../progress/">Progress</a>Every rule, guarantee and candidate with its status, and the open questions.</li>
  <li><a href="../graph/">Explore</a>The area map, the dependency matrix, every card, the history, and any card's neighbourhood.</li>
  <li><a href="../review/">Review document</a>A chapter per requirement, with its guarantees, examples and questions.</li>
</ul>
</section>
<footer>Generated by <code>scripts/render_tour.py</code> from the Lean build and the blueprint.
Statuses, counts and the example's result are computed; nothing on this page is typed by hand.</footer>
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
