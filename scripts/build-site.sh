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
python3 scripts/render_status.py
lake build Review
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

rm -rf site
mkdir -p site/blueprint site/review
cp build/progress/index.html site/index.html
cp -r build/review/html-multi/. site/review/
cp -r pages/. site/
cp -r blueprint/web/. site/blueprint/
cp blueprint/print/print.pdf site/blueprint/print.pdf
cp -r .kiro/specs site/specs
cp build/ears.md build/ears.csv build/ears-criteria.csv build/status.json site/
cp build/oracle/vectors.jsonl site/conformance-vectors.jsonl
echo "site/ is ready; preview with: python3 -m http.server -d site"
