#!/usr/bin/env python3
"""The Split toning strip, test w1 (feature/split-tone-row): on the Split toning row's pages (Shadows / Highlights),
two small colour wheels and the Tone Balance slider in the guide picture's place under the camera's wheel, the same
400 x 64 place as the colour wheel's H / S / L bar (mkhbar.py). Owner (2026-11-23), mock-up C: "its exactly what i am
really envisioning"; this test only shows them (the keys are s1's: INFO Shadows <-> Highlights, the dials the page's
colour and strength; Tone Balance is still set on its own row).

Left to right: the Shadows wheel, its label and Highlights' over the Balance slider, "Balance" and its value under it,
the Highlights wheel. Each wheel: the 12 colours as a pie (yellow at 12 o'clock, clockwise, as the camera's wheel), a
dot at its tint (angle = colour, distance from the middle = strength 0..10). The page's wheel and label are white-ringed
/ white-boxed. Colours: palette 62's entries 108..119 hold the 12 hues while the strip is shown (stwheel.s writes them,
as hbar.s does its own; entry 120 white).

The firmware builds each row as: the background row (two variants: Shadows or Highlights the page), then the sprites
(the two dots, the caret, the value) over it (0 = see-through), then the row's tokens (greedy runs of up to 16), as
stream() here. The emulator test compares the two byte for byte.

usage: mkstwheel.py OUT.inc [--preview PNG]"""
import argparse, math
import numpy as np
from PIL import Image, ImageDraw
from mkguides import raster, edge
from mkhbar import hsv, HUE, BG, GHDR, W, H, row_tokens, pack, SHOW, PAL_TABLE, SLOT0, NSLOT

R = 26                                   # the wheels' radius (pixels)
CY = 32                                  # the wheels' middle (between rows 31 and 32)
CX = (33, W - 33)                        # Shadows', Highlights' middle
SX0, SX1 = 88, 312                       # the slider's outline columns
SY0, SY1 = 27, 36                        # its outline rows (its bands 28..35)
BANDS = (12, 64, 11, 10)                 # dark grey .. white (palette 62)
DOT = 11                                 # the dot sprite's size
DMAX = R - 7                             # strength 10's distance from the middle
VX, VY = 228, 44                         # the value sprite's place (after "Balance")
VW, VH = 28, 18
CW, CTOP = 11, 21                        # the caret sprite: 11 wide, rows 21..42 (above and below the slider)
CH = 22
WHITE = SLOT0 + 12                       # entry 120


def colours():
    return [hsv(h) for h in HUE] + [(254, 254, 254)]


def argb():
    return [0xff000000 | r << 16 | g << 8 | b for r, g, b in colours()]


def fs_for(cap):
    for fs in range(6, 60):
        r = np.nonzero((raster('H', fs, 1.0) > 128).any(axis=1))[0]
        if r.max() - r.min() + 1 >= cap: return fs
    raise SystemExit('no font size fits')


def word(txt, fs, cap):
    """txt's raster cropped to its cap rows + 2 above / 3 below, and its columns."""
    a = raster(txt, fs, 0.85)
    base = np.nonzero((raster('H', fs, 0.85) > 128).any(axis=1))[0].max()
    a = a[base - cap - 1:base + 4]
    cols = np.nonzero((a > 40).any(axis=0))[0]
    return a[:, cols.min():cols.max() + 1]


def put_text(out, a, x0, y0, boxed):
    """a's letters at (x0, y0): boxed, dark letters in a white rounded box; else white letters, the camera's outline."""
    hh, ww = a.shape
    if boxed:
        S = 4
        bx0, by0, bx1, by1 = x0 - 5, y0 - 2, x0 + ww + 5, y0 + hh + 1
        im = Image.new('L', (W * S, H * S), 0)
        ImageDraw.Draw(im).rounded_rectangle((bx0 * S, by0 * S, bx1 * S - 1, by1 * S - 1), radius=4 * S, fill=255)
        box = np.array(im.resize((W, H), Image.LANCZOS))
        out[box > 128] = 10; out[(box > 40) & (box <= 128)] = 11
        reg = out[y0:y0 + hh, x0:x0 + ww]
        reg[a > 128] = 7; reg[(a > 40) & (a <= 128) & (reg == 10)] = 12
    else:
        m = np.zeros(out.shape, dtype=bool); s = np.zeros(out.shape, dtype=bool)
        m[y0:y0 + hh, x0:x0 + ww] = a > 128; s[y0:y0 + hh, x0:x0 + ww] = (a > 40) & (a <= 128)
        e = edge(m, s & ~m)
        put = (e != 0) & (out == BG)
        out[put] = e[put]


def wheel(out, cx, active):
    yy, xx = np.mgrid[0:H, 0:W]
    dx, dy = xx + 0.5 - cx, yy + 0.5 - CY
    d = np.hypot(dx, dy)
    ang = (np.degrees(np.arctan2(dx, -dy)) + 15) % 360          # 0 at 12 o'clock, clockwise; slice 0 centred there
    sl = (ang // 30).astype(int)
    inside = d <= R
    out[inside] = (SLOT0 + sl)[inside]
    out[(d <= 2.5)] = 64                                         # the middle: no tint
    out[(d > R) & (d <= R + 1)] = 7
    if active:
        out[(d > R + 1) & (d <= R + 3)] = 10
        out[(d > R + 3) & (d <= R + 4)] = 7


def background(axis):
    """axis 5 (Shadows the page) or 6 (Highlights)."""
    out = np.full((H, W), BG, dtype=np.uint8)
    wheel(out, CX[0], axis == 5); wheel(out, CX[1], axis == 6)
    out[SY0, SX0:SX1 + 1] = 7; out[SY1, SX0:SX1 + 1] = 7
    out[SY0:SY1 + 1, SX0] = 7; out[SY0:SY1 + 1, SX1] = 7
    n = SX1 - SX0 - 1
    for i in range(n):
        out[SY0 + 1:SY1, SX0 + 1 + i] = BANDS[i * len(BANDS) // n]
    cap = 11; fs = fs_for(cap)
    sh, hl = word('Shadows', fs, cap), word('Highlights', fs, cap)
    put_text(out, sh, SX0 + 6, 2, axis == 5)
    put_text(out, hl, SX1 - 6 - hl.shape[1], 2, axis == 6)
    bal = word('Balance', fs, cap)
    put_text(out, bal, VX - 6 - bal.shape[1], VY + 1, False)
    return out


def dot():
    S = 4; c = DOT * S / 2
    im = Image.new('L', (DOT * S, DOT * S), 0); dr = ImageDraw.Draw(im)
    dr.ellipse((c - 5.2 * S, c - 5.2 * S, c + 5.2 * S, c + 5.2 * S), fill=128)
    dr.ellipse((c - 3.4 * S, c - 3.4 * S, c + 3.4 * S, c + 3.4 * S), fill=255)
    a = np.array(im.resize((DOT, DOT), Image.LANCZOS))
    out = np.zeros((DOT, DOT), dtype=np.uint8)
    out[a > 40] = 7; out[a > 170] = WHITE
    return out


def dot_xy(c, s):
    """colour c (0..11), strength s (0..10) -> the dot sprite's top-left, relative to the wheel's middle pixel."""
    a = math.radians(30 * c); r = DMAX * s / 10
    return round(r * math.sin(a)) - DOT // 2, round(-r * math.cos(a)) - DOT // 2


def caret():
    S = 4
    im = Image.new('L', (CW * S, CH * S), 0)
    ImageDraw.Draw(im).polygon([(0.5 * S, 0), ((CW - 0.5) * S, 0), (CW / 2 * S, 5.5 * S)], fill=255)
    tri = np.array(im.resize((CW, CH), Image.LANCZOS)) > 100
    tri[CH // 2:] = tri[:CH // 2][::-1]
    pad = np.zeros((CH + 4, CW + 4), dtype=bool); pad[2:-2, 2:-2] = tri
    e = edge(pad)[2:-2, 2:-2]
    out = np.where(e == 9, 0, e).astype(np.uint8)                # the faint rim: see-through
    out[6:CH - 6] = 0
    return out


def caret_x(b):
    """Tone Balance b (-5..5) -> the caret sprite's first column."""
    return SX0 + 1 + round((b + 5) * (SX1 - SX0 - 2) / 10) - CW // 2


def value(b, fs, cap):
    txt = ('+' if b > 0 else '−' if b < 0 else '±') + str(abs(b))
    a = word(txt, fs, cap)
    out = np.full((VH, VW), BG, dtype=np.uint8)
    m = np.zeros((VH, VW), dtype=bool); s = np.zeros((VH, VW), dtype=bool)
    hh, ww = a.shape
    assert ww <= VW - 4 and hh <= VH - 2, (txt, a.shape)
    m[1:1 + hh, 2:2 + ww] = a > 128; s[1:1 + hh, 2:2 + ww] = (a > 40) & (a <= 128)
    e = edge(m, s & ~m)
    out = np.where(e == 0, BG, e).astype(np.uint8)              # opaque: covers the last value
    return out


def pieces():
    cap = 11; fs = fs_for(cap)
    return dict(bg=[background(5), background(6)], dot=dot(), caret=caret(),
                val=[value(b, fs, cap) for b in range(-5, 6)])


def code_to_s(code):
    """the slot's stored strength code (signed byte) -> strength 0..10 (tn_set's code, undone)."""
    s = 2 * code if code >= 0 else -2 * code - 1
    return max(0, min(10, s))


def sprites(sc, ss, hc, hs, b, P):
    """[(sprite, x0, y0)] in the order the firmware lays them."""
    out = []
    for cx, c, s in ((CX[0], sc, ss), (CX[1], hc, hs)):
        x, y = dot_xy(c, s)
        out.append((P['dot'], cx + x, CY + y))
    out.append((P['caret'], caret_x(b), CTOP))
    out.append((P['val'][b + 5], VX, VY))
    return out


def render(sc, ss, hc, hs, b, axis, P=None):
    """the strip for Shadows colour sc strength ss, Highlights hc / hs (0..11 / 0..10), Tone Balance b (-5..5)."""
    P = P or pieces()
    out = P['bg'][axis - 5].copy()
    for sp, x0, y0 in sprites(sc, ss, hc, hs, b, P):
        h, w = sp.shape
        assert 0 <= x0 and x0 + w <= W and 0 <= y0 and y0 + h <= H
        reg = out[y0:y0 + h, x0:x0 + w]
        reg[sp != 0] = sp[sp != 0]
    return out


def stream(sc, ss, hc, hs, b, axis, P=None):
    pic = render(sc, ss, hc, hs, b, axis, P)
    toks = []
    for y in range(H): toks += row_tokens(pic[y])
    return pack(toks)


def inc(P=None):
    """stwheel.inc for stwheel.s (.ext15). st_rows: each distinct background row, u32 = first token << 8 | count;
    st_bg: per variant (axis 5, 6) its 64 rows (u16 indices); st_tok: the tokens (u16). Sprites: u16 w, h, then w x h
    bytes (0 = see-through). st_dxy: per colour c, strength s (c * 11 + s) the dot's x, y offset (signed bytes).
    st_cx: per Balance b + 5 the caret's column (u16). st_pal: entries 108..120 (ARGB)."""
    P = P or pieces()
    rows = {}; toks = []
    def rid(a):
        t = tuple(row_tokens(a))
        if t not in rows: rows[t] = len(rows); toks.append(t)
        return rows[t]
    bg = [rid(P['bg'][v][y]) for v in range(2) for y in range(H)]
    at = 0; rec = []
    for t in toks: rec.append(at << 8 | len(t)); at += len(t)
    hw = lambda xs: ''.join(' .short ' + ','.join(str(x) for x in xs[i:i + 16]) + '\n' for i in range(0, len(xs), 16))
    bw = lambda xs: ''.join(' .byte ' + ','.join(str(int(x)) for x in xs[i:i + 32]) + '\n' for i in range(0, len(xs), 32))
    spr = lambda name, a: f'.balign 2\n{name}:\n .short {a.shape[1]},{a.shape[0]}\n' + bw(a.flatten())
    dxy = []
    for c in range(12):
        for s in range(11): dxy += list(dot_xy(c, s))
    return (f'.set ST_HDR, {int.from_bytes(GHDR, "little"):#x}\n.set ST_CX0, {CX[0]}\n.set ST_CX1, {CX[1]}\n'
            f'.set ST_CY, {CY}\n.set ST_CTOP, {CTOP}\n.set ST_VX, {VX}\n.set ST_VY, {VY}\n.set ST_WHITE, {WHITE}\n'
            '.balign 4\nst_rows:\n' + ''.join(f' .long {r}\n' for r in rec) +
            '.balign 2\nst_bg:\n' + hw(bg) + 'st_cx:\n' + hw([caret_x(b) for b in range(-5, 6)]) +
            'st_tok:\n' + hw([x for t in toks for x in t]) +
            'st_dxy:\n' + bw([x & 255 for x in dxy]) +
            spr('st_dot', P['dot']) + spr('st_car', P['caret']) +
            '.balign 2\nst_val:\n' + ''.join(spr(f'st_v{b + 5}', P['val'][b + 5]) for b in range(-5, 6)) +
            '.balign 4\nst_vtab:\n' + ''.join(f' .long st_v{b + 5}\n' for b in range(-5, 6)) +
            '.balign 4\nst_pal:\n .long ' + ','.join(f'{x:#010x}' for x in argb()) + '\n')


def preview(pics, path, scale=3, ground=(96, 110, 120)):
    sheet = Image.new('RGB', (W * scale, (H + 6) * scale * len(pics)), (40, 40, 40))
    show = {**SHOW, BG: ground, 0: ground, 9: tuple(round(x * 0.47) for x in ground),
            **{SLOT0 + i: col for i, col in enumerate(colours())}}
    for k, b in enumerate(pics):
        rgb = Image.new('RGB', (W, H)); rgb.putdata([show.get(int(v), (255, 0, 255)) for v in b.flatten()])
        sheet.paste(rgb.resize((W * scale, H * scale), Image.NEAREST), (0, k * (H + 6) * scale))
    sheet.save(path)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--preview')
    a = ap.parse_args()
    P = pieces()
    open(a.out, 'w').write(inc(P))
    if a.preview:
        preview([render(*st, P=P) for st in ((6, 6, 1, 4, -2, 5), (8, 10, 0, 10, 3, 6), (0, 0, 0, 0, 0, 5),
                                              (3, 5, 9, 2, 5, 6))], a.preview)
