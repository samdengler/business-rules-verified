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

A new requirement needs `{include 1 Review.Generated.<ID without the dash>}` (such as `ONE301`) in `Review/Review.lean`; `render_status.py` fails until it is there.

## Branches, tags and milestones

- `main` grows toward as much of ONE Order as the public material allows. The `starting-small` branch (tag `snapshot/starting-small`) keeps the version to propose for an internal pilot; fixes to that version go on that branch.
- Each milestone (a survey round's candidates added, a capability's rules in Lean) gets a snapshot and an annotated tag with `python3 scripts/graph_history.py snapshot <name> "<sentence>" --tag`, then `python3 scripts/graph_history.py layout`. `docs/motion-brief.md` explains why: the snapshots feed a motion piece about how the graph grew.

## ONE Order areas

- `Rules/OneOrder/*.lean` are the foundations (services, statuses, items, orders, accepting an offer). Each area has its own folder and sub-namespace and its own range of requirement IDs:

  | Area | Namespace | IDs | Blueprint file |
  | --- | --- | --- | --- |
  | Delivery | `Rules.OneOrder.Delivery` | ONE-101 to ONE-199 | `areas/delivery.tex` |
  | Change and cancellation | `Rules.OneOrder.Change` | ONE-201 to ONE-299 | `areas/change-cancellation.tex` |
  | Payment | `Rules.OneOrder.Payment` | ONE-301 to ONE-399 | `areas/payment.tex` |
  | Order creation and information | `Rules.OneOrder.Creation` | ONE-401 to ONE-499 | `areas/order-creation.tex` |
  | Offers, prices and conditions | `Rules.OneOrder.Offers` | ONE-501 to ONE-599 | `areas/offers-prices.tex` |
  | Ancillaries, seats and bundles | `Rules.OneOrder.Ancillaries` | ONE-601 to ONE-699 | `areas/ancillaries.tex` |
  | Airline-initiated change | `Rules.OneOrder.AirlineChange` | ONE-701 to ONE-799 | `areas/airline-change.tex` |
  | Commission, accounting and settlement | `Rules.OneOrder.Accounting` | ONE-801 to ONE-899 | `areas/accounting.tex` |

- Where the sources are vague or silent, the rule takes the undecided part as a parameter (a reading, such as `ValueReading` or `RepeatHandling`). A guarantee is proven only if it holds under every reading; otherwise it is open, with an example under the reading that breaks it. A proven version for one reading may follow, named with `_of_` and tagged with no criterion. Never pick a reading for the business and then prove the guarantee.
- Tag a theorem `@[checks "ID"]` only if it proves that criterion for every input. A theorem that two statuses never overlap does not prove "mark X when Y".
- Several areas can be written at once in git worktrees, each with `.lake/packages` linked to the main checkout's. Merge by rebasing onto `main`; conflicts in `Rules.lean`, `Review/Review.lean` and `.kiro/specs/README.md` are additive. Keep the requirement chapters in ID order, run `scripts/build-site.sh`, and commit the regenerated specs index.

## Versions

Lean, Mathlib and Verso are on `v4.35.0` because the pinned Aeneas release needs it. The Aeneas commit in `lakefile.toml` and the release in `scripts/translate-rust.sh` move together with the Lean version.

## Writing

Prose on the site, in docstrings and in the README follows one style: no em or en dashes; short declarative sentences; headings that name the topic; no "X, not Y" contrasts, rhetorical setups or filler adverbs. Business-facing text uses the status words already on the site: modelled, proven, open question, needs a decision, ready to build, waiting; and for criteria, proven, example only, open, not checked.
