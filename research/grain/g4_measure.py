"""Grain g4 against g3 and g2c (research/NOTES.md "Better grain g4"), from the exact model (tile_model.py).

Per size and tile: Y mean / sigma, neighbour correlations (sideways, down, diagonal, 2 sideways), the box filter's
mark (power along the axes / along the diagonals at 0.35..0.45 cycle / px: >> 1 = straight-edged clumps), and repeats
(the largest autocorrelation away from 0: over the whole tile half, and in 640 x 640 windows as cad measured the
camera photos). Usage: python3 research/grain/g4_measure.py [seed ...]
"""
import sys
import numpy as np
import tile_model as tm


def neigh(y):
    a = y - y.mean()
    v = (a * a).mean()
    return [(a * np.roll(np.roll(a, -dy, 0), -dx, 1)).mean() / v for dy, dx in ((0, 1), (1, 0), (1, 1), (0, 2))]


def boxmark(y):
    a = y - y.mean()
    p = np.abs(np.fft.fft2(a)) ** 2
    fy, fx = np.fft.fftfreq(a.shape[0])[:, None], np.fft.fftfreq(a.shape[1])[None, :]
    r, th = np.hypot(fy, fx), np.degrees(np.arctan2(np.abs(fy), np.abs(fx)))
    ring = (r >= 0.35) & (r < 0.45)
    return p[ring & ((th < 10) | (th > 80))].mean() / p[ring & (np.abs(th - 45) < 10)].mean()


def repeats_tile(y, excl=6):
    a = y - y.mean()
    ac = np.fft.fftshift(np.fft.irfft2(np.abs(np.fft.rfft2(a)) ** 2, s=a.shape)) / a.size / a.var()
    cy, cx = a.shape[0] // 2, a.shape[1] // 2
    ac[cy - excl:cy + excl + 1, cx - excl:cx + excl + 1] = 0
    return ac.max()


def repeats_640(y, nwin=6, n=640, excl=6):
    big, rng, out = np.tile(y, (3, 3)), np.random.default_rng(1), []
    for _ in range(nwin):
        y0, x0 = rng.integers(0, y.shape[0]), rng.integers(0, y.shape[1])
        a = big[y0:y0 + n, x0:x0 + n].copy()
        a -= a.mean()
        ac = np.fft.fftshift(np.fft.irfft2(np.abs(np.fft.rfft2(a, s=(2 * n, 2 * n))) ** 2, s=(2 * n, 2 * n)))
        ac /= a.size * a.var()
        ac[n - excl:n + excl + 1, n - excl:n + excl + 1] = 0
        out.append(ac.max())
    return max(out)


def main():
    seeds = [int(s, 0) for s in sys.argv[1:]] or [0x12345678]
    tiles = (('g2c', tm.full_tile), ('g3', tm.fast_tile), ('g4', tm.g4_tile), ('g4 across an edge', tm.g4_full))
    for w, name in ((1, 'Fine'), (2, 'Medium'), (3, 'Coarse')):
        for label, f in tiles:
            for sb in seeds:
                t = f(w, sb)[:768]
                y = t[:, 0::2].astype(np.float64)
                print('%-6s %-17s %#010x  Y %5.2f / %5.2f  Cb %6.2f / %5.2f  neighbours %s  box mark %6.2f  '
                      'repeats tile %.3f, 640 %.3f' % (name, label, sb, y.mean(), y.std(), t[:, 1::4].mean(),
                                                       t[:, 1::4].std(), ' '.join('%.2f' % v for v in neigh(y)),
                                                       boxmark(y), repeats_tile(y), repeats_640(np.vstack([y, y]))))


if __name__ == '__main__':
    main()
