#!/usr/bin/env bash
# Assemble site/ from the build outputs, in the layout GitHub Pages serves:
# the progress page at the root, the review document under review/, the
# blueprint under blueprint/, the try-it panels' WebAssembly under try/, and
# the specs and exports beside them.
#
#   scripts/assemble-site.sh
#
# CI, scripts/build-site.sh and scripts/preview.sh all use this script.  The
# blueprint PDF, the conformance vectors and the WebAssembly are required unless
# ALLOW_MISSING=1, which the preview sets because it skips those steps.
set -euo pipefail
cd "$(dirname "$0")/.."

optional() {
  if [ -f "$1" ]; then
    cp "$1" "$2"
  elif [ "${ALLOW_MISSING:-}" != 1 ]; then
    echo "missing $1" >&2
    exit 1
  fi
}

rm -rf site
mkdir -p site/blueprint site/review
cp build/progress/index.html site/index.html
mkdir -p site/graph
cp build/graph/index.html build/graph/graph.json site/graph/
cp -r build/review/html-multi/. site/review/
cp -r pages/. site/
cp -r blueprint/web/. site/blueprint/
python3 scripts/site_nav.py site/blueprint
optional blueprint/print/print.pdf site/blueprint/print.pdf
cp -r .kiro/specs site/specs
cp build/ears.md build/ears.csv build/ears-criteria.csv build/status.json site/
optional build/oracle/vectors.jsonl site/conformance-vectors.jsonl
mkdir -p site/try
optional build/try/rules.wasm site/try/rules.wasm
