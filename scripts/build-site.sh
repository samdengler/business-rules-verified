#!/usr/bin/env bash
# Build everything CI builds, in the same order, and assemble site/.
#
#   scripts/build-site.sh
#
# Needs: elan, Python 3.12 with leanblueprint, graphviz, a TeX installation
# with xelatex and latexmk, and Java 21 with Maven.
set -euo pipefail
cd "$(dirname "$0")/.."

lake build
lake exe status
# Verified Airline's fares, evaluated by the model (Airline/); fails if two
# readings of the guide disagree.  The airline's site reads them from
# /airline-data/.
lake build Airline airline-facts
mkdir -p build/airline-data
lake exe airline-facts > build/airline-data/facts.json
python3 scripts/render_status.py
lake build Review
rm -rf build/review
lake exe review-doc --output build/review
lake build Oracle oracle
mkdir -p build/oracle
lake exe oracle --vectors > build/oracle/vectors.jsonl
mvn -B -q -f impl/java/pom.xml verify
lake build Verify
# web writes blueprint/lean_decls, which checkdecls reads.
leanblueprint web
leanblueprint checkdecls
leanblueprint pdf
python3 scripts/render_progress.py
python3 scripts/render_home.py
python3 scripts/render_graph.py
python3 scripts/render_history.py
python3 scripts/render_areas.py
python3 scripts/render_tour.py
# The rest of /airline-data/, then Verified Airline's wording checked against it.
python3 scripts/export_airline.py
scripts/check-airline.sh
scripts/build-wasm.sh

scripts/assemble-site.sh
echo "site/ is ready; preview with: python3 scripts/serve_site.py"
