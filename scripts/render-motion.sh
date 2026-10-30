#!/usr/bin/env bash
# Render the motion piece about how the graph grew: motion/out/history.mp4
# (1920 by 1080, 30 fps, H.264) and its poster, motion/out/history-poster.jpg,
# the final state.  Then record what the film was drawn from in
# motion/out/history-film.json.
#
#   scripts/render-motion.sh
#
# Needs Python 3 and Node 24 with npm.  Remotion downloads its own headless
# Chrome on the first run and brings its own ffmpeg.  CI does not run this:
# the rendered files are committed, and scripts/assemble-site.sh copies them
# into the site.  scripts/render_graph.py stops the site build when the record
# no longer matches history/ and motion/src/, so rerun this after recording a
# milestone or changing the storyboard, then commit motion/out/.
# docs/motion-brief.md describes the piece.
set -euo pipefail
cd "$(dirname "$0")/.."

# The composition reads history/ and build/frames/frames.json.
python3 scripts/graph_history.py frames

(
  cd motion
  npm ci --no-audit --no-fund
  mkdir -p out
  npx remotion render src/index.ts History out/history.mp4
  npx remotion still src/index.ts Poster out/history-poster.jpg --image-format=jpeg --jpeg-quality=85
  ls -l out/history.mp4 out/history-poster.jpg
)

python3 scripts/graph_history.py film
