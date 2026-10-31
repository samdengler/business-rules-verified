#!/usr/bin/env bash
# Rebuild the documents and serve the site at http://localhost:8000/ (or the
# port given), to review a change before it is pushed.
#
#   scripts/preview.sh [port]
#
# Builds the model, the status, the review document, the blueprint web pages,
# the progress page, the Explore page, the area pages, the tour, the files
# Verified Airline's site reads, and the try-it panels' WebAssembly.  Skips the Java
# checks, the Rust proofs and the blueprint PDF, which CI runs; a PDF or
# conformance vectors from an earlier full build are included if present.
# Needs elan, Python 3.12 with leanblueprint, graphviz, and rustup for the
# try-it panels.
set -euo pipefail
cd "$(dirname "$0")/.."
port="${1:-8000}"

lake build
lake exe status
lake build Airline airline-facts
mkdir -p build/airline-data
lake exe airline-facts > build/airline-data/facts.json
python3 scripts/render_status.py
lake build Review
rm -rf build/review
lake exe review-doc --output build/review
leanblueprint web
python3 scripts/render_progress.py
python3 scripts/render_home.py
python3 scripts/render_graph.py
python3 scripts/render_history.py
python3 scripts/render_areas.py
python3 scripts/render_tour.py
python3 scripts/export_airline.py
# The try-it panels need the Rust rules compiled to WebAssembly; skipped
# without rustup.
if command -v rustup >/dev/null; then scripts/build-wasm.sh; fi
ALLOW_MISSING=1 scripts/assemble-site.sh

echo "serving site/ at http://localhost:$port/ (Ctrl-C to stop)"
python3 scripts/serve_site.py "$port"
