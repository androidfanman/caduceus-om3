#!/usr/bin/env python3
"""v0.27 polish: the Button Function body diagrams for the rows Caduceus adds or moves (owner, 2026-11-10: the lines
and highlights must point at the right control).

The camera's diagrams (422 x 446, ids 0x3f7b..0x3f83, one per stock row) have the highlight and the leader line drawn
in; the line ends at the right edge at the row's place on its page (7 rows a page: rows 29 + 64 * pos .. +3). They are
not in the firmware file as stored (the camera unpacks them at start-up), so the camera composes ours at run time
(editor.s `dg_get`) from its own pictures, by the programs below: a base picture, up to two other stock pictures to copy
rectangles from (same place), solid fills, and stamps (our own drawing: line corners, the Creative Dial highlight).
Only numbers live here; no camera graphics. `compose()` is the same composition in Python, to check the camera's result.

Stock diagrams (index = id - 0x3f7b): 0 Fn, 1 REC, 2 |o|, 3 CP, 4 AF-ON (2..4 differ by view: 0..2 top, 3..7 back),
5 arrow pad, 6 right, 7 down, 8 L-Fn (side view). Measured in om-emu (research/NOTES.md, "polish 2").
"""
import struct
import numpy as np

W, H, BG, LINE, HI = 422, 446, 33, 63, 80
STOCK = 0x3f7b
DG0 = 0x7fd0                       # our diagram ids DG0 + k (ar_ic -> dg_get)
R = 18                             # corner: outer radius (stock ~17-18)
XR = 421                           # lines end at x 420 (column 421 stays clear, as stock)


def slot(pos):
    return 29 + 64 * pos


# --- stamps (our drawing): 0 = transparent ---------------------------------------------------------------------------
def corner_up():
    """line from below turning right; stamp origin = (x0 - 2, row - 2); arc centre (x0 + R, row + R)."""
    n = R + 4
    st = np.zeros((n, n), np.uint8)
    for y in range(n):
        for x in range(n):
            px, py = x - 2 + 0.5, y - 2 + 0.5
            if px > R or py > R:
                continue
            d = np.hypot(px - R, py - R)
            if R - 4 <= d < R:
                st[y, x] = LINE
            elif R - 6 <= d < R + 2:
                st[y, x] = BG
    return st


def corner_down():
    """line from above turning right; stamp origin = (x0 - 2, row + 4 - R - 2); arc centre (x0 + R, row + 4 - R)."""
    return corner_up()[::-1].copy()


def dial_hi():
    """the Creative Dial's highlight (top view, the knurled block at x 276..315, y 270..284): a filled box with
    rounded corners in the camera's highlight colour."""
    w, h, r = 42, 17, 4
    st = np.zeros((h, w), np.uint8)
    for y in range(h):
        for x in range(w):
            cx = min(max(x + 0.5, r), w - r); cy = min(max(y + 0.5, r), h - r)
            if np.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r:
                st[y, x] = HI
    return st


# --- programs ---------------------------------------------------------------------------------------------------------
# op: ('ovl', src, x0, x1, y0, y1) | ('fill', val, x0, x1, y0, y1) | ('stamp', name, x, y) | ('bridge', x0, x1, y0, y1)
#     bridge: on each row where the pixels left of x0 and at x1 are both drawn, fill [x0, x1) with the left one
def vline(x0, ya, yb):
    """a vertical line, columns x0..x0+3, rows ya..yb-1, with a 2 px clear margin on both sides"""
    return [('fill', BG, x0 - 2, x0 + 6, ya, yb), ('fill', LINE, x0, x0 + 4, ya, yb)]


def hline(row, xa):
    return [('fill', BG, xa, XR, row - 2, row + 6), ('fill', LINE, xa, XR, row, row + 4)]


def leader(cx, ytop, ybot, pos):
    """from a control at column cx (spanning rows ytop..ybot) to the row's slot: vertical, corner, horizontal"""
    row, x0 = slot(pos), cx - 2
    if row + 4 + R <= ytop:                                # the slot is above: up, then right
        return vline(x0, row + R, ytop) + [('stamp', 'cu', x0 - 2, row - 2)] + hline(row, x0 + R)
    if row - R >= ybot:                                    # below: down, then right
        return vline(x0, ybot, row + 4 - R) + [('stamp', 'cd', x0 - 2, row + 4 - R - 2)] + hline(row, x0 + R)
    return None


BACK_CLEAN = [('ovl', 5, 258, 422, 140, 229)]             # base 3 (CP): its dot and line -> the pad picture's pixels
TOP_CLEAN = [('ovl', 2, 342, 422, 27, 150), ('ovl', 1, 342, 370, 150, 167), ('ovl', 2, 342, 422, 167, 330)]   # base 0
PAD = {'up': (5, 310, 341, 238, 265, 325, 238, 265), 'left': (5, 294, 317, 262, 286, 305, 262, 286),
       'right': (6, 330, 356, 258, 288, 343, 258, 288), 'down': (7, 308, 342, 282, 304, 325, 282, 304)}
#        key: (source, x0, x1, y0, y1 of its highlight, line column, control top, bottom)


def arrow(key, pos):
    s, x0, x1, y0, y1, cx, yt, yb = PAD[key]
    ops = BACK_CLEAN + [('ovl', s, x0, x1, y0, y1)]
    if key == 'up':                                        # down through the pad, as stock ▼'s line goes up through it
        ops += vline(cx - 2, yb, slot(pos) + 4 - R) + [('stamp', 'cd', cx - 4, slot(pos) + 4 - R - 2)] + hline(slot(pos), cx - 2 + R)
    elif key == 'down':                                    # up through the pad (as stock)
        ops += vline(cx - 2, slot(pos) + R, yt) + [('stamp', 'cu', cx - 4, slot(pos) - 2)] + hline(slot(pos), cx - 2 + R)
    else:
        ops += leader(cx, yt, yb, pos)
    return 3, ops


def dial(pos):
    ops = TOP_CLEAN + [('stamp', 'dh', 275, 269)]
    cx = 296
    row = slot(pos)
    if row + 4 + R <= 268:
        ops += vline(cx - 2, row + R, 268) + [('stamp', 'cu', cx - 4, row - 2)] + hline(row, cx - 2 + R)
    elif row - R >= 287:
        ops += vline(cx - 2, 287, row + 4 - R) + [('stamp', 'cd', cx - 4, row + 4 - R - 2)] + hline(row, cx - 2 + R)
    else:                                                  # the slot runs past the dial: straight to the right edge
        ops += hline(row, 318)
    return 0, ops


def lfn(pos):
    # the stock line (up from the dot at x 224..227 to rows 93..96) cleared, outlines it crossed joined again
    ops = [('fill', BG, 222, 247, 91, 113), ('fill', BG, 247, XR, 91, 99), ('fill', BG, 222, 230, 113, 168),
           ('bridge', 222, 230, 113, 168)]
    ops += vline(224, 196, slot(pos) + 4 - R) + [('stamp', 'cd', 222, slot(pos) + 4 - R - 2)] + hline(slot(pos), 224 + R)
    return 8, ops


# rows -> (diagram key, position on its page). Rows: Fn REC |o| CP AF-ON ✥ ▲ | ◀ ▶ ▼ L-Fn CRT ART COLOR | MONO
DIAGRAMS = [('up', arrow('up', 6)), ('left', arrow('left', 0)), ('right', arrow('right', 1)), ('down', arrow('down', 2)),
            ('lfn', lfn(3)), ('crt', dial(4)), ('art', dial(5)), ('color', dial(6)), ('mono', dial(0))]
STAMPS = {'cu': corner_up(), 'cd': corner_down(), 'dh': dial_hi()}


def pack():
    """(programs blob, stamps blob): per diagram 16 u16 header {nsrc, base, src1, src2, nops, 0...} then ops of 8 u16
    {type 1 ovl / 2 fill / 3 stamp / 4 bridge, a, x0, x1, y0, y1, w, offset}. Program k at offset table."""
    sb, soff = b'', {}
    for k, a in STAMPS.items():
        soff[k] = (len(sb), a.shape[1], a.shape[0]); sb += a.tobytes()
        sb += b'\0' * (-len(sb) % 4)
    progs = []
    for name, (base, ops) in DIAGRAMS:
        srcs = [base] + sorted({o[1] for o in ops if o[0] == 'ovl'} - {base})
        assert len(srcs) <= 3, name
        body = b''
        for o in ops:
            if o[0] == 'ovl':
                body += struct.pack('<8H', 1, srcs.index(o[1]), *o[2:6], 0, 0)
            elif o[0] == 'fill':
                body += struct.pack('<8H', 2, o[1], *o[2:6], 0, 0)
            elif o[0] == 'stamp':
                off, w, h = soff[o[1]]
                body += struct.pack('<8H', 3, 0, o[2], o[2] + w, o[3], o[3] + h, w, off)
            elif o[0] == 'bridge':
                body += struct.pack('<8H', 4, 0, *o[1:5], 0, 0)
        hdr = struct.pack('<16H', len(srcs), *(STOCK + s for s in srcs), *([0] * (3 - len(srcs))), len(ops), *([0] * 11))
        progs.append(hdr + body)
    return progs, sb


def compose(stock, k):
    """the composition for diagram k from the stock pictures (dict index -> 446 x 422 array), as dg_get does it"""
    name, (base, ops) = DIAGRAMS[k]
    out = stock[base].copy()
    for o in ops:
        if o[0] == 'ovl':
            _, s, x0, x1, y0, y1 = o; out[y0:y1, x0:x1] = stock[s][y0:y1, x0:x1]
        elif o[0] == 'fill':
            _, v, x0, x1, y0, y1 = o; out[y0:y1, x0:x1] = v
        elif o[0] == 'stamp':
            st = STAMPS[o[1]]; x, y = o[2], o[3]; h, w = st.shape
            reg = out[y:y + h, x:x + w]; m = st[:reg.shape[0], :reg.shape[1]]
            reg[m != 0] = m[m != 0]
        elif o[0] == 'bridge':
            _, x0, x1, y0, y1 = o
            for y in range(y0, y1):
                if out[y, x0 - 1] != BG and out[y, x1] != BG:
                    out[y, x0:x1] = out[y, x0 - 1]
    return out


def encode(px):
    """the type-11 stream as dg_get writes it: runs of 1..16 within a row, 5 tokens a 64-bit word, 4-byte header"""
    h, w = px.shape
    out = bytearray([(h - 1) & 255, ((h - 1) >> 8 & 3) | (((w - 1) & 15) << 4), ((w - 1) >> 4) & 63, 11])
    toks = []
    for row in px:
        x = 0
        while x < w:
            v, r = row[x], 1
            while r < 16 and x + r < w and row[x + r] == v:
                r += 1
            toks.append(int(v) << 4 | (r - 1)); x += r
    for k in range(0, len(toks), 5):
        wd = 0
        for s_, t in enumerate(toks[k:k + 5]):
            wd |= t << (12 * s_)
        out += wd.to_bytes(8, 'little')
    return bytes(out)
