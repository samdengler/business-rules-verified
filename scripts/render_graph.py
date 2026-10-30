#!/usr/bin/env python3
"""Render the Explore page, build/graph/index.html, served at /graph/.

The page has five views of the blueprint's graph, chosen by ?view= in the
address:

  area-map    one box per area with its status bar, and the dependencies
              between areas (the default);
  matrix      areas by areas, with the number of dependencies in each cell;
  all-cards   every card, with an arrow from each one to the cards that build
              on it, and lenses by area and by IATA capability;
  history     the milestones in history/, as clusters of dots by area;
  card        one card's neighbourhood: what it depends on and what builds
              on it.  A link ending in #<label> opens it.

layout() places the cards of the full graph in rows below the cards they use;
the page repeats it in the browser to draw a lens.  The area map, the matrix
and the clusters are drawn here by scripts/area_views.py; the page's script
(scripts/explore.js) draws the full graph and the neighbourhood and switches
between views.

Statuses come from build/status.json through scripts/render_progress.py, so
the page changes when the model does.
"""

import html
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_progress import classify, load_decls, parse_nodes, split_question  # noqa: E402
from site_nav import FAVICON, REPO, SITE_NAME, TOPBAR_CSS, topbar  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "graph" / "index.html"
HERE = Path(__file__).resolve().parent

CARD_W = 184          # card width
NAME_CHARS = 25       # characters per name line at 13/600
LINE = 17             # name line height


def wrap(text, width=NAME_CHARS):
    words, lines, cur = text.split(), [], ""
    for w in words:
        if cur and len(cur) + 1 + len(w) > width:
            lines.append(cur)
            cur = w
        else:
            cur = f"{cur} {w}".strip()
    return lines + [cur]


def card_height(lines):
    return 22 + LINE * len(lines) + 22


# The most cards side by side in one row of the graph.  Most candidate rules
# depend on the same few definitions, so ranking by dependency alone would put
# a hundred of them in one row; rows() spreads them over more rows.
ROW_MAX = 14


def rows(nodes, labels):
    """The row of each card: below every card it uses, in the first row from
    there with room.  Cards are placed by depth, then blueprint section, so
    each area's candidates stay together."""
    by_label = {n["label"]: n for n in nodes}
    depth = {}

    def d(label, seen=()):
        if label not in depth:
            ups = [u for u in by_label[label]["uses"] if u in labels and u not in seen]
            depth[label] = 1 + max((d(u, seen + (label,)) for u in ups), default=-1)
        return depth[label]

    row, count = {}, {}
    for n in sorted(nodes, key=lambda n: (d(n["label"]), n.get("section") or "", n["label"])):
        r = 1 + max((row[u] for u in n["uses"] if u in row), default=-1)
        while count.get(r, 0) >= ROW_MAX:
            r += 1
        row[n["label"]] = r
        count[r] = count.get(r, 0) + 1
    return row


GAP_X = 28   # between cards in a row
GAP_Y = 72   # between rows


def order_rows(nodes, labels, row):
    """Each row's cards from left to right.  A few sweeps of the barycentre
    heuristic put each card under the cards it uses, and over the cards that
    use it, which keeps connectors short and crossings few."""
    by_label = {n["label"]: n for n in nodes}
    used_by = {n["label"]: [] for n in nodes}
    for n in nodes:
        for u in n["uses"]:
            if u in labels:
                used_by[u].append(n["label"])
    last = max(row.values())
    order = [sorted((x for x, r in row.items() if r == i),
                    key=lambda x: (by_label[x].get("section") or "", x)) for i in range(last + 1)]

    def place():
        return {x: (i + 0.5) / len(r) for r in order for i, x in enumerate(r)}

    for _ in range(4):
        for rng, links in ((range(1, last + 1), lambda x: [u for u in by_label[x]["uses"] if u in labels]),
                           (range(last - 1, -1, -1), lambda x: used_by[x])):
            for i in rng:
                at = place()
                key = {x: (sum(at[y] for y in links(x)) / len(links(x)) if links(x) else at[x]) for x in order[i]}
                order[i].sort(key=lambda x: key[x])
    return order


def layout(nodes, labels):
    """Positions of the cards and the connector paths.  Cards sit in rows of
    at most ROW_MAX, each row centred; a connector runs from the bottom of a
    card to the top of a card that uses it."""
    row = rows(nodes, labels)
    order = order_rows(nodes, labels, row)
    heights = {n["label"]: card_height(n["lines"]) for n in nodes}
    slot = CARD_W + GAP_X
    width = max(len(r) for r in order) * slot - GAP_X
    pos, y = {}, 0
    for r in order:
        h = max(heights[x] for x in r)
        x0 = (width - (len(r) * slot - GAP_X)) / 2
        for i, x in enumerate(r):
            pos[x] = (round(x0 + i * slot + CARD_W / 2, 1), round(y + h / 2, 1))
        y += h + GAP_Y
    height = y - GAP_Y
    edges = []
    for n in nodes:
        for u in n["uses"]:
            if u not in labels:
                continue
            (x1, y1), (x2, y2) = pos[u], pos[n["label"]]
            y1 += heights[u] / 2
            y2 -= heights[n["label"]] / 2 + 2
            bend = min(GAP_Y, (y2 - y1) / 2)
            d = f"M{x1} {y1}C{x1} {round(y1 + bend, 1)} {x2} {round(y2 - bend, 1)} {x2} {y2}"
            edges.append((u, n["label"], d))
    return round(width + 32), round(height + 32), pos, edges


STATUS_WORDS = {
    "modelled": "In Lean",
    "proven": "Proven",
    "open": "Open question",
    "decision": "Needs a decision",
    "ready": "Ready to build",
    "waiting": "Waiting",
}




def details(m):
    """What the page knows about each card: its text for the side panel, what
    it uses and what uses it, and how far an answer to it reaches."""
    data = {}
    for n in m.nodes:
        desc, found, question, source = split_question(n)
        imp = m.impact(n["label"])
        data[n["label"]] = {
            "title": n["title"],
            "cid": n["cid"],
            "status": n["status"],
            "statusWords": STATUS_WORDS[n["status"]],
            "section": n["section"],
            "desc": desc,
            "found": found,
            "question": question,
            "source": source,
            "lean": n["lean"],
            "caps": n.get("caps", []),
            "readings": m.readings(n),
            "deps": [u for u in n["uses"] if u in m.by],
            "users": m.users[n["label"]],
            "down": imp["count"],
            "downAreas": len(imp["areas"]),
            "lines": n["lines"],
            "height": card_height(n["lines"]),
        }
    return data


CSS = """
:root { color-scheme: light;
  --page: #f9f9f7; --surface: #fcfcfb; --ink: #0b0b0b; --ink-2: #52514e; --muted: #898781;
  --hair: #e1e0d9; --ring: rgba(11,11,11,0.10); --axis: #b9b8b0;
  --good: #0ca30c; --lean: #e87ba4; --warning: #fab219; --critical: #d03b3b; --ready: #2a78d6; --waiting: #898781; }
@media (prefers-color-scheme: dark) { :root { color-scheme: dark;
  --page: #0d0d0d; --surface: #1a1a19; --ink: #f0efec; --ink-2: #c3c2b7; --muted: #898781;
  --hair: #2c2c2a; --ring: rgba(255,255,255,0.10); --axis: #55544f; --ready: #3987e5; } }
* { box-sizing: border-box; }
html, body { height: 100%; }
body { margin: 0; background: var(--page); color: var(--ink); display: flex; flex-direction: column;
  font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }
.intro { padding: 18px 28px 12px; display: flex; flex-wrap: wrap; align-items: flex-end; gap: 10px 32px; }
.intro h1 { font-size: 22px; line-height: 1.25; margin: 0 0 4px; letter-spacing: -0.01em; }
.intro p { margin: 0; color: var(--ink-2); max-width: 760px; font-size: 14px; }
.legend { display: flex; flex-wrap: wrap; gap: 6px 16px; font-size: 13px; color: var(--ink-2); }
.legend span { display: inline-flex; align-items: center; gap: 6px; }
.legend i { width: 10px; height: 10px; border-radius: 50%; background: var(--waiting); display: inline-block; }
.legend .s-modelled i { background: var(--lean); } .legend .s-proven i { background: var(--good); }
.legend .s-open i { background: var(--critical); } .legend .s-decision i { background: var(--warning); }
.legend .s-ready i { background: var(--ready); }
.lens { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; padding: 0 28px 12px; }
.lens button { font: 13px system-ui, sans-serif; color: var(--ink-2); background: var(--surface); border: 1px solid var(--ring);
  border-radius: 999px; padding: 3px 11px; cursor: pointer; }
.lens button span { color: var(--muted); font-variant-numeric: tabular-nums; margin-left: 2px; }
.lens button:hover { border-color: var(--axis); color: var(--ink); }
.lens button.on { background: var(--ink); color: var(--page); border-color: var(--ink); }
.lens button.on span { color: var(--page); opacity: .7; }
.lens .note { flex-basis: 100%; margin: 4px 2px 0; font-size: 13px; color: var(--muted); }
.lens .note strong { color: var(--ink-2); }
.lens .note a { color: var(--ready); }
.node.context { opacity: .45; }
.stage { position: relative; flex: 1; min-height: 420px; margin: 0 28px 24px; background: var(--surface);
  border: 1px solid var(--ring); border-radius: 10px; overflow: hidden; }
#graph { width: 100%; height: 100%; display: block; cursor: grab; touch-action: none; user-select: none; }
#graph.dragging { cursor: grabbing; }
.edge { fill: none; stroke: var(--axis); stroke-width: 1.25; transition: opacity .15s, stroke .15s; }
marker#arrow path { fill: var(--axis); }
marker#arrow-hot path { fill: var(--ink-2); }
.node { cursor: pointer; transition: opacity .15s; }
.node rect { fill: var(--surface); stroke: var(--axis); stroke-width: 1.25; }
.node .name { font-size: 13px; font-weight: 600; fill: var(--ink); }
.node .status { font-size: 11.5px; fill: var(--ink-2); }
.node .dot { fill: var(--waiting); }
/* Finished states get a lighter rim than the ones that need attention. */
.node.s-modelled rect { stroke: var(--lean); stroke-width: 1.5; fill: color-mix(in srgb, var(--lean) 7%, var(--surface)); }
.node.s-modelled .dot { fill: var(--lean); }
.node.s-proven rect { stroke: var(--good); stroke-width: 1.5; fill: color-mix(in srgb, var(--good) 8%, var(--surface)); }
.node.s-proven .dot { fill: var(--good); }
.node.s-open rect { stroke: var(--critical); stroke-width: 2; fill: color-mix(in srgb, var(--critical) 10%, var(--surface)); }
.node.s-open .dot { fill: var(--critical); }
.node.s-decision rect { stroke: var(--warning); stroke-width: 2; fill: color-mix(in srgb, var(--warning) 12%, var(--surface)); }
.node.s-decision .dot { fill: var(--warning); }
.node.s-ready rect { stroke: var(--ready); stroke-width: 2; fill: color-mix(in srgb, var(--ready) 10%, var(--surface)); }
.node.s-ready .dot { fill: var(--ready); }
.node.s-waiting rect { stroke-dasharray: 5 4; }
.node:hover rect, .node:focus rect { stroke-width: 2.5; }
.node:focus { outline: none; }
svg.focus .node, svg.focus .edge { opacity: .18; }
svg.focus .node.near, svg.focus .node.chosen { opacity: 1; }
svg.focus .edge.hot { opacity: 1; stroke: var(--ink-2); stroke-width: 1.75; }
.node.chosen rect { stroke-width: 3; }
.controls { position: absolute; left: 12px; bottom: 12px; display: flex; gap: 6px; align-items: center;
  background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 5px 10px 5px 6px; }
.controls button { font: 13px system-ui, sans-serif; color: var(--ink); background: var(--surface); border: 1px solid var(--ring);
  border-radius: 8px; padding: 4px 10px; cursor: pointer; }
.controls button:hover { border-color: var(--axis); }
.controls .hint { font-size: 12.5px; color: var(--muted); margin-left: 6px; }
.panel { position: absolute; top: 0; right: 0; bottom: 0; width: 380px; max-width: 90%; background: var(--surface);
  border-left: 1px solid var(--ring); padding: 18px 20px 24px; overflow-y: auto; transform: translateX(100%);
  transition: transform .2s; font-size: 14.5px; }
.panel.open { transform: none; }
.panel .close { position: absolute; top: 10px; right: 12px; border: none; background: none; color: var(--muted);
  font-size: 20px; cursor: pointer; }
:is(.panel, .nb-panel) .kicker { font-size: 12px; color: var(--muted); letter-spacing: .02em; margin: 0 0 4px; }
:is(.panel, .nb-panel) h2 { font-size: 18px; line-height: 1.3; margin: 0 28px 8px 0; }
:is(.panel, .nb-panel) .chip { font-size: 13px; margin-bottom: 10px; }
:is(.panel, .nb-panel) p { margin: 6px 0; color: var(--ink); }
:is(.panel, .nb-panel) .box { border-radius: 8px; padding: 8px 10px; margin: 10px 0; }
:is(.panel, .nb-panel) .box.question { background: color-mix(in srgb, var(--warning) 14%, transparent); }
:is(.panel, .nb-panel) .box.found { background: color-mix(in srgb, var(--critical) 11%, transparent); }
:is(.panel, .nb-panel) h3 { font-size: 12px; font-weight: 600; letter-spacing: .05em; text-transform: uppercase; color: var(--muted); margin: 16px 0 6px; }
:is(.panel, .nb-panel) ul { margin: 0; padding-left: 18px; }
:is(.panel, .nb-panel) li { margin: 3px 0; }
:is(.panel, .nb-panel) a { color: var(--ready); }
:is(.panel, .nb-panel) button.link { border: none; background: none; padding: 0; color: var(--ready); font: inherit; cursor: pointer; text-align: left; }
:is(.panel, .nb-panel) code { font: 12.5px ui-monospace, SFMono-Regular, Menlo, monospace; background: color-mix(in srgb, var(--ink) 6%, transparent);
  padding: 0 4px; border-radius: 4px; overflow-wrap: anywhere; }
"""


def legend(counts=None):
    return "".join(f'<span class="s-{k}"><i></i>{STATUS_WORDS[k]}{" " + str(counts[k]) if counts else ""}</span>'
                   for k in STATUS_WORDS if counts is None or counts[k])


def page(m, history):
    from area_views import AREA_CSS, COLS, DOT, area_map, clusters, matrix
    from graph_model import STATUS_ORDER, short, slug

    counts = m.counts()
    in_lean = counts["modelled"] + counts["proven"] + counts["open"]
    cap_cards = m.capabilities()
    data = {
        "site": SITE_NAME,
        "cards": details(m),
        "areas": [{"name": a, "short": short(a), "slug": slug(a), "count": len(m.area_nodes[a])} for a in m.order],
        "caps": {c: {**m.cap_names[c], "count": len(ids)} for c, ids in cap_cards.items()},
        "words": STATUS_WORDS,
        "order": STATUS_ORDER,
        "ranking": [{"id": r["node"]["label"], "count": r["count"]} for r in m.ranking(10)],
        "history": history["data"],
        "cardW": CARD_W, "line": LINE, "cols": COLS, "dot": DOT,
    }
    blob = json.dumps(data, separators=(",", ":")).replace("</", "<\\/")
    area_svg, hidden = area_map(m, STATUS_WORDS, lambda a: f"../area/{slug(a)}/")
    matrix_svg = matrix(m)
    cluster_svg = clusters(m, history["members"], history["statuses"], history["titles"], history["pairs"])
    ms = history["data"]["milestones"]
    steps = "".join(f'<button title="{html.escape(x["name"])}">{x["seq"]}</button>' for x in ms)
    lens = "".join(f'<button data-area="{html.escape(a)}">{html.escape(short(a))} <span>{len(m.area_nodes[a])}</span></button>'
                   for a in m.order)
    groups = {}
    for c in cap_cards:
        groups.setdefault(m.cap_names[c]["group"], []).append(c)
    options = "".join(
        f'<optgroup label="{html.escape(g)}">' + "".join(
            f'<option value="{c}">{c} {html.escape(m.cap_names[c]["name"])} ({len(cap_cards[c])})</option>' for c in cs)
        + "</optgroup>" for g, cs in groups.items())
    tabs = [("area-map", "Area map"), ("matrix", "Dependency matrix"), ("all-cards", "All cards"),
            ("history", "History"), ("card", "Card neighbourhood")]
    tab_html = "".join(f'<button role="tab" id="tab-{k}" data-view="{k}" aria-controls="view-{k}" aria-selected="false" '
                       f'tabindex="-1">{t}</button>' for k, t in tabs)
    css = CSS + AREA_CSS + (HERE / "explore.css").read_text()
    script = (HERE / "explore.js").read_text()
    back = sum(v for (a, b), v in m.pair.items() if a != b and m.is_back(a, b))
    status_legend = legend()
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Explore: {SITE_NAME}</title>
{FAVICON}
<style>{css}{TOPBAR_CSS}</style>
</head>
<body>
{topbar("Explore", "../", '<a class="local" href="../blueprint/">Blueprint chapters</a>')}
<div class="explore-bar">
  <div class="tabs" role="tablist" aria-label="Views of the model">{tab_html}</div>
  <div class="search" role="search">
    <label class="sr" for="search">Find a card</label>
    <input id="search" type="search" placeholder="Find a card by title, C-number or Lean name" autocomplete="off"
      role="combobox" aria-autocomplete="list" aria-controls="search-results" aria-expanded="false">
    <ul id="search-results" role="listbox" aria-label="Cards found" hidden></ul>
  </div>
</div>

<section class="view doc" id="view-area-map" role="tabpanel" aria-labelledby="tab-area-map" hidden>
  <div class="intro">
    <div>
      <h1>How the areas depend on each other</h1>
      <p>Each box is an area of the blueprint, with its cards counted by status. An arrow runs from an area to an area that
      builds on it, thicker for more dependencies, so the foundations sit at the top. Click an area to read its summary.</p>
    </div>
    <div class="legend">{status_legend}</div>
  </div>
  <div class="figure">{area_svg}</div>
  <p class="caption">The {len(m.order)} areas are the blueprint's sections, in {len(m.layers)} layers. Arrows stand for five or
  more dependencies; {hidden} smaller links are left out, and a number marks links of eight or more. A dashed arrow points
  back: the area it reaches comes earlier in the layers. The <a href="?view=matrix" data-view="matrix">dependency matrix</a>
  counts every link.</p>
</section>

<section class="view doc" id="view-matrix" role="tabpanel" aria-labelledby="tab-matrix" hidden>
  <div class="intro">
    <div>
      <h1>How many dependencies join each pair of areas</h1>
      <p>Each row is an area and each column an area it builds on; a cell counts the dependencies of the row's cards on the
      column's cards, and the outlined diagonal counts those inside an area. Rows and columns follow the layers of the area
      map, so most counts fall below the diagonal. Click a cell to list the cards behind its count.</p>
    </div>
    <div class="legend">{status_legend}<span class="key"><svg width="18" height="14" aria-hidden="true"><rect x="1" y="1" width="16" height="12" rx="3"
      fill="none" stroke="var(--critical)" stroke-width="2" stroke-dasharray="4 3"/></svg> Points back: {back} dependencies</span></div>
  </div>
  <div class="matrix-wrap">
    <div class="figure">{matrix_svg}</div>
    <div class="cell-list" aria-live="polite"></div>
  </div>
</section>

<section class="view" id="view-all-cards" role="tabpanel" aria-labelledby="tab-all-cards" hidden>
  <div class="intro">
    <div>
      <h1>All cards and their dependencies</h1>
      <p>Every definition, rule and guarantee in the blueprint, with an arrow from each one to the cards that build on it:
      {in_lean} are in Lean and {counts['decision']} candidate rules need a business decision. Pick an area or an IATA
      capability to see its cards and what they build on, or click a card to read it.</p>
    </div>
    <div class="legend">{legend(counts)}</div>
  </div>
  <nav class="lens" aria-label="Show one area or capability">
    <button data-area="">All areas <span>{len(m.nodes)}</span></button>{lens}
    <span class="sep" aria-hidden="true"></span>
    <label class="sr" for="cap">IATA capability</label>
    <select id="cap"><option value="">Any IATA capability</option>{options}</select>
    <p class="note" aria-live="polite"></p>
  </nav>
  <div class="stage">
    <svg id="graph" role="img" aria-label="Dependency graph of the blueprint"></svg>
    <div class="controls">
      <button data-zoom="in" aria-label="Zoom in">+</button>
      <button data-zoom="out" aria-label="Zoom out">&minus;</button>
      <button data-zoom="fit">Fit</button>
      <span class="hint">Drag to move. Pinch or Ctrl and scroll to zoom.</span>
    </div>
    <aside class="panel" aria-live="polite"><button class="close" aria-label="Close">&times;</button><div class="body"></div></aside>
  </div>
</section>

<section class="view" id="view-history" role="tabpanel" aria-labelledby="tab-history" hidden>
  <div class="intro">
    <div>
      <h1>How the model grew, in {len(ms)} milestones</h1>
      <p>Each dot is a card, in its area's box and in the color of its status at that milestone. Surveys of IATA's public
      material add candidate rules, mostly amber because the material leaves them to the business; writing an area in Lean
      turns its rules magenta and its guarantees green, or red where an example shows the rule breaking a guarantee.
      Click a dot to open its card.</p>
    </div>
    <div class="legend">{status_legend}</div>
  </div>
  <div class="player">
    <button class="play">Play</button>
    <button data-step="prev" aria-label="Previous milestone">&larr;</button>
    <button data-step="next" aria-label="Next milestone">&rarr;</button>
    <div class="steps" aria-label="Milestones">{steps}</div>
    <div class="caption-live" aria-live="polite"><h2></h2><span class="when"></span><p></p><div class="counts"></div></div>
  </div>
  <div class="history-stage">{cluster_svg}</div>
  <p class="note">Each milestone is a tagged commit, <code>milestone/&lt;name&gt;</code>; its snapshot is in
  <a href="{REPO}/tree/main/history">history/</a>. The <a href="{REPO}/blob/main/docs/motion-brief.md">motion brief</a>
  tells the same story for a motion piece.</p>
</section>

<section class="view" id="view-card" role="tabpanel" aria-labelledby="tab-card" hidden>
  <div class="intro">
    <div class="text"></div>
    <div class="legend">{status_legend}</div>
  </div>
  <div class="nb-stage">
    <div class="nb-main"><p class="nb-summary" aria-live="polite"></p><div class="nb-scroll"></div></div>
    <aside class="nb-panel" aria-live="polite" hidden><div class="body"></div></aside>
  </div>
</section>

<script type="application/json" id="explore-data">{blob}</script>
<script>{script}</script>
</body>
</html>
"""


def graph_data(nodes, labels):
    """The graph as data: every node with its status and what it uses.  The
    site publishes it at /graph/graph.json, and scripts/graph_history.py saves
    one per milestone for the motion piece (docs/motion-brief.md)."""
    return {
        "nodes": [{
            "id": n["label"],
            "title": n["title"],
            "candidate": n["cid"],
            "kind": "theorem" if n["env"] != "definition" else "definition",
            "chapter": n["chapter"],
            "area": n["section"],
            "status": n["status"],
            "statusWords": STATUS_WORDS[n["status"]],
            "lean": n["lean"],
            "uses": [u for u in n["uses"] if u in labels],
            "capabilities": n.get("caps", []),
        } for n in nodes],
    }


def main():
    from graph_model import Model
    from render_history import history_data
    decls = load_decls()
    nodes = parse_nodes()
    classify(nodes, decls)
    for n in nodes:
        n["lines"] = wrap(n["title"])
    labels = {n["label"] for n in nodes}
    m = Model(nodes, decls)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(page(m, history_data(m)))
    (OUT.parent / "graph.json").write_text(json.dumps(graph_data(nodes, labels), indent=1) + "\n")
    print(f"rendered {OUT.relative_to(ROOT)} and graph.json: {len(nodes)} nodes")


if __name__ == "__main__":
    main()
