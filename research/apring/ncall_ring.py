#!/usr/bin/env python3
"""Aperture ring (firmware/src/apring.s), emulator only: native cases run on the ring build and on a build without the
ring (the same base), from the same synthetic RAM, then checked. Nothing here is a camera result.

usage: python3 ncall_ring.py EMU_DIR RING_BUILD BASE_BUILD OUT_DIR

Part 1, parser consumption (base build): the stock lens state parser 0x602fc511 is called on a synthetic reply for
every R+21 option byte with the ring bit clear, n 0 / 1 / 3, the first-call K of 69 / 75 / 84 / 90 with each selector
(0 / 8 / 16 / 32), the lens record's block bits (+1676) off / on, and the lens-info getters' answer (0xa32c9c28) giving
the 0x80 block or not. The bytes it reads (a2 at its ret) must be ap_rl's expected length less the 2 ring bytes.
Part 2, hooks (both builds): request (0x603049f6), parser (0x602fc5ed), the count helper (0x60305322, called as the
reply handlers call it) and the 0x80CA getter (0x605ac5e4, mode / AE / lens functions stubbed: last, they overwrite
code). Every result the stock code produces must be the base build's; the ring's own effects as expected.
SEC is SEC_READY (0xa32de58c), the ready mask the stubs test.
Layout (B = scratch base from the driver, SP = its stack): R = B+0x100, command id at B+0x200, reply at B+0x300, lens
record at B+0x1000 (pointer cell 0xa32c9c24 aimed at it)."""
import json, os, subprocess, sys
from pathlib import Path

EMU, RING, BASE, OUT = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3]), Path(sys.argv[4])
REPO = Path(__file__).resolve().parents[2]
NM = Path.home() / 'om3-work/toolchain/build/binutils/nm-new'
SEC, LREC, IDC, FIX, LINFO = 0xa32de58c, 0xa32c9c24, 0x62996006, 0xa32d3d32, 0xa32c9c28
PARSER, HELPER, GETFN = 0x602fc511, 0x60305322, 0x605ac5e4
AV_MODE, AV_AE, AV_LENS = 0x603f088b, 0x6031c0eb, 0x602f6460
ID_LO, ID_HI = 0x1234, 0x0042
ID = ID_HI << 16 | ID_LO


def syms(build):
    out = subprocess.run([NM, build / 'p.elf'], capture_output=True, text=True, check=True).stdout
    return {l.split()[2]: int(l.split()[0], 16) for l in out.splitlines() if len(l.split()) == 3}


S = syms(RING)
ST = {k: S[k] for k in ('ap_id', 'ap_nask', 'ap_nrng', 'ap_na', 'ap_nign', 'ap_nbad', 'ap_nodd', 'ap_val', 'ap_on',
                        'ap_st', 'ap_ok', 'ap_used')}
ST_LO, ST_LEN = ST['ap_id'], ST['ap_used'] + 1 - ST['ap_id']


def le(v, n):
    return (v & (1 << 8 * n) - 1).to_bytes(n, 'little').hex()


def state(ring, rid=ID, val=0x1111, on=1, st=0, ok=0):
    """the state block (ring build only): ID, counters 0, val, on, st, ok, used 0"""
    if not ring:
        return []
    b = bytearray(ST_LEN)
    b[0:4] = rid.to_bytes(4, 'little')
    o = ST['ap_val'] - ST_LO
    b[o:o + 2] = val.to_bytes(2, 'little')
    b[ST['ap_on'] - ST_LO], b[ST['ap_st'] - ST_LO], b[ST['ap_ok'] - ST_LO] = on, st, ok
    return [[f'{ST_LO:#x}', b.hex()]]


def env(flags=0x80, fix=1, sec=0x3ff, idc=(ID_LO, ID_HI), desc=0, linfo=0x140a):
    rec = '00' * 1096 + le(flags, 1) + '000000' + le(ID_LO, 2) + le(ID_HI, 2) + '00' * (1676 - 1104) + le(desc, 4)
    return [['B+0x1000', rec], [f'{LREC:#x}', '=B+0x1000'], [f'{IDC:#x}', le(idc[0], 2) + le(idc[1], 2)],
            [f'{FIX:#x}', le(fix, 1)], [f'{SEC:#x}', le(sec, 4)], [f'{LINFO:#x}', le(linfo, 2)]]


RESTORE = [[f'{SEC:#x}', le(0x3ff, 4)]]


def expected(cmd, n, f, desc, linfo):
    """ap_rl's E (with the 2 ring bytes)"""
    e = 2 * max(n, 1) + 14 + (2 if cmd in (84, 90) else 0)
    e += 16 if f & 0x02 else 0
    e += 4 if f & 0x08 else 0
    f1 = linfo != 2826 and (linfo & 10) != 0
    f2 = 4096 if linfo == 2826 else linfo
    e += 1 if f & 0x80 and desc & 0x02 and f1 and f2 >= 5130 else 0
    e += 1 if f & 0x10 and desc & 0x20 else 0
    e += 5 if f & 0x20 and desc & 0x80 else 0
    return e


def run(build, spec, name):
    d = OUT / name
    d.mkdir(parents=True, exist_ok=True)
    (d / 'spec.json').write_text(json.dumps(spec))
    e = {**os.environ, 'OM_EMU_MODEL': 'E147', 'NCALL': str(d / 'spec.json'), 'NOUT': str(d / 'out.json')}
    lw = syms(build).get('lg_wk')
    if lw:
        e['OM_WORKER_ENTRY'] = f'{lw:x}'
    card = Path.home() / 'om3-work/card-blank.omsd'
    r = subprocess.run(['node', REPO / 'tools/emulator/session_ed1.mjs', EMU, build / 'main.bin', card, d / 'boot.json',
                        d / 'card.omsd', 's1 wait wait ncall'], env=e, capture_output=True, text=True, timeout=1800)
    (d / 'boot.log').write_text(r.stdout + r.stderr)
    if r.returncode or not (d / 'out.json').exists():
        sys.exit(f'{name}: driver exit {r.returncode}, no result ({d}/boot.log)')
    return json.loads((d / 'out.json').read_text())['out']


# ---------------------------------------------------------------- part 1: the stock parser's consumption
KCMD = {0: 69, 1: 75, 4: 84, 5: 90}
cons, meta = [], []
for kb, cmd in KCMD.items():
    for sel in (0, 8, 16, 32):
        for n in (0, 1, 3):
            for desc, linfo in ((0, 0x140a), (0xa2, 0x140a), (0xa2, 0x0001), (0xa2, 0x1409), (0x22, 0x140a)):
                for f in range(0, 256, 2):                      # every option byte with the ring bit clear
                    mem = env(desc=desc, linfo=linfo) + [
                        ['B', 'dd'], ['B+1', f'={PARSER:#x}-B'], ['B+5', 'f030'],   # call 0x602fc511,[d2,d3,a2,a3],48
                        ['SP+4', le(kb | sel, 4)], ['B+0x300', '11' * 96], ['0x629960ba', '00']]
                    cons.append({'name': f'c {cmd} sel{sel} n{n} d{desc:x} i{linfo:x} f{f:02x}', 'mem': mem,
                                 'pc': 'B', 'stop': [f'{PARSER + 0x4ff:#x}', 'B+7'], 'max': 400000,
                                 'regs': {'d0': 'B+0x300', 'd1': f'{n}', 'a0': f'{n}', 'a1': f'{f:#x}'},
                                 'restore': RESTORE})
                    meta.append((cmd, n, f, desc, linfo))
assert PARSER + 0x4ff == 0x602fca10                             # the parser's only ret
res = run(BASE, cons, 'consumption')
B0 = int(json.loads((OUT / 'consumption/out.json').read_text())['B'], 16)
bad = []
for (cmd, n, f, desc, linfo), o in zip(meta, res):
    if int(o['regs']['pc'], 16) != 0x602fca10 or int(o['regs']['d0'], 16) != 0:
        bad.append(f"{o['name']}: no clean return (pc {o['regs']['pc']} d0 {o['regs']['d0']})")
        continue
    got = (int(o['regs']['a2'], 16) - (B0 + 0x300)) & 0xffffffff
    if cmd in (84, 90):
        got += 2        # K & 6 == 4: the last u16 is read at a2 without a2 += 2 (0x602fc84e), so a2 stops 2 short of it
    want = expected(cmd, n, f, desc, linfo) - 2
    if got != want:
        bad.append(f"{o['name']}: the parser read {got} B, ap_rl expects {want} + 2")
print(f'part 1: {len(res)} parser cases, {len(res) - len(bad)} match ap_rl\'s length')
for b in bad[:20]:
    print('  FAIL', b)

# ---------------------------------------------------------------- part 2: the hooks, ring build vs base
def cases(ring):
    cs = []

    def rq(name, cmd, p2=0x0600, st=None, **kw):
        mem = env(**kw) + state(ring, **(st or {})) + [['B+0x100', '00' * 32], ['SP+16', '=B+0x200'],
                                                        ['B+0x200', le(cmd, 2)]]
        cs.append({'name': name, 'mem': mem, 'pc': '0x603049f6', 'stop': ['0x603049fd'], 'restore': RESTORE,
                   'regs': {'d0': f'{p2:#x}', 'd1': 'B+0x115'}, 'read': [['B+0x115', 1], [f'{ST_LO:#x}', ST_LEN]]})

    for c in (69, 75, 84, 90, 81, 88, 1):
        rq(f'rq{c}', c)
    rq('rq69 no-ring-flag', 69, flags=0x00)
    rq('rq69 flags-0x40', 69, flags=0x40)
    rq('rq69 on0', 69, st={'on': 0})
    rq('rq69 on2', 69, st={'on': 2})
    rq('rq69 st2', 69, st={'st': 2})
    rq('rq69 fix0', 69, fix=0)
    rq('rq69 sec6-not-loaded', 69, sec=0x1f)
    rq('rq69 rec-id-mismatch', 69, idc=(ID_LO, 0x0043))
    rq('rq69 id-change', 69, st={'rid': 0x77, 'st': 2, 'ok': 1, 'val': 0x0300})
    rq('rq69 p2-0x0500', 69, p2=0x0500)
    rq('rq69 p2-0x0700', 69, p2=0x0700)

    def ps(name, d2, word, st=None):
        mem = env() + state(ring, **(st or {})) + [['B+0x300', le(word, 2) + 'aaaa'], ['SP+24', 'eeeeeeee']]
        cs.append({'name': name, 'mem': mem, 'pc': '0x602fc5ed', 'stop': ['0x602fc5f3'], 'restore': RESTORE,
                   'regs': {'d2': f'{d2:#x}', 'a2': 'B+0x300'}, 'read': [[f'{ST_LO:#x}', ST_LEN], ['SP+24', 4]]})

    for w in (0x8000, 0x0a37, 0x0000, 0x1000, 0x1001, 0x2000, 0xffff, 0x7fff):
        ps(f'ps {w:#06x}', 0x07, w)
    ps('ps 0x0a37 bit2-clear', 0x03, 0x0a37)
    ps('ps 0x0a37 hi-bits', 0xffffff07, 0x0a37)
    ps('ps no-bit', 0x06, 0x0a37, st={'ok': 1})

    def rl(name, cmd, n, f, recv, desc=0, linfo=0x140a, st=None):
        mem = env(desc=desc, linfo=linfo) + state(ring, **(st or {'ok': 1})) + [
            ['B+0x100', '00' * 32], ['B+0x114', le(n, 1)], ['B+0x115', le(f, 1)], ['B+0x118', le(recv, 2)],
            ['SP+24', '=B+0x100'], ['B', 'dd'], ['B+1', f'={HELPER:#x}-B'], ['B+5', 'c00c']]   # call ..,[d2,d3],12
        cs.append({'name': name, 'mem': mem, 'pc': 'B', 'stop': ['B+7'], 'restore': RESTORE,
                   'regs': {'d0': f'{n:#x}', 'd1': f'{cmd:#x}', 'd2': '0x22222222', 'd3': '0x33333333'},
                   'read': [['B+0x115', 1], [f'{ST_LO:#x}', ST_LEN]], 'meta': [cmd, n, f, recv, desc, linfo]})

    for cmd in (69, 75, 84, 90):
        for n in (0, 3):
            for f, desc, linfo in ((0x07, 0, 0x140a), (0x0f, 0, 0x140a), (0xb7, 0xa2, 0x140a), (0xb7, 0xa2, 0x0001),
                                   (0xb7, 0, 0x140a), (0x97, 0x22, 0x1409), (0x01, 0, 0x140a)):
                e = expected(cmd, n, f, desc, linfo)
                for d in (4, 0, -1, -2, -3, -e + 10):
                    rl(f'rl{cmd} n{n} f{f:02x} d{desc:x} i{linfo:x} L{e + d}', cmd, n, f, e + d, desc, linfo)
    rl('rl69 no-bit', 69, 3, 0x06, 5)
    rl('rl81 no-bit', 81, 3, 0x06, 40)
    rl('rl88 no-bit', 88, 2, 0x86, 7)

    def stub_d0(addr, v, ret):
        return [f'{addr:#x}', 'fccc' + le(v, 4) + ret]

    def av(name, mode, ae=4, lens=True, st=None, **kw):
        s = {'val': 0x0a37, 'ok': 1}
        s.update(st or {})
        mem = env(**kw) + state(ring, **s) + [stub_d0(AV_MODE, mode, 'df8008'), stub_d0(AV_AE, ae, 'df0004'),
                                              ['B', 'dd'], ['B+1', f'={GETFN:#x}-B'], ['B+5', '0004']]   # call ..,[],4
        if not lens:
            mem.append([f'{AV_LENS:#x}', 'fcdc00000000df8008'])                  # mov 0,a0; ret [d2],8
        cs.append({'name': name, 'mem': mem, 'pc': 'B', 'stop': ['B+7'], 'restore': RESTORE,
                   'read': [[f'{ST_LO:#x}', ST_LEN]], 'av': [mode, ae, lens, s, kw]})

    for m in (2, 4, 1, 3):
        av(f'av mode{m}', m)
    av('av C1 ae4', 53, 4)
    av('av C4 ae6', 56, 6)
    av('av C5 ae4', 63, 4)
    av('av C5 ae6', 63, 6)
    av('av C2 ae1', 54, 1)
    av('av C3 ae3', 55, 3)
    av('av mode57 ae4', 57, 4)
    av('av mode52 ae4', 52, 4)
    av('av mode62 (B)', 62, 4)
    av('av mode2 ok0', 2, st={'ok': 0})
    av('av mode2 on0', 2, st={'on': 0})
    av('av mode2 on2', 2, st={'on': 2})
    av('av mode2 sec6-not-loaded', 2, sec=0x1f)
    av('av mode2 no-ring-flag', 2, flags=0)
    av('av mode2 other-lens-id', 2, st={'rid': 0x77})
    av('av mode2 fix0', 2, fix=0)
    av('av mode2 val0x1000', 2, st={'val': 0x1000})
    av('av mode2 val0x8000 ok1 (torn)', 2, st={'val': 0x8000})
    av('av mode2 no-lens', 2, lens=False)
    return cs


rc, bc = cases(True), cases(False)
R = run(RING, [{k: v for k, v in c.items() if k not in ('meta', 'av')} for c in rc], 'hooks-ring')
B = run(BASE, [{k: v for k, v in c.items() if k not in ('meta', 'av')} for c in bc], 'hooks-base')


def st(h):
    b = bytes.fromhex(h)
    g = lambda k, n=1: int.from_bytes(b[ST[k] - ST_LO:ST[k] - ST_LO + n], 'little')
    return {'id': g('ap_id', 4), 'ask': g('ap_nask', 4), 'rng': g('ap_nrng', 4), 'na': g('ap_na', 4),
            'ign': g('ap_nign', 4), 'bad': g('ap_nbad', 4), 'odd': g('ap_nodd', 4), 'val': g('ap_val', 2),
            'on': g('ap_on'), 'st': g('ap_st'), 'ok': g('ap_ok'), 'used': g('ap_used')}


fails, n2 = [], 0
for c, r, b in zip(rc, R, B):
    n2 += 1
    nm, rr, br = c['name'], r['regs'], b['regs']
    why = []
    s = st(r['mem'][0] if nm.startswith('ps') or nm.startswith('av') else r['mem'][1])
    if nm.startswith('rq'):
        flags_r, flags_b = int(r['mem'][0], 16), int(b['mem'][0], 16)
        p2 = int(c['regs']['d0'], 16)
        cmd = int(nm[2:].split()[0])
        gated = not any(k in nm for k in ('no-ring-flag', 'flags-0x40', 'on0', 'on2', 'st2', 'fix0', 'sec6',
                                          'id-mismatch'))
        ask = cmd in (69, 75, 84, 90) and gated
        if flags_b != (p2 >> 8) & 255:
            why.append(f'base flags {flags_b:#x}')
        if flags_r != flags_b | (1 if ask else 0):
            why.append(f'ring flags {flags_r:#x} (asked {ask})')
        for k in ('d1', 'a0'):
            if rr[k] != br[k]:
                why.append(f'{k} {rr[k]} != base {br[k]}')
        if 'id-change' in nm and (s['id'] != ID or s['ok'] or s['st']):
            why.append(f'not re-keyed {s}')
        if s['ask'] != (1 if ask else 0):
            why.append(f"asked count {s['ask']}")
    elif nm.startswith('ps'):
        d2 = int(c['regs']['d2'], 16)
        w = int(c['mem'][-2][1][:4][2:] + c['mem'][-2][1][:2], 16)
        asked = d2 & 1
        da = int(rr['a2'], 16) - int(br['a2'], 16)
        if da != (2 if asked else 0):
            why.append(f'a2 moved {da}')
        if (int(rr['psw'], 16) ^ int(br['psw'], 16)) & 0xf:
            why.append(f"flags {rr['psw']} != base {br['psw']}")
        if r['mem'][1] != b['mem'][1]:
            why.append(f"(24,sp) {r['mem'][1]} != base {b['mem'][1]}")
        if asked:
            want_ok = 1 if w <= 0x1000 else 0
            want_st = 0 if w <= 0x1000 or w == 0x8000 else 2
            if s['ok'] != want_ok or s['st'] != want_st or (want_ok and s['val'] != w):
                why.append(f'state {s} for word {w:#x}')
        elif s['ok'] != 1 or s['val'] != 0x1111:
            why.append(f'state touched {s}')
    elif nm.startswith('rl'):
        cmd, n, f, recv, desc, linfo = c['meta']
        fr, fb = int(r['mem'][0], 16), int(b['mem'][0], 16)
        for k in ('d0', 'd2', 'd3', 'sp'):
            if rr[k] != br[k]:
                why.append(f'{k} {rr[k]} != base {br[k]}')
        if fb != f:
            why.append(f'base flags changed {fb:#x}')
        if f & 1 and cmd in (69, 75, 84, 90):
            e = expected(cmd, n, f, desc, linfo)
            if recv >= e:
                want = (f, 0, 1, 0, 0)
            elif recv == e - 2:
                want = (f & ~1, 2, 0, 1, 0)
            else:
                want = (f & ~1, 2, 0, 0, 1)
            got = (fr, s['st'], s['ok'], s['ign'], s['bad'])
            if got != want:
                why.append(f'(flags, st, ok, ignored, short) {got} != {want} (E {e})')
        elif fr != f or s['st'] or s['ok'] != 1:
            why.append(f'touched without the bit: flags {fr:#x} {s}')
    elif nm.startswith('av'):
        mode, ae, lens, s_in, kw = c['av']
        body = int(br['d0'], 16)
        am = mode in (2, 4) or ((53 <= mode <= 56 or mode == 63) and ae in (4, 6))
        ok = (am and lens and s_in.get('ok') == 1 and s_in.get('on', 1) == 1 and kw.get('sec', 0x3ff) & 0x20
              and kw.get('flags', 0x80) & 0x80 and kw.get('fix', 1) == 1 and s_in.get('rid', ID) == ID
              and s_in['val'] <= 0x1000)
        want = s_in['val'] if ok else body
        got = int(rr['d0'], 16)
        exth = lambda v: (v & 0xffff) | (0xffff0000 if v & 0x8000 else 0)
        if got != exth(want):
            why.append(f'd0 {got:#x}, want {exth(want):#x} (body {body:#x})')
        for k in ('d2', 'd3', 'a2', 'a3', 'sp'):
            if rr[k] != br[k]:
                why.append(f'{k} {rr[k]} != base {br[k]}')
        if s['used'] != (1 if ok else 0):
            why.append(f"used {s['used']}")
    if why:
        fails.append(f'{nm}: ' + '; '.join(why))
print(f'part 2: {n2} hook cases, {n2 - len(fails)} pass')
for x in fails:
    print('  FAIL', x)
sys.exit(1 if bad or fails else 0)
