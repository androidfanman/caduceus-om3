// Your own film sims ("User created" in the Film sims window): saved apart from the lists, in this browser.
import { describe, expect, it } from 'vitest';
import { blankLook } from '../src/pack';
import { putSaved, readSaved, savedCopy, savedIndex, writeSaved } from '../src/saved';

const look = (name: string, hue0 = 0) => { const l = blankLook('colour', name); l.hue[0] = hue0; l.notes = 'test'; return l; };

describe('saved film sims', () => {
  it('saves a copy that later edits to the look do not change', () => {
    const l = look('Test look', 2);
    const { looks } = putSaved([], l);
    l.hue[0] = -3;
    expect(looks[0].hue[0]).toBe(2);
    expect(looks[0].name).toBe('Test look');
  });

  it('the same name (any case) replaces; a new name is added at the end', () => {
    let r = putSaved([], look('One', 1));
    r = putSaved(r.looks, look('Two', 2));
    expect(r.replaced).toBe(false);
    r = putSaved(r.looks, look(' one ', 5));
    expect(r.replaced).toBe(true);
    expect(r.looks.map((x) => [x.name, x.hue[0]])).toEqual([[' one ', 5], ['Two', 2]]);
    expect(savedIndex(r.looks, 'TWO')).toBe(1);
    expect(savedIndex(r.looks, 'Three')).toBe(-1);
  });

  it('leaves out the app-only built-in origin, so a saved film stands on its own', () => {
    const l = Object.assign(look('From Portra'), { origin: 'film:Portra 400', lib: 'abc' });
    const c = savedCopy(l);
    expect(c.origin).toBeUndefined();
    expect(c.lib).toBeUndefined();
  });

  it('round-trips through storage, curves and mix included; broken or missing storage gives none', () => {
    const l = look('Test look', 3);
    l.rgb = { r: [1, 1, 2, 2, 3], g: [0, 0, 0, 0, 0], b: [0, -1, 0, 1, 1] };
    l.mix = [1, 1, -2, -3, 2, -1];
    const back = readSaved(writeSaved(putSaved([], l).looks));
    expect(back).toHaveLength(1);
    expect(back[0]).toEqual(savedCopy(l));
    expect(readSaved(null)).toEqual([]);
    expect(readSaved('not json')).toEqual([]);
    expect(readSaved(JSON.stringify({ looks: [{ bad: 1 }, JSON.parse(writeSaved([l])).looks[0]] }))).toHaveLength(1);
  });
});
