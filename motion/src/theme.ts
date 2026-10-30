// The site's colors and card shapes, as scripts/render_graph.py and
// scripts/graph_history.py draw them.  Change them there and here together.

import type { Status } from "./data";

export type ThemeName = "light" | "dark";

export type Theme = {
  page: string;
  surface: string;
  ink: string;
  ink2: string;
  muted: string;
  hair: string;
  axis: string;
  status: Record<Status, string>;
};

const STATUS_LIGHT: Record<Status, string> = {
  modelled: "#e87ba4",
  proven: "#0ca30c",
  open: "#d03b3b",
  decision: "#fab219",
  ready: "#2a78d6",
  waiting: "#898781",
};

export const THEMES: Record<ThemeName, Theme> = {
  light: {
    page: "#f9f9f7",
    surface: "#fcfcfb",
    ink: "#0b0b0b",
    ink2: "#52514e",
    muted: "#898781",
    hair: "#e1e0d9",
    axis: "#b9b8b0",
    status: STATUS_LIGHT,
  },
  dark: {
    page: "#0d0d0d",
    surface: "#1a1a19",
    ink: "#f0efec",
    ink2: "#c3c2b7",
    muted: "#898781",
    hair: "#2c2c2a",
    axis: "#55544f",
    status: { ...STATUS_LIGHT, ready: "#3987e5" },
  },
};

// The share of the status color mixed into a card's fill, and the rim width.
export const TINT: Record<Status, number> = {
  modelled: 0.07,
  proven: 0.08,
  open: 0.1,
  decision: 0.12,
  ready: 0.1,
  waiting: 0,
};
export const RIM: Record<Status, number> = {
  modelled: 1.5,
  proven: 1.5,
  open: 2,
  decision: 2,
  ready: 2,
  waiting: 1.25,
};

export const CARD_W = 184;
export const LINE = 17;
export const FONT = 'system-ui, -apple-system, "Segoe UI", sans-serif';

// The site's mark: a plane taking off (PLANE_PATH in scripts/site_nav.py).
export const PLANE_PATH =
  "M21.6 12c0-.85-.7-1.45-1.55-1.45H14.3L9.4 3.2H7.6l2.35 7.35H5.5L3.75 8.1H2.4l1.05 3.9-1.05 3.9h1.35l1.75-2.45h4.45L7.6 20.8h1.8l4.9-7.35h5.75c.85 0 1.55-.6 1.55-1.45z";

const rgb = (hex: string) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));

// color-mix(in srgb, color share, base), as the site's stylesheet does.
export function mix(color: string, base: string, share: number): string {
  const a = rgb(color);
  const b = rgb(base);
  return "#" + a.map((x, i) => Math.round(x * share + b[i] * (1 - share)).toString(16).padStart(2, "0")).join("");
}
