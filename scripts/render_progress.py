#!/usr/bin/env python3
"""Render the progress page for business readers.

Reads build/status.json (written by `lake exe status`) and
blueprint/src/content.tex, and writes build/progress/index.html, served at
/progress/.  The site's home page (scripts/render_home.py) shares its counts.

The page shows the rules and guarantees in the model and the candidate
rules from the ONE Order survey, each with a status in plain words:

  Modelled         a rule written in Lean
  Proven           a guarantee Lean has checked for every input
  Open question    a guarantee with no proof, marked as a question for the business
  Needs a decision a candidate the source states vaguely or not at all
  Ready to build   a candidate whose dependencies are all in Lean
  Waiting          a candidate that depends on candidates not yet in Lean

The open questions are listed one line each, grouped by area, with the
example and the open point behind a click.  A table of contents beside the
page, or across its top on a narrow screen, links each section.

Nothing on the page is typed by hand: the statuses come from the build and
the text comes from the blueprint, so the page changes when the model does.
"""

import html
import json
import re
import sys
from pathlib import Path
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_status import read_blueprint, section_tag  # noqa: E402
from site_nav import FAVICON, SITE_NAME, TOPBAR_CSS, topbar  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
STATUS = ROOT / "build" / "status.json"
CONTENT = ROOT / "blueprint" / "src" / "content.tex"
OUT = ROOT / "build" / "progress" / "index.html"
REPO = "https://github.com/samdengler/airline-order-verified"

DONE = {"definition", "proven"}

# Blueprint sections that hold supporting definitions rather than rules.
SKIP_SECTIONS = {"Core concepts"}

STATUSES = {
    # key: (label, icon, tile label)
    "modelled": ("Modelled", "✓", "rules in the model"),
    "proven": ("Proven", "✓", "guarantees proven"),
    "open": ("Open question", "!", "open question"),
    "decision": ("Needs a decision", "?", "need a business decision"),
    "ready": ("Ready to build", "→", "ready to build"),
    "waiting": ("Waiting", "…", "waiting on other rules"),
}

NODE_RE = re.compile(r"\\begin\{(definition|theorem|lemma)\}(?:\[([^\]]*)\])?(.*?)\\end\{\1\}", re.S)
HEAD_RE = re.compile(r"\\(chapter|section)\{([^}]*)\}")


def load_decls():
    if not STATUS.exists():
        sys.exit(f"{STATUS} not found; run `lake exe status` first")
    return {d["name"]: d for d in json.loads(STATUS.read_text())["declarations"]}


def arg(cmd, body):
    m = re.search(r"\\" + cmd + r"\{([^}]*)\}", body)
    return [x.strip() for x in m.group(1).split(",") if x.strip()] if m else []


def tex_html(s):
    s = html.escape(s, quote=False)
    s = re.sub(r"\\href\{([^}]*)\}\{([^}]*)\}", r'<a href="\1">\2</a>', s)
    s = re.sub(r"\\texttt\{([^}]*)\}", r"<code>\1</code>", s)
    s = re.sub(r"\\emph\{([^}]*)\}", r"<em>\1</em>", s)
    for a, b in [("\\%", "%"), ("\\_", "_"), ("\\#", "#"), ("\\$", "$"), ("~", " ")]:
        s = s.replace(a, b)
    return re.sub(r"\s+", " ", s).strip()


def plain(s):
    return html.unescape(re.sub(r"<[^>]+>", "", s))


def parse_nodes(src=None):
    """The blueprint's nodes, from content.tex or from its text as given (for
    an earlier commit, in scripts/graph_history.py)."""
    src = read_blueprint() if src is None else src
    heads = [(m.start(), m.group(1), m.group(2)) for m in HEAD_RE.finditer(src)]
    nodes = []
    for m in NODE_RE.finditer(src):
        chapter = next(t for p, k, t in reversed(heads) if p < m.start() and k == "chapter")
        section = next(t for p, k, t in reversed(heads) if p < m.start() and k == "section")
        body = m.group(3)
        title = m.group(2) or ""
        cid = re.search(r"\((C-\d+)\)$", title)
        text = re.sub(r"\\(label|lean|uses|discussion)\{[^}]*\}|\\notready", "", body)
        paras = [tex_html(p) for p in re.split(r"\n\s*\n", text) if p.strip()]
        # "Capabilities: ORDCAN, ORDCA2." names the IATA ARMI capabilities a
        # candidate belongs to; the pages list it apart from the description.
        caps = [c for p in paras if p.startswith("Capabilities:") for c in re.findall(r"\b[A-Z0-9]{6}\b", p)]
        paras = [p for p in paras if not p.startswith("Capabilities:")]
        nodes.append({
            "env": m.group(1),
            "label": arg("label", body)[0],
            "title": re.sub(r"\s*\(C-\d+\)$", "", title),
            "cid": cid.group(1) if cid else None,
            "lean": arg("lean", body),
            "uses": arg("uses", body),
            "notready": "\\notready" in body,
            "chapter": chapter,
            "section": section,
            "paras": paras,
            "caps": caps,
        })
    return nodes


def is_done(node, decls):
    return bool(node["lean"]) and all(decls.get(n, {}).get("status") in DONE for n in node["lean"])


def classify(nodes, decls):
    by_label = {n["label"]: n for n in nodes}
    for n in nodes:
        if n["lean"]:
            states = {decls[x]["status"] for x in n["lean"]}
            n["status"] = "open" if "open" in states else ("proven" if n["env"] != "definition" else "modelled")
        elif n["notready"]:
            n["status"] = "decision"
        elif all(is_done(by_label[u], decls) for u in n["uses"] if u in by_label):
            n["status"] = "ready"
        else:
            n["status"] = "waiting"
        ears = [decls[x]["earsId"] for x in n["lean"] if decls.get(x, {}).get("earsId")]
        checks = [c for x in n["lean"] for c in decls.get(x, {}).get("checks", [])]
        n["tag"] = n["cid"] or (ears[0] if ears else None) or (("checks " + ", ".join(checks)) if checks else None)
        n["href"] = card_href(n, decls)
    return by_label


def shown(nodes, decls):
    """Rules (with an EARS statement), guarantees, and every survey candidate."""
    out = []
    for n in nodes:
        if n["section"] in SKIP_SECTIONS:
            continue
        has_ears = any(decls.get(x, {}).get("earsId") for x in n["lean"])
        if n["cid"] or n["env"] != "definition" or has_ears:
            out.append(n)
    return out


def split_question(n):
    """The description, the counterexample, the open point, and the source line."""
    desc, found, question, source = [], None, None, None
    for p in n["paras"]:
        if p.startswith("Counterexample:"):
            found = p.split(":", 1)[1].strip()
        elif p.startswith("Open point:"):
            question = p.split(":", 1)[1].strip()
        elif p.startswith(("Source:", "Sources:")):
            source = p.split(":", 1)[1].strip()
        else:
            desc.append(p)
    return desc, found, question, source


def chip(status):
    label, icon, _ = STATUSES[status]
    return f'<span class="chip s-{status}"><span class="ico" aria-hidden="true">{icon}</span>{label}</span>'


def review_index():
    """The section tags and Lean names the review document has a page for,
    from the cross-reference index `lake exe review-doc` writes.  Empty when
    the review document has not been built."""
    path = ROOT / "build" / "review" / "html-multi" / "xref.json"
    if not path.exists():
        return None
    x = json.loads(path.read_text())
    return (set(x.get("Verso.Genre.Manual.section", {}).get("contents", {})),
            set(x.get("Verso.Genre.Manual.doc", {}).get("contents", {})))


REVIEW = review_index()


def card_href(n, decls):
    """Where a card on the progress page leads, from /progress/, found by
    Verso's own lookup so a moved chapter keeps working: a rule opens its
    requirement chapter at the top, a guarantee its section in that chapter
    (tags from scripts/render_status.py), an object its card in the review
    document, and anything the review document does not show, such as a
    candidate without Lean, its node in the dependency graph."""
    sections, names = REVIEW or (None, None)
    find = "../review/find/?domain=Verso.Genre.Manual.section&name="
    if n["lean"]:
        ears = decls.get(n["lean"][0], {}).get("earsId")
        if ears:
            return find + quote(ears.lower())
        if n["env"] != "definition":
            tag = section_tag("guarantee", n["lean"][0])
            if sections is None or tag in sections:
                return find + quote(tag)
        elif names is None or n["lean"][0] in names:
            return "../review/find/?domain=Verso.Genre.Manual.doc&name=" + quote(n["lean"][0])
    return "../graph/#" + quote(n["label"])


def card(n):
    desc, found, question, source = split_question(n)
    tag = f'<span class="tag">{html.escape(n["tag"])}</span>' if n["tag"] else ""
    q = (f'<p class="found-line"><strong>Counterexample:</strong> {found}</p>' if found else "") + (
        f'<p class="question"><strong>Open point:</strong> {question}</p>' if question else "")
    src = f'<p class="source">Source: {source}</p>' if source else ""
    return f"""<article class="card s-{n['status']}">
  <header>{tag}{chip(n['status'])}</header>
  <h4><a class="card-link" href="{html.escape(n['href'])}">{html.escape(n['title'])}</a></h4>
  <p>{' '.join(desc)}</p>
  {q}{src}
</article>"""


CSS = """
:root { color-scheme: light;
  --page: #f9f9f7; --surface: #fcfcfb; --ink: #0b0b0b; --ink-2: #52514e; --muted: #898781;
  --hair: #e1e0d9; --ring: rgba(11,11,11,0.10); --axis: #b9b8b0;
  --good: #0ca30c; --lean: #e87ba4; --warning: #fab219; --critical: #d03b3b; --ready: #2a78d6; --waiting: #898781; }
@media (prefers-color-scheme: dark) { :root { color-scheme: dark;
  --page: #0d0d0d; --surface: #1a1a19; --ink: #f0efec; --ink-2: #c3c2b7; --muted: #898781;
  --hair: #2c2c2a; --ring: rgba(255,255,255,0.10); --axis: #55544f; --ready: #3987e5; } }
* { box-sizing: border-box; }
body { margin: 0; background: var(--page); color: var(--ink);
  font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif; }
main { max-width: 1180px; margin: 0 auto; padding: 32px 28px 64px; }
.site-topbar { position: sticky; top: 0; z-index: 10; }
a { color: var(--ready); }
code { font: 0.86em ui-monospace, SFMono-Regular, Menlo, monospace; background: color-mix(in srgb, var(--ink) 6%, transparent);
  padding: 0 4px; border-radius: 4px; white-space: nowrap; }
.kicker { color: var(--muted); font-size: 13px; letter-spacing: .02em; margin: 0 0 6px; }
h1 { font-size: 30px; line-height: 1.2; margin: 0 0 10px; letter-spacing: -0.01em; }
.lede { color: var(--ink-2); max-width: 760px; margin: 0 0 14px; }
.links { display: flex; flex-wrap: wrap; gap: 8px 18px; font-size: 14px; margin-bottom: 28px; }
h2 { font-size: 20px; margin: 44px 0 6px; }
h2 + .sub { color: var(--ink-2); margin: 0 0 16px; max-width: 760px; }
h3 { font-size: 15px; margin: 26px 0 10px; color: var(--ink-2); font-weight: 600; }
.tiles { display: grid; grid-template-columns: repeat(6, 1fr); gap: 10px; }
.tile { background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 14px 14px 12px; }
.tile .n { font-size: 32px; font-weight: 650; line-height: 1; display: flex; align-items: center; gap: 8px; }
.tile .l { color: var(--ink-2); font-size: 13px; margin-top: 6px; }
.bar { display: flex; gap: 2px; height: 10px; margin: 14px 0 0; }
.bar span { border-radius: 2px; }
.bar span:first-child { border-radius: 4px 2px 2px 4px; } .bar span:last-child { border-radius: 2px 4px 4px 2px; }
.ico { display: inline-grid; place-items: center; width: 18px; height: 18px; border-radius: 50%;
  font-size: 11px; font-weight: 800; color: #fff; flex: none; }
.tile .ico { width: 22px; height: 22px; font-size: 13px; }
.s-modelled .ico, .bar .s-modelled { background: var(--lean); }
.s-proven .ico, .bar .s-proven { background: var(--good); }
.s-open .ico, .bar .s-open { background: var(--critical); }
.s-decision .ico, .bar .s-decision { background: var(--warning); color: #0b0b0b; }
.s-ready .ico, .bar .s-ready { background: var(--ready); }
.s-waiting .ico, .bar .s-waiting { background: var(--waiting); }
.found { background: var(--surface); border: 1px solid var(--ring); border-left: 4px solid var(--critical);
  border-radius: 10px; padding: 16px 20px; margin-top: 12px; }
.found h4 { margin: 0 0 6px; font-size: 16px; }
.found p { margin: 6px 0; }
.board { display: grid; grid-template-columns: repeat(auto-fill, minmax(268px, 1fr)); gap: 10px; }
.card { background: var(--surface); border: 1px solid var(--ring); border-radius: 10px; padding: 12px 14px;
  border-top: 3px solid var(--waiting); font-size: 14px; }
.card.s-modelled { border-top-color: var(--lean); }
.card.s-proven { border-top-color: var(--good); }
.card.s-open { border-top-color: var(--critical); }
.card.s-decision { border-top-color: var(--warning); }
.card.s-ready { border-top-color: var(--ready); }
/* The title's link covers the whole card; links inside it sit above. */
.card { position: relative; transition: border-color .15s; }
.card:hover { border-color: color-mix(in srgb, var(--ready) 45%, var(--ring)); }
.card h4 a.card-link, .card h4 a.card-link:visited { color: var(--ink); text-decoration: none; }
.card h4 a.card-link::after { content: ""; position: absolute; inset: 0; border-radius: 10px; }
.card h4 a.card-link:focus-visible::after { outline: 2px solid var(--ready); outline-offset: 2px; }
.card .source a, .card .question a, .card .found-line a { position: relative; z-index: 1; }
.card header { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
.card h4 { margin: 8px 0 4px; font-size: 15px; line-height: 1.3; }
.card p { margin: 4px 0; color: var(--ink-2); }
.card .question { color: var(--ink); background: color-mix(in srgb, var(--warning) 14%, transparent);
  border-radius: 6px; padding: 6px 8px; margin-top: 8px; }
.card .found-line { color: var(--ink); background: color-mix(in srgb, var(--critical) 12%, transparent);
  border-radius: 6px; padding: 6px 8px; margin-top: 8px; }
.card .source { font-size: 12.5px; color: var(--muted); }
.tag { font-size: 12px; color: var(--muted); font-variant-numeric: tabular-nums; }
.chip { display: inline-flex; align-items: center; gap: 6px; font-size: 12.5px; font-weight: 600; color: var(--ink); }
.legend { display: flex; flex-wrap: wrap; gap: 8px 18px; margin: 4px 0 12px; }
.ranking { list-style: none; padding: 0; margin: 0; counter-reset: rank; background: var(--surface);
  border: 1px solid var(--ring); border-radius: 10px; }
.ranking li { counter-increment: rank; display: grid; grid-template-columns: 30px minmax(220px, 1fr) minmax(200px, 1.3fr);
  gap: 4px 16px; align-items: center; padding: 10px 16px; border-top: 1px solid var(--ring); }
.ranking li:first-child { border-top: none; }
.ranking li::before { content: counter(rank); color: var(--muted); font-variant-numeric: tabular-nums; font-size: 14px; }
.ranking .rk-title { font-weight: 600; color: var(--ink); text-decoration: none; }
.ranking .rk-title:hover { color: var(--ready); text-decoration: underline; }
.ranking .rk-meta { display: flex; flex-wrap: wrap; align-items: center; gap: 2px 10px; font-size: 13px; color: var(--ink-2); margin-top: 2px; }
.ranking .rk-bar { height: 12px; border-radius: 3px; background: var(--waiting); min-width: 3px; }
.ranking .s-open .rk-bar { background: var(--critical); } .ranking .s-decision .rk-bar { background: var(--warning); }
.ranking .rk-n { font-size: 13.5px; color: var(--ink); margin-top: 4px; }
.ranking .rk-n strong { font-variant-numeric: tabular-nums; }
.ranking .rk-areas { color: var(--ink-2); }
@media (max-width: 700px) { .ranking li { grid-template-columns: 24px 1fr; } .ranking .rk-impact { grid-column: 2; } }
footer { margin-top: 48px; color: var(--muted); font-size: 13px; }
@media (max-width: 900px) { .tiles { grid-template-columns: repeat(3, 1fr); } }
"""


def decide_first(model, root="./", limit=10):
    """The open questions and decisions with the most cards depending on
    them, each linking to its neighbourhood on the Explore page.  The tour
    (scripts/render_tour.py) shows the first five."""
    from graph_model import short
    rows = model.ranking(limit)
    if not rows:
        return ""
    top = rows[0]["count"]
    items = []
    for r in rows:
        n = r["node"]
        k, areas = r["count"], r["areas"]
        tag = f'<span class="tag">{html.escape(n["cid"])}</span>' if n["cid"] else ""
        items.append(
            f'<li class="s-{n["status"]}"><div><a class="rk-title" href="{root}graph/#{quote(n["label"])}">{html.escape(n["title"])}</a>'
            f'<div class="rk-meta">{tag}{chip(n["status"])}<span>{html.escape(n["section"])}</span></div></div>'
            f'<div class="rk-impact"><div class="rk-bar" style="width: {100 * k / top:.1f}%"></div>'
            f'<div class="rk-n"><strong>{k}</strong> {"card" if k == 1 else "cards"} in {len(areas)} '
            f'{"area" if len(areas) == 1 else "areas"}: <span class="rk-areas">{html.escape(", ".join(short(a) for a in areas))}</span>'
            f'</div></div></li>')
    return "<ol class=\"ranking\">" + "".join(items) + "</ol>"


def tiles_html(show):
    """The status tiles and the bar under them, as on the home page."""
    counts = {k: sum(1 for n in show if n["status"] == k) for k in STATUSES}
    tiles = "".join(
        f'<div class="tile s-{k}"><div class="n"><span class="ico" aria-hidden="true">{STATUSES[k][1]}</span>{counts[k]}</div>'
        f'<div class="l">{STATUSES[k][2] if counts[k] != 1 or k != "open" else "open question"}</div></div>'
        for k in STATUSES)
    total = len(show)
    bar = "".join(
        f'<span class="s-{k}" style="flex:{counts[k]}" title="{STATUSES[k][0]}: {counts[k]} of {total}"></span>'
        for k in STATUSES if counts[k])
    return (f'<div class="tiles">{tiles}</div>'
            f'<div class="bar" role="img" aria-label="Status of {total} rules and guarantees">{bar}</div>')


def open_questions(show, model, root):
    """The open questions, one line each and grouped by area in the order of
    the area map.  A line opens to the example and the open point; within an
    area, the questions with the most cards depending on them come first."""
    from graph_model import slug
    groups = []
    for area in model.order:
        qs = [n for n in show if n["status"] == "open" and n["section"] == area]
        if not qs:
            continue
        reach = {n["label"]: model.impact(n["label"])["count"] for n in qs}
        qs.sort(key=lambda n: (-reach[n["label"]], n["title"]))
        rows = []
        for n in qs:
            desc, found, question, _ = split_question(n)
            k = reach[n["label"]]
            count = (f'<span class="oq-reach">{k} {"card depends" if k == 1 else "cards depend"} on it</span>'
                     if k else "")
            links = [f'<a href="{root}graph/#{quote(n["label"])}">See what depends on it</a>']
            if "review/" in n["href"]:
                links.insert(0, f'<a href="{html.escape(n["href"])}">Read it in the review document</a>')
            rows.append(
                f'<details class="oq"><summary><span class="oq-title">{html.escape(n["title"])}</span>{count}</summary>'
                f'<div class="oq-body"><p>{" ".join(desc)}</p>'
                + (f'<p class="found-line"><strong>Counterexample:</strong> {found}</p>' if found else "")
                + (f'<p class="question"><strong>Open point:</strong> {question}</p>' if question else "")
                + f'<p class="oq-links">{" · ".join(links)}</p></div></details>')
        groups.append(
            f'<section class="oq-area"><h3 id="found-{slug(area)}"><a href="{root}area/{slug(area)}/">{html.escape(area)}</a>'
            f'<span class="n">{len(qs)}</span></h3><div class="oq-list">{"".join(rows)}</div></section>')
    return "".join(groups)


def toc(entries):
    """The table of contents: (anchor, label, count or None, sub-entries)."""
    def item(anchor, label, count, subs=()):
        n = f'<span class="n">{count}</span>' if count is not None else ""
        sub = f'<ol>{"".join(item(*e) for e in subs)}</ol>' if subs else ""
        return f'<li><a href="#{anchor}">{html.escape(label)}{n}</a>{sub}</li>'
    return (f'<nav class="toc" aria-label="On this page"><p class="toc-head">On this page</p>'
            f'<ol>{"".join(item(*e) for e in entries)}</ol></nav>')


# The progress page's own layout: the table of contents and the open
# questions.  The tour and the area pages share CSS, not these.
PROGRESS_CSS = """
.layout { max-width: 1440px; margin: 0 auto; display: grid; grid-template-columns: 264px minmax(0, 1fr); }
.layout main { max-width: 1180px; margin: 0; min-width: 0; }
h2, h3 { scroll-margin-top: 64px; }
.toc { position: sticky; top: 48px; align-self: start; max-height: calc(100vh - 48px); overflow-y: auto;
  padding: 36px 4px 24px 24px; font-size: 13.5px; scrollbar-width: thin; }
.toc-head { font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: .06em; color: var(--muted); margin: 0 0 8px 8px; }
.toc ol { list-style: none; margin: 0; padding: 0; }
.toc > ol > li { margin: 0 0 6px; }
.toc ol ol { margin: 2px 0 4px 8px; padding-left: 6px; border-left: 1px solid var(--hair); }
.toc a { display: flex; justify-content: space-between; gap: 8px; padding: 3px 8px; border-radius: 6px;
  color: var(--ink-2); text-decoration: none; }
.toc > ol > li > a { color: var(--ink); font-weight: 600; }
.toc a:hover { background: color-mix(in srgb, var(--ink) 6%, transparent); }
.toc a[aria-current] { background: color-mix(in srgb, var(--ready) 13%, transparent); color: var(--ink); }
.toc .n, .oq-area .n { color: var(--muted); font-weight: 400; font-variant-numeric: tabular-nums; }
.oq-area h3 { display: flex; align-items: baseline; gap: 8px; }
.oq-area h3 a { color: var(--ink); text-decoration: none; }
.oq-area h3 a:hover { color: var(--ready); text-decoration: underline; }
.oq-list { background: var(--surface); border: 1px solid var(--ring); border-left: 4px solid var(--critical); border-radius: 10px; }
.oq + .oq { border-top: 1px solid var(--ring); }
.oq summary { display: grid; grid-template-columns: 12px minmax(0, 1fr) auto; align-items: baseline; gap: 4px 12px;
  padding: 9px 16px 9px 14px; cursor: pointer; list-style: none; }
.oq summary::-webkit-details-marker { display: none; }
.oq summary::before { content: ""; width: 6px; height: 6px; border-right: 2px solid var(--muted); border-bottom: 2px solid var(--muted);
  transform: translateY(-2px) rotate(-45deg); transition: transform .15s; }
.oq[open] summary::before { transform: translateY(-3px) rotate(45deg); }
.oq summary:hover .oq-title { color: var(--ready); }
.oq summary:focus-visible { outline: 2px solid var(--ready); outline-offset: -2px; border-radius: 8px; }
.oq-title { font-weight: 600; }
.oq-reach { color: var(--ink-2); font-size: 13px; white-space: nowrap; font-variant-numeric: tabular-nums; }
.oq-body { padding: 0 16px 14px 42px; }
.oq-body p { margin: 6px 0; max-width: 860px; }
.oq-body .found-line { background: color-mix(in srgb, var(--critical) 12%, transparent); border-radius: 6px; padding: 6px 8px; }
.oq-body .question { background: color-mix(in srgb, var(--warning) 14%, transparent); border-radius: 6px; padding: 6px 8px; }
.oq-links { font-size: 13.5px; }
/* On a narrow screen the contents become a bar of the sections under the
   site's bar, scrolling sideways. */
@media (max-width: 1100px) { .layout .tiles { grid-template-columns: repeat(3, 1fr); } }
@media (max-width: 1000px) {
  .layout { display: block; }
  h2, h3 { scroll-margin-top: 104px; }
  .toc { z-index: 9; max-height: none; padding: 0 12px; overflow-x: auto; overflow-y: hidden; scrollbar-width: none;
    background: var(--surface); border-bottom: 1px solid var(--ring); }
  .toc-head, .toc ol ol { display: none; }
  .toc > ol { display: flex; align-items: center; gap: 2px; height: 44px; white-space: nowrap; }
  .toc > ol > li { margin: 0; }
  .toc > ol > li > a { font-weight: 500; color: var(--ink-2); }
  .toc a.within { background: color-mix(in srgb, var(--ready) 13%, transparent); color: var(--ink); }
}
@media (max-width: 600px) {
  .oq summary { grid-template-columns: 12px minmax(0, 1fr); }
  .oq-reach { grid-column: 2; }
  .oq-body { padding-left: 16px; }
}
"""

# Marks the contents entry of the section being read.  The entry under a
# heading that has scrolled past the bars is the current one; on a narrow
# screen, where only the top level shows, its top-level entry is marked too
# and scrolled into view.
PROGRESS_JS = """
(function () {
  var nav = document.querySelector(".toc");
  if (!nav) return;
  var links = Array.prototype.slice.call(nav.querySelectorAll("a"));
  var targets = links.map(function (a) { return document.getElementById(a.hash.slice(1)); });
  var queued = false;
  function update() {
    queued = false;
    var wide = nav.offsetHeight > 100;
    var box = nav.getBoundingClientRect();
    var line = wide ? 140 : box.bottom + 24;
    var current = -1;
    for (var i = 0; i < targets.length; i++) if (targets[i].getBoundingClientRect().top < line) current = i;
    links.forEach(function (a, i) {
      if (i === current) a.setAttribute("aria-current", "true"); else a.removeAttribute("aria-current");
      a.classList.remove("within");
    });
    if (current < 0) return;
    var top = links[current].closest(".toc > ol > li").firstElementChild;
    top.classList.add("within");
    if (!wide) {
      var r = top.getBoundingClientRect();
      if (r.left < box.left || r.right > box.right) nav.scrollLeft += r.left - box.left - 12;
    } else {
      var c = links[current].getBoundingClientRect();
      if (c.top < box.top || c.bottom > box.bottom) nav.scrollTop += c.top - box.top - nav.clientHeight / 3;
    }
  }
  function queue() { if (!queued) { queued = true; requestAnimationFrame(update); } }
  window.addEventListener("scroll", queue, { passive: true });
  window.addEventListener("resize", queue);
  update();
})();
"""


def page(show, by_label, decls, model):
    from graph_model import short, slug
    counts = {k: sum(1 for n in show if n["status"] == k) for k in STATUSES}
    groups, entries = [], []
    for key, head, label, in_lean in (("today", "In the model today", "In the model today", True),
                                      ("next", "Next: candidate rules from the ONE Order survey",
                                       "Candidates from the survey", False)):
        part = [n for n in show if bool(n["lean"]) == in_lean]
        sections = list(dict.fromkeys(n["section"] for n in part))
        body = "".join(
            f'<h3 id="{key}-{slug(s)}">{html.escape(s)}</h3><div class="board">'
            + "".join(card(n) for n in part if n["section"] == s) + "</div>"
            for s in sections)
        groups.append(f'<h2 id="{key}">{head}</h2>{body}')
        entries.append((key, label, len(part),
                        [(f"{key}-{slug(s)}", short(s), sum(1 for n in part if n["section"] == s)) for s in sections]))
    contents = toc([("decide", "Decide these first", None),
                    ("found", "Open questions", counts["open"]),
                    *entries,
                    ("map", "How the rules depend on each other", None)])
    legend = "".join(chip(k) for k in STATUSES)
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{SITE_NAME}: progress</title>
{FAVICON}
<style>{CSS}{PROGRESS_CSS}{TOPBAR_CSS}</style>
</head>
<body>
{topbar("Progress", "../")}
<div class="layout">
{contents}
<main>
<p class="kicker">Proof of concept · built from public IATA ONE Order material · not affiliated with IATA</p>
<h1>Every rule, guarantee and candidate, with its status</h1>
<p class="lede">Every rule and guarantee in the Lean model, and every candidate rule from the ONE Order survey, with the
status the build gives it. A <strong>proven</strong> guarantee holds for every possible input. An <strong>open question</strong>
is a guarantee the rules as written do not meet, with an example that shows the failing case.
This page is generated from the model on every build.</p>
{tiles_html(show)}

<h2 id="decide">Decide these first</h2>
<p class="sub">These open questions and decisions have the most cards depending on them, so an answer reaches furthest.
Each is ranked by the number of cards that use it, directly or through other cards, and ties by the number of areas those cards are in.</p>
{decide_first(model, "../")}

<h2 id="found">Open questions</h2>
<p class="sub">A guarantee the business expected to hold, and an example where the rules as written break it.
Open a question to read the example and the open point. An area's name leads to its summary page.</p>
{open_questions(show, model, "../")}
{''.join(groups)}

<h2 id="map">How the rules depend on each other</h2>
<p class="sub">A rule can only be written in Lean once everything it depends on is, so the dependencies show what to build next.
The <a href="../graph/">Explore page</a> shows them as a map of the areas, a matrix of dependencies between areas, every card with an arrow
to the cards that build on it, and the history of the model. Click a card there to see what it depends on and what builds on it.</p>
<div class="legend">{legend}</div>

<footer>Generated by <code>scripts/render_progress.py</code> from the Lean build and the blueprint.
Statuses are computed; nothing on this page is typed by hand.</footer>
</main>
</div>
<script>{PROGRESS_JS}</script>
</body>
</html>
"""


def main():
    from graph_model import Model
    decls = load_decls()
    nodes = parse_nodes()
    by_label = classify(nodes, decls)
    show = shown(nodes, decls)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(page(show, by_label, decls, Model(nodes, decls)))
    counts = {k: sum(1 for n in show if n["status"] == k) for k in STATUSES}
    print(f"rendered {OUT.relative_to(ROOT)}: " + ", ".join(f"{v} {k}" for k, v in counts.items()))


if __name__ == "__main__":
    main()
