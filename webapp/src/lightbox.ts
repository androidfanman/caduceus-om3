/** The colour chart "light box" (owner 2026-11-09): a drawn test chart whose light and camera white balance can be
 *  changed, so a film can be judged in sun, shade, cloud, lamp light and at different Kelvin settings.
 *
 *  It is a simple model, not a measurement: each patch has an RGB reflectance, the light has a colour (from its colour
 *  temperature, a green / magenta tint and how well it shows colours), and the camera's white balance divides by the
 *  colour of the light it is set for. Everything is our own drawing: no photo and no maker's chart is used. */

export type Source = 'sun' | 'shade' | 'cloudy' | 'tungsten' | 'street' | 'fluor' | 'led';
/** The camera's WB modes with their Kelvin, as the OM-3's menu lists them (values confirmed by the owner 2026-11-09); 'custom' is CWB (2000 to 14000 K). */
export type WbMode = 'auto' | 'sunny' | 'shadow' | 'cloudy' | 'incand' | 'fluor' | 'flash' | 'custom';

export interface ChartLight {
  source: Source;
  /** Time of day for the sun, minutes after midnight, 360..1080 (6:00 to 18:00; noon = 720) (source 'sun'). */
  time: number;
  /** Part of the chart in shadow, 0..100 % (source 'sun'). */
  shadow: number;
  /** Brightness in thirds of a stop, -9..9 (-3 to +3 EV). */
  ev: number;
  wb: WbMode;
  /** CWB Kelvin, 2000..14000 (wb 'custom'). */
  kelvin: number;
}

export const CHART_DEFAULT: ChartLight = { source: 'sun', time: 720, shadow: 0, ev: 0, wb: 'auto', kelvin: 5300 };

interface SourceDef { label: string; k: number; tint: number; cri: number; spot: number }
/** k = colour temperature, tint = green (+) / magenta (-), cri = how fully colours show (1 = all, 0 = none: everything
 *  the lamp's own colour), spot = how much the light falls off away from its centre (a lamp close by). */
export const SOURCES: Record<Source, SourceDef> = {
  sun: { label: 'Sun', k: 5500, tint: 0, cri: 1, spot: 0 },
  shade: { label: 'Open shade', k: 7500, tint: 0, cri: 1, spot: 0 },
  cloudy: { label: 'Cloudy', k: 6500, tint: 0, cri: 1, spot: 0 },
  tungsten: { label: 'Tungsten bulb', k: 2850, tint: 0, cri: 1, spot: 0.35 },
  street: { label: 'Street lamp (sodium)', k: 2050, tint: -0.09, cri: 0.22, spot: 0.5 },
  fluor: { label: 'Fluorescent tube', k: 4100, tint: 0.12, cri: 0.8, spot: 0 },
  led: { label: 'LED (neutral white)', k: 4000, tint: 0.02, cri: 0.92, spot: 0.15 },
};
export const SOURCE_ORDER: Source[] = ['sun', 'shade', 'cloudy', 'tungsten', 'street', 'fluor', 'led'];

export const WB_MODES: Record<WbMode, { label: string; k: number; tint: number }> = {
  auto: { label: 'Auto', k: 0, tint: 0 },
  sunny: { label: 'Sunny 5300K', k: 5300, tint: 0 },
  shadow: { label: 'Shadow 7500K', k: 7500, tint: 0 },
  cloudy: { label: 'Cloudy 6000K', k: 6000, tint: 0 },
  incand: { label: 'Incandescent 3000K', k: 3000, tint: 0 },
  fluor: { label: 'Fluorescent 4000K', k: 4000, tint: 0.08 },
  flash: { label: 'WB Flash 5500K', k: 5500, tint: 0 },
  custom: { label: 'Custom Kelvin (CWB)', k: 0, tint: 0 },
};
export const WB_ORDER: WbMode[] = ['auto', 'sunny', 'shadow', 'cloudy', 'incand', 'fluor', 'flash', 'custom'];
/** Auto WB follows the light only inside this range (a sodium street lamp stays orange, as on a camera). */
const AUTO_MIN = 2600, AUTO_MAX = 9500;

/** Sunlight's colour temperature by the sun's height: about 2400 K at the horizon, 5500 K high up. */
export const sunKelvin = (deg: number) => Math.round((2300 + 3250 * (1 - Math.exp(-Math.max(0, deg) / 16))) / 50) * 50;
/** The sun's height (degrees) at a time of day: an even 12-hour day, rising at 6:00, highest (70 degrees) at noon,
 *  setting at 18:00; never below 1 degree so there is still light at the ends. */
export const SUN_RISE = 360, SUN_SET = 1080, SUN_PEAK = 70;
export const sunHeight = (time: number) => Math.max(1, SUN_PEAK * Math.sin((Math.PI * (Math.max(SUN_RISE, Math.min(SUN_SET, time)) - SUN_RISE)) / (SUN_SET - SUN_RISE)));
/** The light's colour temperature (K). */
export const lightKelvin = (p: ChartLight) => (p.source === 'sun' ? sunKelvin(sunHeight(p.time)) : SOURCES[p.source].k);
/** The Kelvin the camera's white balance is set for. */
export function wbKelvin(p: ChartLight): number {
  if (p.wb === 'custom') return Math.max(2000, Math.min(14000, p.kelvin));
  if (p.wb === 'auto') return Math.max(AUTO_MIN, Math.min(AUTO_MAX, lightKelvin(p)));
  return WB_MODES[p.wb].k;
}

type RGB = [number, number, number];
const LUM = (c: RGB) => 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];

/** Linear sRGB colour of a black body at T kelvin (Kim et al.'s fit of the Planckian locus), before normalising. */
function planck(T: number): RGB {
  const t = Math.max(1667, Math.min(25000, T));
  const x = t <= 4000
    ? -0.2661239e9 / t ** 3 - 0.2343589e6 / t ** 2 + 0.8776956e3 / t + 0.17991
    : -3.0258469e9 / t ** 3 + 2.1070379e6 / t ** 2 + 0.2226347e3 / t + 0.24039;
  const y = t <= 2222 ? -1.1063814 * x ** 3 - 1.3481102 * x ** 2 + 2.18555832 * x - 0.20219683
    : t <= 4000 ? -0.9549476 * x ** 3 - 1.37418593 * x ** 2 + 2.09137015 * x - 0.16748867
      : 3.081758 * x ** 3 - 5.8733867 * x ** 2 + 3.75112997 * x - 0.37001483;
  const X = x / y, Z = (1 - x - y) / y;
  return [3.2406 * X - 1.5372 - 0.4986 * Z, -0.9689 * X + 1.8758 + 0.0415 * Z, 0.0557 * X - 0.204 + 1.057 * Z];
}
const P65 = planck(6504);
/** The colour of light of T kelvin with a green / magenta tint, as linear sRGB with luminance 1 (6500 K = white). */
export function lightColor(T: number, tint = 0): RGB {
  const p = planck(T);
  const c: RGB = [Math.max(0.02, p[0] / P65[0]), Math.max(0.02, (p[1] / P65[1]) * (1 + tint)), Math.max(0.02, p[2] / P65[2])];
  const l = LUM(c);
  return [c[0] / l, c[1] / l, c[2] / l];
}

const dec = (v: number) => (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4);
function hsv(hDeg: number, s: number, v: number): RGB {
  const f = (n: number) => { const k = (n + hDeg / 60) % 6; return v - v * s * Math.max(0, Math.min(k, 4 - k, 1)); };
  return [f(5), f(3), f(1)];
}
const hex = (s: string): RGB => [parseInt(s.slice(1, 3), 16) / 255, parseInt(s.slice(3, 5), 16) / 255, parseInt(s.slice(5, 7), 16) / 255];

/** The chart, upright (owner 2026-11-09: "fewer colours, smaller ... vertical"): 3 columns x 6 rows, 18 patches (sRGB
 *  as drawn in neutral light). Left, a wider column of six greys, white at the top to black; middle, six strong
 *  colours from the wheel (red, yellow, green, cyan, blue, magenta); right, three skin tones, then sky, leaves and
 *  brick. Our own layout and colours. */
export const CHART_COLS = 3, CHART_ROWS = 6;
/** Column widths in units of the row height (the greys are wider), and the layout as fractions of the picture's
 *  width: table margin, card padding. */
const COL_W = [1.4, 1, 1], COL_X = [0, 1.4, 2.4], COLS_W = 3.4;
const CHART_MARGIN = 0.06, CHART_PAD = 0.04, CHART_CELL = (1 - 2 * CHART_MARGIN - 2 * CHART_PAD) / COLS_W;
/** The picture's shape: height / width. */
export const CHART_ASPECT = 2 * CHART_MARGIN + 2 * CHART_PAD + CHART_ROWS * CHART_CELL;
/** The middle of patch (col, row) as fractions of the picture's width and height. */
export const patchCentre = (col: number, row: number): [number, number] =>
  [CHART_MARGIN + CHART_PAD + CHART_CELL * (COL_X[col] + COL_W[col] / 2), (CHART_MARGIN + CHART_PAD + CHART_CELL * (row + 0.5)) / CHART_ASPECT];
const SOFT = ['#f3d2bd', '#c99472', '#7d5236', '#6f9ccb', '#4c7a3d', '#a8553f'];   // skin light / medium / dark, sky, leaves, brick
function patchSrgb(): RGB[] {
  const out: RGB[] = [];
  for (let r = 0; r < CHART_ROWS; r++) {
    const L = 96 - (96 - 8) * (r / 5), y = L > 8 ? ((L + 16) / 116) ** 3 : L / 903.3, e = y <= 0.0031308 ? 12.92 * y : 1.055 * y ** (1 / 2.4) - 0.055;
    out.push([e, e, e], hsv(r * 60, 0.8, 0.86), hex(SOFT[r]));
  }
  return out;
}
/** Patch reflectances (linear), kept inside what real paint can do. */
const PATCHES: RGB[] = patchSrgb().map((c) => c.map((v) => Math.max(0.006, Math.min(0.92, dec(v)))) as RGB);
const CARD: RGB = [0.035, 0.035, 0.035], TABLE: RGB = [0.16, 0.16, 0.16];

/** Soft highlight clip, then the sRGB curve, as a table over linear 0..4. */
const TONE_N = 4096, TONE_MAX = 4;
const TONE = (() => {
  const t = new Uint8ClampedArray(TONE_N + 1);
  for (let i = 0; i <= TONE_N; i++) {
    let x = (i / TONE_N) * TONE_MAX;
    if (x > 0.8) x = 0.8 + 0.2 * (1 - Math.exp(-(x - 0.8) / 0.2));
    t[i] = Math.round(255 * (x <= 0.0031308 ? 12.92 * x : 1.055 * x ** (1 / 2.4) - 0.055));
  }
  return t;
})();

export interface ChartImage { width: number; height: number; data: Uint8ClampedArray }

/** One surface's two colours (lit by the main light, lit by the shade's skylight) after the camera's white balance. */
function shade2(refl: RGB, cri: number, main: RGB, sky: RGB, gain: RGB): [RGB, RGB] {
  const l = LUM(refl);
  const r: RGB = [l + (refl[0] - l) * cri, l + (refl[1] - l) * cri, l + (refl[2] - l) * cri];
  return [[r[0] * main[0] * gain[0], r[1] * main[1] * gain[1], r[2] * main[2] * gain[2]],
    [refl[0] * sky[0] * gain[0], refl[1] * sky[1] * gain[1], refl[2] * sky[2] * gain[2]]];
}

/** Draw the chart, `width` px wide (CHART_ASPECT gives its height), in the given light as the camera would record it (before any film). */
export function renderChart(p: ChartLight, width: number): ChartImage {
  const W = Math.max(48, Math.round(width)), H = Math.round(W * CHART_ASPECT);
  const src = SOURCES[p.source];
  const main = lightColor(lightKelvin(p), src.tint);
  // the shade inside a sunny scene: blue skylight, about two stops down
  const SKY_LEVEL = 0.24, sky = lightColor(9000).map((v) => v * SKY_LEVEL) as RGB;
  const wbTint = p.wb === 'auto' ? src.tint : WB_MODES[p.wb].tint;
  const wbc = lightColor(wbKelvin(p), wbTint), gain: RGB = [1 / wbc[0], 1 / wbc[1], 1 / wbc[2]];
  const expo = 2 ** (Math.max(-9, Math.min(9, p.ev)) / 3);
  const shadow = p.source === 'sun' ? Math.max(0, Math.min(100, p.shadow)) / 100 : 0, pm = p.time > 720;

  const surf = [shade2(TABLE, src.cri, main, sky, gain), shade2(CARD, src.cri, main, sky, gain), ...PATCHES.map((c) => shade2(c, src.cri, main, sky, gain))];
  // layout (fractions of the width): the card inside the table, the patches inside the card
  const cx0 = CHART_MARGIN * W, cy0 = cx0, cx1 = W - cx0, cy1 = H - cy0;
  const pad = CHART_PAD * W, gx = CHART_CELL * W, gy = gx, gap = 0.1;
  const data = new Uint8ClampedArray(W * H * 4);
  // the shadow's edge: a soft diagonal line that moves across the chart as the shadow grows
  const soft = 0.035, edge = shadow <= 0 ? -1 : shadow >= 1 ? 3 : shadow * (1.3 + 2 * soft) - soft;
  for (let y = 0; y < H; y++) {
    const v = y / H, inY = y >= cy0 && y < cy1, fy = (y - cy0 - pad) / gy, row = Math.floor(fy), ry = fy - row;
    for (let x = 0; x < W; x++) {
      const u = x / W;
      let s = 0;
      if (x >= cx0 && x < cx1 && inY) {
        s = 1;
        const fx = (x - cx0 - pad) / gx, col = fx < 0 ? -1 : fx < COL_X[1] ? 0 : fx < COL_X[2] ? 1 : fx < COLS_W ? 2 : -1;
        const dx = col < 0 ? 0 : fx - COL_X[col];   // distance into the patch's column, in row heights (same gap all round)
        if (row >= 0 && row < CHART_ROWS && col >= 0 && dx > gap / 2 && dx < COL_W[col] - gap / 2 && ry > gap / 2 && ry < 1 - gap / 2) s = 2 + row * CHART_COLS + col;
      }
      // how much of this pixel is in shadow (0 lit .. 1 shaded): the shadow comes in from the right in the morning
      // and at noon, from the left in the afternoon (the sun has moved across)
      let w = 0;
      if (edge >= 0) { const d = (pm ? u : 1 - u) + 0.3 * v; w = d < edge - soft ? 1 : d > edge + soft ? 0 : 0.5 - (d - edge) / (2 * soft); }
      // a lamp close by: brightest a little above the centre, falling off outward
      let f = expo;
      if (src.spot) { const dx = u - 0.5, dy = (v - 0.42) * (H / W); f *= 1 + src.spot * 0.25 - src.spot * 2.6 * (dx * dx + dy * dy); }
      const [a, b] = surf[s], o = (y * W + x) * 4;
      for (let c = 0; c < 3; c++) {
        const lin = (a[c] * (1 - w) + b[c] * w) * f;
        data[o + c] = TONE[lin <= 0 ? 0 : lin >= TONE_MAX ? TONE_N : Math.round((lin / TONE_MAX) * TONE_N)];
      }
      data[o + 3] = 255;
    }
  }
  return { width: W, height: H, data };
}

/** Clean a stored setting: anything missing or out of range falls back to the default. */
export function chartLight(j: unknown): ChartLight {
  const o = (j && typeof j === 'object' ? j : {}) as Record<string, unknown>;
  const num = (v: unknown, lo: number, hi: number, d: number) => (typeof v === 'number' && Number.isFinite(v) ? Math.max(lo, Math.min(hi, Math.round(v))) : d);
  return {
    source: SOURCE_ORDER.includes(o.source as Source) ? (o.source as Source) : CHART_DEFAULT.source,
    time: Math.round(num(o.time, SUN_RISE, SUN_SET, CHART_DEFAULT.time) / 15) * 15, shadow: num(o.shadow, 0, 100, 0), ev: num(o.ev, -9, 9, 0),
    wb: WB_ORDER.includes(o.wb as WbMode) ? (o.wb as WbMode) : CHART_DEFAULT.wb,
    kelvin: Math.round(num(o.kelvin, 2000, 14000, CHART_DEFAULT.kelvin) / 100) * 100,
  };
}
