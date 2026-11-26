#!/usr/bin/env python3
"""Film Rolls E1 probe: the roll of the poll mock-up (v12) as OpenVG path data for the card file (frblock.s fb_draw).

Our own drawing, from scratch (no camera graphics). Output: an assembler include with one record per colour group
{segment count, segments, coordinates (VG_PATH_DATATYPE_S_16 in quarter pixels: scale 0.25, as OMKit's), RGBA}, coordinates in a 256 x 256 surface
(OpenVG: y up), as the Color Creator renderer's surface (OMKit: 256 x 256 on the OM-5 II; the probe logs the OM-3's).
Usage: mkrollpath.py OUT.inc [--preview PNG]
"""
import math, struct, sys
from pathlib import Path

FONT = Path.home() / 'Library/Fonts/DejaVuSansCondensed-Bold.ttf'
if not FONT.exists():
    FONT = Path('/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf')


class TTF:
    """the little of TrueType we need: cmap (format 4), advance widths, simple glyphs' quadratic outlines"""
    def __init__(self, path):
        b = self.b = Path(path).read_bytes()
        n = struct.unpack_from('>H', b, 4)[0]
        self.t = {b[12 + 16 * i:16 + 16 * i].decode('latin1'): struct.unpack_from('>II', b, 20 + 16 * i) for i in range(n)}
        self.upm = struct.unpack_from('>H', b, self.t['head'][0] + 18)[0]
        self.locfmt = struct.unpack_from('>h', b, self.t['head'][0] + 50)[0]
        self.nhm = struct.unpack_from('>H', b, self.t['hhea'][0] + 34)[0]
        c = self.t['cmap'][0]
        for i in range(struct.unpack_from('>H', b, c + 2)[0]):
            pid, eid, off = struct.unpack_from('>HHI', b, c + 4 + 8 * i)
            if (pid, eid) == (3, 1):
                self.c4 = c + off
        o = self.c4; seg = struct.unpack_from('>H', b, o + 6)[0] // 2
        self.ends = struct.unpack_from(f'>{seg}H', b, o + 14)
        self.starts = struct.unpack_from(f'>{seg}H', b, o + 16 + 2 * seg)
        self.deltas = struct.unpack_from(f'>{seg}h', b, o + 16 + 4 * seg)
        self.roff = o + 16 + 6 * seg
        self.ros = struct.unpack_from(f'>{seg}H', b, self.roff)

    def gid(self, ch):
        code = ord(ch)
        for i, e in enumerate(self.ends):
            if code <= e:
                if code < self.starts[i]:
                    return 0
                if self.ros[i] == 0:
                    return (code + self.deltas[i]) & 0xffff
                a = self.roff + 2 * i + self.ros[i] + 2 * (code - self.starts[i])
                g = struct.unpack_from('>H', self.b, a)[0]
                return (g + self.deltas[i]) & 0xffff if g else 0
        return 0

    def adv(self, g):
        h = self.t['hmtx'][0]
        return struct.unpack_from('>H', self.b, h + 4 * min(g, self.nhm - 1))[0]

    def contours(self, g, steps=4):
        """the glyph's closed contours as point lists (font units, y up); quadratic curves flattened"""
        L = self.t['loca'][0]
        if self.locfmt == 0:
            a, e = (2 * v for v in struct.unpack_from('>HH', self.b, L + 2 * g))
        else:
            a, e = struct.unpack_from('>II', self.b, L + 4 * g)
        if a == e:
            return []
        o = self.t['glyf'][0] + a; b = self.b
        nc = struct.unpack_from('>h', b, o)[0]
        assert nc >= 0, 'composite glyph'
        ends = struct.unpack_from(f'>{nc}H', b, o + 10); n = ends[-1] + 1
        q = o + 10 + 2 * nc; q += 2 + struct.unpack_from('>H', b, q)[0]
        fl = []
        while len(fl) < n:
            f = b[q]; q += 1; fl.append(f)
            if f & 8:
                r = b[q]; q += 1; fl += [f] * r
        def coords(short, same):
            nonlocal q
            out, v = [], 0
            for f in fl:
                if f & short:
                    d = b[q]; q += 1; v += d if f & same else -d
                elif not f & same:
                    v += struct.unpack_from('>h', b, q)[0]; q += 2
                out.append(v)
            return out
        xs = coords(2, 16); ys = coords(4, 32)
        out, s0 = [], 0
        for e in ends:
            pts = [(xs[i], ys[i], fl[i] & 1) for i in range(s0, e + 1)]; s0 = e + 1
            if not any(p[2] for p in pts):
                pts.insert(0, ((pts[0][0] + pts[-1][0]) / 2, (pts[0][1] + pts[-1][1]) / 2, 1))
            k = next(i for i, p in enumerate(pts) if p[2]); pts = pts[k:] + pts[:k]
            poly, cur, j, m = [pts[0][:2]], pts[0], 1, len(pts)
            while j <= m:
                p = pts[j % m]
                if p[2]:                                   # a line to an on-curve point
                    poly.append(p[:2]); cur = p; j += 1
                    continue
                n = pts[(j + 1) % m]                       # a quadratic: control p, end n or the implied midpoint
                end = n if n[2] else ((p[0] + n[0]) / 2, (p[1] + n[1]) / 2, 1)
                for t in (k / steps for k in range(1, steps + 1)):
                    poly.append(((1 - t) ** 2 * cur[0] + 2 * (1 - t) * t * p[0] + t * t * end[0],
                                 (1 - t) ** 2 * cur[1] + 2 * (1 - t) * t * p[1] + t * t * end[1]))
                cur = end; j += 2 if n[2] else 1
            out.append(poly[:-1] if poly[-1] == poly[0] else poly)
        return out


_F = None


def text(s, cx, base, cap, maxw=None, steps=4):
    """polygons of the string s, centred on cx, baseline at base (viewBox units, y down), cap height cap"""
    global _F
    _F = _F or TTF(FONT)
    k = cap / (0.729 * _F.upm)                      # DejaVu's cap height is 0.729 em
    w = sum(_F.adv(_F.gid(ch)) for ch in s) * k
    if maxw and w > maxw:
        k *= maxw / w; w = maxw
    x, polys = cx - w / 2, []
    for ch in s:
        g = _F.gid(ch)
        for c in _F.contours(g, steps):
            polys.append([pt(x + px * k, base - py * k) for px, py in c])
        x += _F.adv(g) * k
    return polys

VB_W, VB_H = 110, 200            # the mock-up's roll (frblock / poster v12 viewBox)
S = 1.1                          # its scale in the 256 surface
X0, Y0 = (256 - VB_W * S) / 2, (256 - VB_H * S) / 2
MOVE, LINE, CLOSE = 2, 4, 0      # VG_MOVE_TO_ABS, VG_LINE_TO_ABS, VG_CLOSE_PATH


def pt(x, y):
    """viewBox (y down) -> surface (y up)"""
    return (X0 + x * S, 256 - (Y0 + y * S))


def rrect(x, y, w, h, r=0, n=4):
    """a rectangle with rounded corners (r in viewBox units, n segments a corner), as one closed polygon"""
    if r <= 0:
        return [pt(x, y), pt(x + w, y), pt(x + w, y + h), pt(x, y + h)]
    out = []
    for cx, cy, a0 in ((x + w - r, y + r, -90), (x + w - r, y + h - r, 0), (x + r, y + h - r, 90), (x + r, y + r, 180)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n)
            out.append(pt(cx + r * math.cos(a), cy + r * math.sin(a)))
    return out


def circle(cx, cy, r, n=28):
    return [pt(cx + r * math.cos(2 * math.pi * k / n), cy + r * math.sin(2 * math.pi * k / n)) for k in range(n)]


def lum(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def base():
    """the parts every roll shares, drawn first (frpaths.inc, in the card file): the leader, its holes, the caps"""
    rgb = lambda c: (c[0] << 24) | (c[1] << 16) | (c[2] << 8) | 0xff
    return [
        (rgb((0x5a, 0x46, 0x30)), [rrect(88, 42, 18, 108)]),
        (rgb((0x0b, 0x0b, 0x0b)), [rrect(95, y, 6, 7) for y in range(50, 146, 14)]),
        (rgb((0x3c, 0x3c, 0x3c)), [rrect(8, 10, 90, 16, 5), rrect(8, 176, 90, 16, 5)]),
    ]


def film(name='Portra', iso=400, exp=36, body=(0xd9, 0x8a, 0x2b), labelled=False):
    """one film's own parts, drawn after base(): the body, the badge, the ISO in the body's colour, then the label's
    ink (the name, the line, "36 exp"): dark on light films, light on dark ones (ROLLART.BIN). exp None: no length
    (the film selection row with no roll loaded; owner, test 24: "since this hasnt been set yet, shouldnt that be
    blank?")"""
    rgb = lambda c: (c[0] << 24) | (c[1] << 16) | (c[2] << 8) | 0xff
    ink = (0x14, 0x12, 0x10) if lum(body) > 90 else (0xf0, 0xec, 0xe4)
    n = len(name); iso = str(iso)
    return [
        (rgb(body), [rrect(12, 26, 82, 150)]),
        (rgb((0x14, 0x12, 0x10)), [circle(53, 60, 21)]),
        (rgb(body), text(iso, 53, 67, 14 if len(iso) < 4 else 11, maxw=34)),
        (rgb(ink), text(name, 53, 120, 17 if n <= 7 else 14, maxw=74) + [rrect(12, 134, 82, 4)]
         + (text(f'{exp} exp', 53, 163, 12, maxw=60) if exp else [])),
    ] + (label(exp) if labelled else [])


def label(exp):
    """above the roll (ROLLART.BIN only; owner, test 27: "we need to clarify/add some sort text to signify what changing
    that shot selection count"): what the rear dial sets, and its value ("36 exposures"; None: "No roll")"""
    rgb = lambda c: (c[0] << 24) | (c[1] << 16) | (c[2] << 8) | 0xff
    return [(rgb((0xb2, 0xb2, 0xb2)), text('Rear dial', 55, -30, 9, maxw=190, steps=2)),
            (rgb((0xf2, 0xf2, 0xf2)), text(f'{exp} exposures' if exp else 'No roll', 55, -8, 14, maxw=190, steps=2))]


def roll(name='Portra', iso=400, exp=36, body=(0xd9, 0x8a, 0x2b)):
    return base() + film(name, iso, exp, body)


def records(groups):
    out = []
    for rgba, polys in groups:
        segs, data = [], []
        for poly in polys:
            segs.append(MOVE); data += poly[0]
            for p in poly[1:]:
                segs.append(LINE); data += p
            segs.append(CLOSE)
        out.append((rgba, segs, data))
    return out


def write_inc(path, recs):
    L = ['/* made by firmware/mkrollpath.py: the E1 probe roll as OpenVG paths (VG_PATH_DATATYPE_S_16, quarter pixels) */', ' .balign 4', 'fb_paths:']
    for i in range(len(recs)):
        L.append(f' .long {len(recs[i][1])}, fb_pseg{i}, fb_pdat{i}, {recs[i][0]:#010x}')
    L.append(' .long 0, 0, 0, 0')
    L.append(' .balign 4')
    for i, (rgba, segs, data) in enumerate(recs):
        L.append(f'fb_pdat{i}:')
        for k in range(0, len(data), 12):
            L.append(' .short ' + ', '.join(str(max(-32768, min(32767, round(v * 4)))) for v in data[k:k + 12]))
        L.append(f'fb_pseg{i}:')
        for k in range(0, len(segs), 16):
            L.append(' .byte ' + ', '.join(str(s) for s in segs[k:k + 16]))
        L.append(' .balign 4')
    open(path, 'w').write('\n'.join(L) + '\n')


def preview(png, recs, scale=2):
    from PIL import Image, ImageDraw
    im = Image.new('RGBA', (256 * scale, 256 * scale), (40, 40, 40, 255)); d = ImageDraw.Draw(im)
    for rgba, segs, data in recs:
        col = (rgba >> 24, rgba >> 16 & 255, rgba >> 8 & 255, 255)
        pts, k = [], 0
        for s in segs:
            if s == CLOSE:
                d.polygon([(x * scale, (256 - y) * scale) for x, y in pts], fill=col); pts = []
            else:
                pts.append((data[k], data[k + 1])); k += 2
    im.save(png)


# The default shelf (owner, Q8: "for now, just use the default 20"): FILM 1..20 in camera order (README "The 20 film
# sims"), the label's short name, the box speed, our own colour; then COLOR 1..4 (the badge carries the profile's
# number). The user's own names and colours: later from LookLab (a roll designer writing this file).
FILMS = [('Portra', 400, (0xd9, 0x8a, 0x2b)), ('Portra', 160, (0xe8, 0xa8, 0x62)), ('Portra', 800, (0xb8, 0x6a, 0x24)),
         ('Gold', 200, (0xe0, 0xb2, 0x3a)), ('ColorPlus', 200, (0xe8, 0x9a, 0x3c)), ('Ektar', 100, (0xd6, 0x5a, 0x3c)),
         ('E100', 100, (0x4a, 0x78, 0xb8)), ('Kodachrome', 64, (0xd8, 0xb0, 0x40)), ('CineStill', 800, (0xb0, 0x4a, 0x62)),
         ('Velvia', 50, (0x4f, 0xa6, 0x73)), ('Provia', 100, (0x4c, 0x8c, 0xc8)), ('Pro 400H', 400, (0x7c, 0xc0, 0xb0)),
         ('Pro 160S', 160, (0x8a, 0xb8, 0x7a)), ('NPS', 160, (0xa8, 0xc4, 0x8c)), ('NHG II', 800, (0x3e, 0x8c, 0x7c)),
         ('Superia', 400, (0x5a, 0xa8, 0x5a)), ('C200', 200, (0x6a, 0x9c, 0xd8)), ('Fujifilm', 200, (0x9a, 0xc0, 0x5a)),
         ('Fujifilm', 400, (0x48, 0xa0, 0x60)), ('Natura', 1600, (0x6e, 0x6a, 0x66))]
COLORS = [(f'COLOR', k, (0x8a, 0x8a, 0x8a)) for k in (1, 2, 3, 4)]
EXPS = (24, 36, 72)


def pack(groups):
    """one record: u32 groups, then each {u32 segments, u32 their offset, u32 the coordinates' offset, u32 RGBA}
    (offsets from the record's start), the coordinates (S_16 quarter pixels), the segments (bytes)"""
    recs = records(groups)
    head = struct.pack('<I', len(recs))
    body, idx = b'', []
    at = 4 + 16 * len(recs)
    for rgba, segs, data in recs:
        d = b''.join(struct.pack('<h', max(-32768, min(32767, round(v * 4)))) for v in data)
        sg = bytes(segs)
        idx.append(struct.pack('<IIII', len(segs), at + len(d), at, rgba))
        blob = d + sg
        blob += b'\0' * (-len(blob) % 4)
        body += blob; at += len(blob)
    return head + b''.join(idx) + body


SV = {200: 1536, 400: 1792, 800: 2048, 1600: 2304, 3200: 2560, 6400: 2816}


def isotab():
    """the roll's ISO table, between ROLLART.BIN's index and its records (frblock.s rl_arms reads it): 'OM3I', then
    24 u16, the camera's ISO setting (Sv x 256) for FILM 1..20 (owner, 2026-11-24: "box speed unless its lower than 200;
    if lower, 200"), then COLOR 1..4 (400). LookLab writes its own films' ISO here (2026-11-25)"""
    return b'OM3I' + struct.pack('<24H', *([SV[max(200, iso)] for _, iso, _ in FILMS] + [SV[400]] * len(COLORS)))


def rollart(path):
    """OM3MOD/FILMROLL/ROLLART.BIN: 'OM3R', u16 1, u16 n, n x {u32 offset, u32 length}, the ISO table (isotab), the
    records. Entry
    3 x i + (exposures 24 / 36 / 72 -> 0 / 1 / 2): i 0..19 FILM 1..20, 20..23 COLOR 1..4; then 72 + i: the same films
    without a length (the film selection row, no roll loaded)"""
    entries = ([film(nm, iso, e, col, True) for nm, iso, col in FILMS + COLORS for e in EXPS]
               + [film(nm, iso, None, col, True) for nm, iso, col in FILMS + COLORS])
    blobs = [pack(g) for g in entries]
    n = len(blobs); isos = isotab(); at = 8 + 8 * n + len(isos); idx = b''
    for b in blobs:
        idx += struct.pack('<II', at, len(b)); at += len(b)
    out = b'OM3R' + struct.pack('<HH', 1, n) + idx + isos + b''.join(blobs)
    Path(path).write_bytes(out)
    return max(len(b) for b in blobs), len(out)


def unpack(rec):
    """a record back to [(rgba, segments, coordinates as floats)] (the sheet draws from the file itself)"""
    n = struct.unpack_from('<I', rec, 0)[0]; out = []
    for i in range(n):
        ns, so, do, rgba = struct.unpack_from('<IIII', rec, 4 + 16 * i)
        segs = list(rec[so:so + ns])
        npts = sum(1 for x in segs if x != CLOSE)
        data = [v / 4 for v in struct.unpack_from(f'<{2 * npts}h', rec, do)]
        out.append((rgba, segs, data))
    return out


def sheet(png, art):
    """every film's 36 roll as the camera's renderer would draw it: base() then the film's record read back from
    ROLLART.BIN, filled in order, even-odd; 256 x 256 each"""
    from PIL import Image, ImageDraw
    Z = 4
    tiles = []
    b = Path(art).read_bytes(); n = struct.unpack_from('<H', b, 6)[0]
    for i in range(len(FILMS) + len(COLORS)):
        off, ln = struct.unpack_from('<II', b, 8 + 8 * (3 * i + 1))
        recs = records(base()) + unpack(b[off:off + ln])
        im = Image.new('RGB', (256 * Z, 256 * Z), (18, 18, 18)); d = ImageDraw.Draw(im)
        for rgba, segs, data in recs:
            c = (rgba >> 24, rgba >> 16 & 255, rgba >> 8 & 255)
            # even-odd fill as OpenVG's default: draw each subpath into a mask, XOR
            mask = Image.new('1', im.size, 0)
            pts, k = [], 0
            for sg in segs:
                if sg == CLOSE:
                    m1 = Image.new('1', im.size, 0)
                    ImageDraw.Draw(m1).polygon([(round(x * 4) / 4 * Z, (256 - round(y * 4) / 4) * Z) for x, y in pts], fill=1)
                    from PIL import ImageChops
                    mask = ImageChops.logical_xor(mask, m1); pts = []
                else:
                    pts.append((data[k], data[k + 1])); k += 2
            im.paste(c, (0, 0), mask.convert('L'))
        tiles.append(im.resize((256, 256), Image.LANCZOS))
    cols = 8
    out = Image.new('RGB', (cols * 272 + 16, ((len(tiles) + cols - 1) // cols) * 272 + 16), (30, 30, 30))
    for i, t in enumerate(tiles):
        out.paste(t, (16 + (i % cols) * 272, 16 + (i // cols) * 272))
    out.save(png)


if __name__ == '__main__':
    recs = records(base())                        # the card file draws these itself; each film's part: ROLLART.BIN
    write_inc(sys.argv[1], recs)
    if '--art' in sys.argv:
        print('ROLLART.BIN: largest record %d B, file %d B' % rollart(sys.argv[sys.argv.index('--art') + 1]))
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1], recs)
    if '--sheet' in sys.argv:
        sheet(sys.argv[sys.argv.index('--sheet') + 1], sys.argv[sys.argv.index('--art') + 1])
