#!/usr/bin/env python3
"""Render the dependency graph page, build/graph/index.html.

Every node of the blueprint (blueprint/src/content.tex) is drawn as a card
with its title and its status, and every \\uses as a connector from the node
used to the node that uses it.  Graphviz computes the positions only; the page
draws the cards and connectors itself, in the style of the progress page, and
lets the reader move, zoom and open a node to read its statement.

Statuses come from build/status.json through scripts/render_progress.py, so
the page changes when the model does.  Needs graphviz (`dot` and `unflatten`).
"""

import html
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_progress import classify, load_decls, parse_nodes, split_question  # noqa: E402
from site_nav import TOPBAR_CSS, topbar  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "build" / "graph" / "index.html"

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


def layout(nodes, labels):
    """Positions of the cards and the connector paths, from Graphviz."""
    out = ["digraph G {",
           "graph [rankdir=TB, nodesep=0.28, ranksep=0.62, splines=spline];",
           'node [shape=box, fixedsize=true, label=""];']
    for n in nodes:
        out.append(f'"{n["label"]}" [width={CARD_W / 72:.3f}, height={card_height(n["lines"]) / 72:.3f}];')
    for n in nodes:
        for u in n["uses"]:
            if u in labels:
                out.append(f'"{u}" -> "{n["label"]}";')
    out.append("}")
    src = subprocess.run(["unflatten", "-l", "3"], input="\n".join(out), capture_output=True, text=True, check=True).stdout
    g = json.loads(subprocess.run(["dot", "-Tjson"], input=src, capture_output=True, text=True, check=True).stdout)
    _, _, width, height = (float(v) for v in g["bb"].split(","))
    flip = lambda x, y: (round(float(x), 1), round(height - float(y), 1))
    pos = {}
    for o in g["objects"]:
        x, y = flip(*o["pos"].split(","))
        pos[o["name"]] = (x, y)
    edges = []
    for e in g["edges"]:
        tail, head = g["objects"][e["tail"]]["name"], g["objects"][e["head"]]["name"]
        parts = e["pos"].split()
        end = None
        if parts[0].startswith("e,"):
            end = flip(*parts[0][2:].split(","))
            parts = parts[1:]
        pts = [flip(*p.split(",")) for p in parts]
        d = f"M{pts[0][0]} {pts[0][1]}"
        for i in range(1, len(pts) - 2, 3):
            d += f"C{pts[i][0]} {pts[i][1]} {pts[i + 1][0]} {pts[i + 1][1]} {pts[i + 2][0]} {pts[i + 2][1]}"
        if end:
            d += f"L{end[0]} {end[1]}"
        edges.append((tail, head, d))
    return round(width + 32), round(height + 32), pos, edges


STATUS_WORDS = {
    "modelled": "In Lean",
    "proven": "Proven",
    "open": "Open question",
    "decision": "Needs a decision",
    "ready": "Ready to build",
    "waiting": "Waiting",
}


def svg(nodes, width, height, pos, edges):
    out = [f'<svg id="graph" viewBox="-16 -16 {width} {height}" role="img" aria-label="Dependency graph of the blueprint">',
           '<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" '
           'orient="auto-start-reverse"><path d="M0 0L10 5L0 10z"/></marker>'
           '<marker id="arrow-hot" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" '
           'orient="auto-start-reverse"><path d="M0 0L10 5L0 10z"/></marker></defs>',
           '<g class="edges">']
    for tail, head, d in edges:
        out.append(f'<path class="edge" data-from="{html.escape(tail)}" data-to="{html.escape(head)}" d="{d}" marker-end="url(#arrow)"/>')
    out.append('</g><g class="nodes">')
    for n in nodes:
        x, y = pos[n["label"]]
        h = card_height(n["lines"])
        x0, y0 = x - CARD_W / 2, y - h / 2
        out.append(f'<g class="node s-{n["status"]}" data-id="{html.escape(n["label"])}" tabindex="0" role="button" '
                   f'aria-label="{html.escape(n["title"])}, {STATUS_WORDS[n["status"]]}">')
        out.append(f'<rect x="{x0}" y="{y0}" width="{CARD_W}" height="{h}" rx="8"/>')
        for i, line in enumerate(n["lines"]):
            out.append(f'<text class="name" x="{x0 + 14}" y="{y0 + 24 + LINE * i}">{html.escape(line)}</text>')
        sy = y0 + 24 + LINE * len(n["lines"]) + 4
        tag = f'{n["cid"]} · ' if n["cid"] else ""
        out.append(f'<circle class="dot" cx="{x0 + 18}" cy="{sy - 4}" r="4"/>')
        out.append(f'<text class="status" x="{x0 + 28}" y="{sy}">{html.escape(tag + STATUS_WORDS[n["status"]])}</text>')
        out.append("</g>")
    out.append("</g></svg>")
    return "\n".join(out)


def details(nodes, labels, decls):
    """What the side panel shows for each node."""
    by = {n["label"]: n for n in nodes}
    used_by = {n["label"]: [] for n in nodes}
    for n in nodes:
        for u in n["uses"]:
            if u in labels:
                used_by[u].append(n["label"])
    data = {}
    for n in nodes:
        desc, found, question, source = split_question(n)
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
            "deps": [u for u in n["uses"] if u in by],
            "users": used_by[n["label"]],
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
.intro { padding: 20px 28px 12px; display: flex; flex-wrap: wrap; align-items: flex-end; gap: 12px 32px; }
.intro h1 { font-size: 22px; line-height: 1.25; margin: 0 0 4px; letter-spacing: -0.01em; }
.intro p { margin: 0; color: var(--ink-2); max-width: 720px; font-size: 14px; }
.legend { display: flex; flex-wrap: wrap; gap: 6px 16px; font-size: 13px; color: var(--ink-2); }
.legend span { display: inline-flex; align-items: center; gap: 6px; }
.legend i { width: 10px; height: 10px; border-radius: 50%; background: var(--waiting); display: inline-block; }
.legend .s-modelled i { background: var(--lean); } .legend .s-proven i { background: var(--good); }
.legend .s-open i { background: var(--critical); } .legend .s-decision i { background: var(--warning); }
.legend .s-ready i { background: var(--ready); }
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
.panel .kicker { font-size: 12px; color: var(--muted); letter-spacing: .02em; margin: 0 0 4px; }
.panel h2 { font-size: 18px; line-height: 1.3; margin: 0 28px 8px 0; }
.panel .chip { display: inline-flex; align-items: center; gap: 6px; font-size: 13px; font-weight: 600; margin-bottom: 10px; }
.panel .chip i { width: 10px; height: 10px; border-radius: 50%; background: var(--waiting); display: inline-block; }
.panel .s-modelled i { background: var(--lean); } .panel .s-proven i { background: var(--good); } .panel .s-open i { background: var(--critical); }
.panel .s-decision i { background: var(--warning); } .panel .s-ready i { background: var(--ready); }
.panel p { margin: 6px 0; color: var(--ink); }
.panel .box { border-radius: 8px; padding: 8px 10px; margin: 10px 0; }
.panel .box.question { background: color-mix(in srgb, var(--warning) 14%, transparent); }
.panel .box.found { background: color-mix(in srgb, var(--critical) 11%, transparent); }
.panel h3 { font-size: 12px; font-weight: 600; letter-spacing: .05em; text-transform: uppercase; color: var(--muted); margin: 16px 0 6px; }
.panel ul { margin: 0; padding-left: 18px; }
.panel li { margin: 3px 0; }
.panel a { color: var(--ready); }
.panel button.link { border: none; background: none; padding: 0; color: var(--ready); font: inherit; cursor: pointer; text-align: left; }
.panel code { font: 12.5px ui-monospace, SFMono-Regular, Menlo, monospace; background: color-mix(in srgb, var(--ink) 6%, transparent);
  padding: 0 4px; border-radius: 4px; }
"""

SCRIPT = r"""
const svg = document.getElementById("graph");
const data = JSON.parse(document.getElementById("graph-data").textContent);
const panel = document.querySelector(".panel");
const [vx, vy, vw, vh] = svg.getAttribute("viewBox").split(" ").map(Number);
let view = { x: vx, y: vy, w: vw, h: vh };
let moved = false;  // once the reader zooms or moves, a resize keeps their view
const apply = () => svg.setAttribute("viewBox", `${view.x} ${view.y} ${view.w} ${view.h}`);

// The view starts showing the whole graph; the reader zooms in to read.
// Room under the graph for the zoom buttons.
const CONTROLS = 52;
function fit() {
  const r = svg.getBoundingClientRect();
  const scale = Math.min(r.width / vw, (r.height - CONTROLS) / vh);
  view.w = r.width / scale; view.h = r.height / scale;
  view.x = vx - (view.w - vw) / 2; view.y = vy - (view.h - CONTROLS / scale - vh) / 2;
  apply();
}
function zoom(factor, cx, cy) {
  const r = svg.getBoundingClientRect();
  const px = cx === undefined ? 0.5 : (cx - r.left) / r.width;
  const py = cy === undefined ? 0.5 : (cy - r.top) / r.height;
  const nw = Math.min(Math.max(view.w / factor, 200), vw * 4), nh = nw * view.h / view.w;
  view.x += (view.w - nw) * px; view.y += (view.h - nh) * py; view.w = nw; view.h = nh;
  moved = true; apply();
}
svg.addEventListener("wheel", (e) => {
  e.preventDefault();
  if (e.ctrlKey || e.metaKey) zoom(Math.exp(-e.deltaY / 200), e.clientX, e.clientY);
  else {
    const r = svg.getBoundingClientRect();
    view.x += e.deltaX * view.w / r.width; view.y += e.deltaY * view.h / r.height; moved = true; apply();
  }
}, { passive: false });
let drag = null;
svg.addEventListener("pointerdown", (e) => {
  if (e.target.closest(".node")) return;
  drag = { x: e.clientX, y: e.clientY, vx: view.x, vy: view.y, moved: false };
  svg.setPointerCapture(e.pointerId); svg.classList.add("dragging");
});
svg.addEventListener("pointermove", (e) => {
  if (!drag) return;
  const r = svg.getBoundingClientRect();
  const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
  if (Math.abs(dx) + Math.abs(dy) > 3) drag.moved = true;
  view.x = drag.vx - dx * view.w / r.width; view.y = drag.vy - dy * view.h / r.height; moved = true; apply();
});
svg.addEventListener("pointerup", (e) => {
  if (drag && !drag.moved && !e.target.closest(".node")) clear();
  drag = null; svg.classList.remove("dragging");
});
document.querySelector("[data-zoom=in]").onclick = () => zoom(1.4);
document.querySelector("[data-zoom=out]").onclick = () => zoom(1 / 1.4);
document.querySelector("[data-zoom=fit]").onclick = () => { moved = false; fit(); };

const esc = (s) => s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const nodeEl = (id) => svg.querySelector(`.node[data-id="${CSS.escape(id)}"]`);
function relatedList(ids) {
  if (!ids.length) return "<p>None.</p>";
  return "<ul>" + ids.map((id) => `<li><button class="link" data-go="${esc(id)}">${esc(data[id].title)}</button></li>`).join("") + "</ul>";
}
function select(id) {
  const d = data[id];
  svg.classList.add("focus");
  svg.querySelectorAll(".node").forEach((n) => n.classList.remove("chosen", "near"));
  svg.querySelectorAll(".edge").forEach((p) => {
    const hot = p.dataset.from === id || p.dataset.to === id;
    p.classList.toggle("hot", hot);
    p.setAttribute("marker-end", hot ? "url(#arrow-hot)" : "url(#arrow)");
  });
  nodeEl(id).classList.add("chosen");
  reveal(nodeEl(id));
  d.deps.concat(d.users).forEach((n) => nodeEl(n).classList.add("near"));
  let body = `<p class="kicker">${esc(d.section)}${d.cid ? " · " + esc(d.cid) : ""}</p>`
    + `<h2>${esc(d.title)}</h2><div class="chip s-${d.status}"><i></i>${esc(d.statusWords)}</div>`
    + d.desc.map((p) => `<p>${p}</p>`).join("");
  if (d.found) body += `<div class="box found"><strong>Counterexample:</strong> ${d.found}</div>`;
  if (d.question) body += `<div class="box question"><strong>Open point:</strong> ${d.question}</div>`;
  if (d.source) body += `<p><strong>Source:</strong> ${d.source}</p>`;
  if (d.lean.length) body += `<h3>In Lean</h3><ul>` + d.lean.map((n) =>
    `<li><a href="../review/find/?domain=Verso.Genre.Manual.doc&name=${encodeURIComponent(n)}"><code>${esc(n)}</code></a></li>`).join("") + "</ul>";
  body += `<h3>Depends on</h3>${relatedList(d.deps)}<h3>Used by</h3>${relatedList(d.users)}`;
  panel.querySelector(".body").innerHTML = body;
  history.replaceState(null, "", "#" + encodeURIComponent(id));
  panel.classList.add("open");
  panel.querySelectorAll("[data-go]").forEach((b) => b.onclick = () => select(b.dataset.go));
}
// Moves the view so a node is not hidden under the side panel or off the edge.
function reveal(el) {
  const r = svg.getBoundingClientRect(), b = el.getBoundingClientRect();
  const visible = r.right - Math.min(panel.offsetWidth, r.width * 0.9) - 24;
  if (b.left >= r.left + 24 && b.right <= visible && b.top >= r.top + 24 && b.bottom <= r.bottom - 60) return;
  const k = view.w / r.width;
  view.x += ((b.left + b.right) / 2 - (r.left + visible) / 2) * k;
  view.y += ((b.top + b.bottom) / 2 - (r.top + r.bottom) / 2) * k;
  apply();
}
function clear() {
  svg.classList.remove("focus");
  svg.querySelectorAll(".chosen, .near, .hot").forEach((n) => n.classList.remove("chosen", "near", "hot"));
  svg.querySelectorAll(".edge").forEach((p) => p.setAttribute("marker-end", "url(#arrow)"));
  panel.classList.remove("open");
  history.replaceState(null, "", location.pathname + location.search);
}
svg.querySelectorAll(".node").forEach((n) => {
  n.addEventListener("click", () => select(n.dataset.id));
  n.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); select(n.dataset.id); } });
});
panel.querySelector(".close").onclick = clear;
document.addEventListener("keydown", (e) => { if (e.key === "Escape") clear(); });
fit();
// A link such as graph/#def:c08-delivery-status opens with that node selected
// and zoomed to a readable size.
function openFromHash() {
  const id = decodeURIComponent(location.hash.slice(1));
  if (!data[id]) return;
  const r = svg.getBoundingClientRect(), b = nodeEl(id).getBoundingClientRect();
  const k = view.w / r.width;
  const cx = view.x + ((b.left + b.right) / 2 - r.left) * k, cy = view.y + ((b.top + b.bottom) / 2 - r.top) * k;
  view.w = r.width / 1.1; view.h = r.height / 1.1;
  view.x = cx - view.w * 0.35; view.y = cy - view.h / 2;
  moved = true; apply();
  select(id);
}
openFromHash();
window.addEventListener("hashchange", openFromHash);
window.addEventListener("resize", () => {
  if (!moved) return fit();
  const r = svg.getBoundingClientRect();
  view.h = view.w * r.height / r.width; apply();
});
"""


def page(nodes, labels, decls):
    width, height, pos, edges = layout(nodes, labels)
    counts = {k: sum(1 for n in nodes if n["status"] == k) for k in STATUS_WORDS}
    legend = "".join(f'<span class="s-{k}"><i></i>{STATUS_WORDS[k]} {counts[k]}</span>' for k in STATUS_WORDS if counts[k])
    in_lean = counts["modelled"] + counts["proven"] + counts["open"]
    title = (f"{in_lean} parts of the model are in Lean; {counts['decision']} candidate rules need a business "
             f"decision before they can join them")
    data = json.dumps(details(nodes, labels, decls)).replace("</", "<\\/")
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dependency graph: Offer and Order rules</title>
<style>{CSS}{TOPBAR_CSS}</style>
</head>
<body>
{topbar("Dependency graph", "../", '<a class="local" href="../blueprint/">Blueprint chapters</a>')}
<div class="intro">
  <div>
    <h1>{html.escape(title)}</h1>
    <p>Every definition, rule and guarantee in the blueprint, with an arrow from each one to the ones that build on it.
    Click a card to read it and see what it depends on.</p>
  </div>
  <div class="legend">{legend}</div>
</div>
<div class="stage">
{svg(nodes, width, height, pos, edges)}
<div class="controls">
  <button data-zoom="in" aria-label="Zoom in">+</button>
  <button data-zoom="out" aria-label="Zoom out">&minus;</button>
  <button data-zoom="fit">Fit</button>
  <span class="hint">Drag to move. Pinch or Ctrl and scroll to zoom.</span>
</div>
<aside class="panel" aria-live="polite"><button class="close" aria-label="Close">&times;</button><div class="body"></div></aside>
</div>
<script type="application/json" id="graph-data">{data}</script>
<script>{SCRIPT}</script>
</body>
</html>
"""


def main():
    decls = load_decls()
    nodes = parse_nodes()
    classify(nodes, decls)
    for n in nodes:
        n["lines"] = wrap(n["title"])
    labels = {n["label"] for n in nodes}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(page(nodes, labels, decls))
    print(f"rendered {OUT.relative_to(ROOT)}: {len(nodes)} nodes")


if __name__ == "__main__":
    main()
