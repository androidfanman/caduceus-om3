// Editor test 1 in a full om-emu E147 play session (our script).
//   OM_EMU_MODEL=E147 node session_ed1.mjs EMU_DIR IMAGE CARD.omsd OUT.json SAVE.omsd 'tokens...'
// Tokens: s1 (half-press click), ok/down/info/... (key click), main+N / sub+N (dials), wait. After each token: STATE,
// the editor fields of P (marker, axis, dirty, status), slot 0..3 hue/light/flags, and the settings 928..975 + 2197.
const [EMU, IMAGE, CARD, OUT, SAVE, SCRIPT] = process.argv.slice(2);
const fs = await import('node:fs');
const { createHash } = await import('node:crypto');
const zlib = await import('node:zlib');
const { expandImage } = await import(EMU + '/src/fw/expand.mjs');
const { loadBlock } = await import(EMU + '/bin/run.mjs');
const { Player } = await import(EMU + '/src/lab/player.mjs');
// om-emu builds without PlaySession.lab_created: the application's task allow-list takes the worker's entry directly
if (process.env.OM_WORKER_ENTRY) { const ca = await import(EMU + '/src/lab/camapp.mjs'); ca.CA_TASK_ENTRIES.push((parseInt(process.env.OM_WORKER_ENTRY, 16) - 0x10021020) >>> 0); }
const { PLAYER_PARSER } = await import(EMU + '/scenarios/session_replay.mjs');
const { cardFromImage, cardImage } = await import(EMU + '/src/lab/sdcard.mjs');
const STATE = 0x62b4dd16, POOL = 0xa2852000, HMAX = 0xae81;
let c0 = cardFromImage(new Uint8Array(fs.readFileSync(CARD)));
const card = { open: () => c0, save: (x) => { c0 = x; } };
const rom = expandImage(new Uint8Array(fs.readFileSync(IMAGE)));
const env = { rom, resBlock: loadBlock(), createHash, card,
  deflate: (b, l) => new Uint8Array(zlib.deflateSync(b, { level: l })), inflate: (b) => new Uint8Array(zlib.inflateSync(b)) };
const pl = new Player({ ...PLAYER_PARSER, no_browser: true, idle: 'off', a15: 'on', out: '<out>', no_wait_on_error: true, device: 'tft' },
  { ...env, wallClock: () => performance.now() / 1000 });
pl.open_session();
const s = pl.session, lab = s.lab, log = []; let saved_sp_for_desc;
const rd = (a, n) => lab.sim.read(a >>> 0, n);
const u16 = (a) => { const b = rd(a, 2); return b[0] | b[1] << 8; };
const u32 = (a) => { const b = rd(a, 4); return (b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24) >>> 0; };
const s8 = (x) => (x << 24) >> 24;
// settings read: the facade GetValue is code; read through the debugger would need a call. Use the stock getter's
// table? Not known: so record the editor's view only (P) and the GUI state.
const snap = (k) => {
  const st = u16(STATE), e = { step: k, state: st, gui: lab.state_names.get(lab.state()) ?? lab.state() };
  if (st >= 1 && st - 1 < HMAX && ((st - 1) & 3) === 0) {
    const P = POOL + st - 1;
    e.marker = Buffer.from(rd(P + 680, 4)).toString('latin1'); e.gptr = u32(P + 700).toString(16); e.gdesc = [u32(0xa49ecdf8 + 12), u32(0xa49ecdf8 + 16).toString(16)]; e.vdesc = [u32(0xa4cf688c + 12), u32(0xa4cf688c + 16).toString(16)]; e.glbl = u32(P + 704); e.axis = rd(P + 684, 1)[0]; e.glowP = rd(P + 688, 1)[0]; e.dirty = rd(P + 685, 1)[0]; e.status = rd(P + 686, 1)[0]; e.lptr = u32(P + 708).toString(16); e.lidx = [...rd(P + 712, 4)].map(s8).join(',');
    e.slots = [0, 1, 2, 3].map((k2) => { const b = rd(P + 32 + 64 * k2, 64); return { hue: [...b.slice(0, 12)].map(s8).join(','), light: [...b.slice(12, 24)].map(s8).join(','), flags: b[31], wb: [b[25], s8(b[26]), s8(b[27])].join('/'), bw: [s8(b[47]), s8(b[48])].join('/'), glow: [b[28], b[29]].join('/'), tone: [b[55], s8(b[56]), b[57], s8(b[58])].join('/') }; });
  }
  log.push(e);
  console.log(JSON.stringify(e));
};
s.idle_slice(lab.lab_time() + 1500e6); snap('start');
const { Debugger } = await import(EMU + '/src/debug/debugger.mjs');
const WATCH = new Set((process.env.WATCH || '').split(',').filter(Boolean).map((x) => parseInt(x, 16) >>> 0));
let curStep = 'start'; const hits = [];
const WRANGE = process.env.WRANGE; let wdbg = null; const wlog = [];
if (WRANGE) { wdbg = Debugger.attach(lab.sim, { lab }); }
if (WATCH.size) {
  const dbg = Debugger.attach(lab.sim, { lab });
  dbg.traceExec((r) => { const g = dbg.regs(); if (process.env.WIDS && !((g.d0 >>> 0) >= 928 && (g.d0 >>> 0) <= 975) && !(((g.d0 >>> 0) >> 4) >= 928 && ((g.d0 >>> 0) >> 4) <= 975 && (g.d0 >>> 0) < 0x10000)) return; if (process.env.WFROM && !globalThis.__armed) return; if (hits.length < 200000) { const h = { step: curStep, pc: r.pc.toString(16), mdr: (g.mdr >>> 0).toString(16), sp: (g.sp >>> 0), d0: g.d0 | 0, d1: g.d1 | 0, d2: g.d2 | 0, d3: g.d3 | 0, a0: (g.a0 >>> 0).toString(16), a1: (g.a1 >>> 0).toString(16), a2: (g.a2 >>> 0).toString(16), a3: (g.a3 >>> 0).toString(16) }; if (r.pc === 0x6051861a) { const out = u32((g.a2 >>> 0) + 12); h.rec = []; for (let i = 0; i < 12; i++) { const b = rd(out + 836 + 24 * i + 18, 6); const sh = (o) => ((b[o] | b[o + 1] << 8) << 16) >> 16; h.rec.push([sh(0), sh(2), sh(4)]); } } if (process.env.WSTACK) { h.stk = []; for (let k = 0; k < 160; k++) { const v = u32(((g.sp >>> 0) + 4 * k) >>> 0); if (v >= 0x60021020 && v < 0x62020fe0) h.stk.push(k * 4 + ':' + v.toString(16)); } } { const A=(g.a0>>>0); if (A>=0x60000000) { h.f116=u32(A+116); h.f92=u16(A+92); h.f94=u16(A+94); h.f148=u32(A+148); h.vt=u32(A).toString(16); h.f136=u32(A+136).toString(16); h.f132=rd(A+132,1)[0]; h.f131=rd(A+131,1)[0]; h.f140=u32(A+140).toString(16); } } hits.push(h); } }, { pcs: [...WATCH] });
}
// WVAL=n WRANGE=from,to (hex): the first pcs in the range where d0 or d1 holds n, once armed (WFROM) -> hits {pc, d0, d1, a0}
if (process.env.WVAL) {
  const dbg2 = Debugger.attach(lab.sim, { lab }); const val = Number(process.env.WVAL) >>> 0; const [f, t] = process.env.WRANGE.split(',').map((x) => parseInt(x, 16) >>> 0); const seenPc = new Set();
  dbg2.traceExec((r) => { if (process.env.WFROM && !globalThis.__armed) return; const g = dbg2.regs(); if ((g.d0 >>> 0) !== val && (g.d1 >>> 0) !== val) return; if (seenPc.has(r.pc) || seenPc.size > 400) return; seenPc.add(r.pc); hits.push({ step: curStep, pc: r.pc.toString(16), d0: g.d0 | 0, d1: g.d1 | 0, a0: (g.a0 >>> 0).toString(16), mdr: (g.mdr >>> 0).toString(16) }); }, { from: f, to: t });
}
lab.sim.write(0xa32de590, new Uint8Array([0xff, 0x03, 0, 0])); lab.sim.write(0x60369308, new Uint8Array([0x00, 0xf0, 0, 0]));
try {
for (const t of SCRIPT.split(/\s+/).filter(Boolean)) {
  if (process.env.WFROM && t === process.env.WFROM) globalThis.__armed = true;
  const m = /^(main|sub)([+-]\d+)$/.exec(t);
  if (m) { s.dial_input(m[1], parseInt(m[2], 10)); s.camapp.pump(); }
  else if (t.startsWith('sget:')) {    // sget:SID -> the stock getter 0x603f0111 (`call sget,[],4`, as editor.s)
    const { Debugger } = await import(EMU + '/src/debug/debugger.mjs');
    const sid = Number(t.slice(5)); const FN = 0x603f0111;
    const dd = Debugger.attach(lab.sim, { lab }); const saved = dd.m.getRegs().slice();
    const sp = ((saved[8] - 0x800) & ~3) >>> 0, stub = (sp - 0x7000) >>> 0;
    const le = (v) => [v & 255, v >>> 8 & 255, v >>> 16 & 255, v >>> 24 & 255];
    const callAt = stub + 6, rel = (FN - callAt) | 0;
    dd.write(stub, Uint8Array.from([0xfc, 0xcc, ...le(sid), 0xdd, ...le(rel), 0x00, 4, 0xcb, 0xcb]));
    const r = saved.slice(); r[9] = stub; r[8] = sp; r[14] = 0; dd.m.setRegs(r);
    let k = 0; while ((dd.m.getRegs()[9] >>> 0) !== ((callAt + 7) >>> 0) && k < 2000000) { dd.m.step(); k++; }
    const out = dd.m.getRegs()[0] | 0; dd.m.setRegs(saved);
    console.log('SGET', sid, '->', out, 'steps', k);
  }
  else if (t.startsWith('setv:')) {    // setv:SID=VAL -> the facade setter 0x61085d05 (as the dial handler), GET-style stub
    const { Debugger } = await import(EMU + '/src/debug/debugger.mjs');
    const [sid, val] = t.slice(5).split('=').map(Number); const FN = 0x61085d05;
    const dd = Debugger.attach(lab.sim, { lab }); const saved = dd.m.getRegs().slice();
    const sp = ((saved[8] - 0x800) & ~3) >>> 0, stub = (sp - 0x7000) >>> 0;
    const le = (v) => [v & 255, v >>> 8 & 255, v >>> 16 & 255, v >>> 24 & 255];
    const callAt = stub + 12, rel = (FN - callAt) | 0;
    dd.write(stub, Uint8Array.from([0xfc, 0xcc, ...le(sid), 0xfc, 0xcd, ...le(val), 0xdd, ...le(rel), 0xa0, 20, 0xcb, 0xcb]));
    const r = saved.slice(); r[9] = stub; r[8] = sp; r[14] = 0; dd.m.setRegs(r);
    let k = 0; while ((dd.m.getRegs()[9] >>> 0) !== ((callAt + 7) >>> 0) && k < 3000000) { dd.m.step(); k++; }
    const out = dd.m.getRegs()[0] | 0; dd.m.setRegs(saved);
    console.log('SETV', sid, val, '->', out, 'steps', k);
  }
  else if (t.startsWith('get:')) {     // get:SID -> the stock getter 0x61085dbb (as research/upkey/drive.mjs)
    const { Debugger } = await import(EMU + '/src/debug/debugger.mjs');
    const sid = Number(t.slice(4)); const FN = 0x61085dbb;
    const dd = Debugger.attach(lab.sim, { lab }); const saved = dd.m.getRegs().slice();
    const sp = ((saved[8] - 0x800) & ~3) >>> 0, stub = (sp - 0x7000) >>> 0;
    const le = (v) => [v & 255, v >>> 8 & 255, v >>> 16 & 255, v >>> 24 & 255];
    const callAt = stub + 12, rel = (FN - callAt) | 0;
    dd.write(stub, Uint8Array.from([0xfc, 0xcc, ...le(sid), 0xfc, 0xcd, ...le(0), 0xdd, ...le(rel), 0xa0, 24, 0xcb, 0xcb]));
    const r = saved.slice(); r[9] = stub; r[8] = sp; r[14] = 0; dd.m.setRegs(r);
    let k = 0; while ((dd.m.getRegs()[9] >>> 0) !== ((callAt + 7) >>> 0) && k < 2000000) { dd.m.step(); k++; }
    const out = dd.m.getRegs()[0] | 0; dd.m.setRegs(saved);
    console.log('GET', sid, '->', out, 'steps', k);
  }
  else if (t.startsWith('run:')) {     // run:ADDR:D2:A3[:A0]  `call ADDR,[d2,d3,a2,a3],20` (hex): steps, d0
    const { Debugger } = await import(EMU + '/src/debug/debugger.mjs');
    const [fa, d2s, a3s, a0s] = t.slice(4).split(':'); const FN = parseInt(fa, 16) >>> 0;
    const dd = Debugger.attach(lab.sim, { lab }); const saved = dd.m.getRegs().slice();
    const sp = ((saved[8] - 0x800) & ~3) >>> 0, stub = (sp - 0x7000) >>> 0;
    const le = (v) => [v & 255, v >>> 8 & 255, v >>> 16 & 255, v >>> 24 & 255];
    dd.write(stub, Uint8Array.from([0xdd, ...le((FN - stub) | 0), 0xf0, 20, 0xcb, 0xcb]));
    const r = saved.slice(); r[9] = stub; r[8] = sp; r[2] = parseInt(d2s, 16); r[7] = parseInt(a3s, 16); if (a0s) r[4] = parseInt(a0s, 16); dd.m.setRegs(r);
    const lim = Number(process.env.RUNMAX || 5000000);
    const tr = []; let k = 0; while ((dd.m.getRegs()[9] >>> 0) !== ((stub + 7) >>> 0) && k < lim) { if (process.env.RUNTRACE) { const g = dd.m.getRegs(); tr.push((g[9] >>> 0).toString(16) + ' d2=' + (g[2] >>> 0).toString(16)); if (tr.length > 80) tr.shift(); } dd.m.step(); k++; }
    if (process.env.RUNTRACE) console.log(tr.join('\n'));
    const pc = dd.m.getRegs()[9] >>> 0, out = dd.m.getRegs()[0] | 0; dd.m.setRegs(saved);
    console.log('RUN', fa, '->', out, 'steps', k, k >= lim ? 'STUCK at ' + pc.toString(16) : '');
  }
  else if (t.startsWith('mem:')) {     // mem:ADDR:LEN:FILE (hex address and length): raw memory to FILE
    const [a_, n_, f_] = t.slice(4).split(':'); fs.writeFileSync(f_, Buffer.from(rd(parseInt(a_, 16), parseInt(n_, 16))));
  }
  else if (t.startsWith('dump:')) {
    const parts = []; for (const [lo, hi] of [[0x60000000, 0x63000000], [0xa2000000, 0xa6000000]]) { for (let a = lo; a < hi; a += 0x100000) parts.push(Buffer.from(rd(a, 0x100000))); }
    fs.writeFileSync(t.slice(5), Buffer.concat(parts));
  }
  else if (t === 'gc') { const { GUICALLER } = await import(EMU + '/src/lab/menu.mjs'); const gc = u32(GUICALLER); console.log('GC ' + GUICALLER.toString(16) + ' ' + gc.toString(16)); }
  else if (t === 'eng') { const r32 = (a) => u32(a); const tot = r32(0x8E000008); const ring = []; for (let i = 0; i < 16; i++) ring.push([r32(0x8E000100 + 16 * i), r32(0x8E000104 + 16 * i), r32(0x8E000108 + 16 * i), r32(0x8E00010c + 16 * i)].map((x) => x.toString(16))); console.log('ENG ' + tot + ' ' + JSON.stringify(ring)); }
  else if (t.startsWith('inject:')) {   // inject:CODE=VAL (hex): UI_IN's code entry, e.g. the Creative Dial inject:1906=1..5 (CRT, ART, 898, COLOR, MONO)
    const [c, v] = t.slice(7).split('='); for (const c_ of s.inject(parseInt(c, 16), Number(v))) { const [idx] = s.keymap(c_); if (idx !== null) s.event(idx); }
    s.camapp.pump(); s.idle_slice(lab.lab_time() + 800e6); s.camapp.pump();
  }
  else if (t === 'eye' || t === 'tft') { s.display_input('eye', t === 'eye' ? 1 : 0); s.camapp.pump(); }
  else if (t.startsWith('shot:')) {
    const dv = s.device || 'tft'; s.scene_frame(); s.a15_apply(dv); const comp = lab.compose(dv, true, true); const w = comp.header.width, h = comp.header.height, px = comp.raw; const bpp = px.length / (w * h); console.log('shot', w, h, bpp, comp.status, comp.errors.length);
    const raw = Buffer.alloc((w * 3 + 1) * h);
    for (let y = 0; y < h; y++) { raw[y * (w * 3 + 1)] = 0; for (let x = 0; x < w; x++) { const i = (y * w + x) * bpp, o = y * (w * 3 + 1) + 1 + x * 3; raw[o] = px[i]; raw[o + 1] = px[i + 1]; raw[o + 2] = px[i + 2]; } }
    const crcT = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; crcT[n] = c >>> 0; }
    const crc = (b) => { let c = 0xffffffff; for (const x of b) c = crcT[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
    const chunk = (ty, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(ty), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
    const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 2;
    fs.writeFileSync(t.slice(5), Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
  }
  else if (t.startsWith('descswap:')) {
    const [da, file, w, h] = t.slice(9).split('@'); const dd = Debugger.attach(lab.sim, { lab });
    const buf = fs.readFileSync(file), at = ((saved_sp_for_desc ??= (dd.m.getRegs()[8] - 0x20000) & ~0xff) >>> 0);
    dd.write(at, Uint8Array.from(buf)); const D = parseInt(da, 16) >>> 0;
    const W = Number(w), H = Number(h);
    dd.write(D + 2, Uint8Array.from([W & 255, W >> 8, H & 255, H >> 8]));
    dd.write(D + 12, Uint8Array.from([buf.length & 255, buf.length >> 8 & 255, buf.length >> 16 & 255, 0, at & 255, at >> 8 & 255, at >> 16 & 255, at >>> 24]));
    console.log('DESCSWAP', D.toString(16), at.toString(16), buf.length);
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
  else if (t === 'ncall') {
    const spec = JSON.parse(fs.readFileSync(process.env.NCALL, 'utf8')), out = [];
    const dd = Debugger.attach(lab.sim, { lab }); const saved = dd.m.getRegs().slice();
    const st = u16(STATE), P = (POOL + st - 1) >>> 0;
    const SP = ((saved[8] - 0x800) & ~3) >>> 0, B = ((SP - 0x6000) & ~0xff) >>> 0;
    const ev = (x) => (typeof x === 'number' ? x : Function('P', 'SP', 'B', 'return (' + x + ')')(P, SP, B)) >>> 0;
    const RN = ['d0', 'd1', 'd2', 'd3', 'a0', 'a1', 'a2', 'a3', 'sp', 'pc', 'psw', 'mdr'];
    for (const cs of spec) {
      for (const [a, hex] of cs.mem || []) { if (hex.startsWith('=')) { const v = ev(hex.slice(1)); dd.write(ev(a), Uint8Array.from([v & 255, v >> 8 & 255, v >> 16 & 255, v >>> 24])); } else dd.write(ev(a), Uint8Array.from(Buffer.from(hex, 'hex'))); }
      const r = saved.slice(); r[14] = 0;
      for (const [k, v] of Object.entries(cs.regs || {})) r[RN.indexOf(k)] = ev(v);
      if (!cs.regs || cs.regs.sp === undefined) r[8] = SP;
      r[9] = ev(cs.pc); dd.m.setRegs(r);
      const stops = (cs.stop || []).map(ev); let n = 0;
      while (!stops.includes(dd.m.getRegs()[9] >>> 0) && n < (cs.max || 200000)) { dd.m.step(); n++; }
      const g = dd.m.getRegs(), o = { name: cs.name, steps: n, regs: {}, mem: [] };
      RN.forEach((k, i) => { o.regs[k] = (g[i] >>> 0).toString(16); });
      for (const [a, len] of cs.read || []) o.mem.push(Buffer.from(rd(ev(a), len)).toString('hex'));
      for (const [a, hex] of cs.restore || []) dd.write(ev(a), Uint8Array.from(Buffer.from(hex, 'hex')));
      out.push(o);
    }
    dd.m.setRegs(saved); fs.writeFileSync(process.env.NOUT, JSON.stringify({ P: P.toString(16), SP: SP.toString(16), B: B.toString(16), out }));
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
    const SG = 0x603f0111, dd = Debugger.attach(lab.sim, { lab }), saved = dd.m.getRegs().slice(), out = [];
    const ids = (k) => [...Array(12).keys()].map((i) => 928 + 12 * k + i).concat([908 + k, 904 + k, 912 + k, 978 + 3 * k, 977 + 3 * k, 976 + 3 * k]);
    for (let k = 0; k < 4; k++) {
      const row = [];
      for (const id of ids(k)) {
        const sp = (saved[8] - 0x800) & ~3, stub = sp - 0x100, call_at = stub + 6, rel = (SG - call_at) | 0;
        dd.write(stub, new Uint8Array([0xfc, 0xcc, id & 255, id >> 8 & 255, 0, 0, 0xdd, rel & 255, rel >> 8 & 255, rel >> 16 & 255, rel >>> 24, 0x00, 0x04, 0xcb, 0xcb]));
        const r = saved.slice(); r[9] = stub >>> 0; r[8] = sp >>> 0; r[14] = 0; dd.m.setRegs(r);
        let n = 0; while ((dd.m.getRegs()[9] >>> 0) !== ((call_at + 7) >>> 0) && n < 50000) { dd.m.step(); n++; }
        row.push(n >= 50000 ? 'X' : dd.m.getRegs()[0] | 0);
      }
      out.push('S ' + row.slice(0, 12).join(',') + ' | C' + row[12] + ' Sh' + row[13] + ' Sd' + row[14] + ' | ' + row.slice(15).join('/'));
    }
    dd.m.setRegs(saved); console.log('VALS ' + JSON.stringify(out));
  }
  else if (t === 'autoload') {   // the SD loader's conditions, written by the harness (the lab runs no section loader): masks + the kind-4 medium word
    lab.sim.write(0xa32de590, new Uint8Array([0xff, 0x03, 0, 0])); lab.sim.write(0xa32de58c, new Uint8Array([0xe9, 0x02, 0, 0])); lab.sim.write(0x60369308, new Uint8Array([0x00, 0xf0, 0, 0]));
    for (let i = 0; i < 10; i++) { s.idle_slice(lab.lab_time() + 200e6); s.camapp.pump(); }
  }
  else if (t.startsWith('hold2:')) { const k = t.slice(6); s.key(k, 'down'); for (let i = 0; i < 30; i++) { s.camapp.pump(); s.idle_slice(lab.lab_time() + 100e6); } s.key(k, 'up'); s.camapp.pump(); }
  else if (t.startsWith('hold:')) { const k = t.slice(5); s.key(k, 'down'); s.camapp.pump(); s.idle_slice(lab.lab_time() + 2000e6); s.key(k, 'up'); s.camapp.pump(); }
  else if (t !== 'wait' && t !== 'autoload') { s.key(t, 'down'); s.camapp.pump(); s.idle_slice(lab.lab_time() + 150e6); s.key(t, 'up'); s.camapp.pump(); }
  curStep = t; s.idle_slice(lab.lab_time() + 1200e6); snap(t);
  if (wdbg) { if (t === 'down') wdbg.watch(WRANGE.split(',').map((r, i) => { const [lo, n] = r.split(':'); return { id: i, lo: parseInt(lo, 16), len: parseInt(n, 16), kind: process.env.WKIND || 'r', action: 'log' }; })); for (const r of wdbg.watchLog()) wlog.push({ step: t, id: r.id, pc: r.pc.toString(16), addr: (r.addr >>> 0).toString(16) }); }
}
} catch (e) { console.log('CRASH ' + String(e.message).slice(0,300)); }
const st = s.storage;
fs.writeFileSync(OUT, JSON.stringify({ wlog, hits, log, card: st ? { mounted: st.mounted, files: st.files.length } : null }, null, 1));
if (SAVE && st) fs.writeFileSync(SAVE, cardImage(st.card));
