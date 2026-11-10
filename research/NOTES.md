# OM-3 1.1 (build 1100) firmware port — working notes

> The research lab notebook, kept as written during the work (2026-11-04 onward) and continued here from now on.
> Paths like `pp/…`, `osd/…`, `tools/…`, `port/…` and the tree names (`gz2`, `g21`, `gxt` …) were workspace folders:
> their sources now live under `research/` (see `research/README.md`). Newest sections are at the end.
> Status words matter: "camera" / "camera-tested" = seen on a real OM-3; "emulator" = om-emu only; anything else is
> analysis. Read the relevant section before changing that area of the firmware.

All addresses: OM-3 runtime (decoded main + 0x60021020). E-P7 1.1 base 0x60020020.
Stock: OLY_E_147_1100_0000_0000.BIN sha 8c133084…696d, main 5e8d376e…7d59.

## Proven on the camera
- SD update: DCOLYMP/E1479999.BIN, hold OK at power-on; steady ~2 min, then blink. Restore = official file.
- Hue/lightness: builder 0x60518381, single call 0x60518615 (call …,[d2,d3,a2,a3],96), resume 0x6051861a.
  Output records at output(=(12,a2))+836, stride 24; hue +18, sat +20, light +22. Record r = UI sector 2(r%6)+r/6.
  Hue raw = -1000*ui moves yellow->orange->red (toward the NEXT sector; opposite to Caduceus' sim convention).
- Live view uses the same builder call.
- Profile number: getter 0x60063380(d0=63153, d1=0, a0=0) ,[d2,d3],12 -> 1..4 = COLOR1..4.
- Spare state: u16 0x62b4dd16 (= HLS event-manager singleton 0x62b4dc68 +174), boot-cleared, unreferenced.
- Half-press hook: 0x60415216 call 0x60415343,[d2,d3,a2,a3],36 -> resume 0x6041521b.
- Probe 2 (camera-proven): gate (SECBITS 0xa32de590 == 0x3ff, get_tid 0x6003193e == HLS tid 0x62b4dd14,
  media word 0x603692f8/0x60369300/0x60369308 == 0xF000), malloc 0x60024068 (class 1 pool 0xa2852000..0xa285d280),
  fopen 0x608d4d22, fclose 0x608d4d2b, fseek 0x608d4fb1 (2 SET, 0 CUR, 1 END), ftell 0x608d4f47, fread 0x608d4eb7,
  free 0x6002409a. File C:\OM3MOD\BUNDLES.BIN = Caduceus format with magic 'OM3B', OM-3 sha prefix.
  STATE: 0 none, 0xFFFF attempted, h = buf-pool+1 (block 1024 B).
- Code space used: section-1 tail 0x6031e920..0x6031ebf0 (FF from 0x6031e910, end 0x6031f000);
  section-4 tail 0x60a8f100..0x60a8f7f0 (FF from 0x60a8f088, end 0x60a8f800). Section-2 tail 0x607187a8 (92 B).
  Sections load 1..10 in order (0x600455c5…), loader 0x60045ed5 sets bit (id-1) in 0xa32de590.

## Colour Profile editor (emulator traces, om-emu E147 play session)
- Reach: OK (SCP, Picture Mode "COLOR 1" selected) -> OK (picture-mode screen, COLOR1-4 tabs) -> DOWN
  ("Color Vivid" item = the wheel; emulator cannot compose its plane: PLANC_UNOBSERVED).
- COLOR1 sector setting IDs 928..939 (E-P7 927..938 + 1). Cursor setting 2197: 1..12 sector, 0xFF = ALL.
- Main dial = value step; sub dial / arrows = sector; INFO toggles ALL (cursor 0xFF). Delete: no setting change.
- Editor step handler (E-P7 Up/Down family): 0x61223ef7 receives event 0x9004 (step).
- GUI save path: facade table 0x60e57474 (OM-3 API ids = E-P7 - 1): [1] 0x60b8781f is the editor's SetValue
  (called with 928 and 2197); H1 site = 0x60b8798b `call 0x60bb528f,[d2,d3,a2,a3],68`
  (d0 id, d1 value ((24,sp)), a0 inner ((a2)), a1 mode ((28,sp)); after: cmp 1,d0 -> else a3 = 128).
  Settings manager 0x60bb528f (cmp 4508 special case, as E-P7 0x60827440).
- Facade table 0x60e57474 (56 words; refs 0x60b869d2/f2; singleton ptr (0x60369acc), getter `call 0x60b8696a,[],4` -> a0).
  OM-3 api ids = E-P7 ids, but the OM-3 table has one extra word at [1]: +4 SetValue 0x60b8781f (d0 id, d1 mode, a1 value),
  +12 GetValue 0x60b86de7 (d0 id, a1 out -> d0 0; word 0x60e57480), +28 count 0x60b86e09, +32 value-by-index 0x60b87031,
  +40 selectable 0x60b86a01, +156 GetDefault 0x60b86e44 (word 0x60e57510). (+8 0x60b87ae2 is not used by the editor.)
- Editor records (56 B, key +0): 0x615adcc4/cfc/d34/d6c = keys 0x1540..0x1543 = COLOR1..4. +4 init 0x6122393a,
  +8 child_get 0x61223acd, +12 Up 0x61223ef7, +16 Down 0x612241b6, +36 event 0x61225d52, +44 INFO 0x6122661b.
  Parent: +96 key, +122 cursor index (0 = ALL path in Up), +124 child[0] (cursor), +128.. children 1..12; parent+68.. =
  record+36..: router 0x61223ca6: 0x900c/63541 -> +72, INFO 0x9014 -> +76, 0x9015 -> +80, 0x9012 -> +84, else +68.
  Child: +80 setting id, +92 count. Child refresh `call 0x611b20ea,[d2,d3,a2,a3],68` (a0 child).
- Descriptor table 0x615ae61c.. {u16 key, u16 13, u32 list}: COLOR1 2197 + 928..939, COLOR2 2198 + 940..951,
  COLOR3 2199 + 952..963, COLOR4 2200 + 964..975. Cursor setting 255 = ALL (OM-3 has no ALL globals; INFO toggles it
  via SetValue(cursor, 0, 1|255)). Key -> cursor id table 0x615b3db4 (0x6122809f).
- Stock setting getter 0x603f0111 (`call ...,[],4`, d0 id -> value). Settings manager 0x60bb528f (2 callers).
- fwrite 0x608d4da9 (`call ...,[d2,d3,a2,a3],24`, a0 buf, d0 1, d1 n, a1 fp -> count); fopen "w" works (emulator FS).
- Strings (en): 2761 "All colors@A028@", 2762 "Single color@A028@" (E-P7 2755/2756 + 6); no immediate use found yet.
  View part table at .data 0x6037a37c = [0x611c8260, 0x611c8296, 0x611c8335, 0x611c84a3] belongs to the 615/616
  (2-value) view, NOT the COLOR wheel. Guide label and wheel polygon producer for COLOR: still open.
- Section table 0x60029b28 {dest, flash, flag}; ends via 0x60045e6c. Free FF tails: s1 0x6031e910..f000,
  s2 92 B, s3 0x6081fe00..0x60820000, s4 0x60a8f088..f800, s5 0x60adb5a0..b800, s6 0x60f49580..9800,
  s8 0x617e45e0..4800, s9 0x619a966c..9800, s10 0x61aa42f0..4800. RAM = flash + 0x10021000.

## Editor test 1 (pp/ed1.s, build_ed1.py; emulator-verified, not camera-tested)
- = probe 2 + ed_get/ed_default (facade words), ed_set (0x60b8798b), ed_init/ed_info (records +4/+44), ed_trig in the
  half-press hook (save when dirty), ed_save/ed_wfile (.NEW -> .BAK -> .BIN, read-back verified), block zeroed at load.
- Heap P: +680 'OM3E', +684 axis (0 S, 2 Hue, 1 Light), +685 dirty, +686 status (1 saved, 2 no mem, 3 .NEW fail, 4 .BIN fail).
- INFO: S single -> stock (ALL) -> Hue -> Light -> S. Half-press resets the page to S and saves.
- Emulator: edits land in the right slot (COLOR1 slot 0, COLOR2 slot 1), save files CRC-valid, reload restores them,
  no-folder save fails cleanly (status 3), stock path without the loader unchanged. Wheel shape and guide text stay stock.
- Camera 2026-11-04: editor test 1 WORKS (H/L edit + shot, no freeze); the selected slice changes its own colour (sector map confirmed). User: confusing without a page label.

## Tools (this workspace)
- port/align.py (E-P7 -> OM-3 fuzzy matcher), port/xmatch.py (disasm helpers), dis/*.npz
- pp/build_probe2.py, pp/probe2.s/.ld, pp/probe2_test.py, pp/session_probe2.mjs (FIX_GATE=1), pp/card_add_file.py
- ui/nav.mjs (walk + PNG), ui/trace_edit.mjs (PC diff + register watch)
- om-emu at /home/claude/flatpanda/om-emu (Node 26 at /home/claude/node26/package/bin); modelcheck needs --no-port.
- Camera test 2: 2761/2762 never shown on the OM-3 wheel (no label change). Wheel texts (photos): dial labels
  "Color <swatch>" / "Vivid ±0" (single), "Color All" / "Vivid All" (ALL), guide "Color All [INFO]" / "Color Select [INFO]".
  Not whole strings in the en table: composed from words (3231 "Color", 310/1663 "Vivid", 52/442 "All", 2114 "Select").
- Test 3 (out-ed3): string getter hook swaps "Vivid" (310, 1663) -> "Hue" / "Light" on axis 2 / 1. Unit-tested.
- Test 3 camera: no change ("Vivid"/"Color All" are not drawn from the string table; likely image text). Label parked.
- Wheel polygon producer FOUND: 0x60b1d08d.. (case 6): profile = setting 903 (1..4), cursor 2197..2200 -> (172,sp),
  12 x `mov id,d0; call 0x603f039d,[],4; movbu d0,(160+i,sp)` (slice 12 of COLOR1-3 via shared 0x60b1d354).
  Test 4 (out-ed4): 45 call sites -> ed_poly (Hue/Light values on those pages). Emulator: outline values follow the page,
  redraw on INFO and on every edit. ed_str/hook_str removed.
- OSD bitmaps (resource block 0101, image records at 0xa403d000 / 0xa46dd000): descriptor <6H3I> fmt 14, w, h, 8, 0, 0,
  size, payload, flags; stream header (h-1, w-1, type); type 11 = 64-bit groups of five 12-bit tokens (index<<4 | run-1),
  6877/6877 decode (osd/osd11.py). Guide pictures: 0xa49ecdf8 "Color All [INFO]" (175x50, payload 0xa49ebe40, 4022 B),
  0xa49edf88 "Color Select [INFO]". The main CPU re-reads the descriptor on every draw (emulator watch). "Vivid"/"Color"
  dial labels are not bitmaps there (font-drawn by the graphics engine?).
- Test 5 (out-ed5): GUIDES.BIN (OM3MOD, 'OM3G', CRC) loaded after BUNDLES into the heap (P+700); gd_set swaps the
  "Color All" descriptor size/payload to Hue/Light pictures on those pages, stock otherwise (ed_info/ed_init/ed_trig).
  Emulator: swaps on each page change; the draw reads our picture data.
- Test 6 (out-ed6): held-OK reset = event 0x903e -> router catch-all -> record +36 (stock 0x61225d52). ed_event (sec 10):
  stock reset with the page forced to Saturation, then the slot's hue/light zeroed, dirty, children refreshed + poke on
  H/L pages. Emulator: reset from the Light page -> sat 0 (stock), hue/light 0, saved on half-press.
- Test 7 (out-ed7): per-profile additive WB. Keys 34041 (A-B) / 38521 (G-M) read by getter 0x60063380 (type 9, s8
  sign-extended) at 12 sites (capture WB 0x60457982..cff, params 0x604631b2/c5, record 0x604876c3/d8) -> wb_get (sec 1):
  stock + slot +26/+27 when wb_flags (+25) & 0x81 == 1, picture mode 38017 (6 -> 40209) == 11, profile 63153; clamp +-7.
  WB page = axis 3 (INFO S -> H -> L -> WB -> S): Yellow (928+12k) = A-B, Green (938+12k) = G-M, other slices refused.
  ed_info/k_cur/ed_poly moved to sec-6 tail 0x60f49590. GUIDES.BIN v2: s3 (WB picture) at +24; limit 12 KB.
  Emulator (wb_get single-stepped inside the live session): 0 before, +2 after A-B +2 on COLOR1, survives reload,
  reset clears it. The 12 reads themselves do not run in the emulator (no capture pipeline): camera test needed.
- Front dial on the wheel: from slice 1, + goes to ALL, then 12, 11, ...; - goes 2, 3, ...
- Test 8 (out-ed8, sha e777043f...): '*' and the "Reset [OK hold]" guide come from stock is-default 0x6129bad6
  (GetValue vs GetDefault; the guide only shows when the profile is changed, which is why reset seemed missing after
  Hue/Light/WB-only edits). ed_isdef (sec10) wraps the 7 far calls (0x611d18a7/18e8/18f6/1939/1946/1953/1ac3) and
  ed_pmod replaces "COLOR profile changed?" 0x6129ba07 (5-byte jmp hook; near call 0x6129ba33 can't reach sec10):
  a sector id reads changed if its hue/light != 0 or the profile's WB is on and != 0. Emulator: Hue-only and WB-only
  edits show COLOR*/Vivid* and Reset; hold OK clears sat + hue/light/WB; '*' goes away. Mono loop 0x6129b9f0 untouched.
- Emulator screenshots: session_ed1.mjs token shot:FILE.png (lab.compose raw, channels look swapped).
- Test 9 (out-ed9, sha 7976c4f3...): whole-profile reset = hold OK on the "COLOR n" item of the picture-mode list ->
  event 0xf881 (63617) to every item; the wheel record gets it via the router catch-all (ed_event). ed_event now takes
  0x903e and 0xf881 (event kept at (24,sp), frame 28): stock reset on Saturation, then the slot's hue/light/WB cleared +
  dirty. Emulator: hue+light+WB -> hold OK on COLOR 1 -> all zero, every '*' and the Reset guide gone, saved (status 1)
  on half-press; wheel hold-OK unchanged; editing after the reset fine. (A single main-3 token = one step in the emu.)
- Test 10 (out-ed10, sha d68daeff...): the readout next to "Vivid" is built by 0x611d1308: cursor 2201..2204 (by
  picture mode 54/55/56/64), slice -> ids 916..927 (table 0x6154cd00), facade GetValue of that id. ed_get now maps
  916..927 on the Hue/Light/WB pages to 928 + 12k + slice (k = P+687 EDK, stored by ed_info) -> the readout follows
  the page (emu: Hue +2, Light -1, WB +1, Saturation +3). ed_isdef runs the stock compare with AXIS 0, so Saturation
  changes count on every page (Reset guide on the Hue page after a Saturation-only change). Was the same in tests 1-9:
  the readout always showed Saturation.
- Test 11 (out-ed11): WB page = 12 o'clock (sector 0) A-B +26, 6 o'clock (sector 6) G-M +27, 3 o'clock (sector 3)
  Blacks +47, 9 o'clock (sector 9) Whites +48 (Caduceus v0.19 slot ABI; loader range -5..5 there already), others
  refused. Blacks/Whites count for the '*' and are cleared by both resets.
  Tone ends = port of Caduceus E-P7 patches/tone_ends: stage list 0x605197cb.. (COLOR 0x60518573, luminance-LUT
  builder 0x60518db2 = E-P7 0x603b0a70, next 0x60518fa4 = 0x603b0c66). OM-3 offsets: R+1568 art override (E-P7
  1524), C+60 mask 0x4134063e (0x8268063e), O+3828 LUT pointer (2608), O+3832 buffer (2612), stock tone step clears
  O+0 bit 16 (E-P7 O+4 bit 8). Hook 0x605197d7 `call tone,[d2,d3,a2,a3],56` (stock f1ec cdcbf7f038), code sec 5
  tail 0x60adb5b0 (451 B). Profile via getter 63153 (as hl_pp). Frame 52 (d0 at +48: the getter call writes its
  return word at (0,sp)). In-session native test (token tonecall, 127 cases): LUT == ep7_tone.remap bit-exact,
  registers/MDR/sp preserved, idempotent, out-of-range = 0. Capture/LV pipeline itself not emulated: camera test.
- GUIDES.BIN v3 (sha 9f195ef3..., 9948 B): page 3 label "WB/BW" (mkguide2.py: same font 42, squeeze narrowed to
  0.74 so the fill fits cols 2..102); Hue/Light streams byte-identical to v2. No firmware change (test 11 stays).
  The emulator selects stream 3 on the WB page (desc 4052 B) but does not draw heap labels.
- Test 12 (out-ed12, pkg sha 22fe28ac...): per-profile Glow = port of Caduceus E-P7 patches/bloom + the bloom part of
  patches/lv_art. Stock Soft Focus passes (job flag 0x80) on COLOR jobs, weight by strength (942/881/819/748/666 =
  blur share 8..35 %). OM-3 map: converter 0x60555e47 (E-P7 0x603eab39), hook 0x60555ee5 (movbu (37690,a3),d0, 6 B)
  -> glow_flag; weight getter 0x605048c1 (E-P7 0x6039fee8, key ctx+48) -> glow_w (key 11: P+GLOW 688 -> w, else
  600); combiners 11 0x60504ecd / 12 0x60504f15; LV development handler 0x60479c01 (E-P7 0x60321d3b), its ctor call
  0x60479daf -> glow_lv (params +8 key, +12 flags, +40 type; type 0x3x not 0x1xx). Profile = getter 63153. Slot +28
  effect 1, +29 strength (Caduceus ABI). Code: sec-3 tail 0x6081fe10 (370 B); ed_poly moved to sec-8 tail 0x617e45f0.
  UI: INFO S -> H -> L -> WB/BW -> Glow (axis 4) -> S; Glow page 12 o'clock = strength 0..5 (negatives, other slices
  refused); '*', both resets, readout, save/reload verified in the emulator. Native ncall: 24 glow cases + tone 127 pass.
  GUIDES.BIN v4 (sha d53a7423..., 13192 B): s4 "Glow" at +28 after s3; loader limit raised to 24 KB (test 11 and
  earlier reject this file -> stock labels). Not emulated: the Soft Focus passes themselves (camera test).
  Glow colours: not built. Caduceus tried tints (chroma spread, test13b/13c: no visible colour; mask route: garbled
  frames; blur-buffer read: crash) and ships glow without colour (v0.14+).
- Test 13 (out-ed13, pkg sha 177b3df7...): test 12 (glow, never flashed) + page order Hue -> Saturation -> (stock
  Color All) -> Light -> WB/BW -> Glow -> Hue; ed_init opens the wheel on Hue (sets EMARK/EDK on first use).
  Readout label (stock "Vivid" picture, descriptor 0xa4cf688c 70x30, payload 0xa4cf6210/1660 B) follows the page from
  LABELS.BIN ('OM3L' | total | crc | 70 | 30 | size[5] by axis | streams from 36; Saturation/Light/Hue/WB/BW/Glow,
  osd/mklabel.py + mklabels_bin.py, 7928 B); lb_load (sec 4) / lb_check (sec 6) / gl_set (sec 8, from gd_set).
  The labels are pictures, not strings (string-table swaps change nothing); the emulator does not draw heap pictures
  and a wider (140 px) label also vanished there, so the labels keep the 70x30 box ("Saturation" font 25, squeeze 0.54).
  malloc above 16384 B never returns in the emulator: both loaders capped at 16 KB (GUIDES.BIN v4 13192 B unchanged).
  Bug found and fixed in emulation: gd_set had no scratch word, so its nested call's return word overwrote the saved a2
  of its caller (ed_trig then skipped the save); gd_set now reserves 4 B around the call.
  Crop modes (Caduceus ASPECT.md): 145 edits / 2 KB over 8 camera rounds on E-P7 (menu + SCP lists, static validator,
  capture/LV geometry, CapThr switches, size text, icons, boot clamp). Not started for OM-3.
- Camera 2026-11-04: test 13 -> "values move, no effect" on every page (Hue, Light, WB/BW, Glow): nothing rendered,
  existing recipes included; the save still ran (BUNDLES.NEW/BAK identical to BIN). Test 12 (= test 11 + Glow, old order)
  flashed as a bisect: Hue/Light/WB/BW work again, Glow shows nothing. So the test-13-only changes (ed_init opening on Hue +
  EDK/EMARK there, k_step reorder, gl_set readout-label swap of VDESC 0xa4cf688c, lb_load/LABELS.BIN 8 KB) broke rendering;
  exact cause not found. User: drop Glow entirely, keep the default page order, no readout labels.
- Test 14 (out-ed14, pkg sha bc18a10a..., ed1_test14.s/.ld, build_ed1_test14.py) = test 12 minus Glow (glow hooks back to
  stock, ext3 reused) + a Looks page. INFO: S -> (ALL) -> H -> L -> WB/BW -> Looks (axis 4, only when LOOKS.BIN loaded) -> S.
  Main dial on Looks: COLOR1-4 editor records +12/+16 (stock Up 0x61223ef7 / Down 0x612241b6, data words) -> lk_up/lk_down
  (ext3): look n +-1 with wrap 0..n; leaving 0 keeps the 64-B slot entry at P+BKUP(720)+64k, back at 0 puts it back; a look
  writes hue/light, +25 wb on, +26/+27, +47/+48, +31 |= 2; dirty; children refreshed + cursor poked (as ed_event).
  (The child value widgets cache their own value and clamp to -5..5, so the stock step path cannot reach > 5: verified.)
  P+LPTR 708 (heap copy of LOOKS.BIN), P+LIDX 712+k (look number, 0 = "My own"; cleared at load, by hand edits in s_dirty
  and by both resets). Readout on Looks = look number (ed_get 916..927 -> LIDX[EDK]); wheel cells read 0.
  Readout number tables extended at build time: 0x611d16e6 / 0x611d1757 `mov 0x6154caa0|0x6154caf8,a0; mov 11,d3` ->
  rd_sign/rd_mag (22 entries, -5..16) in the section-9 tail 0x619a9670 (FF from 0x619a966c). lk_load (ext8) after gd_load,
  lk_check (ext4). LOOKS.BIN v1 ('OM3K' | total | crc32(12..) | u16 1 | u16 n 1..16 | 16 zero | n x 32 looks | n x 16 names),
  generator looks/mklooks.py (== the Look Lab web tool, byte-checked). GUIDES.BIN = v4 layout with s4 "Looks" (13056 B,
  sha 0699cdb9...). Emulator: steps/wrap/restore/hand-edit reset/save verified, no LOOKS.BIN -> WB -> S.
- OM-3 Look Lab web tool: claude.ai artifact 45ab6f55-8f0c-4464-aae7-5d4384f6798e (looklab/), db doc lab/state, downloads
  (zip of OM3MOD/LOOKS.BIN [+ BUNDLES.BIN]); BUNDLES export byte-identical to the card file for the same values.
- Test 15 (out-ed15, pkg sha e56cea26..., ed1_test15.s/.ld, build_ed1_test15.py): per-profile looks, 5 each. Looks page
  (axis 4) = 12 o'clock spot only, value through the normal facade path (no record +12/+16 hooks, no readout tables):
  CELL -> P+LIDX+k (s8); ed_set -> s_look (sec 3): every -5..5 value is accepted and stored (the dial child caches what it
  asked for, so refusing desyncs it: seen in emulation, refused 3 then -1 gave no change); look = value 1..c_k, anything
  else = "My own" (backup P+BKUP+64k taken on leaving look 0, put back on return); then s_dirty2 (dirty + manager).
  LOOKS.BIN v2 (992 B fixed): 'OM3K' | 992 | crc32(12..) | u16 2 | u16 20 | c[4] (0..5) | 12 zero | 20 x 32 looks
  (COLOR k look j at 5k+j-1) | 20 x 16 names. looks/mklooks2.py == Look Lab (byte-checked). Emulator: COLOR1 and COLOR2
  (tab 'right') apply their own records; undefined/negative = own; restore and save verified.
- Look Lab v3 (artifact seq 5): recipe-card styling, 4 profile groups x 5 looks, db doc lab/state v3 (prof, own).
- Test 16 (out-ed16, pkg sha df0480df..., ed1_test16.s/.ld, build_ed1_test16.py): profile bank. Axis 4 page "Profiles"
  (GUIDES.BIN = osd/GUIDES_profiles.BIN, 13680 B, sha 4704f4d0...). 12 o'clock value 1..5 = COLOR k's bank profile,
  anything else = 0 = neutral. s_look (ext3): leaving profile e_old >= 1 -> pf_cap (ext3: slot hue/light/WB/BW + 18 stock
  settings via sget: sat 928+12k+s, contrast 908+k, sharp 904+k, shading 912+k, Sh 978+3k, Mid 977+3k, Hi 976+3k), then
  pf_put (ext9: slot <- record, flags |= 2, the 18 settings through `call manager,[d2,d3,a2,a3],68` with the SetValue's
  a0/a1). Hand edits and resets no longer clear LIDX. ed_trig: pf_wb (ext1) runs BEFORE the EMARK gate (menu-only edits
  count), captures selected profiles, CRC before/after -> DIRTY; after ed_save, pf_save (ext9) writes sel + CRC, then
  PROFILES.NEW and PROFILES.BIN (pf_w, ext6, read-back compare). pf_load (ext8): file checked by pf_check (ext4,
  tables pf_lo in ext3) -> bank + LIDX = sel; no file -> neutral heap bank; bad file -> no bank (page hidden, file kept).
  Stack-frame rule used: `call f,[d2,d3,a2,a3],N` saves the regs at N-16..N-1 of the callee frame; locals 4..N-17.
  PROFILES.BIN v1 1632 B: 'OM3P' | 1632 | crc32(12..) | u16 1 | u16 20 | sel[4] | 12 zero | 20 x 64 records (5k+v-1:
  hue12 light12 sat12, +36 wb on, +37 ab, +38 gm, +39 blacks, +40 whites, +41 contrast, +42 sharp, +43 shading, +44 Sh,
  +45 Mid, +46 Hi) | 20 x 16 names at 1312. profiles/mkprofiles.py == Look Lab profilesBin (byte-checked).
  Emulator (session_ed1.mjs IMAGE = out-ed16/main.bin, EMU /home/claude/flatpanda/om-emu/emu; new token `vals` reads the
  18 settings x 4 through the getter; snap shows lptr/lidx): switching saves/loads all 18 + slot (incl. +-7, +-2, -5),
  COLOR2 separate, write-back after S-page-only edits, save/reload with sel, bad CRC ignored, recipe bank loads exactly.
  Negative dial values show as -1..-5 but mean 0. Look Lab artifact seq 12: profiles UI, PROFILES.BIN export (sel 0) and
  import (replaces); older LOOKS/BUNDLES import as wheel-only profiles.
- Test 16b (out-ed16, pkg sha 4894d1f9...): Profiles dial limited to 0..5. The dial's value list is rebuilt from facade
  count (+28 word 0x60e57490, stock 0x60b86e09) and value-by-index (+32 word 0x60e57494, stock 0x60b87031) at every
  children refresh (editor open, each INFO page change; seen with WATCH). pf_cnt (ext10) / pf_vbi (ext8) return 6 /
  index 0..5 for the 12 o'clock id when AXIS 4 (shared check pf_is, ext1, macro PROFID); else stock. Emulator: stops at
  0 and 5, Saturation page still -5..5. Camera: test 16 confirmed working before this change.
- Test 17 (pp/ed1_test17.s/.ld, build_ed1_test17.py, out-ed17, pkg sha 536d47cf...): profile names on the Profiles page.
  The editor draws no table strings (string getter 0x610f56a6 never called inside the wheel editor; only 2755 on the
  Picture Mode screen / SCP), and the readout digits are glyph codes, so names are pictures: NAMES.BIN v1 ('OM3N',
  4 groups <= 16 KB, 20 entries {u16 off, u16 len}, type-11 175x50 streams, CRC) written by the Look Lab (namesBin).
  nm_load (ext4, HLS task after pf_load): one malloc per COLOR group (large heap: 16 KB blocks; the class-1 pool has
  only ~5 KB left), CRC + per-entry header checks. gd_set: axis 4 -> nm_pick (ext4) = picture of (EDK, LIDX), else the
  "Profiles" label; nm_own (ext8) lets gd_set switch away from a name buffer. s_look calls gd_set(4) after a switch;
  the guide payload is re-read on every dial step (WRANGE trace), so the name follows the dial. sd_def now builds the
  neutral defaults from sd_hdr + DEF_CRC (544-byte table removed from ext4); gd_path moved to ext9.
  Emulator: names follow 1..5 on COLOR1/COLOR2, reopening shows the saved profile's name, 0 -> Profiles label,
  damaged / missing NAMES.BIN -> Profiles label, defaults path + save valid. Not drawable in the emulator: camera test.
  Titles ("Color Profile n" -> name via string-table pointers, tt_set) written but dropped for code space (283 B).
  GUI task tid 168 vs HLS 164: file I/O stays in the HLS-task load.
- Test 18 (pp/ed1_test18.s, out-ed18, pkg sha c2fbc731...): the wheel opens on the Profiles page. ed_init (ext1, CALLS,
  d0 = editor key 0x1540+k: traced) -> ei_page (ext3, `call ei_page,[],4`): EDK = k, first-use marker, AXIS = 4 with a
  bank (else 0), gd_set; all before the stock init so the children build the 0..5 list. INFO order unchanged
  (4 -> 0 -> ALL -> 2 -> 1 -> 3 -> 4). Room: pf_lo span half computed in pf_check (lo < 0: -2 lo; byte 36: 1).
  Emulator: opens on Profiles with the name, COLOR2 from its key, Hue/Light/WB edits land in P and in the saved
  BUNDLES.BIN (the test-13 failure was edits never reaching P: saved file identical), PROFILES.BIN saved.

## v0.20 grain research (2026-11-05)
- E-P7 history (cakelesscoder docs/GRAIN_PORT.md, CHANGELOG v0.21/v0.22): combiner-32 grain on COLOR jobs = nothing
  visible on full-size stills; COLOR job + stock MONO mask/grain passes (grain_c) = colour, no grain. Never tried on a
  camera: the reverse, a real MONO job with its colour put back (MONO_COLOUR.md capture hooks, dropped by the user).
- OM-3 map (E-P7 -> OM-3): grain gains 0x604ec0ce -> 0x60667dc2 (110/300/600, 50/75/100 at +6); combiner selector
  0x603b5200 -> ~0x6052cf6x (0x0901 -> 31 at 0x6052d042, 0x0902 -> 32); handler 31 reads level request+1751
  (E-P7 1828; request offsets -77 around here), gain -> bank+148. HSL selector mode test 0x603b02bf -> 0x605185fd
  (sat request+1739, table 0x606ba608, control (0x606bb1d8), general path 0x6051863f). Chroma stage 0x603b132a ->
  0x6051958c (key (48,ctx), tone lookup 0x60519452 at 0x605195b2, COLOR result 0x60519568). Matrix stage filter id
  request+1731 at 0x605196d2 (E-P7 1802), matrix fn 0x605147a2 (E-P7 0x603acfe4). Mono curve flag request+1731 bit 7
  at 0x60518f41 ((107, req+1624)). Packer (E-P7 0x60353db9 merge) not found on OM-3 (different code shape).
- Test v0.20-t1 (pp/ed1_v20t1.s, out-ed20t1, pkg f8c1b71c...): every MONO capture renders neutral colour (g_sel: COLOR
  HSL call with a zero sat table; g_chr: no grey/toning constant; g_mat: filter id 0); grain/shading/route stock.
  Curve flag left as is (mono tone curve on colour). Camera question: colour + grain on a MONO profile with Film Grain on.
- Camera: test 1 BOOTLOOPS (recovered by flashing v0.19). Cause (static, likely): the hooked stage code lives in section 2
  and runs before later sections load; g_mat/g_zero sat in section 8 (FF at the time -> exception). Section 1-5 code is
  proven safe on that pipeline (hl_pp sec 1, tone sec 5). Test 1b (out-ed20t1b, pkg 314633d6...): g_sel sec 1, g_chr sec 3,
  g_zero+g_mat sec 4 (room from moving BUNDLES.NEW/.BAK path strings to secs 6/9; save path emulator == v0.19).
- Test 1b camera: boots; MONO JPEG still grey, Cb=Cr=128 exactly (stddev 0), grain strong. Grey comes from kind-3 dispatcher 0x60513115: format 0x0c04 -> grey list 0x60519ea5 (0x60519572 constant chroma). Test 1c (out-ed20t1c, pkg dd558c4b...): call there -> colour list 0x60519e87.
- Test 1c camera: still Cb=Cr=128 exactly. Conclusion: MONO route is luma-only end to end; colour + ISP grain not
  reachable without changing the route's image formats (E-P7 grain_c did the reverse: colour, no grain). Grain parked.

## v0.20 Extras research
- Art Effect -> job flag converter 0x60555e47 (E-P7 0x603eab39): capture+38225 = Art Effect id, jump table 0x606e5f88:
  1 Soft Focus 0x80, 2 Pin Hole 0x400, 3 Frame 0x8000, 4 White Edge 0x2000, 5 Star Light 0x40, 6/7 Diorama 0x100/0x200,
  8/9 Shade 0x800/0x1000; tail: capture+37690|37691 != 0 -> 0x800000 (mono grain/filter route) else cleared.
  Params: key at params+8 (u32 LE 0x000b0000 = COLOR), flags params+12 (= a2). Callers 0x6054f6fa, 0x60553ac2, both
  after the key writer 0x60555d10.
- Work-list builder default path 0x604b917f tests the same flags for every key (0x80 at 0x604b9249 ...), as E-P7.
- Soft Focus weight getter 0x605048c1: key 0x01010065 uses its level, any other key w = 600.
- Test 2 (out-ed20t2, pkg d4db1f42...) = v0.19 + fx_hook at 0x60555e50: COLOR capture without an Art Effect gets
  COLOR1 Soft Focus, COLOR2 Frame, COLOR3 Star Light, COLOR4 none. Question: do Art Effect passes render on COLOR stills.

## v0.20 test 3 (Extras page + white frames) — built 2026-11-05, pkg b5268286…
- Extras page = axis 5 (INFO: … WB/BW → Extras → Looks). 12 o'clock slot+49 (Glow < 0; Clarity > 0 not rendered yet),
  6 o'clock slot+50 (Frame > 0). CELL folds Extras into the WB branch (+23, odd-bit sectors refused). LOOKS.BIN +47/+48.
- fx_hook at 0x60555e50 (section-2 tail + ext6 fx_fl): COLOR key 0x000b0000, no stock Art Effect → flags |= 0x80 / 0x8000.
  The converter's (0,sp) is its outgoing slot (calls 0x61a30a5a, never reads it), so no add -4,sp around the getter.
  Emulator ncall of 0x60555e47: glow+frame 0x8080, frame 0x8000, glow 0x80, MONO and stock Art Effects untouched.
- Emulator: the sub dial does not move the wheel cursor; main after sub = "All" (+1 on every cell), same on the stock WB page.
- Component 2 frame pairs: directory {addr,size} at +0x400, entries 1..26 (odd = layer, even = window mask), JPEG at +0x20,
  zero padding. Masks are exact binary rectangles (not 8-aligned). New layers (om3/frame/frames.py): white outside the
  window, black for 8x8 blocks wholly inside it → correct for lerp and additive blends. Header = libjpeg q=1 4:2:2
  layout, byte-identical to the stock headers; pure-Python DC-only encoder (matches libjpeg on all-white images).
  comp2 sha 3d9fd442… → 3185b34e…; checksum = same wordsum rule as main.

## v0.20 test 4 (Film page + merged Extras, Caduceus layout) — pkg cdf9b961…
- INFO: Film(4) → S → (All) → H(2) → L(1) → Extras(3) → Film. Axis 5 gone; WB/BW page merged into Extras.
- Extras slice i (0 = 12 o'clock, clockwise) via xt_tab {slot byte, min, max}: 1 NR +51 (0..3), 2 Glow/Clarity +49,
  3 A-B +26, 4 G-M +27 (both set wb_flags bit0), 5 Art +50 (Caduceus ids 0 off,1 Star,2 Pin Hole,3 -,4 White Edge,5 Frame),
  6 Blacks +47, 7 Whites +48, 8 none. Record +47 glow, +48 art, +49 NR. fx_ft maps art id → 0x40/0x400/0x2000/0x8000.
- Emulator: ranges hold (NR stops at 0), All mode steps every cell (stock behaviour), save/reload ok, ncall flags ok.
- Live view lead: 0x6046b86c (record → development request; same 0x9d05 error code as E-P7 0x60312f42) maps the
  Art Effect to job flags only for picture mode ≥ 100 (0x6046b8bb). COLOR hook there = Caduceus H2 analogue. Not in emulator.
- Code space is the blocker for NR/clarity/LV (≈90 B free in total). Plan: relocatable code block loaded from the card.

## v0.20 test 5 (code block from the card) — pkg db3fdf0b…, GUIDES.BIN 4aa16a60… (tag 0x58c632cc)
- GUIDES.BIN = pictures + code block at the end: code (linked 0x10000000) | relocs (bit31 abs +Δ, else PC-rel −Δ) |
  {tag, end−code, len, n}. x_load (ext6, from gd_load) checks the tag ('X' + 3 B of the image SHA with placeholder),
  `calls` entry 0 (PIC relocator, byte-wise fields), publishes P+XPTR (692; cleared at gd_load start).
- Stubs (section-2 tail unless noted): xp (STATE→P→XPTR, uses d0, retf), s_lv, s_nr; s_wt (ext5), s_cap (ext8).
  Hooks: 0x6046b8bb (29 B gate rewrite, COLOR → s_lv), 0x605048c1 (jmp s_wt), NR reads 0x603c8038 / 0x603e7891 (call s_nr),
  0x60555e50 (jmp s_cap). k_cur moved to ext1 for room.
- Block: cap flags (glow or clarity → 0x80, art table), lv flags (glow only), weight (glow 942..666, clarity 1100..1420 on
  combiner 11 / 1024 on 12; stock 600), NR (1 Std 0, 2 Low −1, 3 Off −2 after the real read).
- Emulator: relocated block == direct link at its address (except the relocator's own Δ constant); every entry's ncall
  matches the model; with an old GUIDES.BIN every hook is stock.

## v0.20 test 6 — pkg 18a65aa3…, GUIDES.BIN cd3c9f5b…
- Camera report (t5): INFO off 12 o'clock toggles All colors on every page (front dial). stock_info is reachable only via
  the record words, so k_go fell to stock; the only cursor-dependent check is k_cur (GetValue 2197+k). t6: a failed
  cursor read counts as "not ALL" (page step); the poke is skipped without a value. Unverified cause (emulator always reads).
- Forcing the cursor to 1 does not move the wheel: the dial widget keeps its own index (0x611b4570 SetValue from the
  widget's list[index]); a SetValue + view refresh leaves the index, so the next edit hits the old slice. Not used.
- Held-OK reset now clears slot +0..51 (adds Extras +49..51; +31 flags cleared, set again by the next H/L edit).
- t6b (pkg 8dee00e8…, GUIDES c25deb84…, tag 0x584f9219): the stock INFO handler's ALL id is 2201 + k (table 0x615ac0b4),
  not the wheel cursor 2197 + k. Entered from 12 o'clock, ALL shows as 2197 = 255 (2201 stays 1); from another slice as
  2201 = 255 (2197 keeps the slice). k_ad (stub → block +40) reads 2201, then 2197. Emulator: S → ALL → H from 12 and 3.
- ed_isdef now counts slot +47..51 (Blacks, Whites, Glow/Clarity, Art, NR) as changed: '*' and, likely, the stock
  Reset guide (the reset on an Extras-only change never reached ed_event before).

## v0.20 test 7 (Extras dial labels) — pkg 6eb202d3…, GUIDES ea1b9009…, LABELS.BIN v2 06bc64d5… (5686 B)
- The dial label ("Vivid", VDESC 0xa4cf688c 70x30, stock payload 0xa4cf6210 / 1660 B) names the Extras slice + value.
  ed_get's readout path (ids 916..927) calls vl_s (ext7) → block +48 xb_vl: Extras page slices 1..7 → label index from
  xb_vt {slot byte, mode (value / sign / fixed), first, max}; elsewhere stock. Only a 70x30 descriptor with the stock
  payload or ours is touched.
- Heap: the uncached pool is small (~45 KB, P/GUIDES/NAMES/LOOKS in it): 21 pre-encoded labels (36 KB) exhausted it
  in the emulator (malloc 0 at #20). LABELS.BIN v2 = 1-bit letter bitmaps (21 x 270 B); xb_rend draws fill 10, 1 px
  edge 7, grey 8 to 2 px and encodes type 11 into one 2 KB buffer, only when the label changes. Heap use ~7.7 KB.
  Emulator: every label byte-identical to mklabels.render + encode11.
- Bug found in emulation: a call from xb_vl wrote its return word over the saved a1 at (0,sp), ed_get then stored the
  readout into the block's code → crash on the next label. Fixed with a separate call slot.
- PROFILES.BIN fallback dropped (room): v0.17/v0.18 users rename PROFILES.BIN to LOOKS.BIN (same format).
- LABELS.BIN titles (user): NR, Glo/Cla, B/A/A-B as 'B' 'A' 'A/B', 'M' 'G' 'G/M' (sha 4fdee1ff…). Card file only.

## v0.21 test 1 (VigFix) — pkg 1b39002d…, GUIDES e3ee2cfa…, LABELS 96b6623f… (23 labels)
- Shading Comp. = sid 61, key 0x8c21: the setting-ID table 0x6062555c is identical to the E-P7's 0x604d6c14 for its first
  252 entries ([61] = 0x8c21, [143] = 0x9719). Seven reads `mov 35873,d0 ... call getter,[d2,d3],12`: 0x603d4f84,
  0x603dc2ed (settings snapshot 0x62a74d07), 0x603eab70 / 0x603eac45 / 0x6070c6ce / 0x6070c855 (request flag 0x2000 when
  1, the E-P7 R2 shape), 0x60457e83 (capture +5456, R1). All seven -> s_nr (rel32), which passes the key to block +32.
- xb_nr dispatches on the key: 0x9719 NR as v0.20, else slot +52 == 1 -> real read, then 0. Emulator ncall: key 0xf6b1
  (stock 1) -> 1 / 0 for VigFix 0 / 1; NR 2 -> -1, 3 -> -2; d2/d3/a2/a3/sp intact.
- Editor: xt_tab sector 8 {52, 0, 1}; ed_isdef reads +48..51 as one word (slot entries 4-aligned) + 52; reset 53 bytes;
  record +50 <-> slot +52 (pf_cap, pf_bt); pf_lo[50] = -1; BUNDLES range +52 0..1. Labels 21 "Vig Cam", 22 "Vig Off"
  (streams 1508 / 1548 B, equal to Python). Emulator: sector 8 0..1, `*`, hold-OK reset, half-press save, LOOKS.BIN
  look pick loads +50 and an edit saves to the record. v0.20 rejects a LOOKS.BIN / BUNDLES.BIN with a 1 there.
- Also in RAWNR params: ausEffectiveShadingCoefficient[], ucShadingCancel (string 0x61a80656..) — if the getter override
  shows no change on photos, that is where lens shading reaches the pixels.

## Grain on COLOR: own grain (research 2026-11-05)
- IMGPRO_MDL modules (strings 0x61a80180..): ENCODE_JPEG, COPY_YCC, PAINT_YCC (Y/Cb/Cr fill), COMPOSE_RAW, RAWNR, IFINISH
  (development: stBufferICam -> stBufferYCC), ART_EFFECT, CMP_BLEND; CPUs IMGPRO_MDL_CPU0..2. Image descriptor
  (IMGPRO_CTRL_SRC/DST dumper ~0x61a33504): Address (64-bit: lo, hi), AddressC (64-bit), usDataFormat, usMemHw,
  usUseHw/usUseVw (src) or usHw/usVw (dst), offsets, centre; format union YCC / JPEG / BAYER / THUMB.
- Debug buffer dump ("mvr dump", kinds 0..16, 13 = ENCODE JPEG): register 0x6045a91a(d0 kind, a0 CPU address, d1 size)
  -> tables 0xa32de700 / 0xa32de744; check 0x6045b267 (mask 0xa32de68c); the dumper writes from the CPU address. The
  registered addresses are plain 32-bit uncached (e.g. 0xafbd8980, sizes up to 24 MB): CPU can see image memory there.
- CPU-side JPEG encode requests: only 0x6047a3f9 (callers 0x60467334: 160x120 thumbnail / 640x480 screennail, src fmt
  0x0c02, dst 0x1c02 JPEG, memHw 192 / 704; 0x60469fd7 <- 0x60474a0a in fn 0x6047484a: memHw 1344, a ~1280-wide view
  JPEG; then kind 13 registered via 0x60469ffb). The full-size main JPEG is not encoded through these: probably inside
  the still job's module chain. Next: find where the still job runs ENCODE_JPEG for the main image (or where the main
  YCC buffer is complete), then a probe that writes a bit pattern into the top rows of the Y data (proves CPU access,
  carries the descriptor out in the photo itself, no file I/O needed).

## Grain probe g1 (om3/gprepo; out-g1b: pkg 9a1891d3…, GUIDES 47a247d5…; LABELS = v0.21t1)
- Soft Focus on OM-3 (builder 0x604b917f, flag 0x80 at 0x604b9249): classes 0-3 -> pass pusher 0x604be238 + entry
  0x604be2aa / cb 0x604be445 (0x604b8c80 at 0x604b928c); classes 4-8 -> entry 0x604be4b6 / cb 0x604be650. Class byte
  job+5385. Blend setup 0x604be2aa (`calls` callee, a0 = job): BUFIDX 0x604afdf9(job, id) -> index (< 48), records =
  *(job+10276) + 104 i (+0 addr lo, +4 hi, +16 fmt, +18 memHw, +20 Hw, +22 Vw, +88 size, +92 id); request
  0x604b60ce(job, 0): (12) stage 0xf005, (1084) effect 0x0402, +20 input 0x1000 (80 B), +96 input 0x1061, +704 output
  desc fmt 0x0c02, memHw (Hw + 63) & ~63, size memHw*Vw*2 -> 0x604af7c0 alloc new 0x1000; submit 0x604b5a83; then
  releases 0x1060, old 0x1000, 0x1061 (0x604afa9e).
- g1: work-list word 0x604b9288 -> g_sf (ext3; EXT3 end moved to 0x6081fff8) -> block +56 xb_gp: on a COLOR1-4 look
  with Glow/Clarity: pattern A into the input 0x1000 before the stock setup (rows 0-31 even 0xeb / odd 0x80, 32-63
  swapped, 64-95 barcode addr lo, 96-127 barcode memHw<<16|Vw; 32 px per bit, 1 = 0xeb), stock setup, pattern B into
  the new 0x1000 at byte 5120 (barcode lo, barcode memHw|Vw, white band). LOOKS header +20..31 = input record info
  + flags; DIRTY = 1. Writes only via the uncached alias of a 0x6/7/A/B address with hi 0.
- Emulator (fake job 0xb0000000, records 0xb0010000, image 0xb0100000): gate off -> stock, regs/sp intact; probe ->
  bands and barcodes exact, header 0xb0100000 / 0 / 1024 / 600 / 0x02 / flags 0x43, DIRTY 1. Block firmware symbols
  must come by --defsym (a `.set` absolute gave a wrong PC-relative jmp: fixed).

## Grain probe g1 camera result (PB051113/14, LOOKS.BIN header) and g2
- g1 ran twice, no crash, stock setup ok: input 0x1000 = bus 0x4dfe7000 (hi 0), memHw 5184, Vw 3888, format 0x0c02;
  A and B refused (not a 0x6/7/A/B address). So the full-size developed image is NOT CPU-addressed directly.
- CPU bus window: 0xB8000000..0xBFFFFFFF aliases bus (reg byte 3) << 27; per-CPU registers 0x98100058 (+0x4c) CPU0,
  0x98100458 CPU1, 0x98100858 CPU2, 0x98101058 CPU3 (CPU id (0x8050)). Firmware mapper 0x60071018 (`call ...,[d2,d3,a2,
  a3],28`, a0 = bus -> a0 = 0xB8000000 | (bus & 0x07ffffff), 0 on refusal: < 0x08000000 or 0xa0000000..0xb7ffffff);
  takes lock 0x60075f73 (d0 0 -> token: dispatch off + interrupt mask) / unlock 0x60075fbc, cache flush 0x60070e69,
  writes both window registers, per-CPU state table. Users: 0x60540c81 / 0x60540cea only.
- g2 (out-g2, GUIDES 93c6803e…, firmware = g1): xb_open (lock, direct for DRAM bus 0xa0000000..0xb7ffffff, else the
  mapper when the 3.5 MB stays in the window) / xb_close (unlock); header +30 bit4/bit5 = A/B via window. Emulator:
  direct path exact; window path exact with a minimal mapper stub (the emulator's buswin lacks reg 0x4c and the
  flush completion bit).

## Grain probe g2 camera result (PB051115/16) and grain test 1
- g2: A and B both written through the bus window, both in the JPEG: input 0x1000 at bus 0x4dfe7000, blend output
  0x1000 at bus 0x52cca000, 5184 x 3888, memHw 5184 (pitch 10368), format 0x0c02 = YCbYCr with Y in the even bytes
  (band even 0xeb / odd 0x80 -> white; even 0x80 / odd 0xeb -> magenta). The blend is complete when the stock setup
  returns (B survives), so the image after 0x604be2aa returns is the place for grain. Internal Y ~ JPEG Y (235 -> 226,
  128 -> 120 measured through RGB). No crash.
- Grain test 1 (om3/gprepo, out-gr1d: pkg 0aceebb4…, GUIDES 58d26773…, LABELS 73a28cb9… (24 labels)):
  slot +53 Grain 0..5 (record +51, pf_lo -5, BUNDLES 0..5), Extras sector 9 (8 o'clock, label "Grain");
  xb_cap sets 0x80 for Glow/Clarity or Grain; xb_wt w = 1024 for Grain alone; xb_gs (block +56, via g_sf) calls the
  stock setup, then xb_grain on the new 0x1000: malloc 4096 + 2 Hw (T, V, H), per row xb_p1 (noise) and, under
  xb_open (lock + mapper, per row), xb_p2 (Y -> T[Y][h]); FLUSH 0x60070e69 at the end; xb_seed carries on.
  Strength S 20/32/46/64/90 -> sigma 3.4/5.3/7.8/10.9/15.2 at Y 128 (grain/model.py, exact). Emulator: Y bytes ==
  model at levels 3 and 5, chroma untouched, bad format untouched, d2/d3/a2/a3/sp intact; wrapper gate on/off ok;
  sector 9 0..5, label 1236 B (== Python), reset, LOOKS record +51 saved.
  Frame rule (bitten twice): `call f,[regs],N` -> N includes the saved registers: locals only below N - 4*regs, and
  the caller's N must equal the callee's ret N.
- Grain test 1 on the camera: sector 9 works, the shot reboots the camera while it saves (likely the grain pass:
  too long -> watchdog, or the per-row mapper / lock). Diagnostic gd1 (GUIDES e97d7ab9…, firmware = gr1): Grain
  level = mode (1 buffer + T, 2 + noise rows, 3 + 64 image rows, 4 + 512, 5 all), S fixed 90; elapsed from the us
  counter 0x98900284 (E143 board timer channel 33) >> 10 -> LOOKS header +20 + 2 (mode - 1) (u16), +30 modes done,
  +31 runs; DIRTY set.
- gd1 camera: mode 1 ok, mode 2 (noise rows only, no image access) rebooted: the CPU loops themselves are too slow.
  Cause (I): the block and the malloc buffers are in uncached heap (0xa...), so every instruction fetch and buffer
  access goes to DRAM. gd2 (GUIDES 1e782503…): xb_p1s / xb_p2s run via `calls` at the block's cached alias
  (- 0x40000000; parameters in xb_grain's locals 64..88), T/V/H through the work buffer's cached alias, FLUSH before
  and after; xb_grain frame 112. Emulator: modes 1-5 return clean, mode 5 == model.
- gd2 camera (PB051119..123): no reboot in any mode; grain bands exactly where expected (fine-noise std top 64 rows
  10.5 vs 3.0, full image 9-12 at mode 5). Times: mode 1 13 ms, 2 1374 ms (noise for 3888 rows), 3 1440 ms, 4 1965 ms
  -> ~1.15 ms per grained row (mapper per row + uncached window), full image est. ~5.8 s (mode 5 time not saved).
- gd3 (GUIDES ebba1f03…): xb_p1s 4 px per word (SWAR, == model), xb_open reads this CPU's window register under the
  lock and calls the mapper only when the segment differs. Emulator: modes 1-5 and a window-path mode 5 == model.
- gd3 camera (PB051124..129): mode 1 14 ms, 2 804 ms (SWAR noise, was 1374), 3 866, 4 1364, 5 5059 ms. Per grained
  row ~1.09 ms either way: the mapper skip saved little; the uncached word-by-word window access dominates (~4.2 s).
  DRAM 384 MB (emulator board): cached 0x60000000-0x77ffffff, uncached 0xa0000000-0xb7ffffff, window 0xb8000000-
  0xbfffffff; 0x78000000-0x7fffffff presumably the window's cached view (the mapper flushes before every remap).
- gd4 (GUIDES c24eee88…): mode 3 = 512 rows uncached window (baseline), 4 = 512 rows through 0x78.. (cached) with
  FLUSH after each row under the lock, 5 = all rows cached. A 4-px xb_p2s variant had an index bug (h2 bits leaked
  into Y1's index): dropped, the verified per-word loop kept. Emulator: modes 1-5 == model (cached view not modelled).
- gd4 camera (PB051130..136): no reboot; mode 1 13 ms, 2 775, 3 1330 (512 rows uncached: 1.08 ms/row), 4 1097
  (512 rows cached view 0x78..: 0.63 ms/row), 5 2933 ms (whole image cached). Bands exactly where expected; full
  images grained on every row and column (no gaps): the 0x78000000 cached window view is real and per-row FLUSH works.
- Grain test 2 (out-gr2, GUIDES 25131b51…, firmware = gr1 0aceebb4): levels 1..5 -> S 20/32/46/64/90, cached window
  for window rows with FLUSH per row, diagnostics removed. Emulator: levels 1-5 == model on the direct path.
- Grain test 2 on camera works (user: "slow feeling", ~3 s). Strength reference PB051137-139 MONO Low/Med/High vs
  PB051144-148 COLOR 1-5 (same scene). Flat-area grain sigma (Y - gauss 4, MAD; shadows / mids 80-170 / highs
  170-230): MONO Low 2.4/~10/9, Med 2.3/~25/25, High 2.2/34-49/41; COLOR 1 2.9/5/3, 3 5.1/9/6, 5 9.4/16/12. MONO
  grain: none in deep shadows, flat mids-highs, finer (lag-1 autocorrelation ~0 vs ours 0.34).
- Grain test 3 (out-gr3b, GUIDES 32f3e5e6…): h 31 levels ((v + v_left + 1) >> 1), T 256 x 32 (8192 B, own malloc),
  C 945, G = MONO shape (0.08 + 0.92 smoothstep(25..100)) x (1 - 0.25 smoothstep(200..255)), S 56/98/141/183/225 for
  ~10/17/25/32/40 measured on camera. Emulator: levels 1-5 == model. (A table loop end of 1039 left T 31 wide:
  caught by the model check.)
- Grain test 3 camera (PB051150-155, levels 1-5): mids 9.5 / 16.7 / 23.4 / 30 / 36 (targets hit). User: 5 is far
  too much, 3 should be the max. New S 28/56/84/112/141 (5 = old 3 = MONO Med, 2 = MONO Low).
- Grain test 4 (out-gr4, GUIDES b1da205e…): xb_p1s keeps r in a3 (it was a stack load/store per 4 px; stacks look
  uncached), K rows per lock + FLUSH (TEST: K 1 on odd levels, 2 on even; V + 2 H buffer), timing -> LOOKS header
  +20 + 2 (level - 1) and DIRTY (TEST). Emulator: levels 1-5 == model, 5-row image at K 2 too.

## Grain log probe gl1 (om3/glog; out-gl1: pkg 29cceaa6…, GUIDES ed01ec0d…) — research into the stock MONO grain
- Findings (static): OM-3 has the E-P7 combiner 31/32 grain handlers (0x60504fd2 / 0x605050a0, gains 0x60667dc2/c8) but
  the selector reaches them only for key 0x1 (dead: keys < 12 go to the effect-code path); work-list key table
  0x606c957c has no key 12 either (MONO = default path; key 12 only zeroes job+5340/5344/5348 at 0x604b8d38).
  MONO grain setting = capture+37720 -> params(job+8508)+264 (+37721 -> +265), copied only for mode 12 (0x6054fd52,
  0x60553e44); key-12 gate 0x604b3f28 folds it into params+248 (|0x80 | lvl<<4). Filter/tone = capture+37690/37691
  -> params+248/249 for every mode; 0x800000 flag -> kind-3 request +1091/+1092. Combiner 33 (0x60505142, effect
  0x0afd) has a key-12 toning branch (table 0x606adcb6). Op-chain runner 0x6049d343 (types 1..42, type 12 sets
  S+1552 bit 24 when S+264) is used only by 0x604b4dcc <- 0x608b0a91 (factory/test path), not normal stills.
- gl1: hook 0x60504b5d (combiner config -> selector) -> s_cl (ext3, replaces g_sf; work-list word stock = no CPU
  grain) -> block +64 xb_lg logs every request's combiner/kind/stage/effect/key/format + 12 request bytes for 4 s
  after each capture (xb_mark from xb_cap, 4 slots) and copies the first two kind-0 requests (1856 B) and first
  kind-3 request (1152 B); pf_save tail -> block +72 xb_lw writes OM3MOD/GLOG.BIN (35872 B). nm_path moved to ext4.
- Emulator: boots, GUIDES/LOOKS load, editor edit + half-press save status 1 through the new pf_save tail, no GLOG
  without a capture. Logging itself needs the camera. Card backup before gl1: deliver/backup-pre-gl1.
- gl1 camera (PB051167-169, MONO off / MONO High / COLOR): shots fine, one half-press save (between shots 2 and 3),
  no GLOG.BIN. gl1b (GUIDES 82ce5a1d…, firmware unchanged): LOOKS header +20 marks, +21 log buffers, +22 key byte 2,
  +24 xb_lw calls, +25 log data, +26 GLOG open ok, +27 PROFILES.NEW fallback open ok, +28 fwrite bytes/256;
  P DIRTY after each mark and after a write attempt. User LOOKS header +20..31 zeroed (CRC = zlib crc32 of 12..).
- gl1b camera (PB051170-172): header marks 3, buffers 0, key 11, xb_lw calls 2: xb_mark ran every shot, malloc(35872)
  failed. Firmware malloc 0x60024068: <=192 / <=2112 / <=16448 B pools, larger -> error, 0 (also caps GUIDES.BIN!).
- gl1c (GUIDES 15920 B): header 48 B in the block (+32 four slot pointers), slots 6144 B each malloc'd at the first
  half-press save (xb_lw), 95 records, first kind-0 copy +3072, kind-3 copy +4928; GLOG.BIN = 48 + 4 x 6144 = 24624.
  Emulator: buffers allocated at the first save (+21 = 1), saves ok.
- gl1c camera (PB051173-176): GLOG.BIN written; marks MONO, MONO, COLOR; 0 records: 0x60504b5d runs only after the
  first selection 0x604955f1 (fn 0x604955ed, callers 0x60493d7a / 0x604950ce) found a combiner (-> 0x60504779 ->
  0x60504b2b). So plain MONO (grain off/High) and COLOR stills use no combiner at all. Capture bytes at a3+37690..
  all 0 at mark time (MONO High: +37720 = 0 there).
- gl2 (pkg c0509b3c…, GUIDES new tag): + hook 0x604955f1 -> s_cl (every request). Emulator boot/save ok.
- gl2 camera (PB051177-180): marks MONO, MONO, COLOR, 0 records again (block loaded = firmware gl2 is on). The
  combiner config 0x60504779 has one caller (0x604955ed, after the 0x604955f1 selection), so Glow stills pass there.
  gl2b (GUIDES only): log header +20 xb_lg calls, +24 past slot checks, +28 inside the 4 s window. Test adds a Glow shot.
- gl2b camera (PB061181-185, + a Glow shot): xb_lg calls 8572, past slot checks 5409, inside 4 s window 0 -> the
  window test is what dropped everything (USCLK likely per CPU: marks and request config run on different CPUs).
  gl2c (GUIDES only): no window, the first 95 after a mark; record +14 = CPU id (0x8050); slot +24 = mark CPU id.
- gl2c camera (PB061186-190): records! LV request 0x625b0d20 (+14 = 0x0130/0x0030) floods; stills +14 = 0x1000.
  MONO kind-0 dev: effect 0x0c00 -> combiner 33 (0x60505142: mono/toning config, +1732 tone, +1729, +1752), key 12,
  request +1751 = Film Grain level (Off 0, High 3), +1731 = 0xa0 (MONO only), kind-3 +1091 = 0xa0. COLOR: effect 0
  (Glow: 0x0400 + combiners 12/11). All on CPU 2 (marks too) -> the clock theory is wrong; the window failed anyway.
  CORRECTION: the selector/builder hash tables store key-11: table key 0x1 = job key 12. So MONO -> work-list handler
  0x604b908d (mask/grain passes 0x604bba9d / 0x604bbbd0 when job+5356 == 0) and selector 0x6052d03d: stage 0x0901 ->
  combiner 31, 0x0902 -> 32 (the E-P7 grain, reads +1751). Not seen in gl2c: LV filled the 95 records first.
- gl2d (GUIDES only): skip +14 0x0030/0x0130; 63 records; copy A = first kind-0 stage-0 (+2048), B = first stage 0x09xx
  (+3904), 1856 B each.
- gl2d camera (PB061191-195): still-only log. MONO still = kind-0 dev (effect 0x0c00, combiner 33, configured 4-6x)
  + kind-3 final (effect 0, fmt 0x0c02). NO 0x0901/0x0902 passes: Off and High have the same steps; the only
  structural request difference is +1751 (0 -> 3). MONO vs COLOR dev request: +10 key 12/11, +1731 0xa0/0, +1756
  0x0c00/0, +1751. (Readers of +1751 in code: only combiner 31/32 handlers - so the grain consumer is elsewhere.)
- gl3 TEST (GUIDES 16064 B - near the 16448 malloc cap!): COLOR still dev request (kind 0, +14 0x1000, +10 11) gets
  by profile Grain: 1 +1751=3; 2 +effect 0x0c00; 3 +1731=0xa0; 4 +1751,+1731; 5 = 3 + key 12. xb_gt from xb_mark.
- gl3 camera (PB061196 extra, 197-201 = Grain 1-5, 202 MONO High): 1-4 colour, no grain (hp MAD 2.6); 5 (request
  key 12) = grey Cb=Cr=128 with grain = the MONO reference (MAD 31.5). Writing request +10 = 12 turns the later
  config calls' context key to 12: combiner 33's key-12 branch (mode 92 = 0x2a1400, chroma 128..152 zeroed, 144 /
  152 = 0x2a1500, toning 84/88, luma 108..120) -> grain + flat chroma. Grain 3 (combiner 33, key 11) = no grain.
- gl4 TEST (pkg 98ca76b5…, GUIDES 16216): xp now ends `cmp 0,a1` (s_lv / s_nr drop theirs); s_h (ext2) = combiner
  33 handler word -> block +80 xb_h33: stock handler, then for a forced COLOR capture (all levels = MONO request)
  COLOR chroma back by Grain: 1 chroma block; 2 +toning 0; 3 +92 = 0; 4 +luma 108..120 init; 5 none.
- gl4 camera (PB061203 = Grain 0, 204-208 = G1-5): G1 grey + grain (chroma block restore did nothing), G2 (toning 0)
  solid green + strong grain, G3 (92 = 0) solid magenta, weaker grain, G4 grey + grain, G5 MONO + grain. White /
  tinted vignette in all. => the chroma entering combiner 33 is already flat with request key 12 (upstream MONO
  matrix); 84/88 only set the chroma level. (92) 0x2a1400 = luma source select incl. the grain (0x2a?).
- gl5 (GUIDES 16276, firmware = gl4): request stays COLOR (+1751 = 3, effect 0x0c00; G3 also +1731 = 0xa0);
  xb_h33 runs combiner 33 with context key 12 for the handler only, then G1 chroma block, G2 +toning 0,
  G3 = G2 + 1731, G4 G2 + luma init, G5 untouched.
- gl5 camera (PB061209 = 0, 210-214 = G1-5): G1 / G5 grey (Cb = Cr = 128), no grain; G2-G4 green (toning 0), no
  grain. => grain is made upstream only for a request with key 12; combiner 33's MONO config flattens chroma (with
  92 = 0x2a1400 the likely cause; the 128..152 block restore is not enough).
- gl6 (GUIDES 16196): MONO request (key 12, +1751 3); G1-3 effect 0x0c00 with combiner 33 run as COLOR (context key
  11 for the handler), G3 then 92 = 0x2a1400; G4-5 effect 0 (no combiner 33); +1731 0xa0 on 1, 3, 4.
- gl6 camera (PB061215 = 0, 216-220 = G1-5): **COLOUR + STOCK GRAIN.** MONO request (key 12, +1751 3): G4/G5
  (effect 0, no combiner 33) = natural colour with full MONO-High grain (Y hp 26.3, Cb/Cr hp ~1.9/1.2 = some chroma
  speckle), normal vignetting; G1/G2 (combiner 33 run as COLOR) = same + a white vignette; G3 (92 = 0x2a1400) green.
  => the grain is made in development for request key 12; the grey comes only from combiner 33's MONO config.
  +1731 makes no visible difference. Recipe: still COLOR dev request -> +10 = 12, +1751 = level, nothing else.
- gl7 (GUIDES 16172): that recipe; Grain 1 -> 1751 = 1, 2 -> 2, 3-5 -> 3.
- gl7 camera (PB061221-230): Grain 1/2/3 = hp 7 / 17 / 25 (Low/Med/High), back-to-back fine, profile colours fine.
  User: keep 3 stock levels. Grain gone (hp ~2) with Frame (228-229) and Glow (230).
- gl7 Art log (GLOG9): Frame = dev eff 0 (key 12, 1751 3, same as plain) + k3 0xf005 eff 0x0300 combiner 10 + final;
  Glow = dev eff 0x0400 + 0x0401 + 0x0402 c11; Star = dev eff 0 + 0x0100 / c135 0x0104 / 0x0101 (k0 key 2) / 0x0103 /
  c136 0x0106; White Edge = dev eff 0x0500 combiner 13. No grain in any. Final kind-3 request carries no grain field
  (MONO off vs high: only addresses differ; +10 12, +1091 0xa0). => grain survives only dev -> final directly.
- gl8 (GUIDES 16168): copy B = the first kind-3 stage-0 (final) request, to diff plain grain vs Frame.
- gl8 camera (GLOG10: plain G3 / Frame G3 / Star G3 / plain G0): dev requests identical (plain has a 2nd output
  1600x1200 0x0c02 at +1112..1175). KEY: plain G3's dev request is configured twice (context key 0xb, then 0xc
  after our +10 edit); with Frame/Star it is configured once (context 0xb) -> no grain. The grain needs the context
  key 12 at configuration time.
- gl9 (GUIDES 16168): xb_lg also writes context +48 = 12 when it marks the request.
- gl9 camera (PB061242-246): Art / Glow / White Edge still no grain (context 12 at the only config); plain still
  grain (hp 24). The difference is the dev OUTPUT format (+1100): plain 0x1c02 (JPEG-ready, straight to the k10
  encoder) + a 1600x1200 0x0c02 2nd output (+1112..1175); any Art Effect / Glow: 0x0c02 to memory, then an extra
  kind-3 pass (stage 0xf005, effect 0) converts to 0x1c02. => the grain belongs to the 0x1c02 output stage.
  +1751 is read by no CPU code except combiners 31/32 (never selected here) -> the image processor reads the request.
- gl10 TEST (GUIDES 16296): Grain 1/2 mark the kind-3 0xf005 effect-0 conversion pass (+10 / context 12, +1079 = 3;
  2 also +1091 0xa0), 3 the final stage-0 pass instead.

## v0.21 candidate g21 (hybrid grain) — out-g21b
- Tree om3/g21 (from gprepo: VigFix + CPU grain test 4). Grain 0..3 = Off / Low / Medium / High (xt_tab sector 9 {53,0,3}).
- Camera route (plain COLOR, Grain > 0, no Glow/Clarity (+49), no Art Effect (+50)): xb_cap stores xb_gt = min(grain,3)
  (no 0x80). Flash hook 0x604955f1 `call s_cl,[d2,a2],12` (ext2; xp now returns Z) -> block +64 xb_dev: request kind 0,
  +14 0x1000, +10 11 -> +1751 = xb_gt, +10 = 12, context +48 = 12; then jmp SEL 0x6052cf39 (reads only a0). Uses d0 d1 a1.
- CPU route (Grain with Glow/Clarity or an Art Effect): 0x80 as before; xb_wt w 1024 without Glow; xb_gs levels 1..3
  (older 4, 5 -> 3), S table 28 / 68 / 112 (= camera Low / Med / High by band-pass contrast). xb_grain TEST timing and
  K parity removed (K = 2).
- LABELS.BIN 27 labels (XL_N 27): 23..26 "Grain Off/Low/Med/High"; xb_vt slice 9 {53,0,23,3}.
- GUIDES.BIN 14964 B (< 16448 malloc cap). Emulator (V4): boots, look 1 picked, sector 9 0->1->2->3 stops at 3, labels
  Off/Low/Med/High streams 1572/1652/1620/1660 (== Python), main-1 back to 2, half-press save: LOOKS record +51 = 2, CRC ok.
- Open (camera): plain L/M/H, Glow/Frame/Star/Pin Hole/White Edge + grain, back-to-back, MONO, Grain 0, RAW edit in
  playback after a grain shot (xb_gt stays set until the next capture).
- 2026-11-06 DELIVERY MISTAKE: v0.21 candidate E1479999.BIN was copied to the card ROOT. The SD updater (hold OK at
  power-on) reads DCOLYMP/E1479999.BIN, so the camera re-flashed the gl10 file still in DCOLYMP (tag 0x588d1bd0):
  v0.21 GUIDES refused (tag 0x5822d06e) -> no Extras / labels / wheel switching. Firmware ALWAYS goes to DCOLYMP/.
- gt1 (GUIDES acaaafc8…, LABELS back to 24 / "Grain"): xb_dg writes LOOKS header +20.. per capture. Camera PB061256
  (Grain 3, nothing else): glow 0, art 0, grain 3, xb_gt 0, flags 0x80 -> took the CPU branch. Cause: `movbu (49,a1),a0`
  / `movbu (50,a1),a0` (fb 2a, AM33 extended Rn form) misread on the camera (worked in the emulator). Photo Y hp 12.2,
  Cb/Cr 0.7/0.9 (CPU grain). gt2: xb_cap uses data registers only; no fb-prefixed instruction left in the block.
- gt2 camera (PB061257/258, Grain 3 plain): xb_gt 3, flags 0, xb_dev marked, no CPU pass; Y hp 12.2 / 10.7,
  Cb/Cr ~1.8 (camera grain), fast. g21e (GUIDES 14960 B, firmware unchanged 833a7497…): diagnostics removed; user
  LOOKS.BIN header +20..31 zeroed (CRC fixed). Next: effects matrix.
- gt3 camera (user): effects + grain all OK; but with the camera route, Blacks / Whites / A-B / G-M / NR / VigFix do
  not apply (only grain shows). Known cause for Blacks/Whites: tone gate needs request key word 0x000b0000 (we set
  +10 = 12). WB / NR / Vig are capture getter overrides -> key-12 development takes them from elsewhere (not traced).
  g21f (GUIDES 15000 B): camera route only when slot +26, +27, +47, +48, +49, +50, +51, +52 are all 0; else CPU grain.
- gt4 TEST (GUIDES 14956 B, out-gt4; g21f saved as om3/xblock_g21f.s): camera route for any look without Glow/Art
  again; xb_dev writes +1751 and context +48 = 12 only, request +10 stays 11 -> does grain survive, and do tone / WB /
  NR / Vig apply?
- gt4 camera: no grain with context key 12 alone (+10 must be 12). Back to g21f logic. User: speed up the CPU grain.
- gs1 TEST (GUIDES 15144 B, out-gs1): noise strip = 2 noise rows (V + 2H buffer), fresh per band of 32 rows, each
  image row reads h at a random offset (xorshift, mask = 2^k - 1 < Hw) -> no per-row noise pass (was ~0.78 s);
  K rows per lock + FLUSH generic loop (edge: retry the pass with one row). TEST: S 68 at every level, K 2 / 8 / 16
  for levels 1 / 2 / 3, elapsed (1024 us units) -> LOOKS header +20 + 2 (level - 1), DIRTY.

## Option 1: camera grain + all settings (research) — om3/gw
- Request config fn 0x604955ed: SEL(C) -> if result: combiner config 0x60504779, format checks, 0x604980b5. Key 12
  plain dev: SEL table key 1 -> 0x6052d03d needs stage 0x0901/0x0902 (not a dev request) -> 0x6052d0c2 path.
- gw1 (pkg 986c454d…, GUIDES 15760 B, out-gw1): firmware = v0.21 + pf_save tail -> block +72 (nm_path moved to
  ext4, now full) + tone gate: request key 11, or 12 with +1731 == 0 (MONO has 0xa0). Block: camera route for any
  look without Glow/Art (TEST), xb_dev calls SEL itself and logs (GLOG 'GLG1': 4 slots x 6144, 16 records, copies
  A first sight +544, C after each dev call +2400, B at the first kind-3 call +4256, 1856 B), xb_mark slot header
  +16.. Glow Art A-B G-M Blacks Whites NR Vig Grain xb_gt flags CPU. Emulator: boot, editor, save x2 fine.
- gw1 camera (PB061284-299, Daylight WB, aligned pairs): with the tone gate fix every setting survives the camera
  grain: Blacks / Whites (tone maps identical within ±3 after registration), A-B (+5: wall Cb -8.1 G0 / -8.4 G3),
  G-M, NR Off (shadow noise ISO 12800 Y 25-45: 6.95 with grain ~ 7.2 without), Vig Off. Request after config (copy B):
  G0 vs G3 differ only at +1751 and +1148 (1 / 3). Side effect: camera-grain shots ~9-11% less chroma (Cb/Cr spread).
- g21g (GUIDES 14968 B, for firmware gw1 986c454d…): camera route for every look without Glow / Art Effect; logger
  removed; block +72 = rets (pf_save hook kept). Emulator: editor, saves fine. = v0.21 candidate (firmware gw1).
- 2026-11-06 restored user's looks: LOOKS.BIN = PROFILES.BIN (Nov 4, all 12 named looks intact) with sel 0 and header zeroed (fe1ad5a6…); card's previous LOOKS kept at om3/deliver/LOOKS-card-before-restore-20261106.BIN. Cause of damage: pf_wb captures live state into the SELECTED look at each save.
- Look saving (user: "save only on purpose", in v0.21). lk1 (pkg 6a0d0cea…, GUIDES 15204 B, tree om3/gw): ed_trig no
  longer calls pf_wb (removed); s_look no longer captures the look it leaves; ed_event on the Looks page (axis 4)
  -> lk_hold (ext1): held OK with a look selected = pf_cap into that look + dirty + refresh (no look: the reset);
  pf_cap split (pf_capto: a3 = destination); ed_pmod -> lk_pm (ext1) -> block +80 xb_lkd: '*' = COLOR k now (pf_capto
  into xb_lkbuf, pre-filled from the record) differs from its selected look; -1 -> stock defaults test.
  Emulator (L2): pick look 1, Grain edit, save -> record untouched (only sel); OK held on the Looks page (wheel) ->
  dirty, slot kept, save -> record 0 +51 = 1 only. With the cursor moved down (L1) hold did nothing. '*' camera test.
- lk2 (pkg e0af1a78…, GUIDES 15204 B): user: no reset on the Looks page at all. lk_hold without a selected look ->
  nothing (-> 1, ed_event e_ret). Emulator (M1): Looks page, no look, OK held -> Grain 1 and hue kept; Saturation page
  OK held -> full reset (hue, Extras 0). Hold INFO not possible (router gets one 0x9014 per press, hold or not);
  REC / AF-ON never reach the editor; multi-selector press / |o| close it.
- lk2 camera: (1) Looks page still shows "Reset [OK hold]"; (2) the whole-profile reset (OK held on "COLOR n", event
  0xf881) was gone: the axis byte stays 4 there, so lk_hold took it. lk3 (pkg a876a502…, GUIDES 15204 B): lk_hold acts
  only on 0x903e (low byte 0x3e at (24,sp)), else e_rst; ed_isdef returns "default" while axis == 4 (no Reset guide on
  the Looks page; side effect: no '*' there via ed_isdef with no look selected); gd_mode moved to ext3 for room
  (ext1 and ext10 now full). Emulator (N1/N2): wheel hold with look 1 -> record saved; `up` to COLOR 1, OK held ->
  0xf881 -> hue and Grain cleared (axis 4).
- User: A-B / G-M ignored under Auto WB (fine with any preset). Capture WB 0x60457940..: capture +37644 selects the
  branch; presets read 34041 / 38521, Auto WB (default branch 0x60457d22, and 0x60457ae4) reads its own fine-tune keys
  7401 / 7417 (or 7433 / 7449, by (36,sp) / capture +37677) into the same capture +37734 / +37736; a second
  population 0x618e6610.. reads them too. lk4 (pkg a278edc3…, GUIDES 15296 B): 9 Auto WB getter sites -> wb_get,
  which now takes 7401 / 7433 as A-B and 7417 / 7449 as G-M. Room in ext1: lk_hold's body moved to the block
  (+88 xb_lkh, jmp from the 16-byte flash stub; e_lk / e_ret / e_rst by defsym). Emulator: look save on the wheel,
  COLOR 1 reset fine. AWB effect needs the camera.
- lk5/lk6 (user tweaks): (1) whole-profile reset (0xf881) also clears the look selection: ed_event always jumps to
  lk_hold -> block xb_lkh (0xf881: LIDX k = 0, e_rst; 0x903e on axis 4: save; else e_rst). (2) Extras dial dead
  clicks past a slice's max (the dial widget's index ran on; ed_set refusing or clamping did not help): pf_cnt /
  pf_vbi now give Extras cells (928 + 12k + slice, axis 3, EMARK) their xt_tab range via block +96 xb_cv / +104
  xb_vb; both rewritten in ext1, old copies removed (ext10, ext8). Room: wb_get's body moved to the block (+112
  xb_wb; 19-byte flash stub, stock value without a block). s_x clamps instead of refusing. lk6 (pkg d595455b…,
  GUIDES 15740 B). Emulator (S1): Looks dial 1, 2, back 1; Grain 1, 2, 3, 3, 3 then -1 -> 2 at once; Blacks -2..1
  and back; Saturation page fine; save ok. (3) "COLOR n" -> look names: deferred to v0.22 (several bitmap sizes and
  '*' variants, name pictures at those sizes, heap space).
- lk6 camera: REBOOT at every half-press. Not reproducible in the emulator (no capture / AE pipeline there). Suspect:
  wb_get's body running from the code block (heap) for the WB fine-tune reads at S1 (pipeline params / AWB, likely
  another core). lk7 (pkg 4405d38d…, GUIDES 15596 B): wb_get back in flash, instruction for instruction as lk4
  (camera-proven); room from pf_is (111 B) -> block xb_pf; pf_cnt / pf_vbi = stubs (ids 928..975 only -> block +96 /
  +104, else stock); s_x refuses again (the dial range makes clamping moot). Emulator (T1): Looks dial, Grain stops
  at 3 and comes back at once, Blacks, wheel save, COLOR 1 reset (look cleared), save. Lesson: hooks on capture /
  AE paths stay in flash or proven block entries; do not move them to the block without a camera test.
- lk7 camera: no reboot; but switching Natural / MONO -> COLOR hangs ~1 s, goes black, then COLOR (also with no look).
  With a mismatched GUIDES (block not loaded) the hang is gone -> block. Switching to COLOR opens the wheel editor:
  its children build their lists = 12 pf_cnt + 127 pf_vbi calls, now all into the block (uncached heap: every
  instruction fetch from DRAM). lk9 (GUIDES 15664 B, firmware = lk7): entries +96 / +104 go through trampolines to the
  cached alias (-0x40000000) of xb_cv / xb_vb, which only call block code (xb_pf, xb_xt, xb_p). NOT for code that
  calls the firmware: its PC-relative fields are relocated for the uncached address (lk8 ran xb_lkd cached ->
  pf_capto call landed at 0x2081fe97, emulator trap). Emulator (X9): editor open 127 vbi via the cached path, Looks
  dial, Grain range, wheel save, COLOR 1 reset, save all fine.
- lk9 camera: still hangs / looks like a reboot into COLOR. tA (GUIDES-only test, out-tA): xb_cv / xb_vb answer nothing (stock lists) to split count/vbi from the rest.
- tA camera: no restart when count/vbi go stock -> the dial-range answers cause the COLOR switch restart. lk10
  (GUIDES 15640 B, firmware lk7): xb_cv / xb_vb rewritten frameless (one 4-byte call slot) around a leaf xb_cell
  (P, axis 4 Looks 12 o'clock / axis 3 Extras cell with marker), cached trampolines, no firmware calls. Theory:
  stack depth in the switch path (lk7 / lk9 added ~48 B of frames). Emulator (A10): Looks dial, Grain range, Blacks,
  empty sectors, wheel save, COLOR 1 reset, save fine.
- lk10 camera: COLOR switch fine (user confirmed). => v0.21 candidate = firmware lk7 (pkg 4405d38d…) + GUIDES lk10
  (0b936448…), LABELS gt1 (73a28cb9…, 24 labels), source tree om3/gw.

## COLOR 2-4 whole-profile reset bug (user report on lk7 + GUIDES lk10)
- Report: hold OK on "COLOR n" (n = 2..4) -> only the stock Saturation wheel, INFO shows no other pages, until another
  mode is selected. COLOR1 fine.
- Emulator (pp/session_ed1.mjs: 'right' in the picture-mode list = next COLOR; snap now logs EDK; vals adds 2197+k,
  2201+k): NOT reproduced on COLOR2/3/4, with or without edits, look selected, from pages 0/1/3/4, the user's own
  card files (LOOKS 8d2701f3…, BUNDLES fe109ce4…), double hold, half-press after. Reset sets 2197+k and 2201+k to 1.
- Diagnostic gdx (GUIDES-only 660aa498…, 16388 B, flash unchanged): block logs 'K' (each k_ad = k_go passed its checks:
  k, AXIS, EDK, 2201 value, final ALL state), 'H' (xb_lkh: event, AXIS, EDK, LIDX), 'C' (editor key, children id bits,
  first id), 'S' at the save -> OM3MOD/GLOG.BIN (8 + 48 x 8 B). Decoder: scratchpad glog.py. Emulator: records as
  expected. No K after the H/C on the camera = k_go rejects (children / PVAL); K with final 255 stuck = ALL state.
- Camera log (gdx): one reset (COLOR2, H/C ok, children fff), then K records stepping pages normally: bug not seen.
  "Reset all of them" = COLOR3/4 were already blank (BUNDLES.BAK). User's real complaint: the '*'.

## lk11 (tree gz; pkg 9c423edb…, GUIDES bdbb61f1… — block relinked, pair them): '*' = differs from OM factory defaults
- User rule: every wheel at the OM factory default -> no '*'; any change -> '*' (with or without a film).
- ed_pmod: lk_pm (look compare, block +80 xb_lkd) dropped; clr d3 + stock loop through ed_isd0 = ed_isdef that
  also compares on the Looks page (d1 = 1; ed_isdef's own callers d1 = 0 keep "default" there: no Reset guide).
- Film 0 ("none") wrote 0 to the 18 camera settings: COLOR2-4 factory defaults are not 0 (COLOR2 sat 1,1,0,0,0,0,
  1,1,0,0,1,1, tone 3/0/-3 on 979..981) -> '*' after film 0. pf_put neutral now = pf_dflt (ext1): stock_default
  0x60b86e44 (facade +156 stock; ed_default reads 0 on H/L/Looks pages) per id.
- Emulator (pmod probe = call 0x6129ba07 per picture mode; dflt:ADDR probe): reset -> 0; film 1 -> 1; film 0 -> 0
  with factory values; Hue / Extras edit -> 1, edit back -> 0; Looks page shows it too.

## lk12 (tree gz2; GUIDES d991fecd…, firmware = lk11 9c423edb… unchanged): COLOR4 '*' after the reset
- Camera: COLOR4 keeps '*' after "COLOR 4" hold-OK reset. Emulator (film on COLOR4, reset): 964 (12 o'clock) = 0, not
  its factory -4. Cause: the reset ran with the children still holding the Looks page dial list (0..5); the stock
  reset's -4 came back clamped to 0. COLOR1-3 12 o'clock defaults (0, 1, 4) are inside 0..5. Same risk for page
  resets from Extras (slice ranges).
- Fix (block only): xb_lkh's resets jump to xb_rpre: page != Saturation -> AXIS 0, children 1..12 re-read (REFRESH
  0x611b20ea, stock lists), then E_RST (puts the page back and re-reads as before).
- Emulator: COLOR4 film -> reset -> -4,0,0,0,-1,-1,-1,0,0,0,0,-4, '*' 0, INFO pages cycle; Extras-page reset on
  COLOR3 -> factory 4,4,4,4,4,3,...; Hue/Extras page resets keep the film selection (and its contrast/tone) -> '*'.

## Space audit (2026-11-06, after v0.21)
- Our flash space: 10 section tails (ext1..ext10) inside the loader's copy ranges, 7492 B in all; used 7372 B
  (ext1 1742/1744, ext4 1776/1776, ext10 1232/1264, ext6 600/608, ext5 572/576, ext3 481/492, ext8 461/512,
  ext9 379/384, ext2 83/88, ext7 46/48): ~120 B left. GUIDES.BIN 15676 B of the 16448 B malloc cap (code block 3744 B,
  the rest guide pictures); uncached pool ~45 KB shared.
- Loader 0x60045ed5: copies dest..end for sections 1..10 (dest/src from table 0x60029b28, end from the jump table at
  0x60045e6c: one `mov imm32` each at 0x60045e84/8c/c4/94/b4/9c/a4/bc/ac/cd, the ONLY references to those values),
  length = end - dest through 0x600232d1 (flags 0x10200).
- Between each loaded end and the next section start the file is all FF (never loaded): s2 270336 B, s3 32768,
  s4 296960, s5 2048, s6 1005568, s7 342016, s8 149504, s9 342016 = 2441216 B (~2.33 MiB). s10: 0x61aa4800..0x62020fe0
  holds data at 0x61aad000..0x61aaddc0 (referenced from boot code 0x600211d8 etc.) — leave s10 alone.
- Emulator (pp/gapprobe.mjs): sentinel 0xA5 written over every gap before boot; boot + half-press + editor + INFO
  pages + playback + menus wrote 0 bytes in any gap (aliases 0x60/0xa0 verified to share memory). Static scan: no
  aligned references to the gaps besides the end constants (unaligned code-byte false positives only).
- Not yet covered: video recording, Wi-Fi/Bluetooth, USB, the SD updater — a camera probe is needed before using a gap.
- Unused in our own code since lk11: block xb_lkd + xb_lkbuf (~0x377 B incl. 64 B buffer), xb_sv stub.
- GX1 space test (tree om3/gxt, out-gx1; pkg see outputs/gx1, GUIDES rebuilt for it): section 6 end 0x60f49800 ->
  0x60f4a800 (loader word 0x60045e9c); 0x60f49800.. = 'GXT1' header + probe + 888-word pattern. pr_hook calls
  gx_go (ext8, +26 B) -> gx_probe when the header is loaded -> ed_trig. Probe: same gate as saves; pattern check;
  one gap sum per pass (round robin s2..s9, s6 from 0x60f4a800; round 0 = baseline); writes OM3MOD/GAPTEST.BIN
  (112 B: GXR1, passes, bad, npat, base[8], last[8], changed[8]) every pass. Emulator: 25 passes, bad 0, changed 0.
  No GAPTEST.BIN on the camera = the extension was not loaded (loader change ineffective).

## v0.22 Sharp (2026-11-07; camera-tested)
- Details in docs/DEVELOPER_NOTES.md ("v0.22 Sharp"). Capture read 0x603e767f (key 0x8119) -> s_nr -> block xb_nr;
  slot +54 / record +52, -5..+2, -5 sent as -7. Column builder 0x611bd814 / switch table 0x61533520: COLOR 1-4
  -> pm_color (5 rows, Sharpness dropped). Camera: Off clearly softer than 0; quick grain fine; row removal fine.
- Video: not traced. The hook is the stills capture read; video most likely keeps the hidden stock Sharpness.

## Picture-mode sliders research (2026-11-07; emulator only; branch feature/v0.23-alpha-profile-sliders)
- COLOR column items (list 0x61530758, count via the builder's switch): 111 Picture Mode, 5397 wheel, 5398 Highlight
  & Shadow, 5399 Shading, 7 Sharpness, 8 Contrast. Item table 0x6154c2a8 (17 x 40 B, keyed by item id; slider items
  7 / 8 / 59 / 5399 have a type-4 title field: string ids 256 / 91 / 227 / 4809). Column list object: count +92,
  cursor +94, item ids array at +108 (vtable 0x61533620: +8 count 0x611b405c, +16 item 0x611b4083).
- Slider rows read the *virtual* id in the left column (GetValue(7) / (8) / (1016)) and the resolved id (904+k /
  908+k / 912+k) in the bar: the bar's value list comes from facade +28 count and +32 value-by-index, +40
  selectable (0x60b86a01, word 0x60e5749c) per value; changes go through facade SetValue (our .hook_set site).
- Left-column readout: 0x611d1697 (sign) and 0x611d1708 (digit) look the value up in per-item tables: 5 entries
  (-2..+2) for 7/8/59 (0x6154c648 / 0x6154c670 ...), 11 entries (-5..+5) for 5399/1011/5397 (0x6154caa0 /
  0x6154caf8). Out-of-table values draw blank.
- Bar setup 0x611d0f99: ends per item (7/8/59: a3 = -2, d0 = 2 at 0x611d106a; 5399: -5 / 5), dot x = centre +
  value x 155 px (0x611d10ff `mul 155`; Shading's path 62 px). The "-" / "+" grey out at value == min / max.
  0x612af358: 5 vs 11 steps per item (likely touch mapping; not patched).
- Result (emulator): the Sharpness row as the Sharp slider -5..+2 with correct readout, ends, dot; in sync with the
  Extras wheel; looks and the hold-OK reset update it; Contrast untouched.
- MISTAKE (do not repeat): the slider code went into ext11 = 0x60133000, inside the FF run 0x60128e40..0x60134000 at
  the end of the image's first part. The space audit above says the FF stretches between sections are NOT loaded
  on the camera (the emulator maps the whole image, so it hides this). That build must not be flashed. Only the
  ext1..ext10 tails (inside the loader's copy ranges) are proven; the gap-space probe (branch
  experiment/firmware-space-probe) is the way to get more.
- Calling convention lesson: `call f,[regs],N` writes the return address at (0,sp) of the caller, so a CALLS-entered
  hook that pushes registers with movm must `add -4,sp` before its own `call` (and undo it), as pf_cnt does.
  Also `call` overwrites MDR: save it around calls in a `rets` routine.


## Session wrap-up (2026-11-07)
- Released: v0.22 (Sharp, camera-tested; film sims carry Sharp). Control Panel live with it.
- Pushed branches: `feature/v0.23-alpha-profile-sliders` (Sharp on the Sharpness row; emulator only; DO NOT FLASH:
  code in unloaded space, must move first), `experiment/firmware-space-probe` (GX1 probe on v0.21; not yet run on
  the camera), `experiment/grain-cpu-colour` (parked grain test 4). Old `v022-sharp` branch on GitHub is stale
  (same as v0.22); the owner may delete it.
- Repo now holds the whole lab: this notebook, tools, emulator scripts, archives, `CLAUDE.md`,
  `research/setup.sh` (asks for the owner's firmware file; tested from scratch), `docs/FILM_SIMULATION_ROADMAP.md`,
  `docs/PHOTO_TO_LOOK.md`. The claude.ai Project "Om3 Firmware Build" has matching custom instructions.
- The official firmware file stays on the owner's Mac (too large for chat or Project uploads, 30 MB limit): link the
  session to the Mac or have it attached.
- Next (see the roadmap): 1. the owner runs the firmware-space probe on the camera; 2. emulator research on split
  toning and coloured glow; 3. WB mode / exposure compensation per look; 4. move the slider code to proven space.

## Split toning research (2026-11-07; static + emulator only, no camera build; scripts in research/splittone/)
- Question (roadmap): where do Cross Process / Vintage tint shadows and highlights, and can COLOR looks reuse it?
  Answer: the **RGB gamma stage** (per-channel tone curves). Idea from Caduceus E-P7 docs/FUJI_GAPS.md gap 6
  (cakelesscoder, static only there: E-P7 setter 0x603ae7d3 takes three curve pointers); the OM-3 code differs.
- OM-3 map (static): development function ... 0x605196f6 matrix 0x605147a2 -> **0x605196fd gamma stage 0x60516ad9**
  -> 0x60515e64 -> stage list 0x605197c2 (COLOR 0x60518573, luminance LUT 0x60518db2, our tone hook 0x605197d7, ...).
  Gamma stage: a0 = context C (C+4 R, C+12 O, C+48 key); selector **0x605163f8**(a0 R, a1/d0/d1 = where to put the
  R/G/B curve-object pointers); art-cache object (R+1524 -> +5220, compared and skipped when unchanged; 0 for our
  synthetic COLOR request); copier **0x605169a4** (a0 O, a1/d0/d1 R/G/B objects) called at **0x60516c8d**
  (`call 0x605169a4,[d2,d3,a2,a3],32`, 7 B = possible hook site).
- Copier: per channel 256 x u16 from obj+144 and 64 x u16 (fine table for the first knot) from obj+16 into
  **O+1252 (R) / O+1892 (G) / O+2532 (B)** (640 B each: +0 256 entries 12-bit 0..4095, +512 the 64 fine entries),
  pointers to them at O+3172/3176/3180, O+0 bit 20 cleared, header words -> O+188/192 and O+452 bits 24-26.
  Curve object = 8 x u16 header | 64 x u16 | 256 x u16 (656 B). The job owns the copies: our code can bend them
  in place, no ROM data or pointer swap needed (unlike the E-P7 plan).
- Selector: R+1756 == 257 -> lookup row 0x606d403c; art override R+1568 (object +28 vs R+56 bit) -> one curve;
  else id = R+8 (byte) << 24 | R+9 << 16 | u16 R+10; id < 2000 or > 0x02000096 -> default path 0x605167f6
  (R+1923 == 2 gradation -> 0x6068c878; R+1587 1/2; R+1936; 0x6052d394) -> row 0x606d3d3c; else hash 0x606d493c
  (32 x {id - 1999, handler}). Rows: table 0x606d3d3c, 32 B = 8 object pointers; column by R+14 via 0x605163a1
  (stills +14 0x1000 -> column 0, +4 when variant flag 0x6052d2d7). Picture modes: one curve 0x6066c04c for R=G=B.
- Emulator (selector run natively, mk_ncall_sel.py; ncall token): ids 11 / 2000 / 2001 / 0x01010064 / 0x01020064 /
  0x01010066 / 0x01010067 / 0x0101..0x01030070 / 0x02000093 / 96 -> the same curve for R, G and B. **Different
  R, G, B curves:** 0x0101006b and 0x0102006b (Cross Process I / II), 0x01010079 / 0x01020079 / 0x01030079,
  0x0102007b. Names of the 0x..79 / 0x..7b ids are not in a table we found: from their curves (lifted navy blacks,
  faded warm whites) 0x..79 = Vintage I-III is a strong guess; 0x0102007b (lifted blacks, whites capped at 237,
  cyan low mids) unknown. 0x..70 (I-III) uses the plain curve (name unknown).
- Grey tints of the stock curves (curves.py, analysis; 8-bit Cb/Cr before the luminance LUT / COLOR stages):
  Cross Process I green shadows and mids (input 32: Cb -16.5, Cr -23.4), slightly blue highlights (+5 Cb);
  Cross Process II magenta-red mids (Cr up to +50); 0x01010079 blue shadows (black lifted to B 80), yellow highlights.
  So both roadmap examples tint by brightness through three different gamma curves, nothing else.
- Emulator, whole stage (stage_test.py: synthetic C/R/O, R+1660.. image size needed or 0x6052d41a divides by 0):
  COLOR (id 11, and id 12 = camera-grain route) reaches the copier call 0x60516c8d with 0x6066c04c x3 and leaves
  three identical tables at O+1252/1892/2532; Cross Process I and 0x01010079 leave three different ones.
  copier_test.py: the copier writes exactly O+188..195, O+455, O+1252..3183, data == the firmware objects.
- Design (ours, model.py, analysis only): after the copy, per channel c: t = curve[i], s = 4095 - t,
  ws = ((t*s>>12)*s)>>12, wh = ((t*t>>12)*s)>>12 (peaks 606 at 1/3 and 2/3, 0 at black and white),
  curve_c[i] = clamp(t + ((Ks_c*ws + Kh_c*wh) >> 8)). 6 signed bytes per look (Ks/Kh R,G,B) made by the Control
  Panel from shadow hue / strength and highlight hue / strength (12 hues, strength 0..5 = 0..10 Cb/Cr units at the
  peak; Cross Process I reaches ~23, so the range may need raising after a camera test). Curves stay rising, black
  and white unchanged; works on top of Cross Process too. Estimated code ~100-150 B (768-entry loop).
- Where the code can run (space is the blocker, as for everything): (a) hook 0x60516c8d -> stub -> block; the stub
  must sit in sections 1-5 (section-2 stage, bootloop lesson of v0.20 test 1), which have 2-5 B free each;
  (b) piggyback on the camera-proven tone hook (ext5, same C/O, runs after the copy in the same pass; 4 B free there);
  (c) wait for the firmware-space probe. The curves would also apply to Art Filters unless gated on key 11 / 12
  (+1731 == 0, as tone). Not known: whether live view runs this stage (would preview the toning), the fine table's
  role when the header words are 0 (art curves zero it), Cross Process strength (R+1568 / 0x6052dc3c not traced).
- Free camera check, no firmware: a grey card / white wall in Cross Process I should show green shadows and mids.

## Firmware-space probe GX1 on the camera (2026-11-07; camera-tested)
- Flashed `experiment/firmware-space-probe` (package 0c936df9…, GUIDES f7fe50e0…, v0.21 LABELS) on the owner's OM-3
  and used it normally; card files backed up first (`BACKUP-2026-11-07/` on the card), restored to v0.22 after
  (LOOKS / NAMES / BUNDLES were untouched by the test; checksums equal to the backup).
- `OM3MOD/GAPTEST.BIN` was written: **the loader change works** — section 6's loaded end moved from 0x60f49800 to
  0x60f4a800 (loader word 0x60045e9c) and the camera loaded and ran the probe code placed there.
- Last boot's run: 45 passes, `bad` 0 of 888 pattern words (the extended 4 KiB stayed intact), every gap summed ~5
  times with `changed` 0 (nothing wrote into any gap during that run).
- Gap sums: s2 0x987fd2e7, s3 0xe7b8a684, s4 0xc8fe8d3e, s5 0xa7c6315f, s6 (from 0x60f4a800) 0x1910c2dc,
  s7 0x5efa3ee0, s8 0x3507ab67, s9 0xb0d61cec. An all-FF gap would sum to -(words) (s2 0xfffef800 …): none does,
  so the gaps do NOT hold the file's bytes on the camera — confirming they are not loaded unless a loader end is moved
  (the emulator maps them, the camera does not: the sliders mistake).
- Coverage (owner, confirmed by the card): photos JPEG+ORF (PB071392/93, 19:41) and a video (PB071394.MOV,
  106 MB, ended 19:42:40) inside the last run (GAPTEST.BIN last written 19:42:50); Wi-Fi connected during the test.
  Both worked normally. USB and Bluetooth-only not reported.
- So: code and data can go past a section's loaded end **after moving that section's loader end word** (proven for
  s6 +4 KiB). Not yet proven: larger extensions (s6 has 1005568 B), other sections' end words, and which camera
  activities beyond those below. Next: a bigger extension
  (e.g. s6 +64 KiB) with the same probe, then move the slider code (ext11) there.

## Firmware-space probe GX2, 64 KiB, on the camera (2026-11-07; camera-tested)
- Branch `experiment/firmware-space-probe-64k` (on v0.21): section 6 loaded end 0x60f49800 -> 0x60f59800, 16248-word
  pattern, magics GXT2 / GXR2. Package 3e154b3c…, GUIDES 5a73b4bb…, v0.21 LABELS. Emulator: 39 passes, 0 bad.
- Camera: `GAPTEST.BIN` = GXR2 -> **the 64 KiB extension loads and the code in it runs.** The last run held one pass
  (20:00:42), after 3 photos JPEG+ORF (19:59:00-02) and a video (PB071398.MOV, ended 20:00:08): **all 16248 pattern
  words intact** after video recording. Owner noticed no problems. Only one pass after the last power-on, so this run
  gives no gap-change data (GX1 already showed none over 45 passes).
- Gap s2 sum differs from GX1's (0xa13fc1e6 vs 0x987fd2e7): unloaded RAM holds whatever is left there; another sign
  the gaps are not loaded.
- Conclusion: section 6 can grow by at least 64 KiB (0x60f49800..0x60f59800) for code and data, loaded from the
  update file. Use it for test builds (each one camera-tested as usual); larger growth or other sections' end words
  need their own probe. The sliders code (ext11) can move here.
- Card restored to v0.22 (f53950c9…) with the owner's LOOKS / NAMES / BUNDLES unchanged.

## Picture-mode sliders: tests 2-4 (2026-11-07; camera-tested; branch feature/v0.23-alpha-profile-sliders)
### Test 2: code moved into proven space
- `.ext11` (the slider code, 560 B) moved from the base-image FF tail (0x60133000, unloaded on the camera) to
  0x60f49800, the start of the 64 KiB section-6 extension. build.py raises the loader end word 0x60045e9c from
  0x60f49800 to 0x60f59800, the exact patch the camera-tested GX2 probe used. Image diff against test 1: only the
  loader word, the moved code and the branches/pointers into it.
- Emulator: Sharpness row on COLOR 1 goes 0 → −3 → −5 (minus greyed) → +2 (plus greyed), readout and dot right;
  Contrast row still ±2. **Emulator only.**
- Package: E1479999.BIN sha256 5cc25974…, GUIDES.BIN a1927a32…, LABELS.BIN unchanged (v0.22, 6932bfb8…). Put on the
  owner's card and checked by checksum. Camera result: works (below).


### Test 2 camera result; tests 3 and 4
- **Camera-tested (test 2):** the Sharpness row works on COLOR 1-4 with the code in the section-6 extension. Owner:
  +2 did not reach the right end (one 62 px step for the whole -5..+2 bar), which looked off.
- Test 3 (emulator only): sl_dot splits the bar at 0 (on the centre mark): below 0 steps 62 px (-5 at the left end),
  above 0 the stock 155 px (+2 at the right end).
- Test 4 (emulator only): Grain on the camera's own **Film Grain Effect** row (item 5400, the MONO 1-4 row: string
  2778, choices Off / Low / Medium / High, 2779..2782). Added to pm_list after Contrast.
  - The row's setting id per picture mode: 0x611c308a searches table 0x6153670c ({mode, id} x 4: MONO 57/58/59/65 ->
    999..1002), COLOR got 0. build.py points it at gr_tab (8 entries: the stock four + COLOR 54/55/56/64 -> our ids
    GRB 0x7e00 + k) and raises its count (0x611c30b6) to 8.
  - The left column's id lookup 0x611d1963 (table 0x6154cc80, count shared with item 131 at 0x611d19b2): hook_lc at
    0x611d1982 sends 5400 to gr_tab with count 8 (item 131 untouched). Its icon value is GetValue(998) (0x611d0b6d,
    MONO "the mode's grain"): sl_slot answers 998 on COLOR 1-4 like 7.
  - Facade handlers take GRB..GRB+3: count 4, value by index 0..3, selectable 0..3, get / set slot +53 (the Extras
    Grain byte, then s_dirty). The stock choice row wraps High -> Off on the dial (stock behaviour).
  - Emulator: Off / Low / Med / High selectable, title follows ("Film Grain Effect Medium"), the value stays when
    leaving and coming back, the left-column icon follows; Sharpness and Contrast unchanged.
- Package test 4: E1479999.BIN f4e07404…, GUIDES.BIN c8e8ec7c…, LABELS.BIN unchanged (6932bfb8…). On the owner's card,
  checked by checksum. **Camera-tested (owner, 2026-11-07 21:07): "works perfectly"** (Sharpness bar ends and the Film
  Grain Effect row on COLOR 1-4). Not separately reported: MONO 1-4's own grain row (its table entries are kept first,
  unchanged) and touch on the row.
- Strings: the camera's text table is in decoded section 01 (UTF-16LE); index at file offset 0x24a0ac, u32 entries
  minus 0xa4f22020 = the string's file offset (256 Sharpness, 91 Contrast, 227 Saturation, 4809 Shading Effect).

### Test 5: two new rows, Noise Filter and Shading Comp. (emulator only)
- New Picture Mode rows on COLOR 1-4 (the camera has no row for either): **Noise Filter** (string 188, the camera's
  name for its NR) = slot +51 as a slider -2..+1 (-2 Off, -1 Low, 0 Camera, +1 Standard), and **Shading Comp.**
  (string 254) = VigFix slot +52 as a slider -1..0 (-1 Off, 0 Camera). Row order: Picture Mode, wheel, H&S, Shading,
  Shading Comp., Sharpness, Contrast, Noise Filter, Film Grain Effect.
- Item ids NR_IT 5394, VF_IT 5389 (not in the item table; picked so their keys miss the row switches); bar ids
  NRB 0x7e10 + k, VFB 0x7e20 + k.
- How a row exists (all in the column code 0x611c2xxx / 0x611d0xxx):
  - Item table 0x6154c2a8 (17 x 40 B: id, +4/+16 title struct {4, string id, 0x6154b480}, +26 left-column icon) is
    searched at 0x611d040d and 0x611d0846 (count 17): both now take it_tab (stock 17 + ours, count 19).
  - Nine hash switches on item - 6 ({key, target} x 32 or 16, linear probing, key 0 = empty): 0x61536a2c / b2c / c2c
    / d2c (row actions; item 7's targets are generic), 0x61536f2c (the bar object's setting id: our nr_f / vf_f give
    NRB/VFB + k), 0x615510cc (bar setup, generic), 0x615511cc (generic), 0x6155124c (left-column cell: item 7's =
    type-4 cell, GetValue(item id); Shading Comp. uses lc_vf = Shading's type-5 cell with its own id), 0x6155134c
    (generic). build.py inserts ours at the first empty slot of each probe chain.
  - Bar setup 0x611d0f99: hook_bar at 0x611d1035 gives our rows their value (GetValue(item)) and ends; sl_dot keeps 0
    on the centre mark (NR: 155 px below 0, 310 above; VigFix: the two ends). Readout lookups 0x611d1697 / 0x611d1708:
    hook_rda / hook_rdb send our rows to the 11-entry -5..+5 tables. The left column's id lookup (gr_lc) gives our
    per-mode ids for the enable check.
  - Left-column icons: type-4 cells have only 1 S, 2 Contrast, 3 Saturation (others draw the S); type-5 cells draw
    Shading's icon. Noise Filter uses the S for now (no fitting icon); Shading Comp. the Shading icon.
- Lesson: `jmp 0x611c2ce8` in our code assembles as a relative jump by that amount (emulator trap at 0xc211b75a).
  Name stock addresses in editor.ld and jump to the names.
- Facade handlers reworked by class (REAL macro, LOWCNT): Sharp / Grain / NR / VigFix: count, value by index,
  selectable, set (with the NR mapping table) all checked in the emulator with Sharp -3, Grain Medium, VigFix -1,
  NR -2 / +1. GetValue of the rows' own ids (5394, 5389) is answered on COLOR 1-4 only.
- Package test 5: E1479999.BIN 8cfa7096…, GUIDES.BIN b8c1ea1a…, LABELS unchanged. Camera result: pending.

### Test 6: Noise Filter and Shading Comp. as choice rows; NR High (emulator only)
- Owner (test 5 feedback): the slider icons were confusing; Shading Comp. should be Off / On and Noise Filter a
  choice row like Film Grain, with the camera's real Noise Filter levels Off / Low / Standard / High and the grain
  icons reversed (grain High = NR Off; owner's choice after seeing that the icons' words stay the grain's).
- Rows are now choice rows built like Film Grain Effect (item 5400): item entries {id, title, labels, n, 0, icons,
  n, 0, icons 2, n}; option lists {value, 4 string | 3 icon, id, 0x6154b480}. Values are the camera's: Noise Filter
  -2 Off, -1 Low, 0 Standard, +1 High (titles 1845/1848/1846/1847 "Noise Filter Off/: Low/: Standard/: High");
  Shading Comp. 0 Off, 1 On, title stays 254, icons 358 "Off" / 480 "On" (camera icons, owner-approved).
- Film Grain's cases that ask its own id (0x611c308a) are replaced for our rows by stubs (CHC macro -> ch_id: our id
  per picture mode, then the stock case after its call: 0x611c2446 / 25a1 / 2705 / 2867 / 2d03). Left column: lc_nr
  / lc_vf = 0x611d0b57 with our id instead of 998 -> 0x611d0b72. Other switches: 5400's (generic) targets. The slider
  hooks for these rows (bar ends, readouts, Shading-type cell) are gone.
- Look NR value 4 = High (new): stills Noise Filter +1 (stock range -2..+1: the capture read sets min -2, max 1 right
  after reading key 0x9719). xb_nm gets +1; Extras wheel NR 0..4 with a new "NR High" label (LABELS.BIN n 27, all later
  first-label indexes +1). A look with NR Camera shows the camera's own Noise Filter on the row (getter 0x60063380,
  key 38681); choosing on the row writes the look.
- Control Panel (webapp, this branch only; not published): NR Camera / Off / Low / Std / High; High needs the new
  "v0.23 (test builds)" firmware choice, else it is written as Std. E-P7 packs write high as standard.
- Emulator: both rows step through their choices, titles follow, the left column shows the chosen icon, Camera shows
  the camera's Standard; Sharpness and Film Grain unchanged. Not checked in the emulator: the Extras wheel's label
  pictures (the emulator does not draw them) and photos.
- Owner: "Shading Comp." reads too close to Shading. The row is titled **Vignette Correction** (our own string): the
  camera's text table has no vignette wording, so the string getter 0x610f56a6 (`call ..,[d2],8`, d0 id -> a0 UTF-16
  string; language index 0x610f56bd, table lookup 0x610f56ac) is hooked (hook_str, 6 B) to answer our id ST_VIG
  0x7f00 with our string; every other id as stock. Emulator: the title shows; Shading Effect's own title unchanged.
- Package test 6 (with the title): E1479999.BIN f786481c…, GUIDES.BIN e19b775c… and **LABELS.BIN 903af75b… (new, must go with
  it)**.
- **Camera-tested (owner, 2026-11-08 05:05): test 6 works** (Vignette Correction Off / On, Noise Filter Off / Low /
  Standard / High, Sharpness, Film Grain). Owner: the words under the Noise Filter icons must match (the grain icons'
  words "High / Med / Low / Off" are part of the icon pictures, so Noise Filter Off reads "High").

### Test 7: Noise Filter words (emulator only)
- The camera has no Low / Std / High word icons (its Noise Filter menu list 0x6151cacc is strings only: -2 Off 1460,
  -1 Low 284, 0 Standard 264, +1 High 267). An option-list entry of type 4 (string) draws the word in the camera's font
  in the strip and the left column, like a word icon. "Standard" is clipped by the cell ("tandar"), so st_get also
  answers ST_STD 0x7f01 = "Std". Noise Filter lists: Off / Low / Std / High as words.
- Emulator: strip and left column read Off / Low / Std / High; titles follow ("Noise Filter: Low" ...).
- Package test 7: E1479999.BIN fda1c7d4…, GUIDES.BIN bb2a30f9…, LABELS.BIN 903af75b… (as test 6). On the owner's card,
  checked by checksum. **Camera-tested (owner, 2026-11-08 05:18): "perfect".**

### Test 8: Blacks and Whites rows (emulator only)
- Owner: Glow / Clarity and Art Effect (Frame) stay on the Extras wheel (they interact with Grain). Next: Blacks,
  Whites, A-B, G-M (ideally the camera's own WB A-B / G-M grid).
- Blacks (slot +47) and Whites (+48) as slider rows -5..+5 after Highlight & Shadow: items BK_IT 5386 / WH_IT 5385,
  bar ids BKB 0x7e30 / WHB 0x7e40 + k, classes 5 / 6. As test 5's slider rows (item 7's switch cases; f2c -> our stub
  to 0x611c2ce8 with our id; bar ends hook_bar / rw_bar; readouts hook_rda/b -> 11-entry tables; dot 62 px like
  Shading when max is 5) except the left column: the choice-type cell (lc_bk / lc_wh, like Film Grain's) with a word per
  value from the item's +20 list: "Bk-5".."Bk+5", "Wh-5".."Wh+5" (our strings; "Blk"/"Wht" were clipped). Titles
  "Blacks" / "Whites" (our strings, owner's choice over the camera's "Black" / "White").
- The 16-entry row switches 0x615511cc and 0x6155134c were full: build.py re-hashes them into 32-entry copies in our
  space (sw11_tab / sw13_tab) and patches their code (base 0x611d05eb / 0x611d1a59, mask 15 -> 31 at 0x611d05f1 /
  0x611d1a5f, end bound 0x611d060a / 0x611d1a74). Both switches do nothing for an unknown item.
- Emulator: Blacks 0 -> -5, Whites +5 -> +2, bar ends and dots right, left column follows; other rows unchanged.
- Package test 8: E1479999.BIN 21eb72c2…, GUIDES.BIN 6d109d75…, LABELS.BIN 903af75b… (as test 6). On the owner's card,
  checked by checksum. Camera result: see test 9.

### A-B / G-M: the camera's WB grid (research started 2026-11-08; analysis + emulator observation)
- Owner wants A-B / G-M on COLOR 1-4 as the camera's own WB fine-tune grid, not sliders ("research the grid first").
- Where it is (emulator): SCP -> WB (right of the picture mode) -> OK = GUI `SS_MENU_LV/ID_ST_DIRECT_WB`. Left column:
  WB mode, Keep Warm Color, **WB±**; on WB± the right side shows the grid (G top, M bottom, B left, A right, a dot).
- How it is built (analysis): unlike the Picture Mode column (generic item table 0x6154c2a8 + row switches), the WB
  screen is a bespoke class. Its draw code (around 0x611d1cbd..0x611d1e8x) branches on the screen object's own fields
  (+5254 row index 0 / 1 / 4, +5256, +5240 a sub-object with a vtable, +5252 still/movie) and draws with the shared
  helpers 0x611c7785 / 0x611c782f from tables 0x615513dc..0x61551490 and 0x61551c50.
- Its values: per-axis id functions pick the camera's real WB compensation id for the current WB mode and still/movie:
  0x611d27df A-B (1578 / 1579 by +5252), 0x611d2807 (1634 / 1635), 0x611d282f / 0x611d2919 / 0x611d28c7 (tables
  0x615518a8 13 entries, 0x61551910); traced GetValue ids on the screen include 1578, 1584, 1597.
- So the grid is not a row type the Picture Mode column can list (as Film Grain was). Ways to port, not yet tried:
  1. Draw a grid row ourselves in the Picture Mode column with the same helpers (most work; looks native).
  2. From an "A-B / G-M" row, open the camera's WB screen on WB±, with its A-B / G-M ids answered from the look's
     slot (+26 A-B, +27 G-M) only while opened from our row (needs the screen transition and a context flag).
  3. Two slider rows (as Blacks / Whites) as a fallback.

### Test 8 camera feedback; test 9 (emulator only)
- Owner on test 8 (camera): (1) the Blacks / Whites left-column words look bad, want stock-looking icons; (2) the
  arrows run backwards on Blacks / Whites; (3) several left-column cells highlighted at once.
- (2) Cause: a bar's value list (0x611b2180..) is built top-down only when its setting id is in the camera's table
  0x6152d6fe (322 u16 ids; 904 Sharpness is in it), else bottom-up, so the arrows flip. rv_chk (hook 0x611b21e8) also
  sets top-down for our BKB / WHB ids. Emulator: Left -> -1, -2; Right -> +1.
- (3) Cause: the Picture Mode column pages rows 5 at a time but assumes at most 2 pages (rows 0-4, then 5..n-1):
  0x611d07a4 (first row / rows shown), 0x611c3709 (cursor -> slot = cursor - 5), 0x611d0bd3.. (scroll arrows). With
  11 rows page 2 drew 6 rows into 5 slots (10 rows was fine in the emulator; test 7 had 9). pg_fix / pg_mod / pg_arw:
  pages of 5, as many as needed; the middle page shows both arrows. Emulator: 3 pages, one highlight at a time.
- (1) open: the type-4 slider cells only have icons 1 S, 2 Contrast, 3 Saturation; stock-looking Blacks / Whites
  icons need our own pictures (owner's approval first) and a way to draw them in the cell.
- Package test 9: E1479999.BIN 61288b36…, GUIDES.BIN 2467d8d3…, LABELS.BIN 903af75b…. On the owner's card, checked by
  checksum. Camera result: works except (below).

### Test 9 camera result; test 10 (emulator only)
- Owner on test 9 (camera): works well, but Blacks / Whites wrap round (+5 -> -5 and back); the stock sliders stop.
- Cause: the bar's +116 (0x611b40f0 back / 0x611b4167 on: 0 = wrap round, else stop at the ends) is set by the bar setup
  (0x611b201b..) only for the ids in the camera's table 0x6152d520 (239 u16 ids, 904 Sharpness in it). Emulator: Sharp
  bar +116 = 1, Blacks bar 0. st_chk (hook 0x611b201b) also sets 1 for our BKB / WHB ids.
- Emulator: Blacks -5 stays at -5, +5 at +5; Whites the same; Sharp still stops at -5 / +2. Noise Filter unchanged.
- Owner chose style B for the Blacks / Whites left cells (one small line, "Blk -2" / "Wht +1", like "S ±0"); needs the
  picture route (icon id -> picture descriptor lookup, not found yet).
- Package test 10: E1479999.BIN f50c1f97…, GUIDES.BIN d3e7f818…, LABELS.BIN 903af75b… (unchanged). On the owner's card,
  checked by checksum. Not flashed (owner waits for the icons, test 11).

### Test 11: Blk / Wht icons in the left column (emulator only)
- Pictures: id -> slot lookup 0x610f5611 (a0 = (0x60379740) + 4 id; the slot holds the descriptor <6H3I> 14, w, h, 8,
  0, 0, size, payload, flags). ic_get (hook) answers our ids IC_BK 0x7f80 / IC_WH 0x7f81 with our descriptors.
- The slider cell (switch 0x6155124c case 0x611d096e, items 7 / 8 / 59): cell type 4, cell +154 = item +26; draw case
  0x61178939 sets the row slot's picture object to choice +26 - 1 (0x6128abe0 / 0x610dae1e; ignored from the object's
  +131 count on). The 5 row slots' objects come from layout records 0x614557f8 + 88 n: byte +5 = count (3), then the
  choice list start / end (stock lists 0x614548b4.. of {0xffff, 7, 7, id}: S 11416, Contrast 11417, Saturation 11418).
  build.py points all 5 at ic_list (S, C, Sat, S for +26 = 4 (Shading draws its own), Blk, Wht), count 6.
- Blacks / Whites are slider cells again (item 7's case; +26 = 5 / 6), so the camera draws its own value next to our
  icon. The word cells (lc_bk / lc_wh, 22 "Bk-5".. strings) are gone.
- Icons: firmware/mkicons.py (DejaVu Sans Condensed, 46 x 46 as the S icon, cap 20 px, fill 10, soft 11 / 12, 2 px edge
  7), type-11 streams in ext11 (ic_pbk / ic_pwh, 732 / 900 B). Two emulator finds: (1) the payload must be the uncached
  address (+0x40000000; 0x6.. | 0x40000000 is a no-op), else DMA_RANGE; (2) a run must not cross a row end (engine
  BMP_TOKEN; stock streams never do). The GUIDES picture shows BMP_TOKEN in the emulator too (its runs cross rows), but
  it is camera-tested as working.
- Emulator: Blk / Wht + the camera's value on page 1, Sharpness / Contrast keep S / half-circle, Shading unchanged;
  owner-approval screenshot sent.
- Package test 11 (includes test 10's stop-at-ends): E1479999.BIN f490d866…, GUIDES.BIN 9d8865c5…, LABELS.BIN 903af75b…
  (unchanged). On the owner's card, checked by checksum. Camera-tested (owner, 2026-11-08): works, "this is perfect!".

### Test 12: A-B / G-M opens the camera's own WB grid (emulator only)
- The grid is the camera's WB fine-tune screen, GUI state 0x0408 ID_ST_MENU_FUNC_DIRECT_WB_REV (the WB screen 0x0417
  opens it on OK / dial at its WB± row: handler 0x6125bc8b returns 0x0408 when 0x6124f6c7 says 3). Screen handlers
  return the next state (parent << 8 | child) to the dispatcher 0x610f5f88 (`calls (a2)` at 0x610f6014); the GUI state
  bytes are at (8,sp) there. Picture Mode's handler: 0x6125becc; its row list = (0x6037dfa0) + 0x51a0 (+92 count,
  +94 cursor, +108 item ids u32). Events: 0x900c OK press, 0x900d release, 0x9031 / 0x9032 main dial, 0x9006 / 0x9007
  keys.
- The grid's entry (0x612590ec) picks the stills A-B id by WB mode (setting 1578 -> table 0x615d1944 {mode, A-B id,
  movie id}, 13 modes) into 0x6037dfbc and builds the screen (0x6124f4e5, kind 18); its item list (table 0x615ae434
  {key, n, list}) gives two generic bars: A-B 1580..1592 and G-M 1593..1605 (stills), read / written via the facade.
- Ours: new row GR_IT 5384 "A-B / G-M" after Whites (a one-option choice row like VigFix; the strip and left column
  show the camera's own WB± picture 12545; bar id WGB 0x7e50 + k, class 9). pm_ev (hook 0x6125becc): OK press on that
  row on COLOR 1-4 -> gr_flag = look + 1, return 0x0408. While gr_flag is set the facade answers the grid's stills
  ids from the look's slot +26 (A-B, class 7) / +27 (G-M, class 8), -7..+7, and a write sets wb_flags +25 bit0 (as the
  Extras wheel). gx_map (hook 0x610f6016): any state change out of 0x0408 clears gr_flag; MENU's 0x0417 -> 0x0418.
- Row memory: Picture Mode remembers its row in setting 2148, which refuses our row ids (5384..5394), and resets it
  to 111 on entry; we mirror our rows in gr_row (sl_set / sl_get on 2148), and after MENU from the grid the one reset
  write is skipped (gr_hold), so the cursor comes back to the A-B / G-M row.
- Emulator: OK opens the grid with the look's values (dot and "A3 . M1" header follow), dials change the slot only,
  MENU returns to the row, OK leaves to live view, hold-OK Reset zeroes the look's A-B / G-M; COLOR 2 keeps its own;
  the camera's own WB grid (from the WB screen) still changes the camera's values, not the look's. The header's WB
  name is the camera's current WB mode. Opening by dial (as the WB screen does) not done; only OK.
- Package test 12: E1479999.BIN 500f6e0d…, GUIDES.BIN 1e6aeb91…, LABELS.BIN 903af75b… (unchanged). On the owner's card,
  checked by checksum. Camera (owner, 2026-11-08): the row and its WB± icon show, but
  OK on it goes back to live view (stock behaviour), so pm_ev did not catch it on the camera although it does in the
  emulator. Not yet known why: the camera may send OK as another event, or the row / picture-mode check may differ.
- Owner's choice: the grid should show right on the Picture Mode screen when the row is selected (as Highlight &
  Shadow's curve, item 5398: its own left cell 0x611d0a9f and object in the bar switch 0x611c2d19 -> 0x611c30bc, kind 7),
  with the dials moving the dot, not on a separate screen. Next: study how the H&S curve row is built and drawn, and
  draw a grid there (the WB screen's grid helpers 0x611c7785 / 0x611c782f, tables 0x615513dc.., 0x61551c50, may help).
  The test 12 route stays in the code for now.

### On-screen WB grid research (2026-11-08; emulator + analysis, nothing for the camera yet)
- Object kind 7 (factory table 0x61502654, ctor 0x61223340) is the camera's generic 2-D control: Highlight & Shadow
  (keys 5444..5451 by picture mode, table 0x6153672c) and the WB fine-tune (keys 1580..1618) both use it. Its children
  come from table 0x615ae434 {key, n, list}: key 1580 -> bars 1580 (A-B) and 1593 (G-M). Tables 0x615aed5c (43 {key,
  2039 WB / 1153 H&S}) and 0x615ae948 (87 {key, 0x13f, 500, 100}; a 208-byte panel 0x612233de) are read by its ctor.
- Experiment (branch, not packaged): our A-B / G-M row with item 5398's cases and its row object = kind 7 on key 1580
  (gk_f): the dials change the look's A-B / G-M (facade redirect while gr_flag is set), but the picture shows the H&S
  curve: the curve is Picture Mode's own panel (+4920, a 548-byte subclass of the base screen 0x611c76db, ctor
  0x61287fb4, vtable 0x615e6258), shown by its case 0x611d04e5 (0x611d15d7: +295 = 1, show). With item 7's case there
  instead, nothing is drawn: the kind-7 object does not draw a grid by itself.
- Where grids are drawn: the WB screen (0x0417, class vtable 0x61551c6c, 5260 B, base 0x611c76db) draws its grid as
  part of its own layout: row type 2 (WB±) 0x611d257a sets +393 = 1 (grid on), +5188..5191 B/A/G/M box states,
  +5194 / +5198 A-B / G-M non-zero, dot x = 594 + 13 A-B (+80 when 0x611d2941 = 1), y = 280 - 13 G-M, and lines at
  613 + 13 A-B / 299 - 13 G-M. The fine-tune screen (0x0408) is another class (0x612900a5, 3188 B, vtable 0x615ee29c,
  base 0x611c84eb) with its own layout. Picture Mode's layout (vtable 0x615513cc) has no grid elements.
- So an on-screen grid needs drawing added to Picture Mode's screen (its layout / compose), e.g. the WB screen's grid
  elements, or our own pictures (box, letters, dot) placed by the same mechanism. Not started.
- (continued, 2026-11-08) How the camera draws the WB grid: it is a GUI scene of its own, element type 24813 (record
  0x6136d9fc, class ctor 0x61192c01, vtable 0x6148d1ac, 15 children at +792 from records 0x6148ccd4.. (box 10904,
  B/A boxes 10176/10177, G/M 10166/10167, lines, dot 10905 ...), child getter 0x61192c5d). Scene index 485 in the
  scene-by-index switch 0x61121cec (table 0x6136f59c) creates it. Its update 0x61192dc6 reads property 256, an 18-byte
  block the WB screen publishes from its +5188 (0x610cd5c4 = publish(d0 id, a0 src, d1 size, a1 flag)): bytes 0..3
  B/A/G/M box picture states (3 normal, 2 lit), byte 6 A-B line on, h8 A-B line x, byte 10 G-M line on, h12 G-M
  line y, h14 / h16 dot x / y (594 + 13 A-B, 280 - 13 G-M, +80 when 0x611d2941 = 1). Example (WB Auto, 0 / 0):
  03030303 00000000 b502 0000 2b01 a202 1801.
- Scenes live in holder elements (0x610cdf05 = load scene index d0 into holder a0; -1 empties; +768 index, +776 the
  scene). At start-up the GUI fills ~25 top-layer holders (one with 485, captured by sc_cap); every screen empties
  them (-1) when it opens and loads its own layers (Picture Mode: 497, 288, 287, 286, 285, 501, 502, 457, 456; WB
  screen: 497, 456, 498, 457; the grid comes inside the WB screen's layer 498).
- Tries (emulator, branch only): publishing property 256 from Picture Mode alone shows nothing (no grid scene there);
  loading 485 into the start-up holder from Picture Mode's update crashed; doing it while Picture Mode loads its
  layer 501 does not crash but no grid shows and the grid scene's update never runs (the scene-by-index path for 485
  is not taken there; not understood yet). Next: find how layer 498 creates its grid child, or create element 24813
  directly (0x6111caee with record 0x6136d9fc) under one of Picture Mode's layers.

### Test 13: the WB grid on the Picture Mode screen (emulator only)
- Scene indices are looked up as index - 13 in table 0x6136f59c: the WB grid (element 24813, record 0x6136d9fc) is
  scene **498** (not 485; 485 is element 24800). The WB screen loads it as one of its layers (497, 456, 498, 457).
- A layer only draws when its holder is part of the shown screen: a scene loaded into a start-up top-layer holder or
  into Picture Mode's hidden layers (287, 501, 502) gets no canvas (+0x24 = 0) and its elements stay at state +0x2c = 0
  (0x610c9ce8 draws state 1 -> 2). Picture Mode's drawn layers: 497, 288, 286, 285, 457 (the bottom bar), 456.
- Ours: sc_cap (hook 0x610cdf05) remembers the holder of Picture Mode's layer 457. On our A-B / G-M row, gr_upd (hook
  0x611d04ec, the Picture Mode update) loads scene 498 into that holder (0x610cdf05), publishes the grid block
  (property 256, gr_pub) and makes the scene re-read it (method 0x61192d6c); on any other row, or when leaving Picture
  Mode (gx_map), the holder gets 457 back. gr_is checks the holder's scene is element 24813 (scene +4).
- The row: item 5398's cases (its object = the camera's 2-D control on WB key 1580, gk_f), item 7's left cell with
  +26 = 7 (the camera's WB± picture 12545 in ic_list) and item 7's main-area case (no curve). A dial change writes the
  look's slot +26 / +27 (facade redirect while gr_flag), then gr_pub / gr_ref move the dot and lines.
- Emulator: grid with the look's values (dot and lines move with the dials), Shading's bar back on the next row, COLOR 2
  its own values, the camera's own WB screen unchanged afterwards. No value text (the fine-tune screen's "A3 . G2"
  header is not part of this scene).
- Package test 13: E1479999.BIN e0efd67c…, GUIDES.BIN 83f72a22…, LABELS.BIN 903af75b… (unchanged). Card not connected
  at packaging; copied later and checked by checksum. Camera (owner, 2026-11-08): not what they wanted; the grid route
  is dropped for two sliders (test 14). The grid findings stay here for later.

### Test 14: A-B and G-M as two slider rows (emulator only)
- Owner: drop the grid, use two sliders. Firmware code back to test 11 (camera-tested), then two rows after Whites
  built exactly like Blacks / Whites: items AB_IT 5384 "A-B", GM_IT 5383 "G-M" (our strings), bar ids ABB 0x7e50 /
  GMB 0x7e60 + k, classes 7 / 8, the look's slot +26 / +27, -7..+7 (count 15). A write also sets wb_flags +25 bit0
  and clears bit7, as the Extras wheel does. Bars: rw_bar ends -7 / +7, sl_dot 44 px a step, top-down (rv_chk) and
  stop at the ends (st_chk). Readout: our 15-entry sign / digit tables rd15_a / rd15_b fed to the stock search loops
  (0x611d16ee / 0x611d175f). Left column: item 7's slider cell with +26 = 7 / 8 and our icons "A-B" / "G-M"
  (firmware/mkicons.py; IC_AB 0x7f82 / IC_GM 0x7f83; ic_list now 8 choices).
- Emulator: A-B +3, stops at -7 (minus greys out), G-M -2, Shading's bar on the next row; slot values and wb flag set.
- Package test 14: E1479999.BIN 61fdfcb7…, GUIDES.BIN 8d56b7e9…, LABELS.BIN 903af75b… (unchanged). On the owner's card,
  checked by checksum. Camera (owner, 2026-11-08): works ("this is truly amazing") -> A-B / G-M rows camera-tested.

### Test 15: side-bar titles, row order, a smaller Extras wheel (emulator only)
- Owner asks: (1) the side bar showed only "Off" / "On" / "Std" for Noise Filter and Vignette Correction: give them a
  short title; (2) a better row order; (3) take NR, A-B, G-M, Blacks, Whites, VigFix, Grain and Sharp off the Extras
  wheel (they are Picture Mode rows now): Glow/Clarity at 12 o'clock, Art Effect at 6 o'clock. Owner is thinking of
  dropping Glow/Art until they run faster with grain (undecided).
- (1) firmware/mkicons.py now draws 10 pictures: the four 46 x 46 slider icons and six 100 x 76 two-line pictures
  ("Vignette" over Off / On, "Noise" over Off / Low / Std / High), our ids IC_BK 0x7f80 .. 0x7f89. ic_get answers the
  range from a table ic_ent; descriptors ic_d0..9 (build.py fills w, h, size, payload), streams packed into ic_pay
  (16 KiB, 14128 B used). Finding: in a choice row's item entry the FIRST icon list (nr_l1 / vf_l1) is the left column
  and the SECOND (nr_l2 / vf_l2) is the strip under the title (the old comments had them the other way round; both
  lists held the same words, so it never showed). Strip keeps the camera's words / Off-On icons.
- (2) pm_list: Picture Mode, Color (wheel), Contrast, Highlight & Shadow, Blacks, Whites, A-B, G-M, Sharpness, Noise
  Filter, Vignette Correction, Shading, Film Grain (look -> tone -> white balance -> detail -> lens -> finish).
- (3) xt_tab / xb_vt: sector 0 (12 o'clock) Glow/Clarity +49, sector 6 (6 o'clock) Art +50, all others slot byte 0
  (no cell). xb_vl: slot byte 0 -> the stock readout picture. LABELS.BIN unchanged (label numbers kept).
- Emulator: rows in the new order; side bar "Noise / Std", "Vignette / On"/"Off" follow the value; strips unchanged.
  Wheel (sub dial = slice, main = value): 12 o'clock main+2 -> +49 = 2; the other sectors refuse; 6 o'clock -> +50
  steps; "Color All" (stock all-cells mode) steps both. The emulator does not draw the wheel itself.
- Package test 15: E1479999.BIN 77f0aea2…, GUIDES.BIN dc6ad9a9…, LABELS.BIN 903af75b… (unchanged). On the owner's card,
  checked by checksum. Camera result: pending. docs/USING.md (main) still describes the old wheel: update at release.

## v0.24 film list (2026-11-08; branch feature/v0.24-film-list)
- Owner: the Picture Mode list should show COLOR 1-4 and then every film (look) on the card; a film's tweaks are saved
  into that film. (Caduceus for the E-P7 does not add entries: it shows the chosen look's name in place of COLOR n.)
- How the list is made (emulator traces + disassembly): on the COLOR position the Picture Mode row (item 111) shows the
  value list of setting **901** (the COLOR picture mode). Table 0x6152f8a0 = {setting, count, records} x 6: 111 (40),
  898 (8), 899 (31), 900 (1), 988 (MONO 1-4), 901 (COLOR 1-4: 4 records at 0x6152f850). Record 20 B {value, id, value,
  0, func}: the builder 0x611b3250.. keeps a value when func(value) (+16) or else GetValue(id) (+4, 1072..1075 for
  COLOR 1-4) is non-zero, then asks facade selectable(901, value) (sl_sel); the current value is GetValue(901) from
  0x611b32ae; the left column reads GetValue(901) from 0x611d1869. Choosing calls SetValue(901, value) (our sl_set).
  GetValue(111) (the picture mode everywhere else: 0x610fd979 often, the column builder 0x611bd835, ...) is never
  touched. Pictures / strings per value come from item 111's three option lists (it_tab entry 0: title, left column,
  strip; 48 x 12 B each).
- Test 1 (emulator only): build.py points 901 at fl_rec (the stock four + 20 records {FV0 + j, FLB + j, FV0 + j, 0, 0},
  FV0 = 100) and item 111's lists at fl_l0..2 (the stock 48 + 20 type-4 strings ST_F0 + j). fl_get: GetValue(FLB + j)
  = film j there (a name, or any non-zero record byte); GetValue(901) from the two GUI callers = FV0 + 5k + n - 1 when
  COLOR k has look n and that film is there. fl_sel: selectable = film there. fl_set: a film -> COLOR k = j / 5 gets
  look n = j % 5 + 1 (pf_put, as the Film page), then the manager sets 901 = COLOR k; COLOR k itself -> look 0. fl_str:
  the name as UTF-16 in a buffer after the LOOKS.BIN copy (pf_load mallocs PF_LEN + 680), unnamed -> "Look n".
- Emulator: the strip reads COLOR 1-4, then the films by name; right / left switch COLOR and look (LIDX follows, e.g.
  3,3,0,1); the title shows the full name; reopening after a half-press highlights the film; the saved selection is
  written to LOOKS.BIN. Strip cells are narrow: names longer than ~5 letters are cut ("SoftOff" -> "oftOf"). The SCP
  and live view still say COLOR n.
- Known in test 1: choosing COLOR n itself sets its look to 0 (the factory settings, as the Film page's 0), and a film
  keeps its tweaks only when saved with OK held on the Film page (v0.21 behaviour). Both are for test 2 (owner: tweaks
  go into the film; COLOR 1-4 should keep their own settings).
- Package film test 1: E1479999.BIN 2006939f…, GUIDES.BIN 914f5642…, LABELS.BIN 903af75b… (includes v0.23 test 15).
  Card not connected at packaging; copied later and checked by checksum. Camera (owner, 2026-11-08): "it works" ->
  the film list is camera-tested (films by name, switching, title).
- Film test 2 (emulator only): owner: cells "FILM 1, 2, ..." in the same style and size as COLOR 1-4 ("it should look
  seamless"), the film's name as the big title. The camera's list font is too big: "Film 12" on one line is cut and
  "FILM" + line break spills out of the cell (a line break, 10, does work in type-4 strings). So pictures: measured the
  stock COLOR cells (strip 100 x 76: "COLOR" fill rows 16..36, x 13..85, 2 px edge, stems ~3 px; digits rows 43..68,
  9..16 px wide; left column 82 x 62) and matched our font to them (firmware/mkicons.py: "FILM" cap 20, baseline 36,
  0.88 width, thresholds 0.2 / 0.4 / 0.6; digits cap 26, baseline 69, 0.95 width). 20 finished pictures would be
  ~30 KB of firmware, so the camera draws them: fl_mk (called by pf_load after the films load, HLS task) composes each
  row from fl_top (the "FILM" line, 2000 B, 4 bits a pixel) or the digit pictures fl_dig (10 x 360 B; one digit at x 40,
  two at x 31 / 49, a digit pixel replacing clear or edge only) and encodes runs as type-11 tokens (fl_emit) into up to
  3 heap blocks of 14 KB; block 0 holds 20 slot words + 20 descriptors; P+TTAB (816, unused before) = the slot words.
  The strip list's film entries are type 3 IC_FM0 + j (0x7f90..); ic_get -> fl_ic counts the films before j for the
  number. Bug found in the emulator: fl_ic called fl_has, which overwrote mdr, and ic_get returns with retf (through
  mdr) -> crash; fl_ic now saves and restores mdr. Emulator: all 20 pictures byte-identical to mkicons.film_cell(n)
  (memory dump), the strip reads COLOR 1-4, FILM 1 .. FILM 13 with the names as titles. The left column still shows
  COLOR n (it does not use these lists). ext11 31.9 KB of 64 KB.
- Package film test 2: E1479999.BIN 8657819e…, GUIDES.BIN 8b742cfb…, LABELS.BIN 903af75b…. On the owner's card,
  checked by checksum. Owner (2026-11-08): "this looks great" (look approved).
- Film test 3 (emulator only): owner: (1) the quick menu (Super Control Panel) should show the film, (2) changes to a
  film are kept, not reset.
  - Quick menu: its picture-mode cell is a picture, 160 x 48, ids 15746..15749 = "COLOR 1..4", 15750..15753 = with
    "*" (choice records {76, 76, id, 0xffff} at 0x61408260..); its text style: no dark edge, fill 13, soft 14 / 15 / 7,
    ink rows 7..40, stems ~5 px, letters ~2 px apart. Its title "Color Profile k" = strings 2755 / 2756 / 2757 / 4769
    (the only string asked when it opens). ic_get -> fl_scp: when COLOR k holds a film that is there, "FILM N" (N its
    list number) drawn by fl_sp into a heap block (P+TORG, allocated by fl_mk: 4 slot words, 4 descriptors, 4 drawn
    numbers, 4 pictures) and redrawn only when N changes; st_get -> fl_tt: those titles -> the film's name. Parts from
    firmware/mkicons.py sp_parts (each letter drawn on its own, cap 32, 0.75 width, 0.6 px blur, 2 px apart, 6 px
    before the number; the "*" picture shows the same "FILM N"). Emulator: the cell reads FILM 1, the title the
    film's name; the picture is byte-identical to mkicons.sp_film(1) (memory dump).
  - Keeping changes: leaving a film (choosing another film or COLOR n in the list, or turning the Film page) now saves
    COLOR k into the film first: fl_sw (in place of pf_put's call in s_look and fl_set) = pf_cap(k, old look) + dirty,
    then pf_put. pf_cap takes everything (wheels, Extras, WB shift, Blacks / Whites, the 18 camera settings). Holding
    OK on "COLOR n" still resets it and sets its look to 0 (nothing saved over the film). Emulator: FILM 1 Contrast
    +1 -> +2, FILM 2, back to FILM 1: +2; after a half-press LOOKS.BIN record 0 +41 = 2.
  - ext11 38.6 KB of 64 KB.
- Package film test 3: E1479999.BIN 590db381…, GUIDES.BIN 7830515b…, LABELS.BIN 903af75b…. On the owner's card,
  checked by checksum. Not flashed (owner asked for test 4 first).
- Film test 4 (emulator only): owner: COLOR 1-4 keep what you adjust; OK held resets COLOR 1-4 and FILM 1-20 to their
  defaults.
  - Changes are kept apart from the films as built: new card file EDITS.BIN (docs/FORMATS.md), written by the camera
    at the half-press save when changed (fl_save in place of pf_save's call in ed_trig), read when the films load (fl_mk;
    bad size / magic / CRC -> nothing valid). Record r = film j (0..19) or COLOR k's own settings (20 + k), LOOKS.BIN
    record format (pf_capto / pf_put), + a check (films: CRC-32 of the LOOKS.BIN record it came from, so a film
    rebuilt in the Control Panel drops its old changes). LOOKS.BIN is no longer changed by switching (only by the
    Film page's OK-held save, which makes that the film's new default, and the selection bytes).
  - fl_sw (every look switch, list or Film page): COLOR k leaving look 0 -> its own settings saved (r = 20 + k);
    leaving film j -> its changes saved (r = j); then the new one loads from its record when valid (pf_put1: pf_put
    from any record), else as built (pf_put; look 0 without own settings = factory).
  - OK held with a film selected: the camera sends the reset to the rows listed for the selected picture mode
    (table 0x61536324, 8 entries {mode, count, rows}: MONO / COLOR 1-4; read at 0x611c3c07, bound `cmp 8` at
    0x611c3cae); a film value had no entry, so nothing happened and the OK release left the screen. build.py points it
    at fl_rtab (the stock 8 + 20 films with one row, 5397, the wheel: the stock rows 7 / 8 / 5398 / 5399 would put
    their settings to factory after the film loads). xb_lkh (0xf881) with COLOR k on film j: j's changes dropped,
    the next capture skipped, look 0, then facade SetValue(901, FV0 + j) -> fl_set / fl_sw load the film as built.
    OK held on COLOR n itself: the stock factory reset, as before.
  - Bug found: 0x611d1869 (made to read the film value in test 1) is the "COLOR k changed?" check behind the Reset
    guide and the held-OK reset, not the left column; it reads COLOR k again.
  - Emulator: COLOR 1 Contrast +2 -> FILM 1 (+1 as built) -> back to COLOR 1: +2; FILM 1 to +2, FILM 2, back: +2; OK
    held on FILM 1: +1, stays on FILM 1, its record equal to LOOKS.BIN's; COLOR 1 still +2 after. OK held on COLOR 1
    (+2): 0, '*' gone, still 0 after a film. EDITS.BIN written (CRC ok), LOOKS.BIN records unchanged.
  - Owner's card: LOOKS.BIN / BUNDLES.BIN equal their .NEW copies (saving healthy; the older FAT dates are cosmetic).
- Package film test 4: E1479999.BIN 8408e7a8…, GUIDES.BIN 11962fd4…, LABELS.BIN 903af75b…. On the owner's card,
  checked by checksum. Camera (owner, 2026-11-08): "nearly perfect" -> COLOR 1-4 / film keeping and the held-OK
  resets camera-tested; one quirk: after adjusting a film the title read "Picture Mode" (owner photo: FILM 6, Blk -1).
- Film test 5 (emulator only): the title on the Picture Mode row is the item's own title, string 203 "Picture Mode",
  whenever the row is reached with up / down (stock behaviour for COLOR n as well); the selection's title (l0) shows
  only when the value is changed. st_get -> fl_pm: string 203 while the GUI state is 0x0418 (Picture Mode screen; the
  state is the two bytes at the pointer 0x603713a4 on the OM-3 = E-P7's 0x60368b88, from om-emu src/fw/ports.mjs)
  and COLOR k is selected -> fl_tt with "Color Profile k" (the film's name when it holds one). Emulator: after an edit
  and up to the row: "Color Profile 1" on COLOR 1, "SoftOff" on FILM 1; the quick menu still FILM 1 / SoftOff.
- Package film test 5: E1479999.BIN 0c3a0925…, GUIDES.BIN 7d301e73…, LABELS.BIN 903af75b…. On the owner's card,
  checked by checksum. Camera (owner, 2026-11-08, photos): the title keeps the film's name ("Classic Chrome") ->
  camera-tested. Two issues: (1) the row's left cell still reads COLOR 1 on a film; (2) the '*' were wrong: after
  cycling through the films COLOR 2-4 had '*' (they held films), and films showed '*' too.
- Film test 6 (emulator only):
  - Pictures per COLOR / MONO profile: 82 x 62 (unused here), 100 x 76 cell, 100 x 76 cell with '*' (14519..14530
    COLOR, 14507..14518 MONO). The star: the cell builder (0x611d0e2a) asks "COLOR changed?" (0x6129ba07) for a
    COLOR value and swaps in the '*' picture (table 0x61550fc0 {value, id}); any other value draws as listed.
  - Left cell: GetValue(111) returning to 0x611d08f4 (the left column's generic cell) -> the film value (fl_get), and
    item 111's left-column list has the film cell pictures (IC_FM0 + j); the cell draws "FILM n" (+ a '*' mark when
    the film is changed, see below).
  - '*' rules: COLOR n = its own settings differ from the factory; a film = it differs from how it was built.
    .hook_pmod -> fl_pmod: COLOR k holding a film -> for the cell (any caller but 0x611d1837): its own settings' flag
    (EDITS.BIN record 20 + k byte +63, set by fl_sw from ed_pmod when they are saved); for the row's own check
    (0x611d182f, return 0x611d1837: the row '*' and the Reset guide): the film changed? (its 18 settings via fl_isdef
    and the slot's pf_bt bytes against LOOKS.BIN record j). The seven "is at default" sites (ISDEF_SITES) -> fl_isdef:
    one of COLOR k's 18 settings (pf_ids) while COLOR k holds a film -> default when equal to the film as built
    (Saturation sectors: Hue and Light too); else ed_isdef.
  - Emulator: FILM 14 as built: no '*'; Contrast +1 -> +2: "+2*", left cell FILM* 14, Reset guide; OK held: all
    clear; after cycling all films COLOR 2-4 have no '*', COLOR 1* (changed itself) keeps it. (The row's return address
    was first taken as 0x611d1835: the call is 7 bytes.)
- Package film test 6: E1479999.BIN f70024c2…, GUIDES.BIN 3e240b4b…, LABELS.BIN 903af75b…. On the owner's card,
  checked by checksum. Camera (owner, 2026-11-08): "so so close": FILM n in the left cell works; two asks: the
  numbers a little smaller; a changed film shows no '*' in the list.
- Film test 7 (emulator only), with three more owner asks:
  - Digits: cap 24, baseline 68, 0.92 width (box 18 px; firmware constants FDB / FDS / FX1 / FX2 / FX2B from build.py).
  - "FILM*": a second "FILM" line with our font's asterisk over its top-right corner (as the stock "COLOR*": star
    rows ~4..21, just past the word's end). fl_mk draws 40 pictures (20 plain + 20 starred; slot / descriptor 20 + n - 1;
    up to 6 heap blocks of 14 KB; if they run out, the plain ones are used). fl_ic: a list cell (IC_FM0 + j) of a
    changed film (fl_fch) gets the starred picture; the row's left cell uses IC_FL0 + j, never starred (the row adds
    its own '*'). fl_fch: film on its COLOR now -> fl_live (the row check, moved out of fl_pmod); else its saved
    changes (EDITS.BIN, valid) differ from the LOOKS.BIN record in bytes 0..52.
  - Wheel pages (owner: "Color, Color all, Hue, Light"; keep the code): W_FILM / W_EXTRAS 0 in editor.s -> INFO goes
    Saturation -> (All) -> Hue -> Light -> Saturation; the wheel opens on Saturation. Glow / Clarity and Art Effect read
    0 where they act (XB_FX 0 in xblock.s: capture, live view, Soft Focus weight, Art Effect flags); the slot and
    LOOKS.BIN bytes are kept. 1 brings either back.
  - "HSL" in place of the Color row's "Color / Vivid" cell (82 x 62, list at 0x6154be9c id 11389 -> IC_HSL 0x7f8a;
    mkicons PICTURES[10], cap 26, the FILM cells' weight).
  - Emulator: FILM* 2 in the list after a Contrast change and after switching away and back; HSL; INFO axis 0 -> 0 (All)
    -> 2 -> 1 -> 0; the earlier star / reset / quick-menu checks unchanged.
- Package film test 7: E1479999.BIN 9c8cdf20…, GUIDES.BIN 14c04fff…, LABELS.BIN 903af75b…. On the owner's card,
  checked by checksum. Camera (owner, 2026-11-08), three asks: (1) the '*' still wrong ("not always showing right, or
  showing even after resetting"; photo: FILM 6, "Blk -1*" but no '*' on the film); (2) the number under FILM in the
  row's left cell is cut off ("6"); (3) rename Color All to Saturation and hide the single-colour page.
- Film test 8 (emulator only):
  - (1) Cause found and reproduced in the emulator (old build, a film built with Blacks -1: "Blk -1*", film without
    '*'): our own rows (Grain, NR, VigFix, Blacks, Whites, A-B, G-M; ids GRB..GMB + k) asked "is at default" through
    0x611d1ac3 -> fl_isdef -> ed_isdef, i.e. against the factory 0, not the film. fl_isdef now compares those rows'
    slot bytes with the LOOKS.BIN record (fl_xr, the pf_bt pairs) while COLOR k holds a film. Emulator: film built
    Blk -1 -> "Blk -1" (no '*'), -2 -> "Blk -2*" + FILM* , OK held -> "Blk -1", no '*' anywhere.
  - (2) The left cell is the camera's small 82 x 62 cell; it took the 100 x 76 list picture and cut its bottom. Now
    its own picture (mkicons film_lcell: FILM cap 20 baseline 26, digits cap 22 baseline 55). The cell drawing is one
    renderer (fl_rc) with three layouts (fl_L0 list, fl_L1 "FILM*", fl_L2 left cell): fl_mk draws the 20 plain list
    cells at load (TTAB); "FILM*" and left cells are drawn on demand into an 8-slot cache (fl_cget, P+STC 824, 16 KB;
    8 >= cells on screen at once). Emulator dump: all 20 plain cells, the cached FILM* and left cells byte-identical
    to mkicons.
  - (3) W_SALL 1: Saturation always shows all colours. INFO: Saturation (all) -> Hue -> Light -> Saturation (all)
    (k_sall: after Light the stock INFO handler turns all colours on); left / right (editor records +20 / +24, events
    0x9008 / 0x900a) do nothing there (ed_l / ed_r), so the single-colour page can't be reached; after OK held on
    Saturation all colours come back (e_sall). The wheel's "Color" label (descriptor 0xa4cf61f8, 70 x 30) and the
    "Color Select [INFO]" guide (0xa49edf88, 180 x 50) show our "Saturation" pictures on Saturation and the camera's
    elsewhere (gd_sel from gd_set; ed_trig passes -1 at the half-press: the camera's own again). Pictures built by
    card/mklabels.py / card/mkguides.py (mkicons.sat_pictures), copied into the heap by fl_mk (P+SATB 828). The
    rear-dial label stays the camera's "Vivid All". Not tried: setting all colours before the stock init (the opening
    INFO then stepped on to Hue in the emulator); the front dial on Saturation (the emulator has no dial key; if it
    still leaves all colours, it goes through another record).
  - Package film test 8: E1479999.BIN 4cef0e81…, GUIDES.BIN 015d526f…, LABELS.BIN 903af75b… (unchanged). On the
    owner's card, checked by checksum. Camera (owner, 2026-11-08): the film numbers look good; two asks: (1) holding OK
    on a film jumps the list to the COLOR cells and the highlighted film is off screen; (2) the shooting screen still
    shows "COLOR n", not the film.
- Film test 9 (emulator only):
  - (1) The held-OK reset (0x611c3b..) ends by putting the row's cursor place on screen (row +88) = the list index
    (fine for the camera's 4 COLOR cells); with 24 cells the strip then started at COLOR 1 with FILM 6 off screen
    (row +86 the index, +88 its place; found by a memory diff and a write watch: 0x611c3cba). .hook_rsp 0x611c3cb5 ->
    rs_pos: the place is kept when it is not past the index. Emulator: FILM 6 and FILM 2 reset in place, the arrows
    move on from there.
  - Also: OK held on the wheel of a COLOR holding a film reset the slot to the factory (Blacks 0), so a film built
    with Blk -1 showed "Blk ±0*" after its reset. xb_lkh: the wheel reset (0x903e) on a film = the film as built (as
    OK held on FILM n), then the wheel's values re-read (e_lk) and all colours on Saturation (e_sall). Emulator:
    "Blk -1", no '*'.
  - (2) The shooting screen's picture-mode name is a picture, 15706..15709 "COLOR1".."COLOR4" (96 x 44; found by
    tracing the picture lookup in live view). fl_lvp (ic_get) -> "FILM N" for a COLOR holding a film, drawn by fl_sp
    (now one renderer with layouts: fl_LS the quick menu's 160 x 48, fl_LVL this one; mkicons lv_parts / lv_film, the
    label style, cap 24 baseline 33) into a 4-picture block (P+LVB 832, LV_SLOT 2800). Emulator dump: the live-view
    "FILM11" and the quick menu's byte-identical to mkicons.
  - Found while doing this: `jmp 0x604be2aa` (g_sf's fallback without the code block) assembled as a relative jump to a
    wrong address (the same happened to a first `jmp 0x6122471c`); bare numbers in jmp / call are linker symbols now
    (sf_stock, stock_left, stock_right, rsp_back). Never taken so far (the code block is always loaded).
  - Not verified: in the emulator the up arrow on the wheel's Saturation page (all colours) still shows one colour
    (it goes through the Picture Mode screen, not the editor's records). The front dial: no emulator key.
  - Package film test 9: E1479999.BIN d44c4c76…, GUIDES.BIN b05673ac…, LABELS.BIN 903af75b…. On the owner's card,
    checked by checksum. Camera result: pending.
- Film test 10 (emulator only), owner: "the HSL wheels in HSL order, Light renamed Luminance: hue, saturation,
  luminance". W_HSL 1 in editor.s:
  - INFO: Hue -> Saturation (all colours) -> Luminance -> Hue (k_step; the old order under W_HSL 0).
  - Opens on Hue: in the emulator the INFO that opens the wheel reaches ed_info right after the init (that is why the
    wheel used to open on "all colours"). ei_page now calls ei_open (P+EOPEN 689 = 1, then gd_set); k_open, at
    ed_info's ALL check, sends that first INFO to Hue (all colours off first when on).
  - The dial label: "Hue" / "Saturation" / "Luminance" in place of the camera's "Color" on the three pages (gd_sel;
    mkicons hsl_labels, the SATB block now Saturation label, guide, Hue label, Luminance label). The guide: "Luminance
    [INFO]" (card/mkguides.py PAGES). GUIDES.BIN would pass the loader's 16 KB (16844 B), so the hidden Film page's
    guide stream is left out (length 0; mkguides SKIP): 14144 B.
  - Emulator: opens on Hue, then Saturation All, Luminance, Hue; arrows move the colour on Hue.
  - Package film test 10: E1479999.BIN 91bd1746…, GUIDES.BIN da1303db…, LABELS.BIN 903af75b…. On the owner's card,
    checked by checksum. Camera result: pending.
- OPEN (owner, 2026-11-08, camera): a COLOR still with Shading on comes out monochrome. The stock OM-3 keeps Shading
  colour (Color Profile Control lists Shading), so it is ours. Analysis only (the emulator cannot capture):
  - Not the Art Effect converter hook: Shading reaches it as a nonzero Art Effect id (stock ids 8 / 9 "Shade",
    flags 0x800 / 0x1000), and xb_cap sends any nonzero id straight to the stock code (fx_back). Not the camera grain
    route either: xb_gt is cleared at every capture and set only with no Art Effect.
  - Suspect: hl_pp (hook_color 0x60518615) writes Hue / Light into output records at (12,a2)+854 whenever the
    effective COLOR slot has its H/L bit, whatever the job; if Shading builds the job differently, those writes may
    land on other fields. Also possible: tone (Blacks / Whites LUT) and wb_get, both slot-dependent.
  - Asked the owner for two shots: a factory COLOR with only Shading, and a film with Shading. Colour + mono -> the
    slot-dependent hooks (start with hl_pp); both mono -> a logging build.
  - Owner found it (camera): mono only with Shading AND Grain; Shading alone stays colour. So the camera grain route
    (xb_gt -> xb_dev: request key 11 -> 12, the MONO pipeline) plus the camera's Shading = monochrome.
- Film test 11 (emulator only; capture not emulated):
  - Grain: xb_cap's plain-COLOR path reads the COLOR's Shading (setting 912 + k, stock getter 0x603f039d = AGET) and,
    when it is not 0, takes the CPU grain route (Soft Focus passes, flag 0x80) as with an Art Effect (camera-tested
    with effects in gt3) instead of the camera's MONO grain route. Camera check pending: Shading + Grain in colour.
  - Wheel (owner): the Saturation page should adjust one colour at a time, not all at once. Film test 8 had it the
    wrong way round: the owner's "hide the color select wheel" meant the all-colours page, whose guide reads "Color
    Select [INFO]". W_SONE 1: Saturation shows one colour; INFO from it goes on to Luminance (no all-colours step);
    entering it turns all colours off when on (k_sall); the reset leaves one colour (e_sall off). Its guide: our
    "Saturation [INFO]" in the camera's "Color All [INFO]" descriptor (gd_set's stock path -> gd_s0; gd_sel puts the
    camera's back first so gd_set accepts the descriptor); the all-colours guide swap is off. The Saturation guide is
    now 175 x 50 (mkicons sat_pictures).
  - Emulator: Hue -> Saturation (one colour, "Saturation ■", "Saturation INFO") -> right stays one colour ->
    Luminance -> Hue -> Saturation; OK held on Saturation stays one colour.
  - Package film test 11: E1479999.BIN 04ad3e83…, GUIDES.BIN 45d40212…, LABELS.BIN 903af75b…. On the owner's card,
    checked by checksum. Camera result: pending.
- Film test 11/10 camera (owner, 2026-11-08): the wheel went "sat, hue, sat, lum" and acted oddly. Owner: work with the
  firmware, not against it; the camera's own order. Film test 12 (emulator only): W_SALL / W_SONE / W_HSL 0 -> the
  stock order Color (one colour) -> Color All -> Hue -> Luminance, the camera's own labels and guides, our "Luminance
  [INFO]" guide (renamed from Light) on that page. The film-test 8/10/11 wheel code stays, switched off. The Grain +
  Shading CPU-route fix of film test 11 stays. Emulator: opens on Color All (the opening INFO, as before), then Hue,
  Luminance, Color, Color All, Hue.
- Fast-grain review (2026-11-08, analysis; owner: "as quick as default with every feature"). Read: this notebook's
  grain sections (g1..gt4, gl1..gl10, gw1), branch experiment/grain-cpu-colour, cakelesscoder/caduceus-ep7
  docs/GRAIN_PORT.md (incl. their ports of our fast and CPU routes, both no grain on the E-P7 camera, 2026-11-07),
  BLOOM_HALATION.md, MONO_COLOUR.md, OM3_NOTES.md; firmware work-list table 0x606c957c.
  - CPU grain cannot reach "no added time": it is memory-bound (gd4: 0.63 ms/row cached, 2.9 s whole image). Every
    listed speed-up (noise tile ~40 % of the loop, more rows per flush ~0.15-0.3 s, a second CPU ~half) leaves >= ~1 s.
    So only the image processor can do it.
  - Shading: dev effect 0x0c00 = combiner 33; with request key 12 its MONO set-up greys the picture (owner camera
    test). gl6 G1/G2 (combiner 33 handler run with context key 11 on a key-12 request) = colour + full grain,
    camera-tested. -> lead 1, high confidence, no added time.
  - Art / Glow / Clarity: the dev pass writes 0x0c02 to memory and a kind-3 0xf005 pass converts to 0x1c02; grain is
    only seen on a dev pass with direct 0x1c02 output (gl9). gl10 (key 12 + level on that conversion pass) was built
    but never measured, and its level offset (+1079) was a guess (kind-3 layout differs from kind 0: +1731 -> +1091,
    +1756 effect -> +1084). -> lead 2: log the conversion pass first, then retry.
  - The stock grain passes still exist: the MONO work-list handler 0x604b908d sends every MONO still to the default list
    (its grain-pass branches are dead: both arms jmp 0x604b917f), but Art key 0x01010071's handler 0x604b90ca still
    appends pass 0x604bbbd0 (the old combiner-grain pass, E-P7 stage 0x0901 style) when job+5356 != 0. If 0x01010071 is
    the camera's Grainy Film, that hardware pass could follow Glow / Art. Risks: the E-P7's mask route forces mono and
    its combiner-32 tests on colour showed nothing. -> lead 3, research.
  - Owner (2026-11-08, camera): the OM-3 has the Grainy Film Art Filter; it saves very quickly, also with Art Effects
    added on top, and keeps its grain. So the camera has a fast image-processor grain that survives the extra effect
    passes -> lead 3 moves up: find Grainy Film's work list (which art key; candidates with grain passes: 0x01010071
    handler 0x604b90ca -> passes 0x604bba9d / 0x604bbbd0 when job+5356 == 0) and whether its grain is colour-safe.
  - fg1 logging build (branch experiment/fast-grain-log; GUIDES.BIN only, firmware = v0.24 80570ac6…): the gl2d/gl8
    logger back in the code block. xb_cap marks each capture (slot = mark & 3; capture key, flags, capture bytes),
    xb_dev's selector call (s_cl, every request) goes through xb_lg (records: combiner, kind, stage, type, effect,
    context key, request key, CPU, 12 B at +1744 / +1086; copies A first kind-0 stage 0, B first stage 0x09xx, C first
    kind-3 stage 0), xb_lw (block +72 after the half-press save) allocates 4 x 7168 B at the first save and writes
    OM3MOD/GLOG.BIN when something new was logged. GUIDES.BIN 15004 B. Emulator: boots, live-view requests pass xb_lg,
    menus fine; the half-press save does not run in today's emulator sessions (v0.24 baseline neither), so the log
    write is checked by review only (same design as the camera-proven gl8 logger). Shots asked: COLOR + Grain High,
    Grainy Film, Grainy Film + an Art Effect, Grainy Film + another Art Effect.
  - E-P7 ideas not yet tried here: stock additive combiner (E-P7 136, A + B gains 1.0) with a noise layer; needs a
    full-size noise buffer (CPU-filled: same memory cost) -> not "as quick as default".
- NEXT (owner, 2026-11-08): grain as fast as the camera's MONO grain AND with Art Effects, Glow, Clarity and Shading.
  Plan (analysis): project doc claude/fast-grain-plan.md. Order: (1) Shading: run combiner 33 as COLOR (context key 11)
  on our key-12 stills (gl6 G1/G2 gave colour + full grain); (2) Art / Glow / Clarity: grain on the kind-3 0xf005
  conversion pass (gl10, never measured), logging build if needed; (3) fallback: faster CPU grain (gs1).


## v0.24 withdrawn, v0.24.1 (2026-11-08; camera-tested; branch hotfix/v0.24.1)

- v0.24 (firmware 80570ac6…, GUIDES 4b483bb9…) on the owner's camera: a photo with Film Grain High rebooted the
  camera. fg1 log (branch experiment/fast-grain-log, details there): the capture was marked COLOR, but no development
  request followed. Cause (analysis, confirmed by the fix): film test 11's Shading check in `xb_cap` calls the settings
  getter AGET 0x603f039d during the capture. Fix: `XB_SHG 0` in `firmware/src/xblock.s` (the check left out: v0.22's
  grain route). GUIDES-only hotfix 4b3bac02… with v0.24 firmware: camera-tested, High no longer reboots.
- Without that check, Shading + Grain is mono again (combiner 33 MONO set-up). v0.24.1 hides the Shading row
  (`pm_list` without 5399). Emulator: Picture Mode rows end Noise → Vignette → Grain, no crash. Camera-tested (owner,
  2026-11-08: "it is working"). Firmware 6fbc80b8…, GUIDES 112e8f93… (7 bytes differ from 4b3bac02: addresses after
  `pm_list`), LABELS 903af75b….
- A Shading value already set on a COLOR, or loaded from a film's record +43, still applies (hidden). The Control
  Panel's "v0.24.1 or later" export writes +43 = 0; the release notes ask owners to set Shading 0 before flashing.
- `releases/v0.24` removed: the release workflow publishes every folder without a GitHub release, so keeping it would
  re-create the deleted v0.24 release.
- fg2 (2026-11-08; emulator only so far): the fg1b logger rebuilt on v0.24.1 (branch experiment/fast-grain-log, merge
  of hotfix/v0.24.1). Firmware identical to v0.24.1 (6fbc80b8…), so GUIDES.BIN only: 457043250ec7…, 14948 B.
  Emulator: boots, Picture Mode rows and the HSL wheel open, half-press fine. Camera run asked (4 slots, in order):
  COLOR + Film Grain High, ART Grainy Film, Grainy Film + an Art Effect, Grainy Film + another Art Effect; then
  half-press to write GLOG.BIN. Afterwards put the v0.24.1 GUIDES.BIN (112e8f93…) back.
- fg2 camera run 1 (2026-11-08, owner): 5 photos (PB081430..434, camera clock 00:22:52..00:23:36) after a half-press
  save at 00:22:40 (BUNDLES.NEW / LOOKS.NEW), but no save after the photos: GLOG.BIN on the card is still the fg1 one
  (marks 1, records 5, selector calls 372). Likely cause (analysis): the last half-press was in ART mode (Grainy
  Film); the half-press save (ed_trig -> pf_save -> block +72 xb_lw) runs only from the editor's states, so the log
  was never written. Also 5 shots > 4 slots (slot = mark & 3: the fifth overwrites the first). Redo: exactly 4
  photos, then Picture Mode back to a COLOR, half-press, wait, switch off.
- fg2 camera run 2 (2026-11-08, owner): 4 photos (PB081435..438), Picture Mode back to COLOR, half-press: no save
  at all (BUNDLES.NEW, GLOG.BIN unchanged). Reading (analysis): (1) the log buffers are made only at a half-press
  save, and with nothing changed the power-on half-press does not save, so this run had no buffers; (2) the dirty mark
  xb_mark sets during a capture did not cause a save in run 1 or run 2 (possibly the capture runs on the other CPU
  and the write is not seen; not checked). Workaround for run 3: change a Picture Mode row (and back) before the first
  half-press and again before the last one, so the editor's own change flag triggers both saves.
- fg2 camera run 3 (2026-11-08, owner; Blk changed and back before the first and the last half-press): GLOG.BIN
  written (camera-tested log; the decoded text of the fg3 logs is research/grain/fg3_logs.txt, decoder research/grain/glog3.py; the GLOG.BIN files stay off the repo). Photos PB081439..441 (JPEG ~15 MB) before the save, 442 (~9 MB,
  the size of run 2's COLOR + Grain High) after it. Header: 4 marks, 44 records, 1952 selector calls. Slots alternate
  capture keys 0x00680201 / 0x00020000:
  - key 0x00680201 (context key 0x01020068: Art 0x68 variant II, presumably Grainy Film II): kind-3 0xf002 x4, then
    combiner 1 kind 0 stage 0x0100 (the development; not stage 0, so copy A missed it), then kind 3 stage 0x0101
    (slot 0: combiner 9, effect 0x0200; slot 2: combiner 10, effect 0x0300 = the gl7 Frame combiner), then kind-3
    stage-0 finals (+1095..1097 = 0a 55 08).
  - key 0x00020000 (context 2, after each Art capture): kind 0 stage 0 x2, kind 3 stage 0 x2, kind 10 0xf006 (likely a
    second, plain image per Art photo, e.g. the preview).
  - Capture bytes +37691.. all read 02 (suspect: wrong base). No COLOR capture in the logged window.
  Reading (analysis): Grainy Film develops in a stage-0x0100 pass and keeps its grain through a following kind-3 art
  pass (0x0101), unlike our COLOR grain (lost on any extra pass, gl9). Next: a logger that copies the stage-0x0100
  development and the 0x0101 art pass in full (fg3), and the owner's exact shot list for run 3.
- Owner (run 3 shot list): Grainy Film II, GF II + Pin Hole, GF II + Frame, then COLOR + Grain High (after the
  save). So the logged slots are slot 0 = GF II + Pin Hole (combiner 9, effect 0x0200), slot 2 = GF II + Frame
  (combiner 10, effect 0x0300); plain GF II came before the logged window. Owner: GF keeps its grain with both.
- fg3 (2026-11-08; emulator: boots, menus fine): 8 slots (header 64 B, 'GLG3'), copy A = the first kind-0 request at
  any stage (GF's 0x0100 development), B = the first kind-3 stage 0x01xx (the Art pass), C = the final. Firmware
  unchanged (v0.24.1); GUIDES.BIN 0ecb6bc8…, 14968 B. Shots asked: GF II, GF II + Pin Hole, GF II + Frame, COLOR +
  Grain High; Blk change and back before the first and the last half-press (in COLOR).
- fg3 camera run (2026-11-08, owner; PB081443..446: GF II, + Pin Hole, + Frame, COLOR + Grain High): GLOG.BIN
  ('GLG3', 2 marks, 19 records, 3982 selector calls) written at 1445's time; no save after 1446.
  - Saves: the capture mark's dirty flag DOES work: the half-press of the NEXT shot saves (first save = buffers, next =
    the log). Here: 1443 marked before the buffers existed (not logged), 1444's half-press made the buffers... -> slot 0
    = GF II + Pin Hole (full), slot 1 = GF II + Frame (marked at the save, 1 record). The final Blk-change half-press
    did not save (not understood). Procedure from now: after each photo, one plain half-press saves the log so far.
  - GF II + Pin Hole, full copies (camera-tested log; analysis): development = kind 0, stage 0x0100, combiner 1,
    request +10 = 0x68 (the Art id; COLOR stills have 11, our grain 12), +1751 = 0 (no MONO grain level), output
    +1100 = 0x0c02 (to memory), no 2nd output. Then the Art pass (kind 3, stage 0x0101, combiner 9, effect 0x0200)
    and the finals (stage 0). => Grainy Film's grain is not the MONO grain (+1751 / 0x1c02 output stage, lost on any
    extra pass): it is made in the 0x0100 development itself (baked into the 0x0c02 image), so it survives Art passes.
    Grainy Film is a monochrome Art Filter, so colour safety is still open.
  - Next: diff this development request against a COLOR development (plain and Grain High) to find what makes the
    grain (request fields vs combiner 1's set-up for context 0x01020068); run: COLOR plain, COLOR + Grain High,
    GF II, each followed by a plain half-press.
- fg3 run 2 (2026-11-08, owner; PB081447 COLOR, 448 COLOR + Grain High, 449 GF II; a plain half-press after each):
  all three logged (3 marks). Plain GF II also has the kind-3 stage-0x0101 pass (combiner 0, effect 0).
  Development requests (copy A), word diff, camera-tested log (meaning = analysis):
  - +8 key: COLOR 0x000b0000, Grain High 0x000c0000 (+1751 = 3), GF II 0x00680201; +12 stage 0 / 0 / 0x0100.
  - **GF II only: an extra image at +780..+812:** +780 = 0x4dfd4400 (bus address), +796 = 0x14400c02 (5184,
    format 0x0c02), +800 / +804 = 0x0f401440 (5184 x 3904), +812 = 0x07a00a20 (2592 x 1952, half size). COLOR and
    Grain High have it all 0. Guess: a half-size grain texture blended into the development (combiner 1).
  - COLOR / Grain High only: +872..+888 (0x0080200c, 0x00800080 x2, 0x00400040), and the 2nd output +1112..+1175
    (1600 x 1200 0x0c02); output +1100 0x1c02 (GF: 0x0c02 to memory for its 0x0101 pass).
  - +1652..+1852 (tone tables) differ a little in all three (exposure).
  Next (static + emulator): who fills +780..+812 for Art 0x68 and with what (a stored texture or made per shot), and
  what combiner 1 does with it; then try that extra image on a COLOR development (key 11) for colour grain that
  survives Art / Glow / Clarity passes.

## Grainy Film's grain path in the firmware (2026-11-08; static analysis of OM-3 1.1, matched to the fg3 camera logs)

- **Work list.** The table at 0x606c957c holds (key − 11, handler) pairs, found by hashing (key − 11) & 31 and probing
  (so 0x0102005d = Grainy Film II 0x01020068, 0x0101005d = GF I 0x01010068, 0x00000001 = MONO 12). GF's handler is
  **0x604b8ddc**: default list if the request flags (+40) have 0x0100 in 0xf00 or 0x40 in 0xf0; otherwise pass
  0x604b81ca (job+5385 in 4..8) or 0x604b81ec, pass 0x604bc17e, **config hook 0x604bc0cf** (0x604b8cb5 sets the hook
  of the last pass), then the common tail 0x604b918c with pass 0x604bc2a1 / hook 0x604bc40e. A list entry is
  12 B: +0 pass, +4 request-config hook (0x604b8c45 adds a pass).
- **Hook 0x604bc0cf (a1 = request) attaches the texture:** kind 0 (development): 19 words (76 B, an image
  descriptor) from (job+8324)+8 to request **+780**, its bus address from the object's +8/+12 with job+8312 & obj+108
  (0x6004c404) to +780/+784, and request **+12 = 0x0100** (the stage seen in the logs). Kind 3: the same into request
  +96 (the 0x0101 pass gets the texture as well). This is exactly the extra half-size image the fg3 log showed.
- **The texture object (job+8324)** is made in the still set-up function (around 0x604b9956, keys GF I / GF II):
  flags at (4,sp)+40 checked, then 0x604cd921 with a 7-byte parameter block ((4,sp)+40 halfword, +44 byte, (20,sp),
  0x604b77fb(...), (8,sp)). 0x604cd921 is a **cache of 4 objects** (116 B each at 0xa32e94b8, refcount +112, match
  0x604ce6f0): a texture with the same parameters is reused, a new one built otherwise. So the grain is a ready-made
  image blended in development by the image processor: no CPU time per photo.
- Same set-up code treats MONO (job+5352 = 12) next to GF (0x604b3c66: grain flag job+5356 -> stage bits 0x0100;
  0x604b8d1b) — the camera's own MONO grain probably used this texture route once (its list's grain branches are dead
  now, see the fast-grain review).
- **Open:** whether combiner 1 at stage 0x0100 blends the texture into luma only (colour kept) or needs a mono image;
  where 0x604cd921 builds a new texture; the parameter values for GF II (log them).
- **Plan (ft1):** for COLOR stills with Grain, (a) get a texture object (call 0x604cd921 with GF II's parameters at
  set-up, or log them first), (b) give the COLOR development request the same attach as hook 0x604bc0cf (+780
  descriptor, +12 = 0x0100) instead of the MONO-key trick. If the blend keeps colour, grain becomes part of the
  developed image: as fast as default and kept through Art Effect / Glow / Clarity / Shading passes.
- **ft1 build (2026-11-08; emulator: boots, menus and half-press fine; the emulator cannot take stills, so the new
  code is untested until the camera):** flash hook `.hook_su` on the still set-up thunk 0x604b7730 -> `xs_su` (ext11):
  stock set-up 0x604b97db, then code block +112 `xb_su` (a0 = S): COLOR still (job+5352 = 11) whose profile has Grain
  -> texture object from 0x604cd921 with GF's 6-byte block and gate, stored at job+8324 (stock clean-up releases it),
  `xb_tx` = 1. `xb_dev`: with `xb_tx`, the first COLOR development request (kind 0, +14 0x1000, +10 11) goes through
  the stock hook 0x604bc0cf (a0 = S, a1 = request: +780 texture, +12 = 0x0100) and keeps key 11 (no MONO key). The
  fg3 logger stays in (it shows the combiner and +780). Firmware 83ef2c01…, GUIDES 684d9e4e…. Camera questions: does
  the photo save; grain or not; colour or grey; the log's combiner for the COLOR development. Grain strength is not
  wired (Low / Med / High give the same texture).
- **ft1 camera (2026-11-08, owner; PB081450, COLOR + Grain High):** the photo saved, in colour, **no visible grain**
  (flat areas: Y high-pass ~5, Cb/Cr ~0.9; the MONO-grain photo PB081448: Y ~38). Log (camera-tested; decoded in
  research/grain/fg3_logs.txt): the texture WAS attached (development request +780 = 0x4dfd4400, the same buffer GF
  II used, +796..+812 as GF, +12 = 0x0100, key 11), but the selector chose **combiner 0**, not 1. The request was
  configured a second time and our MONO route applied then (context 12, +1751 3) - no MONO grain came out either
  (stage 0x0100 changes the path).
- Selector 0x6052cf39 (analysis): kind 3 by stage; otherwise by the context key (48) via the hash table 0x606dc4dc
  ({key - 11, handler}): GF I / GF II (0x01010068 / 0x01020068) -> 0x6052cfc6 = **combiner 1 when +12 == 0x0100**;
  key 11 has no entry (default 0x6052d0c2). So combiner 1 needs GF's context key at selection time.
- **ft2 (GUIDES only, firmware = ft1 83ef2c01; emulator: boots):** the textured request gets context 0x01020068 for
  the selector on every configuration (combiner 1); Grain Low / High put the key back to 11 right after the selector
  (combiner 1's set-up sees COLOR), Grain Med keeps GF II's key (to see what that set-up does). xb_gt cleared for that
  still (no MONO key). GUIDES 55fcc753….
- **ft2 camera (2026-11-08, owner; PB081452 Grain Low, PB081453 Grain Med; 1451 missing; the owner saw one brief
  restart, not repeatable):** both saved. Log: **combiner 1** chosen for the textured COLOR development in both.
  - Low (key back to 11 after the selector): colour, **no grain** (flat areas Y hp 3.5..6.7, Cb/Cr ~0.9, as plain).
  - Med (GF II's key kept for combiner 1's set-up): **black and white with grain** (Cb = Cr = 128 everywhere, Y hp
    ~19 on every patch: a Grainy Film look on a COLOR still).
  => The blend is switched on by combiner 1's set-up under Grainy Film's key, together with its mono conversion.
  Next (emulator, no camera): run combiner 1's handler natively with key 11 and with 0x01020068 on the same request
  and diff what it writes, to separate "blend the texture" from "make it mono" (as gl4..gl6 did for combiner 33).
- Why ft2 Low had no grain (analysis): the request configuration calls the selector twice - our hooked call at
  0x604955f1, then again inside the combiner set-up 0x60504b2b (0x60504b5d), which then jumps to the combiner's case
  (table 0x606cc794). With the key back to 11 the second call gave combiner 0, so the default case (0x605056ef) set
  up no blend. **Combiner 1's case 0x60504b90 does not read the context key**: it calls 0x605047c1 (signed second
  input, -512..511) and writes the register image (context+8)+7988: +4 = 0x00200001 (default 0x00200000), +8 = 3822,
  +92 = 0x2a0000, +96 = 1024, +100 = 0, +144 = 0x2a0000, +148 = 1024. So the mono of ft2 Med comes from other
  key-driven set-ups, not from the blend.
- **ft3 (firmware + GUIDES; emulator: boots, live view and menus fine; stills untested):** new flash hook
  `.hook_sel2` (0x60504b5d -> `s_sel2` -> block +120 `xb_sel2`): the textured COLOR development gets combiner 1 from
  both selector calls with its key left at 11 (Grain Low / High); Grain Med keeps the ft2 control (GF II's key).
  Firmware 95649831…, GUIDES 6d62e1bf….
- ft2 restart (owner): one brief restart on a Grain Low shot (probably the missing PB081451), not repeatable. Guess:
  in ft2 Low the request carried the texture and stage 0x0100 while the combiner set-up was the default one (the
  second selector call gave 0), a mismatch ft3 removes. Watch for it in ft3.
- **ft3 camera (2026-11-08, owner; PB081454 Grain Low, PB081455 Med; no restart):** both saved, combiner 1 in the
  log, key 11 for Low. **Both black and white with grain** (Cb = Cr = 128, Y high-pass ~20 on every patch). So the
  mono is combiner 1's own set-up, not the key. Its case vs the default case (analysis): default `+96 = 0x04000400,
  +100 = 1024` (+ 0x60504811), combiner 1 `+96 = 1024, +100 = 0`, `+144 = 0x2a0000, +148 = 1024, +152 = 0`,
  `+8 = 3822`, signed ranges (0x605047c1). Guess: +96 high half and +100 are the main input's chroma gains (0 =
  Grainy Film's mono), +144..+152 the texture's (luma 1024, chroma 0).
- **ft4 (firmware + GUIDES; emulator: boots, live view fine):** `.hook_c1e` at 0x605053cc (the end of that set-up)
  -> `s_c1e` -> block +128 `xb_c1e`: when xb_sel2 forced combiner 1 for Grain Low / High, +96 = 0x04000400 and
  +100 = 1024 (the default's values); High also +148 = 2048 (texture gain guess). Med = ft2/ft3 control. Firmware
  75a48eb7…, GUIDES 605f7b1a….
- **ft4 camera (2026-11-08, owner; PB081456 Grain Low, PB081457 Grain High; no restarts): COLOUR + GRAIN from the
  image processor.** Low: full colour (Cb/Cr means 101..148, as normal), grain Y high-pass ~20 on every patch (the
  MONO-grain High of v0.21 measured ~25..38 on its scene; plain COLOR ~4), chroma high-pass ~0.5 (grey grain).
  High (+148 = 2048): stronger grain (Y hp ~31..38) but the whole photo darker (patch means 28..96 vs 90..187) and some
  chroma speckle (Cb/Cr hp up to 8): so +148 is the texture's gain and the texture is not zero-mean at that gain
  (or the gain also shifts the offset). Confirms: +96 high half / +100 = the main input's chroma gains.
  => Fast colour-photo grain through Grainy Film's texture blend works. Next: strength levels (texture gain with the
  right offset: +8 3822, +144 0x2a0000, the signed ranges of 0x605047c1, or +148 below 1024 for Low), speed check,
  Art Effects / Glow / Clarity / Shading on top, then our own texture (colour speckle).
- **ft5 (GUIDES only, firmware = ft4 75a48eb7…; emulator: boots, live view fine):** XB_FX 1 (Glow / Clarity / Art
  back on). Texture gain +148 by Grain: Low 512, Med 768, High 1024. Texture only on a development without its own
  effect (+1756 = 0: plain, Frame, Star, Pin Hole per gl7; Glow 0x0400 / White Edge 0x0500 keep their combiner and
  fall back to the CPU grain). xb_cap: Art + Grain no longer adds the Soft Focus pass; xb_gs: no CPU grain when the
  texture went in (xb_tx 2). GUIDES 51477b56…. Test LOOKS.BIN (card only; the owner's LOOKS / EDITS backed up outside
  the repo): COLOR 1 FILM 1-5 = Grain Low / Med / High / High + Frame / High + Pin Hole, COLOR 2 FILM 6-7 = High +
  Glow -3 / High + Star.
- **ft5 camera (2026-11-08, owner; PB081458..463):** FILM 1-3 (Low / Med / High) = colour + grain, Y high-pass
  **11 / 15 / 20** (strengths work; shadows a little lighter with more grain: dark patch mean 26 / 32 / 38, likely
  grain clipped at black). **FILM 4 (High + Frame) restarted the camera** (no file). FILM 5 (Pin Hole, PB081461): no
  grain - its development carries effect 0x0200 (combiner 9: the vignette is done there), so no texture and no CPU
  grain any more. FILM 6 (Glow, PB081462): development effect 0x0400 -> no texture; Glow passes + the CPU grain (grain
  in mid/bright areas only, Y hp 3..17, as the CPU grain's shape). FILM 7 (Star, PB081463): textured development
  (combiner 1) then the Star passes (combiner 135): **colour + grain + Star** (Y hp ~20). The log starts after the
  restart (slot 0 Pin Hole, 1 Glow, 2 Star).
  Open: why Frame restarts (Frame = development effect 0 -> textured, then a kind-3 0xf005 pass with combiner 10;
  in GF + Frame that pass also got the texture at +96 by the hook); Pin Hole / Glow / White Edge need the texture
  somewhere else (their development has its own combiner).
- Owner: FILM 4 (High + Frame) restarts the camera **every time** (ft5).
- **ft6 (GUIDES only, firmware = ft4; emulator: boots):** the texture only for no Art Effect or Star Light and no
  Glow / Clarity; Frame, Pin Hole, White Edge and Glow / Clarity with Grain go back to the CPU grain (Soft Focus pass,
  ~3 s, as v0.22). GUIDES 705cf9b8…. Meant as the safe base for a release candidate; Frame + texture stays research.
- **ft6 camera (2026-11-08, owner; PB081465..471; no restarts):** FILM 1-3 fast, colour + grain Y hp 12 / 15 / 20;
  FILM 4 Frame, 5 Pin Hole, 6 Glow slow (owner) with the CPU grain (Y hp 3..18 by brightness, as the CPU grain's
  shape), FILM 7 Star fast with texture grain (Y hp ~20). All in colour. => ft6 = a release candidate base: fast
  colour-photo grain (plain, Star), Glow / Clarity / Art Effects back with the slower grain. Not yet checked: Shading
  + Grain on ft6 (Shading's development has effect 0x0c00, so no texture and no MONO key: expect colour, no grain),
  White Edge, Clarity, burst.
- Owner (2026-11-08): "Pin Hole is really just Shading": goal = Shading, Frame and Glow with the quick grain.
- **ft7 (GUIDES only, firmware = ft4; emulator: boots):** when the development has its own effect (Pin Hole 0x0200,
  Glow 0x0400, White Edge 0x0500, Shading 0x0c00) the texture waits (xb_tx 3) for the kind-3 **conversion pass**
  (stage 0xf005, effect 0) and goes there: stock hook in its kind-3 form (texture at +96), its stage kept at 0xf005,
  combiner 1 forced (xb_lg / xb_sel2 by request) with COLOR's chroma back (xb_c1e). Frame still CPU grain. No CPU
  grain whenever a texture exists. Test LOOKS: COLOR 1 FILM 1-5 = High / + Pin Hole / + Glow -3 / + Shading -3 /
  + White Edge, COLOR 2 FILM 6-7 = + Frame (CPU) / + Star. GUIDES 2b66efbc….
- **ft7 camera (2026-11-08, owner): FAILED.** FILM 1 (plain High) fine (PB081472). **FILM 2 (Pin Hole): took the
  picture, froze, black screen, battery pull** (no file): texture + combiner 1 on the kind-3 conversion pass hangs the
  image processor. Do not retry that form. Also: "COLOR 1 had a white frame": with XB_FX 1 again, COLOR 1's own
  stored Art Effect (likely Frame, set in the v0.20-v0.22 Extras era; v0.24 has no row to change it) is active again
  (analysis; to check). ft6 GUIDES (705cf9b8…) put back on the card.

## Grainy Film's work list for COLOR + effects (2026-11-08; analysis + ft8 build)

- Default (COLOR) list 0x604b917f: main pass 0x604b857b / hook 0x604b84c6 = the development itself (Pin Hole /
  White Edge / Shading / Glow put their combiner there), then flag-driven passes (request flags 0x20000, 0x40000,
  0x40 + job+5385 ...), then finals. Grainy Film's list 0x604b8ddc: pre-pass 0x604b81ca (job+5385 4..8) / 0x604b81ec
  (the four kind-3 0xf002 records), development 0x604bc17e + texture hook 0x604bc0cf (stage 0x0100), then the common
  tail 0x604b918c with **pass 0x604bc2a1 / hook 0x604bc40e = the kind-3 stage-0x0101 pass that carries the Art
  Effect** (Pin Hole combiner 9, Frame combiner 10 in the fg3 logs), then the same flag passes. So Grainy Film keeps
  the effect out of the development; COLOR puts it in.
- **ft8 (firmware + GUIDES; emulator: boots, live view fine):** `.hook_wl` at 0x604b8d91 (the builder's key read) ->
  `s_wl` -> block +136 `xb_wl`: a COLOR still (job key 11) that already has our texture (job+8324) and Grain with Pin
  Hole / White Edge / Frame (no Glow) is given Grainy Film II's list (lookup key only; the job keeps key 11, so its
  colour settings stay COLOR's). ft7's conversion-pass texture removed (it hung); xb_su makes the texture for every
  Art Effect (not with Glow / Clarity: CPU grain there); Art + Grain never adds the Soft Focus pass. If the set-up
  runs after the list build, job+8324 is still 0 and nothing changes (safe). Firmware 235ecee0…, GUIDES 38408948….
  Test LOOKS: COLOR 1 FILM 1-5 = High / + Pin Hole / + White Edge / + Frame / + Star.
- **ft8 camera (2026-11-08, owner; PB081473..476):** FILM 1 plain fast + grain (Y hp 20); FILM 2 Pin Hole and FILM 3
  White Edge fast but **no grain** (Y hp 2..7); **FILM 4 Frame restarted** again; FILM 5 Star as before (grain, Star
  always a little slower). Reading (analysis): the list swap never happened - the work list is built **before** the
  set-up, so job+8324 was still 0 at xb_wl; Pin Hole / White Edge stayed in the development (no texture, no CPU
  grain); Frame took the texture in the development on COLOR's list -> restart (as ft5).
- **ft8b (firmware + GUIDES; emulator: boots):** s_wl passes S (the builder's (4,sp)); xb_wl makes the texture itself
  (shared `xb_tex`, also used by xb_su, which now only marks a texture made earlier) and swaps to Grainy Film's list
  only when the texture exists. Frame never gets the texture on COLOR's list (xb_sw / xb_tart guard). Firmware
  ec1d0608…, GUIDES ada120aa…. Same test LOOKS as ft8.
- **ft8b camera (2026-11-08, owner; PB081477..481; no restarts): Pin Hole, White Edge and Frame WITH fast grain.**
  All five in colour with grain Y hp ~20: plain, Pin Hole (dark vignette), White Edge, **Frame (white frame, no
  restart)**, Star. Grain fades in the darkest vignette corners (Y hp 2..4 at Y ~24, clipped at black). So COLOR +
  Art Effect + grain works through Grainy Film's work list (texture made at list time). Left: Glow / Clarity and
  Shading.
- **ft9 (GUIDES only, firmware = ft8b; emulator: boots):** every COLOR Grain still except Star Light takes Grainy
  Film's list (plain, Shading, Glow / Clarity too); the texture also with Glow / Clarity (no CPU grain). Test LOOKS:
  COLOR 1 FILM 1-5 = High / Pin Hole / Frame / Shading -3 / Glow -3, COLOR 2 FILM 6 = Star. GUIDES c73e3e4f….
- **ft9 camera (2026-11-08, owner; PB081482..487): EVERYTHING fast with colour grain, no freezes or restarts.**
  Owner: "quick across the board". Measured: plain (Grainy Film's list now) Y hp 20; Pin Hole (dark vignette) 18..20;
  Frame (white frame) 19..20; **Shading -3 (dark corners) 18..20**; **Glow -3 (soft glow) ~16** (the glow softens the
  grain a little); Star 19..20 (COLOR's list). All full colour (Cb/Cr high-pass < 1). The grain fades in the darkest
  corners (clipped at black).
  => Goal reached in the test build: grain as fast as default, in colour, with Art Effects, Glow / Clarity and
  Shading. Next: a clean release candidate (logger out, Shading row back, strengths, Control Panel), and the open
  "COLOR 1 white frame" question (an Art Effect stored on COLOR 1 from the Extras era, no row to change it).

## v0.25 candidate rc1 (2026-11-08; branch feature/v0.25-fast-grain from experiment/fast-grain-log ft9)

- Owner: release candidate yes; Glow / Clarity and Art Effects should get Picture Mode rows (rc2).
- rc1 (emulator: boots, live view fine, the Shading row is back between Vignette and Film Grain): ft9 + XB_LOG 0
  (no GLOG.BIN, no 57 KB buffers), Shading row back (pm_list 5399), and COLOR k's **own** Glow / Art Effect are not
  used (xb_own: P+LIDX+k not 1..5 = no film) until rc2 gives them rows (fixes the hidden "COLOR 1 white frame" from
  the Extras era). Films' Glow / Art apply. Firmware d69485cd…, GUIDES 8860ded9…. Camera test with the owner's own
  LOOKS.BIN / EDITS.BIN put back.
- rc1 camera (owner): works; **grain brightens the photo**, **Med and High look alike**. Same-scene test PB081496..499
  (Off / Low / Med / High, COLOR 1), 32 px blocks binned by the Off photo's Y: Y lifted on **every tone** by ~+12 /
  +19 / +26 (8-bit) at gain 512 / 768 / 1024 (~0.026 x gain), Cb/Cr ~unchanged; grain high-pass std Off 2..8,
  Low 10..12, Med 15..16, High 19..20 (Med / High only 1.3x apart). => the texture is not zero-mean (a DC offset
  scaled by its gain), not black clipping.
- rc2a (GUIDES only; emulator: boots): gains Low 448 / Med 832 / High 1280 (2048 went dark in ft4: likely a signed
  12-bit field) and the output's Y offset (+180 low half; combiner 1's set-up leaves it 0 and puts 512 in the chroma
  offsets) = -0.102 x gain (10-bit): -46 / -85 / -131. Which offset field is Y is a guess: a colour cast instead of
  the fix would say it is chroma. GUIDES 7294c032….
- **rc2a camera (2026-11-08, owner: "vastly better"; PB081500..503 Off / Low / Med / High, same scene):** brightness
  lift gone - Y shift vs Off within -5..+5 on mid tones (shadows +1..+7, highlights -5..-16 at High: grain clipped at
  black / white), **no colour cast** (Cb/Cr within ±1.2): +180 low half is the Y offset (confirmed). Grain high-pass
  std **Low ~10, Med ~16, High ~24** (Off 2..8): clearly three steps.
- Owner (2026-11-08): option 2 (rows first, one release) with: the **Glow / Clarity slider back**; for Art Effects
  **only Frame On / Off** (Star Light is slow: out; Pin Hole / White Edge: Shading covers them).
- **rc2b (firmware + GUIDES; emulator: rows show, values change, '*' appears):** two Picture Mode rows after Shading:
  **Glow / Clarity** (GL_IT 5382, slider class 9, bar GLB 0x7ea0 + k, slot +49 = -5 Glow .. +5 Clarity, icon "Glow",
  readout and -5..+5 bar as Blacks) and **Frame** (FR_IT 5381, choice class 10 as Vignette Correction, bar FRB 0x7eb0 +
  k, slot +50 = 0 / 5, left cells "Frame / Off|On", strip the camera's Off / On icons). Strings ST_GLC "Glow /
  Clarity", ST_FRM "Frame"; it_tab 25 entries; ic_list 9 (count 9); fl_xr rows 10/11 (rows 7..9 skipped: FLB); 14
  mkicons pictures, ic_pay 19480 B (ext11 64976 of 65536: 560 B left). Block: xb_art = Frame (5) only; COLOR k's
  own Glow / Frame used again (XB_OWNOFF 0). Firmware 591fe72d…, GUIDES 6ec55047…. New camera pictures: "Glow",
  "Frame / Off", "Frame / On" (sent to the owner).
- Owner approved the rc2b row pictures ("Glow", "Frame / Off", "Frame / On"), 2026-11-08.
- **rc2b camera (2026-11-08, owner):** the four row tests worked (Glow / Clarity, Frame, '*', hold-OK reset;
  PB081506..508). But **Glow + Frame + Grain together: "picture error"**: PB081509 / 510 / 511 are 93 184 B files -
  the EXIF header and thumbnail only, no main image (the camera wrote no picture). Isolation (PB081511..513): Glow -1 +
  Frame + Grain High = broken; Glow -1 + Frame, Grain Off = fine (white frame); Sharp -5 + NR Off + VigFix Off + Grain
  High = fine (Y hp ~22). So the break is Glow + Frame on Grainy Film's list with the texture.
- **rc2c (GUIDES only, firmware = rc2b; emulator: boots):** Glow / Clarity together with Frame and Grain: no texture,
  COLOR's own list, the CPU grain (~3 s, as v0.22). Every other combination as rc2b. GUIDES cbee5efc….
- **rc2c camera (2026-11-08, owner: "that works!!!"):** Glow + Frame + Grain saves (slower CPU grain) with grain,
  glow and frame; Glow + Grain and Frame + Grain fast. rc2c = firmware 591fe72d…, GUIDES cbee5efc… = the v0.25
  release candidate.
- **v0.25 release prepared (2026-11-08):** releases/v0.25 from the rc2c build (patch.py rebuilds 591fe72d… byte for
  byte), Control Panel "v0.25 or later" export (fw 24: Shading kept, Art Effect Frame / Off; the slow-grain note only
  for Glow / Clarity + Frame + Grain), docs. Waiting for the owner's go-ahead to publish.

## WB grid again, and a Blacks / Whites grid (owner, 2026-11-08 evening; for v0.25)

- Owner: go back to the WB grid ("we were close"); and a second grid for Blacks (horizontal) / Whites (vertical).
  Both grids replace their slider rows (one "WB" grid row instead of A-B + G-M, one grid row instead of Blacks +
  Whites).
- Why test 13 was rejected (owner, asked 2026-11-08; not written down before): **no numbers shown**, and **the
  directions were reversed** (right moved the dot left, up moved it down).
- Plan (analysis, 2026-11-08): port the test-13 grid (commit 4d5288b: scene 498 in Picture Mode's layer-457 holder via
  sc_cap / gr_upd (hook 0x611d04ec) / gr_pub (property 256) / gr_ref, row object = the camera's 2-D control kind 7 on
  key 1580 (gk_f), facade redirect of the grid ids 1580..1605 to the look's slot +26 / +27 while gr_flag, gx_map to
  leave) onto v0.25, as one "WB" row replacing A-B + G-M. Fix the directions (owner: right moved the dot left, up
  moved it down): negate the value in both redirect directions (the control then steps the other way) and keep the dot
  at 594 + 13 A-B / 280 - 13 G-M, so right = A (+), up = G (+) as on the camera's own grid. Numbers: the row title as a
  dynamic string ("WB  A3 · G2") from st_get, refreshed by gr_upd (to try). Then the Blacks / Whites grid: the same
  scene with the box pictures B / A / G / M answered by our own (ic_get while the BW grid shows), redirect to slot
  +47 / +48 clamped to -5..+5, title "Blk +2 · Wht -1". New pictures need the owner's approval.

### v0.25 WB grid row, first build (2026-11-08; emulator only)
- Branch `feature/v0.25-fast-grain`, commit "WB grid row on v0.25": one WB row (AB_IT, item 5384) replaces A-B and
  G-M. As test 13: item 5398-style entry (`0x6154bd18`, 27, +26 = 7), row switches as 5398's / item 7's left cell /
  gk_f (kind-7 control on key 1580), scene 498 into the holder of Picture Mode's layer 457 (sc_cap / gr_upd via
  hook 0x611d04ec), gx_map (0x610f6016) to leave. New: `gr_id` maps the grid's ids (1580..1605) to our ABB / GMB + k
  in one place (sl_get, sl_cnt, sl_vbi, sl_sel, sl_set; MDR kept), and marks them `gr_neg`: values the other way
  round (get negated, set negated). The row's own left-cell ids (AB_IT, ABB + k) are negated too and the readout's
  sign table rd15_a is flipped, so the left cell shows the true A-B ("WB± -1" = B1). The left cell's picture is the
  camera's WB± (12545, ic_list 7); the A-B / G-M slider pictures are blank now (ic_pay 18040). ext11 64448 B.
- Directions (emulator): the camera's own WB± screen: right arrow = A, up arrow = G, sub+1 (front dial) = B,
  main+1 = G. On our row the emulator sends right/left and both dials to the kind-7 control (ids 1580 / 1593);
  up/down change rows. Owner (asked 2026-11-08): test 13 was used with the **arrow buttons**, and both axes went the
  wrong way on the camera. So on the camera the arrows reach the control differently from the emulator; the build
  negates both axes (analysis: camera arrows then right = A / dot right, up = G / dot up; to confirm on the camera).
- Layers: the grid only draws in the holder of layer 457 (bottom bar). 286, 288, 456: no grid (the bottom bar's slider
  shows instead, with no title).
- Numbers: no text in scene 498 (string requests while it draws: none; its B / A / G / M letters are pictures,
  probably 10324..10328). Owner: numbers "underneath like on the standard white balance screen". The camera's WB±
  screen shows "WBAuto B1 . G2" with dial icons in the dial-guide readout (shared layer 497; Picture Mode shows "Sh /
  Mid / Hi" there for Highlight & Shadow, "Color" / "Vivid" for the Color row). Next: find how a row sets that readout.

### WB grid test 1 for v0.25: OK opens the camera's WB fine-tune screen (2026-11-08; emulator only)
- Owner (2026-11-08): "clicking ok to open and adjust the white balance grid, just like it is in the super menu would
  be perfect. same for the blk/wht grid". Owner's photo of the camera's WB screen: the WB± cell shows the values
  under its picture ("A2.G2").
- Build (commit "WB grid row: OK opens..."): the WB row keeps the on-screen grid preview (test 13 route) and pm_ev
  (hook 0x6125becc, as test 12) opens GUI state 0x0408 (the camera's WB fine-tune screen) on our row for OK 0x900c,
  left / right 0x9008 / 0x900a, dials 0x9031 / 0x9032, and the WB screen's other openers 0xf83c and 0x9755 with
  code 9 (0x6129b050 reads the event's data; the WB± handler 0x6125bc8b opens on these; test 12 caught only 0x900c,
  which is likely why OK went to live view on the camera). Picture Mode events: up 0x9004, down 0x9006, left 0x9008,
  right 0x900a, OK 0x900c, INFO 0x9014 (press; +1 = release).
- In the fine-tune screen (gr_fine = 1) the facade answers the grid ids from the look without negation: the camera's
  own directions and its "A2 . G1" header. Inline (on the Picture Mode row) the values stay negated (owner: test 13's
  arrows went the wrong way on the camera).
- MENU in it -> 0x0418 with gr_hold / gr_row (setting 2148) as test 12, back on our row. The row list at
  (0x6037dfa0) + 0x51a0 then holds the fine-tune screen's list (Picture Mode resumes without rebuilding it), so pm_ev
  uses gr_flag (gr_upd) for "our row". Loading 498 into the holder at the first update after MENU crashed the
  emulator (fault at 0x610f3b82): Picture Mode reloads its bottom bar (457) right after; sc_cap now swaps that load
  for 498 (gr_wait) and keeps the holder; sc_cap does not capture while gr_fine (the fine-tune screen's holders).
- Emulator: row -> right / OK -> fine-tune with the look's values; arrows move the dot the natural way, header
  numbers follow; MENU -> back on the row with the preview at the new values; up / down rows; OK from the fine-tune ->
  live view. Left cell "WB± -2" for B2. Package wbg1: E1479999.BIN c3c195d2…, GUIDES.BIN 83674857…, LABELS.BIN
  903af75b… (card not connected at packaging).
- Still to do: Blacks / Whites grid the same way (the fine-tune screen shows B / A / G / M and WB letters: needs our
  own pictures / header); docs.
- Camera (owner, 2026-11-08, package wbg1): **OK opens the grid**, arrows and the rest adjust properly; **half-press out
  of the grid restarted the camera**; the WB row's left cell looks wrong (wants it as the camera's WB screen: the WB±
  picture with "A2.G2" under it). Emulator reproduced the restart: the next Picture Mode visit called gr_is on the old
  screen's holder (fault in gr_is). Fix (package wbg2: E1479999.BIN 40927e34…, GUIDES.BIN 11d8ca4b…, LABELS.BIN
  903af75b…, on the card, checked by checksum): leaving the fine-tune screen anywhere but MENU forgets the holder;
  sc_cap loads 498 in place of 457 whenever our row is current (Picture Mode now comes back on the remembered row,
  setting 2148 / gr_row); gr_wait only after MENU. Emulator: half-press, OK and MENU exits, re-entry, OK again: no
  fault. Next: the left cell as a runtime-drawn picture (WB± over the values), then the Blacks / Whites grid.
- Camera (owner, wbg2): no restarts; exits work. Owner: get the left-cell icon right, then the Blacks / Whites grid.
- WB grid test 3 (wbg3; emulator only): the row is a one-option choice row again (test 12's: CHC wg_a..f, lc_wg,
  WGB 0x7ec0 + k class 11, value 0, item entry with wb_l0 "WB" / wb_l1 IC_WB / wb_l2 12545); the 2-D control, its
  inline negation and the title numbers are gone. Left cell = picture IC_WB 0x7f8f (100 x 76, wb_desc), drawn when
  the left column reads the row's value (SL_VAL class 11 -> wb_draw -> block +144 xb_wbc, only when A-B / G-M
  change): the camera's WB± picture (12545: descriptor = word at (0x60379740) + 4 id, type 11, 82 x 30) decoded row
  by row at (9, 6), the values as the camera writes them ("A2.G1", "B1.0", blank at 0 / 0) from our glyphs (DejaVu
  cap 18, the cells' 2 px edge; firmware/mkicons.py wbc_glyphs), packed into a malloc'd buffer (3200 + 112 B).
  Glyphs travel in LABELS.BIN v3 (12160 B: 'WBG1' section after the 27 bitmaps; the block's XL_FILE comes from the
  build) because GUIDES.BIN must stay <= 16448 B (malloc pool; now 16316 B); the token reader / packer (wb_wtk /
  wb_wem, wb_v) are in ext11 for the same reason (ext11 65408 of 65536 B). The LABELS section is only 2-aligned
  (first try faulted on a 32-bit read). With a choice row the bottom bar is layer 456 (457 is hidden): GLY = 456.
  Emulator: cell "WB±" / "A2.G1" / "B2.M2" follows the fine-tune values, grid preview with "WB" under it, half-press /
  OK / MENU exits and re-entry: no fault. Package wbg3: E1479999.BIN eba6b508…, GUIDES.BIN 58983837…, LABELS.BIN
  d6c1b4ab… (new: always copy with this firmware), on the card, checked by checksum.
- Camera (owner, 2026-11-08, wbg3): "It's perfect!" The WB row (cell, preview, OK -> fine-tune, exits) is
  camera-tested. Next: the Blacks / Whites grid.

### Blacks / Whites grid: plan (2026-11-08; analysis)
- Owner: a grid like the WB one, Blacks on the horizontal axis, Whites on the vertical; it replaces the Blacks and
  Whites rows; OK opens it "just like" the WB grid.
- The fine-tune screen's pictures (emulator, rendered from the picture table): box letters 10324 G, 10325 B, 10327 A,
  10328 M (32 x 32, type 11); header "WBAuto*" 11240 (86 x 44), header glyphs 16 x 30: 10813 'A', 10817 'G', 10826
  '.', 1121 '1' (the digits nearby); 10159 "Reset OK Hold"; 10904..10907 grid frame / dot / lines.
- Plan: one row (BK_IT reused, WH_IT dropped; their "Blk" / "Wht" pictures freed from ic_pay, ~1.6 KB of ext11).
  gr_mode 1 = Blacks / Whites: pm_ev opens 0x0408 the same way; gr_id maps the grid ids to BKB / WHB + k (slots
  +47 / +48, -5..+5); gr_pub draws the dot from +47 / +48; ic_get answers the box letters, the header letters and the
  header title with our pictures while gr_mode = 1 and gr_flag (boxes '-' / '+', header "Blk/Wht", '+' / '-'); the
  left cell "Blk/Wht" over "+2.-1". Pictures drawn at run time by the cell drawer, generalised and moved to ext11
  (GUIDES.BIN is at 16316 of 16448 B); glyphs in LABELS.BIN (+ '+', '-', '/', 'l', 'k', 'W', 'h', 't').
  To check in the emulator: does the fine-tune screen take the facade's count (11) and stop at +-5?

### Blacks / Whites grid test 1 (2026-11-08; emulator only)
- Commit "Blacks / Whites grid row": BK_IT is a one-option choice row (class 12, BWB 0x7ed0 + k; CHC bw_a..f, lc_bw,
  item entry bw_l0 "Blacks / Whites" / bw_l1, bw_l2 IC_BW 0x7f7f); WH_IT has no row now, the Blk / Wht slider
  pictures are blank (ic_pay 16432). gr_mode (gr_upd: AB_IT 0, BK_IT 1) picks the slots (+26 / +27 or +47 / +48 in
  gr_pub) and the facade ids (gr_id: BKB / WHB + k). Experiment first: the fine-tune screen takes the facade's range
  (-5..+5) and stops there.
- Pictures while gr_mode = 1 and gr_flag (ic_get, bw_swap): the box letters G 10324 / A 10327 -> our '+' (IC_BP), B
  10325 / M 10328 -> our '-' (IC_BM), 32 x 32; the header letters A 10813 / 10814, G 10817 / 10818 -> our '+' (IC_HP,
  16 x 30), B 10815 / 10816, M 10820 -> the camera's '-' 1120; the header's "WBAuto" 11240 -> "Blk/Wht" (bw_tdesc).
  No large camera '+' exists among the 32 x 32 / 16 x 30 pictures (survey of the table), so ours (mkicons bw_syms,
  bw_top) travel in LABELS.BIN's 'WBG1' section (header now 4 (offset, length) pairs); the block publishes the
  section at wb_v + 36 and wb_draw (mode 1) fills the descriptors. The left cell (xb_wbc mode 1): "Blk/Wht" over
  "+2/-1" (glyphs '+', '-', '/' added: 16). gr_upd reloads scene 498 when moving between the two grid rows
  (gr_lmode), else the boxes kept the other row's pictures.
- Sizes: GUIDES.BIN 16416 of 16448 B, LABELS.BIN 15244 B, ext11 64544 of 65536 B.
- Emulator: both rows, preview, fine-tune (+ / - boxes, "Blk/Wht +2 . +3" header), MENU / OK / half-press exits,
  re-entry: no fault. Package bw1: E1479999.BIN e44e23c4…, GUIDES.BIN c7d51ce8…, LABELS.BIN 88f4c049… (card not
  connected at packaging).
- Camera (owner, 2026-11-08, bw1): "that don't look too good. lets scrap it and go back to the sliders". Reverted
  (commit "Revert the Blacks / Whites grid row"): firmware and card files are WB grid test 3 again (rebuilt byte for
  byte: E1479999.BIN eba6b508…, GUIDES.BIN 58983837…, LABELS.BIN d6c1b4ab…), back on the card, checked by
  checksum. The Blacks / Whites grid code stays in commit 2fa6a5c for reference.

### v0.25 fixes from the owner's list (2026-11-08; emulator only)
- Owner's list: (1) profile changes not kept over a restart; (2) Picture Mode should open on its top row; (3) remove
  Frame; (4) the viewfinder info screen shows COLOR 3 on FILM 6; (5) Shading's number sits low; (6) Glow -> Clarity
  (rows named for the + side); (7) the selected film / profile is lost over a power cycle.
- (1) / (7), found (analysis + emulator): the editor's first use since the load (ei_page, and the wheel's k_ path)
  cleared P+DIRTY with the marker, so a film chosen (fl_set) or a change made before it was never saved (the next
  half-press found nothing to save). DIRTY is kept now. Still possible (to check on the camera): the bank loads at
  the first half-press after power-on, so before it the menus show COLOR n. (The emulator's half-press does not pass
  ed_trig's gate, so the save itself cannot be seen there.)
- (2) the row memory (setting 2148) answers 111 every time, except once after MENU from the WB fine-tune screen
  (gr_bk). (3) pm_list without FR_IT; xblock XB_ART 0 (ARTB: the Art Effect reads as 0 everywhere); the Frame
  pictures blank (ic_pay 14704); Control Panel v25Art 'off', slowGrain false, the Art Effect select only Off.
  (5) the Shading row's own left cell puts its readout ~5 px lower than the slider rows' cells: its picture 16244
  (46 x 46) is answered with a copy moved down 6 rows (sh_build, once from pu_hook, with wb_wtk / wb_wem). The 11-entry
  readout tables for 5399 (rd_a / rd_b) did not move it. (6) string "Clarity", icon "Clarity" (cap 16).
- (4) not found yet: on the back screen every live-view INFO display shows "FILM 3" correctly; the emulator's EVF
  switch fails (re-entry check), and no other picture in the table looks like the shooting screen's COLOR labels
  (15706..15709), so the viewfinder may draw it as text. Possibly the same cause as (7) (bank not loaded yet).
- Package fx1: E1479999.BIN 1203dedc…, GUIDES.BIN 9fc2aea5…, LABELS.BIN d6c1b4ab…, on the card, checked by checksum.
- Camera (owner, 2026-11-08, fx1, photos): the film now shows on the screens (the viewfinder title too); **missing
  icons** in the Noise Filter / Vignette Correction / Film Grain strips (only "High Std", nothing, "Low Off"); the
  Clarity icon looks bad -> back to "Glow", **+ = stronger Glow, - = Clarity**.
- Strips: a regression since the WB grid builds (wbg1..fx1; rc2c fine in the emulator): sl_cnt / sl_vbi / sl_sel
  called gr_id without a return-address slot, so the call's return address overwrote the saved d2 (call writes
  (0,sp)); the strips' option lists came out wrong. Fixed with add -4,sp around the call. Glow row: string "Glow",
  icon "Glow" again; SL_VAL / sl_set class 9 negate (the row + = slot - = Glow; the slot and the Control Panel keep
  - Glow / + Clarity). Emulator: all three strips as rc2c; Glow +2 on the row.
- Package fx2: E1479999.BIN 9fb1d1f1…, GUIDES.BIN 48ff01c3…, LABELS.BIN d6c1b4ab…, on the card, checked by checksum.
- Camera (owner, fx2): strips all fine, Glow + / - right; **settings still not kept over power off / on**.
- Found (emulator): ed_trig never passed its dirty check once the editor had been used: it calls gd_set, whose first
  instruction (film test 8: `call gd_sel`) had no return-address slot, so that call wrote over gd_set's saved a2;
  ed_trig came back with a2 = 0x61aa4492 (gd_set + 7) and read DIRTY there. So since film test 8 the half-press saved
  only when the editor had not been used since power-on. Fix: add -4 / +4 around that call. The same pattern in our
  own code (call ..,[d2,d3,a2,a3],16 in functions that call others: gr_upd / gr_pub / gr_ref / gr_now / wb_draw /
  sh_build) -> frame 20; calls from hooked frames (pu_hook, sc_cap, gx_map) get their own slot.
- Emulator after the fix: film change + Contrast, half-press -> status 1 (saved), LOOKS.BIN selection 2, EDITS.BIN
  and BUNDLES.BIN written; booting from that card: LIDX 2 again. (The camera keeps its own picture mode itself.)
- Package fx3: E1479999.BIN db189ca6…, GUIDES.BIN 1edf66bd…, LABELS.BIN d6c1b4ab… (card not connected).
- **Camera (owner, 2026-11-08, fx3): "it works perfectly!"** Settings and the film choice are kept over power off /
  on. With fx1 / fx2: the film shows on the screens and in the viewfinder, Picture Mode opens on the top row, Frame is
  gone, Shading's number is in line, the strips show all options, Glow + / - right. **fx3 is camera-tested** (the
  v0.25 candidate: E1479999.BIN db189ca6…, GUIDES.BIN 1edf66bd…, LABELS.BIN d6c1b4ab…). Not released yet: releases
  /v0.25 on the branch still holds rc2c's files and must be rebuilt from this build before a release (owner's go-ahead
  needed). Next (owner): update the Control Panel and the film sims.

## The camera's 20 film sims, rewritten (2026-11-08; preview + emulator, camera test pending)
- Owner: the 20 films on the camera in a fixed order, the same order in the Control Panel, rewritten with every
  setting now mapped: 1 Portra 400, 2 Gold 200, 3 Kodachrome 64, 4 Portra 800, 5 CineStill 800T, 6 Ektar 100,
  7 Ultramax 400, 8 Pro 400H, 9 Velvia 50, 10 Superia 400, 11 ColorPlus 200, 12 CineStill 400D, 13 Fuji C200,
  14 Ektachrome E100, 15 Reala 100, 16 Provia 100F, 17 Vision3 250D (250D / 50D), 18 Fuji Eterna, 19 Astia 100F,
  20 Agfa Ultra 100. FILM n = LOOKS.BIN record n - 1 (COLOR (n - 1) / 5 + 1, look (n - 1) % 5 + 1).
- webapp/scripts/films.py: the 20 recipes rewritten at the top of FILMS (single sectors where it matters, e.g. skin
  = O, OR; WB A-B / G-M, Blacks / Whites, Contrast, Shadows / Midtones / Highlights, Sharp); `CAMERA` = the order
  (om3films.json 'camera'). Renamed: Fuji 400H -> Pro 400H, Superia Reala -> Reala 100 (aliases keep older looks'
  film). New: Fuji Eterna (the motion-picture film; 'Eterna' stays as Fujifilm's cinema mode). No grain, Glow /
  Clarity, Art Effects, Shading or NR in the films (user's choice); lens vignette correction off as every look.
- Tuned by eye on the Control Panel preview (approximate; analysis): contact sheets of the 20 on 7 sample photos.
  Kodachrome 64's Shadows -3 crushed the blue-hour scene: -2.
- Control Panel: the look list is one list FILM 1-20 (no COLOR 1-4 groups; owner); the film browser shows "The 20"
  first in FILM order, the rest under "More"; first visit and "Reset looks to standard" give the 20 in order.
  Tests (om3) pass. looklab/ not rebuilt yet.
- LOOKS.BIN (Control Panel export, fw 24): b7e4262a…. Emulator (fx3 build, GUIDES / LABELS fx3): the Picture Mode
  list shows FILM 1-20; FILM 1 "Portra 400" Contrast -1, Sh +1 Mid +1 Hi -2; FILM 9 "Velvia 50" Contrast +2, Blk -1;
  FILM 20 "Agfa Ultra 100" Contrast +1. On the owner's card as LOOKS.BIN and LOOKS.NEW, checked by checksum; the old
  LOOKS.BIN / .NEW / EDITS.BIN kept in the session scratchpad (not in the repo). Old EDITS.BIN changes drop by
  themselves (each carries a CRC of the film record it came from). No firmware change.

## Halation on the E-P7: how cakelesscoder did it (read 2026-11-09, their repo 685531c; analysis only, nothing built here)
- Source: github.com/cakelesscoder/caduceus-ep7 (Apache-2.0), docs/HALATION_RED.md sections 14-17, patches/halation
  (hl.s.in), v0.31. Read only; their repository was not changed.
- Their result: **camera-tested on the E-P7** (h1): CineStill 800T shows a red / orange halo around an LED strip.
  h2 (a Halo Off / Low / Med / High control) is emulator only on their side.
- How: a CPU pass over the finished photo, on the CPU grain route (Soft Focus blend hook, after the blend, before the
  grain). That route was ported from our OM-3 CPU grain (xb_gs / xb_open window / mapper), so the OM-3 already has it.
  A. read Y (every 2nd pixel, every 4th row), sum how far it is above a threshold into a 64 x 64 px cell grid (u8,
     one malloc <= 16 KB); B. blur the grid ([1 2 1] twice per axis) and soften it (knee); skip when a third of the
     cells glow (bright daylight stays fast); C. on rows near lights, add the glow to Y and push the chroma toward red
     / amber / warm / cool, fading on bright pixels so light cores stay white.
- Buffer: 2 bytes per pixel, pixel pair = Y0 Cb Y1 Cr, chroma offset-binary (camera-proven on the E-P7 by the red halo).
  **Not proven on the OM-3** (our CPU grain writes Y only): the first OM-3 test needs a swap fallback, as theirs had.
- Cost on the E-P7 (their estimate): about 1-2 s more per photo at night, about 3 s near the cap, on top of the Soft
  Focus passes; ~1.8 KB of code in 7 places.
- For the OM-3 (analysis / guess): feasible on the same route as our Glow row (which already runs the Soft Focus
  passes). Code must be our own (credit them in NOTICE / README). Space: GUIDES.BIN is full (16308 / 16448), ext11
  has ~3 KB left, so the pass would go in ext11 and call the block's xb_open / mapper through the block entry table.
  Rules: halation is an effect the user adds (like Glow), not part of the film sims. Open: control (a Halo row, or a
  Glow colour), and the OM-3 chroma byte order.

## Split toning probe st1 (2026-11-09; emulator only, camera test pending; branch experiment/split-tone-probe)
- Owner: halation parked; split toning next. Plan: (1) probe the mechanism on the camera with fixed values, (2) then
  per-look bytes, a Picture Mode row and the Control Panel.
- st1 = fx3 (v0.25 candidate) + st_run (ext11, ~260 B; ext11 now ends 0x60f58d43 of 0x60f59800). Tone hook's exit
  `jmp tone_next` -> `jmp st_run`, which ends with the displaced `mov d3,a0; jmp tone_next`. The gamma stage
  (copier 0x60516c8d) runs before the stage list that holds the tone hook, so the job's R/G/B tables are there.
  Bend per channel as model.py (Ks, Kh s8, >> 8) over all 320 entries (256 + the 64-entry fine table: the bend is a
  function of the value, so both stay consistent). Gates: key 11 (or 12 with +1731 0); effective COLOR profile 4
  (getter 63153) only; R, G, B tables identical before (one curve copied three times = stock COLOR; after our bend
  they differ, so a repeated pass or a skipped copy never bends twice; art curves are left alone).
  Probe tint: Ks (-66, 5, 121) teal shadows, Kh (57, -5, -124) orange highlights.
- Emulator (research/splittone/probe_test.py; stock stage on a synthetic COLOR still, then tone -> st_run, then
  tone only again; sess7 ncall now takes '=expr' values): COLOR 1: R = G = B (untouched). COLOR 4: toned, curves
  rising, grey tint Cb +6.7 / Cr -4.5 at input 16, Cb -6.7 / Cr +3.7 at input 128, white and black unchanged;
  the second pass leaves it as it was (no double bend). Bug found on the way: the test's request id bytes
  (R+8.. must be 00 00 0b 00).
- Package st1: E1479999.BIN 337bb2ff…, GUIDES.BIN 0457541…, LABELS.BIN d6c1b4ab… (= fx3). Not known: whether the
  ISP uses these tables for the photo (camera test), whether live view shows it.
- **Camera (owner, 2026-11-09, st1): it works.** Owner: "if there was one, it was very very subtle". Measured
  (PB091535 COLOR 3 / PB091536 COLOR 4, same exposure 1/40 f1.8 ISO 1000, manual WB, tungsten-lit room; aligned by
  phase correlation, shift -9/-10 px at 1296 wide, r = 0.992; binned by Y): COLOR 4 - COLOR 3 =
  Y 30-60 Cb +4.6 Cr -4.1, Y 60-90 Cb +5.5 Cr -4.1, Y 90-120 Cb +4.8 Cr -2.8 (teal shadows / low mids), Y 160-200
  Cb 0 Cr +1.2, Y 200-235 Cb -3.3 Cr +1.0 (warmer highlights), black and white ~0. Close to the emulator's
  prediction in the shadows (Cb +6.7 / Cr -4.5 at the curve's input 16), about half in the highlights (this scene's
  highlights were already strongly yellow, Cb -36). Mids Y +3..+5. **So the ISP uses the job's R/G/B tables for the
  photo: split toning by curve bending is camera-proven.** Not answered yet: live view (owner could not tell).
- Conclusion: the probe strength (~5 Cb/Cr units) is too subtle to see; the feature needs a range up to ~3x
  (Cross Process I reaches ~23 at its peak). Photos not kept in the repo (owner's).
- Owner (2026-11-09): strength about 3x the probe; control = **two colour wheels**, one for shadows and one for
  highlights, each setting colour and strength. Design (proposal, analysis): reuse our HSL wheel editor (it already
  hosted non-HSL pages: Looks page axis 4, Extras page axis 5 with per-sector settings in v0.20-v0.22) for two new
  pages / rows "Shadows" and "Highlights": front dial = colour (12 wheel colours), rear dial = strength 0..5, one
  colour active per wheel. Storage 4 bytes per look (hue, strength x 2): LOOKS.BIN record +53..+56 (firmware's
  range check to widen), EDITS.BIN the same, slot bytes to pick. Engine: st_run with K from a 12-hue table scaled
  by strength, max ~24 Cb/Cr units at the peak (>> 7 or wider K), running max to keep curves rising. Control Panel:
  two wheels (angle = colour, distance = strength) + preview (model.py). Space: ext11 ~2.7 KB left after st1;
  GUIDES.BIN full.

## v0.25 released (2026-11-09; owner's go-ahead)
- Owner: release v0.25 with everything (not split toning). releases/v0.25 rebuilt from the branch (= fx3, rebuilt byte
  for byte: E1479999.BIN db189ca6…, GUIDES.BIN 1edf66bd…, LABELS.BIN d6c1b4ab…); `patch.py --release v0.25` makes
  db189ca6… again. New: the release also carries the 20 film sims as an optional LOOKS.BIN (b7e4262a…; the workflow
  now attaches LOOKS.BIN when a release folder has one). main merged into the branch first (v0.24.1 release commit;
  the branch already held its changes; conflicts taken from the branch).
- Docs: CHANGELOG, release notes with the 20 films, README (features, Control Panel step by step, the 20-film table,
  the rows), USING.md, DEVELOPER_NOTES. Control Panel text: the Glow row is "+ Glow, − Clarity". looklab rebuilt.

## Split toning sp1: two wheels (2026-11-09; emulator only, camera test next; branch feature/v0.26-split-tone)
- Owner: "two wheels ... set the color and strength of the tone", the wheel's 12 colours, about 3x the probe.
- Engine (st_run, ext11): K = st_k[colour] x strength per channel (st_k: 12 colours x R G B, 4.8 Cb/Cr units at the
  weight peak per step; colours as HSV hues Y 60, O 35, OR 18, R 0, M 310, V 270, B 235, BC 205, C 180, GC 155,
  G 120, YG 85); slot +55 / +56 Shadows colour 0..11 / strength -5..5 (minus = the opposite colour), +57 / +58
  Highlights, of the effective COLOR; both 0 -> nothing. Curves kept rising by a running max (the 256 and the 64
  entries apart). Probe gate (COLOR 4) gone.
- Wheel pages: axis 5 Shadows, 6 Highlights; INFO cycle Color -> Color All -> Hue -> Luminance -> Shadows ->
  Highlights -> Color (k_step, W_TONE). sl_get / sl_set misses go to tn_get / tn_set (ext11) and the wheel drawing's
  48 reads to tn_poly (build.py) before ed_get / ed_set / ed_poly. A colour reads its strength when it is the page's
  colour, else 0; setting a non-zero value makes that colour the page's (with that strength), 0 on the page's colour
  turns it off. tn_get also restores the camera's dial label on the Color pages (else "Highlights" stayed there).
- Labels: dial label "Shadows" / "Highlights" (LABELS.BIN labels 27 / 28, XL_N 29, xb_vl); guide "Tone [INFO]"
  (GUIDES.BIN stream 3, the hidden Extras page's slot; 2836 B), gd_set maps pages 5 / 6 to stream 3.
- Files: LOOKS.BIN record +53..+56 (pf_lo -12 / -5 / -12 / -5; pf_bt pairs 53..56 <-> slot +55..+58, moved to ext3;
  pf_capto copies through pf_bt now, so EDITS.BIN and the '*' include them); BUNDLES.BIN ranges +55 0..11, +56 -5..5,
  +57 0..11, +58 -5..5 (build.py range_table). Older firmware rejects a LOOKS.BIN with these set (Control Panel
  "v0.26 or later" export only).
- Sizes: ext11 63552 of 65536, GUIDES.BIN 16068 of 16448, LABELS.BIN 12700.
- Emulator (outsp1): engine (research/splittone/probe_test.py with slot bytes): Cyan 5 / Orange 5 -> grey at input 16
  Cb +2.2 Cr -16.7, input 128 Cb -15.1 Cr +7.1, black / white unchanged, rising, second pass unchanged; strengths 0
  -> untouched; strength 11 clamped to 5. Pages: INFO reaches axis 5 / 6, the rear dial sets colour + strength, the
  front dial moves the cursor only; dial label descriptor "Shadows" 1380 B / "Highlights" 1804 B, guide 2836 B, the
  stock label back on Color; half-press save status 1; BUNDLES.BIN keeps 0/2/11/1 over a reboot; a film's values
  from LOOKS.BIN load with the film, changes kept over film switches and written to EDITS.BIN record 0.
- Control Panel: Look.split {sh_color, sh, hl_color, hl}; export "v0.26 or later (split toning; test build)" (fw 25)
  writes +53..+56; two wheels in the editor (click a colour, strength slider); the preview bends R, G, B the same way
  (src/split.ts); films.py `split=(shadow colour, strength, highlight colour, strength)`: Portra 400 / 800,
  CineStill 400D, Vision3 250D BC 1 / O 1; CineStill 800T C 2 / O 2; Kodachrome 64 B 1 / Y 1; Pro 400H C 1;
  Superia 400 G 2; Fuji C200, Fuji Eterna GC 1 (analysis: our own, to tune on the camera).
- Package sp1: E1479999.BIN 5a49c741…, GUIDES.BIN 238f5f4e…, LABELS.BIN ee0dc195…, LOOKS.BIN 742c70b2… (the 20
  films with toning, fw 25). New camera pictures ("Tone [INFO]", "Shadows", "Highlights") sent to the owner.
- Owner (2026-11-09): the new pictures ("Tone [INFO]", "Shadows", "Highlights") "look good, but it will depend on when it is in camera": approved for the camera test, final OK after seeing them there.

### sp1 camera result and sp2 (2026-11-09)
- **Camera (owner, sp1): "it's working, but with a big bug"**: with split toning on, changing the shooting mode
  (silent mode) and then half-pressing **restarts the camera**. Owner's fixes: guides "Shadows" / "Highlights"
  instead of "Tone"; the small dial label stays the camera's ("Vivid").
- Cause (analysis / guess, not reproduced: the emulator does not run that pass): st_run bent the tables on every pass
  through the stage list with key 11 / 12, after only an R = G = B check; another pass (silent mode's half-press)
  with an output whose +1252.. are not the gamma tables (equal by chance, e.g. zero) would get 1920 B written into
  something else. sp2 gates, in order: key 11 / 12; **R+14 = 0x1000 (still development)**; **O+3172 / 3176 / 3180 =
  O+1252 / 1892 / 2532** (the copier's own pointers: the tables are real); P valid; some COLOR slot has a strength
  (only then the getter); then the profile, K, and R = G = B. Emulator: toned as sp1; R+14 = 0 -> untouched.
- Guides: TONES.BIN ('OM3S', two streams "Shadows [INFO]" 3964 B / "Highlights [INFO]" 4396 B, 8380 B; GUIDES.BIN
  has no room: its malloc cap), loaded once per power-on at the half-press load (pf_load -> fl_mk2 -> tg_load,
  then fl_mk), kept at tg_ptr (ext11 RAM). gd_set -> tg_sel puts the page's picture in the guide descriptor; gd_sel
  first puts the camera's back when ours is there (so gd_set takes the descriptor as stock again). No TONES.BIN ->
  the camera's guide on those pages. The dial label code from sp1 is gone (LABELS.BIN back to 27 labels, = v0.25's
  d6c1b4ab…); GUIDES.BIN leaves the hidden Extras stream out too (13216 B, 3.2 KB free).
- Emulator (outsp2): Hue 2708 / Luminance 4052 / Shadows 3964 / Highlights 4396 / back to the camera's 4022 on Color;
  dial label the camera's throughout; values set on both pages; half-press save status 1. Without TONES.BIN: the
  camera's guide on pages 5 / 6, no fault.
- Package sp2: E1479999.BIN 6245db90…, GUIDES.BIN 2fffcee5…, LABELS.BIN d6c1b4ab…, TONES.BIN a5cd04e9… (LOOKS.BIN on the card kept).

### sp2 camera result and sp3 (2026-11-09)
- **Camera (owner, sp2): still restarts.** Owner's recipe: adjust COLOR 1's HSL, switch to silent mode (the photo is
  taken fine), then open COLOR 1 to adjust it -> restart. Also: the '*' stays when everything is back at 0, and
  holding OK does not reset everything.
- **Reproduced in the emulator, and also on the released v0.25 (fx3 = outrel): not split toning.** Tokens
  `s1 ok ok down info info main+2 s1 wait ok down down ok right ok s1 wait ok up up ok`: fault in gr_is
  (0x60f4b29b, `movhu (4,a0)` with a0 = 0x20041001) at Picture Mode's first update. Cause: sc_cap took any holder
  that loads scene 456 as the WB grid's holder (gr_cont); the drive mode list (FUNC_DIRECT, 0x....) uses 456 for its
  bottom bar too, then goes away; Picture Mode's first update read the freed holder. Fix: gx_map keeps the state it
  sends the GUI to (gr_st); sc_cap takes the holder only when that is Picture Mode (0x0418). Emulator: the recipe
  runs without a fault; the WB row's grid shows before and after the drive mode change.
- '*': ed_isdef read slot +52..55 as a word, so a split toning colour byte (+55) with strength 0 counted as a change;
  now +52, +53, +54 and the strengths +56, +58 (not the colours). tn_set clears the colour with the strength.
  Emulator: '*' on COLOR 1 / HSL with Shadows 1, gone at 0.
- Hold OK on the wheel / COLOR n cleared slot +0..54 only: now +0..58 (split toning too). Emulator: Hue and Shadows
  back to 0.
- The still-only engine gates of sp2 stay (harmless; the silent-mode report was this grid bug).
- Package sp3: E1479999.BIN 8fdec5af…, GUIDES.BIN f1d60781…, LABELS.BIN d6c1b4ab…, TONES.BIN a5cd04e9… (as sp2).
- **v0.25 has the drive-mode restart too** (the WB grid row): fix it in the next release (or a v0.25.1).

### sp3 camera result and sp4 (2026-11-09)
- **Camera (owner, sp3): the fixes work** (no restart with the drive-mode recipe, '*' and hold-OK reset right) and
  split toning works in photos; **not shown in live view**.
- Analysis: sp2's still-only gate (R+14 = 0x1000) excludes any other pass; the restart that prompted it was the WB grid
  holder (sp3). The emulator does not run live view's image processing (no hits at tone / st_run / hl_pp while idle in
  live view), so whether live view passes through this stage is a camera question. sp4: ST_STILL 0 (the gate off);
  the copier-pointer check and R = G = B stay. Emulator: stills as before; a request with R+14 = 0x2000 is toned too;
  the restart recipe still runs clean. Open: whether live view uses this stage at all; whether its copy is skipped
  when the curve object is unchanged (then a strength change would show only after the curve is copied again).
- Package sp4: E1479999.BIN 34df5bf6…, GUIDES.BIN 1189c811… (LABELS.BIN, TONES.BIN as sp3).

### sp4 camera result and v0.26 released (2026-11-09)
- **Camera (owner, sp4): works.** Split toning shows in live view as well as in photos, and nothing broke (camera-tested).
  So live view does pass through the tone stage with the copier pointers set, and `ST_STILL 0` is right.
- Released as v0.26 from build sp4 (`feature/v0.26-split-tone`): the branch rebuilds sp4 byte for byte
  (E1479999.BIN 34df5bf6…, GUIDES.BIN 1189c811…, TONES.BIN a5cd04e9…, LABELS.BIN d6c1b4ab…), and
  `patch.py --release v0.26` reproduces the same files. Optional LOOKS.BIN e742c70b… (the 20 films, fw 25 export).

### The 20 film sims: tuning draft 1 (2026-11-09)
- The owner tuned the 20 in the Control Panel from colour checker photos (fixed light, one photo per film) and sent the
  set as a looks link. Taken into `webapp/scripts/films.py` as `TUNED` (hue / light / sat, WB, tone, split): the
  recipe still gives Contrast, `SHARP` the Sharp, and a film without a split in the link keeps its recipe's.
- Owner's choices (2026-11-09): Contrast and Sharp were 0 in the link (six names were shortened the way the old share
  codes did, which drop those settings), so the old values stay; Gold 200's Sharp −1 was set by the owner and is kept.
  Seven films without a split tone in the link (Portra 400, Kodachrome 64, Pro 400H, Superia 400, CineStill 400D,
  Fuji C200, Vision3 250D) keep their old one. Checked: every film's colours, WB, tone and split equal the link's
  apart from those.
- Status: Control Panel defaults only (live 2026-11-09); the v0.26 release's optional `LOOKS.BIN` is still the
  earlier set.


### WB -7..+7 in LOOKS.BIN: test build wb7 (2026-11-09)
- Owner: the camera's WB shift goes −7..+7; the Control Panel stopped at ±5. Found (code): `pf_lo` limits LOOKS.BIN
  record +37 / +38 (A-B / G-M) to −5..5, and the range check refuses the **whole file** when any byte is out of range
  (`pf_load` returns 1, no films). The camera's own WB row and `wb_get` already go ±7.
- Emulator: v0.26 (34df5bf6) with a LOOKS.BIN whose FILM 1 has WB +7 / −7: bank not loaded (LPTR 0); the same card
  with the normal 20 loads (control). Build wb7 (`pf_lo` +37 / +38 = −7): the ±7 file loads (LPTR set). Emulator only.
- Package wb7: E1479999.BIN dec03d2f…, GUIDES.BIN d2476a54… (LABELS.BIN, TONES.BIN as v0.26). To be v0.26.1 after a
  camera test. Control Panel (live): WB −7..+7; export "v0.26.1 or later" (fw 26) keeps it, older settings save ±5.
- Same day: the preview's grain was too strong (owner: tool Med ≈ camera High): GRAIN_S 24 / 44 / 68 (analysis from the
  owner's comparison; camera texture gains 448 / 832 / 1280).

### wb7 camera result and v0.26.1 released (2026-11-09)
- **Camera (owner): wb7 works** (camera-tested): a `LOOKS.BIN` with WB past ±5 loads.
- Released as v0.26.1 from build wb7: the branch rebuilds it byte for byte (E1479999.BIN dec03d2f…, GUIDES.BIN
  d2476a54…), and `patch.py --release v0.26.1` reproduces the same files. Optional LOOKS.BIN 26998eeb… (the tuned 20).

### fernandezk26's fork: SD loading without a half-press, and the EDITS.BIN bad-bytes bug (2026-11-09)
Fork: github.com/fernandezk26/camera-stuff (Apache-2.0), branches `sdload/v0.26.1` (tag v0.26.1.1), `wbrecall/v0.26.2`,
`wbrecall/v0.26.3`. By their own notes everything there is emulator only.
- **SD loader** (their commit 3ec4ff8, taken as is; `docs/SD_LOADER.md`): a worker task (SDLOAD, priority 56, 2 KiB)
  polls every ~100 ms until the section masks and the card word allow a load, then wakes the HLS_EVENT task, which runs
  our own `pr_gate` (same once-per-power-on gate as the half-press). Hooks 0x60af0fb9 and 0x60af101c (stock calls).
  `nm_load` / `nm_pick` / `nm_path` moved from ext4 to ext11 for room.
- **Bug they found (in our v0.26 / v0.26.1):** EDITS.BIN records saved by v0.24 / v0.25 hold heap leftovers in
  +53..+63 (the image block was never zeroed; `pf_capto` did not write those bytes then). v0.26 reads +53..+56 as split
  toning. Seen in the owner's own card files (analysis of the 2026-11-09 card copy, not in the repo): 9 of 20 film
  records with out-of-range split bytes, and BUNDLES.BIN slots 2 and 3 carrying them.
  **Emulator, v0.26.1 (dec03d2f) with the owner's card files:** choosing FILM 9 gives slot tone 45/109/237/-113 and the
  half-press save writes it into BUNDLES.BIN. **Build sd1:** the same steps give 0/0/0/0 in the slot and in BUNDLES.BIN;
  a real split tone (FILM 5: 8/2/1/2) is kept.
- **Our port of the fix** (their v0.26.3, without its stored-WB parts): `fl_mk` zeroes the whole SP_BLK; `tw_san`
  (after EDITS.BIN's CRC passes) zeroes a record's +53..+56 as a group when out of range, +57..+62, and +63 on films;
  `ed_save` runs `sd_san` (sd_check's own table) over its image before the CRC. Difference from theirs: `tw_san`
  sign-extends the strengths before the range test (theirs reads them unsigned, which zeroes every negative strength:
  worth telling them). We did not take their per-slot `sd_san` after each film load (the three above cover it).
- **Build sd1** (branch `feature/v0.26.2-sdload-ff`): E1479999.BIN 0b676068..., GUIDES.BIN 43981bd4...; LABELS / TONES as
  v0.26.1. Emulator: card block published within 500 ms with no key (`session_autoload.mjs`, masks written by the
  harness); wheel pages, split toning set, drive-mode recipe run without a stop. **Emulator only.** Only a camera can
  show: AF / shooting while the worker polls, no card, card pulled, power cycles.
- Emulator note: this om-emu has no `PlaySession.lab_created`; the scripts push the worker's entry onto
  `CA_TASK_ENTRIES` instead (`OM_WORKER_ENTRY=<sdl_worker_entry>`, 60a8f623 on sd1). Needed for every session with
  this firmware.
- Their stored WB mode / Kelvin per film (v0.26.2 / v0.26.3) is not taken yet (owner: later, and with a Control Panel
  control). Space after sd1: see build output (ext11 nearly full); halation will need room.


### sd1 first camera result (2026-11-09)
- **Camera (owner): sd1 "works and works well"** (camera-tested, first look): films load without a half-press. The owner
  keeps testing before any release; no detail yet on AF / shooting speed, no-card start, card pulled, or the films that
  had bad bytes. Not released: wait for the owner's go-ahead.

### sd1 quirks on the camera, and sd2 (2026-11-09)
- **Camera (owner, sd1):** (1) after power-on live view does not show the film's look, and the shooting screen reads
  "COLOR1*" where Picture Mode shows FILM 5 (owner's photo); (2) on the super control panel the dials on the Picture Mode
  cell step through COLOR 1–4 only, not the films (a wish, not a regression).
- (1) Analysis / guess: live view and the shooting screen are built before the worker's load publishes the block, and
  nothing rebuilds them (the half-press used to). The emulator cannot show this (it runs no live view, and its start
  screen is drawn after the load: FILM 5 shows there).
- **sd2** = sd1 + `sdl_poke` (ext11) after the automatic `pr_gate`: when the block is published and the picture mode is
  COLOR k, the wheel's cursor setting 2197 + k is re-written with its own value (GetValue + SetValue through the facade,
  the editor's own poke after an edit). E1479999.BIN 12993ce6…, GUIDES.BIN da30267c…. Emulator only: the poke runs once
  after the load, DIRTY stays 0, the session goes on (Picture Mode, wheel, half-press). Whether live view and the label
  follow is a camera question; the SetValue runs on the HLS_EVENT task, not the GUI's (watch for a hang).
- (2) not started.
- **Camera (owner, 2026-11-09), flashing from sd1:** holding OK and switching on did not start the update at first (the
  camera just started); pressing OK before switching on and holding ~10 s did. Not known whether sd1 narrows the window
  (its receive hook loads the card on the OK key message, and the worker loads early) or it was the timing of the press:
  an open question. To settle before a release: flash a few times from the released build and from sd2 and compare; if
  the loader is the cause, drop its OK trigger and delay the worker's first load.
- **Camera (owner, 2026-11-09): sd2 "works well"** (camera-tested): after power-on, with no half-press, live view and
  the shooting screen follow the selected film. No hang reported. Still open: the flash-entry question above, and the
  longer test (AF / burst speed, no card, card pulled, power cycles). Not released.

### Super control panel: dials through the films (sd3 draft, 2026-11-09; emulator only, not for the camera yet)
- Owner: on the super control panel the dials on the Picture Mode cell step COLOR 1–4 only; wanted: the films too.
- Found (disassembly + emulator WATCH): the step is 0x611c6e44 (called from 0x611c59fd). It reads GetValue(111)
  (return 0x611c6e79) as "where am I", GetValue(897) -> the key into its own table at 0x615384b4 (6 x {key, count,
  default, records}; records 20 B {0, value, 0, 0, availability id}); entry 5 = key 901, COLOR 1–4 at 0x61538464. The
  helpers 0x611c74e0 / 0x611c75ce pick the next / previous record that is available (GetValue(availability id) == 1 and
  facade vtable +40 (id, value) == 1), then SetValue(901, value).
- sd3 draft: entry 5 -> `fl_scr` (ext11: the stock four, then FV0 + j with FLB + j; build.py asserts the stock entry),
  and `fl_get` answers the film value to the caller 0x611c6e79. **Emulator: the dials now go COLOR 2, 3, 4, FILM 1, 2,
  3 … and back with wrap (FILM 20, 19 …); SetValue(901, FV0 + j) -> fl_set loads the film (LIDX follows).**
- **Not solved: the cell and the title do not redraw when the step stays on the same COLOR** (FILM 1 -> FILM 2: both on
  COLOR 1, the picture mode value stays 54; no picture / title request follows: WATCH on ic_get / st_get). Tried, no
  effect in the emulator: (a) the editor's poke (SetValue 2197 + k with its own value) from fl_set; (b) the manager
  called twice (another COLOR, then COLOR k). (c) Answering the film value to the GUI's value cache (GetValue from
  0x610fd979) made it worse (the cell has no choice for an unknown value; the title stuck). Next idea: teach the
  panel's cell the film values (its value -> picture / title choice tables, as fl_l0..2 did for the Picture Mode screen),
  then (c) becomes right. The panel's own redraw after a step: 0x611c5a68.. (`0x611c65ec`, `0x612970e8` with 8000).
- Space: ext11 65248 of 65536 with the draft.

### sd3: the super control panel's label follows the film (2026-11-09; emulator only)
- Why nothing redrew: the panel's update (0x61157c..: widgets 200..204 from its model bytes) sets the Picture Mode
  cell's choice with `call 0x6128abe0` at 0x61157d30 (a0 widget, d0 16..19 for COLOR 1–4), and the title's string id
  (2755 / 2756 / 2757 / 4769) through 0x6128b0fd -> 0x6128b1d3 `call 0x6128ab86,[],4` (found with a value trace:
  sess7 `WVAL=2756 WRANGE=610c0000,612a0000`). Both setters do nothing when the value is the one they hold, and a film
  step inside one COLOR changes neither.
- Fix: `fl_set` sets two flag bytes (`fl_scf`, `fl_scf + 1`) when a film is switched. `fl_scw` (hook `.hook_scw`,
  0x61157d30, the same 7-byte call) sets the neighbouring choice (d0 ^ 1) first when the flag is up, then the real
  one; `fl_stw` (hook `.hook_stw`, 0x6128b1d3: the 5-byte call + its 3-byte `jmp 0x6128b2c6` replaced by `jmp fl_stw`
  + 3 nop) sets another of the four title ids first. The pictures / the name are asked again (fl_scp / fl_tt).
- **Emulator:** dials on the cell: COLOR 1 -> 2 -> 3 -> 4 -> FILM 1 (Portra 400) -> FILM 2 (Gold 200) -> FILM 3
  (Kodachrome 64), back, COLOR 4 ("Color Profile 4"), and before COLOR 1: FILM 20 (Agfa Ultra 100); cell and title
  right at every step; Picture Mode then opens on FILM 20 and the shooting screen reads FILM 20.
- Build sd3 = sd2 + this: E1479999.BIN / GUIDES.BIN checksums in the commit message. ext11 65392 of 65536 (144 left).
  0x6128b1d3 is a general text-widget path (every title set through 0x6128b0fd goes through fl_stw's flag test).

- **Camera (owner, 2026-11-09): sd3 "looks good so far"** (camera-tested, first look; the owner keeps testing). Not yet
  reported: whether the flash started on the first try, and titles elsewhere in the menus. Not released.
- **Camera (owner, 2026-11-09):** flashing sd3 from sd2 started normally ("flashed fine"), nothing odd in the menus so
  far. So the one failed start from sd1 looks like the timing of the press, not the loader (one good flash from a
  loader build; keep an eye on it).

### Grain + RAW+JPEG: the camera goes black after the photo (owner, 2026-11-09, on sd3)
- **Camera (owner):** with image quality RAW+JPEG, a photo with Film Grain (Low, Med or High alike) is saved, then the
  screen goes black, the camera tries to restart and freezes (battery out). JPEG only: fine. All the owner's grain
  tests so far were JPEG only. FILM 1, Contrast −1, Blk +1, WB A2, Sharpness −1 when found; the grain level does not
  matter. GitHub #12 (2026-11-09, "the image gets recorded, but then black screen and crash", glow + grain) reads the same.
- Not known: whether v0.25 / v0.26 / v0.26.1 do it too (likely: the fast grain route is unchanged since v0.25, and
  sd1–sd3 do not touch it), and why. The fast route gives a COLOR still Grainy Film II's work list and texture
  (`xb_wl`, `xb_tex`, `xb_dev`, `xb_c1e`); a RAW+JPEG capture presumably runs another development (the RAW's
  preview) or a different list through the same hooks. Analysis / guess; the emulator does not develop photos.
- The v0.21–v0.24 CPU grain was used with JPEG+ORF on 2026-11-07 (photos PB071392 / 93) without this.
- Dead end while looking for a way to tell RAW from the settings: the emulator docs' MODE_RAW (22) is about the mode
  dial's custom banks, not the image quality; the panel's image-quality cell (cursor id 861) does not open in the
  emulator. Getters during the capture are risky (v0.24's restart).
- Plan: a logging build (the fg1–fg3 GLOG logger on the current branch) and two grain-off photos from the owner, one
  JPEG and one RAW+JPEG, to see what the RAW capture adds; then keep the texture route off those requests (CPU grain
  or no grain there). Until then: grain with JPEG only.
- **Logging build lg1** (2026-11-09): sd3 with `XB_LOG 1` (not committed as the default). Firmware identical to sd3
  (836cafd6…), so GUIDES.BIN only: 43f35661…, 13756 B. Emulator: boots, Picture Mode, the half-press save runs. Run
  asked of the owner (as fg2 run 3: a row changed and back before the first and the last half-press): JPEG grain off,
  RAW+JPEG grain off, JPEG grain Low; then GLOG.BIN from the card. Afterwards sd3's GUIDES.BIN (c6b6728d…) back.
- **lg1 result (camera, 2026-11-09; GLOG.BIN decoded with `research/grain/glog3.py`):** a JPEG photo is one capture
  (key 11, 6 requests: 2 kind 0 + 4 kind 3). A RAW+JPEG photo is **two captures**: the same key-11 one, then a second
  with **key 2** (context 2, 4 requests) at 3200 x 2400 (request +1100 `0c80`/`0960` against `1440`/`0f30`): the
  RAW's preview JPEG (analysis). All key-11 requests are configured before the second capture's mark.
- **Fix try rj1 (2026-11-09, analysis / guess until the camera says):** the grain state is global and every job reset
  it: `xb_su` cleared `xb_tx` and moved `xb_S`, `xb_wl` cleared `xb_sw`, also for the key-2 job, while the JPEG's
  textured job (Grainy Film II's list, combiner 1 answered by `xb_sel2` only while `xb_tx` = 2) may still be running.
  Now only a COLOR job (job+5352 = 11) touches that state; and since the state can then outlive other jobs,
  `xb_dev` (attached case) and `xb_sel2` also require the request key 11. GUIDES.BIN only: 13248 B, sha256 70139a8f…;
  firmware unchanged (836cafd6…, = sd3). Emulator: boots, block loads, films step (it cannot develop a photo).
  On the owner's card 2026-11-09 (checksum verified). Test: RAW+JPEG with Grain; JPEG-only Grain; a non-COLOR
  picture mode after a grain photo. If it still freezes: log the order of `xb_cap` / `xb_wl` / `xb_su` calls.
- **rj1 camera result (owner, 2026-11-09): works; all four checks run** ("It took them and I did try all those").
  Photos on the card, centre-crop fine-detail measure (residual against a 3x3 blur, 8-bit rms): PB091584 RAW+JPEG
  light grain 8.6; PB091585 RAW+JPEG heavy grain 23.0; PB091586 JPEG only heavy grain 22.8 (same as the RAW+JPEG
  one); PB091587 JPEG no grain 5.1; PB091588 RAW+JPEG no grain 5.3 (clean after the grain photos). Each RAW+JPEG
  shot has its ORF. Keep rj1's GUIDES.BIN (70139a8f…) with sd3's firmware; goes into v0.26.2.

### sd4: "FILM N" missing from the shooting screen when COLOR k itself is changed (owner, 2026-11-09)
- **Camera (owner):** "if color profile 1 has had edits made, it shows up on the viewfinder for any of the film sets":
  the screen reads COLOR 1 (with its '*') instead of FILM N. Not caused by the rj1 grain change (firmware was sd3's).
  The owner's EDITS.BIN had record 20 (COLOR 1's own settings) valid with its changed flag (+63) set.
- **Found (disassembly + emulator trace with the owner's card files):** the shooting screen's label builder
  (0x61234c9d..) asks "COLOR changed?" (0x6129ba07, return 0x61234cb2; fl_pmod answers COLOR k's own flag there) and
  on 1 swaps in the '*' pictures **15710..15713** for COLOR 1–4. ic_get sent only 15706..15709 to fl_lvp.
- **Fix (sd4):** ic_get sends 15706..15713 to fl_lvp, which takes k = (id - 15706) & 3. A film reads "FILM N" on the
  shooting screen whether or not COLOR k's own settings are changed (no '*' there for a changed film: not drawn yet).
- **Emulator (owner's card files):** the request for 15710 now reaches fl_lvp and fl_sp draws FILM 1, FILM 2 after a
  switch. Build sd4 = sd3 + rj1 + this: E1479999.BIN 4add99d3…, GUIDES.BIN 92b67919… (13248 B); ext11 65392 of 65536.
  On the owner's card 2026-11-09 (DCOLYMP + OM3MOD/GUIDES.BIN, read back and checked by sha256). Camera: pending.
- **Camera (owner, 2026-11-09): sd4 "everything works!"** (flashed; FILM N shows with COLOR 1 changed; camera-tested).
- **Released as v0.26.2 (2026-11-09, owner: "Lets push out a .26 update"):** sd4 = `releases/v0.26.2`
  (`patch.py --release v0.26.2` rebuilds E1479999.BIN 4add99d3… byte for byte; GUIDES.BIN 92b67919…). Credit to
  fernandezk26 in the README, CHANGELOG and release notes. Not yet told to fernandezk26: their `tw_san` reads the
  strengths unsigned (ours sign-extends). Issue #12 reply: still waiting for the owner's "post it".

### Session wrap-up (2026-11-09, after the v0.26.2 release)
- Owner's camera and card are on v0.26.2 (sd4). Card cleaned by the owner (DCOLYMP empty, test files, the old backup
  folder and the test photos removed); OM3MOD holds the v0.26.2 card files and the owner's films / changes.
- Open, in the owner's hands: (1) the issue #12 reply (say the RAW+JPEG fix is in v0.26.2) waits for "post it";
  (2) a note to fernandezk26 that their `tw_san` reads strengths unsigned (not sent, not drafted).
- Open, technical: a changed film shows no '*' on the shooting screen (15710..15713 answered with the plain "FILM N");
  the one flash that did not start from sd1 (not seen again on sd2, sd3, sd4); firmware space: ext11 has 144 B left
  (halation needs ~1.8 KB: more proven space or a move into the GUIDES.BIN block first).
- Next on the list (owner): per-film WB mode / Kelvin with a Control Panel sidebar control; then halation, custom crops.
- Tool note: the Mac shell bridge could not reach the card after it was re-inserted mid-session (listing and copying
  still worked; deleting did not). A fresh session with the card already in restores it.

### Control Panel: colour chart "light box" (2026-11-09, branch feature/chart-lightbox; not published yet)
- Owner: a colour chart whose light can be changed (sun angle, brightness, shadow / cloudy, street lamp, fluorescent)
  and camera WB options "like in camera so we can see the film sims at different K values".
- Built: `webapp/src/lightbox.ts` (drawn 12 x 5 chart: greys, the 12 wheel hues at three strengths, skin tones,
  everyday colours; light = Kelvin + green/magenta tint + colour-showing factor; camera WB = Auto / Sunny 5300 /
  Shadow 7500 / Cloudy 6000 / Incandescent 3000 / Fluorescent 4000 / Flash 5500 / CWB 2000-14000 K; sun height sets
  the sun's Kelvin; Shadow puts part of the chart in blue skylight; lamps fall off from the centre). A thumbnail
  "Colour chart" after the sample photos, its controls under the thumbnails; settings kept in the browser.
- Status: a model (analysis / guess), not measured against the camera. The WB preset Kelvin values are from memory of
  the OM menu: **confirmed by the owner 2026-11-09** (Sunny 5300, Shadow 7500, Cloudy 6000, Incandescent 3000,
  Fluorescent 4000, WB Flash 5500). Custom Kelvin: a typed field (2000-14000) next to the slider (owner's ask).
- Sun: a time-of-day arc in place of the height slider (owner's ask: "an arc with times on it, noon at the very
  center"): 6 AM to 6 PM in 15-minute steps, height = 70° x sin, Kelvin from the height (2500 K at the horizon,
  5500 K at noon); the Shadow comes from the right until noon, from the left after. Tests: `webapp/tests/lightbox.test.ts`. Waiting for the owner's approval
  of the look before it goes into `looklab/`.
- **Published 2026-11-09** (owner: "I love this! Lets publish it but make it the default image"): the chart is the
  first picture and the first thumbnail; `looklab/` rebuilt on `main`.
- Same day, owner's asks after seeing it live: the sun arc gets its own fixed 300 px column (it shrank in a wide
  window); the chart is smaller with fewer colours (6 x 4 square patches: 6 greys, the 12 wheel hues, 3 skin, sky /
  leaves / brick) and, for the chart only, before and after are two pictures side by side (no dividing line; photos
  keep the line). Checked in Chromium at desktop and phone widths; not checked in Safari itself (no WebKit here).
- Then (owner, with a photo of a commercial 18-patch grey / colour card: "something like this but vertical"): the
  chart is an upright card, 3 columns x 6 rows: a wider column of six greys (white at the top), six strong wheel
  colours (red, yellow, green, cyan, blue, magenta), and three skin tones, sky, leaves, brick. Our own layout and
  colours; nothing taken from that card (no name, artwork or values). Published.
- Then (owner): the card's border and grid black (the darkest grey lifted to L* 16 so it still shows on it); on the
  chart, the light controls sit right under the chart and the other pictures' thumbnails below them. Published.
- Then (owner: "no shadow at noon ... then shadows vice versa"): the shadow follows the time of day (none at noon,
  growing to 60% of the chart at sunrise / sunset; on the right in the morning, the left in the afternoon, the sun
  being on the arc's side); the slider became an on / off tick. Published.
- Then (owner: "the camera wb should only affect the after"): the chart's Before picture is drawn with the light's
  own colour cancelled exactly (`renderChart(p, px, true)`), whatever the camera WB is set to; After = the camera's WB
  setting + the film. Before still follows the light source's other effects (shadow, brightness, lamp falloff, the
  street lamp's weak colours). Published.
- **Scrapped the same evening (owner: "I dont like this colorchart light tool yet. Lets scrap it ... make notes ... so
  we can recreate it ... return to just the photos with the frames being the default 1st image").** `main`: the
  Control Panel source and `looklab/` are back to the build before it (same asset files as v0.26.2's site,
  index-CsE7MpWk.js / index-CtM6tPCp.css; colour frames first). The full version stays on `feature/chart-lightbox`
  (0588953); the write-up to rebuild it is `docs/CHART_LIGHTBOX.md`; ROADMAP: Parked.

### Research: the film / colour profile in the photo's EXIF (2026-11-09; no code, analysis from photos + firmware tables)
- Owner: "how possible would it be to put the color profile info into the exif data?"
- **What the camera already writes (camera photos PB091585 / PB091587, maker notes decoded by hand; "OM SYSTEM" header,
  CameraSettings IFD 0x2020):** PictureMode 0x520 = 9 (Color Profile 1) or 2 (Natural); PictureModeContrast 0x523,
  PictureModeSharpness 0x524, NoiseFilter 0x527, the tone levels 0x52e (Sh / Mid / Hi), and at 0x539 fourteen values =
  {-5, 5, then the 12 colours' saturation}: so the film's Saturation wheel, Contrast, Sharp and the Sh / Mid / Hi curve
  are in every photo today. **Not there:** the film's number or name, Hue, Luminance, split toning, Blk / Wht, our
  grain (0x538 reads 0: our grain is not the camera's setting), Glow, Shading. WB shift: not checked.
- **Empty fields with room (same photos):** ImageDescription 0x010e = 32 bytes, blank; UserComment 0x9286 = 125 bytes,
  blank. (Artist 0x013b and Copyright 0x8298, 64 bytes each, hold the owner's Copyright Info settings.)
- **Firmware:** the EXIF writer is table-driven. Table of 12-byte entries {tag, type, count, offset into an EXIF data
  block} at 0x6062abc0.. (main block): 0x010e -> 32 B at block +0x5a8; 0x9286 -> 125 B at +0xf7c; 0x013b -> +0x568;
  0x8298 -> +0xf12; 0x02bc (XMP) 2301 B at +0x612; 0x927c maker note at +0xf78. Pointers to the entries at
  0x6062c66c.. / 0x6062cf18... Not found yet: where the block lives and which routine fills +0x5a8 / +0xf7c for a shot.
- **Text is at hand:** LOOKS.BIN carries 20 x 16-byte film names at 1312 (card/mkprofiles.py), the 64-byte record
  holds the settings (53 used bytes).
- **Idea:** at capture (xb_cap already runs there, in the GUIDES.BIN block, ~3 KB free; ext11 has 144 B) copy
  "FILM n name" into the block's ImageDescription (32 B) and a compact code of the whole look into UserComment (125 B:
  an 8-byte "ASCII\0\0\0" prefix + up to 117 characters; 53 bytes as base64 = 72 characters). The Control Panel could
  then read a photo and rebuild the film. Fixed-size fields only, so the file's layout does not change.
- **Open / risks:** find the fill routine and the block (the emulator cannot take a photo: camera tests); check the
  ORF gets the same fields; check what apps show (Description / caption, User Comment); the stock blank value (spaces or
  zeros) must be matched for a COLOR with no film. Status: analysis / guess, nothing built.
- **EXIF research, step 2 (2026-11-09, disassembly only; owner: JPEG only is enough, "important for sharing, and
  sorting of images"):** the two routines that fill the EXIF data block are found.
  - **Set-up, about 0x60455f30..0x60456040** (block pointer at `(4,sp)`): Make = `call 0x60458165` (a0 = block + 1480,
    d0 = 24, d1 = setting 11073: "copy a string setting"), Model = block + 1504 (17, setting 25329), Software = block
    + 1522 (32 B, from the constant "Version x.x" at 0x6062e194 through `0x6045812d`, digits patched in), then
    **UserComment: block + 3972 (= 0xf7c + 8) filled with 117 spaces** (the loop at 0x60455ff7..0x60456007), then
    the XMP packet (block + 1554, 2301 B zeroed, strings appended with 0x60024867).
  - **Per shot, about 0x60457500..0x60457578** (block pointer at `(8,sp)`): when setting 24305 (Copyright Info) is on,
    Artist = `0x60458165(block + 1384, 64, setting 24321)` and Copyright = `(block + 3858, 64, setting 24337)`. It
    reads settings with the stock getter 0x60063380, so the getter is usable in that task.
  - `0x603dafa1`: image handle (d0) -> its EXIF block (a0), used by 0x6055bc0e (copies Artist / Copyright from one
    image's block to another's).
  - ImageDescription (block + 0x5a8, 32 B): no writer found; it stays as the block is cleared (blank in the photos).
  - **Hook idea:** at 0x60457578 (right after the Artist / Copyright copy; `mov (8,sp),a0` + `movhu (37666,a0),d0`,
    2 + 6 bytes) jump to our code with the block in a0: film on COLOR k (as fl_lvp decides) -> "FILM n name" into
    block + 0x5a8 and the recipe text into block + 3972 (117 characters); no film -> leave both as stock.
  - **Next step (not built):** a camera probe that writes a fixed test text into both fields at that hook, to prove
    the hook runs for every JPEG and to see what the Mac / phone apps show. Then the real text. Space: ext11 144 B
    (enough for the probe's jump and a short copy; the real code goes in the GUIDES.BIN block).

### Control Panel: look format version and minimum firmware (2026-11-09; published)
- Owner (from a comment): add `"schema": "caduceus-om3-look/{n}"` to each look's JSON and a `"min_fw"` field.
- Built: `LOOK_SCHEMA` (pack.ts; parseLook accepts no schema or format <= 1, refuses higher with "reload the page",
  refuses unknown strings), `minFw` / `bankMinFw` / `exportLook` / `FW_NAME` (om3.ts). Rules: WB past ±5 0.26.1,
  split toning 0.26, NR High 0.24.1, Sharp below -2 0.22, Film Grain or lens correction off 0.21, else 0.20. Links
  (op1_ / ob1_) and the .om3.json file carry them; the bank object gets `min_fw` too. LOOKS.BIN unchanged.
- Checked: unit tests (format and rules), and in a browser: the site's link has schema / min_fw first; an old link
  without them opens ("needs Caduceus v0.26.1 or later" for WB +6); a format-2 link is refused with the reload message.

### Parity with Caduceus for the E-P7 (2026-11-09; read only, nothing changed in their repo)
- Owner: compare both repos and show what both have, what aligns and what doesn't; "if this is going to be a tool,
  we will need to keep it on parity". Read cakelesscoder/caduceus-ep7 at 78dbbc4 (v0.31b) as data, ours at edbb130.
- Result: `docs/PARITY.md` (49 features: 12 same, 18 both but different, 11 E-P7 only, 6 OM-3 only, 2 neither) and a
  page published for the owner (artifact "Caduceus Parity"). Source data + generator: `research/tools/parity/`.
- Key findings: their AGENTS.md asks ports to keep one look format, one set of share codes and one panel hosted in
  their repo; their panel copies our om3.ts / om3names.ts / split.ts / om3films.ts unchanged (synced to our v0.26.1)
  and opens our op1_ / ob1_ links; ours went OM-3 only and no longer opens their pk1_ / look codes. Today's
  schema / min_fw (pack.ts LOOK_SCHEMA, om3.ts exportLook) is not in theirs: their next sync of om3.ts will need
  LOOK_SCHEMA. Open question there: hue direction may be opposite on the two bodies.
- Any message to cakelesscoder (issue / PR) is the owner's call; nothing sent.

### Review of PR #26 "Assignable up key (▲)" by ryanbughuang (2026-11-10; not merged)
- What it is: research only (`research/BUTTONS.md`, `research/upkey/`), a script that lays an up-key patch onto the
  v0.26.2 release files; nothing in `firmware/` or `releases/`. No firmware, disassembly dumps, camera graphics or
  personal data in it (the ▼ picture is read from the emulator at build time). Contributor reports it camera-tested
  on their OM-3 on v0.26.2 (▲ row, picker, ▲ itself with ▶'s functions, films; FILM 17 picture bug found and fixed).
- Rebuilt here from the PR (branch pr-26 at 314346b) with our toolchain and v0.26.2 from `patch.py --release`:
  **E1479999.BIN be17717a…, GUIDES.BIN 5c06ddb1… = the contributor's final camera-tested package, byte for byte.**
  3577 main bytes differ from v0.26.2.
- Code read: `up_get` (hook 0x610833b3) restores the 5 stock bytes and calls the getter with the stock frame
  (`call 0x61085dbb,[d2,a2],24`, as at 0x610834b2), returns with the routine's own `ret [d2],8`; `up_ic` (hook
  0x610f5611, replaces our `jmp ic_get`) uses ic_get's convention (`retf [],0`) and picture id 0x7fe0, clear of ours
  (0x7f80..0x7fc3). Looks right.
- Emulator (om-emu, v0.26.2 card files): boots, our code block loads, `get:50` = 3341 (Exp comp), `get:158` = 1.
  om-emu's `up` key in P mode reads **sid 1280** (and `right` reads 1283), on stock v0.26.2 too: om-emu routes keys
  through the 128x set, so it cannot show the stills ▲ path (camera result stands). With the PR, 1280 now follows
  arrow-pad mode 1279 (stock: always Exp comp): in om-emu ▲ opened the AF-area screen instead of Exp comp.
- Before it could ship (owner's call): (1) the extra 4 KiB of section 6 (0x60f59800..0x60f5a800) is past our
  probe-proven space (CLAUDE.md rule): the code there ran on their camera, GX1 saw nothing write that RAM, but a
  longer run (photos, video, Wi-Fi) or a probe is needed; (2) sid 1957's borrowed entries (test only, as the PR
  says); (3) move it into `firmware/` (editor.s / build.py) and plan the space with our next features; (4) the sid
  1280 branch changes the up key wherever 1280 is read (the PR calls it movie, "not done yet"): camera-check movie
  mode's up key in each arrow-pad setting; (5) only one camera so far.

### Freeze report: Clarity + grain (Reddit Grand-Temperature763, GitHub #12 codefist) (2026-11-10)
- Reports: on v0.26.2 (JPEG only), Grain Low + Glow row −2 / −3 (= Clarity) -> photo taken, black screen, camera off;
  Glow +3 fine. After that first crash, **Grain alone (Glow 0) kept shutting the camera off on every film, even after a
  battery pull**; without grain fine; camera hot. Earlier in the same thread, after one re-flash, grain and glow did
  nothing at all (likely a firmware / GUIDES.BIN mismatch, fixed by the next flash: analysis). #12 (closed):
  codefist on v0.26.1, "negative glow 'clarity' and low grain", same symptom.
- **Owner's camera, v0.26.2, FILM 1, 2026-11-10 (camera-tested): no crash in any of the five.** Centre Y high-pass
  (no grain ~5): PB101596 Grain Low, Glow 0: 8.1; PB101597 Low, Glow +2: 7.1 (glow softens); PB101598 Low, **Glow −2
  (Clarity): 9.2**; PB101599 High, **Glow −5**: 29.8; PB101600 Low, Glow −2, **RAW+JPEG**: 9.3 (ORF saved). Grain and
  Clarity both applied. So Clarity + grain alone does not crash here: the reporters' setups differ somehow.
- Reporter's film: hue / colour changed, NR Off, Vignette Correction On, Sharpness 0, Shading 0. Asked for their
  `OM3MOD` files and whether holding OK (reset) clears the repeat crash. Owner's card files backed up in the session
  scratchpad (cardbak-1110) before the test.
- **Install path check (2026-11-10, owner's ask after the report):** GitHub's latest release is v0.26.2; its six
  downloads equal `releases/v0.26.2` (GUIDES 92b67919…, LABELS d6c1b4ab…, TONES a5cd04e9…, LOOKS 26998eeb…, patch.json,
  SHA256SUMS). Tag v0.26.2 = f958fdb holds releases up to v0.26.2, so its Source code zip makes v0.26.2 by default.
  A fresh clone of main + `patch.py` with no options: v0.26.2, E1479999.BIN 4add99d3…, GUIDES 92b67919… (= SHA256SUMS),
  LABELS / TONES copied with it, VERSION.txt written. Control Panel "Install firmware" points to releases/latest.
  Weak spot: a GUIDES.BIN from another release fails silently (no grain / glow), as the reporter saw once; README
  quick answers now cover freezes (battery out, same-release files, Film Grain off, report with OM3MOD files).
