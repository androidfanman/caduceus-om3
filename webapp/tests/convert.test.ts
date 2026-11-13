// LUT / Lightroom preset -> OM-3 film. All grades here are made up for the test (no real LUTs or presets).
import { describe, expect, it } from 'vitest';
import { cubeApply, fitLook, hsvToRgb, lab, lightroomExtras, lightroomTransform, looksLikeLog, parseCube, parseLightroom, rgbToHsv, type RGB, type Transform } from '../src/convert';

/** A .cube text of `tf` at size n. */
function makeCube(tf: Transform, n = 17, title = 'Test warm'): string {
  const lines = [`TITLE "${title}"`, `LUT_3D_SIZE ${n}`];
  for (let b = 0; b < n; b++) for (let g = 0; g < n; g++) for (let r = 0; r < n; r++) {
    const o = tf([r / (n - 1), g / (n - 1), b / (n - 1)]);
    lines.push(o.map((v) => v.toFixed(6)).join(' '));
  }
  return lines.join('\n');
}
const warmFaded: Transform = ([r, g, b]) => {
  const [h, s, v] = rgbToHsv([r, g, b]);
  const c = hsvToRgb(h, s * 0.75, v);
  return [Math.min(1, c[0] * 1.06 + 0.03), Math.min(1, c[1] * 1.0 + 0.03), Math.min(1, c[2] * 0.9 + 0.05)];
};
const dE = (a: RGB, b: RGB) => { const x = lab(a), y = lab(b); return Math.hypot(x[0] - y[0], x[1] - y[1], x[2] - y[2]); };

describe('.cube', () => {
  it('reads and applies a 3D LUT (identity and a grade)', () => {
    const id = parseCube(makeCube((c) => c, 9, 'Identity'));
    expect(id.size).toBe(9); expect(id.title).toBe('Identity');
    for (const c of [[0.1, 0.5, 0.9], [0.33, 0.66, 0.2]] as RGB[]) expect(dE(cubeApply(id, c), c)).toBeLessThan(0.5);
    const w = parseCube(makeCube(warmFaded));
    for (const c of [[0.8, 0.3, 0.2], [0.2, 0.5, 0.8], [0.5, 0.5, 0.5]] as RGB[]) expect(dE(cubeApply(w, c), warmFaded(c))).toBeLessThan(1.5);
  });
  it('reads a 1D LUT and DOMAIN lines', () => {
    const one = parseCube('LUT_1D_SIZE 3\nDOMAIN_MIN 0 0 0\nDOMAIN_MAX 1 1 1\n0 0 0\n0.6 0.5 0.4\n1 1 1\n');
    expect(cubeApply(one, [0.5, 0.5, 0.5]).map((v) => +v.toFixed(2))).toEqual([0.6, 0.5, 0.4]);
  });
  it('refuses a file without a size', () => { expect(() => parseCube('0 0 0\n1 1 1')).toThrow(/LUT_3D_SIZE/); });
  it('spots Log LUTs by name and by effect', () => {
    expect(looksLikeLog('SLog3 to Rec709', (c) => c)).toBe(true);
    expect(looksLikeLog('Warm Fade', warmFaded)).toBe(false);
    const harsh: Transform = (c) => c.map((v) => Math.min(1, Math.max(0, (v - 0.5) * 2.6 + 0.5))) as RGB;
    expect(looksLikeLog('Grade', (c) => { const [h, s, v] = rgbToHsv(harsh(c)); return hsvToRgb(h, Math.min(1, s * 2), v); })).toBe(true);
  });
  it('fits a warm, faded LUT closer than the camera\'s normal look', async () => {
    const r = await fitLook((c) => cubeApply(parseCube(makeCube(warmFaded)), c), 'Warm fade');
    expect(r.after).toBeLessThan(r.before * 0.6);
    expect(r.look.wb && r.look.wb.a_b).toBeGreaterThan(0);                // warmer
    expect(r.look.sat.reduce((a, b) => a + b, 0)).toBeLessThan(0);         // less saturated
  });
});

const XMP = `<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
 <rdf:Description rdf:about="" xmlns:crs="http://ns.adobe.com/camera-raw-settings/1.0/"
   crs:PresetType="Normal" crs:Version="15.0" crs:IncrementalTemperature="+15" crs:Contrast2012="-20"
   crs:Shadows2012="+25" crs:SaturationAdjustmentBlue="-40" crs:HueAdjustmentGreen="-30"
   crs:SplitToningShadowHue="200" crs:SplitToningShadowSaturation="20" crs:SplitToningHighlightHue="40"
   crs:SplitToningHighlightSaturation="25" crs:GrainAmount="30" crs:PostCropVignetteAmount="-25" crs:Dehaze="10">
  <crs:Name><rdf:Alt><rdf:li xml:lang="x-default">Test Cool Shadows</rdf:li></rdf:Alt></crs:Name>
  <crs:ToneCurvePV2012><rdf:Seq><rdf:li>0, 20</rdf:li><rdf:li>128, 128</rdf:li><rdf:li>255, 240</rdf:li></rdf:Seq></crs:ToneCurvePV2012>
 </rdf:Description></rdf:RDF></x:xmpmeta>`;
const LRT = `s = {
	id = "0000", internalName = "Test Old Preset", title = "Test Old Preset", type = "Develop",
	value = { settings = { Exposure2012 = 0.2, Vibrance = -20, HueAdjustmentRed = 10, ToneCurvePV2012 = { 0, 0, 64, 50, 255, 255, }, }, uuid = "x", },
	version = 0,
}`;

describe('Lightroom presets', () => {
  it('reads an .xmp preset', () => {
    const p = parseLightroom(XMP, 'x.xmp');
    expect(p.name).toBe('Test Cool Shadows');
    expect(p.s.IncrementalTemperature).toBe(15); expect(p.s.SaturationAdjustmentBlue).toBe(-40);
    expect(p.curves.ToneCurvePV2012).toEqual([[0, 20], [128, 128], [255, 240]]);
    const ex = lightroomExtras(p);
    expect(ex.look.film_grain).toBe(2); expect(ex.look.vignette).toBe(-1);
    expect(ex.dropped).toContain('Dehaze');
  });
  it('reads an .lrtemplate preset', () => {
    const p = parseLightroom(LRT, 'old.lrtemplate');
    expect(p.name).toBe('Test Old Preset');
    expect(p.s.Exposure2012).toBe(0.2); expect(p.s.Vibrance).toBe(-20);
    expect(p.curves.ToneCurvePV2012).toEqual([[0, 0], [64, 50], [255, 255]]);
  });
  it('approximates the preset: faded blacks, warmer, bluer shadows, less blue', () => {
    const tf = lightroomTransform(parseLightroom(XMP));
    expect(tf([0, 0, 0])[1]).toBeGreaterThan(0.05);                         // the curve lifts black
    const grey = tf([0.75, 0.75, 0.75]); expect(grey[0]).toBeGreaterThan(grey[2]);   // warmer highlights
    const [, s] = rgbToHsv(tf(hsvToRgb(230, 0.8, 0.7))); expect(s).toBeLessThan(0.8);
  });
  it('fits a preset closer than the camera\'s normal look', async () => {
    const r = await fitLook(lightroomTransform(parseLightroom(XMP)), 'Cool shadows');
    expect(r.after).toBeLessThan(r.before * 0.7);
  });
});
