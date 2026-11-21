// CURVES.BIN v1 (432 bytes, firmware v0.30; docs/FORMATS.md "CURVES.BIN v1", reference card/mkcurves.py): each film's
// built-in RGB curves and colour mix, for the films of the LOOKS.BIN written with it. The camera reads
// OM3MOD/CURVES.BIN at the first half-press and gives film j entry j's values only while its LOOKS.BIN record's
// CRC-32 equals the entry's check; firmware before v0.30 never reads it.
import { crc32 } from './format';
import { profilesBin, type Bank } from './om3';
import type { RgbCurves } from './curves';

export const CURVES_LEN = 432, CURVES_COUNT = 20;
const ZERO5 = [0, 0, 0, 0, 0], ZERO6 = [0, 0, 0, 0, 0, 0];
const v7 = (x: number) => Math.max(-7, Math.min(7, x | 0));

/** CURVES.BIN for `bank` (COLOR k, look v at 5k + v, as LOOKS.BIN), checked against `looksBin` (the LOOKS.BIN written with it). */
export function curvesBin(looksBin: Uint8Array, bank: Bank): Uint8Array {
  if (looksBin.length !== 1632 || String.fromCharCode(...looksBin.subarray(0, 4)) !== 'OM3P') throw new Error('CURVES.BIN needs a v1 LOOKS.BIN');
  const out = new Uint8Array(CURVES_LEN), dv = new DataView(out.buffer);
  out.set([0x4f, 0x4d, 0x33, 0x4b]);                       // 'OM3K'
  dv.setUint16(4, 1, true); dv.setUint16(6, CURVES_LEN, true); dv.setUint16(12, CURVES_COUNT, true);
  const looks = bank.flat();
  for (let j = 0; j < CURVES_COUNT; j++) {
    const e = 32 + 20 * j, l = looks[j];
    dv.setUint32(e, crc32(looksBin.subarray(32 + 64 * j, 96 + 64 * j)), true);
    const nib = [...(l?.rgb?.r ?? ZERO5), ...(l?.rgb?.g ?? ZERO5), ...(l?.rgb?.b ?? ZERO5)].map((x) => v7(x) & 15).concat([0]);
    for (let i = 0; i < 8; i++) out[e + 4 + i] = nib[2 * i] | (nib[2 * i + 1] << 4);
    (l?.mix ?? ZERO6).forEach((x, i) => dv.setInt8(e + 12 + i, v7(x)));
  }
  dv.setUint32(8, crc32(out.subarray(12)), true);
  return out;
}

/** True when any look of the bank has RGB curves or a colour mix (else CURVES.BIN would be all zero values). */
export const bankHasCurves = (bank: Bank) => bank.flat().some((l) => !!l && (!!l.rgb || !!l.mix?.some((x) => x)));

/** One CURVES.BIN entry's values: the film's RGB curves (5 points each) and colour mix (hue, strength for R, G, B). */
export interface CurvesEntry { rgb: RgbCurves; mix: number[] }

/** Read a CURVES.BIN v1 (as the camera checks it, docs/FORMATS.md): entries keyed by their check, the CRC-32 of the
 *  LOOKS.BIN record they were made for. Throws on a file the camera would refuse. */
export function readCurvesBin(b: Uint8Array): Map<number, CurvesEntry> {
  const bad = (why: string) => new Error(`not a CURVES.BIN the camera would take (${why})`);
  if (b.length !== CURVES_LEN) throw bad(`${b.length} bytes, not ${CURVES_LEN}`);
  if (String.fromCharCode(...b.subarray(0, 4)) !== 'OM3K') throw bad('wrong start');
  const dv = new DataView(b.buffer, b.byteOffset, b.byteLength);
  if (dv.getUint16(4, true) !== 1 || dv.getUint16(6, true) !== CURVES_LEN || dv.getUint16(12, true) !== CURVES_COUNT) throw bad('wrong version, length or count');
  if (dv.getUint32(8, true) !== crc32(b.subarray(12))) throw bad('damaged: its check sum is wrong');
  if (b.subarray(14, 32).some((x) => x)) throw bad('unused bytes not zero');
  const out = new Map<number, CurvesEntry>();
  for (let j = 0; j < CURVES_COUNT; j++) {
    const e = 32 + 20 * j, nib: number[] = [];
    for (let i = 0; i < 8; i++) nib.push(b[e + 4 + i] & 15, b[e + 4 + i] >> 4);
    if (nib[15] || b[e + 18] || b[e + 19]) throw bad(`entry ${j + 1}: unused bytes not zero`);
    const v = nib.slice(0, 15).map((x) => (x > 7 ? x - 16 : x)), mix = [...b.subarray(e + 12, e + 18)].map((x) => (x > 127 ? x - 256 : x));
    if (v.some((x) => x < -7) || mix.some((x) => x < -7 || x > 7)) throw bad(`entry ${j + 1}: a value out of range`);
    out.set(dv.getUint32(e, true), { rgb: { r: v.slice(0, 5), g: v.slice(5, 10), b: v.slice(10, 15) }, mix });
  }
  return out;
}

/** Put a CURVES.BIN's curves and colour mix back on the looks of `bank` it was made for: a look takes an entry when
 *  its LOOKS.BIN record (written as for firmware v0.28 or later, the only firmware that reads CURVES.BIN) has the
 *  entry's check, wherever it sits in the list (so a moved film keeps its values). A look that matches a flat entry
 *  ends with no curves and mix, as on the camera; a look that matches nothing (changed since, or from another set) is
 *  left as it is. Returns how many looks matched, of how many. */
export function applyCurvesBin(bank: Bank, entries: Map<number, CurvesEntry>): { matched: number; looks: number } {
  const lb = profilesBin(bank, 28);
  let matched = 0, looks = 0;
  bank.forEach((row, k) => row.forEach((l, v) => {
    if (!l) return;
    looks++;
    const r = 5 * k + v, en = entries.get(crc32(lb.subarray(32 + 64 * r, 96 + 64 * r)));
    if (!en) return;
    matched++;
    if ([...en.rgb.r, ...en.rgb.g, ...en.rgb.b].some((x) => x)) l.rgb = { r: en.rgb.r.slice(), g: en.rgb.g.slice(), b: en.rgb.b.slice() }; else delete l.rgb;
    if (en.mix.some((x) => x)) l.mix = en.mix.slice(); else delete l.mix;
  }));
  return { matched, looks };
}
