// Render the 20 camera films (and a few extras) on sample photos with the Control Panel's own preview code.
// cd webapp && npx vite-node ../research/showcase/films.ts -- RAW_DIR   (make.sh runs it)
import fs from 'node:fs';
import { renderLook } from '../../webapp/src/preview';
import { CAMERA_FILMS } from '../../webapp/src/om3films';
import type { Look } from '../../webapp/src/pack';
const dir = process.argv[process.argv.length - 1];
const load = (n: string) => { const d = JSON.parse(fs.readFileSync(`${dir}/${n}.rgba.json`, 'utf8')); return { width: d.w, height: d.h, data: new Uint8ClampedArray(fs.readFileSync(`${dir}/${n}.rgba`)) }; };
const save = (src: { width: number; height: number }, out: string, data: Uint8ClampedArray) => {
  fs.writeFileSync(`${dir}/out/${out}.rgba`, data); fs.writeFileSync(`${dir}/out/${out}.rgba.json`, JSON.stringify({ w: src.width, h: src.height }));
};
const run = (n: string, out: string, look: Look) => {
  const src = load(n); const dst = { width: src.width, height: src.height, data: new Uint8ClampedArray(src.data.length) };
  renderLook(src as unknown as ImageData, dst as unknown as ImageData, look, { advice: true, camera: 'om3' });
  save(src, out, dst.data);
};
fs.mkdirSync(`${dir}/out`, { recursive: true });
// the films exactly as the Control Panel has them (mklooks.ts: the standard 20)
const LOOKS: Look[] = JSON.parse(fs.readFileSync(`${dir}/../looks-std.json`, 'utf8'));
const names: string[] = [];
for (const s of ['meadow', 'portrait', 'paris', 'taxi']) {
  LOOKS.forEach((l, i) => run(s, `${s}-${String(i + 1).padStart(2, '0')}`, l));
}
LOOKS.forEach((l) => names.push(l.name));
// Halation: CineStill 800T at 0 and 5 on the neon night photo
for (const s of ['neon']) for (const lv of [0, 5]) {
  const l: Look = { ...LOOKS.find((x) => x.name === 'CineStill 800T')! }; if (lv) l.halation = lv; run(s, `hal-${s}-${lv}`, l);
}
fs.writeFileSync(`${dir}/out/films.json`, JSON.stringify(LOOKS.map((l) => { const f = CAMERA_FILMS.find((c) => c.name === l.name)!; return { name: l.name, film: f.film, desc: f.desc, group: f.group }; })));
console.log('done', names.length);
