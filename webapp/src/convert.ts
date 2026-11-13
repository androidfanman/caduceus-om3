// Make an OM-3 film from someone's own colour grade: a .cube LUT or a Lightroom preset (.xmp or .lrtemplate).
// Nothing here copies the grade: it is run on a fixed set of test colours (greys, skin, sky, foliage and a ring of
// hues at several strengths), and the camera's own settings that come closest are searched for, using the Control
// Panel's preview, which is fitted to the OM-3 (research/film-grading/). The result is an approximation: the camera
// has 12 colour sectors, a luminance tone curve, a WB shift and split toning, and a LUT can do much more.
// The user's file stays in the browser; it is never stored or uploaded.
import { renderLook } from './preview';
import { zeroTone, type Look } from './pack';
import { OM3 } from './om3';

export type RGB = [number, number, number];
export type Transform = (c: RGB) => RGB;

// ---------------------------------------------------------------- colour helpers
const clamp01 = (x: number) => (x < 0 ? 0 : x > 1 ? 1 : x);
const dec = (x: number) => (x <= 0.04045 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4));
const enc = (x: number) => (x <= 0.0031308 ? 12.92 * x : 1.055 * Math.pow(Math.max(0, x), 1 / 2.4) - 0.055);
const luma = (c: RGB) => 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];

export function hsvToRgb(h: number, s: number, v: number): RGB {
  h = ((h % 360) + 360) % 360;
  const f = (n: number) => { const k = (n + h / 60) % 6; return v - v * s * Math.max(0, Math.min(k, 4 - k, 1)); };
  return [f(5), f(3), f(1)];
}
export function rgbToHsv(c: RGB): [number, number, number] {
  const [r, g, b] = c, mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn;
  let h = 0;
  if (d > 1e-9) h = mx === r ? 60 * (((g - b) / d) % 6) : mx === g ? 60 * ((b - r) / d + 2) : 60 * ((r - g) / d + 4);
  return [(h + 360) % 360, mx > 1e-9 ? d / mx : 0, mx];
}
/** sRGB (0..1) -> CIE Lab (D65). */
export function lab(c: RGB): RGB {
  const [r, g, b] = c.map(dec);
  const X = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047, Y = 0.2126 * r + 0.7152 * g + 0.0722 * b, Z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  const f = (t: number) => (t > 0.008856 ? Math.cbrt(t) : 7.787 * t + 16 / 116);
  return [116 * f(Y) - 16, 500 * (f(X) - f(Y)), 200 * (f(Y) - f(Z))];
}

// ---------------------------------------------------------------- .cube
export interface Cube { title: string; size: number; dim: 1 | 3; min: RGB; max: RGB; data: Float32Array }

/** Parse a .cube file (Adobe / Resolve: 3D or 1D, DOMAIN_MIN / DOMAIN_MAX, red changing fastest). */
export function parseCube(text: string): Cube {
  let title = '', size = 0, dim: 1 | 3 = 3;
  let min: RGB = [0, 0, 0], max: RGB = [1, 1, 1];
  const vals: number[] = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const m = /^([A-Z_0-9]+)\s+(.*)$/.exec(line);
    if (m && !/^[-+\d.]/.test(line)) {
      const [, key, rest] = m;
      if (key === 'TITLE') title = rest.replace(/^"|"$/g, '');
      else if (key === 'LUT_3D_SIZE') { size = parseInt(rest, 10); dim = 3; }
      else if (key === 'LUT_1D_SIZE') { size = parseInt(rest, 10); dim = 1; }
      else if (key === 'DOMAIN_MIN') min = rest.split(/\s+/).map(Number) as RGB;
      else if (key === 'DOMAIN_MAX') max = rest.split(/\s+/).map(Number) as RGB;
      continue;                                   // LUT_3D_INPUT_RANGE and other keywords: ignored
    }
    const p = line.split(/\s+/).map(Number);
    if (p.length >= 3 && p.slice(0, 3).every(Number.isFinite)) vals.push(p[0], p[1], p[2]);
  }
  if (!size || size < 2 || size > 256) throw new Error('This .cube file has no LUT_3D_SIZE (or LUT_1D_SIZE).');
  const need = (dim === 3 ? size ** 3 : size) * 3;
  if (vals.length < need) throw new Error(`This .cube file is incomplete (${vals.length / 3} of ${need / 3} entries).`);
  return { title, size, dim, min, max, data: Float32Array.from(vals.slice(0, need)) };
}

/** Apply a parsed .cube to one colour (trilinear; 1D per channel). */
export function cubeApply(cb: Cube, c: RGB): RGB {
  const N = cb.size - 1;
  const t = c.map((v, i) => clamp01((v - cb.min[i]) / ((cb.max[i] - cb.min[i]) || 1)) * N);
  if (cb.dim === 1) {
    return t.map((x, ch) => { const a = Math.min(N - 1, Math.floor(x)), f = x - a; return cb.data[a * 3 + ch] * (1 - f) + cb.data[(a + 1) * 3 + ch] * f; }) as RGB;
  }
  const [x, y, z] = t, x0 = Math.min(N - 1, Math.floor(x)), y0 = Math.min(N - 1, Math.floor(y)), z0 = Math.min(N - 1, Math.floor(z));
  const fx = x - x0, fy = y - y0, fz = z - z0, S = cb.size;
  const at = (i: number, j: number, k: number, ch: number) => cb.data[((k * S + j) * S + i) * 3 + ch];
  const out: RGB = [0, 0, 0];
  for (let ch = 0; ch < 3; ch++) {
    const c00 = at(x0, y0, z0, ch) * (1 - fx) + at(x0 + 1, y0, z0, ch) * fx;
    const c10 = at(x0, y0 + 1, z0, ch) * (1 - fx) + at(x0 + 1, y0 + 1, z0, ch) * fx;
    const c01 = at(x0, y0, z0 + 1, ch) * (1 - fx) + at(x0 + 1, y0, z0 + 1, ch) * fx;
    const c11 = at(x0, y0 + 1, z0 + 1, ch) * (1 - fx) + at(x0 + 1, y0 + 1, z0 + 1, ch) * fx;
    out[ch] = clamp01((c00 * (1 - fy) + c10 * fy) * (1 - fz) + (c01 * (1 - fy) + c11 * fy) * fz);
  }
  return out;
}

/** True when a LUT looks made for Log video (flat footage in, normal video out): it says so in its name, or it
 *  stretches a normal photo's greys and colours far too much. */
export function looksLikeLog(name: string, tf: Transform): boolean {
  if (/(^|[^a-z])(s-?log|v-?log|log-?c|c-?log|f-?log|n-?log|d-?log|om-?log|log3?g?10|slog|vlog|logc|clog|flog|nlog|hlg|log)([^a-z]|$)|rec\.?\s?709|to\s?709|log2|log_to/i.test(name)) return true;
  const g1 = luma(tf([0.35, 0.35, 0.35])), g2 = luma(tf([0.6, 0.6, 0.6]));
  const slope = (g2 - g1) / 0.25;
  let gain = 0, n = 0;
  for (let h = 0; h < 360; h += 30) { const a = hsvToRgb(h, 0.3, 0.6), b = tf(a); gain += rgbToHsv(b)[1] / 0.3; n++; }
  return slope > 1.9 && gain / n > 1.7;
}

// ---------------------------------------------------------------- Lightroom presets
export interface LrPreset { name: string; s: Record<string, number>; curves: Record<string, [number, number][]>; strings: Record<string, string> }

/** Parse a Lightroom / Camera Raw preset: .xmp (crs: attributes or elements) or the older .lrtemplate (Lua). */
export function parseLightroom(text: string, fileName = ''): LrPreset {
  const s: Record<string, number> = {}, curves: Record<string, [number, number][]> = {}, strings: Record<string, string> = {};
  let name = fileName.replace(/\.(xmp|lrtemplate)$/i, '');
  if (/crs:|camera-raw-settings/i.test(text)) {
    for (const m of text.matchAll(/crs:([A-Za-z0-9]+)="([^"]*)"/g)) {
      const v = Number(m[2].replace(/^\+/, ''));
      if (Number.isFinite(v) && m[2] !== '') s[m[1]] = v; else strings[m[1]] = m[2];
    }
    for (const m of text.matchAll(/<crs:([A-Za-z0-9]+)>([\s\S]*?)<\/crs:\1>/g)) {
      const items = [...m[2].matchAll(/<rdf:li[^>]*>([^<]*)<\/rdf:li>/g)].map((x) => x[1].trim());
      if (/^ToneCurve/.test(m[1])) curves[m[1]] = items.map((p) => p.split(/\s*,\s*/).map(Number) as [number, number]).filter((p) => p.length === 2 && p.every(Number.isFinite));
      else if (m[1] === 'Name' && items[0]) name = items[0];
      else if (!/<rdf:/.test(m[2])) { const v = Number(m[2].trim().replace(/^\+/, '')); if (Number.isFinite(v)) s[m[1]] = v; }
    }
    if (strings.Name) name = strings.Name;
  } else if (/settings\s*=\s*\{/.test(text)) {
    const at = text.search(/settings\s*=\s*\{/);
    let depth = 0, i = text.indexOf('{', at), end = i;
    for (; end < text.length; end++) { if (text[end] === '{') depth++; else if (text[end] === '}' && --depth === 0) break; }
    const body = text.slice(i + 1, end);
    for (const m of body.matchAll(/([A-Za-z0-9_]+)\s*=\s*(\{[^{}]*\}|"[^"]*"|-?[\d.]+(?:e-?\d+)?|true|false)/g)) {
      const [, k, v] = m;
      if (v.startsWith('{')) {
        const nums = v.slice(1, -1).split(',').map((x) => Number(x.trim())).filter(Number.isFinite);
        if (/^ToneCurve/.test(k)) curves[k] = Array.from({ length: nums.length >> 1 }, (_, j) => [nums[2 * j], nums[2 * j + 1]] as [number, number]);
      } else if (v.startsWith('"')) strings[k] = v.slice(1, -1);
      else if (v === 'true' || v === 'false') s[k] = v === 'true' ? 1 : 0;
      else s[k] = Number(v);
    }
    const t = /title\s*=\s*(?:ZSTR\s*)?"([^"]*)"/.exec(text) ?? /internalName\s*=\s*"([^"]*)"/.exec(text);
    if (t) name = t[1].replace(/^\$\$\$\/[^=]*=/, '');
  } else throw new Error('This is not a Lightroom preset (.xmp or .lrtemplate) we can read.');
  return { name: name.trim() || 'Preset', s, curves, strings };
}

const LR_COLOURS = ['Red', 'Orange', 'Yellow', 'Green', 'Aqua', 'Blue', 'Purple', 'Magenta'];
const LR_CENTRES = [0, 30, 60, 120, 180, 240, 270, 300];
/** The settings of a preset this tool uses for the colour grade; the rest are reported as left out or mapped. */
const LR_USED = /^(Exposure2012|Exposure|Contrast2012|Contrast|Highlights2012|Shadows2012|Whites2012|Blacks2012|Temperature|Tint|IncrementalTemperature|IncrementalTint|Saturation|Vibrance|(Hue|Saturation|Luminance)Adjustment(Red|Orange|Yellow|Green|Aqua|Blue|Purple|Magenta)|SplitToning\w+|ColorGrade\w+|Parametric\w+|ToneCurve\w*)$/;

/** Weights of the 8 Lightroom colour bands for an HSV hue (linear between neighbouring band centres). */
function lrBands(h: number): number[] {
  const w = new Array(8).fill(0);
  for (let k = 0; k < 8; k++) {
    const a = LR_CENTRES[k], b = k < 7 ? LR_CENTRES[k + 1] : 360;
    const d = ((h - a) % 360 + 360) % 360;
    if (d <= b - a) { const f = d / (b - a); w[k] += 1 - f; w[(k + 1) % 8] += f; break; }
  }
  return w;
}
function curveFn(pts: [number, number][] | undefined): ((x: number) => number) | null {
  if (!pts || pts.length < 2) return null;
  const p = [...pts].sort((a, b) => a[0] - b[0]);
  if (p.every(([x, y]) => x === y)) return null;
  return (x: number) => {
    const X = x * 255;
    if (X <= p[0][0]) return p[0][1] / 255;
    for (let i = 1; i < p.length; i++) if (X <= p[i][0]) {
      const [x0, y0] = p[i - 1], [x1, y1] = p[i], f = (X - x0) / ((x1 - x0) || 1);
      const s = f * f * (3 - 2 * f);                               // smooth between the points, as Lightroom's curve
      return (y0 + (y1 - y0) * (0.5 * f + 0.5 * s)) / 255;
    }
    return p[p.length - 1][1] / 255;
  };
}
const bump = (x: number, c: number, w: number) => { const d = Math.abs(x - c) / w; return d >= 1 ? 0 : 0.5 + 0.5 * Math.cos(Math.PI * d); };

/** An approximation of what a Lightroom preset does to an already-rendered sRGB colour (Lightroom's own maths is
 *  not public): white balance and exposure in linear light, then the tone controls and curves, then the colour
 *  bands, saturation / vibrance and split toning / colour grading. */
export function lightroomTransform(p: LrPreset): Transform {
  const g = (k: string, d = 0) => (Number.isFinite(p.s[k]) ? p.s[k] : d);
  let temp = g('IncrementalTemperature'), tint = g('IncrementalTint');
  if ('Temperature' in p.s && !('IncrementalTemperature' in p.s)) temp = Math.max(-100, Math.min(100, (g('Temperature') - 5500) / 45));
  if ('Tint' in p.s && !('IncrementalTint' in p.s)) tint = Math.max(-100, Math.min(100, g('Tint') - 10));
  const exp = 'Exposure2012' in p.s ? g('Exposure2012') : g('Exposure');
  const con = ('Contrast2012' in p.s ? g('Contrast2012') : g('Contrast') / 2) / 100;
  const hi = g('Highlights2012') / 100, sh = g('Shadows2012') / 100, wh = g('Whites2012') / 100, bl = g('Blacks2012') / 100;
  const par = ['ParametricShadows', 'ParametricDarks', 'ParametricLights', 'ParametricHighlights'].map((k) => g(k) / 100);
  const split = [g('ParametricShadowSplit', 25), g('ParametricMidtoneSplit', 50), g('ParametricHighlightSplit', 75)].map((v) => v / 100);
  const parC = [split[0] / 2, (split[0] + split[1]) / 2, (split[1] + split[2]) / 2, (split[2] + 1) / 2];
  const main = curveFn(p.curves.ToneCurvePV2012 ?? p.curves.ToneCurve);
  const cR = curveFn(p.curves.ToneCurvePV2012Red), cG = curveFn(p.curves.ToneCurvePV2012Green), cB = curveFn(p.curves.ToneCurvePV2012Blue);
  const hueA = LR_COLOURS.map((c) => g(`HueAdjustment${c}`) / 100), satA = LR_COLOURS.map((c) => g(`SaturationAdjustment${c}`) / 100);
  const lumA = LR_COLOURS.map((c) => g(`LuminanceAdjustment${c}`) / 100);
  const sat = g('Saturation') / 100, vib = g('Vibrance') / 100;
  // split toning (old) or colour grading (Lightroom 10 on; it writes both, colour grading wins)
  const cg = Object.keys(p.s).some((k) => k.startsWith('ColorGrade') && g(k) !== 0 && !/Blending|Balance/.test(k) || /ColorGradeGlobal/.test(k) && g(k) !== 0);
  const zones = cg ? {
    sh: [g('ColorGradeShadowHue'), g('ColorGradeShadowSat') / 100, g('ColorGradeShadowLum') / 100],
    mid: [g('ColorGradeMidtoneHue'), g('ColorGradeMidtoneSat') / 100, g('ColorGradeMidtoneLum') / 100],
    hl: [g('ColorGradeHighlightHue'), g('ColorGradeHighlightSat') / 100, g('ColorGradeHighlightLum') / 100],
    gl: [g('ColorGradeGlobalHue'), g('ColorGradeGlobalSat') / 100, g('ColorGradeGlobalLum') / 100],
    bal: g('SplitToningBalance') / 100,
  } : {
    sh: [g('SplitToningShadowHue'), g('SplitToningShadowSaturation') / 100, 0], mid: [0, 0, 0],
    hl: [g('SplitToningHighlightHue'), g('SplitToningHighlightSaturation') / 100, 0], gl: [0, 0, 0],
    bal: g('SplitToningBalance') / 100,
  };
  const tintVec = (h: number, s: number): RGB => { const c = hsvToRgb(h, 1, 1), y = luma(c); return [(c[0] - y) * s, (c[1] - y) * s, (c[2] - y) * s]; };
  const vSh = tintVec(zones.sh[0], zones.sh[1]), vMid = tintVec(zones.mid[0], zones.mid[1]), vHl = tintVec(zones.hl[0], zones.hl[1]), vGl = tintVec(zones.gl[0], zones.gl[1]);
  const wbR = 1 + 0.28 * temp / 100, wbB = 1 - 0.28 * temp / 100, wbG = 1 - 0.22 * tint / 100;
  const tone = (x: number) => {
    let y = x;
    y += con * 0.15 * Math.sin(2 * Math.PI * (y - 0.5)) * (1 - Math.abs(2 * y - 1) * 0.3);
    y += 0.2 * hi * bump(y, 0.78, 0.3) + 0.2 * sh * bump(y, 0.22, 0.3) + 0.12 * wh * bump(y, 0.95, 0.2) + 0.12 * bl * bump(y, 0.05, 0.2);
    for (let k = 0; k < 4; k++) y += 0.12 * par[k] * bump(y, parC[k], 0.25);
    y = clamp01(y);
    return main ? clamp01(main(y)) : y;
  };
  return (c: RGB): RGB => {
    let lin = [dec(c[0]) * wbR * 2 ** exp, dec(c[1]) * wbG * 2 ** exp, dec(c[2]) * wbB * 2 ** exp];
    const mx = Math.max(...lin, 1e-6);                                     // keep the colour when white balance overshoots
    if (mx > 1) lin = lin.map((v) => v / mx * (1 - Math.exp(-mx)) / (1 - Math.exp(-1)) * 1);
    let v: RGB = [tone(enc(clamp01(lin[0]))), tone(enc(clamp01(lin[1]))), tone(enc(clamp01(lin[2])))];
    if (cR) v[0] = clamp01(cR(v[0])); if (cG) v[1] = clamp01(cG(v[1])); if (cB) v[2] = clamp01(cB(v[2]));
    let [h, s, val] = rgbToHsv(v);
    if (s > 1e-4) {
      const w = lrBands(h);
      let dh = 0, ds = 0, dl = 0;
      for (let k = 0; k < 8; k++) { dh += w[k] * hueA[k] * 30; ds += w[k] * satA[k]; dl += w[k] * lumA[k]; }
      h += dh;
      s *= Math.max(0, 1 + ds);
      val = clamp01(val * (1 + 0.35 * dl * s));
    }
    s *= Math.max(0, 1 + sat);
    s *= Math.max(0, 1 + vib * (1 - Math.min(1, s)) * 1.2);
    v = hsvToRgb(h, clamp01(s), val);
    const y = luma(v), b = zones.bal;
    const wS = Math.max(0, 1 - y / Math.max(0.15, 0.6 + 0.3 * b)) ** 1.5, wH = Math.max(0, (y - Math.min(0.85, 0.4 + 0.3 * b)) / Math.max(0.15, 0.6 - 0.3 * b)) ** 1.5, wM = 4 * y * (1 - y);
    const amt = 0.22;
    for (let ch = 0; ch < 3; ch++) v[ch] += amt * (wS * vSh[ch] + wM * vMid[ch] + wH * vHl[ch] + vGl[ch]);
    const dlum = 0.12 * (wS * zones.sh[2] + wM * zones.mid[2] + wH * zones.hl[2] + zones.gl[2]);
    return v.map((x) => clamp01(x + dlum)) as RGB;
  };
}

/** What a preset holds that the colour fit can't use, and what is carried over as a camera setting. */
export function lightroomExtras(p: LrPreset): { look: Partial<Look>; mapped: string[]; dropped: string[] } {
  const g = (k: string) => (Number.isFinite(p.s[k]) ? p.s[k] : 0);
  const look: Partial<Look> = {}, mapped: string[] = [], dropped: string[] = [];
  const grain = g('GrainAmount');
  if (grain > 0) { look.film_grain = grain <= 25 ? 1 : grain <= 50 ? 2 : 3; mapped.push(`Grain ${grain} → Film Grain ${['', 'Low', 'Med', 'High'][look.film_grain]}`); }
  const vig = g('PostCropVignetteAmount');
  if (Math.abs(vig) >= 10) { look.vignette = Math.max(-OM3.shading, Math.min(OM3.shading, Math.round(vig / 20))); mapped.push(`Vignette ${vig} → Shading ${look.vignette > 0 ? '+' : ''}${look.vignette}`); }
  const cl = g('Clarity2012') || g('Clarity');
  if (cl >= 15) { look.effect = { type: 'clarity', strength: Math.max(1, Math.min(5, Math.round(cl / 20))) }; mapped.push(`Clarity ${cl} → Clarity ${look.effect.strength}`); }
  else if (cl <= -15) { look.effect = { type: 'bloom', strength: Math.max(1, Math.min(5, Math.round(-cl / 20))) }; mapped.push(`Clarity ${cl} → Glow ${look.effect.strength}`); }
  const sharp = g('Sharpness');
  if ('Sharpness' in p.s && sharp < 20) { look.advice = { sharpness: -1 }; mapped.push(`Sharpening ${sharp} → Sharp −1`); }
  const known = /^(GrainAmount|GrainSize|GrainFrequency|PostCropVignette\w*|Clarity2012|Clarity|Sharpness|Version|ProcessVersion|PresetType|Cluster|UUID|SupportsAmount\w*|SupportsColor|SupportsMonochrome|SupportsHighDynamicRange|SupportsNormalDynamicRange|SupportsSceneReferred|SupportsOutputReferred|CameraModelRestriction|Copyright|ContactInfo|HasSettings|ConvertToGrayscale|WhiteBalance|CameraProfile\w*|LookName|Group|Name|ShortName|SortName|Description|ToneCurveName\w*|OverrideLookVignette|AutoLateralCA|LensProfile\w*|LensManualDistortionAmount|PerspectiveUpright|RequiresRGBTables)$/;
  const labels: [RegExp, string][] = [[/^Dehaze$/, 'Dehaze'], [/^Texture$/, 'Texture'], [/^(LuminanceSmoothing|ColorNoiseReduction)/, 'Noise reduction'],
    [/^Sharpen/, 'Sharpening detail'], [/^(Perspective|Lens|Defringe|Chromatic)/, 'Lens corrections'], [/^Shadow(Tint)$/, 'Calibration shadows'],
    [/^(Red|Green|Blue)(Hue|Saturation)$/, 'Calibration'], [/^(Gray|Grey)Mixer/, 'B&W mix'], [/^(Mask|Gradient|Circular|Paint|Retouch)/, 'Local adjustments']];
  for (const [k, v] of Object.entries(p.s)) {
    if (!v || LR_USED.test(k) || known.test(k)) continue;
    const l = labels.find(([re]) => re.test(k));
    const label = l ? l[1] : k;
    if (!dropped.includes(label)) dropped.push(label);
  }
  if (g('ConvertToGrayscale')) dropped.unshift('Black & white (the OM-3 films are colour)');
  return { look, mapped, dropped };
}

// ---------------------------------------------------------------- test colours
export interface Samples { rgb: RGB[]; w: number[] }
/** Greys, skin, sky, foliage and a ring of 24 hues at three strengths and three brightnesses. */
export function testColours(): Samples {
  const rgb: RGB[] = [], w: number[] = [];
  for (let i = 0; i < 12; i++) { const v = 0.04 + (0.94 * i) / 11; rgb.push([v, v, v]); w.push(3); }
  const skin: RGB[] = [[0.98, 0.85, 0.75], [0.94, 0.76, 0.65], [0.86, 0.62, 0.5], [0.76, 0.53, 0.41], [0.55, 0.36, 0.27], [0.42, 0.27, 0.2]];
  for (const c of skin) { rgb.push(c); w.push(3); }
  for (const c of [[0.45, 0.65, 0.9], [0.62, 0.78, 0.95], [0.3, 0.45, 0.2], [0.45, 0.55, 0.25], [0.8, 0.2, 0.15], [0.95, 0.75, 0.2]] as RGB[]) { rgb.push(c); w.push(2); }
  for (let hh = 0; hh < 360; hh += 15) for (const s of [0.25, 0.5, 0.8]) for (const v of [0.35, 0.6, 0.88]) { rgb.push(hsvToRgb(hh, s, v)); w.push(1); }
  return { rgb, w };
}

// ---------------------------------------------------------------- fitting
type ImageLike = { width: number; height: number; data: Uint8ClampedArray };
function samplesImage(rgb: RGB[]): ImageLike {
  const data = new Uint8ClampedArray(rgb.length * 4);
  rgb.forEach((c, i) => { data[i * 4] = c[0] * 255 + 0.5; data[i * 4 + 1] = c[1] * 255 + 0.5; data[i * 4 + 2] = c[2] * 255 + 0.5; data[i * 4 + 3] = 255; });
  return { width: rgb.length, height: 1, data };
}
/** The look's colour as the OM-3 gives it (the Control Panel preview, camera-fitted), on the test colours. */
export function renderSamples(look: Look, src: ImageLike): RGB[] {
  const out = { width: src.width, height: 1, data: new Uint8ClampedArray(src.data.length) };
  renderLook(src as ImageData, out as ImageData, look, { advice: true, camera: 'om3' });
  const r: RGB[] = [];
  for (let i = 0; i < src.width; i++) r.push([out.data[i * 4] / 255, out.data[i * 4 + 1] / 255, out.data[i * 4 + 2] / 255]);
  return r;
}

interface Param { get: (l: Look) => number; set: (l: Look, v: number) => void; lo: number; hi: number; step: number }
const sectorParams = (key: 'hue' | 'sat' | 'light', n: number): Param[] =>
  Array.from({ length: 12 }, (_, k) => ({ get: (l) => l[key][k], set: (l, v) => { l[key][k] = v; }, lo: -n, hi: n, step: 1 }));
const toneParam = (k: 'highlights' | 'shadows' | 'midtones' | 'blacks' | 'whites', n: number): Param =>
  ({ get: (l) => l.tone[k], set: (l, v) => { l.tone[k] = v; }, lo: -n, hi: n, step: 1 });

export function blankFitLook(name: string): Look {
  return {
    name, notes: '', kind: 'colour', hue: new Array(12).fill(0), light: new Array(12).fill(0), sat: new Array(12).fill(0), grain: 'off',
    wb: { a_b: 0, g_m: 0 }, effect: null, vignette: 0, art_effect: 'off', tone: zeroTone(), advice: { contrast: 0, sharpness: 0 },
  };
}
const cloneLook = (l: Look): Look => ({ ...l, hue: [...l.hue], light: [...l.light], sat: [...l.sat], tone: { ...l.tone }, wb: l.wb ? { ...l.wb } : null,
  advice: { ...l.advice }, ...(l.split ? { split: { ...l.split } } : {}) });

export interface FitResult {
  look: Look;
  /** Mean colour difference (CIE ΔE, lower is better) between the grade and: the camera's normal look, and the film. */
  before: number; after: number;
  quality: 'close' | 'fair' | 'rough';
  target: RGB[]; samples: Samples;
}

/** Search the camera settings that come closest to `tf` on the test colours. Calls `progress` (0..1) now and then
 *  and awaits it, so a page can stay responsive. */
export async function fitLook(tf: Transform, name: string, progress?: (f: number) => Promise<void> | void): Promise<FitResult> {
  const samples = testColours();
  const src = samplesImage(samples.rgb);
  const target = samples.rgb.map((c) => tf(c));
  const tLab = target.map(lab), wsum = samples.w.reduce((a, b) => a + b, 0);
  const err = (l: Look) => {
    const got = renderSamples(l, src);
    let e = 0;
    for (let i = 0; i < got.length; i++) { const a = lab(got[i]), b = tLab[i]; e += samples.w[i] * ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2); }
    return e / wsum;
  };
  const meanDE = (l: Look) => {
    const got = renderSamples(l, src);
    let e = 0;
    for (let i = 0; i < got.length; i++) { const a = lab(got[i]), b = tLab[i]; e += samples.w[i] * Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]); }
    return e / wsum;
  };
  const params: Param[] = [
    { get: (l) => l.wb!.a_b, set: (l, v) => { l.wb!.a_b = v; }, lo: -OM3.wb, hi: OM3.wb, step: 1 },
    { get: (l) => l.wb!.g_m, set: (l, v) => { l.wb!.g_m = v; }, lo: -OM3.wb, hi: OM3.wb, step: 1 },
    { get: (l) => l.advice.contrast ?? 0, set: (l, v) => { l.advice.contrast = v; }, lo: -OM3.contrast, hi: OM3.contrast, step: 1 },
    toneParam('midtones', OM3.hsm), toneParam('highlights', OM3.hsm), toneParam('shadows', OM3.hsm), toneParam('blacks', OM3.bw), toneParam('whites', OM3.bw),
    ...sectorParams('sat', OM3.sat), ...sectorParams('hue', OM3.hl), ...sectorParams('light', OM3.hl),
  ];
  const splitParams: Param[] = [
    { get: (l) => l.split?.sh ?? 0, set: (l, v) => { if (l.split) l.split.sh = v; }, lo: 0, hi: 5, step: 0.5 },
    { get: (l) => l.split?.hl ?? 0, set: (l, v) => { if (l.split) l.split.hl = v; }, lo: 0, hi: 5, step: 0.5 },
    { get: (l) => l.tone_balance ?? 0, set: (l, v) => { l.tone_balance = v; }, lo: -OM3.balance, hi: OM3.balance, step: 1 },
  ];
  const LAMBDA = 0.6;                         // cost of each step away from 0: keeps sliders that barely help at 0
  const penalty = (l: Look) => LAMBDA * (params.reduce((a, p) => a + Math.abs(p.get(l)), 0) + 2 * ((l.split?.sh ?? 0) + (l.split?.hl ?? 0)) + Math.abs(l.tone_balance ?? 0));
  let best = blankFitLook(name), bestCost = err(best) + penalty(best);
  const before = meanDE(best);
  let evals = 0;
  const tick = async () => { if (++evals % 60 === 0 && progress) await progress(Math.min(0.95, evals / 3000)); };
  const descend = async (ps: Param[], rounds: number) => {
    for (let r = 0; r < rounds; r++) {
      let moved = false;
      for (const p of ps) {
        for (const dir of [1, -1]) {
          for (;;) {
            const v = p.get(best) + dir * p.step;
            if (v < p.lo - 1e-9 || v > p.hi + 1e-9) break;
            const c = cloneLook(best); p.set(c, v);
            const cost = err(c) + penalty(c); await tick();
            if (cost < bestCost - 1e-6) { best = c; bestCost = cost; moved = true; } else break;
          }
        }
      }
      if (!moved) break;
    }
  };
  await descend(params, 12);
  // split toning: try each wheel colour for the shadows and the highlights
  for (const side of ['sh', 'hl'] as const) {
    let pick: Look | null = null, pickCost = bestCost;
    for (let col = 0; col < 12; col++) for (const st of [0.5, 1, 1.5, 2.5]) {
      const c = cloneLook(best);
      c.split = c.split ? { ...c.split } : { sh_color: 0, sh: 0, hl_color: 0, hl: 0 };
      if (side === 'sh') { c.split.sh_color = col; c.split.sh = st; } else { c.split.hl_color = col; c.split.hl = st; }
      const cost = err(c) + penalty(c); await tick();
      if (cost < pickCost - 1e-6) { pick = c; pickCost = cost; }
    }
    if (pick) { best = pick; bestCost = pickCost; }
  }
  if (best.split) await descend([...splitParams, ...params], 8);
  if (best.split && !best.split.sh && !best.split.hl) delete best.split;
  if (!best.tone_balance) delete best.tone_balance;
  if (best.wb && !best.wb.a_b && !best.wb.g_m) best.wb = null;
  const after = meanDE(best);
  if (progress) await progress(1);
  return { look: best, before, after, quality: after < 4 ? 'close' : after < 7 ? 'fair' : 'rough', target, samples };
}
