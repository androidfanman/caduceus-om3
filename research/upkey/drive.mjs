// Minimal om-emu E147 driver (same bring-up as caduceus-om3 tools/emulator/session_ed1.mjs, without its RAM pokes).
//   OM_EMU_MODEL=E147 node drive.mjs EMU_DIR IMAGE CARD.omsd OUT.json 'tokens'
// Tokens: s1, key names (up/down/left/right/ok/menu/info...), lever (toggle Fn lever), mode:NAME (mode dial),
//         shot:FILE.png, wait. Env WATCH=hex,hex records d0..d3/a0 at those PCs.
const [EMU, IMAGE, CARD, OUT, SCRIPT] = process.argv.slice(2);
const fs = await import('node:fs');
const { createHash } = await import('node:crypto');
const zlib = await import('node:zlib');
const { expandImage } = await import(EMU + '/src/fw/expand.mjs');
const { loadBlock } = await import(EMU + '/bin/run.mjs');
const { Player } = await import(EMU + '/src/lab/player.mjs');
const { PLAYER_PARSER } = await import(EMU + '/scenarios/session_replay.mjs');
const { cardFromImage } = await import(EMU + '/src/lab/sdcard.mjs');
const { MODE_DIAL, POSITION_SWITCH_LISTS, set_bit } = await import(EMU + '/src/lab/play.mjs');   // POSITION_SWITCH_LISTS: a local om-emu addition (v0.27 notes)
const { Debugger } = await import(EMU + '/src/debug/debugger.mjs');
// OM_WORKER_ENTRY=hex (image address): allow a Caduceus worker task (v0.25+ starts one at power-on), as Caduceus'
// tools/emulator/session_autoload.mjs does
if (process.env.OM_WORKER_ENTRY) {
  const WE = parseInt(process.env.OM_WORKER_ENTRY, 16);
  const ca = await import(EMU + '/src/lab/camapp.mjs'); ca.CA_TASK_ENTRIES?.push((WE - 0x10021020) >>> 0);
  const { PlaySession } = await import(EMU + '/src/lab/play.mjs');
  const oldCreated = PlaySession.prototype.lab_created;
  PlaySession.prototype.lab_created = function (lab) { oldCreated?.call(this, lab); lab.lt.allow.add(WE - 0x10021020); };
}
let c0 = cardFromImage(new Uint8Array(fs.readFileSync(CARD)));
const card = { open: () => c0, save: (x) => { c0 = x; } };
const rom = expandImage(new Uint8Array(fs.readFileSync(IMAGE)));
const env = { rom, resBlock: loadBlock(), createHash, card,
  deflate: (b, l) => new Uint8Array(zlib.deflateSync(b, { level: l })), inflate: (b) => new Uint8Array(zlib.inflateSync(b)) };
const pl = new Player({ ...PLAYER_PARSER, no_browser: true, idle: 'off', a15: 'on', out: '<out>', no_wait_on_error: true, device: 'tft' },
  { ...env, wallClock: () => performance.now() / 1000 });
pl.open_session();
const s = pl.session, lab = s.lab, log = [], hits = [];
let cur = 'start';
const gui = () => lab.state_names.get(lab.state()) ?? lab.state();
s.idle_slice(lab.lab_time() + 1500e6);
log.push({ step: 'start', gui: gui(), mode: MODE_DIAL.names[s.mode_index]?.name ?? s.mode_index, lever: s.bit_of('lever') });
const WATCH = (process.env.WATCH || '').split(',').filter(Boolean).map((x) => parseInt(x, 16) >>> 0);
if (WATCH.length) {
  const dbg = Debugger.attach(lab.sim, { lab });
  const rd32 = (a) => { const b = lab.sim.read(a >>> 0, 4); return (b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24) >>> 0; };
  dbg.traceExec((r) => {
    const g = dbg.regs(); if (hits.length >= 50000) return;
    if (process.env.WD0 && (g.d0 | 0) !== Number(process.env.WD0)) return;
    const h = { step: cur, pc: r.pc.toString(16), d0: g.d0 | 0, d1: g.d1 | 0, d2: g.d2 | 0, d3: g.d3 | 0, a0: (g.a0 >>> 0).toString(16) };
    if (process.env.WSTACK) { h.stk = []; for (let k = 0; k < 200; k++) { const v = rd32(((g.sp >>> 0) + 4 * k) >>> 0); if (v >= 0x60021020 && v < 0x62020fe0) h.stk.push((k * 4) + ':' + v.toString(16)); } }
    hits.push(h);
  }, { pcs: WATCH });
}
// WREAD=strid,strid: log reads of those string-table slots (who asks for the string), per token
const wreads = [];
let wdbg = null;
if (process.env.WREAD) {
  const rd32 = (a) => { const b = lab.sim.read(a >>> 0, 4); return (b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24) >>> 0; };
  const lang = lab.sim.read(0x6036f980, 1)[0], tab = rd32((0x603794a0 + 4 * lang) >>> 0);
  wdbg = Debugger.attach(lab.sim, { lab });
  wdbg.watch(process.env.WREAD.split(',').map((id, i) => ({ id: Number(id), lo: (tab + 4 * Number(id)) >>> 0, len: 4, kind: 'r', action: 'log' })));
}
// WMEM=lo:len[,lo:len] (hex): log reads of those memory ranges (pc, address) per token
let mdbg = null;
if (process.env.WMEM) {
  mdbg = Debugger.attach(lab.sim, { lab });
  mdbg.watch(process.env.WMEM.split(',').map((r, i) => { const [lo, n] = r.split(':'); return { id: i, lo: parseInt(lo, 16) >>> 0, len: parseInt(n, 16), kind: 'r', action: 'log' }; }));
}
// RANGE=lo:hi (hex) with RSTEP=token and RVAL=n: record PCs in [lo,hi) where some data register equals n, during that token
if (process.env.RANGE) {
  const [lo, hi] = process.env.RANGE.split(':').map((x) => parseInt(x, 16) >>> 0), want = Number(process.env.RVAL);
  const dbg2 = Debugger.attach(lab.sim, { lab });
  dbg2.traceExec((r) => {
    if (!cur.startsWith(process.env.RSTEP)) return;
    const g = dbg2.regs();
    if ((g.d0 | 0) === want || (g.d1 | 0) === want || (g.d2 | 0) === want || (g.d3 | 0) === want) {
      if (hits.length < 50000) hits.push({ step: cur, pc: r.pc.toString(16), d0: g.d0 | 0, d1: g.d1 | 0, d2: g.d2 | 0, d3: g.d3 | 0, a0: (g.a0 >>> 0).toString(16), a1: (g.a1 >>> 0).toString(16) });
    }
  }, { from: lo, to: hi });
}
for (const t of SCRIPT.split(/\s+/).filter(Boolean)) {
  cur = t + '#' + log.length;
  const dm = /^(main|sub)([+-]\d+)$/.exec(t);
  if (dm) { s.dial_input(dm[1], parseInt(dm[2], 10)); s.camapp.pump(); }
  else if (t.startsWith('inject:')) {   // inject:CODE=VAL (hex code): UI_IN's code entry (om-emu H-JSINJECT), then post its events
    const [c, v] = t.slice(7).split('='); const codes = s.inject(parseInt(c, 16), Number(v));
    for (const c_ of codes) { const [idx] = s.keymap(c_); if (idx !== null) s.event(idx); }
    s.camapp.pump(); s.idle_slice(lab.lab_time() + 800e6);
  }
  else if (t.startsWith('cdial:')) {   // cdial:K: the Creative Dial (E147 0x1909) to position K at run time
    const k = Number(t.slice(6)), l = (POSITION_SWITCH_LISTS ?? [])[0];
    if (!l) throw new Error('cdial: needs the om-emu POSITION_SWITCH_LISTS addition');
    s.begin(`cdial ${k}`);
    const gs = new Set();
    l.forEach(([g, b, bit, pol], i) => { set_bit(s.images[g], b, bit, i === k ? pol : 1 - pol); gs.add(g); });
    const posted = [];
    for (const g of gs) { const [codes] = s.push_group(g); for (const c of codes) { const [idx] = s.keymap(c); if (idx !== null) { s.event(idx); posted.push(idx); } } }
    console.error("cdial", k, JSON.stringify(l), [...gs], posted); s.end(`cdial ${k}`, 'switch', posted, [], {});
    s.camapp.pump(); s.idle_slice(lab.lab_time() + 800e6);
  }
  else if (t === 'lever') { s.switch_input('lever', 1 - s.bit_of('lever')); s.camapp.pump(); s.idle_slice(lab.lab_time() + 800e6); }
  else if (t.startsWith('mode:')) {
    const k = MODE_DIAL.names.findIndex((p) => p.name === t.slice(5));
    if (k < 0) throw new Error('mode names: ' + MODE_DIAL.names.map((p) => p.name).join(','));
    s.switch_input('mode_dial', k); s.camapp.pump(); s.idle_slice(lab.lab_time() + 1500e6);
  }
  else if (t.startsWith('shot:')) {
    s.scene_frame(); s.a15_apply('tft'); const comp = lab.compose('tft', true, true);
    const w = comp.header.width, h = comp.header.height, px = comp.raw, bpp = px.length / (w * h);
    const raw = Buffer.alloc((w * 3 + 1) * h);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const i = (y * w + x) * bpp, o = y * (w * 3 + 1) + 1 + x * 3; raw[o] = px[i]; raw[o + 1] = px[i + 1]; raw[o + 2] = px[i + 2]; }
    const T = []; for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; T[n] = c >>> 0; }
    const crc = (b) => { let c = 0xffffffff; for (const x of b) c = T[(c ^ x) & 255] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
    const chunk = (ty, d) => { const l = Buffer.alloc(4); l.writeUInt32BE(d.length); const td = Buffer.concat([Buffer.from(ty), d]); const c = Buffer.alloc(4); c.writeUInt32BE(crc(td)); return Buffer.concat([l, td, c]); };
    const ih = Buffer.alloc(13); ih.writeUInt32BE(w, 0); ih.writeUInt32BE(h, 4); ih[8] = 8; ih[9] = 2;
    fs.writeFileSync(t.slice(5), Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ih), chunk('IDAT', zlib.deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]));
  }
  else if (t.startsWith('set:') || t.startsWith('get:')) {   // set:SID=VAL -> setter 0x603f1b24; get:SID -> getter 0x61085dbb
    const isSet = t.startsWith('set:'); const [sidS, valS] = t.slice(4).split('=');
    const sid = Number(sidS), val = Number(valS || 0);
    const FN = isSet ? 0x603f1b24 : 0x61085dbb, REGS = isSet ? 0xf0 : 0xa0, SIZE = isSet ? 20 : 24;
    const dd = Debugger.attach(lab.sim, { lab }); const saved = dd.m.getRegs().slice();
    const sp = ((saved[8] - 0x800) & ~3) >>> 0, stub = (sp - 0x7000) >>> 0;
    const le = (v) => [v & 255, v >>> 8 & 255, v >>> 16 & 255, v >>> 24 & 255];
    const callAt = stub + 12, rel = (FN - callAt) | 0;
    dd.write(stub, Uint8Array.from([0xfc, 0xcc, ...le(sid), 0xfc, 0xcd, ...le(val), 0xdd, ...le(rel), REGS, SIZE, 0xcb, 0xcb]));
    const r = saved.slice(); r[9] = stub; r[8] = sp; r[14] = 0; dd.m.setRegs(r);
    let k = 0; while ((dd.m.getRegs()[9] >>> 0) !== ((callAt + 7) >>> 0) && k < 2000000) { dd.m.step(); k++; }
    const out = dd.m.getRegs()[0] | 0; dd.m.setRegs(saved);
    console.log(isSet ? 'SET' : 'GET', sid, isSet ? val : '', '->', out, 'steps', k);
    hits.push({ step: cur, pc: isSet ? 'set' : 'get', d0: out, d1: sid, d2: val, d3: 0, a0: '' });
  }
  else if (t.startsWith('robj:')) {               // robj:SID  the rule-target object (hash 0x62a81654, sid & 63) and its bytes
    const sid = Number(t.slice(5)); const rd32 = (a) => { const b = lab.sim.read(a >>> 0, 4); return (b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24) >>> 0; };
    let n = rd32((0x62a81654 + 4 * (sid & 63)) >>> 0), obj = 0;
    while (n) { const o = rd32(n); const b = lab.sim.read(o, 2); if ((b[0] | b[1] << 8) === sid) { obj = o; break; } n = rd32(n + 4); }
    const bytes = obj ? Buffer.from(lab.sim.read(obj, 72)).toString('hex') : '';
    console.log('ROBJ', sid, obj.toString(16), 'flag56', obj ? lab.sim.read(obj + 56, 4).join(',') : '-', bytes);
  }
  else if (t.startsWith('strset:')) {            // strset:ID=TEXT  overwrite string ID in place (UTF-16 or latin1, NUL-padded to its old length)
    const [id, raw] = t.slice(7).split('='); const txt = raw.replace(/\|/g, '\r\n').replace(/_/g, ' ');   // '_' = space, '|' = new line
    const rd32 = (a) => { const b = lab.sim.read(a >>> 0, 4); return (b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24) >>> 0; };
    const lang = lab.sim.read(0x6036f980, 1)[0], tab = rd32((0x603794a0 + 4 * lang) >>> 0), p = rd32((tab + 4 * Number(id)) >>> 0);
    const old = lab.sim.read(p, 200), wide = old[1] === 0; let n = 0;
    if (wide) { while (old[n] | old[n + 1]) n += 2; } else { while (old[n]) n++; }
    const enc = wide ? Buffer.from(txt, 'utf16le') : Buffer.from(txt, 'latin1');
    if (enc.length > n) throw new Error(`strset ${id}: new text longer than old (${enc.length} > ${n})`);
    const buf = Buffer.alloc(n); enc.copy(buf);
    Debugger.attach(lab.sim, { lab }).write(p, Uint8Array.from(buf));
    console.log('STRSET', id, p.toString(16), wide, n, JSON.stringify(txt));
  }
  else if (t.startsWith('pic:')) {               // pic:ID:FILE  picture ID's descriptor (24 B) + payload -> FILE (json)
    const [id, f] = t.slice(4).split(':'); const rd32 = (a) => { const b = lab.sim.read(a >>> 0, 4); return (b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24) >>> 0; };
    const slot = (rd32(0x60379740) + 4 * Number(id)) >>> 0, d = rd32(slot), desc = Buffer.from(lab.sim.read(d, 24));
    const size = desc.readUInt32LE(12), p = desc.readUInt32LE(16);
    fs.writeFileSync(f, JSON.stringify({ id: Number(id), desc_at: d.toString(16), desc: desc.toString('hex'), payload: Buffer.from(lab.sim.read(p, size)).toString('hex') }));
    console.log('PIC', id, d.toString(16), desc.toString('hex'));
  }
  else if (t.startsWith('strings:')) {           // dump the active language's string table (ids 0..NSTR) as JSON
    const rd32 = (a) => { const b = lab.sim.read(a >>> 0, 4); return (b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24) >>> 0; };
    const lang = lab.sim.read(0x6036f980, 1)[0], tab = rd32((0x603794a0 + 4 * lang) >>> 0), out = { lang, tab: tab.toString(16), s: {} };
    for (let id = 0; id < Number(process.env.NSTR || 16384); id++) {
      const p = rd32((tab + 4 * id) >>> 0); if (p < 0x40000000) continue;
      let b; try { b = lab.sim.read(p, 160); } catch { continue; }
      const wide = b[1] === 0; let txt = '';
      if (wide) { for (let i = 0; i + 1 < b.length; i += 2) { const c = b[i] | b[i + 1] << 8; if (!c) break; txt += String.fromCharCode(c); } }
      else { for (const c of b) { if (!c) break; txt += String.fromCharCode(c); } }
      out.s[id] = txt;
    }
    fs.writeFileSync(t.slice(8), JSON.stringify(out));
  }
  else if (t === 's1') { s.key('s1', 'down'); s.camapp.pump(); s.idle_slice(lab.lab_time() + 300e6); s.key('s1', 'up'); s.camapp.pump(); }
  else if (t !== 'wait') { s.key(t, 'down'); s.camapp.pump(); s.idle_slice(lab.lab_time() + 150e6); s.key(t, 'up'); s.camapp.pump(); }
  s.idle_slice(lab.lab_time() + 400e6);
  if (wdbg) for (const r of wdbg.watchLog()) wreads.push({ step: cur, id: r.id, pc: (r.pc >>> 0).toString(16) });
  if (mdbg) for (const r of mdbg.watchLog()) wreads.push({ step: cur, id: r.id, pc: (r.pc >>> 0).toString(16), addr: ((r.addr ?? r.address ?? 0) >>> 0).toString(16) });
  log.push({ step: t, gui: gui(), mode: MODE_DIAL.names[s.mode_index]?.name ?? s.mode_index, lever: s.bit_of('lever') });
}
fs.writeFileSync(OUT, JSON.stringify({ log, hits, wreads }));
for (const e of log) console.log(JSON.stringify(e));
