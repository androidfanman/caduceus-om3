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
    ([('Blk', 18, 30), ('Wht', 18, 60)], CW, CH), ([], 8, 2), ([], 8, 2), ([], W, H),  # v0.28 the Blacks / Whites grid row's left cell before it is drawn with its values (was the Blk / Wht slider icons); A-B unused (the WB grid row shows the camera's WB± picture); borders b1c: the Border row's icon in G-M's place (border_icon)
    ([('Vignette', 15, 30), ('Off', 18, 60)], CW, CH), ([('Vignette', 15, 30), ('On', 18, 60)], CW, CH),
    ([('Noise', 15, 30), ('Off', 18, 60)], CW, CH), ([('Noise', 15, 30), ('Low', 18, 60)], CW, CH),
    ([('Noise', 15, 30), ('Std', 18, 60)], CW, CH), ([('Noise', 15, 30), ('High', 18, 60)], CW, CH),
    ([('HSL', 26, 44)], 82, 62),   # v0.24 film test 7 (owner): the Color row's cell, stock "Color / Vivid" (82 x 62)
    ([('Glow', 20, 33)], W, H),    # v0.25: the Glow (+) / Clarity (-) slider's icon (owner: named for the + side)
    ([('Halo', 20, 33)], W, H), ([('Bal', 20, 33)], W, H),  # v0.28: the Halation and Tone Balance sliders' icons (Frame Off / On's places)
    ([('Grain', 20, 33)], W, H),   # better grain g2 (id 0x7f78): the Film Grain strength slider's icon (grain_icon)
    ([], 82, 62), ([], 82, 62), ([], 82, 62), ([], 82, 62),   # Halation Radius (ids IC_RZ0..): its row's left cells (r4: radius_cell, the Grain Size pictures' size)
    ([], 100, 76), ([], 100, 76), ([], 100, 76), ([], 100, 76),  # r4: its strip cells (ids IC_RZS..; were the words in the camera's font)
    ([], 82, 62),                  # the Split toning row's cell (id IC_SP): split_icon
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


def _pad(a, w=None):
    """a at the left of a picture w wide, by default its own width rounded up to even"""
    out = np.zeros((a.shape[0], a.shape[1] + a.shape[1] % 2 if w is None else w), dtype=np.uint8)
    out[:, :a.shape[1]] = a
    return out


def sp_parts():
    """(word picture, its width even-padded; digit boxes 10 x SPH x WD; digit ink widths)"""
    fw = _sp_word('FILM')
    fwp = _pad(fw)
    ds = [_sp_part(str(d)) for d in range(10)]
    wd = max(d.shape[1] for d in ds)
    wd += wd % 2
    boxes = [_pad(d, wd) for d in ds]
    return fwp, fw.shape[1], boxes, [d.shape[1] for d in ds]


def sp_star():
    """v0.28 (owner: "FILM 1*"): the quick menu's '*' after the number, in its lettering (the asterisk sits high, as the
    camera's "COLOR*"); -> (picture even-padded, ink width)."""
    st = _sp_part('*')
    return _pad(st), st.shape[1]


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
# the '*' of a changed film, placed as the camera's "COLOR1*": its fill 8 rows above the cap line, its dark edge over the digit's edge
LV_SCAP, LV_STOP, LV_SGAP = 18, LV_BASE - LV_CAP + 1 - 8, -5


def _lv_glyph(txt, cap=LV_CAP):
    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'card'))
    import mklabels
    fs = next(f for f in range(10, 80) if (lambda r: r[1] - r[0] + 1)(mklabels.cap_rows(f)) >= cap)
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
    fwp = _pad(fw)
    ds = [_lv_glyph(str(d)) for d in range(10)]
    wd = max(d.shape[1] for d in ds)
    wd += wd % 2
    boxes = [_pad(d, wd) for d in ds]
    return fwp, fw.shape[1], boxes, [d.shape[1] for d in ds]


def lv_star():
    """as sp_star, for the shooting screen -> (picture even-padded, ink width)"""
    st = _lv_glyph('*', LV_SCAP)
    sh = LV_STOP - np.argwhere(st == 10)[:, 0].min()
    out = np.zeros_like(st)
    if sh >= 0:
        assert not st[st.shape[0] - sh:].any()
        out[sh:] = st[:st.shape[0] - sh]
    else:
        assert not st[:-sh].any()
        out[:sh] = st[-sh:]
    st = out
    return _pad(st), st.shape[1]


def lv_film(n, parts=None, star=None):
    fwp, fwi, boxes, dw = lv_parts() if parts is None else parts
    ds = [int(c) for c in str(n)]
    tw = fwi + LV_GAP + sum(dw[d] for d in ds) + LV_DGAP * (len(ds) - 1)
    if star is not None:
        sx = tw + LV_SGAP
        tw = sx + star[1]
    x = (LVW - tw) // 2
    px = np.zeros((LVH, LVW), dtype=np.uint8)
    for a, xx in [(fwp, x)] + [(boxes[d], x + fwi + LV_GAP + sum(dw[e] + LV_DGAP for e in ds[:i])) for i, d in enumerate(ds)] \
            + ([(star[0], x + sx)] if star is not None else []):
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
    Saturation page now showing one colour at a time; card/mkguides.py), and #64's "Sat. All [INFO]" guide for all
    colours. Returns three palette arrays."""
    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'card'))
    import mklabels, mkguides
    lab = np.asarray(mklabels.build('Saturation'), dtype=np.uint8)
    gd = np.asarray(mkguides.build('Saturation'), dtype=np.uint8)   # film test 11: 175 x 50, for the one-colour page
    gda = np.asarray(mkguides.build('Sat. All', 'del'), dtype=np.uint8)  # #64: the same page with all colours;
    # feature/picture-mode: Delete turns them off there now (INFO steps H / S / L), so its key is the Delete key
    assert lab.shape == (30, 70) and gd.shape == gda.shape == (50, 175)
    return lab, gd, gda


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


# v0.28 Blacks / Whites grid (owner, look D): our pictures in place of the camera's WB grid pictures while that grid
# shows (editor.s bwg_swap): the square (206 x 206, as the camera's 10904: fill 52, a cross with 15 ticks in 81, 6 px
# bands), its bands black (left / right, outlined) and white (top / bottom); the boxes' letters as -/+ swatches
# (32 x 32): black for Blacks (B '-', A '+'), white for Whites (M '-', G '+'); the header's letters (16 x 30) and its
# "WBAuto" (86 x 44) as "Blk/Wht". All drawn here from scratch (palette indices: 7 dark, 10 white, 52 the grid's
# fill, 81 its lines); no camera graphics copied.
BWG_TICKS = (12, 25, 38, 51, 64, 77, 90, 103, 115, 128, 141, 154, 167, 180, 193)


def bwg_square():
    n, b = 206, 6
    px = np.full((n, n), 52, dtype=np.uint8)
    px[103, b:n - b] = 81
    px[b:n - b, 103] = 81
    for t in BWG_TICKS:
        px[99:108, t] = 81
        px[t, 99:108] = 81
    y, x = np.mgrid[0:n, 0:n]
    d = np.stack([y, n - 1 - y, x, n - 1 - x])          # distance to the top, bottom, left, right edge
    near = d.min(axis=0)
    side = d.argmin(axis=0)
    band = near < b
    white = band & (side < 2)
    black = band & (side >= 2)
    px[white] = 10
    px[black] = 7
    px[black & ((near == 0) | (near == b - 1))] = 81     # the black bands' grey outline (else lost on the dark screen)
    return px


def bwg_sign(plus, w, h, bar, length, fg, bg, edge=None):
    px = np.full((h, w), bg, dtype=np.uint8)
    cy, cx = h // 2, w // 2
    px[cy - bar // 2:cy - bar // 2 + bar, cx - length // 2:cx - length // 2 + length] = fg
    if plus:
        px[cy - length // 2:cy - length // 2 + length, cx - bar // 2:cx - bar // 2 + bar] = fg
    if edge is not None:
        ink = px == fg
        px[ndimage.binary_dilation(ink, structure=np.ones((3, 3)), iterations=1) & ~ink] = edge
    return px


def bwg_pictures():
    """[(pixels, w, h)] in bwg_swap order: square, box A '+', box B '-', box G '+', box M '-', header '+', header '-',
    the header title "Blk/Wht"."""
    box = lambda plus, fg, bg: bwg_sign(plus, 32, 32, 4, 18, fg, bg)
    hdr = lambda plus: bwg_sign(plus, 16, 30, 3, 12, 10, 0, 7)
    return [(bwg_square(), 206, 206), (box(True, 10, 7), 32, 32), (box(False, 10, 7), 32, 32),
            (box(True, 7, 10), 32, 32), (box(False, 7, 10), 32, 32), (hdr(True), 16, 30), (hdr(False), 16, 30),
            (picture([('Blk/Wht', 20, 32)], 86, 44, 0.92, (0.20, 0.40, 0.60)), 86, 44)]


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


# colour menu (test 7, owner-approved spec color-menu-design/SPEC.md): drawings instead of words for four cells. The
# left column's palette (om-emu, 2026-11-15, a 16 x 16 probe in a cell): 0 clear, 7 black, 10 white, 11 / 12 soft
# greys, greys 43..60 / 93 / 97..100 / 121 / 124, orange 34 (253,104,0) / 55 / 102 / 17 / 18 (darker), red 122, yellow
# 123, yellow-green 38, green 40 / 41 / 54, blue 53; no cyan, magenta or purple (those are two colours alternated).
GREYS = [(10, 254), (98, 235), (99, 198), (46, 178), (11, 170), (97, 147), (43, 115), (44, 90), (12, 85), (58, 77),
         (100, 64), (51, 60), (59, 45), (45, 40), (60, 33)]


def _grey(v):
    return min(GREYS, key=lambda g: abs(g[1] - v))[0]


def hsl_pie():
    """the Color wheel row's cell (82 x 62, the "HSL" word's place): a disc of the wheel's 12 colours, yellow at 12
    o'clock, clockwise, a thin white rim with a dark edge"""
    import math
    w, h, cx, cy, R = 82, 62, 41, 31, 24
    secs = [(123,), (123, 34), (34,), (122,), (122, 53), (53, 53, 122), (53,), (53, 53, 40), (53, 40), (41, 41, 53),
            (41,), (38,)]
    px = np.zeros((h, w), dtype=np.uint8)
    for y in range(h):
        for x in range(w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r > R + 2:
                continue
            if r > R + 0.5:
                px[y, x] = 7
            elif r > R - 1.5:
                px[y, x] = 10
            else:
                a = (math.degrees(math.atan2(dy, dx)) + 90 + 15) % 360
                c = secs[int(a // 30)]
                px[y, x] = c[(x + y) % len(c)]
    return px


def split_icon():
    """the Split toning row's cell (82 x 62, as the colour wheel row's): a disc cut on the diagonal, orange (the
    highlights) upper right, blue (the shadows) lower left, a thin white rim with a dark edge as hsl_pie's"""
    import math
    w, h, cx, cy, R = 82, 62, 41, 31, 24
    px = np.zeros((h, w), dtype=np.uint8)
    for y in range(h):
        for x in range(w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r > R + 2:
                continue
            if r > R + 0.5:
                px[y, x] = 7
            elif r > R - 1.5 or abs(dx + dy) < 1.2:
                px[y, x] = 10
            else:
                px[y, x] = 34 if dy < -dx else 53
    return px


def glow_icon():
    """Glow (46 x 46, the "Glow" word's place): a white dot with a soft white glow round it"""
    import math
    px = np.zeros((46, 46), dtype=np.uint8)
    for y in range(46):
        for x in range(46):
            r = math.hypot(x + 0.5 - 23, y + 0.5 - 23)
            if r <= 4.5:
                px[y, x] = 10
            elif r < 16:
                t = (r - 4.5) / 11.5
                v = 255 * (0.92 * (1 - t) ** 1.3)
                if v >= 30:
                    px[y, x] = _grey(v)
    return px


def halo_icon():
    """Halation (46 x 46, the "Halo" word's place): a white dot with a red-orange ring"""
    import math
    px = np.zeros((46, 46), dtype=np.uint8)
    for y in range(46):
        for x in range(46):
            r = math.hypot(x + 0.5 - 23, y + 0.5 - 23)
            if r <= 5:
                px[y, x] = 10
                continue
            q = 1 - abs(r - 10.5) / 5.5            # the ring: strongest at r 10.5, gone at 5 and 16
            if q > 0.75:
                px[y, x] = 34
            elif q > 0.5:
                px[y, x] = 55
            elif q > 0.28:
                px[y, x] = 17
            elif q > 0.1:
                px[y, x] = 18
    return px


def bal_icon():
    """Split Tone Balance (46 x 46, the "Bal" word's place): a dark-to-light tone bar, white outline, a small white
    triangle under its middle"""
    px = np.zeros((46, 46), dtype=np.uint8)
    x0, x1, y0, y1 = 5, 41, 13, 27
    px[y0:y1, x0:x1] = 10
    for x in range(x0 + 2, x1 - 2):
        px[y0 + 2:y1 - 2, x] = _grey(30 + 225 * (x - x0 - 2) / (x1 - x0 - 5))
    for y in range(7):
        px[30 + y, 23 - y:23 + y + 1] = 10
    return px


def border_icon():
    """Border (46 x 46, borders b1c; owner: the camera's own Frame picture is too big for this slot): a small photo
    with a white border, the same width all round: white frame 4 px, a grey picture inside (light sky, a darker hill),
    a 1 px dark line between them and a 2 px dark edge round the outside, as the other icons"""
    px = np.zeros((46, 46), dtype=np.uint8)
    x0, x1, y0, y1 = 6, 40, 10, 36                 # the print: 34 x 26
    px[y0:y1, x0:x1] = 10
    ix0, ix1, iy0, iy1 = x0 + 4, x1 - 4, y0 + 4, y1 - 4
    px[iy0 - 1:iy1 + 1, ix0 - 1:ix1 + 1] = 7       # the line round the picture
    px[iy0:iy1, ix0:ix1] = _grey(147)              # sky
    for x in range(ix0, ix1):                      # a hill: rises from the left, falls to the right
        top = iy0 + 7 + abs(x - (ix0 + 16)) // 3
        px[top:iy1, x] = _grey(77)
    ring = ndimage.binary_dilation(px > 0, structure=np.ones((3, 3)), iterations=2) & (px == 0)
    px[ring] = 7
    return px


def grain_icon():
    """Film Grain (46 x 46, better grain g2): a small square of film grain, 2 x 2 specks in greys from dark to white
    with a few coloured specks (the grain's colour), a 2 px dark edge round it as the other icons"""
    px = np.zeros((46, 46), dtype=np.uint8)
    rng = np.random.default_rng(1103)
    x0, x1, y0, y1 = 9, 37, 9, 37                 # 28 x 28: 14 x 14 specks
    for y in range(y0, y1, 2):
        for x in range(x0, x1, 2):
            v = rng.normal(150, 55)
            c = _grey(min(254, max(40, v)))
            r = rng.random()
            if r < 0.03:
                c = 55                             # orange
            elif r < 0.055:
                c = 53                             # blue
            elif r < 0.07:
                c = 41                             # green
            px[y:y + 2, x:x + 2] = c
    for (y, x) in ((y0, x0), (y0, x1 - 1), (y1 - 1, x0), (y1 - 1, x1 - 1)):
        px[y, x] = 0                               # rounded corners
    ring = ndimage.binary_dilation(px > 0, structure=np.ones((3, 3)), iterations=2) & (px == 0)
    px[ring] = 7
    return px


RZ_KINDS = ('Bloom', 'Tight', 'Med', 'Wide')
RZ_REACH = {'Tight': 3.0, 'Med': 5.5, 'Wide': 9.5}   # the orange ring's width past the light (px at the left patch's scale)


def radius_patch(kind, pw, ph, s=1.0):
    """Halation Radius (r4, owner-approved preview 2026-11-20: "Yes, build them"): a small night patch, pw x ph, in a
    white 2 px frame with rounded corners, a white light in the middle. Bloom: a soft haze (a larger white centre, pale
    tones, a dithered warm edge); Tight / Med / Wide: a crisp light with a thin / medium / wide orange ring (the
    Halation icon's oranges). Drawn from scratch."""
    import math
    px = np.full((ph, pw), 10, dtype=np.uint8)
    px[2:ph - 2, 2:pw - 2] = 7
    for (y, x) in ((0, 0), (0, pw - 1), (ph - 1, 0), (ph - 1, pw - 1)):
        px[y, x] = 0
    cx, cy, core = pw / 2, ph / 2, 2.6 * s
    for y in range(2, ph - 2):
        for x in range(2, pw - 2):
            r = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r <= core:
                px[y, x] = 10
                continue
            if kind == 'Bloom':
                if r <= core + 1.2 * s:
                    c = 10
                elif r <= core + 2.6 * s:
                    c = 98
                elif r <= core + 4.0 * s:
                    c = 99
                else:
                    t = (r - core - 4.0 * s) / (7.5 * s)
                    if t >= 1.0:
                        continue
                    pair = ((46, 34), (34, 55), (55, 17), (17, 18), (18, 7))[min(4, int(t * 5))]
                    c = pair[(x + y) % 2]
            else:
                t = (r - core) / (RZ_REACH[kind] * s)
                if r <= core + 0.9:
                    c = 98
                elif t < 0.45:
                    c = 34
                elif t < 0.70:
                    c = 55
                elif t < 0.88:
                    c = 17
                elif t < 1.0:
                    c = 18
                else:
                    continue
            px[y, x] = c
    return px


def radius_cell(kind, strip=False):
    """the row's cell, as the camera's Grain Size pictures: left column 82 x 62 (patch 36 x 30, the word cap 19,
    baseline 54), strip 100 x 76 (patch 42 x 31, cap 23, baseline 64); the word in our lettering with its own 2 px dark
    edge, as Grain Size's words (r5, owner: "it should match the camera and grain"; r4 put a second ring round the
    word too, a black box behind it), and a 2 px dark edge round the patch"""
    w, h, pw, ph, py, cap, base = (100, 76, 42, 31, 5, 23, 64) if strip else (82, 62, 36, 30, 2, 19, 54)
    px = picture([(kind, cap, base)], w, h, *STYLE.get(10, ()))
    p = radius_patch(kind, pw, ph, s=pw / 36)
    x0 = (w - pw) // 2
    pm = np.zeros(px.shape, bool)
    pm[py:py + ph, x0:x0 + pw] = p > 0
    px[pm] = p[p > 0]
    ring = ndimage.binary_dilation(pm, structure=np.ones((3, 3)), iterations=2) & (px == 0)
    px[ring] = 7
    return px


CUSTOM = {3: border_icon, 10: hsl_pie, 11: glow_icon, 12: halo_icon, 13: bal_icon, 14: grain_icon, 23: split_icon}
CUSTOM.update({15 + i: (lambda k=k: radius_cell(k)) for i, k in enumerate(RZ_KINDS)})            # r4: ids IC_RZ0 + i
CUSTOM.update({19 + i: (lambda k=k: radius_cell(k, strip=True)) for i, k in enumerate(RZ_KINDS)})  # r4: ids IC_RZS + i


def streams():
    """[(w, h, stream)] in PICTURES order."""
    out = []
    for k, (l, w, h) in enumerate(PICTURES):
        a = CUSTOM[k]() if k in CUSTOM else picture(l, w, h, *STYLE.get(k, ()))
        assert a.shape == (h, w), (k, a.shape)
        out.append((w, h, encode11(bytes(a.flatten()), w, h)))
    return out


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--preview'); a = ap.parse_args()
    print([len(s) for _, _, s in streams()], 'bytes')
    if a.preview:
        pal = {0: (40, 40, 40), 7: (10, 10, 10), 10: (255, 255, 255), 11: (170, 170, 170), 12: (85, 85, 85),
               34: (253, 104, 0), 55: (206, 86, 1), 17: (168, 69, 0), 18: (82, 34, 0), 122: (254, 0, 0),
               123: (254, 255, 0), 38: (140, 170, 0), 40: (0, 254, 0), 41: (0, 170, 0), 53: (40, 44, 205)}
        pal.update({g: (v, v, v) for g, v in GREYS})
        sheet = Image.new('RGB', (len(PICTURES) * (CW + 10), CH), (40, 40, 40))
        for k, (l, w, h) in enumerate(PICTURES):
            a = CUSTOM[k]() if k in CUSTOM else picture(l, w, h)
            rgb = Image.new('RGB', (w, h)); rgb.putdata([pal[int(v)] for v in a.flatten()])
            sheet.paste(rgb, (k * (CW + 10), 0))
        sheet.resize((sheet.width * 2, CH * 2), Image.NEAREST).save(a.preview)


# v0.25 WB grid row: its left cell (100 x 76, as the camera's WB screen cell): the camera's own WB± picture (82 x 30,
# picture 12545, copied by the firmware at run time) over the fine-tune values as the camera writes them ("A2.G2",
# "B1.0"; blank when both are 0). The firmware (xblock xb_wbc) draws it from these glyphs: 0..7, A, B, G, M, '.'.
WBC_CHARS = '01234567ABGM.+\u2212/'     # v0.25 Blacks / Whites: '+', '\u2212', '/' (indices 13..15)
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


def wbc_text(ab, gm, bw=False):
    if ab == 0 and gm == 0:
        return ''
    if bw:                                       # Blacks / Whites: "+2/\u22121" (Blk / Wht, as the top line)
        f = lambda v, p, n: '0' if v == 0 else ('+' if v > 0 else '\u2212') + str(abs(v))
    else:
        f = lambda v, p, n: '0' if v == 0 else (p if v > 0 else n) + str(abs(v))
    return f(ab, 'A', 'B') + ('/' if bw else '.') + f(gm, 'G', 'M')


def plate_icon(text, k=1.0):
    """our plate icon (owner, g3: like the WB row's WB± picture, which is the camera's; this one is drawn here from
    scratch in its style) at k times its size: a white plate (66 x 30 at k = 1, a 2 px dark edge, rounded corners) with
    `text` in dark letters and a square split on its diagonal, dark with a white '+' and white with a dark '-'."""
    r = lambda v: int(round(v * k))
    w, h, e = r(66), r(30), r(2)
    px = np.full((h, w), 7, dtype=np.uint8)
    px[e:h - e, e:w - e] = 10
    for y in range(e):
        for x in range(e - y):
            for yy, xx in ((y, x), (y, w - 1 - x), (h - 1 - y, x), (h - 1 - y, w - 1 - x)):
                px[yy, xx] = 0
    if text == 'B/W':                            # colour menu (test 7): a black and a white square ("B/W" reads as
        q, y0 = r(14), r(8)                      # monochrome on a camera), the white one outlined to show on the plate
        px[y0:y0 + q, r(5):r(5) + q] = 7
        px[y0:y0 + q, r(21):r(21) + q] = 7
        px[y0 + r(2):y0 + q - r(2), r(21) + r(2):r(21) + q - r(2)] = 10
    else:
        cov, b = word(text, r(17), r(34), 1.0)
        y0, xs = int(round(r(23) - b)), r(4) + (r(34) - cov.shape[1]) // 2
        for y in range(cov.shape[0]):
            for x in range(cov.shape[1]):
                c, yy, xx = cov[y, x], y0 + y, xs + x
                if 0 <= yy < h and 0 <= xx < w and px[yy, xx] == 10:
                    px[yy, xx] = 7 if c >= 0.6 else 12 if c >= 0.35 else 11 if c >= 0.15 else 10
    sx, sy, n, t, a = r(40), r(4), r(22), r(2), r(4)
    for y in range(n):
        for x in range(n - 1 - y):
            px[sy + y, sx + x] = 7
    cx, cy = sx + r(7), sy + r(7)
    px[cy - 1:cy - 1 + t, cx - a:cx + a + 1] = 10
    px[cy - a:cy + a + 1, cx - 1:cx - 1 + t] = 10
    px[sy + r(15):sy + r(15) + t, sx + r(11):sx + r(19)] = 7
    return px


def bw_top():
    """the Blacks / Whites row's cell top over its values (g3): the plate "B/W", 82 x 30 as the camera's WB±"""
    px = np.zeros((30, 82), dtype=np.uint8)
    px[:, 8:74] = plate_icon('B/W')
    return px


ZC_K = 1.2                                       # owner, g4: at 0 / 0 the icon bigger and centred (g5: 1.4 was clipped)
ZC_WIN = 82                                      # the list shows only this strip of the cell, from WBC_IX (the WB±
                                                 # picture's place): g4's 92 px plate lost its edges (camera; om-emu too)


def zero_cell(text):
    """the WB ('WB') and Blacks / Whites ('B/W') rows' left cell at 0 / 0 (owner, g4: no values -> the icon alone,
    bigger, centred in the cell): 100 x 76, our plate at ZC_K (79 x 36) in the middle of the shown strip. editor.s
    wb_draw points the cell there."""
    cell = np.zeros((CH, CW), dtype=np.uint8)
    p = plate_icon(text, ZC_K)
    assert p.shape[1] <= ZC_WIN - 2
    y, x = (CH - p.shape[0]) // 2, WBC_IX + (ZC_WIN - p.shape[1]) // 2
    cell[y:y + p.shape[0], x:x + p.shape[1]] = p
    return cell


def bw_syms():
    """the Blacks / Whites grid's own symbols in place of the camera's letters: the boxes' '+' / '\u2212' (32 x 32, as
    the letters G / A / B / M) and the header's '+' (16 x 30, as its letters; its '\u2212' is the camera's 1120)"""
    return [picture([('+', 22, 27)], 32, 32), picture([('\u2212', 22, 27)], 32, 32), picture([('+', 16, 25)], 16, 30)]


def wbc_cell(ab, gm, wbpm=None, bw=False):
    """the cell as the firmware draws it (wbpm: the WB± picture, 30 x 82, for previews only)"""
    cell = np.zeros((CH, CW), dtype=np.uint8)
    if bw:
        wbpm = bw_top()
    if wbpm is not None:
        cell[WBC_IY:WBC_IY + 30, WBC_IX:WBC_IX + 82] = wbpm
    gl = wbc_glyphs()
    t = [gl[WBC_CHARS.index(c)] for c in wbc_text(ab, gm, bw)]
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


# Custom crop modes (feature/composition-guides): the SCP aspect strip's pictures for the new ratios, 100 x 76 as the
# stock ones (471 / 472 / ...: white figures about 31 px tall, a 2 px dark edge, baseline row 53, measured from the
# camera's "4:3"). Our drawing in DejaVu Sans Condensed; crop.py puts them at CR_IC0 + 0..2.
CROP_LABELS = ('5:4', 'XPan', '21:9')


def crop_pictures():
    return [picture([(t, 31, 53)], CW, CH) for t in CROP_LABELS]


def crop_streams():
    return [(CW, CH, encode11(bytes(p.flatten()), CW, CH)) for p in crop_pictures()]


# c2: the current-value labels. Top bar (46 x 34, as 10930 "16:9" / 10931 "4:3": figures rows 5..28 inside a 2 px
# dark edge) and the SCP cell (160 x 48, as 5859 / 5863: no edge, fill 13, edge shades 14 / 15, rows 8..39).
def cell_quant(cov):
    px = np.zeros(cov.shape, dtype=np.uint8)
    px[cov >= 0.15] = 15
    px[cov >= 0.40] = 14
    px[cov >= 0.66] = 13
    return px


def cell_picture(txt, w=160, h=48, cap=32, base=39):
    small, b = word(txt, cap, w - 20)
    cov = np.zeros((h, w))
    y0, x0 = int(round(base - b)), (w - small.shape[1]) // 2
    sh = cov[y0:y0 + small.shape[0], x0:x0 + small.shape[1]]
    cov[y0:y0 + small.shape[0], x0:x0 + small.shape[1]] = small[:sh.shape[0], :sh.shape[1]]
    return cell_quant(cov)


def crop_label_streams():
    """[(w, h, stream)]: the strip's 3 (100 x 76), the top bar's 3 (46 x 34), the SCP cell's 3 (160 x 48)."""
    out = list(crop_streams())
    out += [(46, 34, encode11(bytes(picture([(t, 24, 28)], 46, 34).flatten()), 46, 34)) for t in CROP_LABELS]
    out += [(160, 48, encode11(bytes(cell_picture(t).flatten()), 160, 48)) for t in CROP_LABELS]
    return out
