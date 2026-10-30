import React from "react";
import { AbsoluteFill, Easing, useCurrentFrame } from "remotion";
import { type Box, layout, milestones, STATUS_ORDER, type Status, statusWords } from "./data";
import {
  APPEAR,
  BAND,
  type Beat,
  beatAt,
  beats,
  camera,
  CAPTION_IN,
  CAPTION_OUT,
  CAPTION_RISE,
  countsAt,
  DIM,
  DIM_CHANGE,
  FINAL_FROM,
  lastMilestone,
  PULSE,
  QUESTION_IN,
  QUESTION_OUT,
  STAGE_H,
  statusAt,
  type Track,
  trackList,
  WIDTH,
} from "./story";
import { CARD_W, FONT, LINE, mix, PLANE_PATH, RIM, type Theme, type ThemeName, THEMES, TINT } from "./theme";

const clamp = (x: number) => Math.min(1, Math.max(0, x));
const lerp = (a: number, b: number, k: number) => a + (b - a) * k;
const easeOut = Easing.out(Easing.cubic);
const easeInOut = Easing.inOut(Easing.cubic);
const slow = Easing.bezier(0.45, 0, 0.2, 1);

// ------------------------------------------------------------------ camera

type Cam = { s: number; tx: number; ty: number };
const PAD = 20;

function fit(b: Box): Cam {
  const aw = WIDTH - 2 * PAD;
  const ah = STAGE_H - 2 * PAD;
  const s = Math.min(aw / b.width, ah / b.height);
  return { s, tx: PAD + (aw - b.width * s) / 2 - b.x * s, ty: PAD + (ah - b.height * s) / 2 - b.y * s };
}

// Between two boxes the centre moves in a straight line and the size changes
// at a steady rate, so a pull back reads as one smooth move.
function boxAt(f: number): Box {
  const ks = camera;
  if (f <= ks[0].at) return ks[0].box;
  for (let i = 1; i < ks.length; i++) {
    if (f <= ks[i].at) {
      const a = ks[i - 1].box;
      const b = ks[i].box;
      const k = slow(clamp((f - ks[i - 1].at) / (ks[i].at - ks[i - 1].at)));
      const w = Math.exp(lerp(Math.log(a.width), Math.log(b.width), k));
      const h = Math.exp(lerp(Math.log(a.height), Math.log(b.height), k));
      const cx = lerp(a.x + a.width / 2, b.x + b.width / 2, k);
      const cy = lerp(a.y + a.height / 2, b.y + b.height / 2, k);
      return { x: cx - w / 2, y: cy - h / 2, width: w, height: h };
    }
  }
  return ks[ks.length - 1].box;
}

// ------------------------------------------------------------------ cards

function shown(t: Track, f: number) {
  return easeOut(clamp((f - t.appear) / APPEAR));
}

function focusIn(b: Beat | undefined, t: Track): number {
  if (!b?.focus) return 1;
  return (b.focus.area !== undefined && t.area[b.m] === b.focus.area) || b.focus.ids.has(t.id) ? 1 : DIM;
}

function dimOf(t: Track, f: number, b: Beat, prev: Beat | undefined): number {
  const now = focusIn(b, t);
  if (!prev || t.appear >= b.from) return now;
  return lerp(focusIn(prev, t), now, easeInOut(clamp((f - b.from) / DIM_CHANGE)));
}

const mixColor = (a: string, b: string, k: number) => (k <= 0 ? a : k >= 1 ? b : mix(b, a, k));

type Look = { s: number; rimScale: number; tintScale: number; textOpacity: number };

function lookAt(s: number): Look {
  // The site's rims are 1.5 and 2 px and its tints 7 to 12 percent.  On the
  // full canvas a card is a quarter of its size; there rims stay at least
  // about a pixel wide, tints are stronger and text is lighter, so the
  // statuses still read.  Close up, cards are drawn as the site draws them.
  const far = clamp((0.75 - s) / (0.75 - 0.28));
  return { s, rimScale: Math.max(1, 0.75 / s), tintScale: 1 + 1.3 * far, textOpacity: 1 - 0.4 * far };
}

function Card({ t, f, th, look, dim }: { t: Track; f: number; th: Theme; look: Look; dim: number }) {
  const p = shown(t, f);
  if (p <= 0) return null;
  const st = statusAt(t, f);
  const scale = 0.96 + 0.04 * p;
  const cx = t.x0 + CARD_W / 2;
  const cy = t.y0 + t.h / 2;
  const fillOf = (s: Status) => mix(th.status[s], th.surface, Math.min(1, TINT[s] * look.tintScale));
  const rimOf = (s: Status) => (s === "waiting" ? th.axis : th.status[s]);
  const fill = mixColor(fillOf(st.from), fillOf(st.to), st.k);
  const rim = mixColor(rimOf(st.from), rimOf(st.to), st.k);
  const width = lerp(RIM[st.from], RIM[st.to], st.k) * look.rimScale;
  const dashed = (st.k < 0.5 ? st.from : st.to) === "waiting";
  const dot = mixColor(th.status[st.from], th.status[st.to], st.k);
  const sy = t.y0 + 24 + LINE * t.lines.length + 4;
  const label = (s: Status) => (t.candidate ? `${t.candidate} · ` : "") + statusWords[s];
  return (
    <g opacity={p * dim} transform={`translate(${cx} ${cy}) scale(${scale}) translate(${-cx} ${-cy})`}>
      <rect
        x={t.x0}
        y={t.y0}
        width={CARD_W}
        height={t.h}
        rx={8}
        fill={fill}
        stroke={rim}
        strokeWidth={width}
        strokeDasharray={dashed ? `${5 * look.rimScale} ${4 * look.rimScale}` : undefined}
      />
      <g opacity={look.textOpacity}>
        {t.lines.map((line, i) => (
          <text key={i} x={t.x0 + 14} y={t.y0 + 24 + LINE * i} fontSize={13} fontWeight={600} fill={th.ink}>
            {line}
          </text>
        ))}
        {st.k < 1 ? (
          <>
            <text x={t.x0 + 28} y={sy} fontSize={11.5} fill={th.ink2} opacity={1 - st.k}>
              {label(st.from)}
            </text>
            <text x={t.x0 + 28} y={sy} fontSize={11.5} fill={th.ink2} opacity={st.k}>
              {label(st.to)}
            </text>
          </>
        ) : (
          <text x={t.x0 + 28} y={sy} fontSize={11.5} fill={th.ink2}>
            {label(st.to)}
          </text>
        )}
      </g>
      <circle cx={t.x0 + 18} cy={sy - 4} r={4} fill={dot} />
    </g>
  );
}

// A ring that grows out of a card's rim and fades, once.
function Pulses({ t, f, th, s }: { t: Track; f: number; th: Theme; s: number }) {
  return (
    <>
      {t.pulses.map((at, i) => {
        const q = (f - at) / PULSE;
        if (q < 0 || q > 1) return null;
        const pad = (3 + 24 * easeOut(q)) / s;
        return (
          <rect
            key={i}
            x={t.x0 - pad}
            y={t.y0 - pad}
            width={CARD_W + 2 * pad}
            height={t.h + 2 * pad}
            rx={8 + pad}
            fill="none"
            stroke={th.status.open}
            strokeWidth={(7 * (1 - q) + 1) / s}
            opacity={0.9 * (1 - q)}
          />
        );
      })}
    </>
  );
}

// ------------------------------------------------------------------ the question callout

type Rect = { x: number; y: number; w: number; h: number };
const overlap = (a: Rect, b: Rect) =>
  Math.max(0, Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x)) * Math.max(0, Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y));

const K = 1.45; // the callout's card is drawn at 1.45 times the site's size

function Callout({ t, cam, th, op, beat, f }: { t: Track; cam: Cam; th: Theme; op: number; beat: Beat; f: number }) {
  const card: Rect = { x: cam.tx + t.x0 * cam.s, y: cam.ty + t.y0 * cam.s, w: CARD_W * cam.s, h: t.h * cam.s };
  const w = CARD_W * K;
  const h = t.h * K;
  const gap = 34;
  const cx = card.x + card.w / 2;
  const cy = card.y + card.h / 2;
  const options: Rect[] = [
    { x: cx - w / 2, y: card.y - gap - h, w, h },
    { x: cx - w / 2, y: card.y + card.h + gap, w, h },
    { x: card.x + card.w + gap, y: cy - h / 2, w, h },
    { x: card.x - gap - w, y: cy - h / 2, w, h },
  ];
  // Keep it on the stage, and cover as few of the area's bright cards as can be.
  const bright: Rect[] = trackList
    .filter((o) => o.id !== t.id && f >= o.appear && focusIn(beat, o) === 1)
    .map((o) => ({ x: cam.tx + o.x0 * cam.s, y: cam.ty + o.y0 * cam.s, w: CARD_W * cam.s, h: o.h * cam.s }));
  let best = options[0];
  let bestScore = Infinity;
  for (const o of options) {
    const fits = o.x >= 12 && o.y >= 12 && o.x + o.w <= WIDTH - 12 && o.y + o.h <= STAGE_H - 12;
    const score = (fits ? 0 : 1e9) + bright.reduce((sum, b) => sum + overlap(o, b), 0);
    if (score < bestScore) {
      best = o;
      bestScore = score;
    }
  }
  // A line from the callout to the card.
  const bx = Math.min(Math.max(cx, best.x + 16), best.x + best.w - 16);
  const by = Math.min(Math.max(cy, best.y + 12), best.y + best.h - 12);
  const from = best.y + best.h <= card.y ? { x: bx, y: best.y + best.h } : best.y >= card.y + card.h ? { x: bx, y: best.y } : best.x >= card.x + card.w ? { x: best.x, y: by } : { x: best.x + best.w, y: by };
  const to = {
    x: Math.min(Math.max(from.x, card.x - 6), card.x + card.w + 6),
    y: Math.min(Math.max(from.y, card.y - 6), card.y + card.h + 6),
  };
  const red = th.status.open;
  const sy = 24 + LINE * t.lines.length + 4;
  return (
    <g opacity={op}>
      <line x1={from.x} y1={from.y} x2={to.x} y2={to.y} stroke={red} strokeWidth={2} />
      <g transform={`translate(${best.x} ${best.y}) scale(${K})`} filter="url(#lift)">
        <rect x={0} y={0} width={CARD_W} height={t.h} rx={8} fill={mix(red, th.surface, TINT.open)} stroke={red} strokeWidth={RIM.open} />
        {t.lines.map((line, i) => (
          <text key={i} x={14} y={24 + LINE * i} fontSize={13} fontWeight={600} fill={th.ink}>
            {line}
          </text>
        ))}
        <circle cx={18} cy={sy - 4} r={4} fill={red} />
        <text x={28} y={sy} fontSize={11.5} fill={th.ink2}>
          {(t.candidate ? `${t.candidate} · ` : "") + statusWords.open}
        </text>
      </g>
    </g>
  );
}

// A steady ring on the card a caption is about.
function Ring({ t, cam, th, op }: { t: Track; cam: Cam; th: Theme; op: number }) {
  const pad = 6 / cam.s;
  return (
    <rect
      x={t.x0 - pad}
      y={t.y0 - pad}
      width={CARD_W + 2 * pad}
      height={t.h + 2 * pad}
      rx={8 + pad}
      fill="none"
      stroke={th.status.open}
      strokeWidth={3 / cam.s}
      opacity={op}
    />
  );
}

// ------------------------------------------------------------------ the band

function fade(f: number, from: number, to: number, fadeIn = 8, fadeOut = 6) {
  return clamp((f - from) / fadeIn) * clamp((to - f) / fadeOut);
}

function Plane({ color, size }: { color: string; size: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" style={{ flex: "none" }}>
      <path transform="rotate(-30 12 12)" fill={color} d={PLANE_PATH} />
    </svg>
  );
}

function Dot({ color, size }: { color: string; size: number }) {
  return <span style={{ width: size, height: size, borderRadius: "50%", background: color, display: "inline-block", flex: "none" }} />;
}

function Kicker({ beat, f, th }: { beat: Beat; f: number; th: Theme }) {
  const m = milestones[beat.m];
  const op = fade(f, beat.from, beat.final ? Infinity : beat.to, beat.from === 0 ? 12 : 6, 4);
  return (
    <div style={{ position: "absolute", left: 56, top: 24, height: 30, display: "flex", alignItems: "center", gap: 14, fontSize: 20 }}>
      <Plane color={th.ink} size={24} />
      <span style={{ fontWeight: 650, color: th.ink }}>Airline Order</span>
      <span style={{ width: 1, height: 22, background: th.hair, margin: "0 6px" }} />
      <span style={{ opacity: op, display: "flex", gap: 12 }}>
        <span style={{ color: th.ink2, fontVariantNumeric: "tabular-nums" }}>
          Milestone {m.seq} of {milestones.length}
        </span>
        <span style={{ color: th.ink, fontWeight: 600 }}>{beat.title}</span>
      </span>
    </div>
  );
}

function Captions({ beat, f, th, width }: { beat: Beat; f: number; th: Theme; width: number }) {
  return (
    <>
      {beat.captions.map((c, i) => {
        const op = fade(f, c.from, c.to, CAPTION_IN, CAPTION_OUT);
        if (op <= 0) return null;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: 56,
              top: beat.final ? 118 : 70,
              width,
              fontSize: beat.final ? 28 : 31,
              lineHeight: 1.3,
              textWrap: "balance",
              color: th.ink,
              opacity: op,
              transform: `translateY(${(1 - easeOut(clamp((f - c.from) / CAPTION_RISE))) * 10}px)`,
            }}
          >
            {c.chip ? (
              <span
                style={{
                  display: "inline-flex",
                  alignItems: "center",
                  gap: 9,
                  fontSize: 21,
                  fontWeight: 600,
                  padding: "3px 13px 3px 11px",
                  borderRadius: 999,
                  background: mix(th.status.open, th.page, 0.13),
                  color: th.ink,
                  marginRight: 14,
                  verticalAlign: "4px",
                }}
              >
                <Dot color={th.status.open} size={12} />
                {c.chip}
              </span>
            ) : null}
            {c.text}
          </div>
        );
      })}
    </>
  );
}

function Counters({ f, th, beat, op }: { f: number; th: Theme; beat: Beat; op: number }) {
  const { counts, total } = countsAt(f);
  const prev = beat.m > 0 ? milestones[beat.m - 1].counts : undefined;
  const cols = [STATUS_ORDER.slice(0, 3), STATUS_ORDER.slice(3)];
  return (
    <div style={{ position: "absolute", left: 1290, top: 24, width: 590, opacity: op }}>
      <div style={{ fontSize: 20, color: th.ink2, height: 30, display: "flex", alignItems: "center", fontVariantNumeric: "tabular-nums" }}>
        {total} cards
      </div>
      <div style={{ display: "flex", gap: 24, marginTop: 8 }}>
        {cols.map((col, ci) => (
          <div key={ci} style={{ display: "flex", flexDirection: "column", gap: 4, width: 283 }}>
            {col.map((s) => {
              const delta = prev ? counts[s] - prev[s] : 0;
              return (
                <div key={s} style={{ display: "flex", alignItems: "center", height: 30, fontSize: 18, color: th.ink2, whiteSpace: "nowrap" }}>
                  <Dot color={th.status[s]} size={12} />
                  <span style={{ marginLeft: 10, flex: 1 }}>{statusWords[s]}</span>
                  <span style={{ fontSize: 24, fontWeight: 650, color: th.ink, fontVariantNumeric: "tabular-nums", width: 52, textAlign: "right" }}>
                    {counts[s]}
                  </span>
                  <span style={{ fontSize: 16, width: 48, textAlign: "right", fontVariantNumeric: "tabular-nums", opacity: delta ? 1 : 0 }}>
                    {delta > 0 ? `+${delta}` : `\u2212${-delta}`}
                  </span>
                </div>
              );
            })}
          </div>
        ))}
      </div>
    </div>
  );
}

// The closing count: three numbers count up from zero.
function FinalCount({ f, th }: { f: number; th: Theme }) {
  const stats: { s: Status; label: string }[] = [
    { s: "proven", label: statusWords.proven },
    { s: "open", label: "Open questions" },
    { s: "decision", label: "Still need a decision" },
  ];
  return (
    <div style={{ position: "absolute", left: 56, top: 64, display: "flex", gap: 64, alignItems: "baseline" }}>
      {stats.map(({ s, label }, i) => {
        const start = FINAL_FROM + 12 + i * 8;
        const k = easeOut(clamp((f - start) / 54));
        const op = clamp((f - start) / 8);
        return (
          <div key={s} style={{ display: "flex", alignItems: "center", gap: 14, opacity: op }}>
            <Dot color={th.status[s]} size={16} />
            <span style={{ fontSize: 46, fontWeight: 700, color: th.ink, fontVariantNumeric: "tabular-nums", lineHeight: 1 }}>
              {Math.round(lastMilestone.counts[s] * k)}
            </span>
            <span style={{ fontSize: 24, color: th.ink2 }}>{label}</span>
          </div>
        );
      })}
    </div>
  );
}

// ------------------------------------------------------------------ the frame

export type HistoryProps = { theme: ThemeName; at?: number };

export const History: React.FC<HistoryProps> = ({ theme, at }) => {
  const current = useCurrentFrame();
  const f = at ?? current;
  const th = THEMES[theme];
  const cam = fit(boxAt(f));
  const look = lookAt(cam.s);
  const beat = beatAt(f);
  const prevBeat = beats[beats.indexOf(beat) - 1];
  const byId = new Map(trackList.map((t) => [t.id, t]));
  const dims = new Map(trackList.map((t) => [t.id, dimOf(t, f, beat, prevBeat)]));
  const edgeWidth = Math.max(1.25, 0.7 / cam.s);
  const q = beat.question;
  const qTrack = q ? byId.get(q.id) : undefined;
  const qOp = q ? fade(f, q.from, q.to, QUESTION_IN, QUESTION_OUT) : 0;
  const countersOp = beat.final ? 1 - clamp((f - beat.from) / 10) : 1;
  return (
    <AbsoluteFill style={{ background: th.surface, fontFamily: FONT }}>
      <svg width={WIDTH} height={STAGE_H} style={{ position: "absolute", left: 0, top: BAND }} fontFamily={FONT}>
        <defs>
          <marker id="arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
            <path d="M0 0L10 5L0 10z" fill={th.axis} />
          </marker>
          <filter id="lift" x="-20%" y="-20%" width="140%" height="160%">
            <feDropShadow dx="0" dy="6" stdDeviation="9" floodColor="#000" floodOpacity={theme === "dark" ? 0.5 : 0.16} />
          </filter>
        </defs>
        <g transform={`translate(${cam.tx} ${cam.ty}) scale(${cam.s})`}>
          <g fill="none" stroke={th.axis} strokeWidth={edgeWidth}>
            {layout.edges.map((e, i) => {
              const a = byId.get(e.from);
              const b = byId.get(e.to);
              if (!a || !b) return null;
              const op = Math.min(shown(a, f), shown(b, f)) * dims.get(b.id)!;
              if (op <= 0) return null;
              return <path key={i} d={e.path} opacity={op} markerEnd="url(#arrow)" />;
            })}
          </g>
          {trackList.map((t) => (
            <Card key={t.id} t={t} f={f} th={th} look={look} dim={dims.get(t.id)!} />
          ))}
          {qTrack && qOp > 0 ? <Ring t={qTrack} cam={cam} th={th} op={qOp} /> : null}
          {trackList.map((t) => (t.pulses.length ? <Pulses key={t.id} t={t} f={f} th={th} s={cam.s} /> : null))}
        </g>
        {qTrack && q?.callout && qOp > 0 ? <Callout t={qTrack} cam={cam} th={th} op={qOp} beat={beat} f={f} /> : null}
      </svg>
      <div style={{ position: "absolute", left: 0, top: 0, width: WIDTH, height: BAND, background: th.page, borderBottom: `1px solid ${th.hair}` }} />
      <Kicker beat={beat} f={f} th={th} />
      <Captions beat={beat} f={f} th={th} width={beat.final ? 1800 : 1210} />
      {countersOp > 0 ? <Counters f={f} th={th} beat={beat} op={countersOp} /> : null}
      {beat.final ? <FinalCount f={f} th={th} /> : null}
    </AbsoluteFill>
  );
};
