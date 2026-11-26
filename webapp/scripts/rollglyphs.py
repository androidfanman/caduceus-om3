#!/usr/bin/env python3
"""Film Rolls canisters in LookLab: the raw outlines (TrueType points, unflattened) of DejaVu Sans Condensed Bold for
the printable ASCII letters, as src/data/rollglyphs.json. LookLab (src/rollart.ts) lays them out and flattens the
curves exactly as firmware/mkrollpath.py does, so its canisters match the card's ROLLART.BIN.
Usage: rollglyphs.py MKROLLPATH_DIR OUT.json   (MKROLLPATH_DIR: the folder holding firmware/mkrollpath.py)"""
import json, struct, sys
sys.path.insert(0, sys.argv[1])
from mkrollpath import TTF, FONT


def raw(f, g):
    """the glyph's contours as [[x, y, on], ...] (font units, y up), as TTF.contours reads them before flattening"""
    L = f.t['loca'][0]
    if f.locfmt == 0:
        a, e = (2 * v for v in struct.unpack_from('>HH', f.b, L + 2 * g))
    else:
        a, e = struct.unpack_from('>II', f.b, L + 4 * g)
    if a == e:
        return []
    o = f.t['glyf'][0] + a; b = f.b
    nc = struct.unpack_from('>h', b, o)[0]
    if nc < 0:
        return None
    ends = struct.unpack_from(f'>{nc}H', b, o + 10); n = ends[-1] + 1
    q = o + 10 + 2 * nc; q += 2 + struct.unpack_from('>H', b, q)[0]
    fl = []
    while len(fl) < n:
        x = b[q]; q += 1; fl.append(x)
        if x & 8:
            r = b[q]; q += 1; fl += [x] * r
    def coords(short, same):
        nonlocal q
        out, v = [], 0
        for x in fl:
            if x & short:
                d = b[q]; q += 1; v += d if x & same else -d
            elif not x & same:
                v += struct.unpack_from('>h', b, q)[0]; q += 2
            out.append(v)
        return out
    xs = coords(2, 16); ys = coords(4, 32)
    out, s0 = [], 0
    for e in ends:
        out.append([[xs[i], ys[i], fl[i] & 1] for i in range(s0, e + 1)]); s0 = e + 1
    return out


f = TTF(FONT)
glyphs, skipped = {}, []
for c in range(32, 127):
    ch = chr(c); g = f.gid(ch); r = raw(f, g)
    if r is None:
        skipped.append(ch); continue
    glyphs[ch] = {'adv': f.adv(g), 'c': r}
json.dump({'font': 'DejaVu Sans Condensed Bold', 'upm': f.upm, 'glyphs': glyphs}, open(sys.argv[2], 'w'), separators=(',', ':'))
print('glyphs', len(glyphs), 'skipped (composite)', skipped)
