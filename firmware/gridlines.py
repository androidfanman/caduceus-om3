"""Framing lines (#104, 2026-11-27), the table side: Cross (10) and Ticks (11) in the Displayed Grid lists.

Called from build.py after crop.apply: apply(m, o, sy) edits the decoded main block m (o = address -> offset, sy = our
symbols). Every stock value is checked before it is changed. Code: src/gridlines.s; notes: research/NOTES.md
"Framing lines (#104)". The movie grid (446) keeps its stock lists.
"""
import struct

NEW = (10, 11)                                   # Cross, Ticks: menu rows k = 0, 1 (picture IC_FG0 + k)
W, H = 44, 34                                    # as the camera's own grid icons in the list (om-emu, rear screen)
S4_WORD, S4_LO, S4_HI = 0x60045e94, 0x60a8f800, 0x60ad8000   # section 4's loaded-end word; its GX5-proven gap


def icons():
    """framing-lines-3: Cross and Ticks as list pictures in the camera's grid-icon style (44 x 34, a 2 px outline with
    clipped corners, 2 px lines), palette index 10 (white) on 0 (clear). Our own drawing."""
    import numpy as np

    def frame():
        a = np.zeros((H, W), np.uint8)
        a[:2, :] = a[-2:, :] = a[:, :2] = a[:, -2:] = 10
        a[0, 0] = a[0, -1] = a[-1, 0] = a[-1, -1] = 0
        return a
    cross = frame(); cross[:, 21:23] = 10; cross[16:18, :] = 10
    ticks = frame()
    ticks[2:7, 21:23] = ticks[-7:-2, 21:23] = 10                  # top / bottom marks
    ticks[16:18, 2:8] = ticks[16:18, -8:-2] = 10                  # left / right marks
    ticks[13:21, 21:23] = 10; ticks[16:18, 18:26] = 10            # the small centre cross
    return [cross, ticks]


def pics_inc():
    """fgpics.inc (.ext16): descriptors <6H3I> as crop.py's (14, w, h, 8, 0, 0, length, the stream's uncached address,
    0), then the type-11 streams."""
    from mkicons import encode11
    sts = [encode11(bytes(a.flatten()), W, H) for a in icons()]
    out = []
    for k, st in enumerate(sts):
        out += [f'fg_d{k}:', f' .short 14, {W}, {H}, 8, 0, 0', f' .long {len(st)}, fg_p{k} + 0x40000000, 0']
    for k, st in enumerate(sts):
        out += [' .balign 8', f'fg_p{k}:', ' .byte ' + ', '.join(str(b) for b in st)]
    return '\n'.join(out) + '\n'


def place_s4(m, o, blob, log=print):
    """Put .ext16 at the start of section 4's gap and raise section 4's loaded-end word over it (GX5, camera-proven
    2026-11-27 up to 0x60ad8000; the stock word and an all-FF gap checked first, as the GX5 probe build)."""
    assert m[o(S4_WORD - 2):o(S4_WORD) + 4] == b'\xfc\xcc' + struct.pack('<I', S4_LO), 'section 4 end word not stock'
    end = (S4_LO + len(blob) + 0x7ff) & ~0x7ff
    assert end <= S4_HI and set(m[o(S4_LO):o(end)]) == {0xff}, hex(end)
    m[o(S4_LO):o(S4_LO) + len(blob)] = blob
    struct.pack_into('<I', m, o(S4_WORD), end)
    log(f'gridlines: .ext16 {len(blob)} B at {S4_LO:#x}, section 4 loaded to {end:#x}')


def apply(m, o, sy, log=print):
    u16 = lambda a: struct.unpack_from('<H', m, o(a))[0]
    u32 = lambda a: struct.unpack_from('<I', m, o(a))[0]
    put16 = lambda a, v: struct.pack_into('<H', m, o(a), v)
    put32 = lambda a, v: struct.pack_into('<I', m, o(a), v)

    # 1. Selection: the validator records (20 B: sid, 0x80, u32 list, .., u16 count at +12), as crop.py's 269.
    for rec, sid, lst, vals, ours in ((0x6061b904, 155, 0x60616713, [0, 5, 6, 1, 7, 8, 9], 'fg_v155'),
                                      (0x60621188, 2047, 0x60618b62, [0, 5, 6, 1, 7, 8], 'fg_v2047')):
        assert (u16(rec), u32(rec + 4), u16(rec + 12)) == (sid, lst, len(vals)), hex(rec)
        assert list(m[o(lst):o(lst) + len(vals)]) == vals
        assert list(m[o(sy[ours]):o(sy[ours]) + len(vals) + 2]) == vals + [10, 11]
        put32(rec + 4, sy[ours]); put16(rec + 12, len(vals) + 2)

    # 2. The Displayed Grid menu list (12-B entries {u32 value, u16 type 4, u16 string, u32 cond}) + Cross, Ticks.
    ML = 0x6158bf08
    ents = [bytearray(m[o(ML) + 12 * i:o(ML) + 12 * i + 12]) for i in range(7)]
    assert [struct.unpack_from('<IH', e) for e in ents] == [(v, 4) for v in (0, 5, 6, 7, 8, 1, 9)]
    for k, v in enumerate(NEW):                  # type 3: a picture (framing-lines-1/2: type 4, our words)
        e = bytearray(ents[0]); struct.pack_into('<IHH', e, 0, v, 3, sy['IC_FG0'] + k); ents.append(e)
    m[o(sy['fg_ml']):o(sy['fg_ml']) + 108] = b''.join(ents)
    # Its records (36 B: {u32 id, u16 type, u16 title, cond, list, count, 0, cond, list, count}): 155 at 0x6158e544,
    # 2047 at 0x6158e6ac, each naming the list twice. 446 (0x6158e5f8) stays stock.
    for rec, sid in ((0x6158e544, 155), (0x6158e6ac, 2047)):
        assert u32(rec) == sid, hex(rec)
        for f in (12, 28):
            assert (u32(rec + f), u32(rec + f + 4)) == (ML, 7), hex(rec + f)
            put32(rec + f, sy['fg_ml']); put32(rec + f + 4, 9)
    log('gridlines: Cross 10 / Ticks 11 in the Displayed Grid lists (155, 2047)')
