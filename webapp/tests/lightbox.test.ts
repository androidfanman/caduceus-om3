import { describe, expect, it } from 'vitest';
import { CHART_DEFAULT, chartLight, lightColor, lightKelvin, patchCentre, renderChart, sunHeight, sunKelvin, wbKelvin, type ChartLight } from '../src/lightbox';

const px = (im: { width: number; data: Uint8ClampedArray }, u: number, v: number, h: number) => {
  const o = (Math.round(v * h) * im.width + Math.round(u * im.width)) * 4;
  return [im.data[o], im.data[o + 1], im.data[o + 2]];
};
type Im = { width: number; height: number; data: Uint8ClampedArray };
const at = (im: Im, col: number, row: number) => { const [u, v] = patchCentre(col, row); return px(im, u, v, im.height); };
// grey c: 0 black .. 5 white (the left column, white at the top)
const grey = (im: Im, c: number) => at(im, 0, 5 - c);
const L = (p: Partial<ChartLight>): ChartLight => ({ ...CHART_DEFAULT, ...p });

describe('light box', () => {
  it('6500 K is white and warm light is red-heavy', () => {
    const w = lightColor(6504); expect(w[0]).toBeCloseTo(1, 2); expect(w[2]).toBeCloseTo(1, 2);
    const t = lightColor(2850); expect(t[0]).toBeGreaterThan(t[1]); expect(t[1]).toBeGreaterThan(t[2]);
    const s = lightColor(9000); expect(s[2]).toBeGreaterThan(s[0]);
  });
  it('the sun warms toward the horizon', () => {
    expect(sunHeight(720)).toBeCloseTo(70, 5); expect(sunHeight(540)).toBeCloseTo(sunHeight(900), 5); expect(sunHeight(360)).toBe(1);
    expect(lightKelvin(L({ time: 720 }))).toBeGreaterThan(5300); expect(lightKelvin(L({ time: 375 }))).toBeLessThan(3600);
    expect(sunKelvin(90)).toBeGreaterThan(5300); expect(sunKelvin(5)).toBeLessThan(3800); expect(sunKelvin(2)).toBeLessThan(sunKelvin(30));
  });
  it('Auto WB keeps greys grey in daylight and tungsten', () => {
    for (const source of ['sun', 'shade', 'cloudy', 'tungsten', 'fluor'] as const) {
      const [r, g, b] = grey(renderChart(L({ source }), 600), 3);
      expect(Math.abs(r - g)).toBeLessThanOrEqual(4); expect(Math.abs(b - g)).toBeLessThanOrEqual(4);
    }
  });
  it('a fixed WB shows the light\'s colour', () => {
    const [r, , b] = grey(renderChart(L({ source: 'tungsten', wb: 'sunny' }), 600), 3); expect(r).toBeGreaterThan(b + 40);
    const [r2, , b2] = grey(renderChart(L({ source: 'shade', wb: 'sunny' }), 600), 3); expect(b2).toBeGreaterThan(r2 + 8);
    const [r3, , b3] = grey(renderChart(L({ source: 'sun', time: 720, wb: 'custom', kelvin: 9000 }), 600), 3); expect(r3).toBeGreaterThan(b3 + 15);
  });
  it('a street lamp stays orange under Auto WB', () => {
    const p = L({ source: 'street' }); expect(wbKelvin(p)).toBeGreaterThan(lightKelvin(p));
    const [r, , b] = grey(renderChart(p, 600), 3); expect(r).toBeGreaterThan(b + 20);
  });
  it('brightness and shadow darken, grey ramp rises', () => {
    const a = grey(renderChart(L({}), 600), 3)[1], d = grey(renderChart(L({ ev: -6 }), 600), 3)[1];
    expect(d).toBeLessThan(a - 30);
    const sh = renderChart(L({ shadow: 50 }), 600), lit = renderChart(L({}), 600);
    const lum = (c: number[]) => c[0] + c[1] + c[2];
    expect(lum(at(sh, 2, 0))).toBeLessThan(lum(at(lit, 2, 0)) - 60);                       // morning / noon: the right side is in shadow
    expect(at(sh, 0, 5)).toEqual(at(lit, 0, 5));                                            // the bottom left is still lit
    expect(grey(renderChart(L({ shadow: 100 }), 600), 5)[2]).toBeGreaterThan(grey(renderChart(L({ shadow: 100 }), 600), 5)[0]);   // shade is bluer
    const pm = renderChart(L({ shadow: 50, time: 900 }), 600), pmLit = renderChart(L({ time: 900 }), 600);   // afternoon: from the left
    expect(grey(pm, 5)[1]).toBeLessThan(grey(pmLit, 5)[1] - 40); expect(at(pm, 2, 5)).toEqual(at(pmLit, 2, 5));
    const im = renderChart(L({}), 600); let last = -1;
    for (let c = 0; c < 6; c++) { const g = grey(im, c)[1]; expect(g).toBeGreaterThan(last); last = g; }
  });
  it('cleans stored settings', () => {
    expect(chartLight(null)).toEqual(CHART_DEFAULT);
    expect(chartLight({ source: 'moon', time: 5000, ev: -99, wb: 'x', kelvin: 123456 })).toEqual({ ...CHART_DEFAULT, time: 1080, ev: -9, kelvin: 14000 });
  });
});
