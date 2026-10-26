#!/usr/bin/env python3
"""Draw the README diagrams as SVG, in a light and a dark version.

    python3 scripts/diagrams.py

writes docs/diagrams/<name>-light.svg and <name>-dark.svg.  The README shows
them with a <picture> element so GitHub picks the one that matches the
reader's theme.  The SVGs are committed; rerun this script after editing a
diagram here.
"""

from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent.parent / "docs" / "diagrams"

SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica Neue', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, monospace"

# GitHub's own light and dark page colors, so the diagrams sit on the page.
THEMES = {
    "light": {
        "text": "#1f2328", "muted": "#59636e", "line": "#8c959f",
        "box": "#f6f8fa", "stroke": "#d0d7de", "band": "#f6f8fa",
        "blue": ("#ddf4ff", "#0969da"), "green": ("#dafbe1", "#1a7f37"),
        "amber": ("#fff8c5", "#9a6700"), "plain": ("#ffffff", "#d0d7de"),
    },
    "dark": {
        "text": "#e6edf3", "muted": "#9198a1", "line": "#6e7681",
        "box": "#161b22", "stroke": "#30363d", "band": "#161b22",
        "blue": ("#121d2f", "#4493f8"), "green": ("#12261e", "#3fb950"),
        "amber": ("#272115", "#d29922"), "plain": ("#0d1117", "#3d444d"),
    },
}

TITLE_SIZE = 15
BODY_SIZE = 13.5
MONO_SIZE = 12.5
LINE = 19


class Svg:
    def __init__(self, w, h, theme):
        self.w, self.h, self.t = w, h, THEMES[theme]
        self.parts = []

    def box(self, x, y, w, h, title, body=(), code=(), tone="plain", dashed=False, tag=None):
        """A rounded box with a bold title, then code lines, then body lines."""
        fill, stroke = self.t[tone]
        dash = ' stroke-dasharray="6 5"' if dashed else ""
        self.parts.append(
            f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="1.5"{dash}/>'
        )
        ty = y + 28
        if tag:
            self.parts.append(
                f'<text x="{x + w - 14}" y="{ty}" text-anchor="end" font-family="{SANS}" font-size="12" '
                f'font-weight="600" fill="{self.t["muted"] if tone == "plain" else stroke}">{escape(tag)}</text>'
            )
        self.text(x + 16, ty, title, size=TITLE_SIZE, weight=600)
        ty += 8
        for line in code:
            ty += LINE
            self.text(x + 16, ty, line, size=MONO_SIZE, font=MONO)
        if code:
            ty += 6
        for line in body:
            ty += LINE
            self.text(x + 16, ty, line, size=BODY_SIZE, color=self.t["muted"])

    def text(self, x, y, s, size=BODY_SIZE, weight=400, color=None, font=SANS, anchor="start"):
        color = color or self.t["text"]
        self.parts.append(
            f'<text x="{x}" y="{y}" font-family="{font}" font-size="{size}" font-weight="{weight}" '
            f'fill="{color}" text-anchor="{anchor}" xml:space="preserve">{escape(s)}</text>'
        )

    def arrow(self, points, label=None, label_at=None, anchor="middle"):
        """A polyline with rounded corners and an arrowhead at the last point."""
        d = f"M{points[0][0]},{points[0][1]}"
        for i in range(1, len(points) - 1):
            (x0, y0), (x1, y1), (x2, y2) = points[i - 1], points[i], points[i + 1]
            r = min(10, abs(x1 - x0 + y1 - y0) / 2, abs(x2 - x1 + y2 - y1) / 2)
            sx = x1 - r * ((x1 > x0) - (x1 < x0))
            sy = y1 - r * ((y1 > y0) - (y1 < y0))
            ex = x1 + r * ((x2 > x1) - (x2 < x1))
            ey = y1 + r * ((y2 > y1) - (y2 < y1))
            d += f" L{sx},{sy} Q{x1},{y1} {ex},{ey}"
        d += f" L{points[-1][0]},{points[-1][1]}"
        self.parts.append(
            f'<path d="{d}" fill="none" stroke="{self.t["line"]}" stroke-width="1.6" marker-end="url(#head)"/>'
        )
        if label:
            lx, ly = label_at
            self.text(lx, ly, label, size=12.5, color=self.t["muted"], anchor=anchor, weight=500)

    def heading(self, x, y, s):
        self.text(x, y, s.upper(), size=12, weight=700, color=self.t["muted"])

    def render(self, title):
        head = (
            f'<marker id="head" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
            f'orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="{self.t["line"]}"/></marker>'
        )
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
            f'viewBox="0 0 {self.w} {self.h}" role="img" aria-label="{escape(title)}">\n'
            f"<title>{escape(title)}</title>\n<defs>{head}</defs>\n" + "\n".join(self.parts) + "\n</svg>\n"
        )


def question_loop(theme):
    s = Svg(1000, 430, theme)
    w, h = 205, 150
    gap = 53
    xs = [10 + k * (w + gap) for k in range(4)]
    top, bottom = 20, 270
    s.box(xs[0], top, w, h, "Business rule", body=[
        "A refund cannot exceed", "the payment it is made", "against."])
    s.box(xs[1], top, w, h, "Lean definition", tone="blue", code=[
        "acceptRefund p r :=", "  r.payment == p.id &&", "  r.amount ≤ p.amount"])
    s.box(xs[2], top, w, h, "Theorem", tone="blue", code=[
        "totalRefunded", "  ≤ totalPaid"], body=["for every list of payments", "and refunds on an order"])
    s.box(xs[3], top, w, h, "Proven", tone="green", body=[
        "A guarantee about every", "input. Lean checked the", "proof on this commit."])
    s.box(xs[2], bottom, w, h, "Counterexample", tone="amber", tag="OPEN", body=[
        "Two refunds of 60.00", "against one payment of", "100.00 both pass, so", "120.00 comes back."])
    s.box(xs[1], bottom, w, h, "Question for the business", body=[
        "Is the limit per refund,", "per payment or per order?", "Is a goodwill refund above",
        "the amount paid ever", "allowed?"])
    mid = top + h / 2
    s.arrow([(xs[0] + w, mid), (xs[1] - 2, mid)])
    s.arrow([(xs[1] + w, mid), (xs[2] - 2, mid)])
    s.arrow([(xs[2] + w, mid), (xs[3] - 2, mid)])
    gx = xs[2] + w + gap / 2
    s.text(gx, mid - 26, "proof", size=12.5, color=s.t["muted"], anchor="middle", weight=500)
    s.text(gx, mid - 11, "checks", size=12.5, color=s.t["muted"], anchor="middle", weight=500)
    cx = xs[2] + w / 2
    s.arrow([(cx, top + h), (cx, bottom - 2)], "proof fails", (cx + 10, (top + h + bottom) / 2 + 4), "start")
    bmid = bottom + h / 2
    s.arrow([(xs[2], bmid), (xs[1] + w + 2, bmid)])
    lx = xs[1] + w / 2
    s.arrow([(lx, bottom), (lx, top + h + 2)], "the answer changes the rule",
            (lx - 10, (top + h + bottom) / 2 + 4), "end")
    return s.render("From a business rule to a guarantee or a question")


def build(theme):
    s = Svg(1000, 640, theme)
    w = 286
    cx = [10, 357, 704]
    s.heading(cx[0], 22, "Written by people")
    s.heading(cx[1], 22, "Checked by the build")
    s.heading(cx[2], 22, "Published on every push")

    s.box(cx[0], 40, w, 128, "Rules/*.lean", tone="blue", body=[
        "Rules, theorems and examples.", "Each rule's docstring holds its",
        "EARS statement, user story and", "acceptance criteria."])
    s.box(cx[0], 316, w, 84, "Review/Review/*.lean", body=["Prose chapters of the review", "document"])
    s.box(cx[0], 420, w, 84, "blueprint/src/content.tex", body=["Statements for the dependency", "graph"])

    s.box(cx[1], 40, w, 100, "lake build", body=["Lean checks every proof and every", "example value"])
    s.box(cx[1], 176, w, 110, "lake exe status", body=[
        "Works out proven or open for each", "theorem and a status for each",
        "acceptance criterion"])
    s.box(cx[1], 322, w, 110, "scripts/render_status.py", body=[
        "Writes the generated chapters,", "the graph's proof markers and",
        "the Kiro specs"])

    s.box(cx[2], 176, w, 84, "CSV exports", body=["ears.csv, one row per rule", "ears-criteria.csv, per criterion"])
    s.box(cx[2], 280, w, 66, "Review document", body=["Verso, at the site root"])
    s.box(cx[2], 362, w, 66, "Dependency graph and PDF", body=["leanblueprint, at /blueprint/"])
    s.box(cx[2], 444, w, 66, "Kiro specs", body=[".kiro/specs/<area>/requirements.md"])

    s.arrow([(cx[0] + w, 90), (cx[1] - 2, 90)])
    mx = cx[1] + w / 2
    s.arrow([(mx, 140), (mx, 174)])
    s.arrow([(mx, 286), (mx, 320)])
    gx = cx[0] + w + 30
    s.arrow([(cx[0] + w, 358), (cx[1] - 2, 358)])
    s.arrow([(cx[0] + w, 462), (gx, 462), (gx, 400), (cx[1] - 2, 400)])
    s.arrow([(cx[1] + w, 218), (cx[2] - 2, 218)])
    fx = cx[1] + w + 30
    out = cx[1] + w
    s.arrow([(out, 377), (fx, 377), (fx, 313), (cx[2] - 2, 313)])
    s.arrow([(out, 377), (fx, 377), (fx, 395), (cx[2] - 2, 395)])
    s.arrow([(out, 377), (fx, 377), (fx, 477), (cx[2] - 2, 477)])

    t = s.t
    s.parts.append(f'<rect x="10" y="530" width="980" height="96" rx="10" fill="{t["amber"][0]}" '
                   f'stroke="{t["amber"][1]}" stroke-width="1.5"/>')
    s.text(26, 558, "CI fails on", size=TITLE_SIZE, weight=600)
    s.text(26, 584, "a proof Lean rejects  ·  a changed example value  ·  a renamed rule the review document mentions",
           size=BODY_SIZE, color=t["muted"])
    s.text(26, 607, "an unproven theorem not marked as an open question  ·  an EARS line that fits no template  ·  "
                    "out-of-date Kiro specs", size=BODY_SIZE, color=t["muted"])
    return s.render("How the build turns the Lean model into documents")


def namespaces(theme):
    s = Svg(1000, 280, theme)
    w = 316
    xs = [10, 342, 674]
    s.box(xs[0], 20, w, 108, "Rules.OfferOrder", tone="blue", tag="BUILT", body=[
        "Offers, orders, payments, refunds.", "3 rules, 4 theorems, 6 examples"])
    s.box(xs[1], 20, w, 108, "Rules.Identity", dashed=True, tag="NOT BUILT", body=[
        "Customers, agents, and who may", "act for whom"])
    s.box(xs[2], 20, w, 108, "Rules.DataGovernance", dashed=True, tag="NOT BUILT", body=[
        "Which fields each clearance", "level may see"])
    s.box(10, 196, 980, 74, "Rules.Core", body=[
        "Shared by every group: money, time, parties, data classification, and the attributes "
        "the status executable reads"])
    for x in xs:
        s.arrow([(x + w / 2, 128), (x + w / 2, 194)])
    s.text(xs[0] + w / 2 + 10, 167, "builds on", size=12.5, color=s.t["muted"], weight=500)
    return s.render("Each business group is a namespace that builds on Rules.Core")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in [("question-loop", question_loop), ("build", build), ("namespaces", namespaces)]:
        for theme in THEMES:
            (OUT / f"{name}-{theme}.svg").write_text(draw(theme))
    print(f"wrote {OUT.relative_to(OUT.parent.parent)}/*.svg")


if __name__ == "__main__":
    main()
