"""The Button Function entries of the ISO Auto key and the WB lock key (editor.s "ISO Auto key and WB lock key").

menu_tables(m, o, sy) gives the photo buttons the functions in FUNCS, IA (ISO Auto) and WK (WB lock): the buttons'
validator lists, the Button Function rows' value labels and the choice screen's title / cell / help lists each get a
copy with the new entries, in the space editor.s keeps for them (ia_v0.. ia_ph, at the end of ext13), and the
camera's records are pointed at the copies. It reads the lists from the image it is given, so build.py runs it on its
own image and research/isoauto/layer.py on a release's.
"""
import struct

IA = 3910                                # ISO Auto's function code (free: the camera's codes end below 3500, ours 3900..3904)
WK = 3911                                # WB lock's
FUNCS = ((IA, 0), (WK, 3))               # (function code, its first string: ST_IAC + this = cell, + 1 title, + 2 help)
OFF = 3200
VAL, NVAL = 0x6061912c, 1712             # validator records, 20 B
HDR = 0x61569064                         # the photo Button Function rows' item records {0, ptr, n}
VARS, NVARS = 0x61571ba0, 32             # choice screen variants, 24 B {key, n, titles, cells, help, ?}
PICK = (55, 0x61570e08, 0x61571288, 0x61571708)   # the Fn functions' lists in the stock variants
BUTTONS = (47, 48, 1292, 49, 1964, 570, 56, 50, 52, 53, 51)   # Fn, REC, |o|, CP, AF-ON, Delete, L-Fn, the four arrows


def menu_tables(m, o, sy):
    u32 = lambda a, n=1: struct.unpack_from(f'<{n}I', m, o(a))
    ST = sy['ST_IAC']                    # three strings per function: cell, title, help

    def put(name, size, data):
        assert len(data) <= size, (name, len(data), size)
        m[o(sy[name]):o(sy[name]) + len(data)] = data
        return sy[name]

    # 1. validator lists: one copy per different list (Fn's, L-Fn's, the arrows'), IA and WK before Off
    vrec = {struct.unpack_from('<H', m, o(VAL) + 20 * i)[0]: VAL + 20 * i for i in range(NVAL)}
    copies = {}
    for sid in BUTTONS:
        a = vrec[sid]
        rsid, attr, lst, alt, nbytes, elem = struct.unpack_from('<HHIIHH', m, o(a))
        assert (rsid, attr, alt, elem) == (sid, 128, 0, 2), (sid, rsid, attr, alt, elem)
        codes = struct.unpack_from(f'<{nbytes // 2}H', m, o(lst))
        assert not any(c in codes for c, _ in FUNCS) and OFF in codes, sid
        if codes not in copies:
            k = len(copies)
            new = list(codes)
            new[new.index(OFF):new.index(OFF)] = [c for c, _ in FUNCS]
            copies[codes] = (put(f'ia_v{k}', 2 * 56, struct.pack(f'<{len(new)}H', *new)), 2 * len(new))
        struct.pack_into('<HHIIHH', m, o(a), sid, attr, copies[codes][0], 0, copies[codes][1], elem)
    assert len(copies) == 3, len(copies)

    # 2. the rows' value labels: one copy per different list, plus {code, string << 16 | 4, the list's object}
    _, ip, ni = u32(HDR, 3)
    lab = {}
    for k in range(ni):
        r = ip + 28 * k
        sid, _, _, lp, ln = u32(r, 5)
        if sid not in BUTTONS:
            continue
        if (lp, ln) not in lab:
            old = bytes(m[o(lp):o(lp) + 12 * ln])
            obj = struct.unpack_from('<I', old, 8)[0]
            assert all(struct.unpack_from('<I', old, 12 * i)[0] not in [c for c, _ in FUNCS] for i in range(ln))
            new = old + b''.join(struct.pack('<3I', c, ((ST + k) << 16) | 4, obj) for c, k in FUNCS)
            lab[(lp, ln)] = (put(f'ia_l{len(lab)}', 12 * 56, new), ln + len(FUNCS))
        struct.pack_into('<2I', m, o(r) + 12, *lab[(lp, ln)])
    assert len(lab) == 3, len(lab)

    # 3. the choice screen: titles, cells, help
    n, *old = PICK
    new = []
    for j, (lst, name) in enumerate(zip(old, ('ia_pt', 'ia_pc', 'ia_ph'))):
        b = bytes(m[o(lst):o(lst) + 12 * n])
        obj = struct.unpack_from('<I', b, 8)[0]
        part = (1, 0, 2)[j]                                         # title, cell, help
        b += b''.join(struct.pack('<3I', c, ((ST + k + part) << 16) | 4, obj) for c, k in FUNCS)
        new.append(put(name, 12 * 57, b))
    hits = 0
    for i in range(NVARS):
        v = VARS + 24 * i
        if u32(v + 4, 4) == PICK:
            struct.pack_into('<4I', m, o(v) + 4, n + len(FUNCS), *new)
            hits += 1
    assert hits == 11, hits


def lock_picture(m, o, sy):
    """The shooting screen's "WB Lock" sign (editor.s wi_lv / wi_ic): drawn as the author's "FILM n" label there
    (mkicons._lv_glyph: DejaVu Sans Condensed, cap 24, baseline 33, the label style), on the size of the camera's
    "WB Auto" picture, 86 x 44: the widget shows no more than that width (a wider picture is cut on the left), so the
    two words are squeezed until they fit, 4 px apart, against the right edge. An OSD type-11 stream in wi_pic;
    wi_desc gets its size and uncached address."""
    import numpy as np
    import mkicons
    W, GAP = 86, 4
    sq0 = mkicons.LV_SQ
    try:
        for sq in (0.80, 0.78, 0.76, 0.74, 0.72, 0.70, 0.68, 0.66, 0.64, 0.62, 0.60):
            mkicons.LV_SQ = sq
            a, b = mkicons._lv_glyph('WB'), mkicons._lv_glyph('Lock')
            if a.shape[1] + GAP + b.shape[1] <= W - 2:
                break
        else:
            raise AssertionError('the sign does not fit')
    finally:
        mkicons.LV_SQ = sq0
    px = np.zeros((mkicons.LVH, W), dtype=np.uint8)
    x = W - 1 - b.shape[1]
    px[:, x:x + b.shape[1]] = b
    x -= GAP + a.shape[1]
    px[:, x:x + a.shape[1]] = a
    st = mkicons.encode11([int(v) for v in px.reshape(-1)], W, mkicons.LVH)
    assert len(st) <= sy['wi_pend'] - sy['wi_pic'], len(st)
    m[o(sy['wi_pic']):o(sy['wi_pic']) + len(st)] = st
    d = sy['wi_desc']
    assert struct.unpack_from('<6H', m, o(d)) == (14, 0, 0, 8, 0, 0)
    struct.pack_into('<6H3I', m, o(d), 14, W, mkicons.LVH, 8, 0, 0, len(st), sy['wi_pic'] + 0x40000000, 0)
    return W, mkicons.LVH, len(st), sq
