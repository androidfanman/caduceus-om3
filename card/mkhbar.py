#!/usr/bin/env python3
"""The colour wheel's H / S / L bar (experiment/wheel-hsl-view): the fields the firmware puts together under the wheel,
and the same picture made here (the emulator test compares the firmware's with it byte for byte).

The bar takes the guide picture's place (175 x 50, OSD type 11, the camera's guide palette: 0 clear, 7 dark edge,
9 faint rim, 10 white fill, 11 light edge, 12 grey). Three fields, H, S and L of the colour under the cursor, each
"H+2" in the camera's outlined white letters over a small slider (-5 .. +5, a white mark on a grey line with a centre
tick); the page's field has a white frame round it. Drawn from scratch with DejaVu (no camera graphics).

A field is its content (letter, value: text and slider, rows 6..43, cols 9..w-10) and, on the page's field, a frame
round it that never touches the content. Both are drawn and encoded here, each row part on its own (runs of up to 16
that stop at the part's edge, as the camera's own pictures stop at a row's end), each distinct row part kept once. The
firmware (hbar.s) only joins them: for each of the 50 rows, for H, S and L, the frame's left part, the content's, the
frame's right part, packed five 12-bit tokens to a 64-bit word, the last word padded with zero tokens. A click costs
the packing of about 2,000 tokens, no drawing.

usage: mkhbar.py OUT.inc [--preview PNG]"""
import argparse
import numpy as np
from PIL import Image, ImageDraw
from mkguides import raster, edge

W, H = 175, 50
CELLW = (58, 58, 59)                 # the fields' widths (H, S, L), left to right
CX = 29                              # a field's centre, from its left edge
CAP = 19                             # the letters' cap height (px)
BASE = 27                            # their baseline row
TRACK_Y, TRACK_X0, TRACK_X1 = 37, 13, 45  # the slider line: rows 37..38 (its tick 35..40), cols 13..45 of the field
STEP = 3                             # the mark moves 3 px a step: -5 .. +5 -> cols 14 .. 44
MARK_W, MARK_H, MARK_Y = 3, 7, 34    # the mark's white fill: 3 x 7 from row 34
CHARS = 'HSL+−±012345'     # glyph order: letters, signs (+, minus, plus-minus), digits
RANK = {0: 0, 9: 1, 12: 2, 11: 3, 7: 4, 10: 5}   # a piece's pixel goes in only where it outranks the one there
FIELD_OF_AXIS = {2: 0, 0: 1, 1: 2}   # the editor's page (P+AXIS: 2 Hue, 0 Saturation, 1 Luminance) -> its field
GHDR = bytes([(H - 1) & 255, ((H - 1) >> 8 & 3) | (((W - 1) & 15) << 4), ((W - 1) >> 4) & 63, 11])


def _fit():
    for fs in range(10, 60):
        r = np.nonzero((raster('H', fs, 1.0) > 128).any(axis=1))[0]
        if r.max() - r.min() + 1 >= CAP: return fs
    raise SystemExit('no font size fits')


def glyphs():
    """-> [(piece, advance, left)], top row: piece = uint8 array in the guide palette with a 3 px margin, advance = the
    fill's width + 1, left = the margin (the piece goes at x - left)."""
    fs = _fit()
    rs = [raster(c, fs, 0.8) for c in CHARS]
    base = np.nonzero((rs[0] > 128).any(axis=1))[0].max()          # 'H': its last row is the baseline
    top = min(np.nonzero((r > 40).any(axis=1))[0].min() for r in rs)
    out = []
    for r in rs:
        a = r[top:base + 1]
        cols = np.nonzero((a > 40).any(axis=0))[0]; a = a[:, cols.min():cols.max() + 1]
        fill = np.pad(a > 128, 3); soft = np.pad((a > 40) & (a <= 128), 3)
        out.append((edge(fill, soft & ~fill), a.shape[1] + 1, 3))
    return out, BASE - (base - top) - 3


def frame(w):
    """The page's field: a rounded white line round it, the camera's outline style; transparent inside."""
    S = 4
    im = Image.new('L', (w * S, H * S), 0); d = ImageDraw.Draw(im)
    d.rounded_rectangle((3 * S, 1 * S, (w - 3) * S - 1, (H - 1) * S - 1), radius=6 * S, outline=255, width=2 * S)
    return edge(np.array(im.resize((w, H), Image.LANCZOS)) > 110)


def track():
    """The slider line with a centre tick, grey with a dark edge (3 px margin)."""
    m = np.zeros((10, TRACK_X1 - TRACK_X0 + 1), dtype=bool); m[4:6, :] = True; m[2:8, CX - TRACK_X0] = True
    p = edge(np.pad(m, 3)); p[p == 10] = 12
    return p


def mark():
    return edge(np.pad(np.ones((MARK_H, MARK_W), dtype=bool), 3))


def pieces():
    g, gy = glyphs()
    return dict(glyphs=g, gy=gy, frames=[frame(w) for w in sorted(set(CELLW))], track=track(), mark=mark())


def _blit(buf, p, x, y):
    h, w = p.shape
    assert 0 <= x and x + w <= buf.shape[1] and 0 <= y and y + h <= buf.shape[0], (x, y, w, h)
    reg = buf[y:y + h, x:x + w]
    rk = np.vectorize(RANK.get)
    put = (p != 0) & (rk(p) > rk(reg))
    reg[put] = p[put]


def cell(f, v, active, P):
    """Field f (0 H, 1 S, 2 L) with value v (-5..5), framed when active -> uint8 array 50 x CELLW[f]."""
    w = CELLW[f]
    buf = np.zeros((H, w), dtype=np.uint8)
    if active:
        _blit(buf, P['frames'][sorted(set(CELLW)).index(w)], 0, 0)
    _blit(buf, P['track'], TRACK_X0 - 3, TRACK_Y - 4 - 3)
    _blit(buf, P['mark'], CX + STEP * v - MARK_W // 2 - 3, MARK_Y - 3)
    idx = [f, 3 if v > 0 else 4 if v < 0 else 5, 6 + abs(v)]
    tw = sum(P['glyphs'][i][1] for i in idx) - 1
    x = CX - tw // 2
    for i in idx:
        p, adv, left = P['glyphs'][i]
        _blit(buf, p, x - left, P['gy'])
        x += adv
    return buf


def render(h, s, l, axis, P=None):
    """The bar for values h, s, l (-5 .. +5) on page axis (FIELD_OF_AXIS) -> uint8 array H x W."""
    P = P or pieces()
    return np.hstack([cell(f, v, FIELD_OF_AXIS.get(axis) == f, P) for f, v in enumerate((h, s, l))])


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


TOP, BOT, SIDE = 6, 44, 9        # a field's content (text, slider) stays in rows 6..43, cols 9..w-10; the frame outside


def segments(f, v, active, P):
    """A field's 50 rows as 3 token lists each: rows 0..5 and 44..49 the frame part whole (then two empty lists);
    rows 6..43 the frame's left strip, the content, the frame's right strip. Runs stop at each part's edge."""
    w = CELLW[f]
    c = cell(f, v, active, P)
    fr = cell(f, v, active, P) * 0
    if active:
        _blit(fr, P['frames'][sorted(set(CELLW)).index(w)], 0, 0)
    con = cell(f, v, 0, P)
    inner = np.zeros(c.shape, dtype=bool); inner[TOP:BOT, SIDE:w - SIDE] = True
    assert not (con[~inner]).any() and not (fr[inner]).any() and (np.where(inner, con, fr) == c).all(), (f, v, active)
    return [([row_tokens(c[y]), [], []] if y < TOP or y >= BOT else
             [row_tokens(c[y, :SIDE]), row_tokens(c[y, SIDE:w - SIDE]), row_tokens(c[y, w - SIDE:])]) for y in range(H)]


def stream(h, s, l, axis, P=None):
    """The firmware's picture: row by row, field by field (H, S, L), its three parts' tokens."""
    P = P or pieces()
    sg = [segments(f, v, FIELD_OF_AXIS.get(axis) == f, P) for f, v in enumerate((h, s, l))]
    return pack([t for y in range(H) for f in range(3) for part in sg[f][y] for t in part])


def inc(P=None):
    """hbar.inc for hbar.s (.ext15). hb_rows: each distinct row part, u32 = its first token's index << 8 | its token
    count (row 0 = the empty part); hb_tok: the tokens (u16). hb_tc: 33 contents (f * 11 + v + 5), hb_ta / hb_tb: the
    frame's left / right parts by (framed * 2 + (field L)), each 50 u16 row indices (rows 0..5, 44..49 of a content:
    the empty part; there hb_ta holds the whole row and hb_tb the empty part). HB_WORST: the longest stream."""
    P = P or pieces()
    rows = {(): 0}; toks = []
    def rid(t):
        t = tuple(t)
        if t not in rows: rows[t] = len(rows); toks.append(t)
        return rows[t]
    tc = [[0] * H for _ in range(33)]; ta = [[0] * H for _ in range(4)]; tb = [[0] * H for _ in range(4)]
    for f in range(3):
        for active in (0, 1):
            for v in range(-5, 6):
                sg = segments(f, v, active, P)
                for y in range(H):
                    a, c, b = (rid(x) for x in sg[y])
                    ka = active * 2 + (f == 2)
                    ta[ka][y] = a; tb[ka][y] = b; tc[f * 11 + v + 5][y] = c
    for f in range(3):                  # every field reads its parts from the tables: check them against segments()
        for active in (0, 1):
            for v in range(-5, 6):
                sg = segments(f, v, active, P); ka = active * 2 + (f == 2)
                inv = {i: t for t, i in rows.items()}
                assert all([list(inv[ta[ka][y]]), list(inv[tc[f * 11 + v + 5][y]]), list(inv[tb[ka][y]])] == sg[y]
                           for y in range(H)), (f, v, active)
    best = max(sum(max(sum(len(x) for r in segments(f, v, act == f, P) for x in r) for v in range(-5, 6))
                   for f in range(3)) for act in range(3))
    at = 0; rec = [0]
    for t in toks:
        rec.append(at << 8 | len(t)); at += len(t)
    assert max(len(t) for t in toks) < 256 and at < 1 << 24
    hw = lambda xs: ''.join(' .short ' + ','.join(str(x) for x in xs[i:i + 16]) + '\n' for i in range(0, len(xs), 16))
    return (f'.set HB_WORST, {len(pack([0] * best))}\n.set HB_NTOK, {at}\n.balign 4\nhb_rows:\n' +
            ''.join(f' .long {r}\n' for r in rec) + '.balign 2\nhb_tc:\n' + hw([x for r in tc for x in r]) +
            'hb_ta:\n' + hw([x for r in ta for x in r]) + 'hb_tb:\n' + hw([x for r in tb for x in r]) +
            'hb_tok:\n' + hw([x for t in toks for x in t]) + '.balign 4\n')


PAL = {0: (30, 30, 60), 7: (20, 20, 20), 9: (60, 60, 60), 10: (255, 255, 255), 11: (200, 200, 200), 12: (160, 160, 160)}


def preview(bufs, path, scale=3):
    sheet = Image.new('RGB', (W * scale, H * scale * len(bufs)))
    for k, b in enumerate(bufs):
        rgb = Image.new('RGB', (W, H)); rgb.putdata([PAL.get(int(v), (255, 0, 255)) for v in b.flatten()])
        sheet.paste(rgb.resize((W * scale, H * scale), Image.NEAREST), (0, k * H * scale))
    sheet.save(path)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--preview')
    a = ap.parse_args()
    P = pieces()
    open(a.out, 'w').write(inc(P))
    if a.preview:
        preview([render(2, 0, -1, 2, P), render(-5, 5, 0, 0, P), render(0, -3, 4, 1, P)], a.preview)
