import { describe, expect, it } from 'vitest';
import { CHART_DEFAULT, chartLight, lightColor, lightKelvin, renderChart, sunKelvin, wbKelvin, type ChartLight } from '../src/lightbox';

const px = (im: { width: number; data: Uint8ClampedArray }, u: number, v: number, h: number) => {
  const o = (Math.round(v * h) * im.width + Math.round(u * im.width)) * 4;
  return [im.data[o], im.data[o + 1], im.data[o + 2]];
};
// the middle of the grey patch in column c (row 1)
const grey = (im: { width: number; height: number; data: Uint8ClampedArray }, c: number) => {
  const W = im.width, H = im.height, cx0 = 0.045 * W, pad = 0.022 * W, gx = (W - 2 * cx0 - 2 * pad) / 12, cy0 = 0.06 * H, gy = (H - 2 * cy0 - 2 * pad) / 5;
  return px(im, (cx0 + pad + gx * (c + 0.5)) / W, (cy0 + pad + gy * 0.5) / H, H);
};
const L = (p: Partial<ChartLight>): ChartLight => ({ ...CHART_DEFAULT, ...p });

describe('light box', () => {
  it('6500 K is white and warm light is red-heavy', () => {
    const w = lightColor(6504); expect(w[0]).toBeCloseTo(1, 2); expect(w[2]).toBeCloseTo(1, 2);
    const t = lightColor(2850); expect(t[0]).toBeGreaterThan(t[1]); expect(t[1]).toBeGreaterThan(t[2]);
    const s = lightColor(9000); expect(s[2]).toBeGreaterThan(s[0]);
  });
  it('the sun warms toward the horizon', () => {
    expect(sunKelvin(90)).toBeGreaterThan(5300); expect(sunKelvin(5)).toBeLessThan(3800); expect(sunKelvin(2)).toBeLessThan(sunKelvin(30));
  });
  it('Auto WB keeps greys grey in daylight and tungsten', () => {
    for (const source of ['sun', 'shade', 'cloudy', 'tungsten', 'fluor'] as const) {
      const [r, g, b] = grey(renderChart(L({ source }), 600), 6);
      expect(Math.abs(r - g)).toBeLessThanOrEqual(4); expect(Math.abs(b - g)).toBeLessThanOrEqual(4);
    }
  });
  it('a fixed WB shows the light\'s colour', () => {
    const [r, , b] = grey(renderChart(L({ source: 'tungsten', wb: 'sunny' }), 600), 6); expect(r).toBeGreaterThan(b + 40);
    const [r2, , b2] = grey(renderChart(L({ source: 'shade', wb: 'sunny' }), 600), 6); expect(b2).toBeGreaterThan(r2 + 8);
    const [r3, , b3] = grey(renderChart(L({ source: 'sun', sun: 60, wb: 'custom', kelvin: 9000 }), 600), 6); expect(r3).toBeGreaterThan(b3 + 15);
  });
  it('a street lamp stays orange under Auto WB', () => {
    const p = L({ source: 'street' }); expect(wbKelvin(p)).toBeGreaterThan(lightKelvin(p));
    const [r, , b] = grey(renderChart(p, 600), 6); expect(r).toBeGreaterThan(b + 20);
  });
  it('brightness and shadow darken, grey ramp rises', () => {
    const a = grey(renderChart(L({}), 600), 6)[1], d = grey(renderChart(L({ ev: -6 }), 600), 6)[1];
    expect(d).toBeLessThan(a - 30);
    const sh = renderChart(L({ shadow: 50 }), 600);
    expect(grey(sh, 11)[1]).toBeLessThan(grey(renderChart(L({}), 600), 11)[1] - 40);   // the right side is in shadow
    expect(grey(sh, 11)[2]).toBeGreaterThan(grey(sh, 11)[0]);                            // and bluer
    const im = renderChart(L({}), 600); let last = -1;
    for (let c = 0; c < 12; c++) { const g = grey(im, c)[1]; expect(g).toBeGreaterThan(last); last = g; }
  });
  it('cleans stored settings', () => {
    expect(chartLight(null)).toEqual(CHART_DEFAULT);
    expect(chartLight({ source: 'moon', sun: 500, ev: -99, wb: 'x', kelvin: 123456 })).toEqual({ ...CHART_DEFAULT, sun: 90, ev: -9, kelvin: 14000 });
  });
});
