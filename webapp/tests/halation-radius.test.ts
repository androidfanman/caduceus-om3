// Halation Radius (v0.40.3, by fernandezk26): Bloom / Tight / Medium / Wide. Not in any card file; photo codes carry
// it in byte 63 bits 2..3 (firmware ex_rz), beside the split-tone half steps in bits 0..1.
import { describe, expect, it } from 'vitest';
import { blankLook, parseLook } from '../src/pack';
import { lookFromPhotoCode, photoCodeOf, recordFromPhotoCode } from '../src/om3';
import { renderLook } from '../src/preview';

describe('Halation Radius', () => {
  it('round-trips through the photo code, the split half steps kept', () => {
    for (const r of [0, 1, 2, 3]) {
      const l = { ...blankLook('colour', 'Test look'), halation: 3, split: { sh_color: 8, sh: 1.5, hl_color: 1, hl: 2.5 }, ...(r ? { halation_radius: r } : {}) };
      const code = photoCodeOf(l);
      expect(recordFromPhotoCode(code)[63]).toBe(3 | (r << 2));
      const back = lookFromPhotoCode(`Caduceus FILM 1 Test ${code}`);
      expect(back.halation_radius).toBe(r || undefined);
      expect(back.split).toEqual(l.split);
    }
  });

  it('a look file keeps 1..3 and drops anything else', () => {
    const j = (v: unknown) => parseLook({ ...blankLook('colour', 'x'), halation_radius: v }).halation_radius;
    expect([j(1), j(2), j(3)]).toEqual([1, 2, 3]);
    expect([j(0), j(4), j('wide'), j(undefined)]).toEqual([undefined, undefined, undefined, undefined]);
  });

  it('the preview spreads the glow further at a wider radius', () => {
    // a dark frame with one bright square light in the middle
    const w = 1296, h = 972, src = { width: w, height: h, data: new Uint8ClampedArray(w * h * 4) } as ImageData;
    for (let i = 0; i < w * h; i++) { src.data.set([20, 20, 20, 255], i * 4); }
    for (let y = 480; y < 492; y++) for (let x = 642; x < 654; x++) src.data.set([255, 255, 255, 255], (y * w + x) * 4);
    const red = (r: number) => {
      const out = { width: w, height: h, data: new Uint8ClampedArray(w * h * 4) } as ImageData;
      renderLook(src, out, { ...blankLook('colour', 'x'), lens_correction: true, halation: 5, ...(r ? { halation_radius: r } : {}) }, { advice: true, camera: 'om3' });
      const at = (x: number) => out.data[(486 * w + x) * 4];   // red at the light's row, x px from the left
      return at(654 + 12) - at(5);                              // glow 12 px (about 50 camera px) right of the light, against the far edge
    };
    const tight = red(1), medium = red(2), wide = red(3);   // Medium is tuned to Bloom's edge glow (GAIN)
    expect(wide).toBeGreaterThan(medium);
    expect(medium).toBeGreaterThan(tight);
  });
});
