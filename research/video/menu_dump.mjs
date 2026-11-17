// Dump the camera's menu tabs, pages and rows (labels and value lists) with English text, from a main.bin.
//   OM_EMU_MODEL=E147 node menu_dump.mjs EMU_DIR MAIN.BIN [TAB_INDEX]
const [EMU, IMAGE, TABI] = process.argv.slice(2);
const fs = await import('node:fs');
const M = await import(EMU + '/src/lab/menudata.mjs');
const { loadBlock } = await import(EMU + '/bin/run.mjs');
const { expandImage } = await import(EMU + '/src/fw/expand.mjs');
const rom = expandImage(new Uint8Array(fs.readFileSync(IMAGE)));
const img = new M.Image(rom), block = loadBlock();
let S = null; try { S = new M.Strings(['en'], rom, block); } catch (e) { try { S = new M.Strings(['ENG'], rom, block); } catch (e2) { console.log('strings: ' + e2.message); } }
const txt = (d) => { try { return S ? M.render(d, S, S.t.keys().next().value) : `${d.type}:${d.id}`; } catch (e) { return `${d.type}:${d.id}${d.literal ? ' ' + d.literal : ''}`; } };
const G = M.groups(img);
for (const t of M.tabs(img)) {
  if (TABI !== undefined && t.index !== Number(TABI)) continue;
  console.log(`TAB ${t.index} id ${t.id} pages ${t.pages.join(',')}`);
  for (const pid of t.pages) {
    const e = G.get(pid); if (!e) { console.log(`  page ${pid}: no group`); continue; }
    console.log(`  page ${pid} "${txt(e.title)}" record 0x${(e.record >>> 0).toString(16)} header 0x${(e.header >>> 0).toString(16)}`);
    (e.labels || []).forEach((lab, r) => {
      const vals = e.values?.get(lab.key);
      console.log(`    row ${r} mode ${lab.key} "${txt(lab)}"` + (vals ? '  values: ' + vals.map((v) => `${v.key}=${JSON.stringify(txt(v))}`).join(' ') : ''));
    });
  }
}
