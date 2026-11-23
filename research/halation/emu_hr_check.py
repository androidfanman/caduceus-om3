"""The branch's Halation (HL_RUN = hl_sel) in om-emu at every radius, byte for byte against the models: radius 0
(Bloom) against v0.40's research/halation/model.py, radii 1..3 against hr_model.py. Upstream's driver
(research/halation/emu_hl.mjs) runs the pass; hr_rad is poked per case (and hr_busy cleared).

    emu_hr_check.py BUILD_DIR OUT_DIR [--only NAME ...] [--radii 0 1 2 3] [--big] [--jobs N]

--own R: a fixed-radius test build (hr_rad not poked), expected radius R.
--arg: the radius passed as the capture passes it (strength | radius << 8, hr_rad 0), not poked into hr_rad.
--busy: another pass holds the work area, so every radius must fall back to Bloom.
BUILD_DIR: a build of this branch (main.bin, p.elf). Needs OM3_EMU / OM3_CARD. Exit 0 when every case is exact."""
import argparse, concurrent.futures, json, os, pathlib, subprocess, sys
import numpy as np
HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parents[1]
sys.path.insert(0, str(SRC / 'research/halation'))
sys.path.insert(0, str(SRC / 'tools/test'))
import emu_check, model          # noqa: E402  (v0.40's)
import hr_model                  # noqa: E402
T = pathlib.Path(os.environ.get('OM3_TC', pathlib.Path.home() / 'om3-work/toolchain/build'))


def syms(elf):
    nm = subprocess.run([T / 'binutils/nm-new', elf], capture_output=True, text=True).stdout
    return {l.split()[2]: int(l.split()[0], 16) for l in nm.splitlines() if len(l.split()) == 3}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('build', type=pathlib.Path); ap.add_argument('out', type=pathlib.Path)
    ap.add_argument('--only', nargs='+'); ap.add_argument('--radii', nargs='+', type=int, default=[0, 1, 2, 3])
    ap.add_argument('--big', action='store_true'); ap.add_argument('--jobs', type=int, default=3)
    ap.add_argument('--busy', action='store_true', help='hr_busy set: every radius must give Bloom (the fallback)')
    ap.add_argument('--own', type=int, help="a fixed-radius test build: hr_rad left as the build has it, expected this radius")
    ap.add_argument('--arg', action='store_true', help='radius in the strength word (bits 8..9), as xb_gs passes it; hr_rad 0')
    a = ap.parse_args()
    if a.own is not None:
        a.radii = [a.own]
    sy = syms(a.build / 'p.elf')
    out = a.out.resolve(); out.mkdir(parents=True, exist_ok=True)
    names = a.only or [n for n in emu_check.CASES if a.big or n not in emu_check.BIG]
    cases, expect = [], {}
    for n in names:
        make, level = emu_check.CASES[n]
        buf, W, H, pitch = make()
        buf = np.ascontiguousarray(buf, np.uint8)
        (out / f'{n}.in').write_bytes(buf.tobytes())
        for r in a.radii:
            e = buf.copy()
            st = model.halate(e, W, H, pitch, level) if r == 0 or a.busy else hr_model.halate(e, W, H, pitch, level, r)
            k = f'{n}.r{r}'
            expect[k] = (e.tobytes(), st)
            cases.append({'name': k, 'in': str(out / f'{n}.in'), 'out': str(out / f'{k}.out'), 'W': W, 'H': H,
                          'pitch': pitch, 'level': level | (r << 8 if a.arg else 0),
                          'pokes': ([] if a.own is not None else [[sy['hr_rad'], '00' if a.arg else f'{r:02x}']]) + [[sy['hr_busy'], '01' if a.busy else '00']]})
    def run(group):
        spec = out / f'spec-{group[0]["name"]}.json'; res = out / f'res-{group[0]["name"]}.json'
        spec.write_text(json.dumps({'hl_run': sy['hl_sel'], 'flush': 0x60070e69, 'lock': 0x60075f73,
                                    'unlock': 0x60075fbc, 'cases': group}))
        env = {**os.environ, 'OM_EMU_MODEL': 'E147'}
        r = subprocess.run(['node', SRC / 'research/halation/emu_hl.mjs', os.environ['OM3_EMU'], a.build / 'main.bin',
                            os.environ['OM3_CARD'], spec, res], env=env, capture_output=True, text=True)
        if r.returncode:
            raise RuntimeError(r.stderr[-2000:])
        return json.loads(res.read_text())
    groups = [cases[i::a.jobs] for i in range(a.jobs) if cases[i::a.jobs]]
    with concurrent.futures.ThreadPoolExecutor(len(groups)) as pool:
        results = {o['name']: o for g in pool.map(run, groups) for o in g}
    bad = 0
    for cs in cases:
        o = results[cs['name']]
        got = np.frombuffer((out / f'{cs["name"]}.out').read_bytes(), np.uint8)
        want, st = expect[cs['name']]
        want = np.frombuffer(want, np.uint8)
        diff = np.flatnonzero(got != want)
        ok = o['done'] and o['regsBack'] and o['guard'] and diff.size == 0
        bad += not ok
        where = '' if not diff.size else f' first at row {diff[0] // cs["pitch"]} byte {diff[0] % cs["pitch"]}'
        print(f'{"exact" if ok else "DIFF":6}{cs["name"]:<16} {cs["W"]}x{cs["H"]} L{cs["level"] & 255} {st:<4} steps {o["steps"]:>12,} '
              f'locks {o["locks"]:>5} maxlock {o["maxLock"]:>8,}' + ('' if ok else f'  [{diff.size} bytes differ{where}; '
              f'done {o["done"]} regs {o["regsBack"]} guard {o["guard"]}]'), flush=True)
        (out / f'{cs["name"]}.out').unlink()
    for n in names:
        (out / f'{n}.in').unlink()
    print(f'{len(cases) - bad} of {len(cases)} exact')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
