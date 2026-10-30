// The storyboard of docs/motion-brief.md as frames: when each card appears and
// changes color, where the camera is, and which caption is on screen.  Counts
// in captions are computed from the milestones; the examples in captions are
// our own words about the model's Lean examples.

import { Easing } from "remotion";
import { type Box, type Counts, layout, milestones, type Milestone, type Status, STATUS_ORDER, zeroCounts } from "./data";
import { CARD_W } from "./theme";

export const FPS = 30;
export const WIDTH = 1920;
export const HEIGHT = 1080;
// The caption band is at the top, so a browser's video controls, which sit at
// the bottom, cover cards rather than the captions and counts.
export const BAND = 176; // the caption band
export const STAGE_H = HEIGHT - BAND; // the graph below it

export const APPEAR = 9; // a new card fades in and scales from 96 to 100 percent (about 300 ms)
export const CHANGE = 12; // a status change crossfades (about 400 ms)
export const PULSE = 33; // a new open question pulses its rim once (about 1.1 s)
export const DIM = 0.2; // the opacity of other areas during an area's beat

const sec = (s: number) => Math.round(s * FPS);

export type Track = {
  id: string;
  x0: number; // top left corner on the canvas
  y0: number;
  h: number;
  lines: string[];
  candidate: string | null;
  appear: number; // the frame its fade-in starts
  states: { at: number; status: Status }[]; // its status from each frame on (a change crossfades from `at`)
  area: (string | undefined)[]; // its area at each milestone
  pulses: number[];
};

export type Caption = { from: number; to: number; chip?: string; text: string };

export type Beat = {
  from: number;
  to: number;
  m: number; // index of the milestone on screen
  title: string;
  captions: Caption[];
  focus?: { area: string; ids: Set<string> }; // dim every other card
  question?: { id: string; from: number; to: number; callout: boolean };
  final?: boolean;
};

const tracks = new Map<string, Track>();
for (const [i, m] of milestones.entries()) {
  for (const [id, n] of m.nodes) {
    let t = tracks.get(id);
    if (!t) {
      const p = layout.nodes[id];
      t = {
        id,
        x0: p.x - CARD_W / 2,
        y0: p.y - p.height / 2,
        h: p.height,
        lines: p.lines,
        candidate: null,
        appear: Infinity,
        states: [],
        area: [],
        pulses: [],
      };
      tracks.set(id, t);
    }
    t.area[i] = n.area;
    t.candidate = n.candidate; // the latest, as the layout's titles are
  }
}

// Start frames for a set of cards between `from` and `to`, row by row from the
// top and left to right within a row.
function cascade(ids: string[], from: number, to: number, rowSpread = 0.35): Map<string, number> {
  const rows = [...new Set(ids.map((id) => layout.nodes[id].y))].sort((a, b) => a - b);
  const out = new Map<string, number>();
  const span = Math.max(0, to - from - sec(rowSpread));
  for (const id of ids) {
    const p = layout.nodes[id];
    const r = rows.indexOf(p.y);
    const rowStart = rows.length > 1 ? (span * r) / (rows.length - 1) : 0;
    out.set(id, Math.round(from + rowStart + (p.x / layout.width) * sec(rowSpread)));
  }
  return out;
}

function appearAt(m: Milestone, starts: Map<string, number>) {
  for (const id of m.appear) {
    const t = tracks.get(id)!;
    t.appear = starts.get(id)!;
    t.states.push({ at: t.appear, status: m.nodes.get(id)!.status });
  }
}

function changeAt(m: Milestone, starts: Map<string, number>) {
  for (const c of m.change) tracks.get(c.id)!.states.push({ at: starts.get(c.id)!, status: c.to });
}

// The frame at which a card's open status shows: when it appears or when it turns.
function openAt(id: string, m: Milestone): number {
  const t = tracks.get(id)!;
  const s = [...t.states].reverse().find((x) => x.status === "open");
  if (!s || m.nodes.get(id)?.status !== "open") throw new Error(`${id} is not an open question at ${m.name}`);
  return s.at;
}

// Every card that becomes an open question pulses once, a moment after it
// shows red, unless a caption calls for it later.
function pulseNewOpen(m: Milestone, except: Set<string> = new Set()) {
  const turned = [...m.appear.filter((id) => m.nodes.get(id)!.status === "open"), ...m.change.filter((c) => c.to === "open").map((c) => c.id)];
  for (const id of turned) if (!except.has(id)) tracks.get(id)!.pulses.push(openAt(id, m) + 4);
}

function expect(i: number, name: string) {
  if (milestones[i]?.name !== name) {
    throw new Error(`the storyboard expects milestone ${i + 1} to be ${name}; extend motion/src/story.ts for a new opening`);
  }
}

const plural = (n: number, one: string, many: string) => `${n} ${n === 1 ? one : many}`;
const newWith = (m: Milestone, s: Status) => m.appear.filter((id) => m.nodes.get(id)!.status === s).length;

// The open question named in each area's caption, and the example that breaks
// it, in our own words.  Each is checked to be open at its milestone.
const AREA_QUESTIONS: Record<string, { id: string; text: string }> = {
  "change-cancellation": {
    id: "thm:change-cancellation-offer-within-payments",
    text: "A partly paid order is offered a refund of its full price.",
  },
  payment: {
    id: "thm:payment-settled-final",
    text: "A redirected payment captured a minute after its time limit succeeds, and the trip stays removed.",
  },
  delivery: {
    id: "thm:delivery-all-final-closed",
    text: "An order whose services all end not claimed never closes.",
  },
  "order-creation": {
    id: "thm:order-creation-offer-used-once",
    text: "A request resent after a timeout creates a second order from the same offer.",
  },
  "airline-change": {
    id: "thm:airline-change-cancel-after-involuntary",
    text: "Declining the airline's own change costs a 50 EUR cancellation fee.",
  },
  "offers-prices": {
    id: "thm:offers-zero-duration-payable",
    text: "With a zero payment duration, the item can never be paid on time.",
  },
  ancillaries: {
    id: "thm:ancillaries-seat-one-passenger",
    text: "One request gives seat 12B to two passengers.",
  },
  accounting: {
    id: "thm:accounting-one-allocation",
    text: "Two source pages split a short payment of 100.00 between two airlines: 50 and 50, or 100 and 0.",
  },
};

const OPEN = "Open question";

export const beats: Beat[] = [];
export const camera: { at: number; box: Box }[] = [];

// Keep the camera where it is until `at`.
const hold = (at: number) => camera.push({ at, box: camera[camera.length - 1].box });

// 1. The pilot (0 to 8 s): milestone 1 fades in, zoomed to its box; the open
// refund guarantee pulses with its example.
{
  expect(0, "first-slice");
  const m = milestones[0];
  appearAt(m, cascade(m.appear, sec(0.4), sec(2.2), 0.3));
  const refund = "thm:refunds-le-payments";
  const at = sec(3.6);
  tracks.get(refund)!.pulses.push(at);
  pulseNewOpen(m, new Set([refund]));
  // Hold on the pilot's box, then move in a little toward the open question
  // while its caption is up.
  const b = m.box;
  const card = layout.nodes[refund];
  const k = 0.88;
  const cx = b.x + b.width / 2 + (card.x - (b.x + b.width / 2)) * 0.35;
  const cy = b.y + b.height / 2 + (card.y - (b.y + b.height / 2)) * 0.35;
  const closer = { x: cx - (b.width * k) / 2, y: cy - (b.height * k) / 2, width: b.width * k, height: b.height * k };
  camera.push({ at: 0, box: b }, { at: at - sec(0.4), box: b }, { at: sec(7.8), box: closer });
  beats.push({
    from: 0,
    to: sec(8),
    m: 0,
    title: "The pilot",
    captions: [
      { from: sec(0.6), to: sec(3.4), text: "The pilot in Lean: offers and orders, delivery, payments and refunds." },
      { from: at, to: sec(8), chip: OPEN, text: "Two refunds of 60.00 against a payment of 100.00 return 120.00." },
    ],
    question: { id: refund, from: at, to: sec(8), callout: false },
  });
}

// 2. First survey (8 to 14 s): the candidates fade in and the camera eases out.
{
  expect(1, "candidates-identified");
  const m = milestones[1];
  appearAt(m, cascade(m.appear, sec(8.4), sec(10.8)));
  pulseNewOpen(m);
  hold(sec(8.1));
  camera.push({ at: sec(11), box: m.box });
  beats.push({
    from: sec(8),
    to: sec(14),
    m: 1,
    title: "First survey",
    captions: [
      {
        from: sec(8.2),
        to: sec(14),
        text: `A first survey of IATA's public pages adds ${plural(m.appear.length, "candidate rule", "candidate rules")}; ${newWith(m, "decision")} need a business decision.`,
      },
    ],
  });
}

// 3. Starting small (14 to 18 s): hold.
{
  expect(2, "starting-small");
  const m = milestones[2];
  if (m.appear.length || m.change.length) throw new Error("the storyboard holds on starting-small, which should change nothing");
  beats.push({
    from: sec(14),
    to: sec(18),
    m: 2,
    title: "Starting small",
    captions: [{ from: sec(14.2), to: sec(18), text: "Where a pilot could stop." }],
  });
}

// 4. Foundations (18 to 24 s): ONE Order's structure arrives; candidates
// recolor; two new open questions pulse.
{
  expect(3, "oneorder-foundations");
  const m = milestones[3];
  appearAt(m, cascade(m.appear, sec(18.4), sec(19.8)));
  changeAt(m, cascade(m.change.map((c) => c.id), sec(19.2), sec(20.6)));
  const opened = m.appear.filter((id) => m.nodes.get(id)!.status === "open");
  const at = sec(21.2);
  for (const id of opened) tracks.get(id)!.pulses.push(at);
  pulseNewOpen(m, new Set(opened));
  camera.push({ at: sec(18), box: m.box });
  beats.push({
    from: sec(18),
    to: sec(24),
    m: 3,
    title: "Foundations",
    captions: [
      { from: sec(18.2), to: sec(21), text: "ONE Order's own structure in Lean: services, order items, orders and their statuses." },
      {
        from: at,
        to: sec(24),
        chip: opened.length === 1 ? OPEN : "Open questions",
        text: "An item can meet two statuses at once, and an order can be neither opened nor closed.",
      },
    ],
  });
}

// 5. The whole standard (24 to 33 s): the second survey cascades in row by
// row while the camera pulls back to the full canvas.
{
  expect(4, "second-survey");
  const m = milestones[4];
  appearAt(m, cascade(m.appear, sec(25), sec(30.5), 0.5));
  pulseNewOpen(m);
  hold(sec(24.3));
  camera.push({ at: sec(27.8), box: m.box });
  beats.push({
    from: sec(24),
    to: sec(33),
    m: 4,
    title: "Second survey",
    captions: [
      {
        from: sec(24.2),
        to: sec(33),
        text: `The second survey reads every area: ${plural(m.appear.length, "candidate rule", "candidate rules")}, ${newWith(m, "decision")} of them left to the business to decide.`,
      },
    ],
  });
}

// 6. Eight areas (33 to 60 s): each area in Lean in turn, with the others dimmed.
const AREA_BEAT = 3.375;
let t0 = 33;
for (let i = 5; i < milestones.length; i++) {
  const m = milestones[i];
  const from = sec(t0);
  const to = sec(t0 + AREA_BEAT);
  // The area being written is the one most of the new cards belong to.
  const byArea = new Map<string, number>();
  for (const id of m.appear) {
    const a = m.nodes.get(id)!.area;
    byArea.set(a, (byArea.get(a) ?? 0) + 1);
  }
  const area = [...byArea.entries()].sort((a, b) => b[1] - a[1])[0]?.[0];
  if (!area) throw new Error(`${m.name} adds no cards, so it has no area to show`);
  appearAt(m, cascade(m.appear, from + sec(0.2), from + sec(1.2), 0.25));
  changeAt(m, cascade(m.change.map((c) => c.id), from + sec(0.7), from + sec(1.6), 0.25));
  pulseNewOpen(m);
  const q = AREA_QUESTIONS[m.name];
  const captions: Caption[] = [];
  let question: Beat["question"];
  if (q) {
    const at = Math.max(openAt(q.id, m) + 6, from + sec(0.5));
    captions.push({ from: from + 2, to, chip: OPEN, text: q.text });
    question = { id: q.id, from: at, to: to - 3, callout: true };
  } else {
    const prev = milestones[i - 1].counts;
    captions.push({
      from: from + 2,
      to,
      text: `In Lean: ${plural(m.appear.length, "new card", "new cards")}, ${m.counts.proven - prev.proven} more proven, ${m.counts.open - prev.open} more open questions.`,
    });
  }
  const ids = new Set([...m.appear, ...m.change.map((c) => c.id)]);
  beats.push({ from, to, m: i, title: area, captions, focus: { area, ids }, question });
  t0 += AREA_BEAT;
}
camera.push({ at: sec(t0), box: milestones[milestones.length - 1].box });

// 7. Where it stands (10 s): undim, hold on the full canvas, count up.
export const FINAL_FROM = sec(t0);
export const DURATION = sec(t0 + 10);
beats.push({
  from: FINAL_FROM,
  to: DURATION,
  m: milestones.length - 1,
  title: "Where it stands",
  captions: [
    {
      from: FINAL_FROM + sec(3.2),
      to: DURATION + sec(10), // stays to the last frame, which is the poster
      text: "Every red card is a question for the business, with the example that breaks the rule.",
    },
  ],
  final: true,
});

export const trackList = [...tracks.values()];
for (const t of trackList) {
  if (!Number.isFinite(t.appear)) throw new Error(`${t.id} never appears`);
  t.states.sort((a, b) => a.at - b.at);
}

export function statusAt(t: Track, f: number): { from: Status; to: Status; k: number } {
  let i = t.states.length - 1;
  while (i > 0 && t.states[i].at > f) i--;
  const s = t.states[i];
  if (i > 0 && f < s.at + CHANGE) return { from: t.states[i - 1].status, to: s.status, k: Easing.inOut(Easing.cubic)(Math.min(1, Math.max(0, (f - s.at) / CHANGE))) };
  return { from: s.status, to: s.status, k: 1 };
}

// The counts of the cards on screen: a card counts once it is half faded in,
// in its new status once a change is half done.
export function countsAt(f: number): { counts: Counts; total: number } {
  const counts = zeroCounts();
  let total = 0;
  for (const t of trackList) {
    if (f < t.appear + APPEAR / 2) continue;
    const s = statusAt(t, f);
    counts[s.k >= 0.5 ? s.to : s.from] += 1;
    total += 1;
  }
  return { counts, total };
}

// At the end of every beat the counters show the milestone's counts from
// history/index.json, which data.ts checked against the snapshots.
for (const b of beats) {
  const { counts, total } = countsAt(b.to - 1);
  const m = milestones[b.m];
  if (total !== m.total || STATUS_ORDER.some((s) => counts[s] !== m.counts[s])) {
    throw new Error(`the cards on screen at the end of "${b.title}" do not add up to milestone ${m.seq}'s counts`);
  }
}

export function beatAt(frame: number): Beat {
  return beats.find((b) => frame >= b.from && frame < b.to) ?? beats[beats.length - 1];
}

export const lastMilestone = milestones[milestones.length - 1];
