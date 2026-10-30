# Motion piece: how the graph grew

A 70-second film of the dependency graph growing over the milestones in [`history/`](../history/), made with [Remotion](https://www.remotion.dev): a React composition that is rendered frame by frame in headless Chrome and encoded to MP4. It follows the storyboard in [`docs/motion-brief.md`](../docs/motion-brief.md) and is shown above the step control in the History tab of the site's Explore page.

## Rendering

```sh
scripts/render-motion.sh
```

The script runs `python3 scripts/graph_history.py frames`, installs the pinned packages with `npm ci`, and writes:

| File | What it is |
| --- | --- |
| `out/history.mp4` | 1920 by 1080, 30 fps, H.264 (CRF 20, BT.709), about 9 MB |
| `out/history-poster.jpg` | The last frame, the final state, used as the video's poster |

Both files are committed. CI does not render video, so after a new milestone run the script again and commit them; `scripts/assemble-site.sh` copies them to `site/motion/`. A render takes about a minute on a recent Mac. The first run downloads Remotion's headless Chrome; Remotion brings its own ffmpeg (`npx remotion ffmpeg` runs it, for example to pull a still from the MP4).

`npm run studio` opens Remotion's preview, where the timeline can be scrubbed. It needs `build/frames/frames.json`, so run the frames command first.

## Where the numbers come from

Nothing on screen is typed by hand except the captions' wording. `src/data.ts` imports `history/index.json`, every snapshot `history/NNNN-*.json`, `history/layout.json` and `build/frames/frames.json`, and stops the bundle if they disagree: the status counts of each snapshot against `index.json`, and the nodes that appear and change status against `frames.json`. `src/story.ts` checks that the cards on screen at the end of every beat add up to that milestone's counts. The counters count the cards on screen frame by frame, and the counts in captions (23 candidate rules, 138, 124) are computed from the milestones.

The examples in the captions (two refunds of 60.00, seat 12B, the 50 EUR fee and the others) are our own words about the model's Lean examples, and each names the open question whose card is highlighted. `src/story.ts` lists them with the card each one belongs to and fails if that card is not an open question at its milestone. No caption says Lean found anything.

## Files

| File | What it does |
| --- | --- |
| `src/data.ts` | Reads and checks the history files |
| `src/story.ts` | The storyboard as frames: when each card appears and changes, where the camera is, the captions |
| `src/History.tsx` | Draws a frame: cards and connectors on the shared canvas, the caption band, the counters |
| `src/theme.ts` | The site's colors, card shapes and mark |
| `remotion.config.ts` | Encoding settings |

The composition takes a `theme` prop, `light` (rendered) or `dark`. Text uses `system-ui`, so a render on another system uses that system's font.

## Licence

Remotion is free for individuals, for-profit companies of up to three employees and non-profits, and a larger company needs a company licence ([terms](https://www.remotion.dev/license)).
