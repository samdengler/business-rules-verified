#!/usr/bin/env python3
"""Render Verified Airline's policy pages, build/airline/, served at /airline/.

Verified Airline is a fictional airline.  Its pages answer a traveler's
questions about fares, payment, changes, refunds, extras and schedule changes,
in wording kept in airline-site/content/, one file per page.  Each section
names the requirements it rests on, and each "still being decided" item names
the open criterion behind it.  With the Lean model shown (the button in the
page's band, or ?lean=1 in the address), a marker beside each section opens a
popover with the requirement's EARS statement, its criteria and a link to its
chapter in the review document.

Every status comes from build/status.json (lake exe status) and every amount
from build/airline/facts.json (lake exe airline-facts, which evaluates the
fares in Airline/Fares.lean with the model's functions).  The build stops if a
content file

  * cites a requirement or criterion the model does not have,
  * lists as still being decided a criterion that is no longer open,
  * uses a placeholder such as {{examples.mainChange.youPay}} that the facts
    do not have,
  * types an amount where a placeholder belongs, or
  * leaves a section without a marker,

or if a page shows a requirement ID or the words rule, theorem or criterion
while the Lean model is hidden.

A content file is a few `key: value` lines, `---`, then the page in a small
Markdown: `##` sections ending in `{#anchor}` and `{model: ONE-503}`, `###`
items under "Still being decided" ending in `{open: ONE-503.5}`, paragraphs
(one ending in `{model: ...}` gets a marker of its own), `- ` lists, **bold**,
[links](@changes#cancel) to another page, and fenced blocks for the fare
table (`fares`), worked examples (`example`), the stages of a trip (`stages`)
and the home page's questions (`questions`).
"""

import html
import json
import re
import shutil
import sys
from html.parser import HTMLParser
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from render_status import PILOT, kiro_ears, plain, section_tag  # noqa: E402
from site_nav import PLANE_PATH, PLANE_SVG  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "airline-site"
CONTENT = SOURCE / "content"
ASSETS = SOURCE / "assets"
OUT = ROOT / "build" / "airline"
FACTS = OUT / "facts.json"
STATUS = ROOT / "build" / "status.json"
XREF = ROOT / "build" / "review" / "html-multi" / "xref.json"

AIRLINE = "Verified Airline"
FOOTER = ("Verified Airline is a fictional airline. Fares and fees are invented and computed from the Lean model. "
          "Not affiliated with IATA.")
STORAGE_KEY = "verified-airline-lean"
FONTS = ("https://fonts.googleapis.com/css2?family=DM+Serif+Display&family=Fira+Sans:wght@400;500;600;700"
         "&family=JetBrains+Mono:wght@400;500;700&display=swap")

# The mark is the site's plane (PLANE_SVG in scripts/site_nav.py) in the
# airline's night indigo, and the favicon is the same plane.
FAVICON = ('<link rel="icon" href="data:image/svg+xml,'
           + "%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'%3E"
           + f"%3Cpath transform='rotate(-30 12 12)' fill='%232B3A67' d='{PLANE_PATH}'/%3E%3C/svg%3E"
           + '">')

# The words a traveler never reads, and requirement IDs.  Both may appear only
# in the parts of a page shown with the Lean model.
BANNED = re.compile(r"\b(rules?|theorems?|criterion|criteria)\b|\b(?:ONE|OO)-\d{3}(?:\.\d+)?\b", re.I)
TYPED_AMOUNT = re.compile(r"[$€£]\s*\d|\b\d+(?:[.,]\d+)?\s*(?:dollars?|cents?|USD|EUR|GBP|euros?)\b", re.I)
PLACEHOLDER = re.compile(r"\{\{\s*([\w.]+)\s*\}\}")
MARK = re.compile(r"\s*\{(model|open):\s*([^}]*)\}\s*$")
ANCHOR = re.compile(r"\s*\{#([\w-]+)\}")
CRITERION = re.compile(r"^((?:ONE|OO)-\d{3})\.\d+$")
SYMBOL = {"USD": "$", "EUR": "€", "GBP": "£"}
STATUS_WORD = {"proven": "proven", "open": "open", "example": "example only", "not checked": "not checked"}

esc = html.escape


class BuildError(Exception):
    pass


def fail(where, message):
    raise BuildError(f"{where}: {message}")


# ------------------------------------------------------------------ inputs

def load_model():
    """The requirements by EARS ID, and the open theorems by the criterion
    they check, from build/status.json."""
    decls = json.loads(STATUS.read_text())["declarations"]
    rules = {d["earsId"]: d for d in decls if d.get("earsId")}
    criteria = {c["id"]: c for d in rules.values() for c in d["criteria"]}
    open_by = {}
    for d in decls:
        if d["kind"] == "theorem" and d["status"] == "open":
            for c in d.get("checks", []):
                open_by.setdefault(c, []).append(d)
    return rules, criteria, open_by


def load_review():
    """The review document's sections by tag, or None when it is not built."""
    if not XREF.exists():
        return None
    x = json.loads(XREF.read_text())
    return {k: v[0] for k, v in x.get("Verso.Genre.Manual.section", {}).get("contents", {}).items()}


def money(v, where):
    if not (isinstance(v, dict) and "cents" in v and "currency" in v):
        fail(where, f"expected an amount in the facts, found {v!r}")
    cents, sym = v["cents"], SYMBOL.get(v["currency"])
    if sym is None:
        fail(where, f"no symbol for currency {v['currency']}")
    return f"{sym}{cents // 100:,}" if cents % 100 == 0 else f"{sym}{cents / 100:,.2f}"


def lookup(facts, path, where):
    v = facts
    for part in path.split("."):
        if not isinstance(v, dict) or part not in v:
            fail(where, f"no value for {{{{{path}}}}} in build/airline/facts.json")
        v = v[part]
    if isinstance(v, dict):
        return money(v, f"{where}, {{{{{path}}}}}")
    if isinstance(v, (str, int)):
        return str(v)
    fail(where, f"{{{{{path}}}}} is not a single value")


# ------------------------------------------------------------------ content

class Section:
    def __init__(self, title, anchor, model):
        self.title, self.anchor, self.model = title, anchor, model
        self.blocks, self.items = [], []


class Item:
    def __init__(self, title, opens):
        self.title, self.opens, self.blocks = title, opens, []


def split_mark(text):
    """A line without its trailing {model: ...} or {open: ...}, and the IDs."""
    m = MARK.search(text)
    if not m:
        return text, None, []
    return text[:m.start()], m.group(1), [i.strip() for i in m.group(2).split(",") if i.strip()]


def parse_blocks(lines, where):
    """Paragraphs, lists and fenced blocks."""
    blocks, para, i = [], [], 0

    def flush():
        if para:
            text, kind, ids = split_mark(" ".join(para))
            if kind == "open":
                fail(where, "a paragraph cannot be still being decided; use a ### item")
            blocks.append(("p", text, ids))
            para.clear()

    while i < len(lines):
        line = lines[i].rstrip()
        if line.startswith("```"):
            flush()
            kind, body = line[3:].strip(), []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                body.append(lines[i].rstrip())
                i += 1
            blocks.append(("fence", kind, body))
        elif line.startswith("- "):
            flush()
            items = []
            while i < len(lines) and lines[i].startswith("- "):
                items.append(lines[i][2:].strip())
                i += 1
            blocks.append(("ul", items))
            continue
        elif not line.strip():
            flush()
        else:
            para.append(line.strip())
        i += 1
    flush()
    return blocks


def parse(path):
    text = path.read_text()
    head, sep, body = text.partition("\n---\n")
    if not sep:
        fail(path.name, "no --- after the header lines")
    meta = {}
    for line in head.splitlines():
        if line.strip():
            k, _, v = line.partition(":")
            meta[k.strip()] = v.strip()
    page = {"slug": path.stem, "meta": meta, "intro": [], "sections": []}
    chunks, current = [], ("intro", None, [])
    for line in body.splitlines():
        if line.startswith("## ") or line.startswith("### "):
            chunks.append(current)
            current = ("h2" if line.startswith("## ") else "h3", line, [])
        else:
            current[2].append(line)
    chunks.append(current)
    where = f"airline-site/content/{path.name}"
    for kind, line, lines in chunks:
        blocks = parse_blocks(lines, where)
        if kind == "intro":
            page["intro"] = blocks
            continue
        title, mark, ids = split_mark(line.lstrip("#").strip())
        am = ANCHOR.search(title)
        anchor = am.group(1) if am else None
        title = ANCHOR.sub("", title).strip()
        if kind == "h2":
            if mark == "open":
                fail(where, f"section {title!r}: a section rests on {{model: ...}}; open criteria go on ### items")
            if not anchor:
                fail(where, f"section {title!r} has no {{#anchor}}")
            page["sections"].append(Section(title, anchor, ids))
            page["sections"][-1].blocks = blocks
        else:
            if not page["sections"]:
                fail(where, f"item {title!r} is outside a section")
            if mark != "open":
                fail(where, f"item {title!r} needs {{open: ...}}")
            item = Item(title, ids)
            item.blocks = blocks
            page["sections"][-1].items.append(item)
    return page


# ------------------------------------------------------------------ checks

def customer_strings(page):
    """Every piece of wording a traveler reads from a content file, with the
    file's placeholders still in it."""
    m = page["meta"]
    out = [m.get(k, "") for k in ("title", "lede", "summary")] + m.get("questions", "").split("|")

    def blocks(bs):
        for b in bs:
            if b[0] == "p":
                out.append(b[1])
            elif b[0] == "ul":
                out.extend(b[1])
            else:
                for line in b[2]:
                    if b[1] == "fares":
                        out.append(line.split(":", 1)[1] if ":" in line and "|" not in line else line.split("|")[0])
                    elif b[1] == "questions":
                        out.extend(line.split("|")[:2])
                    else:
                        out.append(line)
    blocks(page["intro"])
    for s in page["sections"]:
        out.append(s.title)
        blocks(s.blocks)
        for it in s.items:
            out.append(it.title)
            blocks(it.blocks)
    return out


def check_page(page, model, pages):
    rules, criteria, _ = model
    where = f"airline-site/content/{page['slug']}.md"
    for s in customer_strings(page):
        bare = PLACEHOLDER.sub("", s)
        if TYPED_AMOUNT.search(bare):
            fail(where, f"an amount is typed in {s.strip()!r}; write it as a {{{{placeholder}}}} from the facts")
    if page["meta"].get("kind") != "policy":
        return
    listed = [i.strip() for i in page["meta"].get("requirements", "").split(",") if i.strip()]
    for r in listed:
        if r not in rules:
            fail(where, f"requirements lists {r}, which the model does not have")
    cited = set()
    for s in page["sections"]:
        marked = bool(s.model) or bool(s.items)
        ids = list(s.model)
        for b in s.blocks:
            if b[0] == "p" and b[2]:
                ids += b[2]
        for r in ids:
            if r not in rules:
                fail(where, f"section {s.title!r} cites {r}, which the model does not have")
            if r not in listed:
                fail(where, f"section {s.title!r} cites {r}; add it to the requirements line")
            cited.add(r)
        for it in s.items:
            if not it.opens:
                fail(where, f"item {it.title!r} names no open criterion")
            for c in it.opens:
                if c not in criteria:
                    fail(where, f"item {it.title!r} cites {c}, which the model does not have")
                st = criteria[c]["status"]
                if st != "open":
                    fail(where, f"{c} is now {STATUS_WORD.get(st, st)}, so {it.title!r} is no longer still being "
                                f"decided; rewrite that wording")
                parent = CRITERION.match(c).group(1)
                if parent not in listed:
                    fail(where, f"item {it.title!r} cites {c}; add {parent} to the requirements line")
                cited.add(parent)
        if not marked:
            fail(where, f"section {s.title!r} has no marker: end its heading with {{model: ...}}")
    for r in listed:
        if r not in cited:
            fail(where, f"requirements lists {r}, but no section cites it")
    for r in page["meta"].get("related", "").split(","):
        if r.strip() and r.strip() not in pages:
            fail(where, f"related names {r.strip()!r}, which is not a page")


class VisibleText(HTMLParser):
    """The text of a page as a traveler sees it with the Lean model hidden:
    no scripts, styles, markers, popovers or parts shown only with the model."""

    VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}

    def __init__(self):
        super().__init__()
        self.stack, self.text = [], []

    def handle_starttag(self, tag, attrs):
        if tag in self.VOID:
            return
        a = dict(attrs)
        hidden = (tag in ("script", "style") or "data-lean" in a
                  or (self.stack and self.stack[-1]))
        self.stack.append(bool(hidden))

    def handle_endtag(self, tag):
        if tag not in self.VOID and self.stack:
            self.stack.pop()

    def handle_data(self, data):
        if not (self.stack and self.stack[-1]):
            self.text.append(data)


def check_hidden(page_html, where):
    p = VisibleText()
    p.feed(page_html)
    text = " ".join(p.text)
    m = BANNED.search(text)
    if m:
        i = m.start()
        fail(where, f"shows {m.group(0)!r} with the Lean model hidden: ...{text[max(0, i - 60):i + 40].strip()}...")


# ------------------------------------------------------------------ render

class Renderer:
    def __init__(self, pages, facts, model, review):
        self.pages, self.facts, self.model, self.review = pages, facts, model, review
        self.pop = 0

    # Paths --------------------------------------------------------------
    @staticmethod
    def path_of(slug):
        """A page's directory under /airline/."""
        return "" if slug == "index" else "policies/" if slug == "policies" else f"policies/{slug}/"

    def href(self, here, slug, anchor=""):
        """A link from page `here` to page `slug`."""
        up = "../" * self.path_of(here).count("/")
        target = up + self.path_of(slug)
        return (target or "./") + (f"#{anchor}" if anchor else "")

    def site_root(self, here):
        """The main site's root from page `here`."""
        return "../" * (self.path_of(here).count("/") + 1)

    def review_link(self, here, tag):
        if self.review is None:
            return self.site_root(here) + "review/find/?domain=Verso.Genre.Manual.section&name=" + tag
        if tag not in self.review:
            fail(f"the {here} page", f"the review document has no section tagged {tag}")
        e = self.review[tag]
        # A chapter is a page of its own; a section is an anchor in one.
        anchor = "" if len(e["data"]["context"]) <= 2 else "#" + e["id"]
        return self.site_root(here) + "review/" + e["address"].strip("/") + "/" + anchor

    # Text ---------------------------------------------------------------
    def inline(self, text, here):
        where = f"airline-site/content/{here}.md"
        text = PLACEHOLDER.sub(lambda m: "\0" + lookup(self.facts, m.group(1), where) + "\1", text)
        out = esc(text, quote=False).replace("\0", '<span class="amount">').replace("\1", "</span>")
        out = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", out)

        def link(m):
            label, target = m.group(1), m.group(2)
            if target.startswith("@"):
                slug, _, anchor = target[1:].partition("#")
                if slug not in self.pages:
                    fail(where, f"a link names {slug!r}, which is not a page")
                if anchor and anchor not in self.anchors(slug):
                    fail(where, f"a link names #{anchor}, which {slug} does not have")
                target = self.href(here, slug, anchor)
            return f'<a href="{esc(target)}">{label}</a>'
        return re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", link, out)

    def anchors(self, slug):
        return {s.anchor for s in self.pages[slug]["sections"]}

    # Markers ------------------------------------------------------------
    def requirement_html(self, rid, here):
        rules = self.model[0]
        r = rules[rid]
        counts = {}
        for c in r["criteria"]:
            counts[c["status"]] = counts.get(c["status"], 0) + 1
        badges = "".join(
            f'<span class="badge {k.replace(" ", "-")}">{counts[k]} {STATUS_WORD[k]}</span>'
            for k in ("proven", "open", "example", "not checked") if counts.get(k))
        n = len(r["criteria"])
        return (f'<div class="lean-req"><p class="lean-head"><strong>Lean requirement {esc(rid)}</strong>'
                f'<span class="lean-count">{n} {"criterion" if n == 1 else "criteria"}</span>{badges}</p>'
                f'<p class="lean-ears">{esc(kiro_ears(plain(r["ears"])))}</p>'
                f'<p class="lean-name">Lean: <code>{esc(r["name"])}</code></p>'
                f'<p><a href="{esc(self.review_link(here, rid.lower()))}">Read the requirement and its proofs</a></p></div>')

    def question_html(self, cid, here):
        _, criteria, open_by = self.model
        c = criteria[cid]
        theorems = sorted(open_by.get(cid, []), key=lambda d: d["name"])
        parts = [f'<p class="lean-head"><strong>Open criterion {esc(cid)}</strong>'
                 f'<span class="badge open">open</span></p>',
                 f'<p class="lean-ears">{esc(kiro_ears(plain(c["ears"])))}</p>']
        for d in theorems:
            q = opening(d["docstring"])
            if q:
                parts.append(f'<p class="lean-question">{q}</p>')
            parts.append(f'<p class="lean-name">Open theorem: <code>{esc(d["name"])}</code></p>')
            tag = "open-questions" if d["name"].startswith(PILOT) else section_tag("question", d["name"])
            parts.append(f'<p><a href="{esc(self.review_link(here, tag))}">Read the open question</a></p>')
        if not theorems:
            parts.append(f'<p><a href="{esc(self.review_link(here, CRITERION.match(cid).group(1).lower()))}">'
                         "Read the requirement</a></p>")
        return '<div class="lean-req">' + "".join(parts) + "</div>"

    def marker(self, ids, here, opens=False):
        """A ∀ button and its popover.  Blue when every criterion behind it is
        proven, amber when any is open."""
        if not ids:
            return ""
        self.pop += 1
        pid = f"lean-pop-{self.pop}"
        rules, criteria, _ = self.model
        if opens:
            statuses = [criteria[c]["status"] for c in ids]
            body = "".join(self.question_html(c, here) for c in ids)
            label = "Open " + ("criterion " if len(ids) == 1 else "criteria ") + ", ".join(ids)
        else:
            statuses = [c["status"] for r in ids for c in rules[r]["criteria"]]
            body = "".join(self.requirement_html(r, here) for r in ids)
            label = "Lean " + ("requirement " if len(ids) == 1 else "requirements ") + ", ".join(ids)
        tone = "open" if "open" in statuses else "proven" if all(s == "proven" for s in statuses) else "partial"
        return (f'<span class="lean-anchor" data-lean><button type="button" class="lean-marker {tone}" '
                f'aria-expanded="false" aria-controls="{pid}" aria-label="{esc(label)}">∀</button>'
                f'<div class="lean-pop {"amber" if tone == "open" else ""}" id="{pid}" role="dialog" '
                f'aria-label="{esc(label)}" hidden>{body}</div></span>')

    # Blocks -------------------------------------------------------------
    def blocks(self, bs, here):
        out = []
        for b in bs:
            if b[0] == "p":
                text = self.inline(b[1], here)
                if b[2]:
                    out.append(f'<div class="marked"><p>{text}</p>{self.marker(b[2], here)}</div>')
                else:
                    out.append(f"<p>{text}</p>")
            elif b[0] == "ul":
                out.append("<ul>" + "".join(f"<li>{self.inline(i, here)}</li>" for i in b[1]) + "</ul>")
            else:
                out.append(getattr(self, "fence_" + b[1], self.fence_unknown)(b[2], here))
        return "\n".join(out)

    def fence_unknown(self, lines, here):
        fail(f"airline-site/content/{here}.md", "unknown fenced block")

    def fence_stages(self, lines, here):
        items = "".join(f'<li><span class="num">{i}</span><span>{self.inline(t, here)}</span></li>'
                        for i, t in enumerate((l for l in lines if l.strip()), 1))
        return f'<ol class="stages">{items}</ol>'

    def fence_example(self, lines, here):
        lines = [l for l in lines if l.strip()]
        rows = []
        for l in lines[1:]:
            total = l.startswith("= ")
            label, _, value = l.lstrip("= ").partition("|")
            rows.append(f'<div class="row{" total" if total else ""}"><span>{self.inline(label.strip(), here)}</span>'
                        f'<span>{self.inline(value.strip(), here)}</span></div>')
        return (f'<div class="example"><p class="example-title">{self.inline(lines[0], here)}</p>'
                + "".join(rows) + "</div>")

    def fence_questions(self, lines, here):
        cards = []
        for l in lines:
            if not l.strip():
                continue
            topic, question, target = (x.strip() for x in l.split("|"))
            slug, _, anchor = target.lstrip("@").partition("#")
            if slug not in self.pages or (anchor and anchor not in self.anchors(slug)):
                fail(f"airline-site/content/{here}.md", f"question links to {target}, which does not exist")
            cards.append(f'<a class="question" href="{esc(self.href(here, slug, anchor))}">'
                         f'<span class="q-topic">{self.inline(topic, here)}</span>'
                         f'<span class="q-text">{self.inline(question, here)}</span></a>')
        return '<div class="questions">' + "".join(cards) + "</div>"

    def fence_fares(self, lines, here):
        """The fare table: for each row an action and a stage, and for each
        fare what the model decides there."""
        where = f"airline-site/content/{here}.md"
        words, rows = {}, []
        for l in lines:
            if not l.strip():
                continue
            if "|" in l:
                label, _, key = l.partition("|")
                action, stage = key.split()
                rows.append((label.strip(), action, stage))
            else:
                k, _, v = l.partition(":")
                words[k.strip()] = v.strip()
        for k in ("refused", "fee", "no fee", "nothing", "full", "fixed"):
            if k not in words:
                fail(where, f"the fare table has no wording for {k!r}")
        order = self.facts["fareOrder"]
        fares = self.facts["fares"]

        def cell(fare, action, stage):
            f = fares[fare][action].get(stage)
            at = f"{where}, the fare table, {fare} {action} {stage}"
            if f is None:
                fail(at, "no fact")
            if action == "change":
                if f["decision"] == "refused":
                    return esc(words["refused"])
                if f["decision"] != "allowed":
                    fail(at, f"the model gives {f['decision']}, which the table cannot show")
                if f.get("approximate"):
                    fail(at, "the fee is approximate, which the table cannot show")
                if f["fee"]["cents"] == 0:
                    return esc(words["no fee"])
                return esc(words["fee"]).replace("{fee}", f'<span class="amount">{money(f["fee"], at)}</span>')
            kind = f["kind"]
            if kind in ("nothing", "full"):
                return esc(words[kind])
            if kind == "fixed":
                return esc(words["fixed"]).replace("{refund}", f'<span class="amount">{money(f["refund"], at)}</span>')
            fail(at, f"the model gives {kind}, which the table cannot show")

        head = "".join(f'<th scope="col">{esc(fares[k]["name"])}</th>' for k in order)
        body = "".join(f'<tr><th scope="row">{self.inline(label, here)}</th>'
                       + "".join(f"<td>{cell(k, a, s)}</td>" for k in order) + "</tr>"
                       for label, a, s in rows)
        return (f'<div class="table-wrap" tabindex="0" role="region" aria-label="What each fare allows">'
                f'<table class="fares"><thead><tr><td></td>{head}</tr></thead><tbody>{body}</tbody></table></div>')

    # Page parts ---------------------------------------------------------
    def header(self, here):
        # Only Travel policies goes anywhere; the others lead home.
        cur = {"index": "", "policies": ' aria-current="page"'}.get(here, ' aria-current="true"')
        nav = "".join(f'<a href="{self.href(here, "index")}">{n}</a>' for n in ("Book", "My trips", "Check in"))
        nav += f'<a href="{self.href(here, "policies")}"{cur}>Travel policies</a>'
        return (f'<header class="site"><div class="wrap">'
                f'<a class="brand" href="{self.href(here, "index")}">{PLANE_SVG}'
                f'<span class="wordmark">{AIRLINE}</span></a>'
                f'<nav aria-label="Main">{nav}</nav></div></header>')

    def footer(self, here):
        return (f'<footer class="site"><div class="wrap"><p>{esc(FOOTER)}</p>'
                f'<nav aria-label="Footer"><a href="{self.href(here, "policies")}">Travel policies</a>'
                f'<a href="{self.site_root(here)}">The Verified Air model</a></nav></div></footer>')

    def toggle(self):
        return ('<button type="button" class="lean-toggle" aria-pressed="false">'
                '<span class="when-off">Show the Lean model</span><span class="when-on">Hide the Lean model</span></button>')

    def legend(self, here):
        return (f'<div class="lean-legend" data-lean><div class="wrap"><p>Each <span class="lean-marker proven" '
                f'aria-hidden="true">∀</span> button shows the requirement in the Lean model behind an answer. '
                f'Blue means every criterion is proven; amber means at least one is still open. '
                f'Every amount on these pages comes from <a href="{self.href(here, "index")}facts.json">facts.json</a>, '
                f'which <code>lake exe airline-facts</code> computes from the fares in '
                f'<a href="https://github.com/samdengler/verified-air/blob/main/Airline/Fares.lean">'
                f'Airline/Fares.lean</a>.</p></div></div>')

    def page(self, here, title, body, band):
        doc_title = AIRLINE if here == "index" else f"{title}: {AIRLINE}"
        up = "../" * self.path_of(here).count("/")
        return f"""<!DOCTYPE html>
<html lang="en" class="no-js">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(doc_title)}</title>
{FAVICON}
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="{FONTS.replace("&", "&amp;")}">
<link rel="stylesheet" href="{up}assets/airline.css">
<script>
  // Before the page draws: whether to show the Lean model.  ?lean=1 or
  // ?lean=0 sets it and is remembered; otherwise the remembered choice holds.
  (function () {{
    var d = document.documentElement, q = null, on = false;
    d.className = d.className.replace("no-js", "js");
    try {{ q = new URLSearchParams(location.search).get("lean"); }} catch (e) {{}}
    try {{
      if (q === "1" || q === "0") localStorage.setItem("{STORAGE_KEY}", q);
      on = (q || localStorage.getItem("{STORAGE_KEY}")) === "1";
    }} catch (e) {{ on = q === "1"; }}
    if (on) d.classList.add("lean-on");
  }})();
</script>
<script src="{up}assets/airline.js" defer></script>
</head>
<body>
<a class="skip" href="#content">Skip to content</a>
{self.header(here)}
{band}
<div id="content">
{body}
</div>
{self.footer(here)}
</body>
</html>
"""

    def band(self, here, page, toggle):
        m = page["meta"]
        crumb = ""
        if m.get("kind") == "policy":
            crumb = (f'<nav class="crumbs" aria-label="Breadcrumb"><a href="{self.href(here, "policies")}">Travel policies</a>'
                     f'<span aria-hidden="true">/</span><span aria-current="page">{esc(m["title"])}</span></nav>')
        tog = self.toggle() if toggle else ""
        return (f'<section class="band"><div class="wrap">{crumb}<div class="band-row"><div class="band-text">'
                f'<h1>{self.inline(m["title"], here)}</h1><p class="lede">{self.inline(m["lede"], here)}</p></div>'
                f"{tog}</div></div></section>" + (self.legend(here) if toggle else ""))

    # Pages --------------------------------------------------------------
    def home(self):
        p = self.pages["index"]
        m = p["meta"]
        sections = []
        for s in p["sections"]:
            sections.append(f'<section class="home-section" id="{s.anchor}"><div class="wrap">'
                            f'<div class="home-head"><div><h2>{self.inline(s.title, "index")}</h2>'
                            f'<p class="lede">{self.inline(m["lede"], "index")}</p></div>'
                            f'<a class="all" href="{self.href("index", "policies")}">All travel policies</a></div>'
                            f'{self.blocks(s.blocks, "index")}</div></section>')
        hero = f"""<section class="band hero"><div class="wrap">
<h1>{self.inline(m["title"], "index")}</h1>
<form class="search" onsubmit="return false" aria-describedby="search-note">
<div class="field"><label for="from">From</label><input id="from" value="Atlanta (ATL)" autocomplete="off"></div>
<div class="field"><label for="to">To</label><input id="to" placeholder="City or airport" autocomplete="off"></div>
<div class="field"><label for="depart">Depart</label><input id="depart" placeholder="Add date" autocomplete="off"></div>
<div class="field"><label for="return">Return</label><input id="return" placeholder="Add date" autocomplete="off"></div>
<button type="submit">Find flights</button>
</form>
<p class="search-note" id="search-note">This is a demonstration site, so it sells no flights. Its
<a href="{self.href("index", "policies")}">travel policies</a> are complete.</p>
</div></section>"""
        return self.page("index", m["title"], "\n".join(sections), hero)

    def counts(self, slug):
        rules = self.model[0]
        crit = [c for r in self.pages[slug]["meta"]["requirements"].split(",") for c in rules[r.strip()]["criteria"]]
        out = {"total": len(crit)}
        for c in crit:
            out[c["status"]] = out.get(c["status"], 0) + 1
        return out

    def hub(self):
        p = self.pages["policies"]
        cards = []
        for slug in (t.strip() for t in p["meta"]["topics"].split(",")):
            if slug not in self.pages:
                fail("airline-site/content/policies.md", f"topics names {slug!r}, which is not a page")
            m = self.pages[slug]["meta"]
            href = self.href("policies", slug)
            qs = "".join(f'<li><a href="{href}">{self.inline(q.strip(), "policies")}</a></li>'
                         for q in m["questions"].split("|"))
            n = self.counts(slug)
            badges = "".join(f'<span class="badge {k.replace(" ", "-")}">{n[k]} {STATUS_WORD[k]}</span>'
                             for k in ("proven", "open", "example", "not checked") if n.get(k))
            cards.append(f'<article class="topic"><h2><a href="{href}">{self.inline(m["title"], "policies")}</a></h2>'
                         f'<p>{self.inline(m["summary"], "policies")}</p><ul>{qs}</ul>'
                         f'<p class="topic-counts" data-lean><span>{n["total"]} criteria in the model</span>{badges}</p>'
                         f"</article>")
        body = f'<div class="wrap"><div class="topics">{"".join(cards)}</div></div>'
        return self.page("policies", p["meta"]["title"], body, self.band("policies", p, True))

    def policy(self, slug):
        p = self.pages[slug]
        nav, sections = [], []
        for s in p["sections"]:
            nav.append(f'<li><a href="#{s.anchor}">{self.inline(s.title, slug)}</a></li>')
            items = []
            for it in s.items:
                items.append(f'<div class="deciding"><div class="heading-row"><h3>{self.inline(it.title, slug)}</h3>'
                             f'{self.marker(it.opens, slug, opens=True)}</div>{self.blocks(it.blocks, slug)}</div>')
            sections.append(f'<section id="{s.anchor}"><div class="heading-row"><h2>{self.inline(s.title, slug)}</h2>'
                            f'{self.marker(s.model, slug)}</div>{self.blocks(s.blocks, slug)}{"".join(items)}</section>')
        related = "".join(f'<li><a href="{self.href(slug, r.strip())}">{esc(self.pages[r.strip()]["meta"]["title"])}</a></li>'
                          for r in p["meta"].get("related", "").split(",") if r.strip())
        body = (f'<div class="wrap policy"><nav class="toc" aria-label="On this page"><p>On this page</p>'
                f'<ul>{"".join(nav)}</ul></nav><main>{"".join(sections)}'
                f'<section class="related"><h2>Related policies</h2><ul>{related}</ul></section></main></div>')
        return self.page(slug, p["meta"]["title"], body, self.band(slug, p, True))


def opening(docstring):
    """The start of an open theorem's question: its first sentence or two after
    the words "Open question for ...".  Names in backticks become code."""
    text = plain(docstring)
    m = re.search(r"Open question for [^.]*\.\s*(.*)", text, re.S)
    if not m:
        return ""
    body = " ".join(m.group(1).split())
    sentences = re.split(r"(?<=[.?])\s+(?=[A-Z])", body)
    # The first sentence, and the second too if both are short.
    n = 2 if len(sentences) > 1 and len(sentences[0]) + len(sentences[1]) < 220 else 1
    start = " ".join(sentences[:n])
    more = len(sentences) > n
    out = esc(start, quote=False)
    out = re.sub(r"`([^`]+)`", r"<code>\1</code>", out)
    return out + (" …" if more else "")


def write(rel, text):
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


def main():
    if not FACTS.exists():
        sys.exit("render_airline: build/airline/facts.json is missing; run: lake exe airline-facts > build/airline/facts.json")
    facts = json.loads(FACTS.read_text())
    model = load_model()
    review = load_review()
    pages = {p.stem: parse(p) for p in sorted(CONTENT.glob("*.md"))}
    for need in ("index", "policies"):
        if need not in pages:
            sys.exit(f"render_airline: airline-site/content/{need}.md is missing")
    try:
        for page in pages.values():
            check_page(page, model, pages)
        r = Renderer(pages, facts, model, review)
        out = {"index": r.home(), "policies": r.hub()}
        for slug, page in pages.items():
            if page["meta"].get("kind") == "policy":
                out[slug] = r.policy(slug)
        for slug, text in out.items():
            check_hidden(text, f"the {slug} page")
    except BuildError as e:
        sys.exit(f"render_airline: {e}")
    for d in ("index.html", "policies", "assets"):
        p = OUT / d
        if p.is_dir():
            shutil.rmtree(p)
        elif p.exists():
            p.unlink()
    for slug, text in out.items():
        write(Renderer.path_of(slug) + "index.html", text)
    shutil.copytree(ASSETS, OUT / "assets")
    print(f"rendered build/airline/: {len(out)} pages, {r.pop} markers"
          + ("" if review else " (review document not built: links use its lookup page)"))


if __name__ == "__main__":
    main()
