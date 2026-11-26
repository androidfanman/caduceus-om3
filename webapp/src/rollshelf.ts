// Film Rolls (test firmware): each film's roll, the name, ISO and colour its canister shows on the camera and the ISO
// a roll of it is shot at. Our 20 films start with the shelf of firmware/mkrollpath.py (FILMS: the short name and our
// colour); any other look starts with its own name (an ISO at its end goes to the badge) and a colour picked from the
// shelf's. The roll ISO is never below 200 (owner, 2026-11-25: "for the roll iso, dont do anything lower than 200").
import type { Look } from './pack';
import { filmOf } from './om3films';
import { film as rollFilm, pack as rollPack, type Rgb } from './rollart';
import { ROLL_ISOS, cleanRollName, type Roll } from './roll';
export { ROLL_ISOS, ROLL_NAME_MAX, cleanRollName, parseRoll, type Roll } from './roll';

/** The default shelf (mkrollpath.py FILMS), by our film's name: the label's short name, the box speed, our colour. */
const SHELF: Record<string, [string, number, string]> = {
  'Portra 400': ['Portra', 400, '#d98a2b'], 'Portra 160': ['Portra', 160, '#e8a862'], 'Portra 800': ['Portra', 800, '#b86a24'],
  'Gold 200': ['Gold', 200, '#e0b23a'], 'ColorPlus 200': ['ColorPlus', 200, '#e89a3c'], 'Ektar 100': ['Ektar', 100, '#d65a3c'],
  'Ektachrome E100': ['E100', 100, '#4a78b8'], 'Kodachrome 64': ['Kodachrome', 64, '#d8b040'], 'CineStill 800T': ['CineStill', 800, '#b04a62'],
  'Velvia 50': ['Velvia', 50, '#4fa673'], 'Provia 100F': ['Provia', 100, '#4c8cc8'], 'Pro 400H': ['Pro 400H', 400, '#7cc0b0'],
  'Pro 160S': ['Pro 160S', 160, '#8ab87a'], 'NPS 160': ['NPS', 160, '#a8c48c'], 'NHG II 800': ['NHG II', 800, '#3e8c7c'],
  'Superia 400': ['Superia', 400, '#5aa85a'], 'Fuji C200': ['C200', 200, '#6a9cd8'], 'Fujifilm 200': ['Fujifilm', 200, '#9ac05a'],
  'Fujifilm 400': ['Fujifilm', 400, '#48a060'], 'Natura 1600': ['Natura', 1600, '#6e6a66'],
};
/** The colours LookLab offers as swatches: the shelf's 20. */
export const ROLL_SWATCHES = [...new Set(Object.values(SHELF).map((s) => s[2]))];

/** A box speed as a roll ISO: never below 200, the nearest whole stop LookLab offers. */
export function rollIso(box: number): number {
  if (!(box > 0)) return 400;
  return ROLL_ISOS.reduce((a, b) => (Math.abs(Math.log2(b / box)) < Math.abs(Math.log2(a / box)) ? b : a), ROLL_ISOS[0] as number) as number;
}

/** The roll a look starts with (before the user changes it). */
export function defaultRoll(l: Look): Roll {
  const f = filmOf(l), s = f && SHELF[f.name];
  if (s) return { name: s[0], iso: rollIso(s[1]), color: s[2] };
  const m = /^(.*?)\s*(\d{2,4})[A-Za-z]{0,2}$/.exec(l.name.trim());   // "Gold 200", "CineStill 800T", "Provia 100F"
  const nm = cleanRollName((m && m[1] ? m[1] : l.name).trim()) || 'Film';
  let h = 0; for (const ch of l.name) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return { name: nm, iso: m ? rollIso(Number(m[2])) : 400, color: ROLL_SWATCHES[h % ROLL_SWATCHES.length] };
}
/** The look's roll: what the user set, else its default. */
export const rollOf = (l: Look): Roll => ({ ...defaultRoll(l), ...(l.roll ?? {}) });

export const hexRgb = (c: string): Rgb => [parseInt(c.slice(1, 3), 16), parseInt(c.slice(3, 5), 16), parseInt(c.slice(5, 7), 16)];
/** The camera's ISO setting for a roll ISO (Sv x 256: 200 = 1536, each stop + 256). */
export const isoSetting = (iso: number) => Math.round(256 * Math.log2(iso / 3.125));

// ---- OM3MOD/FILMROLL/ROLLART.BIN (the card file Film Rolls draws its canisters from; firmware/mkrollpath.py rollart())
// 'OM3R' | u16 1 | u16 n = 96 | n x {u32 offset, u32 length} | 'OM3I' + 24 x u16 roll ISO | the records.
// Entry 3 i + (24 / 36 / 72 -> 0 / 1 / 2) for i 0..19 = FILM 1..20 (the camera's numbers: empty places left out),
// 20..23 = COLOR 1..4; then 72 + i: the same without a length. Every record carries the rear dial's label.
// The ISO table (LookLab, 2026-11-25): the camera's ISO setting (Sv x 256) per film, FILM 1..20 then COLOR 1..4; the
// card code reads only the index, so a FILMROLL.BIN that doesn't know the table draws this file as before.
export const ROLL_EXPS = [24, 36, 72] as const;
export const ROLL_FILMS = 20, ROLL_COLORS = 4;
/** frblock.s: a record and its page's 24-byte header must fit SC_PAGE (10240 B), else the camera draws no canister. */
export const ROLL_RECORD_MAX = 10240 - 24;
const COLOR_GREY = '#8a8a8a';
const SPARE: Roll = { name: 'Film', iso: 400, color: COLOR_GREY };

/** The shelf the camera gets: FILM 1..20 in its order (the bank's films, empty places left out; spare entries after
 *  the last film), then COLOR 1..4. */
export function shelfOf(bank: (Look | null)[][]): { films: Roll[]; looks: Look[] } {
  const looks = bank.flat().filter((l): l is Look => !!l).slice(0, ROLL_FILMS);
  const films = looks.map(rollOf);
  while (films.length < ROLL_FILMS) films.push(SPARE);
  return { films, looks };
}
const entry = (i: number, exp: number | null, films: Roll[]) =>
  i < ROLL_FILMS ? rollFilm(films[i].name, films[i].iso, exp, hexRgb(films[i].color), true)
    : rollFilm('COLOR', i - ROLL_FILMS + 1, exp, hexRgb(COLOR_GREY), true);

/** A canister too detailed for the camera: one of its records (24 / 36 / 72 exposures or none) past ROLL_RECORD_MAX. */
export const rollTooBig = (r: Roll): boolean =>
  [...ROLL_EXPS, null].some((e) => rollPack(rollFilm(r.name, r.iso, e, hexRgb(r.color), true)).length > ROLL_RECORD_MAX);

export function rollartBin(bank: (Look | null)[][]): Uint8Array {
  const { films } = shelfOf(bank);
  const N = ROLL_FILMS + ROLL_COLORS;
  const blobs: Uint8Array[] = [];
  for (let i = 0; i < N; i++) for (const e of ROLL_EXPS) blobs.push(rollPack(entry(i, e, films)));
  for (let i = 0; i < N; i++) blobs.push(rollPack(entry(i, null, films)));
  const n = blobs.length, tab = 4 + 2 * N, head = 8 + 8 * n + tab;
  const total = head + blobs.reduce((a, b) => a + b.length, 0);
  const out = new Uint8Array(total), dv = new DataView(out.buffer);
  out.set([0x4f, 0x4d, 0x33, 0x52]); dv.setUint16(4, 1, true); dv.setUint16(6, n, true);
  let at = head;
  blobs.forEach((b, k) => { dv.setUint32(8 + 8 * k, at, true); dv.setUint32(12 + 8 * k, b.length, true); out.set(b, at); at += b.length; });
  const t = 8 + 8 * n;
  out.set([0x4f, 0x4d, 0x33, 0x49], t);   // 'OM3I'
  for (let i = 0; i < N; i++) dv.setUint16(t + 4 + 2 * i, isoSetting(i < ROLL_FILMS ? films[i].iso : 400), true);
  return out;
}

/** A ROLLART.BIN's ISO table (FILM 1..20, COLOR 1..4 as ISO numbers), or null when it has none. */
export function readRollIsos(b: Uint8Array): number[] | null {
  if (b.length < 8 || String.fromCharCode(...b.subarray(0, 4)) !== 'OM3R') return null;
  const dv = new DataView(b.buffer, b.byteOffset, b.byteLength), n = dv.getUint16(6, true), t = 8 + 8 * n;
  if (b.length < t + 4 + 2 * (ROLL_FILMS + ROLL_COLORS) || String.fromCharCode(...b.subarray(t, t + 4)) !== 'OM3I') return null;
  return Array.from({ length: ROLL_FILMS + ROLL_COLORS }, (_, i) => Math.round(3.125 * 2 ** (dv.getUint16(t + 4 + 2 * i, true) / 256)));
}
