#!/usr/bin/env python3
"""The colour wheel's H / S / L bar, round 2 (experiment/wheel-hsl-view): what the firmware puts together under the
wheel, and the same picture made here (the emulator test compares the firmware's with it byte for byte).

The bar: 400 x 50 in the guide picture's place (its two widgets widened by build.py's DATA), OSD type 11, the guide
plane's palette (om-emu, 2026-11-22: about 25 strong colours, many greys, no cyan, no pale tints; indices 128.. not
drawn). Left to right: a swatch of the colour under the cursor (its hue turned by its Hue value), then H, S and L,
each its value ("H+2") and a coloured slider of 11 steps with a mark under the value's step:
- H: the neighbouring shades (the colour's hue -27 .. +27 degrees, 5.5 a step, as the camera turns it);
- S: grey to the full colour, L: dark through the colour to light, both in the colour as its Hue value turns it.
The page's field shows its value white-boxed. Colours the palette lacks are two palette colours in alternating rows
(1, 2 or 3 rows in 4), so each row of a step stays one run.

Each row of the bar is a list of parts, encoded part by part (runs of up to 16 stopping at each part's edge):
  swatch (46 px) | for H, S, L: text (46 px), slider (72 px).
Fixed parts (blank rows, frames, letters, marks) are encoded here once each (hb_rows / hb_tok); the slider rows
11..30 and the swatch rows 8..41 are made at each redraw from colour tables (hb_seg): a fixed head, the steps (one
colour each, chosen per row by its 4-row mask), a fixed tail. hbar.s does exactly what stream() does.

usage: mkhbar.py OUT.inc [--preview PNG]"""
import argparse, colorsys
import numpy as np
from PIL import Image, ImageDraw
from mkguides import raster, edge

W, H = 400, 50
BG = 72                               # the bar's ground: (13, 13, 13), opaque, so the camera's button frame behind it
                                      # (180 px, centred in the widened widget) stays hidden
SWW, TW, SLW = 46, 46, 72             # swatch, text, slider widths; a field = text + slider = 118; 46 + 3 * 118 = 400
SW_Y0, SW_Y1 = 6, 43                  # the swatch box's rows (outline rows 6, 43; fill rows 8..41 between 2-px lines)
SL_Y0, SL_Y1 = 10, 31                 # the slider's outline rows; its fill rows 11..30
MK_Y0, MK_Y1 = 32, 42                 # the mark's rows
STEPW, NSTEP = 6, 11                  # 11 steps of 6 px (slider cols 2..67; outline cols 1, 68)
CAP = 17                              # the value's cap height
HUE = [60, 35, 15, 355, 320, 280, 235, 205, 180, 155, 120, 85]   # docs/PHOTO_TO_LOOK.md, slices 0..11
DEG = 5.5                             # degrees of hue a step; + turns toward the next slice (lower HSV hue)
FIELD_OF_AXIS = {2: 0, 0: 1, 1: 2}    # the editor's page (P+AXIS: 2 Hue, 0 Saturation, 1 Luminance) -> its field
GHDR = bytes([(H - 1) & 255, ((H - 1) >> 8 & 3) | (((W - 1) & 15) << 4), ((W - 1) >> 4) & 63, 11])
MASKS = (0b0000, 0b0001, 0b0101, 0b0111)   # rows (y & 3) that take colour B, for B's share 0, 1/4, 1/2, 3/4
# the guide plane's palette (om-emu probe, 2026-11-22), the colours the mixes may use
PAL = {7: (0, 0, 0), 12: (85, 85, 85), 64: (128, 128, 128), 11: (170, 170, 170), 98: (235, 235, 235),
       10: (254, 254, 254), 122: (254, 0, 0), 90: (253, 0, 83), 89: (254, 0, 254), 88: (138, 27, 253),
       87: (49, 52, 253), 104: (0, 0, 254), 105: (19, 116, 247), 107: (63, 173, 252), 2: (94, 175, 254),
       86: (0, 172, 39), 54: (1, 207, 0), 22: (0, 255, 0), 23: (0, 170, 0), 24: (0, 85, 0), 1: (212, 255, 0),
       20: (141, 171, 0), 21: (70, 86, 0), 123: (254, 255, 1), 16: (253, 105, 0), 17: (168, 70, 0), 18: (83, 35, 0),
       55: (207, 87, 1)}
SHOW = {**PAL, 0: (11, 11, 11), BG: (13, 13, 13), 9: (5, 5, 5)}   # for previews


def _lin(c):
    c = c / 255
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _lab(lin):
    x, y, z = (sum(m * v for m, v in zip(row, lin)) for row in
               ((0.4124, 0.3576, 0.1805), (0.2126, 0.7152, 0.0722), (0.0193, 0.1192, 0.9505)))
    f = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x / 0.9505), f(y), f(z / 1.089)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


_KEYS = sorted(PAL)
_LABS = np.array([_lab(tuple(_lin(v) for v in PAL[k])) for k in _KEYS])
_LINS = np.array([[_lin(v) for v in PAL[k]] for k in _KEYS])


def _mixes():
    """Every candidate: (A, B, share of B) with its Lab colour (the mix of the two in linear light)."""
    cand, labs = [], []
    for ia, a in enumerate(_KEYS):
        for ib, b in enumerate(_KEYS):
            for k, sh in enumerate((0, .25, .5, .75)):
                if (k == 0) != (a == b): continue
                cand.append((ia, ib, k, sh)); labs.append(_lab(tuple(_LINS[ia] * (1 - sh) + _LINS[ib] * sh)))
    return cand, np.array(labs)


_CAND, _CLAB = _mixes()
_CA = np.array([c[0] for c in _CAND]); _CB = np.array([c[1] for c in _CAND]); _CS = np.array([c[3] for c in _CAND])
HUES = {122, 90, 89, 88, 87, 104, 105, 107, 2, 86, 54, 22, 1, 123, 16, 55}   # the strong colours (no greys, no darks)
_HOK = np.array([_KEYS[a] in HUES and _KEYS[b] in HUES for a, b in zip(_CA, _CB)])


def mix(target):
    """target sRGB (0..255) -> (A, B, mask): two strong palette colours and B's share (row dither), nearest in Lab,
    each of the two weighed by its own distance too (no far-apart pairs)."""
    tl = np.array(_lab(tuple(_lin(v) for v in target)))
    d = np.sqrt(((_CLAB - tl) ** 2).sum(1))
    da = np.sqrt(((_LABS[_CA] - tl) ** 2).sum(1)); db = np.sqrt(((_LABS[_CB] - tl) ** 2).sum(1))
    e = np.where(_HOK, d + 0.5 * ((1 - _CS) * da + _CS * db), np.inf)
    ia, ib, k, _ = _CAND[int(np.argmin(e))]
    return _KEYS[ia], _KEYS[ib], MASKS[k]


def nearest(target):
    """The strong palette colour nearest to target (Lab)."""
    tl = np.array(_lab(tuple(_lin(v) for v in target)))
    return min(HUES, key=lambda k: ((_LABS[_KEYS.index(k)] - tl) ** 2).sum())


def share(a, b, t):
    """a to b, b's share t (0..1) in quarters -> (A, B, mask)."""
    q = round(4 * t)
    return (b, b, 0) if q >= 4 else (a, a, 0) if q <= 0 else (a, b, MASKS[q])


def hsv(h, s=1.0, v=1.0):
    return tuple(round(255 * x) for x in colorsys.hsv_to_rgb((h % 360) / 360, s, v))


def blend(a, b, t):
    return tuple(round(x * (1 - t) + y * t) for x, y in zip(a, b))


GREY, BLACK, WHITE = 64, 7, 10


def colours(c, h):
    """slice c, its Hue value h -> 34 (A, B, mask): the swatch, H's, S's and L's 11 steps. The swatch and H: the hue
    as near as two strong colours mixed get; S: grey to the colour, L: black to the colour to white, the colour = the
    strong palette colour nearest to the turned hue (so S and L change when the Hue value turns it far enough)."""
    full = hsv(HUE[c] - DEG * h)
    col = nearest(full)
    hs = [mix(hsv(HUE[c] - DEG * v)) for v in range(-5, 6)]
    ss = [share(GREY, col, (v + 5) / 10) for v in range(-5, 6)]
    ls = [share(BLACK, col, 1 - 0.75 * -v / 5) if v < 0 else share(col, WHITE, 0.75 * v / 5) for v in range(-5, 6)]
    return [mix(full)] + hs + ss + ls


def _fit(cap):
    for fs in range(8, 60):
        r = np.nonzero((raster('H', fs, 1.0) > 128).any(axis=1))[0]
        if r.max() - r.min() + 1 >= cap: return fs
    raise SystemExit('no font size fits')


def text_part(f, v, active, fs):
    """46 x 50: 'H+2' centred on row 21; on the page's field dark letters in a white rounded box."""
    word = 'HSL'[f] + ('+' if v > 0 else '−' if v < 0 else '±') + str(abs(v))
    a = raster(word, fs, 0.8)
    base = np.nonzero((raster('H', fs, 0.8) > 128).any(axis=1))[0].max()
    top = base - CAP + 1
    a = a[top - 2:base + 3]                       # cap rows plus 2 above, 2 below (the minus / plus-minus fit)
    cols = np.nonzero((a > 40).any(axis=0))[0]; a = a[:, cols.min():cols.max() + 1]
    hh, ww = a.shape
    assert ww <= TW - 8, (word, ww)
    y0 = 21 - (CAP + 4) // 2; x0 = (TW - ww) // 2
    out = np.full((H, TW), BG, dtype=np.uint8)
    if active:
        S = 4
        im = Image.new('L', (TW * S, H * S), 0)
        ImageDraw.Draw(im).rounded_rectangle((1 * S, 7 * S, (TW - 1) * S - 1, 36 * S - 1), radius=5 * S, fill=255)
        box = np.array(im.resize((TW, H), Image.LANCZOS))
        out[box > 128] = 10; out[(box > 40) & (box <= 128)] = 11
        reg = out[y0:y0 + hh, x0:x0 + ww]
        reg[a > 128] = 7; reg[(a > 40) & (a <= 128) & (reg == 10)] = 12
    else:
        m = np.zeros((H, TW), dtype=bool); s = np.zeros((H, TW), dtype=bool)
        m[y0:y0 + hh, x0:x0 + ww] = a > 128; s[y0:y0 + hh, x0:x0 + ww] = (a > 40) & (a <= 128)
        e = edge(m, s & ~m)
        out[e != 0] = e[e != 0]
    return out


def mark_part(v):
    """72 x 50, rows MK_Y0..MK_Y1 only: a white triangle pointing up at step v's centre."""
    out = np.full((H, SLW), BG, dtype=np.uint8)
    cx = 2 + STEPW * (v + 5) + STEPW / 2
    S = 4
    im = Image.new('L', (SLW * S, H * S), 0)
    ImageDraw.Draw(im).polygon([(cx * S, 34 * S), ((cx - 4.5) * S, 40 * S), ((cx + 4.5) * S, 40 * S)], fill=255)
    tri = np.array(im.resize((SLW, H), Image.LANCZOS)) > 100
    e = edge(tri)
    out[e != 0] = e[e != 0]
    assert not (out[:MK_Y0] != BG).any() and not (out[MK_Y1 + 1:] != BG).any()
    return out


SW_FILL = SWW - 10                    # 36 px of swatch colour between head and tail


def fixed_rows():
    """The fixed row parts besides text and marks: name -> 1-D array."""
    sw_edge = np.full(SWW, BG, dtype=np.uint8); sw_edge[3:SWW - 3] = 7
    sw_line = np.full(SWW, BG, dtype=np.uint8); sw_line[3] = sw_line[SWW - 4] = 7; sw_line[4:SWW - 4] = 10
    sl_edge = np.full(SLW, BG, dtype=np.uint8); sl_edge[1:2 + STEPW * NSTEP + 1] = 7
    u8 = lambda xs: np.array(xs, dtype=np.uint8)
    return {'sw_blank': np.full(SWW, BG, dtype=np.uint8), 'sw_edge': sw_edge, 'sw_line': sw_line,
            'sw_head': u8([BG, BG, BG, 7, 10]), 'sw_tail': u8([10, 7, BG, BG, BG]),
            'sl_blank': np.full(SLW, BG, dtype=np.uint8), 'sl_edge': sl_edge,
            'sl_head': u8([BG, 7]), 'sl_tail': u8([7, BG, BG, BG])}


def pieces():
    fs = _fit(CAP)
    return dict(text=[[[text_part(f, v, a, fs) for v in range(-5, 6)] for a in (0, 1)] for f in range(3)],
                mark=[mark_part(v) for v in range(-5, 6)], fixed=fixed_rows(),
                spec={(c, h): colours(c, h) for c in range(12) for h in range(-5, 6)})


def pick(spec, y):
    a, b, m = spec
    return b if (m >> (y & 3)) & 1 else a


def row_parts(c, h, s, l, axis, y, P):
    """Row y of the bar as parts: each a 1-D array (fixed) or ('run', colour, width) (made at the redraw)."""
    F = P['fixed']; sp = P['spec'][(c, h)]      # sp[0] swatch, sp[1..11] H, sp[12..22] S, sp[23..33] L
    parts = []
    if y < SW_Y0 or y > SW_Y1: parts.append(F['sw_blank'])
    elif y in (SW_Y0, SW_Y1): parts.append(F['sw_edge'])
    elif y in (SW_Y0 + 1, SW_Y1 - 1): parts.append(F['sw_line'])
    else: parts += [F['sw_head'], ('run', pick(sp[0], y), SW_FILL), F['sw_tail']]
    for f, v in enumerate((h, s, l)):
        parts.append(P['text'][f][int(FIELD_OF_AXIS.get(axis) == f)][v + 5][y])
        if y in (SL_Y0, SL_Y1): parts.append(F['sl_edge'])
        elif SL_Y0 < y < SL_Y1:
            parts += [F['sl_head']] + [('run', pick(sp[1 + 11 * f + k], y), STEPW) for k in range(NSTEP)] + [F['sl_tail']]
        elif MK_Y0 <= y <= MK_Y1: parts.append(P['mark'][v + 5][y])
        else: parts.append(F['sl_blank'])
    return parts


def row_tokens(row):
    toks = []; i = 0
    while i < len(row):
        v = int(row[i]); r = 1
        while r < 16 and i + r < len(row) and row[i + r] == v: r += 1
        toks.append(v << 4 | (r - 1)); i += r
    return toks


def run_tokens(colour, width):
    return [colour << 4 | (min(16, width - k) - 1) for k in range(0, width, 16)]


def pack(toks):
    out = bytearray(GHDR)
    for k in range(0, len(toks), 5):
        word = 0
        for s_, t in enumerate(toks[k:k + 5]): word |= t << (12 * s_)
        out += word.to_bytes(8, 'little')
    return bytes(out)


def clamp(v):
    return max(-5, min(5, v))


def stream(c, h, s, l, axis, P=None):
    """The firmware's picture for slice c (0..11) with values h, s, l on page axis."""
    P = P or pieces()
    h, s, l = clamp(h), clamp(s), clamp(l)
    toks = []
    for y in range(H):
        for p in row_parts(c, h, s, l, axis, y, P):
            toks += run_tokens(p[1], p[2]) if isinstance(p, tuple) else row_tokens(p)
    return pack(toks)


def render(c, h, s, l, axis, P=None):
    P = P or pieces()
    rows = []
    for y in range(H):
        r = []
        for p in row_parts(c, h, s, l, axis, y, P):
            r += [p[1]] * p[2] if isinstance(p, tuple) else list(p)
        assert len(r) == W
        rows.append(r)
    return np.array(rows, dtype=np.uint8)


def inc(P=None):
    """hbar.inc for hbar.s (.ext15). hb_rows: each distinct fixed row part, u32 = its first token's index << 8 | its
    count; hb_tok: their tokens (u16). hb_tx: 66 text parts (f * 22 + framed * 11 + v + 5) x 50 rows, hb_mk: 11 mark
    parts x 50 rows (u16 row indices); HB_R_*: the fixed parts' indices. hb_seg: per slice c and Hue value h
    (c * 11 + h + 5), 34 entries {A, B, mask, 0}: the swatch, then H, S, L's 11 steps each. HB_WORST: the longest
    stream (a bound: every field at its longest)."""
    P = P or pieces()
    rows = {}; toks = []
    def rid(a):
        t = tuple(row_tokens(a))
        if t not in rows: rows[t] = len(rows); toks.append(t)
        return rows[t]
    tx = [rid(P['text'][f][a][v][y]) for f in range(3) for a in (0, 1) for v in range(11) for y in range(H)]
    mk = [rid(P['mark'][v][y]) for v in range(11) for y in range(H)]
    fx = {k: rid(a) for k, a in P['fixed'].items()}
    seg = bytearray()
    for c in range(12):
        for h in range(-5, 6):
            for a, b, m in P['spec'][(c, h)]: seg += bytes((a, b, m, 0))
    at = 0; rec = []
    for t in toks:
        rec.append(at << 8 | len(t)); at += len(t)
    assert max(len(t) for t in toks) < 256 and at < 1 << 24
    # a bound on the stream: the swatch's and the sliders' rows at their most tokens, each text / mark row at its most
    tmax = lambda f, y: max(len(row_tokens(P['text'][f][a][v][y])) for a in (0, 1) for v in range(11))
    mmax = lambda y: max(len(row_tokens(P['mark'][v][y])) for v in range(11))
    n = 0
    for y in range(H):
        F = P['fixed']
        n += (len(row_tokens(F['sw_head'])) + 3 + len(row_tokens(F['sw_tail']))) if SW_Y0 + 1 < y < SW_Y1 - 1 else 3
        for f in range(3):
            n += tmax(f, y)
            n += (2 + NSTEP + 4) if SL_Y0 < y < SL_Y1 else mmax(y) if MK_Y0 <= y <= MK_Y1 else 5
    worst = len(pack([0] * n))
    hw = lambda xs: ''.join(' .short ' + ','.join(str(x) for x in xs[i:i + 16]) + '\n' for i in range(0, len(xs), 16))
    db = lambda b: ''.join(' .byte ' + ','.join(str(x) for x in b[i:i + 32]) + '\n' for i in range(0, len(b), 32))
    return (f'.set HB_WORST, {worst}\n.set HB_HDR, {int.from_bytes(GHDR, "little"):#x}\n' + ''.join(f'.set HB_R_{k.upper()}, {i}\n' for k, i in fx.items()) +
            f'.set HB_SWF, {SW_FILL}\n.set HB_STEPW, {STEPW}\n.set HB_NSTEP, {NSTEP}\n'
            f'.set HB_SWY0, {SW_Y0}\n.set HB_SWY1, {SW_Y1}\n.set HB_SLY0, {SL_Y0}\n.set HB_SLY1, {SL_Y1}\n'
            f'.set HB_MKY0, {MK_Y0}\n.set HB_MKY1, {MK_Y1}\n'
            '.balign 4\nhb_rows:\n' + ''.join(f' .long {r}\n' for r in rec) + 'hb_seg:\n' + db(bytes(seg)) +
            '.balign 2\nhb_tx:\n' + hw(tx) + 'hb_mk:\n' + hw(mk) + 'hb_tok:\n' + hw([x for t in toks for x in t]) +
            '.balign 4\n')


def preview(bars, path, scale=3):
    sheet = Image.new('RGB', (W * scale, (H + 6) * scale * len(bars)), (40, 40, 40))
    for k, b in enumerate(bars):
        rgb = Image.new('RGB', (W, H)); rgb.putdata([SHOW.get(int(v), (255, 0, 255)) for v in b.flatten()])
        sheet.paste(rgb.resize((W * scale, H * scale), Image.NEAREST), (0, k * (H + 6) * scale))
    sheet.save(path)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--preview')
    a = ap.parse_args()
    P = pieces()
    open(a.out, 'w').write(inc(P))
    if a.preview:
        preview([render(0, 2, 3, 0, 2, P), render(3, 0, -5, 0, 0, P), render(6, -3, 0, 4, 1, P),
                 render(10, 5, 5, -5, 0, P), render(8, 0, 0, 0, 2, P)], a.preview)
