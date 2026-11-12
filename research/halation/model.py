#!/usr/bin/env python3
"""Caduceus for OM-3 halation (v0.28 h1): the exact integer model of the camera's pass (editor.s `hl_run`).

Our own code. The method (a threshold-excess grid of 64 px cells, a small blur, a soft knee, then a tint that fades on
bright pixels) follows Caduceus for the E-P7's halation by cakelesscoder (docs/HALATION_RED.md, camera-tested there);
the numbers and the code here are ours.

Buffer: YCbYCr 4:2:2 (byte 0 Y0, 1 Cb, 2 Y1, 3 Cr per pixel pair; Cb / Cr offset-binary, 128 neutral: camera probe h0,
2026-11-12), W pixels a row (a multiple of 4), H rows, `pitch` bytes from row to row.

  A. grid:  every 2nd row, every pair's Y0: e = Y0 - T if > T, summed (u16) into 64 x 64 px cells
  B. blur:  [1 2 1] / 4 (rounded, edges repeated), BLUR times across and BLUR times down
  map:      u = 255 v / (v + K) by table (`tables`);  g = (u gmax[level]) >> 8
  cap:      no halation when more than a third of the cells have g >= 16 (bright daylight stays fast)
  C. each row: the two nearest cell rows (centres 32 + 64 k) lerped (/64, rounded), then each pair's g lerped between
     cell centres (/32, rounded); with t = (255 - Y) g:  Y += (t kY) >> 16 (both pixels),
     Cb += (t0 kCb) >> 16, Cr += (t0 kCr) >> 16 (t0 from Y0, floor, clamped 0..255)
usage: model.py IN.png OUT.png LEVEL   (a preview on any picture: converted to the camera's buffer and back)
"""
import numpy as np

import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'firmware'))
from halation import T, K, BLUR, GMAX, KY, KCB, KCR, CAP_G, curve, tables   # one set of numbers for both


def grid_sum(buf, W, H, pitch):
    GW, GH = (W + 63) >> 6, (H + 63) >> 6
    g = np.zeros((GH, GW), np.int64)
    pairs = W // 2
    for y in range(0, H, 2):
        row = buf[y * pitch: y * pitch + 4 * pairs: 4].astype(np.int64)        # Y0 of each pair
        e = np.where(row > T, row - T, 0)
        cells = np.add.reduceat(e, np.arange(0, pairs, 32))
        g[y >> 6, :len(cells)] += cells
    assert g.max() < 65536
    return g


def blur(a):
    def b1(x, axis):
        lo = np.take(x, [0], axis=axis); hi = np.take(x, [x.shape[axis] - 1], axis=axis)
        p = np.concatenate([lo, x, hi], axis=axis)
        n = x.shape[axis]
        sl = lambda s, e: np.take(p, range(s, e), axis=axis)
        return (sl(0, n) + 2 * sl(1, n + 1) + sl(2, n + 2) + 2) >> 2
    for axis in (1,) * BLUR + (0,) * BLUR:
        a = b1(a, axis)
    return a


def grid(buf, W, H, pitch, level):
    v = blur(grid_sum(buf, W, H, pitch))
    lo, hi = (np.frombuffer(x, np.uint8).astype(np.int64) for x in tables())
    u = np.where(v < 1024, lo[np.minimum(v >> 2, 255)], hi[np.minimum(v >> 8, 255)])
    return (u * GMAX[level]) >> 8


def halate(buf, W, H, pitch, level):
    """buf: bytearray / uint8 array, changed in place. Returns 'capped', 'none' or 'done'."""
    b = np.frombuffer(buf, np.uint8) if not isinstance(buf, np.ndarray) else buf
    G = grid(b, W, H, pitch, level)
    GH, GW = G.shape
    if int((G >= CAP_G).sum()) * 3 > GW * GH:
        return 'capped'
    if not G.any():
        return 'none'
    pairs = W // 2
    p = np.arange(pairs)
    for y in range(H):
        f = y - 32
        if f < 0:
            line = G[0]
        else:
            r0, wy = f >> 6, f & 63
            if r0 >= GH - 1:
                line = G[GH - 1]
            else:
                line = (G[r0] * (64 - wy) + G[r0 + 1] * wy + 32) >> 6
        if not line.any():
            continue
        # each pair's g: left of the first centre line[0]; between centres k, k+1 lerped; after the last line[-1]
        gp = np.empty(pairs, np.int64)
        gp[:16] = line[0]
        q = p[16:] - 16
        k = np.minimum(q >> 5, GW - 1)
        i = q & 31
        k1 = np.minimum(k + 1, GW - 1)
        inner = (line[k] * (32 - i) + line[k1] * i + 16) >> 5
        gp[16:] = np.where(k >= GW - 1, line[GW - 1], inner)
        r = b[y * pitch: y * pitch + 4 * pairs].reshape(pairs, 4).astype(np.int64)
        t0 = (255 - r[:, 0]) * gp
        t1 = (255 - r[:, 2]) * gp
        r[:, 0] += (t0 * KY) >> 16
        r[:, 2] += (t1 * KY) >> 16
        r[:, 1] = np.clip(r[:, 1] + ((t0 * KCB) >> 16), 0, 255)
        r[:, 3] = np.clip(r[:, 3] + ((t0 * KCR) >> 16), 0, 255)
        b[y * pitch: y * pitch + 4 * pairs] = r.astype(np.uint8).reshape(-1)
    return 'done'


def to_buf(rgb):
    """RGB (H, W, 3) uint8 -> the camera's 4:2:2 buffer (JFIF YCbCr), W cut to a multiple of 4."""
    from PIL import Image
    H, W = rgb.shape[:2]; W -= W % 4
    ycc = np.asarray(Image.fromarray(rgb[:, :W]).convert('YCbCr'), np.int64)
    out = np.empty((H, W // 2, 4), np.uint8)
    out[..., 0] = ycc[:, 0::2, 0]; out[..., 2] = ycc[:, 1::2, 0]
    out[..., 1] = (ycc[:, 0::2, 1] + ycc[:, 1::2, 1] + 1) >> 1
    out[..., 3] = (ycc[:, 0::2, 2] + ycc[:, 1::2, 2] + 1) >> 1
    return out.reshape(-1), W, H, W * 2


def from_buf(buf, W, H, pitch):
    from PIL import Image
    r = np.frombuffer(bytes(buf), np.uint8)[:H * pitch].reshape(H, pitch)[:, :W * 2].reshape(H, W // 2, 4)
    ycc = np.empty((H, W, 3), np.uint8)
    ycc[:, 0::2, 0] = r[..., 0]; ycc[:, 1::2, 0] = r[..., 2]
    ycc[:, 0::2, 1] = ycc[:, 1::2, 1] = r[..., 1]
    ycc[:, 0::2, 2] = ycc[:, 1::2, 2] = r[..., 3]
    return np.asarray(Image.fromarray(ycc, 'YCbCr').convert('RGB'))


if __name__ == '__main__':
    import sys
    from PIL import Image
    rgb = np.asarray(Image.open(sys.argv[1]).convert('RGB'))
    buf, W, H, pitch = to_buf(rgb)
    print(halate(buf, W, H, pitch, int(sys.argv[3])))
    Image.fromarray(from_buf(buf, W, H, pitch)).save(sys.argv[2])
