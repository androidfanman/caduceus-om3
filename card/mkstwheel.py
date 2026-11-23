#!/usr/bin/env python3
"""The Split toning bar, test w7 (feature/split-tone-row): the colour wheel's H / S / L bar (mkhbar.py, p3,
camera-tested) made for the Split toning row: Shadows, Balance, Highlights.

Owner (2026-11-23), after w4..w6 (moving the camera's widgets at run time did not work on the camera): "lets build
something that looks very identical to the new HSL wheel ... but instead of HSL as the bottom bars, we would have
Shadow, balance and highlight."

The same 400 x 64 place under the camera's wheel, the same parts as the H / S / L bar (mkhbar's swatch column, slider
frames, carets, letter style): left to right a swatch of the page's tint colour, then S (Shadows: strength 0..10, grey
to the shadow tint's colour), B (Balance: Tone Balance -5..+5, dark shadow tint to light highlight tint), H (Highlights:
strength 0..10, grey to the highlight tint's colour); the page's field white-boxed, carets above and below at the value.
A tint with strength 0 has no colour: grey.

Colours: palette 62's entries 108..120 (the bar's slots), written by stwheel.s from st_ctab (per colour, 12 = grey)
each time it draws a new bar: 108 S colour, 109..111 S 25 / 50 / 75 % over grey, 112 H colour, 113..115 H over grey,
116 / 117 the dark and middle shadow tint, 118 the swatch (the page's tint colour; grey on Balance), 119 / 120 the
light highlight tints.

usage: mkstwheel.py OUT.inc [--preview PNG]"""
import argparse
import numpy as np
from PIL import Image, ImageDraw
from mkguides import raster, edge
from mkhbar import (hsv, HUE, BG, W, H, TW, GW, GREY, SLOT0, NSLOT, SHOW, CAP, MID2,
                    row_tokens, pack, mark_part, swatch_rows, sw_fill, sl_fill, _fit, SWF0, SWF1, SLF0, SLF1)

LETTERS = 'SBH'                           # the fields left to right: Shadows, Balance, Highlights
FIELD_OF_MODE = {0: 0, 2: 1, 1: 2}        # the page (0 Shadows, 1 Highlights, 2 Balance) -> its field
SC, S_SL, HC, H_SL = 108, (109, 110, 111), 112, (113, 114, 115)
B_SL, SWC = (116, 117, GREY, 119, 120), 118
GS_ = [(GREY, *S_SL, SC)[x * 5 // GW] for x in range(GW)]
GB_ = [B_SL[x * 5 // GW] for x in range(GW)]
GH_ = [(GREY, *H_SL, HC)[x * 5 // GW] for x in range(GW)]
GRAD = (GS_, GB_, GH_)
NONE = 12                                 # "no tint" (strength 0): grey


def tint(c):
    return (128, 128, 128) if c == NONE else hsv(HUE[c])


def role(c):
    """colour c (0..11, NONE) -> its 8 colours (r, g, b): full, 25 / 50 / 75 % over grey, dark, middle (the shadow
    side of Balance), light, lighter (the highlight side)."""
    t = tint(c)
    out = [t] + [tuple(round(128 * (1 - k) + x * k) for x in t) for k in (0.25, 0.5, 0.75)]
    out += [tuple(round(x * 0.42) for x in t), tuple(round(x * 0.72) for x in t)]
    out += [tuple(round(x + (255 - x) * k) for x in t) for k in (0.3, 0.62)]
    return out


def colours(sc, ss, hc, hs, mode):
    """the 13 colours of entries 108..120."""
    s = role(sc if ss else NONE); h = role(hc if hs else NONE)
    sw = s[0] if mode == 0 else h[0] if mode == 1 else (128, 128, 128)
    out = [s[0], *s[1:4], h[0], *h[1:4], s[4], s[5], sw, h[6], h[7]]
    assert len(out) == NSLOT
    return out


def argb(sc, ss, hc, hs, mode):
    return [0xff000000 | r << 16 | g << 8 | b for r, g, b in colours(sc, ss, hc, hs, mode)]


def word_of(f, v):
    """field f, value index v (0..10) -> its text: S / H the strength 0..10 ("S+6", "S±0", as the camera's own Tint
    readout; w8, owner: "the is no + next to the numbers"), B the Balance -5..+5."""
    n = v - 5 if f == 1 else v
    return LETTERS[f] + ('+' if n > 0 else '−' if n < 0 else '±') + str(abs(n))


def text_part(f, v, active, fs):
    """TW x H: as mkhbar.text_part, with this bar's words."""
    word = word_of(f, v)
    a = raster(word, fs, 0.8)
    base = np.nonzero((raster('H', fs, 0.8) > 128).any(axis=1))[0].max()
    top = base - CAP + 1
    a = a[top - 2:base + 3]
    cols = np.nonzero((a > 40).any(axis=0))[0]; a = a[:, cols.min():cols.max() + 1]
    hh, ww = a.shape
    if ww > TW - 6:                                 # "S+10" / "H+10": a little narrower
        a = np.array(Image.fromarray(a.astype(np.uint8)).resize((TW - 6, hh), Image.LANCZOS)).astype(int)
        hh, ww = a.shape
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


def pieces():
    fs = _fit(CAP)
    return dict(text=[[[text_part(f, v, a, fs) for v in range(11)] for a in (0, 1)] for f in range(3)],
                mark=[mark_part(v) for v in range(-5, 6)], swatch=swatch_rows())


def values(ss, b, hs):
    return (max(0, min(10, ss)), max(-5, min(5, b)) + 5, max(0, min(10, hs)))


def row_parts(ss, hs, b, mode, y, P):
    parts = [sw_fill(SWC) if SWF0 <= y <= SWF1 else P['swatch'][y]]
    boxed = FIELD_OF_MODE[mode]
    for f, v in enumerate(values(ss, b, hs)):
        parts.append(P['text'][f][int(boxed == f)][v][y])
        parts.append(sl_fill(GRAD[f]) if SLF0 <= y <= SLF1 else P['mark'][v][y])
    return parts


def render(sc, ss, hc, hs, b, mode, P=None):
    """the bar for Shadows colour sc / strength ss, Highlights hc / hs (0..11 / 0..10), Tone Balance b (-5..5), the
    page mode (0 Shadows, 1 Highlights, 2 Balance). (The colours are in the palette entries, not the picture.)"""
    P = P or pieces()
    rows = [np.concatenate(row_parts(ss, hs, b, mode, y, P)) for y in range(H)]
    assert all(len(r) == W for r in rows)
    return np.array(rows, dtype=np.uint8)


def stream(sc, ss, hc, hs, b, mode, P=None):
    P = P or pieces()
    toks = []
    for y in range(H):
        for p in row_parts(ss, hs, b, mode, y, P): toks += row_tokens(p)
    return pack(toks)


def inc(P=None):
    """stwheel.inc for stwheel.s (.ext15), as mkhbar.inc: st_rows / st_tok (each distinct row part), st_swr (the swatch
    column's rows), st_tx (66 text parts: f * 22 + boxed * 11 + v, x H rows), st_mk (11 slider parts, x H rows),
    st_gid (the swatch's colour row, the three gradient rows); st_ctab: per colour 0..12 its 8 role colours (ARGB)."""
    P = P or pieces()
    rows = {}; toks = []
    def rid(a):
        t = tuple(row_tokens(a))
        if t not in rows: rows[t] = len(rows); toks.append(t)
        return rows[t]
    swr = [rid(P['swatch'][y]) for y in range(H)]
    tx = [rid(P['text'][f][a][v][y]) for f in range(3) for a in (0, 1) for v in range(11) for y in range(H)]
    mk = [rid(P['mark'][v][y]) for v in range(11) for y in range(H)]
    gid = [rid(sw_fill(SWC))] + [rid(sl_fill(g)) for g in GRAD]
    at = 0; rec = []
    for t in toks:
        rec.append(at << 8 | len(t)); at += len(t)
    assert max(len(t) for t in toks) < 256 and at < 1 << 24 and len(rows) < 65536
    L = lambda a: len(row_tokens(a))
    gmax = [len(toks[g]) for g in gid]
    n = 0
    for y in range(H):
        n += gmax[0] if SWF0 <= y <= SWF1 else L(P['swatch'][y])
        for f in range(3):
            n += max(L(P['text'][f][a][v][y]) for a in (0, 1) for v in range(11))
            n += gmax[1 + f] if SLF0 <= y <= SLF1 else max(L(P['mark'][v][y]) for v in range(11))
    worst = len(pack([0] * n))
    argb_ = lambda c: [0xff000000 | r << 16 | g << 8 | b for r, g, b in role(c)]
    hw = lambda xs: ''.join(' .short ' + ','.join(str(x) for x in xs[i:i + 16]) + '\n' for i in range(0, len(xs), 16))
    return (f'.set ST_WORST, {worst}\n.set ST_NONE, {NONE}\n'
            '.balign 4\nst_rows:\n' + ''.join(f' .long {r}\n' for r in rec) +
            '.balign 2\nst_gid:\n' + hw(gid) + 'st_swr:\n' + hw(swr) + 'st_tx:\n' + hw(tx) + 'st_mk:\n' + hw(mk) +
            'st_tok:\n' + hw([x for t in toks for x in t]) + '.balign 4\nst_ctab:\n' +
            ''.join(' .long ' + ','.join(f'{x:#010x}' for x in argb_(c)) + '\n' for c in range(13)))


def preview(bars, path, scale=3, ground=(96, 110, 120)):
    """bars: [(sc, ss, hc, hs, b, mode)]."""
    P = pieces()
    sheet = Image.new('RGB', (W * scale, (H + 6) * scale * len(bars)), (40, 40, 40))
    for k, st in enumerate(bars):
        b = render(*st, P=P)
        show = {**SHOW, BG: ground, 0: ground, 9: tuple(round(x * 0.47) for x in ground),
                **{SLOT0 + i: col for i, col in enumerate(colours(*st[:4], st[5]))}}
        rgb = Image.new('RGB', (W, H)); rgb.putdata([show.get(int(v), (255, 0, 255)) for v in b.flatten()])
        sheet.paste(rgb.resize((W * scale, H * scale), Image.NEAREST), (0, k * (H + 6) * scale))
    sheet.save(path)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--preview')
    a = ap.parse_args()
    P = pieces()
    s = inc(P)
    assert int(s.split('.set ST_WORST, ')[1].split()[0]) < 8192
    open(a.out, 'w').write(s)
    if a.preview:
        preview([(6, 6, 1, 4, -2, 0), (6, 6, 1, 4, -2, 2), (6, 6, 1, 4, -2, 1), (0, 0, 0, 10, 5, 1)], a.preview)
