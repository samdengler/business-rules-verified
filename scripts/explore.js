// The Explore page (/graph/), written into the page by scripts/render_graph.py.
//
// Five views share the page, chosen by ?view= in the address: the area map,
// the dependency matrix, all cards (the full graph with its area and
// capability lenses), the history of milestones as clusters of dots, and one
// card's neighbourhood.  A selected card is in the address's hash, so a link
// such as graph/#def:c06-item-status opens that card's neighbourhood.
(() => {
const D = JSON.parse(document.getElementById("explore-data").textContent);
const C = D.cards, ALL = Object.keys(C);
const VIEWS = ["area-map", "matrix", "all-cards", "history", "card"];
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
const cmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);
const AREA_RANK = Object.fromEntries(D.areas.map((a, i) => [a.name, i]));
const AREA = Object.fromEntries(D.areas.map((a) => [a.name, a]));
const reduceMotion = () => matchMedia("(prefers-reduced-motion: reduce)").matches;

// ------------------------------------------------------------ the address

function readURL() {
  const q = new URLSearchParams(location.search);
  const hash = decodeURIComponent(location.hash.slice(1));
  const s = { view: q.get("view"), id: C[hash] ? hash : null, area: q.get("area"), cap: q.get("cap"),
              m: q.get("m"), all: q.get("all") === "1", row: q.get("row"), col: q.get("col") };
  // Links from before the Explore page: ?focus=<card> and ?area=<area>.
  const focus = q.get("focus");
  if (!s.view && focus && C[focus]) { s.view = "card"; s.id = focus; }
  if (!s.view && (s.area || s.cap)) s.view = "all-cards";
  if (!VIEWS.includes(s.view)) s.view = s.id ? "card" : "area-map";
  if (s.area && !AREA[s.area]) s.area = null;
  if (s.cap && !D.caps[s.cap]) s.cap = null;
  return s;
}
function urlFor(s) {
  const q = new URLSearchParams();
  q.set("view", s.view);
  if (s.view === "all-cards") { if (s.area) q.set("area", s.area); if (s.cap) q.set("cap", s.cap); }
  if (s.view === "history" && s.m) q.set("m", s.m);
  if (s.view === "card" && s.all) q.set("all", "1");
  if (s.view === "matrix" && s.row && s.col) { q.set("row", s.row); q.set("col", s.col); }
  const withId = s.id && (s.view === "card" || s.view === "all-cards");
  return location.pathname + "?" + q.toString() + (withId ? "#" + encodeURIComponent(s.id) : "");
}
let state = readURL();
// Older links (?focus=, ?area= without a view) take the current form.
if (new URLSearchParams(location.search).has("focus") || !new URLSearchParams(location.search).has("view"))
  history.replaceState(null, "", urlFor(state));
function go(next, push = true) {
  state = { ...state, ...next };
  const url = urlFor(state);
  if (url !== location.pathname + location.search + location.hash) history[push ? "pushState" : "replaceState"](null, "", url);
  render();
}
function setQuiet(next) {  // updates the address without redrawing
  state = { ...state, ...next };
  history.replaceState(null, "", urlFor(state));
}
window.addEventListener("popstate", () => { state = readURL(); render(); });
window.addEventListener("hashchange", () => { state = readURL(); render(); });
const cardHref = (id) => "?view=card#" + encodeURIComponent(id);
// Links inside the page change the view without reloading it; a modified
// click still opens a new tab.
document.addEventListener("click", (e) => {
  const a = e.target.closest("a[data-card], a[data-view]");
  if (!a || e.metaKey || e.ctrlKey || e.shiftKey || e.button !== 0) return;
  e.preventDefault();
  if (a.dataset.card) go({ view: "card", id: a.dataset.card });
  else go({ view: a.dataset.view, id: a.dataset.view === "card" ? state.id : null });
});

// ------------------------------------------------------------- shared bits

function chip(st) { return `<span class="chip s-${st}"><i></i>${esc(D.words[st])}</span>`; }
function pill(id, extra = "") {
  const n = C[id];
  return `<a class="pill s-${n.status}${extra}" href="${cardHref(id)}" data-card="${esc(id)}" data-id="${esc(id)}" title="${esc(n.title)}">`
    + `<span class="pt">${esc(n.title)}</span><span class="ps"><i></i>${esc((n.cid ? n.cid + " · " : "") + n.statusWords)}</span></a>`;
}
// What the side panel says about a card, in the All cards and neighbourhood views.
function details(id, where) {
  const d = C[id], area = AREA[d.section];
  let body = `<p class="kicker">${esc(d.section)}${d.cid ? " · " + esc(d.cid) : ""}</p>`
    + `<h2>${esc(d.title)}</h2><div class="chip s-${d.status}"><i></i>${esc(d.statusWords)}</div>`
    + d.desc.map((p) => `<p>${p}</p>`).join("");
  if (d.found) body += `<div class="box found"><strong>Counterexample:</strong> ${d.found}</div>`;
  if (d.question) body += `<div class="box question"><strong>Open point:</strong> ${d.question}</div>`;
  if (d.readings.length) {
    body += `<div class="box reading"><h3>If we decide this</h3>`
      + d.readings.map((r) => `<p>Lean proves this guarantee for one reading of the sources. If the business settles the question that way, it holds for every input:</p>`
        + `<p class="doc">${r.doc}</p><p class="lean"><a href="../review/find/?domain=Verso.Genre.Manual.doc&name=${encodeURIComponent(r.proven)}"><code>${esc(r.proven.split(".").pop())}</code></a></p>`).join("")
      + `</div>`;
  }
  if (d.source) body += `<p><strong>Source:</strong> ${d.source}</p>`;
  if (d.down) body += `<p class="impact">${d.down} ${d.down === 1 ? "card depends" : "cards depend"} on it, directly or through other cards, in ${d.downAreas} ${d.downAreas === 1 ? "area" : "areas"}.</p>`;
  if (d.caps.length) body += `<h3>IATA capabilities</h3><ul>` + d.caps.map((c) =>
    `<li><a href="?view=all-cards&cap=${encodeURIComponent(c)}" data-cap="${esc(c)}"><code>${esc(c)}</code></a> ${esc(D.caps[c].name)}</li>`).join("") + "</ul>";
  if (d.lean.length) body += `<h3>In Lean</h3><ul>` + d.lean.map((n) =>
    `<li><a href="../review/find/?domain=Verso.Genre.Manual.doc&name=${encodeURIComponent(n)}"><code>${esc(n)}</code></a></li>`).join("") + "</ul>";
  body += `<h3>See also</h3><ul class="also">`;
  if (where === "all") body += `<li><a href="${cardHref(id)}" data-card="${esc(id)}"><strong>Open this card's neighbourhood</strong></a></li>`;
  else body += `<li><a href="?view=all-cards#${encodeURIComponent(id)}">Show it among all cards</a></li>`;
  if (area) body += `<li><a href="../area/${area.slug}/">${esc(d.section)}: the area summary</a></li>`;
  body += "</ul>";
  if (where === "all") {
    const list = (ids) => ids.length ? "<ul>" + ids.map((x) => `<li><button class="link" data-go="${esc(x)}">${esc(C[x].title)}</button></li>`).join("") + "</ul>" : "<p>None.</p>";
    body += `<h3>Depends on</h3>${list(d.deps)}<h3>Used by</h3>${list(d.users)}`;
  }
  return body;
}
function wireCaps(root) {
  root.querySelectorAll("a[data-cap]").forEach((a) => a.onclick = (e) => {
    if (e.metaKey || e.ctrlKey || e.shiftKey) return;
    e.preventDefault();
    go({ view: "all-cards", cap: a.dataset.cap, area: null, id: null });
  });
}

// --------------------------------------------------------------- the tabs

const tabs = [...document.querySelectorAll('[role="tab"]')];
tabs.forEach((t) => {
  t.onclick = () => go({ view: t.dataset.view, id: t.dataset.view === "card" || t.dataset.view === "all-cards" ? state.id : null });
  t.onkeydown = (e) => {
    const i = tabs.indexOf(t);
    const j = e.key === "ArrowRight" ? (i + 1) % tabs.length : e.key === "ArrowLeft" ? (i - 1 + tabs.length) % tabs.length : -1;
    if (j >= 0) { tabs[j].focus(); tabs[j].click(); }
  };
});
const TITLES = { "area-map": "Area map", matrix: "Dependency matrix", "all-cards": "All cards", history: "History", card: "Card" };
function render() {
  for (const v of VIEWS) {
    document.getElementById("view-" + v).hidden = v !== state.view;
    const t = document.getElementById("tab-" + v);
    t.setAttribute("aria-selected", v === state.view ? "true" : "false");
    t.tabIndex = v === state.view ? 0 : -1;
  }
  if (state.view === "all-cards") Graph.show();
  if (state.view === "history") History.show(); else History.pause();
  if (state.view === "card") Nb.show();
  if (state.view === "matrix") Matrix.show();
  // A figure wider than a narrow screen starts scrolled to its middle.
  const fig = document.querySelector(`#view-${state.view} .figure`);
  if (fig && !fig.dataset.centred && fig.scrollWidth > fig.clientWidth) {
    fig.scrollLeft = (fig.scrollWidth - fig.clientWidth) / 2;
    fig.dataset.centred = "1";
  }
  document.title = `${state.view === "card" && state.id ? C[state.id].title : TITLES[state.view]}: Explore: ${D.site}`;
}

// ------------------------------------------------------------ the matrix

const Matrix = (() => {
  const list = document.querySelector("#view-matrix .cell-list");
  const cells = [...document.querySelectorAll("#view-matrix .mcell")];
  cells.forEach((c) => {
    c.addEventListener("click", () => go({ row: c.dataset.row, col: c.dataset.col }, false));
    c.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); c.dispatchEvent(new Event("click")); } });
  });
  function show() {
    cells.forEach((c) => c.classList.toggle("on", c.dataset.row === state.row && c.dataset.col === state.col));
    const row = state.row, col = state.col;
    if (!row || !col || !AREA[row] || !AREA[col]) {
      list.innerHTML = '<p class="hint">Click a cell to list the cards behind its count.</p>';
      return;
    }
    // Every dependency of a card in the row's area on a card in the column's area.
    const by = new Map();
    for (const id of ALL) {
      if (C[id].section !== row) continue;
      const used = C[id].deps.filter((u) => C[u].section === col);
      if (used.length) by.set(id, used);
    }
    const n = [...by.values()].reduce((s, x) => s + x.length, 0);
    const back = AREA_RANK[col] > AREA_RANK[row];
    const head = row === col
      ? `${n} ${n === 1 ? "dependency" : "dependencies"} inside ${esc(row)}`
      : `${esc(row)} builds on ${esc(col)} through ${n} ${n === 1 ? "dependency" : "dependencies"}`;
    list.innerHTML = `<h2>${head}</h2>`
      + (back ? `<p class="hint">${esc(col)} comes after ${esc(row)} in the layers, so these point back.</p>` : "")
      + `<p class="hint">Each card on the left uses the cards on its right. Click a card to open its neighbourhood.</p>`
      + '<ul class="pairs">' + [...by.entries()].sort((a, b) => cmp(C[a[0]].title, C[b[0]].title)).map(([id, used]) =>
        `<li>${pill(id)}<span class="uses" aria-label="uses">uses</span><span class="used">${used.map((u) => pill(u)).join("")}</span></li>`).join("") + "</ul>";
  }
  return { show };
})();

// --------------------------------------------------------- all the cards

const Graph = (() => {
  const view = document.getElementById("view-all-cards");
  const svg = document.getElementById("graph");
  const panel = view.querySelector(".panel");
  const CARD_W = D.cardW, LINE = D.line, GAP_X = 28, GAP_Y = 72;
  let vx = -16, vy = -16, vw = 1, vh = 1;
  const view_ = { x: 0, y: 0, w: 1, h: 1 };
  let moved = false, drawn = null, selected = null;
  const apply = () => svg.setAttribute("viewBox", `${view_.x} ${view_.y} ${view_.w} ${view_.h}`);

  // The same layout as scripts/render_graph.py: each card in the first row
  // with room below every card it uses, rows no wider than about the square
  // root of the number of cards, and a few sweeps that put each card near
  // the cards it is linked to.
  function layout(show) {
    const vis = new Set(show);
    const uses = (id) => C[id].deps.filter((u) => vis.has(u));
    const usedBy = (id) => C[id].users.filter((u) => vis.has(u));
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
    const sorted = [...show].sort((a, b) => d(a) - d(b) || cmp(C[a].section, C[b].section) || cmp(a, b));
    const row = {}, count = {};
    for (const id of sorted) {
      let r = 1 + Math.max(-1, ...uses(id).filter((u) => u in row).map((u) => row[u]));
      while ((count[r] || 0) >= rowMax) r++;
      row[id] = r; count[r] = (count[r] || 0) + 1;
    }
    const order = [];
    for (const id of sorted) (order[row[id]] = order[row[id]] || []).push(id);
    const rows = order.filter(Boolean);
    rows.forEach((r) => r.sort((a, b) => cmp(C[a].section, C[b].section) || cmp(a, b)));
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
      const h = Math.max(...r.map((id) => C[id].height));
      const x0 = (width - (r.length * slot - GAP_X)) / 2;
      r.forEach((id, i) => { pos[id] = [x0 + i * slot + CARD_W / 2, y + h / 2]; });
      y += h + GAP_Y;
    }
    const edges = [];
    for (const id of show) for (const u of uses(id)) {
      const [x1, ya] = pos[u], [x2, yb] = pos[id];
      const y1 = ya + C[u].height / 2, y2 = yb - C[id].height / 2 - 2;
      const bend = Math.min(GAP_Y, (y2 - y1) / 2);
      edges.push([u, id, `M${x1} ${y1}C${x1} ${y1 + bend} ${x2} ${y2 - bend} ${x2} ${y2}`]);
    }
    return { width: width + 32, height: y - GAP_Y + 32, pos, edges };
  }
  function card(id, pos, extra) {
    const n = C[id], [x, y] = pos[id], h = n.height;
    const x0 = x - CARD_W / 2, y0 = y - h / 2;
    const sy = y0 + 24 + LINE * n.lines.length + 4;
    return `<g class="node s-${n.status}${extra}" data-id="${esc(id)}" tabindex="0" role="button" aria-label="${esc(n.title)}, ${esc(n.statusWords)}">`
      + `<rect x="${x0}" y="${y0}" width="${CARD_W}" height="${h}" rx="8"/>`
      + n.lines.map((l, i) => `<text class="name" x="${x0 + 14}" y="${y0 + 24 + LINE * i}">${esc(l)}</text>`).join("")
      + `<circle class="dot" cx="${x0 + 18}" cy="${sy - 4}" r="4"/>`
      + `<text class="status" x="${x0 + 28}" y="${sy}">${esc((n.cid ? n.cid + " · " : "") + n.statusWords)}</text></g>`;
  }
  // The cards in the lens: every card, one area's cards with the cards they
  // build on, or the cards with one capability with the cards they build on.
  function shown() {
    const own = state.cap ? ALL.filter((id) => C[id].caps.includes(state.cap))
      : state.area ? ALL.filter((id) => C[id].section === state.area) : null;
    if (!own) return { ids: ALL, context: new Set() };
    const keep = new Set(own);
    own.forEach((id) => C[id].deps.forEach((u) => keep.add(u)));
    const mine = new Set(own);
    return { ids: ALL.filter((id) => keep.has(id)), context: new Set([...keep].filter((id) => !mine.has(id))) };
  }
  function draw() {
    const { ids, context } = shown();
    const L = layout(ids);
    vw = L.width; vh = L.height;
    svg.innerHTML = '<defs><marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z"/></marker>'
      + '<marker id="arrow-hot" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z"/></marker></defs>'
      + '<g class="edges">' + L.edges.map(([f, t, p]) => `<path class="edge" data-from="${esc(f)}" data-to="${esc(t)}" d="${p}" marker-end="url(#arrow)"/>`).join("") + "</g>"
      + '<g class="nodes">' + ids.map((id) => card(id, L.pos, context.has(id) ? " context" : "")).join("") + "</g>";
    svg.querySelectorAll(".node").forEach((n) => {
      n.addEventListener("click", () => select(n.dataset.id));
      n.addEventListener("keydown", (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); select(n.dataset.id); } });
    });
    view.querySelectorAll(".lens button[data-area]").forEach((b) =>
      b.classList.toggle("on", !state.cap && (b.dataset.area || null) === state.area));
    view.querySelector(".lens select").value = state.cap || "";
    const note = view.querySelector(".lens .note");
    const own = ids.length - context.size;
    note.innerHTML = state.cap
      ? `Showing the ${own} ${own === 1 ? "card" : "cards"} with capability <strong>${esc(state.cap)}</strong>, ${esc(D.caps[state.cap].name)}, and ${context.size} they build on, faded. Capability codes are on candidate cards only.`
      : state.area ? `Showing ${own} cards in this area and ${context.size} they build on, faded. <a href="../area/${AREA[state.area].slug}/">Read the area summary</a>.`
      : `Showing all ${ALL.length} cards.`;
    drawn = (state.area || "") + "|" + (state.cap || "");
    moved = false; fit();
  }
  view.querySelectorAll(".lens button[data-area]").forEach((b) =>
    b.onclick = () => go({ area: b.dataset.area || null, cap: null, id: null }));
  view.querySelector(".lens select").onchange = (e) => go({ cap: e.target.value || null, area: null, id: null });

  const CONTROLS = 52;  // room under the graph for the zoom buttons
  function fit() {
    const r = svg.getBoundingClientRect();
    if (!r.width) return;
    const scale = Math.min(r.width / vw, (r.height - CONTROLS) / vh, 1.2);
    view_.w = r.width / scale; view_.h = r.height / scale;
    view_.x = vx - (view_.w - vw) / 2; view_.y = vy - (view_.h - CONTROLS / scale - vh) / 2;
    apply();
  }
  function zoom(factor, cx, cy) {
    const r = svg.getBoundingClientRect();
    const px = cx === undefined ? 0.5 : (cx - r.left) / r.width;
    const py = cy === undefined ? 0.5 : (cy - r.top) / r.height;
    const nw = Math.min(Math.max(view_.w / factor, 200), Math.max(vw, 800) * 4), nh = nw * view_.h / view_.w;
    view_.x += (view_.w - nw) * px; view_.y += (view_.h - nh) * py; view_.w = nw; view_.h = nh;
    moved = true; apply();
  }
  svg.addEventListener("wheel", (e) => {
    e.preventDefault();
    if (e.ctrlKey || e.metaKey) zoom(Math.exp(-e.deltaY / 200), e.clientX, e.clientY);
    else {
      const r = svg.getBoundingClientRect();
      view_.x += e.deltaX * view_.w / r.width; view_.y += e.deltaY * view_.h / r.height; moved = true; apply();
    }
  }, { passive: false });
  let drag = null;
  svg.addEventListener("pointerdown", (e) => {
    if (e.target.closest(".node")) return;
    drag = { x: e.clientX, y: e.clientY, vx: view_.x, vy: view_.y, moved: false };
    svg.setPointerCapture(e.pointerId); svg.classList.add("dragging");
  });
  svg.addEventListener("pointermove", (e) => {
    if (!drag) return;
    const r = svg.getBoundingClientRect();
    const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
    if (Math.abs(dx) + Math.abs(dy) > 3) drag.moved = true;
    view_.x = drag.vx - dx * view_.w / r.width; view_.y = drag.vy - dy * view_.h / r.height; moved = true; apply();
  });
  svg.addEventListener("pointerup", (e) => {
    if (drag && !drag.moved && !e.target.closest(".node")) clear();
    drag = null; svg.classList.remove("dragging");
  });
  view.querySelector("[data-zoom=in]").onclick = () => zoom(1.4);
  view.querySelector("[data-zoom=out]").onclick = () => zoom(1 / 1.4);
  view.querySelector("[data-zoom=fit]").onclick = () => { moved = false; fit(); };

  const nodeEl = (id) => svg.querySelector(`.node[data-id="${CSS.escape(id)}"]`);
  function select(id, zoomIn) {
    if (!nodeEl(id)) { go({ area: null, cap: null, id }, false); return; }
    selected = id;
    const d = C[id];
    svg.classList.add("focus");
    svg.querySelectorAll(".node").forEach((n) => n.classList.remove("chosen", "near"));
    svg.querySelectorAll(".edge").forEach((p) => {
      const hot = p.dataset.from === id || p.dataset.to === id;
      p.classList.toggle("hot", hot);
      p.setAttribute("marker-end", hot ? "url(#arrow-hot)" : "url(#arrow)");
    });
    nodeEl(id).classList.add("chosen");
    if (zoomIn) {
      const r = svg.getBoundingClientRect(), b = nodeEl(id).getBoundingClientRect();
      const k = view_.w / r.width;
      const cx = view_.x + ((b.left + b.right) / 2 - r.left) * k, cy = view_.y + ((b.top + b.bottom) / 2 - r.top) * k;
      view_.w = r.width / 1.1; view_.h = r.height / 1.1;
      view_.x = cx - view_.w * 0.35; view_.y = cy - view_.h / 2;
      moved = true; apply();
    } else reveal(nodeEl(id));
    d.deps.concat(d.users).forEach((n) => { const el = nodeEl(n); if (el) el.classList.add("near"); });
    panel.querySelector(".body").innerHTML = details(id, "all");
    panel.classList.add("open");
    panel.querySelectorAll("[data-go]").forEach((b) => b.onclick = () => select(b.dataset.go));
    wireCaps(panel);
    if (state.id !== id) setQuiet({ id });
  }
  // Moves the view so a node is not hidden under the side panel or off the edge.
  function reveal(el) {
    const r = svg.getBoundingClientRect(), b = el.getBoundingClientRect();
    const visible = r.right - Math.min(panel.offsetWidth, r.width * 0.9) - 24;
    if (b.left >= r.left + 24 && b.right <= visible && b.top >= r.top + 24 && b.bottom <= r.bottom - 60) return;
    const k = view_.w / r.width;
    view_.x += ((b.left + b.right) / 2 - (r.left + visible) / 2) * k;
    view_.y += ((b.top + b.bottom) / 2 - (r.top + r.bottom) / 2) * k;
    apply();
  }
  function clear() {
    selected = null;
    svg.classList.remove("focus");
    svg.querySelectorAll(".chosen, .near, .hot").forEach((n) => n.classList.remove("chosen", "near", "hot"));
    svg.querySelectorAll(".edge").forEach((p) => p.setAttribute("marker-end", "url(#arrow)"));
    panel.classList.remove("open");
    if (state.id) setQuiet({ id: null });
  }
  panel.querySelector(".close").onclick = () => clear();
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && state.view === "all-cards") clear(); });
  window.addEventListener("resize", () => {
    if (state.view !== "all-cards" || !drawn) return;
    if (!moved) return fit();
    const r = svg.getBoundingClientRect();
    view_.h = view_.w * r.height / r.width; apply();
  });
  function show() {
    const key = (state.area || "") + "|" + (state.cap || "");
    if (drawn !== key) draw();
    else if (!moved) fit();
    if (state.id && state.id !== selected) select(state.id, true);
    else if (!state.id && selected) clear();
  }
  return { show };
})();

// ---------------------------------------------------------------- history

const History = (() => {
  const H = D.history;
  const view = document.getElementById("view-history");
  const svg = view.querySelector("svg.clusters");
  const dots = {};
  svg.querySelectorAll(".dot").forEach((d) => {
    dots[d.dataset.id] = d;
    d.addEventListener("click", () => go({ view: "card", id: d.dataset.id }));
  });
  const boxes = {};
  svg.querySelectorAll(".cluster").forEach((g) => { boxes[g.dataset.area] = { g, x: +g.dataset.x, y: +g.dataset.y, count: g.querySelector(".count") }; });
  const bundles = [...svg.querySelectorAll(".bundle")];
  const RANK = Object.fromEntries(D.order.map((s, i) => [s, i]));
  const CODE = H.codes;  // one letter per status
  // Cards are listed in the order they first appeared, so within a status
  // the dots keep that order.
  const IDX = Object.fromEntries(H.ids.map((id, i) => [id, i]));
  const stage = view.querySelector(".history-stage");
  const playBtn = view.querySelector(".play");
  let at = -1, timer = null;
  function paint(i) {
    const m = H.milestones[i], prev = i > 0 ? H.milestones[i - 1] : null;
    const per = {};
    H.ids.forEach((id, k) => {
      const c = m.st[k];
      if (c === ".") return;
      (per[H.area[k]] = per[H.area[k]] || []).push([id, CODE[c], prev ? prev.st[k] : "."]);
    });
    const shownIds = new Set();
    for (const [area, b] of Object.entries(boxes)) {
      const list = (per[area] || []).sort((a, z) => RANK[a[1]] - RANK[z[1]] || IDX[a[0]] - IDX[z[0]]);
      b.g.classList.toggle("off", !list.length);
      b.count.textContent = list.length;
      list.forEach(([id, st, was], k) => {
        const d = dots[id];
        shownIds.add(id);
        const x = b.x + 14 + (k % D.cols) * D.dot + D.dot / 2, y = b.y + 38 + Math.floor(k / D.cols) * D.dot + D.dot / 2;
        const appearing = !d.classList.contains("on");
        if (appearing) { d.style.transition = "none"; d.style.transform = `translate(${x}px, ${y}px)`; void d.getBoundingClientRect(); d.style.transition = ""; }
        else d.style.transform = `translate(${x}px, ${y}px)`;
        d.setAttribute("class", `dot on f-${st}`);
        d.querySelector("title").textContent = `${C[id] ? C[id].title : id}: ${D.words[st]}`;
        if (st === "open" && was !== "o" && prev && !reduceMotion()) d.classList.add("pulse");
      });
    }
    for (const [id, d] of Object.entries(dots)) if (!shownIds.has(id)) d.setAttribute("class", "dot");
    const pairs = Object.fromEntries(m.pairs.map(([a, b, n]) => [a + "|" + b, n]));
    bundles.forEach((p) => {
      const n = pairs[p.dataset.pair] || 0;
      p.style.strokeWidth = (0.6 + n * 0.45).toFixed(1);
      p.classList.toggle("off", !n);
    });
    view.querySelectorAll(".steps button").forEach((b, k) => b.classList.toggle("on", k === i));
    const c = view.querySelector(".caption-live");
    c.querySelector("h2").textContent = `${m.seq}. ${m.name.replaceAll("-", " ")}`;
    c.querySelector(".when").textContent = `${m.date} · ${shownIds.size} cards`;
    c.querySelector("p").textContent = m.description;
    c.querySelector(".counts").innerHTML = D.order.filter((k) => m.counts[k])
      .map((k) => `<span class="s-${k}"><i></i>${esc(D.words[k])} ${m.counts[k]}</span>`).join("");
    at = i;
  }
  function stop() { clearInterval(timer); timer = null; playBtn.textContent = at === H.milestones.length - 1 ? "Replay" : "Play"; }
  function step(i) { paint(i); setQuiet({ m: String(H.milestones[i].seq) }); }
  playBtn.onclick = () => {
    if (timer) return stop();
    if (at === H.milestones.length - 1) step(0);
    playBtn.textContent = "Pause";
    timer = setInterval(() => { if (at + 1 >= H.milestones.length) return stop(); step(at + 1); }, 2600);
  };
  view.querySelector("[data-step=prev]").onclick = () => { stop(); step(Math.max(0, at - 1)); };
  view.querySelector("[data-step=next]").onclick = () => { stop(); step(Math.min(H.milestones.length - 1, at + 1)); };
  view.querySelectorAll(".steps button").forEach((b, k) => b.onclick = () => { stop(); step(k); });
  document.addEventListener("keydown", (e) => {
    if (state.view !== "history" || e.target.closest("input, select, textarea")) return;
    if (e.key === "ArrowRight") view.querySelector("[data-step=next]").click();
    if (e.key === "ArrowLeft") view.querySelector("[data-step=prev]").click();
  });
  function show() {
    const asked = Number(state.m);
    const i = asked >= 1 && asked <= H.milestones.length ? asked - 1 : H.milestones.length - 1;
    if (i !== at) {
      // The first milestone shown appears at once; later ones move.
      if (at < 0) stage.classList.add("instant");
      paint(i);
      requestAnimationFrame(() => requestAnimationFrame(() => stage.classList.remove("instant")));
    }
    if (!timer) stop();
  }
  return { show, pause: () => { if (timer) stop(); } };
})();

// ------------------------------------------------- one card's neighbourhood

const Nb = (() => {
  const view = document.getElementById("view-card");
  const intro = view.querySelector(".intro .text");
  const scroll = view.querySelector(".nb-scroll");
  const summaryEl = view.querySelector(".nb-summary");
  const panel = view.querySelector(".nb-panel");
  let shownId = null, shownAll = null;
  const byArea = (a, b) => AREA_RANK[C[a].section] - AREA_RANK[C[b].section] || cmp(C[a].title, C[b].title);
  function distances(id, next) {
    const dist = new Map();
    let frontier = [id], d = 0;
    while (frontier.length) {
      d++;
      const nxt = [];
      for (const x of frontier) for (const u of next(x)) if (!dist.has(u) && u !== id) { dist.set(u, d); nxt.push(u); }
      frontier = nxt;
    }
    return dist;
  }
  function column(title, ids, side, k, grouped) {
    let inner = "";
    if (grouped) {
      let area = null;
      for (const id of ids) {
        if (C[id].section !== area) { area = C[id].section; inner += `<h4>${esc(AREA[area] ? AREA[area].short : area)}</h4>`; }
        inner += pill(id);
      }
    } else inner = ids.map((id) => pill(id)).join("");
    // On a narrow screen the columns stack: the card, then what it depends on, then what builds on it.
    const o = side === "up" ? k : 100 + k;
    return `<section class="nb-col" data-side="${side}" data-k="${k}" style="--o: ${o}"><h3>${title}</h3>${inner}</section>`;
  }
  function show() {
    const id = state.id;
    if (!id) {
      intro.innerHTML = `<h1>A card's neighbourhood</h1><p>Find a card with the search box, or pick one in another view.
        Its neighbourhood shows what it depends on and what builds on it.</p>`;
      summaryEl.innerHTML = "";
      scroll.innerHTML = `<div class="nb-empty"><p>The open questions and decisions that the most cards depend on:</p><ul>`
        + D.ranking.slice(0, 6).map((r) => `<li>${pill(r.id)} <span class="hint">${r.count} cards depend on it</span></li>`).join("")
        + "</ul></div>";
      panel.hidden = true;
      shownId = null;
      return;
    }
    if (id === shownId && state.all === shownAll) return;
    shownId = id; shownAll = state.all;
    const n = C[id];
    const up = distances(id, (x) => C[x].deps);
    const downAll = distances(id, (x) => C[x].users);
    const down = state.all ? downAll : new Map([...downAll].filter(([, d]) => d === 1));
    const maxu = Math.max(0, ...up.values()), maxd = Math.max(0, ...down.values());
    const direct = n.users.length;
    const areasOf = (ids) => new Set(ids.map((x) => C[x].section)).size;
    const directAreas = areasOf(n.users), allAreas = areasOf([...downAll.keys()]);
    intro.innerHTML = `<h1>What ${esc(n.title)} depends on and what builds on it</h1>
      <p>The cards it depends on are to the left, nearest first. The cards that build on it are to the right, grouped by area.
      Click a card to put it in the middle.</p>`;
    let summary = `${esc(n.title)} depends on ${up.size} ${up.size === 1 ? "card" : "cards"}`
      + (up.size ? ` (${n.deps.length} directly)` : "") + ". ";
    summary += direct ? `${direct} ${direct === 1 ? "card builds" : "cards build"} on it directly, in ${directAreas} ${directAreas === 1 ? "area" : "areas"}; `
      + `${downAll.size} ${downAll.size === 1 ? "card depends" : "cards depend"} on it directly or through other cards, in ${allAreas} ${allAreas === 1 ? "area" : "areas"}.`
      : "No card builds on it.";
    const toggle = downAll.size > direct
      ? ` <a class="toggle" href="?view=card${state.all ? "" : "&all=1"}#${encodeURIComponent(id)}" data-all="${state.all ? "" : "1"}">${state.all ? "Show only the cards that build on it directly" : `Show all ${downAll.size}`}</a>` : "";
    let cols = "";
    for (let k = maxu; k >= 1; k--) {
      const ids = [...up].filter(([, d]) => d === k).map(([x]) => x).sort(byArea);
      cols += column(k === 1 ? "Depends on directly" : `${k} steps back`, ids, "up", k, false);
    }
    if (!maxu) cols += `<section class="nb-col nb-none" data-side="up" style="--o: 1"><h3>Depends on</h3><p class="hint">Nothing: it builds on no other card.</p></section>`;
    cols += `<section class="nb-col nb-centre" data-side="centre" style="--o: 0"><h3>This card</h3>${pill(id, " centre")}</section>`;
    for (let k = 1; k <= maxd; k++) {
      const ids = [...down].filter(([, d]) => d === k).map(([x]) => x).sort(byArea);
      cols += column(k === 1 ? "Builds on it directly" : `${k} steps on`, ids, "down", k, true);
    }
    if (!maxd) cols += `<section class="nb-col nb-none" data-side="down" style="--o: 101"><h3>Builds on it</h3><p class="hint">No card builds on it yet.</p></section>`;
    summaryEl.innerHTML = summary + toggle;
    scroll.innerHTML = `<div class="nb-grid">${cols}<svg class="nb-links" aria-hidden="true"></svg></div>`;
    const t = summaryEl.querySelector(".toggle");
    if (t) t.onclick = (e) => { e.preventDefault(); go({ all: !!t.dataset.all }, false); };
    panel.hidden = false;
    panel.querySelector(".body").innerHTML = details(id, "card");
    wireCaps(panel);
    panel.scrollTop = 0;
    scroll.scrollLeft = 0;
    requestAnimationFrame(() => {
      // When the columns are wider than the view, start at the first column
      // from which the card and the first column to its right fit, so the
      // nearest cards on both sides are in view.
      const cols = [...scroll.querySelectorAll(".nb-col")];
      const centre = cols.findIndex((c) => c.classList.contains("nb-centre"));
      const need = (cols[centre + 1] || cols[centre]).getBoundingClientRect().right;
      const r = scroll.getBoundingClientRect(), room = r.width - 20;
      if (need - r.left > room) {
        const from = cols.slice(0, centre + 1).find((c) => need - c.getBoundingClientRect().left <= room) || cols[centre];
        scroll.scrollLeft = from.getBoundingClientRect().left - r.left - 20;
      }
      links();
      edges();
    });
  }
  // A fade at an edge with more to scroll to.
  function edges() {
    const more = scroll.scrollWidth - scroll.clientWidth;
    scroll.classList.toggle("more-left", scroll.scrollLeft > 2);
    scroll.classList.toggle("more-right", scroll.scrollLeft < more - 2);
  }
  scroll.addEventListener("scroll", edges, { passive: true });
  // The connectors: from each card to the cards that use it, drawn between
  // the columns.
  function links() {
    const grid = scroll.querySelector(".nb-grid");
    if (!grid) return;
    const svg = grid.querySelector(".nb-links");
    const g = grid.getBoundingClientRect();
    svg.setAttribute("width", grid.scrollWidth); svg.setAttribute("height", grid.scrollHeight);
    const at = {};
    grid.querySelectorAll(".pill").forEach((p) => {
      const r = p.getBoundingClientRect(), col = p.closest(".nb-col");
      const side = col.dataset.side, k = +col.dataset.k || 0;
      at[p.dataset.id] = { l: r.left - g.left, r: r.right - g.left, y: (r.top + r.bottom) / 2 - g.top, c: side === "up" ? -k : side === "down" ? k : 0 };
    });
    let paths = "";
    for (const [u, pu] of Object.entries(at)) {
      for (const v of C[u].deps) {
        const pv = at[v];
        if (!pv || pv.c >= pu.c) continue;
        if (pv.c < 0 && pu.c > 0) continue;
        const x1 = pv.r, x2 = pu.l - 2, mid = (x1 + x2) / 2;
        paths += `<path data-from="${esc(v)}" data-to="${esc(u)}" d="M${x1} ${pv.y}C${mid} ${pv.y} ${mid} ${pu.y} ${x2} ${pu.y}"/>`;
      }
    }
    svg.innerHTML = paths;
  }
  scroll.addEventListener("pointerover", (e) => {
    const p = e.target.closest(".pill");
    scroll.querySelectorAll(".nb-links path").forEach((x) =>
      x.classList.toggle("hot", !!p && (x.dataset.from === p.dataset.id || x.dataset.to === p.dataset.id)));
  });
  new ResizeObserver(() => { if (state.view === "card") links(); }).observe(scroll);
  return { show };
})();

// ----------------------------------------------------------------- search

(() => {
  const input = document.getElementById("search");
  const out = document.getElementById("search-results");
  const index = ALL.map((id) => {
    const n = C[id];
    return { id, title: n.title.toLowerCase(), cid: n.cid ? n.cid.toLowerCase() : "",
             lean: n.lean.map((x) => x.toLowerCase()) };
  });
  let hits = [], active = -1;
  function find(q) {
    q = q.trim().toLowerCase();
    if (!q) return [];
    const cnum = q.match(/^c-?0*(\d+)$/);
    const words = q.split(/\s+/);
    const scored = [];
    for (const e of index) {
      let s = 0, via = null;
      if (cnum && e.cid && Number(e.cid.slice(2)) === Number(cnum[1])) s = 100;
      else if (words.every((w) => e.title.includes(w))) s = e.title.startsWith(q) ? 50 : 30;
      else {
        const l = e.lean.find((x) => words.every((w) => x.includes(w)));
        if (l) { s = l.endsWith("." + q) ? 40 : 10; via = C[e.id].lean[e.lean.indexOf(l)]; }
      }
      if (s) scored.push({ id: e.id, s, via });
    }
    return scored.sort((a, b) => b.s - a.s || cmp(C[a.id].title, C[b.id].title)).slice(0, 12);
  }
  function paint() {
    if (!input.value.trim()) { out.hidden = true; input.setAttribute("aria-expanded", "false"); return; }
    out.innerHTML = hits.length ? hits.map((h, i) => {
      const n = C[h.id];
      return `<li role="option" id="hit-${i}" data-id="${esc(h.id)}" aria-selected="${i === active}" class="${i === active ? "on" : ""}">`
        + `<span class="ht">${esc(n.title)}</span><span class="hm"><span class="chip s-${n.status}"><i></i>${esc(n.statusWords)}</span>`
        + `${n.cid ? esc(n.cid) + " · " : ""}${esc(n.section)}${h.via ? ` · <code>${esc(h.via)}</code>` : ""}</span></li>`;
    }).join("") : '<li class="none">No card matches.</li>';
    out.hidden = false;
    input.setAttribute("aria-expanded", "true");
    input.setAttribute("aria-activedescendant", active >= 0 ? `hit-${active}` : "");
  }
  function open(id) {
    input.value = ""; hits = []; active = -1; paint(); input.blur();
    go({ view: "card", id });
  }
  input.addEventListener("input", () => { hits = find(input.value); active = hits.length ? 0 : -1; paint(); });
  input.addEventListener("keydown", (e) => {
    if (e.key === "ArrowDown" && hits.length) { e.preventDefault(); active = (active + 1) % hits.length; paint(); }
    else if (e.key === "ArrowUp" && hits.length) { e.preventDefault(); active = (active - 1 + hits.length) % hits.length; paint(); }
    else if (e.key === "Enter" && hits.length) { e.preventDefault(); open(hits[Math.max(active, 0)].id); }
    else if (e.key === "Escape") { input.value = ""; hits = []; paint(); }
  });
  out.addEventListener("pointerdown", (e) => { const li = e.target.closest("li[data-id]"); if (li) { e.preventDefault(); open(li.dataset.id); } });
  input.addEventListener("blur", () => setTimeout(() => { out.hidden = true; input.setAttribute("aria-expanded", "false"); }, 150));
  input.addEventListener("focus", () => { if (input.value.trim()) paint(); });
  document.addEventListener("keydown", (e) => {
    if (e.key === "/" && !e.target.closest("input, select, textarea")) { e.preventDefault(); input.focus(); }
  });
})();

render();
})();
