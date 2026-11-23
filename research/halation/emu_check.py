#!/usr/bin/env python3
"""The firmware's halation pass (editor.s `hl_run`) against the exact model (model.py), bit for bit, in om-emu.

    python3 research/halation/emu_check.py BUILD_DIR [--out DIR] [--only NAME ...] [--jobs N] [--profile] [--card C]

BUILD_DIR is a firmware/build.py --out folder (main.bin, p.elf). Each case is a test frame in the camera's buffer
format (YCbYCr 4:2:2, rows `pitch` bytes apart: the padding past 2 W bytes must stay as it is): synthetic night scenes,
odd sizes, a frame that fades out (8..24 % bright cells), daylight (no halation), dark (no glow), chroma at the clamp
ends, and five CC0 / public-domain sample photos from webapp/public/samples. emu_hl.mjs runs `hl_run` on each in om-emu
(single steps = instructions; FLUSH stubbed) and the result must equal model.halate's byte for byte, with the
callee-saved registers, sp and a guard after the frame intact, and every block malloc handed out during the case given
back to free exactly once (speed-1: hl_run's grids come from hl_ga / hl_gf). Prints one line per case: steps, LOCK / FLUSH calls,
the most instructions run under one lock. --profile adds steps per function (and per phase label in hl_run).
Exit 0 when every case is bit-exact.
"""
import argparse, concurrent.futures, json, os, pathlib, subprocess, sys, tempfile
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parents[1]
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(REPO / 'tools' / 'test'))
import model  # noqa: E402
from emu_test import elf_symbols  # noqa: E402

DRIVER = HERE / 'emu_hl.mjs'
SAMPLES = REPO / 'webapp' / 'public' / 'samples'


def smooth(rng, H, W, k):
    """Low-frequency noise in -1..1: a coarse random grid, upsampled."""
    g = rng.uniform(-1, 1, ((H + k - 1) // k + 1, (W + k - 1) // k + 1))
    ys, xs = np.arange(H) / k, np.arange(W) / k
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = (ys - y0)[:, None], (xs - x0)[None, :]
    a, b = g[y0][:, x0], g[y0][:, x0 + 1]
    c, d = g[y0 + 1][:, x0], g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def pack(Y, Cb, Cr, pad, rng):
    """Y (H, W), Cb / Cr (H, W/2) floats -> the 4:2:2 buffer with pad pixels of random bytes after each row."""
    H, W = Y.shape
    q = lambda a: np.clip(np.rint(a), 0, 255).astype(np.uint8)
    rows = np.empty((H, W // 2, 4), np.uint8)
    rows[..., 0], rows[..., 2] = q(Y[:, 0::2]), q(Y[:, 1::2])
    rows[..., 1], rows[..., 3] = q(Cb), q(Cr)
    buf = rows.reshape(H, 2 * W)
    if pad:
        buf = np.concatenate([buf, rng.integers(0, 256, (H, 2 * pad), dtype=np.uint8)], axis=1)
    return buf.reshape(-1).copy(), W, H, 2 * (W + pad)


def night(W, H, seed, grain=0.0, pad=0, lights=None, base=35, extreme=False, windows=None, strip=True, rmax=12):
    rng = np.random.default_rng(seed)
    lights = max(1, W * H // 150000) if lights is None else lights
    windows = W * H // 800000 if windows is None else windows
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float64)
    Y = base + 25 * smooth(rng, H, W, 97) + 10 * yy / H
    Cb = 128 + 18 * smooth(rng, H, W // 2, 61)
    Cr = 128 + 18 * smooth(rng, H, W // 2, 53)
    for _ in range(lights):                      # bulbs: a clipped core and a soft falloff
        cx, cy, r = rng.uniform(0, W), rng.uniform(0, H), rng.uniform(1.5, rmax)
        d2 = (xx - cx) ** 2 + (yy - cy) ** 2
        Y = np.maximum(Y, 270 * np.exp(-d2 / (2 * r * r)))
    for _ in range(windows):                     # lit windows
        x0, y0 = rng.integers(0, W - 8), rng.integers(0, H - 8)
        w, h = rng.integers(6, max(7, W // 24)), rng.integers(6, max(7, H // 24))
        Y[y0:y0 + h, x0:x0 + w] = rng.uniform(205, 245)
    if strip:                                    # a 4 px LED strip
        y0 = int(H * 0.7)
        Y[y0:y0 + 4, W // 8: W // 8 + W // 5] = 250
    for _ in range(W * H // 40000):               # single bright pixels
        Y[rng.integers(0, H), rng.integers(0, W)] = rng.uniform(200, 255)
    if grain:
        Y = Y + rng.normal(0, grain, Y.shape)
    if extreme:                                  # chroma at both clamp ends near lights
        Cb[:, : W // 4] = rng.uniform(0, 6, (H, W // 4))
        Cr[:, W // 4:] = rng.uniform(249, 255, (H, W // 2 - W // 4))
    return pack(Y, Cb, Cr, pad, rng)


def flat(W, H, seed, lo, hi, pad=0, spots=0):
    rng = np.random.default_rng(seed)
    Y = lo + (hi - lo) * (0.5 + 0.5 * smooth(rng, H, W, 71))
    for _ in range(spots):
        x0, y0 = rng.integers(0, W - 40), rng.integers(0, H - 40)
        Y[y0:y0 + 40, x0:x0 + 40] = 250
    return pack(Y, 128 + 10 * smooth(rng, H, W // 2, 41), 128 + 10 * smooth(rng, H, W // 2, 43), pad, rng)


def random_bytes(W, H, seed, ymax):
    rng = np.random.default_rng(seed)
    b = rng.integers(0, 256, (H, 2 * W), dtype=np.uint8)
    b[:, 0::2] = (b[:, 0::2].astype(np.int64) * ymax // 255).astype(np.uint8)   # Y 0..ymax, chroma anything
    return b.reshape(-1).copy(), W, H, 2 * W


def photo(name, gamma=2.2, scale=1.0):
    """A sample photo as a night shot: Y' = 255 (Y / 255)^gamma (the lights stay bright, the rest goes dark);
    scale > 1: enlarged (bicubic), so the lights cover as few 64 px cells as on the camera's 20 MP."""
    from PIL import Image
    im = Image.open(SAMPLES / name).convert('RGB')
    if scale != 1.0:
        im = im.resize((int(im.width * scale), int(im.height * scale)), Image.BICUBIC)
    buf, W, H, pitch = model.to_buf(np.asarray(im))
    y = buf.reshape(H, W // 2, 4)[..., 0::2]
    y[...] = np.rint(255 * (y / 255.0) ** gamma).astype(np.uint8)
    return buf, W, H, pitch


CASES = {   # name: (frame maker, level)
    'night5': (lambda: night(1536, 1152, 1, pad=16, lights=4, windows=1), 5),
    'night1': (lambda: night(1536, 1152, 1, pad=16, lights=4, windows=1), 1),
    'grain4': (lambda: night(1536, 1152, 2, grain=20, pad=16, lights=4, windows=1), 4),
    'fade3': (lambda: flat(1024, 768, 3, 20, 120, spots=1), 3),
    'day5': (lambda: flat(1024, 768, 4, 150, 250), 5),
    'dark5': (lambda: flat(1024, 768, 5, 10, 150), 5),
    'odd2': (lambda: night(1000, 700, 6, pad=24, lights=2, windows=0), 2),
    'small5': (lambda: night(320, 256, 7, lights=1, windows=0, strip=False, rmax=2), 5),
    'min5': (lambda: night(64, 320, 8, lights=1, windows=0, strip=False, rmax=1.5), 5),
    'w68': (lambda: night(68, 512, 9, lights=1, windows=0, strip=False, rmax=1.5), 5),
    'odd131': (lambda: night(1028, 131, 10, lights=1, windows=0, strip=False, rmax=4), 5),
    'clamp5': (lambda: night(768, 512, 11, extreme=True, lights=2, windows=0, strip=False), 5),
    'sparse5': (lambda: night(1536, 1152, 12, lights=4, windows=0, strip=False), 5),
    'random3': (lambda: random_bytes(512, 384, 13, 206), 3),
    'random5off': (lambda: random_bytes(512, 384, 14, 255), 5),
    'neon5': (lambda: photo('neon.jpg'), 5),
    'paris5': (lambda: photo('paris.jpg'), 5),
    'taxi3': (lambda: photo('taxi.jpg'), 3),
    'bluehour5': (lambda: photo('bluehour.jpg'), 5),
    'big5': (lambda: night(5184, 3888, 15, lights=12, windows=2), 5),
    'bigphoto5': (lambda: photo('bluehour.jpg', scale=2.5), 5),
}
BIG = ('big5', 'bigphoto5')   # camera-sized (16-20 MP): for the counts, not in the default run


def run_driver(build, cards, out, spec_cases, profile):
    spec = out / f'spec-{spec_cases[0]["name"]}.json'
    res = out / f'res-{spec_cases[0]["name"]}.json'
    syms = elf_symbols(build / 'p.elf')
    spec.write_text(json.dumps({'hl_run': syms['hl_run'], 'flush': syms['FLUSH'], 'lock': syms['LOCK'],
                                'unlock': syms['UNLOCK'], 'malloc': syms['malloc'], 'free': syms['free'],
                                'cases': spec_cases}))
    env = {**os.environ, 'OM_EMU_MODEL': 'E147', **({'PROFILE': '1'} if profile else {})}
    r = subprocess.run(['node', DRIVER, os.environ['OM3_EMU'], build / 'main.bin', cards, spec, res], env=env,
                       capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f'emu_hl.mjs exit {r.returncode}: {r.stderr[-2000:]}')
    return json.loads(res.read_text())


def profile_lines(prof, syms):
    """steps per pc -> per symbol (the nearest one at or below the pc; FLUSH / LOCK / ... are stock)."""
    table = sorted((v, k) for k, v in syms.items() if 0x60000000 <= v < 0x70000000 and not k.startswith('.'))
    import bisect
    addrs = [a for a, _ in table]
    tot = {}
    for pc, n in prof.items():
        i = bisect.bisect_right(addrs, int(pc, 16)) - 1
        name = table[i][1] if i >= 0 else '?'
        tot[name] = tot.get(name, 0) + n
    return sorted(tot.items(), key=lambda kv: -kv[1])


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('build', type=pathlib.Path)
    ap.add_argument('--out', type=pathlib.Path)
    ap.add_argument('--only', nargs='+', choices=list(CASES))
    ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--profile', action='store_true')
    ap.add_argument('--card', help='an om-emu card image to boot with (default $OM3_CARD)')
    a = ap.parse_args()
    card = a.card or os.environ.get('OM3_CARD')
    if not os.environ.get('OM3_EMU') or not card:
        sys.exit('OM3_EMU / OM3_CARD not set: . ~/om3-work/env.sh')
    build = a.build.resolve()
    out = (a.out or pathlib.Path(tempfile.mkdtemp(prefix='hl-check-'))).resolve()
    out.mkdir(parents=True, exist_ok=True)
    names = a.only or [n for n in CASES if n not in BIG]
    cases, expect = [], {}
    for n in names:
        make, level = CASES[n]
        buf, W, H, pitch = make()
        buf = np.ascontiguousarray(buf, np.uint8)
        (out / f'{n}.in').write_bytes(buf.tobytes())
        e = buf.copy()
        status = model.halate(e, W, H, pitch, level)
        expect[n] = (e.tobytes(), status)
        cases.append({'name': n, 'in': str(out / f'{n}.in'), 'out': str(out / f'{n}.out'), 'W': W, 'H': H,
                      'pitch': pitch, 'level': level})
    groups = [cases[i::a.jobs] for i in range(a.jobs) if cases[i::a.jobs]]
    with concurrent.futures.ThreadPoolExecutor(len(groups)) as pool:
        results = [o for g in pool.map(lambda g: run_driver(build, card, out, g, a.profile), groups)
                   for o in g]
    syms = elf_symbols(build / 'p.elf') if a.profile else None
    bad = 0
    for cs in cases:
        o = next(r for r in results if r['name'] == cs['name'])
        got = (out / f'{cs["name"]}.out').read_bytes()
        want, status = expect[cs['name']]
        orig = (out / f'{cs["name"]}.in').read_bytes()
        diff = np.flatnonzero(np.frombuffer(got, np.uint8) != np.frombuffer(want, np.uint8))
        changed = int((np.frombuffer(want, np.uint8) != np.frombuffer(orig, np.uint8)).sum())
        heap_ok = o.get('heap') is None or o['heap']['same']   # speed-1: every block malloc gave, freed once
        ok = o['done'] and o['regsBack'] and o['guard'] and diff.size == 0 and heap_ok
        bad += not ok
        where = '' if not diff.size else f' first at row {diff[0] // cs["pitch"]} byte {diff[0] % cs["pitch"]}'
        print(f'{"exact" if ok else "DIFF":<6}{cs["name"]:<11} {cs["W"]}x{cs["H"]} L{cs["level"]} {status:<4} '
              f'{changed:>8} B changed  steps {o["steps"]:>11,}  locks {o["locks"]:>5}  flushes {o["flushes"]:>5}  '
              f'max under lock {o["maxLock"]:>8,}' + ('' if ok else f'  [{diff.size} bytes differ{where}; done '
              f'{o["done"]} regs {o["regsBack"]} guard {o["guard"]} heap {o.get("heap")}]'))
        if a.profile and 'profile' in o:
            print('      ' + ', '.join(f'{k} {v:,}' for k, v in profile_lines(o['profile'], syms)[:12]))
    (out / 'results.json').write_text(json.dumps([{k: v for k, v in r.items() if k != 'profile'} for r in results], indent=1))
    print(f'{len(cases) - bad} of {len(cases)} bit-exact; files in {out}')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
