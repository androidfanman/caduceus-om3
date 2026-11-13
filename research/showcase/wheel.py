"""Draw an approximate HSL wheel onto an emulator screenshot (om-emu does not draw the camera's wheel), plus our own
guide picture ("Hue [INFO]" ...) from card/mkguides.py in the box the emulator leaves blank.

The wheel follows the Control Panel's camera-style wheel (webapp/src/main.ts hslPanel): 12 colours as a ring, Yellow at
12 o'clock, clockwise; an outline through one corner per colour, out for +, in for -, the dashed circle = 0. Split
pages (Shadows / Highlights): strength 0..10 drawn at s - 5 on the -5..+5 scale, other colours at the inner edge.

usage: wheel.py IN.png OUT.png PAGE SEL v0,v1,...,v11 [GUIDE]
  PAGE = sat | hue | light | sh | hl;  SEL = selected colour index (0 = Yellow, clockwise);  GUIDE = text or '-'
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFont

COLS = ['#f2d600', '#f59a00', '#f05a00', '#e0102a', '#d4157a', '#7a33cc', '#1f5fe0', '#1d96e0', '#16c0d0', '#18b583',
        '#2fae3a', '#9cc414']
INK, DIM, BG = (241, 239, 233), (141, 138, 131), (12, 12, 12)
CX, CY, S = 430, 292, 1.434            # centre on the 900 x 600 screen; scale from the Control Panel's 290 px wheel
R0, R1, RZ, RB = 104 * S, 122 * S, 64 * S, 34 * S
SS = 3                                   # supersampling


def hexrgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def font(size):
    for p in ['/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf', '/System/Library/Fonts/Supplemental/Arial Bold.ttf']:
        try:
            return ImageFont.truetype(p, size)
        except OSError:
            pass
    return ImageFont.load_default()


def draw_wheel(im, page, sel, vals):
    split = page in ('sh', 'hl')
    W, H = im.size
    ov = Image.new('RGBA', (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    P = lambda a, r: ((CX + r * math.sin(a)) * SS, (CY - r * math.cos(a)) * SS)
    step = math.pi / 6
    # ring wedges
    for i, col in enumerate(COLS):
        a0, a1 = (i - .5) * step, (i + .5) * step
        pts = [P(a0 + (a1 - a0) * t / 16, R1) for t in range(17)] + [P(a1 - (a1 - a0) * t / 16, R0) for t in range(17)]
        rgb = hexrgb(col)
        d.polygon(pts, fill=rgb + (235 if i != sel else 255,), outline=BG + (255,), width=int(1.4 * SS))
    if sel is not None:                   # selected wedge: a light outline
        a0, a1 = (sel - .5) * step, (sel + .5) * step
        pts = [P(a0 + (a1 - a0) * t / 16, R1 + 1) for t in range(17)] + [P(a1 - (a1 - a0) * t / 16, R0 - 1) for t in range(17)]
        d.line(pts + [pts[0]], fill=INK + (255,), width=int(2.6 * SS), joint='curve')
    # spokes and the dashed zero circle
    for i in range(12):
        d.line([P(0, 0), P(i * step, R0 - 3)], fill=INK + (52,), width=SS)
    n = 72
    for k in range(n):
        if k % 2 == 0:
            d.arc([(CX - RZ) * SS, (CY - RZ) * SS, (CX + RZ) * SS, (CY + RZ) * SS], k * 360 / n, (k + 0.55) * 360 / n,
                  fill=DIM + (255,), width=int(1.3 * SS))
    # the outline through one corner per colour
    on = (lambda v: v - 5) if split else (lambda v: v)
    corners = [P(i * step, RZ + on(v) / 5 * RB) for i, v in enumerate(vals)]
    d.polygon(corners, fill=INK + (34,))
    d.line(corners + [corners[0]], fill=INK + (255,), width=int(2.2 * SS), joint='curve')
    for i, (x, y) in enumerate(corners):
        r = (7.5 if i == sel else 5) * SS
        d.ellipse([x - r, y - r, x + r, y + r], fill=hexrgb(COLS[i]) + (255,), outline=(INK if i == sel else BG) + (255,), width=int(2 * SS))
    # numbers outside the ring for the colours that are changed
    f = font(int(19 * SS))
    for i, v in enumerate(vals):
        if v:
            txt = (str(v) if v >= 10 else f'+{v}') if split else (f'+{v}' if v > 0 else f'−{-v}')
            x, y = P(i * step, R1 + 19)
            d.text((x, y), txt, font=f, fill=INK + (255,), anchor='mm')
    ov = ov.resize((W, H), Image.LANCZOS)
    im.alpha_composite(ov)


def draw_guide(im, txt):
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '../../card'))
    import mkguides
    px = mkguides.build(txt)
    pal = {7: (16, 16, 16), 9: (70, 70, 70), 10: (248, 248, 248), 11: (196, 196, 196), 12: (150, 150, 150)}
    h, w = px.shape
    g = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    g.putdata([pal[int(v)] + (255,) if int(v) in pal else (0, 0, 0, 0) for v in px.flatten()])
    # the emulator's blank box: 361..539 x 528..577; the stock "Color All [INFO]" sits in the same place
    im.alpha_composite(Image.new('RGBA', (180, 52), (12, 12, 12, 255)), (360, 527))
    im.alpha_composite(g, (362, 528))


if __name__ == '__main__':
    src, dst, page, sel, vals = sys.argv[1:6]
    guide = sys.argv[6] if len(sys.argv) > 6 and sys.argv[6] != '-' else None
    im = Image.open(src).convert('RGBA')
    draw_wheel(im, page, int(sel), [int(v) for v in vals.split(',')])
    if guide:
        draw_guide(im, guide)
    im.convert('RGB').save(dst)
