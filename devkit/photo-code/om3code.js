// om3code.js: read the film recipe that Caduceus for OM-3 (v0.27 and later) writes into a JPEG.
// No dependencies; works in browsers and in Node 18+ as an ES module. Apache-2.0 (see README.md).
//
//   import { readPhoto, decode, describe } from './om3code.js';
//   const recipe = readPhoto(await file.arrayBuffer());   // null when the photo has no code
//   console.log(recipe.film, recipe.name, describe(recipe));
//
// The camera writes the EXIF UserComment "Caduceus FILM 19 Astia 100F om3.1.<43 characters>". The 43 characters are
// the film's 64 settings bytes, one 4-bit value each, two to a byte (32 bytes), in base64url without padding.
// From v0.28 the code holds the film as it was set when the photo was taken, plus Halation, Tone Balance and the WB.
//
// om3.2 (2026-11-24): the UserComment is the code alone, "om3.2.<60 characters>" = 45 bytes: the same 64 values
// (bytes 0..31), then the RGB curves and the colour mix (bytes 32..43, 24 more 4-bit values) and the grain byte (44:
// Film Grain strength and Grain Size). The film's number and name stay in the EXIF ImageDescription ("FILM 19 Astia
// 100F"). Everything here reads both codes.

export const PREFIX = 'om3.1.';
export const PREFIX2 = 'om3.2.';
const CODE_RE = /om3\.(?:1\.([A-Za-z0-9_-]{43})|2\.((?:[A-Za-z0-9_-]{4}){15,}))(?![A-Za-z0-9_-])/;
const NAME_RE = /FILM (\d+) (.*?) ?om3\.[12]\./;
const DESC_RE = /FILM (\d+)(?: ([\x20-\x7e]{1,16}))?\0/;   // om3.2: the ImageDescription of a photo

/** The camera's 12-colour wheel, clockwise from 12 o'clock (used by Hue / Saturation / Lightness and split toning). */
export const WHEEL = ['Yellow', 'Orange', 'Orange-red', 'Red', 'Magenta', 'Violet', 'Blue', 'Blue-cyan', 'Cyan',
  'Green-cyan', 'Green', 'Yellow-green'];
export const ART_EFFECTS = ['Off', 'Star Light', 'Pin Hole', 'Off', 'White Edge', 'Frame'];   // 3 is unused (read as Off)
export const NOISE_REDUCTION = ['Camera setting', 'Standard', 'Low', 'Off', 'High'];
export const GRAIN = ['Off', 'Low', 'Medium', 'High'];
/** The Film Grain strength (1..5) of a grain level, for codes that do not give it. */
export const GRAIN_STRENGTH = [0, 2, 3, 5];
export const GRAIN_SIZES = ['Fine', 'Medium', 'Coarse'];
export const HALATION_RADII = ['Bloom', 'Tight', 'Medium', 'Wide'];
/** v0.28: the camera's WB modes, in its own order (bytes 61 / 62). */
export const WB_MODES = ['Auto', 'Sunny', 'Shade', 'Cloudy', 'Incandescent', 'Fluorescent', 'Underwater', 'Flash',
  'One-touch 1', 'One-touch 2', 'One-touch 3', 'One-touch 4', 'Custom WB'];

/** Bytes read as 0..15. Every other byte is signed (-8..7). v0.27 had 57..63 spare; v0.28 uses them all (57 Halation,
 *  58 Tone Balance, 59..62 the WB, 63 split toning's half steps). v0.40: byte 48 is the Border (-5..5), signed. */
const UNSIGNED = new Set([36, 49, 50, 51, 53, 55, 57, 63]);

/** Find a code in text (a UserComment, a pasted string) or in a photo's bytes. Returns an om3.1 code's 43 characters
 *  (as before om3.2), a whole om3.2 code ("om3.2." and its 60 or more characters), or null. */
export function findCode(input) {
  const m = CODE_RE.exec(toText(input));
  return m ? m[1] ?? m[0] : null;
}

/** An om3.2 code's raw bytes (45 or more), or null for an om3.1 code. */
function bytes2(code) {
  if (!code.startsWith(PREFIX2)) return null;
  const body = code.slice(PREFIX2.length);
  if (!/^(?:[A-Za-z0-9_-]{4}){15,}$/.test(body)) throw new Error('An om3.2 code has 60 characters (or more, in groups of 4) after "om3.2.".');
  return Array.from(atob(body.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0));
}

/** The 64 settings bytes of a code (an om3.2 code, or an om3.1 code with or without its prefix) as numbers, signed
 *  where the field is. */
export function decodeBytes(code) {
  const body = code.startsWith(PREFIX2) ? (bytes2(code), code.slice(PREFIX2.length, PREFIX2.length + 43))
    : code.startsWith(PREFIX) ? code.slice(PREFIX.length) : code;
  if (!/^[A-Za-z0-9_-]{43}$/.test(body)) throw new Error('An om3.1 code has 43 characters after "om3.1.".');
  const bin = atob(body.replace(/-/g, '+').replace(/_/g, '/') + '=');
  const out = new Array(64);
  for (let i = 0; i < 64; i++) {
    const byte = bin.charCodeAt(i >> 1), v = i & 1 ? byte & 15 : byte >> 4;
    out[i] = UNSIGNED.has(i) || v < 8 ? v : v - 16;
  }
  return out;
}

/** A code -> the recipe as named settings (see README.md for every field and its range). */
export function decode(code) {
  const b = decodeBytes(code), b2 = bytes2(code), wheel = (at) => Object.fromEntries(WHEEL.map((c, i) => [c, b[at + i]]));
  const fx = b[47];
  // split toning on the camera's v0.28 scale 0..10: v0.26 steps x 2 + byte 63's half step; a v0.26 / v0.27 minus
  // (the opposite colour) as the opposite colour of the wheel
  const tone = (col, st, bit) => (b[st] < 0 ? { colour: WHEEL[(b[col] + 6) % 12] ?? null, strength: -2 * b[st] }
    : { colour: WHEEL[b[col]] ?? null, strength: 2 * b[st] + ((b[63] >> bit) & 1) });
  const sh = tone(53, 54, 0), hl = tone(55, 56, 1);
  const mode = b[61] + 11 * b[62], kv = b[59] + 11 * b[60];
  // om3.2: 24 more values (the curves, the mix) and the grain byte; om3.1: flat curves, no mix, the level's grain
  const x = (b2 ?? new Array(45).fill(0)).slice(32, 44).flatMap((y) => [y >> 4, y & 15]).map((v) => (v < 8 ? v : v - 16));
  const curve = (at) => [0, 2, 3, 4, 5].map((p) => x[at + p]), mix = (at) => ({ hue: x[at], strength: x[at + 1] });
  const level = Math.min(b[51], 3), g = b2 && b2[44] & 0x80 && level ? b2[44] : 0;
  return {
    version: b2 ? 'om3.2' : 'om3.1',
    hue: wheel(0),                       // -5..5 per colour
    lightness: wheel(12),                // -5..5 per colour
    saturation: wheel(24),               // -5..5 per colour
    whiteBalance: b[36] ? { amberBlue: b[37], greenMagenta: b[38] } : null,   // -7..7 each; null = the camera's own
    blacks: b[39], whites: b[40],        // -7..7 (-5..5 before v0.28)
    contrast: b[41],                     // -2..2
    shadows: b[44], midtones: b[45], highlights: b[46],   // -7..7
    shading: b[43],                      // vignette, -5..5
    sharpness: b[52] <= -5 ? 'Off' : b[52] || b[42],      // -4..2 (b[42]: older firmware's -2..2, 0 from v0.22 on)
    glow: fx < 0 ? -fx : 0,              // 0..5
    clarity: fx > 0 ? fx : 0,            // 0..5
    artEffect: 'Off',                    // always Off: photo codes start at v0.27, and v0.25 removed the Art Effects
    border: b[48],                       // -5..5 (v0.40): minus = a black border, plus = white, 0 = none
    noiseReduction: NOISE_REDUCTION[b[49]] ?? 'Camera setting',
    lensShadingCorrection: b[50] === 0,  // true = the camera's correction (normal); false = turned off
    grain: GRAIN[b[51]] ?? 'Off',        // v0.40's Film Grain 1..5 is written as 1-2 Low, 3 Medium, 4-5 High
    splitToning: sh.strength || hl.strength ? { shadows: sh, highlights: hl } : null,   // strength 0..10 (as the camera from v0.28)
    toneBalance: b[58],                  // -5..5 (v0.28): - the shadow colour reaches further, + the highlight colour
    halation: b[57],                     // 0..5 (v0.28)
    halationRadius: HALATION_RADII[(b[63] >> 2) & 3],   // v0.40.3: 'Bloom' (also every older code), 'Tight', 'Medium', 'Wide'
    filmGrain: (g & 7) >= 1 && (g & 7) <= 5 ? g & 7 : GRAIN_STRENGTH[level],   // 0 Off, 1..5 (om3.1: the level's 2 / 3 / 5)
    grainSize: (g && GRAIN_SIZES[(g >> 3) & 3]) || 'Medium',
    rgbCurves: { red: curve(0), green: curve(6), blue: curve(12) },   // 5 points each (0 / 25 / 50 / 75 / 100 %), -7..7; flat in om3.1
    colourMix: { red: mix(18), green: mix(20), blue: mix(22) },       // hue and strength, -7..7; none in om3.1
    whiteBalanceMode: mode > 0 && mode < WB_MODES.length   // v0.28: the camera's WB when the photo was taken; null = Auto (or an older photo)
      ? { mode: WB_MODES[mode], kelvin: mode === 12 ? 2000 + 100 * (kv + 60) : null } : null,
    bytes: b,
  };
}

/** A photo (ArrayBuffer, Uint8Array) or its UserComment text -> { film, name, code, ...decode(code) }, or null. */
export function readPhoto(input) {
  const text = toText(input), m = CODE_RE.exec(text);
  if (!m) return null;
  // the film's number and name: before an om3.1 code; for om3.2 in the photo's ImageDescription (or before the code in text)
  const nm = NAME_RE.exec(text.slice(Math.max(0, m.index - 80), m.index + PREFIX.length)) ?? (m[2] && typeof input !== 'string' ? DESC_RE.exec(text) : null);
  return { film: nm ? Number(nm[1]) : null, name: nm?.[2] ? nm[2].trim() : null, code: m[0], ...decode(m[0]) };
}

/** A recipe -> short lines a person can read ("Contrast +1"); settings at 0 / off are left out. */
export function describe(r) {
  const sg = (v) => (v > 0 ? `+${v}` : String(v)), lines = [];
  const wheel = (label, o) => { const s = Object.entries(o).filter(([, v]) => v).map(([c, v]) => `${c} ${sg(v)}`); if (s.length) lines.push(`${label}: ${s.join(', ')}`); };
  wheel('Hue', r.hue); wheel('Saturation', r.saturation); wheel('Lightness', r.lightness);
  if (r.whiteBalance) lines.push(`White balance: A-B ${sg(r.whiteBalance.amberBlue)}, G-M ${sg(r.whiteBalance.greenMagenta)}`);
  for (const [k, l] of [['contrast', 'Contrast'], ['shadows', 'Shadows'], ['midtones', 'Midtones'], ['highlights', 'Highlights'],
    ['blacks', 'Blacks'], ['whites', 'Whites'], ['shading', 'Shading']]) if (r[k]) lines.push(`${l} ${sg(r[k])}`);
  if (r.sharpness) lines.push(`Sharpness ${typeof r.sharpness === 'number' ? sg(r.sharpness) : r.sharpness}`);
  if (r.splitToning) for (const [k, l] of [['shadows', 'Split toning shadows'], ['highlights', 'Split toning highlights']]) {
    const t = r.splitToning[k]; if (t.strength) lines.push(`${l}: ${t.colour} ${t.strength} of 10`);
  }
  if (r.toneBalance) lines.push(`Tone balance ${sg(r.toneBalance)}`);
  if (r.whiteBalanceMode) lines.push(`White balance mode: ${r.whiteBalanceMode.mode}${r.whiteBalanceMode.kelvin ? ` ${r.whiteBalanceMode.kelvin} K` : ''}`);
  if (r.halation) lines.push(`Halation ${r.halation}${r.halationRadius !== 'Bloom' ? ` (${r.halationRadius})` : ''}`);
  if (r.glow) lines.push(`Glow ${r.glow}`);
  if (r.clarity) lines.push(`Clarity ${r.clarity}`);
  if (r.version === 'om3.1') { if (r.grain !== 'Off') lines.push(`Grain ${r.grain}`); }
  else if (r.filmGrain) lines.push(`Film grain ${r.filmGrain} of 5${r.grainSize !== 'Medium' ? `, ${r.grainSize}` : ''}`);
  for (const c of ['red', 'green', 'blue']) if (r.rgbCurves[c].some(Boolean)) lines.push(`RGB curve ${c}: ${r.rgbCurves[c].map(sg).join(' ')}`);
  for (const c of ['red', 'green', 'blue']) { const m = r.colourMix[c]; if (m.hue || m.strength) lines.push(`Colour mix ${c}: hue ${sg(m.hue)}, strength ${sg(m.strength)}`); }
  if (r.noiseReduction !== 'Camera setting') lines.push(`Noise reduction ${r.noiseReduction}`);
  if (!r.lensShadingCorrection) lines.push('Lens shading correction off');
  if (r.border) lines.push(`Border ${r.border < 0 ? 'black' : 'white'} ${Math.abs(r.border)}`);
  return lines;
}

/** Text from a string, or the bytes of a photo read as Latin-1 (the code is plain ASCII, so a byte scan finds it
 *  wherever the camera put it, with no EXIF parser needed). EXIF lives in the first 64 KB of a JPEG, so only the first
 *  128 KB are read. */
function toText(input) {
  if (typeof input === 'string') return input;
  let u8 = input instanceof Uint8Array ? input : new Uint8Array(input.buffer ?? input, input.byteOffset ?? 0, input.byteLength);
  u8 = u8.subarray(0, 0x20000);
  let s = '';
  for (let i = 0; i < u8.length; i += 0x8000) s += String.fromCharCode.apply(null, u8.subarray(i, i + 0x8000));
  return s;
}
