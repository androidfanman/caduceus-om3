#!/usr/bin/env python3
"""Split toning on the OM-3: our own design, modelled in integers the way camera code would run it.

The camera's RGB gamma stage copies one curve (picture modes) or three curves (Cross Process, Vintage, ...) into the
job: O+1252 R / +1892 G / +2532 B, 256 x u16, 12-bit (see curves.py, research/NOTES.md "Split toning"). Split
toning = after that copy, bend each channel's curve by a shadow and a highlight amount:

    t  = curve[i]  (0..4095),  s = 4095 - t
    ws = ((t * s >> 12) * s) >> 12        shadow weight, peak 606 at t = 1/3, 0 at black and white
    wh = ((t * t >> 12) * s) >> 12        highlight weight, peak 606 at t = 2/3
    curve_c[i] = clamp(t + ((Ks_c * ws + Kh_c * wh) >> 8), 0, 4095)        Ks_c, Kh_c: s8 per channel

Black and white stay put, the curve stays rising (|K| <= 127 -> slope change <= 0.5). A look needs 6 signed bytes
(Ks R,G,B, Kh R,G,B), computed on the Control Panel from a hue (12 steps, as the colour wheel) and a strength 0..5.

usage: python3 model.py [MAIN.decoded.bin] [preview.png]   (default $OM3_MAIN). Prints the grey tints of example
looks; with a PNG path also draws a grey ramp + colour strips for them (needs Pillow).
"""
import math, os, sys
import numpy as np

BASE, BASE_CURVE = 0x60021020, 0x6066c04c          # picture-mode curve object (column 0)
CHROMA = [0, 2, 4, 6, 8, 10]                       # strength 0..5 -> grey tint at the weight peak, 8-bit Cb/Cr units

def base_curve(path):
    b = open(path, 'rb').read(); o = BASE_CURVE - BASE
    return np.frombuffer(b[o + 144:o + 656], '<u2').astype(np.int64)

def k_values(hue_step, strength):
    """hue_step 0..11 (30 degrees each in the Cb/Cr plane, 0 = blue, 3 = red, 6 = yellow, 9 = green), strength 0..5
    -> (K_R, K_G, K_B) s8 so that a grey at the weight peak moves by CHROMA[strength] in that direction."""
    th = math.radians(30 * hue_step); cb, cr = math.cos(th), math.sin(th)
    d = (1.402 * cr, -0.344 * cb - 0.714 * cr, 1.772 * cb)
    return tuple(max(-127, min(127, round(x * CHROMA[strength] * 16 * 256 / 606))) for x in d)

def bend(curve, ks, kh):
    out = []
    for c in range(3):
        t = curve.copy(); s = 4095 - t
        ws = ((t * s >> 12) * s) >> 12; wh = ((t * t >> 12) * s) >> 12
        out.append(np.clip(t + ((ks[c] * ws + kh[c] * wh) >> 8), 0, 4095))
    return out

def bend28(curve, ks, kh, balance=0):
    """v0.28 (firmware st_run, bit-exact in om-emu): half the v0.26 step (>> 9), and the Tone Balance b (-5..+5) moves
    the hand-over point c = 2048 - 256 b: the weights are taken at u (= t when b = 0), u = t * 2048 / c below c and
    2048 + (t - c) * 2047 / (4095 - c) above (16.16 factors, as the camera). + = the highlight colour covers more.
    ks, kh: st_k[colour] x strength (0..5) per channel. Each of the camera's two table parts (256 + 64 entries) is
    kept rising on its own (running max); here one 256-entry curve."""
    c = 2048 - 256 * max(-5, min(5, balance)); f1 = 134217728 // c; f2 = 134152192 // (4095 - c)
    out = []
    for ch in range(3):
        res, mx = [], 0
        for t in (int(x) for x in curve):
            u = (t * f1) >> 16 if t < c else (((t - c) * f2) >> 16) + 2048
            sv = 4095 - u; ws = ((u * sv >> 12) * sv) >> 12; wh = ((u * u >> 12) * sv) >> 12
            v = max(mx, max(0, min(4095, t + ((ks[ch] * ws + kh[ch] * wh) >> 9)))); mx = v; res.append(v)
        out.append(np.array(res))
    return out

def ycc(r, g, b):
    y = 0.299 * r + 0.587 * g + 0.114 * b
    return y, 0.564 * (b - y), 0.713 * (r - y)

HUES = {'blue': 0, 'magenta': 2, 'red': 3, 'orange': 5, 'yellow': 6, 'green': 9, 'teal': 11}
LOOKS = {   # examples only (not film copies): (shadow hue, strength, highlight hue, strength)
    'teal shadows / warm highlights': ('teal', 4, 'orange', 3),
    'cool shadows': ('blue', 3, 'yellow', 1),
    'green shadows': ('green', 3, 'magenta', 1),
}

if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].endswith('.png') else os.environ.get('OM3_MAIN')
    png = next((a for a in sys.argv[1:] if a.endswith('.png')), None)
    base = base_curve(path)
    print('hue steps (strength 5): ' + ', '.join(f'{h}={k_values(i, 5)}' for h, i in HUES.items()))
    curves = {}
    for name, (sh, ss, hh, hs) in LOOKS.items():
        ks, kh = k_values(HUES[sh], ss), k_values(HUES[hh], hs)
        R, G, B = bend(base, ks, kh); curves[name] = (R, G, B)
        mono = all((np.diff(x) >= 0).all() for x in (R, G, B))
        print(f'{name}: Ks {ks} Kh {kh}, curves rising: {mono}')
        for i in (8, 16, 32, 64, 128, 192):
            y, cb, cr = ycc(*(x[i] / 16 for x in (R, G, B)))
            print(f'   input {i:3d}  Y {y:5.1f}  Cb {cb:+5.1f}  Cr {cr:+5.1f}')
    if png:
        from PIL import Image
        W, rows = 768, []
        lin = np.linspace(0, 1, W) ** 2.2                       # scene ramp, dark to bright
        idx = np.clip((lin * 255).round().astype(int), 0, 255)
        strips = [(1, 1, 1), (1, .55, .35), (.35, .6, 1), (.4, .8, .35), (.9, .75, .55)]   # grey, warm, sky, foliage, skin-ish
        def render(R, G, B):
            img = []
            for (fr, fg, fb) in strips:
                ri = np.clip((idx * fr).astype(int), 0, 255); gi = np.clip((idx * fg).astype(int), 0, 255)
                bi = np.clip((idx * fb).astype(int), 0, 255)
                row = np.stack([R[ri], G[gi], B[bi]], -1) / 16
                img += [row] * 40
            return np.array(img)
        panels = [render(base, base, base)] + [render(*c) for c in curves.values()]
        sep = np.full((8, W, 3), 255.0)
        out = np.concatenate(sum([[p, sep] for p in panels], [])[:-1]).clip(0, 255).astype(np.uint8)
        Image.fromarray(out).save(png)
        print('preview:', png, '(top: stock COLOR; then', ', '.join(curves), ')')
