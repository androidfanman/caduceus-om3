#!/usr/bin/env python3
"""Caduceus for OM-3 halation (v0.28 h4): the exact integer model of the camera's pass (editor.s `hl_run`).

Our own code. The method (a threshold-excess grid of 64 px cells, a small blur, a soft knee, then a tint that fades on
bright pixels) follows Caduceus for the E-P7's halation by cakelesscoder (docs/HALATION_RED.md, camera-tested there);
the numbers and the code here are ours.

Buffer: YCbYCr 4:2:2 (byte 0 Y0, 1 Cb, 2 Y1, 3 Cr per pixel pair; Cb / Cr offset-binary, 128 neutral: camera probe h0,
2026-11-12), W pixels a row (a multiple of 4), H rows, `pitch` bytes from row to row.

  A. grids: every 2nd row, every pair's Y0: e = Y0 - T if > T summed (u16) into 64 x 64 px cells, and Y0 >> 2
     summed into a second grid; the cell's mean B = (4 sum) // samples
  B. blur:  [1 2 1] / 4 (rounded, edges repeated) BLUR times across and down (tight) and BLUR2 times (broad),
            mixed v = (tight (256 - MIX) + broad MIX + 128) >> 8 (h4)
  map:      u = 255 v / (v + K) by table (`tables`); n = cells with u >= COV_U: none when n >= COV_HI % of the
            cells, full strength up to COV_LO %, in between sc = ((n_hi - n) 256) // (n_hi - n_lo);
            g = (((u gmax[level]) >> 8) sc) >> 8;  w = min(255, WMUL (255 - B))
  C. each row: g and w each lerped between the two nearest cell rows (centres 32 + 64 k, /64 rounded) and then
     between cell centres per pair (/32 rounded); Y += ((255 - Y) g kY) >> 16 (both pixels);
     with c = (g w) >> 8:  Cb += (c kCb) >> 8, Cr += (c kCr) >> 8 (floor, clamped 0..255)
usage: model.py IN.png OUT.png LEVEL   (a preview on any picture: converted to the camera's buffer and back)
"""
import numpy as np

import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'firmware'))
from halation import T, K, BLUR, BLUR2, MIX, GMAX, KY, KCB, KCR, WMUL, COV_U, COV_LO, COV_HI, curve, tables   # one set of numbers for both


def grid_sums(buf, W, H, pitch):
    """A: the threshold-excess grid E (u16) and the cell brightness B (mean Y0, from Y0 >> 2 sums)."""
    GW, GH = (W + 63) >> 6, (H + 63) >> 6
    E = np.zeros((GH, GW), np.int64); Q = np.zeros((GH, GW), np.int64); N = np.zeros((GH, GW), np.int64)
    pairs = W // 2
    starts = np.arange(0, pairs, 32)
    ones = np.ones(pairs, np.int64)
    for y in range(0, H, 2):
        row = buf[y * pitch: y * pitch + 4 * pairs: 4].astype(np.int64)        # Y0 of each pair
        E[y >> 6] += np.add.reduceat(np.where(row > T, row - T, 0), starts)
        Q[y >> 6] += np.add.reduceat(row >> 2, starts)
        N[y >> 6] += np.add.reduceat(ones, starts)
    assert E.max() < 65536 and Q.max() < 65536
    return E, (4 * Q) // N


def blur_n(a, passes):
    def b1(x, axis):
        lo = np.take(x, [0], axis=axis); hi = np.take(x, [x.shape[axis] - 1], axis=axis)
        p = np.concatenate([lo, x, hi], axis=axis)
        n = x.shape[axis]
        sl = lambda s, e: np.take(p, range(s, e), axis=axis)
        return (sl(0, n) + 2 * sl(1, n + 1) + sl(2, n + 2) + 2) >> 2
    for axis in (1,) * passes + (0,) * passes:
        a = b1(a, axis)
    return a


def blur(a):
    """h4: a tight layer (BLUR passes) and a broad one (BLUR2), mixed: a long, soft tail."""
    return (blur_n(a, BLUR) * (256 - MIX) + blur_n(a, BLUR2) * MIX + 128) >> 8


def grids(buf, W, H, pitch, level):
    """-> (G, Wc) or None (too much of the frame is bright)."""
    E, B = grid_sums(buf, W, H, pitch)
    v = blur(E)
    lo, hi = (np.frombuffer(x, np.uint8).astype(np.int64) for x in tables())
    u = np.where(v < 1024, lo[np.minimum(v >> 2, 255)], hi[np.minimum(v >> 8, 255)])
    cells = u.size
    n = int((u >= COV_U).sum())
    n_lo, n_hi = cells * COV_LO // 100, cells * COV_HI // 100
    if n >= n_hi:
        return None
    sc = 256 if n <= n_lo else ((n_hi - n) * 256) // (n_hi - n_lo)
    G = (((u * GMAX[level]) >> 8) * sc) >> 8
    return G, np.minimum(255, WMUL * (255 - B))


def _rows(A, y):
    GH = A.shape[0]
    f = y - 32
    if f < 0:
        return A[0]
    r0, wy = f >> 6, f & 63
    if r0 >= GH - 1:
        return A[GH - 1]
    return (A[r0] * (64 - wy) + A[r0 + 1] * wy + 32) >> 6


def _pairs(line, pairs):
    GW = len(line)
    gp = np.empty(pairs, np.int64)
    gp[:16] = line[0]
    q = np.arange(16, pairs) - 16
    k = np.minimum(q >> 5, GW - 1)
    i = q & 31
    k1 = np.minimum(k + 1, GW - 1)
    gp[16:] = np.where(k >= GW - 1, line[GW - 1], (line[k] * (32 - i) + line[k1] * i + 16) >> 5)
    return gp


def halate(buf, W, H, pitch, level):
    """buf: bytearray / uint8 array, changed in place. Returns 'off' (bright frame), 'none' or 'done'."""
    b = np.frombuffer(buf, np.uint8) if not isinstance(buf, np.ndarray) else buf
    r = grids(b, W, H, pitch, level)
    if r is None:
        return 'off'
    G, Wc = r
    if not G.any():
        return 'none'
    pairs = W // 2
    for y in range(H):
        gl = _rows(G, y)
        if not gl.any():
            continue
        g = _pairs(gl, pairs)
        w = _pairs(_rows(Wc, y), pairs)
        rr = b[y * pitch: y * pitch + 4 * pairs].reshape(pairs, 4).astype(np.int64)
        c = (g * w) >> 8
        rr[:, 0] += ((255 - rr[:, 0]) * g * KY) >> 16
        rr[:, 2] += ((255 - rr[:, 2]) * g * KY) >> 16
        rr[:, 1] = np.clip(rr[:, 1] + ((c * KCB) >> 8), 0, 255)
        rr[:, 3] = np.clip(rr[:, 3] + ((c * KCR) >> 8), 0, 255)
        b[y * pitch: y * pitch + 4 * pairs] = rr.astype(np.uint8).reshape(-1)
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
