"""Convert session_ed1.mjs 'shot:' PNGs (bytes = Y, Cb, Cr) to real RGB (om-emu A9: inverse full-range BT.601)."""
import sys
import numpy as np
from PIL import Image

def convert(src, dst):
    a = np.asarray(Image.open(src).convert('RGB')).astype(np.int64)
    y, cb, cr = a[..., 0], a[..., 1] - 128, a[..., 2] - 128
    r = y + ((91881 * cr + 32768) >> 16)
    g = y + ((-22554 * cb - 46802 * cr + 32768) >> 16)
    b = y + ((116130 * cb + 32768) >> 16)
    out = np.clip(np.stack([r, g, b], -1), 0, 255).astype(np.uint8)
    Image.fromarray(out).save(dst)

if __name__ == '__main__':
    for p in sys.argv[1:]:
        convert(p, p.replace('.png', '.rgb.png'))
