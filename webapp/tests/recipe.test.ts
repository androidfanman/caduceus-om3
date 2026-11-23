// A readable recipe .json (name, photo_code, rgb_curves, colour_mix, …): Open… makes the look from its photo code
// and adds the curves and mix, which the code does not hold.
import { describe, expect, it } from 'vitest';
import { lookFromPhotoCode } from '../src/om3';
import { isRecipe, lookFromRecipe } from '../src/recipe';

// written by the firmware (om-emu, test dr4) for FILM 19 of the test card
const CODE = 'om3.1.AAAAAAAAAQAAAAAADwAAEQAAAAAPABDwABAAAAAAAAA';

describe('recipe .json', () => {
  it('is told apart from other .json', () => {
    expect(isRecipe({ name: 'x', photo_code: CODE })).toBe(true);
    expect(isRecipe({ name: 'x', hue: [] })).toBe(false);
    expect(isRecipe({ photo_code: 'om3.1.short' })).toBe(false);
    expect(isRecipe([CODE])).toBe(false);
  });

  it('takes every camera setting from the photo code, the name, the curves and the mix', () => {
    const l = lookFromRecipe({
      name: 'Test look', photo_code: CODE, blacks: 99,   // readable fields are not read: the code holds them
      rgb_curves: { R: [1, 1, 2, 2, 3], G: [0, 0, 0, 0, 0], B: [0, -1, 0, 1, 1] },
      colour_mix: { R_hue: 1, R_strength: 1, G_hue: -2, G_strength: -3, B_hue: 2, B_strength: -1 },
    });
    const fromCode = lookFromPhotoCode(CODE);
    expect(l.name).toBe('Test look');
    expect({ ...l, name: '', rgb: undefined, mix: undefined }).toEqual({ ...fromCode, name: '', rgb: undefined, mix: undefined });
    expect(l.rgb).toEqual({ r: [1, 1, 2, 2, 3], g: [0, 0, 0, 0, 0], b: [0, -1, 0, 1, 1] });
    expect(l.mix).toEqual([1, 1, -2, -3, 2, -1]);
  });

  it('flat or missing curves and mix leave none; a long name is cut to the camera\'s 15', () => {
    const l = lookFromRecipe({ name: 'A very long look name', photo_code: CODE, rgb_curves: { R: [0, 0, 0, 0, 0] }, colour_mix: { R_hue: 0 } });
    expect(l.rgb).toBeUndefined();
    expect(l.mix).toBeUndefined();
    expect(l.name).toBe('A very long loo');
  });

  it('refuses curves or a mix it cannot read', () => {
    expect(() => lookFromRecipe({ photo_code: CODE, rgb_curves: { R: [9, 0, 0, 0, 0] } })).toThrow(/rgb_curves/);
    expect(() => lookFromRecipe({ photo_code: CODE, colour_mix: { G_hue: 8 } })).toThrow(/colour_mix/);
  });
});
