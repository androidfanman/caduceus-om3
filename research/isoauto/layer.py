"""Lay the ISO Auto key, and the WB lock key when the build has it, onto a released Caduceus for OM-3 package: a
camera test build.

A local build renders Caduceus' own pictures differently from the release (fonts), so a full local build is not the
release plus this change. The keys' code sits at the end of ext13 and, besides a few words, holds only stock
addresses, so its bytes are the same in every build. This takes the release's own package and writes, from a local
build of the branch (NEW): the code (ia_last .. the end of NEW's ext13; the release must hold 0xff there, inside the
part the loader already loads, or the loader's end word is raised as build.py does, inside the camera-proven
reserve); the hook in the key dispatcher (the release must hold the stock bytes there); and the jumps at .hook_dl and
.hook_str, which go to ia_dl and ia_str now. The words ia_dln and ia_strn are dl_look's and st_get's addresses: they
get the addresses the release's own jumps went to. The Button Function lists (firmware/isoauto.py) are made again
from the release's own lists, and its records pointed at them.
With the WB lock key: also the hooks in the capture's two WB set-ups and the shooting screen's WB display (stock
bytes there), and .hook_ic -> wi_ic, with wi_icn given the release's cv_ic.

usage: layer.py RELEASE_E1479999.BIN NEW_main.bin NEW_p.elf OUT_DIR
"""
import hashlib, importlib.util, struct, sys
from pathlib import Path

B = 0x60021020
REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('pt', REPO / 'firmware' / 'patch.py')
pt = importlib.util.module_from_spec(spec); spec.loader.exec_module(pt)
sys.path.insert(0, str(REPO / 'tools' / 'test'))
from emu_test import elf_symbols
sys.path.insert(0, str(REPO / 'firmware'))
import isoauto

pkg_p, new_p, elf_p, out = map(Path, sys.argv[1:5])
if out.exists():
    sys.exit(f'{out} exists')
pkg = pkg_p.read_bytes(); new = new_p.read_bytes()
sy = elf_symbols(elf_p)
comps = pt.parse(pkg)
rel = bytearray(pt.decode(comps[0]['enc']))
assert len(rel) == len(new)
o = lambda a: a - B
HOOK, STOCK = 0x61083041, bytes.fromhex('cd8800f014')
EXT13_END = 0x60fbc000
lo = sy['ia_last']
hi = EXT13_END
while new[o(hi) - 1] == 0xff:
    hi -= 1
assert 0 < hi - lo < 16384 and sy['ia_key'] > lo, (hex(lo), hex(hi))
end_word, = struct.unpack_from('<I', rel, o(0x60045e9c))          # the loader's end word: the code must lie below it
assert hi <= struct.unpack_from('<I', new, o(0x60045e9c))[0], hex(hi)
assert set(rel[o(lo):o(hi)]) == {0xff}, 'the release is not free where the code goes'
assert rel[o(HOOK):o(HOOK) + 5] == STOCK, 'the release does not hold the stock bytes at the hook'
assert new[o(HOOK)] == 0xdc and struct.unpack_from('<i', new, o(HOOK) + 1)[0] + HOOK == sy['ia_key']   # jmp ia_key
DL = 0x610ba015                                                    # .hook_dl: `jmp dl_look` in the release
jmp = lambda img: struct.unpack_from('<i', img, o(DL) + 1)[0] + DL
assert rel[o(DL)] == 0xdc and new[o(DL)] == 0xdc and jmp(new) == sy['ia_dl']
rel_dl_look = jmp(rel)
assert 0x60f59800 <= rel_dl_look < 0x60f99800                      # in ext12, as the local build's dl_look
assert rel[o(rel_dl_look):o(rel_dl_look) + 16] == new[o(sy['dl_look']):o(sy['dl_look']) + 16]   # dl_look's first bytes
assert struct.unpack_from('<I', new, o(sy['ia_dln']))[0] == sy['dl_look']
WB = 'wd_cap' in sy                                                # the build has the WB lock key too
WD, WD_STOCK = 0x60545933, bytes.fromhex('f8bc843cfa93a401')        # .hook_wd: the capture's WB set-up
WI, WI_STOCK = 0x6118cc43, bytes.fromhex('dd79df0f00e010')          # .hook_wi: the shooting screen's WB display
if WB:
    assert rel[o(WD):o(WD) + 8] == WD_STOCK, 'the release does not hold the stock bytes at .hook_wd'
    assert new[o(WD)] == 0xdc and struct.unpack_from('<i', new, o(WD) + 1)[0] + WD == sy['wd_cap'] and new[o(WD) + 5:o(WD) + 8] == b'\xcb' * 3
    assert rel[o(WI):o(WI) + 7] == WI_STOCK, 'the release does not hold the stock bytes at .hook_wi'
    assert new[o(WI)] == 0xdc and struct.unpack_from('<i', new, o(WI) + 1)[0] + WI == sy['wi_lv'] and new[o(WI) + 5:o(WI) + 7] == b'\xcb' * 2
new_end, = struct.unpack_from('<I', new, o(0x60045e9c))            # the loader's end word, raised when the code needs it
if new_end != end_word:
    assert end_word < new_end <= 0x6103f000 and set(rel[o(end_word):o(new_end)]) == {0xff}, (hex(end_word), hex(new_end))
    struct.pack_into('<I', rel, o(0x60045e9c), new_end)
    print(f'loader end word {end_word:#x} -> {new_end:#x}')
WD2, WD2_STOCK = 0x60545b1c, bytes.fromhex('f8bc88fa93a801')        # .hook_wd2: the twin WB set-up
if WB:
    assert rel[o(WD2):o(WD2) + 7] == WD2_STOCK, 'the release does not hold the stock bytes at .hook_wd2'
    assert new[o(WD2)] == 0xdc and struct.unpack_from('<i', new, o(WD2) + 1)[0] + WD2 == sy['wd_cap2'] and new[o(WD2) + 5:o(WD2) + 7] == b'\xcb' * 2
    rel[o(WD2):o(WD2) + 7] = new[o(WD2):o(WD2) + 7]
if WB:
    rel[o(WD):o(WD) + 8] = new[o(WD):o(WD) + 8]
    rel[o(WI):o(WI) + 7] = new[o(WI):o(WI) + 7]
SH = 0x610f56a6                                                    # .hook_str: `jmp st_get; nop` in the release
jmps = lambda img: struct.unpack_from('<i', img, o(SH) + 1)[0] + SH
assert rel[o(SH)] == 0xdc and new[o(SH)] == 0xdc and rel[o(SH) + 5] == new[o(SH) + 5] == 0xcb and jmps(new) == sy['ia_str']
rel_st_get = jmps(rel)
assert rel[o(rel_st_get):o(rel_st_get) + 16] == new[o(sy['st_get']):o(sy['st_get']) + 16]   # st_get's first bytes
assert struct.unpack_from('<I', new, o(sy['ia_strn']))[0] == sy['st_get']
rel[o(SH):o(SH) + 5] = new[o(SH):o(SH) + 5]
IC = 0x610f5611                                                    # .hook_ic: `jmp cv_ic; nop` in the release
if WB:                                                             # the WB lock's sign: wi_ic before cv_ic
    jmpi = lambda img: struct.unpack_from('<i', img, o(IC) + 1)[0] + IC
    assert rel[o(IC)] == 0xdc and new[o(IC)] == 0xdc and rel[o(IC) + 5] == new[o(IC) + 5] == 0xcb and jmpi(new) == sy['wi_ic']
    rel_cv_ic = jmpi(rel)
    assert rel[o(rel_cv_ic):o(rel_cv_ic) + 12] == new[o(sy['cv_ic']):o(sy['cv_ic']) + 12]   # cv_ic's first bytes
    assert struct.unpack_from('<I', new, o(sy['wi_icn']))[0] == sy['cv_ic']
    rel[o(IC):o(IC) + 5] = new[o(IC):o(IC) + 5]
rel[o(lo):o(hi)] = new[o(lo):o(hi)]
struct.pack_into('<I', rel, o(sy['ia_strn']), rel_st_get)
if WB:
    struct.pack_into('<I', rel, o(sy['wi_icn']), rel_cv_ic)
rel[o(sy['ia_v0']):o(sy['ia_tend'])] = b'\0' * (sy['ia_tend'] - sy['ia_v0'])   # the lists: from the release's own
isoauto.menu_tables(rel, o, sy)
print(f'.hook_str -> ia_str -> {rel_st_get:#x}; Button Function lists at {sy["ia_v0"]:#x}..{sy["ia_tend"]:#x}')
struct.pack_into('<I', rel, o(sy['ia_dln']), rel_dl_look)
rel[o(HOOK):o(HOOK) + 5] = new[o(HOOK):o(HOOK) + 5]
rel[o(DL):o(DL) + 5] = new[o(DL):o(DL) + 5]
print(f'code {lo:#x}..{hi:#x} ({hi - lo} bytes), hook {HOOK:#x} (5 bytes), .hook_dl -> ia_dl -> {rel_dl_look:#x}')
hdr, trl = comps[0]['hdr'], bytearray(comps[0]['trl'])
struct.pack_into('<I', trl, 28, 0)
struct.pack_into('<I', trl, 28, (-(pt.wordsum(hdr) + pt.wordsum(rel) + pt.wordsum(trl))) & 0xFFFFFFFF)
newpkg = b''.join([hdr + pt.encode(rel) + bytes(trl)] + [c['hdr'] + c['enc'] + c['trl'] for c in comps[1:]])
assert len(newpkg) == len(pkg)
chk = pt.parse(newpkg)
assert pt.decode(chk[0]['enc']) == bytes(rel)
for c in chk:                                        # every component's additive checksum
    assert (pt.wordsum(c['hdr']) + pt.wordsum(pt.decode(c['enc'])) + pt.wordsum(c['trl'])) & 0xFFFFFFFF == 0
assert [c['enc'] for c in chk[1:]] == [c['enc'] for c in comps[1:]]
(out / 'DCOLYMP').mkdir(parents=True)
(out / 'DCOLYMP' / 'E1479999.BIN').write_bytes(newpkg)
(out / 'main.bin').write_bytes(bytes(rel))           # for the emulator; not for the card
h = hashlib.sha256(newpkg).hexdigest()
(out / 'SHA256SUMS').write_text(f'{h}  DCOLYMP/E1479999.BIN\n')
print(h, 'DCOLYMP/E1479999.BIN')
