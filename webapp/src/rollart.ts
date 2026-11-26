// Film Rolls (test firmware): a film's canister, as the camera draws it on Picture Mode's film selection row.
// A line-for-line port of firmware/mkrollpath.py (feature/film-rolls-card): the same shapes, letters (DejaVu Sans
// Condensed Bold outlines, src/data/rollglyphs.json from scripts/rollglyphs.py) and curve flattening, so a canister
// drawn here is the one OM3MOD/FILMROLL/ROLLART.BIN carries to the camera. Coordinates: a 256 x 256 surface, y up
// (OpenVG); the camera gets them in quarter pixels (S_16, scale 0.25) and fills each colour group even-odd, in order.
import glyphJson from './data/rollglyphs.json';

type Pt = [number, number];
type Poly = Pt[];
/** One colour group: RGBA (0xRRGGBBAA) and its closed polygons. */
export type Group = [number, Poly[]];

const G = glyphJson as unknown as { upm: number; glyphs: Record<string, { adv: number; c: [number, number, number][][] }> };

const VB_W = 110, VB_H = 200, S = 1.1;                // the mock-up's roll in the 256 surface
const X0 = (256 - VB_W * S) / 2, Y0 = (256 - VB_H * S) / 2;
const pt = (x: number, y: number): Pt => [X0 + x * S, 256 - (Y0 + y * S)];   // viewBox (y down) -> surface (y up)
const RAD = Math.PI / 180;                            // as CPython's math.radians (x * (pi / 180))

function rrect(x: number, y: number, w: number, h: number, r = 0, n = 4): Poly {
  if (r <= 0) return [pt(x, y), pt(x + w, y), pt(x + w, y + h), pt(x, y + h)];
  const out: Poly = [];
  for (const [cx, cy, a0] of [[x + w - r, y + r, -90], [x + w - r, y + h - r, 0], [x + r, y + h - r, 90], [x + r, y + r, 180]]) {
    for (let k = 0; k <= n; k++) {
      const a = (a0 + (90 * k) / n) * RAD;
      out.push(pt(cx + r * Math.cos(a), cy + r * Math.sin(a)));
    }
  }
  return out;
}
const circle = (cx: number, cy: number, r: number, n = 28): Poly =>
  Array.from({ length: n }, (_, k) => pt(cx + r * Math.cos((2 * Math.PI * k) / n), cy + r * Math.sin((2 * Math.PI * k) / n)));

/** A glyph's closed contours (font units, y up), its quadratic curves flattened in `steps` (mkrollpath TTF.contours). */
function contours(ch: string, steps: number): Pt[][] {
  const g = G.glyphs[ch] ?? G.glyphs['?'];
  const out: Pt[][] = [];
  for (const raw of g.c) {
    let pts = raw.map(([x, y, on]) => [x, y, on] as [number, number, number]);
    if (!pts.some((p) => p[2])) pts.unshift([(pts[0][0] + pts[pts.length - 1][0]) / 2, (pts[0][1] + pts[pts.length - 1][1]) / 2, 1]);
    const k0 = pts.findIndex((p) => p[2]); pts = [...pts.slice(k0), ...pts.slice(0, k0)];
    const m = pts.length, poly: Pt[] = [[pts[0][0], pts[0][1]]];
    let cur = pts[0], j = 1;
    while (j <= m) {
      const p = pts[j % m];
      if (p[2]) { poly.push([p[0], p[1]]); cur = p; j += 1; continue; }
      const n = pts[(j + 1) % m];
      const end: [number, number, number] = n[2] ? n : [(p[0] + n[0]) / 2, (p[1] + n[1]) / 2, 1];
      for (let s = 1; s <= steps; s++) {
        const t = s / steps;
        poly.push([(1 - t) ** 2 * cur[0] + 2 * (1 - t) * t * p[0] + t * t * end[0], (1 - t) ** 2 * cur[1] + 2 * (1 - t) * t * p[1] + t * t * end[1]]);
      }
      cur = end; j += n[2] ? 2 : 1;
    }
    const a = poly[0], z = poly[poly.length - 1];
    out.push(a[0] === z[0] && a[1] === z[1] ? poly.slice(0, -1) : poly);
  }
  return out;
}
const adv = (ch: string) => (G.glyphs[ch] ?? G.glyphs['?']).adv;

/** Polygons of the string s, centred on cx, baseline at base (viewBox units, y down), cap height cap. */
function text(s: string, cx: number, base: number, cap: number, maxw?: number, steps = 4): Poly[] {
  let k = cap / (0.729 * G.upm);                      // DejaVu's cap height is 0.729 em
  let w = [...s].reduce((a, ch) => a + adv(ch), 0) * k;
  if (maxw && w > maxw) { k *= maxw / w; w = maxw; }
  let x = cx - w / 2;
  const polys: Poly[] = [];
  for (const ch of s) {
    for (const c of contours(ch, steps)) polys.push(c.map(([px, py]) => pt(x + px * k, base - py * k)));
    x += adv(ch) * k;
  }
  return polys;
}

export type Rgb = [number, number, number];
const rgba = (c: Rgb) => ((c[0] << 24) | (c[1] << 16) | (c[2] << 8) | 0xff) >>> 0;
const lum = (c: Rgb) => 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2];

/** The parts every roll shares, drawn first (the card file's own): the leader, its holes, the caps. */
export function base(): Group[] {
  const holes: Poly[] = [];
  for (let y = 50; y < 146; y += 14) holes.push(rrect(95, y, 6, 7));
  return [
    [rgba([0x5a, 0x46, 0x30]), [rrect(88, 42, 18, 108)]],
    [rgba([0x0b, 0x0b, 0x0b]), holes],
    [rgba([0x3c, 0x3c, 0x3c]), [rrect(8, 10, 90, 16, 5), rrect(8, 176, 90, 16, 5)]],
  ];
}

/** One film's own parts, drawn after base(): the body, the badge, the ISO in the body's colour, then the label's ink
 *  (the name, the line, "36 exp"): dark on light films, light on dark ones. exp null: no length (no roll loaded).
 *  labelled: the rear dial's label above the roll, as on the film selection row. */
export function film(name: string, iso: number | string, exp: number | null, body: Rgb, labelled = false): Group[] {
  const ink: Rgb = lum(body) > 90 ? [0x14, 0x12, 0x10] : [0xf0, 0xec, 0xe4];
  const n = [...name].length, is = String(iso);
  return [
    [rgba(body), [rrect(12, 26, 82, 150)]],
    [rgba([0x14, 0x12, 0x10]), [circle(53, 60, 21)]],
    [rgba(body), text(is, 53, 67, is.length < 4 ? 14 : 11, 34)],
    [rgba(ink), [...text(name, 53, 120, n <= 7 ? 17 : 14, 74), rrect(12, 134, 82, 4), ...(exp ? text(`${exp} exp`, 53, 163, 12, 60) : [])]],
    ...(labelled ? label(exp) : []),
  ];
}

/** Above the roll: what the rear dial sets, and its value ("36 exposures"; none: "No roll"). */
export function label(exp: number | null): Group[] {
  return [[rgba([0xb2, 0xb2, 0xb2]), text('Rear dial', 55, -30, 9, 190, 2)],
    [rgba([0xf2, 0xf2, 0xf2]), text(exp ? `${exp} exposures` : 'No roll', 55, -8, 14, 190, 2)]];
}

/** Python's round(): halves to even (mkrollpath's quarter pixels). */
export function roundEven(v: number): number {
  const f = Math.floor(v), d = v - f;
  return d > 0.5 ? f + 1 : d < 0.5 ? f : f % 2 === 0 ? f : f + 1;
}
const q4 = (v: number) => Math.max(-32768, Math.min(32767, roundEven(v * 4)));

/** One ROLLART.BIN record (mkrollpath pack): u32 groups, each {u32 segments, u32 their offset, u32 the coordinates'
 *  offset, u32 RGBA}, then per group the coordinates (S_16 quarter pixels) and the segments (bytes), 4-aligned. */
export function pack(groups: Group[]): Uint8Array {
  const MOVE = 2, LINE = 4, CLOSE = 0;
  const recs = groups.map(([c, polys]) => {
    const segs: number[] = [], data: number[] = [];
    for (const p of polys) { segs.push(MOVE); data.push(...p[0]); for (const q of p.slice(1)) { segs.push(LINE); data.push(...q); } segs.push(CLOSE); }
    return { c, segs, data };
  });
  const blobs: Uint8Array[] = [], idx: number[][] = [];
  let at = 4 + 16 * recs.length;
  for (const r of recs) {
    const dl = 2 * r.data.length, len = dl + r.segs.length, pad = (4 - (len % 4)) % 4;
    const b = new Uint8Array(len + pad), dv = new DataView(b.buffer);
    r.data.forEach((v, i) => dv.setInt16(2 * i, q4(v), true));
    b.set(r.segs, dl);
    idx.push([r.segs.length, at + dl, at, r.c]);
    blobs.push(b); at += b.length;
  }
  const out = new Uint8Array(at), dv = new DataView(out.buffer);
  dv.setUint32(0, recs.length, true);
  idx.forEach((v, i) => v.forEach((x, j) => dv.setUint32(4 + 16 * i + 4 * j, x, true)));
  let o = 4 + 16 * recs.length;
  for (const b of blobs) { out.set(b, o); o += b.length; }
  return out;
}

/** Draw groups on a canvas as the camera's renderer would (quarter pixels, even-odd, in order). The surface's top
 *  `top` px above the 256 square hold the rear dial's label. */
export function drawGroups(ctx: CanvasRenderingContext2D, groups: Group[], z = 1, top = 44) {
  for (const [c, polys] of groups) {
    const p = new Path2D();
    for (const poly of polys) {
      poly.forEach(([x, y], i) => {
        const X = (q4(x) / 4) * z, Y = (256 - q4(y) / 4 + top) * z;
        if (i) p.lineTo(X, Y); else p.moveTo(X, Y);
      });
      p.closePath();
    }
    ctx.fillStyle = `rgb(${c >>> 24},${(c >>> 16) & 255},${(c >>> 8) & 255})`;
    ctx.fill(p, 'evenodd');
  }
}
