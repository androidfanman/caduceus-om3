#!/usr/bin/env python3
"""GUIDES.BIN for the OM-3 colour editor: the guide pictures shown under the wheel ("Hue [INFO]", "Luminance [INFO]",
"Extras [INFO]", "Film [INFO]"), drawn from scratch (no camera graphics are copied).

Picture: 175 x 50 px, OM-3 OSD palette indices (0 clear, 7 dark edge, 9 faint rim, 10 white fill, 11 light edge,
12 grey). The word is fitted to the camera's own guide metrics (cap height 31 px, baseline row 40, right edge col 102);
the INFO box sits at cols 107..172.
Stream format: OSD type 11 (header 4 B: h-1 | w-1 << 12 | 11 << 24, then 64-bit groups of five 12-bit tokens,
token = index << 4 | run - 1).
GUIDES.BIN v4: 'OM3G' | u32 total | u32 crc32(bytes 12..) | u16 w | u16 h | u32 len1..len4 | streams, each padded to 4 B.
usage: mkguides.py OUT.BIN [--preview PNG]"""
import argparse, struct, zlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

W, H, BOX = 175, 50, 109
CAP, OW, DESC = 31, 15, 6
FONTS = ['/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed.ttf', '/Library/Fonts/Arial Narrow.ttf',
         '/System/Library/Fonts/Supplemental/Arial Narrow.ttf']
BOLD = ['/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf', '/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf']


def font(paths, size):
    for p in paths:
        try: return ImageFont.truetype(p, size)
        except OSError: pass
    raise SystemExit('no usable font found (install DejaVu fonts)')


def raster(txt, fs, sq, paths=FONTS):
    S = 4
    f = font(paths, fs * S)
    im = Image.new('L', (fs * S * len(txt) + 200, fs * S * 2), 0); ImageDraw.Draw(im).text((50, 20), txt, font=f, fill=255)
    a = np.array(im); ys, xs = np.nonzero(a > 0)
    im = im.crop((xs.min(), 0, xs.max() + 1, a.shape[0]))
    return np.array(im.resize((max(1, round(im.width / S * sq)), round(im.height / S)), Image.LANCZOS)).astype(int)


def fit(txt):
    for fs in range(20, 60):
        r = np.nonzero((raster('H', fs, 1.0) > 128).any(axis=1))[0]
        if r.max() - r.min() + 1 >= CAP: break
    for sq in [x / 100 for x in range(60, 111)]:
        c = np.nonzero((raster('o', fs, sq) > 128).any(axis=0))[0]
        if c.max() - c.min() + 1 >= OW: break
    a = raster(txt, fs, sq)
    while a.shape[1] > 100 and sq > 0.5:
        sq = round(sq - 0.02, 2); a = raster(txt, fs, sq)
    return a, fs, sq


def edge(fillm, soft=None):
    """The camera's outline style around a white fill: 1-px edge, light corners, 2-px dark line, faint rim."""
    e = ndimage.distance_transform_edt(~fillm)
    out = np.zeros(fillm.shape, dtype=np.uint8)
    out[(e > 0) & (e <= 1.0)] = 7
    if soft is not None: out[(e > 0) & (e <= 1.0) & soft] = 11
    out[(e > 1.0) & (e < 1.5)] = 12
    out[(e >= 1.5) & (e <= 2.0)] = 7
    out[(e > 2.0) & (e <= 2.9)] = 9
    out[fillm] = 10
    return out


def key_box(kx0=107, kw=66):
    """A rounded white key, kw x 40 px, at cols kx0..kx0+kw-1, rows 5..44: 1 px faint rim, dark 1 px line, white inside.
    Returns the picture and the key's mask."""
    img = np.zeros((H, W), dtype=np.uint8)
    S = 4
    im = Image.new('L', (kw * S, 40 * S), 0); d = ImageDraw.Draw(im)
    d.rounded_rectangle((0, 0, kw * S - 1, 40 * S - 1), radius=3 * S, fill=255)
    box = np.array(im.resize((kw, 40), Image.LANCZOS)) > 128
    full = np.zeros((H, W), dtype=bool); full[5:45, kx0:kx0 + kw] = box
    e = ndimage.distance_transform_edt(~full)
    img[(e > 0) & (e <= 1.0)] = 9
    inner = ndimage.binary_erosion(full, iterations=2)
    img[full] = 7; img[inner] = 10
    corner = full & ~inner & ndimage.binary_erosion(full, iterations=1) & ~ndimage.binary_erosion(full, structure=np.ones((3, 3)), iterations=1)
    img[corner & (img == 7)] = 12
    return img


def ink(img, a, y0, x0):
    """Dark glyph a (0..255 coverage) into the white key at (y0, x0), its soft edge light."""
    h, w = a.shape
    reg = img[y0:y0 + h, x0:x0 + w]
    reg[(a > 128)] = 7
    reg[(a > 40) & (a <= 128) & (reg == 10)] = 11


def info_box():
    """A rounded white key with a dark 'INFO' inside, 66 x 40 px, placed at cols 107..172, rows 5..44."""
    img = key_box()
    # 'INFO', bold, 27 px cap height, centred
    for fs in range(14, 50):
        a = raster('INFO', fs, 1.0, BOLD)
        r = np.nonzero((a > 128).any(axis=1))[0]
        if r.max() - r.min() + 1 >= 26: break
    sq = 1.0
    while a.shape[1] > 50 and sq > 0.4:                   # narrow until it fits the key like the camera's (50 px)
        sq = round(sq - 0.02, 2); a = raster('INFO', fs, sq, BOLD)
    rows = np.nonzero((a > 40).any(axis=1))[0]; a = a[rows.min():rows.max() + 1]
    h, w = a.shape
    ink(img, a, 25 - h // 2, 140 - w // 2)
    return img


DEL_X0, DEL_W = 129, 44


def del_box():
    """feature/picture-mode (owner: "the delete switch to the sat all"): the Delete key, the camera's bin drawn from
    scratch (lid with its handle, a tapered body with three slots), dark in a 44 x 40 white key at cols 129..172."""
    img = key_box(DEL_X0, DEL_W)
    S, gw, gh = 8, 24, 28
    im = Image.new('L', (gw * S, gh * S), 0); d = ImageDraw.Draw(im)
    u = lambda v: round(v * S)
    d.rectangle((u(8), u(0), u(16) - 1, u(4) - 1), fill=255)              # handle
    d.rectangle((u(10.5), u(1.7), u(13.5) - 1, u(4) - 1), fill=0)
    d.rectangle((u(0), u(3.5), u(24) - 1, u(6.5) - 1), fill=255)          # lid
    d.polygon([(u(2), u(8)), (u(22), u(8)), (u(20), u(28)), (u(4), u(28))], fill=255)   # body
    for cx in (7.6, 12, 16.4):                                             # slots
        d.rectangle((u(cx - 1.1), u(11), u(cx + 1.1) - 1, u(25) - 1), fill=0)
    a = np.array(im.resize((gw, gh), Image.LANCZOS)).astype(int)
    ink(img, a, 25 - gh // 2, DEL_X0 + DEL_W // 2 - gw // 2)
    return img


def build(txt, key='info'):
    """The word, right-aligned 5 px before the key, then the key: INFO (cols 107..172) or Delete (key='del')."""
    kx0 = DEL_X0 if key == 'del' else 107
    box = kx0 + 2
    a, fs, sq = fit(txt)
    a0 = raster(txt[0], fs, sq); base_row = np.nonzero((a0 > 128).any(axis=1))[0].max()
    ink = np.nonzero((a > 40).any(axis=1))[0]
    if ink.max() - base_row > DESC:                       # squeeze only a descender's tail into rows 41..46
        tail = Image.fromarray(a[base_row + 1:ink.max() + 1].astype(np.uint8))
        tail = np.array(tail.resize((tail.width, DESC), Image.LANCZOS)).astype(int)
        a = np.vstack([a[:base_row + 1], tail, np.zeros((a.shape[0] - base_row - 1 - DESC, a.shape[1]), dtype=int)])
    fill = a > 128; soft = (a > 40) & ~fill
    lay = np.zeros((H, W), dtype=np.uint8); h, w = fill.shape; x0 = kx0 - 5 - w + 1; shift = 40 - base_row
    assert x0 >= 2, (txt, w)
    for y in range(h):
        yy = y + shift
        if 0 <= yy < H:
            lay[yy, x0:x0 + w][fill[y]] = 10
            lay[yy, x0:x0 + w][soft[y] & ~fill[y]] = 11
    word = edge(lay == 10, lay == 11); word[:, box - 2:] = 0
    img = del_box() if key == 'del' else info_box(); img[:, :box - 2] = word[:, :box - 2]
    return img


def encode11(px, w, h):
    toks = []; i = 0
    while i < len(px):
        v = px[i]; r = 1
        while r < 16 and i + r < len(px) and px[i + r] == v: r += 1
        toks.append(v << 4 | (r - 1)); i += r
    out = bytearray([(h - 1) & 255, ((h - 1) >> 8 & 3) | (((w - 1) & 15) << 4), ((w - 1) >> 4) & 63, 11])
    for k in range(0, len(toks), 5):
        word = 0
        for s, t in enumerate(toks[k:k + 5]): word |= t << (12 * s)
        out += word.to_bytes(8, 'little')
    return bytes(out)


PAGES = ['Hue', 'Luminance', 'Extras', 'Film']           # streams 1..4 = pages Hue, Luminance (v0.24 film test 10; before: Light), Extras (v0.20; before: WB/BW), Film (v0.20; before: Looks, Profiles)
SKIP = {'Extras', 'Film'}   # v0.26: Extras (hidden since v0.24) left out too: room in GUIDES.BIN
TONES = ['Shadows', 'Highlights']   # v0.26 TONES.BIN (--tones): the split toning pages' guides
_SKIP_NOTE = None   # v0.24 film test 10: the Film page is hidden (editor.s W_FILM 0): its stream left out (length 0, the
                  # camera's own guide there) to keep GUIDES.BIN under the loader's 16 KB with "Luminance"; put it back with the page

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('out'); ap.add_argument('--preview'); ap.add_argument('--tones')
    a = ap.parse_args()
    if a.tones:   # 'OM3S' | u32 total | u32 CRC-32 of bytes 12.. | u32 s1 | u32 s2 | stream 1 | pad 4 | stream 2
        ts = [encode11(bytes(build(t).flatten()), W, H) for t in TONES]
        body = struct.pack('<II', *map(len, ts)) + ts[0] + bytes((-len(ts[0])) % 4) + ts[1]
        body += bytes((-len(body)) % 4)
        open(a.tones, 'wb').write(b'OM3S' + struct.pack('<II', 12 + len(body), zlib.crc32(body) & 0xffffffff) + body)
        print(a.tones, 12 + len(body), 'bytes')
    imgs = [build(t) for t in PAGES]
    st = [b'' if t in SKIP else encode11(bytes(i.flatten()), W, H) for t, i in zip(PAGES, imgs)]
    body = struct.pack('<HHIIII', W, H, *map(len, st[:4]))
    for s in st: body += s + bytes((-len(s)) % 4)
    body += bytes((-len(body)) % 4)
    out = b'OM3G' + struct.pack('<II', 12 + len(body), zlib.crc32(body) & 0xffffffff) + body
    open(a.out, 'wb').write(out); print(a.out, len(out), 'bytes')
    if a.preview:
        pal = {0: (30, 30, 60), 7: (20, 20, 20), 9: (60, 60, 60), 10: (255, 255, 255), 11: (200, 200, 200), 12: (160, 160, 160)}
        sheet = Image.new('RGB', (W * 3, H * 3 * len(imgs)))
        for k, i in enumerate(imgs):
            rgb = Image.new('RGB', (W, H)); rgb.putdata([pal.get(int(v), (255, 0, 255)) for v in i.flatten()])
            sheet.paste(rgb.resize((W * 3, H * 3), Image.NEAREST), (0, k * H * 3))
        sheet.save(a.preview)
