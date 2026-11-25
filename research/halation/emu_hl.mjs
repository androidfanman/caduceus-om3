// Runs the firmware's halation pass (editor.s `hl_run`) directly in om-emu on test frames, for the bit-exact check
// against research/halation/model.py and the instruction counts (our script; emu_check.py drives it).
//   OM_EMU_MODEL=E147 node emu_hl.mjs EMU_DIR MAIN.BIN CARD.omsd SPEC.json OUT.json
// SPEC: {hl_run, flush, lock, unlock, cases: [{name, in, out, W, H, pitch, level}]} (addresses as numbers; optional fn and
// frame: another pass with the same record and level, called `call fn,[d2,d3,a2,a3],frame`: research/border). Each case:
// the frame (raw 4:2:2, H x pitch bytes) is written to DRAM at FRAME (uncached view, so hl_open uses it directly, no
// bus window), a guard pattern after it, a buffer record {bus, 0, format 0x0c02, memHw, W, H}; then a stub
// `call hl_run,[d2,d3,a2,a3],124` runs single-stepped (no interrupts) until it returns. FLUSH (0x60070e69) polls a cache
// register forever in om-emu, so it is replaced by `ret [d2,d3],16` (it is camera-proven through xb_grain); FLUSH calls,
// LOCK calls and the most instructions run between a LOCK and its UNLOCK are counted. OUT: per case the steps,
// whether the callee-saved registers and sp came back, the guard, the counts, and (PROFILE=1) steps per pc.
const [EMU, IMAGE, CARD, SPEC, OUT] = process.argv.slice(2);
const fs = await import('node:fs');
const { createHash } = await import('node:crypto');
const zlib = await import('node:zlib');
const { expandImage } = await import(EMU + '/src/fw/expand.mjs');
const { loadBlock } = await import(EMU + '/bin/run.mjs');
const { Player } = await import(EMU + '/src/lab/player.mjs');
const { PLAYER_PARSER } = await import(EMU + '/scenarios/session_replay.mjs');
const { cardFromImage } = await import(EMU + '/src/lab/sdcard.mjs');
const { Debugger } = await import(EMU + '/src/debug/debugger.mjs');
const { S: CPU } = await import(EMU + '/src/core/cpu.mjs');   // the insn limit (the lab session's ~200 M would stop a 20 MP case)
let c0 = cardFromImage(new Uint8Array(fs.readFileSync(CARD)));
const card = { open: () => c0, save: (x) => { c0 = x; } };
const rom = expandImage(new Uint8Array(fs.readFileSync(IMAGE)));
const env = { rom, resBlock: loadBlock(), createHash, card,
  deflate: (b, l) => new Uint8Array(zlib.deflateSync(b, { level: l })), inflate: (b) => new Uint8Array(zlib.inflateSync(b)) };
const pl = new Player({ ...PLAYER_PARSER, no_browser: true, idle: 'off', a15: 'on', out: '<out>', no_wait_on_error: true, device: 'tft' },
  { ...env, wallClock: () => performance.now() / 1000 });
pl.open_session();
const s = pl.session, lab = s.lab;
s.idle_slice(lab.lab_time() + 1500e6);
const spec = JSON.parse(fs.readFileSync(SPEC, 'utf8'));
const dd = Debugger.attach(lab.sim, { lab });
const rd = (a, n) => lab.sim.read(a >>> 0, n);
const u32b = (v) => Uint8Array.from([v & 255, v >> 8 & 255, v >> 16 & 255, v >>> 24 & 255]);
const saved = dd.m.getRegs().slice();
const SP = ((saved[8] - 0x800) & ~3) >>> 0;
const STUB = 0xa7f00000, REC = STUB + 0x100, FRAME = 0xa8000000, GUARD = 0x1000;   // uncached DRAM, unused in om-emu
// (checked: every byte there reads 0 before a case; 0xb2000000 and up are not DRAM in om-emu's E147)
dd.write(spec.flush, Uint8Array.from([0xdf, 0xc0, 0x10]));                       // ret [d2,d3],16
const FN = spec.fn ?? spec.hl_run, FRM = spec.frame ?? 124;
const rel = (FN - STUB) | 0;
dd.write(STUB, Uint8Array.from([0xdd, ...u32b(rel), 0xf0, FRM, 0xcb, 0xcb]));   // call hl_run,[d2,d3,a2,a3],124 (or fn, frame)
const RET = STUB + 7;
// speed-1 (2026-11-19): with spec.malloc / spec.free, every block malloc hands out during the case (its a0 at the
// return) must be given back to free exactly once (hl_run's grids come from hl_ga / hl_gf: aligned, through the cached
// alias, malloc's own pointer kept before each)
const limit0 = CPU.limit; CPU.limit = 0;   // no insn limit while the cases run (restored after)
const out = [];
for (const cs of spec.cases) {
  const frame = new Uint8Array(fs.readFileSync(cs.in));
  if (frame.length !== cs.H * cs.pitch) throw new Error(`${cs.name}: frame is ${frame.length} bytes, not H x pitch`);
  const guard = new Uint8Array(GUARD).map((_, i) => (i * 37 + 11) & 255);
  const before = rd(FRAME, frame.length + GUARD);
  if (before.some((x) => x !== 0)) throw new Error(`${cs.name}: DRAM at ${FRAME.toString(16)} is in use`);
  dd.write(FRAME, frame); dd.write(FRAME + frame.length, guard);
  const rec = new Uint8Array(24); rec.set(u32b(FRAME), 0);
  rec.set([0x02, 0x0c, (cs.pitch >> 1) & 255, cs.pitch >> 9, cs.W & 255, cs.W >> 8, cs.H & 255, cs.H >> 8], 16);
  dd.write(REC, rec);
  const pokes = (cs.pokes || []).map(([a, hex]) => [a, rd(a, hex.length / 2)]);   // crop round 7: e.g. Image Aspect
  for (const [a, hex] of cs.pokes || []) dd.write(a, Uint8Array.from(Buffer.from(hex, 'hex')));
  const r = saved.slice(); r[14] = 0;
  r[0] = cs.level; r[1] = 0x11111111; r[2] = 0x22222222; r[3] = 0x33333333; r[4] = REC; r[5] = 0x55555555;
  r[6] = 0x66666666; r[7] = 0x77777777; r[8] = SP; r[9] = STUB; r[11] = 0x12345678;
  dd.m.setRegs(r);
  const mrets = new Map(), got = [], freed = [];
  const prof = process.env.PROFILE ? new Map() : null;
  const max = cs.max || 2e9;
  let n = 0, flushes = 0, locks = 0, inLock = -1, maxLock = 0, lockSum = 0, lockAt = 0;
  for (;;) {
    const pc = dd.m.getRegs()[9] >>> 0;
    if (pc === RET || n >= max) break;
    if (spec.malloc) {
      if (pc === spec.malloc) { const ra = lab.sim.u32(((dd.m.getRegs()[8] >>> 0) + 4) >>> 0) >>> 0; mrets.set(ra, (mrets.get(ra) || 0) + 1); }
      else if (pc === spec.free) freed.push(dd.m.getRegs()[4] >>> 0);
      else if (mrets.has(pc)) { got.push(dd.m.getRegs()[4] >>> 0); const k = mrets.get(pc) - 1; if (k) mrets.set(pc, k); else mrets.delete(pc); }
    }
    if (pc === spec.flush) flushes++;
    else if (pc === spec.lock) { locks++; inLock = n; }
    else if (pc === spec.unlock && inLock >= 0) { const k = n - inLock; lockSum += k; if (k > maxLock) { maxLock = k; lockAt = locks; } inLock = -1; }
    if (prof) prof.set(pc, (prof.get(pc) || 0) + 1);
    dd.m.step(); n++;
    if ((n & 0xfffff) === 0 && (dd.m.lastStop()?.kind ?? 'break') !== 'break') break;   // a fault: reported as not done
  }
  const g = dd.m.getRegs();
  const o = { name: cs.name, steps: n, done: (g[9] >>> 0) === RET, flushes, locks, maxLock, maxLockAt: lockAt, lockSum,
    heap: spec.malloc ? { got, freed, same: got.length === freed.length && [...got].sort().join() === [...freed].sort().join() } : null,
    regsBack: g[2] === 0x22222222 && g[3] === 0x33333333 && g[6] === 0x66666666 && g[7] === 0x77777777 && (g[8] >>> 0) === SP,
    guard: Buffer.from(rd(FRAME + frame.length, GUARD)).equals(Buffer.from(guard)) };
  fs.writeFileSync(cs.out, rd(FRAME, frame.length));
  if (prof) o.profile = Object.fromEntries([...prof].map(([k, v]) => [k.toString(16), v]));
  dd.write(FRAME, before);
  for (const [a, old] of pokes) dd.write(a, old);
  out.push(o);
  console.log(JSON.stringify({ ...o, profile: undefined }));
}
dd.m.setRegs(saved); CPU.limit = limit0;
fs.writeFileSync(OUT, JSON.stringify(out));
