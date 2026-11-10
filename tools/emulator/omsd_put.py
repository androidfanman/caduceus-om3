#!/usr/bin/env python3
"""Replace (or create in place) a file in an om-emu OMSD card image's FAT32 volume, without mtools.
Only the case the lab needs: the 8.3 file already exists in DIR and the new content fits its cluster chain.
usage: omsd_put.py IN.omsd OUT.omsd DOS_DIR DOS_NAME LOCAL_FILE   (names upper case, e.g. OM3MOD GUIDES.BIN)"""
import struct, sys
inp, outp, ddir, dname, local = sys.argv[1:6]
b = open(inp, 'rb').read()
assert b[:4] == b'OMSD' and struct.unpack_from('<I', b, 4)[0] == 1
sectors, n = struct.unpack_from('<II', b, 8)
data = {struct.unpack_from('<I', b, 16 + i * 516)[0]: bytearray(b[20 + i * 516:20 + i * 516 + 512]) for i in range(n)}
def sec(k): return data.setdefault(k, bytearray(512))
part = struct.unpack_from('<I', data[0], 0x1c6)[0]
bpb = data[part]
bps, spc, rsv, nfat = struct.unpack_from('<HBHB', bpb, 11)
fatsz = struct.unpack_from('<I', bpb, 36)[0]
root = struct.unpack_from('<I', bpb, 44)[0]
assert bps == 512
fat0 = part + rsv
datastart = part + rsv + nfat * fatsz
def clus_lba(c): return datastart + (c - 2) * spc
def fat_get(c):
    s, o = divmod(c * 4, 512)
    return struct.unpack_from('<I', sec(fat0 + s), o)[0] & 0x0fffffff
def chain(c):
    out = []
    while 2 <= c < 0x0ffffff8:
        out.append(c); c = fat_get(c)
    return out
def read_dir(c):
    raw = bytearray()
    for cl in chain(c):
        for i in range(spc): raw += sec(clus_lba(cl) + i)
    return raw
def find(dirclus, name83):
    for cl in chain(dirclus):
        for i in range(spc):
            s = sec(clus_lba(cl) + i)
            for off in range(0, 512, 32):
                e = s[off:off + 32]
                if e[0] == 0: return None
                if e[0] == 0xe5 or e[11] == 0x0f: continue
                if bytes(e[:11]) == name83: return s, off
    return None
def n83(n):
    base, _, ext = n.partition('.')
    return (base.upper().ljust(8) + ext.upper().ljust(3)).encode()
hit = find(root, n83(ddir)); assert hit, ddir
s, off = hit
dclus = (struct.unpack_from('<H', s, off + 20)[0] << 16) | struct.unpack_from('<H', s, off + 26)[0]
hit = find(dclus, n83(dname)); assert hit, dname
s, off = hit
fclus = (struct.unpack_from('<H', s, off + 20)[0] << 16) | struct.unpack_from('<H', s, off + 26)[0]
ch = chain(fclus)
payload = open(local, 'rb').read()
cap = len(ch) * spc * 512
assert len(payload) <= cap, (len(payload), cap)
pad = payload + bytes(cap - len(payload))
k = 0
for cl in ch:
    for i in range(spc):
        sec(clus_lba(cl) + i)[:] = pad[k * 512:(k + 1) * 512]; k += 1
struct.pack_into('<I', s, off + 28, len(payload))
keys = sorted(data)
out = bytearray(b[:16])
struct.pack_into('<I', out, 12, len(keys))
for key in keys: out += struct.pack('<I', key) + bytes(data[key])
open(outp, 'wb').write(out)
print('replaced', ddir + '/' + dname, len(payload), 'bytes in', len(ch), 'cluster(s) of', spc * 512)
