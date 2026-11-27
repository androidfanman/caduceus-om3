// Capture One styles (.costyle, #103): read into the same colour fit as LUTs and Lightroom presets. Made-up styles.
import { describe, expect, it } from 'vitest';
import { captureOneExtras, captureOneTransform, parseCaptureOne, type RGB } from '../src/convert';

const style = (...e: [string, string][]) => `<?xml version="1.0"?>\n<SL Engine="1300">\n${e.map(([k, v]) => `\t<E K="${k}" V="${v}" />`).join('\n')}\n</SL>`;
const grey = (v: number): RGB => [v, v, v];
const close = (a: RGB, b: RGB, d = 1e-3) => a.every((x, i) => Math.abs(x - b[i]) < d);

describe('Capture One styles', () => {
  it('reads the settings and the name; refuses other files', () => {
    const p = parseCaptureOne(style(['Name', 'Test &amp; Look'], ['Contrast', '12'], ['GradationCurve', '0,0;1,1']), 'x.costyle');
    expect(p.name).toBe('Test & Look');
    expect(p.e.Contrast).toBe('12');
    expect(parseCaptureOne(style(['Saturation', '5']), 'My Style.costyle').name).toBe('My Style');
    expect(() => parseCaptureOne('<x:xmpmeta/>', 'a.costyle')).toThrow(/Capture One/);
  });

  it('a style with only neutral values changes nothing', () => {
    const tf = captureOneTransform(parseCaptureOne(style(['Contrast', '0'], ['GradationCurve', '0,0;1,1'], ['ColorBalance', '1;1;1'], ['Highlight', '1;1;1;1'], ['Midtone', '0;0;0;0'])));
    for (const c of [grey(0.1), grey(0.5), [0.8, 0.3, 0.2] as RGB]) expect(close(tf(c), c)).toBe(true);
  });

  it('curves, Levels, Color Balance and saturation move colours the expected way', () => {
    const red = captureOneTransform(parseCaptureOne(style(['GradationCurveRed', '0,0;0.5,0.6;1,1'])));
    expect(red(grey(0.5))[0]).toBeGreaterThan(0.55);
    expect(red(grey(0.5))[2]).toBeCloseTo(0.5, 3);
    const fade = captureOneTransform(parseCaptureOne(style(['TargetShadow', '0;0;0;0.1'])));
    expect(fade(grey(0))[1]).toBeCloseTo(0.1, 3);                 // the master's output black lifted
    const warmHi = captureOneTransform(parseCaptureOne(style(['ColorBalanceHighlight', '1.1;1;0.9'])));
    const hi = warmHi(grey(0.9)), lo = warmHi(grey(0.1));
    expect(hi[0] - hi[2]).toBeGreaterThan(0.05);                  // warmer highlights
    expect(Math.abs(lo[0] - lo[2])).toBeLessThan(0.01);           // shadows nearly untouched
    const flat = captureOneTransform(parseCaptureOne(style(['Saturation', '-100'])));
    const f = flat([0.8, 0.3, 0.2]);
    expect(Math.max(...f) - Math.min(...f)).toBeLessThan(1e-3);   // no colour left
  });

  it('carries grain and clarity over, and names what it leaves out', () => {
    const x = captureOneExtras(parseCaptureOne(style(['FilmGrainAmount', '40'], ['Clarity', '30'], ['ColorCorrections', '1,1,0,1,-5,0.1,200,40,60,-9,9,-80,19,25,0,0,0,0'], ['Contrast', '5'], ['NoiseReductionLuminance', '0'])));
    expect(x.look.film_grain).toBe(2);
    expect(x.look.effect).toEqual({ type: 'clarity', strength: 2 });
    expect(x.dropped).toEqual(['Color Editor (its format is not published)']);
  });
});
