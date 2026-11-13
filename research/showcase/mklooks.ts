// LookLab's standard 20 (CAMERA_FILMS, as on a first visit or "Reset looks to standard"): LOOKS.BIN for the
// emulator card (profilesBin, the v0.28+ format, as Export makes it), the looks as JSON for films.ts, and
// films/films.js (names, descriptions, colour matched or not) for the page.
//   cd webapp && npx vite-node ../research/showcase/mklooks.ts -- WORK_DIR IMG_DIR
import fs from 'node:fs';
import { CAMERA_FILMS, filmLook } from '../../webapp/src/om3films';
import { profilesBin, emptyBank, PER } from '../../webapp/src/om3';
const [work, img] = process.argv.slice(-2);
const looks = CAMERA_FILMS.map((f) => filmLook(f));
const bank = emptyBank();
looks.forEach((l, i) => { bank[Math.floor(i / PER)][i % PER] = l; });
fs.writeFileSync(`${work}/LOOKS.BIN`, profilesBin(bank, 28));
fs.writeFileSync(`${work}/looks-std.json`, JSON.stringify(looks, null, 1));
const meta = CAMERA_FILMS.map((f) => ({ name: f.name, film: f.film, desc: f.desc, group: f.group, matched: !!f.matched }));
fs.writeFileSync(`${img}/films/films.js`, '// The standard 20 films (webapp/src/data/om3films.json CAMERA, FILM 1-20 order); made by research/showcase/mklooks.ts\nwindow.FILMS = ' + JSON.stringify(meta, null, 0) + ';\n');
console.log(CAMERA_FILMS.map((f, i) => `${i + 1} ${f.name}${f.matched ? ' (matched)' : ''}`).join(', '));
