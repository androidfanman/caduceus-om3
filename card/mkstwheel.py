#!/usr/bin/env python3
"""The Split toning panel, test w4 (feature/split-tone-row): mock-up C on the Split toning row's pages.

Owner (2026-11-23, w3 on the camera, the camera's wheel gone): "When I adjust the value on the wheel the dot from the
wheel should move with the value, not still stay in that center position"; "It's still hard to read and see based on
how small it is ... a better layout would the the wheels being on the left side of the screen and stacked. So
highlight wheel on top. Shadow wheel below it. Balance below that (the balance bar horizontal instead of vertical."

w4: a tall panel at the left of the screen (stwheel.s moves the guide picture's widget there while the panel shows):
the Highlights wheel on top, the Shadows wheel under it, the Balance bar (dark to light, left to right) under that;
each with its name, the page's white-ringed / white-boxed. Each wheel: the 12 colours as a pie (yellow at 12 o'clock,
clockwise, as the camera's wheel), each colour a small point on a ring round the middle; the tint's colour has a big
dot that moves out with its strength and its point is gone from the ring (the point "moves"); a white ring marks the
colour the front dial is on.

Size: one picture of the camera's type 11 (runs of up to 16 pixels) in the bar's heap blocks: under 16 KB (checked
here). The background is stored as row parts (SEG; per page, de-duplicated); the firmware joins a row's parts, lays the
sprites over it (0 = see-through) and encodes it, as stream().

usage: mkstwheel.py OUT.inc [--preview PNG]"""
import argparse, math
import numpy as np
from PIL import Image, ImageDraw
from mkguides import raster
from mkhbar import hsv, HUE, SHOW, SLOT0, row_tokens

R = 84                                   # the wheels' radius
W = 2 * R + 20                           # (188)
NH = 24                                  # a name's rows
CX = (W // 2, W // 2)                    # Shadows', Highlights' middle column
CY = (2 * R + 14 + NH + R + 8, R + 8)    # their middle row lines: Highlights on top, Shadows under it
LY = (CY[0] + R + 8, CY[1] + R + 8)      # their names' letters (top)
SX0, SX1 = 8, W - 9                      # the Balance bar's outline columns
SY0 = LY[0] + NH + 16                    # its outline rows
SY1 = SY0 + 13
BY = SY1 + 12                            # "Balance" and the value
H = BY + NH + 2
SEG = (0, 64, 128, W)                    # each row's three parts
GROUND = 72                              # the bar's ground: palette 0x11282828, almost clear (live view through it)
BANDS = (12, 64, 11, 10)                 # left to right: dark grey .. white
DOT = 17
DMAX = R - 12
R0 = 22                                  # the ring of points (strength 0)
PT = 7                                   # a point's patch (the eraser sprite)
CUR = 23                                 # the cursor ring sprite
CW, CH = 13, 38                          # the caret sprite: a caret over and one under the bar
CTOP = SY0 - 12
VW, VH = 34, 24                          # the value sprite, after "Balance" (VX below)
WHITE = SLOT0 + 12
CAP = 15
PLACE = (116, 578)                       # the panel's left column and bottom row on the rear screen (viewfinder: 41 left)
MODES = ('Shadows', 'Highlights', 'Balance')
ST_BUF = 16448                           # hbar.s HB_BUF: the two heap buffers the bar and the panel share
MAXSTREAM = ST_BUF - 16


def colours():
    return [hsv(h) for h in HUE] + [(254, 254, 254)]


def argb():
    return [0xff000000 | r << 16 | g << 8 | b for r, g, b in colours()]


def fs_for(cap):
    for fs in range(6, 80):
        r = np.nonzero((raster('H', fs, 1.0) > 128).any(axis=1))[0]
        if r.max() - r.min() + 1 >= cap: return fs
    raise SystemExit('no font size fits')


_FS = []


def word(txt):
    if not _FS: _FS.append(fs_for(CAP))
    fs = _FS[0]
    a = raster(txt, fs, 0.85)
    base = np.nonzero((raster('H', fs, 0.85) > 128).any(axis=1))[0].max()
    a = a[base - CAP - 2:base + 5]
    cols = np.nonzero((a > 40).any(axis=0))[0]
    return a[:, cols.min():cols.max() + 1]


def put_text(out, a, x0, y0, boxed):
    hh, ww = a.shape
    if boxed:
        S = 4
        bx0, by0, bx1, by1 = x0 - 6, y0 - 2, x0 + ww + 6, y0 + hh + 1
        h_, w_ = out.shape
        im = Image.new('L', (w_ * S, h_ * S), 0)
        ImageDraw.Draw(im).rounded_rectangle((bx0 * S, by0 * S, bx1 * S - 1, by1 * S - 1), radius=5 * S, fill=255)
        box = np.array(im.resize((w_, h_), Image.LANCZOS))
        out[box > 128] = 10; out[(box > 40) & (box <= 128)] = 11
        reg = out[y0:y0 + hh, x0:x0 + ww]
        reg[a > 128] = 7; reg[(a > 40) & (a <= 128) & (reg == 10)] = 12
    else:
        reg = out[y0:y0 + hh, x0:x0 + ww]
        reg[a > 150] = 10; reg[(a > 60) & (a <= 150)] = 11


def point_xy(c):
    """colour c's point: its middle pixel, relative to the wheel's middle."""
    a = math.radians(30 * c)
    return round(R0 * math.sin(a)), round(-R0 * math.cos(a))


def wheel(out, cx, cy, active, points=True):
    hh, ww = out.shape
    yy, xx = np.mgrid[0:hh, 0:ww]
    dx, dy = xx + 0.5 - cx, yy + 0.5 - cy
    d = np.hypot(dx, dy)
    ang = (np.degrees(np.arctan2(dx, -dy)) + 15) % 360
    sl = (ang // 30).astype(int)
    out[d <= R] = (SLOT0 + sl)[d <= R]
    out[d <= 3.5] = 64
    if points:
        for c in range(12):
            px, py = point_xy(c)
            dd = np.hypot(xx - (cx + px), yy - (cy + py))
            out[dd <= 3.2] = 7; out[dd <= 2.0] = 10
    out[(d > R) & (d <= R + 1.5)] = 12
    if active:
        out[(d > R + 2.5) & (d <= R + 5.5)] = 10


def erasers():
    """per colour, the PT x PT patch of the wheel without its points at that colour's point (laid over the point when
    the colour's dot is out)."""
    side = 2 * R + 20
    w = np.full((side, side), GROUND, dtype=np.uint8)
    wheel(w, side // 2, side // 2, False, points=False)
    out = []
    for c in range(12):
        px, py = point_xy(c)
        x0, y0 = side // 2 + px - PT // 2, side // 2 + py - PT // 2
        out.append(w[y0:y0 + PT, x0:x0 + PT].copy())
    return out


def background(mode):
    out = np.full((H, W), GROUND, dtype=np.uint8)
    for i, name in enumerate(MODES[:2]):
        wheel(out, CX[i], CY[i], mode == i)
        a = word(name)
        put_text(out, a, CX[i] - a.shape[1] // 2, LY[i], mode == i)
    out[SY0, SX0:SX1 + 1] = 7; out[SY1, SX0:SX1 + 1] = 7
    out[SY0:SY1 + 1, SX0] = 7; out[SY0:SY1 + 1, SX1] = 7
    n = SX1 - SX0 - 1
    for i in range(n):
        out[SY0 + 1:SY1, SX0 + 1 + i] = BANDS[i * len(BANDS) // n]
    if mode == 2:                                   # the bar white-framed
        out[SY0 - 4:SY0 - 2, SX0 - 4:SX1 + 5] = 10; out[SY1 + 3:SY1 + 5, SX0 - 4:SX1 + 5] = 10
        out[SY0 - 4:SY1 + 5, SX0 - 4:SX0 - 2] = 10; out[SY0 - 4:SY1 + 5, SX1 + 3:SX1 + 5] = 10
    a = word('Balance')
    put_text(out, a, LX, BY, mode == 2)
    return out


LX = 0; VX = 0  # set in pieces(): "Balance" and the value, centred together


def dot():
    S = 4; c = DOT * S / 2
    im = Image.new('L', (DOT * S, DOT * S), 0); dr = ImageDraw.Draw(im)
    dr.ellipse((c - 7.2 * S, c - 7.2 * S, c + 7.2 * S, c + 7.2 * S), fill=128)
    dr.ellipse((c - 5.0 * S, c - 5.0 * S, c + 5.0 * S, c + 5.0 * S), fill=255)
    a = np.array(im.resize((DOT, DOT), Image.LANCZOS))
    out = np.zeros((DOT, DOT), dtype=np.uint8)
    out[a > 40] = 7; out[a > 170] = WHITE
    return out


def dot_xy(c, s):
    """colour c (0..11), strength s (0..10) -> the dot sprite's top-left, relative to the wheel's middle pixel: on the
    ring of points at 0, out to DMAX at 10."""
    a = math.radians(30 * c); r = R0 + (DMAX - R0) * s / 10
    return round(r * math.sin(a)) - DOT // 2, round(-r * math.cos(a)) - DOT // 2


def cursor():
    """CUR x CUR: a white ring, dark-edged, see-through inside (round a point or the dot)."""
    S = 4; c = CUR * S / 2
    yy, xx = np.mgrid[0:CUR * S, 0:CUR * S]
    d = np.hypot(xx + 0.5 - c, yy + 0.5 - c) / S
    big = np.zeros((CUR * S, CUR * S), dtype=np.uint8)
    big[(d > 6.6) & (d <= 10.4)] = 1; big[(d > 7.6) & (d <= 9.6)] = 2
    out = np.zeros((CUR, CUR), dtype=np.uint8)
    for v, idx in ((1, 7), (2, 10)):
        m = (big >= v).reshape(CUR, S, CUR, S).mean(axis=(1, 3)) > 0.5
        out[m] = idx
    return out


def caret():
    S = 4
    im = Image.new('L', (CW * S, CH * S), 0)
    ImageDraw.Draw(im).polygon([(0.5 * S, 0), ((CW - 0.5) * S, 0), (CW / 2 * S, 6.5 * S)], fill=255)
    tri = np.array(im.resize((CW, CH), Image.LANCZOS)) > 100
    tri[CH // 2:] = tri[:CH // 2][::-1]
    out = np.zeros((CH, CW), dtype=np.uint8)
    out[tri] = 10
    return out


def caret_x(b):
    """Tone Balance b (-5..5) -> the caret sprite's first column."""
    return SX0 + 1 + round((b + 5) * (SX1 - SX0 - 2) / 10) - CW // 2


def value(b):
    txt = ('+' if b > 0 else '−' if b < 0 else '±') + str(abs(b))
    a = word(txt)
    out = np.full((VH, VW), GROUND, dtype=np.uint8)
    hh, ww = a.shape
    assert ww <= VW - 2 and hh <= VH, (txt, a.shape)
    put_text(out, a, 1, 0, False)
    return out


def pieces():
    global LX, VX
    bw_ = word('Balance').shape[1]
    LX = (W - (bw_ + 8 + VW)) // 2
    VX = LX + bw_ + 8
    return dict(bg=[background(m) for m in range(3)], dot=dot(), caret=caret(), cursor=cursor(), erase=erasers(),
                val=[value(b) for b in range(-5, 6)])


def code_to_s(code):
    s = 2 * code if code >= 0 else -2 * code - 1
    return max(0, min(10, s))


def sprites(sc, ss, hc, hs, b, mode, cur, P):
    """[(sprite, x0, y0)] in the firmware's order: the two erasers, the two dots, the caret, the value, the cursor."""
    out = []
    tint = ((sc, ss), (hc, hs))
    for i, (c, s) in enumerate(tint):
        if s:                                       # the tint's point leaves the ring
            px, py = point_xy(c)
            out.append((P['erase'][c], CX[i] + px - PT // 2, CY[i] + py - PT // 2))
    for i, (c, s) in enumerate(tint):
        if s:                                       # ... as its dot (none at strength 0)
            x, y = dot_xy(c, s)
            out.append((P['dot'], CX[i] + x, CY[i] + y))
    out.append((P['caret'], caret_x(b), CTOP))
    out.append((P['val'][b + 5], VX, BY))
    if mode < 2:                                    # the cursor on the page's wheel
        c, s = tint[mode]
        x, y = dot_xy(cur, s if cur == c else 0)
        d = (DOT - CUR) // 2
        out.append((P['cursor'], CX[mode] + x + d, CY[mode] + y + d))
    return out


def render(sc, ss, hc, hs, b, mode, cur=0, P=None):
    """Shadows colour sc / strength ss, Highlights hc / hs (0..11 / 0..10), Tone Balance b (-5..5), the page mode
    (0 Shadows, 1 Highlights, 2 Balance), the cursor's colour cur (0..11)."""
    P = P or pieces()
    out = P['bg'][mode].copy()
    for sp, x0, y0 in sprites(sc, ss, hc, hs, b, mode, cur, P):
        h, w = sp.shape
        assert 0 <= x0 and x0 + w <= W and 0 <= y0 and y0 + h <= H
        reg = out[y0:y0 + h, x0:x0 + w]
        reg[sp != 0] = sp[sp != 0]
    return out


def header(w, h):
    return bytes([(h - 1) & 255, ((h - 1) >> 8 & 3) | (((w - 1) & 15) << 4), ((w - 1) >> 4) & 63, 11])


def pack(toks):
    out = bytearray(header(W, H))
    for k in range(0, len(toks), 5):
        word_ = 0
        for s_, t in enumerate(toks[k:k + 5]): word_ |= t << (12 * s_)
        out += word_.to_bytes(8, 'little')
    return bytes(out)


def stream(sc, ss, hc, hs, b, mode, cur=0, P=None):
    pic = render(sc, ss, hc, hs, b, mode, cur, P)
    toks = []
    for y in range(H): toks += row_tokens(pic[y])
    return pack(toks)


def worst(P, n=400, seed=1):
    import random
    random.seed(seed); mx = 0
    for _ in range(n):
        st = (random.randrange(12), random.randrange(11), random.randrange(12), random.randrange(11),
              random.randrange(-5, 6), random.randrange(3), random.randrange(12))
        mx = max(mx, len(stream(*st, P=P)))
    return mx


def inc(P=None):
    """stwheel.inc for stwheel.s (.ext15). st_rows: each distinct row part, u32 = first token << 8 | count; st_bg: per
    part, mode and row (part * 3 H + mode * H + y) its row part (u16 indices); st_tok: the tokens (u16). Sprites: u16 w, h, then w x h
    bytes (0 = see-through). st_dxy: per colour c, strength s (c * 11 + s) the dot's x, y offset (signed bytes).
    st_cx: per Balance b + 5 the caret's column (u16). st_etab: per colour its eraser sprite; st_exy: per colour the
    eraser's x, y offset from the wheel's middle (signed bytes). st_pal: entries 108..120 (ARGB)."""
    P = P or pieces()
    rows = {}; toks = []
    def rid(a):
        t = tuple(row_tokens(a))
        if t not in rows: rows[t] = len(rows); toks.append(t)
        return rows[t]
    bg = [rid(P['bg'][m][y][SEG[k]:SEG[k + 1]]) for k in range(3) for m in range(3) for y in range(H)]
    at = 0; rec = []
    for t in toks: rec.append(at << 8 | len(t)); at += len(t)
    assert max(len(t) for t in toks) < 256 and at < 1 << 24
    hw = lambda xs: ''.join(' .short ' + ','.join(str(x) for x in xs[i:i + 16]) + '\n' for i in range(0, len(xs), 16))
    bw = lambda xs: ''.join(' .byte ' + ','.join(str(int(x)) for x in xs[i:i + 32]) + '\n' for i in range(0, len(xs), 32))
    spr = lambda name, a: f'.balign 2\n{name}:\n .short {a.shape[1]},{a.shape[0]}\n' + bw(a.flatten())
    dxy = []
    for c in range(12):
        for s in range(11): dxy += list(dot_xy(c, s))
    exy = []
    for c in range(12):
        px, py = point_xy(c); exy += [px - PT // 2, py - PT // 2]
    return (f'.set ST_W, {W}\n.set ST_H, {H}\n.set ST_HDR, {int.from_bytes(header(W, H), "little"):#x}\n'
            f'.set ST_CX0, {CX[0]}\n.set ST_CX1, {CX[1]}\n.set ST_CY0, {CY[0]}\n.set ST_CY1, {CY[1]}\n'
            f'.set ST_CTOP, {CTOP}\n.set ST_VX, {VX}\n.set ST_VY, {BY}\n.set ST_CURD, {(DOT - CUR) // 2}\n'
            f'.set ST_PX, {PLACE[0]}\n.set ST_PY, {PLACE[1] - H}\n'
            '.balign 4\nst_rows:\n' + ''.join(f' .long {r}\n' for r in rec) +
            '.balign 2\nst_bg:\n' + hw(bg) + 'st_cx:\n' + hw([caret_x(b) for b in range(-5, 6)]) +
            'st_tok:\n' + hw([x for t in toks for x in t]) +
            'st_dxy:\n' + bw([x & 255 for x in dxy]) + 'st_exy:\n' + bw([x & 255 for x in exy]) +
            spr('st_dot', P['dot']) + spr('st_car', P['caret']) + spr('st_cur', P['cursor']) +
            ''.join(spr(f'st_e{c}', P['erase'][c]) for c in range(12)) +
            '.balign 2\nst_none:\n .short 1,0\n' +
            ''.join(spr(f'st_v{b + 5}', P['val'][b + 5]) for b in range(-5, 6)) +
            '.balign 4\nst_vtab:\n' + ''.join(f' .long st_v{b + 5}\n' for b in range(-5, 6)) +
            'st_etab:\n' + ''.join(f' .long st_e{c}\n' for c in range(12)) +
            '.balign 4\nst_pal:\n .long ' + ','.join(f'{x:#010x}' for x in argb()) + '\n')


def preview(pics, path, scale=2):
    show = {**SHOW, 0: (96, 110, 120), GROUND: (96, 110, 120), **{SLOT0 + i: col for i, col in enumerate(colours())}}
    sheet = Image.new('RGB', ((W + 8) * scale * len(pics), H * scale), (40, 40, 40))
    for k, b in enumerate(pics):
        rgb = Image.new('RGB', (W, H)); rgb.putdata([show.get(int(v), (255, 0, 255)) for v in b.flatten()])
        sheet.paste(rgb.resize((W * scale, H * scale), Image.NEAREST), (k * (W + 8) * scale, 0))
    sheet.save(path)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--preview')
    a = ap.parse_args()
    P = pieces()
    mx = worst(P)
    assert mx <= MAXSTREAM, mx
    open(a.out, 'w').write(inc(P))
    print('worst stream', mx)
    if a.preview:
        preview([render(*st, P=P) for st in ((6, 6, 1, 4, -2, 0, 6), (8, 10, 0, 0, 3, 1, 3), (3, 5, 9, 2, 5, 2, 0))], a.preview)
