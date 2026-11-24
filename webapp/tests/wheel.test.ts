// "Sat. All" on the colour wheel (v0.41): all 12 saturations move together, each within ±5.
import { describe, expect, it } from 'vitest';
import { satAllValue, shiftSat } from '../src/wheel';

describe('Sat. All', () => {
  it('moves every colour by the same step', () => {
    expect(shiftSat([0, 1, -2, 0, 0, 0, 0, 0, 0, 3, 0, 0], 2)).toEqual([2, 3, 0, 2, 2, 2, 2, 2, 2, 5, 2, 2]);
  });
  it('keeps each colour within ±5 (a colour at the end stays there)', () => {
    expect(shiftSat([5, 4, -5, 0, 0, 0, 0, 0, 0, 0, 0, 0], 2).slice(0, 3)).toEqual([5, 5, -3]);
    expect(shiftSat([-5, -4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], -3).slice(0, 3)).toEqual([-5, -5, -3]);
  });
  it('shows the mean, rounded', () => {
    expect(satAllValue(new Array(12).fill(0))).toBe(0);
    expect(satAllValue([1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0])).toBe(1);   // 0.5 rounds up
    expect(satAllValue([-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2])).toBe(-2);
  });
});
