#!/usr/bin/env python3
"""The history of the model: the data for the History tab of the Explore page,
and build/history/index.html, which sends readers of the old /history/ page
there.

The History tab plays the milestones in history/ as clusters of dots, one box
per area: cards appear as surveys find them and change color as rules are
written in Lean, proven, or left open with an example.  It reads the same
snapshots as the motion piece described in docs/motion-brief.md.  A card is
drawn in the area it has today, so the boxes keep their place across
milestones; a card that no longer exists keeps the area of its last snapshot.

`history_data` is called by scripts/render_graph.py.  Run as a script, this
writes the page at /history/, which keeps the milestone in the address:
/history/?m=13 opens /graph/?view=history&m=13.
"""

import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from site_nav import FAVICON, SITE_NAME  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
HISTORY = ROOT / "history"
OUT = ROOT / "build" / "history" / "index.html"

# One letter for each status in a milestone's string of statuses; "." for a
# card not yet in the graph.
CODES = {"m": "modelled", "p": "proven", "o": "open", "d": "decision", "r": "ready", "w": "waiting"}
LETTER = {v: k for k, v in CODES.items()}


def history_data(m):
    """What the History tab needs: every card that appears in a milestone with
    its area, and for each milestone its status letters, counts and the
    dependencies between areas.  Also the cards of each area, their latest
    status and title, and the area pairs, for drawing the clusters."""
    index = json.loads((HISTORY / "index.json").read_text())
    snaps = [json.loads((HISTORY / x["file"]).read_text()) for x in index["milestones"]]
    area, title, ids = {}, {}, []
    for s in snaps:
        for n in s["nodes"]:
            if n["id"] not in area:
                ids.append(n["id"])
            area[n["id"]] = n["area"]
            title[n["id"]] = n["title"]
    for i in ids:
        if i in m.by:
            area[i], title[i] = m.by[i]["section"], m.by[i]["title"]
    lost = [i for i in ids if area[i] not in m.layer]
    if lost:
        print(f"render_history: {len(lost)} cards from old areas are left out of the History tab: {', '.join(lost)}")
        ids = [i for i in ids if area[i] in m.layer]
    milestones, every_pair = [], set()
    for x, s in zip(index["milestones"], snaps):
        st = {n["id"]: n["status"] for n in s["nodes"]}
        pairs = Counter()
        for n in s["nodes"]:
            for u in n["uses"]:
                if u in st and n["id"] in area and u in area:
                    a, b = area[u], area[n["id"]]
                    if a in m.layer and b in m.layer and m.layer[a] < m.layer[b]:
                        pairs[(a, b)] += 1
        every_pair |= set(pairs)
        milestones.append({
            "seq": x["seq"], "name": x["name"], "description": x["description"], "date": x["date"][:10],
            "tag": x["tag"], "counts": x["statusCounts"],
            "st": "".join(LETTER[st[i]] if i in st else "." for i in ids),
            "pairs": [[a, b, k] for (a, b), k in sorted(pairs.items())],
        })
    last = {n["id"]: n["status"] for n in snaps[-1]["nodes"]}
    members = {}
    for i in ids:
        members.setdefault(area[i], []).append(i)
    return {
        "data": {"ids": ids, "area": [area[i] for i in ids], "codes": CODES, "milestones": milestones},
        "members": members,
        "statuses": last,
        "titles": title,
        "pairs": sorted(every_pair, key=lambda p: (m.order.index(p[0]), m.order.index(p[1]))),
    }


PAGE = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>History: {SITE_NAME}</title>
{FAVICON}
<link rel="canonical" href="../graph/?view=history">
<script>
  // The history is a tab of the Explore page now; keep the milestone.
  const m = new URLSearchParams(location.search).get("m");
  location.replace("../graph/?view=history" + (m ? "&m=" + encodeURIComponent(m) : ""));
</script>
<noscript><meta http-equiv="refresh" content="0; url=../graph/?view=history"></noscript>
<style>body {{ font: 15px/1.5 system-ui, sans-serif; margin: 40px; color: #52514e; }}</style>
</head>
<body>
<p>The history of the model is now the History tab of the
<a href="../graph/?view=history">Explore page</a>.</p>
</body>
</html>
"""


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(PAGE)
    print(f"rendered {OUT.relative_to(ROOT)}: a link to the History tab of the Explore page")


if __name__ == "__main__":
    main()
