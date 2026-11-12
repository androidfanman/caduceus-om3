#!/usr/bin/env python3
"""v0.28 halation (h2): the tuning numbers and tables, shared by the firmware build (editor.s `hl_run`, via hl_tab.inc) and
the exact Python model (research/halation/model.py). Our own numbers; the method follows Caduceus for the E-P7's
halation by cakelesscoder (credited in NOTICE / README)."""
T = 200                            # threshold on Y: only Y above it lights the grid
K = 600                            # the soft curve u = 255 v / (v + K): no hard ceiling, so halos fade out
BLUR = 3                           # [1 2 1] passes across and down
GMAX = {1: 40, 2: 72, 3: 104, 4: 144, 5: 192}   # strength 1..5
KY, KCB, KCR = 44, -40, 60         # the tint at full glow: red-orange (Y by the pixel, Cb / Cr by the area)
WMUL = 2                           # h2: chroma weight = min(255, WMUL (255 - the cell's mean Y)): no speckle from grain
COV_U, COV_LO, COV_HI = 32, 8, 24  # h2: cells with u >= COV_U: up to COV_LO % full strength, fading to none at COV_HI %


def curve(v):
    return (255 * v + (v + K) // 2) // (v + K)


def tables():
    """u by table (no division on the camera): v < 1024 -> LO[v >> 2], else HI[min(255, v >> 8)]."""
    lo = [curve(4 * i + 2) for i in range(256)]
    hi = [curve(256 * i + 128) if i >= 4 else 0 for i in range(256)]
    return bytes(lo), bytes(hi)


def inc():
    """hl_tab.inc for editor.s."""
    lo, hi = tables()
    rows = [f' .set HL_T, {T}', f' .set HL_BLUR, {BLUR}', f' .set HL_KY, {KY}', f' .set HL_KCB, {KCB}',
            f' .set HL_KCR, {KCR}', f' .set HL_WMUL, {WMUL}', f' .set HL_COVU, {COV_U}', f' .set HL_COVLO, {COV_LO}',
            f' .set HL_COVHI, {COV_HI}', '.balign 4', 'hl_gmax:',
            ' .long ' + ', '.join(str(GMAX[i]) for i in range(1, 6)), 'hl_lo:']
    rows += [' .byte ' + ', '.join(str(b) for b in lo[i:i + 32]) for i in range(0, 256, 32)]
    rows += ['hl_hi:'] + [' .byte ' + ', '.join(str(b) for b in hi[i:i + 32]) for i in range(0, 256, 32)]
    return '\n'.join(rows) + '\n'
