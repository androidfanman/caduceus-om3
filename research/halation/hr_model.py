"""Halation Radius (hr_run, Tight / Medium / Wide): the exact integer model of the firmware pass, step for step as
editor.s does it. Bloom (radius 0) is v0.40's hl_run and its model.py, unchanged.

Buffer as v0.40 (YCbYCr 4:2:2, W pixels a row, a multiple of 4, `pitch` bytes a row). Radius r = 1, 2, 3.
  grid   16 x 16 px cells (8 pairs x 16 rows): GW = (W + 15) >> 4, GH = (H + 15) >> 4; Bloom's 64 px grid
         GW6 = (W + 63) >> 6, GH6 = (H + 63) >> 6 for the bright-frame decision
  A.     rows 0, 4, 8, ..: per cell Ef += sum of max(0, Y0 - T), Qf += sum of Y0 >> 2 (u16)
  w      B = 4 Qf // N (N = the cell's sampled rows x its pairs; a full cell 32: Qf >> 3), w = min(255, 2 (255 - B))
  skip   E6[i][j] = 2 x the sum of the 4 x 4 cells' Ef (Bloom's 64 px excess at pass A's every 2nd row, here from every
         4th); v6 = (blur(E6, 3) (256 - MIX) + blur(E6, 10) MIX + 128) >> 8; u6 by v0.40's table; n = cells with
         u6 >= COV_U; n >= n_hi: no halation; sc as v0.40
  B.     v = (32 Ef GAIN + 128) >> 8; across every row: forward v[i] = max(v[i], (v[i-1] D) >> 8), then back the same
         from the right; then down every column, forward and back; then one [1 2 1] pass across and down (v0.40's
         hl_blur, edges repeated, rounded)
  map    u by v0.40's table; g = (((u gmax) >> 8) sc) >> 8
  C.     bands: rows 0..7 (cell row 0 alone), rows 8 + 16 k .. 23 + 16 k (cell rows k, k + 1; wy = (y - 8) & 15),
         then the last rows (cell row GH - 1 alone); segments j = 0..GW of the pairs [0, 4), [8 j - 4, 8 j + 4),
         [8 GW - 4, pairs); a segment's ends lerped down ((16 a + (b - a) wy + 8) >> 4), its pairs across
         ((8 a + 4 + i (b - a)) >> 3); v0.40's paint; pairs with g <= 1 left as they are.
GAIN = 66 (the owner's research tune_one.py, Medium's edge glow matched to Bloom's); D = 81, 144, 192 (round(256 exp(-16 ln 10 / R)) for
R = 32, 64, 128 px: the glow falls to 10 % at R px)."""
import sys, pathlib
import numpy as np
UP = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(UP / 'research/halation'))
sys.path.insert(0, str(UP / 'firmware'))
import model  # noqa: E402  (v0.40's)
from halation import T, BLUR, BLUR2, MIX, GMAX, KY, KCB, KCR, WMUL, COV_U, COV_LO, COV_HI, tables  # noqa: E402

GAIN = 66
D = {1: 81, 2: 144, 3: 192}
RADIUS_PX = {1: 32, 2: 64, 3: 128}
MAXC = 81920                       # cells the work area holds (5184 x 3888 = 78,732)
_lo, _hi = (np.frombuffer(x, np.uint8).astype(np.int64) for x in tables())


def u_of(v):
    return np.where(v < 1024, _lo[np.minimum(v >> 2, 255)], _hi[np.minimum(v >> 8, 255)])


def fits(W, H):
    return ((W + 15) >> 4) * ((H + 15) >> 4) <= MAXC


def halate(buf, W, H, pitch, level, r):
    """In place. -> 'off' (bright frame), 'none' (no g >= 2) or 'done'."""
    b = np.asarray(buf, np.uint8)
    P = b[:H * pitch].reshape(H, pitch)[:, :2 * W].reshape(H, W // 2, 4)
    pairs = W // 2
    GW, GH = (W + 15) >> 4, (H + 15) >> 4
    GW6, GH6 = (W + 63) >> 6, (H + 63) >> 6
    ys = np.arange(0, H, 4)
    y0 = P[ys, :, 0].astype(np.int64)
    cs = np.arange(0, pairs, 8)
    exc = np.add.reduceat(np.where(y0 > T, y0 - T, 0), cs, axis=1)
    qc = np.add.reduceat(y0 >> 2, cs, axis=1)
    Ef = np.zeros((GH, GW), np.int64); Qf = np.zeros((GH, GW), np.int64)
    np.add.at(Ef, ys >> 4, exc); np.add.at(Qf, ys >> 4, qc)
    assert Ef.max() < 65536 and Qf.max() < 65536
    rows = (np.minimum(16, H - 16 * np.arange(GH)) + 3) >> 2
    pc = np.minimum(8, pairs - 8 * np.arange(GW))
    N = rows[:, None] * pc[None, :]
    Bm = np.where(N == 32, Qf >> 3, (4 * Qf) // N)
    w = np.minimum(255, WMUL * (255 - Bm))
    # Bloom's bright-frame decision
    E6 = np.zeros((GH6, GW6), np.int64)
    np.add.at(E6, (np.arange(GH)[:, None] >> 2, np.arange(GW)[None, :] >> 2), Ef)
    E6 = 2 * E6
    assert E6.max() < 65536
    v6 = (model.blur_n(E6, BLUR) * (256 - MIX) + model.blur_n(E6, BLUR2) * MIX + 128) >> 8
    n = int((u_of(v6) >= COV_U).sum()); cells6 = GW6 * GH6
    n_lo, n_hi = cells6 * COV_LO // 100, cells6 * COV_HI // 100
    if n >= n_hi:
        return 'off'
    sc = 256 if n <= n_lo else ((n_hi - n) * 256) // (n_hi - n_lo)
    # B: the peak-preserving spread
    d = D[r]
    v = (32 * Ef * GAIN + 128) >> 8
    for i in range(1, GW):
        v[:, i] = np.maximum(v[:, i], (v[:, i - 1] * d) >> 8)
    for i in range(GW - 2, -1, -1):
        v[:, i] = np.maximum(v[:, i], (v[:, i + 1] * d) >> 8)
    for i in range(1, GH):
        v[i] = np.maximum(v[i], (v[i - 1] * d) >> 8)
    for i in range(GH - 2, -1, -1):
        v[i] = np.maximum(v[i], (v[i + 1] * d) >> 8)
    v = model.blur_n(v, 1)
    G = (((u_of(v) * GMAX[level]) >> 8) * sc) >> 8
    if G.max() < 2:
        return 'none'
    # C: lerp and paint
    f = np.arange(H) - 8
    r0 = np.clip(f >> 4, 0, GH - 1); r1 = np.minimum(r0 + 1, GH - 1); wy = (f & 15)[:, None]
    def down(A):
        mid = (16 * A[r0] + (A[r1] - A[r0]) * wy + 8) >> 4
        out = np.where((f < 0)[:, None], A[0][None, :], mid)
        return np.where(((f >= 0) & ((f >> 4) >= GH - 1))[:, None], A[GH - 1][None, :], out)
    q = np.arange(pairs); qq = np.maximum(q - 4, 0)
    k = np.minimum(qq >> 3, GW - 1); i = qq & 7; k1 = np.minimum(k + 1, GW - 1)
    def across(L):
        v_ = np.where(k >= GW - 1, L[:, [GW - 1]], (8 * L[:, k] + 4 + i * (L[:, k1] - L[:, k])) >> 3)
        return np.where(q < 4, L[:, [0]], v_)
    g = across(down(G)); wp = across(down(w))
    gm = np.where(g > 1, g, 0)
    c = (gm * wp) >> 8
    Y0 = P[..., 0].astype(np.int64); Y1 = P[..., 2].astype(np.int64)
    Cb = P[..., 1].astype(np.int64); Cr = P[..., 3].astype(np.int64)
    P[..., 0] = Y0 + (((255 - Y0) * gm * KY) >> 16)
    P[..., 2] = Y1 + (((255 - Y1) * gm * KY) >> 16)
    P[..., 1] = np.clip(Cb + ((c * KCB) >> 8), 0, 255)
    P[..., 3] = np.clip(Cr + ((c * KCR) >> 8), 0, 255)
    return 'done'
