#!/usr/bin/env python3
"""Film Rolls: the end-of-roll slip (owner, 2026-11-25: "Build the end slip"; the poll mock-up's screen 3). At the
roll's end the shooting screen's picture-mode label (the camera's "COLOR1" / our "FILM N") shows a slip, 352 x 64:
the camera's orange line on top and the length in big orange figures, "End of the roll" and "Shutter locked · press
OK to rewind" (OK there opens Picture Mode on the Film Roll row, where the roll is wound back; owner, test 22: the
text "needs to be changed" from test 21's "rewind on the Film Roll row"), on the camera's dark see-through panel colour
(palette 62). The card file widens the label's box to the slip's size, keeping its right edge
and middle (frblock.s fb_tic). Drawn here from scratch (DejaVu Sans Condensed); no camera graphics.
(Until test 21 the label showed a film window during the whole roll, "Portra 400" / "36 exp", in the same file. Owner,
test 21: "its pretty useless. I think you should just keep it as it works for standard .41b": taken out.)
Output: OM3MOD/FILMROLL/WINDOW.BIN, 'OM3W', u16 1, u16 n, n x {u32 offset, u32 length}, the OSD type-11 streams
(mkicons.encode11); entries 0..2 the slips of a 24 / 36 / 72 roll.
usage: mkwindow.py OUT.BIN [--preview PNG]"""
import struct, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'card'))
import mkicons

EXPS = (24, 36, 72)


# the slip (palette indices of the OSD palette, 0x614a67f0: 62 a dark grey at 80 %, 34 the camera's orange, darker
# oranges 102 / 17 / 18 and opaque greys for the letters' soft edges over the panel)
SW, SH, SBG = 352, 64, 62
FONT_DIR = '/usr/share/fonts/truetype/dejavu/'
GREYS = [(10, 254), (98, 235), (99, 198), (46, 178), (11, 170), (97, 147), (43, 115), (44, 90), (12, 85), (63, 71),
         (51, 60), (45, 40), (28, 32), (96, 23)]
ORANGES = [(0.86, 34), (0.64, 102), (0.42, 17), (0.18, 18)]


def ink(txt, cap, bold, sq=1.0):
    """txt's coverage (0..1) at a cap height of cap px, cropped left / right, and its cap's bottom row"""
    path = FONT_DIR + ('DejaVuSansCondensed-Bold.ttf' if bold else 'DejaVuSansCondensed.ttf')
    S = 4

    def draw(t, fs):
        im = Image.new('L', (fs * S * (len(t) + 2), fs * S * 2), 0)
        ImageDraw.Draw(im).text((fs * S, fs * S // 3), t, font=ImageFont.truetype(path, fs * S), fill=255)
        return im

    def caps(fs):
        r = np.nonzero((np.array(draw('H', fs)) > 128).any(axis=1))[0]
        return r.min() / S, r.max() / S

    fs = next(f for f in range(6, 80) if caps(f)[1] - caps(f)[0] + 0.25 >= cap)
    im = draw(txt, fs)
    xs = np.nonzero(np.array(im).any(axis=0))[0]
    im = im.crop((xs.min(), 0, xs.max() + 1, im.height))
    im = im.resize((max(1, round(im.width / S * sq)), round(im.height / S)), Image.LANCZOS)
    return np.array(im).astype(float) / 255, caps(fs)[1]


def paint(p, cov, x0, base, capbot, kind):
    """cov into the slip p, its cap's bottom on row base: orange, white or grey letters over the panel"""
    dy = int(round(base - capbot))
    for y, x in zip(*np.nonzero(cov >= 0.12)):
        yy, xx, c = y + dy, x + x0, cov[y, x]
        if not (0 <= yy < SH and 0 <= xx < SW):
            continue
        if kind == 'orange':
            p[yy, xx] = next(i for t, i in ORANGES + [(0, SBG)] if c >= t)
        else:
            v = 20 + c * ((254 if kind == 'white' else 205) - 20)
            p[yy, xx] = min(GREYS, key=lambda g: abs(g[1] - v))[0]


def slip(n):
    p = np.full((SH, SW), SBG, dtype=np.uint8)
    p[:3, :] = 34
    num, nb = ink(str(n), 34, True, 0.92)
    paint(p, num, 16, 51, nb, 'orange')
    x1 = 16 + num.shape[1] + 14
    t1, b1 = ink('End of the roll', 17, True, 0.95)
    paint(p, t1, x1, 30, b1, 'white')
    t2, b2 = ink('Shutter locked \u00b7 press OK to rewind', 11, False)
    paint(p, t2, x1, 50, b2, 'grey')
    assert x1 + max(t1.shape[1], t2.shape[1]) + 12 <= SW, n
    return p


def pictures():
    return [slip(e) for e in EXPS]


def write(path):
    blobs = [mkicons.encode11(p.flatten().tolist(), p.shape[1], p.shape[0]) for p in pictures()]
    n = len(blobs); at = 8 + 8 * n; idx = b''
    for b in blobs:
        b += b'\0' * (-len(b) % 8)
        idx += struct.pack('<II', at, len(b)); at += len(b)
    out = b'OM3W' + struct.pack('<HH', 1, n) + idx + b''.join(b + b'\0' * (-len(b) % 8) for b in blobs)
    Path(path).write_bytes(out)
    return max(len(b) for b in blobs), len(out)


# the OSD palette indices used, as om-emu draws them (preview only)
PAL = {62: (20, 20, 20, 204), 34: (255, 105, 0, 255), 102: (204, 84, 0, 255), 17: (170, 70, 0, 255),
       18: (85, 35, 0, 255)}
PAL.update({i: (v, v, v, 255) for i, v in GREYS})


def preview(png):
    ps = pictures()
    sheet = Image.new('RGB', (SW * 2 + 24, len(ps) * (SH * 2 + 12) + 12), (60, 70, 80))
    for k, p in enumerate(ps):
        im = Image.new('RGBA', (SW, SH), (0, 0, 0, 0))
        im.putdata([PAL[int(v)] for v in p.flatten()])
        im = im.resize((SW * 2, SH * 2), Image.NEAREST)
        sheet.paste(im, (12, 12 + k * (SH * 2 + 12)), im)
    sheet.save(png)


if __name__ == '__main__':
    print('WINDOW.BIN: largest picture %d B, file %d B' % write(sys.argv[1]))
    if '--preview' in sys.argv:
        preview(sys.argv[sys.argv.index('--preview') + 1])
