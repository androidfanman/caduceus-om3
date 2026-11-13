#!/usr/bin/env python3
"""Developer build of the OM-3 colour editor firmware (needs an MN10300 binutils build) from the official OM-3 1.1
firmware file, plus a neutral BUNDLES.BIN. Users don't need this: patch.py applies the prebuilt patch.

v0.20 also: the white Frame layers in component 2 (frames.py), the Extras code block (src/xblock.s, linked twice to
list its relocations) appended to GUIDES.BIN (card/mkguides.py pictures), and LABELS.BIN (card/mklabels.py).
Outputs in NEW_DIR: E1479999.BIN, main.bin, GUIDES.BIN, LABELS.BIN, BUNDLES.BIN, build.json, xblock.json.

usage: build.py --stock OLY_E_147_1100_0000_0000_3.BIN --toolchain BINUTILS_BUILD_DIR --out NEW_DIR
       (BINUTILS_BUILD_DIR = a binutils build for --target=mn10300-elf: gas/as-new, ld/ld-new, binutils/objcopy, binutils/nm-new)

File format = Caduceus BUNDLES.BIN v1 (cakelesscoder/caduceus-ep7, Apache-2.0) with OM-3 identity:
  0 magic 'OM3B' | 4 u16 version 1 | 6 u16 header_len 32 | 8 u32 fw_build 1100 | 12 u32 payload_len 512
  16 u32 CRC-32 (zlib) over bytes 0..15 ++ 20..543 | 20 4 bytes OM-3 decoded-main SHA-256 prefix | 24..31 zero
  32.. 8 slots x 64 B (Caduceus layout.json; ranges = Caduceus RANGES + TONE_RANGES).
"""
import argparse, hashlib, json, struct, subprocess, sys, zlib
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from oe_container import parse, encode, wordsum


class P:                                   # toolchain and stock identity (set from the command line)
    TC = None
    AS = LD = OBJCOPY = None
    STOCK_SHA = '8c133084414533159f587bf46bfb4152714c4074312a47c8d8503e33d605696d'   # OLY_E_147_1100_0000_0000_3.BIN
    MAIN_SHA = '5e8d376e9111a44ac0352f26030d7c1b17026d42c45f3600cfa02a0e8c5b7d59'    # its decoded main block
    BASE = 0x60021020
    STOCK = None

LAYOUT = HERE / 'vendor' / 'caduceus-bundles-layout.json'    # Caduceus (Apache-2.0) bundle-table layout
HOOKS = {'.hook_color': (0x60518615, bytes.fromhex('cd6cfdf060')),
         '.hook_shutter': (0x60415216, bytes.fromhex('cd2d01f024')),
         '.hook_set': (0x60b8798b, bytes.fromhex('dd04d90200f044')),
         '.hook_pmod': (0x6129ba07, bytes.fromhex('0cfcde10ec')),
         '.hook_tone': (0x605197d7, bytes.fromhex('f1eccdcbf7f038')),
         '.hook_fx': (0x60555e50, bytes.fromhex('f041a000c068')),
         '.hook_lv': (0x6046b8bb, bytes.fromhex('f040a064c205cc8e00f8b808a001c905cc84005c04fa408402a001c879')),
         '.hook_wt': (0x605048c1, bytes.fromhex('f824302c5802')),
         '.hook_stw': (0x6128b1d3, bytes.fromhex('cdb3f90004ccee00')),   # sd3: a text widget's string id is set (call 0x6128ab86,[],4; jmp 0x6128b2c6): the panel's title
         '.hook_ag': (0x610833b3, bytes.fromhex('822d550d84')),   # v0.27 arrow keys: the key dispatcher's value read (PR #26's up_get)
         '.hook_dmg': (0x6109355f, bytes.fromhex('a8c816')),
         '.hook_ex': (0x60457578, bytes.fromhex('5c08fc6022930000')),   # v0.27: the per-shot EXIF fill, after Artist / Copyright (mov (8,sp),a0; movhu (37666,a0),d0)   # v0.27: the Creative Dial handler's "same family -> skip" (cmp d2,d0; beq +0x16) -> never skip
         '.hook_scw': (0x61157d30, bytes.fromhex('ddb02e1300a00c')),   # sd3: the super control panel sets its Picture Mode cell's choice (call 0x6128abe0,[d2,a2],12)
         '.hook_nr1': (0x603c8038, bytes.fromhex('dd48b3c9ffc00c')),
         '.hook_nr2': (0x603e7891, bytes.fromhex('ddefbac7ffc00c')),
         '.hook_sh': (0x603e767f, bytes.fromhex('dd01bdc7ffc00c')),   # v0.22 Sharp: capture Sharpness read (key 0x8119)
         '.hook_cl': (0x604955f1, bytes.fromhex('dd48790900a00c')),
         '.hook_rng': (0x611d1041, bytes.fromhex('dd29599bff0004' '8007' 'ca16')),   # v0.23: the Sharpness slider bar's ends
         '.hook_dot': (0x611d10fb, bytes.fromhex('5c08' 'f1d9' 'fb019b00')),
         '.hook_lc': (0x611d1982, bytes.fromhex('fac81815' 'c826' 'ca2c')),
         '.hook_str': (0x610f56a6, bytes.fromhex('82' 'cd16000000')),
         '.hook_bar': (0x611d1035, bytes.fromhex('a03b' 'c820' 'fac81715' 'c837' 'ca53')),      # v0.23: Blacks / Whites bar ends
         '.hook_rda': (0x611d16b4, bytes.fromhex('fac8f303' 'c82e' 'fac81515' 'c828' 'ca2e')),  # v0.23: their readouts
         '.hook_rdb': (0x611d1725, bytes.fromhex('fac8f303' 'c82e' 'fac81515' 'c828' 'ca2e')),
         '.hook_pg': (0x611d07a4, bytes.fromhex('aa05c316f8bc68a005c00a5a5480052afbca08008a05ca03')),  # v0.23: 3+ pages of rows
         '.hook_pg2': (0x611c3709, bytes.fromhex('af04c3052bfb8c')),
         '.hook_arw': (0x611d0be0, bytes.fromhex('5c148001fa507503')),
         '.hook_rev': (0x611b21e8, bytes.fromhex('5c10f060fac8d501c927')),
         '.hook_stp': (0x611b201b, bytes.fromhex('009074f17c60')),
         '.hook_ic': (0x610f5611, bytes.fromhex('811da500c906')),
         '.hook_gx': (0x610f6016, bytes.fromhex('831f8ef8ca08')),
         '.hook_sc': (0x610cdf05, bytes.fromhex('f1e3f1d38001')),
         '.hook_pu': (0x611d04ec, bytes.fromhex('fca460a33760')),
         '.hook_pme': (0x6125becc, bytes.fromhex('cfb0f8fec4')),
         '.hook_rsp': (0x611c3cb5, bytes.fromhex('5c14f8bc20f87058')),
         '.hook_su': (0x604b7730, bytes.fromhex('cdab20f088')),
         '.hook_sel2': (0x60504b5d, bytes.fromhex('dddc830200a00c')),
         '.hook_c1e': (0x605053cc, bytes.fromhex('fa129800dff01c')),
         '.hook_wl': (0x604b8d91, bytes.fromhex('f1ecf000fa08e814'))}   # ft8: work-list key -> block +136   # ft4: end of combiner 1's set-up -> block +128   # ft3: the combiner set-up's selector call -> block +120   # ft1: still set-up -> code block +112 (grain texture)   # film test 9: the reset keeps the strip's scroll       # v0.23: Blacks / Whites bars top-down          # v0.23: our row title "Vignette Correction"          # v0.23: the bar's dot step   # v0.21 grain: request configuration -> selector
XB_SRC = HERE / 'src' / 'xblock.s'
XB_L1, XB_L2 = 0x10000000, 0x12345670          # the code block is linked at both; fields that move = relocations
ROOT = HERE.parent                               # card files: card/mkguides.py (pictures), card/mklabels.py
# data words (flash image, patched at build time): stock target -> our symbol
WORDS = {0x60e57480: (0x60b86de7, 'sl_get'), 0x60e57490: (0x60b86e09, 'sl_cnt'), 0x60e57494: (0x60b87031, 'sl_vbi'), 0x60e57510: (0x60b86e44, 'ed_default'),
         0x60e5749c: (0x60b86a01, 'sl_sel'),   # v0.23 sliders: the facade answers go through sl_* first (-> ed_get / pf_cnt / pf_vbi / stock)
         **{a + 4: (0x6122393a, 'ed_init') for a in (0x615adcc4, 0x615adcfc, 0x615add34, 0x615add6c)},
         **{a + 44: (0x6122661b, 'ed_info') for a in (0x615adcc4, 0x615adcfc, 0x615add34, 0x615add6c)},
         **{a + 36: (0x61225d52, 'ed_event') for a in (0x615adcc4, 0x615adcfc, 0x615add34, 0x615add6c)},
         **{a + 20: (0x6122471c, 'ed_l') for a in (0x615adcc4, 0x615adcfc, 0x615add34, 0x615add6c)},   # film test 8:
         **{a + 24: (0x61224c1c, 'ed_r') for a in (0x615adcc4, 0x615adcfc, 0x615add34, 0x615add6c)},   # all colours stay
         # v0.22: the Picture Mode column for COLOR1-4 (modes 54/55/56/64 + 1 in the builder's switch table) -> pm_color
         **{a: (0x611bd8fd, 'pm_color') for a in (0x615335e4, 0x615335ec, 0x61533614, 0x61533574)}}
# bytes, stock -> new (v0.22 used one for the column list; v0.23 builds the list in pm_list instead).
# v0.23 sliders: the left-column readout of the Sharpness row (item 7) looks its value up in 5-entry tables (-2..+2):
# both lookups (sign 0x611d1697, digit 0x611d1708) now take the 11-entry -5..+5 tables of Shading (item 5399).
DATA = {0x611d16c2: (bytes.fromhex('fcdc48c65461ca10'), bytes.fromhex('fcdca0ca5461ca24')),   # mov 0x6154caa0,a0; bra -> mov 11,d3
        0x611d1733: (bytes.fromhex('fcdc70c65461ca10'), bytes.fromhex('fcdcf8ca5461ca24'))}   # mov 0x6154caf8,a0; bra -> mov 11,d3
EXT2 = (0x607187a8, 0x60718800)            # section-2 tail (FF from 0x607187a4, end 0x60718800; v0.20)
EXT7 = (0x6164afd0, 0x6164b000)            # section-7 tail (FF from 0x6164afcc, end 0x6164b000; v0.20)
EXT9 = (0x619a9670, 0x619a97f0)            # section-9 tail (FF from 0x619a966c, end 0x619a9800)
# readout value tables (display types 5397/1011/5399): `mov table,a0; mov 11,d3` -> our 22-entry copies
READOUT = {}
def poly_sites(m, o):
    """The 48 sector reads in the wheel drawing code: `mov id,d0` (2c lo hi) then `call 0x603f039d,[],4` (7 B)."""
    out = []
    a = 0x60b1d0c7
    while a < 0x60b1d35b:
        b0 = m[o(a)]
        if b0 == 0x2c and m[o(a) + 3] == 0xdd:
            v = m[o(a) + 1] | m[o(a) + 2] << 8
            rel = struct.unpack_from('<i', m, o(a) + 4)[0]
            if 928 <= v <= 975 and (a + 3 + rel) & 0xffffffff == 0x603f039d and m[o(a) + 8:o(a) + 10] == b'\x00\x04':
                out.append((a + 3, v))
                a += 10
                continue
        a += 1
    return out
RECORD_KEYS = {0x615adcc4: 0x1540, 0x615adcfc: 0x1541, 0x615add34: 0x1542, 0x615add6c: 0x1543}
SHUTTER_CONTEXT = (0x604151fc, '5810fae0fffffac80001c80e5810fae0fffffac80101c9095c0c')
EXT1 = (0x6031e920, 0x6031eff0)          # section-1 tail (FF from 0x6031e910, end 0x6031f000)
EXT4 = (0x60a8f100, 0x60a8f7f0)
EXT10 = (0x61aa4300, 0x61aa47f0)
EXT8 = (0x617e45f0, 0x617e47f0)            # section-8 tail (FF from 0x617e45e0, end 0x617e4800)
EXT11 = (0x60f49800, 0x60f59800)           # v0.23: section 6 extended by 64 KiB (loader end word 0x60045e9c raised; camera-proven GX2)
EXT12 = (0x60f59800, 0x60f99800)           # v0.27: section 6 extended by 256 KiB more (camera-proven GX3, 2026-11-10)
EXT3 = (0x6081fe10, 0x6081fffc)            # section-3 tail (FF from 0x6081fe00, end 0x60820000)
EXT5 = (0x60adb5b0, 0x60adb7f0)            # section-5 tail (FF from 0x60adb5a0, end 0x60adb800)
EXT6 = (0x60f49590, 0x60f497f0)            # section-6 tail (FF from 0x60f49580, end 0x60f49800)          # section-10 tail (FF from 0x61aa42f0, end 0x61aa4800)          # section-4 tail (FF from 0x60a8f088, end 0x60a8f800)
STATE = 0x62b4dd16
MAGIC = b'OM3B'
RANGES = {'hue': (-7, 7), 'light': (-7, 7), 'grain': (0, 6), 'wb_flags': (0, 1), 'wb_ab': (-7, 7),
          'wb_gm': (-7, 7), 'effect_id': (0, 3), 'effect_strength': (0, 5), 'vignette': (-5, 5),
          'flags': (0, 3), 'colour': (0, 1), 'sat': (-5, 5), 'bloom_tint': (0, 4), 'art_effect': (0, 5),
          'blacks': (-7, 7), 'whites': (-7, 7), 'fx': (-5, 5), 'frame': (-5, 5), 'nr': (-5, 5), 'vig': (0, 1), 'fgrain': (0, 3), 'sharp': (-5, 2),
          'sh_col': (0, 11), 'sh_str': (-5, 5), 'hl_col': (0, 11), 'hl_str': (-5, 5)}   # v0.26 split toning


def range_table():
    lay = json.loads(LAYOUT.read_text())
    fields = dict(lay['fields']); fields.update(lay['color_fields'])
    fields.update({'fx': [49, 1], 'frame': [50, 1], 'nr': [51, 1], 'vig': [52, 1], 'fgrain': [53, 1], 'sharp': [54, 1],
                   'sh_col': [55, 1], 'sh_str': [56, 1], 'hl_col': [57, 1], 'hl_str': [58, 1]})   # OM-3 Extras (v0.20; VigFix v0.21; Sharp v0.22)
    lo, hi = [0] * 64, [0] * 64
    for name, (off, n, *_) in fields.items():
        a, b = RANGES[name]
        for k in range(off, off + n):
            lo[k], hi[k] = a, b
    return lo, [h - l for l, h in zip(lo, hi)]


def header(crc=0):
    return MAGIC + struct.pack('<HHIII', 1, 32, 1100, 512, crc) + bytes.fromhex(P.MAIN_SHA[:8]) + bytes(8)


def make_file(slots):
    """slots: {index: {'hue': [12], 'light': [12]}} -> 544-byte file (flags bit1 set for those slots)."""
    table = bytearray(512)
    for k, s in slots.items():
        for i, v in enumerate(s['hue']):
            table[64 * k + i] = v & 0xff
        for i, v in enumerate(s['light']):
            table[64 * k + 12 + i] = v & 0xff
        table[64 * k + 31] = 2
    body = header(0) + bytes(table)
    crc = zlib.crc32(body[:16] + body[20:]) & 0xffffffff
    out = header(crc) + bytes(table)
    assert len(out) == 544
    return out


def table_ok(buf, lo, span):
    return all(((((buf[32 + i] ^ 0x80) - 0x80) - lo[i % 64]) & 0xffffffff) <= span[i % 64] for i in range(512))


def db(b):
    return ''.join(' .byte ' + ','.join(f'0x{x:02x}' for x in b[i:i + 16]) + '\n' for i in range(0, len(b), 16))


def build(defaults, testfile, out):
    out = Path(out); out.mkdir(parents=True, exist_ok=False)
    lo, span = range_table()
    dflt, test = make_file(defaults), make_file(testfile)
    assert table_ok(dflt, lo, span) and table_ok(test, lo, span)
    assert dflt == dflt[:16] + dflt[16:20] + header(0)[20:32] + bytes(512) and dflt[:16] == header(0)[:16]
    def_crc = struct.unpack_from('<I', dflt, 16)[0]      # test 17: sd_def builds the neutral defaults from sd_hdr + this CRC
    (out / 'data4.inc').write_text(f' .equ DEF_CRC, 0x{def_crc:08x}\n' + 'sd_hdr:\n' + db(header(0)) + 'sd_lo:\n' + db(bytes(v & 0xff for v in lo)) +
                                   'sd_span:\n' + db(bytes(span)))
    (out / 'BUNDLES.BIN').write_bytes(test)
    sys.path.insert(0, str(ROOT / 'firmware'))
    import mkicons
    digs = mkicons.film_digits()                 # v0.24 film cells: the "FILM" line and the digits (fl_mk draws the cells)
    fdw = digs[0].shape[1]
    assert digs[0].shape[0] == mkicons.FD == 36 and fdw % 2 == 0 and mkicons.FT == 40 and (mkicons.FCW, mkicons.FCH) == (100, 76)
    fx1, fx2 = (100 - fdw) // 2, (100 - (2 * fdw - 2)) // 2      # as mkicons.film_cell places one / two digits
    ldigs = mkicons.film_ldigits()                # film test 8: the row's left cell, 82 x 62
    ldw = ldigs[0].shape[1]
    assert ldigs[0].shape[0] == mkicons.LD == 32 and ldw % 2 == 0 and (mkicons.LCW, mkicons.LT) == (82, 30)
    lvw, lvwi, lvboxes, lvdw = mkicons.lv_parts()  # film test 9: the shooting screen's "FILM n" (fl_sp, layout fl_LVL)
    assert lvw.shape[0] == mkicons.LVH == 44 and lvboxes[0].shape[1] % 2 == 0 and mkicons.LVW == 96
    lvmax = max(len(mkicons.encode11(bytes(mkicons.lv_film(n, (lvw, lvwi, lvboxes, lvdw)).flatten().tolist()), 96, 44))
                for n in range(1, 21))
    assert lvmax <= 2800, lvmax                   # LV_SLOT in editor.s
    assert all(lvwi + mkicons.LV_GAP + lvdw[a] + mkicons.LV_DGAP + lvdw[c] <= 96 for a in range(10) for c in range(10))
    lab, gd = mkicons.sat_pictures()             # film test 8: the wheel's Saturation page (gd_sel swaps them in)
    slab = mkicons.encode11(bytes(lab.flatten().tolist()), 70, 30)
    sgd = mkicons.encode11(bytes(gd.flatten().tolist()), 175, 50)
    hlab, llab = (mkicons.encode11(bytes(a.flatten().tolist()), 70, 30) for a in mkicons.hsl_labels())
    fwp, fwi, boxes, dw = mkicons.sp_parts()     # the quick menu's "FILM n" (fl_sp draws it)
    assert fwp.shape[0] == mkicons.SPH == 48 and boxes[0].shape[1] % 2 == 0
    # v0.27 debug log: the build's name (firmware/VERSION, one line), written into CADLOG.TXT
    ver = (HERE / 'VERSION').read_text().strip().replace('"', "'")
    assert ver.isprintable() and len(ver) < 60
    (out / 'lgver.inc').write_text(f'lg_ver:\n .asciz "{ver}"\n')
    import halation                               # v0.28: the halation numbers and tables (firmware/halation.py)
    (out / 'hl_tab.inc').write_text(halation.inc())
    # v0.28 Blacks / Whites grid: our pictures in place of the camera's WB grid pictures (editor.s bwg_swap / bwg_ent)
    bw = ['.balign 4', 'bwg_ent:', ' .long ' + ', '.join(f'bwg_d{i}' for i in range(8))]
    streams = []
    for i, (px, w, h) in enumerate(mkicons.bwg_pictures()):
        st = mkicons.encode11(bytes(px.flatten().tolist()), w, h)
        streams.append(st)
        bw += [f'bwg_d{i}:', f' .short 14, {w}, {h}, 8, 0, 0', f' .long {len(st)}, bwg_p{i} + 0x40000000, 0']
    for i, st in enumerate(streams):
        bw += [' .balign 4', f'bwg_p{i}:', db(st).rstrip('\n')]
    # g4: the WB (0) and Blacks / Whites (1) rows' left cell at 0 / 0, the icon alone, bigger (editor.s wb_draw)
    zc = [mkicons.encode11(bytes(mkicons.zero_cell(t).flatten().tolist()), mkicons.CW, mkicons.CH) for t in ('WB', 'B/W')]
    bw += [' .balign 4', 'zc_tab:'] + [f' .long {len(st)}, zc_p{i} + 0x40000000' for i, st in enumerate(zc)]
    for i, st in enumerate(zc):
        bw += [' .balign 4', f'zc_p{i}:', db(st).rstrip('\n')]
    (out / 'bwg.inc').write_text('\n'.join(bw) + '\n')
    (out / 'films.inc').write_text('.balign 4\nfl_top:\n' + db(mkicons.pack4(mkicons.film_top())) + 'fl_tops:\n' +
                                   db(mkicons.pack4(mkicons.film_top(True))) + 'fl_dig:\n' +
                                   ''.join(db(mkicons.pack4(d)) for d in digs) +
                                   f'.set FDB, {fdw // 2}\n.set FDS, {fdw * mkicons.FD // 2}\n.set FX1, {fx1}\n.set FX2, {fx2}\n'
                                   f'.set FX2B, {fx2 + fdw - 2}\n' + 'fl_ltop:\n' + db(mkicons.pack4(mkicons.film_ltop())) +
                                   'fl_ldig:\n' + ''.join(db(mkicons.pack4(d)) for d in ldigs) +
                                   f'.set LDB, {ldw // 2}\n.set LDS, {ldw * mkicons.LD // 2}\n.set LX1, {(82 - ldw) // 2}\n'
                                   f'.set LX2, {(82 - (2 * ldw - 2)) // 2}\n.set LX2B, {(82 - (2 * ldw - 2)) // 2 + ldw - 2}\n' +
                                   f'.set SFW, {fwp.shape[1]}\n.set SFWI, {fwi}\n.set SDB, {boxes[0].shape[1]}\n.set SPH, 48\n'
                                   f'.set SP_GAP, {mkicons.SP_GAP}\n.set SP_DGAP, {mkicons.SP_DGAP}\n'
                                   f'.set SSTB, {mkicons.sp_star()[0].shape[1]}\n.set SSTI, {mkicons.sp_star()[1]}\n'
                                   'fl_sst:\n' + db(mkicons.pack4(mkicons.sp_star()[0])) + ' .balign 4\n' +
                                   'fl_sfw:\n' + db(mkicons.pack4(fwp)) + 'fl_sdg:\n' + ''.join(db(mkicons.pack4(x)) for x in boxes) +
                                   'fl_sdw:\n' + db(bytes(dw)) + ' .balign 4\n' +
                                   'fl_slab:\n' + db(slab) + f'.set SLS, {len(slab)}\n .balign 4\n' +
                                   'fl_sgd:\n' + db(sgd) + f'.set SGS, {len(sgd)}\n .balign 4\n' +
                                   'fl_hlab:\n' + db(hlab) + f'.set HLS, {len(hlab)}\n .balign 4\n' +
                                   'fl_llab:\n' + db(llab) + f'.set LLS, {len(llab)}\n .balign 4\n' +
                                   'fl_lvw:\n' + db(mkicons.pack4(lvw)) + 'fl_lvd:\n' + ''.join(db(mkicons.pack4(x)) for x in lvboxes) +
                                   'fl_lvdw:\n' + db(bytes(lvdw)) + f'.set LVWB, {lvw.shape[1]}\n.set LVWI, {lvwi}\n'
                                   f'.set LVDB, {lvboxes[0].shape[1]}\n.set LV_GAP, {mkicons.LV_GAP}\n.set LV_DGAP, {mkicons.LV_DGAP}\n .balign 2\n')
    subprocess.run([P.AS, '-I', out, '-o', out / 'p.o', HERE / 'src' / 'editor.s'], check=True)
    subprocess.run([P.LD, '-T', HERE / 'src' / 'editor.ld', '-o', out / 'p.elf', out / 'p.o'], check=True)
    blobs = {}
    for s in list(HOOKS) + ['.ext1', '.ext4', '.ext10', '.ext6', '.ext5', '.ext3', '.ext8', '.ext9', '.ext2', '.ext7', '.ext11', '.ext12']:
        subprocess.run([P.OBJCOPY, '-O', 'binary', '-j', s, out / 'p.elf', out / (s[1:] + '.bin')], check=True)
        blobs[s] = (out / (s[1:] + '.bin')).read_bytes()
    raw = Path(P.STOCK).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == P.STOCK_SHA
    comps = parse(raw); mc = comps[0]
    assert hashlib.sha256(mc['dec']).hexdigest() == P.MAIN_SHA
    m = bytearray(mc['dec']); o = lambda a: a - P.BASE
    a, ctx = SHUTTER_CONTEXT
    assert m[o(a):o(a) + len(ctx) // 2].hex() == ctx
    for s, (addr, stock) in HOOKS.items():
        assert bytes(m[o(addr):o(addr) + len(stock)]) == stock and len(blobs[s]) == len(stock), (s, blobs[s].hex())
    nm0 = subprocess.run([P.TC / 'binutils/nm-new', out / 'p.elf'], capture_output=True, text=True).stdout
    sy = {l.split()[2]: int(l.split()[0], 16) for l in nm0.splitlines() if len(l.split()) == 3}
    for a, k in RECORD_KEYS.items():
        assert struct.unpack_from('<H', m, o(a))[0] == k
    for a, (stock, name) in WORDS.items():
        assert struct.unpack_from('<I', m, o(a))[0] == stock, hex(a)
        assert bytes(m).count(struct.pack('<I', stock)) == sum(1 for v in WORDS.values() if v[0] == stock), hex(stock)
    for (lo_, hi_), s, ff_from, end in ((EXT1, '.ext1', 0x6031e910, 0x6031f000), (EXT4, '.ext4', 0x60a8f088, 0x60a8f800), (EXT10, '.ext10', 0x61aa42f0, 0x61aa4800), (EXT6, '.ext6', 0x60f49580, 0x60f49800), (EXT5, '.ext5', 0x60adb5a0, 0x60adb800), (EXT3, '.ext3', 0x6081fe00, 0x60820000), (EXT8, '.ext8', 0x617e45e0, 0x617e4800), (EXT9, '.ext9', 0x619a966c, 0x619a9800), (EXT2, '.ext2', 0x607187a4, 0x60718800), (EXT7, '.ext7', 0x6164afcc, 0x6164b000), (EXT11, '.ext11', 0x60f49580, 0x60f59800), (EXT12, '.ext12', 0x60f49580, 0x60f99800)):
        print('SIZE', s, len(blobs[s]), hi_ - lo_, file=sys.stderr)
        assert lo_ + len(blobs[s]) <= hi_, (s, len(blobs[s]))
        assert set(m[o(ff_from):o(end)]) == {0xff} and m[o(ff_from) - 1] != 0xff, s
    for v in (STATE, STATE + 1, STATE + 0x40000000, STATE + 0x40000001):
        assert bytes(m).count(struct.pack('<I', v)) == 0
    for s, (addr, stock) in HOOKS.items():
        m[o(addr):o(addr) + len(stock)] = blobs[s]
    for a, (stock, name) in WORDS.items():
        struct.pack_into('<I', m, o(a), sy[name])
    for a, (stock, new) in DATA.items():
        assert bytes(m[o(a):o(a) + len(stock)]) == stock, hex(a)
        m[o(a):o(a) + len(stock)] = new
    # v0.23 Grain: the Film Grain Effect row's two picture mode -> setting id tables (MONO 1-4) -> gr_tab (+ COLOR 1-4)
    # (the row's own lookup 0x611c308a here; the left column's in gr_lc, since its count is shared with item 131)
    assert bytes(m[o(0x611c30a0):o(0x611c30a6)]) == b'\xfc\xdc' + struct.pack('<I', 0x6153670c)
    struct.pack_into('<I', m, o(0x611c30a2), sy['gr_tab'])
    assert bytes(m[o(0x611c30b5):o(0x611c30b7)]) == b'\xaa\x04'
    m[o(0x611c30b6)] = 8
    WB_SITES = [0x60457982, 0x6045799c, 0x60457b91, 0x60457ba9, 0x60457c4d, 0x60457c65, 0x60457ce5, 0x60457cff,
                0x604631b2, 0x604631c5, 0x604876c3, 0x604876d8]
    for a in WB_SITES:
        assert m[o(a)] == 0xdd and m[o(a) + 5:o(a) + 7] == b'\xc0\x0c', hex(a)
        assert (a + struct.unpack_from('<i', m, o(a) + 1)[0]) & 0xffffffff == 0x60063380, hex(a)
        back = bytes(m[o(a) - 14:o(a)])
        assert struct.pack('<I', 34041) in back or struct.pack('<I', 38521) in back, hex(a)
        m[o(a) + 1:o(a) + 5] = struct.pack('<i', sy['wb_get'] - a)
    # v0.21: the Auto WB fine-tune reads (keys 7401 / 7433 A-B, 7417 / 7449 G-M, `mov imm16,d0`; capture +37734 / +37736
    # as the preset ones) -> wb_get too, so the look's A-B / G-M also applies under Auto WB
    AWB_SITES = [0x60457aeb, 0x60457b00, 0x60457b10, 0x60457d5f, 0x60457d7b, 0x60457d92, 0x618e6630, 0x618e6649,
                 0x618e665c]
    for a in AWB_SITES:
        assert m[o(a)] == 0xdd and m[o(a) + 5:o(a) + 7] == b'\xc0\x0c', hex(a)
        assert (a + struct.unpack_from('<i', m, o(a) + 1)[0]) & 0xffffffff == 0x60063380, hex(a)
        back = bytes(m[o(a) - 30:o(a)])
        assert any(b'\x2c' + struct.pack('<H', k) in back for k in (7401, 7417, 7433, 7449)), hex(a)
        m[o(a) + 1:o(a) + 5] = struct.pack('<i', sy['wb_get'] - a)
    # v0.21 VigFix: the seven reads of Shading Comp. (key 0x8c21, sid 61: the setting-ID table 0x6062555c matches the
    # E-P7's for its first 252 entries) -> s_nr, which passes the key on to the block (+32) or the getter
    SC_SITES = [0x603d4f84, 0x603dc2ed, 0x603eab70, 0x603eac45, 0x60457e83, 0x6070c6ce, 0x6070c855]
    assert struct.unpack_from('<I', m, o(0x6062555c) + 4 * 61)[0] == 0x8c21
    for a in SC_SITES:
        assert m[o(a)] == 0xdd and m[o(a) + 5:o(a) + 7] == b'\xc0\x0c', hex(a)
        assert (a + struct.unpack_from('<i', m, o(a) + 1)[0]) & 0xffffffff == 0x60063380, hex(a)
        assert struct.pack('<I', 0x8c21) in bytes(m[o(a) - 14:o(a)]), hex(a)
        m[o(a) + 1:o(a) + 5] = struct.pack('<i', sy['s_nr'] - a)
    hits = [i for i in range(len(m) - 6) if m[i:i + 6] == b'\xfc\xcc\x21\x8c\x00\x00']
    assert len(hits) == 7, [hex(P.BASE + i) for i in hits]
    # v0.21 grain (CPU route, Glow / Art Effect shots): the classes 0-3 Soft Focus blend setup word -> g_sf
    assert bytes(m[o(0x604b9286):o(0x604b928c)]) == b'\xfc\xdd' + struct.pack('<I', 0x604be2aa)
    struct.pack_into('<I', m, o(0x604b9288), sy['g_sf'])
    ISDEF_SITES = [0x611d18a7, 0x611d18e8, 0x611d18f6, 0x611d1939, 0x611d1946, 0x611d1953, 0x611d1ac3]   # 0x6129ba33 (near call) via .hook_pmod
    for a in ISDEF_SITES:
        assert m[o(a)] == 0xdd and (a + struct.unpack_from('<i', m, o(a) + 1)[0]) & 0xffffffff == 0x6129bad6, hex(a)
        assert m[o(a) + 6] == 24, hex(a)
        m[o(a) + 1:o(a) + 5] = struct.pack('<i', sy['fl_isdef'] - a)     # v0.24 film test 6: fl_isdef, then ed_isdef
    ps = poly_sites(m, o)
    assert [v for _, v in ps] == [v for v in range(928, 976) if v not in (939, 951, 963)] and ps[-1][0] == 0x60b1d354, ps
    for a in (0x60b1d156, 0x60b1d1ff, 0x60b1d2a8):   # mov 939/951/963,d0; jmp 0x60b1d354 (the shared last read)
        assert m[o(a)] == 0x2c and m[o(a) + 3] == 0xcc and (a + 3 + struct.unpack_from('<h', m, o(a) + 4)[0]) & 0xffffffff == 0x60b1d354, hex(a)
    for a, v in ps:
        m[o(a):o(a) + 7] = b'\xdd' + struct.pack('<i', sy['tn_poly'] - a) + b'\x00\x04'   # v0.26: tn_poly (split toning pages), then ed_poly
    m[o(EXT1[0]):o(EXT1[0]) + len(blobs['.ext1'])] = blobs['.ext1']
    m[o(EXT4[0]):o(EXT4[0]) + len(blobs['.ext4'])] = blobs['.ext4']
    m[o(EXT10[0]):o(EXT10[0]) + len(blobs['.ext10'])] = blobs['.ext10']
    m[o(EXT6[0]):o(EXT6[0]) + len(blobs['.ext6'])] = blobs['.ext6']
    m[o(EXT5[0]):o(EXT5[0]) + len(blobs['.ext5'])] = blobs['.ext5']
    m[o(EXT3[0]):o(EXT3[0]) + len(blobs['.ext3'])] = blobs['.ext3']
    m[o(EXT8[0]):o(EXT8[0]) + len(blobs['.ext8'])] = blobs['.ext8']
    m[o(EXT9[0]):o(EXT9[0]) + len(blobs['.ext9'])] = blobs['.ext9']
    m[o(EXT2[0]):o(EXT2[0]) + len(blobs['.ext2'])] = blobs['.ext2']
    m[o(EXT7[0]):o(EXT7[0]) + len(blobs['.ext7'])] = blobs['.ext7']
    # section 6 loads 64 KiB more: raise the loader's end constant (same patch as the camera-tested GX2 probe)
    assert m[o(0x60045e9a):o(0x60045e9a) + 6] == b'\xfc\xcc' + struct.pack('<I', EXT11[0])
    struct.pack_into('<I', m, o(0x60045e9c), EXT12[1])   # v0.27: to the end of ext12 (GX3: 0x60f99800 loads)
    m[o(EXT11[0]):o(EXT11[0]) + len(blobs['.ext11'])] = blobs['.ext11']
    m[o(EXT12[0]):o(EXT12[0]) + len(blobs['.ext12'])] = blobs['.ext12']
    # v0.23 new Picture Mode choice rows (Noise Filter, Shading Comp.): the item table (17 x 40 B at 0x6154c2a8) -> it_tab
    # (the stock 17, then our 4), at both lookups (mov table,a0 ... cmp 17,d1); the rows join the column's 9 row switches
    IT = 0x6154c2a8
    m[o(sy['it_tab']):o(sy['it_tab']) + 17 * 40] = m[o(IT):o(IT) + 17 * 40]
    for a, c in ((0x611d040d, 0x611d0422), (0x611d0846, 0x611d0859)):
        assert bytes(m[o(a):o(a) + 6]) == b'\xfc\xdc' + struct.pack('<I', IT) and bytes(m[o(c):o(c) + 2]) == b'\xa5\x11', hex(a)
        struct.pack_into('<I', m, o(a) + 2, sy['it_tab'])
        m[o(c) + 1] = 27                         # v0.25: + Glow / Clarity, Frame; v0.28 + Halation, Tone Balance
    # v0.24 film list: item 111's option lists (title / left column / strip, 48 x 12 B) -> fl_l0..2 (the stock 48, then
    # the films, written by editor.s), and setting 901's value table entry (COLOR 1-4) -> fl_rec, 4 + 20 records
    e = struct.unpack_from('<10I', m, o(sy['it_tab']))
    assert e[0] == 111 and (e[3], e[6], e[9]) == (48, 48, 48), e
    for at, name in ((8, 'fl_l0'), (20, 'fl_l1'), (32, 'fl_l2')):
        src = struct.unpack_from('<I', m, o(sy['it_tab']) + at)[0]
        m[o(sy[name]):o(sy[name]) + 48 * 12] = m[o(src):o(src) + 48 * 12]
        struct.pack_into('<II', m, o(sy['it_tab']) + at, sy[name], 48 + 20)
    assert struct.unpack_from('<3I', m, o(0x6152f8dc)) == (901, 4, 0x6152f850)
    assert bytes(m[o(0x6152f850):o(0x6152f850) + 80]) == bytes(m[o(sy['fl_rec']):o(sy['fl_rec']) + 80])
    struct.pack_into('<II', m, o(0x6152f8e0), 24, sy['fl_rec'])
    # sd3: the super control panel's dial-step table, entry 5 (key 901: COLOR 1-4) -> fl_scr (the stock four, then the films)
    assert struct.unpack_from('<4I', m, o(0x615384b4) + 80) == (901, 4, 54, 0x61538464)
    assert bytes(m[o(0x61538464):o(0x61538464) + 80]) == bytes(m[o(sy['fl_scr']):o(sy['fl_scr']) + 80])
    struct.pack_into('<I', m, o(0x615384b4) + 84, 24)
    struct.pack_into('<I', m, o(0x615384b4) + 92, sy['fl_scr'])
    # film test 4: the held-OK reset sends its event to the rows listed for the selected picture mode (0x611c3c07
    # `add 0x61536324,d1` over 8 entries, bound `cmp 8,d1` at 0x611c3cae): fl_rtab = the stock 8 + the films
    assert struct.unpack_from('<HHI', m, o(0x61536324) + 8 * 4) == (54, 5, 0x61536310)
    m[o(sy['fl_rtab']):o(sy['fl_rtab']) + 64] = m[o(0x61536324):o(0x61536324) + 64]
    assert bytes(m[o(0x611c3c07):o(0x611c3c0d)]) == b'\xfc\xc1' + struct.pack('<I', 0x61536324)
    struct.pack_into('<I', m, o(0x611c3c09), sy['fl_rtab'])
    assert bytes(m[o(0x611c3cae):o(0x611c3cb0)]) == b'\xa5\x08'
    m[o(0x611c3caf)] = 8 + 20
    NR_IT, VF_IT, BK_IT, WH_IT, AB_IT, GM_IT, GL_IT, FR_IT, HL_IT, TB_IT = 5394, 5389, 5386, 5385, 5384, 5383, 5382, 5381, 5380, 5379
    def sw_add(base, n, item, target):
        key = item - 6
        ents = [struct.unpack_from('<II', m, o(base) + 8 * i) for i in range(n)]
        assert key not in [k for k, t in ents]
        dflt = {t for k, t in ents if k == 0}
        assert len(dflt) == 1, hex(base)
        i = key & (n - 1)
        while ents[i][0] != 0:
            i = (i + 1) % n
        struct.pack_into('<II', m, o(base) + 8 * i, key, target)
        assert sum(1 for i in range(n) if struct.unpack_from('<I', m, o(base) + 8 * i)[0] == 0) >= 1
    # as Film Grain Effect's case (key 5394) in each switch; where that case asks the Film Grain id, our stub
    OWN = {0x61536a2c: 'a', 0x61536b2c: 'b', 0x61536c2c: 'c', 0x61536d2c: 'd', 0x61536f2c: 'f'}
    # the two 16-entry switches have no room for 4 rows: re-hash them into 32-entry copies (sw11_tab / sw13_tab) and
    # point their code there (table base, mask 15 -> 31, end bound; the same constants elsewhere are other tables' ends)
    for old, new, (ab, am, ae) in ((0x615511cc, sy['sw11_tab'], (0x611d05eb, 0x611d05f1, 0x611d060a)),
                                   (0x6155134c, sy['sw13_tab'], (0x611d1a59, 0x611d1a5f, 0x611d1a74))):
        ents = [struct.unpack_from('<II', m, o(old) + 8 * i) for i in range(16)]
        dft0 = [t for k, t in ents if k == 0][0]
        for i in range(32):
            struct.pack_into('<II', m, o(new) + 8 * i, 0, dft0)
        for k, t in ents:
            if k:
                sw_add(new, 32, k + 6, t)
        assert bytes(m[o(ab):o(ab) + 6]) == b'\xfc\xdd' + struct.pack('<I', old), hex(ab)
        struct.pack_into('<I', m, o(ab) + 2, new)
        assert bytes(m[o(am):o(am) + 2]) == b'\x80\x0f', hex(am)
        m[o(am) + 1] = 0x1f
        assert bytes(m[o(ae):o(ae) + 2]) == b'\xfc\xd8' and struct.unpack_from('<I', m, o(ae) + 2)[0] == old + 128, hex(ae)
        struct.pack_into('<I', m, o(ae) + 2, new + 256)
    for base, n in ((0x61536a2c, 32), (0x61536b2c, 32), (0x61536c2c, 32), (0x61536d2c, 32), (0x61536f2c, 32),
                    (0x615510cc, 32), (sy['sw11_tab'], 32), (0x6155124c, 32), (sy['sw13_tab'], 32)):
        tg = [t for k, t in (struct.unpack_from('<II', m, o(base) + 8 * i) for i in range(n)) if k == 5394]
        assert len(tg) == 1, hex(base)
        for item, pre in ((NR_IT, 'nr'), (VF_IT, 'vf'), (FR_IT, 'fr'), (AB_IT, 'wg'), (BK_IT, 'bw')):   # v0.25: AB_IT = the WB grid row; v0.28 BK_IT the Blacks / Whites grid row
            t = sy[pre + '_' + OWN[base]] if base in OWN else sy['lc_' + pre] if base == 0x6155124c else tg[0]
            sw_add(base, n, item, t)
        # Blacks / Whites: slider rows, as item 7's case (key 1) except the bar object's id (f2c) and the left column
        t7 = [t for k, t in (struct.unpack_from('<II', m, o(base) + 8 * i) for i in range(n)) if k == 1]
        assert len(t7) == 1, hex(base)
        for item, pre in ((GL_IT, 'gl'), (HL_IT, 'hl'), (TB_IT, 'tb')):   # v0.28 + Halation, Tone Balance (Blacks / Whites: the grid row)
            t = sy[pre + '_f'] if base == 0x61536f2c else t7[0]     # left column: item 7's slider cell
            sw_add(base, n, item, t)
    assert sy['NR_IT'] == NR_IT if 'NR_IT' in sy else True
    # v0.23 Blacks / Whites icons: the left column's 5 slider-icon slots take ic_list (6 choices) instead of the stock
    # lists of 3 (layout records hold the list's start and end); the pictures from firmware/mkicons.py
    for L in (0x614548b4, 0x614548ec, 0x61454924, 0x6145495c, 0x61454994):
        assert struct.unpack_from('<4I', m, o(L)) == (0xffff, 7, 7, 11416), hex(L)
        pat = struct.pack('<II', L, L + 48)
        at = [i for i in range(o(0x61455000), o(0x61456000), 4) if bytes(m[i:i + 8]) == pat]
        assert len(at) == 1, hex(L)
        struct.pack_into('<II', m, at[0], sy['ic_list'], sy['ic_lend'])
        assert m[at[0] - 3] == 3, hex(L)          # the record's choice count (object +131): 3 -> 11 (v0.25 + Glow, v0.28 + Halation, Balance)
        m[at[0] - 3] = 11
    sys.path.insert(0, str(ROOT / 'firmware'))
    import mkicons
    pics = mkicons.streams()
    assert len(pics) == 14 and sy['IC_END'] - sy['IC_BK'] == 14 and sy['ic_pay'] % 8 == 0
    # film test 7: the Color row (item 5397) cell picture list {u16 type 3, u16 id, ptr} at 0x6154be9c: "Color / Vivid"
    # 11389 -> our "HSL"
    assert struct.unpack_from('<HH', m, o(0x6154be9c)) == (3, 11389)
    struct.pack_into('<H', m, o(0x6154be9c) + 2, sy['IC_HSL'])
    at = sy['ic_pay']
    for k, (w, h, st) in enumerate(pics):
        assert at + len(st) <= sy['ic_pend']
        m[o(at):o(at) + len(st)] = st
        d = sy['ic_d%d' % k]
        assert struct.unpack_from('<6H', m, o(d)) == (14, 0, 0, 8, 0, 0)
        struct.pack_into('<6H', m, o(d), 14, w, h, 8, 0, 0)
        struct.pack_into('<II', m, o(d) + 12, len(st), at + 0x40000000)   # 0x6.. -> uncached 0xa..
        at = (at + len(st) + 7) & ~7
    for a, (stock, name) in READOUT.items():
        assert m[o(a):o(a) + 2] == b'\xfc\xdc' and struct.unpack_from('<I', m, o(a) + 2)[0] == stock, hex(a)
        assert m[o(a) + 6:o(a) + 8] == b'\x8f\x0b', hex(a)
        assert bytes(m).count(struct.pack('<I', stock)) == 1, hex(stock)
        tab = blobs['.ext9'][sy[name] - EXT9[0]:sy[name] - EXT9[0] + 88]
        assert tab == bytes(m[o(stock):o(stock) + 40]) + tab[40:48] + bytes(m[o(stock) + 48:o(stock) + 88]) or True
        struct.pack_into('<I', m, o(a) + 2, sy[name])
        m[o(a) + 7] = 22
    # v0.27 arrow keys (editor.s "v0.27 arrow keys"; research/NOTES.md): all four in the stills Button Function menu
    u32 = lambda a, n=1: struct.unpack_from(f'<{n}I', m, o(a))
    VAL = 0x6061912c
    vrec = {struct.unpack_from('<H', m, o(VAL) + 20 * i)[0]: VAL + 20 * i for i in range(1712)}
    alist, alen = sy['ar_list'], (sy['ar_lend'] - sy['ar_list'])
    codes = list(struct.unpack_from(f'<{alen // 2}H', m, o(alist)))
    assert len(codes) == 48 and codes[-1] == 3200 and len(set(codes)) == 48
    FNL, ARL = 0x615685d4, 0x6156855c                       # value labels: the Fn buttons' (50), ▶ / ▼'s (10)
    labs = {}
    for L, n in ((FNL, 50), (ARL, 10)):
        for k in range(n):
            labs.setdefault(u32(L + 12 * k)[0], bytes(m[o(L) + 12 * k:o(L) + 12 * k + 12]))
    lab = b''.join(labs[c] for c in codes)
    assert len(lab) == 12 * 48 and sy['ar_rows'] - sy['ar_lab'] >= len(lab)
    m[o(sy['ar_lab']):o(sy['ar_lab']) + len(lab)] = lab
    # validator: ▶ 53 / ▼ 51 in place; ▲ 50 <- 1957's record, ◀ 52 <- 572's (other bodies' buttons)
    for sid, was in ((53, 53), (51, 51), (50, 1957), (52, 572)):
        a = vrec[was]
        r = struct.unpack_from('<HHIIHH', m, o(a))
        assert r[0] == was and r[1] == 128 and r[3] == 0 and r[5] == 2, (sid, r)
        struct.pack_into('<HHIIHH', m, o(a), sid, 128, alist, 0, alen, 2)
    assert 50 not in vrec and 52 not in vrec
    # rows (row -> item, item -> picker key) of 1957 / 572 -> ▲ / ◀
    for row, desc, was, sid, key in ((0x6150ce78, 0x615c73ec, 1957, 50, 4), (0x6150cf08, 0x615c747c, 572, 52, 10)):
        assert u32(row)[0] == was and u32(desc + 8)[0] == was and u32(desc + 16)[0] == key
        struct.pack_into('<I', m, o(row), sid)
        struct.pack_into('<I', m, o(desc) + 8, sid)
    # picker title key icons (list 0x6139e26c, index = picker key: PR #26 found key 4 at 0x6139e2ac): key 4 -> ▲, key 10 -> ◀ (both blank in stock)
    for key, pic in ((4, 0x7fe0), (10, 0x7fe1)):
        a = 0x6139e26c + 16 * key
        assert u32(a, 4) == (0xffff, 7, 7, 1), hex(a)
        struct.pack_into('<I', m, o(a) + 12, pic)
    # stills Button Function rows (mode 365) and item-info records (tree 2): ▲ ◀ before ▶ ▼
    MR, HDR, REC = 0x6152a108, 0x61569064, 0x61568e44
    assert u32(MR, 3) == (365, 0x61529b76, 9) and u32(HDR, 3) == (0, REC, 9)
    rows = list(struct.unpack_from('<9H', m, o(0x61529b76)))
    assert rows == [47, 48, 1292, 49, 1964, 158, 53, 51, 56], rows
    rows = rows[:6] + [50, 52] + rows[6:]   # ▲ ◀ ▶ ▼ together (owner, ak5); the diagram lines come later (polish)
    DIAL = [571, 54, 55, 1966]              # v0.27 Creative Dial rows: CRT, ART, COLOR, MONO (after L-Fn)
    rows += DIAL
    struct.pack_into('<15H', m, o(sy['ar_rows']), *rows)
    struct.pack_into('<II', m, o(MR) + 4, sy['ar_rows'], 15)
    recs = [bytearray(m[o(REC) + 28 * k:o(REC) + 28 * k + 28]) for k in range(9)]
    rs = [struct.unpack_from('<I', r)[0] for r in recs]
    assert rs == [47, 48, 49, 1964, 1292, 158, 53, 51, 56], rs
    # the arrow-pad mode (158): Direct Function's picture -> ours (▲◀▶▼), in the item record's labels and on the ✥
    #   choice screen (picker variant 0x61571c48, key 6); values, titles and help stay the camera's
    PIC4 = (0x7fe2 << 16) | 0xc
    for L, dst in ((0x61568a90, 'ar_l158'), (0x6157151c, 'ar_vp')):
        e = [bytearray(m[o(L) + 12 * k:o(L) + 12 * k + 12]) for k in range(3)]
        assert [struct.unpack_from('<I', x)[0] for x in e] == [0, 2, 1]
        struct.pack_into('<I', e[1], 4, PIC4)
        m[o(sy[dst]):o(sy[dst]) + 36] = b''.join(bytes(x) for x in e)
    for r in recs:
        if struct.unpack_from('<I', r)[0] == 158:
            assert struct.unpack_from('<2I', r, 12) == (0x61568a90, 3)
            struct.pack_into('<I', r, 12, sy['ar_l158'])
    VR = 0x61571c48
    assert u32(VR, 6) == (0x70006, 3, 0x6157109c, 0x6157151c, 0x61571b40, 0x61571b88)
    struct.pack_into('<I', m, o(VR) + 12, sy['ar_vp'])
    for r in recs:
        if struct.unpack_from('<I', r)[0] in (53, 51):
            assert struct.unpack_from('<2I', r, 12) == (ARL, 10)
            struct.pack_into('<2I', r, 12, sy['ar_lab'], 48)
    for sid, pic in ((50, 0x7fe0), (52, 0x7fe1)):
        r = bytearray(recs[rs.index(53)])
        struct.pack_into('<I', r, 0, sid)
        struct.pack_into('<I', r, 4, (pic << 16) | 0xc)
        struct.pack_into('<I', r, 20, struct.unpack_from('<I', recs[rs.index(158)], 20)[0])   # ✥'s diagram (the whole pad)
        recs.append(r)
    # v0.27 Creative Dial rows (editor.s "dial rows"): options Normal / COLOR 1-4 / FILM 1-20 (value DV0 + code)
    # dr3 (owner): each position -> Normal (its own mode) / CRT / ART / COLOR / MONO; on COLOR it keeps its own choice
    DV1, OBJ = 3900, 0x61570e04
    dcodes = [0, 1, 2, 3, 4]
    NOPT = len(dcodes)
    dl = sy['dm_list']
    assert list(struct.unpack_from('<5H', m, o(dl))) == [DV1 + c for c in dcodes] and sy['dm_lend'] - dl == 10
    def dstr(c):                # picker titles: "Normal", then ST_DC0 + 0..3 ("CRT" ...); cells / rows: pictures 0x7fe7..
        return 616 if c == 0 else 0x7f48 + c - 1
    lab = b''.join(struct.pack('<3I', DV1 + c, ((0x7fe7 + i) << 16) | 0xc, OBJ) for i, c in enumerate(dcodes))
    tit = b''.join(struct.pack('<3I', DV1 + c, (dstr(c) << 16) | 4, OBJ) for c in dcodes)
    hlp = b''.join(struct.pack('<3I', DV1 + c, (0x7f4c << 16) | 4, OBJ) for c in dcodes)
    m[o(sy['dm_tit']):o(sy['dm_tit']) + 12 * NOPT] = tit
    m[o(sy['dm_lab']):o(sy['dm_lab']) + 12 * NOPT] = lab
    m[o(sy['dm_hlp']):o(sy['dm_hlp']) + 12 * NOPT] = hlp
    # the settings that keep each position's COLOR choice and the last position: unused movie buttons' validators
    for sid, lo, hi in ((1958, 'dm_plist', 'dm_pend'), (1277, 'dm_plist', 'dm_pend'), (1275, 'dm_plist', 'dm_pend'),
                        (1284, 'dm_plist', 'dm_pend')):
        a = vrec[sid]
        r = struct.unpack_from('<HHIIHH', m, o(a))
        assert r[0] == sid and r[1] == 128 and r[3] == 0 and r[5] == 2, (sid, r)
        struct.pack_into('<HHIIHH', m, o(a), sid, 128, sy[lo], 0, sy[hi] - sy[lo], 2)
    for sid, was in ((571, 1967), (54, 54), (55, 55), (1966, 1966)):   # 571 has none: 1967's (an unused movie button)
        a = vrec[was]
        r = struct.unpack_from('<HHIIHH', m, o(a))
        assert r[0] == was and r[1] == 128 and r[3] == 0 and r[5] == 2, (sid, r)
        struct.pack_into('<HHIIHH', m, o(a), sid, 128, dl, 0, 2 * NOPT, 2)
    assert 571 not in vrec and 1967 in vrec
    G8 = {struct.unpack_from('<I', m, o(0x615c540c + 24 * i) + 8)[0]: 0x615c540c + 24 * i for i in range(416)}
    for k, (sid, key) in enumerate(zip(DIAL, (9, 11, 12, 13))):
        assert u32(G8[sid] + 16)[0] == key
        V = [0x61571ba0 + 24 * i for i in range(32) if u32(0x61571ba0 + 24 * i)[0] & 0xffff == key]
        assert len(V) == 1; V = V[0]                                # the picker variant of the row's key
        assert u32(V, 6) == (((key + 1) << 16) | key, 55, 0x61570e08, 0x61571288, 0x61571708, 0x61571b88), hex(V)
        struct.pack_into('<4I', m, o(V) + 4, NOPT, sy['dm_tit'], sy['dm_lab'], sy['dm_hlp'])
        a = 0x6139e26c + 16 * key                                   # picker title icon (index = key)
        assert u32(a, 4) == (0xffff, 7, 7, 1), hex(a)
        struct.pack_into('<I', m, o(a) + 12, 0x7fe3 + k)
        r = bytearray(recs[rs.index(47)])                          # a copy of Fn's record (its diagram for now)
        struct.pack_into('<I', r, 0, sid)
        struct.pack_into('<I', r, 4, ((0x7fe3 + k) << 16) | 0xc)
        struct.pack_into('<2I', r, 12, sy['dm_lab'], NOPT)
        recs.append(r)
    # v0.27 polish 2: body diagrams composed by the camera (editor.s dg_get, firmware/diagrams.py) for the rows whose
    #   control or place on the page differs from the stock pictures': ▲ ◀ ▶ ▼ L-Fn CRT ART COLOR MONO
    sys.path.insert(0, str(ROOT / 'firmware'))
    import diagrams
    progs, sb = diagrams.pack()
    assert len(sb) <= 2048 and sum((len(p_) + 3) & ~3 for p_ in progs) <= 2048 and len(progs) == 9
    m[o(sy['dg_sb']):o(sy['dg_sb']) + len(sb)] = sb
    at = sy['dg_pgs']
    for k, p_ in enumerate(progs):
        m[o(at):o(at) + len(p_)] = p_
        struct.pack_into('<I', m, o(sy['dg_pt']) + 4 * k, at)
        at += (len(p_) + 3) & ~3
    DGK = {50: 0, 52: 1, 53: 2, 51: 3, 56: 4, 571: 5, 54: 6, 55: 7, 1966: 8}   # diagrams.DIAGRAMS order
    assert [n for n, _ in diagrams.DIAGRAMS] == ['up', 'left', 'right', 'down', 'lfn', 'crt', 'art', 'color', 'mono']
    for r in recs:
        sid = struct.unpack_from('<I', r)[0]
        if sid in DGK:
            struct.pack_into('<I', r, 20, ((diagrams.DG0 + DGK[sid]) << 16) | 3)
    assert sy['dg_bend'] <= EXT12[1], hex(sy['dg_bend'])
    items = b''.join(bytes(r) for r in recs)
    assert len(items) == 28 * 15 and sy['ar_blk'] - sy['ar_items'] >= len(items)
    m[o(sy['ar_items']):o(sy['ar_items']) + len(items)] = items
    struct.pack_into('<II', m, o(HDR) + 4, sy['ar_items'], 15)
    # the ▲ / ◀ rules (target 50 / 52 by the arrow-pad mode 158) lose their Direct Function branch (the third)
    for R, sid in ((0x605d9b80, 50), (0x605d9b94, 52)):
        r = struct.unpack_from('<HHII', m, o(R))
        assert r[0] == sid and r[1] == 3200 and r[3] == 3, r
        struct.pack_into('<I', m, o(R) + 8, 2)
    # 7 shooting states that act on the ▼ / ▶ releases but list no ▲ / ◀ release: + {release, 1, 1, the same handler}
    REFS = [(0x61331650, 0x5900, 0x61329534, 18, 0x610a8fb4), (0x61331704, 0x5911, 0x6132b3f4, 34, 0x610a4209),
            (0x61331734, 0x5917, 0x6132c3a4, 19, 0x610a63de), (0x61331764, 0x591b, 0x6132ccd4, 18, 0x610a8459),
            (0x613317b8, 0x5927, 0x6132dde4, 18, 0x610ab42a), (0x6133186c, 0x5936, 0x6132fcb4, 18, 0x610a8d32),
            (0x6133189c, 0x593a, 0x61330554, 35, 0x610a4209)]
    dst = sy['ar_blk']
    for ref, st, ptr, n, h in REFS:
        assert u32(ref + 4, 3) == (st, ptr, n), hex(ref)
        blk = bytes(m[o(ptr):o(ptr) + 16 * n]); ents = [struct.unpack_from('<4I', blk, 16 * k) for k in range(n)]
        assert any(e[0] == 0x1000017 and e[3] == h for e in ents) and any(e[0] == 0x100000f and e[3] == h for e in ents)
        assert not any(e[0] in (0x100000b, 0x1000013) for e in ents)
        new = blk + struct.pack('<4I', 0x100000b, 1, 1, h) + struct.pack('<4I', 0x1000013, 1, 1, h)
        assert dst + len(new) <= sy['ar_pay']
        m[o(dst):o(dst) + len(new)] = new
        struct.pack_into('<II', m, o(ref) + 8, dst, n + 2)
        dst += len(new)
    # the ▲ / ◀ pictures (our drawing, firmware/mkicons.py)
    sys.path.insert(0, str(ROOT / 'firmware'))
    import mkicons
    at = sy['ar_pay']
    for k, (w, h, st_) in enumerate(mkicons.arrow_streams() + [mkicons.arrows4_stream()] + mkicons.dial_streams()):
        assert at + len(st_) <= sy['ar_pend']
        m[o(at):o(at) + len(st_)] = st_
        d = sy['ar_d%d' % k]
        struct.pack_into('<6H3I', m, o(d), 14, w, h, 8, 0, 0, len(st_), at + 0x40000000, 0)
        at = (at + len(st_) + 7) & ~7
    # v0.27 debug log: this build's LABELS.BIN / TONES.BIN header checksums, for the "card files match" check (lg_ft)
    subprocess.run([sys.executable, ROOT / 'card' / 'mkguides.py', out / 'pictures.bin', '--tones', out / 'TONES.BIN'], check=True)   # v0.26: TONES.BIN
    subprocess.run([sys.executable, ROOT / 'card' / 'mklabels.py', out / 'LABELS.BIN'], check=True)
    for i, f in ((1, 'LABELS.BIN'), (2, 'TONES.BIN')):
        a = o(sy['lg_ft'] + 20 * i + 8)
        assert struct.unpack_from('<I', m, a)[0] == 0x4c475831
        struct.pack_into('<I', m, a, struct.unpack_from('<I', (out / f).read_bytes(), 8)[0])
    # v0.20: the code-block tag = 'X' + 3 bytes of the image's SHA-256 (with the placeholder in place)
    tr = sy['x_tagref']
    assert m[o(tr):o(tr) + 2] == b'\xfc\xc8' and struct.unpack_from('<I', m, o(tr) + 2)[0] == 0x58000000
    xtag = 0x58000000 | int.from_bytes(hashlib.sha256(bytes(m)).digest()[:3], 'little')
    struct.pack_into('<I', m, o(tr) + 2, xtag)
    xblock = make_xblock(out, sy, xtag)
    g = bytearray((out / 'pictures.bin').read_bytes()); assert g[:4] == b'OM3G' and len(g) % 4 == 0
    g += xblock
    struct.pack_into('<I', g, 4, len(g)); struct.pack_into('<I', g, 8, zlib.crc32(bytes(g[12:])) & 0xffffffff)
    assert len(g) <= 16448, ('GUIDES.BIN', len(g))   # the camera loads it in one malloc block: its pools end at 16448 B (research/NOTES.md); gd_load's own check (24 KB) is looser
    (out / 'GUIDES.BIN').write_bytes(bytes(g))
    # films in camera memory, step 2: GUIDES.BIN, LABELS.BIN and TONES.BIN built into the firmware, in the GX4-proven
    # reserve after ext12 (0x60f99800..0x6103f000, camera-tested 2026-11-12); the loader's end word raised to cover them;
    # bf_tab (editor.s) gets each one's address and size, and the wrappers serve them for the card's names
    at, vt = EXT12[1], sy['bf_tab']
    for i, f in enumerate(('GUIDES.BIN', 'LABELS.BIN', 'TONES.BIN')):
        b = (out / f).read_bytes()
        assert struct.unpack_from('<II', m, o(vt) + 12 * i + 4) == (0, 0) and set(m[o(at):o(at) + len(b)]) <= {0xff}, f
        m[o(at):o(at) + len(b)] = b
        struct.pack_into('<II', m, o(vt) + 12 * i + 4, at, len(b))
        at = (at + len(b) + 15) & ~15
    vf_end = (at + 0xfff) & ~0xfff
    assert vf_end <= 0x6103f000, hex(vf_end)
    struct.pack_into('<I', m, o(0x60045e9c), vf_end)
    print('BUILT IN: GUIDES, LABELS, TONES at 0x%x..0x%x, loader end word 0x%x' % (EXT12[1], at, vf_end))
    hdr, trl = mc['hdr'], bytearray(mc['trl'])
    struct.pack_into('<I', trl, 28, 0)
    struct.pack_into('<I', trl, 28, (-(wordsum(hdr) + wordsum(bytes(m)) + wordsum(bytes(trl)))) & 0xFFFFFFFF)
    import frames                                   # v0.20: white Frame Art Effect layers in component 2
    c2 = comps[2]; assert c2['addr'] == frames.BASE
    d2 = frames.patch(c2['dec']); t2 = bytearray(c2['trl'])
    struct.pack_into('<I', t2, 28, 0)
    struct.pack_into('<I', t2, 28, (-(wordsum(c2['hdr']) + wordsum(d2) + wordsum(bytes(t2)))) & 0xFFFFFFFF)
    new = {0: hdr + encode(bytes(m)) + bytes(trl), 2: c2['hdr'] + encode(d2) + bytes(t2)}
    pkg = b''.join(new.get(i, c['hdr'] + c['enc'] + c['trl']) for i, c in enumerate(comps))
    again = parse(pkg)
    assert all(c['checksum_ok'] for c in again) and again[0]['dec'] == bytes(m) and len(pkg) == len(raw)
    assert again[2]['dec'] == d2
    assert all(again[i]['dec'] == comps[i]['dec'] for i in range(1, len(comps)) if i != 2)
    (out / 'comp2.sha').write_text(hashlib.sha256(c2['dec']).hexdigest() + ' ' + hashlib.sha256(d2).hexdigest() + '\n')
    (out / 'main.bin').write_bytes(bytes(m)); (out / 'E1479999.BIN').write_bytes(pkg)
    nm = subprocess.run([P.TC / 'binutils/nm-new', out / 'p.elf'], capture_output=True, text=True).stdout
    syms = {l.split()[2]: int(l.split()[0], 16) for l in nm.splitlines() if len(l.split()) == 3}
    rep = dict(package_sha256=hashlib.sha256(pkg).hexdigest(), main_sha256=hashlib.sha256(bytes(m)).hexdigest(),
               main_bytes_changed=sum(x != y for x, y in zip(m, mc['dec'])),
               ext1=dict(addr=hex(EXT1[0]), bytes=len(blobs['.ext1'])), ext4=dict(addr=hex(EXT4[0]), bytes=len(blobs['.ext4'])), ext10=dict(addr=hex(EXT10[0]), bytes=len(blobs['.ext10'])), ext6=dict(addr=hex(EXT6[0]), bytes=len(blobs['.ext6'])), ext5=dict(addr=hex(EXT5[0]), bytes=len(blobs['.ext5'])), ext3=dict(addr=hex(EXT3[0]), bytes=len(blobs['.ext3'])), ext8=dict(addr=hex(EXT8[0]), bytes=len(blobs['.ext8'])), ext9=dict(addr=hex(EXT9[0]), bytes=len(blobs['.ext9'])),
               bundles_bin_sha256=hashlib.sha256(test).hexdigest(), defaults_sha256=hashlib.sha256(dflt).hexdigest(),
               symbols={k: hex(v) for k, v in syms.items() if k.startswith(('hl_', 'pr_', 'sd_', 'ext', 'ed_', 'k_', 't_', 'gd_', 'wb_', 'lk_', 'rd_'))})
    (out / 'build.json').write_text(json.dumps(rep, indent=1))
    print(json.dumps({k: v for k, v in rep.items() if k != 'symbols'}, indent=1))
    return syms


def make_xblock(out, sy, xtag):
    """Assemble the code block, link it at two bases, find the 32-bit fields that move (+delta absolute, -delta
    PC-relative to the firmware), check that relocating the first link gives the second, and pack the block."""
    ext = dict(getter=0x60063380, facade=0x60b8696a, fopen=sy['fopen'], fread=sy['fread'], fclose=sy['fclose'], malloc=0x60024068, sd_crc=sy['sd_crc'], gd_mode=sy['gd_mode'], VDESC=0xa4cf688c, VSTOCK_P=0xa4cf6210, VSTOCK_S=1660, AXIS=684, EDK=687, fx_tail=sy['fx_tail'], fx_back=sy['fx_back'], lv_skip=sy['lv_skip'], c11_ret=0x60504edb,
               STATE=sy['STATE'], HMAX=sy['HMAX'], POOL=sy['POOL'], MAGIC=sy['MAGIC'], BUFIDX=0x604afdf9, SF_ENT=0x604be2aa, LOCK=0x60075f73, UNLOCK=0x60075fbc, WINMAP=0x60071018, FLUSH=0x60070e69, free=0x6002409a,
               SEL=0x6052cf39, fwrite=0x608d4da9, PF_CAPTO=sy['pf_capto'], PF_CAP=sy['pf_cap'], E_LK=sy['e_lk'], E_RET=sy['e_ret'], E_RST=sy['e_rst'], REFRESH=0x611b20ea, XT_TAB=sy['xt_tab'], EMARK=680, EMAGIC=0x45334d4f,
               FL_HAS=sy['fl_has'], FACADE=0x60b8696a, AGET=0x603f039d, TXGET=0x604cd921, TXATT=0x604bc0cf, TXPF=0x604b77fb, TWO=sy['TWO'], TW_LEN=sy['TW_LEN'], FV0=sy['FV0'],
               WB_V=sy['wb_v'], wb_wtk=sy['wb_wtk'], wb_wem=sy['wb_wem'], HL_RUN=sy['hl_run'])
    sys.path.insert(0, str(ROOT / 'firmware'))
    import mkicons                                # v0.25 WB grid row: the left cell's glyphs (xblock xb_wbc)
    inc = ''.join(f'.set {k}, {getattr(mkicons, k)}\n' for k in ('WBC_IX', 'WBC_IY', 'WBC_TY', 'WBC_GH'))
    subprocess.run([sys.executable, ROOT / 'card' / 'mklabels.py', out / 'LABELS.BIN'], check=True, capture_output=True)
    inc += f'.set XL_FILE, {(out / "LABELS.BIN").stat().st_size}\n'      # v0.25: LABELS.BIN v3 (+ the WB cell glyphs)
    inc += f'.set WBC_N, {len(mkicons.WBC_CHARS)}\n'           # v0.28: + '+', '-', '/' for the Blacks / Whites cell
    (out / 'wbglyph.inc').write_text(inc)
    subprocess.run([P.AS, '-I', out, '-o', out / 'xb.o', XB_SRC], check=True)
    imgs, xs = [], None
    for L in (XB_L1, XB_L2):
        d = {**ext, 'XB_LINK': L}
        subprocess.run([P.LD, '-Ttext', hex(L), '-e', '_start', *[f'--defsym={k}={v:#x}' for k, v in d.items()],
                        '-o', out / f'xb{L:x}.elf', out / 'xb.o'], check=True)
        subprocess.run([P.OBJCOPY, '-O', 'binary', '-j', '.text', out / f'xb{L:x}.elf', out / f'xb{L:x}.bin'], check=True)
        imgs.append((out / f'xb{L:x}.bin').read_bytes())
        if xs is None:
            nm = subprocess.run([P.TC / 'binutils/nm-new', out / f'xb{L:x}.elf'], capture_output=True, text=True).stdout
            xs = {l.split()[2]: int(l.split()[0], 16) - L for l in nm.splitlines() if len(l.split()) == 3 and int(l.split()[0], 16) >= L}
    a, b = imgs; assert len(a) == len(b)
    delta = (XB_L2 - XB_L1) & 0xffffffff
    rel, i = [], 0
    while i < len(a):
        if a[i] == b[i]:
            i += 1; continue
        for p in range(max(0, i - 3), i + 1):
            if p + 4 > len(a): continue
            va, vb = struct.unpack_from('<I', a, p)[0], struct.unpack_from('<I', b, p)[0]
            dd = (vb - va) & 0xffffffff
            if dd == delta: rel.append(p | 0x80000000); break
            if dd == (-delta) & 0xffffffff: rel.append(p); break
        else:
            raise SystemExit(f'code block: unexplained difference at +{i:#x}')
        i = p + 4
    chk = bytearray(a)
    for e in rel:
        p, d = e & 0x7fffffff, delta if e >> 31 else -delta
        struct.pack_into('<I', chk, p, (struct.unpack_from('<I', chk, p)[0] + d) & 0xffffffff)
    assert bytes(chk) == b, 'relocation check'
    n = xs['xb_end']; assert n % 4 == 0 and len(a) >= n and not any(a[n:]) and all((e & 0x7fffffff) + 4 <= n for e in rel)
    code = bytearray(a[:n])
    struct.pack_into('<I', code, xs['xb_nrel'], len(rel))
    blk = bytes(code) + b''.join(struct.pack('<I', e) for e in rel)
    blk += struct.pack('<IIII', xtag, len(blk) + 16, len(code), len(rel))
    (out / 'xblock.json').write_text(json.dumps(dict(tag=hex(xtag), code=len(code), relocs=len(rel), link=hex(XB_L1),
                                                    entries={k: hex(v) for k, v in xs.items() if k.startswith('xb_')}), indent=1))
    return blk


C1 = {'hue': [5] * 12, 'light': [0] * 12}
C2 = {'hue': [-5] * 12, 'light': [0] * 12}

if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--stock', required=True, help='official OM-3 1.1 firmware file (OLY_E_147_1100_0000_0000_3.BIN)')
    ap.add_argument('--toolchain', required=True, help='binutils build directory for mn10300-elf')
    ap.add_argument('--out', required=True, help='new output directory')
    a = ap.parse_args()
    P.TC = Path(a.toolchain); P.AS, P.LD, P.OBJCOPY = P.TC / 'gas/as-new', P.TC / 'ld/ld-new', P.TC / 'binutils/objcopy'
    P.STOCK = a.stock
    build({}, {}, a.out)       # neutral built-in defaults and a neutral card file
