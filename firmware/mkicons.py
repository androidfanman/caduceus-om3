#!/usr/bin/env python3
"""Left-column pictures for our Picture Mode rows (v0.23), drawn from scratch (DejaVu Sans Condensed, a free font) in
the camera's OSD text style (palette 0 clear, 7 dark edge 2 px, 10 white fill, 11 / 12 soft fill); no camera graphics
are copied.
- Slider rows (46 x 46, the stock "S" icon's size): the words "Blk" / "Wht" / "A-B" / "G-M" in the place of the
  Sharpness row's "S", so the camera draws its own value ("-2") next to them.
- Choice rows (100 x 76, the stock "COLOR / 1" cell picture's size): two lines, the setting's short name over its
  value: "Vignette" Off / On, "Noise" Off / Low / Std / High.
Output: OSD type-11 streams, patched into the firmware by build.py (in PICTURES order; ids 0x7f80 + index).
usage: mkicons.py [--preview PNG]"""
import argparse
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed.ttf'
W, H = 46, 46                      # slider-row icon
CW, CH = 100, 76                   # choice-row cell picture
# (lines, width, height): one line = (text, cap height px, baseline row)
PICTURES = [
    ([('Blk', 20, 33)], W, H), ([('Wht', 20, 33)], W, H), ([], 8, 2), ([], 8, 2),  # v0.25: A-B / G-M unused (the WB grid row shows the camera's WB± picture)
    ([('Vignette', 15, 30), ('Off', 18, 60)], CW, CH), ([('Vignette', 15, 30), ('On', 18, 60)], CW, CH),
    ([('Noise', 15, 30), ('Off', 18, 60)], CW, CH), ([('Noise', 15, 30), ('Low', 18, 60)], CW, CH),
    ([('Noise', 15, 30), ('Std', 18, 60)], CW, CH), ([('Noise', 15, 30), ('High', 18, 60)], CW, CH),
    ([('HSL', 26, 44)], 82, 62),   # v0.24 film test 7 (owner): the Color row's cell, stock "Color / Vivid" (82 x 62)
    ([('Glow', 20, 33)], W, H),    # v0.25: the Glow (+) / Clarity (-) slider's icon (owner: named for the + side)
    ([], 8, 2), ([], 8, 2),  # v0.25: Frame Off / On unused (owner: Frame removed)
]
STYLE = {10: (0.88, (0.20, 0.40, 0.60))}   # width, coverage thresholds (as the FILM cells, matched to the stock lettering)


def word(txt, cap, maxw, sx=1.0, font=None):
    """The word's ink coverage 0..1, cap height `cap`, `sx` times its width, squeezed to fit maxw; and its baseline row
    in that array."""
    S = 8
    f = ImageFont.truetype(font or FONT, 100 * S)
    im = Image.new('L', (100 * S * (len(txt) + 1), 200 * S), 0)
    ImageDraw.Draw(im).text((20 * S, 40 * S), txt, font=f, fill=255)
    a = np.array(im)
    hb = Image.new('L', (200 * S, 200 * S), 0); ImageDraw.Draw(hb).text((20 * S, 40 * S), 'H', font=f, fill=255)
    rows = np.nonzero(np.array(hb).any(axis=1))[0]
    cap_top, cap_bot = rows.min(), rows.max()
    cols = np.nonzero(a.any(axis=0))[0]
    ink = np.nonzero(a.any(axis=1))[0]
    a = a[ink.min():ink.max() + 1, cols.min():cols.max() + 1]
    scale = cap / (cap_bot - cap_top + 1)
    w = a.shape[1] * scale * sx
    sq = min(1.0, maxw / w)
    out_w, out_h = max(1, round(w * sq)), max(1, round(a.shape[0] * scale))
    small = np.array(Image.fromarray(a).resize((out_w, out_h), Image.BOX)).astype(float) / 255
    return small, (cap_bot - ink.min()) * scale


def picture(lines, w, h, sx=1.0, th=(0.30, 0.50, 0.70)):
    """w x h palette indices: fill 10, soft 11 / 12 (coverage thresholds th), a 2 px dark edge 7 round the ink."""
    cov = np.zeros((h, w))
    for txt, cap, base in lines:
        small, b = word(txt, cap, w - 6, sx)
        y0, x0 = int(round(base - b)), (w - small.shape[1]) // 2
        sh = cov[y0:y0 + small.shape[0], x0:x0 + small.shape[1]]
        cov[y0:y0 + small.shape[0], x0:x0 + small.shape[1]] = np.maximum(sh, small[:sh.shape[0], :sh.shape[1]])
    return quant(cov, th)


def quant(cov, th=(0.30, 0.50, 0.70)):
    px = np.zeros(cov.shape, dtype=np.uint8)
    px[cov >= th[0]] = 12
    px[cov >= th[1]] = 11
    px[cov >= th[2]] = 10
    ink = px > 0
    px[ndimage.binary_dilation(ink, structure=np.ones((3, 3)), iterations=2) & ~ink] = 7
    return px


# v0.24 film cells (100 x 76, the stock "COLOR / 1" strip cell's size): "FILM" over the film's number, matched to the
# stock cells' measured metrics (owner: "the same style and size as COLOR 1-4"): word fill rows 16..36 and 73 px for
# "COLOR" -> cap 20, baseline 36, 0.88 width, coverage thresholds 0.2 / 0.4 / 0.6 in our font; digits fill rows
# 43..68, 9..16 px wide -> cap 26, baseline 69, 0.95 width (film test 7, owner: a little smaller: cap 24, baseline 68,
# 0.92 width). The camera
# draws them itself when the films load (firmware fl_mk): the "FILM" line (rows 0..FT-1) as it is, then each digit's
# picture (FD rows, FW wide) under it, centred; two digits overlap by 2 px (their dark edges), a digit pixel replacing
# only clear or edge pixels. film_cell() is the same rule, for the preview and the checks.
FCW, FCH, FT = 100, 76, 40
FD = FCH - FT


def film_top(star=False):
    """the "FILM" line; star: with a '*' over its top-right corner as the stock "COLOR*" (star fill ~16 x 18 px,
    rows ~4..21, its left edge ~6 px inside the word's end; our font's asterisk, the same 2 px dark edge)"""
    if not star:
        return picture([('FILM', 20, 36)], FCW, FT, 0.88, (0.20, 0.40, 0.60))
    cov = np.zeros((FT, FCW))
    small, b = word('FILM', 20, FCW - 6, 0.88)
    y0, x0 = int(round(36 - b)), (FCW - small.shape[1]) // 2
    cov[y0:y0 + small.shape[0], x0:x0 + small.shape[1]] = small
    word_px = quant(cov, (0.20, 0.40, 0.60))
    right = np.nonzero(np.isin(word_px, (10, 11, 12)).any(axis=0))[0][-1]
    st, _ = word('*', 34, 99, 1.0)
    cs = np.zeros((FT, FCW))
    sy, sx = 4, right - 2
    h, w = min(st.shape[0], FT - sy), min(st.shape[1], FCW - sx)
    cs[sy:sy + h, sx:sx + w] = st[:h, :w]
    star_px = quant(cs, (0.20, 0.40, 0.60))
    out = word_px.copy()
    m = star_px != 0
    out[m] = star_px[m]
    return out


def film_digits():
    """10 arrays FD x FW: the digits 0..9, cap 24, baseline 68 - FT, centred in a common width."""
    small = [word(str(d), 24, 99, 0.92) for d in range(10)]   # film test 7: owner: a little smaller (was 26, 0.95)
    fw = max(a.shape[1] for a, _ in small) + 4
    out = []
    for a, b in small:
        cov = np.zeros((FD, fw))
        y0, x0 = int(round(68 - FT - b)), (fw - a.shape[1]) // 2
        cov[y0:y0 + a.shape[0], x0:x0 + a.shape[1]] = a
        out.append(quant(cov))
    return out


def film_cell(n, top=None, digs=None, star=False):
    top = film_top(star) if top is None else top
    digs = film_digits() if digs is None else digs
    fw = digs[0].shape[1]
    px = np.zeros((FCH, FCW), dtype=np.uint8)
    px[:FT] = top
    ds = [int(c) for c in str(n)]
    tw = len(ds) * fw - 2 * (len(ds) - 1)
    x = (FCW - tw) // 2
    for d in ds:
        g = digs[d]
        for yy in range(FD):
            for xx in range(fw):
                v, c = g[yy, xx], px[FT + yy, x + xx]
                if v and (c == 0 or c == 7):
                    px[FT + yy, x + xx] = v
        x += fw - 2
    return px


# v0.24 quick menu (Super Control Panel) picture of a COLOR holding a film: "FILM n" on one line, 160 x 48, in that
# panel's own style (measured from its "COLOR 4" picture: no dark edge, fill 13, soft 14 / 15 / 7, ink rows 7..40,
# x 12..148, stems ~5 px, letters ~2 px apart, a wider gap before the number). Matched by drawing each letter on its own
# (cap 32, baseline 40, 0.75 width, a 0.6 px blur, thresholds 0.05 / 0.08 / 0.18 / 0.50 in our font), 2 px apart;
# 6 px between word and number. Parts: the "FILM" word and the digits 0..9 (left-aligned in a common box), composed
# by the camera (fl_sp): centred, a part pixel written only where it is not clear.
SPW, SPH, SP_GAP, SP_DGAP = 160, 48, 6, 2


def _sp_part(txt):
    small, b = word(txt, 32, 999, 0.75)
    cov = np.zeros((SPH, small.shape[1] + 8))
    y0 = int(round(40 - b))
    cov[y0:y0 + small.shape[0], 4:4 + small.shape[1]] = small
    cov = ndimage.gaussian_filter(cov, 0.6)
    px = np.zeros(cov.shape, dtype=np.uint8)
    for t, v in ((0.05, 7), (0.08, 15), (0.18, 14), (0.50, 13)):
        px[cov >= t] = v
    cols = np.nonzero((px != 0).any(axis=0))[0]
    return px[:, cols[0]:cols[-1] + 1]


def _sp_word(txt):
    ps = [_sp_part(c) for c in txt]
    out = np.zeros((SPH, sum(p.shape[1] for p in ps) + SP_DGAP * (len(ps) - 1)), dtype=np.uint8)
    x = 0
    for p in ps:
        m = p != 0
        out[:, x:x + p.shape[1]][m] = p[m]
        x += p.shape[1] + SP_DGAP
    return out


def sp_parts():
    """(word picture, its width even-padded; digit boxes 10 x SPH x WD; digit ink widths)"""
    fw = _sp_word('FILM')
    fwp = np.zeros((SPH, fw.shape[1] + fw.shape[1] % 2), dtype=np.uint8)
    fwp[:, :fw.shape[1]] = fw
    ds = [_sp_part(str(d)) for d in range(10)]
    wd = max(d.shape[1] for d in ds)
    wd += wd % 2
    boxes = []
    for d in ds:
        bx = np.zeros((SPH, wd), dtype=np.uint8)
        bx[:, :d.shape[1]] = d
        boxes.append(bx)
    return fwp, fw.shape[1], boxes, [d.shape[1] for d in ds]


def sp_film(n, parts=None):
    fwp, fwi, boxes, dw = sp_parts() if parts is None else parts
    ds = [int(c) for c in str(n)]
    tw = fwi + SP_GAP + sum(dw[d] for d in ds) + SP_DGAP * (len(ds) - 1)
    x = (SPW - tw) // 2
    px = np.zeros((SPH, SPW), dtype=np.uint8)

    def blit(a, x):
        for yy in range(SPH):
            for xx in range(a.shape[1]):
                if a[yy, xx] and x + xx < SPW:
                    px[yy, x + xx] = a[yy, xx]
    blit(fwp, x)
    x += fwi + SP_GAP
    for d in ds:
        blit(boxes[d], x)
        x += dw[d] + SP_DGAP
    return px


# v0.24 film test 9: the shooting screen's picture-mode name (the camera's "COLOR2", 96 x 44: fill rows 10..33, the
# label style: white fill, dark edge, grey, faint) -> "FILM" and the number in that style (cap 24, baseline 33,
# DejaVu Sans Condensed squeezed 0.8; 3 px between the word and the number, digits 1 px overlapped at their rims).
# The firmware composes it (fl_sp with the fl_LVL layout) from these parts, as sp_film below.
LVW, LVH, LV_BASE, LV_CAP, LV_SQ, LV_GAP, LV_DGAP = 96, 44, 33, 24, 0.80, 3, -1


def _lv_glyph(txt):
    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'card'))
    import mklabels
    fs = next(f for f in range(10, 80) if (lambda r: r[1] - r[0] + 1)(mklabels.cap_rows(f)) >= LV_CAP)
    a = mklabels.raster(txt, fs, LV_SQ)
    base = mklabels.cap_rows(fs)[1]
    lay = np.zeros((LVH, a.shape[1] + 8), dtype=np.uint8)
    fill, soft = a > 128, (a > 60) & (a <= 128)
    for y in range(a.shape[0]):
        yy = y + LV_BASE - base
        if 0 <= yy < LVH:
            row = lay[yy, 4:4 + a.shape[1]]
            row[fill[y]] = 10
            row[soft[y] & (a[y] > 100)] = 11
            row[soft[y] & (a[y] <= 100)] = 12
    fm = lay == 10
    e = ndimage.distance_transform_edt(~fm)
    out = np.zeros_like(lay)
    out[(e > 0) & (e <= 1.0)] = 7
    out[(e > 1.0) & (e <= 2.0)] = 8
    out[(e > 2.0) & (e <= 2.5)] = 9
    sm = (lay == 11) | (lay == 12)
    out[sm] = lay[sm]
    out[fm] = 10
    cols = np.nonzero(out.any(axis=0))[0]
    return out[:, cols[0]:cols[-1] + 1]


def lv_parts():
    """as sp_parts: (word picture even-padded, its ink width, digit boxes, digit ink widths)"""
    fw = _lv_glyph('FILM')
    fwp = np.zeros((LVH, fw.shape[1] + fw.shape[1] % 2), dtype=np.uint8)
    fwp[:, :fw.shape[1]] = fw
    ds = [_lv_glyph(str(d)) for d in range(10)]
    wd = max(d.shape[1] for d in ds)
    wd += wd % 2
    boxes = []
    for d in ds:
        bx = np.zeros((LVH, wd), dtype=np.uint8)
        bx[:, :d.shape[1]] = d
        boxes.append(bx)
    return fwp, fw.shape[1], boxes, [d.shape[1] for d in ds]


def lv_film(n, parts=None):
    fwp, fwi, boxes, dw = lv_parts() if parts is None else parts
    ds = [int(c) for c in str(n)]
    tw = fwi + LV_GAP + sum(dw[d] for d in ds) + LV_DGAP * (len(ds) - 1)
    x = (LVW - tw) // 2
    px = np.zeros((LVH, LVW), dtype=np.uint8)
    for a, xx in [(fwp, x)] + [(boxes[d], x + fwi + LV_GAP + sum(dw[e] + LV_DGAP for e in ds[:i])) for i, d in enumerate(ds)]:
        m = a != 0
        px[:, xx:xx + a.shape[1]][m[:, :LVW - xx]] = a[:, :LVW - xx][m[:, :LVW - xx]]
    return px


# v0.24 film test 8: the row's left cell (82 x 62, the stock small "COLOR / 1" cell: word fill rows 7..26, digits
# rows 32..55, 8..14 px wide; the wheel screen's left column draws this size) -> "FILM" cap 20, baseline 26; digits
# cap 22, baseline 55 (as the list cell's, a little under the stock), drawn by the camera like the list cells.
LCW, LCH, LT = 82, 62, 30
LD = LCH - LT


def film_ltop():
    return picture([('FILM', 20, 26)], LCW, LT, 0.88, (0.20, 0.40, 0.60))


def film_ldigits():
    small = [word(str(d), 22, 99, 0.92) for d in range(10)]
    fw = max(a.shape[1] for a, _ in small) + 4
    fw += fw % 2
    out = []
    for a, b in small:
        cov = np.zeros((LD, fw))
        y0, x0 = int(round(55 - LT - b)), (fw - a.shape[1]) // 2
        cov[y0:y0 + a.shape[0], x0:x0 + a.shape[1]] = a
        out.append(quant(cov))
    return out


def film_lcell(n, top=None, digs=None):
    top = film_ltop() if top is None else top
    digs = film_ldigits() if digs is None else digs
    fw = digs[0].shape[1]
    px = np.zeros((LCH, LCW), dtype=np.uint8)
    px[:LT] = top
    ds = [int(c) for c in str(n)]
    tw = len(ds) * fw - 2 * (len(ds) - 1)
    x = (LCW - tw) // 2
    for d in ds:
        g = digs[d]
        for yy in range(LD):
            for xx in range(fw):
                v, c = g[yy, xx], px[LT + yy, x + xx]
                if v and (c == 0 or c == 7):
                    px[LT + yy, x + xx] = v
        x += fw - 2
    return px


def sat_pictures():
    """Film test 8 (owner): the wheel's Saturation page always shows all colours, so its pictures say "Saturation":
    the dial label (70 x 30, in place of the camera's "Color" there; card/mklabels.py, the Extras labels' style) and
    the guide (film test 8: 180 x 50 for "Color Select [INFO]"; film test 11: 175 x 50 for "Color All [INFO]", the
    Saturation page now showing one colour at a time; card/mkguides.py). Returns two palette arrays."""
    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'card'))
    import mklabels, mkguides
    lab = np.asarray(mklabels.build('Saturation'), dtype=np.uint8)
    gd = np.asarray(mkguides.build('Saturation'), dtype=np.uint8)   # film test 11: 175 x 50, for the one-colour page
    assert lab.shape == (30, 70) and gd.shape == (50, 175)
    return lab, gd


def hsl_labels():
    """Film test 10 (owner: "hue, saturation and luminance"): the wheel's "Color" dial label on the Hue and Luminance
    pages, 70 x 30 as sat_pictures' label (card/mklabels.py style)."""
    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'card'))
    import mklabels
    out = [np.asarray(mklabels.build(t), dtype=np.uint8) for t in ('Hue', 'Luminance')]
    assert all(a.shape == (30, 70) for a in out)
    return out


def pack4(a):
    """palette rows, two pixels a byte (low nibble first)"""
    f = a.flatten().tolist()
    if len(f) % 2: f.append(0)
    return bytes(f[i] | f[i + 1] << 4 for i in range(0, len(f), 2))


def encode11(px, w, h):
    """OSD type-11 stream; as the stock pictures, no run crosses a row's end."""
    toks, i = [], 0
    while i < len(px):
        v, r = px[i], 1
        while r < 16 and (i + r) % w and px[i + r] == v: r += 1
        toks.append(v << 4 | (r - 1)); i += r
    out = bytearray([(h - 1) & 255, ((h - 1) >> 8 & 3) | (((w - 1) & 15) << 4), ((w - 1) >> 4) & 63, 11])
    for k in range(0, len(toks), 5):
        word_ = 0
        for s, t in enumerate(toks[k:k + 5]): word_ |= t << (12 * s)
        out += word_.to_bytes(8, 'little')
    return bytes(out)


def streams():
    """[(w, h, stream)] in PICTURES order."""
    return [(w, h, encode11(bytes(picture(l, w, h, *STYLE.get(k, ())).flatten()), w, h)) for k, (l, w, h) in enumerate(PICTURES)]


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--preview'); a = ap.parse_args()
    print([len(s) for _, _, s in streams()], 'bytes')
    if a.preview:
        pal = {0: (40, 40, 40), 7: (10, 10, 10), 10: (255, 255, 255), 11: (210, 210, 210), 12: (150, 150, 150)}
        sheet = Image.new('RGB', (len(PICTURES) * (CW + 10), CH), (40, 40, 40))
        for k, (l, w, h) in enumerate(PICTURES):
            rgb = Image.new('RGB', (w, h)); rgb.putdata([pal[int(v)] for v in picture(l, w, h).flatten()])
            sheet.paste(rgb, (k * (CW + 10), 0))
        sheet.resize((sheet.width * 2, CH * 2), Image.NEAREST).save(a.preview)


# v0.25 WB grid row: its left cell (100 x 76, as the camera's WB screen cell): the camera's own WB± picture (82 x 30,
# picture 12545, copied by the firmware at run time) over the fine-tune values as the camera writes them ("A2.G2",
# "B1.0"; blank when both are 0). The firmware (xblock xb_wbc) draws it from these glyphs: 0..7, A, B, G, M, '.'.
WBC_CHARS = '01234567ABGM.'
WBC_GH, WBC_BASE, WBC_CAP = 26, 22, 18          # glyph rows, baseline row in them, cap height
WBC_IX, WBC_IY, WBC_TY = 9, 6, 40               # the WB± picture's place; the text glyphs' top row


def wbc_glyphs():
    """[array WBC_GH x w] per WBC_CHARS: our font, the cells' style (2 px dark edge), trimmed to the ink + edge."""
    out = []
    for ch in WBC_CHARS:
        small, b = word(ch, WBC_CAP, 40, 0.92)
        cov = np.zeros((WBC_GH, small.shape[1] + 4))
        y0 = int(round(WBC_BASE - b))
        cov[y0:y0 + small.shape[0], 2:2 + small.shape[1]] = small
        out.append(quant(cov, (0.20, 0.40, 0.60)))
    return out


def wbc_text(ab, gm):
    if ab == 0 and gm == 0:
        return ''
    f = lambda v, p, n: '0' if v == 0 else (p if v > 0 else n) + str(abs(v))
    return f(ab, 'A', 'B') + '.' + f(gm, 'G', 'M')


def wbc_cell(ab, gm, wbpm=None):
    """the cell as the firmware draws it (wbpm: the WB± picture, 30 x 82, for previews only)"""
    cell = np.zeros((CH, CW), dtype=np.uint8)
    if wbpm is not None:
        cell[WBC_IY:WBC_IY + 30, WBC_IX:WBC_IX + 82] = wbpm
    gl = wbc_glyphs()
    t = [gl[WBC_CHARS.index(c)] for c in wbc_text(ab, gm)]
    tot = sum(g.shape[1] - 2 for g in t) + 2 if t else 0
    x = (CW - tot) // 2
    for g in t:
        for yy in range(WBC_GH):
            for xx in range(g.shape[1]):
                v, d = g[yy, xx], cell[WBC_TY + yy, x + xx]
                if v and (v != 7 or d in (0, 7)):
                    cell[WBC_TY + yy, x + xx] = v
        x += g.shape[1] - 2
    return cell


# v0.27 arrow keys: the ▲ and ◀ pictures of the Button Function rows and the picker title (40 x 40). Our own drawing,
# sized and coloured to sit with the camera's ▼ / ▶ cells (owner, camera test ak2: the first ones were too small):
# ▲ spans x 2..37, y 7..30; ◀ x 6..29, y 2..37; fill 13, a dark outline 7 and an outer edge 9, clear (0) outside.
ARROW_W = ARROW_H = 40


def arrow_picture(direction):
    """4-bit picture (numpy, ARROW_H x ARROW_W); direction 'up' or 'left'."""
    import numpy as np
    n = 4                                            # supersampling
    ys, xs = (np.mgrid[0:ARROW_H * n, 0:ARROW_W * n] + 0.5) / n
    if direction == 'left':
        xs, ys = ys, xs                              # the up triangle turned on its side (tip at the left)
    x0, x1, top, base = 2.0, 38.0, 7.0, 31.0         # base 36 px at y 31, tip at the middle of y 7
    t = (ys - top) / (base - top)                    # 0 at the tip, 1 at the base
    inside = (t >= 0) & (t <= 1) & (np.abs(xs - (x0 + x1) / 2) <= (x1 - x0) / 2 * t)
    cov = inside.reshape(ARROW_H, n, ARROW_W, n).mean(axis=(1, 3))
    m = cov >= 0.5

    def erode(a):
        b = a.copy()
        b[1:, :] &= a[:-1, :]; b[:-1, :] &= a[1:, :]; b[:, 1:] &= a[:, :-1]; b[:, :-1] &= a[:, 1:]
        return b
    m1 = erode(m); m2 = erode(m1)
    px = np.zeros((ARROW_H, ARROW_W), dtype=np.uint8)
    px[m] = 9
    px[m1] = 7
    px[m2] = 13
    return px


def arrow_streams():
    """[(w, h, stream)] for ▲, ◀."""
    return [(ARROW_W, ARROW_H, encode11(bytes(arrow_picture(d).flatten().tolist()), ARROW_W, ARROW_H)) for d in ('up', 'left')]


def arrows4_picture():
    """The fourth arrow-pad option (all four keys assignable): ▲ ◀ ▶ ▼ in a row, 104 x 40, the camera's option-picture
    colours (fill 13, outline 7, edge 9). Our own drawing."""
    import numpy as np
    n, W, H = 4, 104, 40
    ys, xs = (np.mgrid[0:H * n, 0:W * n] + 0.5) / n
    m = np.zeros((H, W), dtype=bool)
    for k, d in enumerate(('up', 'left', 'right', 'down')):
        cx, cy, half = 13 + 26 * k, 20.0, 10.0          # each triangle 20 x 20, centred in its 26 px column
        u, v = xs - cx, ys - cy
        if d == 'down':
            v = -v
        elif d == 'left':
            u, v = v, u
        elif d == 'right':
            u, v = v, -u
        t = (v + half) / (2 * half)                       # 0 at the tip, 1 at the base
        inside = (t >= 0) & (t <= 1) & (np.abs(u) <= half * t)
        m |= inside.reshape(H, n, W, n).mean(axis=(1, 3)) >= 0.5

    def erode(a):
        b = a.copy()
        b[1:, :] &= a[:-1, :]; b[:-1, :] &= a[1:, :]; b[:, 1:] &= a[:, :-1]; b[:, :-1] &= a[:, 1:]
        return b
    m1 = erode(m); m2 = erode(m1)
    px = np.zeros((H, W), dtype=np.uint8)
    px[m] = 9
    px[m1] = 7
    px[m2] = 13
    return px


def arrows4_stream():
    p = arrows4_picture()
    return (p.shape[1], p.shape[0], encode11(bytes(p.flatten().tolist()), p.shape[1], p.shape[0]))


# v0.27 Creative Dial rows (Button Function), our own drawing (DejaVu Sans Condensed), matched to the camera's
# measured style (owner, dr1: "look slightly off" next to the stock rows):
# - row / picker-title icons as the camera's boxed button names (L-Fn 73 x 40): a light box (13) with a 1 px border (7)
#   and a 1 px dark rim (8) outside it, small round corners; the word solid in 7, cap 28 px (rows 6..33), 4 px strokes;
# - value pictures as the camera's "AF Stop" (118 x 40): letters filled 13, a 1 px outline 7, a 1 px rim 8 / 9, cap
#   ~31 px (rows 3..34 filled).
DIAL_WORDS = ('CRT', 'ART', 'COLOR', 'MONO')
BOLD = '/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf'


def dial_label(txt, cap=28, maxw=74):
    import numpy as np
    small, b = word(txt, cap, maxw, 0.95)
    tw = small.shape[1]
    H, W = 40, tw + 14
    px = np.zeros((H, W), dtype=np.uint8)
    yy, xx = np.mgrid[0:H, 0:W]
    def rrect(x0, y0, x1, y1, r):
        cx = np.clip(xx, x0 + r, x1 - r); cy = np.clip(yy, y0 + r, y1 - r)
        return ((xx - cx) ** 2 + (yy - cy) ** 2 <= r * r + 0.5) & (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)
    px[rrect(2, 0, W - 3, H - 1, 4)] = 8
    px[rrect(3, 1, W - 4, H - 2, 3)] = 7
    inner = rrect(4, 2, W - 5, H - 3, 2)
    px[inner] = 13
    y0, x0 = int(round(33.5 - b)), (W - tw) // 2
    cov = np.zeros((H, W)); h = min(small.shape[0], H - y0); cov[y0:y0 + h, x0:x0 + tw] = small[:h, :]
    px[(cov >= 0.3) & inner] = 14
    px[(cov >= 0.42) & inner] = 7
    return px


def value_picture(txt, cap=31, maxw=150):
    """The camera's value-picture style ("AF Stop"): letters filled 13 (14 on soft edges), a 1 px outline 7, a 1 px
    rim 8 (9 where it only touches diagonally); 40 px high, baseline row 34."""
    import numpy as np
    small, b = word(txt, cap, maxw, 0.86)
    tw = small.shape[1]
    H, W = 40, tw + 6
    cov = np.zeros((H, W))
    y0 = int(round(34.5 - b)); h = min(small.shape[0], H - 1 - y0)
    cov[y0:y0 + h, 3:3 + tw] = small[:h, :]
    fill = cov >= 0.4
    cross = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], bool)
    o1 = ndimage.binary_dilation(fill, structure=cross) & ~fill
    o2 = ndimage.binary_dilation(fill | o1, structure=cross) & ~(fill | o1)
    o2d = ndimage.binary_dilation(fill | o1, structure=np.ones((3, 3), bool)) & ~(fill | o1 | o2)
    px = np.zeros((H, W), dtype=np.uint8)
    px[o2d] = 9
    px[o2] = 8
    px[o1] = 7
    px[fill] = 13
    px[fill & (cov < 0.6)] = 14
    return px


def dial_value_words():
    return ['Normal', 'CRT', 'ART', 'COLOR', 'MONO']           # dr3: the modes a position can take


def dial_streams():
    """[(w, h, stream)]: the icons CRT, ART, COLOR, MONO, then the value pictures (Normal, CRT, ART, COLOR, MONO)."""
    out = []
    for p in [dial_label(t) for t in DIAL_WORDS] + [value_picture(t) for t in dial_value_words()]:
        out.append((p.shape[1], p.shape[0], encode11(bytes(p.flatten().tolist()), p.shape[1], p.shape[0])))
    return out
