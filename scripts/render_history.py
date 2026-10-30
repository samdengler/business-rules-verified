#!/usr/bin/env python3
"""Render the history page, build/history/index.html.

The page plays the milestones in history/ on the dependency graph: cards
appear as surveys find them and change color as rules are written in Lean,
proven, or left open with an example.  Every milestone uses the positions in
history/layout.json, so cards keep their place from one milestone to the next.
It is the site's version of the motion piece described in
docs/motion-brief.md, and it reads the same files.

Run scripts/graph_history.py layout after the last snapshot first.
"""

import html
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_graph import CARD_W, CSS as GRAPH_CSS, LINE, STATUS_WORDS  # noqa: E402
from site_nav import FAVICON, REPO, SITE_NAME, TOPBAR_CSS, topbar  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
HISTORY = ROOT / "history"
OUT = ROOT / "build" / "history" / "index.html"


def page_data():
    lay = json.loads((HISTORY / "layout.json").read_text())
    index = json.loads((HISTORY / "index.json").read_text())
    cid, milestones = {}, []
    for m in index["milestones"]:
        snap = json.loads((HISTORY / m["file"]).read_text())
        for n in snap["nodes"]:
            cid[n["id"]] = n.get("candidate")
        milestones.append({
            "seq": m["seq"], "name": m["name"], "description": m["description"], "date": m["date"][:10],
            "tag": m["tag"], "counts": m["statusCounts"],
            "status": {n["id"]: n["status"] for n in snap["nodes"]},
        })
    nodes = {i: {"x": n["x"], "y": n["y"], "h": n["height"], "lines": n["lines"], "cid": cid.get(i)}
             for i, n in lay["nodes"].items()}
    edges = [[e["from"], e["to"], e["path"]] for e in lay["edges"]]
    return {"width": lay["width"], "height": lay["height"], "nodes": nodes, "edges": edges,
            "milestones": milestones, "words": STATUS_WORDS}


CSS = """
.intro { padding: 20px 28px 8px; }
.intro p { margin: 4px 0 0; }
.player { display: flex; flex-wrap: wrap; align-items: center; gap: 10px 14px; padding: 4px 28px 12px; }
.player button { font: 13px system-ui, sans-serif; color: var(--ink); background: var(--surface); border: 1px solid var(--ring);
  border-radius: 8px; padding: 4px 12px; cursor: pointer; }
.player button:hover { border-color: var(--axis); }
.player button.play { font-weight: 600; min-width: 84px; }
.steps { display: flex; gap: 4px; flex-wrap: wrap; }
.steps button { width: 30px; padding: 4px 0; font-variant-numeric: tabular-nums; color: var(--ink-2); }
.steps button.on { background: var(--ink); color: var(--page); border-color: var(--ink); }
.caption { flex-basis: 100%; display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px 16px; }
.caption h2 { font-size: 16px; margin: 0; }
.caption .when { font-size: 12.5px; color: var(--muted); }
.caption p { margin: 0; flex-basis: 100%; color: var(--ink-2); font-size: 14px; max-width: 900px; }
.counts { flex-basis: 100%; display: flex; flex-wrap: wrap; gap: 4px 16px; font-size: 13px; color: var(--ink-2); }
.counts span { display: inline-flex; align-items: center; gap: 6px; font-variant-numeric: tabular-nums; }
.counts i { width: 10px; height: 10px; border-radius: 50%; display: inline-block; background: var(--waiting); }
.counts .s-modelled i { background: var(--lean); } .counts .s-proven i { background: var(--good); }
.counts .s-open i { background: var(--critical); } .counts .s-decision i { background: var(--warning); }
.counts .s-ready i { background: var(--ready); }
#graph { cursor: default; }
.node { cursor: default; opacity: 0; transition: opacity .5s; }
.node.on { opacity: 1; }
.node rect { transition: fill .6s, stroke .6s, stroke-width .6s; }
.node .dot { transition: fill .6s; }
.edge { opacity: 0; transition: opacity .5s; }
.edge.on { opacity: 1; }
@keyframes pulse { 0%, 100% { stroke-width: 2; } 40% { stroke-width: 6; } }
.node.pulse rect { animation: pulse .9s ease-out 1; }
.note { padding: 0 28px 20px; font-size: 13px; color: var(--muted); }
.note a { color: var(--ready); }
@media (prefers-reduced-motion: reduce) { .node, .edge, .node rect, .node .dot { transition: none; } .node.pulse rect { animation: none; } }
"""

SCRIPT = r"""
const D = JSON.parse(document.getElementById("history-data").textContent);
const svg = document.getElementById("graph");
const ids = Object.keys(D.nodes);
const CARD_W = %CARD_W%, LINE = %LINE%;
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);

// Every card and connector is drawn once; a milestone shows some of them and
// sets their status, and the page's stylesheet fades and recolors them.
let body = '<g class="edges">' + D.edges.map(([f, t, d], i) => `<path class="edge" data-i="${i}" d="${d}"/>`).join("") + "</g><g>";
for (const id of ids) {
  const n = D.nodes[id], x0 = n.x - CARD_W / 2, y0 = n.y - n.h / 2;
  const sy = y0 + 24 + LINE * n.lines.length + 4;
  body += `<g class="node" data-id="${esc(id)}"><rect x="${x0}" y="${y0}" width="${CARD_W}" height="${n.h}" rx="8"/>`
    + n.lines.map((l, i) => `<text class="name" x="${x0 + 14}" y="${y0 + 24 + LINE * i}">${esc(l)}</text>`).join("")
    + `<circle class="dot" cx="${x0 + 18}" cy="${sy - 4}" r="4"/><text class="status" x="${x0 + 28}" y="${sy}"></text></g>`;
}
svg.innerHTML = body + "</g>";
const cards = {}; svg.querySelectorAll(".node").forEach((g) => { cards[g.dataset.id] = g; });
const edges = [...svg.querySelectorAll(".edge")];

// The camera eases between the boxes around the cards each milestone shows.
let view = [0, 0, D.width, D.height], anim = null;
function boxFor(m) {
  const xs = [], ys = [];
  for (const id in m.status) { xs.push(D.nodes[id].x); ys.push(D.nodes[id].y); }
  const r = svg.getBoundingClientRect(), aspect = r.width / Math.max(r.height, 1);
  let x = Math.min(...xs) - CARD_W / 2 - 40, y = Math.min(...ys) - 80;
  let w = Math.max(...xs) - Math.min(...xs) + CARD_W + 80, h = Math.max(...ys) - Math.min(...ys) + 160;
  if (w / h < aspect) { const nw = h * aspect; x -= (nw - w) / 2; w = nw; } else { const nh = w / aspect; y -= (nh - h) / 2; h = nh; }
  return [x, y, w, h];
}
function moveTo(target, ms) {
  cancelAnimationFrame(anim);
  const from = view.slice(), t0 = performance.now();
  const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const step = (t) => {
    const k = reduce || ms <= 0 ? 1 : Math.min(1, (t - t0) / ms), e = k < 0.5 ? 2 * k * k : 1 - Math.pow(-2 * k + 2, 2) / 2;
    view = from.map((v, i) => v + (target[i] - v) * e);
    svg.setAttribute("viewBox", view.join(" "));
    if (k < 1) anim = requestAnimationFrame(step);
  };
  anim = requestAnimationFrame(step);
}

let at = 0, timer = null;
const playBtn = document.querySelector(".play");
function show(i, ms = 1100) {
  const m = D.milestones[i], prev = i > 0 ? D.milestones[i - 1].status : {};
  for (const id of ids) {
    const g = cards[id], st = m.status[id];
    g.classList.toggle("on", !!st);
    g.classList.remove("pulse");
    if (!st) continue;
    g.setAttribute("class", `node on s-${st}`);
    g.querySelector(".status").textContent = (D.nodes[id].cid ? D.nodes[id].cid + " · " : "") + D.words[st];
    if (st === "open" && prev[id] !== "open") { void g.getBoundingClientRect(); g.classList.add("pulse"); }
  }
  D.edges.forEach(([f, t], k) => edges[k].classList.toggle("on", !!(m.status[f] && m.status[t])));
  document.querySelectorAll(".steps button").forEach((b, k) => b.classList.toggle("on", k === i));
  const c = document.querySelector(".caption");
  c.querySelector("h2").textContent = `${m.seq}. ${m.name.replaceAll("-", " ")}`;
  c.querySelector(".when").textContent = `${m.date} · ${Object.keys(m.status).length} cards`;
  c.querySelector("p").textContent = m.description;
  c.querySelector(".counts").innerHTML = Object.keys(D.words).filter((k) => m.counts[k])
    .map((k) => `<span class="s-${k}"><i></i>${esc(D.words[k])} ${m.counts[k]}</span>`).join("");
  moveTo(boxFor(m), ms);
  at = i;
  history.replaceState(null, "", `?m=${m.seq}`);
}
function stop() { clearInterval(timer); timer = null; playBtn.textContent = at === D.milestones.length - 1 ? "Replay" : "Play"; }
function play() {
  if (timer) return stop();
  if (at === D.milestones.length - 1) show(0, 600);
  playBtn.textContent = "Pause";
  timer = setInterval(() => { if (at + 1 >= D.milestones.length) return stop(); show(at + 1); }, 2600);
}
playBtn.onclick = play;
document.querySelector("[data-step=prev]").onclick = () => { stop(); show(Math.max(0, at - 1)); };
document.querySelector("[data-step=next]").onclick = () => { stop(); show(Math.min(D.milestones.length - 1, at + 1)); };
document.querySelectorAll(".steps button").forEach((b, k) => b.onclick = () => { stop(); show(k); });
document.addEventListener("keydown", (e) => {
  if (e.key === "ArrowRight") document.querySelector("[data-step=next]").click();
  if (e.key === "ArrowLeft") document.querySelector("[data-step=prev]").click();
});
window.addEventListener("resize", () => moveTo(boxFor(D.milestones[at]), 0));
const asked = Number(new URLSearchParams(location.search).get("m"));
show(asked >= 1 && asked <= D.milestones.length ? asked - 1 : 0, 0);
stop();
"""


def page():
    data = page_data()
    ms = data["milestones"]
    steps = "".join(f'<button title="{html.escape(m["name"])}">{m["seq"]}</button>' for m in ms)
    last = ms[-1]["counts"]
    script = SCRIPT.replace("%CARD_W%", str(CARD_W)).replace("%LINE%", str(LINE))
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>History: {SITE_NAME}</title>
{FAVICON}
<style>{GRAPH_CSS}{CSS}{TOPBAR_CSS}</style>
</head>
<body>
{topbar("History", "../")}
<div class="intro"><div>
  <h1>How the model grew, in {len(ms)} milestones</h1>
  <p>Each milestone is a tagged commit. Surveys of IATA's public ONE Order material add candidate rules, mostly amber because the
  material leaves them to the business; writing an area in Lean turns its rules magenta and its guarantees green, or red where an
  example shows the rule breaking a guarantee. Today: {last.get("proven", 0)} proven, {last.get("open", 0)} open questions,
  {last.get("decision", 0)} still need a decision.</p>
</div></div>
<div class="player">
  <button class="play">Play</button>
  <button data-step="prev" aria-label="Previous milestone">&larr;</button>
  <button data-step="next" aria-label="Next milestone">&rarr;</button>
  <div class="steps" aria-label="Milestones">{steps}</div>
  <div class="caption" aria-live="polite"><h2></h2><span class="when"></span><p></p><div class="counts"></div></div>
</div>
<div class="stage"><svg id="graph" role="img" aria-label="The dependency graph at one milestone"></svg></div>
<p class="note">The milestones and their snapshots are in <a href="{REPO}/tree/main/history">history/</a>, with the git tags
<code>milestone/&lt;name&gt;</code>. The <a href="{REPO}/blob/main/docs/motion-brief.md">motion brief</a> describes the same story
for a motion piece. Open the <a href="../graph/">dependency graph</a> to read any card.</p>
<script type="application/json" id="history-data">{json.dumps(data).replace("</", "<\\/")}</script>
<script>{script}</script>
</body>
</html>
"""


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(page())
    print(f"rendered {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
