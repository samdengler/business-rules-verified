#!/usr/bin/env python3
"""Draw the README diagrams as SVG.

    python3 scripts/diagrams.py

writes docs/diagrams/<name>.svg.  Each diagram has its own white background,
so it reads the same on a light or a dark page.  The SVGs are committed;
rerun this script after editing a diagram here.
"""

from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent.parent / "docs" / "diagrams"

SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'Helvetica Neue', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, 'SF Mono', Menlo, Consolas, monospace"

# GitHub's light colors.  The dark set is kept for a later dark variant; the
# diagrams are drawn in light only, on a white background.
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
BODY_SIZE = 14
MONO_SIZE = 13
LINE = 20


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
        bg = (f'<rect x="-12" y="-12" width="{self.w + 24}" height="{self.h + 24}" rx="12" '
              f'fill="#ffffff" stroke="#d0d7de" stroke-width="1"/>')
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w + 26}" height="{self.h + 26}" '
            f'viewBox="-13 -13 {self.w + 26} {self.h + 26}" role="img" aria-label="{escape(title)}">\n'
            f"<title>{escape(title)}</title>\n<defs>{head}</defs>\n{bg}\n" + "\n".join(self.parts) + "\n</svg>\n"
        )


# The README column on GitHub is 700 to 900 pixels wide, so the diagrams are
# drawn 760 wide and show close to their natural size.
W = 760


def question_loop(theme):
    s = Svg(W, 470, theme)
    w, h, gap = 220, 150, 50
    xs = [k * (w + gap) for k in range(3)]
    top, bottom = 10, 310
    s.box(xs[0], top, w, h, "Business rule", body=[
        "A refund cannot exceed the", "payment it is made against."])
    s.box(xs[1], top, w, h, "Lean definition", tone="blue", code=[
        "acceptRefund p r :=", "  r.payment == p.id &&", "  r.amount ≤ p.amount"])
    s.box(xs[2], top, w, h, "Theorem", tone="blue", code=[
        "totalRefunded", "  ≤ totalPaid"], body=["for every list of payments", "and refunds on an order"])
    s.box(xs[2], bottom, w, h, "Proven", tone="green", body=[
        "A guarantee about every", "input. Lean checked the", "proof on this commit."])
    s.box(xs[1], bottom, w, h, "Counterexample", tone="amber", tag="OPEN", body=[
        "Two refunds of 60.00", "against one payment of", "100.00 both pass, so", "120.00 comes back."])
    s.box(xs[0], bottom, w, h, "Question for the business", body=[
        "Is the limit per refund, per", "payment or per order? Is a", "goodwill refund above the",
        "amount paid ever allowed?"])
    mid = top + h / 2
    s.arrow([(xs[0] + w, mid), (xs[1] - 2, mid)])
    s.arrow([(xs[1] + w, mid), (xs[2] - 2, mid)])
    band = (top + h + bottom) / 2
    px = xs[2] + w * 0.7
    s.arrow([(px, top + h), (px, bottom - 2)], "proof checks", (px - 10, band + 34), "end")
    fx = xs[2] + w * 0.3
    s.arrow([(fx, top + h), (fx, band), (xs[1] + w / 2, band), (xs[1] + w / 2, bottom - 2)],
            "proof fails", ((fx + xs[1] + w / 2) / 2, band - 9))
    bmid = bottom + h / 2
    s.arrow([(xs[1], bmid), (xs[0] + w + 2, bmid)])
    qx = xs[0] + w / 2
    s.arrow([(qx, bottom), (qx, top + h + 2)])
    s.text(qx + 10, band - 4, "the answer", size=12.5, color=s.t["muted"], weight=500)
    s.text(qx + 10, band + 13, "changes the rule", size=12.5, color=s.t["muted"], weight=500)
    return s.render("From a business rule to a guarantee or a question")


def build(theme):
    s = Svg(W, 720, theme)
    w, gap = 210, 65
    cx = [k * (w + gap) for k in range(3)]
    s.heading(cx[0], 14, "Written by people")
    s.heading(cx[1], 14, "Checked by the build")
    s.heading(cx[2], 14, "Published")

    s.box(cx[0], 30, w, 150, "Rules/*.lean", tone="blue", body=[
        "Rules, theorems and", "examples. Each rule's", "docstring holds its EARS",
        "statement, user story and", "acceptance criteria."])
    s.box(cx[0], 330, w, 92, "Review/Review/*.lean", body=["Prose chapters of the", "review document"])
    s.box(cx[0], 442, w, 92, "blueprint/src/", code=["content.tex"], body=["Graph statements"])

    s.box(cx[1], 30, w, 112, "lake build", body=["Lean checks every proof", "and every example value"])
    s.box(cx[1], 172, w, 132, "lake exe status", body=[
        "Proven or open for each", "theorem; a status for", "each acceptance criterion"])
    s.box(cx[1], 334, w, 132, "render_status.py", body=[
        "Writes the generated", "chapters, the graph's", "proof markers and the", "Kiro specs"])

    s.box(cx[2], 172, w, 92, "CSV exports", body=["ears.csv", "ears-criteria.csv"])
    s.box(cx[2], 296, w, 72, "Review document", body=["Verso, site root"])
    s.box(cx[2], 384, w, 72, "Dependency graph", body=["leanblueprint, /blueprint/"])
    s.box(cx[2], 472, w, 72, "Kiro specs", body=[".kiro/specs/"])

    s.arrow([(cx[0] + w, 86), (cx[1] - 2, 86)])
    mx = cx[1] + w / 2
    s.arrow([(mx, 142), (mx, 170)])
    s.arrow([(mx, 304), (mx, 332)])
    s.arrow([(cx[0] + w, 376), (cx[1] - 2, 376)])
    gx = cx[0] + w + gap / 2
    s.arrow([(cx[0] + w, 488), (gx, 488), (gx, 426), (cx[1] - 2, 426)])
    s.arrow([(cx[1] + w, 218), (cx[2] - 2, 218)])
    fx = cx[1] + w + gap / 2
    out = cx[1] + w
    for ty in (332, 420, 508):
        s.arrow([(out, 400), (fx, 400), (fx, ty), (cx[2] - 2, ty)])

    t = s.t
    s.parts.append(f'<rect x="1" y="568" width="{W - 2}" height="144" rx="10" fill="{t["amber"][0]}" '
                   f'stroke="{t["amber"][1]}" stroke-width="1.5"/>')
    s.text(17, 596, "CI fails on", size=TITLE_SIZE, weight=600)
    for k, line in enumerate([
        "a proof Lean rejects  ·  a changed example value",
        "a renamed rule that the review document mentions",
        "an unproven theorem not marked as an open question",
        "an EARS line that fits no template  ·  out-of-date Kiro specs",
        "Java that disagrees with the model  ·  Rust whose proof fails",
    ]):
        s.text(17, 622 + 20 * k, line, color=t["muted"])
    return s.render("How the build turns the Lean model into documents")


def namespaces(theme):
    s = Svg(W, 300, theme)
    w, gap = 230, 35
    xs = [k * (w + gap) for k in range(3)]
    s.box(xs[0], 1, w, 130, "Rules.OfferOrder", tone="blue", tag="BUILT", body=[
        "Offers, orders, payments", "and refunds. 3 rules,", "4 theorems, 6 examples"])
    s.box(xs[1], 1, w, 130, "Rules.Identity", dashed=True, body=[
        "Customers, agents, and", "who may act for whom", "", "Not built"])
    s.box(xs[2], 1, w, 130, "Rules.DataGovernance", dashed=True, body=[
        "Which fields each", "clearance level may see", "", "Not built"])
    s.box(1, 200, W - 2, 92, "Rules.Core", body=[
        "Shared by every group: money, time, parties, data classification,",
        "and the attributes the status executable reads"])
    for x in xs:
        s.arrow([(x + w / 2, 131), (x + w / 2, 198)])
    s.text(xs[0] + w / 2 + 10, 170, "builds on", size=12.5, color=s.t["muted"], weight=500)
    return s.render("Each business group is a namespace that builds on Rules.Core")


def implementation_checks(theme):
    s = Svg(W, 452, theme)
    w, gap = 230, 35
    xs = [k * (w + gap) for k in range(3)]
    s.box(1, 1, W - 2, 64, "Lean model: Rules/OfferOrder", tone="blue",
          body=["The definitions and theorems; the specification every implementation is checked against"])
    s.box(xs[0], 120, w, 168, "1  Test oracle", tag="FIXED CASES", body=[
        "lake exe oracle --vectors", "writes 24 requests with the", "model's answers. A JUnit test",
        "runs each one through Java", "and compares."])
    s.box(xs[1], 120, w, 168, "2  Property tests", tag="SAMPLED", body=[
        "jqwik generates thousands", "of inputs. Java and the", "running oracle must agree,",
        "and each theorem is checked", "as a property of the Java."])
    s.box(xs[2], 120, w, 168, "3  Aeneas proof", tag="ALL INPUTS", body=[
        "Charon and Aeneas translate", "the Rust code into Lean, and", "a Lean proof shows it",
        "computes what the model", "computes, for every input."])
    s.box(xs[0], 352, xs[1] + w - xs[0], 92, "Java: impl/java", tone="green", body=[
        "OfferOrderRules.java, written the way a service team would. mvn verify", "runs options 1 and 2 in CI."])
    s.box(xs[2], 352, w, 92, "Rust: impl/rust", tone="green", body=["step and accept_refund.", "lake build Verify runs the proofs"])
    for x in xs:
        s.arrow([(x + w / 2, 66), (x + w / 2, 118)])
        s.arrow([(x + w / 2, 288), (x + w / 2, 350)])
    s.text(xs[0] + w / 2 + 10, 98, "answers", size=12.5, color=s.t["muted"], weight=500)
    s.text(xs[0] + w / 2 + 10, 324, "checks", size=12.5, color=s.t["muted"], weight=500)
    return s.render("Three ways to check an implementation against the Lean model")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name, draw in [("question-loop", question_loop), ("build", build), ("namespaces", namespaces),
                       ("implementation-checks", implementation_checks)]:
        (OUT / f"{name}.svg").write_text(draw("light"))
    print(f"wrote {OUT.relative_to(OUT.parent.parent)}/*.svg")


if __name__ == "__main__":
    main()
