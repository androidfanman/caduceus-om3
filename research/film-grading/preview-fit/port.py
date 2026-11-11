# Python port of webapp/src/preview.ts colour path (WB, 12-sector engine, split bend) with tunable constants. No tone.
import numpy as np
CENTRE = np.array([12197, 9466, 8192, 6736, 3095, 30401, 28945, 27489, 24212, 20753, 16111, 15019]) / 32768 * 360
WIDTH = np.array([3823, 5461, 3959, 2685, 5006, 9057, 6872, 2867, 4642, 6690, 8055, 5643]) / 32768 * 360
OLD = dict(gp=np.array([240, 240, 240, 256, 369, 328, 382, 382, 300, 615, 400, 656], float),
           gn=np.array([385, 385, 395, 493, 513, 395, 385, 385, 395, 395, 395, 395], float),
           hp=np.full(12, 5.5), hn=np.full(12, 5.5), lscale=1.0,
           wab=np.array([0.015, 0.0, -0.015]), wgm=np.array([0.0, 0.015, 0.0]), split=1.0)
L_LUT = np.array([-300, -250, -200, -150, -100, -50, -25, 0, 25, 50, 100, 150, 200, 250, 300], float)
SPLIT_K = np.array([[7, 7, -57], [26, -4, -47], [37, -12, -33], [43, -18, -18], [39, -26, 29], [17, -19, 53],
  [-11, -5, 56], [-33, 9, 39], [-43, 18, 18], [-45, 24, -5], [-36, 25, -36], [-13, 17, -55]], float)
BINS = 720
def dec(x): return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)
def enc(x): x = np.clip(x, 0, 1); return np.where(x <= 0.0031308, 12.92 * x, 1.055 * x ** (1 / 2.4) - 0.055)
_h = (np.arange(BINS) + 0.5) * (360 / BINS)
_d = ((_h[:, None] - ((CENTRE + 15) % 360)[None] + 540) % 360) - 180
_w = np.maximum(0, np.cos(np.clip(_d / np.maximum(WIDTH, 1), -1, 1) * np.pi / 2)); _w = _w / _w.sum(1, keepdims=True)
def sector(hue, light, sat, p):
    hue = np.asarray(hue, float); sat = np.asarray(sat, float); light = np.asarray(light, float)
    sc = sat * np.where(sat >= 0, p['gp'], p['gn']) / 5 * 1.5
    hs = hue * np.where(hue >= 0, p['hp'], p['hn'])
    l = L_LUT[np.clip(light, -7, 7).astype(int) + 7] * p['lscale']
    return np.clip(1 + _w @ sc / 1000, 0, 3), np.radians(_w @ hs), (_w @ l) / 4096
def bend(img, sp, s):
    ks = SPLIT_K[sp[0]] * sp[1] * s; kh = SPLIT_K[sp[2]] * sp[3] * s
    t = np.arange(256) * 4095 / 255; r = 4095 - t; ws = t * r / 4096 * r / 4096; wh = t * t / 4096 * r / 4096
    out = img.copy()
    for c in range(3):
        lut = np.maximum.accumulate(np.clip(t + (ks[c] * ws + kh[c] * wh) / 256, 0, 4095)) / 4095
        x = np.clip(img[:, c] * 255, 0, 255); out[:, c] = np.interp(x, np.arange(256), lut)
    return out
def render(rgb8, look, p=OLD):
    """rgb8: (n,3) 0..255; look: dict hue/light/sat (camera numbers), wb (ab, gm) or None, split tuple or None -> (n,3) 0..1"""
    x = np.asarray(rgb8, float) / 255
    ab, gm = look.get('wb') or (0, 0)
    if ab or gm:
        g = 1 + p['wab'] * ab + p['wgm'] * gm; x = enc(dec(x) * g)
    r, gg, b = x.T
    y0 = 0.299 * r + 0.587 * gg + 0.114 * b
    y = 0.299 * r + 0.587 * gg + 0.114 * b; cb = -0.168736 * r - 0.331264 * gg + 0.5 * b; cr = 0.5 * r - 0.418688 * gg - 0.081312 * b
    if look.get('tone') is not None: y = np.asarray(look['tone'])[np.clip(np.floor(y * 1024 + 0.5), 0, 1024).astype(int)]
    sm, sh, ls = sector(-np.asarray(look['hue'], float), look['light'], look['sat'], p)   # om3: hue negated
    ch = np.hypot(cb, cr); hd = np.degrees(np.arctan2(cr, cb)) % 360; bi = np.minimum(BINS - 1, (hd * BINS / 360).astype(int))
    ang = np.radians(hd) + sh[bi]; c2 = ch * sm[bi]; y = y + ls[bi] * np.minimum(1, ch / 0.25)
    cb = c2 * np.cos(ang); cr = c2 * np.sin(ang)
    out = np.clip(np.stack([y + 1.402 * cr, y - 0.344136 * cb - 0.714136 * cr, y + 1.772 * cb], 1), 0, 1)
    if look.get('split'): out = bend(out, look['split'], p['split'])
    return out
