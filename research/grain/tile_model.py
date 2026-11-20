"""Exact integer model of our colour grain tile (firmware/src/editor.s `tg_fill`, better grain g1..g4).

The tile: 1536 x 1536 YCbYCr 4:2:2 (3072 bytes a row), Y = 48 + noise, Cb / Cr = 128 + noise, each noise a w x w box
sum of uniform random bytes (w = the Grain Size 1..3, Cb / Cr (w + 1) // 2 at half width and half height), seamless in
both directions. Row y + 768 = row y.

- `full_tile(w, sb)`: g1..g2c, and g3 when the tile is across a 128 MB window edge: all 768 rows by the box filter.
- `fast_tile(w, sb)`: g3 (2026-11-17): a band of 128 rows by the box filter (period 128), then rows 128..767 from 20
  strips of 32 band rows each, turned round by a random sx and crossfaded over their first B = 2 w rows from the strip
  before (cos / sin weights, so the grain keeps its strength); the last strip is crossfaded into rows 0..B - 1.

- g4 (2026-11-19, rounder clumps and fewer repeats): `g4_tile(w, sb)` (the whole tile in one window segment) and
  `g4_full(w, sb)` (across an edge). See the g4 part below.

`sb` is the tile's seed (`tg_sb`, read back from the camera code). Results are uint8 arrays (1536, 3072).
"""
import math
import numpy as np

M32 = 0xffffffff
KT = [14189, 7094, 4730, 3547, 2838]          # tg_kt: 16 / (73.9 w) x 65536
BAND, STRIP, STRIPS, SY_CHOICES = 128, 32, 20, 44
WT = {1: [(222, 128), (128, 222)],             # tg_wt: round(256 cos / sin ((i + 1) 90 / (B + 1) degrees)), B = 2 w
      2: [(243, 79), (207, 150), (150, 207), (79, 243)],
      3: [(250, 57), (231, 111), (200, 160), (160, 200), (111, 231), (57, 250)],
      4: [(252, 44), (241, 88), (222, 128), (196, 165), (165, 196), (128, 222), (88, 241), (44, 252)],
      5: [(253, 36), (246, 72), (233, 106), (215, 138), (193, 168), (168, 193), (138, 215), (106, 233), (72, 246),
          (36, 253)]}
MID = np.tile(np.array([48, 128, 48, 128], np.int64), 768)


def seed(row, ch, sb):
    """tg_seed: row, channel (0 Y, 1 Cb, 2 Cr, 3 g3's strips) -> a 32-bit stream seed, never 0."""
    d0 = ((row ^ (ch << 28)) * 0x9e3779b9) & M32
    d0 ^= sb
    d0 ^= d0 >> 16
    d0 = (d0 * 0x7feb352d) & M32
    d0 ^= d0 >> 15
    d0 = (d0 * 0x846ca68b) & M32
    d0 ^= d0 >> 16
    return d0 or 1


def rowbytes(s, n):
    """tg_col's bytes: xorshift32 (13, 17, 5) words, low byte first."""
    out = np.empty(n, np.int64)
    x = s
    for g in range(n // 4):
        x ^= (x << 13) & M32
        x ^= x >> 17
        x ^= (x << 5) & M32
        out[4 * g:4 * g + 4] = (x & 255, (x >> 8) & 255, (x >> 16) & 255, x >> 24)
    return out


def plane(n, period, w, ch, sb, base):
    """One plane, `period` rows (row period = row 0): column sums of w rows, a running sum of w along the row."""
    k = KT[w - 1]
    add = (base << 16) + 32768 - ((255 * w * w * k) >> 1)
    rows = [rowbytes(seed(j, ch, sb), n) for j in range(period)]
    out = np.empty((period, n), np.int64)
    c = sum(rows[j % period] for j in range(w))
    for y in range(period):
        cs = np.concatenate([[0], np.cumsum(np.concatenate([c, c[:w]]))])
        out[y] = np.clip((k * (cs[w:w + n] - cs[0:n]) + add) >> 16, 0, 255)
        c = c + rows[(y + w) % period] - rows[y]
    return out


def rows(w, sb, period):
    """`period` rows of the tile by the box filter, as bytes (period, 3072)."""
    wc = (w + 1) >> 1
    b = np.empty((period, 3072), np.int64)
    b[:, 0::2] = plane(1536, period, w, 0, sb, 48)
    b[:, 1::4] = np.repeat(plane(768, period // 2, wc, 1, sb, 128), 2, axis=0)
    b[:, 3::4] = np.repeat(plane(768, period // 2, wc, 2, sb, 128), 2, axis=0)
    return b


def full_tile(w, sb):
    t = rows(w, sb, 768).astype(np.uint8)
    return np.vstack([t, t])


def blend(p, n, c, s):
    """tg_bl: clamp(mid + ((c (p - mid) + s (n - mid) + 128) >> 8)), mid 48 (Y) / 128 (Cb, Cr)."""
    return np.clip(MID + ((c * (p - MID) + s * (n - MID) + 128) >> 8), 0, 255)


def strip(k, sb):
    """Strip k's first band row sy (even, 0..86) and its turn sx (bytes, a multiple of 4)."""
    h = seed(k, 3, sb)
    return 2 * (((h & 0xffff) * SY_CHOICES) >> 16), 4 * (((h >> 16) * 768) >> 16)


def fast_tile(w, sb):
    bd = rows(w, sb, BAND)
    t = np.zeros((768, 3072), np.int64)
    t[:BAND] = bd
    turn = lambda row, sx: np.roll(row, -sx)
    prow, psx = 0, 0                           # the band going on: its row 128 is row 0
    for k in range(STRIPS):
        sy, sx = strip(k, sb)
        r0 = BAND + STRIP * k
        for i in range(STRIP):
            t[r0 + i] = turn(bd[sy + i], sx)
        for i, (c, s) in enumerate(WT[w]):
            t[r0 + i] = blend(turn(bd[prow + i], psx), t[r0 + i], c, s)
        prow, psx = sy + STRIP, sx
    for i, (c, s) in enumerate(WT[w]):         # the tile's wrap: row 767 -> row 0
        t[i] = blend(turn(bd[prow + i], psx), t[i], c, s)
    t = t.astype(np.uint8)
    return np.vstack([t, t])


# ---- g4 (2026-11-19): rounder clumps (small round filters instead of the w x w box) and fewer repeats (the rows after
# the band made of 40 x 128 px blocks, some upside down, instead of full-width strips). research/NOTES.md "Better grain
# g4". Same tile format and levels as g1..g3: Y 48 sigma 16, Cb / Cr 128 sigma 16, seamless, row y + 768 = row y.
#
# The band: P rows (period P: row P = row 0) of each plane. Random bytes per plane row r from tg_seed(r, ch): xorshift32
# words, word g -> pixels 4g, 4g+1, 4g+2, 4g+3 = its bytes 0, 2, 1, 3 (so x & 0x00ff00ff and (x >> 8) & 0x00ff00ff are
# two pixels each, in order). Vertical v[y] = sum_j h[j] bytes[(y + j) mod P]; horizontal s[x] = sum_k h[k] v[x + k - 1]
# (x + k for a 1-tap h), wrapping round; value = max((K s + add) >> 16, 0) (never above 255). Chroma: half width and
# half height (chroma row m for rows 2m and 2m + 1), its own taps. Fine keeps single-pixel noise.
G4_SIZE = {1: ((1,), (1,), 0, 0),                  # Y taps, chroma taps, Bh (rows crossfaded), G (2-px groups a join)
           2: ((1, 3, 1), (1,), 4, 2),
           3: ((1, 3, 3, 1), (1, 3, 1), 6, 3)}
G4_BAND, G4_H, G4_W = 128, 40, 128                # band rows, strip rows, block width (px)
G4_NB, G4_NST = 1536 // G4_W, (768 - G4_BAND) // G4_H


def g4_k(h, mid):
    """tg_g4k: K = round(16 / (73.9 sum h^2) 65536) (sigma 16 from bytes of sigma 73.9), add = (mid << 16) + 32768 -
    ((255 (sum h)^2 K) >> 1)."""
    k = int(16 / (73.9 * sum(a * a for a in h)) * 65536 + 0.5)
    return k, (mid << 16) + 32768 - ((255 * sum(h) ** 2 * k) >> 1)


def g4_bytes(s, n):
    w = np.empty(n // 4, np.int64)
    x = s
    for g in range(n // 4):
        x ^= (x << 13) & M32
        x ^= x >> 17
        x ^= (x << 5) & M32
        w[g] = x
    out = np.empty(n, np.int64)
    out[0::4], out[1::4], out[2::4], out[3::4] = w & 255, (w >> 16) & 255, (w >> 8) & 255, w >> 24
    return out


def g4_plane(p, n, h, ch, sb, mid):
    rb = [g4_bytes(seed(r, ch, sb), n) for r in range(p)]
    k, add = g4_k(h, mid)
    off = 0 if len(h) == 1 else 1
    out = np.empty((p, n), np.int64)
    for y in range(p):
        v = sum(a * rb[(y + j) % p] for j, a in enumerate(h))
        s_ = sum(a * np.roll(v, off - j) for j, a in enumerate(h))        # v[x + j - off]
        out[y] = np.maximum((k * s_ + add) >> 16, 0)
    assert out.max() <= 255
    return out


def g4_band(w, sb, p):
    hy, hc = G4_SIZE[w][:2]
    b = np.empty((p, 3072), np.int64)
    b[:, 0::2] = g4_plane(p, 1536, hy, 0, sb, 48)
    b[:, 1::4] = np.repeat(g4_plane(p // 2, 768, hc, 1, sb, 128), 2, axis=0)
    b[:, 3::4] = np.repeat(g4_plane(p // 2, 768, hc, 2, sb, 128), 2, axis=0)
    return b


def g4_wt(b):
    """tg_g4w: B crossfade weights c, s = round(256 cos / sin ((i + 1) 90 / (B + 1) degrees))."""
    import math
    return [(int(256 * math.cos(math.radians((i + 1) * 90 / (b + 1))) + 0.5),
             int(256 * math.sin(math.radians((i + 1) * 90 / (b + 1))) + 0.5)) for i in range(b)]


def g4_strip(k, sb):
    """Strip k: x0 (px, even) and its blocks (sy (even), flip, sx (px, even))."""
    h = seed(k, 3, sb)
    bl = []
    for j in range(G4_NB):
        hb = seed((k << 4) | j, 4, sb)
        bl.append((2 * (((hb & 0xffff) * 64) >> 16), (hb >> 16) & 1, 2 * (((hb >> 17) * 768) >> 15)))
    return 2 * (((h & 0xffff) * 768) >> 16), bl


MID4 = np.array([48, 128, 48, 128], np.int64)


def g4_row(t, st, i, g):
    """Row i of strip st (i >= 40: the strip going on), its band rows read from the tile t's rows 0..127: block j =
    band row (sy + i) mod 128 (upside down: sy + 1 - i), from px x + sx; its first g groups (2 px) crossfaded from block
    j - 1 going on (Y per pixel over 2g steps, Cb / Cr per group over g)."""
    x0, bl = st
    src = [np.roll(t[((sy + 1 - i) if fl else (sy + i)) & (G4_BAND - 1)], -2 * sx) for sy, fl, sx in bl]
    row = np.empty(3072, np.int64)
    for j in range(G4_NB):
        b = (2 * (x0 + j * G4_W) + np.arange(2 * G4_W)) % 3072
        row[b] = src[j][b]
    wy, wc = g4_wt(2 * g), g4_wt(g)
    for j in range(G4_NB):
        for q in range(4 * g):
            b = (2 * (x0 + j * G4_W) + q) % 3072
            c, s_ = wy[q // 2] if q % 2 == 0 else wc[q // 4]
            m = MID4[q % 4]
            row[b] = min(max(m + ((c * (src[j - 1][b] - m) + s_ * (row[b] - m) + 128) >> 8), 0), 255)
    return row


def g4_tile(w, sb, band=None):
    """The fast way: band rows 0..127 (period 128); rows 128..767 = 16 strips of 40 rows, each 12 blocks of 128 px
    from a random x0; a strip's first Bh rows crossfaded from the strip before going on (strip 0: the band going on), at
    the end rows 0..Bh - 1 from the last strip going on (in order, reading the tile as it is then). band: g4_band
    (v0.40.1) or g6_band."""
    w = min(max(w, 1), 3)
    _, _, bh, g = G4_SIZE[w]
    wh = g4_wt(bh)
    t = np.zeros((768, 3072), np.int64)
    t[:G4_BAND] = (band or g4_band)(w, sb, G4_BAND)
    prev = None
    for k in range(G4_NST):
        st = g4_strip(k, sb)
        r0 = G4_BAND + G4_H * k
        for i in range(G4_H):
            t[r0 + i] = g4_row(t, st, i, g)
        for i in range(bh):
            p = t[i] if prev is None else g4_row(t, prev, G4_H + i, g)
            c, s_ = wh[i]
            t[r0 + i] = blend(p, t[r0 + i], c, s_)
        prev = st
    for i in range(bh):
        c, s_ = wh[i]
        t[i] = blend(g4_row(t, prev, G4_H + i, g), t[i], c, s_)
    t = t.astype(np.uint8)
    return np.vstack([t, t])


def g4_full(w, sb):
    """Across a window edge: all 768 rows the band's way (period 768)."""
    t = g4_band(min(max(w, 1), 3), sb, 768).astype(np.uint8)
    return np.vstack([t, t])


# ---- g6, grain colour (2026-11-19, after the owner's real-film comparison): v0.40.1's grain (g4) with the colour grain
# made on every row (full height: g4's chroma rows served two pixel rows, whose 2-row steps showed as bands in Coarse's
# colour spectrum, camera photos too) and the red-green colour weaker (Cr sigma 9, Cb 16: real colour film's is about
# 0.56 of the blue-yellow). Y, the strips, blocks, flips and crossfades as g4. Chroma row r (0..P - 1): random bytes
# tg_seed(r, 1 / 2), 768 samples; vertical taps on full rows, horizontal on the samples (2 px each). research/NOTES.md
# "Colour fix preview".
G6_C = {1: ((1, 1), (1,)), 2: ((1, 1), (1,)), 3: ((1, 3, 3, 1), (1, 6, 1))}   # (vertical, horizontal) taps
G6_SIG = (16, 9)                                                                # Cb, Cr sigma


def g6_k(hv, hh, sigma, mid=128):
    """tg_g4p's KC / AC (Cb) and KR / AR (Cr): K = round(sigma / (73.9 sqrt(sum k^2)) 65536) over the 2-D kernel,
    add = (mid << 16) + 32768 - ((255 (sum k) K) >> 1)."""
    k2 = sum(a * a for a in hv) * sum(a * a for a in hh)
    k = int(sigma / (73.9 * math.sqrt(k2)) * 65536 + 0.5)
    return k, (mid << 16) + 32768 - ((255 * sum(hv) * sum(hh) * k) >> 1)


def g6_cplane(p, hv, hh, ch, sb, sigma):
    rb = [g4_bytes(seed(r, ch, sb), 768) for r in range(p)]
    k, add = g6_k(hv, hh, sigma)
    off = 0 if len(hh) == 1 else 1
    out = np.empty((p, 768), np.int64)
    for y in range(p):
        v = sum(a * rb[(y + j) % p] for j, a in enumerate(hv))
        s_ = sum(a * np.roll(v, off - j) for j, a in enumerate(hh))        # v[x + j - off]
        out[y] = np.maximum((k * s_ + add) >> 16, 0)
    assert out.max() <= 255
    return out


def g6_band(w, sb, p):
    b = g4_band(w, sb, p)
    hv, hh = G6_C[w]
    b[:, 1::4] = g6_cplane(p, hv, hh, 1, sb, G6_SIG[0])
    b[:, 3::4] = g6_cplane(p, hv, hh, 2, sb, G6_SIG[1])
    return b


def g6_tile(w, sb):
    return g4_tile(w, sb, band=g6_band)


def g6_full(w, sb):
    """Across a window edge: all 768 rows the band's way (period 768)."""
    t = g6_band(min(max(w, 1), 3), sb, 768).astype(np.uint8)
    return np.vstack([t, t])
