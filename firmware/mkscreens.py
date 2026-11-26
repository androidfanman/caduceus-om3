#!/usr/bin/env python3
"""Film Rolls E2 designs: the end-of-roll slip and the rewind panel, as OpenVG colour groups for the
256 x 256 surface the camera's graphics engine draws into (the same format as mkrollpath.py's rolls). Our own drawing,
in the poll mock-up's style (v12: the OM-3 menus' colours). Draft for the owner's approval: previews only.
Usage: mkscreens.py OUT_DIR
"""
import struct, sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import mkrollpath as R

AMBER, GOLD, ROW, INK = (0xfe, 0xb7, 0x41), (0x88, 0x6f, 0x15), (0x34, 0x34, 0x34), (0x0b, 0x0b, 0x0b)
WHITE, SOFT, PANEL = (0xf2, 0xf2, 0xf2), (0xb2, 0xb2, 0xb2), (0x16, 0x16, 0x16)
rgb = lambda c, a=0xff: (c[0] << 24) | (c[1] << 16) | (c[2] << 8) | a


def P(x, y):
    """surface pixels, y down -> OpenVG (y up)"""
    return (x, 256 - y)


def box(x, y, w, h, r=0, n=4):
    """a rectangle in surface pixels (y down), corners rounded by r"""
    import math
    if r <= 0:
        return [P(x, y), P(x + w, y), P(x + w, y + h), P(x, y + h)]
    out = []
    for cx, cy, a0 in ((x + w - r, y + r, -90), (x + w - r, y + h - r, 0), (x + r, y + h - r, 90), (x + r, y + r, 180)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            out.append(P(cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def words(s, cx, base, cap, maxw=None, left=None):
    """text in surface pixels (y down): centred on cx, or from x = left"""
    f = R._F = R._F or R.TTF(R.FONT)
    k = cap / (0.729 * f.upm)
    w = sum(f.adv(f.gid(ch)) for ch in s) * k
    if maxw and w > maxw:
        k *= maxw / w; w = maxw
    x = left if left is not None else cx - w / 2
    out = []
    for ch in s:
        g = f.gid(ch)
        for c in f.contours(g):
            out.append([P(x + px * k, base - py * k) for px, py in c])
        x += f.adv(g) * k
    return out


def small_roll(cx, cy, scale, name='Portra', iso=400, exp=36, body=(0xd9, 0x8a, 0x2b)):
    """mkrollpath's roll (shared parts + the film's), scaled about the surface's centre and moved to (cx, cy)"""
    groups = R.base() + R.film(name, iso, exp, body)
    out = []
    for col, polys in groups:
        out.append((col, [[(cx + (x - 128) * scale, (256 - cy) + (y - 128) * scale) for x, y in p] for p in polys]))
    return out


def slip(length=36):
    """the end-of-roll slip (mock-up step 3): a dark panel with an amber top edge, the big frame count, the words.
    Owner (test 31): "the text is tiny": the whole box now, the words on three lines (until then one strip, 9 px)"""
    return [
        (rgb(PANEL, 0xee), [box(4, 28, 248, 200, 10)]),
        (rgb(AMBER), [box(4, 28, 248, 5, 2)] + words(str(length), 128, 106, 54)),
        (rgb(WHITE), words('End of the roll', 128, 148, 24, maxw=232)),
        (rgb(SOFT), words('Shutter locked', 128, 180, 17, maxw=232)),
        (rgb(SOFT), words('Rear dial to rewind', 128, 207, 17, maxw=232)),
    ]


def rewind(left=14, length=36, film=('Portra', 400, (0xd9, 0x8a, 0x2b))):
    """the rewind panel (mock-up step 5): the roll, the frames still to wind back, a progress bar"""
    done = (length - left) / length
    g = [(rgb(PANEL, 0xee), [box(8, 8, 240, 240, 12)])]
    g += small_roll(128, 78, 0.48, film[0], film[1], length, film[2])
    g += [
        (rgb(WHITE), words(str(left), 128, 182, 40)),
        (rgb(SOFT), words('frames to rewind', 128, 202, 11)),
        (rgb(ROW), [box(36, 214, 184, 8, 4)]),
        (rgb(AMBER), [box(36, 214, max(8, 184 * done), 8, 4)]),
    ]
    return g


def dp(pts, eps):
    """Douglas-Peucker on an open polyline"""
    if len(pts) < 3:
        return pts
    (x0, y0), (x1, y1) = pts[0], pts[-1]
    dx, dy = x1 - x0, y1 - y0
    L = (dx * dx + dy * dy) ** .5
    best, bi = -1, 0
    for i in range(1, len(pts) - 1):
        x, y = pts[i]
        d = abs(dy * (x - x0) - dx * (y - y0)) / L if L else ((x - x0) ** 2 + (y - y0) ** 2) ** .5
        if d > best:
            best, bi = d, i
    if best <= eps:
        return [pts[0], pts[-1]]
    return dp(pts[:bi + 1], eps)[:-1] + dp(pts[bi:], eps)


EPS = 0.15   # surface pixels: the points dropped are at most this far from the drawn outline (the S_16 grid is 0.25)


def simp(groups, eps=EPS):
    """every closed polygon with the points nobody can see dropped (the record must fit the card file's buffers)"""
    out = []
    for col, polys in groups:
        ps = []
        for poly in polys:
            if len(poly) > 4:
                far = max(range(len(poly)), key=lambda i: (poly[i][0] - poly[0][0]) ** 2 + (poly[i][1] - poly[0][1]) ** 2)
                q = dp(poly[:far + 1], eps)[:-1] + dp(poly[far:] + [poly[0]], eps)[:-1]
                poly = q if len(q) >= 3 else poly
            ps.append(poly)
        out.append((col, ps))
    return out


def wid(s, cap):
    f = R._F = R._F or R.TTF(R.FONT)
    return sum(f.adv(f.gid(ch)) for ch in s) * cap / (0.729 * f.upm)


# ---- The pieces the card file puts the screens together from (SCREENS.BIN; frblock.s fb_art): a screen is up to 4
# records drawn in order. Entry numbers: frscreens.inc (made here, read by frblock.s).
LENS = (24, 36, 72)
NMAX = 72


def rw_base():
    return [(rgb(PANEL, 0xee), [box(8, 8, 240, 240, 12)]),
            (rgb(SOFT), words('frames to rewind', 128, 202, 11)),
            (rgb(ROW), [box(36, 214, 184, 8, 4)])]


def rw_roll(name, iso, length, body):
    return small_roll(128, 78, 0.48, name, iso, length, body)


def big(n):
    return [(rgb(WHITE), words(str(n), 128, 182, 40))]


def bar(p):
    return [(rgb(AMBER), [box(36, 214, max(8, 184 * p / 12), 8, 4)])]


def pieces():
    """[(name, groups)] in SCREENS.BIN's order, and the entry numbers"""
    out, at = [], {}
    def add(key, g):
        at.setdefault(key, len(out)); out.append(g)
    for L in LENS:
        add('SLIP', slip(L))
    add('RWB', rw_base())
    for nm, iso, col in R.FILMS + R.COLORS:
        for L in LENS:
            add('RWR', rw_roll(nm, iso, L, col))
    for n in range(NMAX + 1):
        add('BIG', big(n))
    for p in range(13):
        add('BAR', bar(p))
    at['N'] = len(out)
    return out, at


SC_PAGE = 10240   # a screen's pieces together, with their 24-byte header (frblock.s SC_PAGE)


def screens(path, inc):
    """OM3MOD/FILMROLL/SCREENS.BIN, as ROLLART.BIN: 'OM3R', u16 1, u16 n, n x {u32 offset, u32 length}, the records;
    and frscreens.inc, its entry numbers for frblock.s"""
    gs, at = pieces()
    blobs = [R.pack(simp(g)) for g in gs]
    big_ = max(len(b) for b in blobs)
    n = len(blobs); off = 8 + 8 * n; idx = b''
    for b in blobs:
        idx += struct.pack('<II', off, len(b)); off += len(b)
    Path(path).write_bytes(b'OM3R' + struct.pack('<HH', 1, n) + idx + b''.join(blobs))
    L = ['/* made by firmware/mkscreens.py: SCREENS.BIN\'s entry numbers */']
    L += [f' .set SC_{k}, {v}' for k, v in at.items()]
    L.append(f' .set SC_PAGE, {SC_PAGE}')
    Path(inc).write_text('\n'.join(L) + '\n')
    # the largest screen must fit one page
    worst = max(len(blobs[at['RWB']]) + max(len(blobs[at['RWR'] + i]) for i in range(72))
                + max(len(blobs[at['BIG'] + m]) for m in range(NMAX + 1)) + max(len(blobs[at['BAR'] + p]) for p in range(13)),
                *(len(blobs[at['SLIP'] + i]) for i in range(3)))
    assert worst + 24 + 16 <= SC_PAGE, worst
    return big_, worst, len(blobs), off


def entry(f, i):
    b = f
    n = struct.unpack_from('<H', b, 6)[0]
    assert i < n
    o, ln = struct.unpack_from('<II', b, 8 + 8 * i)
    return b[o:o + ln]


def back(rec):
    """a record back to groups of polygons (for the previews: drawn from the file itself)"""
    out = []
    for rgba, segs, data in R.unpack(rec):
        polys, cur, k = [], [], 0
        for sg in segs:
            if sg == R.CLOSE:
                polys.append(cur); cur = []
            else:
                cur.append((data[k], data[k + 1])); k += 2
        out.append((rgba, polys))
    return out


def compose(b, ids):
    g = []
    for i in ids:
        g += back(entry(b, i))
    return g


def render(groups, Z=4, bg=None):
    """the groups as the camera's renderer fills them (in order, even-odd, alpha), 256 x 256"""
    from PIL import Image, ImageDraw, ImageChops
    im = (bg.copy() if bg else Image.new('RGBA', (256, 256), (0, 0, 0, 0))).convert('RGBA').resize((256 * Z, 256 * Z))
    for rgba, polys in groups:
        c = (rgba >> 24, rgba >> 16 & 255, rgba >> 8 & 255, rgba & 255)
        mask = Image.new('1', im.size, 0)
        for poly in polys:
            m1 = Image.new('1', im.size, 0)
            ImageDraw.Draw(m1).polygon([(round(x * 4) / 4 * Z, (256 - round(y * 4) / 4) * Z) for x, y in poly], fill=1)
            mask = ImageChops.logical_xor(mask, m1)
        layer = Image.new('RGBA', im.size, c)
        a = mask.convert('L').point(lambda v: c[3] if v else 0)
        im.paste(layer, (0, 0), a)
    return im.resize((256, 256), Image.LANCZOS)


def size(groups):
    """bytes as a ROLLART-style record"""
    return len(R.pack(groups))


if __name__ == '__main__':
    if '--file' in sys.argv:          # build.py: SCREENS.BIN and frscreens.inc
        print('SCREENS.BIN: largest piece %d B, largest screen %d B, %d pieces, file %d B'
              % screens(sys.argv[sys.argv.index('--file') + 1], sys.argv[sys.argv.index('--inc') + 1]))
    else:
        out = Path(sys.argv[1]); out.mkdir(parents=True, exist_ok=True)
        panels = [('slip', slip()), ('rewind', rewind())]
        for name, g in panels:
            render(g).save(out / f'{name}.png')
            print(name, size(g), 'B')
