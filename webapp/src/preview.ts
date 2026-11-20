import { bendSplit } from './split';
import { mixIsFlat, mixMatrix } from './curves';
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
  /** OM-3 Contrast: the change per step at y = CON_X (display 0..1), applied before the look's tone. Fitted 2026-11-18 on
   *  the 9 standard films with Contrast +1 / +2 (calibration card 3): the camera lifts the highlights far more than the
   *  old symmetric S-curve (white patch +4 L a step); films left out of the fit 4.70 -> 4.37 and 3.99 -> 3.95.
   *  Contrast -1 / -2 (no shots) are taken as the mirror. */
  contrast: [0, -0.0042, -0.0216, -0.0039, 0.0053, 0.0265, 0.0442, 0.0684, 0],
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
const CON_X = [0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.85, 0.92, 1];
/** OM-3 Contrast (-2..+2): the camera's own curve per step (OM3_CAL.contrast). */
export const om3ContrastCurve = (contrast: number) => (y: number) => {
  const v = OM3_CAL.contrast; let i = 0;
  while (i < CON_X.length - 2 && y > CON_X[i + 1]) i++;
  const t = Math.max(0, Math.min(1, (y - CON_X[i]) / (CON_X[i + 1] - CON_X[i])));
  return clamp01(y + contrast * (v[i] + (v[i + 1] - v[i]) * t));
};

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
export interface PreviewOptions { advice: boolean; camera?: 'ep7' | 'om3'; crop?: CropRect }
/** OM-3 Image Aspect (preview): the part of the photo the camera keeps, centred, as the camera's JPEG sizes (4:3 = the
 *  whole photo; crops of the 5184 x 3888 frame: 3:2 5184 x 3456, 16:9 5184 x 2920, 1:1 3888 x 3888, 3:4 2912 x 3888, and
 *  v0.40's 5:4 4864 x 3888, XPan 5184 x 1920, 21:9 5184 x 2224; research/border/model.py). The look is made on the whole
 *  photo (Shading, the lens corners and grain as on the sensor's frame), then cut, and the Border sits inside the cut. */
export interface CropRect { x: number; y: number; w: number; h: number }
export const ASPECTS: { id: string; label: string; r?: number }[] = [
  { id: '4:3', label: '4:3' }, { id: '3:2', label: '3:2', r: 5184 / 3456 }, { id: '16:9', label: '16:9', r: 5184 / 2920 },
  { id: '1:1', label: '1:1', r: 1 }, { id: '3:4', label: '3:4', r: 2912 / 3888 }, { id: '5:4', label: '5:4', r: 4864 / 3888 },
  { id: 'xpan', label: 'XPan', r: 5184 / 1920 }, { id: '21:9', label: '21:9', r: 5184 / 2224 },
];
/** The crop of a w x h photo at Image Aspect `id` (a portrait photo: the camera's crop turned with it). */
export function cropRect(w: number, h: number, id: string): CropRect {
  const a = ASPECTS.find((x) => x.id === id);
  if (!a?.r) return { x: 0, y: 0, w, h };
  const r = h > w ? 1 / a.r : a.r;
  const cw = r > w / h ? w : Math.min(w, Math.round(h * r)), ch = r > w / h ? Math.min(h, Math.round(w / r)) : h;
  return { x: Math.round((w - cw) / 2), y: Math.round((h - ch) / 2), w: cw, h: ch };
}

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
  const mx = om3 && !mono && !mixIsFlat(look.mix) ? mixMatrix(look.mix!) : null;   // OM-3 colour mix: in the camera's colour matrix, after WB
  const fall = om3 && !look.lens_correction ? lensFalloff(w, h) : null;           // OM-3 Vignette Correction Off: the lens's own corners
  for (let i = 0; i < n; i++) {
    const p = i * 4, q = i * 3;
    if (fall) {
      const f = fall[i], m = mx ?? [[1, 0, 0], [0, 1, 0], [0, 0, 1]];
      const r = DEC[s[p]] * gr * f, g = DEC[s[p + 1]] * gg * f, b = DEC[s[p + 2]] * gb * f;
      img[q] = enc(m[0][0] * r + m[0][1] * g + m[0][2] * b);
      img[q + 1] = enc(m[1][0] * r + m[1][1] * g + m[1][2] * b);
      img[q + 2] = enc(m[2][0] * r + m[2][1] * g + m[2][2] * b);
    } else if (mx) {
      const r = DEC[s[p]] * gr, g = DEC[s[p + 1]] * gg, b = DEC[s[p + 2]] * gb;
      img[q] = enc(mx[0][0] * r + mx[0][1] * g + mx[0][2] * b);
      img[q + 1] = enc(mx[1][0] * r + mx[1][1] * g + mx[1][2] * b);
      img[q + 2] = enc(mx[2][0] * r + mx[2][1] * g + mx[2][2] * b);
    } else if (ab || gm || fwg) {
      img[q] = enc(DEC[s[p]] * gr); img[q + 1] = enc(DEC[s[p + 1]] * gg); img[q + 2] = enc(DEC[s[p + 2]] * gb);
    } else {
      img[q] = s[p] / 255; img[q + 1] = s[p + 1] / 255; img[q + 2] = s[p + 2] / 255;
    }
  }
  // 2. contrast advice + the look's tone (luminance), 3. 12-sector colour engine, 4. mono
  const con = opt.advice ? look.advice.contrast ?? 0 : 0;
  const tl = !toneIsZero(look.tone) || con ? previewToneLut(look.tone, 1024, con ? (om3 ? om3ContrastCurve(con) : contrastCurve(con)) : undefined) : null;
  const lut = sectorLut(om3 ? look.hue.map((v) => -v) : look.hue, look.light, !mono ? look.sat : new Array(12).fill(0), om3 ? OM3_CAL : undefined);
  const mf = look.advice.mono_filter;
  let mw: [number, number, number] = MONO_W.none;
  if (mono && mf) {
    const f = MONO_W[mf.colour] ?? MONO_W.none, k = Math.min(3, Math.max(0, mf.strength)) / 3;
    mw = [0, 1, 2].map((c) => MONO_W.none[c] + (f[c] - MONO_W.none[c]) * k) as [number, number, number];
    const t = mw[0] + mw[1] + mw[2];
    mw = [mw[0] / t, mw[1] / t, mw[2] / t];
  }
  const cosS = new Float64Array(BINS), sinS = new Float64Array(BINS);
  for (let b = 0; b < BINS; b++) { cosS[b] = lut.satMul[b] * Math.cos(lut.shift[b]); sinS[b] = lut.satMul[b] * Math.sin(lut.shift[b]); }
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
      y += lut.lsum[bin] * Math.min(1, chroma / 0.25);
      const c0 = cb;
      cb = c0 * cosS[bin] - cr * sinS[bin]; cr = c0 * sinS[bin] + cr * cosS[bin];
    }
    let R = y + 1.402 * cr, G = y - 0.344136 * cb - 0.714136 * cr, B = y + 1.772 * cb;
    R = clamp01(R); G = clamp01(G); B = clamp01(B);
    if (mono) R = G = B = mw[0] * R + mw[1] * G + mw[2] * B;
    img[q] = R; img[q + 1] = G; img[q + 2] = B;
  }
  if (om3 && (look.split || look.rgb)) bendSplit(img, n, look.split, OM3_CAL.split, look.tone_balance ?? 0, look.rgb);   // OM-3 v0.26 split toning (the camera bends its gamma curves); v0.28 Tone Balance; RGB curves
  // OM-3: Sharp and Film Grain are part of the camera's development, before Glow (Soft Focus), Halation, Shading, Border
  if (om3) om3Sharp(img, w, h, look.advice.sharpness ?? 0);
  if (om3 && look.film_grain) om3Grain(img, w, h, look.grain_strength ?? GRAIN_STRENGTH[Math.min(3, look.film_grain)], look.grain_size ?? 2);
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
      // OM-3 (calibration card 2, 2026-11-18): the camera's Soft Focus copy is a blur of about sigma 48 camera pixels and
      // adds no light (Glow +3 / +5 fitted 0.18 / 0.33 against the firmware's 0.20 / 0.35, sigma 48, brightness -2 %)
      const bl = om3 ? blurredCopy(img, w, h, w / Math.max(1, Math.round((Math.max(w, h) * 24) / FULL_WIDTH)), 2) : blurredCopy(img, w, h, 160, 1.2);
      const sh = BLOOM_SHARE[st], lift = om3 ? 1 : 1.08;
      for (let i = 0; i < n * 3; i += 3) {
        for (let c = 0; c < 3; c++) img[i + c] = clamp01((1 - sh) * img[i + c] + sh * Math.min(1, bl[i + c] * tint[c] * lift));
      }
    }
  }
  lastHalation = om3 && look.halation ? om3Halation(img, w, h, look.halation) : null;   // OM-3 v0.28: after the Soft Focus blend, as the camera
  // 6. OM-3 Shading and Border (the camera's passes on the finished photo); grain (E-P7: Olympus xorshift32 luma grain)
  if (om3 && look.vignette) om3Shading(img, w, h, look.vignette);
  if (om3 && look.border) om3Border(img, w, h, look.border, opt.crop);
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
 *  less on bright cells). h7's fade again since v0.40-beta3 (the camera dropped h8's wide layer: faster). */
/** What Halation did on the last preview: 'off' = the photo is too bright (the camera skips it too), 'none' = no bright
 *  lights, 'done', or null (not set). */
export let lastHalation: 'off' | 'none' | 'done' | null = null;
const HL = { T: 200, K: 900, BLUR: 3, BLUR2: 10, MIX: 128, GMAX: [0, 43, 78, 113, 156, 208], KY: 44, KCB: -40, KCR: 60, WMUL: 2, COV_U: 32, COV_LO: 8, COV_HI: 24,
  DLO: 60, DHI: 72, DCOV: 16 };   // DLO / DHI / DCOV: the preview's dark-photo allowance (not in the firmware)
function om3Halation(img: Float32Array, w: number, h: number, level: number): 'off' | 'none' | 'done' {
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
  let cov = bright >= hi ? 0 : bright <= lo ? 1 : (hi - bright) / (hi - lo);   // many bright cells: daylight, fade out
  // Preview only (owner, 2026-11-12; the camera keeps its own rule): a dark photo (night) keeps the glow, toned down
  // when many cells are lit. The sample night streets are brighter, edited JPEGs that pass the camera's bright-frame
  // cut-off, where the owner's own night shots get the glow on the camera.
  let mb = 0; for (let g = 0; g < Bs.length; g++) mb += Bs[g];
  const f = Math.min(1, (HL.DHI - mb / Bs.length) / (HL.DHI - HL.DLO));
  if (f > 0) cov = Math.max(cov, (bright ? Math.min(1, (u.length * HL.DCOV) / (100 * bright)) : 1) * f);
  if (cov <= 0) return 'off';                // a bright frame (daylight): no halation
  const G = u.map((x) => (x * HL.GMAX[Math.min(5, level)] / 256) * cov);
  if (!G.some((x) => x >= 1)) return 'none';
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
  return 'done';
}

/** OM-3 Sharp (-5..+2): an unsharp mask on luma (negative softens), sized so the preview changes as much as the
 *  camera's photo does when shrunk to the preview (calibration card 2, 2026-11-18: Sharp +2 / -5 at 1296 px). */
const SHARP_AMT = { up: 0.05, down: [0, 0.07, 0.14, 0.22, 0.31, 0.4] };
function om3Sharp(img: Float32Array, w: number, h: number, sharp: number) {
  if (!sharp) return;
  const n = w * h, k = Math.min(4, (Math.max(w, h) / 1296) ** 2);   // the camera's sharpening is per camera pixel: more of it shows on a larger preview
  const amt = (sharp > 0 ? SHARP_AMT.up * sharp : -SHARP_AMT.down[Math.min(5, -sharp)]) * k;
  const Y = new Float32Array(n);
  for (let i = 0; i < n; i++) Y[i] = 0.299 * img[i * 3] + 0.587 * img[i * 3 + 1] + 0.114 * img[i * 3 + 2];
  for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) {
    const i = y * w + x;
    const bl = (Y[i - w - 1] + 2 * Y[i - w] + Y[i - w + 1] + 2 * Y[i - 1] + 4 * Y[i] + 2 * Y[i + 1] + Y[i + w - 1] + 2 * Y[i + w] + Y[i + w + 1]) / 16;
    const dl = Math.max(-1, amt) * (Y[i] - bl), q = i * 3;
    img[q] = clamp01(img[q] + dl); img[q + 1] = clamp01(img[q + 1] + dl); img[q + 2] = clamp01(img[q + 2] + dl);
  }
}

/** OM-3 Vignette Correction Off: the lens's own corners, in linear light, as the camera leaves them (calibration card 2,
 *  2026-11-18: OM 17 mm f/1.8 II at f/4, corners 0.84 of the centre). Other lenses and apertures differ. */
function lensFalloff(w: number, h: number): Float32Array {
  const f = new Float32Array(w * h), cx = (w - 1) / 2, cy = (h - 1) / 2, R2 = (w * w + h * h) / 4;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const r2 = ((x - cx) ** 2 + (y - cy) ** 2) / R2;
    f[y * w + x] = 1 - 0.18 * Math.min(1, r2) ** 1.2;
  }
  return f;
}

/** OM-3 Shading -5..+5: the camera's own (as on v0.40-beta: v0.41-dev test 7 went back to it, 2026-11-18). Measured on a plain
 *  wall, every level (card backup 2026-11-18-shading-stock-levels, PB183616..626: Shading 0, then -5..-1, +1..+5; OM
 *  17 mm f/1.8, exposure matched at the centre): a radial mask m(r), r = the distance from the centre / the
 *  half-diagonal, nothing inside r 0.4 and most of it past r 0.8. Darker blends toward black, Y' = Y (1 - m), lighter
 *  toward white, Y' = 1 - (1 - Y)(1 - m), the colour toward grey by the same amount (probe s1, 2026-11-12). The tables
 *  are the measured m at SHADE_R (the last point extended to the corner); -2 also matches the probe p1 photos. */
const SHADE_R = [0.3, 0.325, 0.375, 0.425, 0.475, 0.525, 0.575, 0.625, 0.675, 0.725, 0.775, 0.825, 0.875, 0.925, 0.975, 1];
const SHADE_DARK = [
  [0, 0, 0, 0, 0.018, 0.053, 0.083, 0.127, 0.178, 0.234, 0.31, 0.448, 0.617, 0.737, 0.835, 0.884],
  [0, 0, 0, 0.002, 0.023, 0.065, 0.11, 0.153, 0.211, 0.279, 0.36, 0.508, 0.677, 0.794, 0.886, 0.932],
  [0, 0, 0, 0.002, 0.03, 0.078, 0.128, 0.176, 0.238, 0.309, 0.392, 0.549, 0.721, 0.836, 0.916, 0.956],
  [0, 0, 0.001, 0.013, 0.043, 0.095, 0.169, 0.214, 0.276, 0.345, 0.422, 0.599, 0.766, 0.874, 0.937, 0.969],
  [0, 0, 0.003, 0.021, 0.059, 0.118, 0.19, 0.253, 0.317, 0.391, 0.478, 0.668, 0.825, 0.917, 0.964, 0.987]];
const SHADE_LIGHT = [
  [0, 0, 0, 0.004, 0.021, 0.046, 0.085, 0.126, 0.179, 0.265, 0.351, 0.465, 0.595, 0.72, 0.809, 0.854],
  [0, 0, 0, 0.004, 0.025, 0.054, 0.097, 0.148, 0.211, 0.311, 0.396, 0.517, 0.654, 0.775, 0.859, 0.901],
  [0, 0, 0.004, 0.008, 0.035, 0.068, 0.117, 0.175, 0.248, 0.355, 0.441, 0.567, 0.709, 0.824, 0.904, 0.944],
  [0, 0, 0.004, 0.015, 0.039, 0.084, 0.148, 0.199, 0.268, 0.377, 0.476, 0.606, 0.739, 0.849, 0.919, 0.954],
  [0, 0, 0.004, 0.017, 0.05, 0.096, 0.176, 0.23, 0.305, 0.417, 0.523, 0.662, 0.786, 0.883, 0.937, 0.964]];
/** m by r^2 (513 steps) for a measured row: a monotone cubic through the points, 0 inside the first. */
function shadeTable(v: number[]): Float32Array {
  const X = SHADE_R, n = X.length, hh = X.slice(0, -1).map((x, i) => X[i + 1] - x), d = hh.map((w, i) => (v[i + 1] - v[i]) / w);
  const t = new Array<number>(n).fill(0);
  t[n - 1] = d[n - 2];
  for (let i = 1; i < n - 1; i++) {
    if (d[i - 1] * d[i] <= 0) continue;
    const w1 = 2 * hh[i] + hh[i - 1], w2 = hh[i] + 2 * hh[i - 1];
    t[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i]);
  }
  return Float32Array.from({ length: 513 }, (_, k) => {
    const r = Math.sqrt(k / 512);
    if (r <= X[0]) return 0;
    let i = 0;
    while (i < n - 2 && r > X[i + 1]) i++;
    const sp = Math.min(1, (r - X[i]) / hh[i]), s2 = sp * sp, s3 = s2 * sp;
    return Math.max(0, Math.min(1, (2 * s3 - 3 * s2 + 1) * v[i] + (s3 - 2 * s2 + sp) * hh[i] * t[i] + (-2 * s3 + 3 * s2) * v[i + 1] + (s3 - s2) * hh[i] * t[i + 1]));
  });
}
const shadeTables = new Map<number, Float32Array>();
function om3Shading(img: Float32Array, w: number, h: number, level: number) {
  const L = Math.max(-5, Math.min(5, level));
  let T = shadeTables.get(L);
  if (!T) { T = shadeTable((L < 0 ? SHADE_DARK : SHADE_LIGHT)[Math.abs(L) - 1]); shadeTables.set(L, T); }
  const D = w * w + h * h;
  for (let y = 0; y < h; y++) {
    const Yc = (2 * y + 1 - h) ** 2;
    for (let x = 0; x < w; x++) {
      const m = T[Math.min(512, Math.round((((2 * x + 1 - w) ** 2 + Yc) * 512) / D))];
      if (m <= 0) continue;
      const g = 1 - m;                           // what is left of the pixel's distance to the target
      const q = (y * w + x) * 3, r = img[q], gg = img[q + 1], b = img[q + 2];
      const Y = 0.299 * r + 0.587 * gg + 0.114 * b;
      const cb = (-0.168736 * r - 0.331264 * gg + 0.5 * b) * g, cr = (0.5 * r - 0.418688 * gg - 0.081312 * b) * g;
      const Y2 = L < 0 ? Y * g : 1 - (1 - Y) * g;
      img[q] = clamp01(Y2 + 1.402 * cr); img[q + 1] = clamp01(Y2 - 0.344136 * cb - 0.714136 * cr); img[q + 2] = clamp01(Y2 + 1.772 * cb);
    }
  }
}

/** OM-3 Border -5..+5 (firmware v0.40 bd_run, research/border/model.py; camera-tested 2026-11-18): white (1..5) or black
 *  (-1..-5), the same width on every side, 1.5 / 3 / 4.5 / 6 / 7.5 % of the short side of the photo as kept (the crop). */
const BORDER_T = [983, 1966, 2949, 3932, 4915];
function om3Border(img: Float32Array, w: number, h: number, level: number, crop: CropRect = { x: 0, y: 0, w, h }) {
  const { x: x0, y: y0, w: cw, h: ch } = crop, v = level > 0 ? 1 : 0;
  const B = Math.max(1, Math.round((Math.min(cw, ch) * BORDER_T[Math.min(5, Math.abs(level)) - 1]) / 65536));
  for (let y = y0; y < y0 + ch; y++) for (let x = x0; x < x0 + cw; x++) {
    if (y >= y0 + B && y < y0 + ch - B && x >= x0 + B && x < x0 + cw - B) { x = x0 + cw - B - 1; continue; }
    const q = (y * w + x) * 3; img[q] = img[q + 1] = img[q + 2] = v;
  }
}

/** OM-3 Film Grain (firmware v0.40.2 grain colour g6: editor.s tg_fill, research/grain/tile_model.py G4_SIZE, G6_C). The
 *  camera adds a colour grain tile in its development: Y = uniform random bytes through a small round filter both ways,
 *  sigma 16 (8-bit): Fine single pixels, Medium 1-3-1, Coarse 1-3-3-1 (v0.40: a w x w box); Cb / Cr at half width and
 *  (from v0.40.2) full height: Fine and Medium 1-1 down, single samples across, Coarse 1-3-3-1 down, 1-6-1 across;
 *  Cb sigma 16, Cr 9 (from v0.40.2: blue-yellow, as colour film; v0.40.1 Cr 16 and half height); times the strength's gain,
 *  Y 400 / 650 / 1024 / 1280 / 1536 of 1024 for 1..5, Cb / Cr 0.4375 of it. LOOKS.BIN's Low / Med / High are 2 / 3 / 5
 *  at Medium. Calibration card 2 (2026-11-18): the camera's grain at 2 / 3 / 5 measured 10.6 / 15.9 / 23.8 (Y, full
 *  size), the model 10.2 / 16 / 24, about the same in every tone. The preview shows the photo as it looks shrunk to the
 *  preview: each preview pixel is the mean of the tile over the camera pixels it covers. The JPEG keeps colour at half
 *  size, which takes about 14 % off the colour speckle (card 2: Cb / Cr 2.9..4.5 against 3.5..5.1 without it). */
export const GRAIN_STRENGTH = [0, 2, 3, 5];
const GRAIN_GAIN = [0, 400, 650, 1024, 1280, 1536];
const GT_W = 1536, GT_H = 768;                     // the tile: 1536 x 1536 camera pixels, rows repeating every 768
const G4_TAPS: Record<number, number[]> = { 1: [1], 2: [1, 3, 1], 3: [1, 3, 3, 1] };   // Y, both ways
const G6_C: Record<number, [number[], number[]]> = { 1: [[1, 1], [1]], 2: [[1, 1], [1]], 3: [[1, 3, 3, 1], [1, 6, 1]] };   // Cb / Cr: down, across
const grainTiles = new Map<number, Float32Array[]>();
function grainTile(size: number): Float32Array[] {
  const hit = grainTiles.get(size);
  if (hit) return hit;
  let st = 0x9e3779b9 ^ size;
  const rnd = () => { st ^= st << 13; st >>>= 0; st ^= st >>> 17; st ^= st << 5; st >>>= 0; return st & 255; };
  const sum = (h: number[], p: number) => h.reduce((a, b) => a + b ** p, 0);
  const plane = (W: number, H: number, hv: number[], hh: number[], sigma: number, lo: number, hi: number) => {
    const u = new Float32Array(W * H), row = new Float32Array(W * H), out = new Float32Array(W * H);
    for (let i = 0; i < u.length; i++) u[i] = rnd();
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { let a = 0; for (let k = 0; k < hh.length; k++) a += hh[k] * u[y * W + ((x + k) % W)]; row[y * W + x] = a; }
    const kt = sigma / (73.9 * Math.sqrt(sum(hv, 2) * sum(hh, 2))), mean = 127.5 * sum(hv, 1) * sum(hh, 1);   // tg_g4p: K
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      let a = 0; for (let k = 0; k < hv.length; k++) a += hv[k] * row[((y + k) % H) * W + x];
      out[y * W + x] = Math.max(lo, Math.min(hi, kt * (a - mean))) / 255;
    }
    return out;
  };
  const hy = G4_TAPS[size], [cv, ch] = G6_C[size];
  const t = [plane(GT_W, GT_H, hy, hy, 16, -48, 207), plane(GT_W / 2, GT_H, cv, ch, 16, -128, 127), plane(GT_W / 2, GT_H, cv, ch, 9, -128, 127)];
  grainTiles.set(size, t);
  return t;
}
function om3Grain(img: Float32Array, w: number, h: number, strength: number, size: number) {
  if (!strength) return;
  const gy = GRAIN_GAIN[Math.min(5, strength)] / 1024, gc = 0.86 * 0.4375 * gy, tiles = grainTile(Math.max(1, Math.min(3, size)));
  const sc = Math.max(1, FULL_WIDTH / Math.max(w, h));   // camera pixels per preview pixel
  // per plane: the mean of the tile over each preview pixel's footprint (rows summed, then a running sum along the row)
  const field = (t: Float32Array, TW: number, TH: number, k: number, ky = k) => {
    const out = new Float32Array(w * h), acc = new Float64Array(TW), P = new Float64Array(TW + 1);
    const cx = new Int32Array(w + 1);
    for (let x = 0; x <= w; x++) cx[x] = Math.round((x * sc) / k);
    const sumTo = (c: number) => Math.floor(c / TW) * P[TW] + P[c % TW];
    for (let y = 0; y < h; y++) {
      const r0 = Math.round((y * sc) / ky) + 211, r1 = Math.max(r0 + 1, Math.round(((y + 1) * sc) / ky) + 211);
      acc.fill(0);
      for (let r = r0; r < r1; r++) { const o = (r % TH) * TW; for (let x = 0; x < TW; x++) acc[x] += t[o + x]; }
      for (let x = 0; x < TW; x++) P[x + 1] = P[x] + acc[x];
      for (let x = 0; x < w; x++) {
        const c0 = cx[x] + 97, c1 = Math.max(c0 + 1, cx[x + 1] + 97);
        out[y * w + x] = (sumTo(c1) - sumTo(c0)) / ((c1 - c0) * (r1 - r0));
      }
    }
    return out;
  };
  const nY = field(tiles[0], GT_W, GT_H, 1), nB = field(tiles[1], GT_W / 2, GT_H, 2, 1), nR = field(tiles[2], GT_W / 2, GT_H, 2, 1);
  for (let i = 0; i < w * h; i++) {
    const q = i * 3, r = img[q], g = img[q + 1], b = img[q + 2];
    const Y = clamp01(0.299 * r + 0.587 * g + 0.114 * b + gy * nY[i]);
    const cb = -0.168736 * r - 0.331264 * g + 0.5 * b + gc * nB[i], cr = 0.5 * r - 0.418688 * g - 0.081312 * b + gc * nR[i];
    img[q] = clamp01(Y + 1.402 * cr); img[q + 1] = clamp01(Y - 0.344136 * cb - 0.714136 * cr); img[q + 2] = clamp01(Y + 1.772 * cb);
  }
}
