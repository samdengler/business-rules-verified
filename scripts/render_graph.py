#!/usr/bin/env python3
"""Render the dependency graph page, build/graph/index.html.

Every node of the blueprint (blueprint/src/content.tex) is drawn as a card
with its title and its status, and every \\uses as a connector from the node
used to the node that uses it.  layout() places the cards in rows below the
cards they use; the page draws the cards and connectors in the style of the
progress page, and lets the reader move, zoom and open a node to read its
statement.

Statuses come from build/status.json through scripts/render_progress.py, so
the page changes when the model does.
"""

import html
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_progress import classify, load_decls, parse_nodes, split_question  # noqa: E402
from site_nav import FAVICON, SITE_NAME, TOPBAR_CSS, topbar  # noqa: E402

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
.intro { padding: 20px 28px 12px; display: flex; flex-wrap: wrap; align-items: flex-end; gap: 12px 32px; }
.intro h1 { font-size: 22px; line-height: 1.25; margin: 0 0 4px; letter-spacing: -0.01em; }
.intro p { margin: 0; color: var(--ink-2); max-width: 720px; font-size: 14px; }
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
.lens .note button.link, .panel .lens-btn { border: none; background: none; padding: 0; color: var(--ready); font: inherit; cursor: pointer; }
.panel .lens-btn { font-weight: 600; }
.node.context { opacity: .45; }
.node.anchor rect { stroke-width: 3; }
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
const AREAS = JSON.parse(document.getElementById("graph-areas").textContent);
const panel = document.querySelector(".panel");
const ALL = Object.keys(data);
const CARD_W = 184, LINE = 17, GAP_X = 28, GAP_Y = 72;
let vx = -16, vy = -16, vw = 1, vh = 1;
let view = { x: 0, y: 0, w: 1, h: 1 };
let moved = false;  // once the reader zooms or moves, a resize keeps their view
const apply = () => svg.setAttribute("viewBox", `${view.x} ${view.y} ${view.w} ${view.h}`);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);

// The same layout as scripts/render_graph.py: each card in the first row with
// room below every card it uses, rows no wider than about the square root of
// the number of cards, and a few sweeps that put each card near the cards it
// is linked to.
function layout(show) {
  const vis = new Set(show);
  const uses = (id) => data[id].deps.filter((u) => vis.has(u));
  const usedBy = (id) => data[id].users.filter((u) => vis.has(u));
  const depth = {}, path = new Set();
  const d = (id) => {
    if (depth[id] === undefined) {
      path.add(id);
      depth[id] = 1 + Math.max(-1, ...uses(id).filter((u) => !path.has(u)).map(d));
      path.delete(id);
    }
    return depth[id];
  };
  const rowMax = Math.max(3, Math.min(14, Math.round(Math.sqrt(1.2 * show.length))));
  const sorted = [...show].sort((a, b) => d(a) - d(b) || cmp(data[a].section, data[b].section) || cmp(a, b));
  const row = {}, count = {};
  for (const id of sorted) {
    let r = 1 + Math.max(-1, ...uses(id).filter((u) => u in row).map((u) => row[u]));
    while ((count[r] || 0) >= rowMax) r++;
    row[id] = r; count[r] = (count[r] || 0) + 1;
  }
  const order = [];
  for (const id of sorted) (order[row[id]] = order[row[id]] || []).push(id);
  const rows = order.filter(Boolean);
  rows.forEach((r) => r.sort((a, b) => cmp(data[a].section, data[b].section) || cmp(a, b)));
  const place = () => { const at = {}; rows.forEach((r) => r.forEach((id, i) => { at[id] = (i + 0.5) / r.length; })); return at; };
  for (let k = 0; k < 4; k++) {
    for (const [from, to, step, links] of [[1, rows.length, 1, uses], [rows.length - 2, -1, -1, usedBy]]) {
      for (let i = from; i !== to; i += step) {
        const at = place(), key = {};
        rows[i].forEach((id) => { const l = links(id); key[id] = l.length ? l.reduce((s, x) => s + at[x], 0) / l.length : at[id]; });
        rows[i].sort((a, b) => key[a] - key[b]);
      }
    }
  }
  const slot = CARD_W + GAP_X;
  const width = Math.max(...rows.map((r) => r.length)) * slot - GAP_X;
  const pos = {};
  let y = 0;
  for (const r of rows) {
    const h = Math.max(...r.map((id) => data[id].height));
    const x0 = (width - (r.length * slot - GAP_X)) / 2;
    r.forEach((id, i) => { pos[id] = [x0 + i * slot + CARD_W / 2, y + h / 2]; });
    y += h + GAP_Y;
  }
  const edges = [];
  for (const id of show) for (const u of uses(id)) {
    const [x1, ya] = pos[u], [x2, yb] = pos[id];
    const y1 = ya + data[u].height / 2, y2 = yb - data[id].height / 2 - 2;
    const bend = Math.min(GAP_Y, (y2 - y1) / 2);
    edges.push([u, id, `M${x1} ${y1}C${x1} ${y1 + bend} ${x2} ${y2 - bend} ${x2} ${y2}`]);
  }
  return { width: width + 32, height: y - GAP_Y + 32, pos, edges };
}

function card(id, pos, extra) {
  const n = data[id], [x, y] = pos[id], h = n.height;
  const x0 = x - CARD_W / 2, y0 = y - h / 2;
  const sy = y0 + 24 + LINE * n.lines.length + 4;
  return `<g class="node s-${n.status}${extra}" data-id="${esc(id)}" tabindex="0" role="button" aria-label="${esc(n.title)}, ${esc(n.statusWords)}">`
    + `<rect x="${x0}" y="${y0}" width="${CARD_W}" height="${h}" rx="8"/>`
    + n.lines.map((l, i) => `<text class="name" x="${x0 + 14}" y="${y0 + 24 + LINE * i}">${esc(l)}</text>`).join("")
    + `<circle class="dot" cx="${x0 + 18}" cy="${sy - 4}" r="4"/>`
    + `<text class="status" x="${x0 + 28}" y="${sy}">${esc((n.cid ? n.cid + " · " : "") + n.statusWords)}</text></g>`;
}

// What the reader is looking at: every card, one area with the cards it
// builds on, or one card with everything it depends on and what uses it.
const params = new URLSearchParams(location.search);
let lens = { area: params.get("area"), focus: params.get("focus") };
if (lens.area && !AREAS.some((a) => a.name === lens.area)) lens.area = null;
if (lens.focus && !data[lens.focus]) lens.focus = null;
function shown() {
  if (lens.focus) {
    const keep = new Set([lens.focus, ...data[lens.focus].users]);
    const up = (id) => data[id].deps.forEach((u) => { if (!keep.has(u)) { keep.add(u); up(u); } });
    up(lens.focus);
    return { ids: ALL.filter((id) => keep.has(id)), context: new Set() };
  }
  if (lens.area) {
    const own = ALL.filter((id) => data[id].section === lens.area);
    const keep = new Set(own);
    own.forEach((id) => data[id].deps.forEach((u) => keep.add(u)));
    return { ids: ALL.filter((id) => keep.has(id)), context: new Set([...keep].filter((id) => data[id].section !== lens.area)) };
  }
  return { ids: ALL, context: new Set() };
}
function draw() {
  const { ids, context } = shown();
  const L = layout(ids);
  vw = L.width; vh = L.height;
  svg.innerHTML = '<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z"/></marker>'
    + '<marker id="arrow-hot" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z"/></marker></defs>'
    + '<g class="edges">' + L.edges.map(([f, t, p]) => `<path class="edge" data-from="${esc(f)}" data-to="${esc(t)}" d="${p}" marker-end="url(#arrow)"/>`).join("") + "</g>"
    + '<g class="nodes">' + ids.map((id) => card(id, L.pos, (context.has(id) ? " context" : "") + (id === lens.focus ? " anchor" : ""))).join("") + "</g>";
  svg.querySelectorAll(".node").forEach((n) => {
    n.addEventListener("click", () => select(n.dataset.id));
    n.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); select(n.dataset.id); } });
  });
  document.querySelectorAll(".lens button[data-area]").forEach((b) =>
    b.classList.toggle("on", !lens.focus && (b.dataset.area || null) === lens.area));
  const note = document.querySelector(".lens .note");
  note.innerHTML = lens.focus
    ? `Showing <strong>${esc(data[lens.focus].title)}</strong>, everything it depends on and what uses it: ${ids.length} of ${ALL.length} cards. <button class="link" data-clear-focus>Show all</button>`
    : lens.area ? `Showing ${ids.length - context.size} cards in this area and ${context.size} they build on, faded.` : `Showing all ${ALL.length} cards.`;
  const back = note.querySelector("[data-clear-focus]");
  if (back) back.onclick = () => setLens({ area: null, focus: null });
  moved = false; fit();
}
function setLens(next) {
  lens = next;
  const q = new URLSearchParams();
  if (lens.area) q.set("area", lens.area);
  if (lens.focus) q.set("focus", lens.focus);
  history.replaceState(null, "", location.pathname + (q.toString() ? "?" + q : "") + location.hash);
  clear(true);
  draw();
}
document.querySelectorAll(".lens button[data-area]").forEach((b) =>
  b.onclick = () => setLens({ area: b.dataset.area || null, focus: null }));

// The view starts showing everything in the lens; the reader zooms in to read.
// Room under the graph for the zoom buttons.
const CONTROLS = 52;
function fit() {
  const r = svg.getBoundingClientRect();
  const scale = Math.min(r.width / vw, (r.height - CONTROLS) / vh, 1.2);
  view.w = r.width / scale; view.h = r.height / scale;
  view.x = vx - (view.w - vw) / 2; view.y = vy - (view.h - CONTROLS / scale - vh) / 2;
  apply();
}
function zoom(factor, cx, cy) {
  const r = svg.getBoundingClientRect();
  const px = cx === undefined ? 0.5 : (cx - r.left) / r.width;
  const py = cy === undefined ? 0.5 : (cy - r.top) / r.height;
  const nw = Math.min(Math.max(view.w / factor, 200), Math.max(vw, 800) * 4), nh = nw * view.h / view.w;
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

const nodeEl = (id) => svg.querySelector(`.node[data-id="${CSS.escape(id)}"]`);
function relatedList(ids) {
  if (!ids.length) return "<p>None.</p>";
  return "<ul>" + ids.map((id) => `<li><button class="link" data-go="${esc(id)}">${esc(data[id].title)}</button></li>`).join("") + "</ul>";
}
function select(id) {
  if (!nodeEl(id)) setLens({ area: null, focus: null });
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
  d.deps.concat(d.users).forEach((n) => { const el = nodeEl(n); if (el) el.classList.add("near"); });
  let body = `<p class="kicker">${esc(d.section)}${d.cid ? " · " + esc(d.cid) : ""}</p>`
    + `<h2>${esc(d.title)}</h2><div class="chip s-${d.status}"><i></i>${esc(d.statusWords)}</div>`
    + d.desc.map((p) => `<p>${p}</p>`).join("");
  if (d.found) body += `<div class="box found"><strong>Counterexample:</strong> ${d.found}</div>`;
  if (d.question) body += `<div class="box question"><strong>Open point:</strong> ${d.question}</div>`;
  if (d.source) body += `<p><strong>Source:</strong> ${d.source}</p>`;
  if (d.lean.length) body += `<h3>In Lean</h3><ul>` + d.lean.map((n) =>
    `<li><a href="../review/find/?domain=Verso.Genre.Manual.doc&name=${encodeURIComponent(n)}"><code>${esc(n)}</code></a></li>`).join("") + "</ul>";
  if (lens.focus !== id) body += `<p><button class="lens-btn" data-focus="${esc(id)}">Show only this card's connections</button></p>`;
  body += `<h3>Depends on</h3>${relatedList(d.deps)}<h3>Used by</h3>${relatedList(d.users)}`;
  panel.querySelector(".body").innerHTML = body;
  history.replaceState(null, "", location.pathname + location.search + "#" + encodeURIComponent(id));
  panel.classList.add("open");
  panel.querySelectorAll("[data-go]").forEach((b) => b.onclick = () => select(b.dataset.go));
  const f = panel.querySelector("[data-focus]");
  if (f) f.onclick = () => { setLens({ area: null, focus: id }); select(id); };
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
function clear(keepPanel) {
  svg.classList.remove("focus");
  svg.querySelectorAll(".chosen, .near, .hot").forEach((n) => n.classList.remove("chosen", "near", "hot"));
  svg.querySelectorAll(".edge").forEach((p) => p.setAttribute("marker-end", "url(#arrow)"));
  if (keepPanel === true) return;
  panel.classList.remove("open");
  history.replaceState(null, "", location.pathname + location.search);
}
panel.querySelector(".close").onclick = () => clear();
document.addEventListener("keydown", (e) => { if (e.key === "Escape") clear(); });
draw();
// A link such as graph/#def:c08-delivery-status opens with that node selected
// and zoomed to a readable size.
function openFromHash() {
  const id = decodeURIComponent(location.hash.slice(1));
  if (!data[id]) return;
  if (!nodeEl(id)) setLens({ area: null, focus: null });
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
    counts = {k: sum(1 for n in nodes if n["status"] == k) for k in STATUS_WORDS}
    legend = "".join(f'<span class="s-{k}"><i></i>{STATUS_WORDS[k]} {counts[k]}</span>' for k in STATUS_WORDS if counts[k])
    in_lean = counts["modelled"] + counts["proven"] + counts["open"]
    title = (f"{in_lean} parts of the model are in Lean; {counts['decision']} candidate rules need a business "
             f"decision before they can join them")
    data = json.dumps(details(nodes, labels, decls)).replace("</", "<\\/")
    areas = [{"name": a, "count": sum(1 for n in nodes if n["section"] == a)}
             for a in dict.fromkeys(n["section"] for n in nodes)]
    lens = "".join(f'<button data-area="{html.escape(a["name"])}">{html.escape(a["name"])} <span>{a["count"]}</span></button>'
                   for a in areas)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dependency graph: {SITE_NAME}</title>
{FAVICON}
<style>{CSS}{TOPBAR_CSS}</style>
</head>
<body>
{topbar("Dependency graph", "../", '<a class="local" href="../blueprint/">Blueprint chapters</a>')}
<div class="intro">
  <div>
    <h1>{html.escape(title)}</h1>
    <p>Every definition, rule and guarantee in the blueprint, with an arrow from each one to the ones that build on it.
    Pick an area to see its rules and what they build on, or click a card to read it.</p>
  </div>
  <div class="legend">{legend}</div>
</div>
<nav class="lens" aria-label="Show one area">
  <button data-area="">All areas <span>{len(nodes)}</span></button>{lens}
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
<script type="application/json" id="graph-data">{data}</script>
<script type="application/json" id="graph-areas">{json.dumps(areas)}</script>
<script>{SCRIPT}</script>
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
        } for n in nodes],
    }


def main():
    decls = load_decls()
    nodes = parse_nodes()
    classify(nodes, decls)
    for n in nodes:
        n["lines"] = wrap(n["title"])
    labels = {n["label"] for n in nodes}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(page(nodes, labels, decls))
    (OUT.parent / "graph.json").write_text(json.dumps(graph_data(nodes, labels), indent=1) + "\n")
    print(f"rendered {OUT.relative_to(ROOT)} and graph.json: {len(nodes)} nodes")


if __name__ == "__main__":
    main()
