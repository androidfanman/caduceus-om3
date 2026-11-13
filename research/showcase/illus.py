"""Illustrations for the two settings the Control Panel preview doesn't model: Noise Filter and Vignette Correction.
usage: illus.py SAMPLES_DIR OUT_DIR"""
import sys, numpy as np
from PIL import Image, ImageFilter
src, out = sys.argv[1], sys.argv[2]
rng = np.random.default_rng(7)
# Noise Filter: a dim crop with high-ISO-like noise (Off) and the same smoothed (High)
im = Image.open(f'{src}/bluehour.jpg').convert('RGB').crop((560, 260, 1460, 860))
a = np.asarray(im).astype(np.float32) / 255
a = a ** 1.0
lum = rng.normal(0, 0.055, a.shape[:2])[..., None]
chroma = rng.normal(0, 0.035, a.shape)
chroma = np.asarray(Image.fromarray(((chroma + .5) * 255).clip(0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))).astype(np.float32) / 255 - .5
noisy = (a + lum * (0.4 + 0.6 * np.sqrt(1 - a.mean(-1, keepdims=True))) + chroma * 1.6).clip(0, 1)
off = Image.fromarray((noisy * 255).astype(np.uint8))
y, cb, cr = off.convert('YCbCr').split()
y = y.filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.GaussianBlur(0.9))
cb, cr = cb.filter(ImageFilter.GaussianBlur(3)), cr.filter(ImageFilter.GaussianBlur(3))
high = Image.merge('YCbCr', (y, cb, cr)).convert('RGB')
off.save(f'{out}/noise-a.jpg', quality=90); high.save(f'{out}/noise-b.jpg', quality=90)
# Vignette Correction: Off = the lens's natural fall-off (about 1 EV in the corners), On = even
im = Image.open(f'{src}/meadow.jpg').convert('RGB'); im = im.resize((1000, round(im.height * 1000 / im.width)), Image.LANCZOS)
a = np.asarray(im).astype(np.float32) / 255
h, w = a.shape[:2]; yy, xx = np.mgrid[0:h, 0:w]
r = np.hypot((xx - w / 2) / (w / 2), (yy - h / 2) / (h / 2)) / np.sqrt(2)
lin = a ** 2.2 * (np.cos(np.arctan(r * 0.95)) ** 4)[..., None]
Image.fromarray((lin ** (1 / 2.2) * 255).clip(0, 255).astype(np.uint8)).save(f'{out}/vignette-a.jpg', quality=80)
im.save(f'{out}/vignette-b.jpg', quality=80)
print('ok')
