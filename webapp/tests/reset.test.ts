import { describe, expect, it } from 'vitest';
import libraryJson from '../src/data/library.json';
import { blankLook, parsePack } from '../src/pack';
import { fromLibrary, libraryOrigin, resetLook } from '../src/reset';

const LIB = parsePack(libraryJson);

describe('reset', () => {
  it('a library look gets its shipped values back', () => {
    const l = fromLibrary(LIB.looks[0]);
    l.hue = l.hue.map((v) => v + 1); l.notes = 'changed'; l.wb = { a_b: 3, g_m: -2 };
    const r = resetLook(l, LIB);
    expect(r.hue).toEqual(LIB.looks[0].hue);
    expect(r.wb).toEqual(LIB.looks[0].wb);
    expect(r.name).toBe(LIB.looks[0].name);
  });

  it('a renamed library look keeps its name if the shipped one is taken', () => {
    const l = { ...fromLibrary(LIB.looks[0]), name: 'Mine' };
    const r = resetLook(l, LIB, [LIB.looks[0].name]);
    expect(r.name).toBe('Mine');
    expect(r.hue).toEqual(LIB.looks[0].hue);
  });

  it('a look of the retired Nostalgic resets to Provia 400', () => {
    const l = { ...blankLook('colour', 'Nostalgic'), origin: 'Nostalgic' };
    expect(libraryOrigin(l, LIB)?.name).toBe('Provia 400');
  });

  it('a non-library look resets to neutral, keeping name, kind and notes', () => {
    const l = { ...blankLook('colour', 'Own look'), hue: new Array(12).fill(2), notes: 'mine' };
    const r = resetLook(l, LIB);
    expect(r.name).toBe('Own look');
    expect(r.notes).toBe('mine');
    expect([...r.hue, ...r.light, ...r.sat].every((v) => v === 0)).toBe(true);
    expect(r.tone).toEqual({ highlights: 0, shadows: 0, midtones: 0, blacks: 0, whites: 0 });
  });
});
