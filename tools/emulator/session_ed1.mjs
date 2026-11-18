// Editor test 1 in a full om-emu E147 play session (our script).
//   OM_EMU_MODEL=E147 node session_ed1.mjs EMU_DIR IMAGE CARD.omsd OUT.json SAVE.omsd 'tokens...'
// NV_FILE=PATH keeps the camera's settings between runs (S-NVRAM). Tokens: s1 (half-press click), ok/down/info/... (key click), main+N / sub+N (dials), wait. After each token: STATE,
// the editor fields of P (marker, axis, dirty, status), slot 0..3 hue/light/flags, and the settings 928..975 + 2197.
const [EMU, IMAGE, CARD, OUT, SAVE, SCRIPT] = process.argv.slice(2);
const fs = await import('node:fs');
const { createHash } = await import('node:crypto');
const zlib = await import('node:zlib');
const { expandImage } = await import(EMU + '/src/fw/expand.mjs');
const { loadBlock } = await import(EMU + '/bin/run.mjs');
const { Player } = await import(EMU + '/src/lab/player.mjs');
const { PLAYER_PARSER } = await import(EMU + '/scenarios/session_replay.mjs');
const { cardFromImage, cardImage } = await import(EMU + '/src/lab/sdcard.mjs');
const STATE = 0x62b4dd16, POOL = 0xa2852000, HMAX = 0xae81;
let c0 = cardFromImage(new Uint8Array(fs.readFileSync(CARD)));
const card = { open: () => c0, save: (x) => { c0 = x; } };
const rom = expandImage(new Uint8Array(fs.readFileSync(IMAGE)));
// NV_FILE=PATH: the camera's kept settings (om-emu S-NVRAM: the stores' saves run natively and the next run loads them)
const nvram = process.env.NV_FILE ? (await import(EMU + '/host/nvram.mjs')).fileNvram(process.env.NV_FILE) : null;
const env = { rom, resBlock: loadBlock(), createHash, card, ...(nvram ? { nvram } : {}),
  deflate: (b, l) => new Uint8Array(zlib.deflateSync(b, { level: l })), inflate: (b) => new Uint8Array(zlib.inflateSync(b)) };
const pl = new Player({ ...PLAYER_PARSER, no_browser: true, idle: 'off', a15: 'on', out: '<out>', no_wait_on_error: true, device: 'tft' },
  { ...env, wallClock: () => performance.now() / 1000 });
const WATCH = new Set((process.env.WATCH || '').split(',').filter(Boolean).map((x) => parseInt(x, 16) >>> 0));
let curStep = 'start'; const hits = [];
// WBOOT=1: WATCH attaches when the lab is made, before the camera starts, so its hits include the start-up (step 'start').
const { Debugger } = await import(EMU + '/src/debug/debugger.mjs');
let bootLab = null;
// Memory readers for a lab: armWatch takes its own (with WBOOT it runs in preinit, before the session's lab exists).
const readers = (L) => {
  const rd = (a, n) => L.sim.read(a >>> 0, n);
  return { rd, u16: (a) => { const b = rd(a, 2); return b[0] | b[1] << 8; },
    u32: (a) => { const b = rd(a, 4); return (b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24) >>> 0; } };
};
if (process.env.WBOOT && process.env.WATCH) {
  const { PlaySession } = await import(EMU + '/src/lab/play.mjs');
  const Base = PlaySession.lab_class;
  PlaySession.lab_class = class extends Base { preinit(opts) { super.preinit(opts); bootLab = this; armWatch(this); } };
}
pl.open_session();
const s = pl.session, lab = s.lab, log = []; let saved_sp_for_desc;
const { rd, u16, u32 } = readers(lab);
const s8 = (x) => (x << 24) >> 24;
// settings read: the facade GetValue is code; read through the debugger would need a call. Use the stock getter's
// table? Not known: so record the editor's view only (P) and the GUI state.
const snap = (k) => {
  const st = u16(STATE), e = { step: k, state: st, gui: lab.state_names.get(lab.state()) ?? lab.state() };
  if (st >= 1 && st - 1 < HMAX && ((st - 1) & 3) === 0) {
    const P = POOL + st - 1;
    e.marker = Buffer.from(rd(P + 680, 4)).toString('latin1'); e.gptr = u32(P + 700).toString(16); e.gdesc = [u32(0xa49ecdf8 + 12), u32(0xa49ecdf8 + 16).toString(16)]; e.vdesc = [u32(0xa4cf688c + 12), u32(0xa4cf688c + 16).toString(16)]; e.glbl = u32(P + 704); e.axis = rd(P + 684, 1)[0]; e.glowP = rd(P + 688, 1)[0]; e.dirty = rd(P + 685, 1)[0]; e.status = rd(P + 686, 1)[0]; e.lptr = u32(P + 708).toString(16); e.lidx = [...rd(P + 712, 4)].map(s8).join(','); e.edk = rd(P + 687, 1)[0];
    e.slots = [0, 1, 2, 3].map((k2) => { const b = rd(P + 32 + 64 * k2, 64); return { hue: [...b.slice(0, 12)].map(s8).join(','), light: [...b.slice(12, 24)].map(s8).join(','), flags: b[31], wb: [b[25], s8(b[26]), s8(b[27])].join('/'), bw: [s8(b[47]), s8(b[48])].join('/'), glow: [b[28], b[29]].join('/'), fx: [s8(b[49]), s8(b[50]), s8(b[51]), b[52], b[53], s8(b[54])].join("/") }; });
  }
  log.push(e);
  console.log(JSON.stringify(e));
};
const PHOTO_VIDEO_SWITCH = 0x1909;   // uiin input code of the photo/video switch
const { uiin_layout, set_bit } = await import(EMU + '/src/lab/play.mjs');
const pset = (code, k) => { const { groups } = uiin_layout(rom); const pos = []; groups.forEach(({ entries }, g) => entries.forEach(([b, bit, c, typ, pol]) => { if (c === code && typ === 1) pos.push([g, b, bit, pol]); }));
  pos.forEach(([g, b, bit, pol], i) => set_bit(s.images[g], b, bit, i === k ? pol : 1 - pol));
  for (const g of new Set(pos.map((x) => x[0]))) { const [codes] = s.push_group(g); for (const c of codes || []) { const [idx] = s.keymap(c); if (idx !== null) s.event(idx); } }
  if (s.camapp) s.camapp.pump(); return pos.length; };
if (process.env.PSET0) console.error('pset0', pset(PHOTO_VIDEO_SWITCH, parseInt(process.env.PSET0, 10)));
if (process.env.MODE0) s.switch_input('mode_dial', parseInt(process.env.MODE0, 10));
s.idle_slice(lab.lab_time() + 1500e6); snap('start');
const WRANGE = process.env.WRANGE; let wdbg = null; const wlog = [];
if (WRANGE) { wdbg = Debugger.attach(lab.sim, { lab }); }
// WSTR=1: each WATCH hit also gets s, the C string at a0 (a file path at fopen).
function armWatch(L) {
  const { rd, u16, u32 } = readers(L);
  const dbg = Debugger.attach(L.sim, { lab: L });
  dbg.traceExec((r) => { const g = dbg.regs(); if (process.env.WIDS && !((g.d0 >>> 0) >= 928 && (g.d0 >>> 0) <= 975) && !(((g.d0 >>> 0) >> 4) >= 928 && ((g.d0 >>> 0) >> 4) <= 975 && (g.d0 >>> 0) < 0x10000)) return; if (process.env.WFROM && !globalThis.__armed) return; if (hits.length < 200000) { const h = { step: curStep, pc: r.pc.toString(16), mdr: (g.mdr >>> 0).toString(16), sp: (g.sp >>> 0), d0: g.d0 | 0, d1: g.d1 | 0, d2: g.d2 | 0, d3: g.d3 | 0, a0: (g.a0 >>> 0).toString(16) }; if (r.pc === 0x6051861a) { const out = u32((g.a2 >>> 0) + 12); h.rec = []; for (let i = 0; i < 12; i++) { const b = rd(out + 836 + 24 * i + 18, 6); const sh = (o) => ((b[o] | b[o + 1] << 8) << 16) >> 16; h.rec.push([sh(0), sh(2), sh(4)]); } } if (process.env.WSTR) { try { const b = L.sim.read(g.a0 >>> 0, 64), z = b.indexOf(0); h.s = Buffer.from(b.subarray(0, z < 0 ? 64 : z)).toString('latin1'); } catch (e) { h.s = null; } } if (process.env.WTID) { const cpu = u32(0x8050), t1 = u32((0x97f00004 + 4 * cpu) >>> 0), t2 = u32((t1 + 96) >>> 0), t3 = u32(t2); h.tid = u16((t3 + 16) >>> 0); h.hls = u16(0x62b4dd14); } if (process.env.WSTACK) { h.stk = []; for (let k = 0; k < 160; k++) { const v = u32(((g.sp >>> 0) + 4 * k) >>> 0); if (v >= 0x60021020 && v < 0x62020fe0) h.stk.push(k * 4 + ':' + v.toString(16)); } } hits.push(h); if (process.env.WLIVE) console.log('HIT ' + JSON.stringify(h)); } }, { pcs: [...WATCH] });   // WLIVE=1: each hit printed at once (a run that crashes writes no OUT)
}
if (WATCH.size && !bootLab) armWatch(lab);
lab.sim.write(0xa32de590, new Uint8Array([0xff, 0x03, 0, 0])); lab.sim.write(0x60369308, new Uint8Array([0x00, 0xf0, 0, 0]));
const shot = (file, tick = true) => {
    if (tick) s.scene_frame(); s.a15_apply('tft'); const comp = lab.compose('tft', true, true); const w = comp.header.width, h = comp.header.height, px = comp.raw; const bpp = px.length / (w * h); console.log('shot', w, h, bpp, comp.status, comp.errors.length);
    const raw = Buffer.alloc((w * 3 + 1) * h);
    for (let y = 0; y < h; y++) { raw[y * (w * 3 + 1)] = 0; for (let x = 0; x < w; x++) { const i = (y * w + x) * bpp, o = y * (w * 3 + 1) + 1 + x * 3; raw[o] = px[i]; raw[o + 1] = px[i + 1]; raw[o + 2] = px[i + 2]; } }
    const crcT = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crcT[n] = c >>> 0; }
    const crc = (b) => { let c = 0xffffffff; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
    const chunk = (ty, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(ty), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
    const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 2;
    fs.writeFileSync(file, Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
};
// TRACE=PC,... (hex): log each time the code reaches a PC, with its step and d0 / a0 (trace.jsonl), from the trace record
// itself (the debugger cannot read registers while the run is paused in the trace).
if (process.env.TRACE) Debugger.attach(lab.sim, { lab }).traceExec((r) => fs.appendFileSync('trace.jsonl', JSON.stringify({ step: curStep, pc: r.pc.toString(16), d0: r.d0, d1: r.d1, a0: r.a0.toString(16), insns: r.insns }) + '\n'),
  { pcs: process.env.TRACE.split(',').map((x) => parseInt(x, 16) >>> 0) });
// MMIO=1: log the CPU's MMIO writes (name, address, insns) to mmio.jsonl, to time display updates against TRACE.
if (process.env.MMIO) Debugger.attach(lab.sim, { lab }).traceMmio((r) => fs.appendFileSync(process.env.TRACE ? 'trace.jsonl' : 'mmio.jsonl', JSON.stringify({ step: curStep, name: r.name, addr: (r.addr >>> 0).toString(16), value: (r.value >>> 0).toString(16), pc: r.pc?.toString(16), insns: r.insns }) + '\n'), { dir: 'w' });
// SHOTAT=PC,... (hex): during a frames: token, also shoot the screen as it stands when the code reaches each PC
// (at_PC_N.png, no scene tick first), the state the camera's display can show mid-update.
let shotArm = false, shotN = 0; let kept = 0;   // keep: checks passed
const counts = new Map();   // count: / expect:count: (PC -> { any, d0, n })
let hits_n = 0;                                 // hit: matches
if (process.env.SHOTAT) Debugger.attach(lab.sim, { lab }).traceExec((r) => { if (shotArm) shot('at_' + r.pc.toString(16) + '_' + shotN++ + '.png', false); },
  { pcs: process.env.SHOTAT.split(',').map((x) => parseInt(x, 16) >>> 0) });
// getv(id): the camera's setting id through the getter 0x603f0111, run on a stub below the stack ('X' if it never returns).
let gvd = null;                           // one debugger for every getv call
function getv(id) {
  const SG = 0x603f0111, dd = gvd ??= Debugger.attach(lab.sim, { lab }), saved = dd.m.getRegs().slice();
  const sp = (saved[8] - 0x800) & ~3, stub = sp - 0x100, call_at = stub + 6, rel = (SG - call_at) | 0;
  dd.write(stub, new Uint8Array([0xfc, 0xcc, id & 255, id >> 8 & 255, 0, 0, 0xdd, rel & 255, rel >> 8 & 255, rel >> 16 & 255, rel >>> 24, 0x00, 0x04, 0xcb, 0xcb]));
  const r = saved.slice(); r[9] = stub >>> 0; r[8] = sp >>> 0; r[14] = 0; dd.m.setRegs(r);
  let n = 0; while ((dd.m.getRegs()[9] >>> 0) !== ((call_at + 7) >>> 0) && n < 50000) { dd.m.step(); n++; }
  const v = n >= 50000 ? 'X' : dd.m.getRegs()[0] | 0;
  dd.m.setRegs(saved);
  return v;
}
for (const t of SCRIPT.split(/\s+/).filter(Boolean)) {
  if (process.env.WFROM && t === process.env.WFROM) globalThis.__armed = true;
  curStep = t + "#" + log.length;
  const m = /^(main|sub)([+-]\d+)$/.exec(t);
  if (t.startsWith('pset:')) { console.error('pset', pset(PHOTO_VIDEO_SWITCH, parseInt(t.slice(5), 10))); continue; }
  if (t.startsWith('mode:')) { s.switch_input('mode_dial', parseInt(t.slice(5), 10)); if (s.camapp) s.camapp.pump(); continue; }
  if (m) { s.dial_input(m[1], parseInt(m[2], 10)); s.camapp.pump(); }
  else if (t.startsWith('dump:')) {
    const parts = []; for (const [lo, hi] of [[0x60000000, 0x63000000], [0xa2000000, 0xa6000000]]) { for (let a = lo; a < hi; a += 0x100000) parts.push(Buffer.from(rd(a, 0x100000))); }
    fs.writeFileSync(t.slice(5), Buffer.concat(parts));
  }
  else if (t.startsWith('frames:')) {
    // frames:KEY:N:MS:PREFIX presses KEY, then shoots N frames MS ms apart (PREFIX0.png..), the key held 150 ms:
    // shows a redraw before it settles (a plain key token idles 1350 ms first). Each frame is a fresh compose.
    const [k, n, ms, pre] = t.slice(7).split(':'); let held = true, at = lab.lab_time();
    shotArm = true; s.key(k, 'down'); s.camapp.pump();
    for (let i = 0; i < Number(n); i++) {
      if (held && i * Number(ms) >= 150) { s.key(k, 'up'); s.camapp.pump(); held = false; }
      at += Number(ms) * 1e6;
      s.idle_slice(at); shot(pre + i + '.png', !process.env.RAWFRAMES);
    }
    if (held) { s.key(k, 'up'); s.camapp.pump(); }
    shotArm = false;
  }
  else if (t.startsWith('shot:')) shot(t.slice(5));
  else if (t.startsWith('descswap:')) {
    const [da, file, w, h] = t.slice(9).split('@'); const dd = Debugger.attach(lab.sim, { lab });
    const buf = fs.readFileSync(file), at = ((saved_sp_for_desc ??= (dd.m.getRegs()[8] - 0x20000) & ~0xff) >>> 0);
    dd.write(at, Uint8Array.from(buf)); const D = parseInt(da, 16) >>> 0;
    const W = Number(w), H = Number(h);
    dd.write(D + 2, Uint8Array.from([W & 255, W >> 8, H & 255, H >> 8]));
    dd.write(D + 12, Uint8Array.from([buf.length & 255, buf.length >> 8 & 255, buf.length >> 16 & 255, 0, at & 255, at >> 8 & 255, at >> 16 & 255, at >>> 24]));
    console.log('DESCSWAP', D.toString(16), at.toString(16), buf.length);
  }
  else if (t.startsWith('poke:')) {
    // poke:ADDR=HEX writes the bytes at ADDR. poke:ADDR+OFF*=HEX writes them at the pointer stored at ADDR, plus OFF. All hex.
    const [where, hex] = t.slice(5).split('='), m = /^([0-9a-f]+)(?:\+([0-9a-f]+)\*)?$/i.exec(where);
    const at = m[2] === undefined ? parseInt(m[1], 16) : u32(parseInt(m[1], 16)) + parseInt(m[2], 16);
    Debugger.attach(lab.sim, { lab }).write(at >>> 0, Uint8Array.from(Buffer.from(hex, 'hex')));
  }
  else if (t.startsWith('expect:mem:')) {
    // expect:mem:ADDR=HEX ends the run with exit 1 unless the bytes at ADDR are HEX, as om-emu's session.mjs. All hex.
    // ADDR may follow pointers: BASE+OFF*+OFF*...+OFF reads the word at BASE + OFF for each OFF* (poke:'s form, chained).
    const [where, hex] = t.slice(11).split('='), [base, ...offs] = where.split('+');
    let at = parseInt(base, 16);
    for (const o of offs) at = o.endsWith('*') ? u32((at + parseInt(o, 16)) >>> 0) : (at + parseInt(o, 16)) >>> 0;
    const got = Buffer.from(rd(at >>> 0, hex.length / 2)).toString('hex');
    if (got !== hex.toLowerCase()) { console.error(`expect:mem ${where}: ${got}, not ${hex}`); process.exit(1); }
  }
  else if (t.startsWith('expect:pxsame:') || t.startsWith('expect:pxdiff:')) {
    // expect:pxsame:X,Y,X2,Y2 / expect:pxdiff:X,Y,X2,Y2 (border preview, 2026-11-17): the rear screen drawn as shot:
    // draws it; ends the run with exit 1 unless the pixels at (X, Y) and (X2, Y2) are the same / differ.
    const same = t.startsWith('expect:pxsame:'), [x, y, x2, y2] = t.slice(14).split(',').map(Number);
    s.scene_frame(); s.a15_apply('tft'); const comp = lab.compose('tft', true, true);
    const w = comp.header.width, px = comp.raw, bpp = px.length / (w * comp.header.height);
    const at = (X, Y) => Buffer.from(px.slice((Y * w + X) * bpp, (Y * w + X) * bpp + 3)).toString('hex');
    if ((at(x, y) === at(x2, y2)) !== same) { console.error(`${t}: ${at(x, y)} / ${at(x2, y2)}`); process.exit(1); }
  }
  else if (t.startsWith('expect:gui:')) {
    // expect:gui:NAME ends the run with exit 1 unless the GUI state's name ends with NAME.
    const got = String(lab.state_names.get(lab.state()) ?? lab.state());
    if (!got.endsWith(t.slice(11))) { console.error(`expect:gui: ${got}, not ${t.slice(11)}`); process.exit(1); }
  }
  else if (t.startsWith('keep:')) {
    // keep:ENTRY:EXIT:REG ends the run with exit 1 if REG at EXIT differs from REG at the last ENTRY (hex PCs): a
    // callee-saved register the function must give back. expect:kept checks that EXIT was reached at least once.
    const [entry, exit, reg] = t.slice(5).split(':'), E = parseInt(entry, 16) >>> 0, X = parseInt(exit, 16) >>> 0;
    const dk = Debugger.attach(lab.sim, { lab }); let held = null;
    dk.traceExec((r) => {
      const v = dk.regs()[reg] >>> 0;
      if (r.pc === E) held = v;
      else if (held !== null) { if (v !== held) { console.error(`keep ${reg}: ${v.toString(16)} at ${exit}, not ${held.toString(16)}`); process.exit(1); } kept++; held = null; }
    }, { pcs: [E, X] });
  }
  else if (t.startsWith('wcount:')) {
    // wcount:MGR:IDS:K counts the settings manager's (MGR, hex) calls for COLOR K's 18 settings, their ids from the
    // table at IDS (hex, pf_ids: u16 base, u8 step per COLOR, u8 record offset), and notes their values now (getv).
    // expect:wcount ends the run with exit 1 unless the calls equal the settings whose value changed since.
    const [mgr, tab, k] = t.slice(7).split(':'), K = Number(k);
    const ids = [...Array(18).keys()].map((i) => { const a = (parseInt(tab, 16) + 4 * i) >>> 0; return u16(a) + rd(a + 2, 1)[0] * K; });
    const set = new Set(ids), dw = Debugger.attach(lab.sim, { lab });
    globalThis.__wc = { ids, before: ids.map(getv), n: 0, dw };
    dw.traceExec(() => { if (set.has(dw.regs().d0 >>> 0)) globalThis.__wc.n++; }, { pcs: [parseInt(mgr, 16) >>> 0] });
  }
  else if (t === 'expect:wcount') {
    const wc = globalThis.__wc; wc.dw.traceExec(null);
    const after = wc.ids.map(getv), changed = after.filter((v, i) => v !== wc.before[i]).length;
    console.log(`wcount: ${wc.n} writes, ${changed} changed`);
    if (wc.n !== changed) { console.error(`expect:wcount: ${wc.n} writes, ${changed} values changed`); process.exit(1); }
  }
  else if (t.startsWith('mids:')) {
    // mids:PC (hex) notes d0 each time the code reaches PC. expect:mids:ID,... (decimal) ends the run with exit 1
    // unless the d0s noted since are those ids, in that order.
    const dm = Debugger.attach(lab.sim, { lab });
    globalThis.__mids = { ids: [], dm };
    dm.traceExec(() => { globalThis.__mids.ids.push(dm.regs().d0 >>> 0); }, { pcs: [parseInt(t.slice(5), 16) >>> 0] });
  }
  else if (t.startsWith('expect:mids:')) {
    const mi = globalThis.__mids, got = mi.ids.join(',');
    mi.dm.traceExec(null);
    console.log(`mids: ${got}`);
    if (got !== t.slice(12)) { console.error(`expect:mids: ${got}, not ${t.slice(12)}`); process.exit(1); }
  }
  else if (t.startsWith('fhash:')) {
    // fhash:NAME notes the screen's hash (as shot: composes a fresh frame). expect:fsame:A:B / expect:fdiff:A:B end the
    // run with exit 1 unless the frames noted as A and B are the same / differ.
    s.scene_frame(); s.a15_apply('tft');
    (globalThis.__fh ??= {})[t.slice(6)] = createHash('sha256').update(lab.compose('tft', true, true).raw).digest('hex');
  }
  else if (t.startsWith('expect:fsame:') || t.startsWith('expect:fdiff:')) {
    const [a, b] = t.slice(13).split(':'), fh = globalThis.__fh || {}, same = fh[a] === fh[b];
    if (!fh[a] || !fh[b] || same !== t.startsWith('expect:fsame:')) { console.error(`${t}: ${fh[a]} ${fh[b]}`); process.exit(1); }
  }
  else if (t === 'expect:kept') { if (!kept) { console.error('expect:kept: no keep: check ran'); process.exit(1); } }
  else if (t.startsWith('expect:p:')) {
    // expect:p:OFF=HEX: as expect:mem at P + OFF (OFF decimal, as pokep:), e.g. expect:p:82=03 = COLOR 1's slot +50
    const [o, hex] = t.slice(9).split('='), at = (POOL + u16(STATE) - 1 + parseInt(o, 10)) >>> 0;
    const got = Buffer.from(rd(at, hex.length / 2)).toString('hex');
    if (got !== hex.toLowerCase()) { console.error(`expect:p ${o}: ${got}, not ${hex}`); process.exit(1); }
  }
  else if (t.startsWith('hit:')) {
    // hit:PC:REG=V,... counts each time the code reaches PC (hex) with each REG = V (decimal). expect:hit fails if
    // none did.
    const [pc, cond] = t.slice(4).split(':'), P = parseInt(pc, 16) >>> 0;
    const want = cond.split(',').map((kv) => { const [reg, v] = kv.split('='); return [reg, parseInt(v, 10) >>> 0]; });
    const dh = Debugger.attach(lab.sim, { lab });
    dh.traceExec(() => { const g = dh.regs(); if (want.every(([reg, v]) => (g[reg] >>> 0) === v)) hits_n++; }, { pcs: [P] });
  }
  else if (t === 'expect:hit') { if (!hits_n) { console.error('expect:hit: no hit: match'); process.exit(1); } }
  else if (t.startsWith('expect:isdef:')) {
    // expect:isdef:FN:ID=V ends the run with exit 1 unless FN (hex, an "is at default" entered as the stock one,
    // `call FN,[d2,d3,a2],24`, d0 id -> d0 1 default) answers V (0 or 1) for ID (hex): a row's '*' is V = 0.
    const [fn, kv] = t.slice(13).split(':'), [id, want] = kv.split('='), FN = parseInt(fn, 16) >>> 0, idn = parseInt(id, 16);
    const dd = Debugger.attach(lab.sim, { lab }), saved = dd.m.getRegs().slice();
    const sp = (saved[8] - 0x800) & ~3, stub = sp - 0x100, call_at = stub + 6, rel = (FN - call_at) | 0;
    dd.write(stub, new Uint8Array([0xfc, 0xcc, idn & 255, idn >> 8 & 255, 0, 0, 0xdd, rel & 255, rel >> 8 & 255, rel >> 16 & 255, rel >>> 24, 0xe0, 0x18, 0xcb, 0xcb]));
    const r = saved.slice(); r[9] = stub >>> 0; r[8] = sp >>> 0; r[14] = 0; dd.m.setRegs(r);
    let n = 0; while ((dd.m.getRegs()[9] >>> 0) !== ((call_at + 7) >>> 0) && n < 5000000) { dd.m.step(); n++; }
    const got = n >= 5000000 ? 'X' : String(dd.m.getRegs()[0] | 0); dd.m.setRegs(saved);
    if (got !== want) { console.error(`expect:isdef ${id}: ${got}, not ${want}`); process.exit(1); }
  }
  else if (t.startsWith('count:')) {
    // count:PC:D0 (v0.30.4, #72) counts, from here, how often the code reaches PC (hex) with d0 = D0 (hex; * any d0);
    // expect:count:PC=N ends the run with exit 1 unless that count is N (decimal). count: again starts it over.
    const [pc, d0] = t.slice(6).split(':'), PC = parseInt(pc, 16) >>> 0;
    let c = counts.get(PC);
    if (!c) { c = { n: 0 }; counts.set(PC, c); Debugger.attach(lab.sim, { lab }).traceExec((r) => { if (c.any || (r.d0 >>> 0) === c.d0) c.n++; }, { pcs: [PC] }); }
    c.any = d0 === '*'; c.d0 = c.any ? 0 : parseInt(d0, 16) >>> 0; c.n = 0;
  }
  else if (t.startsWith('expect:count:')) {
    const [pc, want] = t.slice(13).split('='), c = counts.get(parseInt(pc, 16) >>> 0), got = c ? String(c.n) : 'not counted';
    if (got !== want) { console.error(`expect:count ${pc}: ${got}, not ${want}`); process.exit(1); }
  }
  else if (t === 'strpoke') {
    const dd = Debugger.attach(lab.sim, { lab });
    for (const [a, txt] of JSON.parse(process.env.STRPOKE)) dd.write(parseInt(a, 16) >>> 0, Uint8Array.from(Buffer.from(txt, 'utf16le')));
  }
  else if (t === 'strtest') {
    const ids = process.env.STRIDS.split(',').map(Number), st = u16(STATE), P = (POOL + st - 1) >>> 0;
    const tab = u32((0x603794a0 + 4 * rd(0x6036f980, 1)[0]) >>> 0); const dd = Debugger.attach(lab.sim, { lab });
    let at = P + 720; const info = [];
    for (const id of ids) {
      const old = u32(tab + 4 * id), b = rd(old, 2), wide = b[1] === 0;
      const txt = 'T' + id; const enc = wide ? Buffer.from(txt + '\0', 'utf16le') : Buffer.from(txt + '\0', 'latin1');
      dd.write(at >>> 0, Uint8Array.from(enc)); dd.write((tab + 4 * id) >>> 0, Uint8Array.from([at & 255, at >> 8 & 255, at >> 16 & 255, at >>> 24]));
      info.push([id, old.toString(16), wide]); at += enc.length + 2;
    }
    console.log('STRTEST', JSON.stringify(info));
  }
  else if (t === 'malloctest') {
    const dd = Debugger.attach(lab.sim, { lab }); const saved = dd.m.getRegs().slice(); const res = [];
    const sp = ((saved[8] - 0x800) & ~3) >>> 0, stub = (sp - 0x7000) >>> 0;
    for (const n of process.env.MSIZES.split(',').map(Number)) {
      const rel = (0x60024068 - (stub + 6)) | 0;
      dd.write(stub, Uint8Array.from([0xfc, 0xcc, n & 255, n >> 8 & 255, n >> 16 & 255, 0, 0xdd, rel & 255, rel >> 8 & 255, rel >> 16 & 255, rel >>> 24 & 255, 0x00, 0x04, 0xcb, 0xcb]));
      const r = saved.slice(); r[9] = stub; r[8] = sp; r[14] = 0; dd.m.setRegs(r);
      let k = 0; while ((dd.m.getRegs()[9] >>> 0) !== stub + 13 && k < 500000) { dd.m.step(); k++; }
      res.push([n, (dd.m.getRegs()[4] >>> 0).toString(16), k]);
    }
    dd.m.setRegs(saved); console.log('MALLOC', JSON.stringify(res));
  }
  else if (t === 'ncall') {   // a call's count: PCs, each one's hits before the stop in its result's count
    const spec = JSON.parse(fs.readFileSync(process.env.NCALL, 'utf8')), out = [];
    const dd = Debugger.attach(lab.sim, { lab }); const saved = dd.m.getRegs().slice();
    const st = u16(STATE), P = (POOL + st - 1) >>> 0;
    const SP = ((saved[8] - 0x800) & ~3) >>> 0, B = ((SP - 0x6000) & ~0xff) >>> 0;
    // better grain g2c: W(addr) in an expression reads the word there (e.g. the code block: W(P+692) + an offset)
    const ev = (x) => (typeof x === 'number' ? x : Function('P', 'SP', 'B', 'W', 'return (' + x + ')')(P, SP, B, u32)) >>> 0;
    const RN = ['d0', 'd1', 'd2', 'd3', 'a0', 'a1', 'a2', 'a3', 'sp', 'pc', 'psw', 'mdr'];
    for (const cs of spec) {
      for (const [a, hex] of cs.mem || []) { if (hex.startsWith('=')) { const v = ev(hex.slice(1)); dd.write(ev(a), Uint8Array.from([v & 255, v >> 8 & 255, v >> 16 & 255, v >>> 24])); } else dd.write(ev(a), Uint8Array.from(Buffer.from(hex, 'hex'))); }
      const r = saved.slice(); r[14] = 0;
      for (const [k, v] of Object.entries(cs.regs || {})) r[RN.indexOf(k)] = ev(v);
      if (!cs.regs || cs.regs.sp === undefined) r[8] = SP;
      r[9] = ev(cs.pc); dd.m.setRegs(r);
      const stops = (cs.stop || []).map(ev), counts = (cs.count || []).map(ev), hit = counts.map(() => 0); let n = 0;
      for (let pc; !stops.includes(pc = dd.m.getRegs()[9] >>> 0) && n < (cs.max || 200000); n++) { const i = counts.indexOf(pc); if (i >= 0) hit[i]++; dd.m.step(); }
      const g = dd.m.getRegs(), o = { name: cs.name, steps: n, regs: {}, mem: [], count: hit };
      RN.forEach((k, i) => { o.regs[k] = (g[i] >>> 0).toString(16); });
      for (const [a, len] of cs.read || []) { try { o.mem.push(Buffer.from(rd(ev(a), len)).toString('hex')); } catch (e) { o.mem.push('ERR ' + e.message.slice(0, 40)); } }
      for (const [a, hex] of cs.restore || []) dd.write(ev(a), Uint8Array.from(Buffer.from(hex, 'hex')));
      out.push(o);
    }
    dd.m.setRegs(saved); const rec = JSON.stringify({ step: log.length, P: P.toString(16), SP: SP.toString(16), B: B.toString(16), out }); if (process.env.NAPPEND) fs.appendFileSync(process.env.NOUT, rec + '\n'); else fs.writeFileSync(process.env.NOUT, rec);
  }
  else if (t === 'tonecall') {
    const TONE = parseInt(process.env.TONE, 16) >>> 0, NEXT = 0x60518fa4, res = [];
    const dd = Debugger.attach(lab.sim, { lab }); const saved = dd.m.getRegs().slice();
    const st = u16(STATE), P = POOL + st - 1;
    const w32 = (a, v) => dd.write(a >>> 0, new Uint8Array([v & 255, v >> 8 & 255, v >> 16 & 255, v >>> 24 & 255]));
    const sp = ((saved[8] - 0x800) & ~3) >>> 0, base = ((sp - 0x6000) & ~0xff) >>> 0, C = base, R = base + 0x100, O = base + 0x900, L = base + 0x2000;
    const ident = []; for (let k = 0; k < 256; k++) ident.push(Math.round(k * 1023 / 255));
    const cases = JSON.parse(process.env.TONECASES);
    for (const cs of cases) {
      const [B, W, c60, pre] = cs;
      dd.write(C, new Uint8Array(0x100)); dd.write(R, new Uint8Array(0x700)); dd.write(O, new Uint8Array(0x1200));
      w32(C + 4, R); w32(C + 12, O); w32(C + 60, c60); w32(R + 8, 0x000b0000); w32(O, 0x10000 | 0x5);
      const lb = new Uint8Array(512); ident.forEach((v, i) => { lb[2 * i] = v & 255; lb[2 * i + 1] = v >> 8; }); dd.write(L, lb);
      if (pre) { dd.write(O + 3832, lb); w32(O + 3828, O + 3832); } else w32(O + 3828, L);
      for (let k = 0; k < 4; k++) dd.write(P + 32 + 64 * k + 47, new Uint8Array([B & 255, W & 255]));
      const r = saved.slice(); r[3] = C >>> 0; r[0] = 0x11111111; r[1] = 0x22222222; r[2] = 0x33333333; r[5] = 0x55555555; r[6] = 0x66666666; r[7] = 0x77777777; r[11] = 0x12345678; r[9] = TONE; r[8] = sp >>> 0; r[14] = 0; dd.m.setRegs(r);
      let n = 0; while ((dd.m.getRegs()[9] >>> 0) !== NEXT && n < 200000) { dd.m.step(); n++; }
      const g = dd.m.getRegs(); const lut = []; const ob = rd(O + 3832, 512); for (let i = 0; i < 256; i++) lut.push(ob[2 * i] | ob[2 * i + 1] << 8);
      res.push({ B, W, c60, pre, steps: n, regs: [g[0], g[1], g[2], g[3], g[4], g[5], g[6], g[7], g[8], g[11]].map((x) => (x >>> 0).toString(16)), ptr: (u32(O + 3828) - O) | 0, o0: u32(O).toString(16), lut });
    }
    for (let k = 0; k < 4; k++) dd.write(P + 32 + 64 * k + 47, new Uint8Array([0, 0]));
    dd.m.setRegs(saved); fs.writeFileSync(process.env.TONEOUT, JSON.stringify({ sp: sp.toString(16), C: C.toString(16), res }));
  }
  else if (t === 'wbcall') {
    const WB = parseInt(process.env.WBGET, 16) >>> 0, out = {};
    const dd = Debugger.attach(lab.sim, { lab }); const saved = dd.m.getRegs().slice();
    for (const key of [34041, 38521]) {
      const sp = (saved[8] - 0x800) & ~3, stub = sp - 0x100;            // REGS order: d0..a3, sp (8), pc (9), ... fault (14)
      const k = new Uint8Array([0xfc, 0xcc, key & 255, key >> 8 & 255, 0, 0]);
      const call_at = stub + 6 + 2 + 1, rel = (WB - call_at) | 0;
      const code = new Uint8Array([...k, 0x90, 0x00, 0x04, 0xdd, rel & 255, rel >> 8 & 255, rel >> 16 & 255, rel >>> 24, 0xc0, 0x0c, 0xcb, 0xcb]);
      dd.write(stub, code);
      const r = saved.slice(); r[9] = stub >>> 0; r[8] = sp >>> 0; r[14] = 0; dd.m.setRegs(r);
      let n = 0; while ((dd.m.getRegs()[9] >>> 0) !== ((call_at + 7) >>> 0) && n < 20000) { dd.m.step(); n++; }
      out[key] = { d0: dd.m.getRegs()[0] | 0, steps: n };
    }
    dd.m.setRegs(saved); console.log('WBCALL', JSON.stringify(out));
  }
  else if (t === 'vals') {                // the camera's own settings of COLOR1..4 through the getter 0x603f0111
    const out = [];
    const ids = (k) => [...Array(12).keys()].map((i) => 928 + 12 * k + i).concat([908 + k, 904 + k, 912 + k, 978 + 3 * k, 977 + 3 * k, 976 + 3 * k, 2197 + k, 2201 + k]);
    for (let k = 0; k < 4; k++) {
      const row = ids(k).map(getv);
      out.push('S ' + row.slice(0, 12).join(',') + ' | C' + row[12] + ' Sh' + row[13] + ' Sd' + row[14] + ' | ' + row.slice(15).join('/'));
    }
    console.log('VALS ' + JSON.stringify(out));
  }
  else if (t.startsWith('expect:val:')) {  // expect:val:ID=V ends the run with exit 1 unless setting ID reads V (decimal)
    const [id, v] = t.slice(11).split('=').map(Number), got = getv(id);
    if (got !== v) { console.error(`expect:val ${id}: ${got}, not ${v}`); process.exit(1); }
  }
  else if (t === 'pmod') {                // '*' per COLOR: stock "profile changed?" 0x6129ba07 (our ed_pmod), d0 = picture mode
    const SG = 0x6129ba07, dd = Debugger.attach(lab.sim, { lab }), saved = dd.m.getRegs().slice(), out = [];
    for (const pm of [54, 55, 56, 64]) {
      const sp = (saved[8] - 0x800) & ~3, stub = sp - 0x100, call_at = stub + 6, rel = (SG - call_at) | 0;
      dd.write(stub, new Uint8Array([0xfc, 0xcc, pm, 0, 0, 0, 0xdd, rel & 255, rel >> 8 & 255, rel >> 16 & 255, rel >>> 24, 0xe0, 0x10, 0xcb, 0xcb]));
      const r = saved.slice(); r[9] = stub >>> 0; r[8] = sp >>> 0; r[14] = 0; dd.m.setRegs(r);
      let n = 0; while ((dd.m.getRegs()[9] >>> 0) !== ((call_at + 7) >>> 0) && n < 5000000) { dd.m.step(); n++; }
      out.push(n >= 5000000 ? 'X' : (dd.m.getRegs()[0] | 0) + ':' + n);
    }
    dd.m.setRegs(saved); console.log('PMOD ' + JSON.stringify(out));
  }
  else if (t.startsWith('dflt:')) {        // dflt:ADDR -> pf_dflt(id) for COLOR2 ids (d1)
    const SG = parseInt(t.slice(5), 16), dd = Debugger.attach(lab.sim, { lab }), saved = dd.m.getRegs().slice(), out = [];
    for (const id of (process.env.DIDS || '940,941,942,946,913,979,980,981,905,909').split(',').map(Number)) {
      const sp = (saved[8] - 0x800) & ~3, stub = sp - 0x100, call_at = stub + 6, rel = (SG - call_at) | 0;
      dd.write(stub, new Uint8Array([0xfc, 0xcc, id & 255, id >> 8, 0, 0, 0xdd, rel & 255, rel >> 8 & 255, rel >> 16 & 255, rel >>> 24, 0x90, 0x10, 0xcb, 0xcb]));
      const r = saved.slice(); r[9] = stub >>> 0; r[8] = sp >>> 0; r[14] = 0; dd.m.setRegs(r);
      let n = 0; while ((dd.m.getRegs()[9] >>> 0) !== ((call_at + 7) >>> 0) && n < 5000000) { dd.m.step(); n++; }
      out.push(id + '=' + (n >= 5000000 ? 'X' : dd.m.getRegs()[1] | 0));
    }
    dd.m.setRegs(saved); console.log('DFLT ' + JSON.stringify(out));
  }
  else if (t.startsWith('pokeb:')) {      // pokeb:ADDR=V writes one byte at an absolute address (hex), e.g. a flag of a simulation build
    const [a, v] = t.slice(6).split('='); lab.sim.write(parseInt(a, 16) >>> 0, Uint8Array.from([Number(v) & 255]));
  }
  else if (t.startsWith('pokep:')) {      // pokep:OFF=HEX,... writes bytes at P + OFF (decimal, or hex with 0x), e.g. pokep:685=01 sets the editor's dirty byte
    const P = POOL + u16(STATE) - 1; for (const kv of t.slice(6).split(',')) { const [o, hex] = kv.split('='); lab.sim.write((P + Number(o)) >>> 0, Uint8Array.from(Buffer.from(hex, 'hex'))); }
  }
  else if (t === 'poweroff') {           // the power lever off and the firmware's own power-off (om-emu H-POWER, S-SHUTDOWN); ends the run
    s.switch_input('power', 1 - s.bit_of('power')); const off = s.power_down(); log.push({ step: t, power_off: off ? true : null }); break;
  }
  else if (t.startsWith('tap:')) {        // tap:X:Y touches the rear screen at X,Y (pixels) for 150 ms
    const [x, y] = t.slice(4).split(':').map(Number); s.touch('down', x, y); s.idle_slice(lab.lab_time() + 150e6); s.touch('up', x, y);
  }
  else if (t.startsWith('hold:')) { const k = t.slice(5); s.key(k, 'down'); s.camapp.pump(); s.idle_slice(lab.lab_time() + 2000e6); s.key(k, 'up'); s.camapp.pump(); }
  else if (t !== 'wait') { s.key(t, 'down'); s.camapp.pump(); s.idle_slice(lab.lab_time() + 150e6); s.key(t, 'up'); s.camapp.pump(); }
  curStep = t; s.idle_slice(lab.lab_time() + 1200e6); snap(t);
  if (wdbg) { if (t === 'down') wdbg.watch(WRANGE.split(',').map((r, i) => { const [lo, n] = r.split(':'); return { id: i, lo: parseInt(lo, 16), len: parseInt(n, 16), kind: process.env.WKIND || 'r', action: 'log' }; })); for (const r of wdbg.watchLog()) wlog.push({ step: t, id: r.id, pc: r.pc.toString(16), addr: (r.addr >>> 0).toString(16) }); }
}
const st = s.storage;
const nv = lab.store_log?.nvram;
fs.writeFileSync(OUT, JSON.stringify({ wlog, hits, log, card: st ? { mounted: st.mounted, files: st.files.length } : null, nvram: nv ? { loaded: [...nv.loaded], saves: nv.saves.length } : null }, null, 1));
if (SAVE && st) fs.writeFileSync(SAVE, cardImage(st.card));
