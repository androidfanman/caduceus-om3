// Checks om3code.js against examples.json:  node test.mjs   (Node 18+; no packages needed)
import { readFileSync } from 'node:fs';
import { findCode, decodeBytes, decode, readPhoto, describe } from './om3code.js';

const ex = JSON.parse(readFileSync(new URL('./examples.json', import.meta.url), 'utf8'));
let fails = 0;
const check = (ok, what) => { if (!ok) { fails++; console.log('FAIL', what); } };
const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);

// A minimal JPEG holding the comment the way the camera stores it (EXIF UserComment = 8 zero bytes + text),
// surrounded by other bytes, to check that the byte scan finds it inside a file.
function fakeJpeg(comment) {
  const head = [0xff, 0xd8, 0xff, 0xe1, 0, 0, ...Buffer.from('Exif\0\0MM\0*'), ...new Array(200).fill(7)];
  const body = Buffer.concat([Buffer.from(head), Buffer.from('\0'.repeat(8) + comment + '\0'), Buffer.alloc(5000, 0x55), Buffer.from([0xff, 0xd9])]);
  return new Uint8Array(body.buffer, body.byteOffset, body.length);
}

for (const f of [...ex.films, ex.fromFirmware, ex.future, ex.v028, ex.v028wb]) {
  check(same(decodeBytes(f.code), f.bytes), `bytes ${f.name}`);
  const r = readPhoto(f.comment);
  check(r && r.film === f.film && r.name === f.name && r.code === f.code, `comment ${f.name}`);
  const p = readPhoto(fakeJpeg(f.comment));
  check(p && p.code === f.code && p.film === f.film && same(p.bytes, f.bytes), `photo ${f.name}`);
  check(Array.isArray(describe(decode(f.code))), `describe ${f.name}`);
}
check(decode(ex.future.code).halation === 3, 'the v0.27 "future" byte 57 reads as Halation 3');
const rest = decode(ex.future.code), rest0 = decode(ex.films[0].code);
check(same(rest.hue, rest0.hue) && rest.contrast === rest0.contrast, 'future code reads like the film otherwise');
for (const f of [ex.v028, ex.v028wb]) for (const [k, v] of Object.entries(f.expect)) check(same(decode(f.code)[k], v), `${f.note.slice(0, 30)}: ${k}`);
check(same(decode(ex.films[4].code).splitToning.highlights, { colour: 'Green-cyan', strength: 2 }), 'a v0.27 film: whole steps on the 0..10 scale');
for (const bad of ex.invalid) check(findCode(bad) === null, `invalid "${bad}" rejected`);
check(readPhoto(new Uint8Array(1000)) === null, 'photo without a code -> null');
// The real camera photo (OM-3, v0.27): FILM 19 Astia 100F, the default recipe.
const real = readPhoto(readFileSync(new URL('./sample-film19-astia-100f.jpg', import.meta.url)));
const astia = ex.films.find((f) => f.film === 19);
check(real && real.film === 19 && real.name === 'Astia 100F' && real.code === astia.code, 'sample photo from the camera');

console.log(fails ? `${fails} failed` : `all passed (${ex.films.length + 4} codes)`);
console.log('\nExample:', ex.films[8].comment, '\n ' + describe(readPhoto(ex.films[8].comment)).join('\n '));
process.exit(fails ? 1 : 0);
