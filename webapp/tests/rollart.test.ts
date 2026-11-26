// Film Rolls (test firmware): LookLab's canisters (src/rollart.ts) are firmware/mkrollpath.py's, byte for byte.
// tests/rollart.fixture.json: sha256 of mkrollpath.pack(film(...)) / pack(base()) made by mkrollpath.py itself.
import { createHash } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import fixture from './rollart.fixture.json';
import { base, film, pack, roundEven } from '../src/rollart';
import { blankLook } from '../src/pack';
import { filmLook, CAMERA_FILMS } from '../src/om3films';
import { defaultRoll, isoSetting, parseRoll, rollIso, rollOf } from '../src/rollshelf';
import { parseLook } from '../src/pack';

const sha = (b: Uint8Array) => createHash('sha256').update(b).digest('hex');

describe('canisters as mkrollpath.py draws them', () => {
  for (const c of fixture as { name?: string; iso?: number; exp?: number | null; body?: number[]; labelled?: boolean; base?: boolean; sha256: string }[]) {
    it(c.base ? 'the shared parts' : `${c.name} ${c.iso} ${c.exp ?? 'no length'}${c.labelled ? ' labelled' : ''}`, () => {
      const g = c.base ? base() : film(c.name!, c.iso!, c.exp ?? null, c.body as [number, number, number], c.labelled);
      expect(sha(pack(g))).toBe(c.sha256);
    });
  }
  it('rounds quarter pixels as Python does (halves to even)', () => {
    expect([0.5, 1.5, 2.5, -0.5, -1.5, 2.4, 2.6].map((v) => roundEven(v) + 0)).toEqual([0, 2, 2, 0, -2, 2, 3]);
  });
});

describe('a film\'s roll', () => {
  it('our films start with the shelf, never below ISO 200', () => {
    expect(defaultRoll(filmLook(CAMERA_FILMS[0]))).toEqual({ name: 'Portra', iso: 400, color: '#d98a2b' });
    expect(defaultRoll(filmLook(CAMERA_FILMS[9]))).toEqual({ name: 'Velvia', iso: 200, color: '#4fa673' });
    expect(defaultRoll(filmLook(CAMERA_FILMS[19])).iso).toBe(1600);
  });
  it('other looks: their name, an ISO at its end, else 400', () => {
    expect(defaultRoll(blankLook('colour', 'Sunset 800T'))).toMatchObject({ name: 'Sunset', iso: 800 });
    expect(defaultRoll(blankLook('colour', 'Beach Day'))).toMatchObject({ name: 'Beach Day', iso: 400 });
  });
  it('roll ISO: whole stops 200..6400', () => {
    expect([50, 100, 160, 200, 250, 640, 3200, 12800].map(rollIso)).toEqual([200, 200, 200, 200, 200, 800, 3200, 6400]);
    expect([200, 400, 800, 1600, 3200, 6400].map(isoSetting)).toEqual([1536, 1792, 2048, 2304, 2560, 2816]);
  });
  it('what the user set is kept with the look; bad values are dropped', () => {
    const l = parseLook({ ...blankLook('colour', 'Mine'), roll: { name: 'Mine', iso: 3200, color: '#AABBCC' } });
    expect(rollOf(l)).toEqual({ name: 'Mine', iso: 3200, color: '#aabbcc' });
    expect(parseRoll({ iso: 100, color: 'red', name: '' })).toBeUndefined();
  });
});

import binFixture from './rollartbin.fixture.json';
import { readRollIsos, rollTooBig, rollartBin, shelfOf } from '../src/rollshelf';
import type { Look } from '../src/pack';

const ourBank = (): (Look | null)[][] => [0, 1, 2, 3].map((k) => CAMERA_FILMS.slice(5 * k, 5 * k + 5).map(filmLook));
const record = (b: Uint8Array, e: number) => { const dv = new DataView(b.buffer); const o = dv.getUint32(8 + 8 * e, true); return b.subarray(o, o + dv.getUint32(12 + 8 * e, true)); };

describe('ROLLART.BIN', () => {
  it('our 20 films: the file mkrollpath.py makes for this shelf, with the ISO table', () => {
    const b = rollartBin(ourBank());
    expect(b.length).toBe(binFixture.size);
    expect(sha(b)).toBe(binFixture.sha256);
    expect(readRollIsos(b)).toEqual([...binFixture.isos, 400, 400, 400, 400]);
  });
  it('a custom film: its own canister and ISO in its FILM\'s entries', () => {
    const bank = ourBank();
    bank[0][0] = { ...blankLook('colour', 'Night Walk'), roll: { name: 'Midnight', iso: 3200, color: '#2f3f8f' } };
    const b = rollartBin(bank);
    expect(readRollIsos(b)!.slice(0, 2)).toEqual([3200, 200]);
    expect(sha(record(b, 1))).toBe(sha(pack(film('Midnight', 3200, 36, [0x2f, 0x3f, 0x8f], true))));   // FILM 1, 36 exposures
    expect(sha(record(b, 72))).toBe(sha(pack(film('Midnight', 3200, null, [0x2f, 0x3f, 0x8f], true))));  // FILM 1, no length
  });
  it('empty places are left out of the camera\'s numbers', () => {
    const bank = ourBank(); bank[0][0] = null;
    const s = shelfOf(bank);
    expect(s.films[0].name).toBe('Portra');          // Portra 160 is FILM 1 now
    expect(s.films[0].iso).toBe(200);
    expect(s.films[19]).toMatchObject({ name: 'Film', iso: 400 });
  });
  it('every record fits the camera\'s page; a name too detailed is caught', () => {
    expect(binFixture.max_record).toBeLessThanOrEqual(10240 - 24);
    expect(rollTooBig({ name: 'Midnight', iso: 3200, color: '#2f3f8f' })).toBe(false);
    expect(rollTooBig({ name: '@@@@@@@@@@@@', iso: 400, color: '#2f3f8f' })).toBe(true);
  });
});
