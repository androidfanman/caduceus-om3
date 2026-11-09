// Does the card get loaded with no key press? (emulator only; derived from the upstream session_ed1.mjs preamble)
//   OM_EMU_MODEL=E147 node session_autoload.mjs EMU_DIR IMAGE CARD.omsd [SECONDS]
// The lab does not run the core-2/3 loader tasks, so (as the SD-native replays do) the section masks and the kind-4
// media word are written by the harness once the session is open; nothing else is injected and no key is pressed.
const [EMU, IMAGE, CARD, SECS] = process.argv.slice(2);
const fs = await import('node:fs');
const { createHash } = await import('node:crypto');
const zlib = await import('node:zlib');
const { expandImage } = await import(EMU + '/src/fw/expand.mjs');
const { loadBlock } = await import(EMU + '/bin/run.mjs');
const { Player } = await import(EMU + '/src/lab/player.mjs');
const { PLAYER_PARSER } = await import(EMU + '/scenarios/session_replay.mjs');
const { cardFromImage } = await import(EMU + '/src/lab/sdcard.mjs');
const { PlaySession } = await import(EMU + '/src/lab/play.mjs');
// om-emu builds without PlaySession.lab_created: the application's task allow-list takes the worker's entry directly
if (process.env.OM_WORKER_ENTRY) { const ca = await import(EMU + '/src/lab/camapp.mjs'); ca.CA_TASK_ENTRIES.push((parseInt(process.env.OM_WORKER_ENTRY, 16) - 0x10021020) >>> 0); }
// the lab names firmware task entries by their decoded address (image address - 0x10021020): allow the worker's
const WORKER_ENTRY = process.env.OM_WORKER_ENTRY ? parseInt(process.env.OM_WORKER_ENTRY, 16) : 0;
const oldCreated = PlaySession.prototype.lab_created;
PlaySession.prototype.lab_created = function (lab) { oldCreated?.call(this, lab); if (WORKER_ENTRY) lab.lt.allow.add(WORKER_ENTRY - 0x10021020); };
const STATE = 0x62b4dd16, POOL = 0xa2852000;
let c0 = cardFromImage(new Uint8Array(fs.readFileSync(CARD)));
const card = { open: () => c0, save: (x) => { c0 = x; } };
const rom = expandImage(new Uint8Array(fs.readFileSync(IMAGE)));
const env = { rom, resBlock: loadBlock(), createHash, card,
  deflate: (b, l) => new Uint8Array(zlib.deflateSync(b, { level: l })), inflate: (b) => new Uint8Array(zlib.inflateSync(b)) };
const pl = new Player({ ...PLAYER_PARSER, no_browser: true, idle: 'off', a15: 'on', out: '<out>', no_wait_on_error: true, device: 'tft' },
  { ...env, wallClock: () => performance.now() / 1000 });
pl.open_session();
const s = pl.session, lab = s.lab;
const u32 = (a) => { const b = lab.sim.read(a >>> 0, 4); return (b[0] | b[1] << 8 | b[2] << 16 | b[3] << 24) >>> 0; };
const u16 = (a) => u32(a) & 0xffff;
lab.sim.write(0xa32de590, new Uint8Array([0xff, 0x03, 0, 0]));
lab.sim.write(0xa32de58c, new Uint8Array([0xe9, 0x02, 0, 0]));
const idle = (ms) => { s.idle_slice(lab.lab_time() + ms * 1e6); s.camapp.pump(); };
idle(1500);
lab.sim.write(0x60369308, new Uint8Array([0x00, 0xf0, 0, 0]));
const total = parseInt(SECS || '8', 10) * 1000;
for (let t = 0; t <= total; t += 500) {
  const st = u16(STATE);
  console.log(JSON.stringify({ t_ms: t, state: st, published: st > 0 && st < 0xae81, hls_tid: u16(0x62b4dd14).toString(16), gptr: u32(POOL + (st > 0 && st < 0xae81 ? st - 1 : 0) + 700).toString(16) }));
  idle(500);
}
