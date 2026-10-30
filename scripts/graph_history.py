#!/usr/bin/env python3
"""Record how the dependency graph grows, one snapshot per milestone.

  python3 scripts/graph_history.py snapshot <name> "<description>" [--commit REF] [--tag]
  python3 scripts/graph_history.py layout
  python3 scripts/graph_history.py frames [--dark]

`snapshot` saves the graph at a commit (HEAD by default) as
history/NNNN-<name>.json and adds it to history/index.json; with --tag it
also creates the annotated git tag milestone/<name> on that commit.  The
nodes and their dependencies come from blueprint/src/content.tex at that
commit; the statuses of nodes in Lean come from the current build/status.json
(run `lake exe status` first).  For a past commit that is exact only while no
proof's status has changed since, which docs/motion-brief.md notes for each
milestone.

`layout` places every node that appears in any snapshot once, with the site's
row layout widened to about 16:9 for video, and writes history/layout.json, so
a node keeps its position from frame to frame.  Run it after the last snapshot
you want to animate.

`frames` draws one SVG per milestone into build/frames/, every frame on the
same canvas, and writes build/frames/frames.json: for each milestone, the
nodes that appear, the nodes whose status changes and from what, and the box
around the nodes present, for a camera to follow.  `--dark` draws the frames
in the site's dark colors.

The snapshots feed the motion piece described in docs/motion-brief.md.
"""

import datetime
import html
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import render_graph  # noqa: E402
from render_graph import CARD_W, LINE, STATUS_WORDS, card_height, graph_data, layout, wrap  # noqa: E402
from render_progress import classify, load_decls, parse_nodes  # noqa: E402
from render_status import read_blueprint  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
HISTORY = ROOT / "history"
INDEX = HISTORY / "index.json"


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, check=True).stdout.strip()


def load_index():
    return json.loads(INDEX.read_text()) if INDEX.exists() else {"milestones": []}


def snapshot(name, description, ref="HEAD", tag=False):
    commit = git("rev-parse", ref)
    date = git("show", "-s", "--format=%cI", commit)
    src = read_blueprint(lambda rel: git("show", f"{commit}:blueprint/src/{rel}"))
    nodes = parse_nodes(src)
    classify(nodes, load_decls())
    labels = {n["label"] for n in nodes}
    index = load_index()
    if any(m["name"] == name for m in index["milestones"]):
        sys.exit(f"history already has a milestone named {name}")
    seq = len(index["milestones"]) + 1
    file = f"{seq:04d}-{name}.json"
    data = {"milestone": {"seq": seq, "name": name, "description": description,
                          "commit": commit, "date": date, "tag": f"milestone/{name}" if tag else None}}
    data.update(graph_data(nodes, labels))
    HISTORY.mkdir(exist_ok=True)
    (HISTORY / file).write_text(json.dumps(data, indent=1) + "\n")
    counts = {}
    for n in data["nodes"]:
        counts[n["status"]] = counts.get(n["status"], 0) + 1
    index["milestones"].append({**data["milestone"], "file": file, "nodes": len(nodes), "statusCounts": counts})
    INDEX.write_text(json.dumps(index, indent=1) + "\n")
    if tag:
        git("tag", "-a", f"milestone/{name}", commit, "-m", description)
    print(f"saved history/{file}: {len(nodes)} nodes at {commit[:7]}" + (f", tagged milestone/{name}" if tag else ""))


# Cards per row in the motion layout: wide enough that the full graph is about
# 16:9, the shape of a video frame.  The site uses narrower rows.
MOTION_ROW_MAX = 26


def union_layout():
    """One position for every node that appears in any snapshot."""
    nodes, seen = [], {}
    for m in load_index()["milestones"]:
        for n in json.loads((HISTORY / m["file"]).read_text())["nodes"]:
            if n["id"] not in seen:
                seen[n["id"]] = {"label": n["id"], "uses": n["uses"], "section": n["area"]}
                nodes.append(seen[n["id"]])
            # A card shows its latest title.
            seen[n["id"]]["lines"] = wrap(n["title"])
    labels = {n["label"] for n in nodes}
    render_graph.ROW_MAX = MOTION_ROW_MAX
    width, height, pos, edges = layout(nodes, labels)
    out = {"width": width, "height": height, "cardWidth": CARD_W,
           "nodes": {n["label"]: {"x": pos[n["label"]][0], "y": pos[n["label"]][1],
                                  "height": card_height(n["lines"]), "lines": n["lines"]} for n in nodes},
           "edges": [{"from": t, "to": h, "path": d} for t, h, d in edges],
           "generated": datetime.datetime.now(datetime.UTC).isoformat(timespec="seconds")}
    (HISTORY / "layout.json").write_text(json.dumps(out, indent=1) + "\n")
    print(f"wrote history/layout.json: {len(nodes)} nodes, {len(edges)} edges")


# The site's colors (scripts/render_graph.py): the status color, and the share
# of it mixed into the card's fill.
STATUS_COLOR = {"modelled": "#e87ba4", "proven": "#0ca30c", "open": "#d03b3b",
                "decision": "#fab219", "ready": "#2a78d6", "waiting": "#898781"}
TINT = {"modelled": 0.07, "proven": 0.08, "open": 0.10, "decision": 0.12, "ready": 0.10, "waiting": 0.0}
RIM = {"modelled": 1.5, "proven": 1.5, "open": 2, "decision": 2, "ready": 2, "waiting": 1.25}
THEMES = {
    "light": {"page": "#f9f9f7", "surface": "#fcfcfb", "ink": "#0b0b0b", "ink2": "#52514e", "axis": "#b9b8b0"},
    "dark": {"page": "#0d0d0d", "surface": "#1a1a19", "ink": "#f0efec", "ink2": "#c3c2b7", "axis": "#55544f"},
}


def mix(color, surface, share):
    """color-mix(in srgb, color share, surface), as the site's stylesheet does."""
    a = [int(color[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(surface[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x * share + y * (1 - share)):02x}" for x, y in zip(a, b))


def frame_svg(lay, snap, theme):
    t = THEMES[theme]
    present = {n["id"]: n for n in snap["nodes"]}
    w, h = lay["width"], lay["height"]
    out = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="-16 -16 {w} {h}" width="{w}" height="{h}" '
           f'font-family="system-ui, -apple-system, Segoe UI, sans-serif">',
           f'<rect x="-16" y="-16" width="{w}" height="{h}" fill="{t["page"]}"/>',
           f'<g fill="none" stroke="{t["axis"]}" stroke-width="1.25">']
    for e in lay["edges"]:
        if e["from"] in present and e["to"] in present:
            out.append(f'<path d="{e["path"]}"/>')
    out.append("</g>")
    for nid, n in present.items():
        p = lay["nodes"][nid]
        st, x0, y0, ch = n["status"], p["x"] - CARD_W / 2, p["y"] - p["height"] / 2, p["height"]
        color = STATUS_COLOR[st]
        dash = ' stroke-dasharray="5 4"' if st == "waiting" else ""
        out.append(f'<g id="{html.escape(nid)}">'
                   f'<rect x="{x0}" y="{y0}" width="{CARD_W}" height="{ch}" rx="8" fill="{mix(color, t["surface"], TINT[st])}" '
                   f'stroke="{color if st != "waiting" else t["axis"]}" stroke-width="{RIM[st]}"{dash}/>')
        for i, line in enumerate(p["lines"]):
            out.append(f'<text x="{x0 + 14}" y="{y0 + 24 + LINE * i}" font-size="13" font-weight="600" fill="{t["ink"]}">{html.escape(line)}</text>')
        sy = y0 + 24 + LINE * len(p["lines"]) + 4
        tag = f'{n["candidate"]} · ' if n.get("candidate") else ""
        out.append(f'<circle cx="{x0 + 18}" cy="{sy - 4}" r="4" fill="{color}"/>'
                   f'<text x="{x0 + 28}" y="{sy}" font-size="11.5" fill="{t["ink2"]}">{html.escape(tag + STATUS_WORDS[st])}</text></g>')
    out.append("</svg>")
    return "\n".join(out)


def frames(theme="light"):
    """One SVG per milestone on a shared canvas, and what changes between them."""
    lay = json.loads((HISTORY / "layout.json").read_text())
    out_dir = ROOT / "build" / "frames"
    out_dir.mkdir(parents=True, exist_ok=True)
    steps, before = [], {}
    for m in load_index()["milestones"]:
        snap = json.loads((HISTORY / m["file"]).read_text())
        now = {n["id"]: n["status"] for n in snap["nodes"]}
        name = m["file"].replace(".json", f"-{theme}.svg")
        (out_dir / name).write_text(frame_svg(lay, snap, theme))
        xs = [lay["nodes"][i]["x"] for i in now]
        ys = [lay["nodes"][i]["y"] for i in now]
        steps.append({
            "seq": m["seq"], "name": m["name"], "description": m["description"], "tag": m["tag"],
            "frame": name, "nodes": len(now), "statusCounts": m["statusCounts"],
            "appear": sorted(i for i in now if i not in before),
            "change": [{"id": i, "from": before[i], "to": s} for i, s in sorted(now.items()) if i in before and before[i] != s],
            "box": {"x": min(xs) - CARD_W / 2, "y": min(ys) - 60, "width": max(xs) - min(xs) + CARD_W,
                    "height": max(ys) - min(ys) + 120},
        })
        before = now
    (out_dir / "frames.json").write_text(json.dumps({"canvas": {"width": lay["width"], "height": lay["height"]},
                                                     "theme": theme, "milestones": steps}, indent=1) + "\n")
    print(f"wrote {len(steps)} frames and frames.json to {out_dir.relative_to(ROOT)}")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["snapshot"] and len(args) >= 3:
        ref = args[args.index("--commit") + 1] if "--commit" in args else "HEAD"
        snapshot(args[1], args[2], ref, tag="--tag" in args)
    elif args == ["layout"]:
        union_layout()
    elif args[:1] == ["frames"]:
        frames("dark" if "--dark" in args else "light")
    else:
        sys.exit(__doc__)
