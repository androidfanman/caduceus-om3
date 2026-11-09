#!/usr/bin/env python3
"""Make releases/vX/patch.json from a developer build (firmware/build.py --out DIR): the changed bytes of the decoded
main block as runs (our code, hooks and tables only), the white Frame layers (rebuilt by patch.py from their window
sizes, frames.py), and the expected checksums. Writes no OM bytes.

usage: tools/mkpatch.py --stock OLY_E_147_1100_0000_0000_3.BIN --build DIR --version v0.20 --description TEXT --out patch.json"""
import argparse, hashlib, json, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'firmware'))
import patch as P                                   # firmware/patch.py: parse/decode
import frames

ap = argparse.ArgumentParser()
for k in ('stock', 'build', 'version', 'description', 'out'):
    ap.add_argument('--' + k, required=True)
a = ap.parse_args()
raw = Path(a.stock).read_bytes()
b = Path(a.build)
main = (b / 'main.bin').read_bytes()
pkg = (b / 'E1479999.BIN').read_bytes()
comps = P.parse(raw)
stock_main = P.decode(comps[0]['enc'])
assert len(stock_main) == len(main)
runs, i, GAP = [], 0, 16
while i < len(main):
    if main[i] == stock_main[i]:
        i += 1; continue
    j = i
    while True:
        k = j
        while k < len(main) and main[k] != stock_main[k]: k += 1
        nxt = k
        while nxt < len(main) and nxt - k <= GAP and main[nxt] == stock_main[nxt]: nxt += 1
        if nxt < len(main) and nxt - k <= GAP:
            j = nxt; continue
        break
    runs.append([hex(0x60021020 + i), main[i:k].hex()]); i = k
out = dict(format='om3-patch-2', name='Caduceus for OM-3', version=a.version, description=a.description,
           stock_file=P.STOCK_NAME, stock_sha256=hashlib.sha256(raw).hexdigest(), stock_size=len(raw),
           main_sha256_before=hashlib.sha256(stock_main).hexdigest(), main_sha256_after=hashlib.sha256(main).hexdigest(),
           result_sha256=hashlib.sha256(pkg).hexdigest(), main_base='0x60021020',
           changed_bytes=sum(x != y for x, y in zip(main, stock_main)),
           frames=dict(component=2, base=hex(frames.BASE), layers=[list(x) for x in frames.LAYERS],
                       note='white Frame layers: rebuilt by patch.py (frames.py), window edges measured from the stock masks'),
           card_files=[n for n in ('GUIDES.BIN', 'LABELS.BIN', 'TONES.BIN') if (Path(a.build) / n).is_file()],   # TONES.BIN: v0.26
           runs=runs)
Path(a.out).write_text(json.dumps(out, indent=0))
print(a.out, len(runs), 'runs', out['changed_bytes'], 'bytes changed')
