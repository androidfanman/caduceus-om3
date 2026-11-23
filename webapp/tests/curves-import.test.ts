import { describe, expect, it } from 'vitest';
import { readFileSync } from 'node:fs';
import { applyCurvesBin, curvesBin, readCurvesBin } from '../src/curvesbin';
import { CAMERA_FILMS, filmLook } from '../src/om3films';
import { emptyBank, profilesBin, readProfiles, PER, type Bank } from '../src/om3';
import { crc32 } from '../src/format';
import { cloneLook } from '../src/pack';

// Opening CURVES.BIN (owner, 2026-11-21: opening a card's LOOKS.BIN lost each film's RGB curves and colour mix, so
// the next export wrote them flat and the camera dropped them). A look takes the entry whose check is its LOOKS.BIN
// record's CRC-32, wherever it sits in the list.
const standard = (): Bank => { const b = emptyBank(); CAMERA_FILMS.forEach((f, i) => { b[Math.floor(i / PER)][i % PER] = filmLook(f); }); return b; };
const curvesOf = (b: Bank) => b.flat().map((l) => ({ rgb: l?.rgb ?? null, mix: l?.mix ?? null }));
const release = (f: string) => new Uint8Array(readFileSync(new URL(`../../releases/${f}`, import.meta.url)));

describe('opening CURVES.BIN', () => {
  const bank = standard(), lb = profilesBin(bank, 28), cb = curvesBin(lb, bank);

  it('brings back every film\'s curves and mix after opening the LOOKS.BIN they were saved with', () => {
    const opened = readProfiles(lb, true);
    expect(opened.flat().some((l) => l?.rgb || l?.mix)).toBe(false);          // LOOKS.BIN alone: none (the bug)
    expect(applyCurvesBin(opened, readCurvesBin(cb))).toEqual({ matched: 20, looks: 20 });
    expect(curvesOf(opened)).toEqual(curvesOf(bank));
  });

  it('reads the released CURVES.BIN onto the released LOOKS.BIN (v0.30.3: the 20 regraded films)', () => {
    const opened = readProfiles(release('v0.30.3/LOOKS.BIN'), true);
    expect(applyCurvesBin(opened, readCurvesBin(release('v0.30.3/CURVES.BIN')))).toEqual({ matched: 20, looks: 20 });
    expect(opened.flat().filter((l) => l?.rgb || l?.mix).length).toBeGreaterThan(15);
    // and writing them out again gives the same CURVES.BIN, byte for byte
    expect(Buffer.from(curvesBin(profilesBin(opened, 28), opened))).toEqual(Buffer.from(release('v0.30.3/CURVES.BIN')));
  });

  it('follows a film moved to another place in the list', () => {
    const opened = readProfiles(lb, true);
    const a = opened[0][0], b = opened[3][4];
    opened[0][0] = b; opened[3][4] = a;                                         // FILM 1 <-> FILM 20
    applyCurvesBin(opened, readCurvesBin(cb));
    expect(opened[3][4]!.mix).toEqual(bank[0][0]!.mix);
    expect(opened[0][0]!.rgb ?? null).toEqual(bank[3][4]!.rgb ?? null);
  });

  it('leaves a film changed since alone, and says how many matched', () => {
    const opened = readProfiles(lb, true);
    opened[0][0]!.sat[0] = opened[0][0]!.sat[0] === 5 ? 4 : opened[0][0]!.sat[0] + 1;   // changed: its record no longer matches
    const mine = { r: [1, 0, 0, 0, 0], g: [0, 0, 0, 0, 0], b: [0, 0, 0, 0, 0] };
    opened[0][0]!.rgb = mine;
    expect(applyCurvesBin(opened, readCurvesBin(cb))).toEqual({ matched: 19, looks: 20 });
    expect(opened[0][0]!.rgb).toEqual(mine);
  });

  it('matches nothing in a list of other films', () => {
    const other = emptyBank(); other[0][0] = cloneLook(bank[0][0]!); other[0][0]!.tone.blacks = 3; delete other[0][0]!.rgb; delete other[0][0]!.mix;
    expect(applyCurvesBin(other, readCurvesBin(cb))).toEqual({ matched: 0, looks: 1 });
    expect(other[0][0]!.rgb).toBeUndefined();
  });

  it('clears curves and mix where the file has a flat entry for the film (as the camera shows it)', () => {
    const flat = standard(); flat.flat().forEach((l) => { delete l!.rgb; delete l!.mix; });
    const opened = standard();                                                   // still has the library's curves
    applyCurvesBin(opened, readCurvesBin(curvesBin(profilesBin(flat, 28), flat)));
    expect(opened.flat().some((l) => l?.rgb || l?.mix)).toBe(false);
  });

  it('refuses a file the camera would refuse', () => {
    const bad = (f: (b: Uint8Array) => void) => { const b = cb.slice(); f(b); return () => readCurvesBin(b); };
    expect(bad((b) => { b[0] = 0x58; })).toThrow(/start/);
    expect(bad((b) => { b[40] ^= 1; })).toThrow(/check sum/);
    expect(() => readCurvesBin(cb.subarray(0, 400))).toThrow(/bytes/);
    // an entry with -8 (refused by the camera), its file CRC made right so only the range check catches it
    const neg = cb.slice(); neg[36] = (neg[36] & 0xf0) | 8; new DataView(neg.buffer).setUint32(8, crc32(neg.subarray(12)), true);
    expect(() => readCurvesBin(neg)).toThrow(/out of range/);
  });
});
