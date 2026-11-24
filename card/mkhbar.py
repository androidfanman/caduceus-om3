#!/usr/bin/env python3
"""The colour wheel's H / S / L bar, round 3 (experiment/wheel-hsl-view): what the firmware puts together under the
wheel, and the same picture made here (the emulator test compares the firmware's with it byte for byte).

The bar: 400 x 64 in the guide picture's place (its two widgets widened and raised by build.py's DATA), OSD type 11,
the guide plane's palette (GUI layer 1, palette 62 at 0x614a67f0). h2 mixed two of the palette's ~25 strong colours in
alternating rows, which the camera showed as rough stripes (owner, 2026-11-22). h3 draws every band in one solid colour
of its own: palette 62's entries 108..120 are unused (0x01010101, not drawn; om-emu: made magenta they changed none of
21 stock screens; entries 128..255 never reach the screen, the plane takes 128). The bar's picture uses those 13
entries (SLOT) for its colours, and hbar.s writes the colour's 13 (PAL: per slice and Hue value) into them, in the
palette table and through the camera's own palette call (GPISetPalette), each time it draws a new bar:
- 108 the colour (its hue turned by its Hue value), the swatch, S's end and L's middle;
- 109..111 S: the colour 25 / 50 / 75 % over grey; 112..115 L: 1/3 and 2/3 of the colour, 1/3 and 2/3 of the way to
  white; 116..120 H: the slice's hue -22, -11, 0, +11, +22 degrees.

Left to right, every part centred on the bar's middle row line (owner: "they arent inline vertically with the color
square"): the swatch, then H, S and L, each its value ("H+2", the page's white-boxed) and a 64 x 34 gradient with a
caret above and below at the value: H 5 bands (the neighbouring hues), S 5 (grey to the colour), L 7 (black, the
colour, white).

Each row of the bar is 7 parts, each a fixed row of tokens (hb_rows / hb_tok): the swatch column (hb_swr; its colour
rows hb_gid[0]), then per field its text part (hb_tx) and its slider part (gradient rows hb_gid[1 + f], other rows the
caret table hb_mk). hbar.s does exactly what stream() does.

usage: mkhbar.py OUT.inc [--preview PNG]"""
import argparse, colorsys
import numpy as np
from PIL import Image, ImageDraw
from mkguides import raster, edge

W, H = 400, 64
BG = 72                               # the bar's ground: palette 0x11282828, almost clear (the camera shows the live
                                      # view through it, h2 photo)
SWW, TW, SLW = 40, 50, 70             # swatch, text, slider widths; 40 + 3 * (50 + 70) = 400
SW_Y0, SW_Y1 = 13, 50                 # the swatch box's rows: outline 13 / 50, white 14 / 49, colour 15..48 (34 x 34)
SL_Y0, SL_Y1 = 14, 49                 # the slider's outline rows; its gradient rows 15..48 (as the swatch's colour)
GX0, GW = 2, 64                       # the gradient's first column in the slider part and its width
CAP = 20                              # the value's cap height (rows 22..41)
MID2 = H - 1                          # twice the middle row line (31.5): every part is symmetric about it
HUE = [60, 35, 15, 355, 320, 280, 235, 205, 180, 155, 120, 85]   # docs/PHOTO_TO_LOOK.md, slices 0..11
DEG = 5.5                             # degrees of hue a step; + turns toward the next slice (lower HSV hue)
FIELD_OF_AXIS = {2: 0, 0: 1, 1: 2}    # the editor's page (P+AXIS: 2 Hue, 0 Saturation, 1 Luminance) -> its field
PAD = 50                              # rows over the bar (w2 / w3 had 136 clear ones, w4..v0.41-alpha none, v0.41-a2 24):
PH = H + PAD                          # the INFO hint (hint_rows), the camera's guide height (v0.41-a3); the Split toning
                                      # bar leaves them clear (entry 0), so both bars stay where they were
HINT = 'H/S/L'                        # the hint: INFO steps the page H -> S -> L (sp_inf, hb_next)
KEYW = 66                             # the guide's INFO key part (rgbpics.info_key: the key and its rim)
GHDR = bytes([(PH - 1) & 255, ((PH - 1) >> 8 & 3) | (((W - 1) & 15) << 4), ((W - 1) >> 4) & 63, 11])
GREY, BLACK, WHITE = 64, 7, 10        # palette 62: 0xff808080, 0xff000000, 0xfffefefe
SLOT0, NSLOT = 108, 13                # palette 62's unused entries 108..120 (stock 0x01010101)
FREE_STOCK = 0x01010101
SW, S_SL, L_SL, H_SL = 108, (109, 110, 111), (112, 113, 114, 115), (116, 117, 118, 119, 120)
H_OFF = (-4, -2, 0, 2, 4)             # the H bands' values (x DEG)
PAL_TABLE = 0x614a67f0                # palette 62 (record 0x614a6bf0)


def hsv(h, s=1.0, v=1.0):
    return tuple(round(255 * x) for x in colorsys.hsv_to_rgb((h % 360) / 360, s, v))


def colours(c, h):
    """slice c, its Hue value h -> the 13 colours (r, g, b) of entries 108..120."""
    t = hsv(HUE[c] - DEG * h)
    out = [t]
    out += [tuple(round(128 * (1 - k) + x * k) for x in t) for k in (0.25, 0.5, 0.75)]
    out += [tuple(round(x * k / 3) for x in t) for k in (1, 2)]
    out += [tuple(round(x + (255 - x) * k / 3) for x in t) for k in (1, 2)]
    out += [hsv(HUE[c] - DEG * v) for v in H_OFF]
    assert len(out) == NSLOT
    return out


def argb(c, h):
    return [0xff000000 | r << 16 | g << 8 | b for r, g, b in colours(c, h)]


SHOW = {7: (0, 0, 0), 10: (254, 254, 254), 11: (170, 170, 170), 12: (85, 85, 85), 64: (128, 128, 128)}


def vx(v):
    """value v (-5..5) -> its gradient column (0..GW-1)"""
    return round((v + 5) * (GW - 1) / 10)


GH = [H_SL[x * 5 // GW] for x in range(GW)]
GS = [(GREY, *S_SL, SW)[x * 5 // GW] for x in range(GW)]
GL = [(BLACK, L_SL[0], L_SL[1], SW, L_SL[2], L_SL[3], WHITE)[x * 7 // GW] for x in range(GW)]


def _fit(cap):
    for fs in range(8, 60):
        r = np.nonzero((raster('H', fs, 1.0) > 128).any(axis=1))[0]
        if r.max() - r.min() + 1 >= cap: return fs
    raise SystemExit('no font size fits')


def text_part(f, v, active, fs):
    """TW x H: 'H+2' with its cap rows on 22..41; on the page's field dark letters in a white rounded box (rows
    14..49)."""
    word = 'HSL'[f] + ('+' if v > 0 else '−' if v < 0 else '±') + str(abs(v))
    a = raster(word, fs, 0.8)
    base = np.nonzero((raster('H', fs, 0.8) > 128).any(axis=1))[0].max()
    top = base - CAP + 1
    a = a[top - 2:base + 3]                       # cap rows plus 2 above, 2 below (the minus / plus-minus fit)
    cols = np.nonzero((a > 40).any(axis=0))[0]; a = a[:, cols.min():cols.max() + 1]
    hh, ww = a.shape
    assert ww <= TW - 6, (word, ww)
    y0 = (MID2 + 1 - CAP) // 2 - 2; x0 = (TW - ww) // 2
    out = np.full((H, TW), BG, dtype=np.uint8)
    if active:
        S = 4
        im = Image.new('L', (TW * S, H * S), 0)
        ImageDraw.Draw(im).rounded_rectangle((1 * S, 14 * S, (TW - 1) * S - 1, (MID2 - 13) * S - 1), radius=5 * S, fill=255)
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


def slider_frame():
    """SLW x H: the slider column without its gradient: the outline rows and sides."""
    out = np.full((H, SLW), BG, dtype=np.uint8)
    out[SL_Y0, GX0 - 1:GX0 + GW + 1] = 7; out[SL_Y1, GX0 - 1:GX0 + GW + 1] = 7
    out[SL_Y0:SL_Y1 + 1, GX0 - 1] = 7; out[SL_Y0:SL_Y1 + 1, GX0 + GW] = 7
    return out


def mark_part(v):
    """SLW x H: the slider column's rows other than the gradient's, with a white caret above (pointing down) and below
    (pointing up) at value v's column, mirror images about the middle row line."""
    out = slider_frame()
    cx = GX0 + vx(v) + 0.5
    S = 4
    im = Image.new('L', (SLW * S, H * S), 0)
    ImageDraw.Draw(im).polygon([((cx - 5) * S, 5 * S), ((cx + 5) * S, 5 * S), (cx * S, 11.5 * S)], fill=255)
    tri = np.array(im.resize((SLW, H), Image.LANCZOS)) > 100
    tri[H // 2:] = tri[:H // 2][::-1]             # the lower caret: the upper one mirrored
    e = edge(tri)
    put = (e != 0) & ((out == BG) | tri)
    out[put] = e[put]
    out[SL_Y0 + 1:SL_Y1, GX0:GX0 + GW] = BG       # the gradient's rows come from hb_gid
    assert (out == out[::-1]).all()
    return out


def swatch_rows():
    """SWW x H: the swatch column without its colour (the box's outline and white line)."""
    out = np.full((H, SWW), BG, dtype=np.uint8)
    out[SW_Y0:SW_Y1 + 1, 1:SWW - 1] = 7
    out[SW_Y0 + 1:SW_Y1, 2:SWW - 2] = 10
    out[SW_Y0 + 2:SW_Y1 - 1, 3:SWW - 3] = BG     # the colour's rows come from hb_gid
    assert (out == out[::-1]).all()
    return out


def sw_fill(colour):
    return np.array([BG, 7, 10] + [colour] * (SWW - 6) + [10, 7, BG], dtype=np.uint8)


def sl_fill(cols):
    out = slider_frame()[(SL_Y0 + SL_Y1) // 2].copy()
    out[GX0:GX0 + GW] = cols
    return out


SWF0, SWF1 = SW_Y0 + 2, SW_Y1 - 2     # the swatch's colour rows
SLF0, SLF1 = SL_Y0 + 1, SL_Y1 - 1     # the gradients' rows


def pieces():
    fs = _fit(CAP)
    return dict(text=[[[text_part(f, v, a, fs) for v in range(-5, 6)] for a in (0, 1)] for f in range(3)],
                mark=[mark_part(v) for v in range(-5, 6)], swatch=swatch_rows())


def row_parts(c, h, s, l, axis, y, P):
    """Row y of the bar: its 7 parts (1-D arrays). (The colour, slice c, is in the palette entries, not the picture.)"""
    parts = [sw_fill(SW) if SWF0 <= y <= SWF1 else P['swatch'][y]]
    for f, (v, g) in enumerate(((h, GH), (s, GS), (l, GL))):
        parts.append(P['text'][f][int(FIELD_OF_AXIS.get(axis) == f)][v + 5][y])
        parts.append(sl_fill(g) if SLF0 <= y <= SLF1 else P['mark'][v + 5][y])
    return parts


def row_tokens(row):
    toks = []; i = 0
    while i < len(row):
        v = int(row[i]); r = 1
        while r < 16 and i + r < len(row) and row[i + r] == v: r += 1
        toks.append(v << 4 | (r - 1)); i += r
    return toks


def pack(toks):
    out = bytearray(GHDR)
    for k in range(0, len(toks), 5):
        word = 0
        for s_, t in enumerate(toks[k:k + 5]): word |= t << (12 * s_)
        out += word.to_bytes(8, 'little')
    return bytes(out)


def clamp(v):
    return max(-5, min(5, v))


def guide_word(word):
    """PAD x (2 + w + 3): word as rgbpics.guide5 draws it (the H&S row's guides, drawn to the camera's "Mid [INFO]";
    stems a pixel heavier, the camera's outline), at H/S/L's letter size whatever its length (guide5 squeezes past 100
    px), 2 px before it and the 3 px gap to the key after it."""
    import os, sys
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'firmware'))
    import mkguides
    _, fs, sq = mkguides.fit('H/S/L')
    a = mkguides.raster(word, fs, sq)
    base = np.nonzero((mkguides.raster(word[0], fs, sq) > 128).any(axis=1))[0].max()
    a = np.maximum(a, np.pad(a, ((0, 0), (1, 0)))[:, :-1])
    fill = a > 128; soft = (a > 40) & ~fill
    h, w = fill.shape
    lay = np.zeros((PAD, 2 + w + 3 + KEYW), dtype=np.uint8)
    for y in range(h):
        if 0 <= y + 40 - base < PAD:
            lay[y + 40 - base, 2:2 + w][fill[y]] = 10
            lay[y + 40 - base, 2:2 + w][soft[y]] = 11
    return edge(lay == 10, lay == 11)[:, :2 + w + 3]


def hint_key():
    """PAD x KEYW: the guide's INFO key (rgbpics.info_key), the same in every hint."""
    import os, sys
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'firmware'))
    import rgbpics
    k = rgbpics.info_key()
    assert k.shape == (PAD, KEYW)
    return k


def hint_layout(word):
    """the hint over a bar as hbar.s's hint_rows puts it together, row by row: a clear part (entry 0) of `left` px,
    the word part, the key part, a clear part of `right` px; the word and key centred over the three fields (x 40..399).
    -> (left, word part, key part, right)"""
    wp, k = guide_word(word), hint_key()
    left = 40 + (W - 40 - wp.shape[1] - KEYW) // 2
    right = W - left - wp.shape[1] - KEYW
    assert left > 0 and right > 0
    return left, wp, k, right


def hint_rows(word=None):
    """PAD x W: the hint as a picture (v0.41-a3, owner on the camera: "the H/S/L text we added to that section is too
    small. make it look like everything else"; H/S/L's is rgbpics.guide5's own picture, camera-tested in a3)."""
    left, wp, k, right = hint_layout(word or HINT)
    return np.hstack([np.zeros((PAD, left), dtype=np.uint8), wp, k, np.zeros((PAD, right), dtype=np.uint8)])


def hint_tokens(word=None):
    """the hint's tokens as hint_rows (hbar.s) puts them out: each row's four parts in turn."""
    left, wp, k, right = hint_layout(word or HINT)
    cl, cr = row_tokens(np.zeros(left, dtype=np.uint8)), row_tokens(np.zeros(right, dtype=np.uint8))
    return [t for y in range(PAD) for t in cl + row_tokens(wp[y]) + row_tokens(k[y]) + cr]


def stream(c, h, s, l, axis, P=None):
    """The firmware's picture for slice c (0..11) with values h, s, l on page axis."""
    P = P or pieces()
    h, s, l = clamp(h), clamp(s), clamp(l)
    toks = hint_tokens()
    for y in range(H):
        for p in row_parts(c, h, s, l, axis, y, P): toks += row_tokens(p)
    return pack(toks)


def render(c, h, s, l, axis, P=None):
    P = P or pieces()
    rows = [np.concatenate(row_parts(c, h, s, l, axis, y, P)) for y in range(H)]
    assert all(len(r) == W for r in rows)
    return np.array(rows, dtype=np.uint8)


def inc(P=None):
    """hbar.inc for hbar.s (.ext15). hb_rows: each distinct row part, u32 = its first token's index << 8 | its count;
    hb_tok: their tokens (u16). hb_swr: the swatch column's rows (u16 row indices; its colour rows unused), hb_tx: 66
    text parts (f * 22 + framed * 11 + v + 5) x H rows, hb_mk: 11 slider parts (v + 5) x H rows (the gradient's rows
    unused), hb_gid: the rows of the swatch's colour and of the H, S, L gradients (4 u16). hb_pal: per slice c and Hue
    value h (c * 11 + h + 5) the 13 colours (ARGB) of entries 108..120. HB_WORST: the longest stream (each part at its
    longest)."""
    P = P or pieces()
    rows = {}; toks = []
    def rid(a):
        t = tuple(row_tokens(a))
        if t not in rows: rows[t] = len(rows); toks.append(t)
        return rows[t]
    swr = [rid(P['swatch'][y]) for y in range(H)]
    tx = [rid(P['text'][f][a][v][y]) for f in range(3) for a in (0, 1) for v in range(11) for y in range(H)]
    mk = [rid(P['mark'][v][y]) for v in range(11) for y in range(H)]
    gid = [rid(sw_fill(SW)), rid(sl_fill(GH)), rid(sl_fill(GS)), rid(sl_fill(GL))]
    at = 0; rec = []
    for t in toks:
        rec.append(at << 8 | len(t)); at += len(t)
    assert max(len(t) for t in toks) < 256 and at < 1 << 24 and len(rows) < 65536
    n = 0
    L = lambda a: len(row_tokens(a))
    gmax = [len(toks[g]) for g in gid]
    for y in range(H):
        n += gmax[0] if SWF0 <= y <= SWF1 else L(P['swatch'][y])
        for f in range(3):
            n += max(L(P['text'][f][a][v][y]) for a in (0, 1) for v in range(11))
            n += gmax[1 + f] if SLF0 <= y <= SLF1 else max(L(P['mark'][v][y]) for v in range(11))
    worst = len(pack([0] * (n + len(hint_tokens()))))
    hw = lambda xs: ''.join(' .short ' + ','.join(str(x) for x in xs[i:i + 16]) + '\n' for i in range(0, len(xs), 16))
    return (f'.set HB_WORST, {worst}\n.set HB_HDR, {int.from_bytes(GHDR, "little"):#x}\n.set HB_H, {H}\n.set HB_PH, {PH}\n.set HB_PAD, {PAD}\n'
            f'.set HB_SLOT0, {SLOT0}\n.set HB_NSLOT, {NSLOT}\n.set HB_PALT, {PAL_TABLE + 4 * SLOT0:#x}\n'
            f'.set HB_SWF0, {SWF0}\n.set HB_SWF1, {SWF1}\n.set HB_SLF0, {SLF0}\n.set HB_SLF1, {SLF1}\n'
            '.balign 4\nhb_rows:\n' + ''.join(f' .long {r}\n' for r in rec) +
            '.balign 2\nhb_gid:\n' + hw(gid) + 'hb_swr:\n' + hw(swr) + 'hb_tx:\n' + hw(tx) + 'hb_mk:\n' + hw(mk) +
            'hb_tok:\n' + hw([x for t in toks for x in t]) + 'hb_pal:\n' +   # picture-mode p1: 3 bytes a colour (B, G, R; hb_spal adds the 0xff), 1716 B less in .ext15
            ''.join(' .byte ' + ','.join(f'{x & 255},{x >> 8 & 255},{x >> 16 & 255}' for x in argb(c, h)) + '\n' for c in range(12) for h in range(-5, 6)) + '.balign 4\n')


def preview(bars, path, scale=3, ground=(96, 110, 120)):
    """bars: [(c, h, picture)]: as the screen would show them over a plain ground (BG and the soft rim 9 drawn as / over
    it), entries 108..120 the colour c, h's."""
    sheet = Image.new('RGB', (W * scale, (H + 6) * scale * len(bars)), (40, 40, 40))
    for k, (c, h, b) in enumerate(bars):
        show = {**SHOW, BG: ground, 0: ground, 9: tuple(round(x * 0.47) for x in ground),
                **{SLOT0 + i: col for i, col in enumerate(colours(c, h))}}
        rgb = Image.new('RGB', (W, H)); rgb.putdata([show.get(int(v), (255, 0, 255)) for v in b.flatten()])
        sheet.paste(rgb.resize((W * scale, H * scale), Image.NEAREST), (0, k * (H + 6) * scale))
    sheet.save(path)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--preview')
    a = ap.parse_args()
    P = pieces()
    open(a.out, 'w').write(inc(P))
    if a.preview:
        preview([(c, h, render(c, h, s, l, ax, P)) for c, h, s, l, ax in
                 ((0, 2, 3, 0, 2), (3, 0, -5, -5, 0), (6, -3, 0, 4, 1), (10, 5, 5, -5, 0), (8, 0, 0, 0, 2))], a.preview)
