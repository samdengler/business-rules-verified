# Motion brief: how the dependency graph grows

This brief prepares a motion piece that shows the model growing: nodes are identified from the ONE Order material, wait on business decisions, and turn into Lean rules and proven guarantees, while a few stay open with a counterexample. It describes the story, the data the piece can be built from, and the visual language the site already uses.

## The story, by milestone

Each milestone is a commit with a git tag `milestone/<name>` and a snapshot in [`history/`](../history/). The snapshots so far:

| # | Milestone | What changes on screen |
| --- | --- | --- |
| 1 | `first-slice` | 25 nodes appear: the shared definitions (money, time, passenger), offers and orders, payments and refunds. Rules are In Lean; three guarantees turn Proven. One guarantee, refunds never exceed payments, turns red: an example shows two refunds of 60.00 against one payment of 100.00 returning 120.00. |
| 2 | `candidates-identified` | The first survey of IATA's public ONE Order pages adds 23 candidate nodes and their connections. 12 arrive amber (needs a decision), 2 blue (ready to build), 9 grey and dashed (waiting on other nodes). |
| 3 | `starting-small` | No new nodes. This is the state to propose for an internal pilot, and the point where the piece can pause on the question "what if we kept going?". |

Later milestones follow the work on `main`: each survey round adds candidates, and each capability formalized turns its nodes In Lean or Proven, or red with a counterexample. The [coverage map](one-order-coverage.md) gives the scale to aim at: 63 business capabilities in ONE Order, 5 in Lean in part today.

## The data

| File | What it holds |
| --- | --- |
| [`history/index.json`](../history/index.json) | Every milestone in order: name, description, commit, date, tag, node count, and the count of nodes in each status. |
| `history/NNNN-<name>.json` | The graph at that milestone: every node with its id, title, candidate ID (C-01 and so on), kind (definition or theorem), area, status, Lean names, and the ids of the nodes it uses. |
| [`history/layout.json`](../history/layout.json) | One position for every node that appears in any milestone, and the connector paths, computed by Graphviz as on the site. A node keeps its place from frame to frame, so the piece can fade nodes in and recolor them without the graph jumping. |
| `/graph/graph.json` on the site | The current graph in the same shape as a snapshot, rebuilt on every push. |

Node ids are the blueprint labels (`def:c08-delivery-status`) and do not change between milestones. Statuses are `modelled` (In Lean), `proven`, `open`, `decision` (needs a decision), `ready` (ready to build) and `waiting`.

Two accuracy notes:

* For milestones recorded after the fact (1 to 3), the statuses of nodes in Lean come from the build at the time of recording. No guarantee in those nodes has changed status since the model was built, so they are exact. A snapshot taken when its milestone is reached is exact by construction.
* Nothing in the build searches for counterexamples. Examples are written by hand and Lean computes their results, so the piece should show the counterexample as an example that breaks the rule, not as something Lean discovered.

## Visual language

The piece should look like the site's dependency graph page.

* Cards: 184 wide, corner radius 8, the title in 13 px at weight 600, and a status line in 11.5 px with a colored dot. Finished states have a 1.5 px colored rim and a light tint of the same color; states that need attention have a 2 px rim and a stronger tint; waiting cards have a dashed grey rim.
* Connectors: 1.25 px, neutral grey (`#b9b8b0` light, `#55544f` dark), with a small filled arrowhead. A selected node's connectors darken.
* Status colors, the same in light and dark mode: In Lean magenta `#e87ba4`, Proven green `#0ca30c`, Open question red `#d03b3b`, Needs a decision amber `#fab219`, Ready to build blue `#2a78d6` (`#3987e5` in dark mode), Waiting grey `#898781`. They were checked against each other for color-blind readers; every status also carries its label.
* Type: the system sans-serif (`system-ui`). Surfaces: `#fcfcfb` on `#f9f9f7` in light mode, `#1a1a19` on `#0d0d0d` in dark mode.
* Mark: a plane taking off and the words "Airline Order" (`PLANE_PATH` in `scripts/site_nav.py`).

## Recording a milestone

```sh
lake exe status                                   # current statuses
python3 scripts/graph_history.py snapshot <name> "<one sentence on what changed>" --tag
python3 scripts/graph_history.py layout           # recompute shared positions
git push origin main --follow-tags
```

`--commit REF` records an earlier commit. Name milestones by what they add, such as `orders-change-identified` for a survey round or `ordpen-formalized` when a capability's rules are in Lean.

## Open for the follow-up

The input format the motion tool expects is not settled here. The data above is plain JSON, and the site's own renderer (`scripts/render_graph.py`) can draw a frame for any milestone from `history/layout.json` and that milestone's snapshot if the tool takes SVG frames.
