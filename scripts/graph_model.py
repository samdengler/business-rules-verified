#!/usr/bin/env python3
"""The blueprint as cards and areas, for the pages that explore it.

The Explore page (scripts/render_graph.py), the area pages
(scripts/render_areas.py), the tour (scripts/render_tour.py) and the
progress page's ranking all read the graph through `Model`, so they agree on
every count:

  - each area's cards and how many are in each status;
  - the dependencies between areas, and the layer each area sits in;
  - how many cards depend on each card, directly or through other cards;
  - the proven version of an open guarantee for one reading of the sources,
    found by name (`<open name>_of_<reading>`, tagged with no criterion);
  - the IATA capability codes on the candidate nodes, with their names from
    docs/one-order-coverage.md.

Areas are the blueprint's sections.  AREA_LAYERS places them in layers for
the area map and the matrix; a new section must be added there, and the
build stops until it is.
"""

import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
COVERAGE = ROOT / "docs" / "one-order-coverage.md"

# The layers of the area map, from the foundations down.  An area builds
# mostly on the areas in the layers above it; the dependencies that point the
# other way are marked on the map and the matrix.
AREA_LAYERS = [
    ["Core concepts"],
    ["Offers and orders", "Payments and refunds"],
    ["Order structure and status"],
    ["Payment", "Change and cancellation", "Delivery and fulfilment"],
    ["Offers, prices and conditions", "Order creation and information", "Ancillaries, seats and bundles",
     "Airline-initiated change", "Commission, accounting and settlement"],
]

# Shorter names where a box or a matrix row has little room.  The pilot's two
# sections say so, since the ONE Order areas have similar names.
SHORT = {
    "Offers and orders": "Pilot offers and orders",
    "Payments and refunds": "Pilot payments and refunds",
    "Order structure and status": "Order structure",
    "Offers, prices and conditions": "Offers and prices",
    "Ancillaries, seats and bundles": "Ancillaries",
    "Order creation and information": "Order creation",
    "Airline-initiated change": "Airline change",
    "Delivery and fulfilment": "Delivery",
    "Commission, accounting and settlement": "Accounting",
}

# The order statuses are listed in, on every page.
STATUS_ORDER = ["modelled", "proven", "open", "decision", "ready", "waiting"]
QUESTION = {"open", "decision"}


def slug(area):
    """The area page's folder: /area/<slug>/."""
    return re.sub(r"[^a-z0-9]+", "-", area.lower()).strip("-")


def short(area):
    return SHORT.get(area, area)


def capability_names(path=COVERAGE):
    """Each ARMI capability code with its name, link and coverage-map group,
    from the tables of docs/one-order-coverage.md and its list of setup
    capabilities."""
    text = path.read_text()
    caps, group = {}, None
    for line in text.splitlines():
        if line.startswith("## "):
            group = line[3:].strip()
        m = re.match(r"\|\s*\[([A-Z0-9]{6})\]\(([^)]+)\)\s*\|\s*([^|]+?)\s*\|", line)
        if m:
            caps[m.group(1)] = {"name": m.group(3), "url": m.group(2), "group": group}
    for m in re.finditer(r"\[([A-Z0-9]{6})\]\(([^)]+)\)\s+([^,\[]+?)(?=,\s*\[|\.\s*$)", text, re.M):
        caps.setdefault(m.group(1), {"name": m.group(3).strip(), "url": m.group(2), "group": "Setup"})
    return caps


def reading_pairs(decls):
    """For each open theorem, the proven theorems named `<its name>_of_<reading>`
    that check no criterion: the guarantee proven for one reading of the
    sources.  Pairs are found by name only."""
    opens = {n for n, d in decls.items() if d["status"] == "open"}
    pairs = defaultdict(list)
    for name, d in sorted(decls.items()):
        if d["status"] != "proven" or d.get("checks"):
            continue
        i = name.find("_of_")
        while i != -1:
            if name[:i] in opens:
                pairs[name[:i]].append(name)
                break
            i = name.find("_of_", i + 1)
    return dict(pairs)


def docstring_html(s):
    """A docstring as one paragraph of HTML: `code` in code tags, and Verso's
    escapes and roles removed."""
    import html as _html
    s = re.sub(r"\{(?:name|lit|lean|attr)\}`", "`", s or "")
    s = s.replace("\\(", "(").replace("\\)", ")")
    s = _html.escape(re.sub(r"\s+", " ", s).strip(), quote=False)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", s)


class Model:
    """The classified blueprint nodes, with what the exploring pages compute
    from them."""

    def __init__(self, nodes=None, decls=None):
        from render_progress import classify, load_decls, parse_nodes
        self.decls = decls if decls is not None else load_decls()
        if nodes is None:
            nodes = parse_nodes()
            classify(nodes, self.decls)
        self.nodes = nodes
        self.by = {n["label"]: n for n in nodes}
        self.users = {n["label"]: [] for n in nodes}
        for n in nodes:
            for u in n["uses"]:
                if u in self.by:
                    self.users[u].append(n["label"])
        self.areas = list(dict.fromkeys(n["section"] for n in nodes))
        layered = [a for layer in AREA_LAYERS for a in layer]
        missing = [a for a in self.areas if a not in layered]
        if missing:
            sys.exit("scripts/graph_model.py: add the blueprint section(s) " + ", ".join(repr(a) for a in missing)
                     + " to AREA_LAYERS")
        self.layers = [[a for a in layer if a in self.areas] for layer in AREA_LAYERS]
        self.layers = [layer for layer in self.layers if layer]
        self.order = [a for layer in self.layers for a in layer]
        self.layer = {a: i for i, layer in enumerate(self.layers) for a in layer}
        self.area_nodes = {a: [n for n in nodes if n["section"] == a] for a in self.order}
        # (used area, using area) -> the dependencies between them, as
        # (used card, using card).
        self.links = defaultdict(list)
        for n in nodes:
            for u in n["uses"]:
                if u in self.by:
                    self.links[(self.by[u]["section"], n["section"])].append((u, n["label"]))
        self.pair = Counter({k: len(v) for k, v in self.links.items()})
        self._down = {}
        self.pairs = reading_pairs(self.decls)
        self.cap_names = capability_names()
        unknown = sorted({c for n in nodes for c in n.get("caps", []) if c not in self.cap_names})
        if unknown:
            sys.exit("blueprint capability codes not in docs/one-order-coverage.md: " + ", ".join(unknown))

    # ------------------------------------------------------------- counts

    def counts(self, area=None):
        ns = self.nodes if area is None else self.area_nodes[area]
        c = Counter(n["status"] for n in ns)
        return {s: c.get(s, 0) for s in STATUS_ORDER}

    def builds_on(self, area):
        """The areas this area's cards use, with the number of dependencies,
        most first."""
        out = [(a, self.pair[(a, area)]) for a in self.order if a != area and self.pair.get((a, area))]
        return sorted(out, key=lambda x: (-x[1], self.order.index(x[0])))

    def built_on_by(self, area):
        out = [(b, self.pair[(area, b)]) for b in self.order if b != area and self.pair.get((area, b))]
        return sorted(out, key=lambda x: (-x[1], self.order.index(x[0])))

    def is_back(self, used, using):
        """A dependency that points back: the using area comes before the used
        one in the order of the layers.  In the matrix these are the cells
        above the diagonal."""
        return self.order.index(using) < self.order.index(used)

    # ------------------------------------------------------- reachability

    def downstream(self, label):
        """Every card that uses this one, directly or through other cards."""
        if label not in self._down:
            seen, stack = set(), [label]
            while stack:
                for y in self.users[stack.pop()]:
                    if y not in seen and y != label:
                        seen.add(y)
                        stack.append(y)
            self._down[label] = seen
        return self._down[label]

    def upstream(self, label):
        """Every card this one uses, directly or through other cards, with its
        distance: 1 for a card it uses directly."""
        dist, frontier, d = {}, [label], 0
        while frontier:
            d += 1
            nxt = []
            for x in frontier:
                for u in self.by[x]["uses"]:
                    if u in self.by and u not in dist and u != label:
                        dist[u] = d
                        nxt.append(u)
            frontier = nxt
        return dist

    def down_distance(self, label):
        dist, frontier, d = {}, [label], 0
        while frontier:
            d += 1
            nxt = []
            for x in frontier:
                for y in self.users[x]:
                    if y not in dist and y != label:
                        dist[y] = d
                        nxt.append(y)
            frontier = nxt
        return dist

    def impact(self, label):
        """How far an answer reaches: the cards that depend on this one and
        the areas they are in, in layer order."""
        down = self.downstream(label)
        areas = [a for a in self.order if any(self.by[x]["section"] == a for x in down)]
        return {"count": len(down), "areas": areas}

    def ranking(self, limit=None, area=None):
        """Open questions and decisions, by the number of cards that depend on
        them, then by the number of areas those cards are in, then by title.
        Only cards with something depending on them are ranked."""
        rows = []
        for n in self.nodes:
            if n["status"] not in QUESTION or (area and n["section"] != area):
                continue
            imp = self.impact(n["label"])
            if imp["count"]:
                rows.append({"node": n, **imp})
        rows.sort(key=lambda r: (-r["count"], -len(r["areas"]), r["node"]["title"]))
        return rows[:limit] if limit else rows

    # ----------------------------------------------------------- readings

    def readings(self, n):
        """For an open card, each of its open theorems that has a proven version
        for one reading: (open name, proven name, the proven theorem's
        docstring as HTML)."""
        out = []
        for name in n["lean"]:
            if self.decls.get(name, {}).get("status") != "open":
                continue
            for p in self.pairs.get(name, []):
                out.append({"open": name, "proven": p, "doc": docstring_html(self.decls[p].get("docstring"))})
        return out

    def unpaired_open(self):
        """Open theorems with no proven `_of_` version found by name."""
        return sorted(n for n, d in self.decls.items() if d["status"] == "open" and n not in self.pairs)

    # ------------------------------------------------------- requirements

    def requirements(self, area):
        """The requirements whose rule, or a theorem checking one of whose
        criteria, is named in one of the area's cards, in ID order."""
        ids = set()
        for n in self.area_nodes[area]:
            for name in n["lean"]:
                d = self.decls.get(name, {})
                if d.get("earsId"):
                    ids.add(d["earsId"])
                for c in d.get("checks", []):
                    ids.add(c.rsplit(".", 1)[0])
        rules = {d["earsId"]: d for d in self.decls.values() if d.get("earsId")}
        return [rules[i] for i in sorted(ids, key=req_key) if i in rules]

    def capabilities(self, area=None):
        """Capability code -> the cards that carry it, in blueprint order."""
        out = defaultdict(list)
        for n in (self.nodes if area is None else self.area_nodes[area]):
            for c in n.get("caps", []):
                out[c].append(n["label"])
        return dict(sorted(out.items()))


def req_key(ears_id):
    prefix, num = ears_id.rsplit("-", 1)
    return (prefix != "OO", prefix, int(num))
