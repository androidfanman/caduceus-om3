#!/usr/bin/env python3
"""LABELS.BIN for the OM-3 Extras wheel (v0.20): the dial label next to the value ("Vivid" on the stock wheel) names
the selected Extras slice and what its value does. Drawn from scratch to the stock label's metrics (70 x 30, OM-3 OSD
palette: 0 clear, 7 dark edge, 8 grey, 9 faint, 10 white fill, 11/12 soft fill); no camera graphics are copied.
LABELS.BIN v2: 'OM3V' | u32 total | u32 crc32(bytes 12..) | u32 n (24 from v0.21, 26 from v0.22, 27 from v0.23) | n bitmaps of 30 rows x 9 bytes (70 px + 2 spare
bits, MSB first, 1 = letter fill). The camera draws the label from its bitmap (firmware code block): fill 10, a 1 px
dark edge 7 (8 neighbours), then grey 8 out to 2 px, and encodes it as an OSD type-11 stream (render() below is the
same rule, for the preview and the tests).
usage: mklabels.py OUT.BIN [--preview PNG]"""
import argparse, struct, zlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

W, H, BASE, CAP = 70, 30, 26, 24
FONTS = ['/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed.ttf', '/Library/Fonts/Arial Narrow.ttf']
LABELS = ['NR', 'NR Std', 'NR Low', 'NR Off', 'NR High',          # slice 1: 0 camera, 1 Standard, 2 Low, 3 Off, 4 High (v0.23)
          'Glow', 'Clarity', 'Glo/Cla',                         # slice 2: negative, positive, zero
          'B', 'A', 'A/B',                                      # slice 3 (A-B): blue, amber, zero
          'M', 'G', 'G/M',                                      # slice 4 (G-M): magenta, green, zero
          'Art Off', 'Star', 'Pin Hole', 'Art Off', 'W. Edge', 'Frame',   # slice 5: Caduceus Art Effect ids 0..5
          'Blacks', 'Whites',                                   # slices 6, 7
          'Vig Cam', 'Vig Off',                                 # slice 8 (VigFix, v0.21): 0 camera, 1 off
          'Grain',                                              # slice 9 (v0.21): the readout shows 0..3
          'Sharp', 'Sharp Off']                                 # slice 10 (v0.22): -4..+2 (readout), -5 Off


def font(size):
    for p in FONTS:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    raise SystemExit('no font')


def raster(txt, fs, sq):
    S = 4
    f = font(fs * S)
    im = Image.new('L', (fs * S * len(txt) + 200, fs * S * 2), 0); ImageDraw.Draw(im).text((50, 20), txt, font=f, fill=255)
    a = np.array(im); xs = np.nonzero(a.any(axis=0))[0]
    im = im.crop((xs.min(), 0, xs.max() + 1, a.shape[0]))
    return np.array(im.resize((max(1, round(im.width / S * sq)), round(im.height / S)), Image.LANCZOS)).astype(int)


def cap_rows(fs):
    r = np.nonzero((raster('H', fs, 1.0) > 128).any(axis=1))[0]; return r.min(), r.max()


def build(txt, maxw=62):
    fs = next(f for f in range(10, 60) if (lambda r: r[1] - r[0] + 1)(cap_rows(f)) >= CAP)
    sq = 0.80
    a = raster(txt, fs, sq)
    while a.shape[1] > maxw and sq > 0.40:
        sq = round(sq - 0.02, 2); a = raster(txt, fs, sq)
    top, base = cap_rows(fs)
    shift, desc_max = BASE - base, H - 3 - BASE
    ink = np.nonzero((a > 40).any(axis=1))[0]
    if ink.max() - base > desc_max:
        tail = Image.fromarray(a[base + 1:ink.max() + 1].astype(np.uint8))
        tail = np.array(tail.resize((tail.width, desc_max), Image.LANCZOS)).astype(int)
        a = np.vstack([a[:base + 1], tail, np.zeros((a.shape[0] - base - 1 - desc_max, a.shape[1]), dtype=int)])
    fill = a > 128; soft = (a > 60) & ~fill
    lay = np.zeros((H, W), dtype=np.uint8)
    for y in range(fill.shape[0]):
        yy = y + shift
        if 0 <= yy < H:
            for x in range(fill.shape[1]):
                if fill[y, x]: lay[yy, 5 + x] = 10
                elif soft[y, x]: lay[yy, 5 + x] = 11 if a[y, x] > 100 else 12
    fm = lay == 10
    e = ndimage.distance_transform_edt(~fm)
    out = np.zeros_like(lay)
    out[(e > 0) & (e <= 1.0)] = 7
    out[(e > 1.0) & (e <= 2.0)] = 8
    out[(e > 2.0) & (e <= 2.5)] = 9
    soft = (lay == 11) | (lay == 12)
    out[soft] = lay[soft]
    out[fm] = 10
    return out


def encode11(px, w, h):
    toks, i = [], 0
    while i < len(px):
        v, r = px[i], 1
        while r < 16 and i + r < len(px) and px[i + r] == v: r += 1
        toks.append(v << 4 | (r - 1)); i += r
    out = bytearray([(h - 1) & 255, ((h - 1) >> 8 & 3) | (((w - 1) & 15) << 4), ((w - 1) >> 4) & 63, 11])
    for k in range(0, len(toks), 5):
        word = 0
        for s, t in enumerate(toks[k:k + 5]): word |= t << (12 * s)
        out += word.to_bytes(8, 'little')
    return bytes(out)


def bitmap(txt):
    """70 x 30 letter fill (bool), placed and squeezed as build() does."""
    return build(txt) == 10


def render(fill):
    out = np.zeros((H, W), dtype=np.uint8)
    pad = np.pad(fill, 2)
    for y in range(H):
        for x in range(W):
            if fill[y, x]: out[y, x] = 10
            elif pad[y + 1:y + 4, x + 1:x + 4].any(): out[y, x] = 7
            elif pad[y:y + 5, x:x + 5].any(): out[y, x] = 8
    return out


def pack(fill):
    b = bytearray()
    for y in range(H):
        bits = list(fill[y]) + [False, False]
        for k in range(0, 72, 8):
            v = 0
            for i in range(8): v = v << 1 | int(bits[k + i])
            b.append(v)
    return bytes(b)


def wb_glyphs(at):
    """v0.25 (LABELS.BIN v3): after the bitmaps (at = this section's offset in the file), the WB / Blacks-Whites grid
    rows' cell glyphs and the Blacks / Whites cell top (firmware/mkicons.py wbc_glyphs, bw_top; drawn from scratch in
    our font): 'WBG1' | u16 offset[N] (from 'WBG1') | u16 offset, length x 4 (the top picture "Blk/Wht" 82 x 30;
    the grid's box '+' / '-' 32 x 32; the header's '+' 16 x 30) | u8 width[N] | pad | each glyph's rows, one palette
    index a byte (0 clear, 7 dark edge, 10 / 11 / 12 fill) | the pictures (OSD type 11, each 4-aligned in the file). The firmware (xb_wbc) draws the cells from them."""
    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent / 'firmware'))
    import mkicons
    gl = mkicons.wbc_glyphs()
    n = len(gl)
    head = (4 + 2 * n + 16 + n + 3) & ~3
    offs, data = [], b''
    for g in gl:
        offs.append(head + len(data))
        data += bytes(int(v) for v in g.flatten())
    pics = [(mkicons.bw_top(), 82, 30)] + [(p, p.shape[1], p.shape[0]) for p in mkicons.bw_syms()]
    pl = []
    for px, w, h in pics:
        st = mkicons.encode11(bytes(px.flatten()), w, h)
        o = head + len(data)
        while (at + o) % 4:
            o += 1
        data += bytes(o - head - len(data)) + st
        pl += [o, len(st)]
    return (b'WBG1' + struct.pack('<%dH' % n, *offs) + struct.pack('<8H', *pl) + bytes(g.shape[1] for g in gl)
            + bytes(head - 4 - 2 * n - 16 - n) + data)


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--preview')
    a = ap.parse_args()
    fills = [bitmap(t) for t in LABELS]
    imgs = [render(f) for f in fills]
    body = struct.pack('<I', len(fills)) + b''.join(pack(f) for f in fills)
    body += wb_glyphs(12 + len(body))
    out = b'OM3V' + struct.pack('<II', 12 + len(body), zlib.crc32(body) & 0xffffffff) + body
    open(a.out, 'wb').write(out); print(a.out, len(out), 'bytes; largest stream', max(len(encode11(bytes(i.flatten()), W, H)) for i in imgs))
    if a.preview:
        pal = {0: (30, 30, 60), 7: (20, 20, 20), 8: (90, 90, 90), 9: (60, 60, 60), 10: (255, 255, 255), 11: (200, 200, 200), 12: (160, 160, 160)}
        sheet = Image.new('RGB', (W * 3 * ((len(imgs) + 6) // 7), H * 3 * 7), (30, 30, 60))
        for k, i in enumerate(imgs):
            rgb = Image.new('RGB', (W, H)); rgb.putdata([pal.get(int(v), (255, 0, 255)) for v in i.flatten()])
            sheet.paste(rgb.resize((W * 3, H * 3), Image.NEAREST), ((k // 7) * W * 3, (k % 7) * H * 3))
        sheet.save(a.preview)
