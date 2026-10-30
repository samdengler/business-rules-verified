# CLAUDE.md

Business rules for airline offers and orders as a Lean model, with review documents, requirement specs and implementation checks generated from it. The README explains the design and records every decision; read it before changing structure.

## Working on the site

- Work locally and publish in batches. `scripts/preview.sh` rebuilds the documents and serves the site at http://localhost:8000; a second run takes a minute or two. CI takes about 15 minutes on a cold cache.
- For a visual change, take screenshots (headless Chrome works) and show them before pushing.
- Before pushing, run `scripts/build-site.sh`, which runs everything CI runs. Commit `.kiro/specs` whenever `scripts/render_status.py` changes it; CI fails if the committed specs are stale.
- After changing `impl/rust`, run `scripts/translate-rust.sh` and commit `Verify/Rust/`; CI checks it matches a fresh translation.
- Push straight to `main`. No pull requests, no merge commits.

## What the site may claim

- Statuses and example values are computed by the build. Never type one by hand: change the Lean and rebuild.
- Proven means Lean checked a proof that holds for every input. Open means the theorem has no proof and is tagged `@[open_question]`.
- Nothing in the build searches for counterexamples. Examples are written by hand and Lean computes their results, so say "an example shows the rule breaking it", never "Lean found".
- `Verify/RustRules.lean` proves the Rust `step` and `accept_refund` equal to the model. The WebAssembly wrapper in `impl/wasm` and the try-it panels' script are not proved, and the panels say so.
- This is a proof of concept, not affiliated with IATA. Rules from IATA's public material are described in our own words with a link to the page. Quote nothing from the EASD guide; its notice forbids reproduction.

## Authored and generated files

| Authored | Generated |
| --- | --- |
| `Rules/**/*.lean`: rule docstrings carry `EARS:`, `Story:` and `* OO-00n.m:` criteria; examples state Given, When and Then and return records whose fields label each part | `Review/Review/Generated/` (`scripts/render_status.py`): a chapter per requirement, the front page cards, the EARS table |
| `blueprint/src/content.tex`, without `\leanok`; candidate nodes use `Open point:`, `Counterexample:` and `Source:` paragraphs, which the progress page reads | `blueprint/src/*.generated.tex`, `.kiro/specs/` (committed) |
| `Review/Review/{Overview,OpenQuestions,Objects}.lean`, `Review/Review.lean`, `Review/Review/Status.lean`, `Review/review.css`, `Review/review.js` | `build/progress/index.html` (`scripts/render_progress.py`), the site root; `build/graph/index.html` (`scripts/render_graph.py`), `/graph/` |
| `impl/java`, `impl/rust`, `impl/wasm`, `scripts/` | `Verify/Rust/` (committed), `build/try/rules.wasm` |

The bar at the top of every page is defined once in `scripts/site_nav.py`; `Review/review.js` repeats its links for the review document, so change both together.

A new requirement needs `{include 1 Review.Generated.OO00n}` in `Review/Review.lean`; `render_status.py` fails until it is there.

## Branches, tags and milestones

- `main` grows toward as much of ONE Order as the public material allows. The `starting-small` branch (tag `snapshot/starting-small`) keeps the version to propose for an internal pilot; fixes to that version go on that branch.
- Each milestone (a survey round's candidates added, a capability's rules in Lean) gets a snapshot and an annotated tag with `python3 scripts/graph_history.py snapshot <name> "<sentence>" --tag`, then `python3 scripts/graph_history.py layout`. `docs/motion-brief.md` explains why: the snapshots feed a motion piece about how the graph grew.

## Versions

Lean, Mathlib and Verso are on `v4.35.0` because the pinned Aeneas release needs it. The Aeneas commit in `lakefile.toml` and the release in `scripts/translate-rust.sh` move together with the Lean version.

## Writing

Prose on the site, in docstrings and in the README follows one style: no em or en dashes; short declarative sentences; headings that name the topic; no "X, not Y" contrasts, rhetorical setups or filler adverbs. Business-facing text uses the status words already on the site: modelled, proven, open question, needs a decision, ready to build, waiting; and for criteria, proven, example only, open, not checked.
