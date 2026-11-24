#!/usr/bin/env python3
"""Pictures for the RGB curves page (feature/rgb-curves), drawn from scratch (DejaVu Sans Condensed, a free font) in
the camera's OSD text style; no camera graphics are copied.

The page is the camera's Highlight & Shadow page in a mode of ours; its header labels, guide and our row's left cell
are on layers whose palettes have true colours (7 dark edge, 10 white, 11 / 12 soft, 122 red, 40 green, 53 blue: an
om-emu stripe test of the left column showed 105 and 125 not blue, as the owner saw on the camera in test 1);
the curves themselves are drawn by the firmware at run time (cv_draw) on the curve layer.
- 38 x 30 header labels (the size of the camera's "Sh" / "Hi"): "R", "G", "B" in their colours, "Pt".
- "Color [INFO]" guide (in place of "Mid [INFO]"), at most 160 px wide (checked in om-emu: the guide button is 180 px).
- the row's left cell (100 x 76, as our other choice rows): "RGB", each letter in its colour.
- a 2 x 2 clear picture (the camera's curve halves while our page shows).
- colour menu test 7 (spec section 4): white "Sat", "Hue", "Level" header labels, the colour's name ("Red", "Green",
  "Blue") for the header's middle; the "Mix" row cell; clear pictures for the header's middle and RGB's right sign.
  And mixtables(): the Mix page's circle tables (editor's colourmix.inc).
usage: rgbpics.py [--preview PNG]     (build.py imports streams())"""
import argparse, os, sys
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mkicons
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'card'))
import mkguides

RED, GREEN, BLUE, WHITE, EDGE = 122, 40, 53, 10, 7   # test 2: blue 53 (105 / 125 do not show blue: camera, om-emu)


def letters(parts, w, h, cap, base, gap=1, maxw=None, sx=1.0):
    """parts = [(text, fill index)] side by side, centred: fill where coverage >= 0.45, a dark edge round the ink"""
    covs = [(mkicons.word(t, cap, maxw or w, sx)[0], mkicons.word(t, cap, maxw or w, sx)[1], f) for t, f in parts]
    total = sum(c.shape[1] for c, _, _ in covs) + gap * (len(covs) - 1)
    x = (w - total) // 2
    px = np.zeros((h, w), dtype=np.uint8)
    ink = np.zeros((h, w), dtype=bool)
    for c, b, f in covs:
        y0 = int(round(base - b))
        for yy in range(c.shape[0]):
            for xx in range(c.shape[1]):
                Y, X = y0 + yy, x + xx
                if 0 <= Y < h and 0 <= X < w and c[yy, xx] >= 0.45:
                    px[Y, X] = f; ink[Y, X] = True
        x += c.shape[1] + gap
    from scipy import ndimage
    e = ndimage.distance_transform_edt(~ink)
    px[(e > 0) & (e <= 2.0)] = EDGE
    return px


def label(parts):
    return letters(parts, 38, 30, 23, 26)


def guide(word='Color'):
    """the RGB curves / Color Mix pages' "Color [INFO]" (in place of the camera's "Mid [INFO]"). v0.41-a6 (owner, a5 on
    the camera: "All the info icons look different. the text and icon need to all be the same"; option B, "lets go with
    B"): drawn as the H&S row's "Sh/Hi [INFO]" / "B/W [INFO]" and the bars' hints (guide5: info_key, the word at
    mkguides' size a pixel heavier); before: mkguides.build, its bold key and larger word."""
    return guide5(word)


def info_key():
    """five-point curve test 8 (owner, camera c7: "the text on all the Info icons looks different"): the [INFO] key
    measured on the camera's own "Mid [INFO]" guide in om-emu (not copied: drawn here from the measures). White key
    60 x 36 (mkguides' was 62 x 36) in a 2 px dark line; "INFO" in the regular face (mkguides' is bold), 26 px tall,
    the letters 3 / 15 / 12 / 15 px wide with 2 / 2 / 3 px between. -> (50 x 64 palette array, its width)"""
    from scipy import ndimage
    H, KW = 50, 64
    S = 4
    im = Image.new('L', (KW * S, 40 * S), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(im).rounded_rectangle((0, 0, KW * S - 1, 40 * S - 1), radius=3 * S, fill=255)
    full = np.zeros((H, KW + 2), dtype=bool); full[5:45, 1:KW + 1] = np.array(im.resize((KW, 40), Image.LANCZOS)) > 128
    img = np.zeros((H, KW + 2), dtype=np.uint8)
    e = ndimage.distance_transform_edt(~full)
    img[(e > 0) & (e <= 1.0)] = 9
    inner = ndimage.binary_erosion(full, iterations=2)
    img[full] = 7; img[inner] = 10
    for fs in range(14, 50):
        r = np.nonzero((mkguides.raster('H', fs, 1.0) > 128).any(axis=1))[0]
        if r.max() - r.min() + 1 >= 26: break
    x = 1 + 2 + 4                                 # the key's line, then 4 px of white
    for ch, w, gap in (('I', 3, 2), ('N', 15, 2), ('F', 12, 3), ('O', 15, 0)):
        a = mkguides.raster(ch, fs, 1.0)
        cols = np.nonzero((a > 128).any(axis=0))[0]; a = a[:, cols.min():cols.max() + 1]
        rows = np.nonzero((mkguides.raster('H', fs, 1.0) > 128).any(axis=1))[0]
        a = a[rows.min() - 1:rows.max() + 2]      # the O's overshoot, a row each way
        a = np.array(Image.fromarray(a.astype(np.uint8)).resize((w, a.shape[0]), Image.LANCZOS)).astype(int)
        y0 = 25 - a.shape[0] // 2
        reg = img[y0:y0 + a.shape[0], x:x + w]
        reg[a > 110] = 7
        reg[(a > 40) & (a <= 110) & (reg == 10)] = 11
        x += w + gap
    return img


def guide5(word):
    """the H&S row's own guides ("Sh/Hi [INFO]", "B/W [INFO]") drawn to the camera's "Mid [INFO]": the word a little
    heavier than mkguides' (the camera's stems are 4 px), then info_key 5 px after it"""
    a, fs, sq = mkguides.fit(word)
    a0 = mkguides.raster(word[0], fs, sq); base = np.nonzero((a0 > 128).any(axis=1))[0].max()
    a = np.maximum(a, np.pad(a, ((0, 0), (1, 0)))[:, :-1])   # every stem 1 px wider (3 -> 4, the camera's)
    fill = a > 128; soft = (a > 40) & ~fill
    h, w = fill.shape
    key = info_key()
    lay = np.zeros((50, 2 + w + 3 + key.shape[1]), dtype=np.uint8)
    shift = 40 - base
    for y in range(h):
        yy = y + shift
        if 0 <= yy < 50:
            lay[yy, 2:2 + w][fill[y]] = 10
            lay[yy, 2:2 + w][soft[y]] = 11
    g = mkguides.edge(lay == 10, lay == 11)
    g[:, 2 + w + 3:] = key
    assert g.shape[1] <= 160, g.shape
    return g


ORANGE = 34                   # colour menu (test 7): the cells' red-orange (the left column's 34, as the page's red dot)


def _disc(px, cx, cy, r, c):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if 0 <= y < px.shape[0] and 0 <= x < px.shape[1] and (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                px[y, x] = c


def _line(px, pts, c, wd):
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 3) + 1
        for i in range(n + 1):
            _disc(px, x0 + (x1 - x0) * i / n, y0 + (y1 - y0) * i / n, wd / 2, c)


def _bez(p0, p1, p2, p3, n=40):
    return [tuple(((1 - t) ** 3) * a + 3 * ((1 - t) ** 2) * t * b + 3 * (1 - t) * t * t * cc + t ** 3 * d
                  for a, b, cc, d in zip(p0, p1, p2, p3)) for t in (i / n for i in range(n + 1))]


def cell():
    """the RGB row's cell (colour menu, test 7): a small picture of its page, the curve box (white outline) with a
    red-orange curve bowed up, a green straight one and a blue one bowed down (the list shows x 9..90)"""
    px = np.zeros((76, 100), dtype=np.uint8)
    x0, y0, s = 24, 12, 52
    px[y0 - 2:y0 + s + 2, x0 - 2:x0 + s + 2] = 7
    px[y0:y0 + s, x0:x0 + s] = 10
    px[y0 + 3:y0 + s - 3, x0 + 3:x0 + s - 3] = 0
    a, b = (x0 + 2, y0 + s - 2), (x0 + s - 2, y0 + 2)
    _line(px, _bez(a, (x0 + 16, y0 + 29), (x0 + 29, y0 + 11), b), ORANGE, 2.6)
    _line(px, [a, b], GREEN, 2.6)
    _line(px, _bez(a, (x0 + 23, y0 + 41), (x0 + 36, y0 + 23), b), BLUE, 2.6)
    return px


def small_label(t, fill, cap=17, maxw=30):
    """colour mix test 2 (owner: "the words sat and hue get cut off"): the camera shows a header label in a 38 px box
    (a wider picture is cut there too, om-emu), so "Sat" / "Hue" are drawn smaller to fit it whole: ink inside 2..35"""
    a = letters([(t, fill)], 38, 30, cap, 26, maxw=maxw, sx=0.92)
    cols = np.nonzero(a.any(axis=0))[0]
    assert cols.min() >= 2 and cols.max() <= 35, (t, cols.min(), cols.max())
    return a


def name_label(t, fill, cap=20):
    """colour menu (test 7, spec section 4): the colour in its colour in the header's middle slot (the camera's "Mid"
    label place, a 50 px box), ink inside 2..47. v0.30 (owner: "lets make it just say R, G, B in the same colors but
    slightly bigger text"): the letter at cap 20 (the words "Red" / "Green" / "Blue" were cap 16, squeezed).
    Test 11 (owner: "center the r,g,b ... its off center"): the box (the layout record's, the same on the camera) sits
    at x 655..704 and the page's middle (the panel 542..845, the midpoint of the two values too) at 693.5 (om-emu), so
    the letter is centred at the box's column MID_CX, not its middle (it was 14 px left); ink inside the box's 50."""
    a = letters([(t, fill)], round(2 * MID_CX) + 1, 30, cap, 26, maxw=42)[:, :50]   # + 1: its centring floors
    cols = np.nonzero(a.any(axis=0))[0]
    assert cols.min() >= 2 and cols.max() <= 49, (t, cols.min(), cols.max())
    return a


def wide_label(t, fill, w):
    """five-point curve test 4 (owner: the selected "Sh" / "Hi" / "Mid" are larger; "have the black/white do the
    same"): "Blk" / "Wht" at the camera's own selected size (om-emu: its "Sh" and "Mid" are 24 px tall, rows 3..26 of
    the 30, 3 px stems), in a box of their own width (the header's objects are moved and resized by b5_lk)"""
    a = letters([(t, fill)], w, 30, 24, 27, maxw=w - 4)
    cols = np.nonzero(a.any(axis=0))[0]
    assert cols.min() >= 0 and cols.max() <= w - 1 and not a[29].any(), (t, cols.min(), cols.max())
    return a


FIVE = (('Blk', 2, 46), ('Sh', 6, 38), ('Mid', 1, 50), ('Hi', 6, 38), ('Wht', 2, 46))   # name, its label's x and box


def five_item(n, v, fill=WHITE):
    """five-point curve test 3 (owner: "I want it to look like" the first mock-up, five values in one line): a value
    the page is not on, its name and number in one 80 x 30 picture (one header slot; curve5.inc b5_lk shows it in a
    spare object of the header, which the camera greys). Laid out as the camera's own slot: the name's box, then a
    13 px sign and a 16 px digit."""
    name, lx, lw = FIVE[n]
    px = np.zeros((30, 80), dtype=np.uint8)
    px[:, lx:lx + lw] = letters([(name, fill)], lw, 30, 20, 26, maxw=lw - 6, sx=0.92)
    sign = '\u00b1' if v == 0 else '+' if v > 0 else '\u2212'
    px[:, lx + lw:lx + lw + 13] = letters([(sign, fill)], 13, 30, 15, 23, maxw=10)
    px[:, lx + lw + 13:lx + lw + 29] = letters([(str(abs(v)), fill)], 16, 30, 21, 26, maxw=13)
    return px


def five_items():
    """the 75 pictures of five_item, name by name, each -7..+7 (curve5.inc b5_cmp)"""
    return [(f'{FIVE[n][0]} {v:+d}', five_item(n, v)) for n in range(5) for v in range(-7, 8)]


def five_streams():
    return [(name, a.shape[1], a.shape[0], mkicons.encode11(bytes(a.flatten().tolist()), a.shape[1], a.shape[0]))
            for name, a in five_items()]


MID_CX = 38.5                 # test 11: the header's middle (x 693.5) less the middle label box's left edge (x 655)


def mixcell():
    """the Mix row's cell (colour menu, test 7): a small picture of its page, a thin grey ring with spokes to three
    dots, red-orange (top, larger), green (lower right), blue (lower left)"""
    import math
    px = np.zeros((76, 100), dtype=np.uint8)
    cx, cy, R = 50, 38, 19
    for y in range(76):
        for x in range(100):
            if abs(math.hypot(x + 0.5 - cx, y + 0.5 - cy) - R) <= 1.0:
                px[y, x] = 97
    for ang, c, r in ((-90, ORANGE, 6.0), (30, GREEN, 4.6), (150, BLUE, 4.6)):
        ex, ey = cx + R * math.cos(math.radians(ang)), cy + R * math.sin(math.radians(ang))
        _line(px, [(cx, cy), (ex, ey)], c, 2.0)
        _disc(px, ex, ey, r + 1.3, 7)
        _disc(px, ex, ey, r, c)
    return px


def pictures():
    """(name, palette index array) in the order of the firmware's cv_pic table. Colour menu (test 7, spec section 4):
    entries 7..12 are the header's white "Sat", "Hue", "Level" and the middle slot's "R", "G", "B" (v0.30).
    """
    return [('blank', np.zeros((2, 2), dtype=np.uint8)),
            ('R', label([('R', RED)])), ('G', label([('G', GREEN)])), ('B', label([('B', BLUE)])),
            ('Pt', label([('Pt', WHITE)])), ('guide', guide()), ('cell', cell())] + \
           [('Sat', small_label('Sat', WHITE)), ('Hue', small_label('Hue', WHITE)),
            ('Level', small_label('Level', WHITE, cap=14, maxw=30))] + \
           [(n + ' mid', name_label(n, c)) for n, c in (('R', RED), ('G', GREEN), ('B', BLUE))] + \
           [('Mix cell', mixcell())] + \
           [('clear 50 x 34', np.zeros((34, 50), dtype=np.uint8))] + \
           [('clear 14 x 30', np.zeros((30, 14), dtype=np.uint8))] + \
           [('Blk', wide_label('Blk', WHITE, 40)), ('Wht', wide_label('Wht', WHITE, 50)),
            ('guide Sh/Hi', guide5('Sh/Hi')), ('guide B/W', guide5('B/W'))]   # five-point curve (curve5.inc): 16..19


def streams():
    out = []
    for name, a in pictures():
        h, w = a.shape
        out.append((name, w, h, mkicons.encode11(bytes(a.flatten().tolist()), w, h)))   # no run past a row's end
    return out


MX_ANG = (-90, 30, 150)      # the Mix page: red at the top; clockwise yellow, green, cyan, blue, purple (screen y down)
MX_DEG = 5                    # degrees a hue step
MXR = 90                      # the ring's radius (editor's MXR); centre 150, 150


def mixtables():
    import math
    ux = [round(1024 * math.cos(math.radians(MX_ANG[j] + MX_DEG * h))) for j in range(3) for h in range(-7, 8)]
    uy = [round(1024 * math.sin(math.radians(MX_ANG[j] + MX_DEG * h))) for j in range(3) for h in range(-7, 8)]
    ro, ri = [], []
    for dy in range(MXR + 3):
        o = (MXR + 1.5) ** 2 - dy * dy
        ro.append(int(math.floor(math.sqrt(o))) if o > 0 else 0)
        i = (MXR - 1.5) ** 2 - dy * dy
        ri.append(max(1, int(math.ceil(math.sqrt(i)))) if i > 0 else 0)
    tk = []
    for j in range(3):
        c, sn = math.cos(math.radians(MX_ANG[j])), math.sin(math.radians(MX_ANG[j]))
        tk += [round(150 + (MXR - 9) * c), round(150 + (MXR - 9) * sn), round(150 + (MXR + 9) * c), round(150 + (MXR + 9) * sn)]
    assert max(ro) < 256 and len(ux) == 45
    return [' .balign 4', 'mx_ux:', ' .short ' + ', '.join(map(str, ux)), 'mx_uy:', ' .short ' + ', '.join(map(str, uy)),
            ' .balign 4', 'mx_tk:', ' .long ' + ', '.join(map(str, tk)),
            'mx_ro:', ' .byte ' + ', '.join(map(str, ro)), 'mx_ri:', ' .byte ' + ', '.join(map(str, ri)), ' .balign 4']


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('--preview')
    a = ap.parse_args()
    COL = {0: (40, 40, 40), 7: (0, 0, 0), 9: (30, 30, 30), 10: (254, 254, 254), 11: (170, 170, 170), 12: (85, 85, 85),
           RED: (255, 1, 1), GREEN: (0, 255, 0), BLUE: (40, 44, 205), 125: (0, 0, 254), 34: (253, 104, 0), 97: (147, 147, 147)}
    for name, w, h, s in streams():
        print(name, w, h, len(s))
    if a.preview:
        pics = pictures(); W = sum(p.shape[1] + 10 for _, p in pics); H = max(p.shape[0] for _, p in pics)
        im = Image.new('RGB', (W, H), (40, 40, 40)); x = 0
        for _, p in pics:
            rgb = np.array([[COL.get(int(v), (255, 0, 255)) for v in row] for row in p], dtype=np.uint8)
            im.paste(Image.fromarray(rgb), (x, 0)); x += p.shape[1] + 10
        im.resize((W * 3, H * 3), Image.NEAREST).save(a.preview)
