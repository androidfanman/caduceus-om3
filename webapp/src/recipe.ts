// A readable recipe .json (owner 2026-11-21: "the open looks doesnt accept .json files"): a look written out setting by
// setting, with the camera's photo code. For example:
//   { "name": "My look", "photo_code": "om3.1.…", "blacks": 2, …,
//     "rgb_curves": { "R": [5 points], "G": […], "B": […] },
//     "colour_mix": { "R_hue": …, "R_strength": …, "G_hue": …, "G_strength": …, "B_hue": …, "B_strength": … } }
// The look comes from the photo code, which holds every setting the camera writes into a photo (the same as opening the
// photo), plus the RGB curves and Color Mix, which the code does not hold. The other readable fields are not read.
import { parseCurves, parseMix } from './curves';
import { OM3_NAME_MAX, PHOTO_RE, lookFromPhotoCode } from './om3';
import type { Look } from './pack';

type Obj = Record<string, unknown>;
const isObj = (v: unknown): v is Obj => !!v && typeof v === 'object' && !Array.isArray(v);

/** A recipe .json: an object with the camera's om3.1. photo code in `photo_code`. */
export const isRecipe = (j: unknown): j is Obj => isObj(j) && typeof j.photo_code === 'string' && PHOTO_RE.test(j.photo_code);

/** The look of a recipe .json. Throws when a curves or mix field is there but not readable. */
export function lookFromRecipe(j: Obj): Look {
  const code = PHOTO_RE.exec(String(j.photo_code));
  if (!code) throw new Error('no om3.1. photo code');
  const l = lookFromPhotoCode(code[0]);
  if (typeof j.name === 'string' && j.name.trim()) l.name = j.name.trim().slice(0, OM3_NAME_MAX);
  const c = j.rgb_curves ?? j.rgb;
  if (c !== undefined) {
    if (!isObj(c)) throw new Error('rgb_curves is not R / G / B');
    const pick = (k: string) => c[k] ?? c[k.toUpperCase()];
    const rgb = parseCurves({ r: pick('r'), g: pick('g'), b: pick('b') });
    const flat = ['r', 'g', 'b'].every((k) => { const a = pick(k); return a === undefined || (Array.isArray(a) && a.every((x) => x === 0)); });
    if (!rgb && !flat) throw new Error('rgb_curves: each channel needs 5 whole numbers from -7 to 7');
    if (rgb) l.rgb = rgb; else delete l.rgb;
  }
  const m = j.colour_mix ?? j.color_mix;
  if (m !== undefined) {
    let v: unknown = m;
    if (isObj(m)) v = ['R', 'G', 'B'].flatMap((ch) => [m[`${ch}_hue`] ?? 0, m[`${ch}_strength`] ?? 0]);
    const mix = parseMix(v);
    if (!mix && !(Array.isArray(v) && v.length === 6 && v.every((x) => x === 0))) throw new Error('colour_mix: hue and strength from -7 to 7 for R, G and B');
    if (mix) l.mix = mix; else delete l.mix;
  }
  return l;
}
