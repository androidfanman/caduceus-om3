#!/usr/bin/env python3
"""v0.28 halation (h2): the tuning numbers and tables, shared by the firmware build (editor.s `hl_run`, via hl_tab.inc) and
the exact Python model (research/halation/model.py). Our own numbers; the method follows Caduceus for the E-P7's
halation by cakelesscoder (credited in NOTICE / README)."""
T = 200                            # threshold on Y: only Y above it lights the grid
K = 900                            # the soft curve u = 255 v / (v + K): no hard ceiling, so halos fade out
BLUR = 3                           # [1 2 1] passes across and down: the tight layer
BLUR2 = 10                         # h4 (owner: the halo stopped too suddenly): a broad layer for a long, soft tail
MIX = 128                          # the broad layer's share /256 (v = (tight (256 - MIX) + broad MIX + 128) >> 8)
GMAX = {1: 43, 2: 78, 3: 113, 4: 156, 5: 208}   # strength 1..5
KY, KCB, KCR = 44, -40, 60         # the tint at full glow: red-orange (Y by the pixel, Cb / Cr by the area)
WMUL = 2                           # h2: chroma weight = min(255, WMUL (255 - the cell's mean Y)): no speckle from grain
COV_U, COV_LO, COV_HI = 32, 25, 50 # h2: cells with u >= COV_U: up to COV_LO % full strength, fading to none at COV_HI %
                                   # 2026-11-20 (fernandezk26, camera-tested): 8 / 24 -> 25 / 50. A sunlit patch on a quarter to a
                                   # half of the cells turned Halation off; at 25 / 50 it keeps its edge glow, and foliage against
                                   # the sky (75 %) or a bright window (89 %) stays off (research/NOTES.md "Bright-frame limit 25 / 50")


def curve(v):
    return (255 * v + (v + K) // 2) // (v + K)


def tables():
    """u by table (no division on the camera): v < 1024 -> LO[v >> 2], else HI[min(255, v >> 8)]."""
    lo = [curve(4 * i + 2) for i in range(256)]
    hi = [curve(256 * i + 128) if i >= 4 else 0 for i in range(256)]
    return bytes(lo), bytes(hi)


def chroma_tables():
    """h7 (faster pass C): the chroma change by c = (g w) >> 8, as the firmware looks it up: CB[c] = -((c KCB) >> 8)
    (what Cb loses, KCB <= 0), CR[c] = (c KCR) >> 8 (what Cr gains, KCR >= 0); floor shifts as the model's."""
    return bytes(-((c * KCB) >> 8) for c in range(256)), bytes((c * KCR) >> 8 for c in range(256))


def gy():
    """h7: the smallest g that can change Y: below it ((255 - Y) g KY) >> 16 is 0 for every Y."""
    return -(-65536 // (255 * KY))


def check_fast_path():
    """The conditions under which h7's shortcuts give the model's bytes exactly (editor.s hl_sp / hl_row):
    one-sided chroma clamps, g <= 1 changes nothing, g, w and c stay below 256, no 32-bit overflow."""
    gmax = max(GMAX.values())
    assert KCB <= 0 <= KCR, 'Cb only falls and Cr only rises: one clamp each'
    assert 255 * 1 * KY < 65536 and (1 * 255) >> 8 == 0, 'g = 1 must leave Y, Cb and Cr as they are'
    assert (255 * gmax) >> 8 <= 255, 'g fits 8 bits'
    assert 255 * 32 * ((255 * gmax) >> 8) * KY < 2 ** 31, '(255 - Y) 32 g KY fits a signed 32-bit product'
    cb, cr = chroma_tables()
    assert max(cb) < 256 and max(cr) < 256


def inc():
    """hl_tab.inc for editor.s."""
    check_fast_path()
    lo, hi = tables()
    cb, cr = chroma_tables()
    rows = [f' .set HL_T, {T}', f' .set HL_BLUR, {BLUR}', f' .set HL_KY, {KY}', f' .set HL_KCB, {KCB}',
            f' .set HL_KCR, {KCR}', f' .set HL_WMUL, {WMUL}', f' .set HL_BLUR2, {BLUR2}', f' .set HL_MIX, {MIX}', f' .set HL_COVU, {COV_U}', f' .set HL_COVLO, {COV_LO}',
            f' .set HL_COVHI, {COV_HI}', f' .set HL_GY32, {32 * gy()}', '.balign 4', 'hl_gmax:',
            ' .long ' + ', '.join(str(GMAX[i]) for i in range(1, 6)), 'hl_lo:']
    rows += [' .byte ' + ', '.join(str(b) for b in lo[i:i + 32]) for i in range(0, 256, 32)]
    rows += ['hl_hi:'] + [' .byte ' + ', '.join(str(b) for b in hi[i:i + 32]) for i in range(0, 256, 32)]
    rows += ['hl_cb:'] + [' .byte ' + ', '.join(str(b) for b in cb[i:i + 32]) for i in range(0, 256, 32)]
    rows += ['hl_cr:'] + [' .byte ' + ', '.join(str(b) for b in cr[i:i + 32]) for i in range(0, 256, 32)]
    return '\n'.join(rows) + '\n'
