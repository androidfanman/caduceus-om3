// om3code.js: read the film recipe that Caduceus for OM-3 (v0.27 and later) writes into a JPEG.
// No dependencies; works in browsers and in Node 18+ as an ES module. Apache-2.0 (see README.md).
//
//   import { readPhoto, decode, describe } from './om3code.js';
//   const recipe = readPhoto(await file.arrayBuffer());   // null when the photo has no code
//   console.log(recipe.film, recipe.name, describe(recipe));
//
// The camera writes the EXIF UserComment "Caduceus FILM 19 Astia 100F om3.1.<43 characters>". The 43 characters are
// the film's 64 settings bytes, one 4-bit value each, two to a byte (32 bytes), in base64url without padding.

export const PREFIX = 'om3.1.';
const CODE_RE = /om3\.1\.([A-Za-z0-9_-]{43})(?![A-Za-z0-9_-])/;
const NAME_RE = /FILM (\d+) (.*?) ?om3\.1\./;

/** The camera's 12-colour wheel, clockwise from 12 o'clock (used by Hue / Saturation / Lightness and split toning). */
export const WHEEL = ['Yellow', 'Orange', 'Orange-red', 'Red', 'Magenta', 'Violet', 'Blue', 'Blue-cyan', 'Cyan',
  'Green-cyan', 'Green', 'Yellow-green'];
export const ART_EFFECTS = ['Off', 'Star Light', 'Pin Hole', 'Off', 'White Edge', 'Frame'];   // 3 is unused (read as Off)
export const NOISE_REDUCTION = ['Camera setting', 'Standard', 'Low', 'Off', 'High'];
export const GRAIN = ['Off', 'Low', 'Medium', 'High'];

/** Bytes read as 0..15. Every other byte is signed (-8..7). Bytes 57..63 are spare: future settings, 0 = off. */
const UNSIGNED = new Set([36, 48, 49, 50, 51, 53, 55, 57, 58, 59, 60, 61, 62, 63]);

/** Find a code in text (a UserComment, a pasted string) or in a photo's bytes. Returns the 43 characters, or null. */
export function findCode(input) {
  const m = CODE_RE.exec(toText(input));
  return m ? m[1] : null;
}

/** The 64 settings bytes of a code (with or without the "om3.1." prefix) as numbers, signed where the field is. */
export function decodeBytes(code) {
  const body = code.startsWith(PREFIX) ? code.slice(PREFIX.length) : code;
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
  const b = decodeBytes(code), wheel = (at) => Object.fromEntries(WHEEL.map((c, i) => [c, b[at + i]]));
  const fx = b[47];
  return {
    version: 'om3.1',
    hue: wheel(0),                       // -5..5 per colour
    lightness: wheel(12),                // -5..5 per colour
    saturation: wheel(24),               // -5..5 per colour
    whiteBalance: b[36] ? { amberBlue: b[37], greenMagenta: b[38] } : null,   // -7..7 each; null = the camera's own
    blacks: b[39], whites: b[40],        // -5..5
    contrast: b[41],                     // -2..2
    shadows: b[44], midtones: b[45], highlights: b[46],   // -7..7
    shading: b[43],                      // vignette, -5..5
    sharpness: b[52] <= -5 ? 'Off' : b[52] || b[42],      // -4..2 (b[42]: older firmware's -2..2, 0 from v0.22 on)
    glow: fx < 0 ? -fx : 0,              // 0..5
    clarity: fx > 0 ? fx : 0,            // 0..5
    artEffect: ART_EFFECTS[b[48]] ?? 'Off',
    noiseReduction: NOISE_REDUCTION[b[49]] ?? 'Camera setting',
    lensShadingCorrection: b[50] === 0,  // true = the camera's correction (normal); false = turned off
    grain: GRAIN[b[51]] ?? 'Off',
    splitToning: b[54] || b[56]
      ? { shadows: { colour: WHEEL[b[53]] ?? null, strength: b[54] }, highlights: { colour: WHEEL[b[55]] ?? null, strength: b[56] } }
      : null,                            // strength -5..5; minus = the opposite colour
    spare: b.slice(57, 64),              // future settings; all 0 in om3.1 photos from today's firmware
    bytes: b,
  };
}

/** A photo (ArrayBuffer, Uint8Array) or its UserComment text -> { film, name, code, ...decode(code) }, or null. */
export function readPhoto(input) {
  const text = toText(input), m = CODE_RE.exec(text);
  if (!m) return null;
  const nm = NAME_RE.exec(text.slice(Math.max(0, m.index - 80), m.index + PREFIX.length));
  return { film: nm ? Number(nm[1]) : null, name: nm ? nm[2].trim() : null, code: PREFIX + m[1], ...decode(m[1]) };
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
    const t = r.splitToning[k]; if (t.strength) lines.push(`${l}: ${t.colour} ${sg(t.strength)}`);
  }
  if (r.glow) lines.push(`Glow ${r.glow}`);
  if (r.clarity) lines.push(`Clarity ${r.clarity}`);
  if (r.grain !== 'Off') lines.push(`Grain ${r.grain}`);
  if (r.noiseReduction !== 'Camera setting') lines.push(`Noise reduction ${r.noiseReduction}`);
  if (!r.lensShadingCorrection) lines.push('Lens shading correction off');
  if (r.artEffect !== 'Off') lines.push(`Art effect ${r.artEffect}`);
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
