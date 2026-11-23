"""Custom crop modes, the table side (feature/crop-modes, 2026-11-17; from feature/composition-guides c5).

Called from build.py once the code sections are in place: apply(m, o, sy) edits the decoded main block m (o = address
-> offset, sy = our symbols). Every stock value is checked before it is changed. Research and addresses:
research/NOTES.md, "Composition guides and crop modes" and "Crop modes ...". Method after Caduceus for the E-P7
(cakelesscoder, docs/ASPECT.md); the OM-3 addresses and these edits are ours.

Values of the still aspect setting 269: 1 4:3, 2 3:2, 3 16:9, 4 1:1, 9 3:4 (stock), and
  5 = 5:4  (the camera's own hidden ratio: its sizes are already in every table, nothing to change),
  6 = XPan 65:24 (stock hidden 7:6, rows rewritten), 7 = 21:9 (stock hidden 6:5, rows rewritten).
New sizes: full sensor width (the larger of the 4:3 and 16:9 widths of that size class), height = width x ratio to
the nearest multiple of 16 (every height the camera makes is one; E-P7 the same). Classes stock leaves 0 stay 0.
"""
import struct

RATIO = {6: 24 / 65, 7: 9 / 21}
CODE = {6: (24 << 8) | 65, 7: (9 << 8) | 21}         # the {w, h, code} table's (H << 8) | W, as 0x304 = 4:3


def h16(w, ratio):
    return int(round(w * ratio / 16)) * 16


def apply(m, o, sy, log=print):
    u16 = lambda a: struct.unpack_from('<H', m, o(a))[0]
    u32 = lambda a: struct.unpack_from('<I', m, o(a))[0]

    def put16(a, v):
        struct.pack_into('<H', m, o(a), v)

    def put32(a, v):
        struct.pack_into('<I', m, o(a), v)

    # 1. Selection. The validator record of 269 (20 B: sid, 0x80, u8 list, 0, count, ...) -> our 8-value list.
    VR = 0x6061b670
    assert (u16(VR), u32(VR + 4), u16(VR + 12)) == (269, 0x60616696, 5)
    assert bytes(m[o(0x60616696):o(0x60616696) + 5]) == bytes([1, 3, 2, 4, 9])
    put32(VR + 4, sy['cr_vlist']); put16(VR + 12, 8)
    # The stills rule of 269 (rule set 0x605d9d74, default rule 0x605d1134): a value is allowed when it is on the "to"
    # side of the rule's map (0x603fc08c), and the map also keeps it (from -> to). + 5->5, 6->6, 7->7.
    RR = 0x605d1134
    assert (u32(RR + 8), u16(RR + 12), u16(RR + 14)) == (0x605d100c, 6, 0xffff)
    pairs = [struct.unpack_from('<HH', m, o(0x605d100c) + 4 * i) for i in range(6)]
    assert pairs == [(1, 1), (3, 3), (2, 2), (4, 4), (9, 9), (10, 1)], pairs
    pairs += [(5, 5), (6, 6), (7, 7)]
    m[o(sy['cr_rmap']):o(sy['cr_rmap']) + 36] = b''.join(struct.pack('<HH', *p) for p in pairs)
    put32(RR + 8, sy['cr_rmap']); put16(RR + 12, 9)
    # The super control panel's strip (record 0x61560388 {269, 5, A, B}, 12-B entries {u32 value, u16 type 3,
    # u16 picture, u32 cond}); its own pictures 7896..7900 are empty in stock (the strip draws from the list below).
    SR = 0x61560388
    assert (u16(SR), u16(SR + 2), u32(SR + 4), u32(SR + 8)) == (269, 5, 0x6155ea2c, 0x6155ea68)
    for src, dst in ((0x6155ea2c, sy['cr_stra']), (0x6155ea68, sy['cr_strb'])):
        ents = [bytearray(m[o(src) + 12 * i:o(src) + 12 * i + 12]) for i in range(5)]
        assert [struct.unpack_from('<I', e)[0] for e in ents] == [1, 3, 2, 4, 9]
        for k, v in enumerate((5, 6, 7)):                          # our pictures (the record's own stock ones are empty)
            e = bytearray(ents[0]); struct.pack_into('<IHH', e, 0, v, 3, sy['CR_IC0'] + k); ents.append(e)
        m[o(dst):o(dst) + 96] = b''.join(ents)
    put16(SR + 2, 8); put32(SR + 4, sy['cr_stra']); put32(SR + 8, sy['cr_strb'])

    # 2. Photo sizes. Split u16 tables W 0x606e60c0 / H 0x606e6270: ids 1..9 x 24 size classes (48 B per id),
    # read by 0x6055e109 / 0x6055e11d (and 0x6055e247).
    W0, H0 = 0x606e60c0, 0x606e6270
    row = lambda base, i: list(struct.unpack_from('<24H', m, o(base) + 48 * (i - 1)))
    assert row(W0, 6)[0] == 4544 and row(H0, 6)[0] == 3888 and row(W0, 7)[0] == 4672 and row(H0, 7)[0] == 3888
    w1, w3 = row(W0, 1), row(W0, 3)
    for i in (6, 7):
        ws, hs = row(W0, i), row(H0, i)
        for c in range(24):
            if ws[c]:
                ws[c] = max(w1[c], w3[c]); hs[c] = h16(ws[c], RATIO[i])
        struct.pack_into('<24H', m, o(W0) + 48 * (i - 1), *ws)
        struct.pack_into('<24H', m, o(H0) + 48 * (i - 1), *hs)
        log(f'crop: W/H id {i}: L {ws[0]} x {hs[0]}')
    # Recorded sizes: {list, size key} pairs at 0x60f15360 (20, ended by a 0 pointer; lists of u32 {id, w, h} ended
    # by id 128).
    NREC = next(k for k in range(64) if u32(0x60f15360 + 8 * k) == 0)
    assert NREC == 20, NREC
    n = 0
    for k in range(NREC):
        lst = u32(0x60f15360 + 8 * k)
        ents, a = [], lst
        while u32(a) != 128:
            ents.append(a); a += 12
            assert len(ents) <= 12
        ids = [u32(e) for e in ents]
        by = {}
        for e in ents:                             # the last 1 before 2 (one list starts with a stray 4:3 L entry)
            by[u32(e)] = e
        if 6 not in by:
            continue
        wmax = max(u32(by[1] + 4), u32(by[3] + 4))
        for i in (6, 7):
            if u32(by[i] + 4):
                put32(by[i] + 4, wmax); put32(by[i] + 8, h16(wmax, RATIO[i])); n += 1
    log(f'crop: recorded-size entries changed: {n}')
    # {w, h, code} by id (6-B entries from id 0 at 0x60663af4; read at 0x604ad644; E-P7 0x604e92c0).
    T = 0x60663af4
    assert struct.unpack_from('<3H', m, o(T) + 36) == (4544, 3888, 0x607)
    assert struct.unpack_from('<3H', m, o(T) + 42) == (4672, 3888, 0x506)
    struct.pack_into('<3H', m, o(T) + 36, 5184, h16(5184, RATIO[6]), CODE[6])
    struct.pack_into('<3H', m, o(T) + 42, 5184, h16(5184, RATIO[7]), CODE[7])
    # {u16 id, 0, w, h} list (8-B entries, ids 1..9, ended by id 128, at 0x60e97f28; read at 0x6036b608).
    T = 0x60e97f28
    assert struct.unpack_from('<4H', m, o(T) + 40) == (6, 0, 4544, 3888)
    assert struct.unpack_from('<4H', m, o(T) + 48) == (7, 0, 4672, 3888)
    struct.pack_into('<4H', m, o(T) + 40, 6, 0, 5184, h16(5184, RATIO[6]))
    struct.pack_into('<4H', m, o(T) + 48, 7, 0, 5184, h16(5184, RATIO[7]))

    # c3: every other table with one row per ratio (camera c2: live view still showed the stock 7:6 / 6:5 box). Found by a
    # scan of the whole block for 9 rows (ids 1..9) shaped 4:3, 3:2, 16:9, 1:1, 5:4, 7:6, 6:5, 7:5, 3:4 (as the E-P7's
    # scan_tables.py; research/NOTES.md "Crop modes c2 on the camera"). Rows 6 / 7 -> full width of the class, height
    # to 16, as above. Formats: (w, h) pairs, (w, h, code) triples, {u16 id, 0, w, h} lists. Addresses = the id 1 row.
    WH4 = (0x603864f8, 0x60386520, 0x60386548, 0x60386570, 0x60386598, 0x60386604, 0x6038662c, 0x60386654, 0x6038667c,
           0x603866a4, 0x603866cc, 0x606c9c20)
    WHC6 = (0x606c970e, 0x606c99a2, 0x606c99e4)
    IDWH8 = (0x6036b50c, 0x6036b564, 0x6036b5b4, 0x60e97c08, 0x60e97c58, 0x60e97ca8, 0x60e97cf8, 0x60e97d98, 0x60e97e38,
             0x60e97fc8, 0x60e98018, 0x60e98068)
    nt = 0
    for t, stride, wo in [(t, 4, 0) for t in WH4] + [(t, 6, 0) for t in WHC6] + [(t, 8, 4) for t in IDWH8]:
        rows = [struct.unpack_from('<2H', m, o(t) + stride * k + wo) for k in range(9)]
        for k, r in enumerate((4 / 3, 3 / 2, 16 / 9, 1.0, 5 / 4, 7 / 6, 6 / 5, 7 / 5, 3 / 4)):
            w, h = rows[k]
            assert h and abs(w / h - r) < 0.03 * r, (hex(t), k + 1, w, h)
        if stride == 8:
            assert [u16(t + 8 * k) for k in range(9)] == [1, 2, 3, 4, 5, 6, 7, 8, 9], hex(t)
        wmax = max(rows[0][0], rows[2][0])
        for i in (6, 7):
            a = t + stride * (i - 1) + wo
            put16(a, wmax); put16(a + 2, h16(wmax, RATIO[i]))
            if stride == 6:
                assert u16(a + 4) == {6: 0x607, 7: 0x506}[i], hex(t)
                put16(a + 4, CODE[i])
        nt += 1
    # Split u16 arrays W[9] then H[9] (ids 1..9) just after the H table: the E-P7's rec-view arrays (0x6053e23c).
    for t in (0x606e6420, 0x606e6444):
        W = list(struct.unpack_from('<9H', m, o(t))); H = list(struct.unpack_from('<9H', m, o(t) + 18))
        assert abs(W[5] / H[5] - 7 / 6) < 0.03 and abs(W[6] / H[6] - 6 / 5) < 0.03, hex(t)
        wmax = max(W[0], W[2])
        for i in (6, 7):
            W[i - 1] = wmax; H[i - 1] = h16(wmax, RATIO[i])
        struct.pack_into('<9H', m, o(t), *W); struct.pack_into('<9H', m, o(t) + 18, *H)
        nt += 1
    log(f'crop: {nt} more per-ratio size tables (rows 6 / 7)')

    # RAW AspectFrame: switch 0x605580b1 (job aspect id - 1 -> jump table 0x606e5fbc; E-P7 0x603ebe95): ids 2, 3, 8 take
    # the width-limited case 0x605580c8 (frame = full 4:3 width, height from the id's own size), 4..7 and 9 the
    # height-limited 0x605580f1. XPan / 21:9 are wider than 4:3: width-limited (else the frame would be 10497 px wide).
    JT = 0x606e5fbc
    assert [u32(JT + 4 * k) for k in range(9)] == [0x60558121, 0x605580c8, 0x605580c8, 0x605580f1, 0x605580f1,
                                                   0x605580f1, 0x605580f1, 0x605580c8, 0x605580f1]
    put32(JT + 4 * 5, 0x605580c8); put32(JT + 4 * 6, 0x605580c8)

    # 3. Live view / preview boxes: the six switches' jump-table entries for ids 6 / 7 -> crop.s.
    SW = {  # table: (stock target of id 6 = the 560 case, stock target of id 7 = the 576 case, our six, our seven)
        0x60e90f28: (0x60c14cfd, 0x60c14d02, 'cr_os6', 'cr_os7'),    # getOutputSize
        0x60e90f54: (0x60c1512b, 0x60c15130, 'cr_ta6', 'cr_ta7'),    # getTakeAreaSize
        0x60e88188: (0x60c066f1, 0x60c066f6, 'cr_sa6', 'cr_sa7'),
        0x60e9b0b8: (0x60c28c5e, 0x60c28c63, 'cr_sb6', 'cr_sb7'),
        0x60e9b678: (0x60c2ab4b, 0x60c2ab50, 'cr_sc6', 'cr_sc7'),
        0x60eac870: (0x60c6686c, 0x60c66871, 'cr_pb6', 'cr_pb7'),    # playback get_aspect_frame
    }
    for jt, (s6, s7, n6, n7) in SW.items():
        assert (u32(jt + 24), u32(jt + 28)) == (s6, s7), hex(jt)
        put32(jt + 24, sy[n6]); put32(jt + 28, sy[n7])
    # 4. The shooting screen's lookups by aspect: its 16 reads of 269 through the GUI getter -> cr_gv (5 -> 4:3,
    # 6 / 7 -> 16:9 for those reads only). Each site: `mov 269,d0` (2c 0d 01), then within 8 bytes
    # `call 0x610fd8ef,[d2,d3,a2,a3],28` (dd rel32 f0 1c).
    GV_SITES = [0x611d8467, 0x6123232c, 0x612356c0, 0x612357fb, 0x61238152, 0x612385d1, 0x61238839, 0x61238985,
                0x61238b3c, 0x6123907e, 0x612395e7, 0x61239848, 0x61239a5b, 0x6123b059, 0x6123e9df, 0x6123eb5c]
    LABEL_SITES = (0x611d8467, 0x612357fb, 0x612356c0)   # c2: the SCP cell's and the top bar's label reads, and the top
                                                         # bar's "show the label?" (hidden at 4:3) -> cr_gvl
    FRAME_SITE = 0x612385d1                              # framelines-1: the aspect frame's style (0x6123853c) -> cr_gvf
    for a in GV_SITES:
        assert bytes(m[o(a):o(a) + 3]) == b'\x2c\x0d\x01', hex(a)
        c = next(c for c in range(a + 3, a + 12) if m[o(c)] == 0xdd)
        assert (c + struct.unpack_from('<i', m, o(c) + 1)[0]) & 0xffffffff == 0x610fd8ef, hex(a)
        assert bytes(m[o(c) + 5:o(c) + 7]) == b'\xf0\x1c', hex(a)
        to = 'cr_gvl' if a in LABEL_SITES else 'cr_gvf' if a == FRAME_SITE else 'cr_gv'
        struct.pack_into('<i', m, o(c) + 1, sy[to] - c)
    # 4b. framelines-1 (2026-11-18): the shooting screen's aspect frame lines. 0x6123853c writes a frame style into the
    # screen object (+2962) from Image Aspect (8 4:3, 10 16:9 on the rear screen; 16 16:9, 32 none at 4:3 in the
    # viewfinder); the frame widget takes its rectangle from the style's entry in 0x60377760 (24 x 20 B {u32 style,
    # u32 on, u16 kind, i16 x0, y0, x1, y1, u16 0}, styles 8..31; lookup 0x61176b7a). Six entries the camera never
    # writes (22, 26, 27, 29, 30, 31; off, rectangle 0) get the crops' rectangles; cr_fst puts their styles in place of
    # 16:9's / 4:3's. Rear 900 x 600 (16:9 rows 47..552): XPan rows 134..465, 21:9 107..492, 5:4 columns 75..825;
    # viewfinder 800 x 600 (16:9 rows 75..524): XPan 152..447, 21:9 129..470, 5:4 25..775 (crop round 2's areas).
    FT = 0x60377760
    CR_FRAMES = {26: (-1, 134, 900, 465), 27: (-1, 107, 900, 492), 29: (75, -1, 825, 600),
                 30: (-1, 152, 800, 447), 31: (-1, 129, 800, 470), 22: (25, -1, 775, 600)}
    assert [u32(FT + 20 * k) for k in range(24)] == list(range(8, 32))
    for sid, r in CR_FRAMES.items():
        e = FT + 20 * (sid - 8)
        assert bytes(m[o(e):o(e) + 20]) == struct.pack('<IIH4hH', sid, 0, 1, 0, 0, 0, 0, 0), sid
        m[o(e):o(e) + 20] = struct.pack('<IIH4hH', sid, 1, 1, *r, 0)
    # 5. Labels. The SCP strip draws its choices from a 5-entry list (0x615491c0, values 1,3,2,9,4, pictures 472 / 471 /
    # 473 / 475 / 2413; its record holds the pointer at 0x6154a8dc and the count at 0x6154a8e0) -> 8 entries, ours
    # CR_IC0 + 0..2 (firmware/mkicons.py crop_streams, 100 x 76) for 5, 6, 7.
    assert (u32(0x6154a8d8), u32(0x6154a8dc), u32(0x6154a8e0)) == (18, 0x615491c0, 5)
    ents = [bytearray(m[o(0x615491c0) + 12 * i:o(0x615491c0) + 12 * i + 12]) for i in range(5)]
    assert [struct.unpack_from('<IHH', e) for e in ents] == [(1, 3, 472), (3, 3, 471), (2, 3, 473), (9, 3, 475), (4, 3, 2413)]
    for k, v in enumerate((5, 6, 7)):
        e = bytearray(ents[0]); struct.pack_into('<IHH', e, 0, v, 3, sy['CR_IC0'] + k); ents.append(e)
    m[o(sy['cr_lst']):o(sy['cr_lst']) + 96] = b''.join(ents)
    put32(0x6154a8dc, sy['cr_lst']); put32(0x6154a8e0, 8)
    import mkicons
    at = sy['cr_pay']
    for k, (w, h, st) in enumerate(mkicons.crop_label_streams()):
        assert at + len(st) <= sy['cr_pend'] and at % 8 == 0
        m[o(at):o(at) + len(st)] = st
        struct.pack_into('<6H3I', m, o(sy['cr_d%d' % k]), 14, w, h, 8, 0, 0, len(st), at + 0x40000000, 0)
        at = (at + len(st) + 7) & ~7
    # The Image Aspect menu lists: three {269, 6, list} records (12-B entries {u32 value, u16 type 4, u16 string,
    # u32 cond}: 4:3, 16:9, 3:2, 1:1, 3:4, 17:9) -> 9 entries, + our strings CR_ST0 + 0..2 (st_get chain, crop.s).
    for rec, lst, dst in ((0x6151ff9c, 0x6151c054, 'cr_ml0'), (0x615863a8, 0x61582684, 'cr_ml1'), (0x61596f00, 0x61596820, 'cr_ml2')):
        assert (u16(rec), u16(rec + 2), u32(rec + 4)) == (269, 6, lst), hex(rec)
        ents = [bytearray(m[o(lst) + 12 * i:o(lst) + 12 * i + 12]) for i in range(6)]
        assert [struct.unpack_from('<IHH', e) for e in ents] == [(1, 4, 292), (3, 4, 291), (2, 4, 293), (4, 4, 1792), (9, 4, 295), (10, 4, 3267)]
        for k, v in enumerate((5, 6, 7)):
            e = bytearray(ents[0]); struct.pack_into('<IHH', e, 0, v, 4, sy['CR_ST0'] + k); ents.append(e)
        m[o(sy[dst]):o(sy[dst]) + 108] = b''.join(ents)
        put16(rec + 2, 9); put32(rec + 4, sy[dst])
    # #97: the Image Aspect screen (0x611f9572, Shooting Menu 1 > Image Aspect) names the ratio under its cursor from a
    # list of its own (record 0x61577268 {u16 0, u16 6, title, list 0x61577208, ...}: 4:3, 3:2, 16:9, 1:1, 3:4, 17:9;
    # looked up by value, 0x611c7785): 5:4 / XPan / 21:9 were not in it, so the last name ("3:4") stayed. -> cr_ml0's 9.
    R = 0x61577268
    assert (u16(R), u16(R + 2), u32(R + 4), u32(R + 8)) == (0, 6, 0x61577200, 0x61577208)
    assert [(u32(0x61577208 + 12 * k), u16(0x61577208 + 12 * k + 4), u16(0x61577208 + 12 * k + 6)) for k in range(6)] == \
        [(1, 4, 292), (2, 4, 293), (3, 4, 291), (4, 4, 1792), (9, 4, 295), (10, 4, 3267)]
    put16(R + 2, 9); put32(R + 8, sy['cr_ml0'])
    # c2: the live view crop ratio (switch at 0x60bf2cc8, jump table 0x60e81df0 by id - 1: ids 6 / 7 -> 65:24 / 21:9),
    # and the wide / tall split at 0x60c0e135 (jump table 0x60e90610 by id: 2, 3, 10 -> 0x60c0e163, the others
    # 0x60c0e158; the E-P7's S6): XPan / 21:9 are wide.
    JT = 0x60e81df0
    assert [u32(JT + 4 * k) for k in range(10)] == [0x60bf2ce9, 0x60bf2ceb, 0x60bf2cf3, 0x60bf2cf7, 0x60bf2cfd,
                                                    0x60bf2d01, 0x60bf2d09, 0x60bf2d0d, 0x60bf2d15, 0x60bf2d1d]
    put32(JT + 20, sy['cr_lr6']); put32(JT + 24, sy['cr_lr7'])
    JT = 0x60e90610
    assert [u32(JT + 4 * k) for k in range(11)] == [0x60c0e173, 0x60c0e158, 0x60c0e163, 0x60c0e163] + [0x60c0e158] * 6 + [0x60c0e163]
    put32(JT + 24, 0x60c0e163); put32(JT + 28, 0x60c0e163)
    # c5: the live view's own ratio (camera c4: none of the switches above ran at XPan / 21:9). ratioToConvertSize
    # 0x60c0d30b (getOutputSize / ForFineZoom's normal path) and getOutputAspect 0x60c14b28 pick w : h through jump
    # tables by id 0..10; ids 6 / 7 were 7:6 / 6:5 -> cr_rc6/7, cr_oa6/7 (65:24 / 21:9).
    for jt, cases, names in ((0x60e905b8, (0x60c0d338, 0x60c0d33f), ('cr_rc6', 'cr_rc7')),
                             (0x60e90efc, (0x60c14b6b, 0x60c14b73), ('cr_oa6', 'cr_oa7'))):
        assert (u32(jt + 4), u32(jt + 12)) == ((0x60c0d31f, 0x60c0d328) if jt == 0x60e905b8 else (0x60c14b53, 0x60c14b5d))
        assert (u32(jt + 24), u32(jt + 28)) == cases, hex(jt)
        put32(jt + 24, sy[names[0]]); put32(jt + 28, sy[names[1]])
    log('crop: live view ratio switches (ratioToConvertSize, getOutputAspect) -> 65:24 / 21:9')
    # c6's AF target selector lists (0x615034f8 / 0x615034e0 + XPan / 21:9) are left out: c6 was the only build with
    # black screens at switch-on, and the owner's S-AF does not read them (research/NOTES.md, crop round 1).
    # Round 2 (camera, round 1: at XPan the AF target screen showed the strip but no target). Two per-ratio tables the
    # live view side reads by Image Aspect have rows only for the camera's own ratios (ids 5..8 are 0 x 0); om-emu does
    # not run this code (research/NOTES.md "Crop round 2").
    # (a) The live view display set-up (log strings "DISP4-3!" ..; 0x602177c3: (12,sp) = camera setting 0x3081 = Image
    # Aspect, om-emu ncall: 1, 3, 6 at 4:3, 16:9, XPan) takes each screen's picture area from 11-entry {u16 w, h} tables
    # by id 0..10: rear 900 x 600 at 0x602ed11e, 1020 x 690 at 0x602ed152, 1024 x 768 at 0x602ed186 (17:9 = its true
    # area, 900 x 476 on the rear). Our ids get their true areas, as 17:9 has: full width at XPan / 21:9 (height to
    # the nearest even), full height at 5:4.
    for t, (sw, sh) in ((0x602ed11e, (900, 600)), (0x602ed152, (1020, 690)), (0x602ed186, (1024, 768))):
        rows = [struct.unpack_from('<HH', m, o(t) + 4 * k) for k in range(11)]
        assert rows[0] == (0, 0) and rows[5:9] == [(0, 0)] * 4, (hex(t), rows)
        assert rows[3][0] == sw and abs(rows[3][1] - sw * 9 / 16) < 3 and rows[10][0] == sw, (hex(t), rows)
        h4 = rows[1][1]                                   # the 4:3 height = the picture's full height on that screen
        new = {5: (2 * round(h4 * 5 / 4 / 2), h4), 6: (sw, 2 * round(sw * 24 / 65 / 2)), 7: (sw, 2 * round(sw * 9 / 21 / 2))}
        for i, (w, h) in new.items():
            struct.pack_into('<HH', m, o(t) + 4 * i, w, h)
        log(f'crop: display areas {hex(t)}: 5:4 {new[5]}, XPan {new[6]}, 21:9 {new[7]}')
    # (b) The AF point grid by id (the AF module, 0x60903e88: (20,a0) = the id; a 0 x 0 row logs an error and takes the
    # 4:3 grid): {u16 columns, rows}, 39 x 27 points at 4:3 (0x60a3cd1e) and the coarser 19 x 13 (0x60a3cd4a). As the
    # camera's own 17:9 takes 16:9's grid, XPan / 21:9 take 16:9's (as the E-P7's af_dim), 5:4 takes 4:3's.
    for t, r43, r169 in ((0x60a3cd1e, (39, 27), (39, 19)), (0x60a3cd4a, (19, 13), (19, 9))):
        rows = [struct.unpack_from('<HH', m, o(t) + 4 * k) for k in range(11)]
        assert rows[0] == (0, 0) and rows[1] == r43 and rows[3] == r169 and rows[10] == r169, (hex(t), rows)
        assert rows[5:9] == [(0, 0)] * 4, (hex(t), rows)
        for i, v in ((5, r43), (6, r169), (7, r169)):
            struct.pack_into('<HH', m, o(t) + 4 * i, *v)
    log('crop: AF point grids: 5:4 as 4:3, XPan / 21:9 as 16:9')
    # c4: the shooting screen's frame boxes (camera c3: live view still showed the 7:6 / 6:5 box). Four (x0, x1, y0, y1)
    # u16 tables by id at stride 8 in api_rec.c's data, one per screen grid (320, 360, 426, 448 x 240): 0x606291b0 read at
    # 0x6043ff17, 0x60629260 / 0x60629208 / 0x606292b8 picked at 0x60438f58 / 8c / 9f (0x60438e62, by screen mode). The id
    # is setting 269 as it is (0x6043900f). Rows 6 / 7 held the 7:6 / 6:5 boxes (the E-P7's "320-grid rows", their v5)
    # -> full width, a centred band of the crop's height (even): 320 grid (0,320,61,179) / (0,320,51,189) as the E-P7's.
    FR = {0x606291b0: (320, (20, 300, 0, 240), (16, 304, 0, 240)), 0x60629260: (360, (40, 340, 0, 240), (36, 324, 0, 240)),
          0x60629208: (426, (73, 353, 0, 240), (69, 357, 0, 240)), 0x606292b8: (448, (84, 366, 0, 240), (80, 370, 0, 240))}
    for t, (w, r6, r7) in FR.items():
        assert struct.unpack_from('<4H', m, o(t)) == (0, 0, 0, 0)
        for i, stock, (rw, rh) in ((6, r6, (65, 24)), (7, r7, (21, 9))):
            assert struct.unpack_from('<4H', m, o(t + 8 * i)) == stock, hex(t)
            h = 2 * round(w * rh / rw / 2)
            struct.pack_into('<4H', m, o(t + 8 * i), 0, w, (240 - h) // 2, (240 - h) // 2 + h)
        log('crop: frame boxes %d x 240: XPan %s, 21:9 %s' % (w, struct.unpack_from('<4H', m, o(t + 48)),
                                                               struct.unpack_from('<4H', m, o(t + 56))))

    # The size text table (0x61600c10) -> 8 columns. Each row's 5:4 / XPan / 21:9 size from the recorded-size list
    # whose 4:3 and 16:9 entries are that row's (lists after section 2 above, so 6 / 7 are the new sizes).
    RT = 0x61600c10
    assert struct.unpack_from('<5H', m, o(RT)) == (1, 3, 2, 4, 9)
    lists = []
    for k in range(NREC):
        lst, a, e = u32(0x60f15360 + 8 * k), u32(0x60f15360 + 8 * k), {}
        while u32(a) != 128:
            e[u32(a)] = (u32(a + 4), u32(a + 8)); a += 12
        lists.append(e)
    rows = []
    for r in range(11):
        key, *wh = struct.unpack_from('<11H', m, o(RT) + 10 + 22 * r)
        w, h = wh[:5], wh[5:]
        hit = [e for e in lists if e.get(1) == (w[0], h[0]) and e.get(3) == (w[1], h[1]) and 5 in e]
        assert hit, (key, w, h)
        ext = [hit[0][i] for i in (5, 6, 7)]
        rows.append(struct.pack('<17H', key, *w, *[x for x, _ in ext], *h, *[y for _, y in ext]))
    tab = struct.pack('<8H', 1, 3, 2, 4, 9, 5, 6, 7) + b''.join(rows)
    assert len(tab) == 16 + 11 * 34
    m[o(sy['cr_rtab']):o(sy['cr_rtab']) + len(tab)] = tab
    for a, old_, new_ in ((0x6129fc2b, RT + 10, sy['cr_rtab'] + 16), (0x6129fc3e, RT, sy['cr_rtab']), (0x6129fc73, RT + 10, sy['cr_rtab'] + 16)):
        assert u32(a) == old_, hex(a)
        put32(a, new_)
    for a, old_, new_ in ((0x6129fc52, 12, 18), (0x6129fc61, 5, 8), (0x6129fc67, 22, 34), (0x6129fc6e, 22, 34), (0x6129fc86, 12, 18)):
        assert m[o(a)] == old_, hex(a)
        m[o(a)] = new_
    log('crop: size text rows (5:4 / XPan / 21:9 L): %s' % ([struct.unpack_from('<17H', rows[0])[i] for i in (6, 7, 8, 14, 15, 16)],))
    log('crop: selection, sizes, 6 live view / playback switches, %d screen reads, labels patched' % len(GV_SITES))


def size_records(m, o):
    """#97: the Image Aspect screen's size records for 5:4, XPan and 21:9, as `.byte` lines for xblock.s (szr.inc).

    The screen (0x611f9572) shows the ratio under its cursor from 266-B records at 0x61577278 {u16 ratio, 11 UTF-16
    sizes of 24 B}: RAW, Large, Middle 1, Middle 2, Small 1, Small 2, then High Res Shot's RAW (tripod, handheld) and
    its three JPEG sizes. Ours take each size from the photo size tables (W 0x606e60c0 / H 0x606e6270, ids 1..9 x 24
    classes; ids 6 / 7 as apply() rewrote them): the class whose 4:3 size is the 4:3 record's. The RAW sizes are the
    full frame, as in every stock record. The method is checked first on the five stock records."""
    T = 0x61577278
    recs = [bytes(m[o(T) + 266 * k:o(T) + 266 * (k + 1)]) for k in range(5)]
    ids = [struct.unpack_from('<H', r)[0] for r in recs]
    assert ids == [1, 3, 2, 4, 9], ids
    txt = lambda r, i: r[2 + 24 * i:26 + 24 * i].decode('utf-16-le').split('\0')[0]
    row = lambda base, i: struct.unpack_from('<24H', m, o(base) + 48 * (i - 1))
    W0, H0 = 0x606e60c0, 0x606e6270
    w1, h1 = row(W0, 1), row(H0, 1)
    RAW = (0, 6, 7)
    cls = {}
    for k in range(11):
        if k not in RAW:
            w, h = map(int, txt(recs[0], k).split('x'))
            cls[k] = next(c for c in range(24) if (w1[c], h1[c]) == (w, h))
    for r, i in zip(recs, ids):
        wi, hi = row(W0, i), row(H0, i)
        for k in range(11):
            want = txt(recs[0], k) if k in RAW else f'{wi[cls[k]]}x{hi[cls[k]]}'
            assert txt(r, k) == want, (i, k, txt(r, k), want)
    out = b''
    for i in (5, 6, 7):
        wi, hi = row(W0, i), row(H0, i)
        out += struct.pack('<H', i)
        for k in range(11):
            s = txt(recs[0], k) if k in RAW else f'{wi[cls[k]]}x{hi[cls[k]]}'
            assert k in RAW or (wi[cls[k]] and hi[cls[k]]), (i, k)
            b = s.encode('utf-16-le')
            assert len(b) <= 22, s
            out += b + bytes(24 - len(b))
    assert len(out) == 3 * 266
    return ''.join(' .byte ' + ','.join(f'0x{x:02x}' for x in out[j:j + 16]) + '\n' for j in range(0, len(out), 16))
