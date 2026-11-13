import { bendSplit } from './split';
// Approximate look preview on 8-bit sRGB images (Canvas 2D, CPU). A rough port of the repo's desktop sim
// (sim/pipeline.py ColorEngine + grain, sim/film.py WB / tone levels / mono, sim/library_preview.py bloom), applied to
// already-rendered JPEGs instead of raw files, so it is an approximation of an approximation: good for direction
// and relative strength, not for exact colour. Vignette and Art Effects are not previewed.
// The look's tone (H/S/M/B/W, card data) is a luminance LUT in the display domain after the base curve (src/tone.ts);
// the contrast advice bends the input to it first. The old recipe tone advice (advice.tone) is not previewed: on
// v0.19 the Film pick sets the profile's H/S/M from the look's own tone.
import { GRAINS, toneIsZero, type FilmWb, type Look } from './pack';
import { previewToneLut } from './tone';

// Firmware COLOR table (generated/color/ep7_color_table.json, UI order): sector centre / width (0..32767 = 360 deg)
// and the positive/negative saturation gains.
const CENTRE = [12197, 9466, 8192, 6736, 3095, 30401, 28945, 27489, 24212, 20753, 16111, 15019].map((w) => (w / 32768) * 360);
const WIDTH = [3823, 5461, 3959, 2685, 5006, 9057, 6872, 2867, 4642, 6690, 8055, 5643].map((w) => (w / 32768) * 360);
const GAIN_POS = [240, 240, 240, 256, 369, 328, 382, 382, 300, 615, 400, 656];
const GAIN_NEG = [385, 385, 395, 493, 513, 395, 385, 385, 395, 395, 395, 395];
const ANGLE_OFFSET = 15, SAT_SCALE = 1.5, HUE_DEG_PER_STEP = 5.5;
/** OM-3 (camera 'om3'): the same engine with numbers fitted to the camera (2026-11-11, research/film-grading/: colour-
 *  checker photos with each slider on its own, plus 80 film shots; preview vs camera on the changed patches, ΔE:
 *  saturation 6.6 -> 4.5, hue 5.1 -> 3.6, luminance 3.4 -> 2.5, WB 3.0 -> 2.2; on film shots left out of the fit
 *  4.4 -> 3.8, where two shoots of the same film differ by 2.3). Per colour: saturation gain up / down,
 *  hue degrees per step for each direction (camera Hue - / +), a luminance scale, the WB shift's linear-light gain per
 *  channel (R, G, B per A-B and per G-M step) and the split bend's scale. Red has no chart patch: it keeps the old numbers. */
export const OM3_CAL = {
  gainPos: [306, 171, 618, 256, 517, 32, 622, 428, 724, 254, 250, 812],
  gainNeg: [988, 327, 1032, 493, 560, 186, 568, 474, 980, 389, 233, 498],
  hueDown: [19.3, 6.5, 10.1, 5.5, 7.4, 0.0, 7.5, 6.4, 19.0, 12.6, 0.0, 3.6],   // degrees per step, camera Hue -
  hueUp: [17.2, 6.7, 13.7, 5.5, 11.9, 0.1, 7.1, 7.7, 21.2, 6.4, 2.9, 5.5],    // degrees per step, camera Hue +
  light: 2.44, wbAB: [0.0379, 0.0118, -0.0129], wbGM: [-0.0097, 0.0181, -0.0131], split: 1.05,
};
export type SectorCal = Pick<typeof OM3_CAL, 'gainPos' | 'gainNeg' | 'hueDown' | 'hueUp' | 'light'>;
const L_LUT = [-300, -250, -200, -150, -100, -50, -25, 0, 25, 50, 100, 150, 200, 250, 300];
const WB_STEP = 0.015, CONTRAST_STEP = 0.035;
const BLOOM_SHARE = [0.08, 0.14, 0.2, 0.27, 0.35];
const COLOUR_GRAIN = [0, 40, 80, 0], MONO_GRAIN = [0, 110, 300, 0];   // v0.22: colour = a hint of sensor-like texture (Noise Filter Low/Off)
const CLARITY = [0.12, 0.22, 0.32, 0.42, 0.52];
const TINT_RGB: Record<string, [number, number, number]> = {
  neutral: [1, 1, 1], red: [1, 0.5, 0.38], amber: [1, 0.75, 0.42], warm: [1, 0.87, 0.72], cool: [0.78, 0.9, 1.1],
};
const MONO_W: Record<string, [number, number, number]> = {
  none: [0.299, 0.587, 0.114], yellow: [0.42, 0.53, 0.05], orange: [0.52, 0.44, 0.04], red: [0.65, 0.32, 0.03],
  green: [0.22, 0.7, 0.08], blue: [0.18, 0.47, 0.35],
};
const FULL_WIDTH = 5184;
const BINS = 720;

const DEC = new Float32Array(256).map((_, i) => {
  const x = i / 255;
  return x <= 0.04045 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4);
});
const ENC_N = 4096;
const ENC = new Float32Array(ENC_N + 1).map((_, i) => {
  const x = i / ENC_N;
  return x <= 0.0031308 ? 12.92 * x : 1.055 * Math.pow(x, 1 / 2.4) - 0.055;
});
const enc = (x: number) => ENC[Math.max(0, Math.min(ENC_N, (x * ENC_N + 0.5) | 0))];
const clamp01 = (x: number) => (x < 0 ? 0 : x > 1 ? 1 : x);

/** Per-hue-bin colour-engine response for a look: saturation multiplier, hue shift (deg), lightness (native sum).
 *  `cal` (OM-3): the camera-fitted numbers; `hue` is then the engine's sign (the camera's negated), so + = camera Hue -. */
export function sectorLut(hue: number[], light: number[], sat: number[], cal?: SectorCal) {
  const satMul = new Float32Array(BINS), shift = new Float32Array(BINS), lsum = new Float32Array(BINS);
  const gp = cal ? cal.gainPos : GAIN_POS, gn = cal ? cal.gainNeg : GAIN_NEG;
  const sc = sat.map((s, k) => (s * (s >= 0 ? gp[k] : gn[k])) / 5 * SAT_SCALE);
  const deg = hue.map((v, k) => (cal ? (v >= 0 ? cal.hueDown[k] : cal.hueUp[k]) : HUE_DEG_PER_STEP));
  const lk = cal ? cal.light : 1;
  const centre = CENTRE.map((c) => (c + ANGLE_OFFSET) % 360);
  const w = new Float64Array(12);
  for (let b = 0; b < BINS; b++) {
    const h = (b + 0.5) * (360 / BINS);
    let sum = 0;
    for (let k = 0; k < 12; k++) {
      const d = ((h - centre[k] + 540) % 360) - 180;
      const x = Math.max(-1, Math.min(1, d / Math.max(WIDTH[k], 1)));
      w[k] = Math.max(0, Math.cos(x * Math.PI / 2));
      sum += w[k];
    }
    let s = 0, hs = 0, l = 0;
    for (let k = 0; k < 12; k++) {
      const wk = sum > 1e-6 ? w[k] / sum : 1 / 12;
      s += wk * sc[k];
      hs += wk * hue[k] * deg[k];          // native -1000*u; shift = -native/1000 * deg/step
      l += wk * L_LUT[Math.max(-7, Math.min(7, light[k])) + 7] * lk;
    }
    satMul[b] = Math.max(0, Math.min(3, 1 + s / 1000));
    shift[b] = (hs * Math.PI) / 180;
    lsum[b] = l / 4096;
  }
  return { satMul, shift, lsum };
}

export const contrastCurve = (contrast: number) => (y: number) => clamp01(y + 0.5 * CONTRAST_STEP * contrast * Math.sin(2 * Math.PI * (y - 0.5)));

/** Box-downsample to ~sw px wide, blur, and bilinear-upsample back: the Soft Focus "blurred copy". */
function blurredCopy(src: Float32Array, w: number, h: number, sw: number, sigma: number): Float32Array {
  const f = Math.max(1, Math.round(w / sw));
  const W = Math.max(4, Math.ceil(w / f)), H = Math.max(3, Math.ceil(h / f));
  let small = new Float32Array(W * H * 3);
  const cnt = new Float32Array(W * H);
  for (let y = 0; y < h; y++) {
    const Y = Math.min(H - 1, (y / f) | 0);
    for (let x = 0; x < w; x++) {
      const X = Math.min(W - 1, (x / f) | 0), o = (Y * W + X), i = (y * w + x) * 3;
      small[o * 3] += src[i]; small[o * 3 + 1] += src[i + 1]; small[o * 3 + 2] += src[i + 2]; cnt[o]++;
    }
  }
  for (let o = 0; o < W * H; o++) { const c = cnt[o] || 1; small[o * 3] /= c; small[o * 3 + 1] /= c; small[o * 3 + 2] /= c; }
  // separable gaussian
  const r = Math.ceil(sigma * 3), ker = new Float32Array(2 * r + 1);
  let ks = 0;
  for (let i = -r; i <= r; i++) ks += ker[i + r] = Math.exp(-(i * i) / (2 * sigma * sigma));
  ker.forEach((v, i) => (ker[i] = v / ks));
  for (const horiz of [true, false]) {
    const out = new Float32Array(small.length);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      let a = 0, b = 0, c = 0;
      for (let k = -r; k <= r; k++) {
        const xx = horiz ? Math.min(W - 1, Math.max(0, x + k)) : x, yy = horiz ? y : Math.min(H - 1, Math.max(0, y + k));
        const j = (yy * W + xx) * 3, kv = ker[k + r];
        a += small[j] * kv; b += small[j + 1] * kv; c += small[j + 2] * kv;
      }
      const o = (y * W + x) * 3;
      out[o] = a; out[o + 1] = b; out[o + 2] = c;
    }
    small = out;
  }
  const big = new Float32Array(w * h * 3);
  for (let y = 0; y < h; y++) {
    const fy = Math.min(H - 1, Math.max(0, (y + 0.5) / f - 0.5)), y0 = fy | 0, y1 = Math.min(H - 1, y0 + 1), ty = fy - y0;
    for (let x = 0; x < w; x++) {
      const fx = Math.min(W - 1, Math.max(0, (x + 0.5) / f - 0.5)), x0 = fx | 0, x1 = Math.min(W - 1, x0 + 1), tx = fx - x0;
      const o = (y * w + x) * 3;
      for (let c = 0; c < 3; c++) {
        const a = small[(y0 * W + x0) * 3 + c] * (1 - tx) + small[(y0 * W + x1) * 3 + c] * tx;
        const b = small[(y1 * W + x0) * 3 + c] * (1 - tx) + small[(y1 * W + x1) * 3 + c] * tx;
        big[o + c] = a * (1 - ty) + b * ty;
      }
    }
  }
  return big;
}

/** camera 'om3' (Caduceus for OM-3): hue turns toward the clockwise neighbour (OM-3 camera-tested direction), no
 *  noise filter preview; glow / clarity (v0.20) and the profile's Sharpness and Shading (vignette) are previewed. */
export interface PreviewOptions { advice: boolean; camera?: 'ep7' | 'om3' }

/** Render `look` from `src` (8-bit sRGB RGBA) into `dst` (same size). */
export function renderLook(src: ImageData, dst: ImageData, look: Look, opt: PreviewOptions) {
  const { width: w, height: h } = src;
  const s = src.data, d = dst.data, n = w * h;
  const img = new Float32Array(n * 3);
  const mono = look.kind === 'mono';
  // 1. WB fine-tune (linear light)
  const ab = look.wb?.a_b ?? 0, gm = look.wb?.g_m ?? 0;
  const om3 = opt.camera === 'om3';
  const fwg = om3 ? filmWbGain(look.film_wb) : null;          // v0.28: the film's WB mode, as if shot in daylight
  const [gr, gg, gb] = (om3 ? [0, 1, 2].map((c) => 1 + OM3_CAL.wbAB[c] * ab + OM3_CAL.wbGM[c] * gm)
    : [1 + WB_STEP * ab, 1 + WB_STEP * gm, 1 - WB_STEP * ab]).map((v, c) => v * (fwg ? fwg[c] : 1));
  for (let i = 0; i < n; i++) {
    const p = i * 4, q = i * 3;
    if (ab || gm || fwg) {
      img[q] = enc(DEC[s[p]] * gr); img[q + 1] = enc(DEC[s[p + 1]] * gg); img[q + 2] = enc(DEC[s[p + 2]] * gb);
    } else {
      img[q] = s[p] / 255; img[q + 1] = s[p + 1] / 255; img[q + 2] = s[p + 2] / 255;
    }
  }
  // 2. contrast advice + the look's tone (luminance), 3. 12-sector colour engine, 4. mono
  const con = opt.advice ? look.advice.contrast ?? 0 : 0;
  const tl = !toneIsZero(look.tone) || con ? previewToneLut(look.tone, 1024, con ? contrastCurve(con) : undefined) : null;
  const lut = sectorLut(om3 ? look.hue.map((v) => -v) : look.hue, look.light, !mono ? look.sat : new Array(12).fill(0), om3 ? OM3_CAL : undefined);
  const mf = look.advice.mono_filter;
  let mw: [number, number, number] = MONO_W.none;
  if (mono && mf) {
    const f = MONO_W[mf.colour] ?? MONO_W.none, k = Math.min(3, Math.max(0, mf.strength)) / 3;
    mw = [0, 1, 2].map((c) => MONO_W.none[c] + (f[c] - MONO_W.none[c]) * k) as [number, number, number];
    const t = mw[0] + mw[1] + mw[2];
    mw = [mw[0] / t, mw[1] / t, mw[2] / t];
  }
  for (let i = 0; i < n; i++) {
    const q = i * 3;
    const r = img[q], g = img[q + 1], b = img[q + 2];
    let y = 0.299 * r + 0.587 * g + 0.114 * b;
    let cb = -0.168736 * r - 0.331264 * g + 0.5 * b;
    let cr = 0.5 * r - 0.418688 * g - 0.081312 * b;
    if (tl) y = tl[Math.max(0, Math.min(1024, (y * 1024 + 0.5) | 0))];   // luminance only: Cb/Cr untouched
    const chroma = Math.hypot(cb, cr);
    if (chroma > 1e-5) {
      let hd = (Math.atan2(cr, cb) * 180) / Math.PI;
      if (hd < 0) hd += 360;
      const bin = Math.min(BINS - 1, (hd * (BINS / 360)) | 0);
      const ang = (hd * Math.PI) / 180 + lut.shift[bin];
      const ch = chroma * lut.satMul[bin];
      y += lut.lsum[bin] * Math.min(1, chroma / 0.25);
      cb = ch * Math.cos(ang); cr = ch * Math.sin(ang);
    }
    let R = y + 1.402 * cr, G = y - 0.344136 * cb - 0.714136 * cr, B = y + 1.772 * cb;
    R = clamp01(R); G = clamp01(G); B = clamp01(B);
    if (mono) R = G = B = mw[0] * R + mw[1] * G + mw[2] * B;
    img[q] = R; img[q + 1] = G; img[q + 2] = B;
  }
  if (om3 && look.split) bendSplit(img, n, look.split, OM3_CAL.split, look.tone_balance ?? 0);   // OM-3 v0.26 split toning (the camera bends its gamma curves); v0.28 Tone Balance
  // 5. bloom / halation (Soft Focus blend of a 160-px-wide blurred copy) or clarity (large-radius local contrast)
  const e = look.effect;                     // OM-3 v0.20: glow (no colour) and clarity too
  if (e && e.strength >= 1) {
    const st = Math.min(5, e.strength) - 1;
    if (e.type === 'clarity') {
      const bl = blurredCopy(img, w, h, 96, 1.5), k = CLARITY[st];
      for (let i = 0; i < n * 3; i += 3) {
        const yo = 0.299 * img[i] + 0.587 * img[i + 1] + 0.114 * img[i + 2];
        const yb = 0.299 * bl[i] + 0.587 * bl[i + 1] + 0.114 * bl[i + 2];
        const dy = k * (yo - yb) * (1 - Math.abs(2 * yo - 1) * 0.5);
        img[i] = clamp01(img[i] + dy); img[i + 1] = clamp01(img[i + 1] + dy); img[i + 2] = clamp01(img[i + 2] + dy);
      }
    } else {
      const tint = TINT_RGB[e.tint ?? (e.type === 'halation' ? 'red' : 'neutral')] ?? TINT_RGB.neutral;
      const bl = blurredCopy(img, w, h, 160, 1.2), sh = BLOOM_SHARE[st];
      for (let i = 0; i < n * 3; i += 3) {
        for (let c = 0; c < 3; c++) img[i + c] = clamp01((1 - sh) * img[i + c] + sh * Math.min(1, bl[i + c] * tint[c] * 1.08));
      }
    }
  }
  if (om3 && look.halation) om3Halation(img, w, h, look.halation);   // OM-3 v0.28: after the Soft Focus blend, as the camera
  // 6. grain (Olympus xorshift32 luma grain with brightness mask; v0.4 colour gains / stock mono gains)
  if (om3) om3Settings(img, w, h, look.advice.sharpness ?? 0, look.vignette);
  if (om3 && look.film_grain) om3Grain(img, w, h, look.film_grain);
  const gi = om3 ? 0 : GRAINS.indexOf(look.grain);
  const gain = gi > 0 ? (mono ? MONO_GRAIN : COLOUR_GRAIN)[gi] : 0;
  const scale = Math.min(1, w / FULL_WIDTH) * 2.2;   // a little stronger than full-res-viewed-small, so it stays visible
  for (let i = 0; i < n; i++) {
    const q = i * 3, p = i * 4;
    let r = img[q], g = img[q + 1], b = img[q + 2];
    if (gain) {
      let st = (Math.imul(i, 2654435761) + 10) >>> 0;
      for (let k = 0; k < 3; k++) { st ^= st << 13; st >>>= 0; st ^= st >>> 17; st ^= st << 5; st >>>= 0; }
      const rnd = (st & 0xffff) - 32768;
      const y = 0.299 * r + 0.587 * g + 0.114 * b;
      const m = clamp01(((y * 255) - 36) / (120 - 36)) * 1023;
      const noise = Math.max(-6682, ((gain * m) / 1024) * rnd / 1024) * scale / 65535;
      r += noise; g += noise; b += noise;
    }
    d[p] = clamp01(r) * 255 + 0.5; d[p + 1] = clamp01(g) * 255 + 0.5; d[p + 2] = clamp01(b) * 255 + 0.5; d[p + 3] = 255;
  }
}

/** OM-3 v0.28 film WB: the camera's WB mode (presets at their Kelvin, Custom WB at its own) on a photo taken in daylight
 *  (5300 K, the camera's Sunny): linear-light gains = the white of 5300 K / the white of the mode's Kelvin (green 1).
 *  Auto, Underwater and the one-touch modes: no change (they follow the light or a measurement). */
const WB_KELVIN: Partial<Record<FilmWb['mode'], number>> = { sunny: 5300, shade: 7500, cloudy: 6000, incandescent: 3000, fluorescent: 4000, flash: 5500 };
export function filmWbGain(w: FilmWb | undefined): [number, number, number] | null {
  const k = !w ? undefined : w.mode === 'custom' ? w.kelvin ?? 5400 : WB_KELVIN[w.mode];
  if (!k || k === 5300) return null;
  const a = planckRgb(5300), b = planckRgb(k), m = [0, 1, 2].map((c) => a[c] / b[c]);
  return [m[0] / m[1], 1, m[2] / m[1]];
}
/** Linear sRGB of a black body at T kelvin (CIE xy by Kim et al. 2002, Y = 1). */
function planckRgb(T: number): [number, number, number] {
  T = Math.max(1667, Math.min(25000, T));
  const t = 1e3 / T, x = T <= 4000 ? -0.2661239 * t ** 3 - 0.2343589 * t ** 2 + 0.8776956 * t + 0.17991
    : -3.0258469 * t ** 3 + 2.1070379 * t ** 2 + 0.2226347 * t + 0.24039;
  const y = T <= 2222 ? -1.1063814 * x ** 3 - 1.3481102 * x ** 2 + 2.18555832 * x - 0.20219683
    : T <= 4000 ? -0.9549476 * x ** 3 - 1.37418593 * x ** 2 + 2.09137015 * x - 0.16748867
      : 3.081758 * x ** 3 - 5.8733867 * x ** 2 + 3.75112997 * x - 0.37001483;
  const X = x / y, Z = (1 - x - y) / y;
  return [3.2406 * X - 1.5372 - 0.4986 * Z, -0.9689 * X + 1.8758 + 0.0415 * Z, 0.0557 * X - 0.204 + 1.057 * Z];
}

/** OM-3 v0.28 Halation, after research/halation/model.py (the camera's pass, firmware hl_run; numbers firmware/halation.py),
 *  on the preview in the camera's own pixel scale (a 5184-px-wide photo): 64-px cells sum how far bright pixels pass
 *  Y 200, two blurs (3 and 10 passes) mixed 50 / 50, u = 255 v / (v + 900); none when 24 % or more of the cells are
 *  bright (full strength up to 8 %); each pixel gets a red-orange glow lerped from the cells (Y by the pixel, the colour
 *  less on bright cells). */
const HL = { T: 200, K: 900, BLUR: 3, BLUR2: 10, MIX: 128, GMAX: [0, 43, 78, 113, 156, 208], KY: 44, KCB: -40, KCR: 60, WMUL: 2, COV_U: 32, COV_LO: 8, COV_HI: 24 };
function om3Halation(img: Float32Array, w: number, h: number, level: number) {
  const sc = FULL_WIDTH / w, Wc = FULL_WIDTH, Hc = Math.round(h * sc);
  const GW = Math.ceil(Wc / 64), GH = Math.max(1, Math.ceil(Hc / 64));
  const E = new Float64Array(GW * GH), Bs = new Float64Array(GW * GH), N = new Float64Array(GW * GH);
  const Yof = (q: number) => 255 * (0.299 * img[q] + 0.587 * img[q + 1] + 0.114 * img[q + 2]);
  for (let y = 0; y < h; y++) {
    const gy = Math.min(GH - 1, ((y + 0.5) * sc / 64) | 0);
    for (let x = 0; x < w; x++) {
      const g = gy * GW + Math.min(GW - 1, ((x + 0.5) * sc / 64) | 0), Y = Yof((y * w + x) * 3);
      if (Y > HL.T) E[g] += Y - HL.T;
      Bs[g] += Y; N[g]++;
    }
  }
  for (let g = 0; g < E.length; g++) {        // the camera's sums: a quarter of a cell's pixels (every 2nd row, one per pair)
    const cnt = N[g] || 1;
    E[g] = (E[g] / cnt) * (64 * 64 / 4) * Math.min(1, (cnt * sc * sc) / (64 * 64));
    Bs[g] /= cnt;
  }
  const blur = (a: Float64Array, passes: number) => {
    let cur = Float64Array.from(a);
    for (const horiz of [true, false]) for (let p = 0; p < passes; p++) {
      const nx = new Float64Array(cur.length);
      for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++) {
        const at = (xx: number, yy: number) => cur[Math.min(GH - 1, Math.max(0, yy)) * GW + Math.min(GW - 1, Math.max(0, xx))];
        nx[y * GW + x] = horiz ? (at(x - 1, y) + 2 * at(x, y) + at(x + 1, y)) / 4 : (at(x, y - 1) + 2 * at(x, y) + at(x, y + 1)) / 4;
      }
      cur = nx;
    }
    return cur;
  };
  const t1 = blur(E, HL.BLUR), t2 = blur(E, HL.BLUR2);
  const u = new Float64Array(E.length);
  let bright = 0;
  for (let g = 0; g < u.length; g++) {
    const v = Math.min(65408, (t1[g] * (256 - HL.MIX) + t2[g] * HL.MIX) / 256);
    u[g] = (255 * v) / (v + HL.K);
    if (u[g] >= HL.COV_U) bright++;
  }
  const lo = (u.length * HL.COV_LO) / 100, hi = (u.length * HL.COV_HI) / 100;
  if (bright >= hi) return;                  // a bright frame (daylight): no halation
  const cov = bright <= lo ? 1 : (hi - bright) / (hi - lo);
  const G = u.map((x) => (x * HL.GMAX[Math.min(5, level)] / 256) * cov);
  const Wt = Bs.map((b) => Math.min(255, HL.WMUL * (255 - b)));
  const lerp = (A: Float64Array, cx: number, cy: number) => {
    const fx = Math.max(0, Math.min(GW - 1, (cx - 32) / 64)), fy = Math.max(0, Math.min(GH - 1, (cy - 32) / 64));
    const x0 = fx | 0, y0 = fy | 0, x1 = Math.min(GW - 1, x0 + 1), y1 = Math.min(GH - 1, y0 + 1), tx = fx - x0, ty = fy - y0;
    return (A[y0 * GW + x0] * (1 - tx) + A[y0 * GW + x1] * tx) * (1 - ty) + (A[y1 * GW + x0] * (1 - tx) + A[y1 * GW + x1] * tx) * ty;
  };
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const cx = (x + 0.5) * sc, cy = (y + 0.5) * sc, g = lerp(G, cx, cy);
    if (g <= 0) continue;
    const q = (y * w + x) * 3, r = img[q] * 255, gg = img[q + 1] * 255, b = img[q + 2] * 255;
    let Y = 0.299 * r + 0.587 * gg + 0.114 * b, Cb = -0.168736 * r - 0.331264 * gg + 0.5 * b, Cr = 0.5 * r - 0.418688 * gg - 0.081312 * b;
    const c = (g * lerp(Wt, cx, cy)) / 256;
    Y += ((255 - Y) * g * HL.KY) / 65536;
    Cb = Math.max(-128, Math.min(127, Cb + (c * HL.KCB) / 256)); Cr = Math.max(-128, Math.min(127, Cr + (c * HL.KCR) / 256));
    img[q] = clamp01((Y + 1.402 * Cr) / 255); img[q + 1] = clamp01((Y - 0.344136 * Cb - 0.714136 * Cr) / 255); img[q + 2] = clamp01((Y + 1.772 * Cb) / 255);
  }
}

/** OM-3 Sharpness (unsharp mask on luma; negative softens) and Shading (corner brightness; negative = darker
 *  corners, the Olympus convention), as the Caduceus for OM-3 Look Lab previewed them. Illustrative at preview size. */
function om3Settings(img: Float32Array, w: number, h: number, sharp: number, shading: number) {
  const n = w * h;
  if (sharp) {
    // the camera's own numbers: -2..+2 as the Look Lab had them; v0.22's -3, -4 and Off (-5) soften a little more
    const Y = new Float32Array(n), amt = sharp >= -2 ? 0.45 * sharp : -0.9 - 0.05 * (-2 - sharp);
    for (let i = 0; i < n; i++) Y[i] = 0.299 * img[i * 3] + 0.587 * img[i * 3 + 1] + 0.114 * img[i * 3 + 2];
    for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) {
      const i = y * w + x;
      const bl = (Y[i - w - 1] + 2 * Y[i - w] + Y[i - w + 1] + 2 * Y[i - 1] + 4 * Y[i] + 2 * Y[i + 1] + Y[i + w - 1] + 2 * Y[i + w] + Y[i + w + 1]) / 16;
      const dl = amt * (Y[i] - bl), q = i * 3;
      img[q] = clamp01(img[q] + dl); img[q + 1] = clamp01(img[q + 1] + dl); img[q + 2] = clamp01(img[q + 2] + dl);
    }
  }
  if (shading) {
    const cx = (w - 1) / 2, cy = (h - 1) / 2, R2 = cx * cx + cy * cy, k = 0.07 * shading;
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
      const r = ((x - cx) ** 2 + (y - cy) ** 2) / R2, f = 1 + k * r * Math.sqrt(r), q = (y * w + x) * 3;
      img[q] = clamp01(img[q] * f); img[q + 1] = clamp01(img[q + 1] * f); img[q + 2] = clamp01(img[q + 2] * f);
    }
  }
}

/** OM-3 v0.21 Grain (Low / Med / High), from research/grain/model.py: the camera's MONO grain shape. Per row, one
 *  xorshift32 per 4 pixels gives a triangular 0..30 value per pixel, smoothed down the columns and paired across, and
 *  each pixel's luma moves by ((64 h - 945) * G[Y] * S) / 2^18 (G: none in deep shadows, full from the midtones up).
 *  S is the strength for the level, reduced as the photo is when it is shown this small. Owner, 2026-11-09 (v0.26 on
 *  the camera): the old Med (68) looked like the camera's High, so High is now 68 and Low / Med follow the camera's
 *  texture gains (v0.25 fast grain: Low 448, Med 832, High 1280), i.e. 68 x 448 / 1280 and 68 x 832 / 1280. */
const GRAIN_S = [0, 24, 44, 68];
const GRAIN_G = Array.from({ length: 256 }, (_, y) => {
  const ss = (t: number) => { t = Math.min(1, Math.max(0, t)); return t * t * (3 - 2 * t); };
  return Math.round(255 * (0.08 + 0.92 * ss((y - 25) / 75)) * (1 - 0.25 * ss((y - 200) / 55)));
});
function om3Grain(img: Float32Array, w: number, h: number, level: number) {
  // The camera's grain is per pixel of a 5184-px photo; shrinking it averages it out. Measured, a Grain High photo
  // shrunk to 1024 px keeps about 0.58 of the full strength (3 / the shrink factor), but the preview is then shown
  // enlarged on most screens, which makes each grain coarser and the texture read stronger than on the photo. A
  // little over a third of it (1.1 / the shrink factor) looks right on screen.
  const S = GRAIN_S[Math.min(3, level)] * Math.min(1, (1.1 * w) / FULL_WIDTH);
  const V = new Int32Array(w).fill(15), H = new Int32Array(w);
  let r = 0x12345678;
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x += 4) {
      r ^= r << 13; r >>>= 0; r ^= r >>> 17; r ^= r << 5; r >>>= 0;
      for (let k = 0; k < 4 && x + k < w; k++) { const b = (r >>> (8 * k)) & 255; V[x + k] = (V[x + k] + (b & 15) + (b >> 4)) >> 1; }
    }
    for (let x = 0; x < w; x++) H[x] = (V[x] + (x ? V[x - 1] : 15) + 1) >> 1;
    for (let x = 0; x < w; x++) {
      const q = (y * w + x) * 3, Y = 0.299 * img[q] + 0.587 * img[q + 1] + 0.114 * img[q + 2];
      const d = ((64 * H[x] - 945) * GRAIN_G[Math.max(0, Math.min(255, (Y * 255) | 0))] * S) / 262144 / 255;
      img[q] = clamp01(img[q] + d); img[q + 1] = clamp01(img[q + 1] + d); img[q + 2] = clamp01(img[q + 2] + d);
    }
  }
}
