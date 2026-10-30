#!/usr/bin/env python3
"""Render the progress page for business readers.

Reads build/status.json (written by `lake exe status`) and
blueprint/src/content.tex, and writes build/progress/index.html.

The page shows the rules and guarantees in the model and the candidate
rules from the ONE Order survey, each with a status in plain words:

  Modelled         a rule written in Lean
  Proven           a guarantee Lean has checked for every input
  Open question    a guarantee with no proof, marked as a question for the business
  Needs a decision a candidate the source states vaguely or not at all
  Ready to build   a candidate whose dependencies are all in Lean
  Waiting          a candidate that depends on candidates not yet in Lean

Nothing on the page is typed by hand: the statuses come from the build and
the text comes from the blueprint, so the page changes when the model does.
Needs graphviz (`dot`) for the dependency map.
"""

import html
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_status import section_tag  # noqa: E402
from site_nav import FAVICON, SITE_NAME, TOPBAR_CSS, topbar  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
STATUS = ROOT / "build" / "status.json"
CONTENT = ROOT / "blueprint" / "src" / "content.tex"
OUT = ROOT / "build" / "progress" / "index.html"
REPO = "https://github.com/samdengler/airline-order-verified"

DONE = {"definition", "proven"}

# Blueprint sections that hold supporting definitions rather than rules.
SKIP_SECTIONS = {"Core concepts"}

STATUSES = {
    # key: (label, icon, tile label)
    "modelled": ("Modelled", "✓", "rules in the model"),
    "proven": ("Proven", "✓", "guarantees proven"),
    "open": ("Open question", "!", "open question"),
    "decision": ("Needs a decision", "?", "need a business decision"),
    "ready": ("Ready to build", "→", "ready to build"),
    "waiting": ("Waiting", "…", "waiting on other rules"),
}

NODE_RE = re.compile(r"\\begin\{(definition|theorem|lemma)\}(?:\[([^\]]*)\])?(.*?)\\end\{\1\}", re.S)
HEAD_RE = re.compile(r"\\(chapter|section)\{([^}]*)\}")


def load_decls():
    if not STATUS.exists():
        sys.exit(f"{STATUS} not found; run `lake exe status` first")
    return {d["name"]: d for d in json.loads(STATUS.read_text())["declarations"]}


def arg(cmd, body):
    m = re.search(r"\\" + cmd + r"\{([^}]*)\}", body)
    return [x.strip() for x in m.group(1).split(",") if x.strip()] if m else []


def tex_html(s):
    s = html.escape(s, quote=False)
    s = re.sub(r"\\href\{([^}]*)\}\{([^}]*)\}", r'<a href="\1">\2</a>', s)
    s = re.sub(r"\\texttt\{([^}]*)\}", r"<code>\1</code>", s)
    s = re.sub(r"\\emph\{([^}]*)\}", r"<em>\1</em>", s)
    s = s.replace("\\%", "%").replace("~", " ")
    return re.sub(r"\s+", " ", s).strip()


def plain(s):
    return html.unescape(re.sub(r"<[^>]+>", "", s))


def parse_nodes(src=None):
    """The blueprint's nodes, from content.tex or from its text as given (for
    an earlier commit, in scripts/graph_history.py)."""
    src = CONTENT.read_text() if src is None else src
    heads = [(m.start(), m.group(1), m.group(2)) for m in HEAD_RE.finditer(src)]
    nodes = []
    for m in NODE_RE.finditer(src):
        chapter = next(t for p, k, t in reversed(heads) if p < m.start() and k == "chapter")
        section = next(t for p, k, t in reversed(heads) if p < m.start() and k == "section")
        body = m.group(3)
        title = m.group(2) or ""
        cid = re.search(r"\((C-\d+)\)$", title)
        text = re.sub(r"\\(label|lean|uses|discussion)\{[^}]*\}|\\notready", "", body)
        paras = [tex_html(p) for p in re.split(r"\n\s*\n", text) if p.strip()]
        nodes.append({
            "env": m.group(1),
            "label": arg("label", body)[0],
            "title": re.sub(r"\s*\(C-\d+\)$", "", title),
            "cid": cid.group(1) if cid else None,
            "lean": arg("lean", body),
            "uses": arg("uses", body),
            "notready": "\\notready" in body,
            "chapter": chapter,
            "section": section,
            "paras": paras,
        })
    return nodes


def is_done(node, decls):
    return bool(node["lean"]) and all(decls.get(n, {}).get("status") in DONE for n in node["lean"])


def classify(nodes, decls):
    by_label = {n["label"]: n for n in nodes}
    for n in nodes:
        if n["lean"]:
            states = {decls[x]["status"] for x in n["lean"]}
            n["status"] = "open" if "open" in states else ("proven" if n["env"] != "definition" else "modelled")
        elif n["notready"]:
            n["status"] = "decision"
        elif all(is_done(by_label[u], decls) for u in n["uses"] if u in by_label):
            n["status"] = "ready"
        else:
            n["status"] = "waiting"
        ears = [decls[x]["earsId"] for x in n["lean"] if decls.get(x, {}).get("earsId")]
        checks = [c for x in n["lean"] for c in decls.get(x, {}).get("checks", [])]
        n["tag"] = n["cid"] or (ears[0] if ears else None) or (("checks " + ", ".join(checks)) if checks else None)
        n["href"] = card_href(n, decls)
    return by_label


def shown(nodes, decls):
    """Rules (with an EARS statement), guarantees, and every survey candidate."""
    out = []
    for n in nodes:
        if n["section"] in SKIP_SECTIONS:
            continue
        has_ears = any(decls.get(x, {}).get("earsId") for x in n["lean"])
        if n["cid"] or n["env"] != "definition" or has_ears:
            out.append(n)
    return out


def split_question(n):
    """The description, the counterexample, the open point, and the source line."""
    desc, found, question, source = [], None, None, None
    for p in n["paras"]:
        if p.startswith("Counterexample:"):
            found = p.split(":", 1)[1].strip()
        elif p.startswith("Open point:"):
            question = p.split(":", 1)[1].strip()
        elif p.startswith(("Source:", "Sources:")):
            source = p.split(":", 1)[1].strip()
        else:
            desc.append(p)
    return desc, found, question, source


def chip(status):
    label, icon, _ = STATUSES[status]
    return f'<span class="chip s-{status}"><span class="ico" aria-hidden="true">{icon}</span>{label}</span>'


def card_href(n, decls):
    """Where a card leads, found by Verso's own lookup so a moved chapter keeps
    working: a rule opens its requirement chapter at the top, a guarantee its
    section in that chapter (tags from scripts/render_status.py), and a
    candidate without Lean its node in the dependency graph."""
    find = "./review/find/?domain=Verso.Genre.Manual.section&name="
    if n["lean"]:
        ears = decls.get(n["lean"][0], {}).get("earsId")
        if ears:
            return find + quote(ears.lower())
        if n["env"] != "definition":
            return find + quote(section_tag("guarantee", n["lean"][0]))
        return "./review/find/?domain=Verso.Genre.Manual.doc&name=" + quote(n["lean"][0])
    return "./graph/#" + quote(n["label"])


def card(n):
    desc, found, question, source = split_question(n)
    tag = f'<span class="tag">{html.escape(n["tag"])}</span>' if n["tag"] else ""
    q = (f'<p class="found-line"><strong>Counterexample:</strong> {found}</p>' if found else "") + (
        f'<p class="question"><strong>Open point:</strong> {question}</p>' if question else "")
    src = f'<p class="source">Source: {source}</p>' if source else ""
    return f"""<article class="card s-{n['status']}">
  <header>{tag}{chip(n['status'])}</header>
  <h4><a class="card-link" href="{html.escape(n['href'])}">{html.escape(n['title'])}</a></h4>
  <p>{' '.join(desc)}</p>
  {q}{src}
</article>"""


def wrap(s, width=22):
    words, lines, cur = s.split(), [], ""
    for w in words:
        if cur and len(cur) + 1 + len(w) > width:
            lines.append(cur)
            cur = w
        else:
            cur = f"{cur} {w}".strip()
    return "\\n".join(lines + [cur])


def dep_map(show, by_label):
    ids = {n["label"]: f"n{i}" for i, n in enumerate(show)}
    lines = [
        "digraph G {",
        '  graph [rankdir=TB, concentrate=true, bgcolor="transparent", nodesep=0.18, ranksep=0.4, fontname="Helvetica", fontsize=11, pad=0.1];',
        '  node [shape=box, style="rounded,filled", fontname="Helvetica", fontsize=10.5, margin="0.10,0.05", height=0.3, penwidth=1.4];',
        '  edge [arrowsize=0.55, penwidth=0.8];',
    ]
    for n in show:
        tip = plain(" ".join(split_question(n)[0])).replace('"', "'")
        lines.append(f'  {ids[n["label"]]} [label="{wrap(n["title"])}", class="s-{n["status"]}", tooltip="{tip}", '
                     f'href="{n["href"]}"];')
    for n in show:
        for u in n["uses"]:
            if u in ids:
                lines.append(f'  {ids[u]} -> {ids[n["label"]]};')
    lines.append("}")
    svg = subprocess.run(["dot", "-Tsvg"], input="\n".join(lines), capture_output=True, text=True, check=True).stdout
    svg = svg[svg.index("<svg"):]
    # Graphviz titles every element with its internal ID ("n0", "n0->n2"), which browsers
    # show on hover; the node tooltips carry the descriptions instead.
    svg = re.sub(r"<title>[^<]*</title>\n?", "", svg)
    # Colors come from the page's stylesheet so the map follows light and dark mode.
    svg = re.sub(r' (fill|stroke)="(?!none)[^"]*"', "", svg)
    return svg.replace("<svg ", '<svg class="map" ', 1)


CSS = """
:root { color-scheme: light;
  --page: #f9f9f7; --surface: #fcfcfb; --ink: #0b0b0b; --ink-2: #52514e; --muted: #898781;
  --hair: #e1e0d9; --ring: rgba(11,11,11,0.10);
  --good: #0ca30c; --lean: #e87ba4; --warning: #fab219; --critical: #d03b3b; --ready: #2a78d6; --waiting: #898781; }
@media (prefers-color-scheme: dark) { :root { color-scheme: dark;
  --page: #0d0d0d; --surface: #1a1a19; --ink: #f0efec; --ink-2: #c3c2b7; --muted: #898781;
  --hair: #2c2c2a; --ring: rgba(255,255,255,0.10); --ready: #3987e5; } }
* { box-sizing: border-box; }
body { margin: 0; background: var(--page); color: var(--ink);
  font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }
main { max-width: 1180px; margin: 0 auto; padding: 32px 28px 64px; }
.site-topbar { position: sticky; top: 0; z-index: 10; }
a { color: var(--ready); }
code { font: 0.86em ui-monospace, SFMono-Regular, Menlo, monospace; background: color-mix(in srgb, var(--ink) 6%, transparent);
  padding: 0 4px; border-radius: 4px; white-space: nowrap; }
.kicker { color: var(--muted); font-size: 13px; letter-spacing: .02em; margin: 0 0 6px; }
h1 { font-size: 30px; line-height: 1.2; margin: 0 0 10px; letter-spacing: -0.01em; }
.lede { color: var(--ink-2); max-width: 760px; margin: 0 0 14px; }
.links { display: flex; flex-wrap: wrap; gap: 8px 18px; font-size: 14px; margin-bottom: 28px; }
h2 { font-size: 20px; margin: 44px 0 6px; }
h2 + .sub { color: var(--ink-2); margin: 0 0 16px; max-width: 760px; }
h3 { font-size: 15px; margin: 26px 0 10px; color: var(--ink-2); font-weight: 600; }
.tiles { display: grid; grid-template-columns: repeat(6, 1fr); gap: 10px; }
.tile { background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 14px 14px 12px; }
.tile .n { font-size: 32px; font-weight: 650; line-height: 1; display: flex; align-items: center; gap: 8px; }
.tile .l { color: var(--ink-2); font-size: 13px; margin-top: 6px; }
.bar { display: flex; gap: 2px; height: 10px; margin: 14px 0 0; }
.bar span { border-radius: 2px; }
.bar span:first-child { border-radius: 4px 2px 2px 4px; } .bar span:last-child { border-radius: 2px 4px 4px 2px; }
.ico { display: inline-grid; place-items: center; width: 18px; height: 18px; border-radius: 50%;
  font-size: 11px; font-weight: 800; color: #fff; flex: none; }
.tile .ico { width: 22px; height: 22px; font-size: 13px; }
.s-modelled .ico, .bar .s-modelled { background: var(--lean); }
.s-proven .ico, .bar .s-proven { background: var(--good); }
.s-open .ico, .bar .s-open { background: var(--critical); }
.s-decision .ico, .bar .s-decision { background: var(--warning); color: #0b0b0b; }
.s-ready .ico, .bar .s-ready { background: var(--ready); }
.s-waiting .ico, .bar .s-waiting { background: var(--waiting); }
.found { background: var(--surface); border: 1px solid var(--ring); border-left: 4px solid var(--critical);
  border-radius: 10px; padding: 16px 20px; margin-top: 12px; }
.found h4 { margin: 0 0 6px; font-size: 16px; }
.found p { margin: 6px 0; }
.board { display: grid; grid-template-columns: repeat(auto-fill, minmax(268px, 1fr)); gap: 10px; }
.card { background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 12px 14px;
  border-top: 3px solid var(--waiting); font-size: 14px; }
.card.s-modelled { border-top-color: var(--lean); }
.card.s-proven { border-top-color: var(--good); }
.card.s-open { border-top-color: var(--critical); }
.card.s-decision { border-top-color: var(--warning); }
.card.s-ready { border-top-color: var(--ready); }
/* The title's link covers the whole card; links inside it sit above. */
.card { position: relative; transition: border-color .15s; }
.card:hover { border-color: color-mix(in srgb, var(--ready) 45%, var(--ring)); }
.card h4 a.card-link, .card h4 a.card-link:visited { color: var(--ink); text-decoration: none; }
.card h4 a.card-link::after { content: ""; position: absolute; inset: 0; border-radius: 10px; }
.card h4 a.card-link:focus-visible::after { outline: 2px solid var(--ready); outline-offset: 2px; }
.card .source a, .card .question a, .card .found-line a { position: relative; z-index: 1; }
.card header { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.card h4 { margin: 8px 0 4px; font-size: 15px; line-height: 1.3; }
.card p { margin: 4px 0; color: var(--ink-2); }
.card .question { color: var(--ink); background: color-mix(in srgb, var(--warning) 14%, transparent);
  border-radius: 6px; padding: 6px 8px; margin-top: 8px; }
.card .found-line { color: var(--ink); background: color-mix(in srgb, var(--critical) 12%, transparent);
  border-radius: 6px; padding: 6px 8px; margin-top: 8px; }
.card .source { font-size: 12.5px; color: var(--muted); }
.tag { font-size: 12px; color: var(--muted); font-variant-numeric: tabular-nums; }
.chip { display: inline-flex; align-items: center; gap: 6px; font-size: 12.5px; font-weight: 600; color: var(--ink); }
.legend { display: flex; flex-wrap: wrap; gap: 8px 18px; margin: 4px 0 12px; }
.mapwrap { background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 12px; overflow-x: auto; }
svg.map { display: block; margin: 0 auto; max-width: 100%; height: auto; }
svg.map text { fill: var(--ink); }
svg.map .cluster path, svg.map .cluster polygon { fill: none; stroke: var(--hair); }
svg.map .cluster text { fill: var(--muted); font-weight: 600; }
svg.map .edge path { stroke: var(--muted); fill: none; } svg.map .edge polygon { fill: var(--muted); stroke: var(--muted); }
svg.map .node path, svg.map .node polygon { fill: var(--surface); stroke: var(--waiting); }
svg.map .node.s-modelled path { fill: color-mix(in srgb, var(--lean) 14%, var(--surface)); stroke: var(--lean); }
svg.map .node.s-proven path { fill: color-mix(in srgb, var(--good) 16%, var(--surface)); stroke: var(--good); }
svg.map .node.s-open path { fill: color-mix(in srgb, var(--critical) 14%, var(--surface)); stroke: var(--critical); }
svg.map .node.s-decision path { fill: color-mix(in srgb, var(--warning) 20%, var(--surface)); stroke: var(--warning); }
svg.map .node.s-ready path { fill: color-mix(in srgb, var(--ready) 12%, var(--surface)); stroke: var(--ready); }
footer { margin-top: 48px; color: var(--muted); font-size: 13px; }
@media (max-width: 900px) { .tiles { grid-template-columns: repeat(3, 1fr); } }
"""


def page(show, by_label, decls):
    counts = {k: sum(1 for n in show if n["status"] == k) for k in STATUSES}
    tiles = "".join(
        f'<div class="tile s-{k}"><div class="n"><span class="ico" aria-hidden="true">{STATUSES[k][1]}</span>{counts[k]}</div>'
        f'<div class="l">{STATUSES[k][2] if counts[k] != 1 or k != "open" else "open question"}</div></div>'
        for k in STATUSES)
    total = len(show)
    bar = "".join(
        f'<span class="s-{k}" style="flex:{counts[k]}" title="{STATUSES[k][0]}: {counts[k]} of {total}"></span>'
        for k in STATUSES if counts[k])
    def found_box(n):
        desc, ce, question, _ = split_question(n)
        return (f'<div class="found"><h4>{html.escape(n["title"])}</h4><p>{" ".join(desc)}</p>'
                f'<p><strong>Counterexample:</strong> {ce}</p><p><strong>Open point:</strong> {question}</p></div>')
    found = "".join(found_box(n) for n in show if n["status"] == "open")
    groups = []
    for chapter in dict.fromkeys(n["chapter"] for n in show):
        secs = dict.fromkeys(n["section"] for n in show if n["chapter"] == chapter)
        head = "In the model today" if chapter != "ONE Order rules from the survey" else "Next: candidate rules from the ONE Order survey"
        body = "".join(
            f"<h3>{html.escape(s)}</h3><div class=\"board\">" + "".join(card(n) for n in show if n["section"] == s) + "</div>"
            for s in secs)
        groups.append(f'<h2 id="{'today' if 'today' in head else 'next'}">{head}</h2>{body}')
    legend = "".join(chip(k) for k in STATUSES)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{SITE_NAME}: progress</title>
{FAVICON}
<style>{CSS}{TOPBAR_CSS}</style>
</head>
<body>
{topbar("Progress", "./")}
<main>
<p class="kicker">Proof of concept · built from public IATA ONE Order material · not affiliated with IATA</p>
<h1>{SITE_NAME} rules, checked by Lean</h1>
<p class="lede">Each business rule here is written as code in Lean, a language that checks proofs.
A <strong>proven</strong> guarantee holds for every possible input, not only the cases someone thought to test.
An <strong>open question</strong> is a guarantee the rules as written do not meet. An example the build computes shows the failing case, and the business decides what the rule should do.
This page is generated from the model on every build.</p>
<nav class="links" aria-label="Also on this site">
  <a href="./review/">Read the rules in the review document</a>
  <a href="{REPO}/tree/main/.kiro/specs">Requirement specs</a>
  <a href="./ears-criteria.csv">Acceptance criteria (CSV)</a>
  <a href="{REPO}/blob/main/docs/one-order-survey.md">ONE Order survey</a>
</nav>
<div class="tiles">{tiles}</div>
<div class="bar" role="img" aria-label="Status of {total} rules and guarantees">{bar}</div>

<h2 id="found">Open questions</h2>
<p class="sub">A guarantee the business expected to hold, and an example where the rules as written break it.</p>
{found}
{''.join(groups)}

<h2 id="map">How the rules depend on each other</h2>
<p class="sub">An arrow points from a rule to the rules that build on it. A rule can only be written in Lean once
everything it depends on is, so the map shows what to build next. Hover over a box for its description, or open the <a href="./graph/">dependency graph</a> to read every rule and definition.</p>
<div class="legend">{legend}</div>
<div class="mapwrap">{dep_map(show, by_label)}</div>

<footer>Generated by <code>scripts/render_progress.py</code> from the Lean build and the blueprint.
Statuses are computed; nothing on this page is typed by hand.</footer>
</main>
</body>
</html>
"""


def main():
    decls = load_decls()
    nodes = parse_nodes()
    by_label = classify(nodes, decls)
    show = shown(nodes, decls)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(page(show, by_label, decls))
    counts = {k: sum(1 for n in show if n["status"] == k) for k in STATUSES}
    print(f"rendered {OUT.relative_to(ROOT)}: " + ", ".join(f"{v} {k}" for k, v in counts.items()))


if __name__ == "__main__":
    main()
