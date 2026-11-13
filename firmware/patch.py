#!/usr/bin/env python3
"""Make the OM-3 colour editor SD-card update file from OM's official OM-3 firmware 1.1.

The repository holds no OM Digital Solutions firmware. You supply the official file (or let this script ask OM's
own update server for it with --download); the script checks it byte for byte, applies a release's prebuilt patch
(releases/vX/patch.json: only the bytes this project changes, all of them its own code and hooks), re-encodes the
update package and checks the result against the expected checksum. Pure Python 3.8+, no extra packages.
Without --release it makes the newest version, and when run from a terminal it offers the older ones.

Output (in --out, default "SD card files" next to this script):
  DCOLYMP/E1479999.BIN   the modified firmware: copy the DCOLYMP folder to the top of the SD card
  OM3MOD/GUIDES.BIN      page labels for the wheel editor (from v0.20 also the Extras code: keep it with its firmware;
                         up to v0.28: from v0.29 it, LABELS.BIN and TONES.BIN are built into the firmware)
  OM3MOD/LABELS.BIN      the Extras dial labels (v0.20)
  OM3MOD/TONES.BIN       the split toning pages' guides (v0.26)
  restore/E1479999.BIN   the official firmware under the SD-update name, to go back to stock

With no --stock, it looks for the official file next to this script, in the project folder and in Downloads, and
otherwise asks OM's update server for it (the download is checked byte for byte like a local file).

usage: patch.py [--stock OLY_E_147_1100_0000_0000.BIN | --download] [--release v0.17] [--out DIR]
"""
import argparse, hashlib, json, shutil, struct, sys, time
from pathlib import Path
from array import array

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
STOCK_NAME = 'OLY_E_147_1100_0000_0000.BIN'           # the name OM's update server gives the 1.1 file
STOCK_NAMES = (STOCK_NAME, 'OLY_E_147_1100_0000_0000_3.BIN')   # the same file under the name earlier downloads used
PERM = [1, 3, 0, 2, 6, 4, 7, 5, 11, 10, 9, 8, 13, 14, 12, 15]          # decoded[i] = encoded[PERM[i]] ^ 0xff per 16 B
INV = [PERM.index(i) for i in range(16)]
FLIP = bytes(255 - i for i in range(256))


class Refuse(Exception):
    pass


def shuffle(data, perm):
    out = bytearray(len(data))
    for i, p in enumerate(perm):
        out[i::16] = data[p::16]
    return bytes(out).translate(FLIP)


def decode(enc):
    return shuffle(enc, PERM)


def encode(dec):
    return shuffle(bytes(dec), INV)


def wordsum(b):
    a = array('I'); a.frombytes(bytes(b))
    if sys.byteorder == 'big': a.byteswap()
    return sum(a) & 0xFFFFFFFF


def parse(data):
    comps, pos = [], 0
    while pos < len(data):
        hdr = data[pos:pos + 32]
        if len(hdr) < 32 or hdr[:2] != b'OE':
            raise Refuse(f'not an OM firmware package (bad header at {pos:#x})')
        length = struct.unpack_from('<I', hdr, 12)[0]
        if length % 16 or pos + 64 + length > len(data):
            raise Refuse(f'bad component length at {pos:#x}')
        enc = data[pos + 32:pos + 32 + length]
        trl = data[pos + 32 + length:pos + 64 + length]
        if trl[:28] != hdr[:28]:
            raise Refuse(f'header/trailer mismatch at {pos:#x}')
        comps.append(dict(hdr=hdr, enc=enc, trl=trl))
        pos += 64 + length
    return comps


def sha(b):
    return hashlib.sha256(b).hexdigest()


def fetch_stock(size):
    """Ask OM's update server for the OM-3 firmware, as OM Workspace does. Adapted from Caduceus (cakelesscoder/
    caduceus-ep7, Apache-2.0) fetch_stock(); the OM-3 model code is E147."""
    import urllib.request, xml.etree.ElementTree as ET
    t = time.strftime('%Y%m%d%H%M%S', time.gmtime())
    req = ("<?xml version='1.0' encoding='utf-8'?><firmware_demand><revision>0001</revision>"
           "<mac_address>00-00-00-00-00-00</mac_address><time>" + t + "</time><language>ENU</language>"
           "<application>FWUT</application><type>0000</type><version>00005000</version><os>WIN</os>"
           "<country_code>0001</country_code><hardwares><firmup_mode>0</firmup_mode><hardware_info>"
           "<hard_code>OLYE147000000000</hard_code><firmware_version>00001000</firmware_version>"
           "<serial_no>000000000</serial_no></hardware_info></hardwares></firmware_demand>")
    hdrs = {'User-Agent': 'Olympus', 'Content-Type': 'text/xml; Charset=UTF-8'}
    print('Asking OM Digital Solutions for the OM-3 firmware ...')
    try:
        with urllib.request.urlopen(urllib.request.Request('https://fw01.om-digitalsolutions.net/ww_inform/fcache.do',
                                                           req.encode(), hdrs), timeout=60) as r:
            info = ET.fromstring(r.read()).find('.//firmware_info')
        name = info.findtext('file_name') if info is not None else None
        if name not in STOCK_NAMES:
            raise Refuse(f'OM server offered {name!r}, not {STOCK_NAME} (OM may have released newer firmware, which this '
                         'patch does not support). Download the 1.1 file another way and use --stock FILE.')
        url = info.findtext('url')
        print(f'Downloading {STOCK_NAME} from {url.split("/")[2]}')
        buf = bytearray()
        with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Olympus'}), timeout=120) as r:
            while True:
                chunk = r.read(1 << 20)
                if not chunk: break
                buf += chunk
                print(f'\r  {len(buf) >> 20} / {size >> 20} MiB', end='', flush=True)
        print()
        return bytes(buf)
    except (OSError, ET.ParseError) as e:
        raise Refuse(f'download failed: {e}. Download {STOCK_NAME} another way and use --stock FILE.')


def find_stock():
    for d in (HERE, ROOT, Path.cwd(), Path.home() / 'Downloads'):
        for n in STOCK_NAMES:
            p = d / n
            if p.is_file():
                return p
    return None


def white_frames(comp, spec):
    """The Frame Art Effect layers made white (frames.py: white outside the stock window, our own JPEG bytes). Only the
    16-byte groups of the changed layers are decoded and re-encoded; the trailer checksum is moved by their sum."""
    import frames
    base = int(spec['base'], 16)
    enc, trl = bytearray(comp['enc']), bytearray(comp['trl'])
    def region(o, n):
        lo, hi = o & ~15, (o + n + 15) & ~15
        if hi > len(enc):
            raise Refuse('the frame pictures are not where expected')
        return lo, bytearray(decode(bytes(enc[lo:hi])))
    dlo, d = region(0x400, 16 * 32)
    delta = 0
    for k, w, h, x0, x1, y0, y1 in spec['layers']:
        a, n = struct.unpack_from('<II', d, 0x400 + 16 * k - dlo)
        o = a - base
        lo, reg = region(o, n)
        hd = frames.header(w, h)
        if bytes(reg[o + 0x20 - lo:o + 0x20 - lo + len(hd)]) != hd or any(reg[o - lo:o + 0x20 - lo]):
            raise Refuse(f'frame picture {k} is not the expected one')
        new = frames.layer(w, h, (x0, x1, y0, y1))
        if len(new) > n - 0x20:
            raise Refuse(f'frame picture {k}: no room')
        old = bytes(reg)
        reg[o + 0x20 - lo:o + n - lo] = new + bytes(n - 0x20 - len(new))
        delta += wordsum(reg) - wordsum(old)
        enc[lo:lo + len(reg)] = encode(reg)
    struct.pack_into('<I', trl, 28, (struct.unpack_from('<I', trl, 28)[0] - delta) & 0xFFFFFFFF)
    return comp['hdr'] + bytes(enc) + bytes(trl)


def apply(raw, patch):
    if len(raw) != patch['stock_size'] or sha(raw) != patch['stock_sha256']:
        raise Refuse(f'this is not the official {patch["stock_file"]} (size or SHA-256 differs). '
                     'Only OM-3 firmware 1.1 is supported.')
    comps = parse(raw)
    main = bytearray(decode(comps[0]['enc']))
    if sha(main) != patch['main_sha256_before']:
        raise Refuse('the decoded firmware is not the expected one')
    base = int(patch['main_base'], 16)
    for addr, new in patch['runs']:
        o, b = int(addr, 16) - base, bytes.fromhex(new)
        main[o:o + len(b)] = b
    if sha(main) != patch['main_sha256_after']:
        raise Refuse('internal: patched firmware differs from the expected result')
    hdr, trl = comps[0]['hdr'], bytearray(comps[0]['trl'])
    struct.pack_into('<I', trl, 28, 0)
    struct.pack_into('<I', trl, 28, (-(wordsum(hdr) + wordsum(main) + wordsum(trl))) & 0xFFFFFFFF)
    parts = [hdr + encode(main) + bytes(trl)] + [c['hdr'] + c['enc'] + c['trl'] for c in comps[1:]]
    if 'frames' in patch:                          # v0.20: white Frame layers in the resource component
        k = patch['frames']['component']
        parts[k] = white_frames(comps[k], patch['frames'])
    pkg = b''.join(parts)
    if len(pkg) != len(raw) or sha(pkg) != patch['result_sha256']:
        raise Refuse('internal: the update package does not match the expected SHA-256')
    if decode(parse(pkg)[0]['enc']) != bytes(main):
        raise Refuse('internal: re-encoding check failed')
    return pkg


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--stock', help=f'the official {STOCK_NAME}')
    ap.add_argument('--download', action='store_true', help="ask OM's update server for the official file")
    def vkey(v):                                   # v0.28-alpha: a test version sorts before its release v0.28
        num, _, pre = v.lstrip('v').partition('-')
        return [int(x) for x in num.split('.')], pre == '', pre
    rels = sorted((d.name for d in (ROOT / 'releases').iterdir() if (d / 'patch.json').is_file()), key=vkey)
    ap.add_argument('--release', choices=rels, help='version to make (default: the newest, ' + rels[-1] + ')')
    ap.add_argument('--out', default=str(ROOT / 'SD card files'))
    a = ap.parse_args()
    rel = a.release
    if not rel:
        rel = rels[-1]
        if len(rels) > 1 and sys.stdin.isatty():
            try:
                ans = input(f'Version to make [{rel}; older: {", ".join(reversed(rels[:-1]))}]: ').strip()
            except EOFError:
                ans = ''
            if ans:
                ans = ans if ans.startswith('v') else 'v' + ans
                if ans not in rels:
                    print(f'Stopped: there is no release {ans} (choose from {", ".join(rels)}).')
                    return 1
                rel = ans
    rdir = ROOT / 'releases' / rel
    patch = json.loads((rdir / 'patch.json').read_text())
    print(f'{patch["name"]} ({patch["version"]})')
    try:
        if a.stock:
            raw = Path(a.stock).read_bytes()
        elif a.download:
            raw = fetch_stock(patch['stock_size'])
        else:
            p = find_stock()
            if p:
                print(f'Using {p}')
                raw = p.read_bytes()
            else:
                print(f'{STOCK_NAME} is not next to this script or in Downloads, so asking OM for it.')
                try:
                    raw = fetch_stock(patch['stock_size'])
                except Refuse as e:
                    raise Refuse(f'{e}\nPut {STOCK_NAME} (OM-3 firmware 1.1) next to this script or in Downloads '
                                 'and run it again.')
                try:                                   # keep a copy so the next run doesn't download again
                    (ROOT / STOCK_NAME).write_bytes(raw)
                except OSError:
                    pass
        pkg = apply(raw, patch)
    except Refuse as e:
        print('Stopped:', e)
        return 1
    out = Path(a.out)
    cards = [n for n in ('GUIDES.BIN', 'LABELS.BIN', 'TONES.BIN') if (rdir / n).is_file()]   # page labels + Extras code (v0.20), Extras dial labels (v0.20), split toning guides (v0.26); none from v0.29 (built into the firmware)
    for sub in ('DCOLYMP', 'restore') + (('OM3MOD',) if cards else ()):
        (out / sub).mkdir(parents=True, exist_ok=True)
    (out / 'DCOLYMP' / 'E1479999.BIN').write_bytes(pkg)
    (out / 'restore' / 'E1479999.BIN').write_bytes(raw)
    for name in cards:
        shutil.copyfile(rdir / name, out / 'OM3MOD' / name)
    (out / 'VERSION.txt').write_text(f'{patch["name"]} {patch["version"]}\n')
    print(f'Done ({patch["version"]}): {out}')
    if cards:
        print('  Copy DCOLYMP and OM3MOD to the top of the SD card, then hold OK while turning the camera on.')
    else:
        print('  Copy DCOLYMP to the top of the SD card (this version needs no OM3MOD files), then hold OK while turning the camera on.')
    print('  restore/E1479999.BIN is the official firmware: put it in DCOLYMP instead to go back to stock.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
