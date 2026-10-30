// The history files, read when the composition is bundled.  Nothing here is
// typed by hand: the milestones, statuses and counts come from history/, and
// the nodes that appear, the status changes and the camera boxes come from
// build/frames/frames.json, which `python3 scripts/graph_history.py frames`
// writes (scripts/render-motion.sh runs it first).  The two are checked
// against each other, so a stale frames.json stops the build.

import indexJson from "../../history/index.json";
import layoutJson from "../../history/layout.json";
import framesJson from "../../build/frames/frames.json";

export type Status = "modelled" | "proven" | "open" | "decision" | "ready" | "waiting";

// The site's order of statuses (STATUS_ORDER in scripts/graph_model.py).
export const STATUS_ORDER: Status[] = ["modelled", "proven", "open", "decision", "ready", "waiting"];

export type Box = { x: number; y: number; width: number; height: number };

type SnapNode = {
  id: string;
  title: string;
  candidate: string | null;
  area: string;
  status: Status;
  statusWords: string;
};

type IndexMilestone = {
  seq: number;
  name: string;
  description: string;
  file: string;
  nodes: number;
  statusCounts: Partial<Record<Status, number>>;
};

type FrameMilestone = {
  seq: number;
  name: string;
  nodes: number;
  statusCounts: Partial<Record<Status, number>>;
  appear: string[];
  change: { id: string; from: Status; to: Status }[];
  box: Box;
};

export type LayoutNode = { x: number; y: number; height: number; lines: string[] };

export type Layout = {
  width: number;
  height: number;
  cardWidth: number;
  nodes: Record<string, LayoutNode>;
  edges: { from: string; to: string; path: string }[];
};

export type Counts = Record<Status, number>;

export type Milestone = {
  seq: number;
  name: string;
  nodes: Map<string, SnapNode>;
  appear: string[];
  change: { id: string; from: Status; to: Status }[];
  box: Box;
  counts: Counts;
  total: number;
};

// webpack, which Remotion bundles with, resolves require.context when it
// builds, so every snapshot in history/ is in the bundle.
declare const require: {
  context(dir: string, deep: boolean, match: RegExp): (key: string) => unknown;
};
const snapshotFiles = require.context("../../history", false, /^\.\/\d{4}-[a-z0-9-]+\.json$/);

function fail(message: string): never {
  throw new Error(`motion/src/data.ts: ${message}`);
}

export function zeroCounts(): Counts {
  return { modelled: 0, proven: 0, open: 0, decision: 0, ready: 0, waiting: 0 };
}

const sameSet = (a: string[], b: string[]) =>
  a.length === b.length && [...a].sort().join("\n") === [...b].sort().join("\n");

export const layout = layoutJson as unknown as Layout;
const index = (indexJson as unknown as { milestones: IndexMilestone[] }).milestones;
const frames = (framesJson as unknown as { milestones: FrameMilestone[] }).milestones;

if (frames.length !== index.length || frames.some((f, i) => f.name !== index[i].name)) {
  fail("build/frames/frames.json does not match history/index.json; run python3 scripts/graph_history.py frames");
}

export const statusWords = {} as Record<Status, string>;

export const milestones: Milestone[] = [];
for (const [i, m] of index.entries()) {
  const snap = snapshotFiles(`./${m.file}`) as { nodes: SnapNode[] };
  const nodes = new Map(snap.nodes.map((n) => [n.id, n]));
  const counts = zeroCounts();
  for (const n of snap.nodes) {
    if (!STATUS_ORDER.includes(n.status)) fail(`${m.file}: unknown status ${n.status}`);
    if (!layout.nodes[n.id]) fail(`${n.id} is in ${m.file} but not in history/layout.json; run python3 scripts/graph_history.py layout`);
    counts[n.status] += 1;
    statusWords[n.status] = n.statusWords;
  }
  if (snap.nodes.length !== m.nodes) fail(`${m.file} has ${snap.nodes.length} nodes and index.json says ${m.nodes}`);
  for (const s of STATUS_ORDER) {
    if (counts[s] !== (m.statusCounts[s] ?? 0)) fail(`${m.file} has ${counts[s]} ${s} and index.json says ${m.statusCounts[s] ?? 0}`);
  }
  const before = i > 0 ? milestones[i - 1].nodes : new Map<string, SnapNode>();
  const appear = snap.nodes.filter((n) => !before.has(n.id)).map((n) => n.id);
  const change = snap.nodes
    .filter((n) => before.has(n.id) && before.get(n.id)!.status !== n.status)
    .map((n) => ({ id: n.id, from: before.get(n.id)!.status, to: n.status }));
  const f = frames[i];
  if (!sameSet(appear, f.appear)) fail(`frames.json disagrees with the snapshots on the nodes that appear at ${m.name}`);
  if (!sameSet(change.map((c) => `${c.id} ${c.from} ${c.to}`), f.change.map((c) => `${c.id} ${c.from} ${c.to}`))) {
    fail(`frames.json disagrees with the snapshots on the status changes at ${m.name}`);
  }
  milestones.push({ seq: m.seq, name: m.name, nodes, appear, change, box: f.box, counts, total: snap.nodes.length });
}

for (const s of STATUS_ORDER) if (!statusWords[s]) fail(`no node has the status ${s}, so its label is unknown`);
