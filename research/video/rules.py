"""List the camera's setting rules (OM-3 1.1 main block) that involve given setting ids.
Record (16 B): {u32 cond_ptr, u16 ncond, u16 ?, u32 table_ptr, u16 ntable, u16 target}. cond entries 8 B
{u16 id, s16 value, u32 ?}; table entries 4 B {s16 from, s16 to}. Layout inferred from the data (analysis).
usage: rules.py DECODED_MAIN ID [ID ...]"""
import struct, sys
d = open(sys.argv[1], 'rb').read(); B = 0x60021020
want = {int(x) for x in sys.argv[2:]}
LO, HI = 0x605b0000, 0x605f0000
inr = lambda p: LO <= p < HI
r = lambda a, n: d[a - B:a - B + n]
for a in range(LO, HI - 16, 4):
    cp, nc, x, tp, nt, tg = struct.unpack('<IHHIHH', r(a, 16))
    if not (inr(cp) and inr(tp) and 0 < nc < 40 and 0 < nt < 80 and x == 0): continue
    conds = [struct.unpack('<Hh', r(cp + 8 * i, 4)) for i in range(nc)]
    tab = [struct.unpack('<hh', r(tp + 4 * i, 4)) for i in range(nt)]
    ids = {c[0] for c in conds} | {tg}
    if ids & want:
        print(f'{a:#x} target {tg}  if {conds}  map {tab}')
