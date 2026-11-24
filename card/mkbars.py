#!/usr/bin/env python3
"""The two bars' tables in one pool (try/picture-mode-4): the colour wheel's H / S / L bar (mkhbar.py) and the Split
toning bar (mkstwheel.py) share one store of row tokens, 9 bits a token, for hbar.s / stwheel.s (.ext15).

Why: p3 + the Split toning bar w8 needed .ext15 67 KB over its size: each bar kept its own row pool as 16-bit tokens
plus a table of row records (hbar.inc 62 KB, stwheel.inc 58 KB). Here:
- one pool for both bars: a row part both use (swatch column, slider marks and frames, the words both have) is
  stored once;
- a token is 9 bits: the colour as one of the pool's 20 colours (bar_cmap) and the run (1..16); the stream the
  camera gets is the same 12-bit token (palette index << 4 | run - 1), so every picture is byte for byte the same
  (mkhbar.stream / mkstwheel.stream, which the emulator tests compare);
- no row records: a table entry is the token index of the row's first token, and bar_row reads tokens until their
  runs fill the part's width (40 swatch, 50 text, 70 slider);
- the text parts' tables hold rows BAR_TX0..BAR_TX0 + BAR_TXN - 1 only: the rows above and below are the same
  empty row in every text part (BAR_TXB).

usage: mkbars.py OUT.inc"""
import argparse
import numpy as np
import mkhbar as Hb
import mkstwheel as St
from mkhbar import row_tokens, sw_fill, sl_fill, H, SWW, TW, SLW


def inc():
    PH, PS = Hb.pieces(), St.pieces()
    assert all((PS['swatch'][y] == PH['swatch'][y]).all() for y in range(H))
    assert all((PS['mark'][v][y] == PH['mark'][v][y]).all() for v in range(11) for y in range(H))
    toks, at = [], {}

    def tid(row):
        t = tuple(row_tokens(row))
        if t not in at:
            at[t] = len(toks); toks.extend(t)
        return at[t]

    def text_rows(P):
        rows = [y for y in range(H) if any((P['text'][f][a][v][y] != Hb.BG).any()
                                           for f in range(3) for a in (0, 1) for v in range(11))]
        return min(rows), max(rows)
    lo = min(text_rows(PH)[0], text_rows(PS)[0]); hi = max(text_rows(PH)[1], text_rows(PS)[1])
    blank = np.full(TW, Hb.BG, dtype=np.uint8)
    for P in (PH, PS):
        for f in range(3):
            for a in (0, 1):
                for v in range(11):
                    for y in list(range(lo)) + list(range(hi + 1, H)):
                        assert (P['text'][f][a][v][y] == blank).all()
    txb = tid(blank)
    swr = [tid(PH['swatch'][y]) for y in range(H)]
    mk = [tid(PH['mark'][v][y]) for v in range(11) for y in range(H)]
    hgid = [tid(sw_fill(Hb.SW)), tid(sl_fill(Hb.GH)), tid(sl_fill(Hb.GS)), tid(sl_fill(Hb.GL))]
    sgid = [tid(sw_fill(St.SWC))] + [tid(sl_fill(g)) for g in St.GRAD]
    hint = [tid(r) for r in Hb.hint_rows()]       # v0.41-a2: the H / S / L bar's INFO hint, HB_PAD rows of HB_W
    htx = [tid(PH['text'][f][a][v][y]) for f in range(3) for a in (0, 1) for v in range(11) for y in range(lo, hi + 1)]
    stx = [tid(PS['text'][f][a][v][y]) for f in range(3) for a in (0, 1) for v in range(11) for y in range(lo, hi + 1)]
    assert len(toks) < 65536
    cols = sorted({t >> 4 for t in toks})
    assert len(cols) <= 32
    code = {c: i for i, c in enumerate(cols)}
    bits = 0; nb = 0; pool = bytearray()
    for t in toks:
        bits |= (code[t >> 4] << 4 | (t & 15)) << nb; nb += 9
        while nb >= 8:
            pool.append(bits & 255); bits >>= 8; nb -= 8
    if nb: pool.append(bits & 255)
    pool += b'\0\0'
    # the decoder, as bar_row reads it: each table entry gives back the part's own tokens
    def read(i, width):
        out = []; left = width; p = 9 * i
        while left:
            w = (pool[p >> 3] | pool[(p >> 3) + 1] << 8) >> (p & 7) & 0x1ff
            out.append(cols[w >> 4] << 4 | (w & 15)); left -= (w & 15) + 1; p += 9
            assert left >= 0
        return out
    assert read(swr[0], SWW) == row_tokens(PH['swatch'][0]) and read(htx[7], TW) == list(toks[htx[7]:htx[7] + len(read(htx[7], TW))])
    for y in range(lo, hi + 1):
        assert read(stx[(2 * 22 + 11 + 10) * (hi - lo + 1) + y - lo], TW) == row_tokens(PS['text'][2][1][10][y])
    assert all(read(hint[y], Hb.W) == row_tokens(r) for y, r in enumerate(Hb.hint_rows()))
    hworst = int(Hb.inc(PH).split('.set HB_WORST, ')[1].split()[0])
    sworst = int(St.inc(PS).split('.set ST_WORST, ')[1].split()[0])
    hw = lambda xs: ''.join(' .short ' + ','.join(str(x) for x in xs[i:i + 16]) + '\n' for i in range(0, len(xs), 16))
    bw = lambda xs: ''.join(' .byte ' + ','.join(str(x) for x in xs[i:i + 32]) + '\n' for i in range(0, len(xs), 32))
    return (f'.set HB_WORST, {hworst}\n.set ST_WORST, {sworst}\n.set ST_NONE, {St.NONE}\n'
            f'.set HB_HDR, {int.from_bytes(Hb.GHDR, "little"):#x}\n.set HB_H, {H}\n.set HB_PH, {Hb.PH}\n.set HB_PAD, {Hb.PAD}\n'
            f'.set HB_SLOT0, {Hb.SLOT0}\n.set HB_NSLOT, {Hb.NSLOT}\n.set HB_PALT, {Hb.PAL_TABLE + 4 * Hb.SLOT0:#x}\n'
            f'.set HB_SWF0, {Hb.SWF0}\n.set HB_SWF1, {Hb.SWF1}\n.set HB_SLF0, {Hb.SLF0}\n.set HB_SLF1, {Hb.SLF1}\n'
            f'.set BAR_SWW, {SWW}\n.set BAR_TW, {TW}\n.set BAR_SLW, {SLW}\n'
            f'.set BAR_TX0, {lo}\n.set BAR_TXN, {hi - lo + 1}\n.set BAR_TXB, {txb}\n'
            '.balign 2\nhb_gid:\n' + hw(hgid) + 'hb_hint:\n' + hw(hint) + 'st_gid:\n' + hw(sgid) + 'hb_swr:\n' + hw(swr) + 'hb_mk:\n' + hw(mk) +
            'hb_tx:\n' + hw(htx) + 'st_tx:\n' + hw(stx) +
            'hb_pal:\n' + ''.join(' .byte ' + ','.join(f'{x & 255},{x >> 8 & 255},{x >> 16 & 255}' for x in Hb.argb(c, h)) + '\n'
                                  for c in range(12) for h in range(-5, 6)) +
            '.balign 4\nst_ctab:\n' +
            ''.join(' .long ' + ','.join(f'{0xff000000 | r << 16 | g << 8 | b:#010x}' for r, g, b in St.role(c)) + '\n'
                    for c in range(13)) +
            'bar_cmap:\n' + bw(cols) + 'bar_pool:\n' + bw(list(pool)) + '.balign 4\n')


if __name__ == '__main__':
    ap = argparse.ArgumentParser(); ap.add_argument('out'); a = ap.parse_args()
    open(a.out, 'w').write(inc())
