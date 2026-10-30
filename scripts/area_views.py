#!/usr/bin/env python3
"""Drawings of the graph by area, shared by the Explore page, the area pages
and the tour: the area map, the dependency matrix, the areas as clusters of
dots, and a card's neighbourhood.  Each returns an SVG string drawn from a
graph_model.Model; AREA_CSS styles them in the site's palette, in light and
dark mode.
"""

import html
import math

from graph_model import STATUS_ORDER, short, slug

esc = html.escape

AREA_CSS = """
svg.areas { display: block; width: 100%; height: auto; }
svg.areas text { font-family: system-ui, -apple-system, "Segoe UI", sans-serif; fill: var(--ink); }
.f-modelled { fill: var(--lean); background: var(--lean); } .f-proven { fill: var(--good); background: var(--good); }
.f-open { fill: var(--critical); background: var(--critical); } .f-decision { fill: var(--warning); background: var(--warning); }
.f-ready { fill: var(--ready); background: var(--ready); } .f-waiting { fill: var(--waiting); background: var(--waiting); }
svg.areas .t1 { font-size: 13.5px; font-weight: 650; } svg.areas .t1s { font-size: 13px; font-weight: 600; }
svg.areas .t2 { font-size: 12px; fill: var(--ink-2); } svg.areas .t2s { font-size: 11.5px; fill: var(--ink-2); }
svg.areas .t3 { font-size: 11px; fill: var(--muted); }
svg.areas .head { font-weight: 600; letter-spacing: .04em; text-transform: uppercase; }
svg.areas .box { fill: var(--page); stroke: var(--axis); stroke-width: 1.2; }
svg.areas a .box { transition: stroke .15s, stroke-width .15s; }
svg.areas a:hover .box, svg.areas a:focus .box { stroke: var(--ready); stroke-width: 2; }
svg.areas a:focus { outline: none; }
svg.areas .link { fill: none; stroke: var(--ink-2); stroke-opacity: .42; }
svg.areas .link.back { stroke-dasharray: 5 4; }
svg.areas .link.thin { stroke-width: 1; stroke-opacity: .45; }
svg.areas .arrowhead { fill: var(--ink-2); fill-opacity: .7; }
svg.areas .bundle { fill: none; stroke: var(--ink-2); stroke-opacity: .22; }
svg.areas .pill rect { fill: var(--surface); stroke: var(--axis); }
svg.areas .pill text { font-size: 11px; font-weight: 600; fill: var(--ink-2); }
svg.areas .diag { fill: none; stroke: var(--ink-2); stroke-width: 1.5; }
svg.areas .empty { fill: var(--page); stroke: var(--ring); }
svg.areas .hot { fill: var(--ink); stroke: none; }
svg.areas .backcell { stroke: var(--critical); stroke-width: 2; stroke-dasharray: 4 3; }
svg.areas .cell { font-size: 12px; font-variant-numeric: tabular-nums; fill: var(--ink); pointer-events: none; }
svg.areas .cell.on { fill: var(--page); font-weight: 600; }
svg.areas .mcell { cursor: pointer; }
svg.areas .mcell:hover rect, svg.areas .mcell:focus rect, svg.areas .mcell.on rect { stroke: var(--ready); stroke-width: 2.5; stroke-dasharray: none; }
svg.areas .mcell:focus { outline: none; }
svg.areas .nbp rect { fill: var(--surface); stroke: var(--axis); }
svg.areas .nbp.center rect { stroke: var(--ink); stroke-width: 2; }
svg.areas .nbp.s-open rect { stroke: var(--critical); } svg.areas .nbp.s-decision rect { stroke: var(--warning); }
svg.areas .nbp a:hover rect { stroke-width: 2; }
svg.areas.nbh { width: auto; max-width: none; }
"""


def arrow(id_):
    # Arrowheads keep one size whatever the link's width.
    return (f'<defs><marker id="{id_}" viewBox="0 0 10 10" refX="8" refY="5" markerUnits="userSpaceOnUse" '
            'markerWidth="11" markerHeight="11" orient="auto-start-reverse"><path class="arrowhead" d="M0 0L10 5L0 10z"/>'
            '</marker></defs>')


def status_bar(x, y, w, h, counts, words):
    total = sum(counts.values()) or 1
    out, cx = [], x
    for s in STATUS_ORDER:
        if not counts.get(s):
            continue
        sw = w * counts[s] / total
        out.append(f'<rect class="f-{s}" x="{cx:.1f}" y="{y}" width="{max(sw - 2, 1):.1f}" height="{h}" rx="2">'
                   f'<title>{esc(words[s])}: {counts[s]}</title></rect>')
        cx += sw
    return "".join(out)


def curve(x1, y1, x2, y2):
    """A link between two points, and where its label goes.  Points at one
    height get an arc over the top."""
    if abs(y2 - y1) < 1:
        mid = (x1 + x2) / 2
        lift = 40 + abs(x2 - x1) * 0.12
        return f"M{x1:.1f} {y1:.1f}Q{mid:.1f} {y1 - lift:.1f} {x2:.1f} {y2:.1f}", (mid, y1 - lift / 2)
    dy = (y2 - y1) * 0.5
    return (f"M{x1:.1f} {y1:.1f}C{x1:.1f} {y1 + dy:.1f} {x2:.1f} {y2 - dy:.1f} {x2:.1f} {y2:.1f}",
            ((x1 + x2) / 2, (y1 + y2) / 2))


def summary_words(c):
    tail = []
    if c["open"]:
        tail.append(f'{c["open"]} open')
    if c["decision"]:
        tail.append(f'{c["decision"]} to decide')
    return tail


# ------------------------------------------------------------------ area map

MAP_W, BOX_W, BOX_H, MAP_GAP_X, MAP_GAP_Y = 1240, 224, 96, 26, 84
MIN_LINK, LABEL_FROM = 5, 8


def map_positions(m):
    pos = {}
    for li, layer in enumerate(m.layers):
        span = len(layer) * BOX_W + (len(layer) - 1) * MAP_GAP_X
        x0 = (MAP_W - span) / 2
        for i, a in enumerate(layer):
            pos[a] = (x0 + i * (BOX_W + MAP_GAP_X), 24 + li * (BOX_H + MAP_GAP_Y))
    return pos, 24 + len(m.layers) * (BOX_H + MAP_GAP_Y) - MAP_GAP_Y + 24


def area_map(m, words, href, marker="am"):
    """One box per area with its status bar and counts, in layers, and an
    arrow from each area to the areas that build on it, as thick as the
    number of dependencies.  `href(area)` is where a box leads."""
    pos, H = map_positions(m)
    cross = {k: v for k, v in m.pair.items() if k[0] != k[1]}
    shown = {k: v for k, v in cross.items() if v >= MIN_LINK}
    out = [f'<svg class="areas map" viewBox="0 0 {MAP_W} {H}" role="img" aria-labelledby="{marker}-t">'
           f'<title id="{marker}-t">{len(m.order)} areas in {len(m.layers)} layers, with an arrow from each area to '
           f'the areas that build on it.</title>', arrow(marker)]
    labels = []
    for (a, b), w in sorted(shown.items(), key=lambda kv: kv[1]):
        ax, ay = pos[a]
        bx, by = pos[b]
        back = m.is_back(a, b)
        if m.layer[a] == m.layer[b]:
            side = BOX_W / 4 if bx > ax else -BOX_W / 4
            x1, y1, x2, y2 = ax + BOX_W / 2 + side, ay, bx + BOX_W / 2 - side, by
        elif m.layer[b] < m.layer[a]:
            x1, y1, x2, y2 = ax + BOX_W / 2 + 30, ay, bx + BOX_W / 2 + 30, by + BOX_H
        else:
            off = (bx - ax) * 0.08
            x1, y1, x2, y2 = ax + BOX_W / 2 + off, ay + BOX_H, bx + BOX_W / 2 - off * 0.3, by
        d, (mx, my) = curve(x1, y1, x2, y2)
        out.append(f'<path class="link{" back" if back else ""}" d="{d}" stroke-width="{1 + w * 0.32:.1f}" '
                   f'marker-end="url(#{marker})"><title>{esc(b)} builds on {esc(a)}: {w} dependencies</title></path>')
        if w >= LABEL_FROM:
            labels.append(f'<g class="pill"><rect x="{mx - 13:.1f}" y="{my - 9:.1f}" width="26" height="18" rx="9"/>'
                          f'<text x="{mx:.1f}" y="{my + 4:.1f}" text-anchor="middle">{w}</text></g>')
    out += labels
    for a, (x, y) in pos.items():
        c = m.counts(a)
        n = sum(c.values())
        tail = summary_words(c)
        label = f"{a}: {n} cards" + (", " + ", ".join(tail) if tail else "") + ". Open the area summary."
        out.append(f'<a href="{esc(href(a))}" aria-label="{esc(label)}"><g class="area">'
                   f'<rect class="box" x="{x}" y="{y}" width="{BOX_W}" height="{BOX_H}" rx="10"/>'
                   f'<text class="t1" x="{x + 14}" y="{y + 26}">{esc(short(a))}</text>'
                   f'<text class="t2" x="{x + 14}" y="{y + 46}">{n} cards{" · " + ", ".join(tail) if tail else ""}</text>'
                   + status_bar(x + 14, y + 62, BOX_W - 28, 14, c, words) + "</g></a>")
    out.append("</svg>")
    return "".join(out), len(cross) - len(shown)


# -------------------------------------------------------------------- matrix

CELL, ROW_LABEL, MATRIX_TOP = 40, 210, 132


def matrix(m):
    """Areas by areas: a row's cell under a column counts the dependencies of
    the row's cards on the column's cards.  Rows and columns follow the
    layers, so a dependency on an area listed later sits above the diagonal,
    outlined dashed."""
    n = len(m.order)
    W, H = ROW_LABEL + n * CELL + 70, MATRIX_TOP + n * CELL + 12
    cross = [v for (a, b), v in m.pair.items() if a != b]
    top = max(cross) if cross else 1
    out = [f'<svg class="areas matrix" viewBox="0 0 {W} {H}" role="group" aria-label="Dependencies between areas: '
           f'each row is an area, each column an area it builds on, and each cell the number of dependencies.">']
    for j, a in enumerate(m.order):
        x = ROW_LABEL + j * CELL + CELL / 2 + 4
        out.append(f'<text class="t2" transform="translate({x:.1f} {MATRIX_TOP - 10}) rotate(-45)">{esc(short(a))}</text>')
    for i, row in enumerate(m.order):
        y = MATRIX_TOP + i * CELL
        out.append(f'<text class="t2" x="{ROW_LABEL - 12}" y="{y + CELL / 2 + 4}" text-anchor="end">{esc(short(row))}</text>')
        for j, col in enumerate(m.order):
            x = ROW_LABEL + j * CELL
            v = m.pair.get((col, row), 0)
            attrs = (f'class="mcell" data-row="{esc(row)}" data-col="{esc(col)}" tabindex="0" role="button" '
                     f'aria-label="{esc(row)} builds on {esc(col) if i != j else "itself"}: {v} '
                     f'dependenc{"y" if v == 1 else "ies"}"')
            if i == j:
                out.append(f'<g {attrs}><rect class="diag" x="{x + 1}" y="{y + 1}" width="{CELL - 2}" height="{CELL - 2}" rx="4"/>'
                           f'<text class="cell" x="{x + CELL / 2}" y="{y + CELL / 2 + 4}" text-anchor="middle">{v}</text></g>')
                continue
            if not v:
                out.append(f'<rect class="empty" x="{x + 1}" y="{y + 1}" width="{CELL - 2}" height="{CELL - 2}" rx="4"/>')
                continue
            op = 0.12 + 0.78 * math.sqrt(v / top)
            back = j > i
            out.append(f'<g {attrs}><rect class="hot{" backcell" if back else ""}" x="{x + 1}" y="{y + 1}" '
                       f'width="{CELL - 2}" height="{CELL - 2}" rx="4" fill-opacity="{op:.2f}"/>'
                       f'<text class="cell{" on" if op > 0.55 else ""}" x="{x + CELL / 2}" y="{y + CELL / 2 + 4}" '
                       f'text-anchor="middle">{v}</text></g>')
    out.append("</svg>")
    return "".join(out)


# ------------------------------------------------------------ dot clusters

DOT, COLS, CL_W, CL_GAP_X, CL_GAP_Y = 12, 16, 224, 26, 64


def cluster_layout(m, sizes):
    """The box of each area, sized for `sizes[area]` dots."""
    heights = {a: 40 + max(1, math.ceil(sizes.get(a, 0) / COLS)) * DOT + 10 for a in m.order}
    layer_h = [max(heights[a] for a in layer) for layer in m.layers]
    pos, y = {}, 16
    for li, layer in enumerate(m.layers):
        span = len(layer) * CL_W + (len(layer) - 1) * CL_GAP_X
        x0 = (MAP_W - span) / 2
        for i, a in enumerate(layer):
            pos[a] = (x0 + i * (CL_W + CL_GAP_X), y + (layer_h[li] - heights[a]) / 2)
        y += layer_h[li] + CL_GAP_Y
    return pos, heights, y - CL_GAP_Y + 16


def dot_slot(x, y, k):
    return (round(x + 14 + (k % COLS) * DOT + DOT / 2, 1), round(y + 38 + (k // COLS) * DOT + DOT / 2, 1))


def clusters(m, members, statuses, titles, pairs):
    """Each area as a box of dots, one per card, sorted by status, with one
    bundle per pair of areas.  `members[area]` lists the cards to draw,
    `statuses` gives each card's status, and `pairs` lists the area pairs
    that get a bundle.  The Explore page's History tab moves and recolors
    the dots by milestone."""
    sizes = {a: len(members.get(a, [])) for a in m.order}
    pos, heights, H = cluster_layout(m, sizes)
    out = [f'<svg class="areas clusters" viewBox="0 0 {MAP_W} {H}" role="img" aria-label="Each area as a box of '
           f'dots, one dot for each card, colored by its status.">']
    out.append('<g class="bundles">')
    for a, b in pairs:
        ax, ay = pos[a]
        bx, by = pos[b]
        d, _ = curve(ax + CL_W / 2, ay + heights[a], bx + CL_W / 2, by)
        out.append(f'<path class="bundle" data-pair="{esc(a)}|{esc(b)}" d="{d}" stroke-width="1"/>')
    out.append("</g>")
    rank = {s: i for i, s in enumerate(STATUS_ORDER)}
    for a in m.order:
        x, y = pos[a]
        out.append(f'<g class="cluster" data-area="{esc(a)}" data-x="{x}" data-y="{y}">'
                   f'<rect class="box" x="{x}" y="{y}" width="{CL_W}" height="{heights[a]}" rx="10"/>'
                   f'<text class="t1" x="{x + 12}" y="{y + 24}">{esc(short(a))}</text>'
                   f'<text class="t3 count" x="{x + CL_W - 12}" y="{y + 24}" text-anchor="end">{sizes[a]}</text>')
        # By status, then in the order the cards first appeared, as the page's script sorts them.
        ids = sorted(members.get(a, []), key=lambda i: rank.get(statuses.get(i), 9))
        for k, i in enumerate(ids):
            cx, cy = dot_slot(x, y, k)
            st = statuses.get(i, "waiting")
            out.append(f'<circle class="dot on f-{st}" data-id="{esc(i)}" r="4.3" '
                       f'style="transform: translate({cx}px, {cy}px)"><title>{esc(titles.get(i, i))}</title></circle>')
        out.append("</g>")
    out.append("</svg>")
    return "".join(out)


# --------------------------------------------------------- a neighbourhood

PILL_W, PILL_H, PILL_GAP_X, PILL_GAP_Y = 228, 40, 64, 8


def neighbourhood(m, center, words, href, down_all=True, up_steps=None, pill_w=PILL_W, gap_x=PILL_GAP_X):
    """A static drawing of one card's neighbourhood: the card in the middle,
    the cards it depends on to the left by distance, and the cards that
    build on it to the right, by distance, grouped by area.  `href(label)` is
    where a card leads; `up_steps` limits how far back the left side goes.
    The drawing is meant at its own size: the SVG carries its width."""
    up = m.upstream(center)
    if up_steps:
        up = {k: v for k, v in up.items() if v <= up_steps}
    down = m.down_distance(center)
    if not down_all:
        down = {k: v for k, v in down.items() if v == 1}
    maxu, maxd = max(up.values(), default=0), max(down.values(), default=0)
    title_of = lambda i: m.by[i]["title"]  # noqa: E731
    area_rank = {a: i for i, a in enumerate(m.order)}
    left = {k: sorted((u for u, v in up.items() if v == k), key=lambda u: (area_rank[m.by[u]["section"]], title_of(u)))
            for k in range(1, maxu + 1)}
    right = {}
    for k in range(1, maxd + 1):
        ids = sorted((u for u, v in down.items() if v == k), key=lambda u: (area_rank[m.by[u]["section"]], title_of(u)))
        groups = []
        for u in ids:
            if not groups or groups[-1][0] != m.by[u]["section"]:
                groups.append((m.by[u]["section"], []))
            groups[-1][1].append(u)
        right[k] = groups
    step = PILL_H + PILL_GAP_Y
    col_h = [len(v) * step for v in left.values()] + [sum(24 + len(g) * step for _, g in gs) for gs in right.values()]
    H = max(col_h + [PILL_H]) + 56
    xs = {("u", k): 16 + (maxu - k) * (pill_w + gap_x) for k in left}
    cx = 16 + maxu * (pill_w + gap_x)
    for k in right:
        xs[("d", k)] = cx + k * (pill_w + gap_x)
    W = cx + (maxd + 1) * (pill_w + gap_x) - gap_x + 16
    pos = {}
    for k, ids in left.items():
        y0 = 40 + (H - 56 - len(ids) * step) / 2
        for i, u in enumerate(ids):
            pos[u] = (xs[("u", k)], y0 + i * step)
    pos[center] = (cx, 40 + (H - 56 - PILL_H) / 2)
    heads = []
    for k, groups in right.items():
        y = 40
        for area, members in groups:
            heads.append(f'<text class="t3 head" x="{xs[("d", k)]}" y="{y + 12}">{esc(short(area))}</text>')
            y += 24
            for u in members:
                pos[u] = (xs[("d", k)], y)
                y += step
    out = [f'<svg class="areas nbh" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="{esc(title_of(center))} in the '
           f'middle, the cards it depends on to the left, and the cards that build on it to the right.">',
           arrow("nb")]
    for k in left:
        out.append(f'<text class="t3" x="{xs[("u", k)] + pill_w / 2}" y="20" text-anchor="middle">'
                   f'{"Depends on directly" if k == 1 else f"{k} steps back"}</text>')
    out.append(f'<text class="t3" x="{cx + pill_w / 2}" y="20" text-anchor="middle">This card</text>')
    for k in right:
        out.append(f'<text class="t3" x="{xs[("d", k)] + pill_w / 2}" y="20" text-anchor="middle">'
                   f'{"Builds on it directly" if k == 1 else f"{k} steps on"}</text>')
    col = {center: 0, **{u: -v for u, v in up.items()}, **{u: v for u, v in down.items()}}
    for u in pos:
        for v in m.by[u]["uses"]:
            if v not in pos or col[v] >= col[u]:
                continue
            if (col[u] > 0) != (col[v] >= 0) and col[u] != 0 and col[v] != 0:
                continue
            x1, y1 = pos[v][0] + pill_w, pos[v][1] + PILL_H / 2
            x2, y2 = pos[u][0], pos[u][1] + PILL_H / 2
            mid = (x1 + x2) / 2
            out.append(f'<path class="link thin" d="M{x1:.1f} {y1:.1f}C{mid:.1f} {y1:.1f} {mid:.1f} {y2:.1f} '
                       f'{x2:.1f} {y2:.1f}" marker-end="url(#nb)"/>')
    out += heads
    for u, (x, y) in pos.items():
        n = m.by[u]
        chars = int((pill_w - 24) / 6.0)
        t = n["title"] if len(n["title"]) <= chars else n["title"][:chars - 2].rstrip() + "…"
        sub = (n["cid"] + " · " if n["cid"] else "") + words[n["status"]]
        cls = "nbp center" if u == center else "nbp"
        out.append(f'<g class="{cls} s-{n["status"]}"><a href="{esc(href(u))}"><title>{esc(n["title"])}</title>'
                   f'<rect x="{x}" y="{y}" width="{pill_w}" height="{PILL_H}" rx="7"/>'
                   f'<text class="t2s" x="{x + 12}" y="{y + 16}" style="font-weight:600;fill:var(--ink)">{esc(t)}</text>'
                   f'<circle class="f-{n["status"]}" cx="{x + 16}" cy="{y + 28}" r="4"/>'
                   f'<text class="t3" x="{x + 25}" y="{y + 32}">{esc(sub)}</text></a></g>')
    out.append("</svg>")
    return "".join(out), W


__all__ = ["AREA_CSS", "area_map", "matrix", "clusters", "cluster_layout", "dot_slot", "neighbourhood", "slug",
           "status_bar"]
