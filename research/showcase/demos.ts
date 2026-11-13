// One before / after pair per Picture Mode setting, rendered with the Control Panel's preview code on a neutral look
// (no film), so only that setting changes. make.sh runs it:
//   cd webapp && npx vite-node ../research/showcase/demos.ts -- RAW_DIR   (writes RAW_DIR/demo/<id>-a / -b .rgba)
import fs from 'node:fs';
import { renderLook } from '../../webapp/src/preview';
import { blankLook, type Look } from '../../webapp/src/pack';
const dir = process.argv[process.argv.length - 1];
fs.mkdirSync(`${dir}/demo`, { recursive: true });
const load = (n: string) => { const d = JSON.parse(fs.readFileSync(`${dir}/${n}.rgba.json`, 'utf8')); return { width: d.w, height: d.h, data: new Uint8ClampedArray(fs.readFileSync(`${dir}/${n}.rgba`)) }; };
const render = (src: string, out: string, edit: (l: Look) => void) => {
  const s = load(src), d = { width: s.width, height: s.height, data: new Uint8ClampedArray(s.data.length) };
  const l = blankLook('colour', 'demo'); edit(l);
  renderLook(s as unknown as ImageData, d as unknown as ImageData, l, { advice: true, camera: 'om3' });
  fs.writeFileSync(`${dir}/demo/${out}.rgba`, d.data); fs.writeFileSync(`${dir}/demo/${out}.rgba.json`, JSON.stringify({ w: s.width, h: s.height }));
};
const none = (_l: Look) => {};
const split = (sh: number, hl: number, shC = 8, hlC = 1) => ({ sh_color: shC, sh, hl_color: hlC, hl });   // strengths in v0.26 steps (camera 10 = 5)
// [id, photo, before, after]
const DEMOS: [string, string, (l: Look) => void, (l: Look) => void][] = [
  ['hsl-color', 'portrait', none, (l) => { l.sat[6] = -5; l.sat[7] = -5; }],
  ['hsl-hue', 'taxi', none, (l) => { l.hue[0] = 5; }],
  ['hsl-luminance', 'ocean', none, (l) => { l.light[6] = -5; l.light[7] = -5; l.light[8] = -5; }],
  ['hsl-shadows', 'portrait', none, (l) => { l.split = split(5, 0, 6); }],
  ['hsl-highlights', 'meadow', none, (l) => { l.split = split(0, 5, 6, 1); }],
  ['tone-balance', 'portrait', (l) => { l.split = split(4, 4); l.tone_balance = -5; }, (l) => { l.split = split(4, 4); l.tone_balance = 5; }],
  ['contrast', 'paris', (l) => { l.advice.contrast = -2; }, (l) => { l.advice.contrast = 2; }],
  ['curve', 'meadow', none, (l) => { l.tone.shadows = 7; l.tone.highlights = -7; }],
  ['blacks-whites', 'paris', none, (l) => { l.tone.blacks = 7; }],
  ['wb', 'meadow', (l) => { l.wb = { a_b: -7, g_m: 0 }; }, (l) => { l.wb = { a_b: 7, g_m: 0 }; }],
  ['sharpness', 'meadow-crop', (l) => { l.advice.sharpness = -5; }, (l) => { l.advice.sharpness = 2; }],
  ['shading', 'portrait', none, (l) => { l.vignette = -5; }],
  ['glow', 'bluehour', none, (l) => { l.effect = { type: 'bloom', strength: 5 }; }],
  ['grain', 'portrait-crop', none, (l) => { l.film_grain = 3; }],
];
for (const [id, src, a, b] of DEMOS) { render(src, `${id}-a`, a); render(src, `${id}-b`, b); }
console.log('demos', DEMOS.length);
