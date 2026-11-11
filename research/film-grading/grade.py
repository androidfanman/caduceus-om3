"""Camera grading for the OM-3 film looks (2026-11-11). See README.md in this folder.

The model: per chart patch, a ridge regression of the measured change in lightness, chroma and hue (LCh) on the
look's sliders (camera_response.json 'rows'), plus a split-toning model (tint vector per wheel colour, scaled by the
patch's brightness and a fitted 2x2 response per patch, from 'split_test'). Everything is camera-measured; only the
split colours Red, Violet, Green-cyan and Yellow-green are interpolated (guess) and never chosen by the solver.

usage (see README.md):
  python3 webapp/scripts/films.py --recipes /tmp/recipes.json      the looks as designed (no GRADED)
  node preview_chart.ts (bundled) /tmp/recipes.json /tmp/preview_chart.json
  python3 grade.py /tmp/recipes.json /tmp/preview_chart.json [out.json]
regrades every look except the camera's 20 so the camera matches its recipe's preview; the result goes into GRADED."""
import json, os, sys
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
D = json.load(open(os.path.join(HERE, 'camera_response.json')))
SEC = D['sectors']; PN = D['patches']
SIDX = ['Y', 'O', 'OR', 'R', 'M', 'V', 'B', 'BC', 'C', 'GC', 'G', 'YG']
Bc = np.array(D['base_lch'])

# --- colour helpers ---
def lab(rgb):
    c = np.array(rgb) / 255; c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    M = np.array([[0.4124, 0.3576, 0.1805], [0.2126, 0.7152, 0.0722], [0.0193, 0.1192, 0.9505]]); X = M @ c
    X = X / np.array([0.95047, 1, 1.08883]); f = np.where(X > 0.008856, np.cbrt(X), 7.787 * X + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])
def lch(P): return np.stack([P[:, 0], np.hypot(P[:, 1], P[:, 2]), np.degrees(np.arctan2(P[:, 2], P[:, 1])) % 360], 1)
def lab_of_lch(P):
    h = np.radians(P[:, 2]); return np.stack([P[:, 0], P[:, 1] * np.cos(h), P[:, 1] * np.sin(h)], 1)
def dd(a, b):
    d = a - b; d[:, 2] = (d[:, 2] + 180) % 360 - 180; return d

# --- slider model ---
def feat(st):
    h = np.array(st['hue'], float); l = np.array(st['light'], float); s = np.array(st['sat'], float)
    tone = [st['con'], st['hl'], st['sh'], st['mid'], st['blk'], st['wht']]
    ab, gm = (st['wb'][1], st['wb'][2]) if st['wb'][0] else (0, 0)
    return np.concatenate([np.maximum(h, 0), np.minimum(h, 0), l, np.maximum(s, 0), np.minimum(s, 0), tone, [ab, gm], [0.0]])
XA = np.array([r['x'] for r in D['rows']]); Y = np.array([r['d_lch'] for r in D['rows']]); LAM = np.array(D['lam'])
W = np.zeros((24, 3, XA.shape[1]))
for i in range(24):
    for o in range(3): W[i, o] = np.linalg.solve(XA.T @ XA + np.diag(LAM), XA.T @ Y[:, i, o])

# --- split-toning model ---
ST = D['split_test']; N = np.array(ST['null_lab']); gL = N[18:, 0]; order = np.argsort(gL)
tests = [(t['side'], SEC.index(t['colour']), t['strength'], np.array(t['lab']) - N) for t in ST['tests']]
def _curve(side):
    d = [t[3] for t in tests if t[0] == side and t[1] == 1 and t[2] == 4][0][18:, 2]; return d / d.max()
CURVE = {'SH': _curve('SH'), 'HI': _curve('HI')}
def wgt(Lv, side): return np.interp(Lv, gL[order], CURVE[side][order])
def peak(ab, side):
    wc = wgt(N[:, 0], side); return (wc[:, None] * ab).sum(0) / (wc ** 2).sum()
VEC = {'SH': {}, 'HI': {}}; acc = {'SH': {}, 'HI': {}}; PV = []
for side, c, s, d in tests:
    v = peak(d[:, 1:], side); PV.append((side, v, d)); acc[side].setdefault(c, []).append(v / s)
for side in VEC:
    for c, v in acc[side].items(): VEC[side][c] = np.mean(v, 0)
hi_o1 = [t[3] for t in tests if t[0] == 'HI' and t[1] == 1 and t[2] == 1][0]
VEC['SH'][7] = peak((np.array(ST['combo_SH_BC1_HI_O1_lab']) - N - hi_o1)[:, 1:], 'SH')
VEC['HI'][7] = VEC['SH'][7] * np.mean([np.hypot(*VEC['HI'][k]) / np.hypot(*VEC['SH'][k]) for k in VEC['HI']])
MEASURED = sorted(VEC['SH'])
for side in VEC:
    for k in range(12):
        if k in VEC[side]: continue
        a, b = VEC[side][(k - 1) % 12], VEC[side][(k + 1) % 12]
        ha, hb = np.arctan2(a[1], a[0]), np.arctan2(b[1], b[0]); dh = (hb - ha + np.pi) % (2 * np.pi) - np.pi
        h = ha + dh / 2; m = (np.hypot(*a) + np.hypot(*b)) / 2; VEC[side][k] = m * np.array([np.cos(h), np.sin(h)])
MP = {}
for side in ('SH', 'HI'):
    X = np.array([v for s_, v, _ in PV if s_ == side])
    MP[side] = np.array([np.linalg.lstsq(X, np.array([d[p, 1:] for s_, _, d in PV if s_ == side]), rcond=None)[0] for p in range(24)])
def split_ab(sp):
    out = np.zeros((24, 2))
    if not sp: return out
    for side, idx, s in (('SH', sp[0], sp[1]), ('HI', sp[2], sp[3])):
        if s: out += np.einsum('j,pjk->pk', VEC[side][idx] * s, MP[side])
    return out
WBG = D['wb_greys']
def wb_ab(ab, gm): return np.array([WBG['a_per_ab'] * ab + WBG['a_per_gm'] * gm, WBG['b_per_ab'] * ab + WBG['b_per_gm'] * gm])

def predict(st):
    """Predicted chart LCh on the camera for a look (st: hue/light/sat lists, con/hl/sh/mid/blk/wht, wb [on, a_b, g_m],
    sp (sh colour index, strength, hl colour index, strength) or None)."""
    P = Bc + np.einsum('iof,f->io', W, feat(st)); X = lab_of_lch(P); X[:, 1:] += split_ab(st.get('sp')); return lch(X)

# --- matching a look's preview ---
GR = [19, 20, 21, 22]
PW = np.ones(18); PW[4] = 2.5; PW[5] = 1.5
def from_film(f):
    t = f['tone']; wb = f['wb']; sp = f.get('split')
    return dict(con=f['contrast'], hl=t['highlights'], sh=t['shadows'], mid=t['midtones'], blk=t['blacks'], wht=t['whites'],
                wb=[1, wb['a_b'], wb['g_m']] if wb else [0, 0, 0], hue=list(f['hue']), light=list(f['light']), sat=list(f['sat']),
                sp=(sp['sh_color'], sp['sh'], sp['hl_color'], sp['hl']) if sp and (sp['sh'] or sp['hl']) else None)
def gab(st):
    w = np.array(st['wb'][1:]) if st['wb'][0] else np.zeros(2); return wb_ab(*w) + split_ab(st['sp'])
def match(a, T):
    """a: the look's own settings (from_film); T: target chart LCh (24 x 3). Returns the camera settings."""
    TX = lab_of_lch(T); g0 = lab_of_lch(Bc)[:, 1:]
    def fit_cost(st):
        P = predict(st); c = 0
        for i in range(18):
            dh = (P[i, 2] - T[i, 2] + 180) % 360 - 180
            c += PW[i] * (((P[i, 1] - T[i, 1]) / 3) ** 2 + (min(P[i, 1], T[i, 1]) / 40) * (dh / 4) ** 2 + ((P[i, 0] - T[i, 0]) / 3) ** 2)
        G = g0 + gab(st)
        return c + sum(1.5 * np.sum((G[i] - TX[i, 1:]) ** 2) / 1.5 ** 2 for i in GR), P, G
    def sp_pen(sp):
        c = 0
        if sp:
            for k in (0, 2):
                if sp[k + 1]:
                    same = a['sp'] and a['sp'][k] == sp[k] and a['sp'][k + 1]
                    c += (0.3 if same else 1.5) + 0.5 * abs(sp[k + 1])
        return c
    def cost(st):
        c = fit_cost(st)[0]
        c += 0.12 * np.sum(np.array(st['sat']) ** 2) + 0.5 * np.sum(np.array(st['hue']) ** 2) + 0.4 * np.sum(np.array(st['light']) ** 2)
        return c + 0.15 * np.sum(np.array(st['wb'][1:]) ** 2) + sp_pen(st['sp'])
    TT = {i: TX[i, 1:] - g0[i] for i in GR}
    cands = [None] + [(x, s, y, t) for x in MEASURED for s in (0, 1, 2) for y in MEASURED for t in (0, 1, 2)
                      if (s or t) and (s or x == 0) and (t or y == 0)]
    if a['sp'] and a['sp'] not in cands: cands.append(a['sp'])
    def gcost(ab, gm, sp):
        G = gab({'wb': [1, ab, gm], 'sp': sp})
        return sum(1.5 * np.sum((G[i] - TT[i]) ** 2) / 1.5 ** 2 for i in GR) + 0.15 * (ab * ab + gm * gm) + sp_pen(sp)
    sc = sorted((gcost(x, y, sp), x, y, sp) for sp in cands for x in range(-4, 5) for y in range(-3, 4) if x * a['wb'][1] >= 0)[:3]
    best = None
    for _, ab, gm, sp in sc:
        st = dict(a, wb=[1 if (ab or gm) else 0, ab, gm], sp=sp); st['hue'] = [int(np.clip(v, -5, 5)) for v in a['hue']]
        c = cost(st)
        free = [(k, i) for k in ('hue', 'light', 'sat') for i in range(12) if i != 3]   # Red: no chart patch
        for _ in range(40):
            imp = False
            for k, i in free:
                for d in (1, -1):
                    s2 = dict(st); s2[k] = list(st[k]); s2[k][i] = int(np.clip(s2[k][i] + d, -5, 5)); cy = cost(s2)
                    if cy < c - 1e-6: st, c, imp = s2, cy, True
            if not imp: break
        if best is None or c < best[0]: best = (c, st)
    st = best[1]
    def mism(s):
        _, P, G = fit_cost(s)
        e = np.c_[P[:18, 0] - T[:18, 0], P[:18, 1] - T[:18, 1], np.radians((P[:18, 2] - T[:18, 2] + 180) % 360 - 180) * T[:18, 1]]
        return np.linalg.norm(e, axis=1).mean(), np.mean([np.linalg.norm(G[i] - TX[i, 1:]) for i in GR])
    return st, mism(a), mism(st)

if __name__ == '__main__':
    films = json.load(open(sys.argv[1])); pv = json.load(open(sys.argv[2]))
    blank = lch(np.array([lab(c) for c in pv['__blank__']]))
    out = {}; R = []
    for f in films['films']:
        n = f['name']
        if n in films['camera']: continue   # the camera's 20 are graded against film references, not the preview
        T = Bc + dd(lch(np.array([lab(c) for c in pv[n]])), blank); T[:, 2] %= 360
        st, m0, m1 = match(from_film(f), T); out[n] = st; R.append(m0 + m1)
        print(f'{n:16s} camera vs preview dE {m0[0]:4.1f} -> {m1[0]:4.1f}   grey tint {m0[1]:3.1f} -> {m1[1]:3.1f}')
    print('mean dE %.2f -> %.2f, grey tint %.2f -> %.2f' % (np.mean([r[0] for r in R]), np.mean([r[2] for r in R]), np.mean([r[1] for r in R]), np.mean([r[3] for r in R])))
    json.dump(out, open(sys.argv[3] if len(sys.argv) > 3 else 'graded.json', 'w'), default=int, indent=1)
