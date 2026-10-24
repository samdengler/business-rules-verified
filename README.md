# business-rules-verified

A Lean model of one slice of the Offer and Order domain: an offer with priced
items and an expiry, the order created when a customer accepts it, payments
against the order, and refunds against payments. The build checks the model,
computes the status of every guarantee, and publishes two review documents.

This is the first namespace of a pattern that repeats per business group.
Shared concepts live in `Rules/Core/`; each group gets a directory under
`Rules/`.

## The two review layers

| Layer | Source | Published at |
| --- | --- | --- |
| Verso document: prose with checked Lean inside it | `Review/` | site root |
| leanblueprint: dependency graph colored by status, plus a PDF | `blueprint/src/content.tex` | `/blueprint/` and `/blueprint/print.pdf` |

Both layers are built from the same commit and take their status from the same
file, `build/status.json`, which `lake exe status` computes from the compiled
Lean.

## Authored and computed parts

Authored, and reviewed against the Lean by a second person:

- Docstrings in `Rules/` (they are the prose of both layers, written in Verso
  markup).
- The Verso chapters `Overview`, `Objects`, `Rules` and `Open Questions` in
  `Review/Review/`.
- The blueprint statements in `blueprint/src/content.tex` (without `\leanok`).

Computed by the build, never typed:

- Whether each theorem is proven or open: `lake exe status` checks the axioms
  each theorem depends on for `sorryAx`.
- Example values: each `@[case]` declaration is evaluated by `lake exe status`,
  and each `#guard` in `Rules/OfferOrder/Examples.lean` fails the build if a
  value changes.
- The EARS table (`build/ears.md`, `build/ears.csv`), from the `EARS:` line of
  each rule's docstring and its `@[ears "OO-00n"]` ID.
- `\leanok` markers in the blueprint, and the Verso `Guarantees`, `Examples`
  and EARS sections, written by `scripts/render_status.py` into
  `blueprint/src/*.generated.tex` and `Review/Review/Generated/`.

`lake exe status` exits nonzero if any declaration depends on `sorry` without
the `@[open_question]` tag, or if an EARS statement does not follow exactly one
EARS template. CI runs it before rendering anything.

## Building locally

Prerequisites: [elan](https://github.com/leanprover/elan), Python 3.12,
graphviz, and a TeX installation with `xelatex` and `latexmk` (TinyTeX works).

```sh
lake exe cache get                      # prebuilt Mathlib, once
lake build                              # the Rules library
lake exe status                         # build/status.json, ears.md, ears.csv

python3 -m venv .venv && . .venv/bin/activate
pip install leanblueprint               # on macOS with Homebrew graphviz, set
                                        # CFLAGS=-I$(brew --prefix graphviz)/include
                                        # LDFLAGS=-L$(brew --prefix graphviz)/lib
scripts/build-site.sh                   # everything CI builds, assembled in site/
python3 -m http.server -d site          # preview at http://localhost:8000
```

`scripts/build-site.sh` runs, in order: `lake build`, `lake exe status`,
`scripts/render_status.py`, `lake build Review`, `lake exe review-doc`,
`leanblueprint web`, `leanblueprint checkdecls`, `leanblueprint pdf`.

## Versions

| Tool | Version |
| --- | --- |
| Lean | `leanprover/lean4:v4.36.0-rc1` (Mathlib master's toolchain on 2026-10-24) |
| Mathlib | tag `v4.36.0-rc1` |
| Verso | tag `v4.36.0-rc1` |
| checkdecls | `master` at `3d42585` |
| leanblueprint | 0.0.20 |

`lake-manifest.json` pins every dependency to a commit.

## Results

RESULTS_PLACEHOLDER

## Decisions

Choices made where the plan left room, in the order they came up.

1. **Lean version.** Mathlib master pinned `v4.36.0-rc1`, and Verso has a tag
   with the same name, so Mathlib, Verso and the toolchain all use
   `v4.36.0-rc1`. Mathlib and Verso are pinned by tag in `lakefile.toml`. Their
   shared dependencies (plausible, Cli) resolve to the same commits.
2. **Cache download.** `lake new ... math` runs `lake exe cache get` itself.
   That first run downloaded the Mathlib cache; the `lake update` and
   `lake exe cache get` in Step 1 then had nothing left to fetch.
3. **Linter.** The template's `weak.linter.mathlibStandardSet` is removed; it
   enforces Mathlib's copyright header and style rules, which do not apply
   here. `autoImplicit = false` is set as the plan asks.
4. **`public` is a keyword** in this Lean version, so the first
   `Classification` constructor is written `«public»`.
5. **`Instant` ordering.** `LinearOrder` cannot be derived, so it is lifted
   from `epochSeconds` with `LinearOrder.lift'`.
6. **Amounts in minor units.** The plan's refund example uses 60, 100 and 120.
   The model stores minor units, so the case uses 6000, 10000 and 12000 cents
   (60.00, 100.00 and 120.00 USD).
7. **`accept` also rejects mixed currencies**, since `Rejection` has a
   `mixedCurrency` constructor. The checks run in the order expiry, empty offer,
   currency.
8. **Distinct payment IDs.** `refunds_le_payments` assumes the payment IDs are
   distinct. Without that, the statement fails even after the refund rule is
   fixed, for a reason unrelated to the business question. The double-refund
   counterexample uses one payment, so it still applies.
9. **What the status executable lists.** Only documented declarations are
   listed, so derived instances, structure projections and helper lemmas
   without docstrings are left out. Proven and open counts are reported per
   namespace. The acceptance count (three proven, one open) refers to
   `Rules.OfferOrder`; `Rules.Core` adds two proven lemmas (`public_le`,
   `Money.add_same_currency`).
10. **Example values** are computed with `Lean.Meta.evalExpr` inside the status
    executable (built with `supportInterpreter = true`). The `#eval` fallback
    was not needed. The executable imports only `Rules.Core.Attributes` and
    loads `Rules` from its `.olean` files at run time. Importing all of `Rules`
    made linking compile Mathlib's native code, which took 14 minutes in CI.
11. **Docstrings use Verso markup** (`doc.verso = true` for the whole
    package). Code spans carry roles: `{name}` for model declarations (a rename
    breaks the docstring), and `{lit}` or `{lean}` for literals and terms.
    `Status/Main.lean` turns the option off, since its comments are for
    developers.
12. **Generated Verso modules.** The plan names one `Generated.lean`. Each Verso
    chapter is its own module, so the script writes three:
    `Review/Review/Generated/Guarantees.lean`, `Examples.lean` and `Ears.lean`.
    They are gitignored and regenerated on every build, as are
    `blueprint/src/*.generated.tex`.
13. **Verso layout.** The `Review` library has `srcDir = "Review"`, so its
    chapters sit in `Review/Review/`. The `review-doc` executable's root is
    `Review/Main.lean`. Verso writes `build/review/html-multi/`, and that
    directory becomes the site root.
14. **Statement in the Guarantees chapter.** Each guarantee shows its Lean
    statement twice: in the `{docstring}` box, which renders the full signature,
    and in a checked ```` ```lean ```` block (`#check @name`).
15. **`leanblueprint new` answers:** checkdecls yes; doc-gen4 no (the Verso
    document takes the place of API docs); Jekyll home page no; CI yes. The
    generated `blueprint.yml` and the template's other three workflows were
    then folded into `ci.yml`.
16. **Graph colors.** Proven theorems get `\leanok` on both the statement and
    the proof, so they fill dark green. The open theorem gets neither. By
    default leanblueprint would fill it light blue ("ready to prove");
    `\graphcolor{can_prove}{}{No}` in `macros/web.tex` leaves it unfilled. Its
    blue border still says the statement is ready.
17. **Blueprint to Verso links.** leanblueprint links each `\lean{}` name to
    `{dochome}/find/#doc/<name>`. `\dochome{../docs}` points that link at
    `pages/docs/find/index.html`, a small redirect into Verso's own
    `find/?name=<name>` page, which jumps to the declaration's section.
18. **CI step order.** `render_status.py` runs before the Verso build, because
    it writes chapters the build imports. `leanblueprint web` runs before
    `checkdecls`, because `web` writes the `lean_decls` file that `checkdecls`
    reads.
19. **TeX in CI.** CI installs TinyTeX instead of `texlive-full`, matching the
    local setup, which also uses TinyTeX. It is far smaller, and its default
    package set built the PDF with no additions. CI runs `tlmgr update --self`
    first, because the installer's `tlmgr` refused to install packages until
    it was updated. CI also caches the compiled Verso packages, keyed on
    `lake-manifest.json`.
20. **Pages deploys from `main` only.** Pull requests build and upload the
    site but do not deploy it.
21. **Deploy is gated on `PAGES_ENABLED`.** GitHub refused to turn on Pages
    for this repository: "Your current plan does not support GitHub Pages for
    this repository." The plan asks for a private repository, so it stays
    private, and the deploy job runs only when the repository variable
    `PAGES_ENABLED` is `true`. Until then, every CI run uploads the assembled
    site as the `github-pages` artifact, which can be downloaded from the run
    and previewed locally.
22. **EARS outputs.** The status executable writes `build/ears.csv` along with
    `ears.md`. "Proven by" lists every theorem whose statement mentions the
    rule, so OO-001 lists both `accept` theorems.
23. **Branch protection** is not turned on for the POC. CODEOWNERS names
    `@samdengler` on every path.
24. **Acceptance demos.** The demos (fixing the refund rule, changing a
    `#guard`, renaming `accept`) were run locally on a branch or as uncommitted
    edits, then discarded, as the plan says.
