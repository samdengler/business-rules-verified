#!/usr/bin/env bash
# Build everything CI builds, in the same order, and assemble site/.
#
#   scripts/build-site.sh
#
# Needs: elan, Python 3.12 with leanblueprint, graphviz, and a TeX
# installation with xelatex and latexmk.
set -euo pipefail
cd "$(dirname "$0")/.."

lake build
lake exe status
python3 scripts/render_status.py
lake build Review
lake exe review-doc --output build/review
leanblueprint checkdecls
leanblueprint web
leanblueprint pdf

rm -rf site
mkdir -p site/blueprint
cp -r build/review/html-multi/. site/
cp -r pages/. site/
cp -r blueprint/web/. site/blueprint/
cp blueprint/print/print.pdf site/blueprint/print.pdf
cp build/ears.md build/ears.csv build/status.json site/
echo "site/ is ready; preview with: python3 -m http.server -d site"
