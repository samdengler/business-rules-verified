#!/usr/bin/env python3
"""Record how the dependency graph grows, one snapshot per milestone.

  python3 scripts/graph_history.py snapshot <name> "<description>" [--commit REF] [--tag]
  python3 scripts/graph_history.py layout

`snapshot` saves the graph at a commit (HEAD by default) as
history/NNNN-<name>.json and adds it to history/index.json; with --tag it
also creates the annotated git tag milestone/<name> on that commit.  The
nodes and their dependencies come from blueprint/src/content.tex at that
commit; the statuses of nodes in Lean come from the current build/status.json
(run `lake exe status` first).  For a past commit that is exact only while no
proof's status has changed since, which docs/motion-brief.md notes for each
milestone.

`layout` places every node that appears in any snapshot once, with Graphviz,
and writes history/layout.json, so a node keeps its position from frame to
frame.  Run it after the last snapshot you want to animate.

The snapshots feed the motion piece described in docs/motion-brief.md.
"""

import datetime
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_graph import CARD_W, card_height, graph_data, layout, wrap  # noqa: E402
from render_progress import classify, load_decls, parse_nodes  # noqa: E402

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
    src = git("show", f"{commit}:blueprint/src/content.tex")
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


def union_layout():
    """One position for every node that appears in any snapshot."""
    nodes, seen = [], set()
    for m in load_index()["milestones"]:
        for n in json.loads((HISTORY / m["file"]).read_text())["nodes"]:
            if n["id"] not in seen:
                seen.add(n["id"])
                nodes.append({"label": n["id"], "lines": wrap(n["title"]), "uses": n["uses"]})
    labels = {n["label"] for n in nodes}
    width, height, pos, edges = layout(nodes, labels)
    out = {"width": width, "height": height, "cardWidth": CARD_W,
           "nodes": {n["label"]: {"x": pos[n["label"]][0], "y": pos[n["label"]][1],
                                  "height": card_height(n["lines"]), "lines": n["lines"]} for n in nodes},
           "edges": [{"from": t, "to": h, "path": d} for t, h, d in edges],
           "generated": datetime.datetime.now(datetime.UTC).isoformat(timespec="seconds")}
    (HISTORY / "layout.json").write_text(json.dumps(out, indent=1) + "\n")
    print(f"wrote history/layout.json: {len(nodes)} nodes, {len(edges)} edges")


if __name__ == "__main__":
    args = sys.argv[1:]
    if args[:1] == ["snapshot"] and len(args) >= 3:
        ref = args[args.index("--commit") + 1] if "--commit" in args else "HEAD"
        snapshot(args[1], args[2], ref, tag="--tag" in args)
    elif args == ["layout"]:
        union_layout()
    else:
        sys.exit(__doc__)
