// Runs the Control Panel's own preview (webapp/src/preview.ts) on the colour checker's 24 colours for every look in a
// films JSON (webapp/scripts/films.py --recipes), so grade.py can match the camera to it. Bundle and run (from webapp/):
//   ./node_modules/.bin/esbuild ../research/film-grading/preview_chart.ts --bundle --platform=node --format=esm --outfile=/tmp/pc.mjs
//   node /tmp/pc.mjs /tmp/recipes.json /tmp/preview_chart.json
import { renderLook } from '../../webapp/src/preview';
import { filmLook, type Film } from '../../webapp/src/om3films';
import { blankLook } from '../../webapp/src/pack';
import * as fs from 'fs';
import data from './camera_response.json';
const rgb: number[][] = (data as any).chart_rgb;
const films: Film[] = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')).films;
const B = 9, W = 24 * B, H = B;   // 9 x 9 blocks: Sharp's 3 x 3 filter leaves the centre pixel alone
const src: any = { width: W, height: H, data: new Uint8ClampedArray(W * H * 4) };
for (let p = 0; p < 24; p++) for (let y = 0; y < H; y++) for (let x = 0; x < B; x++) {
  const o = (y * W + p * B + x) * 4; src.data.set([rgb[p][0], rgb[p][1], rgb[p][2], 255], o);
}
function run(look: any) {
  const dst: any = { width: W, height: H, data: new Uint8ClampedArray(W * H * 4) };
  renderLook(src, dst, look, { advice: true, camera: 'om3' });
  return Array.from({ length: 24 }, (_, p) => { const o = (4 * W + p * B + 4) * 4; return [dst.data[o], dst.data[o + 1], dst.data[o + 2]]; });
}
const res: Record<string, number[][]> = { __blank__: run(blankLook('colour', 'x')) };
for (const f of films) res[f.name] = run(filmLook(f));
fs.writeFileSync(process.argv[3], JSON.stringify(res));
console.log(Object.keys(res).length - 1, 'looks');
