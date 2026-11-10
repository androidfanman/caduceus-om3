#!/usr/bin/env python3
"""Assignable up key (▲) for stills, as a test build on top of the released v0.26.2. Camera-tested 2026-11-10
(owner of this branch's camera, not the repo owner): ▲ takes ▶'s functions and works like ▶.

Edits (details and addresses in research/BUTTONS.md, "Up key"):
  1. Button Function rows (mode 365 list 0x6152a108): + sid 50 (the camera's up-key setting) last.
  2. Item-info tree 2 (header 0x61569064): the 9 stills records + a sid-50 record (53's, ▶, with our ▲ picture).
  3. sid 1957 (a button of other bodies, unused on the OM-3) lends its entries to sid 50: the validator slot (filled
     with 53's record: ▶'s 9 functions), the row -> item table (item 730) and item 730's descriptor (picker key 4).
     TEST ONLY: a release would add its own records.
  4. Rule 0x605d9b80 (target 50): drops "Direct Function -> Exp comp", so ▲ keeps the chosen function.
  5. The 7 "execute on key release" states that list the ▼ / ▶ releases get the ▲ release too (ISO, MF as on ▶).
  6. up_get (up.s) at the dispatcher's value read 0x610833b3: ▲ follows the arrow-pad mode (Off / [·:·] / Direct).
  7. The ▲ picture: ▼ (0x776) flipped, id 0x7fa0, served by up_ic (upic.s) in front of Caduceus' ic_get; also the
     picker title's key icon (list 0x6139e26c, key 4's blank slot).
  Space: v0.26.2 fills its 64 KiB section-6 extension, so section 6's loaded end moves once more, 0x60f59800 ->
  0x60f5a800 (loader word 0x60045e9c, as build.py does). That extra 4 KiB is not covered by a space probe; the
  camera test above ran normally.
The code-block tag is redone in the main block and in the release GUIDES.BIN.

usage: make_upkey.py RELEASE_PKG RELEASE_GUIDES PICTURE_JSON OUT_DIR
  RELEASE_PKG / RELEASE_GUIDES: v0.26.2's DCOLYMP/E1479999.BIN and OM3MOD/GUIDES.BIN (firmware/patch.py --release
  v0.26.2); LABELS.BIN and TONES.BIN are taken from next to GUIDES.BIN. PICTURE_JSON: picture 0x776 (▼) dumped by
  om-emu, `drive.mjs EMU IMAGE CARD out.json 's1 wait pic:1910:p776.json'` (camera graphics: never committed).
  Run assemble.sh first (the hooks, into build/).
"""
import hashlib, importlib.util, struct, sys, zlib
from pathlib import Path

B = 0x60021020
X_TAGREF = 0x60f497cf
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
BUILD = HERE / 'build'
spec = importlib.util.spec_from_file_location('pt', REPO / 'firmware' / 'patch.py')
pt = importlib.util.module_from_spec(spec); spec.loader.exec_module(pt)

pkg_p, gd_p, pic_p, out = map(Path, sys.argv[1:5])
if out.exists():
    sys.exit(f'{out} exists')
pkg = pkg_p.read_bytes(); gd = bytearray(gd_p.read_bytes())
assert hashlib.sha256(pkg).hexdigest() == '4add99d333e8f9f58ecf612e77244349dd71e927567456b20eb69291c86f53e0'
assert hashlib.sha256(gd).hexdigest() == '92b6791941d9aedcb582383bdffaf75ddb5fa877ed2cee5439bdf71aa5a7222b'
comps = pt.parse(pkg)
m = bytearray(pt.decode(comps[0]['enc'])); rel = bytes(m)
o = lambda a: a - B
u32 = lambda a, n=1: struct.unpack_from(f'<{n}I', m, o(a))

FREE, FEND = 0x60f59800, 0x60f5a800                # v0.26.2: 4 KiB past Caduceus' section-6 end (FF, never loaded)
assert set(m[o(FREE):o(FEND)]) == {0xff}
assert struct.unpack_from('<I', m, o(0x60045e9c))[0] == FREE and bytes(m).count(struct.pack('<I', FREE)) == 1
struct.pack_into('<I', m, o(0x60045e9c), FEND)      # section 6's loaded end (the loader's only reference, as build.py)
NEWREC, NEWLIST = FREE, FREE + 0x200

# 1 + 2: rows and item-info records
HDR, REC = 0x61569064, 0x61568e44
assert u32(HDR, 3) == (0, REC, 9)
recs = [bytes(m[o(REC) + 28 * k:o(REC) + 28 * k + 28]) for k in range(9)]
sids = [struct.unpack_from('<I', r)[0] for r in recs]
assert sids == [47, 48, 49, 1964, 1292, 158, 53, 51, 56], sids
up = bytearray(recs[sids.index(53)])
struct.pack_into('<I', up, 0, 50)
assert struct.unpack_from('<I', up, 4)[0] == 0x0777000c
UPIC = 0x7fa0                                               # our ▲ picture (research/upkey/upic.s answers it)
struct.pack_into('<I', up, 4, (UPIC << 16) | 0xc)          # ▶'s own value labels stay (test 3: ▶'s list)
m[o(NEWREC):o(NEWREC) + 280] = b''.join(recs + [bytes(up)])
struct.pack_into('<II', m, o(HDR) + 4, NEWREC, 10)
MR = 0x6152a108
assert u32(MR, 3) == (365, 0x61529b76, 9)
rows = list(struct.unpack_from('<9H', m, o(0x61529b76)))
assert rows == [47, 48, 1292, 49, 1964, 158, 53, 51, 56], rows
struct.pack_into('<10H', m, o(NEWLIST), *(rows + [50]))
struct.pack_into('<II', m, o(MR) + 4, NEWLIST, 10)

# 3: sid 1957's entries -> sid 50
VAL = 0x6061912c
idx = [i for i in range(1712) if struct.unpack_from('<H', m, o(VAL) + 20 * i)[0] == 1957]
assert len(idx) == 1 and not any(struct.unpack_from('<H', m, o(VAL) + 20 * i)[0] == 50 for i in range(1712))
i53 = [i for i in range(1712) if struct.unpack_from('<H', m, o(VAL) + 20 * i)[0] == 53]
assert len(i53) == 1
r53 = bytearray(m[o(VAL) + 20 * i53[0]:o(VAL) + 20 * i53[0] + 20])
assert struct.unpack_from('<HHIIHH', r53) == (53, 128, 0x60615ad4, 0, 18, 2)
struct.pack_into('<H', r53, 0, 50)                          # test 3: ▶'s validator record (9 codes) as sid 50's
m[o(VAL) + 20 * idx[0]:o(VAL) + 20 * idx[0] + 20] = r53
assert u32(0x6150ce78, 6) == (1957, 0, 8, 730, 0, 1)
struct.pack_into('<I', m, o(0x6150ce78), 50)
assert u32(0x615c73ec, 6) == (730, 68, 1957, 96, 4, 0)
struct.pack_into('<I', m, o(0x615c73ec) + 8, 50)
# test 3: the grid follows the validator list (key 4's and ▶'s key 7's variants share their lists); the picker title's
#   key icon is picture list 0x6139e26c ({0xffff, 7, 7, id}, index = variant +2 - 1): key 4 (index 4) is blank -> ▲
assert u32(0x61571c18, 2) == (0x50004, 0x37) and u32(0x61571c60, 6)[1:] == u32(0x61571c18, 6)[1:]
assert u32(0x6139e2ac, 4) == (0xffff, 7, 7, 1) and u32(0x6139e2dc, 4)[3] == 0x777
struct.pack_into('<I', m, o(0x6139e2ac) + 12, 0x7fa0)

# 4: the up-key rule loses its Direct Function branch (the last of three)
R = 0x605d9b80
assert struct.unpack_from('<HHII', m, o(R)) == (50, 3200, struct.unpack_from('<I', m, o(R) + 4)[0], 3)
struct.pack_into('<I', m, o(R) + 8, 2)

# 5 (test 2): the 7 "execute on key release" states that list down / right releases but not the up release get
#   {0x100000b, 1, 1, the same handler} (blocks copied with one entry more; referrer {.., state, ptr, n})
REFS = [(0x61331650, 0x5900, 0x61329534, 18, 0x610a8fb4), (0x61331704, 0x5911, 0x6132b3f4, 34, 0x610a4209),
        (0x61331734, 0x5917, 0x6132c3a4, 19, 0x610a63de), (0x61331764, 0x591b, 0x6132ccd4, 18, 0x610a8459),
        (0x613317b8, 0x5927, 0x6132dde4, 18, 0x610ab42a), (0x6133186c, 0x5936, 0x6132fcb4, 18, 0x610a8d32),
        (0x6133189c, 0x593a, 0x61330554, 35, 0x610a4209)]
dst = 0x60f59a40
for ref, st, ptr, n, h in REFS:
    assert u32(ref + 4, 3) == (st, ptr, n), hex(ref)
    blk = bytes(m[o(ptr):o(ptr) + 16 * n]); ents = [struct.unpack_from('<4I', blk, 16 * k) for k in range(n)]
    assert any(e[0] == 0x1000017 and e[3] == h for e in ents) and any(e[0] == 0x100000f and e[3] == h for e in ents)
    assert not any(e[0] == 0x100000b for e in ents)
    new = blk + struct.pack('<4I', 0x100000b, 1, 1, h)
    m[o(dst):o(dst) + len(new)] = new
    struct.pack_into('<II', m, o(ref) + 8, dst, n + 1)
    dst += len(new)
# 6 (test 2): the dispatcher's value read answers the up key by the arrow-pad mode (research/upkey/up.s, at 0x60f5a4c0)
UPGET = 0x60f5a4c0
assert dst <= UPGET, hex(dst)
code = (BUILD / 'upget.bin').read_bytes()
hook = (BUILD / 'hookv.bin').read_bytes()
assert UPGET + len(code) <= FEND
m[o(UPGET):o(UPGET) + len(code)] = code
assert m[o(0x610833b3):o(0x610833b8)] == bytes.fromhex('822d550d84') and len(hook) == 5
m[o(0x610833b3):o(0x610833b8)] = hook

# 7 (test 3): the ▲ picture: picture 0x776 (▼, 40 x 40, from om-emu RAM, PICTURE_JSON) flipped upside down,
#   served by up_ic (research/upkey/upic.s at 0x60f5a500, jmp at 0x610f5611 in front of Caduceus' ic_get)
import json
UD = BUILD
UPIC_AT, DESC, PAY = 0x60f5a500, 0x60f5a540, 0x60f5a560
assert dst <= UPIC_AT and UPGET + len(code) <= UPIC_AT
icode = (UD / 'upic.bin').read_bytes(); ihook = (UD / 'hooki.bin').read_bytes()
assert UPIC_AT + len(icode) <= DESC and len(ihook) == 5
jj = json.loads(pic_p.read_text()); dsc = bytes.fromhex(jj['desc'])
assert struct.unpack_from('<6H', dsc) == (14, 40, 40, 8, 0, 0)
def encode11(px, w, h):                                     # as firmware/mkicons.py (no run crosses a row's end)
    toks, i = [], 0
    while i < len(px):
        v, r = px[i], 1
        while r < 16 and (i + r) % w and px[i + r] == v: r += 1
        toks.append(v << 4 | (r - 1)); i += r
    out = bytearray([(h - 1) & 255, ((h - 1) >> 8 & 3) | (((w - 1) & 15) << 4), ((w - 1) >> 4) & 63, 11])
    for k in range(0, len(toks), 5):
        wd = 0
        for s_, t in enumerate(toks[k:k + 5]): wd |= t << (12 * s_)
        out += wd.to_bytes(8, 'little')
    return bytes(out)
def decode11(data, w, h):
    px = bytearray(); g = 0
    while len(px) < w * h:
        word = int.from_bytes(data[4 + 8 * g:12 + 8 * g].ljust(8, b'\0'), 'little')
        for s_ in range(5):
            if len(px) >= w * h: break
            t = (word >> (12 * s_)) & 4095; px.extend(bytes([t >> 4]) * ((t & 15) + 1))
        g += 1
    return bytes(px)
dn = decode11(bytes.fromhex(jj['payload']), 40, 40)
upx = b''.join(dn[40 * y:40 * y + 40] for y in range(39, -1, -1))
st = encode11(upx, 40, 40)
assert decode11(st, 40, 40) == upx and PAY + len(st) <= FEND
m[o(PAY):o(PAY) + len(st)] = st
m[o(DESC):o(DESC) + 24] = struct.pack('<6H3I', 14, 40, 40, 8, 0, 0, len(st), PAY + 0x40000000, 0)
m[o(UPIC_AT):o(UPIC_AT) + len(icode)] = icode
assert m[o(0x610f5611):o(0x610f5616)] == bytes.fromhex('dca459e5ff')   # Caduceus' jmp ic_get (0x60f4afb5)
m[o(0x610f5611):o(0x610f5616)] = ihook

# tag, GUIDES.BIN, package
tag_o = o(X_TAGREF) + 2
assert m[tag_o - 2:tag_o] == b'\xfc\xc8' and m[tag_o + 3] == 0x58
old_tag = struct.unpack_from('<I', m, tag_o)[0]
struct.pack_into('<I', m, tag_o, 0x58000000)
new_tag = 0x58000000 | int.from_bytes(hashlib.sha256(bytes(m)).digest()[:3], 'little')
struct.pack_into('<I', m, tag_o, new_tag)
assert struct.unpack_from('<I', gd, len(gd) - 16)[0] == old_tag
struct.pack_into('<I', gd, len(gd) - 16, new_tag)
struct.pack_into('<I', gd, 8, zlib.crc32(bytes(gd[12:])) & 0xffffffff)
hdr, trl = comps[0]['hdr'], bytearray(comps[0]['trl'])
struct.pack_into('<I', trl, 28, 0)
struct.pack_into('<I', trl, 28, (-(pt.wordsum(hdr) + pt.wordsum(m) + pt.wordsum(trl))) & 0xFFFFFFFF)
newpkg = hdr + pt.encode(m) + bytes(trl) + b''.join(c['hdr'] + c['enc'] + c['trl'] for c in comps[1:])
assert len(newpkg) == len(pkg)
chk = pt.parse(newpkg)
assert pt.decode(chk[0]['enc']) == bytes(m)
for c in chk:
    assert (pt.wordsum(c['hdr']) + pt.wordsum(pt.decode(c['enc'])) + pt.wordsum(c['trl'])) & 0xFFFFFFFF == 0
print(f'{sum(1 for i in range(len(m)) if m[i] != rel[i])} main bytes differ from the release')
(out / 'DCOLYMP').mkdir(parents=True); (out / 'OM3MOD').mkdir()
(out / 'DCOLYMP' / 'E1479999.BIN').write_bytes(newpkg)
(out / 'OM3MOD' / 'GUIDES.BIN').write_bytes(bytes(gd))
for f in ('LABELS.BIN', 'TONES.BIN'):
    (out / 'OM3MOD' / f).write_bytes((gd_p.parent / f).read_bytes())
(out / 'main.bin').write_bytes(bytes(m))
sums = {p: hashlib.sha256((out / p).read_bytes()).hexdigest() for p in ('DCOLYMP/E1479999.BIN', 'OM3MOD/GUIDES.BIN', 'OM3MOD/LABELS.BIN', 'OM3MOD/TONES.BIN')}
(out / 'SHA256SUMS').write_text(''.join(f'{h}  {p}\n' for p, h in sums.items()))
print(f'tag {old_tag:#010x} -> {new_tag:#010x}')
for p, h in sums.items():
    print(h, p)
