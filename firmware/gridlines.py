"""Framing lines (#104, 2026-11-27), the table side: Cross (10) and Ticks (11) in the Displayed Grid lists.

Called from build.py after crop.apply: apply(m, o, sy) edits the decoded main block m (o = address -> offset, sy = our
symbols). Every stock value is checked before it is changed. Code: src/gridlines.s; notes: research/NOTES.md
"Framing lines (#104)". The movie grid (446) keeps its stock lists.
"""
import struct

NEW = ((10, 'ST_FG0', 0), (11, 'ST_FG0', 1))     # value, string id symbol, + k


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
    for v, s, k in NEW:
        e = bytearray(ents[0]); struct.pack_into('<IHH', e, 0, v, 4, sy[s] + k); ents.append(e)
    m[o(sy['fg_ml']):o(sy['fg_ml']) + 108] = b''.join(ents)
    # Its records (36 B: {u32 id, u16 type, u16 title, cond, list, count, 0, cond, list, count}): 155 at 0x6158e544,
    # 2047 at 0x6158e6ac, each naming the list twice. 446 (0x6158e5f8) stays stock.
    for rec, sid in ((0x6158e544, 155), (0x6158e6ac, 2047)):
        assert u32(rec) == sid, hex(rec)
        for f in (12, 28):
            assert (u32(rec + f), u32(rec + f + 4)) == (ML, 7), hex(rec + f)
            put32(rec + f, sy['fg_ml']); put32(rec + f + 4, 9)
    log('gridlines: Cross 10 / Ticks 11 in the Displayed Grid lists (155, 2047)')
