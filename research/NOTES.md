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
- **Reporter's OM3MOD (2026-11-10, via the owner; files kept out of the repo, copy in the session scratchpad
  `rep/files`):** GUIDES / LABELS / TONES = v0.26.2's (92b67919… / d6c1b4ab… / a5cd04e9…), so no file mismatch.
  LOOKS.BIN (f38ad600…) is their own 20 films, valid (CRC, ranges); EDITS.BIN valid, every check matching; BUNDLES.BIN
  valid, firmware fingerprint 5e8d376e (the same as the owner's). No Art Effect anywhere, no split toning.
  Films with grain: FILM 1 "Classic Chrome" edited to **Glow 5 (stored −5) + Grain High + NR Off + Sharp −2**, lens
  correction on; FILM 2 "Classic Neg" built with Glow 1 + Grain Low + NR Off; FILM 7 Glow 3 + Grain Med; FILM 14
  Glow 3 + Grain Low + NR Low. Stored values are all inside the ranges the firmware checks: nothing corrupt found.
  Next: run their three files on the owner's camera (owner's own files backed up in `cardbak-1110`); ask them for the
  camera settings that are not in these files (shutter / drive mode, image quality, ISO, IS, lens).
- **Reporter's files on the owner's camera (2026-11-10, v0.26.2, JPEG; camera-tested): no crash.** PB101606 FILM 1
  (their edit: Glow 5 + Grain High + NR Off + Sharp −2) Y hp 14.6; PB101607 FILM 2 (owner set Grain Low, Glow 1)
  8.0; PB101608 FILM 7 (Glow 3 + Med) 10.9; PB101609 FILM 14 (Glow 3 + Low, NR Low) 6.7; PB101610 FILM 1 with
  **Clarity 3 + Grain High** 25.9. Grain applied in every one. (FILM 2's own saved edit had Grain Off; the
  as-built film has Low.) Owner's files restored afterwards (checked by sha256 against `cardbak-1110`).
  => Their card files don't reproduce it on the owner's camera: the cause is in their camera's settings or unit.
- **Reporter: the crashes happen in sequential (burst) drive, mechanical shutter; Single is fine** (LSF JPEG, Auto
  ISO, 17mm f1.8 II). Burst + grain had never been tested (ft6 "not yet checked: … burst").
- **Owner's camera, bursts with grain (2026-11-10, v0.26.2; camera-tested): no crash, grain in every frame.**
  PB101635-637 (3 frames, 1/40 s), PB101638-664 (27 frames in ~2 s, 1/160 s), RAW+JPEG bursts PB101665-670,
  671-675 (Grain High, Y hp ~30 on first and last), 676-680, 681-703 (23 frames, Y hp 14.8 first / middle / last),
  704-729 (26 frames, 17.7 then 14.7). So the shared grain state does not break bursts here (my guess that it would
  was wrong for this camera). Not reproduced: remaining differences are their card (speed, fill, health), lens, or
  unit. Asked for the card.

### GX3 space probe, 256 KiB more of section 6 (2026-11-10; branch experiment/firmware-space-probe-256k)
- Why: the owner wants room for housekeeping features (Caduceus version next to OM's, a debug log from a menu), the
  up key (PR #26 needs 4 KiB), halation and quick film switching; v0.26.2 fills ext11 (112 B left).
- Build = v0.26.2 + GX2's probe, moved: section 6's loaded end 0x60f59800 -> **0x60f99800** (loader word
  0x60045e9c), `.gx` at 0x60f59800 ('GXT3' header, probe, 65400-word pattern to 0x60f99800). ext1 had no room for the
  longer call, so `pr_ed` now jumps to `gx_pr` (ext11: `call gx_go` -> probe if the header loaded -> `ed_trig`; then
  `jmp trig_resume`). GAPTEST.BIN magic 'GXR3'; gap list as GX2 with section 6's gap from 0x60f99800.
- Package E1479999.BIN 2791925c…, GUIDES.BIN c501…. Emulator (om-emu maps everything, so it only shows the code runs):
  10 half-presses -> 19 passes, bad 0 of 65400, no gap changed.
- Camera test: flash, use the camera normally (photos incl. a burst and RAW+JPEG, a video, Wi-Fi, playback, menus),
  half-press often, then read GAPTEST.BIN. Then flash v0.26.2 back with its GUIDES.BIN.
- **GX3 camera result (owner's OM-3, 2026-11-10; camera-tested): section 6 +256 KiB loads and stays intact.**
  GAPTEST.BIN 'GXR3': **72 passes, 0 bad pattern words of 65400 every pass**; the 8 gap sums (9 rounds) never
  changed. Use during the test: RAW+JPEG singles and bursts (PB101740-777, ~38 frames), a video (PB101778.MOV,
  112 MB), menus, half-presses. **So 0x60f59800..0x60f99800 is proven code space** (a build must raise the loader's
  end word 0x60045e9c to 0x60f99800). The unloaded rest of section 6's gap (to 0x6103f000) was not written by
  anything during the test either. Owner's camera put back to v0.26.2 (card checked: 4add99d3… / 92b67919…).

### Debug log dl3 (2026-11-10; branch feature/debug-log)
- Owner: a debug log to test features and check quality; chose "file on the card" (a menu command may come later).
- Build = v0.26.2 + section 6 loaded to 0x60f99800 (GX3's range, loader word 0x60045e9c) + `.ext12` at 0x60f59800
  (8720 B used of 256 KiB). `pr_ed` jumps to `lg_pr`: `lg_pre` (note DIRTY), `ed_trig`, `lg_write`, `jmp trig_resume`.
  `lg_write` uses the GX probes' card gate; the first gated event of a power-on opens `C:\OM3MOD\DEBUG.TXT` ("r") once:
  missing = off for this power-on (no further card access). On: an event {number, picture mode `sget(111)`, DIRTY before,
  STATUS after} into a 32-entry ring, then the whole report is rebuilt as text and written to `CADLOG.TXT` ("w").
  The build name comes from `firmware/VERSION` (build.py writes `lgver.inc`).
- Emulator only: with DEBUG.TXT the file is written at every event, correct counts, ring wraps (71 events -> #40..#71,
  2640 B); without it no file. pr_hook fires about twice per half-press (press and release), so the log says "shutter
  button events", not half-presses. **First try used `DEBUG.ON`: the firmware's fopen did not find it in the emulator**
  (a 2-letter extension?); `DEBUG.TXT` is found. Not checked on the camera.
- Harness note: sess7 `WATCH` on a PC where a0 holds an unmapped address (0x970000xx after fopen) stops the session with
  "CRASH GDB m970000b4": the trace's field reads, not the firmware.
- Not yet logged: shots (would need a call from xb_cap through the code block), errors inside the loaders, the time.
- Camera test: flash with its GUIDES.BIN, copy DEBUG.TXT to OM3MOD, half-press a few times, take photos, open an editor
  and change something, half-press again; read CADLOG.TXT. Then delete DEBUG.TXT and check no new log is written.
- **Camera (dl3, 2026-11-10): works.** 48 events in one power-on (13 RAW+JPEG photos incl. a burst, a film edit),
  no crash; every card file reported loaded except NAMES.BIN (optional, not on the owner's card); the edit showed as
  "edits waiting yes -> save result 1 (saved)" at #33. Picture mode read 54 throughout. **Bug: the camera's fopen "w"
  does not truncate**: a shorter report left the tail of an older, longer one after it. dl4 always writes exactly
  4096 B (text, spaces, CR LF). dl4: E1479999.BIN 71fc8fcd…, GUIDES.BIN cf6462b5…; emulator: 4096 B file, correct text.
  Same caution for any future file we rewrite with a variable length.
- Owner (dl3): the camera was on a film the whole time, yet the log said picture mode 54. Setting 111 holds the COLOR
  (54/55/56/64); the film is that COLOR's look number P+LIDX+k (as fl_get). dl5 logs COLOR k and FILM 5k + n
  (+10/+11 in each event). Emulator, LOOKS.BIN selection 3,2,0,0: "54 = COLOR 1, FILM 3". dl5: E1479999.BIN b1749259…,
  GUIDES.BIN a0c0da82…. Emulator only.
- Owner: the log should say whether the card files match the firmware, and name what does not. dl7 (VERSION "debug log
  4"): once per power-on (when the log turns on) `lg_chk` opens each of GUIDES, LABELS, TONES, LOOKS, EDITS, BUNDLES and
  reads its 16-byte header; each write `lg_vd` gives a verdict. GUIDES: pictures loaded (GPTR) = valid, code block
  (XPTR, x_load's build tag) = same build. LABELS / TONES: header CRC word vs this build's copy (build.py patches the two
  expected CRCs into `lg_ft`); a different TONES the camera refused = damaged. LOOKS: loaded (LPTR) = valid. EDITS /
  BUNDLES: written by the camera, missing = normal. Summary line "Card files: all match this firmware" or "MISMATCH",
  then one line per file; a different LABELS / TONES shows both checksums. TONES loads only after LOOKS, so its own CRC
  decides (first try called a good TONES "damaged" when LOOKS was the bad file). Report now 5120 B.
  Emulator only: matching card -> all match; old v0.26.2 GUIDES + v0.24.1 LABELS + damaged LOOKS -> exactly those three
  named. Not tried: a missing file. dl7: E1479999.BIN bece52e5…, GUIDES.BIN 11cd0b8e….
  Limits: LABELS damage after its header is not seen (the code block holds its copy); a file read once per power-on.
- **Camera (dl7 "debug log 4", 2026-11-10): works.** 24 events: FILM 4 (COLOR 1) -> FILM 6 -> FILM 9 (COLOR 2), each
  switch shown as "edits waiting yes -> saved" (a film choice is saved to LOOKS.BIN, as designed); "Card files: all match
  this firmware", all six lines right; file exactly 5120 B, no leftover text. Camera-tested: fixed length, COLOR / FILM,
  card-file check (matching case only; the mismatch cases are emulator only).

## v0.27 "buttons" release: plan and first research (2026-11-10; branch feature/v0.27-buttons)
- Owner: v0.27 is about customising the buttons: (1) all four arrow keys remappable (owner chose: ▲ ◀ ▼ ▶ in the
  camera's Button Function menu, each with the full Fn function list); (2) issue #30, both parts, shortcut first: a
  button function that opens the Picture Mode list ready for the dial, then a toggle that turns the front dial into a
  profile dial; (3) the front Creative Dial's positions (CRT / ART / COLOR / MONO) mappable to any profile (e.g. COLOR 1,
  FILM 3, FILM 10, FILM 11), **set in the Control Panel** (owner's choice; stored with the films on the card).
- The E-P7 project has no software shortcut to reuse (its quick access is the body's own profile switch;
  docs/LOOK_PICKER.md rejected a button cycle). Arrow keys: research/BUTTONS.md + PR #26 (▲ camera-tested).
- **Creative Dial (static + emulator):** sid **897 = the active picture-mode family**, one of the setting ids of the
  Picture Mode tables (0x6152f8a0): **901 COLOR 1-4**, **988 MONO 1-4**, **899 ART** (31 values), **898 CRT** (8),
  **900** (1 value; which physical position, if any, is not known). The routine at 0x602168c5.. ("picd_00n!" debug
  strings 0x602ecfab..) reads the dial with 0x601780e5(0x02021906) and sets 897 (`call 0x603f0324`, d0 897, d1 family):
  1 -> 900, 2 -> 899, 3 -> 898, 4 -> 901, 5 -> 988. Seen so far in a power-on path; whether the same code runs when
  the dial is turned is not known yet.
- om-emu: the dial is several group-4 switch bits (codes 0x1906..0x1909, set through the G4SET producer). A local
  om-emu change (`OM_SWITCH_POS`, `POSITION_SWITCH_LISTS` in src/lab/play.mjs; not in this repo) picks the power-on
  position: GetValue(897) then reads 988 / 901 / 898 / 899 / 900 for positions 0..4 (emulator only; the mapping of
  emulator positions to the physical labels is not checked). Turning it at run time (`cdial:K` in
  research/upkey/drive.mjs) does not reach the firmware yet (group 4 needs the G4SET path).
- Plan for the dial (analysis): Control Panel stores a target per position (stock / COLOR k / FILM j / MONO k);
  firmware hooks where 897 is set from the dial and, for a mapped position, sets family 901 and loads the target the
  way `fl_set` does for a film. Open: the run-time dial handler, what the Picture Mode list shows on a mapped position,
  and where the mapping lives (LOOKS.BIN header bytes 20..31 are zero and preserved, or a new file).
- Owner: the OM-3's Creative Dial has exactly **4 positions** (so family 900 is not a dial position).
- Logging build dl8 ("debug log 5, dial"): each event also records GetValue(897) (+12) and the log names it
  ("Creative Dial family: COLOR / MONO / ART / CRT"). Emulator: power-on position 1 -> COLOR (pm 54, FILM 3), position 3
  -> ART (pm 29). dl8: E1479999.BIN 20ca50c6…, GUIDES.BIN 7e966925…. Camera test: turn the dial to each position with
  the camera on, half-press at each; the log shows whether a run-time turn changes 897 and which position is which.
- **Camera (dl8, 2026-11-10): the family follows the dial at run time** (one power-on, 16 events, 4 per position):
  900 (picture mode 21) -> 899 ART (pm 40) -> 898 (pm 1) -> 901 COLOR (pm 55 = COLOR 2, FILM 9). Never 988. Owner asked
  to turn CRT -> ART -> COLOR -> MONO; which physical position gave which family is being confirmed with the owner
  (the order seen does not match that request one to one). So the hook can be on the run-time 897 change.
- **Camera (dl8, second run, owner turned CRT -> ART -> COLOR -> MONO, 4 events each): CRT = 900 (picture mode 21,
  Color Creator), ART = 899 (pm 40), COLOR = 901 (pm 55 = COLOR 2, FILM 9), MONO = 988 (pm 57).** So the four physical
  positions are 900 / 899 / 901 / 988, and each turn changes 897 at run time. The first run's 898 (8 values, pm 1)
  group is unexplained (the owner skipped MONO there); 898 is not one of the dial's positions in this run.

### Creative Dial mapping, test dm6 (2026-11-10; emulator only)
- Run-time path (om-emu `inject:1906=V`, V 1..5 = CRT 900, ART 899, 898, COLOR 901, MONO 988; trace): the dial handler
  0x610934f5.. maps the position to a family, reads GetValue(897) (0x61093558) and skips when equal
  (`cmp d2,d0; beq` at 0x6109355f), else facade SetValue(897, family) (0x6109356f) -> our `sl_set` with d0 897.
- Build: `sl_set` -> `sx_set` (ext12; 901 -> fl_set as before). 897 with a mapped position (`dm_map`, fixed for the
  test: CRT -> COLOR 1, ART -> FILM 3, COLOR -> FILM 10, MONO -> FILM 11) and the films loaded (`dm_ok`): the manager
  sets 897 <- 901, then fl_set loads the target (same SetValue context, as the Picture Mode list). `.hook_dmg`: the
  handler's beq at 0x61093560 -> displacement 2 (never skip), because after a mapped position 897 is already 901 and
  turning to the COLOR position would otherwise do nothing. (MN10300 branch displacements count from the branch
  itself: displacement 0 looped forever in om-emu, fault 7.)
- Dead end: replacing the handler's GetValue call (0x61093558) with a call to our code made om-emu stop at start-up
  (SCPU command 0x20041001), even when our code only tail-jumped to the stock getter, from ext12 or ext11. Not
  understood (likely the emulator, not the firmware); the one-byte branch change avoids that site.
- om-emu (dm6, debug log): ART -> FILM 3, CRT -> COLOR 1, COLOR -> FILM 10, MONO -> FILM 11, COLOR again -> FILM 10,
  ART -> FILM 3. Each switch saves the selection (edits waiting -> saved). The first log event after power-on read
  picture mode 0 / family 0 (once; later events right). dm6: E1479999.BIN 43a39e9e…, GUIDES.BIN 27ba6c70….
- Not done: power-on on a mapped position (start-up sets 897 before the films load: stock until the first turn),
  MONO targets, restoring the user's own COLOR choice on an unmapped COLOR position, the Control Panel setting.
- **Camera (dm6, 2026-11-10): the Creative Dial mapping works** (owner: "worked like a treat"). Log, 42 events in one
  power-on: COLOR 1 (pm 54) -> FILM 3 -> FILM 10 (pm 55) -> FILM 11 (pm 56), each switch "edits waiting yes -> saved";
  family reads COLOR throughout (897 = 901, as designed); card files all match. The first-event glitch seen in om-emu
  did not show. Eject note: Finder's Eject (button and File menu) did nothing while the card was a connected folder of
  this session; the owner ejected it himself.
- Next: the map from the Control Panel (stored with the films), power-on on a mapped position, MONO targets, and
  whether the COLOR position should go back to the user's own COLOR choice when unmapped.
- Owner: an unmapped position goes back to what it was before. dm7: `dm_own` keeps the owner's own COLOR choice
  (`dm_cur`: GetValue(901) -> COLOR k, P+LIDX+k -> FILM 5k + n) the first time a mapped position replaces it; an unmapped
  COLOR position loads it back (same manager + fl_set path) and clears it. Kept in RAM only (lost at power-off).
  Fixes: `dm_ok` no longer clobbers a1 (the SetValue's mode; dm6 did, without a visible effect); the stock path after
  `dm_ok` puts the family back in d1 (dm6 passed d1 = 0/1 to the manager when the films were not loaded).
- om-emu (dm7, test map CRT -> FILM 3, ART -> FILM 10, COLOR / MONO unmapped; start FILM 1): FILM 1 -> CRT FILM 3 ->
  COLOR FILM 1 -> ART FILM 10 -> CRT FILM 3 -> MONO (stock MONO, pm 57) -> COLOR FILM 1. dm7: E1479999.BIN 9dc1ae2a…,
  GUIDES.BIN dc9c2c9a…. Emulator only.
- **Camera (dm7, 2026-11-10): works.** 26 events: CRT FILM 3 -> COLOR FILM 18 (the owner's own pick) -> ART FILM 10 ->
  MONO (stock MONO, pm 57) -> COLOR FILM 18 again. Card files all match. Owner: no need to eject the card.
- Owner (2026-11-10, changes the earlier choice): the dial map should be set **in the camera**, in the Custom Menu
  (cog wheel) where the other button functions are set, not in the Control Panel. Plan: build it on the same menu
  work as the arrow keys (PR #26 added the ▲ row to Button Function: row list, item-info record, validator, picker).
  Until then the test map stays fixed in the firmware.

### v0.27 arrow keys, test ak2 (2026-11-10; emulator only)
- Owner chose: ▲ ◀ ▼ ▶ in the stills Button Function menu, each with the full list. Built into firmware/ (editor.s "v0.27
  arrow keys", build.py), from PR #26 (ryanbughuang, camera-tested ▲) and research/BUTTONS.md.
- **List (ar_list, 48 codes)**: the Fn buttons' 50 without the six that cannot work from an arrow (PR #26 camera test 2:
  Magnify 3352, Multi Function 436, HDR 471, High Res 755, Live ND 1709; plus Live GND 2166, same mechanism as ND),
  plus the arrows' own Flash 16, Drive 3265, Power Zoom 3409, Touch Lock 425. Names: action table 0x612f17e0 (name id =
  action + 1) and the label pictures (viewed in om-emu, not kept). Value labels: ar_lab, from 0x615685d4 (Fn) and
  0x6156855c (arrows). The picker grid (55 codes, shared by every stills key) already holds all 48.
- **Records**: validator of 53 / 51 -> ar_list (96 B); ▲ 50 takes sid 1957's validator record, row 0x6150ce78 and picker
  descriptor 0x615c73ec (key 4), as PR #26; ◀ 52 takes sid 572's (validator 0x6061a338, row 0x6150cf08, descriptor
  0x615c747c, key 10): buttons of other OM bodies, not on the OM-3. Real table slots, so nothing indexes past the
  1712-record table. Picker title icons 0x6139e26c index = key (4 -> ▲ 0x7fe0, 10 -> ◀ 0x7fe1; both blank in stock).
  Rows (mode 365) -> ar_rows [47, 48, 1292, 49, 1964, 158, 50, 52, 53, 51, 56]; item-info tree 2 -> ar_items (11; ▲ / ◀
  copies of ▶'s with our pictures; ▲ ◀ ▶ ▼ label list ar_lab, 48).
- **Rules** 0x605d9b80 (50) and 0x605d9b94 (52): third branch (Direct Function) dropped, so the assigned value stays.
  **ar_get** (.hook_ag at 0x610833b3, the dispatcher's value read): 50 / 52 by sid 158: Direct -> assigned; [·:·] -> 85;
  Off -> 3200 (▲) / 85 (◀, stock). **Release events**: the 7 states 0x5900, 0x5911, 0x5917, 0x591b, 0x5927, 0x5936,
  0x593a (the only ones with ▼ / ▶ release handlers but no ▲ / ◀) get {0x100000b / 0x1000013, 1, 1, handler} (ar_blk);
  the other 23 such states already handle all four releases alike.
- **Pictures**: ▲ / ◀ are our own drawing (firmware/mkicons.py arrow_picture: a white triangle with a grey edge, 40 x 40),
  served by ar_ic (.hook_ic -> ar_ic -> ic_get).
- **Bug found: `call 0x6...` / `jmp 0x6...` with a raw address assemble to a wrong target** (displacement from the
  section start: 0x61085dbb became 0xc1fe1c00). Camera functions must be named in editor.ld (ar_getv, ar_vget,
  ar_vback). This was also why the dial hook at 0x61093558 stopped om-emu at start-up (SCPU command 0x20041001).
- om-emu: Button Function shows ▲ and ◀ rows; with ✥ = Direct Function the ▲ picker opens the full grid ("▲ : Exposure
  Comp."), ◀ picker likewise; ◀ = Preview is stored (GetValue(52) = 106) and kept after leaving the menu. Cosmetic:
  the body diagram's pointer for ▲ / ◀ points at the ▶ key; the ✥ choice still reads "±/[·:·]/▶/▼".
- ak2 (also has the dial test map dm7): E1479999.BIN 347a1d1f…, GUIDES.BIN 6f81fdef….
- **Camera (ak2, 2026-11-10): works** (owner, photos): ▲ ◀ ▶ ▼ rows, pickers and assignments. To fix (owner):
  1. ▲ / ◀ icons too small. The camera's ▼ (0x776) spans x 2..37, y 9..32, ▶ (0x777) x 10..33, y 2..37 (40 x 40, fill
     13, outline 7, edge 9); ours were 22 px. mkicons.arrow_picture redrawn at that size and in those colours (our own
     drawing).
  2. The body diagram beside the list does not line up: each item-info record names a whole diagram picture (+20:
     0x3f7b..0x3f83 << 16 | 3, 422 x 446, highlight and leader line drawn in), ▲ / ◀ copied ▶'s (0x3f81). The leader
     line ends at the row's place on its page (7 rows a page), so inserting ▲ ◀ before ▶ also moved ▶, ▼ and L-Fn off
     their lines. Plan: diagrams for ▲ ◀ (and redrawn ▶ ▼ L-Fn lines) made at build time from the user's own stock
     pictures (never stored in the repo), as frames.py does for component 2.
  3. Owner: keep the camera's own Direct Function (▲ = Exp comp, ◀ = AF area, ▶ ▼ assignable) and add the
     all-four-keys mode as a **fourth ✥ option** (sid 158 value 3) instead of changing Direct Function.

### v0.27 arrow keys, test ak5 (2026-11-10; emulator only)
- **Fourth ✥ option "Direct Function, All Keys"** (owner): sid 158 keeps its stock values 0 / 1 / 2 (about 40 code sites
  read it). The option is stored as 158 = 2 plus a flag in sid 1966 (a button of other OM bodies: key-table event 0x54,
  none on the OM-3; 3341 = on, 3200 = off). Write: the menu's facade SetValue(158, v) reaches `sl_set` -> `sx_set` ->
  `ar_s158`: flag by the manager (1966), then 158 = v (3 -> 2) as stock (MDR restored from (68,sp) for sl_set0).
  Read: `sl_get` -> `ar_sget` answers 3 only to the ✥ choice screen and the list's value cells (callers 0x611b24f7,
  0x611b6c44, 0x611b43ad, 0x611f2707); everything else still reads 2. Validator 158 -> ar_v158 [0, 2, 3, 1]; the item
  record's labels -> ar_l158 (4); the choice screen's picker variant 0x61571c48 (key 6): count 3 -> 4, its title /
  picture / help lists -> ar_vt / ar_vp / ar_vh with ours third (title "Direct Function, All Keys", our string ST_AR
  0x7f08 via `ar_st` on .hook_str; picture 0x7fe2, our ▲◀▶▼ drawing, 104 x 40; Direct Function's help text).
- `ar_get`: Direct Function without the flag = the camera's own (▲ Exp comp 3341, ◀ AF area 85); with it, the
  assigned functions. The ▲ / ◀ rules stay without their Direct branch, so an assignment is kept either way.
- **Diagrams**: the item records' 422 x 446 body pictures are not in the firmware file as stored (not found in any
  decoded component; the camera unpacks its resources at start-up), so they cannot be redrawn at build time. Rows
  back in the camera's order with ▲ ◀ last (Fn .. ✥, ▶, ▼, L-Fn, ▲, ◀): ▶ / ▼ / L-Fn keep their own pictures and lines;
  ▲ / ◀ show ✥'s (whole pad highlighted; its line meets the list a little off). Exact ▲ / ◀ pictures would need
  run-time drawing.
- ▲ / ◀ icons now the camera's size and colours. om-emu: choice screen with four boxes, our option chosen and shown
  again on reopening; ✥ row shows ▲◀▶▼ in All Keys and the stock picture in Direct Function; 158 = 2, 1966 = 3341.
- ak5 (also the dial test map dm7): E1479999.BIN 24c5b3f3…, GUIDES.BIN a4bd2a91….
- **Camera (ak5, 2026-11-10)**, owner photos: the fourth option works; to fix: (1) with plain Direct Function the ▲ / ◀
  rows must be inactive (grey) as ▶ / ▼ are outside Direct Function; (2) the diagram lines for ▲ / ◀ still miss, and
  the owner does not want ▲ ◀ apart from ▶ ▼ (rows back to Fn .. ✥, ▲, ◀, ▶, ▼, L-Fn wanted, all lines right).
- Greying, not found yet (om-emu): while the list redraws, no facade method is called with sid 53 except the getter
  (from 0x611f2707). RANGE traces with value 53: GUI 0x610c34ad.. (a 435-entry search), 0x610c31c8 -> 0x610c71de ->
  0x610c7791 (d0 3, d1 53), 0x610f49cd loop, 0x611f2527 (row lookup by sid), 0x611af95f / 0x611f6b39 / 0x61203125
  (53, 10). Next: what makes ▶ grey under [·:·] (compare the two modes' traces), then answer "inactive" for 50 / 52
  unless 158 = 2 and the 1966 flag.
- Diagrams: plan to build the ▲ ◀ ▶ ▼ L-Fn pictures in the firmware at start-up (the stock pictures are only in RAM):
  decode a stock 422 x 446 type-11 stream row by row, move / erase / redraw the highlight and leader line by geometry
  measured from the stock pictures (numbers only, no graphics in the repo), encode into ext12 buffers, serve by ar_ic.
- Greying, more (om-emu, 2026-11-10): om-emu greys ▼, ▲ and ◀ under [·:·] (▲ / ◀ follow the same stock logic as
  ▶ / ▼). ▶ / ▼ have no rules; ▲ / ◀ rules (0x605d9b80 / 0x605d9b94, 20 B {u16 target, u16 3200, branches, 3}) are
  value maps, not greying: branch = {condition {sid 158, value}, 1, map, word}; map = 3 x {u16 to, u16 from}
  (e.g. Off: 3341 / 85 / 3200 -> 3200), so other values survive. Traces by sid 53 and by item 733 show no per-row
  "active" query that differs between [·:·] and Direct (only 0x610c755c.. in Direct). 0x611f26eb is a generic
  "value of sid" cell reader (facade +12), so it is not the greying either. The greying is still to be found.

### v0.27 arrow keys, test ak6 (2026-11-10; emulator only)
- **Owner (after ak5): drop the camera's own Direct Function arrows and keep only ours.** ✥ back to the camera's three
  options; Direct Function now means all four keys run their assigned functions and is shown with our ▲◀▶▼ picture
  (0x7fe2) in the item record's labels (ar_l158) and on the ✥ choice screen (picker variant 0x61571c48 picture list ->
  ar_vp). Titles, help text and values stay the camera's. This also settles the greying: ▲ / ◀ grey under Off /
  [·:·] by the stock logic, as ▶ / ▼, and are active under Direct Function.
- Removed: the fourth option (flag sid 1966, ar_sget / ar_s158, sl_get / sx_set 158 branches, ar_st string hook and
  ST_AR, validator change, variant count 4). `ar_get`: 158 = 2 -> assigned value; [·:·] -> 85; Off -> 3200 / 85.
  sid 1966 is no longer read (a camera that ran ak5 may keep 3341 there; harmless).
- Rows: Fn, REC, ◉, CP, AF-ON, ✥, ▲, ◀, ▶, ▼, L-Fn (owner: arrows together). The body diagram lines for ▲ ◀ ▶ ▼ L-Fn
  are off by two rows; fixing them needs run-time drawing (polish, later).
- om-emu: three boxes (Off / ▲◀▶▼ / [·:·]); ✥ row shows ▲◀▶▼; with Direct all four rows active, ▲ under [·:·] grey;
  ▲ set to Keystone Comp. -> GetValue(50) = 682, 158 = 2.
- ak6 (also the dial test map dm7; firmware/VERSION "v0.27-dev (arrow keys 4)"): E1479999.BIN 719ab357…,
  GUIDES.BIN fc5e3faa….
- **Camera (ak6, 2026-11-10): works** (owner: "that works great"). Next (owner): the Creative Dial mapping as rows in
  the same Button Function menu; then polish (diagram lines etc.).

### v0.27 Creative Dial rows in Button Function, test dr1 (2026-11-10; emulator only)
- Owner: set the dial map in the camera's Button Function menu. Four rows after L-Fn: **CRT, ART, COLOR, MONO**, each
  a button setting of other OM bodies that has row (0x6150ce18), item descriptor (group 8) and picker entries but no
  OM-3 key: CRT -> sid 571 (item 735, key 9), ART -> 54 (737, key 11), COLOR -> 55 (738, key 12), MONO -> 1966 (739,
  key 13). 54 / 55 / 1966 keep their validator records (list -> dm_list); 571 has none and takes 1967's (an unused
  movie button). No rule found for any of them (the rule run at 0x605d9b58, 25 records).
- Values DV0 3800 + code (0 Normal = the position's own mode, 1..4 COLOR k, 11..30 FILM 1..20): 25 options. Picker
  variants of keys 9 / 11 / 12 / 13 -> count 25, titles dm_tit (Normal / COLOR k / the film's name, ST_F0 + n),
  cells dm_lab (Normal 616 / "COLOR k" / "FILM n", our strings 0x7f48.., 0x7f50..), help dm_hlp (our text). Item
  records: copies of Fn's (its diagram for now) with our icons and dm_lab. Picker title icons (list 0x6139e26c, index
  = key; 9 / 11..13 were blank) and row icons: our boxed words CRT / ART / COLOR / MONO (mkicons.dial_label, ids
  0x7fe3..0x7fe6 through ar_ic), in the style of the camera's L-Fn / AF-ON names.
- `dm_get` (sl_get, the facade read for the four sids): the stored value via sget, anything not ours (other bodies'
  defaults, e.g. 1966 = 3341 left by ak5) reads Normal. `sx_set` reads the position's row instead of the fixed dm_map
  (removed).
- om-emu (sess7: drive.mjs does not start the worker, so its films never load): rows show "Normal"; CRT -> FILM 3
  picker title "Kodachrome 64", row "FILM 3"; ART -> FILM 16; dial CRT -> Kodachrome 64 (FILM 3), MONO -> stock
  MONO 1, COLOR (unmapped) -> back to the user's own COLOR 1, ART -> FILM 16. Not checked: power-off persistence;
  power-on on a mapped position is still stock until the first turn (known, dm6).
- dr1 (firmware/VERSION "v0.27-dev (dial rows 1)"): E1479999.BIN d06dce5b…, GUIDES.BIN e7ec47d8… (LABELS / TONES / BUNDLES as ak6).
- **Camera (dr1, 2026-11-10): works** (owner: "its works!!!!!!!"). Next: the polish round (body diagram lines for the
  arrow and dial rows, power-on on a mapped position, icon look), then #30.
- Owner (dr1): films stay set after power-off and on (camera). The dial rows' values "look slightly off" next to the
  stock rows; #30 waits until the buttons are polished.

### v0.27 polish 1, test dr2: the dial rows drawn like the camera's own (2026-11-10; emulator only)
- Stock row values are mostly pictures (type 0xc; strings only for a few, e.g. Off / ISO). Measured from the camera's
  pictures (viewed in om-emu, not kept): value pictures 40 px high, letters filled 13 with a 1 px outline 7 and a 1 px
  rim 8 / 9, cap ~31 (camera "Test" 0x31); button names (L-Fn 0xa4d, AF-ON 0x282c) a box 13 with border 7 and rim 8,
  the word in 7, cap 28 (rows 6..33), ~4 px strokes. dr1 used strings (thin menu font) for the values and thin
  smaller words in the icons.
- mkicons: `dial_label` (cap 28, DejaVu Sans Condensed, solid strokes) and `value_picture` (the value style) for
  Normal / COLOR 1-4 / FILM 1-20: ids 0x7fe7..0x7fff via ar_ic (descriptors ar_d7..ar_d31, ~74 KB of streams in
  ar_pay). Row values and picker cells use the pictures; picker titles keep strings (film names), as stock titles.
- om-emu: CRT / ART icons match L-Fn's size and weight; "FILM 3" / "Normal" / "COLOR 1" match "AF Stop".
- dr2 (VERSION "v0.27-dev (dial rows 2)"): E1479999.BIN 8411b7b8…, GUIDES.BIN fd06a697… (LABELS / TONES / BUNDLES as ak6).
- Card-copy mistake (2026-11-10): the ak6 copy also wrote the build's neutral BUNDLES.BIN over the owner's card file
  (the camera's saved Extras-wheel settings). By dr2 the card's BUNDLES.BIN was camera-written again (37 bytes differ
  from neutral; BUNDLES.NEW / .BAK present). Owner told. Rule added to CLAUDE.md: never copy BUNDLES / LOOKS / EDITS.

### v0.27 polish 2, test dg1: body diagrams with the right highlight and line (2026-11-10; emulator only)
- Owner: fix the lines and highlights; the CRT / ART / COLOR / MONO rows should point at the Creative Dial on the
  camera picture and highlight it.
- The stock diagrams (ids 0x3f7b..0x3f83, 422 x 446, format 14, type-11 runs with 8-bit values; background 33, line
  63 (4 px, 2 px clear margin where it crosses the drawing, corner radius ~17), highlight 80) exist only in RAM (picture
  table *(0x60379740) + 4 id). Views: 0..2 top (Fn, REC, |o|), 3..7 back (CP, AF-ON, pad, right, down), 8 side (L-Fn).
  The line ends at x 420 on rows 29 + 64 pos .. +3 (pos = the row's place on its 7-row page); the menu draws the
  short link from x 455 to the list at the selected row's height.
- Rows now: Fn REC |o| CP AF-ON ✥ ▲ | ◀ ▶ ▼ L-Fn CRT ART COLOR | MONO. Stock pictures stay for Fn..✥; ours for ▲ (6),
  ◀ (0), ▶ (1), ▼ (2), L-Fn (3), CRT (4), ART (5), COLOR (6), MONO (0).
- `dg_get` (ar_ic, ids 0x7fd0..0x7fd8; item records +20) composes them at run time by firmware/diagrams.py programs:
  clean back view = CP's picture with its dot / line area (x 258..422, y 140..229) from the pad picture; clean top view
  = Fn's with x 342..422 from |o|'s (y 27..150, 167..330) and REC's (x 342..370, y 150..167); arrow highlights copied
  from the pad picture's arms (▲ x 310..341 y 238..265, ◀ x 294..317 y 262..286) and the ▶ / ▼ pictures; the
  side view's own line cleared (it ran through empty space; the one outline it crossed is joined by a bridge op);
  new lines = fills + our corner stamps; the Creative Dial = the knurled block at the front of the top view
  (x 276..315, y 270..284), highlighted with our rounded box (colour 80). Decoding / encoding per row (runs within a
  row), two 64 KB buffers in ext12 (the last two pictures kept), stock picture as fallback. ext12 now 236 KB of 256.
- Bug on the way (emulator): frames `call f,[d2,d3,a2,a3],4/8` (N must count the 16 B of saved registers) broke the
  caller's stack; now 20.
- om-emu: all nine pictures show with the line meeting the selected row; the composed streams for ▲ and ◀ are
  byte-identical to diagrams.compose + encode (the Python reference). To confirm with the owner: that the highlighted
  block is the Creative Dial.
- dg1 (VERSION "v0.27-dev (diagrams 1)"): E1479999.BIN 293ec7c0…, GUIDES.BIN ed6e2d3a… (LABELS / TONES as ak6).
- **Camera (dg1, 2026-11-10):** lines and highlights line up and look good (owner; the highlighted Creative Dial
  accepted), but the menu hangs slightly when moving onto those rows, most on a page change. om-emu: one composition
  per cursor step (counter dg_cnt), so it is the work itself (~4-5 M instructions a picture: every pixel of up to three
  pictures decoded and encoded).
- dg2: the base picture's runs pass through as they are outside the span the ops touch in each row (dg_run modes: put
  runs / write pixels / skip); only the span is decoded, changed and encoded; the other sources are decoded only up to
  their last row (header u16 5 + k); the cleaning rectangles tightened to the old dot and line. Estimated work per
  picture 1.2-3.3 M (about 2x less). om-emu: all nine pictures pixel-identical to diagrams.compose (decoded memory).
  dg2 (VERSION "v0.27-dev (diagrams 2)"): E1479999.BIN 2d4fd57b…, GUIDES.BIN 782c0fae….
- Instruction counts (om-emu, drive.mjs `run:ADDR:D2:A3`, which calls dg_build directly and counts steps; `PROF=file`
  with a `:p` suffix writes a per-PC histogram): dg1 6.6-10.0 M a picture, dg2 2.6-5.0 M. dg2 was not sent.
- dg3: the output is the base picture's stream itself, copied word by word (5 tokens a 64-bit word), with only each
  row's span re-encoded; the new span gets as many tokens as the old one modulo 5 (`dg_pad` splits runs), so the rest
  of the stream stays word-aligned and is copied as words again. Row starts: `dg_rix` (447 u16 per stock picture:
  word offset | slot), made once per power-on by `dg_prep` (stock runs never cross a row's end: checked for all nine).
  `dg_seek` skips whole words by adding their 5 run nibbles (WSUM); other pictures' pixels are read only for the
  op's own row segment (no full decode). Counts: 0.6-1.3 M a picture (first visit 0.9-1.7 M with the row index),
  ~8x less than dg1. All nine pixel-identical to diagrams.compose (om-emu). ext12 240 KB of 256.
  dg3 (VERSION "v0.27-dev (diagrams 3)"): E1479999.BIN 65141864…, GUIDES.BIN 9c60d9cb….
- **Camera (dg3, 2026-11-10): "it works wonderfully"** (owner): no hang left; lines and highlights right.
- Owner (dg3, camera): the movie Button Function menu is untouched. Correction after a retest: powered on with the
  Creative Dial on a mapped position, the film loads only after a half-press; owner wants it seamless (#30 tabled).

### v0.27 dial mapping at power-on, test db1 (2026-11-10; emulator only)
- Why: the camera sets 897 (the dial's family) at start-up before the films load, so `sx_set`'s `dm_ok` sent it the
  stock way; nothing set 897 again until a dial turn (on the camera a half-press did; not seen in om-emu).
- `dm_boot`, called by `pf_load` right after the films are published (LPTR, fl_mk2; HLS_EVENT task, STATE already
  valid): GetValue(897) (ar_getv) and, for a dial family (900 / 899 / 901 / 988), SetValue(897, that family) through the
  facade setter 0x61085d05 (`ar_setv`, the call the dial handler makes at 0x6109356f), so `sx_set` maps it now.
- om-emu (sess7 gained `get:SID`; films load at the first half-press there, at power-on on the camera): test build with
  every row = FILM 3: powered on at CRT, ART or COLOR -> 897 = 901 and COLOR 1's look = 3 once the films load. Real
  build (rows Normal): CRT stays 900; after CRT -> FILM 3 in the menu, the dial turns map as before.
- db1 (VERSION "v0.27-dev (dial power-on 1)"): E1479999.BIN 5e35a488…, GUIDES.BIN e38aa7cc….
- **Camera (db1, 2026-11-11): works** (owner: "that worked great"): a mapped position loads its film at power-on
  without a half-press; Normal positions come up as before.

### v0.27 the film's name in the JPEG's EXIF, test ex1 (2026-11-11; emulator only, by a direct call)
- Owner: add the EXIF work talked about earlier (research: "EXIF research, step 2" above).
- `.hook_ex` at 0x60457578 (the per-shot fill, after Artist / Copyright; both branches reach it): `jmp ex_hook`
  (8 bytes replaced: `mov (8,sp),a0; movhu (37666,a0),d0`, redone before `jmp 0x60457580`). `ex_hook` keeps d1 / a1 /
  d2..a3 / MDR; `ex_fill` (a0 = the block): picture mode the capture way (getter 0x60063380: 38017, 6 -> 40209; 11 =
  COLOR, number 63153 1..4 -> k; the facade ids such as 111 read 0 there), film j = fl_film, fl_has; then
  ImageDescription (block + 0x5a8, 32 B) = "FILM n Name" + zeros, UserComment (block + 3972, 117 chars) =
  "Caduceus OM-3: FILM n Name" + spaces. No film: ImageDescription back to the stock bytes (copied from the first block
  seen), UserComment 117 spaces (as the set-up writes).
- om-emu (sess7 `run:ADDR:D2:A3:A0` calls ex_fill on a scratch block; the emulator cannot take a photo): COLOR 1 own
  -> blank; CRT mapped to FILM 3 -> "FILM 3 Kodachrome 64" / "Caduceus OM-3: FILM 3 Kodachrome 64"; back to COLOR
  (own) -> blank again. Not tested: the hook during a real shot (camera), what apps show.
- ex1 (VERSION "v0.27-dev (exif 1)"): E1479999.BIN 1248a059…, GUIDES.BIN 1bf6cb72….
- **ex2: the film's settings as a short code** (owner: "the user comment that will show the film settings; short"):
  UserComment = "Caduceus FILM n Name cd1.<39 characters>" (~73 characters). cd1 = the film's LOOKS.BIN record bytes
  0..56 (all a look sets: wheels, WB, tone, Contrast / Sharp / Shading, Extras, NR, VigFix, Grain, split toning), one
  nibble each (value & 15; unsigned: 36, 48..51, 53, 55), two to a byte, base64url, no padding (`ex_cd1`; reference
  `firmware/cd1.py`). The Control Panel reads it back (`recordFromCd1` / `lookFromCd1` / `encodeCd1` in om3.ts):
  pasted into the import box, or a camera JPEG opened with the file button (it finds "Caduceus ... cd1." in the
  file's first 256 KB); the film lands like a shared op1_ look. Tests: webapp/tests/cd1.test.ts.
- om-emu: CRT -> FILM 3: "Caduceus FILM 3 Kodachrome 64 cd1.EAAA_wERAP8A_w__MUQRMxAAEQ8CAOAAABAGEBA", equal to
  cd1.encode of that record from the card's LOOKS.BIN, and it decodes back to the same 57 bytes. Bug on the way: ex_cd1
  first called after a2 had become the EXIF block (a fault loop in om-emu); now right after the name, while a2 = P.
  ex2 (VERSION "v0.27-dev (exif 2)"): E1479999.BIN ddf84558…, GUIDES.BIN b6b03efd….

### v0.27 dial rows redone: each position picks a mode and keeps its own COLOR choice, test dr3 (2026-11-11; emulator only)
- Owner (found while testing): a position set to FILM 20 is stuck on FILM 20. Wanted instead: each position set to
  CRT / ART / COLOR / MONO, the film picked in the COLOR menus as usual, and each position remembering its own choice
  ("in theory all 4 positions set to COLOR, each a different film sim").
- Rows (571 / 54 / 55 / 1966): values DV1 3900 + 0 Normal (its own mode), 1 CRT, 2 ART, 3 COLOR, 4 MONO (dr1 / dr2
  values read as Normal); value pictures Normal / CRT / ART / COLOR / MONO, titles our strings 0x7f48.. (CRT .. MONO).
- Memory: unused movie buttons with validator records: 1958 / 1277 / 1275 / 1284 = each position's COLOR choice
  (PV0 4000 + the dm_cur code: 1..4 COLOR k own, 11..30 FILM n), 1285 = the last position (LV0 4100 + 0..3); written with
  the manager from sx_set, so the camera keeps them (persistence across power-off: to be confirmed on the camera).
- `dm_turn` on each dial event (sx_set, family -> position p): the position the dial was on (1285) keeps the COLOR choice
  now on the camera when its mode is COLOR; p becomes the last one; p's mode: not COLOR -> that family the stock way;
  COLOR -> 897 = 901 and p's own choice back through fl_set (the old 55 path), or as it is when p has none yet.
  dm_boot (power-on, after the films) runs the same through the facade.
- om-emu (sess7 gained `sget:SID` and `setv:SID=VAL`; 901 reads / writes from the debugger hang there, so films were
  picked on the super control panel: OK closes the dial's screen, OK opens the panel, `sub+N` steps): CRT and MONO rows
  -> COLOR; COLOR position -> FILM 19, CRT -> FILM 18, MONO -> FILM 17; turning back: COLOR shows Astia 100F (FILM 19),
  CRT Fuji Eterna (FILM 18), MONO Vision3 250D (FILM 17), ART Pop Art (stock); memory 1275 / 1958 / 1284 = 4029 / 4028 /
  4027.
- dr3 also carries the EXIF ex2 code. VERSION "v0.27-dev (dial modes 1)": E1479999.BIN 380771bc…, GUIDES.BIN 77b3fc6b….

### v0.27 photo code renamed om3.1 and widened to the whole record, test dr4 (2026-11-11; emulator only)
- Owner: codes must keep working across updates, both ways. cd1 carried bytes 0..56 only, so a future setting had no
  room. Now `om3.1.` + 43 characters = all 64 bytes; rule: new settings go into the spare bytes 57..63 with 0 = off (an
  older reader skips them, a newer one reads an old code as off); only a change that cannot follow that is om3.2.
  The camera is in the name (owner asked about the E-P7): an E-P7 code would be its own (e.g. ep7.1.) with the same
  text layout. Spec: docs/PHOTO_CODE.md; reference firmware/photocode.py (cd1.py removed); Control Panel
  recordFromPhotoCode / lookFromPhotoCode / encodePhotoCode, tests webapp/tests/photocode.test.ts.
- om-emu: FILM 19 picked on the super control panel -> "Caduceus FILM 19 Astia 100F om3.1.AAAAAAAAAQAAAAAADwAAEQAAAAAPABDwABAAAAAAAAA"
  (77 characters), equal to photocode.encode of that record; decodes back to the same 64 bytes.
- Proposal for cakelesscoder (not sent; the owner's call): see the reply of 2026-11-11 and docs/PHOTO_CODE.md.
- dr4 (VERSION "v0.27-dev (dial modes 1, photo code 2)"): E1479999.BIN 296fce57…, GUIDES.BIN b829ec4b….

### Camera results dr3 and the fix dr5 (2026-11-11)
- **Camera (dr3): EXIF works.** Two owner photos (read for the two text fields only, copies deleted): ImageDescription
  "FILM 9 Velvia 50" / "FILM 18 Fuji Eterna", UserComment "Caduceus FILM 9 Velvia 50 cd1.<39>" etc. (the cd1 form,
  replaced by om3.1 in dr4 before any release).
- **Camera (dr3): the dial modes work, but** after moving the dial while the camera was off, power-on lagged badly,
  and once the camera half froze (live view on, nothing else; it would not switch off; battery pulled).
- Likely cause (analysis): dr3's power-on path (dm_boot, HLS_EVENT task -> facade SetValue -> sx_set -> dm_turn)
  wrote settings with the manager (the last position 1285 and the previous position's COLOR choice) from that task;
  db1, which only set the family and loaded the film there, was fine on the camera.
- dr5: no setting is written at power-on or on a dial turn. `dm_turn` only reads (position -> mode -> its choice) and
  keeps the position in RAM (`dm_pos`). Each position's choice is written when the owner changes the COLOR choice:
  `dm_rec` from sx_set's SetValue(901) (super control panel, Picture Mode menu, film list), for the position the dial
  is on when that position is on COLOR (and only when the value changed). The last-position setting (1285) is gone.
- om-emu: same test as dr3 (COLOR -> FILM 19, CRT -> FILM 18, MONO -> FILM 17 on the super control panel; turning back
  shows each; memory 4029 / 4028 / 4027). Power-on with a moved dial: to test on the camera.
- dr5 (VERSION "v0.27-dev (dial modes 2, photo code 2)"): E1479999.BIN bfdf1763…, GUIDES.BIN 611ace28….
- **Camera (dr5): still hangs** at power-on after the dial was moved while off: live view only, nothing else, would
  not switch off; battery pulled. So the writes were not (or not the only) cause.
- dr6, two changes (analysis / guess, the emulator does not show the hang): (1) the power-on mapping (dm_boot) no
  longer runs in the HLS_EVENT task from pf_load; our SDLOAD worker calls it as it stands down, polling dm_ok (up to 60
  x SDL_POLL_TICKS) for the films, then one poll more, then GetValue / SetValue(897) through the facade. Reasoning:
  with the dial moved while off the camera's GUI starts with its own dial work; a facade SetValue from the task the GUI
  may be waiting on (HLS_EVENT) can deadlock; our worker is waited on by nobody. (2) sx_set / dm_turn / dm_rec / dm_ok
  keep a0 / a1 / values on the stack instead of globals (the camera's dial handler and the power-on mapping may run them
  at the same time). om-emu: per-position films as dr3 / dr5; power-on at MONO / CRT starts and the menu opens.
- If dr6 still hangs: drop the power-on mapping (half-press or a dial turn applies it, as before db1) and look for a
  GUI-task moment after the films load.
- dr6 (VERSION "v0.27-dev (dial modes 4, photo code 2)"): E1479999.BIN f31e5420…, GUIDES.BIN 59ce54a5….
- **Camera (dr6): still lags / hangs** at power-on after the dial was moved while off. Owner: take the fallback.
- dr7 (fallback): the power-on mapping is gone (dm_boot and its call from the SDLOAD worker removed). At power-on the
  camera starts in the dial's own mode; a half-press or a dial turn applies the position's mapped mode / film (as
  before db1). Everything else as dr6. om-emu: power-on at MONO and CRT starts and the menu opens.
  Open: why a mapping at power-on hangs only with the dial moved while off (db1, family only, was fine; dr3+ also read
  the per-position settings and switch the film). A later try needs a GUI-task moment after the films load.
- dr7 (VERSION "v0.27-dev (dial modes 5, photo code 2)"): E1479999.BIN 07032d36…, GUIDES.BIN 99473777….
- **Camera (dr7): works** (owner, 2026-11-11): power-on is normal after moving the dial while off; the owner keeps it this way.
- **Camera (dr7): om3.1 code camera-tested.** Owner photo on FILM 4 (read for the UserComment only, copy deleted):
  "Caduceus FILM 4 Portra 800 om3.1.ABEREP7wAAABACIQ8AD-7t3vEg8AAOAgABD3EBAAAAA" = exactly the Control Panel's default
  Portra 800 code (devkit/photo-code/examples.json); devkit reader and firmware/photocode.py decode it.

### v0.27 release (2026-11-11)
- Owner: release v0.27; the photo code kit as a developer folder and a release download; `DEBUG.TXT` only as an optional
  download (never in the default card files: patch.py copies GUIDES / LABELS / TONES only).
- Firmware = dr7 byte for byte (E1479999.BIN 07032d36…, GUIDES.BIN 99473777…), rebuilt after merging main and by
  `patch.py --release v0.27`. VERSION string left as built ("v0.27-dev (dial modes 5, photo code 2)", shown only in
  CADLOG.TXT) so the release is the camera-tested bytes.
- Optional LOOKS.BIN regenerated from the Control Panel defaults (fw 26): Gold 200 / CineStill 800T split tone on the
  Highlights wheel (main c7c5f4f); other 18 records equal v0.26.2's. Devkit examples regenerated to match; the
  firmware example is now the owner's camera photo (FILM 4 Portra 800).
- Workflow `releases.yml` also attaches `DEBUG.TXT` and `*.zip` from a release folder.

### Sporadic power-on hang on v0.27 (camera, 2026-11-11)
- Owner, v0.27 release (= dr7, no power-on mapping): once, at switch-on the live view started but nothing else loaded,
  and the power switch did not turn the camera off: battery pull. Sporadic, can't be forced. Same symptom as the dr3
  "half froze" report and the dr5 / dr6 hangs, so dm_boot was not (or not the only) cause (analysis).
- The card's last camera save before this (BUNDLES.NEW / .BAK, LOOKS.NEW, EDITS.BIN) is from the same session time.
- Debug log put on the owner's card (OM3MOD/DEBUG.TXT, 29aa0c06…). Limit: the log writes only at shutter-button
  events, so a hang before the first half-press leaves the previous power-on's log on the card (useful as "what came
  before"). Open: whether the dial was moved while off; a log from a power-on that hangs needs a write at start-up.
- Suspect (analysis, owner agrees): the v0.26.2 automatic film load (SDLOAD worker + sdl_poke's SetValue from the
  HLS_EVENT task while the GUI builds the start screen; NOTES "sd1 quirks", "watch for a hang"). Moving the dial while
  off gives the GUI more start-up work, so a collision is likelier.
- **Build na1** (branch `experiment/no-autoload`, VERSION "v0.27-na1 (no auto-load)"): v0.27 without `.hook_hb` /
  `.hook_hr` (0x60af0fb9 / 0x60af101c stay stock: no worker, no OK trigger, no poke). Films load at the first
  half-press, as v0.26.1. E1479999.BIN 8c4374d7…, GUIDES.BIN 32f490d1…; LABELS / TONES as v0.27. om-emu (no worker
  entry): LPTR 0 until the half-press, then set; menu opens. Emulator only. Owner to use it for a few days.
- **Camera (na1, 2026-11-11): "works much better"** (owner, after use the same morning). Released as **v0.27.1** (owner).
  Open: a longer run will tell whether the freeze is gone for good.
- After the release (owner-approved): `devkit/photo-code/sample-film19-astia-100f.jpg`, the owner's OM-3 photo (CC0),
  resized to 1600 x 1200 with the camera's own APP1 kept (ExifImageWidth / Height patched); Artist, Copyright and the
  body / internal / lens serials blanked with spaces in place. The camera writes UserComment with a blank character
  code (8 zero bytes), not "ASCII": docs corrected. The v0.27 zip on the release is unchanged (no sample).
- Further speed, if needed: several spans per row (the span is one range from the leftmost to the rightmost op, so a
  line and a cleaning rectangle on the same row make one wide span), `dg_pad` from the end, fewer per-row op scans.

## Film sims graded on the camera (2026-11-11; camera-tested on the chart for the 20, camera model for the rest)
- Method and data: `research/film-grading/` (README, `camera_response.json`, `grade.py`, `preview_chart.ts`). Photos
  of a Datacolor 24-patch chart on the owner's OM-3 (1/40 s, f/1.8, ISO 1000, fixed WB 3100 K; v6 shoot 3300 K), test
  builds v0.27-na1 with `LOOKS.BIN` swaps the owner approved in chat (the camera must be off while the card is out,
  or it saves its looks over the new file; at shut-down it re-saves `LOOKS.BIN` with only the selection bytes changed).
- The release films on the camera were 2–3x too strong against the film references (17.6% average chroma error).
  The Control Panel preview, though, is close to the camera: camera change ≈ 1.06 × preview in lightness, 1.23 × in
  chroma, 0.8 × in hue (corr 0.92 / 0.94 / 0.74); camera vs preview about ΔE 4–6 per patch.
- Per step (camera-tested): Saturation +1 ≈ +7% chroma, −1 ≈ −12..−18%; Hue −1 turns 3–6° (Cyan ≈ 11°), Hue +1 more
  (+2: Yellow −15°, Cyan −49° on the cyan patch); Luminance +1 ≈ L +1..2; Red reaches no chart patch; Violet: purple;
  Green-cyan: aqua and green. Contrast +1: whites +3.9, darks −2.3 L (−1 asymmetric); Midtones ±2.5–3.4 L / step;
  Shadows / Highlights ±1.3–1.6 L / step. WB A-B +1: b +1.0, a +0.65; G-M +1: a −1.3, b +0.8. Vignette correction
  off (every look): corners −2..4 L.
- Split toning (set D): a tint (lightness < 1 L) weighted by brightness: Shadows wheel L26 100%, L51 80%, black 50%,
  L69 40%; Highlights wheel L69 100%, L51 95%, L81 90%, white 60%, L26 40%. Linear in strength (Orange 1 and 4: same
  per step); −2 Blue = +2 Yellow. Per step at the peak (Shadows / Highlights): Yellow 5.6 / 4.5, Orange 4.0 / 3.3,
  Orange-red 3.1 / 2.6, Magenta 5.8 / 4.9, Blue 5.1 / 4.2, Blue-cyan 3.2 / 2.7, Cyan 3.1 / 2.9, Green 6.4 / 5.5
  (Red, Violet, Green-cyan, Yellow-green not measured).
- The camera's 20, graded against film reference statistics (kept outside the repo): v3 → v5 → v6 shot on the
  camera; average chroma error 7.6% → 6.8% → 6.7%, grey tint error 1.4 → 1.1. Films with unchanged settings moved up
  to 4% between shoots, so that is the noise floor. v6 = `GRADED` in films.py (tone and Contrast included); the
  Control Panel's `LOOKS.BIN` for the 20 equals the camera-tested LOOKS_V6.BIN (5399d587…) byte for byte. Changes
  from the 2026-11-09 tuning: Fuji Eterna's split dropped (it went against its reference), new Highlights splits for
  Velvia 50 (Blue 1) and CineStill 400D (Cyan 1); several films' WB off.
- The other 42 looks (camera model; not shot): fitted so the camera matches each recipe's own preview (colours, WB,
  split; Red, tone and Contrast kept). Predicted camera vs preview ΔE 3.5 → 1.9, grey tint 1.2 → 0.7; the looks'
  preview changes by ΔE 1.5 on average (most: Fuji Velvia 3.1). Phoenix 200 / SX-70 were kept from swapping warm WB
  for a cool WB plus warm split (WB sign kept).
- Branch `feature/camera-graded-films`. Next: a camera check of some of the 42; real-scene check of the 20.

## Control Panel preview fitted to the camera (2026-11-11; analysis on camera-tested shots; branch feature/preview-camera-match)
- Each single-slider chart test run through the preview vs the camera: the camera's WB shift is 2–2.7x the preview's;
  saturation is 2–5x on Yellow, Orange-red, Cyan and 1.5–2x on Magenta, Blue, about equal on Orange, Blue-cyan, Green,
  weaker on Red / Violet / Green-cyan; hue turns 1.5–3x further on Yellow, Orange-red, Magenta, Blue-cyan, Cyan and less
  on Blue, Green, Yellow-green; per-colour luminance is stronger; split toning, Contrast and tone are close.
- `preview.ts` `OM3_CAL` (OM-3 only; the E-P7 and RapidRAW paths keep the old numbers): per-colour saturation gains
  up / down, hue degrees per step per direction, luminance scale, WB gain per channel, split scale 1.05. Fitted on the
  tests plus the 80 film shots (`research/film-grading/preview-fit/`). Preview vs camera ΔE: saturation 6.6 -> 4.5,
  hue 5.1 -> 3.6, luminance 3.4 -> 2.5, WB 3.0 -> 2.2; film shoots left out one at a time 4.4 -> 3.8 (shoot-to-shoot
  floor 2.3). The 62 looks' previews move by ΔE 1.7 on average (max 3.7); the 42 graded looks now preview within
  ΔE 1.8 of how their recipes previewed before grading.

## v0.28 code space: the button-picture buffers, space 1 and the GX4 probe (2026-11-11; emulator only)
- Space left in v0.27.1 (measured from the build): ext11 96 B of 64 KiB; ext12 14896 B of 256 KiB; the `GUIDES.BIN`
  block ~3.2 KB under the 16448 B malloc cap; ext1..ext10 a few hundred B. `.ext12` held two big reservations:
  `dg_b0` (2 x 64 KiB body-diagram output buffers) and `ar_pay` (80 KiB for the button pictures).
- The diagram buffers can't move to the heap: the composed pictures are 38556..59892 B (om-emu, `dg_build` k = 0..8:
  39468, 39340, 38876, 38556, 51172, 59292, 59236, 59892, 59540), and the firmware malloc (0x60024068) hands out at
  most 16448 B per block from a small pool (NOTES "gl1b"). They stay as they are; one buffer instead of two would save
  64 KiB but risks the menu redrawing a picture that was overwritten (not tried).
- **space 1** (`feature/v0.28-space`): `ar_pay` held 19061 B in 81920 B; now `.space 20480` (build.py's assert
  `at + len <= ar_pend` keeps it safe). ext12 free 14896 -> 76336 B. The 12 button pictures are byte-identical to
  v0.27.1 (descriptors and streams); om-emu composes all nine body diagrams byte-identical; Picture Mode screenshot
  identical. VERSION "v0.28-dev (space 1)".
- Section map (research/tools/sections.py): section 6's FF gap runs from its data end to section 7's start at
  0x6103f000 (1006208 B); GX2 + GX3 proved 0x60f49800..0x60f99800. The rest, 0x60f99800..0x6103f000 (677888 B), was
  never written during the GX3 camera test (gap sums unchanged), so it is the next candidate.
- **GX4 probe** (`experiment/firmware-space-probe-gx4`, on space 1): section 6's loaded end -> 0x6103f000; `.gx` at
  0x60f99800 ('GXT4', the GX3 probe, 169336 pattern words); `gx_go` (ext12) called from `lg_pr` at every half-press;
  gap list: section 1's tail replaces section 6's (now loaded); `GAPTEST.BIN` 'GXR4'. om-emu: 10 half-presses -> 19
  passes, 0 bad, no gap changed; the nine diagrams byte-identical to v0.27.1. Package (VERSION "v0.28-dev (space 1 +
  GX4 probe)"): E1479999.BIN 6b7ac10f…, GUIDES.BIN 85bb63d0…; LABELS / TONES = v0.27.1. Camera test next: normal use
  incl. bursts, RAW+JPEG, video, Button Function rows, and special modes (Live ND, High Res, ProCapture, bracketing).
- **GX4 camera result (owner's OM-3, 2026-11-12; camera-tested):** `GAPTEST.BIN` 'GXR4' after the last power-on run:
  **62 passes, 0 bad pattern words of 169336, the 8 gap sums never changed** (baselines 0x1b100524 0x9be9ff00
  0x86c31db3 0x04fb821d 0xe355dc76 0xdabfc116 0x3c68c80c 0x6bbc9758: none all-FF, so the gaps stay unloaded).
  That run: four 4K 30p movies (PB122166 24 s, PB122167 2.5 s, PB122168 4 s, PB122169 3.5 s) and 2 JPEGs
  (PB122170 / 171); the evening before, one RAW+JPEG (PB112165, an earlier power-on, whose passes the file no longer
  shows). CADLOG: build "v0.28-dev (space 1 + GX4 probe)", all card files match. No burst in this run (GX3's gap watch
  already covered this area during bursts). So 0x60f99800..0x6103f000 loads and stays intact through 4K video;
  a burst + Button Function session would complete the picture.
- Side finding (owner, 2026-11-12): the films' colour seems to carry into movies (docs say photos only). Sharpness:
  PB122168 vs PB122169 (same scene, 13 s apart) measure the same (Laplacian variance 169/168 = 0.90..0.98, aligned
  frames, corr 0.96); no Caduceus edit was saved between them (CADLOG #59..62 "edits waiting no"; the only edit save,
  #58, came at PB122167's start). Which setting the owner changed is still to be asked. Analysis, to test: the
  camera's own Color Profile values (per-colour hue / saturation / luminance) may be what movies use, while our own
  photo-path effects (Sharp row, grain, glow) are not (#6).
- **GX4 burst run (2026-11-12; camera-tested):** 'GXR4' **35 passes, 0 bad of 169336, no gap changed** (new
  baselines after the power cycle: unloaded RAM keeps whatever is left there, as GX1 / GX2 saw). The run: 34 RAW+JPEG
  frames PB122172..205 in 7 sequential bursts of 3..8 (mechanical, some with anti-shock) on FILM 9 Velvia 50; the
  photo codes say grain 0 and Glow / Clarity 0 in every frame. With the first run: the 662 KiB loads and stays intact
  through 4K video, photos and RAW+JPEG bursts. Not covered: bursts with grain + Glow (the #28 load).
- **GX4 grain + Glow burst run (2026-11-12; camera-tested):** 'GXR4' **29 passes, 0 bad of 169336, no gap changed.**
  19 RAW+JPEG frames PB122206..224 (a single, a burst of 11, a burst of 7 with anti-shock) on FILM 9 at ISO 1600:
  BUNDLES.BIN slot COLOR 2 = grain High, Glow 5 (Clarity 5 before the run's one edit, event #2); the frames show
  the grain (high-pass texture in flat areas 11.9 vs 5.1 for PB122180 at ISO 2000). No freeze. **GX4 is complete:
  0x60f99800..0x6103f000 is proven space** (4K video, photos, RAW+JPEG bursts, grain + Glow bursts). A build that uses
  it must raise the loader's end word 0x60045e9c to the end it uses, at most 0x6103f000.
- Found on the way (camera, analysis of the code): the photo code (`ex_cd1`) encodes the film's record from the heap
  copy of LOOKS.BIN (LPTR), i.e. the film as built, not the changes made on the camera (here grain High + Glow 5 live
  in BUNDLES / the COLOR slot; every frame's code says grain 0, glow 0). docs/PHOTO_CODE.md says "the LOOKS.BIN record",
  so it is as specified, but users will expect their on-camera changes in it. Candidate fix: encode the live values.

## Halation for the OM-3: design and probe h0 (2026-11-12; analysis + emulator only)
- Source read (read only, nothing copied): cakelesscoder/caduceus-ep7 at 54c8e54, docs/HALATION_RED.md §14–22,
  patches/halation/hl.s.in. Their method (camera-tested on the E-P7, h1/h2): a CPU pass over the finished photo after
  the Soft Focus blend. A: Y of every 2nd pixel / 2nd row, threshold excess summed into 64 x 64 px cells (u8, one
  malloc <= 16 KB); B: [1 2 1] blur twice per axis; map u = min(255, 21v/8), g = u(511 - u)/256 x gmax/256 (gmax by
  strength); C: per pixel pair with w = 255 - Y: Y += w g dY / 2^16, C += w0 g dC / 2^16 (clamped), so light cores
  stay white. Coverage cap: skip when >= 1/3 of the cells glow. Lessons: their 10 s watchdog restarted the camera when
  CPU grain + halation ran long (their fix: timeout 30 s); h3's speed-ups (drop g < 8, reuse Y0's delta) made the halo
  blocky and lost thin LEDs, so keep every non-zero g and the per-pixel darkness weight; an unexplained crash on
  bright daylight frames led to a 30 % cap.
- OM-3 route (analysis): our Glow / Clarity row already runs the Soft Focus passes (job flag 0x80); `xb_gs` wraps the
  blend setup SF_ENT, after which buffer 0x1000 (format 0x0c02, YCbYCr 4:2:2, Y in even bytes) is complete and CPU
  writes reach the JPEG (camera probe g2, v0.21). Fast grain stays the image processor's texture (Glow + Grain fast,
  camera rc2c), so halation adds only its own CPU time (E-P7: ~0.2–0.3 s without lights, ~1–3 s for night scenes) and
  stays far from the 10 s watchdog without CPU grain. Plan: the heavy pass in ext12 (cached, 76 KB free), called from
  the block; rows through the window under the lock as xb_grain.
- Open: the chroma byte order and sign on the OM-3 (our grain wrote Y only); the control (own row, or a colour on the
  Glow row: owner); whether halation without Glow should force the Soft Focus passes at a neutral weight.
- **Probe h0** (`experiment/halation-h0`, on space 1): `xb_gs` calls SF_ENT on every still of our looks (as the CPU
  grain path did), then `xb_h0`: rows 0..255, left half byte 1 of each pair = 168, right half byte 3 = 168. om-emu,
  direct call on a 64 x 300 DRAM test buffer: exactly the expected 8128 bytes changed, rows 256.. and padding
  untouched, stack restored; the window path can't be emulated (om-emu out of memory at 0xce9d4b80). Package
  E1479999.BIN e8a49eec…, GUIDES.BIN 571b98a2… (13436 B); LABELS / TONES = v0.27.1. Camera: Glow on, a grey wall.
- **h0 camera result (owner's OM-3, 2026-11-12; camera-tested):** PB122226 (FILM 1, Glow 1, ISO 640) and PB122227
  (Glow 1 + Grain High, ISO 800), RAW+JPEG, a plain scene. Both show the bands on rows 0..255 exactly. Measured in the
  JPEGs (PIL YCbCr, offsets from 128): left band (byte 1 = 168) **Cb +39.9 / +39.0, Cr unchanged**; right band (byte 3 =
  168) **Cr +39.7 / +39.7, Cb unchanged**; below the band Cb, Cr within ±2.2. So **byte 1 = Cb, byte 3 = Cr,
  offset-binary (128 = neutral)**, as on the E-P7. The grain photo saved normally with the bands (fast grain + the Soft
  Focus route + a CPU pass: fine). The grain is almost all in Y (Cb / Cr high-pass below the band 0.40 / 0.35 with
  Grain High vs 0.57 / 0.54 without), so the chroma noise can't tell whether the texture comes before or after xb_gs;
  the higher Cb noise inside the left band is RGB clipping of bright, blue-shifted grain in the decode, not grain
  order. Halation adds to Y and C (not a replacement), so grain shows under the halo either way.

### Halation h1 (2026-11-12; emulator only; branch experiment/halation-h1)
- Look tuned on a synthetic night scene with the exact model (research/halation/model.py): the first tuning gave no
  halo on small lights (bulbs, a 4 px LED strip) and a flat band with a hard edge around a big window (u = min(255,
  v >> S) saturated and a 2-pass blur reached only 2 cells). Fix: u = 255 v / (v + K) by two 256-byte tables (no
  division on the camera), K 600, 3 [1 2 1] passes each way; tint red-orange KY 44 / KCb -40 / KCr 60; gmax 40, 72,
  104, 144, 192 for strength 1..5; T 200; cap: g >= 16 on more than a third of the cells. All in firmware/halation.py
  (build.py writes hl_tab.inc; the model imports the same file).
- Firmware: `hl_run` (+ `hl_b1`, `hl_open` = xb_open's code) in ext12 (1.3 KB code + 532 B tables; ext12 74368 B
  free); one malloc (grid + blur temp + line, <= 16 KB) per call. The block's xb_gs: on our looks with Glow -1..-5, the
  Soft Focus setup, then `call HL_RUN` (defsym from build.py), then CPU grain if any (none with the texture). XB_H0 off.
  editor.ld gains LOCK / UNLOCK / WINMAP / FLUSH. GUIDES.BIN 13320 B.
- om-emu, direct call on DRAM test frames (FLUSH 0x60070e69 stubbed with `ret [d2,d3],16`: in om-emu it polls a cache
  register forever; camera-proven through xb_grain): **7/7 bit-exact with the model** - night 1024 x 768 with 16 px
  padding (strength 3), strength 1, strength 5, daylight (capped: untouched), dark (no glow: untouched), 128 x 128,
  1000 x 700 with 24 px padding; every call returned with the stack restored. Steps: 1.3-1.5 M for a 0.79 MP frame
  without glow (pass A + blur + map), 10.7-13.5 M for the night frames (about half the rows glow). Scaled to 20 MP
  (x 25.6): about 35 M without lights (~0.3-0.6 s at the E-P7's measured rate) and up to ~350 M for dense night scenes
  (~3-5 s), under the 10 s watchdog with fast grain (no CPU grain). Analysis; the camera will tell.
- The test harness (scratch, not in the repo) adds `poke:` and `runa:ADDR:A0:D0:N` to sess7; note for zsh: write
  `${VAR}:a5...` (a bare `$VAR:a` is zsh's absolute-path modifier and jumped the emulator to address 0).
- **h1 camera, first run (owner's OM-3, 2026-11-12; camera-tested):** CADLOG "v0.28-dev (halation h1)", 97 shutter
  events, card files OK; 23 RAW+JPEG stills PB122229..251 at ISO 200-1250, FILM 1 Portra 400 on COLOR 1 (BUNDLES at
  the end: Glow 5, Grain High), incl. bursts of 5 (anti-shock) and 11: **all saved, no freeze or restart.** Scenes: a
  dim room with a warm table lamp (most frames), a floor lamp on a bright wall, two daylight frames. File times are
  the capture times (no save-time measurement from the card).
  - Ring 500..900 px around the lamp (Y 90..235): Cr +7.7 (229) -> 8.5 -> 11.7 -> 12.4 -> 13.3 (236), Cb -17.6 ->
    -21.7: the tint direction of hl_run and growing over the series (settings per frame not known yet). Modest, and the
    lamp is tungsten-warm itself, so halo vs lamp light can't be separated without a reference.
  - With Grain High (236): Cr high-pass noise in the ring 1.78 vs 0.92 far from the lamp; orange / white speckle in
    the glow and the lampshade's thin dark rim turned orange (visible at 100 %). Cause (analysis): the fast grain's
    texture is in the development, before xb_gs, so the per-pixel weight 255 - Y0 modulates the chroma add with the
    grain. Fix for h2: take the chroma weight from a smoothed brightness (e.g. a running mean of Y over ~8 pairs) so
    grain and thin lines don't modulate the tint; keep the per-pixel weight for Y (cores stay white).
  - Next test needs a reference: the same scene with white / LED light, Glow 5 vs Clarity 1 (Soft Focus route without
    halation), with and without grain.

### Halation h2 (2026-11-12; emulator only; branch experiment/halation-h2)
- Owner: PB122229 / 230 / 231 = Glow 1 / 3 / 5 (ring Cr +7.7 / +8.5 / +11.7); saves "reasonably quick" with h1.
- Model on the owner's photos: the lamp scene is not capped (6 % of the cells g >= 16 at Glow 5), but the lamp-lit wall
  is bright, so the per-pixel weight 255 - Y keeps the tint small; the outdoor PB122235 was not capped either (31-33 %
  at Glow 3-5, under the third) and the dark eave next to the sky turned red-brown.
- h2 (model first, then the firmware, bit-exact): chroma weight w = min(255, 2 (255 - B)) with B the cell's mean Y0
  (from Y0 >> 2 sums, B = 4 Q // samples via a shift-subtract `hl_div`), lerped like g; chroma add (c kC) >> 8 with
  c = (g w) >> 8; Y unchanged (per pixel, cores stay white). Bright frames: n = cells with u >= 32; full strength up
  to 8 % of the cells, none from 24 %, sc = ((n_hi - n) 256) // (n_hi - n_lo) between. Speckle test (the owner's Glow
  1 lamp photo + synthetic grain sd 20, Glow 5): Cr high-pass on the wall h1 3.64 (tint +8) -> h2 2.69 (tint +16); a
  per-pixel clip guard on top gave 3.18 (it reintroduced grain modulation near Y 240) and a smoothed one 2.72, so none.
  What speckle is left is bright grains clipping in R once tinted. Lamp core Cr +8.0 vs +5.4 without halation.
- Firmware: two mallocs (E + tmp + two lines; Q / w), `hl_seg` (one loop for the 16 head pairs, the spans and the
  tail, g and w accumulators d2 / d3 and a2 / a3), `hl_vl` (row lerp; its frame must be 24: (4,sp) is a local - caught
  before testing), `hl_div`. hl_run frame 120 (xb_gs updated). ext12 still ~74 KB free; GUIDES.BIN 13320 B.
- om-emu (FLUSH stubbed): **8/8 bit-exact** - night 1536 x 1152 (Glow 5, 16 px padding), Glow 1, night + grain
  (Glow 4), a fade-zone frame (10.8 % bright, Glow 3), daylight (off), dark (none), 1000 x 700 with 24 px padding,
  320 x 256. Steps 2.0-2.7 M for 0.8-1.8 MP frames without glow, 23 M for the 1.8 MP Glow 5 night frame: scaled to
  20 MP about 57 M without lights (~0.6-0.9 s) and ~260 M for dense night scenes (~3-4 s). Analysis.
- **h2 camera (owner's OM-3, 2026-11-12; camera-tested):** CADLOG "v0.28-dev (halation h2)", 105 events, card files OK;
  13 JPEG+RAW singles PB122255..267, FILM 1 on COLOR 1 (BUNDLES at the end: Glow 5, Grain 0): the table lamp (255-259),
  a white floor lamp (260-266), daylight (267). No freeze. Visual: a smooth red-orange glow growing over each series,
  a clear CineStill-like rim around the white shade (264-266), no cell blocks, no halo in daylight.
  - White lamp, ring 250..600 px (Y 60..240): Cr 0.7 (260) / 4.0 / 3.9 / 10.2 / 18.7 (265) / 14.6 (266, grainy),
    Cb down to -12; Cr high-pass "speckle" 0.6-0.73 throughout (266 with grain: 0.60); clipped cores (Y >= 250)
    neutral: Cr -0.2..-0.8. The shade in 266 is not clipped (Glow + grain) and takes a faint pink.
  - Table lamp, ring 300..700 px: Cr 10.0 / 12.8 / 18.5 / 23.6 / 24.5 (259, grain), speckle 1.02-1.35; h1's PB122236
    (grain High) had Cr 15.0 with speckle 2.26: h2 about 60 % stronger with about 40 % less speckle.
- **Owner decisions (2026-11-12):** halation gets **its own Picture Mode row** (not a choice on the Glow row), so it can
  be used with or without Glow. The faint pink on a bright, not clipped surface next to the light (the shade in
  PB122266) stays: it is what real halation does (the bounced light exposes mostly the red layer; clipped cores stay
  white, bright unclipped surfaces warm up a little).

## v0.28 Halation row h3 (2026-11-12; emulator only; branch feature/v0.28-halation)
- Owner: halation gets its own Picture Mode row, 0..5, with or without Glow.
- Storage: BUNDLES slot **+30** (the shared layout's `vignette`, range -5..5 in every OM-3 firmware, unused on the OM-3:
  going back to v0.27.1 keeps BUNDLES valid); LOOKS / EDITS record **+57** (pf_lo -5: accepted -5..5 with no code
  change; firmware before v0.28 rejects a LOOKS.BIN with +57 != 0, so the Control Panel gates it by firmware).
  pf_bt + (57 -> slot 30), both loops to pf_bt+32 (film -> slot, slot -> EDITS record); fl_xr row 13 (HLB) = (57, 30),
  rows up to 13 with 12 (WGB) skipped. fl_live / fl_fch (the film list's FILM*) still compare only up to Sharp, as for
  split toning (not changed: old EDITS records could mark films changed).
- Row: HL_IT 5380 (key 5374), bars HLB 0x7ed0 + k, class 12 (value slot +30, count 6, lowest 0: 0..5), title
  ST_HAL "Halation", left icon IC_HL = IC_F0 ("Halo", mkicons PICTURES[12], Frame Off's old place; ic_list 10
  entries, the layout records' choice count 9 -> 10), it_tab 26 entries, the slider cases as Glow's (bar as
  Blacks / Whites, readout glyphs, rv_chk, stp). pm_list: ... Glow / Clarity, Halation, Film Grain.
- ext11 was full (96 B): ic_pay (the row pictures, now 16384 B) moved to ext12 -> ext11 51088 of 65536 B.
- Photo path (block): xb_cap: Halation > 0 with Glow 0 -> the Soft Focus passes (flag 0x80); xb_wt: our looks with
  Glow 0 -> w 1024 (the sharp image unchanged; was: only with Grain); xb_gs: the level from slot +30 (1..5).
- om-emu: the row shows ("Halo ±0" in the column; "Halation" title, slider, readout); dial steps 0..5 (below 0
  refused), "+1" shown and BUNDLES slot +30 = 1 saved at the half-press; a LOOKS.BIN with record 0 +57 = 3 is
  accepted (LPTR set, COLOR 1 = look 1) and the row shows '*' (slot 0 vs film 3). Not reachable in om-emu: the film
  -> slot copy through fl_set (setv 901 runs om-emu out of memory), the capture path (camera test). Static: pf_bt,
  pf_lo, fl_xr and the loop ends checked in the image. Cosmetic: the bar is the -5..+5 one (0 in the middle).
- **h3 camera (owner, 2026-11-12):** CADLOG "v0.28-dev (halation row h3)", 41 events; PB122268..273: Halation alone on
  the white lamp (268 / 269: a clear red-orange halo without the soft glow), with Glow (270), Glow alone (271: no
  red halo), with grain (272), daylight (273: none). No freeze. BUNDLES at the end: COLOR 1 Halation 5, Grain 3.
  Owner: (1) changing only Halation gives no '*' on the FILM 1 entry; (2) the halo "has too much of a sudden cut
  off": PB122269 Cr by distance from the shade peaks ~+35 at 120-140 px and falls +30 -> +7 between 180 and 300 px.
- **h4:** (1) fl_live compares all 16 pf_bt pairs (was 11) and fl_fch bytes 0..57 (was 0..52): the film list's '*'
  follows split toning and halation too. (2) Two layers: E blurred 3 times (tight) and a copy 10 times (broad, a
  third malloc), mixed 50/50 (MIX 128), K 900, gmax 43 / 78 / 113 / 156 / 208. On PB122271 (Glow only) at strength 5
  the half-strength distance moves from ~260 to ~400 px and the tail fades out past 600 px (a 3 + 14, 40/60, K 1200
  variant was softer still). `hl_blur` (one layer, frame 48) replaces the inline loops; hl_run frame 124.
  om-emu: the 8 frames bit-exact with the model; steps +25 % on night frames (29.7 M for 1.8 MP at strength 5).
- **h4 camera (owner, 2026-11-12):** "the fade looks good now"; saves "a little slow, but manageable"; bursts still
  work. FILM 1* now shows in the Picture Mode list, but not on the super control panel.
- **h5:** the quick menu (super control panel) cell is ours (fl_scp -> fl_pcp draws "FILM N"); its stock '*' variant
  ids (15750..15753) follow COLOR k's own settings (fl_pmod, film test 6) and were drawn without a star, so a changed
  film never showed one there. Now fl_pcp asks fl_fch (as the list cell) and draws "FILM* N" (layout fl_LS1, word
  picture mkicons.sp_star_word, the asterisk in the quick menu's lettering) when the film is changed; the drawn key
  is N | star << 8, so it redraws when that flips. The shooting screen's label (fl_lvp) stays without a star.
  om-emu: super control panel with FILM 1 on COLOR 1: "FILM*1" when the film differs from how it was built,
  "FILM 1" with a neutral record equal to the slot. New picture: "FILM*" (quick menu) - owner to approve.
- **h5b (owner: "it should look like FILM 1*"):** the star moves after the number. fl_sp gains an optional trailing
  picture (layout words +48..+60: picture, bytes a row, ink width, gap; 0 = none for fl_LS / fl_LVL), counted in the
  centring and drawn after the last digit; fl_LS1 = fl_LS's "FILM" + digits + the quick menu's '*' (mkicons.sp_star,
  gap SP_DGAP). Direct calls of fl_sp (om-emu, decoded): "FILM 1*", "FILM 12*" (centred), "FILM 7" (plain layout);
  the super control panel shows "FILM1*" / "FILM1" for a changed / unchanged film.

## Owner decisions on the next look features (2026-11-12)
- Gentler Shading (#22): yes. Per-film WB mode / exposure / ISO: yes. Split toning: finer steps and a balance
  slider; no midtones wheel (#23). Our own grain: on hold until the owner compares today's grain with Lightroom /
  DxO. Highlight roll-off and toe: not planned (Blacks / Whites + the Highlight & Shadow curve cover it). Cleaner
  JPEGs (#17): out of scope (the camera's JPEG compression stays). Film borders: not planned (added in editing).
- v0.28 scope: halation (row, Control Panel), our version in the camera's firmware menu, custom crop modes.
  (Later the same day the version screen moved to a later update: see the section on it below.)
- **h5 camera (owner, 2026-11-12):** "it looks good": FILM 1* on the super control panel, the halo and saves as h4.
  The owner has used the "Halo" row icon and the "FILM 1*" lettering from h3 / h5 without objection.

### Our version on the camera's Firmware Version screen: first look, parked (2026-11-12; emulator / disassembly only)
- Owner: wanted for v0.28; after hearing it is more work than expected: "we can just scrap it. it can be a future
  update." Parked; nothing built. What was found, so the next try starts here:
- **The screen:** MENU -> wrench tab page 6 "Reset/Clock/Language/Others" -> "Firmware Version" (row value "1.1" on
  the camera, "0.0" in om-emu) -> OK opens a page titled "Firmware Version" with one centred line "Body : 1.1" (a lens
  adds a "Lens" line). om-emu walk (research/emulator/nav.mjs): `menu left up up right right right right right right
  down down down down down ok`.
- **The text:** the labels are resource strings (UTF-16, the English table loaded at 0x65126fe0 "Body\0Lens\0Flash\0
  Acc", read by the GUI through the uncached alias 0xa5...). The page is drawn as glyph BITMAP commands into the OSD
  command list (the writer is 0x61046980, deep under the GUI's draw stack 0x61043680 / 0x61045ea6 / 0x610f6834 /
  0x610eb14f ...). The firmware's wide sprintf 0x610fc42c (frame 116) and wide copy 0x610fce25 are NOT used for this
  page (only for the live-view info).
- **Data-driven:** with an exec trace of the whole OK step, opening Firmware Version and opening Certification run
  exactly the same code addresses (99,200 PCs each, none different): the pages are built by generic code from layout
  data, so the hook is not a screen-specific function but the layout entry for this page (or the generic value
  formatter it names). Not found yet: the layout record, and where the "1.1" comes from (om-emu has no body version:
  0.0; `API_FIRMWARE_VERSION_BODY` is only a debug-command name list at 0x60b60a75).
- Next step, when picked up: find the page's layout record (by its title string id, "Firmware Version" in the resource
  table) and how its value item gets "1.1"; then either add a second line to the layout or swap the value text for
  "1.1 / Caduceus v0.xx". om-emu tracing notes: read watches only fire on the uncached alias (0xa5...); `call f,[...],N`
  leaves the return address in MDR and the caller's stack at sp + N at f's first instruction.

### Halation h6: the bar runs 0..+5 (2026-11-12; emulator only)
- Owner (after h5): the Halation bar "looks like it can go from -5 to +5, but we want it to just go from 0 to +5". It
  borrowed Glow / Clarity's -5..+5 bar (rw_bar ends -5 / +5, 0 in the middle).
- h6: rw_bar gives HL_IT its own ends a3 = 0, max 5 (the stock "-" greys out at 0, "+" at 5; st_chk already stops
  HLB at the ends). sl_dot: a 0..5 bar (min 0, max 5) places the dot at value x 124 - 310 px from the centre (0 at the
  left end, 5 at the right end, as the -5..+5 bars' ends). The readout takes its own tables rd6_a / rd6_b (0..5).
- The readout can not show a plain "0": the six callers of the sign lookup (e.g. 0x611d1233) draw sign 1 as "+-%d"
  (char 130), 2 "+%d", 3 "-%d" (wide formats at 0x61551060..70) and nothing at all for any other sign (tried: sign 0 hid
  the number). So 0 reads "+-0", as on every camera slider. The small dot above the bar's middle is part of the stock
  bar picture (the -5..+5 and -2..+2 bars both have it), not placed by the dot code: it stays. (2026-11-14: it is
  the bar block's child 15, and sl_dot now hides it on the 0..5 bar. See "Picture Mode display, stars and saving".)
- om-emu (out-h6b, Halation slot +30 poked to 0 / 3 / 5): dot at the left end / 60 % / the right end, "-" grey at 0,
  "+" grey at 5, readout +-0 / +3 / +5; left column "Halo +3*". Package: E1479999.BIN 6fc8dae8…, GUIDES.BIN 4ad05bf9…
  (LABELS / TONES as h5). firmware/VERSION "v0.28-dev (halation h6)".
- **h6 camera (owner, 2026-11-12): "that looks great!"** The Halation bar runs 0..+5 on the camera. Halation is done
  on the camera side; the Control Panel part remains. Owner: custom crop modes go last in v0.28; split toning next.

### Split toning t1: gentler steps, positive-only wheels, Tone Balance row (2026-11-12; emulator only)
- Owner: lessen the effect; wheels only positive ("we are always adding, not removing"); a balance ("make the shadow
  tone more, or the highlight more"). Chosen: 0..5 with half-size steps (+5 = v0.26's +2.5; films keep their numbers,
  so they come out at half strength); Balance as a Picture Mode row right under the HSL wheels row ("that is where
  you'll be adjusting it"). Custom crop modes moved to the end of v0.28.
- Engine (st_run): `>> 9` (was 8): 2.4 Cb/Cr units per step at the weight peak; strengths clamped 0..5 (negative =
  off, so an old -n reads as off). Balance b (slot +33): weights at u instead of t, hand-over point c = 2048 - 256 b
  (768..3328), u = t * f1 >> 16 below c, 2048 + ((t - c) * f2 >> 16) above, f1 = 2^27 / c, f2 = (2047 << 16) /
  (4095 - c) (two divs per pass; b = 0 gives u = t exactly). Frame 76 -> 92: (76) c, (80) f1, (84) f2, (88) t.
  research/splittone/model.py `bend28` = the camera's math.
- om-emu (out-t1, probe_test.py's stage + tone passes, slot bytes poked): Cyan 5 / Orange 5 at balance 0, +5, -5,
  +2, Shadows -3 (off) / Orange 2, Yellow 1 / Green 4 at -3: all **bit-exact** with the reference (all 320 entries x 3
  channels); model.bend28 equals the 256-entry part. Tints at balance 0 are half of v0.26's (input 16: Cr -8.4 vs
  -16.7). +5 pulls the highlight tint down (input 64: Cb -8.1 Cr +2.9 vs -6.9 / -1.0 at 0); -5 pushes the shadow
  tint up (input 128: Cr -3.8 vs +3.5).
- Wheels: tn_set refuses values below 0, TONEV shows 0..5. om-emu: on Shadows, rear dial down at 0 does nothing,
  up to 3 sets the colour, back down to 0 switches it off (slot colour and strength 0), further down stays 0.
- Row: TB_IT 5379 (key 5373), bars TBB 0x7ee0 + k (row 14), class 13 (slot +33, -5..+5, as Glow's bar and readout),
  title ST_TBL "Tone Balance", left icon IC_TB = IC_F1 ("Bal", mkicons PICTURES[13], Frame On's old place); it_tab 27,
  ic_list 11 (choice count 11), pm_list: Picture Mode, HSL, Tone Balance, Contrast, ...
- Storage: BUNDLES slot **+33** (the shared layout's first `sat` byte: -5..5 in every OM-3 firmware's range table,
  unused on COLOR slots: going back keeps BUNDLES valid); LOOKS / EDITS record **+58** (pf_lo -5; pf_bt 58,9; loops
  to pf_bt+34; fl_xr row 14 = (58, 33); fl_live 17 pairs, fl_fch bytes 0..58). Firmware before v0.28 rejects a
  LOOKS.BIN with +58 != 0 (Control Panel: gate as halation). docs/FORMATS.md now also lists the v0.26 split-toning
  bytes.
- om-emu UI: the row under HSL ("Bal +-0"; "Bal +5*" when set), bar -5..+5 with the dot at -3 / +5, readout -3 / +5.
- Not done yet: the Control Panel (preview at half strength + balance, 0..5 wheels, +58 export gated to v0.28); the
  photo code (EXIF, om3.1) still carries record bytes 0..56 only (no halation, no balance).
- Package t1: E1479999.BIN 2040a94e…, GUIDES.BIN bfe23233… (LABELS / TONES as h6). VERSION "v0.28-dev (split tone t1)".
  New picture "Bal" (left column) sent to the owner for approval.
- **t1 camera (owner, 2026-11-12):** (1) "I struggle to see the tone at all now": back to the first proposal, the top
  as strong as v0.26's +5 with twice the steps (0..10). (2) Bug: on a wheel colour the dial still counts below zero
  without showing it (the camera's wheel keeps its own value; tn_set refused it), so after scrolling down you need
  extra clicks up. (3) "the balance slider looks great!"

### Split toning t2: 0..10 on the dial, no hidden count (2026-11-12; emulator only)
- Strength s 0..10 in half the v0.26 step (st_run >> 9 as t1): **10 = v0.26's +5 exactly** (om-emu: the tables equal
  v0.26's formula at Cyan 5 / Orange 5). Stored as a code -5..5 so every firmware's range checks still pass (BUNDLES
  valid on v0.27.1, LOOKS +54 / +56 within pf_lo -5): v >= 0 -> s = 2v (v0.26 / film values keep their strength:
  a film's 2 is now 4 of 10, the same look), v < 0 -> s = -2v - 1 (1, 3, 5, 7, 9). Older firmware would read the odd
  steps as the opposite colour (going back only). research/splittone/model.py `strength()`.
- The bug of t1 (owner: the dial counts below zero unseen): the wheel keeps its own value per colour and t1's tn_set
  refused negatives. Now the wheel's own -5..+5 is the strength: TONEV shows s - 5 for the page's colour and -5 for
  the others; tn_set stores w + 5 (the wheel stops at both ends itself). om-emu: down at 0 x3 -> nothing; up 1..10
  (codes -1, 1, -2, 2 .. 5), stops at 10; 12 down -> 0 (off); one up -> 1 at once.
- Readout (wheel caller 0x611d1427, item 5397, on axis 5 / 6 only: TONEPG in rd_a / rd_b, a2 saved by movm):
  rd10_a / rd10_b give "+-0", "+1".."+9". The record's text has 3 characters (+2..+7, then its flags), so "+10"
  would overrun: for 10 rd_a gives sign 0 (the caller writes nothing) and rd_b, when MDR = 0x611d1433 (that caller),
  writes "10" itself. om-emu: "+9", "10", "+-0" on Highlights; the Saturation page still -5..+5 ("-2").
- Engine (out-t2b, the probe stage): codes 5 / 5, -3 / -1, 5 / 5 with balance +3, -5 / 1 with -2: bit-exact.
- Package t2: E1479999.BIN 8547ddaa…, GUIDES.BIN 40c1ffeb… (LABELS / TONES as h6). VERSION "v0.28-dev (split tone t2)".
- **t2 camera (owner, 2026-11-12): "It works!!"** Wheels 0..10 with no hidden count, the tone strength back, Tone
  Balance as in t1. The owner has used the "Bal" row picture without objection. Split toning is done on the camera
  side; the Control Panel part remains (half-step preview with model.py bend28 / strength(), 0..10 wheels, the
  balance slider, +58 export gated to v0.28).

## Gentler Shading (#22): first look and probe s1 (2026-11-12; analysis + emulator only)
- Owner: make Shading less powerful (roadmap: -5 / +5 like today's -2 / +2, finer steps between; #22: "make the
  camera match your looklab", whose preview is f = 1 + 0.07 s r^1.5 on RGB, r = (distance / half-diagonal)^2).
- Static (analysis): request **+1752** (s8) is the Shading level; in code it is read (as a byte) only by combiner 33's
  handler 0x60505142 (also +1089 in kind-3 records), and only for its **sign**. With Shading on the handler sets a
  "shading block" in the combiner config (O+7988): +128 = {512 << 16 | 0 (darker) or 1023 (lighter)}, +132 512,
  +136 / +140 0, +144 0x151500, +148 0x04000400, +152 1024 (the MONO branch zeroes 128..148 and sets +144 0x2a1500
  when Shading is 0). None of them carries the level's size, so the amount is set elsewhere (candidates: the
  development's radial shading table, `ausEffectiveShadingCoefficient[64]` at +124 of the struct the RAW-parameter
  dump 0x61a3171b prints, with `ucShadingCancel` at +252; not traced). Readers of +1753 (0x60501066) index 18-entry
  hue tables (toning / colour filter), not Shading.
- Probe s1 (branch `experiment/shading-probe-s1`, VERSION "v0.28-dev (shading probe s1)"): combiner 33's handler word
  (table 0x606cc794, entry 33) -> sh_h33 (ext12): the stock handler in a dispatcher-like frame (`call
  h33_stock,[d2,d3,a2,a3],28`, as the archived gl4 s_h / xb_h33), then for kind-0 requests with +1752 != 0 and the
  COLOR context: COLOR 2 +128's 512 -> 205, COLOR 3 +132 512 -> 205, COLOR 4 +152 1024 -> 410 (40 %); COLOR 1 stock.
  om-emu: boots, menus and half-press as t2 (the emulator runs no development, so the hook itself is camera-only).
  Package: E1479999.BIN 44816a42…, GUIDES.BIN 237ef8ee…. Camera: Shading -5 (and +5) on COLOR 1-4, one even-lit
  photo each.
- **s1 camera (owner, 2026-11-12; PB122284-291, 17 mm f1.8 1/40 ISO 400, plain wall, Shading -5 then +5 on COLOR
  1-4):** Y by radius (centre .. corner, 400x300): stock -5 130 -> 7 (corner / centre **0.057**), +5 131 -> 243
  (1.85). COLOR 2 (+128 upper half 205): corners **olive** (-5) / **yellow** (+5); COLOR 3 (+132 205): **green** /
  **cyan**; COLOR 4 (+152 410): about stock (corner 8.5 vs 7.4). So **+128 = {Cb target << 16 | Y target 0 / 1023},
  +132 = Cr target (512 neutral)**: the corners are blended toward that colour by a radial mask that is ~1 at the
  corners at -5 / +5; +152 is not its strength. The mask's strength is set elsewhere.
- Probe s2 (branch experiment/shading-probe-s1, VERSION "v0.28-dev (shading probe s2)"): COLOR 2 +192 1024 -> 410
  (the dispatcher's default for every combiner), COLOR 3 +148 -> 0x019a019a, COLOR 4 Y target 0 -> 409 / 1023 -> 614
  (tells a linear blend toward grey from a multiplicative one), + the GLOG.BIN logger (xblock XB_LOG 1; copy A = the
  first kind-0 request's first 1856 B) for COLOR 1 at -5 / -3 / -1. Package E1479999.BIN d87eaf60…, GUIDES.BIN
  06ba2216…; om-emu: boots, saves (no capture there, so no log).
- **s2 camera (owner, 2026-11-12; PB122292-297, room with a window, 17 mm f1.8 1/100 ISO 200; COLOR 1 at -5 / -3 /
  -1, COLOR 2-4 at -5) + GLOG.BIN ('GLG3', 10 marks: two per photo, the first two photos overwritten):**
  - Each photo has two kind-0 developments: key 0xb0000 (context key 11, effect 0x0c00, combiner 33) and key 0x20000
    (context key 2, effect 0, combiner 0), then kind-3 finals. The request differs between -1 and -5 (both
    developments) only at **+1752** (0xff / 0xfb), +1655 / +1663 (1 / 0), +1590 (105 / 0, first development only)
    and +1556..+1559 (0 / 48, 95, 98; +1557 differs between the -5 shots too): **no strength table in the request**;
    the level reaches the mask some other way (not traced).
  - Y by radius (centre .. corner): -5 105 / 74 (r .45-.6) / 22 (.7-.8) / 3.5 (corner); -3 114 / 78 / 25 / 5.1;
    -1 107 / 80 / 30 / 8.8: the camera's levels mostly move the ring inwards; even -1 leaves the corner at ~8 %.
  - COLOR 2 (+192 1024 -> 410): the **whole picture** at ~0.40 (an overall gain, set to 1024 by the dispatcher for
    every combiner). COLOR 3 (+148 -> 0x019a019a): about stock. COLOR 4 (Y target 409): the corners go **grey and
    foggy** (dark areas lifted): the blend is linear toward the target colour, Y' = Y + m (Yt - Y). So a softer
    target is no way to a gentler vignette, and the mask amount is still unfound.
  - Options: (1) our own CPU vignette on stills (the Control Panel's f = 1 + 0.07 s r^1.5, any step
    size; camera Shading 0; route as halation: Soft Focus passes at weight 1024 + a CPU pass; not in live view; a
    little slower saves); (2) more probes for the mask amount (keeps live view, no time cost, uncertain).
- **Owner (2026-11-12): "if it isn't easy to do, let's scrap it"**, then: not "not possible" but **difficult**:
  Gentler Shading is parked (ROADMAP "Difficult (parked)"; #22 to be answered so). The probes stay on `experiment/shading-probe-s1` (s1, s2) for
  anyone who picks it up: the next lead would be the mask's source (the radial `ausEffectiveShadingCoefficient` table
  or another unit configured from request +1752 / +1590).

## Film WB: a film sets the camera's WB (2026-11-12; emulator, probe w1)
- Owner: films carry a Kelvin; set on the camera (a new WB row) and later in the Control Panel; values as the
  camera's own Custom WB (2000..14000 K, 100 K steps); a film or COLOR without one sets **Auto WB**.
- Settings (om-emu, confirmed by the camera's own super control panel): **1578 = stills WB mode** (the 13-entry table
  0x615d1944 {mode, stills A-B id, movie id}: 0 Auto, 6 Sunny, 8 Shade, 7 Cloudy, 1 Incandescent, 3 Fluorescent,
  18 Underwater, 17 Flash, 13..16 one-touch 1..4, **9 = CWB**), **107 = Custom WB Kelvin** (sget 5400 = its default;
  519 / 520 also read 5400: probably the RAW-edit pair, as the E-P7's 520 / 521). 1579 = movie WB mode.
- In om-emu the stock getter / facade setter hang for 1578 when called from the debugger (as 901), and the WB screen's
  reads do not pass sl_get after it opens; writing through the settings manager from our code works.
- Probe w1 (branch experiment/film-wb-w1): fl_set -> fw_probe (ext12): film on COLOR k -> manager(107, 3000 + 1000 k),
  manager(1578, 9); COLOR k itself -> manager(1578, 0). om-emu: after picking FILM 3 on COLOR 1 the super control
  panel reads **CWB 3000K**; scrolling the Picture Mode list applies each entry live (fw_probe runs per step).
  Package E1479999.BIN d5bd54cf…, GUIDES.BIN 0267380d….
- **w1 camera (owner, 2026-11-12):** picking FILM 1 sets **CWB 3000K** on the camera (camera-tested), but changing the
  WB afterwards **snaps back to 3000K**: fw_probe ran on every setting-901 write, not only when the selection changed.
  Owner: the list is COLOR 1-4 then FILM 1-20 (describe tests by FILM number; FILM 1-5 = COLOR 1's looks internally).
- **Probe w2** (experiment/film-wb-w1): fl_set keeps the look before in its (24,sp) (unused on the COLOR path) and
  passes it to fw_probe, which returns when the look is the same and sget(111) is already COLOR k's picture mode (the
  camera writes 901 again at each half-press: caller 0x60ae741e). om-emu: FILM 3 -> CWB 3000K; WB changed by hand
  stays after two half-presses; FILM 20 -> 6000K; COLOR 4 -> Auto. Package E1479999.BIN b7923634…, GUIDES.BIN a3412046….
- **w2 camera (owner, 2026-11-12):** a WB set by hand now stays (camera-tested), until another film is picked.
  Owner: "Ideally it will keep its balance when changed so you can go back to it. like it does for hsl": **each film
  (and COLOR) remembers the WB last used on it**. New design (w3): no WB row; the camera's own WB controls are the UI.
  When the look or picture mode changes (fl_set), the camera's WB (1578 mode, 107 Kelvin for CWB) is first kept in the
  slot of the COLOR being left, then the new look's stored WB is set (none / Auto -> Auto). Stored as balanced base-11
  digits (v = lo + 11 hi, lo / hi -5..5, so zero bytes = none and every firmware's range check passes): slot
  +34 / +35 Kelvin v = (K - 2000) / 100 - 60 (CWB only, else 0), +36 / +37 mode code = index in the 13-mode table
  (0 = Auto / none); LOOKS / EDITS record +59..+62 (pf_bt pairs, so EDITS, the film's '*' and the hold-OK reset follow).
- **w3 (feature branch; VERSION "v0.28-dev (film WB w3)"):** fl_set at its COLOR path: fw_keep (frame 48) sees a change
  (look, or picture mode via sget(111) vs fl_cvt[k]) and first keeps the camera's WB in the slot of the COLOR being
  left (sget(1578) -> its index in table 0x615d1944, Auto -> 0; CWB also sget(107) -> v), P+DIRTY; fl_sw then saves a
  film being left with it; at label 4 fw_apply (frame 32) sets the new look's stored WB through the manager (Kelvin
  first for CWB; none -> Auto). pf_bt + (59,10) (60,11) (61,12) (62,13), loops to pf_bt+42, fl_live 21 pairs, fl_fch
  bytes 0..62, pf_lo -5 for +59..+62. Bugs met on the way (om-emu): `sget` does not keep a2 (fw_keep saves P in a
  local); a frame's locals must stay below the saved registers (`call f,[d2,d3,a2,a3],N` keeps them in the top 16 B
  of N: fw_keep 28 -> 48, fw_apply 20 -> 32; the w1 / w2 probes had the same fault, harmless there by luck).
  om-emu: FILM 3 Auto -> Sunny by hand -> FILM 7 Auto -> FILM 3 again **Sunny 5300K and FILM 3***; FILM 3 CWB 5400K
  -> FILM 7 Auto -> FILM 3 **CWB 5400K**. Package E1479999.BIN 9b73b5a0…, GUIDES.BIN 8d8d8c4b… (LABELS / TONES as t2).
  Not done: the Control Panel's WB fields (with its v0.28 work), the photo code (EXIF) does not carry it.
- **w3 camera (owner, 2026-11-12):** the film the camera is left on keeps its WB over a power cycle; **the others come
  back on Auto**. Cause: tw_san (the EDITS.BIN clean-up at load) cleared record +57..+62 as "unused", so every film
  saved in EDITS.BIN lost its **film WB, Halation and Tone Balance** at each power-on (the current look lives in the
  BUNDLES slot, which sd_san checks by range instead). **w4:** tw_san clears each of +57..+62 only when outside -5..5
  (+63 as before). om-emu (two sessions, the card saved between them: FILM 1 Sunny -> FILM 2 -> save -> restart ->
  FILM 1): w3 Auto, **w4 Sunny 5300K**. Package E1479999.BIN e9820df4…, GUIDES.BIN f76e06be….
- **w4 camera (owner, 2026-11-12): "that worked perfectly!"** Each film keeps its WB (Custom WB Kelvin and presets)
  over film switches and power cycles, and a film without one gets Auto (camera-tested). Film WB is done on the camera
  side; the Control Panel part (WB per film in the editor, export of +59..+62 for v0.28) remains, and per-film exposure
  compensation / ISO are not started.

## Blacks / Whites grid again (2026-11-12; owner)
- Owner: "with the color profiles getting long", combine Blacks and Whites into one grid row like the WB (A-B / G-M)
  grid again (bw1, 2026-11-08, was turned down: "that don't look too good"; code in commit 2fa6a5c). This time the
  grid is black on the Blacks axis and white on the Whites axis. Mock-ups (private project folder, mockups/): plain
  black edges vanish on the dark screen; owner chose **D**: black -/+ boxes left / right (Blacks), white -/+ boxes
  top / bottom (Whites), and the grid's edges black (outlined) and white to match.
- Port plan (bw1 = commit 2fa6a5c, on v0.25 code; branch `feature/v0.28-bw-grid` from feature/v0.28-halation):
  - Row: BK_IT becomes the one-option grid row (it_tab {BK_IT, bk_title, bw_l0 "Blacks / Whites", bw_l1 / bw_l2
    IC_BW}); WH_IT leaves pm_list. Bars **BWB = 0x7ef0 + k (row 15; 0x7ed0 is now HLB)**, **class 14** (bw1 used 12,
    now Halation; 13 is Tone Balance), so every bw1 "class >= 11 = grid" test becomes "class 11 or 14": SL_VAL
    (wb_draw mode), sl_cnt (1), LOWCNT (0, 1), sl_set0 (nothing stored). sl_slot / sl_gb: BWB and BK_IT -> 14.
    CHC bw_a..bw_f, lc_bw; build.py: BK_IT 'bw' in the OWN switch loop (as AB_IT 'wg'), BK / WH out of the slider
    loop. gr_lc BK_IT -> bw_tab. The BKB / WHB bar ids and classes 5 / 6 stay (gr_id maps the grid's ids to them).
  - Grid screen (gr_mode 1, gr_lmode; gr_upd by row; gr_id + BKB - ABB; gr_pub's dot from +47 / +48): ic_get swaps
    while gr_flag and gr_mode = 1: box letters G 10324 / A 10327 / B 10325 / M 10328 -> look D boxes (A '+' and B
    '-' black, G '+' and M '-' white, 32 x 32), header letters -> '+' / '-', "WBAuto" 11240 -> "Blk/Wht", and the
    grid's coloured edges -> black (left / right) and white (top / bottom): find which of 10904..10907 carries them.
  - Pictures (ours, LABELS.BIN 'WBG1' section, mkicons): bw_top "Blk/Wht" 82 x 30, the four boxes, the header '+',
    the edge picture; glyphs '+', '-', '/' for the left cell "Blk/Wht" over "+2/-1" (xb_wbc mode 1, two stream
    buffers). Sizes then: GUIDES.BIN block, LABELS.BIN, ext11 / ext12.
- **g1 (branch feature/v0.28-bw-grid; VERSION "v0.28-dev (Blacks / Whites grid g1)"; emulator only):** the port as
  planned: BK_IT the one-option grid row (BWB 0x7ef0 + k, class 14; bw_l0 "Blacks / Whites", left cell IC_BK =
  mkicons PICTURES[0] now a 100 x 76 "Blk" / "Wht" cell, without values), WH_IT out of pm_list; gr_mode / gr_lmode
  (gr_upd reloads scene 498 between the two grid rows), gr_id + BKB - ABB, gr_pub from +47 / +48. ic_get, while
  gr_flag and gr_mode = 1: the WB mode title 11218..11248 (each mode with and without '*': 11223 "WBAuto", 11240
  "WBAuto*", tables 0x6139a694 / 0x614778fc) and bwg_swap {10904 square, 10327 A, 10325 B, 10324 G, 10328 M, header
  letters 10813 / 10814 / 10817 / 10818 '+', 10815 / 10816 / 10820 '-'} -> our IC_BWG 0x7f70.. (mkicons
  bwg_pictures, build.py bwg.inc in ext12: square 206 x 206 drawn to the camera's layout (fill 52, cross and 15 ticks
  in 81, 6 px bands; black bands outlined in 81), boxes 32 x 32, header signs 16 x 30, title 86 x 44).
  om-emu: the row with our square and boxes; OK -> fine-tune, header "Blk/Wht 0 . 0" (also with Sunny WB), dial ->
  "0 . +1" / "+1 . +2" with the dot; MENU back; the WB row's coloured G / B / A / M grid unchanged. ext11 53264,
  ext12 214176 B. Package E1479999.BIN 33171059…, GUIDES.BIN 511b434b… (LABELS / TONES as before).
- **g1 camera (owner, 2026-11-12, photo of the screen): "This is looking good."** The row's grid shows the black / white
  boxes and edges as look D (camera-tested). Owner asks: (1) 7 steps each way to match the WB grid; (2) the values in
  the left cell, as the WB row's "WB± B1.M1".
- **g2 (owner: 7 steps as the WB grid; the values in the left cell):** Blacks / Whites -7..+7 with the same step
  (owner: "Two more steps"): tone clamps 15 / 7 (was 11 / 5), sl_cnt 15 and LOWCNT -7 for classes 5 / 6, sl_set0
  range, pf_lo +39 / +40 -7, build.py RANGES blacks / whites (-7, 7) (an older firmware's sd_check refuses a BUNDLES.BIN
  with +47 / +48 beyond 5: going back needs them within 5). Left cell: bw1's xb_wbc mode 1 (two stream buffers, top
  "Blk/Wht" from LABELS.BIN 'WBG1' pictures), bw1's mklabels / mkicons (WBC_CHARS + '+', '-', '/'; WBC_N in the block's
  inc), wb_draw with the mode (wb_desc / bw_desc, +24 drawn-for), wb_v + 36, IC_BW 0x7f7f -> bw_desc (our static
  "Blk / Wht" until drawn), SL_VAL class 14 -> wb_draw mode 1. om-emu: cell "Blk/Wht +3/+7"; fine-tune header
  "+3 . +7", the dot at the grid's top edge at +7 (the screen stops at the facade's 15); the WB row unchanged.
  LABELS.BIN 88f4c049… (= bw1's), GUIDES.BIN c3449baf…, E1479999.BIN d4941147….
- **g2 camera (owner, 2026-11-12): "that works and looks good"** (camera-tested: -7..+7, the values in the left cell).
  Owner: an icon for the cell like the WB row's WB± icon (instead of the word "Blk/Wht").
- **g3 (2026-11-12, emulator only): the cell's icon.** The owner chose icon A from two drawn previews: a plate like
  the WB row's WB± icon reading "B/W" with a ± square (82×30, drawn from scratch in `mkicons.bw_top()`; dark text on
  a white plate, the square's upper-left half dark with a white '+', a dark '−' lower right). It replaces the word
  picture "Blk/Wht" in WBG1 (LABELS.BIN); firmware and GUIDES differ from g2 in 12 / 17 bytes (the version string). om-emu: the cell
  shows the icon alone at 0 / 0 and the icon over "+2/+3" when set, the WB row unchanged. LABELS.BIN eac8eb47…,
  GUIDES.BIN 98640306…, E1479999.BIN d931c334….
- **g4 (2026-11-12, emulator only): at 0 / 0 the icon alone, bigger and centred** (owner, after g3: "when the b/w grid
  and the wb grid are at zero, the icon should be centered and bigger", for both rows). `mkicons.plate_icon(text, k)`
  is g3's plate made scalable (k = 1 gives bw_top's plate exactly, checked); `zero_cell()` puts it at k = 1.4 (92 x 42)
  in the middle of the 100 x 76 cell, for "WB" and "B/W" (the WB one is our drawing too, in the style of the camera's
  WB± picture, which the cell keeps over its values). build.py: zc_tab / zc_p0..1 in bwg.inc (ext12); wb_draw points
  the descriptor there when both values are 0 (no xb_wbc call). om-emu: both rows big at 0 / 0, "B/W" small over
  "+2/+3" when set, big again back at 0 / 0. LABELS.BIN unchanged from g3 (eac8eb47…).
- **g4 camera (owner, 2026-11-12): the big icons' left and right edges are clipped.** The Picture Mode list shows only
  an 82 px strip of the 100 x 76 cell, cell x 9..90 (WBC_IX, the WB± picture's slot): om-emu shows it too (the
  92 px plate's dark edges missing; I missed it in the g4 shots). Lesson: measure the drawn edges in the emulator
  shot, not only look at it.
- **g5 (2026-11-12, emulator only):** ZC_K 1.2 (plate 79 x 36), centred in the shown strip (`mkicons.ZC_WIN`, an
  assert keeps it inside). om-emu: both plates' dark edges visible on both sides (screen x 15..93 in the strip
  14..95). E1479999.BIN 93f434d3…, GUIDES.BIN efd62b87…, LABELS.BIN unchanged (eac8eb47…).
- **g5 camera (owner, 2026-11-12): "that looks great! and works well too"** (camera-tested: the 0 / 0 icons whole,
  the B/W icon, -7..+7, the values). The Blacks / Whites grid is done on the camera; the Control Panel part (one
  Blacks / Whites grid or two -7..+7 sliders, export gated to v0.28) comes with its v0.28 work.

## Control Panel for v0.28 (2026-11-12; local dev server + vitest, not live)
- Owner: update the Control Panel for everything in v0.28 (Halation, split toning 0..10 + Tone Balance, film WB,
  Blacks / Whites ±7). Owner's choices: Blacks / Whites as a **grid like the camera's** (not the curve ends any more);
  the film's WB mode **previewed as if the photo was taken in daylight**.
- Look JSON (schema still caduceus-om3-look/1: new fields only): `halation` 1..5, `tone_balance` -5..5, `film_wb`
  {mode: one of the camera's 13 (table 0x615d1944 order, checked in the decoded firmware: auto, sunny, shade, cloudy,
  incandescent, fluorescent, underwater, flash, one_touch_1..4, custom), kelvin 2000..14000 / 100 for custom};
  `split.sh` / `split.hl` stay in v0.26 steps, now in halves 0..5 (the editor shows the camera's 0..10). A v0.26
  minus (opposite colour) is read as the wheel's opposite colour (+6) with a plus.
- LOOKS.BIN: firmware choice "v0.28-alpha or later" (Fw 28): +39 / +40 -7..7, +54 / +56 the half-step code (n even ->
  n / 2, odd -> -(n + 1) / 2), +57 Halation, +58 Tone Balance, +59..+62 film WB (balanced base-11 as FWENC: Kelvin v =
  (K - 2000) / 100 - 60, then the mode index). Older choices leave all of it out (±5, whole v0.26 steps, rounded up);
  the export dialog lists the looks that lose something. Reading: half-step codes when the choice is v0.28 or any
  record has +57..+62 set (a v0.26 file's minus otherwise). Photo code: bytes 58..62 now read signed.
- Preview: Tone Balance in `bendSplit` (bend28's u mapping); film WB = linear gains white(5300 K) / white(mode K)
  (Planck locus, Kim et al.), Auto / Underwater / one-touch not shown; Halation = a float port of
  research/halation/model.py on the camera's pixel scale (5184 px wide, 64 px cells). Check against the exact model
  (photo upscaled to 5184, halate level 5, back down) on the sample photos: bluehour R corr 0.978, neon 0.986, mean
  abs diff < 1 level per channel; paris and brasserie "off" (too bright) in both.
- Default firmware choice stays v0.26.1 – v0.27.1 (the released versions): the new settings then show a "Needs
  firmware v0.28" note and are left out of the preview, as split toning was before v0.26. Default film looks unchanged
  (their split tones are whole steps).
- Not done: `looklab/` (the live site) not rebuilt; docs/USING.md not updated. Both with the v0.28 release (or when
  the owner wants the live site updated).

## Photo code for v0.28: the film as set, Halation / Tone Balance / WB, still om3.1 (2026-11-12; emulator only, pc1)
- Owner asked whether the EXIF code reflects the v0.28 settings: it did not (it coded the film's LOOKS.BIN record as
  built, never the on-camera changes; v0.28 records the new settings mostly on the camera). Owner: **keep om3.1**
  (no new name): the new settings go into the spare bytes; split toning, whose LOOKS.BIN meaning changed in v0.28 (the
  half-step code), stays in v0.26 steps in the code with the half steps in the last spare byte 63.
- The settings getter is not safe during the capture (v0.24's AGET reboot), so **ex_live** reads them at each
  half-press in the HLS_EVENT task (the gate of lg_write, whose sget calls are camera-tested in the debug log):
  COLOR k's settings now (pf_capto) + the camera's WB now (1578 / 107 as fw_keep, FWENC into +59..+62) -> ex_rec,
  ex_rk = k. Called from lg_pr (every half-press after the first) and, for the first half-press of a power-on, from
  sd_load's last call (`nm_ex` = nm_load + ex_live: same size call in ext4; ext1 is full, 1744 / 1744 B).
- ex_cd1 (at the shot, d2 = COLOR k): ex_rec when ex_rk == k, else the LOOKS.BIN record as built; copied to ex_out,
  +54 / +56 v < 0 -> ~v with bit 0 / 1 in +63; then the nibble / base64 code as before.
- Found: ex_code was 48 B for 50 written (om3.1. + 43 + NUL): the last 2 bytes went into alignment padding (harmless
  since v0.27); now 52 B.
- om-emu (scratchpad pc1test.mjs, `runp:` = call with a2 = P): ex_rk 0 after the first half-press (COLOR 1); with
  slot pokes (Halation 3, Tone Balance -2, Highlights colour 9, code -2 = 3 half steps) and a second half-press,
  ex_rec +55..+58 = 9, -2, 3, -2, WB Auto (+59..+62 0); ex_cd1 for k = 0 -> ex_out +55..+63 = 9, 1, 3, -2, 0, 0, 0, 0, 2
  and the code `om3.1.AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACRPgAAI` (= the expected encoding); k = 1..3 the record as
  built. Menus and further half-presses afterwards: no crash.
- Readers: Control Panel `lookFromPhotoCode` (photo codes: v0.26 steps + byte 63, never the LOOKS.BIN half-step code),
  `firmware/photocode.py` (split_steps, film_wb), `devkit/photo-code` (om3code.js: halation, toneBalance,
  whiteBalanceMode, split toning 0..10; examples v028 / v028wb; README table), docs/PHOTO_CODE.md (v0.28 used the last
  spare byte: the next new setting needs om3.2). The release's photo code kit zip is rebuilt with v0.28.
- Package pc1: E1479999.BIN 640cdafd…, GUIDES.BIN 572226a4… (LABELS / TONES as g5). VERSION "v0.28-dev (photo code pc1)".
- **pc1 camera (owner, 2026-11-12): works.** 17 photos on FILM 5 CineStill 800T (only the UserComment code read off
  the card, nothing copied or kept): the first 3 as the film was (Highlights Green-cyan 2 of 10, WB Auto); after the
  owner's changes on the camera **Halation 3, Tone Balance -2, Blacks -2 / Whites +6, Highlights Orange-red 3 of 10
  (byte 56 = 1, byte 63 bit 1), Glow 1, Grain Med, Custom WB 3200 K**; then WB Sunny for one photo and a 12-photo burst,
  every code the same and complete (camera-tested: the live record at the half-press, the WB at the shot's half-press,
  bursts).

## Code space check (2026-11-12, after pc1; owner asked to double-check the numbers)
- Two clean rebuilds of b72881b (a fresh worktree): the same section sizes and E1479999.BIN 640cdafd… (= pc1, camera-
  tested). Sizes read twice (build.py's SIZE lines; the ELF's section headers, readelf): ext12 217664 of 262144 B
  (**44480 free**), ext11 53408 of 65536 B (**12128 free**); the section tails ext1 1744 / 1744, ext10 1264 / 1264 (full),
  ext4 1588 / 1776, the others a few bytes each (hooks only).
- The free bytes are 0xFF in the build and in the stock main block; the loader end word 0x60045e9c is 0x60f99800 in the
  build (stock 0x60f49800), so ext11 / ext12 load whole. Reserve (GX4 camera probe): 0x60f99800..0x6103f000 =
  **677888 B (662 KiB)**, all 0xFF in stock, OM's code resumes at 0x6103f000; using it needs the end word raised.
- **GUIDES.BIN: 13416 of 16448 B, 3032 free** (the whole file is one malloc block, pools end at 16448 B: pictures
  6792 + code block 6624). build.py now asserts 16448 (it allowed 24576, gd_load's own limit). The earlier "about
  10 KB" told to the owner counted the code block alone against 16448: wrong, corrected.

## Custom crop modes: what Caduceus for the E-P7 did (2026-11-12; read only, their docs/ASPECT.md, issues #7 / #23)
- Read only (nothing copied): cakelesscoder/caduceus-ep7 docs/ASPECT.md, patches/aspect*, README, issue #23. Their
  addresses are E-P7 1.1 and none apply here; this is a map of what to look for in the OM-3 firmware.
- Approach: the E-P7's aspect setting (sid 270, values 1..10) has hidden still values 5:4, 7:6, 6:5, 7:5 (in its
  tables, absent from the menus). They turned 7:6 and 6:5 into **Panorama 65:24 (5184 x 1920)** and **Wide 21:9
  (5184 x 2224)**: full sensor width, centred, the same width / centre as 16:9.
- What had to change, each found by a camera round (8+ rounds, 145 edits / ~2 KB, then 13 stubs / 484 B):
  1. the option lists (main menu, Super Control Panel strip, a third list for the SCP current-value cell);
  2. the static setting validator (it filtered the new values out of every list);
  3. capture sizes (split W / H tables per aspect id x size class: L, M, S, previews, thumbnail) and the RAW
     AspectFrame crop tag (a jump table per id);
  4. the live view / AF ratio pair (LV crop) and the hard-coded LV output-size switches (else the view was squished);
     playback frame; rec-view size;
  5. the pixel-size readout ("0x0" until patched; then "XPAN 5184x1920" / "UW ..."), new XP / 21:9 icons (OSD);
  6. issue #23 (user flickering-star; their fork's site list was used with credit): AF point selector crash, wrong AF
     grid, iAuto, face / eye frames, AF points, metering marks, grid lines missing, setting lost at power-off: every
     other aspect-keyed lookup found nothing for the new ids. Fix: map the new ids to the 16:9 entry everywhere (AF,
     tracking, AUTO, overlays, metering). Grid lines still not fixed there (need their own pictures).
- For the OM-3: find its aspect setting, whether it has hidden spare aspect values (the E-P7's were the way in), every
  table / switch keyed by aspect (menus, validator, sizes, RAW frame, LV, playback, AF / subject detection, metering,
  overlays), then probe one ratio on the camera first. The OM-3 has more AF / computational modes than the E-P7, so
  likely more lookups. Space is not the limit (ext12 ~43 KB free, 662 KiB reserve). Credit cakelesscoder (and
  flickering-star for the AF site list idea) if their method is followed; the code would be ours.
- **Owner, 2026-11-12: not worth it for now** (custom crop modes set aside; ROADMAP "Set aside").

## Film Mode (a "roll" that locks the film): feasibility (2026-11-12; analysis only)
- Owner idea, after Fujifilm's X half "Film Camera Mode" (pick a film simulation and a roll of 36 / 54 / 72 shots;
  the film cannot be changed until the roll is done; it also hides review, which the owner does not want): a setting
  **Film Mode**, off by default: pick a roll length, and the film picked is locked until the roll is shot.
- **The lock: one place already sees every film / picture-mode change from the UI.** The facade SetValue's manager
  call is hooked (.hook_set -> sl_set -> sx_set): 901 (COLOR 1-4 / FILM 1-20, fl_set) and 897 (the picture-mode
  family: CRT 900, ART 899, COLOR 901, MONO 988; the Creative Dial and the Picture Mode list). While a roll runs, sx_set
  can replace the value with the locked one (the v0.27 dial mapping already rewrites 897 / 901 this way, camera-
  tested), so every attempt lands back on the locked film. Paths that do not use the facade (power-on sets 897
  directly, NOTES "Creative Dial"; custom-mode recall and menu reset: not traced): re-check at each half-press
  (ex_live's moment, HLS_EVENT) and set the locked film back through the manager.
- **Counting shots:** ex_hook runs once per photo (pc1: 17 photos incl. a 12-shot burst, every one coded), in the
  capture: an increment of a RAM counter there is safe (no settings calls). Open: whether it runs for RAW-only shots
  (the ORF carries EXIF too; check on the camera). The camera's own file number is an alternative (not traced).
- **Keeping the roll over power-off:** state (on, the locked selection, length, shots) in a small card file written
  at the half-press save (as EDITS.BIN). A battery pull loses the shots since the last half-press (X half: removing
  card / battery can abandon the roll).
- **Setting it / showing the count:** a Picture Mode choice row "Film Mode" (Off / roll lengths), like Noise Filter /
  Film Grain; its left cell drawn at run time with the shots left (as the WB / B/W cells, xb_wbc); the super control
  panel's FILM N cell (fl_scp) could add the count too. Nicest: the shooting screen's own shots-remaining number
  showing the roll's frames left (display path to be found; it must not change the card-full logic).
- Effort guess: small-to-medium (two or three test rounds): the lock and the counter reuse proven pieces; the screen
  counter is the unknown.
- **Owner, 2026-11-12: tabled as a future idea** (ROADMAP "Film Mode (a roll of film)").

## Control Panel after the v0.28 release: recipe codes in Share, Halation note (2026-11-12)
- Owner: "halation doesn't show up" on the live site. Live check: the row is there; the preview changes on Blue hour
  (R +2.5 mean) and Sunset (a little), **not on the default photo (frames) or Night street (paris)**: both are past the
  bright-frame cut-off (>= 24 % of cells with u >= 32), as in the exact model and so on the camera. The preview now
  says so under the row ("Not on this photo: ... try Blue hour") after each render (preview.ts `lastHalation`
  'off' / 'none' / 'done'); the firmware notes for Halation / Tone Balance update live (they only appeared on a
  re-render before), and Tone Balance says when the film has no split tone.
- Owner: the recipe code under Share. `photoCodeOf(look)` = its v0.28 LOOKS.BIN record with split toning in v0.26
  steps + byte 63 (as ex_cd1); `recipeText` = "Caduceus FILM n Name om3.1.<43>". Share (one film) and Share looks (all,
  one line each) show it with Copy. Check: the as-built CineStill 800T code equals the camera's own (photo PB122390,
  pc1); the owner's pc1 photo code pasted into Paste link gives Halation 3, Tone Balance -2, Custom WB 3200 K,
  B/W -2 / +6. vitest 50 pass (round trip test).
- **Halation on the sample night streets (2026-11-12):** the owner saw no glow on "Night street" at 5. Cause: that
  photo (and Brasserie) has 37 % lit cells, past the bright-frame cut-off (24 %), in the exact model too. A dark-frame
  rule was tried in the model and the firmware (frame mean B < 72, scaled by 16 % / the lit share; h7, not
  finished in om-emu: the direct hl_run call hung in this session's harness), then dropped: **owner: the camera's
  halation looks good on real night shots, change only the Control Panel.** The preview alone keeps the glow on dark
  photos (mean cell brightness < 72, full below 60), toned down by the lit share (16 % / lit share): Night street,
  Brasserie, Neon now glow; daylight samples stay off. The preview now differs from the camera on such photos.

## The 20 films redesigned as signature looks (v7, 2026-11-12; Control Panel preview only so far)
- Owner: "our film sims in the looklab tool just don't look like what they are simulating". In the preview the v6 films
  (graded to reference-photo statistics, 2026-11-11) sat close to the original and to each other: matching averages of
  many photos washed out each film's character (e.g. Portra 400 v6: Contrast +1, Highlights +2, no split, where the film
  is soft). Owner's choices: signature looks; 5 first (Portra 400, Kodachrome 64, CineStill 800T, Velvia 50, Gold 200),
  then all 20 ("Yes, do all 20"); a film may carry its WB mode and Halation where it is known for them.
- `webapp/scripts/films.py` SIGNATURE: a trait recipe per camera film that replaces the recipe and GRADED; new keys
  `bal` (Tone Balance), `halo` (Halation), `wbmode`; split toning in halves (v0.28); Blacks / Whites to ±7. Film / filmLook
  carry tone_balance, halation, film_wb. CineStill 800T: Custom WB 3200 K, Halation 3, teal shadows / warm highlights
  (blue in daylight, true under lamps); CineStill 400D: Halation 2. Our own designs from public descriptions (no LUTs).
  First-pass fixes after the all-20 sheets: Superia's green and Eterna / Vision3's flatness toned down, CineStill 800T's
  greens less cyan (the taxi went olive).
- Sheets (private mockups/films-v7-*): original / v6 / v7 on portrait, meadow, taxi, night street. Not camera-tested;
  not live. The released LOOKS.BIN (v0.27.1's films) is unchanged.
- **Passes against internet references (2026-11-12, owner: "do a few more passes ... compare them to pictures found on
  the internet"):** Wikimedia Commons media search per film (freely licensed photos naming the film; 28-40 per film,
  only 2 for CineStill 400D and 9 for Agfa Ultra; Fuji C200's results are mostly black-and-white scans: not used),
  measured in the browser at 256 px (no files kept): 2 / 50 / 98 % luminance, mean chroma, and the cast of near-neutral
  pixels in shadows / midtones / highlights. The same numbers on our 20 in the preview over the 9 sample photos.
  Different scenes, so each film is compared by how it stands out from the average of the 20 (references vs ours).
  Pass 2: more colour for Portra 400, Gold, Pro 400H, ColorPlus, Superia, Ektachrome, Provia; less for CineStill 800T,
  Ektar, Velvia; blacks less lifted (Portra, Pro 400H, Vision3, Eterna); ColorPlus warmer orange, Gold's midtones
  redder (gm -1 / -2), Superia and Ultramax less green / warm as their references, Velvia cooler, CineStill 800T's teal
  shadows halved. Pass 3: the remaining black / white points and casts. Result (colourfulness vs the average, refs /
  ours): Portra 400 0.96 / 0.86, Gold 1.22 / 1.06, Kodachrome 1.14 / 1.11, CineStill 800T 0.70 / 0.75, Ektar 0.97 /
  1.09, Velvia 1.14 / 1.24, Superia 1.19 / 1.13, Vision3 0.67 / 0.75, Eterna 0.72 / 0.69. The near-neutral cast is a weak
  measure for strongly tinted films (their tinted pixels drop out) and CineStill 800T's references are night scenes
  under lamps while the preview assumes daylight: those two judged by eye. Reference numbers: private folder.
- **Cuban Negative (not a film stock; 2026-11-12):** the popular Fujifilm recipe "Classic Cuban Negative" (by the
  photographer Osan, built on Classic Neg). Ours stays our own design (no recipe settings copied); compared, as the films,
  with the 14 community photos made with it in the Fuji Rumors roundup (measured in the browser, nothing kept): about
  as colourful as the film average, bright whites, cyan-green shadows, slightly warm-pink highlights. v6 had yellow
  highlights and dim whites. New SIGNATURE: olive greens, muted teal blues, orange-leaning reds, honeyed skin, firm
  contrast, Whites +1, split Cyan 1.5 / Red 1 with Tone Balance -1. Measured vs the photos (relative to the 20 films'
  average): colourfulness 0.96 / 0.96, shadow cast -9 / -9 (green), midtone -5 / -4, highlights +4 / +1 (warm).

## Camera memory probe mp1: does M's unused tail survive? (2026-11-13; code checked + emulator, camera test pending)
Question (issue #35, research and design by iancw in PR #36, not merged): can films and edits live in the camera's own
settings store M (256 KiB RAM image at 0x62920700, two alternating flash copies)? Everything rests on one assumption: a
change in M's unused tail (the camera's items end at image offset 0x39465) is saved, survives a battery pull and loads
back without the camera resetting its settings.
- **Checked in the OM-3 1.1 code (analysis):** `0x60063d73` (from `0x6041b160`, the GUI's save on the return to shooting)
  writes M through `0x60061183` only when the byte `0xa32bfb32` is 1, and clears it. For M (callback 0x60063db4 given)
  the write does not compare with flash first: it adds 1 to the image's counter (+4, `0x6006144c`), puts the negated 16-bit
  sum of the whole image at +2 (`0x60061422` / `0x6006142e`: size / 2 halfwords, the checksum word skipped), copies the
  image to a buffer and programs the next slot. The load copies the whole image (`0x600610d2` -> `0x6006148f`, size / 4
  words); a slot is valid when its first halfword is the store id and the 16-bit sum of the whole image is 0
  (`0x600613d7`). So the tail is saved, sealed and checked like the camera's own items, as PR #36 says.
- **om-emu can test persistence:** its S-NVRAM mode (`host/nvram.mjs` `fileNvram`) runs the stores' saves natively down to
  the NAND write, keeps the images in a JSON file and restores M and E at the next session's start. `session_ed1.mjs` now
  takes `NV_FILE=PATH` for it (and reports `nvram: {loaded, saves}`). Without it the emulator stubs the save (S-SETSAVE),
  which is why trace 4 in #36 saw no save.
- **Probe mp1** (branch `experiment/m-store-probe`, `firmware/src/editor.s` `mp_run` / `mp_txt`, ext12): only with the
  debug log on, from `lg_write` (HLS_EVENT task, a shutter button event, never during capture). First logged event of a
  power-on: read 16 bytes at image + 0x3A000 {magic "OMPB", counter, version 1, CRC-32 of 0..11}, write them back with
  counter + 1 to the cached address and the uncached alias 0xa295a700, set `0xa32bfb32` to 1. Every event: M's header
  counter and the changed byte. Report in `CADLOG.TXT` ("M store probe ..."). Never calls the save or writes flash.
- **Emulator (S-NVRAM, out-mp1: E1479999.BIN a54a44ae…, GUIDES.BIN 1ff984ae…):** run 1 from a blank camera: half-press
  (block written, changed byte 1), MENU, MENU (close), half-press: 3 native saves; the kept M image has the block at
  0x3A000, header counter 2, 16-bit sum 0; the changed byte back to 0. Run 2 (a new process = a battery pull, no
  power-off path): M and E loaded; the RAM image at start equals the saved image byte for byte (no reset); the probe
  found counter 1 with a right CRC, wrote 2; one save, counter 3, sum 0. CADLOG.TXT: "Probe block found: yes, CRC right:
  yes, counter 1".
- Test package for the owner (kept outside the repo), with a way back to v0.28. Realistic worst case if the camera disagrees: it resets all its own settings (not the card's films).
- Status: code checked + emulator only. The emulator models the flash, it is not the camera's NAND or its power loss.
- **Camera (owner, 2026-11-13, mp1): the tail survives.** The owner ran the steps (half-press, MENU and back, battery out
  30 s, power on, twice). CADLOG.TXT of the third power-on: "At power-on the tail held: 42504D4F 00000002 00000001
  971777D7 / Probe block found: yes, CRC right: yes, counter 2 / Written this power-on: counter 3 / M header counter at
  power-on 4672, now 4674 / Changed byte at power-on 1, now 0". So the marker written at power-on 1 and 2 was saved by the
  camera at the menu exit, kept over two battery pulls and loaded back with a right CRC; the camera's own save ran twice in
  that power-on (counter +2) and cleared the changed byte. M's header counter 4672 = the camera's long-standing store (no
  rebuild). Card files all matched; LOOKS.BIN only had its selection byte changed by the camera (COLOR 1 -> FILM 4).
  The changed byte was already 1 at the first half-press (the camera's own start-up changes, as in the emulator).
- So the assumption #35 / #36 rests on holds on the camera: bytes in M's unused tail are saved with the camera's settings
  and survive power loss. Owner (2026-11-13): the camera's own settings all looked the same after the battery pulls (no reset).
  Still open: whether a menu "Reset" or an OM firmware update clears the tail (expected; the design's fallback covers it).

## Films in camera memory, step 1 (f1) (2026-11-13; emulator only, camera test pending)
Milestone 1 of the design in PR #36 (iancw), after camera probe mp1 (branch `experiment/m-store-probe`: a marker in store
M's unused tail survived two battery pulls on the owner's OM-3, the camera's own settings unchanged).
- **Owner's choices (2026-11-13):** a card's films are taken only when the camera never had that set ("new films"); no
  copies of the films, edits or Extras are written to the card any more.
- **Block** at M image + 0x3A000 (RAM 0x6295a700 / uncached 0xa295a700), 3,912 B: 'OM3U', version 1, length, CRC-32 of
  16.., generation, a ring of 16 film-set identities (CRC-32 of a LOOKS image's bytes 32..: records and names, so the
  selection bytes don't count), then the LOOKS.BIN, EDITS.BIN and BUNDLES.BIN images in their own formats.
- **Code** (`firmware/src/editor.s`, end, ext12): `ub_chk` (once per power-on), `ub_bun` (sd_load before P is published:
  the Extras from the block), `ub_pfl` (sd_load in place of pf_load: the films from the block, or from the card when new or
  when there is no block; after fl_mk2 the edits from the block; then `ub_put` when the films came from the card),
  `ub_put` (the block from P / TORG / LPTR, as ed_save, fl_save and pf_save prepared their files: selection bytes and CRC,
  EDITS header and CRC, BUNDLES slots through sd_san and its header CRC; the ring gets the films' identity; written to
  both aliases with dispatch held (LOCK) and only when the camera's save of M is not running (busy byte 0xa32a9904, set
  by 0x60063d73 before the checksum and cleared by its callback 0x60063db4 after the flash write), then the changed byte
  0xa32bfb32 = 1; else `ub_pend` and `ub_try` again at the next gated shutter event), `ub_save` (ed_trig in place of
  ed_save + fl_save; still calls the code block +72), `ub_txt` (CADLOG.TXT: "Films in camera memory: ..."). ed_save,
  fl_save, pf_save and pf_load stay in the source, unused (step 2 can remove them).
- **The camera also saves M at power-off** (om-emu S-NVRAM + S-SHUTDOWN, `session_ed1.mjs` token `poweroff`: a probe
  write without any menu visit was in the kept image after the power-off). So a change is saved at the next return to
  shooting after a menu / Picture Mode or at power-off; a battery pull before either loses only that last change.
- **Emulator (out-f1: E1479999.BIN 9e49c360…, GUIDES.BIN 0ec0e4dc…; NV_FILE runs in sequence):** (1) blank camera, the
  owner's card files: "Films from: the card (first time)", block generation 1 (the owner's 20 names, selection 4/5/5/4,
  EDITS valid mask 0xffffff, BUNDLES 'OM3B'), M checksum valid after the power-off save; (2) a card without LOOKS / EDITS /
  BUNDLES: the owner's films and selection from the block; an edit (`pokep:32=03,685=01`: slot 0 hue 3, dirty) written
  (generation 2) and kept over the power-off; (3) the same card after a new start: hue 3 still there; (4) a card with the
  films v7 LOOKS.BIN: "the card (films the camera never had)", the v7 names, the selection and Extras kept, generation 3,
  saved at the menu exit; (5) the owner's old card again: "the camera" (already had them), films stay v7; (6) a blank card
  (no OM3MOD): films, selection and Extras from the camera.
- om-emu note: after a native power-off the kept state holds the sub-CPU's B store, and the next start fails om-emu's own
  check ("BlR." where it expects "BlD."): drop `scpu` from the NV file between runs (only M / E matter here).
- **Not yet:** GUIDES / LABELS / TONES still come from the card (step 2: into the firmware); without them films apply but
  Glow / Clarity, grain, guide and film pictures don't. The Control Panel's saved-at stamp (step 3) is not needed with the
  "never had" rule. Test package for the owner (kept outside the repo).
- **Camera, round 1 (owner, 2026-11-13, f1):** CADLOG.TXT: "a valid block at power-on: no / Films from: the card (first
  time) / Block written this power-on: 2 times, generation now 2 / the camera's changed byte: 0". The owner's change (COLOR 1
  from FILM 4 to FILM 1) was written (event #2: edits waiting, save result 1) and the camera saved M at the menu exit (changed
  byte back to 0). LOOKS.BIN, EDITS.BIN and BUNDLES.BIN on the card unchanged (no card copies). Then, with the owner's OK,
  the six film files were taken off the card for round 2 (a card without films).
- **Camera, round 2 (owner, 2026-11-13, f1): passed.** The card without LOOKS / EDITS / BUNDLES, a battery pull, power on:
  CADLOG.TXT "a valid block at power-on: yes, generation 3 / Films from: the camera / Block written this power-on: 0 times /
  changed byte 0", picture mode 54 = COLOR 1, FILM 1 (the owner's round-1 change kept). So the films, the selection and the
  edits come from the camera's own memory over power-off and a battery pull, with no film files on the card.
- To fix in step 2: the debug log's card check still calls a missing LOOKS.BIN a MISMATCH; with a valid block it is normal.

## Films in camera memory, step 2 (f2): GUIDES / LABELS / TONES built into the firmware (2026-11-13; emulator only)
- **Where:** build.py puts GUIDES.BIN (pictures + code block), LABELS.BIN and TONES.BIN, as built, in the GX4-proven reserve
  after ext12 (0x60f99800..0x60fa26e0 in f2, 36,576 B, 16-aligned) and raises the loader's end word 0x60045e9c to 0x60fa3000
  (GX4: proven to 0x6103f000, camera 2026-11-12). `bf_tab` (editor.s) gets each one's address and size.
- **How:** the camera's file functions are renamed in editor.ld (OS_FOPEN / OS_FCLOSE / OS_FSEEK / OS_FTELL / OS_FREAD);
  `fopen` / `fread` / `fseek` / `ftell` / `fclose` in editor.s are wrappers with the same frames (the stock ones: [],4;
  [d2,d3,a2,a3],24; [d2,d3,a2,a3],20; [d2,a2,a3],16; [d2,a2,a3],16). A read open of "C:\OM3MOD\GUIDES.BIN", "LABELS.BIN"
  or "TONES.BIN" gets a handle on the built-in copy (a pool of 4 {in use, address, size, position}, taken with dispatch
  held); anything else goes to the camera. The code block links its fopen / fread / fclose to the wrappers (build.py
  make_xblock), so its LABELS.BIN read is served too. No caller changed; the card's copies are never read.
- **Debug log:** with a valid block, LOOKS / EDITS / BUNDLES read "not needed (kept in the camera's memory)", or "on the card
  (the camera takes only films it never had)" / "on the card, not used"; they no longer count as a mismatch.
- **Bug found and fixed (f1 code):** ub_chk, ub_bun, ub_put (and f2's vf_new) had frames of 16 with four registers saved,
  so their own calls wrote the return address over a saved register ((0,sp), research/NOTES.md "Picture-mode sliders").
  Harmless for their callers in f1; in f2 it broke lg_chk's row pointer (an fopen of address 0x12f80400, an om-emu trap).
  Now 20. `session_ed1.mjs`: WLIVE=1 prints WATCH hits as they happen (a run that crashes writes no OUT).
- **Emulator (out-f2: E1479999.BIN 1d55d524…):** f1's suite again (first time from the card; a card without films; an edit
  kept; new films taken; an old card ignored; the cards' f1 GUIDES.BIN ignored, the code block still loads); a blank card and
  a card with only DEBUG.TXT: GPTR / XPTR / tg_ptr set from the built-in copies, the three opened at the first half-press
  (rows 0, 1, 2), the Picture Mode screen drawn in full, CADLOG "Card files: all match this firmware".
- Test package for the owner (kept outside the repo): only E1479999.BIN to copy. Camera test pending.
- **Camera, round 1 (owner, 2026-11-13, f2): passed.** (A first attempt still ran f1: the owner had not held OK at power-on;
  f1 kept working, an edit -> generation 4.) After the flash: CADLOG build "v0.29-dev (films in camera f2)", "Card files:
  all match this firmware", LOOKS / EDITS / BUNDLES "not needed (kept in the camera's memory)", "a valid block at power-on:
  yes, generation 4 / Films from: the camera": the block written under f1 survived flashing f2 (our own firmware update keeps
  M's tail). Photos PB132423..25 (FILM 1 Portra 400, photo code: Glow -5, Grain 3 High, ISO 200..800): the grain is plain in a
  1:1 crop of a flat wall and the Glow blooms around a lamp, so the code block runs from the built-in GUIDES.BIN.
- **Camera, round 2 (owner, 2026-11-13, f2): passed, with no OM3MOD folder on the card at all** (removed with the owner's
  OK; backup kept privately). Photos PB132426..29 at ISO 1000: FILM 2 Gold 200 with Glow -5 (the soft bloom around a lamp and
  a window) and FILM 3 Kodachrome 64 with Grain 3 High (flat-tile high-pass texture 10.1 against 1.2 for the Glow frames, the
  grain plain at 1:1). So the films and Extras come from the camera's memory, and the code block, labels and tone pictures
  from the firmware: **any card works.** (No debug log in this round: no DEBUG.TXT on the card.)
- **Camera, new films from a Control Panel export (owner, 2026-11-13, f2): works.** The camera's 20 films loaded into the
  Control Panel (a bank link made from the card's LOOKS.BIN taken in at f1), FILM 15 (one of the owner's own films) Midtones +6 -> +7 with the
  UI's + button, then Export › Single files › LOOKS.BIN ("v0.28 or later"); the file differs from the camera's films only in
  that byte (record 15 +45), its CRC and the selection bytes. On the card (a new OM3MOD with LOOKS.BIN and DEBUG.TXT). Camera:
  the photo PB132430 on FILM 15 has Midtones 7 in its photo code (Shadows 3, Highlights -1, Contrast -1,
  Blacks 3, as exported); the last power-on's CADLOG: "LOOKS.BIN: on the card (the camera takes only films it never had) /
  a valid block at power-on: yes, generation 8 / Films from: the camera" (the set was taken at an earlier power-on, then not
  again). So the whole path works on the camera: Control Panel -> one LOOKS.BIN -> the camera's memory.

## v0.29-beta (test version) prepared (2026-11-13)
- Owner: a pre-release first (v0.28 stays the main release), with the 20 redesigned films (v7) in the optional LOOKS.BIN
  and in the Control Panel (published with v0.29, as the live site is built from `main`).
- Firmware: f2 renamed "v0.29-beta (camera-tested, f2)" (same length; only the name, the code-block tag and the built-in
  GUIDES copy's CRC / tag differ, checked by a byte diff of main.bin). `releases/v0.29-beta`: patch.json (158 runs,
  321,613 bytes changed), LOOKS.BIN b7b6dabb… (v7 films, selection 0), DEBUG.TXT and the photo code kit as v0.28, no card
  files. `patch.py --release v0.29-beta` makes E1479999.BIN b75ae112… (= the build) and only DCOLYMP; v0.28 still makes
  d7f13db0… with its card files.
- Control Panel: rebuilt into `looklab/` on this branch (v7 films; v0.29 wording in Install and Export); webapp tests pass.

## v0.29: which films (owner, 2026-11-13)
- Two redesigns of the camera's 20 existed: the signature looks (v7, above; camera-tried on the owner's OM-3 since
  2026-11-12, shipped as v0.29-beta's optional LOOKS.BIN) and the colour-matched films (below; live in the Control Panel
  since 2026-11-13, not camera-tested). Owner: **v0.29 ships the colour-matched 20.** The v7 recipes stay in the history
  (commits fcd1e05, dcb329e, 88042b1); `webapp/scripts/films.py` is the colour-matched one.

## Colour-matched films (2026-11-13; analysis / camera model, not shot)

Every film on the colour-chart reference (18 films: 24-patch chart, daylight, +0 EV, one lab scanner, Kodak and Fuji
in two sessions) is now graded against it, and only those. The reference numbers stay outside the repo (owner's
private project notes), as for v6. Target: each film relative to its session's average, applied to the camera's
COLOR default from the v6 chart shoot. Solver: `research/film-grading/grade.py`'s camera model (colours, tone, WB,
split; Contrast kept >= 0; clipped scan patches barely count).

- In the earlier 20 (base = the measured v6 chart shoot): Portra 400, Portra 800, Gold 200, Ektar 100, ColorPlus 200,
  Ektachrome E100, Pro 400H, Velvia 50, Superia 400, Fuji C200, Provia 100F.
- Other films already in the list (base = model only): Portra 160, Fujifilm 200.
- New films (the reference has them, the list didn't): Fujifilm 400, Natura 1600, NHG II 800, NPS 160, Pro 160S
  (67 films now). Descriptions are ours, partly from what their charts show.
- New film-browser filters: "Colour matched" (these 18, also tagged in the list) and "Hand-tuned" (the other 49,
  designed from public descriptions). `matched` flag from `MATCHED` in `webapp/scripts/films.py`.

Double check (2026-11-13), two models: (1) grade.py, (2) the Control Panel's own camera-fitted preview run over the
chart (an independent model). Both say all 13 existing films get closer to their film chart. Preview, mean colour
error on unclipped patches, old -> new: Ektachrome 16.1 -> 8.3, Provia 15.1 -> 9.6, Gold 9.9 -> 4.8, Fujifilm 200
10.9 -> 6.0, Portra 400 9.2 -> 6.2, Pro 400H 8.0 -> 3.9, C200 7.5 -> 5.0, Ektar 7.1 -> 4.8, Portra 160 7.1 -> 4.4,
ColorPlus 6.7 -> 5.0, Superia 400 6.3 -> 4.4, Portra 800 5.7 -> 4.9, Velvia 13.9 -> 13.1. New films 4.3-6.4.
Velvia: the two models disagree (skin and sky blue); the camera can't turn the cyan patch as far as Velvia does.
The camera chart shoot decides. Portra 400's grey tint: preview says slightly warmer than the film (2.6 -> 3.0).

- The camera's 20 changed (owner, 2026-11-13): the 18 colour-matched films + CineStill 800T and Kodachrome 64, in
  `CAMERA` (`webapp/scripts/films.py`), the README table and the default-bank test. Dropped from the 20 (still in the
  list): Ultramax 400, CineStill 400D, Reala 100, Vision3 250D, Fuji Eterna, Astia 100F, Agfa Ultra 100.
- Test file: LOOKS_CP2.BIN (sha256 774b36bc…), the new 20 (LOOKS_CP1.BIN, 87c84364…, was the old 20 with 11 regraded).
- Next: owner shoots the chart with it (as for v6); measure, then keep, adjust or drop per film.
- Merged to main and published in the Control Panel (owner, 2026-11-13). The release `LOOKS.BIN` (v0.28) keeps the
  earlier 20 until a camera chart shoot confirms these.

## v0.29 released (2026-11-13)
- Owner: "lets push .29" after v0.29-beta; the films: the colour-matched 20 from main (not the beta's signature v7).
- `release/v0.29` = origin/main (13a2256's wheel fix, the colour-matched films, LUT import) + `feature/films-in-camera`;
  film files taken from main; README without the branch banner, Latest v0.29; Control Panel rebuilt (webapp tests pass).
- Firmware: f2 renamed "v0.29 (camera-tested f2 build)" (same length; byte diff: only the name, the tag, the built-in
  GUIDES CRC / tag). `releases/v0.29`: patch.json (158 runs, 321,613 bytes), LOOKS.BIN ee3f1bde… (colour-matched 20),
  DEBUG.TXT and the kit as v0.28. `patch.py` (no --release) makes v0.29 = E1479999.BIN cd99362c… and only DCOLYMP.
- Guides (INSTALL, USING, FAQ, CONTROL_PANEL), CHANGELOG, releases/README, DEVELOPER_NOTES, roadmaps updated.

## The Highlight & Shadow curve on the camera's screen (2026-11-13; emulator + analysis, nothing on the camera)
- Owner asked whether the camera's curve could show Blacks / Whites at its two ends, as the Control Panel's does.
- The curve is not drawn line by line: Picture Mode's panel (ctor 0x61287fb4, vtable 0x615e6258) reads Sh / Mid / Hi
  and maps each -7..7 to a code through table 0x615e61e0 (0 -> 1, +n -> n + 1, -n -> 8 + n; helper 0x611c776b), puts
  the codes in a 7-byte block (property 281) and a 508-byte element block (property 175, picture ids 12309 / 12310,
  12311 when the values differ from the defaults, 10329) and publishes both (0x610cd5c4), 0x61287c65 / 0x61287cec.
- Stored pictures (format 14, RAM picture table *(0x60379740) + 4 id; om-emu, f2): 4145 312 x 312 (the frame and
  grid), 4146 256 x 64, 4147..4161 and 4162..4176 (155 x 156, 15 each: the curve's halves), 4177..4191 and
  4192..4206 (300 x 300, 15 each; not traced, likely Midtones). Trace of the picture lookup 0x610f5611 (om-emu):
  Sh +1 -> 4148, Sh +2 -> 4149, Hi -1 -> 4155, so a half = 4146 + code. The ends are part of these pictures: they
  can't follow Blacks / Whites with the camera's own pictures.
- Route (not started): answer the curve's ids in ic_get with our own picture of the whole curve, composed at run
  time as dg_build does (format 14), from Blacks / Sh / Mid / Hi / Whites through the camera's tone remap
  (tools/ep7_tone.py remap(), bit-exact). Open: which ids show for Mid (the 300 x 300 sets?), whether the panel asks
  again when only Blacks / Whites changed (they are set on their own row), the left cell's small curve (14534 /
  14539, 82 x 62).
- om-emu tokens for the row: `s1 ok ok down down down down` (COLOR 1, H&S row), then `main+N` Sh, `sub+N` Hi.
## Films with no card in the camera (#38) (2026-11-13; camera-tested)
- Report (#38, v0.29): with no card in the camera the Picture Mode list shows no films; the films load only at the first
  half-press. The owner's camera loaded them with a reformatted card (2026-11-13).
- Cause (analysis): `pr_gate` still ends with the medium check from probe 2 (one of 0x603692f8 / 0x60369300 /
  0x60369308 == 0xF000, MOUNT OK; 0x60369308 is the kind-4 medium, the card slot, docs/SD_LOADER.md). With no card
  mounted it returns without claiming STATE, at every shutter event, so `sd_load` never runs: no P, no films, though
  they are in M's block. Which word, if any, reads 0xF000 with the slot empty is not known on the camera.
- om-emu can't take the card out on E147 (`card_input`: no HLS media side for this model), and its medium words are
  always 0 (the harness writes 0x60369308 = 0xF000 itself). With that write left out (a blank card, "no card mounted"):
  v0.29 (f2 main.bin) STATE 0 after two half-presses, nothing loaded.
- **Build n1** (branch `fix/films-no-card`, VERSION "v0.29.1-dev (no-card test, n1)", same length as v0.29's): pr_gate's
  last medium test `bne pr_gout` -> `beq pr_go; jmp pr_nmd` (ext1 1738 -> 1742 of 1744); `pr_nmd` (end of ext12):
  `ub_chk` -> a valid block: `jmp pr_go` (sd_load as usual: BUNDLES / LOOKS / NAMES opens fail without a card, the
  Extras and films come from the block, GUIDES / LABELS / TONES from the built-in copies); no block: `jmp pr_gout` (wait
  for a card, as before). Side effect: a card that is in but not yet mounted at that shutter event has its new LOOKS.BIN
  taken at the next power-on. E1479999.BIN dc13b574…; vs v0.29 main.bin 107 runs / 1509 bytes (ext1 after pr_gate moved
  5 bytes and the calls into it, the name, pr_nmd). Unchanged source still rebuilds v0.29 cd99362c… byte for byte.
- **Emulator (n1):** no card mounted + a block: films load at the first half-press (lidx 4,5,5,4, CADLOG "Films from: the
  camera"), menu opens; card mounted: as v0.29; no block and no card mounted: nothing loads, STATE 0 (as before).
- Not done: the films loading at switch-on without a half-press (the other half of #38). The v0.26.2 automatic load
  (SDLOAD worker + sdl_poke) was dropped in v0.27.1 as the suspected cause of rare power-on hangs ("Sporadic power-on
  hang on v0.27"); a switch-on load needs another route.
- Test package for the owner (kept outside the repo): only E1479999.BIN to copy.
- **Camera (owner, 2026-11-13, n1): passed.** Flashed n1 from a freshly formatted card (DCOLYMP only); with the card
  taken out, switched on and half-pressed: the films show in the Picture Mode list. (No debug log in this test.)
- **Released as v0.29.1** (owner, 2026-11-13): n1 renamed "v0.29.1 (tested on camera, n1)" (same length; byte diff: only the
  name, the code-block tag, the built-in GUIDES CRC / tag). `releases/v0.29.1`: patch.json (158 runs, 321,631 bytes),
  extras as v0.29. `patch.py` (no --release) makes v0.29.1 = E1479999.BIN 8bb07ccc…; `--release v0.29` still cd99362c….

## Films at switch-on: tried and dropped (#38, second half) (2026-11-13; owner's decision)
- Owner asked to try the films loading at switch-on again (no half-press), now that v0.29 keeps them in the camera's
  memory. Branch `feature/films-at-switch-on` (kept for the record; its NOTES section "Films at switch-on" has the
  details): the films load from M in the GUI task at its first events (gx_map), with no card access.
- **Camera (owner, b1): no freeze, but lag at switch-on "sometimes".** Its log: the films loaded at the GUI's first
  event, before the shooting screen. om-emu then showed the likely cause: with the films in that early, the camera's own
  start-up SetValue(897) (Creative Dial family) ran our dial mapping (dm_turn), v0.27's power-on mapping that had lagged
  and hung before. b2 held the mapping until the first half-press (emulator only, never on the camera).
- **Dropped (owner, 2026-11-13):** the lag already showed, and the owner wants the camera's start-up left alone: rule in
  CLAUDE.md. The films keep loading at the first half-press (v0.29.1).

## spektrafilm as a film reference for LookLab: licence, what it is, options (2026-11-14; analysis only, nothing run or built)
Owner asked to bring spektrafilm (github.com/andreavolpato/spektrafilm, by Andrea Volpato) into LookLab to make it more
accurate. Read its `LICENSE`, `SPEKTRAFILM_LICENSE.txt`, `README.md`, `CITATION.cff`, `pyproject.toml` and the runtime
source (v0.3.4, main as pushed 2026-07-14). Nothing of it is in this repo; nothing was installed or run.

**Licence, as written in their repo:**
- **Code: GPLv3** (`GPL-3.0-or-later` in CITATION.cff). README and CITATION: derivative work must be open source under
  the same licence, and "Derivative work includes any software, plugin, or tool that incorporates spektrafilm code or
  is directly inspired by its methods" (the author's stated wish; they offer to talk if GPLv3 does not fit a project).
- **Film / paper profiles (`src/spektrafilm/data/profiles`) and LUTs: CC BY-SA 4.0** with a preamble (v1.1,
  2026-05-28). Free use, commercial too; graded pictures are the user's own. Every copy or derivative "in any format"
  (LUTs and "any other format that encodes the same content" as a profile) must keep Andrea Volpato as author, the link
  to the repo, the CC BY-SA 4.0 notice and a note of what was changed and by whom; modified profiles / LUTs stay CC BY-SA
  4.0. Their suggested wording for modified files: "Derived from spektrafilm by Andrea Volpato /
  https://github.com/andreavolpato/spektrafilm / Licensed CC BY-SA 4.0 / Modified by [name]."
- **Name:** "Don't use 'spektrafilm' or my name in product branding without asking"; factual reference is welcome
  ("graded with spektrafilm", "this app uses spektrafilm LUTs"). CC BY-SA licenses no trademark rights (2(b)(2)) and
  allows no implied endorsement (2(a)(6)). The icon / banner is not mentioned anywhere; we treat it like the name and
  never use it.
- **Asked, not required:** credit in project docs and about pages; no paid LUT packs; no commercial AI training on the
  LUTs or their output.
- **Against what the owner understood** ("free to use with proper credit, not its name or icon"): the name part matches.
  Two catches: (1) the code is copyleft GPLv3 and this repo is Apache-2.0: any of its code we ship, and in the author's
  words any tool inspired by its methods, must be GPLv3 (in the browser that would be LookLab as a whole). Apache-2.0
  code may go into a GPLv3 work, not the reverse. (2) The data is share-alike: what we make from the profiles (LUTs,
  tables, very likely recipes fitted to its renders) must itself be CC BY-SA 4.0 with the credit, not only credited.

**What it is:**
- A physically based film / print / scan simulation: scene-linear RGB → spectral upsampling (81 bands, 380–780 nm;
  hanatos 2025 or Mallett 2019 method) → the film layers' spectral sensitivities → density curves with DIR couplers
  (layers holding each other back; diffused, they add local contrast), masking couplers in the dye spectra, grain,
  halation and scattering → spectral dye density → enlarger light through dichroic filters (balanced so 18 % grey
  prints neutral) → print paper sensitivity and curves → a scan of the print (or of the slide itself) → linear RGB.
- Data from Kodak / Fujifilm datasheets (spectral sensitivity, density curves, dye absorption) plus public reflectance
  sets (Munsell, Otsu, skin, foliage). 20 films: Kodak Portra 160 / 400 / 800 (+ push 1 / 2), Gold 200, Ultramax 400,
  Ektar 100, Ektachrome 100, Kodachrome 64, Verita 200D, Vision3 50D / 200T / 250D / 500T; Fujifilm C200, Pro 400H,
  Superia X-TRA 400, Provia 100F, Velvia 100. 8 papers / print films: Kodak Portra / Supra / Ultra Endura, Endura
  Premier, Ektacolor Edge, 2383, 2393; Fujifilm Crystal Archive Type II. No black-and-white.
- Python ~3.13 only; numpy, scipy, colour-science, opt-einsum, numba, scikit-image, matplotlib, pyfftw, OpenImageIO,
  rawpy, exiv2, lensfunpy, and by default a Qt / napari desktop GUI (PySide6) and a LUT maker. About 35 MB of files: 28
  profiles of ~205 KB, 10 MB of spectral-upsampling tables, ICC profiles.
- Speed (author): about 10 s per 6 MP picture on a laptop; a colour chart or a few hundred test colours take seconds.
  Faster ports by others: vkdt's filmsim module (GPU, vkdt is BSD-2), spektrafilm-rs (Rust, GPLv3), an OFX plugin, a
  LUT bridge in ART.
- In rapid development: the runtime is "a moving target by design"; results change between versions (any use pins one).

**How it relates to LookLab:**
- LookLab's preview shows what the **camera** does with a recipe (12 colour sectors, tone curve, WB shift, split toning;
  `OM3_CAL` fitted to camera shots, about ΔE 4). The camera has no film model, so spektrafilm cannot bring the preview
  closer to the camera. What it can give is a better **target**: what each film should look like.
- Targets today: 18 films matched to real film scans of a colour chart (private reference, one lab scanner, 24 patches,
  daylight, +0 EV); 49 hand-tuned from descriptions, two of them in the camera's 20 (Kodachrome 64, CineStill 800T).
- spektrafilm has 10 of the 18 matched films (Portra 160 / 400 / 800, Gold 200, Ektar 100, Ektachrome E100, C200,
  Pro 400H, Provia 100F, Superia 400 ≈ X-TRA 400): a second, independent check. And 8 hand-tuned ones: Kodachrome 64,
  CineStill 800T (widely reported to be Vision3 500T without its anti-halation backing; whether spektrafilm can drop
  the anti-halation layer is to check), Ultramax 400, Vision3 250D, CineStill 50D (≈ Vision3 50D), Velvia 100, Kodak
  2383 / 2393 (as the print after a Vision3 negative).
- What it can show and the scans cannot: colours beyond the 24 patches (skin, foliage, sky), exposure ramps (toe and
  shoulder, −3..+3 EV), tungsten light (800T, 200T).
- Its limits as a target: a model, not a measured result; a negative's look depends on the print / scan (its neutral
  enlarger balance is not a lab scanner's look); the author finds the Fujifilm data "less self-consistent" than Kodak's.
  When it and the scans disagree, the camera chart shoot decides, as before.

**Options** (effort is a guess):

| Option | What | Takes | Improves | Risks |
|---|---|---|---|---|
| A. Check against it | Run spektrafilm outside the repo on the chart, exposure ramps and LookLab's LUT-import test colours (greys, skin, sky, foliage, a hue ring), for every film it has. Score our recipes (grade.py's camera model and the preview) against it next to the scan reference; list where they disagree. Changes stay ours, by hand or from the scans. | A Python 3.13 set-up outside the repo (about 1 GB of packages); a small script (GPLv3 if it is ever published, since it imports spektrafilm); 1–2 sessions. | Finds wrong hand-tuned films (Kodachrome 64 and CineStill 800T first) and tone (toe / shoulder) for the 18 overlap films. | Small: nothing of it ships. Credit in NOTICE and the docs once a change it informed ships. |
| B. Fit to it | As A, and grade.py's solver fits the hand-tuned films it covers to spektrafilm's renders, as it fits the scans now. | 2–3 sessions, then a camera chart shoot. | A measured-data target for 8 films that have none. | The recipes are made from its output: doubt with our rule "Film sims are our own designs: no copied looks, LUTs or presets" (owner's call); under its licence they are likely derivatives, so CC BY-SA 4.0 recipes with the credit, kept in their own data file apart from the Apache code. Best asked of the author first. The camera's reach limits the gain (Velvia). |
| C. Reference view in LookLab | A "film reference" picture next to the preview: spektrafilm renders of the sample photos per film (10–20 MB, loaded on demand), or small baked 3D LUTs (17³, tens of KB each) run on the user's photo. | 2–4 sessions; new images to the owner first. | Users see the film itself next to what the camera can reach. | Ships its output inside LookLab (CC BY-SA files, credit on the page; LUTs copied into the app, against our rule's spirit); JPEG input is only an approximation for a scene-linear model; can confuse ("the camera doesn't look like that"); must follow its updates. |
| D. Port its model into the preview | A spectral film pipeline in TypeScript / WebGL. | Weeks; about 10 MB of tables and profiles; a GPU path for a live preview. | Nothing for camera accuracy: the preview would stop showing what the camera does. | LookLab would have to become GPLv3 (repo Apache-2.0; the author counts re-implementations of its methods); heavy; moving target. Not recommended. |

Small extra, no licence questions: LookLab's **From LUT / preset** already makes a camera film from a user's own
`.cube` (sRGB in; Log LUTs are flagged), so a user's own spektrafilm LUT works there today. Its releases ship no
ready-made LUTs (they are made with its Python tool, ART or the OFX plugin). A factual line in the docs is allowed.

**Recommendation (analysis):** A first: it is cheap, ships nothing of spektrafilm, keeps our films our own designs, and
answers whether spektrafilm and our scan reference agree well enough to be worth more. B or C only after the owner
decides the licence and own-design questions (and, for B, ideally after asking the author how a recipe tuned on
spektrafilm renders should be licensed). D: no. **On hold (owner, 2026-11-14): nothing started.**

**Credit, when something it informed ships** (NOTICE and docs; never the spektrafilm name or icon on our films,
LookLab or the camera): "Film references checked against spektrafilm by Andrea Volpato
(https://github.com/andreavolpato/spektrafilm; code GPLv3, film profiles CC BY-SA 4.0). spektrafilm's code and
profiles are not included. Not affiliated with or endorsed by spektrafilm; its name is used only to credit it."

## Custom modes and films (#41) (2026-11-14; emulator + analysis, camera test pending)
- Report (#41, v0.29.1, with CADLOG): a custom mode (C2) does not keep the film (turning to C2 keeps the film last
  picked, the picture mode never goes back to C2's COLOR), and switching between custom modes gave films a "*" with
  Saturation / Contrast / Shadows / Highlights replaced by a COLOR's own settings or the custom mode's (EDITS.BIN read by
  the reporter; Hue / Light untouched). CADLOG: "edits waiting yes" right after mode switches.
- om-emu can turn the mode dial (`switch_input('mode_dial', k)`; E147 positions 0 S, 1 A, 2 P, 3 C5, 4 C4, 5 C3, 6 C2,
  7 C1, 8 B, 9 M) but cannot register a custom mode: the menu greys "Custom Mode" out for the stills / movie / S&Q
  switch, which om-emu does not model on E147. A turn to C2 still recalls C2's bank (registered on the camera this NV
  file came from), which is enough.
- **What a mode turn does (om-emu, v0.29.1):** the manager sees only 897 (Creative Dial family, = COLOR), 679, 680, 682,
  **162 (the shooting mode: P 76, A 77, C2 224)**, 2188, 1440, 2137. COLOR 1..4's 18 film settings (pf_ids: saturation
  928.., Contrast 908.., Sharpness 904.., Shading 912.., Shadows / Mid / Highlights 978 / 977 / 976 + 3k) are swapped in
  one block past the manager: P -> C2 gave COLOR 3 saturation 4,4,4,4,4,3,4,4,4,4,4,4 and tone 0/0/0 (C2's), back to P
  restored P's. 901 is not taken from the bank: the 897 write runs dm_turn -> fl_set(901, the current film), so the
  Creative Dial's current choice wins (and fl_set marks DIRTY: the "edits waiting yes").
- So P+LIDX still says "COLOR 3 = FILM 13" while the camera's COLOR 3 holds C2's settings: the camera shoots the film
  mixed with them, and the next fl_sw (a film pick) pf_capto's them into the film being left. That is the "*".
- Every manager call (both tasks, 165 and 168) has a0 = the same handle (0x6242c3d0 in om-emu) and a1 = 0.
- **Build k1** (branch `fix/custom-modes-films`, VERSION "v0.30-dev (custom modes keep films, k1)"): `sx_set` keeps the
  manager's a0 (`rc_in`) and, on id 162 with the films in (dm_ok), sets `rc_pend`; `gx_map` (GUI task, after a screen
  handler) runs `rc_go` when it is set: for each COLOR k on a film (LIDX 1..5), `rc_put` takes fl_sw's record (the saved
  EDITS record when valid and made from this build of the film, else the film as built) and writes each of the 18
  settings through the manager (rc_in, mode 0) only when sget's value differs. Our slot is not touched; nothing is
  captured or marked to save; COLOR k on its own settings is left as the mode has it. CADLOG: "Films put back after a
  shooting-mode change: N (camera settings written: M)". Bug on the way: rc_put's first frame (32) put its locals on
  the four saved registers (with [d2,d3,a2,a3] they sit at the frame's top 16 bytes): 40, as pf_put.
- **Emulator (k1):** P -> C2 -> P with films on COLOR 1..4: each COLOR keeps its film's settings in C2 and back in P;
  "put back 8 (written 52)". P -> A -> P -> A: "12 (14)", all 14 on the first turn (this NV file's COLOR 4 held other
  values than its film), none after. Menu and half-press fine. E1479999.BIN faf5bae2….
- Not done: part 2 (a film per custom mode); COLOR k on its own settings in a custom mode still gets fl_sw's capture
  into its own record when a film is picked there (the custom mode's own COLOR values would then follow it back to P).
- **Camera (owner, 2026-11-14, k1): the "*" no longer carries over** (camera-tested, part 1). But a custom mode does not
  keep its film: in C2 the Color Profile showed FILM 1. Owner's choice for part 2: **a custom mode brings back the film
  it was saved with by Assign** (its changes forgotten on leaving, as the camera's "Save Settings: Reset").

### Custom modes keep their own films, k2 (2026-11-14; emulator only, camera test pending)
- **k1's camera log (owner's card, copy kept privately):** "Films put back after a shooting-mode change: 0 (camera
  settings written: 0)": on the camera k1's trigger (162) never fired either, as om-emu then showed for photo custom
  modes, so the owner's "no *" with k1 was not k1's doing. k2's trigger (1440) is checked by the same log line.
- **om-emu can do photo custom modes after all:** the OM-3's photo / movie / S&Q switch is om-emu's position switch
  0x1909 (group 4, bits 0..2), which om-emu starts at its idle position 1 = **movie** (so every C mode was a movie mode,
  OM-Cinema, and Custom Mode was greyed out "for the following reason: photo / movie / S&Q"). Position 0 = S&Q,
  **2 = photo**. Scratch token `pset:1909:2` (uiin_layout entries, set_bit, push_group) -> the camera icon, and Shooting
  menu 1 > Custom Mode lists C1..C5 ("--" = never assigned) with Recall, Assign (Set / Reset), **Save Settings
  (Reset / Keep)**, Custom Mode Name.
- **Assign:** Set calls the facade's entry 18 (vtable word 0x60e574bc, stock 0x60b8764c) from the menu (0x611a93be:
  d0 = item - 9) with **d0 = the custom mode 0..4 (C1..C5), d1 = 0**; nothing goes through the settings manager. It
  flips a per-mode byte in M (M+0x31fd8 + 1 + n: 2 never assigned -> 1 set; analysis) and changes ~45 B of M at
  M+0xab58.. (the bank holds mostly the same values, so the diff is small).
- **Which mode:** the settings object behind the manager's handle (a0 of every manager call, 0x6242c3d0 in om-emu)
  holds the mode's code at +24 (byte): **P 1, A 2, C2 54, C3 55** (C1..C5 = 53..57; om-emu memory search). The dial's
  position index is at 0xa32d9d0c (P 2, A 1, C3 5, C2 6), om-emu's MODE_DIAL_INDEX (0xa32daba8) reads 0 on E147.
- **k1's trigger missed photo C modes:** a C mode assigned in P keeps 162 at P's 76, so no 162 write. A photo mode
  change writes (om-emu): 1909 (GUI task), 897, 679, 680, 682, 2188, **1440**, 2136 (movie: ..., 162, 2188, 1440,
  2137). **1440** closes every change and is not written at a half-press (897 / 2136 are): k2 triggers on it.
- **The Creative Dial's own memory** (dm_rec: the dial position's last COLOR choice in settings 1958 / 1277 / 1275 /
  1284, not saved per custom mode: same values in P, C2, C3) is put back by dm_turn at every 897 write, i.e. every
  half-press: after a custom-mode switch the next half-press brought the last menu pick back (om-emu, first k2). So a
  k2 switch also records the new choice with dm_rec (as a menu pick does).
- **Build k2** (branch `fix/custom-modes-films`, VERSION "v0.30-dev (custom modes keep films, k2)"): `cm_asg` (facade
  word 0x60e574bc, build.py WORDS) notes P+LIDX (one look per COLOR) for C(d0+1) when d1 = 0, then `jmp cm_stock`
  (0x60b8764c, editor.ld; a bare `jmp 0x60b8764c` assembled as a displacement and jumped to 0xc1b17caa: trap in om-emu).
  `sx_set` sets rc_pend on 1440 (with the films in); `gx_map` also runs rc_go once at the first GUI event after the
  films are in (STATE != 0: never at start-up) and for a held-back record write. `cm_go` (from rc_go, before the
  re-apply): group = C(code - 53) or P / A / S / M / B; on a group change P's looks are kept when leaving P, and the new
  group's come back (C: its Assign looks if assigned, else as it is; P: its kept looks); each changed COLOR switches
  with fl_sw's no-capture flag (TW_LEN + 1), DIRTY for the selection, then dm_rec with the picture mode's value
  (sget 111 -> fl_k; film FV0 + 5k + look - 1, own: the value itself). Record 'OM3C' at M+0x3B000 (48 B: flags, last
  group, P's looks, C1..C5's looks, CRC), written as ub_put (LOCK, UB_BUSY: held back, both aliases, UB_DIRTY).
  CADLOG: "Custom modes: ...". "Save Settings: Keep" is not followed yet (treated as Reset). E1479999.BIN d7a1a979….
- **Emulator (k2, photo mode):** P: FILM 1 (Portra 400), Assign C2, FILM 6 (Ektar 100) -> C2: Portra 400 (looks
  1,5,5,4 back) -> FILM 3 in C2 (Kodachrome 64) -> P: Ektar 100 (5,1,5,4) -> C2: Portra 400 again; half-presses after
  each switch keep the films; no new "*" in the film list (only the NV file's own FILM 4* / 5*). CADLOG: Assigns 1,
  films switched 8, put back 24.
- **Camera (owner, 2026-11-14, k2): "film still changes by itself"** (CADLOG, copy kept privately): the 1440 trigger
  fires on the camera (put back 52, written 77; C1 and C2 assigned), but back in A the picture mode was COLOR 1 with
  FILM 2 where it had been COLOR 2, FILM 6: k2 kept each COLOR's look per group, not which COLOR the picture mode was on.

### k3: the picture mode too (2026-11-14; emulator only, camera test pending)
- om-emu, k2, photo mode: P FILM 6 -> Assign C1, P FILM 1 -> Assign C2, P FILM 7 (COLOR 2), then C2 FILM 1, C1 FILM 6,
  **A: COLOR 1, FILM 5** (wrong). Leaving P, k3's first try noted P's choice with sget(111) inside cm_go, which runs
  after the camera's swap: that is already the new mode's picture mode.
- **k3:** each group keeps a choice too (the 901 value: FV0 + j for a film, else COLOR k's own 54 / 55 / 56 / 64;
  record 'OM3C' version 2: +14 P's, +40 C1..C5's; v1 records are not read). Assign notes it with cm_val (no swap then).
  P's choice is noted as it is set: sx_set's 901 path, while the last group is P / A / S / M (cm_ppm; first look:
  cm_val), so leaving P uses it. Entering a group: its looks (as k2), then its choice's picture mode through the
  manager when the camera's differs (fl_set's end without its film-WB steps, so the custom mode's WB is not captured
  into a film), then dm_rec with the choice. CADLOG adds "picture modes set: N".
- **Emulator (k3, photo mode):** the same sequence then C2 / C1 / A / C2 / P / C1 / P: FILM 1, 6, **7**, 1, 7, 6, 7,
  each steady over half-presses. Power-off in C2, the next start in P (NV file kept, om-emu's S-SHUTDOWN): the record
  read back ("a valid record: yes"), P's FILM 7 at the first half-press, then C2 FILM 1, P FILM 7.
  E1479999.BIN 195b087e….
- **Camera (owner, 2026-11-14, k3):** (1) "when you switch to a C mode it still has the other film loaded, but then you
  half press and it switches"; (2) after a power-off in a custom mode and a switch to P while off, P's film was wrong.
  CADLOG (copy kept privately): after the power-on in P, FILM 6 (C1's) for 8 half-presses; at the end in P, FILM 1
  (C2's); assigned C1 + C2, switched 3, picture modes set 0. Reading (analysis): (1) rc_pend waits for a GUI event,
  and the camera's GUI got none until the half-press (om-emu's GUI gets events all the time); with the picture mode
  unchanged nothing redrew either. (2) P's memory was only written when leaving P; the first look after the power-on
  compared against a "last group" that may not have been saved, then leaving P kept a custom mode's looks as P's.

### k4: switch at the dial turn; P's memory kept at every half-press (2026-11-14; emulator only, camera test pending)
- `sx_set` 1440 calls rc_go itself (task 165, inside the camera's own mode-change step, as dm_turn switches films at
  897; d2 / d3 keep the value and mode, MDR back from (68,sp) before sl_set0). rc_go is one at a time (rc_busy under
  LOCK; a busy call leaves rc_pend for gx_map).
- `cm_go`: the first look after the films are in enters the group now whatever came before (no "last group" test);
  a change leaves P's looks + noted choice; entering puts the group's looks and choice back and writes the picture
  mode through the manager when it differs **or a film switched** (the write is what makes the camera redraw).
- `cm_hp` (from lg_pr, every shutter event with the films in, HLS_EVENT): while the mode's code and the last look say
  P / A / S / M / B, their looks and choice go into the record when they changed (not before the first look, not while
  rc_go runs).
- CADLOG: "Custom modes, last switches": the last 8 cm_go runs {switched | 0x80 picture mode written, group | 0x80
  first look, code, shutter events}.
- **Emulator (k4, photo mode):** cm_go runs in task 165 during each dial turn (the first look in the GUI task after the
  load); the looks are right before any half-press. P FILM 6 -> C1, FILM 1 -> C2, P FILM 7: C2 1, C1 6, A 7, C2 1, P 7.
  Power-off in C1 -> on in P: FILM 7; a new pick in P (FILM 6) + half-press, power-off in C2 -> on in P: FILM 6. After
  a long switching run, no new "*" in the film list. E1479999.BIN b940705a….
- **Camera (owner, 2026-11-14, k4): "still isn't working right through power off and on"** (CADLOG, copy kept
  privately): the first look after the power-on ran with **mode code 0** (the settings object's byte +24 not set yet on
  the camera; om-emu had 1 there), so it took P's films onto whatever mode the dial was on; the dial turns after it
  were right (A, S, a code 62 position (B or M), C1 FILM 6, C2 FILM 1), each at the turn (same shutter count).

### k5: the dial's position when the code is 0; the Creative Dial memory only on its own turns (2026-11-14; emulator only)
- `cm_gnow`: the group from the mode's code when it is 1..5 / 53..57, else from the mode dial's position (UI_IN index
  0xa32d9d0c: 3..7 = C5..C1, others P / A / S / M / B). CADLOG's code shows 0xc0 | position when the position decided.
  om-emu with the code forced to 0 at a power-on in C2 (`pokeb:6242c3e8=0`): k4 P's FILM 6, k5 C2's FILM 1.
- om-emu then found a second power-off case: off in C1, on in P (FILM 7), C2 (FILM 1), **back in P: FILM 6** (C1's).
  sx_set's 897 path put the Creative Dial position's remembered choice (dm_psid; dm_turn) back at every 897 write, which
  is every half-press and mode-dial change too; after the power-on dm_rec had not recorded P's choice (dm_pos unknown
  until the dial code's first 897), so at the P -> C2 change the 897 write put C1's FILM 6 on P a moment before cm_go
  kept P's looks.
- **k5:** the remembered choice comes back only when the Creative Dial's position really changed (dm_pos before !=
  now); at the first 897 after a power-on (dm_pos unknown) as before, unless the custom-mode record keeps films (then
  theirs decide). cm_go sets dm_pos from 897's family when it is unknown, so dm_rec records from the first look on.
- **Emulator (k5, photo mode):** the full run (C2 1, P 7, C2 1, C1 6, A 7, C2 1, P 7, C1 6), off in C1; on in P: P 7,
  C2 1, **P 7**, C1 6, P 7; on at C2 with the code forced to 0: C2 1, P 7, C2 1. No new "*". E1479999.BIN e27be900….
- **Camera (owner, 2026-11-14, k5): "it is looking good and seems to work"** (camera-tested): each custom mode brings
  back the films and picture mode it was assigned with, P / A / S / M theirs, at the dial turn and through power off /
  on. Known gaps: "Save Settings: Keep" is treated as Reset; the Custom Mode menu's Recall item is not followed.

### k6: Recall and "Save Settings: Hold" (2026-11-14; emulator only, camera test pending)
- Owner: look at Recall first, then follow Hold (the menu's word; I had called it "Keep").
- **Recall** (Shooting menu 1 > Custom Mode > Cn > Recall > "Apply C2 settings? Current camera settings will be
  overwritten." Yes): the menu calls the facade's entry 20 (vtable word 0x60e574c4, stock 0x60b871f3, store op
  0x60bb4b53) with d0 = the custom mode 0..4, d1 = 0 (om-emu trace of every facade entry during the OK). In om-emu the
  camera's settings did not change after it (not after leaving the menu either), so what it copies on the camera is not
  known; nothing went through the manager.
- **Save Settings** per custom mode = settings **1880..1884 (C1..C5): 0 Reset, 1 Hold** (om-emu: the OK writes it
  through the manager, GUI task). The menu's choice is a side-by-side Hold | Reset with "While shooting in custom mode,
  changed settings are not saved" under Reset.
- **Build k6:** the custom-mode code reorganised around cm_src (a group's kept looks and choice), cm_save (a group <-
  P+LIDX and the noted choice cm_gpm, now noted for every group in sx_set's 901 path), cm_hold (P / A / S / M / B
  always, Cn when 1880 + n is 1) and cm_load (k3..k5's switch). cm_go saves the group being left when it holds, then
  loads the new one; cm_hp saves the group now at every shutter event when it holds (so a Hold mode keeps its films over
  a power-off). `cm_rcl` (word 0x60e574c4, `cm_rstock` in editor.ld) calls the camera's Recall, then (films in) sets
  cm_force = n + 1 and runs rc_go: that custom mode's looks and choice into the group now, kept there when it holds;
  rc_pend re-checks the films at the next GUI event in case the camera applies its part later.
- **Emulator (k6, photo mode):** k5's runs unchanged (Reset modes and the power-off cases). Hold: C2 assigned with FILM 1
  and set to Hold, FILM 3 picked in C2 -> P FILM 7 -> C2 **FILM 3** -> P FILM 7; off in C2, on in C2: FILM 3, P 7, C2 3.
  Recall: P FILM 7, Recall C2 (FILM 1): P FILM 1, C2 FILM 1, P FILM 1. No new "*". E1479999.BIN 42a2627a….
- **Camera (owner, 2026-11-14, k6): "everything with custom modes work as intended"** (camera-tested: films and picture
  mode per custom mode at the dial turn and through power off / on, Save Settings: Hold, Recall). CADLOG (copy kept
  privately): the first look after the power-on again read code 0 and took the dial's position (0xc1 = A), then S, M, C1
  (3 films switched + the picture mode written), all right.
- **Released as v0.29.2** (owner, 2026-11-14: "I don't think this fix warrants a .30 release"): k6 renamed "v0.29.2
  (camera-tested k6 custom modes)" (same length; byte diff: only the name, the code-block tag, the built-in GUIDES CRC).
  `releases/v0.29.2`: patch.json (159 runs, 324,781 bytes), extras as v0.29.1. `patch.py` makes 00c64cbd….

## Delete button remap (#37), step 1: the press path
- 2026-11-13. Static analysis and emulator, no camera test.
- Issue #37: in shooting mode the Delete (trash) button does nothing. Let it take the Fn button's functions.
- **The key (static):** Delete is keycode 14. The debug string list at `0x60e2f763..` names `API_DEL_KEY 14` after
  `API_INFO_KEY 12` and `API_EVFSW_KEY 13`. In the event -> keycode table `0x612f3100` keycode 14 has press
  0x01000026, release ..27, long press ..28 and repeat ..29 (group mask 0x800). The event name table at `0x61345410`
  pairs `OLY_PRESS_DEL_KEY` with 0x01000026.
- **The drop point (emulator only):** om-emu has a wired `delete` control. In P live view, a press posts 0x01000026
  and 0x01000027 to the dispatcher `0x61083022` (caller `0x61084dbf`). The key-table walker `0x610830c9` converts the
  event to its keycode (`call 0x61084631`), finds no record for 14 in the key table `0x612f1ee8` (28 records) and
  returns 3200, so the dispatcher returns 0. The function-table walk `0x610831e6` never runs.
- **Only three readers of the key table (static):** `0x610830c9`, `0x61083148` and `0x610831c2` each load
  `0x612f1ee8` as an imm32 (at `0x610830d4`, `0x6108314f`, `0x610831c6`) and stop at `cmp 28,d2`. No other code holds
  the address. The 128 B after the table are another 8-record table, so the table cannot grow in place.
- **A free button setting (static + emulator):** sid 570 (stills) and 1276 (movie) are Button Function settings of a
  body with a button the OM-3 lacks. Both have validators (570: 38 codes at `0x606157fc`, 1276: 24 codes at
  `0x60615d86`) and stored values (om-emu `get:` 3333 for both, a code the function table does not hold). Neither is in
  the key table, either row list (modes 365 / 366) or the item-info trees. In om-emu nothing read either one through
  the getter `0x61085dbb` during boot, live view, the arrows, menu, playback and Delete in playback. The `mov 570,d0`
  run at `0x6088d857..` is trace logging (`0x6083a8ed(570, n)`), not a setting read. 570 is also in the u16 list at
  `0x61540a14` next to the other button sids (still unresolved).
- **Route:** copy the key table into our space with a 29th record `{14, 570, 1276, 1}` (`full` = 1, as Fn) and point
  the three readers at the copy (imm32 and `cmp 29`). No new code. Then point the validators of 570 / 1276 at the Fn
  lists (47: 50 codes at `0x60615432`, 1272: 32 codes at `0x60615b0e`) and add a Delete row to Button Function. The
  default 3333 has no function, so Delete does nothing until a function is chosen, as stock.
- **Build environment (macOS, 2026-11-13):** `research/setup.sh` needs `mcopy` (Homebrew `mtools`) and `nproc`
  (missing on macOS). binutils 2.42's bundled zlib does not compile against the current macOS SDK (`fdopen` macro).
  `--with-system-zlib` fixes it. `firmware/mkicons.py` reads DejaVu Sans Condensed from `/usr/share/fonts`. With the
  Homebrew DejaVu fonts and Pillow 12 (FreeType 2.14.3) the build differs from v0.29.1 (`54dea9bc…`). In an
  `ubuntu:24.04` container (`python3-pil` 10.2.0, `libfreetype6` 2.13.2, `fonts-dejavu-core` and `fonts-dejavu-extra`
  2.37) it rebuilds v0.29.1 `8bb07ccc…` byte for byte.

## Delete button remap (#37), step 2: the Button Function row
- 2026-11-13. Emulator only, no camera test.
- **Build:** `firmware/build.py` copies the key table into `.ext12` (`dl_keys`) with
  the record `{14, 570, 1276, 1}`, points the three imm32 at the copy and the three `cmp 28` at 29. The validators of
  570 and 1276 point at the Fn lists of 47 and 1272.
- **The default reads as Off:** `dl_get` in `firmware/src/editor.s` (called from `sl_get` for sid 570) reports the
  stored 3333 as 3200, so the row shows "Off" and the walk finds no function.
- **The OK-entry table holds 15 rows:** menus 363 (def `0x6151085c`) and 365 (def `0x615108a4`) read
  `{0x6150ce14, 15}`, 24 B entries `{1, sid, 0, 8, item, 0}`, walked at `0x611a2631` (loop `0x611a26c7`). A 16th row
  needs a copy (`dl_oks`) with `{1, 570, 0, 8, 0x2d8, 0}` and both defs set to `(dl_oks, 16)`.
  The movie menus 364 and 366 use `{0x6150cf7c, 15}` and need the same copy (`dl_moks`, see the movie row below).
- **The picker:** descriptor table `0x615c540c` (416 x 24 B `{item, 0x44, sid, 0x60, picker key}`). Item 0x2d8 and
  picker key 1 are unused. The build reuses 1967's descriptor (`0x615c762c`) as `(0x2d8, 0x44, 570, 0x60, 1)`. The
  variant table `0x61571ba0` gives key 1 Fn's 55-entry lists. Title icon list `0x6139e26c` index 1 was blank and now
  holds `DL_IC`, the camera's trash picture 14135, as on its name-entry screens (camera-tested
  d6, 2026-11-14: photo and video rows, picker title).
- **Body diagram:** Delete is the AF-ON-sized button below and left of the ✥ pad (ring x 287..309, y 299..318).
  `firmware/diagrams.py` adds `button_hi()` and `delete(pos)`. Delete follows ▼ in both menus, with the other back
  buttons. The rows below it move one place, and a stock diagram keeps pointing at its old place, so every moved row
  needs our own diagram (`DGK`). Photo: Delete page 2 place 3, L-Fn 4, CRT 5, ART 6, COLOR and MONO page 3 places
  0 and 1. Movie: Delete page 2 place 1, L-Fn place 2. At place 2 the movie L-Fn row is level with the top of the
  dot, so `lfn()` turns its corner off the dot's right edge.
- **Emulator results:** the Delete row shows after ▼ with the trash icon and "Off". Its
  diagram line meets the lower-left button. OK opens a picker titled with the trash icon that lists the Fn
  functions. Choosing C1 stores 3348 in 570 and the row shows C1. The ▲ and CRT pickers match v0.29.1 (▲ is blocked
  by "✥Function" in both).
- **Movie row (emulator only):** the same steps for 1276 in the movie Button Function (menus 364 / 366 def
  `0x61510880` / `0x615108c8`, OK entries `{0x6150cf7c, 15}`, rows mode 366 at `0x6152a114`, item tree `0x61569078`).
  It uses 1285's descriptor (`0x615c7614`, 1285 is in no row list) as `(0x2e8, 0x44, 1276, 0x60, 17)`. Picker key 17
  has the movie Fn lists. A variant word's high half is the title icon index + 1, and key 17's is 2, so it shares
  key 1's trash title. `sl_get` sends 1276 to `dl_get` as well. In om-emu the row shows after ▼ with "Off", the
  picker lists the movie Fn functions, and C1 stores 3457 in 1276. om-emu has no photo / video switch, so the movie
  menu opens from Button Settings (`menu left left left left left ok down ok`) and a press in video is not tested.
- **Camera:** the rows are camera-tested from d1, the press path from d5 (step 3).

## Delete button remap (#37), step 3: the press in live view
- 2026-11-13. Camera result for d1, then static analysis and emulator for d2. d2 has no camera test.
- **Camera (user, d1):** the Delete rows, the icon and the diagrams show. The chosen function is kept after a restart.
  A Delete press in shooting does nothing, whatever the function. In playback Delete still deletes.
- **The cause (static + emulator):** a key event runs the handler in the current state's block (`0x610b9fdb`,
  called at `0x610bed29`). If the block has no entry, the global block `0x61339080` (156 entries) runs. Blocks hold
  16 B entries `{event, UI code, 1, handler}`. The second word is the event's code from the event table
  `0x612f3100` (Delete press 39, release 41), or 1 for none. In om-emu, stills live view is state 0x5100 (block
  `0x6131bd50`, 173 entries, referrer `0x6131e7f0`). Movie live view is 0x5300 (`0x6131eecc`, 146, `0x61321b2c`).
  - 0x5100: Delete press runs `0x610b8397`. It deletes a Multiple Exposure frame when `0x610865c5()` is non-zero
    (strings `deleteMultiExposure`), else it does nothing. Nothing else points at `0x610b8397`.
  - 0x5300: Delete press is `{1, 1, 0}`, no handler.
  - AF-ON press in both states runs `0x610a2407`, which calls the dispatcher `0x61083022` and runs the action. Its
    release runs `0x610a2dec`. Neither state lists a Delete release.
- **d1's emulator run was misleading:** the dispatcher call seen on a Delete press came from `0x61084d48`, a
  touch / key exclusivity check (strings `EXCLUSIVE_STATE_KEY_PRESS`), not from a handler that runs the function.
- **Other finds (static):** the states 0x58xx / 0x59xx pass Delete on as UI code 39 / 41. om-emu reads none of
  those entries in live view or movie. `0x612f45c8` lists 15 full-button press events (◉, AF-ON, Fn, |●|...), not
  Delete. Its readers are `0x61084654` and `0x61084a70`, and a caller at `0x61090402` fills a 13-slot buffer from
  it. The global block maps events 0x0100002a..2d to the Delete events (`0x61084ac9`).
- **Fix (d2):** `dl_lv` in `firmware/src/editor.s` replaces 0x5100's handler. With a Multiple Exposure frame it
  jumps to the stock `0x610b8397`. Otherwise it jumps to AF-ON's `0x610a2407`. 0x5300's entry gets `0x610a2407`.
  Delete still has no release entry, so a hold-type function may not stop on release.
- **Emulator (d2):** stills P, Delete = Magnify: `dl_lv`, then `0x610a2407`, then action 26. The screen drops its
  side indicators. With d1 the screen stayed the same. Movie: `0x610a2407` runs and returns action 26, but nothing
  shows, as with movie Magnify on ▲ in v0.27. Playback: the Erase dialog opens and `dl_lv` does not run.
- d2: E1479999.BIN 1df0410a….
- **d3 (review fixes, emulator only):** the three live-view blocks move to copies in `dl_blk`, each with one more
  entry: Delete release `{0x01000027, 1, 1, 0x610a2dec}`, AF-ON's release handler. State 0x5400 (block
  `0x61321b98`, 89 entries) also gets `0x610a2407` for the Delete press. It sends AF-ON and the arrows to
  `0x610a2407` and has extra 0x02000xxx events, so it is probably video recording (analysis / guess: om-emu does not
  record). om-emu: stills and movie Delete run `0x610a2407` (action 26) on press and `0x610a2dec` on release.
  Playback still opens Erase. ▶ still dispatches action 15. d3: E1479999.BIN b42c2146….
- **Camera (user, d3):** Digital Teleconverter on Delete works in photo mode. High Res and Start/Stop Recording do
  nothing, and nothing works in video mode. After a Delete press, Menu and Info do nothing until playback is opened
  and closed.
- **Full-button list (static):** `0x612f45c8` holds 15 press events (◉, AF-ON, Fn, |●|...). `0x61084a70` tests an
  event against it, and `0x610b4976`, `0x610b4a61`, `0x610b4b03` and `0x610b5b94` dispatch only for a listed event.
  d4 copies the list into `dl_full` with 0x01000026 added and points its readers (`0x61084654` imm32 + `mov 15`,
  `0x61084a77` imm32 + `cmp 15`) at it. om-emu never calls `0x61084a70` for Delete, so this needs the camera.
- **Menu lock (emulator, reproduced on d3 / d4):** with Delete = Magnify, Menu (event 0x0100001e) after a Delete press
  is looked up in state 0x5a02 (block `0x61332288`, 85 entries), not 0x5100. AF-ON's press enters 0x5a02 and AF-ON's
  release `{0x01000033, 1, 1, 0x610b038a}` leaves it. 0x5a02 lists no Delete release and ignores Menu `{1, 1, 0}`.
  67 shooting states have an AF-ON release handler and no Delete release. Copies of all of them need 57 KB, and ext12
  has about 28 KB free.
- **The state lookup (static):** `0x610bece0..` walks the current state's block (`call 0x610b9fdb` at `0x610becf5`),
  then its parent's (`0x610bed29`), then the global block (`0x610bed63`). `0x610b9fdb` walks d1 entries from a1 for
  d0. It returns a3 = found, and a2 = the handler, which it calls with a1 = the state machine. The state machine's
  (188) is the current state.
- **Fix (d5):** `.hook_dl` at `0x610ba015` (the walk's end) jumps to `dl_look`. If no entry matches a Delete press or
  release and the current state is 0x5100..0x56ff or 0x5800..0x5bff, the walk runs again for AF-ON's event (+12). The
  handler still gets the Delete event, so the dispatcher reads Delete's setting. Playback (0x57xx) is unchanged. d5
  drops d3's block copies (`dl_blk`). 0x5100 keeps `dl_lv`, and 0x5300 / 0x5400 keep AF-ON's press handler in place.
- **Emulator (d5):** Delete = Magnify in photo and video: press `0x610a2407` (action 26), release `0x610b038a`, then
  Menu opens. Playback opens Erase. ▶ dispatches action 15. d5: E1479999.BIN 5172b3fe….
- **Camera (d5, 2026-11-13):** Photo mode: Delete runs High Res, Magnify and Subject Detection on/off. Menu
  opens after each Delete press. Video mode: Delete runs Subject Detection on/off, Digital Teleconverter, Magnify and
  Start/Stop Recording. Info opens after a Delete press. Playback Delete still erases. With Delete at Off,
  Multiple Exposure's frame delete works as stock.
- **Bracketing states (static, then camera, 2026-11-13):** the 42 states 0x5900..0x593e (bracketing, trace strings
  `...BktSubAppState...`) list an AF-ON release and no AF-ON press or Delete entry. A Delete press there falls to the
  parent, where `dl_look` takes AF-ON's press. About 37 of their 41 release handlers pass the event to `0x61083022`,
  directly or through `0x610a6ecc`, so Delete's own setting decides. Camera, AE bracketing: Delete = Magnify works
  and Menu opens after it. Delete = Off does nothing.
- **Camera (2026-11-14):** the Delete setting survives a power-off.
- **Display off (static, then camera, 2026-11-14):** stock `0x610b8397` first returns if `0x610894f0()` is 1, which
  it is when `getDisplayDeviceState` (`0x61087e84`) reads DISPLAY_OFF. The same guard blocks Menu. `dl_lv` skips it,
  as AF-ON's `0x610a2407` does. Camera: Delete runs its function with the screen folded shut and with the EVF on.
- **Fallback states (static + emulator, 2026-11-14):** the global block `0x61339080` has no Delete or AF-ON entry.
  In om-emu 0x5100 has no parent block. Of the 69 states `dl_look` sends to AF-ON's entries, every handler dispatches
  through `0x61083022` with Delete's setting, or only consumes the press (`0x610b74f4`) as it does for AF-ON. Not
  proven: a sub-state of 0x5100 with an AF-ON entry would skip `dl_lv`, so a Multiple Exposure frame delete there
  would not run.
- **Arrows next (analysis, 2026-11-13):** d5's route may fix the five functions that fail on the arrows (Magnify,
  Multi Function, HDR, High Res, Live ND, `research/BUTTONS.md` "Up key, camera test 2"). On Delete, High Res and
  Magnify failed until Delete got a full-button list entry and AF-ON's press and release entries, and now they work.
  The arrows need a different hook, because their state blocks already have entries (navigation codes) and d5's
  fallback runs only when nothing matches. Send only those five codes down AF-ON's entries and leave every other
  arrow press on the stock path. HDR, High Res and Live ND are the likely wins. Magnify and Multi Function may still
  fail, because inside them the arrows move the frame or select. The other arrow functions already work, so the route
  is no faster or simpler for them. Try it on its own branch, after #37.

### Delete button (#37, PR #40 by crombach) on top of v0.29.2, and v0.29.3 (2026-11-14; camera-tested)
- PR #40 merged into a local branch at v0.29.2: the firmware merged without conflicts; builds (ext12 230240 of 262144 B);
  its hook 0x610ba015 and the key / full-button table copies are apart from the custom-mode hooks; its sids 570 / 1276
  are free (the Creative Dial memory uses 1275 / 1277 / 1284 / 1958). om-emu: the custom modes as in v0.29.2; the
  Delete row (the camera's trash picture) in Button Function after ▼, its picker opens. Test build d1 (VERSION
  "v0.29.3-dev (Delete button, d1)"): E1479999.BIN 7cab0a88….
- **Camera (owner, 2026-11-14, d1): "it all works"**: Delete takes a function in shooting, playback erase and text entry
  as stock, custom modes as v0.29.2.
- The contributor then rebased the PR onto v0.29.2 (head e406258): its firmware equals d1's but for VERSION.
  **Released as v0.29.3** (owner): the PR's commits as they are, then the release commit; VERSION "v0.29.3 (Delete
  button, tested)" (same length as d1's; byte diff: only the name, the code-block tag, the built-in GUIDES CRC).
  `releases/v0.29.3`: patch.json (175 runs, 327,667 bytes), extras as v0.29.2. `patch.py` makes 1eeb8976….

## Picture Mode display, stars and saving (2026-11-14, camera-tested)

Branch `fix/picture-mode` (crombach), from v0.29.3: `fix/picture-mode-display`, then `fix/hsl-row-star` on top of it,
then `fix/save-on-picture-mode-exit`. Owner rule for the stars (crombach): a row gets a '*' only when it differs from
the default of its profile or film, and a change on one row never stars another row.

### Display
- A negative Whites showed "M" in the Blacks / Whites grid. `bwg_swap` adds header picture 10819, the camera's other
  "M", so it shows "-".
- `wb_draw` masks the second value (`and 255`) before it joins the redraw key. A negative G-M or Whites
  sign-extended over A-B or Blacks, so the grids' left cell stayed stale after a change there.
- Halation's center mark is hidden: it is the bar block's child 15 (block +8). On the 0..5 bar, `sl_dot` clears it
  with `clr d0`, then `movbu d0,(8,a0)`.
- Before the films load, a Blacks / Whites grid edit changed the camera's own WB shift. Owner's camera, c9, COLOR 1-4,
  no half-press yet. v0.29.3 does the same. `gr_id` maps the camera's WB shift ids 1580..1605 to BKB / WHB + k, so
  when `REAL` misses, `sl_set0` label 9 passed `gr_oid`, the WB shift id, to `tn_set` and on to `ed_set`. The WB grid
  row has the same path through ABB / GMB. Label 9 now refuses classes 5..8 (Blacks, Whites, A-B, G-M). The other rows
  use our own ids, which the camera ignores, or Sharpness's own per-COLOR id. Emulator: every row as before after the
  half-press. Before it, v0.29.3 and c9 show the bug (WB A2 M2 after a Blacks / Whites edit) and c11 leaves WB at 0 / 0.
  The emulator reaches Picture Mode with no half-press: `ok wait ok wait ok wait` (date screen, quick menu, Picture
  Mode). Camera-tested 2026-11-14 (owner, c11): WB stays as it was. The grid's dot still moves while the screen is open,
  and the edit is gone when the grid opens again.
- Before the films load: `sl_gb` label 9 jumps to `vf_get`. When `sl_slot` misses, `vf_get` answers 1 (On) for
  VFB + k and for VF_IT (5389, the left-column label), then falls through to `tn_get`. Sharpness stays on the camera's
  range.
- A changed film shows "FILM n*" in the shooting screen's picture-mode name, as a changed COLOR profile shows
  "COLOR n*". `fl_pcp` picks layout `fl_LVL1` for `fl_LVL` when `fl_fch` says the film changed. `fl_LVL1` adds the
  '*' picture `fl_lvst` (cap 18, its fill 8 rows above the cap line, gap -5). Camera-tested 2026-11-14 (build c9).

### Stars
- `ed_isd0` (the profile name's '*' and the Reset guide) and `ed_isdef` (the HSL row's '*') share one path. The flag
  rides in d3 bit 8 (`asl 8,d1`, then `or d1,d3` before `stock_isdef`), because `stock_isdef` clobbers d1.
- A profile changed only on Halation (+30) gets its '*' and the Reset guide.
- Only `ed_isd0` counts the slot's +47..+54, +30 (Halation), +33 (Tone Balance) and the WB shift (+25 & 0x81 == 1,
  then halfword +26). The HSL row keeps hue, light and the split toning strengths +56 / +58.
- Grid rows: the WB row (WGB + k, 0x7ec0) reads the slot's +57 flags and +58 halfword. The Blacks / Whites row
  (BWB + k, 0x7ef0) reads +79 / +80.
- Films (`fl_isdef`): rows 12 and 15 compare two `fl_xr` pairs, packed into (8,sp) as pair1 | pair2 << 16, with
  `and 0xff` after `lsr 8`. The range is 0x100.
- Noise (+51: 0 Camera, 1 Std, 2 Low, 3 Off, 4 High): a reset profile or film holds 0. High then Std stored 1, so the
  profile kept its '*' and the Reset guide while the row showed none. The setter now stores 0 when the choice equals
  the camera's own Noise Filter (`nf_get`, key 0x9719). d0 / a0 / a1 are kept in `gr_sv` across the call, because
  `s_dirty` reads them. Every film in v0.29.3's LOOKS.BIN holds 0 at +51.

### Saving on leaving Picture Mode
- `gx_map` calls `pm_save` (ext12) at `cmp 0x1804,d1`. `pm_save` takes DIRTY under LOCK, then calls `ub_put`. If
  `ub_put` returns 0, DIRTY goes back to 1, so the next exit or half-press saves again.
- `ub_put` guards `ub_wr` with the byte `ub_run` (test-and-set under LOCK), so the GUI task and the half-press task
  never build `ub_stg` at once. A busy guard sets `ub_pend`.
- om-emu: Halation +1, then MENU: `pm_save`, then `ub_wr`. A stock row such as Contrast calls `pm_save` but not
  `ub_wr`, because the camera saves stock rows itself.

### Tests
- om-emu (branch build): each of the 14 rows stars only itself and the profile. Films 1-4 unchanged show no '*'.
  Noise High then Std clears the '*' on COLOR 1 and on FILM 1.
- Camera (crombach, test builds c1..c7 with these branches and PR #45): a reset, or an edit, then MENU, then power-off
  keeps the change. Leaving by a half-press works. All rows star as the rule says. Noise back to Std clears the '*'
  (c7, E1479999.BIN 17d9b9df…). Halation shows no dot, and Whites and the WB cell look right.
- Open, kept as it is (crombach): before the first half-press, our rows (Vignette, Halation, Glow, Grain and the
  others) show their defaults and do not store an edit, so they get no '*'. A later change is planned on its own
  branch: gray out "-" / "+" by giving each of our bars min = max until the load. The emulator reaches Picture Mode
  before the half-press with `ok wait ok wait ok wait` (see Display).

## Film WB: Custom WB Kelvin lost on OK in the WB screen (2026-11-14, camera-tested)

Branch `feature/film-cwb-kelvin` (buburun), from v0.29.3.

- **Camera (v0.29.1, reproduced since in om-emu on v0.29.3):** pick a film whose WB is Custom WB (here 3800 K): the
  shooting screen shows CWB 3800 K. Open the WB screen (Super Control Panel › WB) and press OK on "CWB*": the Kelvin
  jumps to an old value (2700 K on the camera where it was found), and the film gets a '*' (fw_keep stores the
  camera's WB into it) and keeps the wrong Kelvin until reset (OK held).
- **Cause:** fw_apply writes 107 MODE_CUSTOM_WB_KELVIN_1 and 1578 MODE_WB_STILL. The stills Custom WB keeps its own
  Kelvin, **1632 MODE_CUSTOM_WB_KELVIN_1_STILL** (1633 for movies), and OK on CWB in the WB screen loads it into 107.
  Its own shifts are 1592 MODE_WB_REV_CUSTOM_STILL (A-B) and 1605 MODE_WB_REV_G_CUSTOM_STILL (G-M); a film's own
  shift (slot +25..+27) adds to them. Names from the settings name table (decoded block 02, 52-byte names from
  0x28803f0, id = index).
- om-emu, v0.29.3, a film at 3800 K picked: 107 3800, 1632 5400; WB screen, CWB, OK: 107 5400. A card that also
  carries an old BUNDLES.BIN hides it in the emulator (a later write through the camera's own handle sets 1632 too),
  so test with a card holding only LOOKS.BIN.
- **Fix:** fw_apply writes 1632 with the film's Kelvin, then 107 (the mode's local holds K for the two calls; the
  mode is CWB there). om-emu: 107 / 1632 3800 / 3800 after the pick and after CWB, OK; a film at 6000 K, then the
  3800 K film: both follow; a film without its own WB: Auto.
- **Camera:** v0.29.1 + this change (2026-11-14): CWB, OK keeps 3800 K, no '*'; away and back keeps it; a film
  without its own WB goes back to Auto. v0.29.3 + PR #46 + this change (2026-11-15): CWB, OK keeps 3800 K.
- **RAW editing:** a photo taken after the jump, and its RAW, carry the old Kelvin (the om3.1 code records it too),
  so RAW Data Edit with the film's own Kelvin (Custom2 CWB, Picture Mode = the film's COLOR) does not match the
  in-camera JPEG. RAW Data Edit itself develops the film loaded on that COLOR (colour, tone, split toning, Halation,
  grain and the film's WB shift; camera, 2026-11-14); its WB mode, Kelvin, Noise Filter and exposure come from Custom2.

### v0.29.4: PRs #45, #46 and #48 (2026-11-15; camera-tested)
- #45 and #46 merged into main as their authors wrote them (#46 updated by crombach after cad's r1..r4 review builds;
  the review's own changes were not taken, owner). #48 merged on top in a local test branch: conflicts only in
  ROADMAP.md and this file (both entries kept); the firmware merged cleanly. Test build t1 (VERSION "v0.29.4-dev (main
  + PR 48, t1)"): E1479999.BIN 3825f078….
- **Camera (owner, 2026-11-15, t1): all good** (#48's CWB, #46's stars, saving, display); debug log: build t1, every
  file loaded and matching, films block valid, no errors.
- **Released as v0.29.4** (owner): VERSION "v0.29.4 (PRs 45 46 48, tested)" (same length as t1's; byte diff: only the
  name, the code-block tag, the built-in GUIDES CRC). `releases/v0.29.4`: patch.json (175 runs, 327,352 bytes), extras
  as v0.29.3. `patch.py` makes 757e2d39….

## Per-mode settings p1: each custom mode keeps its own copy of everything (2026-11-15; emulator only)

Branch `feature/per-mode-settings-2` (from main v0.29.4; the r4-based first try is kept on `feature/per-mode-settings`).
Owner (2026-11-15): Assign > Set to Cn copies every setting of ours; nothing done in another mode (edits, a film reset,
picks) changes Cn's copy. Plan and earlier findings: `research/per-mode-settings/PLAN.md`.
- **Camera facts (om-emu):** stock firmware: P / A / S / M share one COLOR block, each photo custom mode has its own.
  Video / S&Q at the P position shows the same block as photo P (v0.29.4's movie switch wrote nothing there because
  rc_put had already forced the films into it); movie custom modes have their own. Mode code: P..B 1..5, C1..C5 53..57,
  video / S&Q 10; the photo / movie / S&Q switch's position is the byte 0xa32d9d0d (2 / 1 / 0), next to the dial's.
- **p1 (`ss_*`, end of the custom-mode code, ext12):** six sets (C1..C5, P group), record 'OM3S' at M + 0x3D000
  (11,896 B; M + 0x3C000 is taken by film-rolls and screen-info, which clash with each other there). A set = the looks,
  the four slots (our rows), the camera's 18 values when it was made (diagnostic), and its own EDITS image (every
  film's changes). At a photo dial change (rc_go): the set being left is kept when it holds (P always, Cn on Hold);
  entering a "trusted" set (P, or a Cn with films of its own) loads its EDITS image before cm_go, switches films
  without the camera's 18 settings (`ss_lib`, no manager writes), puts its slots back, and rc_put writes nothing (the
  camera's own per-mode values are right). First entry of a set: made from what is shown (migration: nothing changes
  at the update). Cn without films of its own: as before (rc_put); after Assign > Reset its films as built, no changes.
  Assign > Set copies everything (`ss_asg`); Recall takes Cn's set. Kept at every half-press (`cm_hp`) and on leaving
  Picture Mode (`pm_save` -> `ss_pm`). Video / S&Q: as before, except at the P position with P's slots, where nothing
  is put back (else rc_put overwrote P's own values: found by the video write count).
- **Emulator (p1 vs v0.29.4, same scripts):** the owner's scenario (P: Halation +2, Contrast +1, Assign C1; C2, C3, A,
  S, P, C1; reset the film in P; C1; power-off; C1, P): p1 C1 keeps +2 / +1 throughout and P stays reset; v0.29.4 loses
  C1's values at the P reset and P's Contrast at the power-off. P's later edits and film switches never reach C1.
  Before the first half-press: 4 screens and 99 settings-manager calls identical. Video / S&Q switches in P and C1:
  179 manager writes (v0.29.4 183), none more per switch; P's Contrast kept through video.
- **Assign > Reset is not caught (v0.29.2..v0.29.4 too):** the menu's Reset calls the facade's entry 19 (vtable word
  0x60e574c0, stock 0x60b86aaf) with d0 = the custom mode 0..4 (om-emu trace), not entry 18 with d1 != 0 as cm_rec
  assumed. p1's CADLOG check showed it: after a Reset of C1, entering C1 found 44 camera COLOR values that differed from
  C1's noted ones (the camera's defaults against our films). Hook entry 19 in p2.
- Package p1: `E1479999.BIN` e5dfded3… (VERSION "v0.29.5-dev (per-mode settings, p1)"), go-back v0.29.4 757e2d39….
  Emulator: Hold (C1 keeps its own change over the dial and a power-off; P never shows it); go-back to v0.29.4 starts
  normally with the films and changes of the last mode.
- **Camera (owner, 2026-11-15, p1 e5dfded3…): "It all worked"** (camera-tested): the owner's scenario (Assign C1, other
  modes, a film reset in P: C1 keeps its copy), P keeping its own changes, video, start-up. CADLOG (as reported by the
  main chat): 35 events, saves 1, sets saved 8, 0 differences in Reset custom modes. Not camera-tested: Assign > Reset
  (not handled, see above), every row besides those the owner changed.
- **p2: Assign > Reset** (`cm_rst`, facade entry 19, vtable word 0x60e574c0 -> `cm_xstock` 0x60b86aaf, build.py WORDS):
  cm_rec's clear path (the custom mode loses its films of ours; ss_rst: its set dropped, built from the films at its
  next entry), then the camera's own Reset. Emulator (p2): P Halation +2 / Contrast +1, Assign C1, Reset C1: C1 shows
  the films as built with no changes (all four COLORs; FILM 15 Halation 0, Sharp +1, Contrast 0), at each entry and
  after a power-off; P keeps +2 / +1; 0 differences. The p1 scenario gives p1's results. VERSION "v0.29.5-dev
  (per-mode settings, p2)".
- **Camera (owner, 2026-11-15, p2 27f44762…): "it works"** (camera-tested): Assign > Reset puts the custom mode back to
  the films as built; the p1 scenario still holds. CADLOG (as reported by the main chat): 23 events, saves 1, built from
  the films 1, 0 differences in Reset custom modes.

### v0.29.5: per-mode settings (2026-11-15; camera-tested)
- **Released as v0.29.5** (owner) from `feature/per-mode-settings-2` (p2, 9a92cc1, camera-tested; notes 0820c13).
  VERSION "v0.29.5 (per-mode settings, tested)" (same length as p2's; byte diff: only the name, the code-block tag, the
  built-in GUIDES CRC). `releases/v0.29.5`: patch.json (175 runs, 342,144 bytes), extras as v0.29.4. `patch.py` makes
  01ea3d14….

## Per-film R / G / B tone curves: build (2026-11-15; feature/rgb-curves, emulator only)
Owner: build mockup B (curves edited on the camera); no LookLab, no LOOKS.BIN / photo-code change until the camera build
is finished. Branch `feature/rgb-curves` from v0.29.5. Code `firmware/src/rgbcurves.inc` (comments are the spec),
pictures `firmware/rgbpics.py`, exact model `research/rgbcurves/model.py`.
- **Engine (emulator, bit-exact):** 3 x 6 points (input 0 / 10 / 25 / 50 / 75 / 100 % of the tables' 12-bit output),
  offsets -7..+7 of 48 (1.2 %); D(t) monotone-preserving cubic (Hermite, harmonic-mean tangents), added in `st_run`'s
  pass with split toning's delta, then its clamp and running max; per channel only when it has a point set. om-emu
  ncall of st_run on a fake COLOR job: curves only, curves + split toning (red Shadows / cyan Highlights / Balance +2)
  match the model on all 960 entries; split toning alone is byte-identical to v0.29.5; registers, MDR and sp kept.
  Live view: same gates as split toning (key 11 / 12, `ST_STILL 0`). ~50k instructions a pass per two curved channels.
- **Storage (emulator):** record 'OM3R' at M + 0x3B100 (docs/FORMATS.md), RAM image `cv_ram` (26-byte slots: 18 curve
  values, then 8 bytes kept for a future per-film colour matrix, owner via the research lab 2026-11-15; in M packed two
  values to a byte, 17-byte slots, 3,348 B, version 2, so it fits before +0x3C000: unpacked it would be 5,112 B). The curves follow the
  slot: `cv_rec` at `pf_put1` / `ss_slot` (an EDITS record -> its saved curves, anything else -> flat), `cv_cap` after
  fl_sw's `pf_capto`, `cv_sput` / `cv_sget` / `cv_sed` in ss_put / ss_get / ss_ed, `cv_zk` in e_rst. Written with the
  films block (`ub_wr`, its new generation) and with the sets (`ss_wr`), in their locked sections. Read at the first
  half-press (`ub_pfl`; nothing at start-up), only with the block it was written with. om-emu: film switch keeps each
  film's curves; power-off / on keeps them (flat until the first half-press); after v0.29.5 saved the block they read
  flat; a custom mode change carries them as it carries the slot's other rows.
- **Page (emulator):** row RG_IT 5378 under H&S = the H&S row in the column's switches, except: update case `cv_case`
  (marks the page on; `cv_hs` for H&S, `cv_pu` / `cv_gx` off), left cell `lc_rg` ("RGB"), the row's "changed?" `cv_star`
  (its '*' and the Reset guide from the curves). While on: the page's own reads of 976 + 3k (Hi) / 977 (Mid) / 978 (Sh)
  are ours by return address (`cv_get` / `cv_dflt`: Sh = the selected point's offset, Hi = the point 1..6, Mid 0;
  2191 reads 886), writes of them and of 2191 keep the camera's values (`cv_sv`: the manager gets them back, which
  redraws the page). Events (`cv_ev`): front dial 0x9031 = point, rear 0x9032 = offset, INFO 0x9014 = next colour, then
  passed on as they came; the camera only gives INFO and the held-OK reset to the row's panel for items 5397 / 5398
  (0x611c29c2 / 0x611c296f), so two hooks add RG_IT (`cv_inf`, `cv_rsi`); the reset's first write makes the curves flat
  (`cv_rst`). Dead ends: passing a fake dial event (the camera reads the dial driver, ignored until a real turn) and
  consuming the event (page stale, then Picture Mode closed). Pictures (`cv_ic`): halves 4147..4176 clear, middle
  curves 4177..4206 our 300 x 300 type-11 picture drawn at run time (`cv_draw`, into a 36 KB work area after the
  built-in files: loader end word 0x60fa3000 -> 0x60fac000, GX4-proven space, checked FF in the image), labels
  4208 -> R / G / B, 4207 -> "Pt", 4331 clear, guides 16247 / 16248 -> "Color [INFO]". The film's '*' counts curves
  (`fl_live`, `fl_fch`).
- **Palettes (om-emu):** the curve layer (palette 0x614a5fe0, read when Picture Mode opens) is a 32-entry OSD plane
  (indices >= 32 not drawn) with orange / green / white / greys only; entries 27..31 fill whole screens (a test
  build with them magenta turned almost every screen magenta), so no palette change: red = orange 4 / 6, blue = white
  14 / grey 15. The header labels use another palette (red 122, green 40, blue 105), the left column a third (105 shows
  yellow-green there; 125 is blue).
- **Regression (om-emu, pixel-identical to v0.29.5):** the H&S row (dials, INFO, held-OK reset), the HSL wheel (INFO
  pages, an edit, held-OK reset), the Blacks / Whites and WB grid rows and the WB fine-tune screen.
- **Test build 1 (1b):** VERSION "v0.30-dev (RGB curves, test 1b)", E1479999.BIN 819ce467…64a6 (rebuilds byte for
  byte; replaces 00edb50f…, never flashed, which had 18-byte slots and a version-1 record). ext11 54,224 / 65,536,
  ext12 260,112 / 262,144. Package (private) `test-builds/2026-11-15-rgb-curves-1`. om-emu on 1b: engine bit-exact,
  storage (film switch, power cycle, the packed record read back), the page and the v0.29.5 pixel comparison as above.
  Open for the owner: dial directions, step size, the page's colours.
- **Test 1b camera (owner, 2026-11-15): "This is looking good"**; no freeze, debug log normal (cad). Notes: (1) "the B
  in RGB isn't blue and the line isn't blue either"; (2) "it is cumbersome to use in a way ... there isn't clear guide
  to using those dials".
- **Test 2 (emulator only):** (1) om-emu stripe tests: in the row's cell, entries 105 and 125 do not show blue (125 is a
  dark grey there, as the owner saw); 53 shows blue in the cell and the header -> the "B" is 53. The curve layer: each
  of its fillers 27..31 made magenta alone in v0.29.5 over 29 screens: 31 is the whole-screen fill, 27..30 changed
  nothing -> build.py makes 29 / 30 (and 157 / 158) blue in the palette at 0x614a5fe0 only, for the blue curve (bright /
  dim). (2) A legend in the curve picture, top left: "Front dial: point" / "Rear dial: up / down" (rgbpics.legend, 2 bits
  a pixel, 176 x 40, in the image at the work area's +0x8000, loaded with section 6; cv_draw draws it after the
  points). om-emu: 17 screens (shooting screen info views, quick panel, menus, playback) and the camera's own rows
  pixel-identical to v0.29.5; engine bit-exact; storage as 1b.
- **Test 2 camera (owner, 2026-11-15): "This is lookign good again"**; no problems, debug log normal (cad). Notes: (1) "I
  don't think we need the text on the grid"; (2) "the curves are kinda shallow. and they be a little more dynamic?"
- **Test 3 (emulator only):** the legend removed (bitmap, its blit and its build step); step 48 -> 96 (2.3 % of full
  scale a step, +7 = 672 / 4095 = 16 %, about 42 of 255 levels; model.py STEP 96, om-emu ncall bit-exact incl. the
  -7 / +7 zig-zag); cv_draw keeps each drawn curve rising as st_run does (a lift at black now shows flat until the
  curve rises again, as in the photo; the points stay where they are set). Blue (palette 29 / 30, "B" 53) as test 2.
  om-emu: the 17 screens and the camera's own rows pixel-identical to v0.29.5; storage as before.
- **Test 3 camera (owner, 2026-11-15): froze and rebooted.** "The changes made the camera freeze and reboot. so lets go
  back to the other version. it worked well and I think the changes would be too much anyways." Test 2 (34ba622e) is
  back on the camera and is the line; test 3's package renamed `WITHDRAWN-2026-11-15-rgb-curves-3`. Which step the
  owner was on is not known; the card's CADLOG.TXT only has the power-on after the reboot (3 events; the rest of the
  file is an older log's text, the camera's fopen does not truncate).
- **Why (code + om-emu only; not proven on the camera):** test 3's own changes give no path to a freeze:
  - step 48 -> 96: the maths stays in range (largest products ~3.6e8 in cv_prm, no divide by zero: a + b is never 0
    for same-sign non-zero slopes), and om-emu ncall is bit-exact with the model at -7 / +7 zig-zags; the tables stay
    0..4095 and rising. The shapes it makes (black raised to 672, white lowered to 3423, flat stretches) are inside
    what the camera's own curves already have: of the 70 curve objects in the row table 0x606d3d3c, art-filter curves
    start at up to 1347, end at down to 2866, with up to 233 flat steps.
  - the running max in cv_draw and the legend's removal: our page picture only, bounded loops.
  - CW_END 0x8000 -> 0x9000: the picture never gets there (om-emu, all three curves zig-zag -7 / +7: 10,660 B in test
    3, 13,140 B in test 2, of 28 KB).
  - **A risk shared by 1b, 2 and 3:** `cv_put` packs and checksums the curves record inside ub_wr's / ss_wr's locked
    section, and LOCK (0x60075f73 with d0 = 0) sets the PSW interrupt mask to 0: om-emu counts **212,851 instructions
    with interrupts off** at each films-block save (a change, then a half-press or leaving Picture Mode) and each
    custom-mode record save, against 5,870 for one ub_cpy of the 3,912-B block there in v0.29.5 (two of them, and the
    11,896-B OM3S copies, ~18k each). A time-critical interrupt missed in that window could freeze the camera; it would
    be rare and timing-dependent, which fits test 2 passing twice and test 3 failing once. Test 2 can reach it the same
    way (it does not depend on +-7 or on the doubled values).
  - Fix, if the owner wants one: pack and checksum into a buffer before LOCK and copy only inside it (~1.7k
    instructions), as ub_wr does with ub_stg. Not built (owner: test 2 is the line).
- **Test 2b (owner: "Build the fix"; emulator only):** test 2's code (restored, e2b5961: rebuilds 34ba622e) plus the save
  fix only. `cv_hdr` (before LOCK, interrupts on) packs the record, its header and CRC into a buffer of its own in the
  work area (CW_SU 0x6000 for ub_wr, CW_SS 0x7000 for ss_wr, as ub_stg / ss_ram are the blocks' own; the page's
  picture keeps 0x1000..0x6000, 20 KB, the largest seen ~13 KB); `cv_put` (inside LOCK) only copies it to M's two
  aliases. om-emu: with interrupts off 10,062 instructions (test 2: 213,131; v0.29.5's own two block copies there:
  11,740); cv_hdr 208,100 with interrupts on. The record after the same edits is byte-identical to test 2's; it reloads
  after a power cycle; ss_wr's path (ncall) writes a valid record (CRC, both aliases). 14 screens incl. the RGB page
  (edits in R / G / B, a reset) pixel-identical to test 2. No loader-word change; ext12 260,176 / 262,144.
- **Test 2b camera (owner, 2026-11-15): "Looking good!"** No freeze or reboot (debug log: 37 shutter events, saves
  fine). Camera-tested: the RGB page as test 2, with the curves record packed before the locked save.
- **Test 4 (cad for the owner, 2026-11-15; emulator only), built on 2b (its save and step 48 kept).** Owner: "we dont
  need the text on the grid anymore"; 5 even points 0 / 25 / 50 / 75 / 100 % (front dial 1..5).
  - The dials' legend removed (its bitmap at 0x60fab000, the blit, build.py's step), as test 3 did.
  - Engine: 4 even segments (cv_h 4 x 1024, cv_inv 4 x 16384; cv_d i = t >> 10, at most 3); cv_prm takes a curve's
    values 0, 2, 3, 4, 5 as the 5 points (same block offsets). The record and slots keep their layout (6 values a
    curve, OM3R v2, 3,348 B): value 1, tests 1..2b's 10 % point, is unused; cv_load clears it in every slot after
    reading the record, so curves set with 2b keep points 1, 3, 4, 5, 6 as the new 1..5 and lose the 10 % one.
    model.py updated (X, PTS); om-emu ncall bit-exact with it on 4 cases (incl. a value 1 alone: no change) and with
    split toning; split toning alone still identical to v0.29.5.
  - Page: front dial clamps to points 0..4; rear dial, Sh value and drawing map point -> value (0, 2, 3, 4, 5); points
    drawn at columns 0 / 75 / 150 / 224 / 299 (ncall of cv_ev: every step lands on the right value, never value 1).
  - Storage (om-emu): a 2b record with value 1 set in R / G / B -> test 4 at the first half-press has the other values,
    value 1 zero, nothing before; test 4 saves and reloads after a power cycle; 2b reads test 4's record.
  - Interrupts off per save 10,062 instructions (as 2b). 14 screens vs 2b: identical except the RGB page's curve
    picture (no legend, 5 points).
- **Test 4 camera (owner, 2026-11-15): "This looks good!"** No freeze (debug log: 51 shutter events, the films block
  written 8 times, saves fine). Camera-tested: no text on the grid, 5 even points. Owner's note for the next round:
  "it doesnt update the live view dynamially. I have to make adjustments, half press and then those adjustments show
  up" (the live view takes the curves only at the next set-up of the picture; test 5 looks at that).

### RGB curves: live view refresh while turning the dial (2026-11-15; analysis + om-emu, nothing built)
- Owner (test 4): the live view takes a curve change only after a half-press. Asked (cad): how do our other rows get
  the live view to refresh, and is there a camera-tested way to reuse.
- **Our rows all use one path, and it has no refresh step:** sliders (ed_set / s_dirty), split toning (tn_set ->
  s_dirty) and the RGB row (cv_sv) store our value, then hand the camera's setting manager (0x60bb528f) the camera's
  own, unchanged value (sget), so the page redraws. Nothing else is sent after a change.
- om-emu (WATCH on the manager, its writer tail 0x60aea1de and the change notifier 0x60063519, which the setting
  writer reaches only on a real change): the camera's own tone-curve row, rear dial -> value changes -> 0x60063519 and
  a tone-specific chain (0x603f03f0, 0x603f1a7c, 0x603f32a8, 0x60404f35, 0x60405752, 0x60b86e44, 0x60bb4a28) run. Our
  RGB row, same dial -> the manager runs with the unchanged value, none of those. The editor's "poke" (k_cur +
  SetValue 2197 + k with its own value, after a wheel page change / reset; sd2's sdl_poke did the same after the load)
  -> manager and 0x60aea1de run, 0x60063519 does not (only the writes that really change 2199 reach it). The manager
  sends the "picture mode" message (0x6041b019 with 111) for ids 111, 897..901 and 988 whatever the value; nothing of
  ours sends it.
- om-emu cannot show live view itself (no live view jobs: no hits at the builder 0x60518615 or st_run while idle,
  nor at the half-press). sd2 (camera-tested 2026-11-09: live view followed the film after the automatic load) is the
  only camera result for the poke; with the emulator showing no change notice from it, why it worked is not known.
- So: no camera-tested way to refresh live view on a change of ours exists; split toning and the sliders most likely
  show in live view only after the next half-press too (not checked on the camera). Every way to do it per dial step is
  new (a real change of a camera setting and back, re-writing the picture mode / film setting so the manager sends its
  picture-mode message, or calling the camera's set-up ourselves, as video-sharp v1 did). Waiting for the owner (cad).
- **Owner's decision (2026-11-15, via cad): "Keep the half-press".** No test 5 and no live-refresh experiment. Test 4
  (E1479999.BIN eab68387…, a5df321) is the line: the live view shows curve changes at the next half-press, as with our
  other rows.

### Colour mix per film: engine and probe m1 (2026-11-15; emulator only)
- Owner (via cad): "lets work on the color mix now"; camera firmware only, on test 4. Research Lab's first look:
  branch experiment/screen-info d21cff8, "Colour matrix per film ("colour mixing"): first look".
- **om-emu, stock (ncall of 0x605147a2 on a synthetic request, base matrix rows summing to 256):** COLOR (key 11)
  takes the default branch: with R+1587 and R+1923 0 no matrix is multiplied (the output is the base, rows scaled to
  128); R+1923 1..3 multiplies the identity (same output); R+1587 1 / 2 multiplies 0x606ad348 (the mild change). Key
  2000 and 12 as 11. The real values of R+1587 / R+1923 in a camera job are not known (om-emu runs no jobs); the hook
  does not depend on them. **0x60514290(a0 out, a1 A, d0 B) = A x B** (a row swap in A swaps B's rows), so A acts
  after B on a colour: our matrix goes in as A, the camera's so far as B.
- **Two callers** of 0x605147a2: 0x605196f6 in the development function 0x605196b4 (the one whose stage list holds the
  tone hook / st_run: photos and live view, camera-tested for split toning) and 0x6051a6fb (another job type, its own
  record layout: key from (a0)+8.., filter +918, base +896; not identified). Ours acts only for the first.
- **Hook `.hook_mx`** at 0x6051485a (stock `cd95fcf014` = call 0x605144ef,[d2,d3,a2,a3],20, the row scaling; build.py
  checks it) -> `jmp mx_go` (ext12, 0x60f99014). mx_go, in the matrix function's frame: films read (cv_ok), return
  address 0x605196fb, key 11 or 12 with R+1731 0 (as split toning), the effective COLOR k (getter 63153, as st_run),
  COLOR k's six values (slot + 18; the m1 probe uses mx_pr for COLOR 3) not all 0 -> our 3 x 3 (diagonal = 256 - the
  row's two values x 4) x the matrix so far by 0x60514290 into the function's free work matrix (F + 8, or F + 28
  when the matrix so far is at F + 8); then the stock row scaling and back to 0x6051485f with d2 / d3 as they came.
  ~540 instructions more per COLOR job.
- **Probe m1 (MX_PROBE 1, MX_PK 2):** COLOR 3 gets R' = 1.6 R - 0.6 G, G' = 1.6 G - 0.6 B, B' = 1.6 B - 0.6 R (values
  -38, 0, 0, -38, -38, 0; rows 1.0 so greys stay grey; noise gain ~1.7, the strongest kind of mix): very strong
  colours, yellows toward lime, cyans toward blue, magentas toward red. Nothing stored; the other COLORs as test 4.
- om-emu (the real call site 0x605196f6 run natively after the first half-press, session COLOR 3): key 11 and key 12
  with no filter -> exactly the camera's own multiply then row scaling of probe x base (also with R+1587 1); key
  2000, key 12 with a filter, the other caller, and everything before the first half-press -> identical to test 4.
  A build with MX_PROBE 0: values poked into COLOR 3's slot -> the same as the probe; into COLOR 1's (not in use) or
  none -> stock. 14 screens identical to test 4; save interrupts-off 10,062 (as 2b). ext12 260,448 / 262,144.
- Not known (camera): live view (expected, as split toning in the same function), the look at ISO 6400 (colour noise),
  video (the hook covers what split toning covers).
- **m1 camera (owner, 2026-11-15): works.** Live view: "yes, color 3s live view shows the strong colors" (so live
  view jobs go through the hooked caller, as for split toning). Photos at ISO 6400 under warm light, COLOR 1 vs COLOR 3
  (owner's PB152712 / PB152713, not kept): the mix shows clearly (wood toward yellow-lime, a screen deep blue); the
  warm room cast was pushed too (a silver laptop a bit yellow-green: the mix acts after white balance, so a cast left
  in the picture is mixed like any colour). Dark crop: COLOR 3's chroma spread ~1.7x COLOR 1's (R/B ~8.7 -> ~15),
  blotchy orange / green patches, as predicted for this strongest kind of mix. No freeze (39 events, saves fine).
  Video not tested (owner): list it again next time. Camera-tested: the hook, its gates, live view.

### Colour mix: the Mix row, mix test 1 (2026-11-15; emulator only)
- Owner's page choice (after mockups A / B "very confusing", D by name, an explainer of C): **C, the circle**: hue and
  strength of red, green and blue, as the camera's Color Creator (front dial hue, rear dial strength; INFO the colour).
  Owner's question on HSL (answered, analysis from the code): the mix runs before the gamma stage, HSL (the COLOR
  stage) after it, so HSL acts on the mixed colours; its values do not change.
- **Engine (mx_go):** the six stored values are now h, s per colour (slot + 18: h R, s R, h G, s G, h B, s B; m1's
  off-diagonal reading and the probe are gone). Column j: M[next][j] = 8 (h - s), M[prev][j] = 8 (-h - s), diagonals
  256 - the row's others (research/colourmix/model.py). Hue + = toward the next colour (red -> yellow, green -> cyan,
  blue -> purple), strength + = stronger. om-emu: the real call site with four settings = exactly the camera's
  multiply + row scaling of model.py's matrix; no mix / before the first half-press / key 2000 / a filter / the other
  caller = stock.
- **Page:** row MX_IT 5377 under RGB (pm_list; it_tab 29; the 9 column switches as RG_IT: mx_case, lc_mx, mx_star,
  else the H&S cases). The RGB page's code with cv_on = 2: cv_val -> mx_val (Hi = hue, Sh = strength), cv_ev -> mx_ev
  (front + hue, rear - strength, -7..+7, as the RGB page's offset), cv_ic labels "Sat" / "Hue" in the chosen colour,
  cv_dflt's Reset guide from the mix, resets through cv_zx (the Mix page clears only the mix, the RGB page only the
  curves; the wheel's whole-profile reset e_rst both), cv_kset / cv_jset count the mix as a change of the film ('*').
  The picture (cv_draw -> mx_pre / mx_line): a ring (r 90), its centre, marks where the colours start, spokes, the
  dots at angle start + 5 deg x hue, radius 90 + 4 x strength; the chosen one r 13 in its bright colour on a white
  r 16, the others r 8 dim. INFO's colour is shared with the RGB page.
- Found in om-emu before packaging: the page's row routine was first named mx_row, the camera's row scaling's name
  in editor.ld, and the label won silently, so mx_go called the drawing code (output zeros). Renamed mx_line; build.py
  now asserts the four camera addresses mx_go uses.
- om-emu: the page (labels, dots, '*', Reset guide), dials (ncall of cv_ev: hue / strength step, stop at +-7, INFO
  cycles), hold OK on Mix (mix off, curves kept), on RGB (curves off, mix kept), on the wheel (both off); save + power
  cycle keeps the mix, read at the first half-press. 14 screens vs test 4: the same except the new row in the list
  (and the steps after it). Save interrupts-off 10,062. Pictures moved to ext11 (ext12 was nearly full): ext11
  64,992 / 65,536, ext12 256,160 / 262,144. The camera's grid cross stays behind the circle (its own picture).
- **Mix test 1 camera (owner, 2026-11-15): "ok it works well, but a some tweaks".** No freeze (48 events, 6 films-block
  writes fine). Tweaks: (1) "the words sat and hue get cut off"; (2) "the dial symbols don't line up with what is
  changing". One ISO 6400 photo with a mix and one video clip were taken (owner's PB152714 / PB152715.MOV, not kept);
  no comment on them yet. Camera-tested: the Mix row, its page, the mix in photos and live view.
- **Mix test 2 work (om-emu; not packaged yet):**
  - "Cut off": the camera shows a header label in a 38 px box: test 1's "Sat" / "Hue" were squeezed into 38 px with
    their dark edge cut at both sides; a 58 px picture is cut to the same 38 px box (om-emu screenshot). Now drawn
    smaller (rgbpics.small_label: cap 17, ink inside columns 2..35), whole. The Mix page's pictures moved to ext12 with
    its code (rgbpics2.inc).
  - Dials (om-emu, WATCH on cv_ev and the manager): the emulator's "main" dial posts 0x9032 (EVT_ST_CHANGE_MAIN_DIAL),
    "sub" 0x9031 (SUB); which physical dial each is, om-emu does not know. On the camera's own Highlight & Shadow page
    main changes Sh (the left value, writes 978 + 3k) and sub Hi (the right one, 976 + 3k), "+" on sub lowering Hi.
    Test 1's Mix page already paired them the same way (main -> strength on the left, sub -> hue on the right, same
    directions), so the slots are unchanged; a swap (tried) would break that. The RGB page pairs the same way too
    (sub -> point, right; main -> offset, left). What "doesn't line up" for the owner is asked (cad).
  - **Video (owner, mix test 1's clip: "the video clip carried over the mix changes"; owner's choice "Photos only"):**
    so video jobs go through the development function 0x605196b4 / the caller 0x605196f6 (camera result), which is
    also where split toning and the RGB curves run (its stage list). mx_photo (ss_photo's test without its write:
    the mode code 1..5 / 53..57, else the switch byte 0xa32d9d0d = 2) now gates mx_go and st_run's curves (cv_set ->
    no curved channel); split toning is left as released (it very likely reaches video as well, since v0.26: not
    checked on the camera; owner's call). om-emu (pset:1909:2 = photo, the default is movie): photo -> mix and curves
    as model.py; movie -> mix stock, curves none, split toning alone identical to v0.29.5, split + curves = split only.
  - **Dial highlight (owner: "the dial symbols wernt being highlighted when the values were being adjusted"):** om-emu,
    the camera's own H&S page: the active values are white with their dial symbols above (Sh / Hi; the dial pictures
    10915 bottom arc, 10914 top arc, 36 x 24), the inactive one grey without a symbol (Mid); INFO swaps to Mid (white,
    the full dial picture above it), Sh / Hi grey. Nothing else lights up after a dial step (screens 5 ms .. 1.2 s
    after: only the value and the row cell, which turns to its "editing" look, change). Our pages keep the Sh / Hi
    mode (2191 read 886), so both symbols stay above Sat / Hue, white, and the row cell changes as the camera's. The
    camera's lists hold the dial pictures with palette 7 and 0x4c (a second colour), so a lit state may exist, but
    om-emu shows none on the camera's own page: not reproducible here. Not changed; a photo of the camera's own page
    and of ours while turning a dial is asked (cad).
- **Mix test 2 (package, emulator only):** Sat / Hue whole (smaller), the mix and RGB curves in photos only; dial
  pairing and everything else as test 1. 14 screens vs test 1: the same except the smaller labels. Save 10,062.
  ext11 60,528 / 65,536, ext12 260,480 / 262,144.
- **Mix test 2 camera (owner, 2026-11-15):** "The words look good but this is what I'm talking about. The middle
  number has a dial over it but that middle number never gets adjusted" (owner's photo, not kept: green chosen, so
  INFO was pressed once; the header showed the full dial over the middle "±0", none over Sat / Hue, all values white).
- **Why (om-emu, WATCH on cv_sv):** the camera's H&S panel keeps its own Sh / Hi <-> Mid mode and flips it at every
  INFO, whatever happens to its 2191 write (our refused writes ask 887, 886, 887, ... in turn); it starts in Sh / Hi
  when the row opens. om-emu always draws our header in the Sh / Hi mode (5 ms .. 1.2 s after INFO, from the H&S
  row's Mid mode, entering from below), so the camera's Mid drawing after an odd number of INFO presses was not
  reproducible here; the panel's flip is the difference that matches the photo.
- **Mix test 3:** on our pages (RGB and Mix) cv_ev hands INFO to the panel twice (calls pm_ev, then the usual jmp):
  it flips there and back, ends in the Sh / Hi mode with the dials over our two values; our colour steps once (as
  two quick presses for the camera). om-emu: each INFO on Mix / RGB -> 2191 asks 887 then 886; the page redraws in
  the new colour; the camera's own H&S row still flips once (Mid mode as stock); 14 screens identical to test 2.
- **The middle "±0" stays** (grey, no dial, as the camera's own unused middle value in the Sh / Hi mode): it is the
  camera's slot, drawn with the same "±" / digit pictures as Sat / Hue (picture 1131 "±" etc.; om-emu), so it cannot
  be blanked by picture without blanking ours; its value must stay in -7..+7 (our picture rides on its object).
- **Mix test 2 camera, the rest (owner, 2026-11-15):** words in full: good ("The words look good"). Video: "yes the
  video looked normal": **photos only works on the camera** (no mix and no curves in video; mx_photo camera-tested).
  The dial over the unused middle number: fixed in mix test 3 (above), not camera-tested yet.
- **Mix test 3 camera (owner, 2026-11-15):** the header still showed the dial only over the middle value ("Sat" /
  "Hue" red: likely no INFO pressed): "Ok now the dial icon is only over the middle value. It needs to be over the
  left and right values (sat and hue) and the middle number and icon should be hidden." So on the camera our page
  is drawn in the panel's Mid look even without INFO, which om-emu never shows; the double INFO did not help.
  Mix test 4: our own header (cad's plan): the camera's header pictures blanked on our pages, ours drawn.
- **Mix test 4 (emulator only): our own header on both pages.**
  - Hidden while our page is on (cv_ic -> clear): the camera's header labels (4207 / 4208 / 4331), its numbers
    (glyphs 1111..1119 and 1121..1129 digits, 1120 "-", 1131 "+-", 1132 "+", 10772 "0"; om-emu: the left column's
    numbers are other pictures and stay) and its dial symbols 10912..10919. The double INFO of test 3 is out.
  - Ours, in the top HD_BAND = 64 rows of our 300 x 300 picture (hd_pre / hd_row, ext11): over each of our values
    the symbol of the dial that changes it (left: the main dial's, right: the sub dial's; our own drawings, rgbpics
    hd_icon), under it the name in the chosen colour and the value (RGB "R +3" / "Pt 1"; Mix "Sat -2" / "Hue +5");
    nothing in the middle. Glyphs (rgbpics.hd_glyphs, 2 bits a pixel, 3,180 B) written by build.py into the image at
    the work area + 0x8000 (free since test 4 of the curves), sizes / offsets in hd_tab (hdtab.inc).
  - Our picture is now opaque (the camera's box colour 19), so the camera's grid no longer shows through: the RGB
    graph is drawn in rows 64..299 with our own quarter grid and diagonal (colour 20; HD_K 3761), the Mix ring smaller
    (radius 70 + 3 x strength, centre 150, 182).
  - om-emu: both pages show our header, values follow the dials (main +1 -> left +1, sub +1 -> right -1, as the
    camera's own page), INFO changes the colour; screens outside our pages identical to test 3. ext11 61,552 / 65,536,
    ext12 260,416 / 262,144.
- **Mix test 4 camera (owner, 2026-11-15):** "that looks so much worse, and it affected how the RGB grid looks. Can you
  not just have the old grid and turn the center dial and number black?" Our own header is dropped. Mix test 5: test
  2's code again (the camera's header, the old grid and circle; no double INFO), with only the middle dial symbol and
  the middle number hidden.
- **Mix test 5 (emulator only):** test 2's code (`git checkout 86b567b -- firmware/`: the camera's header, the old RGB
  grid and Mix circle, no double INFO) plus only this: on our pages the H&S header's middle (its dial symbol in the Mid
  look, "Mid", the number) is cleared. The middle number shares its pictures with ours, but the header's draw passes
  the spot's layout record: cv_ic, when its return is HS_HDRAW 0x610daa1f and a0 lies in HS_MID0 0x6146656c ..
  0x61466680 (om-emu: the middle's records in both of the panel's looks, e.g. the Mid look's dial 10912 at
  0x6146656c, "Mid" 0x61466580, its sign 0x61466594, its "0" 0x614665cc; the left value's records lie below, the
  right's from 0x61466680), returns a clear 50 x 34 picture (a 2 x 2 one left parts of the old number, om-emu). The
  other lookups (return 0x610eb160) are left alone. om-emu: the middle gone on the RGB and Mix pages, our values and
  their dials kept; the camera's own H&S row unchanged; 14 screens vs test 2 differ only at that spot.
- **Mix test 5 camera (owner, 2026-11-15; a 5 s video, not kept):** "Do you see how the dial changes but isn't
  actually needed for the circle? Likewise the text by sat and hue are greyed out." On the camera the header still
  flips with INFO between the panel's outer look (dials over Sat / Hue, values white, middle empty: what the owner
  wants) and its middle look (one dial in the middle, still drawn: test 5's clearing misses it there; Sat / Hue
  greyed). Wanted (test 6): always the outer look on our pages; INFO only changes our colour.
- **Mix test 6 (emulator only): the panel kept in its outer look.** om-emu, the H&S panel (= (4, the column) in the
  INFO path; 0x6247a800 in om-emu): its look is a two-entry selector at (124, panel) (count u16 at +92 = 2, current
  entry u16 at +94: 0 outer = 886, 1 middle = 887). Its INFO handler (0x61226702) sends the selector "up" (0x9004) and
  OK (0x900c), then writes the selector's value to (122, panel) (output only: never read; setting it did nothing) and
  2191. So cv_inf, on our rows only and just before INF_GO, puts the selector on entry 1 (when its count is 2): INFO's
  "up" always lands on entry 0, the outer look. om-emu: INFO on Mix / RGB asks 886 every time (before: 887 / 886 in
  turn), the page redraws in the new colour; the camera's own H&S row still flips (887 / 886, its Mid look). Test 5's
  middle clearing stays, plus the Mid look's full dial pictures 10912 / 10913 / 10919 cleared by id on our pages as a
  backstop. 14 screens identical to test 5.
- **Mix test 6 camera (owner, 2026-11-15): "thats perfect!!!!"** The header stays in the outer look on INFO (dials
  over Sat / Hue, values white, middle empty). Camera-tested: the selector set in cv_inf, the middle clearing. **Test 6
  (E1479999.BIN f85e7f86…, f4a053b) is the line for the RGB curves + colour mix.**

### Colour menu: order, cell pictures, titles, headers (test 7, 2026-11-15; camera-tested)
- Owner: "build the mockup that color menu design has done"; spec (owner-approved, private):
  color-menu-design/SPEC.md. Built on test 6 (e1ede86). Its section 4 (new RGB / Mix headers) was skipped at first,
  then built (owner: "i want the rewrite that I have approved in the menu redesign"): see "headers" below.
- **Order (pm_list):** 111, MX_IT, RG_IT, 5397, TB_IT, AB_IT, 5398, BK_IT, 8, 7, NR_IT, VF_IT, 5399, GL_IT, HL_IT,
  5400 (pages of five: the film and its colour in the camera's order, white balance and tone, detail / lens / light,
  Film Grain Effect alone). The camera allocates the row list to its count, so no size limit.
- **The left column's palette (om-emu, a 16 x 16 probe in a cell; the list shows the cell's x 9..90):** 0 clear, 7
  black, 10 / 13 white, 11 (170) / 12 (85) greys, more greys 43..46, 49..51, 56..60, 93, 97..100, 121, 124; orange 16 /
  34 (253,104,0), 17 / 35, 18 / 36, 55, 102; red 122; yellow 123; yellow-green 38 / 39; green 40 / 41 / 42 / 54; blue
  53; many entries a lime filler (the selection border's colour). No cyan, magenta or purple.
- **Cells (mkicons CUSTOM drawings, rgbpics):** Color wheel (82 x 62, "HSL"'s place) a 12-colour pie, yellow at 12
  o'clock clockwise, the missing hues two palette colours alternated (yellow-orange 123 / 34, magenta 122 / 53, purple
  and blue-cyan 2:1 of blue with red / green, cyan 53 / 40, green-cyan 41 / 53), white rim, dark edge; Split Tone
  Balance a dark-to-light bar (greys) in a white outline with a white triangle under it; Glow a white dot in a grey
  glow; Halation a white dot in an orange ring (34 / 55 / 17 / 18); B/W the plate's letters -> a black and an outlined
  white square (bw_top and the 0 / 0 cell); Mix a grey ring (97) with spokes to an orange (34, larger), a green and a
  blue dot; RGB the curve box (white) with an orange curve bowed up, a green straight one, a blue one bowed down.
  ic_pay +256 B (16,640; the pie's alternating pixels cost tokens).
- **Titles:** "Split Tone Balance", "WB Compensation", "Glow Effect", "Halation Effect". Film Grain Effect unchanged.
- om-emu: the 16 rows in the new order on 4 pages, each row's cell and page title as specified, every page opens
  (Mix / RGB / wheel / grids / sliders / choices); the screens outside Picture Mode identical to test 6. (The WB
  fine-tune screen's INFO gives om-emu an "event storm" in test 6 too: not new.) ext11 60,720 / 65,536, ext12 260,288 /
  262,144.
- **Headers (spec section 4, 2026-11-15; emulator only).** Mix: left "Sat ±0" (rear dial), middle the colour's name in
  its colour ("Red" / "Green" / "Blue"), right "Hue ±0" (front dial). RGB: left "Level ±0", middle the colour's name,
  right "Pt 2" (no sign). Test 6's behaviour kept: INFO stays in the outer look (cv_inf), the dial symbols over the two
  outer values, nothing greyed.
  - "Saturation" does not fit: the left label box is 38 px (pictures wider are cut, test 2); "Saturation" is 102 px at
    the labels' size, 67 px at the smallest readable one. "Sat" (34 px) is the closest that fits.
  - Pictures (rgbpics): 7 "Sat", 8 "Hue", 9 "Level" (cap 14, squeezed to 30 px), white; 10..12 the names, 50 px wide
    (the middle "Mid" label's box), cap 16 squeezed to 42 px; 15 a clear 14 x 30. The R / G / B letter labels (1..3)
    are no longer used by the header.
  - cv_ic: 4208 -> "Level" / "Sat", 4207 -> "Pt" / "Hue"; the middle's "Mid" record (0x61466580) and any other 4331
    lookup -> the name; the middle's other records stay clear.
  - **Two lookups per header picture (om-emu trace):** the header first looks a picture up with MDR HS_HDRAW
    (0x610daa1f, a0 = the record), then at once again for the same id with MDR 0x610eb160 (a0 = a draw object, the
    same for every record), and that second picture is the one drawn; the first one's size is the box it is drawn
    in. So for RGB's right sign ("±" record 0x614666a8, "+" 0x614666b8; glyphs 1131 / 1132, both 13 x 30 from the
    camera's table at (0x60379740) + 4 x id) the first lookup returns the clear 14 x 30 and sets cv_sgn, and the
    second lookup (cv_sgn set, RGB on) returns it too and clears cv_sgn. A 2 x 2 blank in the first lookup alone left a
    bit of the glyph; a red test picture showed the box lands exactly between "Pt" and the digit.
  - om-emu: Mix and RGB headers as above through value changes and INFO (Red -> Green -> Blue); the 16-row sheet and
    the screens outside Picture Mode identical to test 7's first build. ext11 60,752 / 65,536, ext12 260,736 / 262,144.
- **Camera (2026-11-15), test 7 with the headers (E1479999.BIN `cfd4992752c2…df85d`, commit 3ba1355):** owner: "that looks
  so good. like properly good." Camera-tested; the current line for RGB curves + colour mix + the colour menu.

## Films at start-up from the camera's memory: bp1 probe and L1 (2026-11-14; branch feature/early-load)
- Goal (crombach): the films and our Picture Mode rows ready without a half-press, and the shooting screen showing
  "FILM N" from its first frame. Until now it read "COLOR k*" until the first half-press. This goes against the
  owner's start-up rule in CLAUDE.md and needs the owner's OK before it ships.
- om-emu cannot time this. Its GUI does nothing until the script sends a key, and its GUI gets an event about every
  200 ms while idle, but the camera's GUI gets none until a key (k3).
- **bp1 probe** (camera-tested): until the first shutter event, the hooks that already run at start-up record the
  facade's SetValue calls (`sl_set`), the shooting screen's label picture asks (`fl_lvp`) and the GUI's state changes
  (`gx_map`), with the task. CADLOG.TXT writes the list at the end. Two camera logs, a plain start and Picture Mode
  opened first, give the same order:
  1. Task 167 (the camera's settings task) writes 15258, 15319 twice, 15313, 897 = 901 (the Creative Dial) and 2188.
  2. Task 170 (the GUI) changes state once (8, from 0x0201).
  3. The GUI asks for the label (15711 = "COLOR 2*" with COLOR 2 on FILM 10).
  4. Task 167 writes 897 twice more, before any key. This is still start-up.
- **L1:** at the GUI's first state change (`gx_map`, GUI task), `el_go` runs `sd_load` when every section is copied
  and the block in M is valid. Card access is blocked while it runs (`el_nc` in our `fopen`), so the built-in
  GUIDES / LABELS / TONES are used. `dm_ok` and `gx_map`'s first look (`cm_init`) wait for the first shutter event
  (`el_hold`), because the 897 writes of step 4 would otherwise run `dm_turn`, which caused b1's lag. No valid block:
  the first half-press loads as before. Code in ext12, the release call in `lg_pr`.
- **Emulator (L1):** with a block saved by an earlier session (`NV_FILE`), FILM 1 chosen, then a power-off: the
  shooting screen shows "FILM1" with no half-press (c11 / bp1: "COLOR 1*"), and Picture Mode opens with the films in.
- **Camera (crombach, L1 on c11 = #45 + #46, E1479999.BIN 39359b78…, GUIDES.BIN 2acd4eb2…): works.** "FILM 10"
  shows as soon as the shooting screen draws, and Picture Mode's profile settings are loaded before any half-press.
  Not reported yet: ten restarts for lag, the dial moved while off, shooting right after switch-on, no card.
- Known limit of L1: with a valid block in M it never reads a new `LOOKS.BIN` or `NAMES.BIN` from the card. `el_card`
  (below) fixes this.
- **Timing (camera, crombach, 2026-11-14):** builds T0 (EL_ON 0: films at the first half-press, as c11) and T1 (EL_ON
  1: L1) with microsecond stamps from the firmware's clock (0x60023c0d: 0x7fffffff minus the down-counter at
  0x98900284). Three plain starts each, times from power-on:

  | Run | GUI state 8 | Early load | First label | Label after state 8 |
  |---|---|---|---|---|
  | T0-1 | 1.111 s | none | 1.210 s | 99 ms |
  | T0-2 | 1.172 s | none | 1.251 s | 79 ms |
  | T0-3 | 1.159 s | none | 1.241 s | 82 ms |
  | T1-1 | 1.139 s | 46 ms | 1.230 s | 91 ms |
  | T1-2 | 1.156 s | 80 ms | 1.323 s | 166 ms |
  | T1-3 | 1.109 s | 96 ms | 1.287 s | 178 ms |

  The early load takes 46..96 ms on the GUI task and moves the first label by 0..100 ms (1.23..1.32 s against
  1.21..1.25 s). The camera's own writes before state 8 are the same in both. Task 167 keeps writing 897 during and
  after the load (T1-2: at 1.170 s and 1.263 s), which `el_hold` keeps from `dm_turn`. No lag felt (crombach).
- **What points into our film blocks** (emulator, RAM dumps in Picture Mode, after it and in the menu, with
  P = 0x62859f80; analysis of the hits):

  | Holder | Points at | Lasts |
  |---|---|---|
  | The camera's GUI (0x62c69b84, 0x62c69e44, 0x62c6a104) | The slot words at the start of the list block (P+TTAB) | The whole power-on. Stock code writes them (0x610fb505, 0x610fb526, 0x610da4d9, 0x610db093). |
  | Picture Mode's screen data (from 0x6268efa8) | The list cells' descriptors | Only while Picture Mode is open |
  | A heap record at 0x62421000, {0x660, LPTR, 1, 0x660, ...} | The films buffer (P+LPTR) | Not known |
  | 0x62421114 / 158 / 20c, 0x6285b984 | P+LVB, P+TORG | Not known; maybe the allocator's own records |

  So the list block must never be freed or moved. The list cells show only "FILM" and a number, so new films never
  need new cells. The films buffer stays until power-off after a swap, because of the record at 0x62421000.
- **el_card** (ext12, from `lg_pr` after `ub_try`): after an early load, once at the first half-press with a card
  mounted (`hl_ok`: ub_try's gate). `NAMES.BIN` goes into a scratch 1024-byte P through `nm_load` (it also writes
  P+TBUF, which holds the titles by then). Then its entries (NENT) and its four group pointers (NPTR) go into P, in
  that order. `LOOKS.BIN` is read through `ub_rd` and checked through `ub_kn`, both taken out of `ub_pfl`. Films the
  camera never had go into a new buffer, P+LPTR switches to it with one store, and `ub_put` writes the block. The
  camera's selection (P+LIDX) and edits stay as they are, as at a normal half-press with new films. The old buffer
  (3 KB) is kept.
- **Emulator (el_card, build EL2):** a first boot with films A writes the block. With films B on the card (one name
  changed, CRC fixed) the next boot shows films A from M before the half-press and films B after it, with "Films
  from: the card (films the camera never had)" and one block write. The boot after that loads films B from M.
  `NAMES.BIN` (a test file with bar pictures): P+NPTR is 0 before the half-press, and after it all four groups and
  the entries match the file. The shooting screen before the half-press is the same as L1's, pixel for pixel.
  L1 with the same steps keeps films A and loads no `NAMES.BIN`. Not camera-tested yet.
- The probe and EL_ON are gone (the timing tests are done).

### Early load on v0.29.5: each mode's own films at start-up (2026-11-15; emulator only)
- Rebased onto v0.29.5. Per-mode settings enter the group now at the first look (`rc_go`: `ss_pre`, `cm_go`,
  `ss_post`), after the first shutter event (`el_hold`). The films block holds the group of the last look, so with
  the dial turned while the camera was off the early load showed the last mode's films until the half-press (code).
- For a trusted set (the P group, or a custom mode with films of its own), entering it changes only RAM: the set's
  film changes (`ss_ed`), each COLOR's look and slot (`cm_load` -> `ss_lib`, no settings-manager call) and the set's
  rows (`ss_get`). The camera has already recalled the set's own 18 COLOR values. The first look's settings writes
  (901, `dm_rec`) and record writes stay at the first shutter event (code).
- **EL6:** `el_ok` (reads only: `cm_ld`, `ss_ld`, `cm_gnow`, the photo / movie / S&Q switch byte while `rc_in` is 0)
  picks the case. Photo in a trusted set: `sd_load`, then `el_pre` does the RAM half of that entry and sets `ss_cur`,
  so the first look finds the films and rows in place and keeps an edit made before it. Otherwise the block loads as it
  is when it already shows what the first look keeps (same group, or a group with no films of its own), and else not
  at all (video in another group with films of its own).
- Emulator (photo switch set with a scratch `pset` token, Assign through Shooting menu 1 > Custom Mode): P FILM 1,
  Assign C1, P FILM 6 (COLOR 2). Off in C1, dial to P, on: v0.29.5 "COLOR 2*" until the half-press, EL6 "FILM 6" at
  once. Off in P, dial to C1, on: v0.29.5 "COLOR 1*", EL6 "FILM 1" at once. After the half-press every screen matches
  v0.29.5 pixel for pixel. EL6's first look switched no films and set no picture mode (v0.29.5: 2 and 1). Film swap
  and `NAMES.BIN` tests as before. Not tested in the emulator: a row edit before the half-press.
- **EL6 camera (crombach, 2026-11-15, E1479999.BIN 1014a7de…):** start-up and the films tests worked. Two faults:
  (1) after a power-on in C1, a turn to P while off and a power-on showed a COLOR profile until the half-press, which
  then set "FILM 10*" (log: picture mode 54 before it, "picture modes set: 1" at the first look); (2) a film picked
  before the first half-press switched at the half-press to another film with a "*".
- (1): on the camera, P's picture mode is not back at that power-on (om-emu keeps it). Only the first look's
  SetValue(901) brings P's choice back, so before the half-press the label shows the camera's picture mode
  (camera log; om-emu does not show it).
- (2), EL8: the first look re-entered the group with its kept films and choice (`cm_load`), over the pick, while the
  camera already held the picked film's values. `dm_rec` also ignored the pick (`dm_pos` unknown until `dm_turn`, held
  by `el_hold`), so the next 897 write would have put the dial's old choice back. EL8: `el_go` notes the GUI task
  (`el_tid`) and the dial position (`dm_know`, reads only, taken out of `cm_load`); before the first shutter event
  `dm_rec` acts only for the GUI task and sets `el_pick`; with `el_pick` the first look keeps what is shown. Emulator:
  FILM 1 saved, FILM 6 picked before the half-press: EL6 "FILM 1*" after it, EL8 "FILM 6" (also after a restart). The
  custom-mode, film-swap and video runs match EL6, and every screen after the half-press matches v0.29.5.
- **EL8 camera (crombach, 2026-11-15, E1479999.BIN 65b88a59…):** start-up, the films tests (with new test files:
  the camera takes a film set only once, and EL6 had taken both old ones) and the dial tests with one picture mode
  worked. Fault: in P pick FILM 6 (COLOR 2) with no half-press after it, off, (C1 on and off,) on in P: FILM 6 until
  the half-press, then "FILM 1*" (log: picture mode 55 at the first event, "picture modes set: 1").
- Cause: a group keeps its films and choice only at a shutter event (`cm_hp` from `lg_pr`), so a pick with no
  shutter event after it is lost at power-off. v0.29.5 does the same (emulator: half-press, pick FILM 6, off, on in
  P, half-press: "FILM 1*"). The early load made it easy to hit (a pick before any half-press).
- **EL9:** every SetValue(901) sets `el_pk`. At the next GUI event (`gx_map`), after the first look and with no
  `rc_pend`, `cm_hp` runs as at a shutter event (its own checks: the last look was this group, not while `rc_go`
  runs, `cm_save` writes only on a change). A menu pick after the early load (`el_pick`) also ends `el_hold`, so the
  first look runs at the next GUI event instead of waiting for a shutter event. Emulator: the pick with no half-press
  (also with the half-press before it, and with C1 on and off between) gives "FILM 6" after the restart's half-press;
  C1 keeps its own film. The custom-mode and film-swap runs match EL8 pixel for pixel; more record writes (one per
  picture-mode change).
- **EL10** (25b2a12): `gx_map` checks `STATE` before the `el_go` call, and `dm_rec` ends `el_hold` where it notes a
  pick (not `gx_map` at each update). Emulator: every run matches EL9 pixel for pixel, logs included.
- **EL9 / EL10 camera (crombach, 2026-11-15; EL10 E1479999.BIN 56746c4f…):** EL9 passed the EL8 fault's steps. EL10
  passed the whole list: the pick with no half-press after it (FILM 7, and FILM 2 after a half-press), start-up, both
  dial turns while off (P and C1 on COLOR 1 films), a row edit in C1 before the half-press, picks of a film and of
  COLOR 4 before the first half-press, ten restarts, no card, video after video, photos and menus. A pick made in a
  custom mode on Reset is dropped at the next power-on, as in v0.29.5 (camera Custom Mode setting).
- **EL10 camera, dial turn while on:** boot in M, turn to C1 before any half-press: "FILM 4*" (P's early-loaded film on
  C1's COLOR 1) until the half-press, then C1's FILM 3 (log: films switched 2, picture modes set 1 at the first
  look). `el_hold` kept the 1440 step's `rc_go` back (`dm_ok`). v0.29.5 shows "COLOR 1*" there (no films yet).
- **EL11:** sx_set's 1440 ends `el_hold`. bp1 shows the camera writes no 1440 before the first shutter event, so a
  1440 then is a dial turn. Emulator (P FILM 1, Assign C1, P FILM 6; boot in M, dial to C1): EL10 "FILM 5*" before the
  half-press, EL11 "FILM 1" (C1's). Every other run matches EL10 pixel for pixel.
- **EL12 (code review):** `dm_rec` wrote the task id and d1 at (12) and (16) of its 28-byte frame, over the caller's
  saved registers (locals only in 4..11); frame now 36 at both calls. `gx_map` keeps a1 over `el_go`, as over `rc_go`
  and `cm_hp`. `el_card` clears `ub_cv` before `ub_rd`. `el_go` drops the `STATE` check `gx_map` now makes.
  Emulator: every run matches EL11 pixel for pixel, logs included. Open (analysis): `el_go` (GUI task) and the
  half-press load (HLS task) test and set `STATE` without a lock, so a half-press inside the early load's 46..96 ms
  could run `sd_load` twice. The GUI task's stack size is not known; `sd_load` has run on it in every camera boot.
- **Video freeze (camera, also v0.29.5 and EL8; issue #53):** photo session, off, boot in video, half-press: the live
  image freezes on one frame while the overlay updates. Switching to photo and back brings it back. Not caused by
  the early load. Cause not known yet.
  - Update: the trigger is a half-press within about a second of a video boot, after any session. A later half-press
    does not freeze (camera, v0.29.5 and EL13).
- **EL12 camera (crombach, 2026-11-15; E1479999.BIN 194dba88…):** the dial before the first half-press (M to C1, C1
  to P) and the picks (a film with no half-press after it, a COLOR profile) passed.
- **Dial turn while on (issue #54, also v0.29.5):** a live turn between M and C1 runs the switch at the in-between code
  (0xC0 plus the raw dial, such as `C7`), before the real mode code. Afterwards M's COLOR 1..4 and C1's COLOR 1 show
  "*" with changed values. Not caused by the early load.
- **EL13 (3f869bc, code review):** `st_claim` sets `STATE` from 0 to 0xffff under LOCK, and both `pr_go` and `el_go`
  load through it. `el_card` zeroes the `NENT` scratch before `nm_load`. Emulator: every run matches EL12. Camera:
  restarts passed. A half-press in the first second can win the claim, and the label then shows "COLOR k*" until the
  films load, as in v0.29.5.
- **EL14 (edc2c3b):** EL13 with the video freeze fix merged in (VF2, below). Emulator: every run matches EL13, except
  that a video boot's CADLOG shows no first look and no record write. **Camera (crombach, 2026-11-15, E1479999.BIN
  7c125da1…):** no freeze in 3 video boots with an early half-press at P, 3 at C1, and a late half-press (films put
  back 0, camera settings written 0). Photo after video at P and at C1, five restarts with dial turns while off, and
  a half-press at once after switch-on all show the mode's film at once, with no lag or freeze.

## Video freeze at the first half-press in video (#53, 2026-11-15; camera-tested)
- **Fault (v0.29.5):** in video, a half-press soon after turn-on freezes the live image while the overlay updates.
  The logs that froze show films put back at that half-press (3 films and 6 camera settings in the #53 report). A
  late half-press puts back none and does not freeze.
- **Fix (VF1, 1ab6af9):** in video and S&Q, `ss_post` leaves nothing for `rc_put` to put back. Films apply to photos
  only. `ss_mvp` is gone.
- **VF2 (code review):** VF1 left `cm_go` running in video (with the dial on C1..C5, `cm_load` writes through `fl_sw`
  and 901) and a Recall in video still put films back. `rc_go` now does no film work while `ss_photo` is 0, and the
  video branches of `ss_pre` and `ss_post` and `ss_phv` are gone. A dial turn or a Recall made in video is done at the
  next photo look. Emulator: every run matches v0.29.5, except that a video boot's CADLOG shows the custom-mode and
  per-mode records as not read (nothing in video reads them).
- **Emulator:** every custom-mode and video run matches v0.29.5 pixel for pixel. om-emu's video boot puts back no
  films on either build, so only the camera shows the fault.
- **Camera (crombach, VF1 E1479999.BIN 3398e72e…):** no freeze in 5 video boots with an
  early half-press, a late half-press, or video after a photo session (films put back 0). Photo after video and a
  photo to video to photo switch while on keep FILM 8, with photos in its look.
- **Camera (crombach, VF2 E1479999.BIN a121ee78…):** no freeze in 3 video boots with an early half-press at P, 3 at
  C1, and a Recall of C1 in video (films put back 0, camera settings written 0). Photo after video shows P's film at
  P and C1's film at C1. A video boot at P, a dial turn to C1, then photo and a half-press shows C1's film (FILM 3).

## v0.30 test 8: issue #54 fixed on the merged build (2026-11-15; camera-tested)
- **Test 8a camera-tested (owner, 2026-11-15):** 6fd2988 (colour menu test 7 + PR #55 + PR #56's early load + PR #57)
  with only a build-name commit (`try/v0.30-8a`, "v0.30-dev (test 8a: early load)", E1479999.BIN 8ace7752…4245).
  Owner: "This looks good and works well." CADLOG clean (10 shutter events, saves 1, card files match; copy kept
  privately). So #56's early load with #55, #57 and the RGB curves / colour mix / colour menu is camera-tested. PRs #56
  and #57 were merged on GitHub as written (heads fcfdb7e and e543f12, the same commits as here). Test 8 below adds only
  the #54 fix, the suite adapted to this build, and notes.
- **Build:** `try/v0.30` = colour menu test 7 (da8abbc) + main (PR #55, #53's video fix) + PR #56 (early load) + PR #57
  (tests) + the #54 fix (770f40d) + the tests adapted (d9e797b). Build name "v0.30-dev (test 8: #54 fix, early load)".
- **#54, cause (analysis from crombach's CADLOG + emulator simulation):** the camera writes 1440 only at mode-dial turns
  (bp1), and a live turn closes twice: first with the settings object's code (+24) 0 at the new dial position, then
  with the mode's code (C7 then 53, C9 then 4; at M -> C1 the first close can be at B, C8, which changes no group).
  sx_set's 1440 ran rc_go at both. At the first, cm_gnow took the group from the dial position and cm_load switched
  the films and wrote the picture mode (901) while the camera still had the old mode's settings in: M's picture mode
  became C1's (log: "54 = COLOR 1" in M, which was on COLOR 2) and C1's camera values no longer matched its own.
  ss_photo shows the first close's code was 0 (codes 6..52 and 58.. read "not photo" and stop rc_go before cm_go).
- **Fix:** sx_set's 1440 calls `rc_turn`, which leaves a close at code 0 alone (counted: CADLOG "dial-turn closes at
  code 0 left alone (#54): N") and runs rc_go at the close with the mode's code. The first look after a power-on
  (code 0 too) is not a 1440 close, so gx_map's first look keeps the dial-position fallback (k5). ext12 +128 B
  (261,568 / 262,144).
- **Emulator:** om-emu closes a turn once, with the code, so the suite cannot show #54. `research/emulator/issue54_sim.py`
  builds a simulation copy whose 897 write (the start of a dial change) runs the dial-turn code at code 0 first:
  6fd2988 "BUG" (M ends on 54 = COLOR 1, FILM 5, C1's film; switch logged at C7; 22 camera values differ from C1's
  own), 770f40d "ok" (M on 55 = COLOR 2, FILM 6; none differ; 2 closes left alone). Without the simulation the fixed
  build behaves as before (M -> C1 -> M: switched 2 + 2, M back on its film).
- **Suite (PR #57) on test 8:** 13 / 13 pass. Adapted for this build (d9e797b): hook sections read from the included
  `.inc` files; hooks.json takes the RGB curves / colour mix hooks (hook_inf: INFO in Picture Mode; hook_rsi: held-OK
  reset; hook_mx: the colour matrix, gated by cv_ok, so it does nothing before our data loads) and patch sites
  (curve-layer palette 29 / 30, the RGB and Mix rows' switch-table entries, cm_rst's word); the video test sets the
  movie switch (om-emu 0819080 reads an unset switch as photo; main + #55 failed the test that way too) and checks
  "films switched: 0, record writes: 0" (with #56, el_ok reads the dial position in video, so group / code show it);
  `--without` v0.29.5: caught. KNOWN_FAILURES emptied (the no-half-press pick passes with #56).
- **Early load + RGB curves / mix (emulator):** Mix Sat +2 / Hue -1 and RGB Level +1 set and half-pressed in boot 1;
  boot 2 shows them (with their '*') before any half-press and after it. The 16 rows and the RGB / Mix pages match
  test 7 pixel for pixel, except FILM 15's Color wheel "Vivid" and H&S values on an old om-emu settings file
  (nv0.json): test 8a (no #54 fix) shows the same, so it comes with #56's early load trusting the camera's own values
  of that old file; the blank-camera tests pass.
- **Test 8 camera-tested (owner, 2026-11-15; E1479999.BIN 5768c9e1…7d7d, built from b9eba89):** "that seemed to work",
  the #54 round trips (M <-> C1 while on) included. The CADLOG kept (copy kept privately) covers only a later power-on
  (2 shutter events, no dial turns, the #54 counter 0, saves 1, card files match), so the round trips are the owner's
  word, not the log. Test 8 is the v0.30 candidate.

## v0.30 test 9: CURVES.BIN, each film's built-in curves and mix (2026-11-15; emulator only)
- **Owner's choice "New card file"** (how people updating to v0.30 get LookLab's 20 films regraded with curves + mix,
  `webapp/scripts/films.py` CURVES_MIX): LOOKS.BIN has no room and the camera takes only a film set it never had, so a
  file of its own. Format: `docs/FORMATS.md` "CURVES.BIN v1" (432 B, 'OM3K'); `card/mkcurves.py` writes it; sent to the
  LookLab session for its export. Each entry carries the CRC-32 of the LOOKS record it was made for (as EDITS records).
- **Firmware (`firmware/src/curvesfile.inc`, ext11; 63,872 / 65,536, ext12 261,488 / 262,144):**
  - At the films' load (the early load or the first half-press), `ck_load` reads M only: the file's copy at M + 0x3BE20
    (between 'OM3R', which ends at +0x3BE14, and +0x3C000, which film-rolls / screen-info use), when valid, gives
    `ck_bi` (each film's 18 curve values and 6 mix values; zero when the entry's check does not match the film's
    record). The check is about 1.7 KB of CRC-32, inside #56's early load.
  - `ck_card` from lg_pr, at the first shutter event with the films in and a card, after el_card (new films first):
    C:\OM3MOD\CURVES.BIN, taken when valid and not the copy in M. The write to M works as ub_wr: under LOCK, only
    while the camera is not saving M, then the changed byte; else pending, retried at the next shutter event.
  - A slot's byte 24 (the 'OM3R' slot's kept byte 6) holds flags: bit 0 the curves follow the film's built-in, bit 1
    the mix, bit 7 set. Slots from test 8 or older have 0, and their all-zero parts follow. `ck_fix` fills following
    parts whenever a slot becomes COLOR k's: cv_rec -> `ck_rec` (an EDITS record r < 20 = film r, a LOOKS record = the
    film as built), cv_sget, the load, a new file.
  - An edit on the RGB / Mix page (cv_ev, mx_ev -> `ck_own`) makes that part the user's. The rows' reset (cv_zk /
    mx_zk -> `ck_zp`) makes it follow again.
  - The '*'s compare with the built-in (cv_kset / cv_jset -> `ck_kset` / `ck_jset`, cv_star / mx_star -> `ck_star`).
  - With no valid file in M (`ck_have` 0) none of it runs. 16 Picture Mode rows on the old om-emu settings file:
    identical to test 8 pixel for pixel.
  - A calling-convention slip found in om-emu: `ck_bik` first had frame 0 and called `ck_p`, whose return address
    overwrote its own (an endless loop at the first half-press). Frame 4 since (research/NOTES.md "Picture-mode
    sliders": a call writes its return address at (0,sp)).
- **Emulator:**
  - FILM 2 with fixture values: Mix "Sat +2 / Hue +1", RGB "Level +1", no '*' on the film or the rows.
  - Reset on the RGB row: back to Level +1. One dial turn: '*' on the row and the film, kept over the half-press.
  - Suite tests `curves-file-kept-in-camera`, `-new-values-follow-edits-stay`, `-none-or-not-valid` pass; on test 8
    (`--without`) caught.
  - `static:changed-bytes`: the same sites as test 8 (0x6061a468, a pointer into ext12, and the cm_rst word), their
    targets moved; hooks.json updated after that review.
- **Sample for test 9:** LookLab's camera 20 (om3films.json rgb + mix, recipes otherwise unchanged from main) against
  releases/v0.29.5/LOOKS.BIN: sha256 4c009f9c…2291 (20 matched in om-emu).
- **LookLab's export (LookLab session, 2026-11-15):** `webapp/src/curvesbin.ts` writes OM3MOD/CURVES.BIN with LOOKS.BIN
  (Save to the SD card, the card zip, and a button of its own, for firmware "v0.28 or later"); for the standard 20 its
  bytes equal the sample (4c009f9c…2291). Branch feature/looklab-rgb-curves 0cfcfc7 (local).

## Debug log dl8: the report redone (2026-11-15; emulator only, camera test pending)
Branch `feature/debug-log` (from main v0.29.5, c209b69), VERSION "v0.29.6-dev (debug log, dl8)". Owner (via cad): a
clearer, complete `CADLOG.TXT` (lines had been added piecemeal, some as hex words and internal codes).
- **Layout:** one writer, `lg_write` -> `lg_top` (build, START-UP, card files), `lg_now` (NOW), `lg_svt` (SAVES),
  `cm_txt` (CUSTOM MODES, rewritten), `lg_evt` (the last 32 events, **newest first**); `ub_txt` / `ss_txt` and their
  strings are gone. Still a fixed 5120 B (same fopen / fwrite / fclose, same bytes on the card). Newest first, so a full
  report loses the oldest events; the fullest emulator case (all custom modes filled, 8 mode changes) is 4827 B with all
  32 events.
- **New facts, all read only:** the shooting mode now and per event (`lg_mode`: the code at rc_in + 24, the mode dial's
  position 0xa32d9d0c, the photo / movie / S&Q switch 0xa32d9d0d; not cm_gnow, which writes cm_code); a custom mode's
  Save Settings (sget 1880 + n); the film on each COLOR with its name (LOOKS +1312 + 16 j); the films with changes; each
  group's films, choice and own copy (OM3C / OM3S); saves at shutter events (`lg_ns`); cm_pend, ss_dirty, rc_pend;
  rc_tr and ss_ml decoded. Ring entry +12 is now u16 family, +14 the code, +15 dial position | switch << 4. Nothing of
  the old report dropped (picture mode numbers 54 / 55 / 56 / 64 now read as COLOR 1..4).
- **Mode codes (om-emu):** P 1, A 2, S 3, M 4, **B 62** (cm_gnow then goes by the dial position: P group, as intended),
  C1..C5 53..57, video and S&Q 10. Camera logs so far showed P, A, C1..C5 and a 62 (k4); S / M / B emulator only.
- **Films with changes:** the same answer as fl_fch (the camera's '*'), but fl_live (a film on its COLOR: the camera's
  18 values through sget) costs up to ~16k instructions when nothing differs. `lg_chg` asks one COLOR per write
  (lg_w & 3) and keeps the others' last answer for the same film (at most 3 events old; a film newly on a COLOR is asked
  at once); a film not on its COLOR uses `lg_fc` (fl_fch's saved-record test, by words).
- **Cost** (om-emu instructions from lg_write to its ret, same scripts, v0.29.5 -> dl8): P with an edit, Assign C1 and
  dial turns, 43 events: average 210,800 -> 194,700, longest 223,711 -> 204,184; video / S&Q, 11 events: 194,159 ->
  189,218, longest 199,322 -> 204,845 (one write +7.7k: the live check with nothing changed); power-on in C1: 191,774 ->
  185,569; no films: 190,543 -> 180,834. First write of a power-on (with the card-file check): ~568.9k -> ~566k. The
  card part (fopen, fwrite of 5120 B, fclose, ~92.5k) is unchanged. lg_d by divu, the padding by words.
- **Settings manager calls** over the whole P run: 153, identical in ids, values and order on v0.29.5 and dl8: no
  settings writes, nothing different before the first half-press.
- **Bug found on the way** (a throwaway 1 KB-buffer build): past the buffer's end the first lg_s still wrote one
  character per call, so a long enough report crept over lg_pon / lg_plog and the next fopen failed (no log). lg_s now
  writes nothing once at lg_bend; the pad after it is 256 B (the longest string is 117 B). That variant writes 1024 B
  ending in CR LF at every event. (v0.29.5's lg_s checked every character: no such bug there.)
- Stack: lg_now -> lg_chg -> fl_live -> fl_isdef -> sget runs ~96 B deeper in the HLS_EVENT task than v0.29.5's
  deepest log path. Only the camera can say if that matters (no sign in om-emu).
- Emulator cases (scripts: video-sharp's s41v.mjs): P, a power-on in C1, video / S&Q, no films (stock NV, no
  LOOKS.BIN), settings block missing (STATE poked 0xFFFF), every custom mode filled (cm_ram / ss_ram poked, emulator
  only). All read right; the "missing" case prints the card files with "not checked" and skips NOW's film lines.

### Debug log dl9: the camera's own state too (2026-11-15; camera-tested)
Owner (via cad): "I want it to cover everything the camera does!" Read only (sget), never a settings write; no slower
half-press, nothing at start-up. VERSION "v0.29.6-dev (debug log, dl9)"; report 8192 B (was 5120).
- **Setting ids found (om-emu, E147):** the quick panel (OK in shooting) writes the highlighted item's own setting id
  into **261** as its cursor moves, so walking it maps every cell: mode **24** (P 3, A 4, S 5), shutter **1699** and
  aperture **1697** as set (APEX x 256), ISO **6** (0 Auto, else Sv x 256, ISO 100 = 1280), AF target **85**, exp comp
  **2** (EV x 256), item **1714** (the "±0.0" with the curve icon; meaning not checked), picture mode **111**, WB **9**,
  item 1414 (the cog), AF mode **289**, face / eye **1712**, flash **16**, flash comp **17**, drive **3265**, metering
  **1**, aspect **269**, stabiliser **157**, image quality **861**, video quality **2236**. The exposure the AE worked
  out: **4000** shutter, **4001** aperture (APEX x 256; 0 before the first metering), 4002 = their sum. WB mode
  **1578** / movie **1579** and Custom WB **107** as in "Film WB". The debugger's getter call times out for 134 ids
  (111, 901, 1578, 9, 289, 16, 3265, 1, 157, 861, 2236 among them) but the firmware's own sget reads them all.
  Getter cost (firmware): ~300..900 instructions, but 111 ~2.5k, 289 ~2.2k, 861 ~1.9k, 107 ~1.3k.
- **Screen:** the GUI state is the u16 at **0x62ce5864** (child << 8 | parent; the firmware loads that address as a
  constant at 0x610fcf81 and keeps it in 0x603713a4, so it is the camera's too): parents 1 COMMON (child 8 = the
  shooting screen), 2 REC (direct setting), 3 / 11 menus, 4 MENU_LV (3 / 4 the quick panel, 0x16 quality, 0x17 WB,
  0x18 Picture Mode), 5..7 playback, 12 edit.
- **Buttons / dials** (research/BUTTONS.md): photo Fn 47, REC 48, |o| 1292, CP 49, AF-ON 1964, ✥ mode 158, up 50,
  left 52, right 53, down 51, Delete 570, L-Fn 56; video 1272, 1273, 1278, 1274, 1965, 1279, 1280, 1282, 1283, 1281,
  1276, 1291; our Creative Dial rows 571 / 54 / 55 / 1966; dials P / A / S / M at Fn lever position 1 and 2 (70..77,
  1302..1309); the Fn lever's state 534 (om-emu 4; 8 = position 2). As dial function codes 1697 = shutter and 1699 =
  aperture (the opposite of the setting ids), 86 Ps, 2 exp comp, 17 flash comp, 1701 WB, 1578 ISO.
- **Not found / not read:** battery level, card free space and shots left (the panel's "803" is not a setting id), the
  Fn lever's function setting (Off / mode 1 / mode 2), names for drive / AF mode / quality / metering / flash /
  stabiliser codes (shown as numbers), photo counts in om-emu (it takes no photo: `s2` and `hold:s2` change nothing).
  Menu visits: only the screen at each event; a full menu history would need a counter in gx_map (not done).
- **Photos:** `lg_np`, one increment in ex_fill (our EXIF hook, once per photo's EXIF; our RAM only). Not testable in
  om-emu; whether RAW-only photos reach ex_fill is not known.
- **Cost kept down:** per event 5 reads (4000, 4001, 6, 2, 1578 / 1579; 107 only for Custom WB) and one of drive / AF
  mode / quality in turn (lg_fv); 4 of 63 other settings per event in turn (lg_cid -> lg_cv, -1 = "-" until read,
  each at most 16 events old; BUTTONS AND DIALS shown after the first full round); each event's line made once
  (lg_line -> lg_lines in ext11, LSLOT 100 B) and copied by words; START-UP, CUSTOM MODES and BUTTONS AND DIALS kept
  as text and copied while their inputs (a key of words) are the same; the padding only over the last report's text.
- **Cost** (om-emu instructions per write, v0.29.5 -> dl9): P run (edit, Assign, dial turns, 43 events) average
  210,800 -> 194,100, longest 223,711 -> 203,663 (7 early writes up to +6.8k, when the custom-mode text changes);
  video / S&Q (11 events) 194,159 -> 195,409, longest 199,322 -> 204,150; power-on in C1 (7) 191,774 -> 193,689;
  no films (7) 190,543 -> 188,801; first write 568.9k -> ~588k. fopen ~48k and the write (~92.5k, the same for 8192 B
  as for 5120 B in om-emu) unchanged. Settings manager calls over the P run: 153, identical to v0.29.5.
- Space: ext12 259,280 of 262,144 (2.8 KB left), ext11 62,240 of 65,536 (3.2 KB left: the 32 lines, the kept texts
  and keys).
- Cases (om-emu): P, a power-on in C1, video / S&Q, no films, settings block missing, every custom mode filled (8,106 B
  with all 32 events), a 1 KB-buffer variant (1024 B with CR LF at every event).
- **Camera test (owner, 2026-11-15): passed.** Owner: half-presses "felt normal" (as quick as v0.29.5, no freeze).
  The report (69 events, one power-on, A and S) read right against what was done: 20 photos counted = 20 RAW + JPG
  pairs on the card (so ex_fill runs once per photo with RAW + JPG; RAW-only still not checked); aperture f/1.8 ->
  f/22, S at 1/100, exp comp -1.3, WB Auto -> Cloudy -> Auto, FILM 1 -> FILM 4, screens menu / camera (settings) /
  panel, the arrow pad's Direct Function, C2 assigned; "Look at: nothing unusual"; card files all match. Drive read
  32 -> 30 (codes not named). Not in that power-on's report: P, M, a custom mode, video.
- **Second camera run (owner, same day): passed.** One power-on, 26 events: P (f/2.0 -> f/1.8, the "set" screen), M
  (1/2 f/11 as set), C1 (code 53; the camera's own C1 drive 0 and quality 15 read), a fast dial turn M -> S -> A, then
  A video (code 10, the switch at 1), one clip recorded. Photos 3 = the 3 RAW + JPG pairs of that power-on on the card.
  Drive at #18 (A) still showed C1's 0: the rotating read (lg_fv) is up to 2 events old, as designed; right at #19.
  "Look at: nothing unusual". The camera's clock runs about an hour ahead of the Mac's (file times), not ours.

## v0.30 test 10: test 9 + debug log dl9 (2026-11-15; emulator only, camera test pending)
Owner: "merge dl9 in for one more test". Branch `try/v0.30-dl9` = try/v0.30 (test 9, 26a65d3) + `feature/debug-log`
(dl9, camera-tested twice on v0.29.5). VERSION "v0.30-dev (test 10: test 9 + debug log dl9)".
- **Merge:** conflicts in VERSION, README, NOTES and editor.s (test 9's lines in the old cm_txt). dl9's report taken;
  `rc_nmid` (#54) kept with its counting in rc_turn. The old cm_txt's extra lines now sit in dl9's report: the #54
  count in CUSTOM MODES ("dial-turn closes at code 0 left alone (#54)", also in the section's key); ss_txt's per-mode
  lines were already there. test 9's `ck_txt` (CURVES.BIN) is replaced and removed from curvesfile.inc: START-UP has
  its file line (in camera memory, this power-on's card, films it matches; ck_have / ck_st / ck_nm in START-UP's key),
  SAVES its writes and held-back write (ck_nw / ck_pend), NOW one word per COLOR from the same comparisons as ck_txt
  (ck_bik, cv_lk, ck_cmp, ck_nz: "none", "none (its film has some)", "its film's", "changed") and the picture mode's
  COLOR's 15 curve values (R, G, B x 5 points, the slot bytes of ck_map), 6 mix values and its follow flags (lg_ckn).
- **Space:** test 9 had ext11 63,872 / 65,536 and ext12 261,488 / 262,144; with dl9 both overflowed (by ~6.5 KB and
  ~13.4 KB). The whole debug log (code, data, the 32 stored lines, the kept texts, the report buffer) is now `.ext13`
  at 0x60fac000, right after the RGB work area (0x60fa3000 + 0x9000), in the GX4-proven reserve (to 0x6103f000):
  editor.ld `.ext13`, build.py EXT13 (0x60fac000..0x60fbc000; written with ext11 / ext12, checked free, the loader's end
  word raised to its end rounded to 4 KiB: **0x60fac000 -> 0x60fb5000**, so the camera's own boot copy takes 36 KB
  more). Sizes: ext11 63,312, ext12 249,568, ext13 36,080. The report is **9216 B** (dl9 8192: the CURVES.BIN, curves
  and #54 lines made the fullest case drop 4 events; 8,494 B with all 32 now).
- **Tests (PR #57's suite, om-emu-new):** its log patterns follow dl9's wording now (emu_test.py: FILM_2_LINE,
  C1_* / P_FILM_LINE, GROUP_C1_LINE, VIDEO_BOOT_LINES, boot-smoke, films-from-camera-memory; ck_line gives the START-UP
  line and NOW's words from the same masks). `hooks.json`: one patch site's run moved (0x6061a469:2 -> 0x6061a468:3,
  the ▼ / ▶ validator list pointer build.py writes: its target in ext12 moved when the log left).
- **Write cost** (om-emu instructions per write, the P run: edit, Assign C1, dial turns; test 9 -> test 10): average
  214,582 -> 199,431, longest 226,291 -> 219,705; 7 early writes higher (the most +18.9k, the live film check after the
  menu Assign, as in dl9); first write 573.6k -> 597.0k (+4%).
- **Plus the Mix / RGB page headers** (R, G, B; try/v0.30 7a92cd3, merged as 1f705bf; ext12 248,944). Package
  `test-builds/2026-11-15-v030-test10`: E1479999.BIN **6c8e8b25…598e**, CURVES.BIN 4c009f9c…2291 (test 9's), go-back
  v0.29.5 01ea3d14…bd59. Suite (om-emu-new) on that build: **16 of 16 pass** (static checks with hooks.json as it is).

## v0.30 test 11: the header's R / G / B centred (2026-11-15; camera-tested)
- Owner after test 10 (camera, 6c8e8b25…, log clean): "can we please please please!!!! center the r,g,b on the
  curves and color mix. its off center".
- om-emu: the middle label's box (the "Mid" layout record, 0x61466580) is x 655..704 on the Mix and RGB pages; the
  page's middle is x 693.5 (the panel 542..845; also the midpoint of the left and right values). The letter was
  centred in its box, at x 679.5: 14 px left (the words "Red" / "Green" / "Blue" of test 7 hid it). The box is the
  layout record's, the same code on the camera.
- rgbpics `name_label`: the letter centred at the box's column 38.5 (MID_CX), ink inside the box (cols 29..48 of 50).
  om-emu: R / G / B at x 693..693.5 on both pages; the 16 Picture Mode rows otherwise identical to test 10.
- Test 11 = test 10 + this (333523c): E1479999.BIN 0f690519…4951, `test-builds/2026-11-15-v030-test11/`; suite 16 / 16.
- **Camera (owner, 2026-11-15; E1479999.BIN 0f690519…4951):** "It looks amazing". CADLOG clean ("Look at: nothing
  unusual"; CURVES.BIN the same, 20 films match; saves 1; copy kept privately). Test 11 is the v0.30 candidate.
## Live dial turn between M and a custom mode (#54, 2026-11-15; emulator only)
- **Fault (camera, v0.29.5 and later):** a dial turn with the camera on runs the custom-mode switch at an in-between
  code, `0xC0` plus the raw dial (such as `C7` at C1), before the camera's real mode code (53). The camera still holds
  the old mode's settings then, so the switch's film and picture-mode writes (`fl_sw`, 901) land in the old mode's set.
  M's COLOR 1..4 then show "*", and the turn back writes M's films into C1's set (C1's COLOR 1 "*").
- **Cause (code):** `cm_gnow` falls back to the mode dial whenever the code at `(24, rc_in)` is not 1..5 or 53..57.
  That fallback is meant for the first look after a power-on, where the code still reads 0.
- **Fix (DS1):** after the first look (`cm_init`), `rc_go` does no film work while `cm_gnow` takes the fallback
  (`cm_code` 0xC0 or more). It sets `rc_pend`, so `gx_map` runs it again at each GUI event until the real code arrives.
- **Emulator:** om-emu reports the real code at once, so the test `live-dial-turn-waits-for-the-mode-code` pokes the
  in-between state (code 0, dial on C1, `rc_pend` 1) after the first look in M, then turns the dial to C1. EL14:
  switch at `C7` (`8200C702`) and 22 changed COLOR values in C1. DS1: one switch, at code 53 (`82003502`), and 0
  changed values.
- **DS1 camera (crombach, 2026-11-15, E1479999.BIN 8fd0bf4a…):** the switch ran at the real codes only (`81003502` to
  C1, `00050404` back to M) and no COLOR showed "*", after C1 was assigned again. A COLOR reset made inside C1 on
  Reset does not last, so earlier damage to C1's saved settings kept its "*" until the new Assign. Fault: back in M,
  the camera showed COLOR 1 (picture mode 54) instead of M's own choice.
- **DS2:** the 901 hook notes the picture mode as the group's choice only when `cm_gnow` is the last look's group.
  During a live turn the camera sets a picture mode of its own before `rc_go` looks at the new mode (the 901 hook's
  comment). With the switch now waiting for the code, DS1 noted that one as M's choice and `cm_save` kept it at the
  switch. om-emu's camera sets no picture mode at a turn, so the emulator does not show this (analysis, from the log).
- **DS3 (the "COLOR1*" flash):** on the camera, a live turn from C1 back to M briefly showed "COLOR1*", then M's film.
  The camera sets M's picture mode at the turn and the label draws it from C1's films, still loaded while the switch
  waits. Now `lv_hold` is set while `rc_go` waits, and also by the 901 hook when the camera writes first while the
  switch waits or the code is not yet a mode (photo only). While it is set, `fl_lvp` answers `lv_slot`, a 96 x 44
  picture with no ink. `rc_go` clears it on every other way out (`lv_end`), and a power-off clears it with the rest of
  RAM. Why no slot of 0: the label's setter (0x6128ac0a) skips a 0 slot and keeps the picture it holds, so the old
  label would stay. The label redraws only when the shooting screen's record, data item 38 (464 B), is written. The
  camera writes it (0x6122fb93, about every 240 ms in om-emu) only when its contents differ (0x61230448), so a
  same-value 901 write does not redraw it. `lv_end` writes the record back unchanged (`ds_put`, as the camera's own
  write), which marks it changed. Emulator: a turn that ends on the same mode, with no 901 write, now asks the label
  again at once, and a poked hold blanks the label until it clears. Test `live-dial-turn-holds-the-label`. The flash
  itself is camera only.
- **DS3 on the camera:** "COLOR1*" still flashed on a turn from C1 back to M. The DS3d log of the label's events
  shows why. The camera changed the picture mode with no 901 write, so `lv_due` never ran. `rc_go` ran during the
  turn and left by its video path, because `ss_photo` reads the in-between mode code as not photo. So nothing set the
  hold, and `fl_lvp` drew the stock "COLOR1*" (id 15710) at code `C7`. The switch then came at code `04` and the
  label showed M's film. Log: `0080C701 82050402` for the switches, and the label events `4C720000 6C723D5E` for the
  video exit and the stock draw.
- **DS4:** `fl_lvp` now asks `lv_chk`, which also answers no picture on a photo look after the first, with the films
  in and the photo switch on photo (`UI_PSW` 2), while the dial's mode (`cm_gnow`) is not the group the films are in
  (`CM_LAST`). It sets `lv_hold`, so the switch's `lv_end` redraws the label. `cm_go` sets `CM_LAST` at each switch,
  so the hold ends there. The emulator draws no label in that state, so this part is camera only.
- **DS4 on the camera:** the C1 to M flash is gone. A live turn from C1 to B gave COLOR 4 a "*", and it stayed after
  the turn back to C1. B has no mode code of 1..5: the camera reads 0 at B (DS4 CADLOG: a power-on in B, photo check
  194, dial 8), and om-emu reads 62. So the wait for a real code never ended at B, no switch came, and C1's films
  stayed on under B's own camera settings. `ss_photo` also read om-emu's 62 as video.
- **DS5:** `cm_gnow` counts code 62, or code 0 with the dial on B, as B's own code (group 5), and `ss_photo` counts 62
  as photo. Test `live-dial-turn-to-b-switches-the-films` fails on DS4 and passes on DS5.

## v0.30 test 12: test 11 + PR #59, the #54 fix (2026-11-15; emulator only, camera test pending)
Owner: "Build test 12 please" (after cad's read of crombach's PR #59). `try/v0.30-dl9` = test 11 (fab2e95) + pr-59
(1039565, with main's #58) merged as written (ca4604f), then our own #54 fix taken out (5476eb7): sx_set's 1440 calls
rc_go again, rc_turn / rc_nmid and its CADLOG line go (the word in CUSTOM MODES' key stays, 0). Why ours goes: rc_turn
left every close at code 0 alone, and on the camera B's code reads 0 (crombach's DS4), so a live turn to B would not
switch; #59 waits inside rc_go for the mode's code (gx_map retries) and counts B as a mode.
- **Conflicts:** NOTES (both kept), TESTING (#59's #54 rows), `emu_test.py` (#59's file with #58, plus this line's
  curves tests, card fixtures, PHOTO_SWITCH_VIDEO = 1 and dl9 wording). #59's two new checks in dl9's wording: a
  switch line `after event N: ... (dial position N) -> ...` that is not a first look, and `Camera COLOR values that
  differed from a Reset custom mode's own: 0`. Shared first boots key on their card files too.
- **Firmware check:** test 11 -> 12 is exactly #59's editor.s / editor.ld lines minus rc_turn. No new hook sites; new
  calls ds_get / ds_put (data item 38, written back as read, only after a held turn); nothing new before the first
  look. `mx_photo` (mix / curves gate) keeps its own copy of the photo test: om-emu's B code 62 is not photo there,
  the camera's B code 0 falls to the switch (photo), so on the camera mix / curves work in B as before.
- **Build:** E1479999.BIN `0116c558…ee25`, rebuilt from 5476eb7 byte for byte. Package
  `test-builds/2026-11-15-v030-test12` (private), with CURVES.BIN as test 11 and the v0.29.5 go-back.
- **Suite:** 20 of 20 pass (`Pass recorded on 5476eb7514dd`). `--without` test 11 (rebuilt, 0f690519…): `caught`
  live-dial-turn-waits-for-the-mode-code and live-dial-turn-back-keeps-the-mode-choice; live-dial-turn-to-b-switches-
  the-films passes on test 11 (expected: it guards #59's own wait, which test 11 does not have).

### Test 12 camera, first report (owner, 2026-11-16)
- **One quick reboot** "when switching between film sims in a mode" (which screen and mode not known yet). The card's
  CADLOG.TXT (16 shutter events, 30 mode changes, "nothing unusual") is written at shutter events, so it may be the
  power-on before or after the reboot. om-emu (test 12 build): repeated film / COLOR picks in Picture Mode in P, in B
  and in C1 right after a held live turn: no crash, no FAIL. Not reproduced; cause unknown.
  Owner: it was the Super Control Panel's picture-mode cell, in a shooting mode, once. om-emu: the SCP cell turned
  with the front dial (one step at a time, and bursts of 2..9 steps) in P, A, B and C1, 24..42 film / COLOR switches
  each: no crash. The only #59 code on that path is sx_set 901's cm_gnow read and compare (same group: cm_gpm as in
  test 11); lv_due runs only when the dial's group is not the films' group. So most likely not #59; an older rare one
  is possible. If it happens again: switch off without a half-press (the next half-press overwrites CADLOG.TXT) and
  bring the card.
- **Noise Filter's '*' on COLOR 1-4 (no film), camera's own Noise Filter set to Off:** the row shows '*' at Off and
  none at Std, while the profile shows none at Off and '*' at Std. Cause (code; matches the owner's report): the row's
  "is at default" (stock_isdef -> GetValue vs GetDefault) has no default for NRB + k, so `vf_def` falls to
  `stock_default` (0 = Std); the profile's '*' (`ed_isd0`) counts slot +51 != 0, and the setter stores 0 when the
  choice equals the camera's own Noise Filter (`nf_get`, #46). Films are not affected (`fl_isdef` compares +51 with
  the film's record). In since v0.29.4 (#46), not new in test 12; shows only when the camera's own Noise Filter is not
  Std. Possible fix: `vf_def` answers NRB + k with `nf_get`, so row and profile both compare with the camera's own.
  Not built (owner's call).

## v0.30 test 13: test 12 + the Noise Filter row '*' fix (2026-11-16; emulator only, camera test pending)
Owner: "yes, build the noise filter fix" (the row's '*' follows the camera's own Noise Filter, as the profile's does).
- **Fix (18a7a33):** `vf_def` (ed_default's miss, the facade's GetDefault) answers NRB + k with the camera's own Noise
  Filter (`nf_get`, key 0x9719, as sl_get's label 94 reads it; MDR kept as sl_gb keeps it). Row and profile now both
  compare with it: camera on Off, a COLOR without a film shows no '*' at Off and one on both at Std. Films unchanged
  (`fl_isdef` compares +51 with the film's record). Left as it is: if the camera's own Noise Filter is changed in the
  menu after a choice was stored (+51 != 0) and the new setting equals that choice, the row shows no '*' while the
  profile keeps its own until the row is set again.
- **Test:** `noise-filter-row-follows-the-camera-setting` with a new driver token `expect:isdef:FN:ID=V` (calls
  `ed_isdef` as the camera's "is at default" calls do). The camera's own Noise Filter is poked into its byte,
  0x6295942d in om-emu (traced with a mem probe on the getter 0x60063380: entry a32ae498 -> (4) -> that byte); a write
  through the settings manager 0x60bb528f from the driver did not return (5M steps), so no `set:` token. Test 12:
  `caught` (`expect:isdef 7e11: 0, not 1`); test 13: pass.
- **Build:** E1479999.BIN `d3ab5d4f…04f1` (rebuilt from 18a7a33 byte for byte). Package
  `test-builds/2026-11-16-v030-test13` (private), CURVES.BIN and the v0.29.5 go-back as test 12.
- **Suite:** 21 of 21 pass (`Pass recorded on 18a7a33bf01c`).
- **Camera-tested (owner, 2026-11-16): "this looks good and works as it should."** Debug log (test 13, 62 shutter
  events, 98 photos, 23 shooting-mode changes, custom modes C1-C5 with films): "nothing unusual", no film with changes,
  no reboot. Test 13 (`d3ab5d4f…04f1`) is the v0.30 candidate: test 11 + PR #59 (#54) + the Noise Filter row fix.

### PR #59 merged into main (owner, 2026-11-16: "can we merge and close pr #59")
- #59's head had moved to 2a21c56 since test 12 (1039565): the firmware differs only by a named constant (`UI_DIAL`
  for 0xa32d9d0c, the same instruction); emu_test.py was tidied (`build_symbols`). main had moved too (#60 om-emu pin,
  #62 commit identity, #63). Merged locally onto main (d7336d0), one conflict in emu_test.py (both import lists;
  #59's MODE_DIAL_B / UI_MODE_DIAL beside main's PHOTO_SWITCH_VIDEO = 1), built (E1479999.BIN `f4eed931…`), suite 17
  of 17 pass, pushed. GitHub marked #59 merged; its "Fix #54" closed issue #54. No release.
- This branch (`try/v0.30-dl9`) still has #59 as 1039565 and lacks #60 / #62 / #63: merge main into it before the
  v0.30 release.

## Issue #50: photos not saved with Film Grain (2026-11-16; analysis only, not reproduced)
- Report (User1211-per, v0.29.4, then v0.29.5): Grain changed on a film (FILM 13 Pro 160S, FILM 10 Velvia 50 and
  others: the standard films, none with grain built in) -> the film gets its '*', the camera seems to take the photo,
  but nothing is on the card or in playback. Grain back to the film's own (Off) -> photos save. Noise Filter changed:
  photos save. With or without a half-press before the change.
- Their CADLOG (v0.29.5, 53 shutter events, COLOR 3 FILM 15 throughout): card files all match, films from camera
  memory, saves 1, nothing unusual. v0.29.5's log has no camera settings and no photo count, so it cannot show the
  cause. (Events 26-35 read save result 0: STATUS is cleared at the editor's first use after a load.)
- Owner's camera: grain has saved in every test since v0.25 (single, bursts, RAW+JPEG, Glow / Clarity, Shading,
  Halation). So their camera settings likely differ. Guess: fast grain swaps a COLOR still to Grainy Film's work list
  (the camera's Art Filter route), so a mode where the camera allows no Art Filter (Hi Res Shot, Live ND, focus
  bracketing / stacking, HDR, multiple exposure, Pro Capture?, digital tele-converter) or RAW only may lose the photo.
  Next: their image quality, aspect, drive / shutter and computational modes (a photo with Grain off, same settings:
  its EXIF), or the owner tries those modes with grain.
- **Owner's camera, test 13, grain test for #50 (2026-11-16; camera-tested): not reproduced.** FILM 10 Velvia 50 with
  Grain High (COLOR 2), then FILM 15 on COLOR 3: 54 shots PB162816..869, numbers with no gap, every one saved (102
  files: 54 JPG, 47 ORF, 1 ORI). Saved: JPEG LF and M (3200 x 2400), RAW+JPEG, aspects 4:3 / 16:9 / 3:2 / 6:6 / 3:4,
  anti-shock, sequential (3 and 6), silent sequential SH1 (4), Pro Capture (13), hand-held High Res (8160 x 6120 + ORI),
  Live GND (GND8), HDR2 (the camera switches to Natural there: no film, no grain), focus bracketing (9), digital
  tele-converter (x2), COLOR 3 FILM 15 single. Not in the files: RAW only, Live ND, multiple exposure, focus stacking,
  silent single. CADLOG: "nothing unusual", photos counted 87 (counted once per EXIF fill; the 33 above the 54 saved
  shots are likely the multi-frame modes' frames: guess).


## LookLab: RGB curves and colour mix (2026-11-15; feature/looklab-rgb-curves; browser-checked, not live)
- Owner: RGB curves are camera-tested (feature/rgb-curves test 4), colour mix is coming: update LookLab, as a private
  test page (claude.ai artifact) first.
- `webapp/src/curves.ts`: the camera's curve maths (research/rgbcurves/model.py, test 4: 5 points at 0 / 25 / 50 / 75 /
  100 %, step 48), bit for bit (vitest against the model's values). The preview adds it in split toning's pass
  (`bendSplit`), then the clamp and running max, as st_run. Looks keep `rgb: {r, g, b}` (5 values each; absent = flat),
  in saved lists and share links.
- Editor: an "RGB curves" panel under Highlight & Shadow (as the camera's row): R / G / B, the three curves on the
  camera-style grid, drag a point or use its slider; Reset.
- Not in `LOOKS.BIN` or the photo code (the camera does not read curves from the card yet): the panel says to set the
  same numbers on the camera's RGB row.
- **Colour mix (2026-11-15, after mix test 6 camera-tested):** `curves.ts` `mixMatrix` = research/colourmix/model.py
  (vitest against its five cases); looks keep `mix: [h R, s R, h G, s G, h B, s B]` (-7..7; absent = none). The preview
  applies it in the WB step, in linear light after the WB gains (the camera: ours x its colour matrix, before the gamma
  stage), so greys stay grey. Editor: a "Color Mix" panel before RGB curves: R / G / B (shared with the RGB panel, as the
  camera's INFO), the ring with three dots (angle = hue, distance = strength), Sat and Hue sliders; Reset. Not in
  `LOOKS.BIN` either: the panel says to set it on the camera's Mix row. Firmware older than v0.28: mix not previewed.
- **The 20 films regraded with curves + mix (2026-11-15; preview only, not camera-tested, not in the films).** Owner:
  "recolor grade the default 20 film sims using the new tools". Each film keeps its v0.29 settings; a search over the
  15 curve points and 6 mix values (the camera's limits) in this preview fits the film to its colour-chart reference,
  the same reference and target as the 2026-11-13 grading (each film relative to its session's average; numbers kept
  outside the repo). Grey patches keep the film's tone; strong mixes are penalised (colour noise). Mean colour error
  over the chart (Lab, exposure taken out), 18 films: 7.9 -> 4.7; on a third of the patches left out of the fit: 8.6
  -> 6.2 (17 of 18 better; Portra 160 5.1 -> 5.8, so its change is doubtful). Velvia 50 14.3 -> 9.0 and Ektachrome
  E100 14.6 -> 7.5 stay the furthest off (the mix reaches its limit on their greens). Kodachrome 64 and CineStill
  800T: no chart reference, unchanged (their reference-photo numbers gave the washed-out v6 looks). Limits: the preview,
  not the camera (it runs the 12 colours before the curves, the camera after); one chart under one light. The fitted
  numbers and the comparison pictures are in the owner's private notes; shipping them needs the firmware's built-in
  films to carry curves and mix (owner's call).
- **Kodachrome 64 and CineStill 800T from internet photos (2026-11-15; preview only).** Owner: "can you regrade
  kodachrome and cinestill based on pictures found on the internet". The reference-photo statistics already measured
  (2026-11-09; HSV 30-degree bins: mean saturation and hue per bin; numbers kept outside the repo) against the same
  numbers on the preview of the 13 sample photos, each film relative to the average of the same nine reference films on
  both sides. Check first: on the 11 films that have both, the chart-scan regrade moves the photo numbers' colour
  strength the right way for 7 (not Ektar, Velvia, C200, Provia) and their lean the wrong way slightly (< 1.2 deg): a
  rough guide for strength, little for lean. So only the mix was fitted (tone and casts in such photos follow their scans
  and edits), lean weighted lightly. Kodachrome 64: mix G Hue +1, Sat -1; colour strength off 10.2 -> 9.1 %. CineStill
  800T: R Hue +1, Sat -1; G Sat -2; B Sat +1; 13.4 -> 7.5 % (its photos are mostly night scenes under lamps).
- **In LookLab (owner: "these look great ... updating the looklab with these new sims and the new camera profile tools
  ... use the new menu order and design"; 2026-11-15, private test page only):** `scripts/films.py` `CURVES_MIX` carries
  the 20 films' curves and mix into `om3films.json` (`rgb`, `mix`), and `filmLook` into the look, so the camera's 20
  preview with their new grades (not in `LOOKS.BIN`: on the camera they need the test firmware's RGB / Mix rows, and to
  ship, the firmware's built-in films must carry them). Saved banks keep their old values until Reset look. The OM-3
  editor follows colour menu test 7 (camera-tested): page 1 Color Mix, RGB curves, Color wheel (HSL), Split Tone
  Balance; page 2 WB Compensation, Highlight & Shadow, Blacks / Whites, Contrast, Sharpness; page 3 Noise Filter,
  Vignette Correction, Shading Effect, Glow Effect, Halation Effect; page 4 Film Grain Effect; small versions of the
  camera's new row pictures in the headings (Mix ring, RGB curve box, colour pie, tone bar, black / white squares, glow
  dot, halation ring); the camera's new titles.
- **Owner's feedback on the test page (2026-11-15):** "notes should be at the very top" (now right under the name) and
  "the color mix wheel does not line up with what is on camera": the Mix ring now draws as the firmware's (mx_pre /
  mx_line, rgbpics.py MX_ANG): a 300 x 300 box with its centre cross, ring r 90, red at the top, green lower right, blue
  lower left (-90 / 30 / 150 deg, screen y down), + Hue clockwise 5 deg a step, radius 90 + 4 per Saturation step,
  start marks, the chosen dot r 13 on a white r 16, the others r 8 dim; header "Saturation / colour / Hue" as test 7.
- Owner: "the looklab doesnt need to have page 1, 2, 3, 4 on it": the page headings are gone; the rows keep the
  camera's order.
- The Mix header and slider say "Sat", as the camera's page does (om-emu on the v0.30 build: "Sat ±0  Red  Hue ±0").
- **CURVES.BIN (2026-11-15; owner's choice "New card file", format from the RGB Curves session, docs/FORMATS.md
  "CURVES.BIN v1" on try/v0.30 c33dc42):** `webapp/src/curvesbin.ts` writes it from the bank and the LOOKS.BIN bytes it
  goes with (each entry's check = CRC-32 of that film's 64-byte record). Export: Save to the SD card and the card zip
  add OM3MOD/CURVES.BIN when the firmware choice is "v0.28 or later" (older firmware never reads it), plus a single-file
  button. The RGB / Mix panels now say it goes to the camera this way (v0.30). vitest `curvesbin.test.ts`: the standard
  20's LOOKS.BIN equals releases/v0.29.5/LOOKS.BIN and CURVES.BIN equals the reference build (card/mkcurves.py) byte for
  byte (sha256 4c009f9c…2291; Portra 400's entry 1c8fb44b 00f0000000001201 0000ffffff00 0000). Not camera-tested
  (firmware reads it from test 9).
- The camera's Mix / RGB headers show R / G / B in the middle (try/v0.30 7a92cd3, owner): LookLab's Mix and RGB
  readouts do the same (the letter in its colour, a little bigger).
- Test 11 (try/v0.30-dl9 333523c, owner: "please center the r,g,b"): the Mix readout's letter centred over the ring
  (a three-column header; measured in the browser: within 1 px of the ring's centre).


## The tour for v0.30 (2026-11-15; feature/tour-v030; emulator screens + LookLab preview, browser-checked, not live)
- Owner: "update the tour with all the new screens, info, ect." Branch `feature/tour-v030` from `try/v0.30` (0c1a80e)
  with `feature/looklab-rgb-curves` merged (owner: v0.30 includes the new LookLab).
- `research/showcase/make.sh` on that build (IMG = its main.bin; E1479999.BIN 5768c9e1…), in v0.30's Picture Mode order
  (keys in make.sh and the showcase README): every Picture Mode screen re-shot (the new row pictures); new screens
  `row-mix` (Red Sat +3, Hue +4) and `row-rgb` (Blue point 2 +5, point 4 −4) and their before / after photos (demos.ts:
  taxi, meadow); the star shot now on page 1 (FILM 1*, Mix*, Split Tone Balance*); the Creative Dial shot one row lower
  (v0.29.3's Delete row had moved it: the old picture predated that row). om-emu keys found on the way: on Mix, `main` =
  Sat, `sub-1` = Hue +1; on RGB, `sub-1` = the next point, `main` = its level (one token = one step); INFO's colour is
  shared and starts on Red. The film photos and the earlier demos are byte-identical to before: `mklooks.ts` leaves out
  LookLab's curves + mix regrade, which the camera's built-in films don't carry.
- `index.html`: a "New in v0.30" section (Color Mix, RGB curves and the new Picture Mode with their screens; ready at
  switch-on, #56 by crombach; fixes #53 / #55 and #54), its nav link, "15 settings per film", the editor's rows in
  v0.30's order with the camera's titles (the wheel's page buttons now find its row), v0.29.5's custom modes and v0.29.4's
  stars under "Your changes stay with each film", LookLab's Mix / RGB curves in its card. Private preview for the owner:
  a claude.ai artifact (links to LookLab / install don't work there).
- Left for the release: USING.md / CHANGELOG etc. (cad).
- **The colour profile menu, shown and explained (owner: "show off the new color profil menu and explain it"):** first as
  its own walk-through section (FILM 1 with the cursor on each of 16 rows); then (owner: "combine the new picture mode
  rows you made with the following and only keep one") folded into "A colour editor on the camera": a Film row first
  (FILM 1's screen, the meadow before / after Portra 400), the camera's groups as labels in the row list (the film and
  its colour, white balance and tone, lens and effects, grain), the intro on the order and the five-row pages, and for
  each row what its picture in the camera's list shows. The walk-through section, its 16 menu screens and their make.sh
  lines are gone.
- Owner: "removes the fixes block, and remove combachs name. I don't want it blasted on the front page": the Fixes card
  is gone and the tour names no contributor (the Ready at switch-on, stars and Delete button captions included); credits
  stay in CHANGELOG and the release notes.
- Owner: "separate them by pages instead of what they do": the row list's group labels read Page 1 to Page 4.
- Owner: "callout the more robust debuglog that is coming in the .30 update. maybe include a prettified example": a
  "A fuller debug log" card in New in v0.30, and in the Help section (anchor #debuglog) what the dl9 log covers
  (feature/debug-log, camera-tested) with a styled, shortened example built from the emulator sample (the film names
  changed to today's standard 20; drive / AF / quality shown as the camera's codes, as the log does). The tour's Help
  steps still say OM3MOD/CADLOG.TXT (dl9 keeps the name). This assumes cad merges feature/debug-log into v0.30.
- try/v0.30 merged in (to 7a92cd3: test 9's CURVES.BIN reading and the Mix / RGB headers' R / G / B, owner) and make.sh
  re-run on that build (E1479999.BIN 9b9ae1a2…): only row-mix, row-rgb and kept-star changed (the header letter); every
  other picture byte-identical. The emulator card has no CURVES.BIN, so the film screens and photos show the films without
  their curves + mix regrade.
- Owner: "Yes, show new grades": the tour's films keep their curves + mix (mklooks.ts), and make.sh puts CURVES.BIN (made
  by LookLab's curvesbin.ts against the same LOOKS.BIN) on the emulator card with LOOKS.BIN. Changed: the 80 film photos,
  the two halation photos, kept-star (om-emu read CURVES.BIN: FILM 1's Mix page shows Portra 400's built-in green / blue,
  the RGB row unstarred); the film screens and the rest byte-identical. Text: New in v0.30 and the films section say the
  films are regraded and that the camera takes the grades from CURVES.BIN once; the release has to carry the standard
  CURVES.BIN for that (cad).
- try/v0.30-dl9 merged in (test 11, 333523c: the debug log dl9 and the Mix / RGB headers' R / G / B centred) and make.sh
  re-run on that build (E1479999.BIN 0f690519…, the same as the test 11 package): only row-mix, row-rgb and kept-star
  changed (the centred letter).

## v0.30 release (2026-11-16; owner: "lets launch v0.30 ... post v.30 on github, and push the lablook and tour updates")
- `try/v0.30-dl9` = test 13 + main (PR #59 as merged, #60 pin via #63, #62) + `feature/tour-v030` (LookLab curves / mix
  and the tour). The merge of main doubled #59's lv_* block (both sides added it from the same base); editor.s was put
  back to test 13's source plus #59's later `UI_DIAL` name (9d186e5).
- `firmware/VERSION` "v0.30 (colour mix and RGB curves, camera-tested t13)", 52 characters as test 13's: main.bin differs
  from test 13 only in that string, the code-block tag (twice) and the built-in GUIDES CRC (53 bytes). E1479999.BIN
  481f3678…7a54; `patch.py --release v0.30` makes it byte for byte, `--release v0.29.5` still 01ea3d14….
- `releases/v0.30`: patch.json, CURVES.BIN (4c009f9c…, test 9's sample, all 20 entries match v0.29.5's LOOKS.BIN
  records), LOOKS.BIN / DEBUG.TXT / photo code kit as v0.29.5, SHA256SUMS, NOTES.md. The release gets
  CURVES.BIN by hand: the push that also listed it in `.github/workflows/releases.yml` was refused (gh's token has no
  `workflow` scope), so the workflow is unchanged. CURVES.BIN needs `git add -f` (`.gitignore` *.bin). LookLab rebuilt
  into looklab/ (tsc clean, 68 tests pass; samples and fonts unchanged).

## Issue #65: live view freezes after a Halation photo when the Creative Dial goes to the standard picture modes (2026-11-17; analysis only)
- Report (flrvr, v0.30 `481f3678…`, also v0.29.5 and v0.28): FILM 9 CineStill 800T with **Halation 5**, take a photo,
  turn the Creative Dial to its middle position (Vivid): live view freezes. Turning back to a film position recovers
  it; a shutter press while frozen saves the photo, then the camera hangs (battery out). Halation 0 on the same film:
  fine. RAW+JPEG, custom mode C1 (Save Settings: Hold), drive [11]. Their CADLOG after the hang: shutter events still
  logged (lg_pr runs), no photos; NOW reads mode code 0 at C1, setting 111 = 0, sid 897 = 898 (the standard modes).
- Same family as #27 (v0.26.2, closed, not reproduced here): Creative Dial away from COLOR froze live view, "mostly
  with Glow and / or grain", CineStill 800T. Glow and Halation share the Soft Focus route for photos (`xb_cap`: job flag
  0x80; `xb_wt`: weight 1024 with Glow 0; `xb_gs` runs `HL_RUN` after SF_ENT, through `hl_open`'s bus window under
  LOCK). Guess: something the Soft Focus route (or the halation pass) leaves after a COLOR still stalls the next
  non-COLOR live view. Not found by reading; not reproduced on the owner's camera yet.
- Log nit: for the standard modes the event table's Picture column prints "898 (not a dial position)", which pushes
  Ed / Sv / Photos out of their columns.
- **Owner's camera, v0.30 (2026-11-17; camera-tested): not reproduced.** P/A group (A), FILM 9 CineStill 800T on COLOR 2
  with Halation 5 (the photos' om3.1 code: halation 5, glow 0, grain Off): four RAW+JPEG shots (PB162871..874, single,
  anti-shock), then the Creative Dial to the standard position (events 31-34 log "898", saves fine), back to FILM 9,
  one JPEG (PB162875): no freeze. CADLOG "nothing unusual". Differences from the reporter: custom mode C1 with Save
  Settings Hold (owner: A), drive [11] (owner [0]), AF mode [4] (owner [0]), face / eye [6] (owner [0]), NAMES.BIN and
  the old card files on their card.
- **Owner's camera, v0.30, set up as the reporter (2026-11-17; camera-tested): not reproduced.** C1 assigned with
  COLOR 1-4 = FILM 5 / 9 / 11 / 20 (their COLOR 4 was FILM 16) and FILM 9 CineStill 800T with Halation 5 (the photos'
  om3.1 code), Save Settings Hold; 16 RAW+JPEG shots PB162879..894 with S-AF and C-AF, single with and without
  anti-shock, Face / Eye detection tried; Creative Dial to the standard position after each pair: no freeze. CADLOG
  "nothing unusual", 176 events, 18 photos. Code pairs seen (log code = EXIF): drive 0 = "Single Shot; Anti-shock",
  30 = "Single Shot"; AF 0 = S-AF, 1 = C-AF; face / eye 5 with detection on (owner), 0 off. The reporter's drive 11,
  AF 4, face / eye 6 and image quality 14 (owner 15) are settings not tried yet.
## Grid rows' flash on leaving (2026-11-16; feature/menu-flicker; camera-tested, issue #66)
- Camera (a 30 fps phone video of the rear screen, 2026-11-16): leaving Blacks / Whites for Contrast, or WB
  compensation for Highlight & Shadow, shows one frame with the old row's title and a green box at the bottom centre
  holding the old row's icon. That is the one-option choice bar, without the grid. The camera's own row changes show
  only mixes of the old and new screens.
- Cause (trace, emulator): gr_upd (hook 0x611d04ec) runs after the row's case draws, but before the update publishes
  the new row's values (0x610cd5c4, ids 275 .. 17, 0x611d050f..0x611d0595). Leaving a grid row, it loaded the bar
  (456) into the holder there, so the reloaded bar read the last row's published values for about 200k instructions.
  The camera can display that frame. om-emu draws the screen only after the update, so it never shows it: frames 5 ms
  after the key and an MMIO trace show OSD-engine writes only once the update has returned.
- Fix: gr_end (new hook 0x611d059c, the update's end: `mov (12,sp),d0; cmp 0,d0; bne 0x611d05b2`) gives the holder its
  bar back after the publishes. gr_upd only clears gr_flag off our rows. Emulator: the seven screens WB, H&S, B/W,
  Contrast and back are byte-identical to the build without the fix. The trace shows sc_set 456 after the publishes.
  Test `grid-row-gives-the-bottom-bar-back` checks the holder's scene (24813 on the row, 24771 after).
- A grid in a layer of its own, which would need no bar reload, is not open: test 13 found the grid draws only in the
  bottom bar's holder (see "Test 13" above).
- Emulator tools (session_ed1.mjs): `frames:KEY:N:MS:PREFIX`, `TRACE=PC,...` (trace.jsonl), `MMIO=1` (with TRACE, in
  the same file, in order), `expect:mem` with pointer chains.
- **Camera (2026-11-16, build ec583c0, E1479999.BIN 973006ba…):** "no more flicker in the new firmware". The flash is
  gone on both moves.

## v0.30.1 test 1: v0.30 + PR #67, the menu flash fix (2026-11-17; emulator only, camera test pending)
- PR #67 (crombach, #66) merged into main on GitHub as written (89b3520; one NOTES conflict, both kept). cad's read:
  `.hook_pe` at 0x611d059c replays the stock `mov (12,sp),d0; cmp 0,d0; bne 0x611d05b2` (pe_back / pe_ret); `gr_end`
  keeps its own call slot, uses only d0 / a0 and calls that save d2 / d3 / a2 / a3; after it the stock code reloads d0 /
  d1 before its call and returns with `ret` (MDR unused). Runs only at the Picture Mode update's end; no start-up or
  video path. Suite on a build of the merge: 22 of 22 pass.
- `try/v0.30.1` = main 89b3520 + firmware/VERSION "v0.30.1-dev (test 1: PR #67, menu flash fix for #66)" (52 characters,
  as v0.30's): main.bin differs from the tested merge build only in the name, the code-block tag (twice) and the
  built-in GUIDES CRC (51 bytes). E1479999.BIN `d1194729…11b7`, rebuilt byte for byte. Package
  `test-builds/2026-11-17-v0301-test1` (private), CURVES.BIN as v0.30, go-back v0.30 (481f3678…).
- **Camera-tested (owner, 2026-11-17): "looks good".** Test 1 (`d1194729…11b7`) on the owner's OM-3: the B/W and WB
  Compensation rows leave without the flash. Test 1 is the v0.30.1 candidate.
- **v0.30.1 release (2026-11-17; owner: "Yes, release v0.30.1"):** `firmware/VERSION` "v0.30.1 (menu flash fix, crombach,
  camera-tested t1)", 52 characters: main.bin differs from test 1 only in the name, the code-block tag (twice) and the
  built-in GUIDES CRC (53 bytes). E1479999.BIN c2b583fd…4bc5; `patch.py --release v0.30.1` makes it byte for byte,
  `--release v0.30` still 481f3678…. `releases/v0.30.1`: patch.json, CURVES.BIN / LOOKS.BIN / DEBUG.TXT / photo code
  kit as v0.30, SHA256SUMS, NOTES.md; CURVES.BIN goes on the GitHub release by hand (the workflow doesn't list it).

## Reboot when resetting many films before a half-press (owner, 2026-11-17; emulator: not reproduced)
- Owner: in the COLOR profiles / films, resetting (held OK) many changed films one after another before a half-press,
  then scrolling on, reboots the camera. Fits the one reboot seen on v0.30 test 12 (film switching in the Super Control
  Panel). All the owner's films had changes.
- om-emu (v0.30.1 build, Picture Mode list from the Super Control Panel): (1) 14 held-OK resets on unchanged cells,
  then 40 scrolls; (2) Contrast changed on FILM 1-12 (10 films starred, saved by a half-press), next boot 12 resets
  with no half-press, then 56 scrolls; (3) Contrast and Sharpness changed on all 24 cells (all 20 films starred), next
  boot 24 resets, 40 scrolls and 24 dial bursts of 3..9 steps. No crash or restart in any; CADLOG "nothing unusual",
  films with changes "none" after the resets. So camera-only so far (timing, live view): needs the owner's exact steps
  and a CADLOG taken with no half-press after the reboot.
- **#65 trigger found (reporter flrvr, 2026-11-16; owner reproduced it "first go around"): Image Review.** With Image
  Review on (0.5 s), the review after a Halation shot is black (since v0.28), and the Creative Dial to the standard
  modes then freezes live view; with Image Review off, no freeze in any of their settings (subject detection, drive,
  shutter, quality, MF). Analysis only: `HL_RUN` works on the finished picture (buffer 0x1000 through the bus window
  after SF_ENT, in `xb_gs`), apparently while or after the camera makes its review picture from it; something in the
  review path is left waiting, and the switch to a standard mode waits on it. #27 (v0.26.2, Glow / grain) may be the same
  mechanism (the CPU grain pass over the finished picture). Needs camera debug builds (stills are camera-only).
- **Debug log cost (same comment):** with DEBUG.TXT on the card, the shutter fires late and sequential bursts go on
  after release. `lg_pr` runs `lg_write` at every shutter event (press and release) in the shutter task: ~63 setting
  reads, a 9216 B report built and written to the card, before `trig_resume`.
- **Owner's camera (2026-11-17, v0.30.1 test 1): Glow 3 alone (Halation 0; PB162900 / 901, om3.1 code glow 3, halation
  0) gives the black review and the Vivid freeze too.** So the shared route (job flag 0x80 on a COLOR job) is the cause,
  not `hl_run` (and #27, Glow on v0.26.2, is the same bug). (A first try, PB162899, had Halation 3 instead of Glow 3.)
- **Cause (Caduceus for the E-P7 found it first: cakelesscoder/caduceus-ep7 v0.31 "Rec View fix", `patches/recview`,
  `docs/BLOOM_HALATION.md`, read only):** the camera strips the multi-pass effect flags (0x40 Star Light, 0x80 Soft Focus,
  ...) from Art Filter jobs whose type is 0x1xx or 0x4x, the extra small developments of a shot (types 0x110 / 0x120,
  capture kinds 0x2001 / 0x2006, the review picture among them), not the saved photo (type 0x1000). That strip never
  runs for COLOR (key 11), so our 0x80 reached them. OM-3's job-type mapper is 0x60555b58 (E-P7 0x603ea909): `mov
  a0,a2; movhu (186,a2),d0`, kinds 0x2001 / 0x2006 -> 0x100 | 0x10 / 0x20 (when 0x60559cc2 != 1), 0x1008 / 0x1006 ->
  0, else 0x1000; the request builders call it right after the converter (`mov a3,a0; call 0x60555b58,[d2,a2],12`,
  0x60553ae4; the result goes to params+40).
- **Fix (0be3c0a, `feature/fix-65-review`):** `xb_rv` (xblock), called by `xb_cap` before it stores the flags: with 0x40
  or 0x80 set, it asks 0x60555b58 for the job type (a0 = the source request at params+4 = (-8,a2)) and clears 0x40 /
  0x80 for types 0x1xx / 0x4x, as the camera does for Art Filters. Keeps a2 / a3 / MDR. The photo (0x1000) and live
  view (`xb_lv`, its own route) keep Glow / Halation; the review picture shows the film without them. A probe build
  (p65a: log + a class-based skip at the work list's 0x80 test) was made first and dropped before any camera test once
  the E-P7 finding gave the exact rule.
- Build "v0.30.2-dev (test 1: #65 fix, Glow route off review)", E1479999.BIN `6cb4dfe8…35ae` (rebuilt byte for byte),
  suite 22 of 22. om-emu develops no photos: camera-only ("Past regressions").

### Caduceus for the E-P7's faster halation h6 (read only, 2026-11-17; owner: "they seem to have made it faster")
- cakelesscoder/caduceus-ep7 `docs/HALATION_RED.md` §23 (v0.33, camera-tested on the E-P7): the same photo bit for bit
  as their h2, 46-74 % fewer instructions (night scene with lights 108 M -> 28 M), no malloc. How: pass A ORs eight Y
  samples and compares once, skips saturated cells; pass B blurs in place; pass C walks each row in 32-pair strips
  between cell centres, skips strips and cell columns with no glow, walks only from the first to the last pair with
  g >= 1, computes g * dY once per pair, eight pairs a loop turn; several rows per lock up to a cap of ~120 K
  instructions masked (fewer flushes); the cell grid in a spare block tail instead of three mallocs.
- Ours (`hl_run`) started from their h2 design but has its own changes (h2: chroma weight from a smoothed cell mean;
  h4: the broad layer), so the same ideas would have to be applied to our code and checked bit for bit against our
  model (`research/halation`). Not started.
- **Camera-tested (owner, 2026-11-17): "The fix works"** (v0.30.2 test 1, `6cb4dfe8…35ae`): no black review, no freeze at
  the Creative Dial to Vivid. Caveat (owner): "the playback doesn't display the glow settings". Expected from the fix:
  the camera's playback shows the photo's small embedded preview, one of the shot's small developments (type 0x110 /
  0x120) that no longer get 0x80; the saved photo itself (0x1000) should keep the glow / halo (to check on the card).
  Possible refinement (analysis): one of the two small types may be the review picture and the other the embedded
  preview; keeping 0x80 on the preview's type only would need one camera test per type.
- **v0.30.2 release (2026-11-17; owner: "Let's keep it as is", the option that released the fix with the playback note):**
  `firmware/VERSION` "v0.30.2 (Image Review fix for #65, camera-tested t1)", 52 characters: main.bin differs from test 1
  only in the name, the code-block tag (twice) and the built-in GUIDES CRC (51 bytes). E1479999.BIN 7fbd3957…445b;
  `patch.py --release v0.30.2` makes it byte for byte, `--release v0.30.1` still c2b583fd…. Extras as v0.30.1.

## Faster halation h7: the same photo, about half the work (2026-11-16; emulator only, camera test pending; branch feature/faster-halation)
- Asked for (main chat, after the owner saw Caduceus for the E-P7's h6, "they seem to have made it faster"): speed up
  `hl_run` with the ideas of cakelesscoder/caduceus-ep7 `docs/HALATION_RED.md` §23 (read only, nothing copied;
  credited in editor.s), applied to our pass (h2's chroma weight from the cell mean, h4's broad layer), without
  changing one output byte.
- **What changed** (editor.s, ext12; `hl_open` and `hl_div` as they were; frame of `hl_run` still 124, so xb_gs is
  unchanged; GUIDES / LABELS / TONES unchanged):
  - Pass A (`hl_pa`, `hl_x8`): eight Y0 ORed and compared with T once; only when the OR is above T are the eight
    excesses summed (the OR bounds each value, so this is exact). A full cell's 32 pairs run in one go. A full cell's
    B = 4 Q / 1024 = Q >> 8 (no division); `hl_div` only for the edge cells.
  - Pass B: `hl_b1` blurs in place (keeps the old left value in a register); no temp copy.
  - Pass C: a pair with g <= 1 never changes (Y: 255 x 1 x KY = 11220 < 2^16; chroma: c = (1 x w) >> 8 = 0 with
    w <= 255), so: no pass when no g >= 2 anywhere; rows go in bands that share their cell rows (rows 0..31: row 0;
    32 + 64 r0 .. + 63: rows r0, r0 + 1; the last rows: row GH - 1); per band `hl_bd` lists the segments (head, the
    spans between cell centres, tail) whose end columns have g >= 2 in either cell row (a lerp stays between its ends);
    per row `hl_row` lerps only those ends (`hl_lp`, the right end carried to the next segment), skips a segment with
    g <= 1 at both ends, and `hl_sp` walks only from the first to the last pair with g >= 2 (g is monotonic along a
    segment), 8 pairs a loop turn. Per pair: g and w in one accumulator ((32 w + 16) << 16 | (32 g + 16), both halves
    stay in 0..8191, so one add steps both exactly); 32 g x KY once per pair and ((255 - Y) 32 g KY) >> 21 (= the
    model's >> 16 of g KY); Y left out while g < GY = 6 (255 x 5 x 44 < 2^16); the chroma change by table on c
    (`hl_cb` / `hl_cr`, 256 B each from firmware/halation.py, the model's floor shifts), one clamp each (KCB <= 0: Cb
    only falls; KCR >= 0: Cr only rises). halation.py `check_fast_path()` asserts these conditions at every build.
  - Several rows per lock and per FLUSH: as many as an estimate keeps under HL_LOCKN = 120 000 instructions (pass A:
    10 a pair + 20 a cell + 40 a row, 4 sampled rows on a 20 MP frame; pass C: 44 a pair + 120 a segment + 100 a row,
    from the band's list). A group across the window's edge is retried one row at a time; the one row across it is
    left out, as before.
- **Proof, om-emu 0819080 (the suite's pin):** `research/halation/emu_check.py` (new; driver `emu_hl.mjs`) calls
  `hl_run` through a `call hl_run,[d2,d3,a2,a3],124` stub, single-stepped (steps = instructions, no interrupts), on
  frames in plain DRAM (0xa8000000: hl_open uses the address directly, no bus window; FLUSH stubbed with
  `ret [d2,d3],16` as for h1; om-emu's ~200 M instruction limit lifted for the run), and compares every byte of the
  frame (padding included) with `model.halate`, plus d2 / d3 / a2 / a3 / sp back and a 4 KB guard after the frame.
  21 frames: synthetic night scenes (padding, grain sd 20, Glow 1..5), a frame in the fade zone (15.6 % bright cells),
  daylight (off), dark (none), widths 64 / 68 / 1000 / 1028 (part cells, GW 1..17), odd heights, chroma at both clamp
  ends, random bytes (Y 0..206: glow everywhere at small g; Y 0..255: off), five CC0 / public-domain sample photos
  darkened to night (two of them off), and two camera-sized ones (a 5184 x 3888 night scene; bluehour.jpg enlarged to
  5120 x 3200). **v0.30.1's code: 21 of 21 bit-exact; h7: 21 of 21 bit-exact**, registers, sp and guard intact.
- **Instructions (om-emu steps), v0.30.1 -> h7:**

  | Frame | Size | Level | Result | v0.30.1 | h7 | fewer |
  |---|---|---|---|---|---|---|
  | big5 (night, 12 lights) | 5184x3888 | 5 | glow | 230.4 M | 84.1 M | 64 % |
  | bigphoto5 (blue hour) | 5120x3200 | 5 | glow | 186.0 M | 85.3 M | 54 % |
  | bluehour5 | 2048x1280 | 5 | glow | 47.0 M | 20.9 M | 56 % |
  | taxi3 | 2048x963 | 3 | glow | 28.3 M | 10.3 M | 64 % |
  | night5 / night1 | 1536x1152 | 5 / 1 | glow | 35.3 / 20.6 M | 16.8 / 8.6 M | 52 / 58 % |
  | grain4 | 1536x1152 | 4 | glow | 36.6 M | 17.8 M | 51 % |
  | sparse5 (4 small lights) | 1536x1152 | 5 | glow | 42.5 M | 16.6 M | 61 % |
  | fade3 / odd2 / clamp5 | 0.8 / 0.7 / 0.4 MP | 3 / 2 / 5 | glow | 9.7 / 10.0 / 11.8 M | 4.8 / 2.9 / 4.9 M | 51 / 71 / 59 % |
  | dark5 / neon5 | 1024x768 | 5 | none / off | 2.10 M | 1.10 M | 48 % |
  | day5 | 1024x768 | 5 | off | 2.32 M | 1.79 M | 23 % |

  Where big5's 84 M go: `hl_sp` (the pairs) 51 M, `hl_pa` (pass A) 25 M, `hl_row` + `hl_lp` 5.6 M, the blur 1.6 M
  (v0.30.1: `hl_seg` 153 M, `hl_run` 61 M (mostly pass A), `hl_vl` 11.6 M, the blur 2.5 M, `hl_div` 1.7 M). Pass A
  is now the floor of ~5 instructions a sampled pair (a load, OR, shift and add for the cell mean B, which our h2
  needs and the E-P7's pass does not). A daylight frame still pays pass A (bright pixels take hl_x8) before it turns off.
- **Locks / FLUSHes per photo:** big5 5647 -> 1310, bigphoto5 3463 -> 1384, night5 1734 -> 258. The most instructions
  under one lock: up to 105 K on the test frames (v0.30.1: up to 133 K, on one row of the 16 MP frame); the cap is the
  estimate's 120 K. On the camera each FLUSH costs real time (xb_grain gr4: 2 rows per FLUSH saved 0.3 s on a 20 MP
  photo), which the emulator can't count; so the camera may gain more than the instruction count says. Analysis.
- **Camera-only:** the bus window path (the buffer through the window's cached view, several rows per lock and per
  FLUSH, the retry at the window's edge), the real time, the capture route. Code space: ext12 250 136 -> 252 376 of
  262 144 B (+2 240).
- **Test:** `tools/test/emu_test.py` gains `halation-matches-the-model` (emu_check.py on ten small frames, ~10 s): passes
  on v0.30.1 and on h7 (the same bytes); a build with a deliberate bug (Y1's shift 21 -> 20) is caught on 3 of the 10
  frames (`--without`: "caught").
- **Package h7 test 1** (commit 11385dc; the full suite, 23 tests, passes on it): E1479999.BIN `7efe76bf…70f3` (GUIDES
  / LABELS / TONES built in, as v0.29); VERSION "v0.30.1 + faster halation (h7 test 1)". No #65 fix in it (that is
  feature/fix-65-review; merging the two conflicts only in VERSION and these notes). Camera test: the same night scene
  at Halation 5 with this and with v0.30.1, the halo compared by eye and the save time counted.

## v0.30.3 test 1: faster halation (h7) + the debug log written at releases only (2026-11-17; emulator only)
Owner: "lets tackle that faster halation and the debug log". `try/v0.30.3` = main (v0.30.2) + the debug log change
(4940e1a, aligned in a later commit) + `feature/faster-halation` (h7, merged as its session built it).
- **Debug log:** `lg_pr` notes the shutter handler's event byte (18,sp) (the event word (16,sp) is 0x0100 at the
  half-press and 0x0101 at its release in om-emu, traced at 0x60415216) in `lg_rel`; `lg_write` still records every
  event (ring, camera values, the line), then `lg_due` lets the report be built and written only at a release, and not
  at the release that ends a burst (2+ photos since the half-press, `lg_npp`); `lg_w` now counts real writes. The first
  build trapped in om-emu on a misaligned `lg_npp` (code before it): fixed with `.balign 4`. Test
  `debug-log-written-at-releases-only` (three clicks: event 5, 3 writes; the first half-press loads the films and is
  not logged): pass; `--without` v0.30.2: caught. The burst rule needs photos: camera-only.
- Build "v0.30.3-dev (test 1: faster halation, debug log fix)" (52 characters), E1479999.BIN `3f5440bc…75b7`, rebuilt
  byte for byte; suite 24 of 24 (incl. `halation-matches-the-model`). Package `test-builds/2026-11-17-v0303-test1`.
- **Camera (owner, 2026-11-17, v0.30.3 test 1 `3f5440bc…`): "that is much quicker"** (Halation photos save faster).
  But "the halation at 5 kinda just ends. I want a smoother taper": the halo's outer edge stops too abruptly at
  strength 5 (the same pixels as v0.30.2, h7 being bit-exact, so the look predates h7; h4's broad layer softened it
  once, "the fade looks good now" on 2026-11-12). Handed to the faster-halation session (it has the model and the
  code). The debug log part of test 1: not reported yet.
- **v0.30.3 test 2 on the camera (owner, 2026-11-17; `5a7f6896…`, built on feature/faster-halation 2a2104d = this line +
  h8):** CADLOG "nothing unusual"; 36 shutter events, 16 log writes (releases only); a 13-frame sequential burst
  (PB162917..929, Kodachrome 64, in ~1.5 s) whose release wrote nothing (the burst rule), then the next release did.
  Halation photos: PB162916 (5), PB162930 (3). The look of the fade: the owner's call (pending).
  Test 1 on the camera: event 16, 8 writes (releases only).
- **Camera-tested (owner, 2026-11-17): test 2 "Looks good"** (the longer halo fade). With test 1's "much quicker" and the
  debug log seen working, test 2 (`5a7f6896…`, feature/faster-halation 2a2104d) is the v0.30.3 candidate.

## Halation h8: a longer, even fade (2026-11-17; emulator only, camera test pending; branch feature/faster-halation)
Owner on v0.30.3 test 1: "the halation at 5 kinda just ends. I want a smoother taper." A deliberate look change: no
longer bit-exact with v0.30.x; the model and the camera code still agree bit for bit.
- **Why it ended (analysis, model on the owner's test 1 lamp photo PB162914, halo taken out again approximately):**
  near the light the curve u = 255 v / (v + 900) is saturated (g ~200 at 5 over the shade), then g falls 189 -> 116 ->
  8 within ~400 px. The tail is the broad layer's: 10 [1 2 1] passes are a Gaussian (sigma ~2.2 cells, ~143 px), whose
  log falls faster the farther out it is, so once v drops near K the glow stops within one or two cells. All
  strengths share this shape (g = u gmax >> 8); at 5 the drop is the largest.
- **h8:** a wide layer, the broad one blurred `BLUR3` = 30 more times (40 in all, sigma ~4.5 cells), added at `WIDE` =
  64 / 256: v = v0 + ((wide 64 + 128) >> 8), v0 = the h4 mix as before. The bright-frame count (u(v0) >= 32: off at 24 %,
  faded from 8 %) stays on v0, so the bright-frame rule decides as before (a dark frame with very little light may now show a
  faint glow where all g were <= 1). Tried in the model (3 + 10 + 30 / 40 / 60
  passes, mixed or added, 1/4 or 1/2): "add 40 at 1/4" keeps test 1's halo near the light and turns the stop into a
  roughly even fall (about x0.7 per cell). Big lamp (r 300 px), Cr gain by 64 px at 5: test 1 47 46 45 42 35 23 11 3 0;
  h8 47 46 45 43 40 35 29 22 16 11 7 4 2 1 (strengths 1-4 the same shape, scaled). Private preview on the owner's
  photo: `test-builds/2026-11-17-v0303-test2/preview-test1-vs-test2.jpg`.
- **Code:** firmware/halation.py `BLUR3`, `WIDE` (+ an overflow assert); model.py `blur` -> (v0, v), `u_of`; editor.s
  hl_run: the count loop keeps no u, then (after the off check, so daylight frames skip it) `hl_blur` 30 more passes on
  the broad copy and a curve loop on v (32-bit, up to ~70 K, hl_hi's index clamped as before). No new malloc, frame
  unchanged, ext12 252 456 of 262 144 B. LookLab's preview (preview.ts `om3Halation`) does the same in floats; Blue
  hour at 5: mean R +2.8 (h4 +2.5).
- **om-emu (pin 0819080):** emu_check.py 21 of 21 frames bit-exact with the new model. Steps (h7 -> h8; v0.30.2 =
  v0.30.1's): big5 20 MP 84.1 M -> 124.4 M (v0.30.2 230.4 M), bigphoto5 85.3 -> 103.7 M (186.0 M), night5 16.8 ->
  22.7 M (35.3), bluehour5 20.9 -> 25.7 M (47.0), taxi3 10.3 -> 13.8 M (28.3), sparse5 16.6 -> 21.5 M (42.5). The extra
  blur is ~2.6 M on 20 MP; the rest is pass C on the larger glowing area (big5 changes 6.0 MB, was 3.9 MB). Max under
  one lock <= 105 K as before. Camera-only: the look, the real save time.
- **Package v0.30.3 test 2** (commit 20f4107 = try/v0.30.3 merged in + h8; the full suite, 24 tests, passes on it, incl.
  `halation-matches-the-model` against the new model): build "v0.30.3-dev (test 2: halation fades out more slowly)" (52
  characters), E1479999.BIN `5a7f6896…033c`; `test-builds/2026-11-17-v0303-test2`, go-back v0.30.2 `7fbd3957…445b`.
  Camera test: the test 1 lamp scene at Halation 5 and 3, the fade compared with test 1's photos, the save time counted.
## Faster looks (2026-11-16; feature/look-perf; emulator only)
Goal: a look costs less per development and per save, with the same output. om-emu instruction counts, repeatable
run to run (an ncall of the camera's RGB stage 0x60516ad9, then our tone hook, on a fake COLOR job; the stage's own
10,568 left out).
- **Where the time went (v0.30):** st_run's pass over the 960 table entries, one channel at a time: no look 252, split
  toning 46,405, one curved channel 70,803, three curves + split toning 119,207. Blacks / Whites (`tone`, ext5)
  ~11,400 with values set, 123 without: left as it is. cv_set's rebuild per pass is ~700 (under 1 %): no cache.
- **st_all (ext12):** the R, G and B tables are identical before the pass (st_run's gate), so the balance, the weights
  and the Hermite basis depend on t only: worked out once per entry, then each channel's own K and block (macro STC,
  unrolled; one path per pass: split toning + curves, split toning only, curves only). Counts: split toning 36,905
  (-20 %), one curve 44,776 (-37 %), three curves + split toning 71,947 (-40 %). Tables byte-identical to v0.30 in
  all cases.
- **sd_crc (ext4, every CRC: films block, sets, curves record, CURVES.BIN, BUNDLES.BIN):** a nibble at a time from a
  16-word table (`sd_nib`, 64 B) instead of a bit at a time: 3,336 bytes (the curves record, cv_hdr at each save, interrupts
  on) 180,260 -> 56,719. Same CRC-32 as zlib. A 256-word table would be ~1.7x faster again but is 1 KB: ext4 has 520 B
  left, and ext12's other callers' timing was not checked.
- Test `look-tables-match-the-model` (emu_test.py): the three paths' tables against a Python model (split toning as
  research/splittone/model.py bend28, curves as research/rgbcurves/model.py, both parts' running max), and sd_crc
  against zlib. Passes on v0.30 and on this branch.
- Not known: whether any of this is visible on the camera (no camera timing exists).
- **Dropped dial clicks on the RGB and Mix pages (camera, user):** a fast turn skipped values, while H&S counted
  every click. Two causes. First, `cv_ev` cut the event's signed click count (a1) to +-1. It now moves by the whole
  count, clamped to +-`CV_CLK`. Test `rgb-page-counts-every-click` catches the old build. Second, `cv_draw` cost
  ~3.63M instructions per redraw: each row tested all 300 columns of all three curves. It now keeps each row's
  column range per curve (`CW_XR`, work area 0x8000..0x9000) and scans only that range. The run encoder got a
  tighter loop. Counts: 3.63M -> 1.06M (flat curves), Mix page 1.34M -> 1.00M. Streams byte-identical over 61
  curve, color, and point states. Camera-tested 2026-11-16 (user, build `5ebd047`): fast turns no longer skip values.
- Camera, 2026-11-16 (user, build `5ebd047`): burst, start-up, and video OK. The card log for that power-on (9
  photos on FILM 10 Velvia 50, then M video) says "nothing unusual". Save and reload: curve and mix edits kept
  through a power cycle (user), and the films block read valid at the next power-on (generation 367).

## v0.30.3 test 3: test 2 + PR #69 (2026-11-17; emulator only)
Owner: "lets intigrate pr#69 in the build. I want to test it out first but it looks good". `try/v0.30.3` = this line +
`feature/faster-halation` (h8, test 2) + PR #69 (crombach, head 7b0cc80: every dial click on the RGB / Mix pages,
faster st_all / cv_draw / sd_crc), merged as written. Conflicts: emu_test.py (both kept; the --only / names lists hold
HALATION, ENGINE and DIAL), NOTES (both kept). cad's read of #69: no hook; `sd_crc` now uses d2 (saved by its
`call [d2,d3],12` frame, as d3 was) and keeps a1 on its own stack word; `st_run` uses ~88 B more stack (#69's note:
burst and video passed on crombach's camera). Build "v0.30.3-dev (test 3: test 2 + PR #69, faster looks.)" (52
characters), E1479999.BIN `53cd002b…459a`, rebuilt byte for byte; suite 26 of 26 (incl. look-tables-match-the-model,
rgb-page-counts-every-click, halation-matches-the-model). Package `test-builds/2026-11-17-v0303-test3`.
- **Camera-tested (owner, 2026-11-17): test 3 "it all works well"** (`53cd002b…`). CADLOG after a power cycle (2 events):
  "nothing unusual", films block valid at power-on (generation 370), saved; COLOR 1 (FILM 1 Portra 400) kept its
  changed mix (7 7 -1 -1 -1 0, "following its film's built-in: mix no") and curve over the power-off (#69's save and
  reload). New photos PB162931..934 (Velvia 50, CineStill 800T, Portra 400). Test 3 is the v0.30.3 candidate.
- **v0.30.3 release (2026-11-17; owner: "yes. merge the pr and release 30.3"):** `firmware/VERSION` "v0.30.3 (faster
  halation + PR #69, camera-tested t3)", 52 characters: main.bin differs from test 3 only in the name, the code-block
  tag (twice) and the built-in GUIDES CRC (53 bytes). E1479999.BIN 60b6d954…f546; `patch.py --release v0.30.3` makes it
  byte for byte, `--release v0.30.2` still 7fbd3957…. Extras as v0.30.2. LookLab rebuilt (h8's preview). PR #69 lands
  on main with this merge (its head 7b0cc80 is in the history).

## Issue #64: the wheel's dial label names the page (2026-11-16; feature/dial-label-per-page; camera-tested)
- Owner on #64: "I like these changes, if you make a pr with them, I'll merge". This replaces the sp1 request (2026-11-09)
  that the dial label stay the camera's "Vivid" on Shadows / Highlights.
- The label ("Vivid", VDESC 0xa4cf688c, 70 x 30) now reads Sat (Color and Color All), Hue, Lum, and Tint (Shadows and Highlights).
  LABELS.BIN goes from 27 to 31 labels (indices 27..30, after the Extras ones). `xb_va` (xblock.s) maps the axis to
  the label, 0xff = the stock picture (Film).
- The label code only ran on axes 1..4: ed_get calls vl_s only there, and the Shadows / Highlights readout is
  tn_get's, which skipped it (the sp1 request). ed_get now also calls vl_s on axis 0, with the entry's d0 / d1 kept
  for the stock path. tn_get calls it on its readout.
- Emulator: VDESC +12 per page = Sat 796, Hue 996, Lum 1092, Tint 1028 (each = mklabels encode11
  length). Test `color-wheel-dial-label-follows-the-page`. On v0.30's code every page keeps the stock 1660.
- Leaving the wheel keeps the last label in VDESC (Sat after the usual exit from Color), as the Extras labels did
  since v0.20. Whether another camera screen draws that picture: camera test.
- Follow-up (2026-11-16, emulator only). The guides on Saturation were the camera's: "Color All [INFO]" with one colour,
  "Color Select [INFO]" with all colours. They name what INFO does next, while ours name the page, so they read swapped.
  - **One Saturation page (crombach, camera, on the look-perf test build):** the front dial already reaches ALL, so
    the INFO stop on ALL repeated it. INFO with a single color now goes straight to Hue (k_6b -> k_step). INFO with ALL
    on is unchanged: the stock handler turns ALL off, then k_step. This differs from the release: the owner's call on
    the PR.
  - **Back to the camera's INFO (crombach, 2026-11-16, PR #70 review):** on stock firmware both the front dial (after
    Yellow-green) and INFO (it toggles ALL) reach Color All (om-emu, unmodified firmware). So k_6b again lets stock INFO
    turn ALL on from a single color, as in v0.30.3. The dial label stays Sat and both guides "Saturation [INFO]".
  - **Guides.** gd_s0 puts film test 8's "Saturation [INFO]" (P+SATB) in both Saturation guides: GDESC (single color)
    and SDESC 0xa49edf88 (ALL), the latter with its width set to 175. gd_sel puts SDESC back to the camera's, at width
    180, before every gd_set.
  - **Dial label.** "Sat" in both states: "Saturation" would squeeze to 42 % in the 62 px label. "Highlt" (squeezed to
    74 %) read jammed on the camera, so it is now "Hilite" (56 px, no squeeze). "Shadow" (62 px) read crammed next to
    the dial icon (crombach, camera, PR #70). Both split-tone pages now read "Tint" (44 px), the value the rear dial
    sets, as Sat, Hue and Lum do. The guide below already names the page.
  - **Half-press.** ed_trig calls vl_s after its page reset, so the label reads "Sat" right away.
  - **W_SALL.** Its SDESC code would now share the descriptor with gd_s0's. Re-enabling it needs a look at both.
  - **Pictures live in the heap.** A test build that pointed a picture's descriptor into .ext12 (0x60f9…) blanked the
    rest of the camera's menu (camera, crombach, 2026-11-16, the swatch work on feature/color-wheel-swatches). Every
    picture of ours that the camera has shown points into the heap (0xa2…). om-emu draws from either address, so no
    emulator test catches this.
  - **Camera (crombach, 2026-11-16, build b023e44e…): the menu works, but the wheel showed a moment late when moving
    down onto it.** om-emu instruction counts on that step (a copy of session_ed1.mjs that adds `insns` to WATCH hits,
    ed_get's first to last hit): v0.30.3 1 761 445, this build 3 379 421. The extra 1.62 M is xb_rend drawing "Sat"
    (vl_s). xb_lc caches one label, so each INFO step to a new page cost the same, and so did a half-press after
    leaving the wheel off Saturation. Now build.py encodes the five wheel labels (mklabels.render, encode11: the same
    sizes as xb_rend's, per the label tests) into wl_tab. xb_vl points VDESC at them, with no drawing. Step after:
    1 761 614.
  - **Where the pictures live.** wl_tab sits in .ext13 (.ext12 had no room). fl_mk copies it into a heap block of its
    own, wl_blk. It could not join the P+SATB block: an 18 KB block made malloc return 0 in om-emu, and the Saturation
    pictures went with it. xb_vl gets wl_blk's address from build.py (WL_BLK).
  - **Build note.** A `.set` that uses a films.inc size before films.inc is included works in editor.s's own code.
    But nm prints a wrong value for it, so a value handed to the code block must be set after films.inc.
  - **Camera (crombach, 2026-11-16, E1479999.BIN 90283858…): no issues.** Labels, the one Saturation page, the guides,
    the half-press reset, editing on each page, photos and video all worked. No screen showed "Sat" in place of
    "Vivid". The wheel opens as fast as on v0.30.3 (om-emu: 1 762 023 instructions on that step, v0.30.3 1 761 853).
    The swatch work moved to feature/color-wheel-swatches, its own PR.
  - Tests:
    - `color-wheel-dial-label-follows-the-page` (INFO from Saturation to ALL, then Hue)
    - `color-wheel-dial-label-resets-with-the-page`
    - `color-wheel-saturation-guide-names-the-page`
    - `color-wheel-front-dial-skips-all-colors-off-saturation`
  - **Camera (crombach, 2026-11-16, E1479999.BIN 6cef8303…): works, performance good.** The camera's INFO, Tint on both
    tone pages and the stack fix. crombach: "Color All is useless on the tint wheels, so we should remove it. Probably
    same for hue and luminance."
  - **The front dial skips all colors off Saturation (2026-11-16, emulator only).** The front dial reaches the wheel as
    the left / right events 0x9008 / 0x900a, through the record hooks ed_l / ed_r (EDLR). The cursor runs 1, 255, 12,
    11 .. 2, 1 (255 = all colors, 2197 + k). On every page but Saturation, EDLR now calls the stock handler, reads the
    cursor (k_ad), and calls it once more when it landed on 255. The dial widget steps both times, so its index and
    the cursor agree. No new hook. Arrow keys take the same path. Driver token `expect:val:ID=V` reads a setting
    through the getter (`getv`, shared with `vals`). The read is k_cur (2197 + k only): from slices 1 and 12 the dial
    sets 255 there, while k_ad also reads 2201 + k.
  - **"Sat. All [INFO]" on all colors (crombach, 2026-11-16, emulator only).** crombach: "When on Sat. All, whether accessed
    via the dial or the INFO button, the label at the bottom (next to the info button) should say Sat. All". gd_s0 now
    puts mkguides "Sat. All" (175 x 50, 3516 B) in SDESC; GDESC keeps "Saturation [INFO]". The picture lives in .ext13
    (fl_sagd in wheel.inc: .ext11 had 1.7 KB too little), and fl_mk copies it to P+SATB + SAT_AG with ub_cpy, so
    gd_sel's range check on the block still finds it. Screenshots (om-emu): the guide reads "Sat. All" after the dial
    and after INFO.
  - **Review fixes (2026-11-16).** ed_trig calls vl_s with d2 = -1 at the half-press: xb_vl puts the camera's "Vivid"
    back in VDESC (it kept Sat for other screens), and the wheel draws Sat when it opens. xb_vl needs LABELS.BIN
    (xb_lb) only to draw a label, not for wl_blk's. fl_mk allocates wl_blk last, after LV_BLK and SP_BLK, and copies
    the P+SATB pictures and wl_tab with ub_cpy (a word at a time, was a byte). Test
    `color-wheel-tone-readout-keeps-the-callers-a2` (keep: on tn_get to t_ret) catches tn_get without its return slot.
  - **Leaving with MENU or OK** keeps the last label in VDESC until the next half-press: neither reaches an editor
    record handler (ed_info, ed_l, ed_r, ed_event, gd_set; the stock words +8..+40 not hit in om-emu). Hooking the
    draw instead: the only VDESC read is 0x610eaf8c, the camera's picture routine for every descriptor on every screen
    (GDESC goes through it too), so not used.
  - **Camera (crombach, 2026-11-16, E1479999.BIN ec545b42…, GUIDES.BIN e433434b…): "Testing is good."** The front
    dial skips Color All off Saturation, "Sat. All [INFO]" from the dial and from INFO, no wheel label on the other
    screens after MENU / OK, the half-press reset, photos, video and films.

## #68: our looks for photos only, video and S&Q stock (2026-11-16; camera-tested; branch feature/video-curves-68)
Issue #68: in video, `st_run` skipped `cv_set` but still ran when the look had split toning, and read `cv_pp`, which
still held the last photo pass's curve blocks. crombach: none of the custom settings are meant for video or S&Q.
- **`st_run`:** `mx_photo` right after the COLOR key gate, so video and S&Q (mode code 10, or switch position 1 / 0
  while the code is 0) leave the tables stock. Split toning, Tone Balance and RGB curves are now photos only. Before
  this, split toning reached video (since v0.26, see "Split toning"). `cv_set` now runs on every pass that gets that far.
- **`s_lv` (live view / movie request flags):** `mx_photo` first, so video and S&Q get no Glow or Art Effect flag.
  The body moved to `.ext11` as `s_lv6`, because `.ext2` had 7 B too few. The v0.24-era changelog line "Movies
  recorded with such a look get the effect too" no longer holds.
- **Unchanged:** Colour Mix (already `mx_photo`), grain and halation (stills only). Films still reach video through the
  COLOR block the camera keeps. Keeping them out means writes at the photo-to-video switch, the path behind #53.
- **B:** `mx_photo` has no `MC_B` check, unlike `ss_photo`. On the camera B reads code 0 and the switch gives photo,
  so B keeps its looks. In om-emu B reads 62 and would count as video. Analysis only.
- Test `video-keeps-the-stock-tables` (emu_test.py): the fake COLOR job of `look-tables-match-the-model`, a photo
  pass then a video pass (rc_in's mode code 10) of a look with split toning and curves. The video tables must equal
  the camera's. On upstream main (v0.30.3) it is `caught` (entry 1: 145, camera 78). Suite 27 of 27 on the fix. The
  Glow gate has no om-emu test: the live view request path is camera-only.
- Camera check: video and S&Q with a look that has split toning, curves and Glow, after a photo in the same power-on.
  The image must look stock. Photos in P / A / S / M / B and a custom mode must keep the full look.
- **Camera, first try (crombach, 2026-11-16; build `bdfe521e…abf3`, GUIDES `0df6729b…86ed`, on top of
  `feature/dial-label-per-page`): one quick reboot** while switching films in the Picture Mode menu. The screen went
  black and the shutter closed, then it came back. crombach: it looks like the v0.30 test 12 reboot ("Test 12 camera,
  first report", and "Reboot when resetting many films before a half-press"). The card's CADLOG.TXT was still the
  15:32 one from v0.30.3: no release came after the flash. Cause unknown. It is not tied to this branch yet.
- **Reproduced (crombach, camera, 2026-11-16):** scroll through the films in the Picture Mode menu with the right
  arrow, held or pressed quickly, until the camera reboots. It happens every time. No film reset or edited, only the
  films' defaults. Moving between films is much slower than between COLOR profiles with no film (a leak? guess). The
  CADLOG after it has only the next power-on (the log is written at a release). Its films with changes read
  "none", where the 15:32 log had 3. crombach says no film was reset, so how they were cleared is not known.
- om-emu (P, the Picture Mode list, `right` with no waits): 60 and 120 presses are clean ("nothing unusual") on this
  build. At 300 the om-emu node process is killed (exit -9, no log, about 1.4 GB). The same happens on upstream main
  (v0.30.3 code), so the stop is not from this branch. Whether it is om-emu's own memory or the camera's code is not
  known.
- **Also on the v0.30.3 release (crombach, camera, 2026-11-16; `60b6d954…f546` from `patch.py --release v0.30.3`):
  the same scrolling reboots it.** So it is older than this branch. Filed as #72. The #68 build is back on the card
  for the video test.
- **Camera-tested (crombach, 2026-11-16; on `feature/dial-label-per-page` c430a40, E1479999.BIN `3beac2ce…`, GUIDES.BIN
  `56e88eeb…`): "Looks good. I didn't run into any issues, and the video and S&Q look normal."** Video and S&Q
  stay stock. Photos keep their looks.
- **A movie from the photo position (crombach, camera, 2026-11-16): stock.** A button mapped to recording in the photo
  Button Function menu starts a movie with the switch at photo (CB161282.MOV; CADLOG: M, mode code 0, switch 2). It
  "looked stock". So the photo position's movie gets none of our looks. Why is not known: the camera may change the
  mode code while it records, or that movie's frames may not reach `st_run` / `s_lv6` as a COLOR job. That part is
  a guess. No recording flag is needed for now.

## #75: Picture Mode closes after 30 s idle, not 8 s (2026-11-17; experiment/film-page-timeout; fix camera-tested)

- **Timer:** the camera's software timers sit in a table at `0x6036f984`, 10 entries of 28 B: +0 active, +4 start
  time, +20 event id, +24 duration in ms. `call 0x612970e8` starts one, with d0 = event id and d1 = ms. Menus share
  id 500 at 8000 ms, armed from 89 sites. The super control panel uses id 510, also 8000 ms.
- **Patch:** `PM_IDLE_SITES` in `firmware/build.py` changes `mov 8000,d1` (`2d 40 1f`) to `mov 30000,d1`
  (`2d 30 75`). The sites are all 9 id-500 arms in Picture Mode's code, `0x611c20ad..0x611c3cc2`. The immediate is
  signed 16-bit, so a byte patch gives 32767 ms at most. No hook, nothing at start-up.
- **Which code is which screen (emulator):** a factory table at `0x615025d8` pairs screen classes with screen ids.
  `0x611c20ad` (id 0x3d) builds Picture Mode. The next one, `0x611c3cc2` (id 0x3c, vtable `0x6153734c`), builds the
  white balance screen `ID_ST_DIRECT_WB`, opened from the super control panel with `right` then `ok`.
- **Picture Mode's 9 sites (emulator):** open `0x611c2243`, up `0x611c22ae`, down `0x611c232d`, left `0x611c2481`,
  right `0x611c25dc`, rear dial `0x611c274b`, front dial `0x611c28ac`, INFO `0x611c29ef`, and a touch `0x611c3b20`. A
  touch arrives as message 0x9755: `0x611c2a0b` looks it up in `0x61536e2c` and calls `0x611c33bd`, which re-arms
  the timer at `0x611c3b20`. A tap on a COLOR tab reaches it.
- **Touch gave 8 s (emulator; fixed by `.hook_tch` below):** after `0x611c3b20` arms 30 s, the shared touch code re-arms id 500 at
  8000 ms from `0x612a8db3`. It takes the id and time from a record at `0x62cf5e14`, which `0x612ae7a1` fills with
  500 and 8000. That function is the third entry of a vtable at `0x61639130` that all touch screens share, so
  patching it would change every screen's time after a touch. A Picture Mode-only fix would need a hook. Not done:
  the owner's call. The `0x611c3b20` patch stays, so a future fix only has to deal with the shared re-arm.
- **Camera (crombach, build f05229b, `E1479999.BIN` 18fe2e4e...):** passed. Picture Mode and its rows stay open about
  30 s after the last input, and each key or dial turn starts the 30 s again. The super control panel still closes
  after 8 s. Sleep, start-up, a photo with a film, and a short video work as before. Other menus were not checked.
- **Review of f05229b (2026-11-17, emulator):** that build patched 12 sites. It missed `up` and touch in Picture Mode,
  so Picture Mode still closed 8 s after either. Its other 5 sites, `0x611c3e79`, `0x611c3f2b`, `0x611c4001`,
  `0x611c40dd` and `0x611c41fb`, are the white balance screen's down, left, right and dial handlers, so that screen
  stayed open 30 s after them but 8 s after it opened or after `up`. The fix patches `0x611c22ae` and `0x611c3b20`
  and gives the white balance screen back all 7 of its stock 8000 ms arms. `up` now gives 30 s. A touch still gives
  8 s, as above. The camera test of f05229b did not try `up`, a touch, or the white balance screen. The fixed build
  is not camera-tested.
- **Camera (crombach, 2026-11-17, build f05229b): the white balance bug is confirmed.** With no key pressed, the white
  balance screen closed after 8 s. After `down`, it stayed open about 30 s.
- **Camera (crombach, 2026-11-17, build ed2523c5..., the fix without a touch hook): a touch gives 8 s.** A tap on a
  COLOR tab in Picture Mode closed it after 8 s, as the emulator showed. Wanted: 30 s.
- **Touch hook `.hook_tch` (2026-11-17; camera-tested, see below):** the hook replaces
  `call 0x612970e8,[d2,d3],12` at `0x612a8db3` (stock bytes `dd35e3feffc00c`). It calls `s_tch` in `.ext11`, 47 B, in
  the same frame. When d0 is 500, d1 is 8000 and the GUI state is 0x0418, d1 becomes 30000. The GUI state is the two
  bytes at the pointer `0x603713a4`, read as `fl_pm` does. Then it jumps to `0x612970e8`. Every other screen keeps
  the stock time, and nothing runs at start-up.
- **Touch hook in the emulator:** a tap on the COLOR 2 tab keeps Picture Mode open about 20 s, and it closes by about
  32 s. A tap on the super control panel goes through the hook with its time unchanged, since it is not id 500 at
  8000. The panel closes after 8 s. Taps on the white balance screen and on several panel sub-screens never reached
  the shared re-arm, so no other id-500 touch screen was tried.
- **Which touch screens re-arm id 500 (analysis, then emulator):** of the 35 touch layouts in the table at
  `0x6161e164`, only layout 28 (vtable `0x61639130`, so not shared by all touch screens as guessed above) re-arms
  id 500, through `0x612ae7a1`. Only Picture Mode opened it. A tap on the function screen (panel, `up`, `ok`)
  reaches `s_tch` with id 512 at 8000 ms, left as it is: test `function-screen-touch-keeps-8-s`.
- **Camera (crombach, 2026-11-17, build 9b8a861a...): passed.** A tap and every key, `up` included, give Picture
  Mode 30 s. Other touch menus and a screen opened from Picture Mode close after 8 s. The white balance screen closes
  8 s after `down`. Photo, video, sleep and start-up work as before.

## ISO Auto key: a button function that switches the photo ISO between Auto and the last manual value
- 2026-11-17 / 18, ryanbughuang (branch `feature/iso-auto-key`). **Camera-tested** on the contributor's OM-3 (the
  function: camera test packages 3 and 5; its own Button Function entry: package 8), as test builds laid onto the
  released v0.30.3 (`research/isoauto/layer.py`). The build of this branch itself is emulator-tested only.
- **Wish:** one press takes a manual ISO to Auto; with the dial it has to be turned all the way down. A second press
  brings the manual value back.
- **The settings (om-emu, read through sget; then the camera):** **1701 is the photo ISO as the user sets it** (0
  Auto, else Sv x 256; ISO 100 = 1280, ISO 200 = 1536): the super control panel's ISO cell writes it (facade
  SetValue(1701, mode 1 = one step up)). **6 is the value in use and follows 1701** (the debug log's "ISO" is 6);
  4002 is the ISO the metering uses (ISO 200 with Auto in om-emu). A first test wrote 6: 1701 stayed at Auto, and on
  the camera the change showed only after a half-press and release. Reading and writing 1701 changes the ISO at the
  press (camera-tested). As dial function codes 1701 is WB and 1578 ISO; as settings 1578 is the WB mode.
- **Facade SetValue's mode (static, `0x60b8781f`):** 1 one step up (`0x60bb5473`), 2 one step down (`0x60bb5423`),
  3 (`0x60bb53d3`, not looked at), anything else sets the value given through the settings manager. The button
  module's own setter `0x61085d05` (`call ..,[d2,a2],20`, d0 id, d1 value; `ar_setv`) uses mode 0, its getter is
  `0x61085dbb` (`ar_getv`).
- **Where a function runs:** the dispatcher `0x61083022` is called from 86 places (each state's press and release
  handlers) and several times per press (om-emu, Delete in P live view: 3 calls with the press event 0x01000026, 6
  with the release 0x01000027). There is no single stock point that runs an action once. The touch / key exclusivity
  check `0x61084d48` calls the dispatcher only under conditions.
- **The hook:** `.hook_ia` at `0x61083041`, the dispatcher's key table walk (`call 0x610830c9,[d2,d3,a2,a3],20`, d0 =
  d3 = the event). `ia_key` runs the stock walk, then `ia_do` reads the key's function through the stock value read
  `0x610833b3` (so `ar_get`'s arrow-pad rule holds). When it is ours and the event is a press (event table
  `0x612f3100`, 20 B records, +8: 0 press, 1 release, 2 long, 3 repeat), it acts, and the walk answers 3200 ("no
  key"), so the dispatcher returns 0 and no stock function runs. Only with the photo / movie switch on photo
  (`0xa32d9d0d` = 2) and the GUI on a COMMON screen (`0x62ce5864` low byte 1).
- **One act per key event:** `.hook_dl` (the event walk's end, `0x610ba015`) goes to `ia_dl` first, which notes the
  event and sets `ia_new` when it differs from the event walked before, then goes on to `dl_look`. `ia_do` acts only
  when the press is the event being handled and `ia_new` is set, and clears it. (A first version acted on the first
  press event after a release event had reached the dispatcher; on the camera a second press of a key was not always
  taken.)
- **The last manual value** is kept in RAM (`ia_last`); with none yet (after a power-on), Auto goes to ISO 200.
- **Its own Button Function entry:** function code **3910** (the camera's own end below 3500; the Creative Dial
  rows use 3900..3904). It is not in the function table `0x612f20a8`. The photo buttons' lists, read from the v0.30.3
  image:
  - Validator lists: Fn 47 and Delete 570 share `0x60615432`; REC 48, |o| 1292, CP 49 and AF-ON 1964 each have a list
    of their own with the same 50 codes; L-Fn 56 has 51 (`0x60615a5c`, + 3209); the arrows 50 to 53 share `ar_list`
    (48). Three different code lists, so three copies with the new code before Off (3200): the choice screen's grid
    follows the validator list, so it shows last, before Off.
  - The rows' value labels (item records behind `0x61569064`, 28 B, +12 list and +16 count): `0x615685d4` (50; Fn,
    REC, |o|, CP, AF-ON, Delete), `0x6156882c` (51; L-Fn), `ar_lab` (48; the arrows). Entries `{code, id << 16 | type,
    object}`, type 4 a string, 0xc a picture; the object word is the same through a list.
  - The choice screen: 11 of the 32 variants at `0x61571ba0` (24 B `{key, n, titles, cells, help, ?}`) hold the photo
    Fn lists `(55, 0x61570e08, 0x61571288, 0x61571708)`: titles and help are strings, cells strings or pictures.
  `firmware/isoauto.py` `menu_tables(m, o, sy)` makes the copies in space at the end of ext13 (`ia_v0..2`, `ia_l0..2`,
  `ia_pt / ia_pc / ia_ph`) from the image's own lists, for each function in its `FUNCS`, and points the records at
  them. Strings ST_IAC + 0..2 (0x7f0a..: cell "ISO Auto", title "ISO Auto / Manual", two lines of help) through
  `ia_str`, which `.hook_str` reaches before `st_get`. The movie Button Function is untouched.
- **Space:** at the end of ext13, after the debug log and the wheel labels (about 4.9 KB with the list copies); the
  loader's end word follows ext13's end as build.py already does it, inside the GX4-proven reserve (0x60fb8000 in
  this branch's build; the test builds on v0.30.3 had the code from `0x60fb4d00`).
- **Rebased 2026-11-18** onto main at e32363a (PRs #70, #73, #76). The camera tests above were made before that, on
  v0.30.3; on the new main the build is emulator-tested only.
- **tools/test/hooks.json:** the new patch sites are added by hand as whole fields (the validator records' list and
  length words of the 11 photo buttons, the 11 variants' count and three list words). `static_check.py --write-hooks`
  on a macOS build narrows other entries whose first byte happens to match stock there, so it was not used.
- **Emulator tests (om-emu 0819080):** `iso-auto-key-switches-auto-and-manual` (Delete stands for the button, with
  `ia_code` poked to the value om-emu's Delete reads: Auto -> ISO 200 -> Auto -> ISO 200, two presses in a row end
  where they started, five presses make five switches) and `iso-auto-key-from-the-button-function-menu` (Delete is
  given ISO Auto in the menu, no poke; two presses switch the ISO and back).
- **Camera (contributor's OM-3):** the ISO changes at the press and the next press brings the manual value back; the
  entry shows in the Button Function lists with its name and help, and the row reads "ISO Auto".
- **Test builds on a release:** a local macOS build renders Caduceus' own pictures differently from the release, so
  `research/isoauto/layer.py` writes only this change into a release's package: the code at the end of ext13, the
  hook, the two jumps (`.hook_dl`, `.hook_str`) with the release's own `dl_look` / `st_get` addresses, and the lists
  made again from the release's.
- **After flashing / going back:** before going back to a firmware without the entry, set a button that holds ISO
  Auto to something else (a value outside a list stays stored).
- **Not done / not known:** the movie Button Function; the last manual value is not kept per custom mode or over a
  power-off; B (Auto may be refused there).

## WB lock key: a button function that holds Auto WB, on the screen and in the photo
- 2026-11-17 / 18, ryanbughuang (branch `feature/wb-lock-key`, on top of `feature/iso-auto-key`). **Camera-tested**
  on the contributor's OM-3 as test builds laid onto the released v0.30.3 (`research/isoauto/layer.py`), packages 5
  to 10 in the work log below. This branch's build, on main at e32363a, is emulator-tested; its camera test is noted
  at the end of this section.
- **What it does:** a button set to "WB Lock" holds Auto WB where it is now; the next press lets it go. While it
  holds, the shooting screen reads "WB Lock" under the Picture Mode label. Only with Auto WB, in the photo modes.
- **How, in short** (the sections after this one are the work in the order it was done, with every address):
  - Live view: the camera's own hold in the live view WB task (queue word `0x6004362c`): message 10 takes a snapshot of
    the Auto WB result, message 11 ends it, sent with the synchronous send `0x6004f3bd` from the key's code.
  - The photo: the capture module settles a photo's WB gains (R / G / G / B, G = 128; the photo's WB_RBLevels are
    twice these; live view's gains are in the same units) in two set-ups. `.hook_wd` at `0x60545933` (single shots,
    burst, AE BKT, Live GND) and `.hook_wd2` at `0x60545b1c` (the twin set-up: High Res, Live ND, focus stacking):
    with Auto WB and the hold on, R and B become the snapshot's. A third set-up (a task loop, the call at
    `0x60545514`) has no hook: every mode tried on the camera takes the hold without it (test package 11).
  - The sign: `.hook_wi` at the end of the shooting screen's WB display update (`0x6118cc4d`) shows the WB icon widget
    on its "WB Auto" choice, and `.hook_ic` answers that picture (11223) with ours, drawn as the "FILM n" label is
    (`firmware/isoauto.py` `lock_picture`). The key writes the shooting screen's record back (data store item 38) so
    the screen draws at the press.
  - Only with Auto WB: the key starts a hold only when the WB mode (1578) is Auto, and the WB display update ends a
    hold when it runs with another mode.
  - The Button Function entry: function code 3911, a second entry in `firmware/isoauto.py` `FUNCS`.
- **Camera results in one place:** the hold on the LCD, in the viewfinder and the INFO styles; the photo's JPEG, its
  WB_RBLevels and the ORF; single shots, burst (normal and SH2), AE BKT, High Res (hand-held), Live ND, Live GND; the
  Button Function entry; the "WB Lock" sign; no effect with a preset; a hold ended when the WB mode leaves Auto.
  **With this branch's code (test package 11, 2026-11-18):** HDR1, High Res on a tripod, focus bracketing, focus
  stacking (the frames and the composite), multiple exposure, Live Composite, Live Time and Bulb take the hold; the
  hold stays over the mode dial's turn to B and over sleep and wake. Details: "WB lock in the multi-shot modes".
  **A film with its own WB during a hold (test package 11):** picked in the Picture Mode screen, a film with Custom
  WB brings it and the hold ends; at a Creative Dial turn into COLOR the film's WB does not come and the hold stays
  (the film WB's own behaviour, not the hold's: see "WB lock in the multi-shot modes").
- **Not tried (camera):** interval shooting with this branch's code (it took the hold in test package 10); HDR2;
  mode changes other than to B and the Creative Dial during a hold.
- **Names:** the symbols are `wk_` / `WK_` (main has `wl_tab` / `wl_blk` for the wheel labels). The work log below
  still says `wl_code`, `wl_n` and so on for them, and speaks of a ring of noted captures (`wd_ring`) and a file
  `WBDIAG.BIN` with its reader `wbdiag.py`: those were in the test builds only and are not in this branch.

### The WB lock key's work log (in the order it was done; "test N" = camera test package N)
The two mixed sections also cover the ISO Auto key's early tests.

## WB lock key (feature/iso-auto-toggle), test 2
- 2026-11-17, ryanbughuang. Static analysis and emulator; no camera test yet. The emulator runs no Auto WB, so
  whether the hold works is a camera question.
- **Wish:** a press stops Auto WB where it is; the next press lets it go again.
- **The live view WB task (static):** task loop `0x6048bb26`, queue word `0x6004362c`, context `0xa32e9238`. Each
  message is `{reply queue, task, id, parameter}`; id at context +272 (`0xa32e9348`), state word +276
  (`0xa32e934c`: 0 stopped, 1 running, 2 One-touch WB, 3 holding), one handler table per state (`0x6065c890` stopped,
  `0x6065c8bc` running, `0x6065c8e8` One-touch, `0x6065c914` holding; 11 entries each).
- **Auto WB's result:** `0xa32e9308..` (context +208): +0 / +2 / +4 three words (meaning not known; +4 is a light
  source index below 14), **+8 / +10 the R and B gains** (`0xa32e9310` / `..12`), +12 / +14 two more gains, +16.. the
  nine colour matrix words (`0xa32e9320`), then a second set. Written by the running state's update handler
  `0x6048c55e` (data key 33057 = the WB mode: 0 / 4 Auto) from the calculation `0x6048d6f8`. `0x6048bc0f` copies the
  gains out (the WB gain provider `0x603c2b3b`, request mode 4 / 6; `stb_expose_get_wb_gain` is one caller).
- **The camera has its own hold.** Message 10 (running state, `0x6048c4c0`; parameter byte 0 = take a new snapshot,
  1 = keep the one there is): `0x6048c7c8` copies the result (gains, matrix, the evaluation words `0xa32e9368..`) to a
  snapshot at `0xa32e9400..`, sets the hold byte `0xa32e93fe` = 1 and the state to 3. While the hold byte is 1 (or 3)
  the task's getters answer with the snapshot: `0x6048bca9` (gains and matrix for a request; caller `0x6047d6dd`) and
  `0x6048bfd6` (the evaluation words; three callers in the capture set-up at `0x605311be..`). A stop and a start of
  live view keep it (the start handler `0x6048c316` goes back to state 3 when the hold byte is 1). Message 11
  (`0x6048cc74`) ends it: hold byte 3, state 1, and the next update makes it 2. The snapshot needs a valid result
  (`0xa32e938c` non-zero).
- **Who uses it in stock:** command handlers 45 (`0x603c8f5d`, sends 10) and 46 (`0x603c8fda`, sends 11) of the
  command table `0x6031e224` (dispatcher `0x603178e4`, 93 commands), guarded by bit 0x80000 of that module's state
  word. Which camera feature sends commands 45 / 46 is **not found** (a multi-shot mode is the guess). A stock message
  10 during our hold is refused by the holding state (handler `0x6048c3f7`), so its bit stays clear and it sends no 11.
- **Test 2:** a second function in `ia_do` (same hook, same one-act-per-press rule, photo switch and COMMON screens
  only): `wl_code` = 404 (ART BKT, borrowed as Test Picture is for ISO Auto). Hold byte 1 -> message 11; else, only
  when the state word is 1, message 10 with parameter 0. Sent with the generic synchronous send `0x6004f3bd` (d0
  queue, d1 id, a0 parameter; it makes its own reply queue, so any task may call it) and it waits for the answer.
- **Emulator:** the WB task is stopped there (state 0, hold byte 0, no valid result). Test
  `wb-lock-key-sends-the-hold-message`: a press sends nothing while the state is 0; with the state word poked to 1 the
  press sends message 10 and returns. The suite passes (28 tests).
- **Camera test package 2** (ISO Auto key + WB lock key on the released v0.30.3): 304 B at `0x60fb4d00` and the 5-byte
  hook; sha256 `1546ad63…da94`.
- **Not known (camera):** whether a photo taken during the hold has the held white balance. The capture works its own
  Auto WB out from the captured frame (`rec_cam_get_awb_exec` `0x6054a39e`, from `rec_precon_wb_exec`); the hold reaches
  the capture set-up through `0x6048bfd6` only. Whether the waiting send can stall the button task. Whether sleep, a
  mode change or video ends the hold. There is no sign on the screen that the hold is on.
- **If photos do not follow the hold:** next candidates are the capture's own Auto WB (hook where it stores its
  gains) or a One-touch WB slot written with the held values (store `0x603c3120`, data keys 52290.. per slot; it keeps
  two chromaticity-like words, not gains, so the values need converting).

## ISO Auto key and WB lock key, camera test 2 and test 3 (feature/iso-auto-toggle)
- 2026-11-17, ryanbughuang.
- **Camera (test package 2, `1546ad63…`; camera-tested):** the ISO Auto key changes the ISO only after a half-press
  and release. The WB lock key holds Auto WB (the picture stops following the light), but a second press does not let
  it go, and picking another WB mode then changes nothing on the screen. No freeze: the waiting send returns.
- **ISO, the cause (emulator):** there are two settings. **1701 is the photo ISO as the user sets it** (the super
  control panel's ISO cell writes it: facade SetValue(1701, mode 1 = one step up)); **6 is the value in use and follows
  1701**. Read through sget in om-emu: a panel change moves both; test 1's write to 6 left 1701 at Auto. 4002 is the
  ISO the metering uses (ISO 200 with Auto in om-emu). The debug log's "ISO" is 6. (The dial function code 1701 is WB
  and 1578 ISO; as settings 1578 is the WB mode and 1701 this ISO.) Test 3 reads and writes 1701 through the same
  getter / setter: in om-emu 6 and 1701 change together at the press.
- **Facade SetValue's mode (static, `0x60b8781f`):** 1 one step up (`0x60bb5473`), 2 one step down (`0x60bb5423`),
  3 (`0x60bb53d3`, not looked at), anything else sets the value given through the settings manager.
- **WB, what the second press may have met (analysis, not proven):** read statically, message 11 in the holding state
  (`0x6048cc74`) puts the Auto WB filters back at the held gains (`0x6048e1c8`), sets the hold byte to 3 and the state
  to 1; the getters keep answering with the snapshot while the byte is 3, and the next periodic update in the running
  state (messages 4 and 5, posted by the task's own two timers) makes it 2. Nothing found there that would keep the
  hold. So either the second press sent nothing, or the press was acted on twice (11, then 10 again). Tests 1 and 2
  acted on the first press event after a release event had reached the dispatcher; whether every button's release
  reaches it on the camera is not known.
- **Test 3, one act per key event:** `.hook_dl` (the event walk's end, `0x610ba015`) now goes to `ia_dl` first, which
  notes the event and sets `ia_new` when it differs from the event walked before, then goes on to `dl_look`. `ia_do`
  acts on a press only when it is the event being handled and `ia_new` is set. After message 11 it also makes the hold
  byte 2 itself when the task left it at 3. A hold is ended when the hold byte is 1 or the state is 3.
- **Emulator:** ISO test extended (two presses in a row end where they started; five presses, five switches). The
  suite passes (28 tests); the same tokens pass on the camera test image.
- **Camera test package 3:** `research/isoauto/layer.py` also moves the release's `.hook_dl` jump to `ia_dl` and gives
  `ia_dln` the release's own `dl_look` address (0x60f67e85 in v0.30.3). 368 B at `0x60fb4d00`; sha256 `1db34dc7…c865`.
- **Still not known (camera):** whether a photo taken during the hold has the held white balance; why the second
  press did nothing in test 2.

## WB lock key, camera test 3 and test 4 (the capture's WB; feature/iso-auto-toggle)
- 2026-11-17, ryanbughuang.
- **Camera (test package 3, `1db34dc7…`; camera-tested):** the ISO Auto key works (the ISO changes at the press).
  The WB lock key holds live view's Auto WB, but **a photo taken during the hold is not held**: the capture works its
  white balance out again.
- **The capture's WB (static):**
  - `rec_cam_get_awb_exec` (`0x6054a39e`) only fetches the capture's Auto WB picture (a 28160 B thumbnail, through the
    CAM capture `0x6054a902`); the calculation is inside the image processor library (`0x61a2…`), reached from the WB
    set-up `0x60546b11(parameters, request)`.
  - The shooting parameters (`0x603e8c12..`) take the WB type from data key **33057** (parameters +37644: 0 Auto,
    1 preset with its index from key 33073 at +37640, 2 One-touch with the slot at +37766, 3 Custom WB with the Kelvin
    at +37642, 4 not known) through the data getter `0x60063380`.
  - **Where the gains meet: `0x60545933`** (function around `0x605456f0`, a3 = the parameters). The usual path builds a
    request and calls `0x60546b11`; the gains come back at (132 / 134 / 136 / 138,sp) (copied on as R, G, G, B). A second
    path skips the image processor's Auto WB and uses stored gains: type 0 and (byte +7632 set, or +6140 non-zero with
    byte +40717 set): the four words at +6512 (or +6334 when byte +38227 is 1), each halved, with (172,sp) = 8 and
    (182,sp) = 3120 (3840). Which camera feature sets +7632 is not known (frames after the first of a multi-shot
    sequence is the guess).
  - The capture set-up `0x60531173` hands live view's Auto WB to the capture (parameters +660: the gains through the
    provider's mode 4, i.e. `0x6048bc0f`, and the evaluation words through `0x6048bfd6`): a starting point, not the
    result.
  - `0x6055dc..`: for some capture kinds the non-Auto gains are kept as ratios to a reference (the provider's mode 0,
    select 8): `(gain << 7) / reference` at parameters +37462 (R) and +37468 (B), 128 = 1.0.
- **What is missing:** how live view's gains (`0xa32e9310`, the provider's units) relate to the gains at
  `0x60545933` and to the stored words at +6512. Only the camera can say: om-emu takes no photo.
- **Test 4 is a measurement build.** `.hook_wd` at `0x60545933` (8 bytes) -> `wd_cap` notes each capture in a ring
  of four (WB type, the stored-gains byte, the hold byte, the four gains, (172,sp), (182,sp), the words at +6512 and
  +6334): reads and our own RAM only. Every press of the WB lock key then writes `OM3MOD/WBDIAG.BIN` (720 B: our
  variables and the ring, then the WB task's context `0xa32e9228..0xa32e9460`) with the stock file calls
  (`OS_FOPEN`, `fwrite`, `OS_FCLOSE`). `research/isoauto/wbdiag.py` reads it. The lock itself is as test 3.
- **Emulator:** the file is written at a press (720 B); the suite passes (28 tests); the same tokens pass on the
  camera test image. The capture hook cannot run there.
- **Camera test package 4:** 784 B at `0x60fb4d00`, so the loader's end word goes from 0x60fb5000 to 0x60fb6000
  (inside the GX4-proven reserve, as build.py does it); hooks `0x61083041`, `0x60545933`, `.hook_dl`. sha256
  `54531cf4…b79e`.

## WB lock key, camera test 4 (measured) and test 5 (the photo is locked too)
- 2026-11-17, ryanbughuang.
- **Camera (test package 4, `54531cf4…`; camera-tested):** the second press ends the hold now (live view follows the
  light again); no stall or freeze at a press, with the file write. `WBDIAG.BIN` and the photos PB170057..60 (kept
  privately):

  | Photo | Scene | Hold byte | Gains at `0x60545933` R / G / G / B | (182,sp) | Photo's WB_RBLevels |
  |---|---|---|---|---|---|
  | PB170057 | warm light | 1 (held) | 324 / 128 / 128 / 173 | 1792 | 648 346 256 256 |
  | PB170058 | warm light | 2 (let go) | 318 / 128 / 128 / 179 | 1792 | 636 358 256 256 |
  | PB170059 | cool light | 1 (held at the warm light) | 229 / 128 / 128 / 344 | 1024 | 458 688 256 256 |

  The snapshot of that hold: gains R 318, B 181 (G 128, 128); the second pair R 324, B 176. Live at the file write:
  318 / 181 and 281 / 266.
- **So:** `.hook_wd` runs once per photo; the gains there are the ones the photo gets (**WB_RBLevels = 2 x them**);
  **live view's Auto WB gains are in the same units** (G = 128) and within about 2 % of what the capture works out
  for the same scene; during a hold the capture still works its own out (PB170059). The stored-gains words at +6512
  were 0 and the byte +7632 was 0 in all three. (182,sp) changes with the light (1792 warm, 1024 cool); what it is
  for is not known.
- **Test 5:** in `wd_cap`, with WB type 0 or 4 and the hold byte 1, the R and B words at (132,sp) / (138,sp) become
  the snapshot's first pair (`0xa32e9400` / `..02`, the one `0x6048bca9` gives live view as its gains). The G words,
  (172,sp) and (182,sp) stay as the camera worked them out. The ring now keeps the gains as used, as worked out, the
  snapshot's and whether the lock replaced them; the file is still written at each press.
- **Emulator:** the suite passes (28 tests); the capture hook cannot run there. Camera test package 5: 832 B at
  `0x60fb4d00`; sha256 `a6b1871f…35ae`.
- **Not known (camera):** whether the photo then matches the screen (the image processor's other Auto WB results,
  such as whatever (182,sp) selects, still follow the scene); whether the RAW file's recorded WB levels follow (they
  may be written from the image processor's own result); burst, bracketing, High Res and the other multi-shot modes;
  video (the key does nothing there).

## WB lock key, camera test 5: the photo is locked (camera-tested)
- 2026-11-17, ryanbughuang. Camera test package 5 (`a6b1871f…`), `WBDIAG.BIN` and photos PB170072..76 (kept privately).
- **Result:** a photo taken during the hold has the held white balance, in the JPEG, in its WB_RBLevels and in the
  RAW file's levels. The second press ends it; photos after that are worked out by the camera again.

  | Photo | Hold | Worked out R / B | Used R / B | WB_RBLevels | JPEG mean R/G, B/G |
  |---|---|---|---|---|---|
  | PB170072 | off | 229 / 344 | 229 / 344 | 458 688 | 1.01, 0.94 |
  | PB170073 | off | 230 / 344 | 230 / 344 | 460 688 | 1.02, 0.92 |
  | PB170074 | on (held under the first light) | 312 / 182 | **229 / 348** | 458 696 | 0.71, 1.32 (blue, as the screen) |
  | PB170075 | on (held under the second light) | 230 / 344 | **306 / 187** | 612 374 | 1.33, 0.41 (orange, as the screen) |
  | PB170076 | off | (after the file) | | 460 688 | 1.02, 0.94 |

- So the gains at `0x60545933` are what the JPEG, the EXIF levels and the ORF take; replacing R and B there is enough
  for the photo to match the screen (owner of the camera: "looks right"). The G words, (172,sp) and (182,sp) were
  left as the camera worked them out ((182,sp) 1792 / 1024 as before, by the scene).
- Correction to the test 4 table above: "warm" and "cool" there are the user's two lights in the order they were
  used; by the gains, R 324 / B 173 is the bluer light and R 229 / B 344 the redder one.
- `research/isoauto/wbdiag.py` fixed (it read 12 of the ring's 14 words).
- **Open:** burst, bracketing, High Res and the other multi-shot modes; video (the key does nothing there); sleep and
  mode changes during a hold; no sign on the screen that the hold is on; the borrowed function codes (Test Picture,
  ART BKT) instead of menu entries of their own; the measurement file is still written at each press.

## ISO Auto key and WB lock key, test 6: their own Button Function entries
- 2026-11-17, ryanbughuang. Emulator only for the menu; the two functions themselves are camera-tested (tests 3 and 5).
- **Function codes:** ISO Auto 3910, WB lock 3911 (the camera's own end below 3500; ours for the Creative Dial rows
  are 3900..3904). Neither is in the function table `0x612f20a8`, and `ia_do` answers "no key" for them, so no stock
  function runs. Test Picture and ART BKT are the camera's own again.
- **The photo buttons' lists (read from the v0.30.3 image):**
  - Validator lists: Fn 47 and Delete 570 share `0x60615432`; REC 48, |o| 1292, CP 49 and AF-ON 1964 each have a list
    of their own with the same 50 codes; L-Fn 56 has 51 (`0x60615a5c`, + 3209); the arrows 50 to 53 share `ar_list`
    (48). Three different code lists, so three copies with the two codes before Off (3200): the choice screen's grid
    follows the validator list, so they show last, before Off.
  - The rows' value labels (item records behind `0x61569064`, 28 B, +12 list and +16 count): `0x615685d4` (50; Fn,
    REC, |o|, CP, AF-ON, Delete), `0x6156882c` (51; L-Fn), `ar_lab` (48; the arrows). Entries `{code, id << 16 | type,
    object}`, type 4 a string, 0xc a picture; the object word is the same through a list.
  - The choice screen: 11 of the 32 variants at `0x61571ba0` (24 B `{key, n, titles, cells, help, ?}`) hold the photo
    Fn lists `(55, 0x61570e08, 0x61571288, 0x61571708)`: titles and help are strings, cells strings or pictures.
- **Build:** `firmware/isoauto.py` `menu_tables(m, o, sy)` makes the copies in space at the end of ext13 (`ia_v0..2`,
  `ia_l0..2`, `ia_pt / ia_pc / ia_ph`) from the image's own lists and points the records at them; build.py calls it,
  and `research/isoauto/layer.py` runs it again on the release image. Strings ST_IAC + 0..5 (0x7f0a..0x7f0f: cell,
  title, help of each) through `ia_str`, which `.hook_str` reaches before `st_get` (as `.hook_dl` and `dl_look`).
- **Emulator:** the Fn and Delete choice screens show "Test, ISO Auto, WB Lock, Off" on the last page, with the
  titles "ISO Auto / Manual" and "Auto WB Lock" and two lines of help each; the row reads "Fn : ISO Auto". New test
  `iso-auto-key-from-the-button-function-menu`: Delete is given ISO Auto in the menu, with no poke, and two presses
  switch the ISO and back. The suite passes (29 tests); the same steps pass on the camera test image.
- **tools/test/hooks.json:** the new patch sites are added by hand as whole fields (the validator records' list and
  length words of the 11 photo buttons, the 11 variants' count and three list words). `static_check.py --write-hooks`
  on a macOS build narrows other entries whose first byte happens to match stock there, so it was not used.
- **Measurement file:** no longer written (the ring of the last four captures stays in RAM).
- **Camera test package 6:** 5488 B at `0x60fb4d00`, loader end word 0x60fb7000; sha256 `a7c7be03…d65a`.
- **After flashing:** a button that was on Test Picture or ART BKT does that stock function again; pick ISO Auto /
  WB Lock for it. Going back to a firmware without these entries: set those buttons to something else first (a value
  outside a list stays stored).
- **Not done:** the movie Button Function (the two functions are photo only); a sign on the screen for the hold.

## WB lock key, test 7: a sign on the shooting screen
- 2026-11-17, ryanbughuang. Emulator only (the screen); the lock itself is camera-tested (test 5).
- **The shooting screen's WB display (static + om-emu):** function `0x6118cc4d` (three callers in the information
  view's update, `0x6118bf89 / 0x6118c08c / 0x6118c0c2`) shows the WB icon and, for a preset or Custom WB, the Kelvin
  as text; with Auto WB every widget of it is hidden (om-emu: nothing drawn; a preset draws pictures 12722 / 13718 and
  the digits). Widgets at its (16 / 24 / 28 / 32 / 36 / 52,sp); the Kelvin text is (52,sp): `"%dK"` (UTF-16) formatted
  by `0x610fc42c`, set with `0x610d7e31(widget, text)`, placed with `0x6128adf3(widget, x, 0)` (x 135 after an icon,
  98 without) and shown / hidden with `0x6128abbc(widget, 1 / 0)`, the function's last call (`0x6118cc43`).
- **The sign:** `.hook_wi` takes that last call (7 bytes) -> `wi_lv`: when the Kelvin text is hidden and the hold
  byte is 1, the widget gets our text at x 98 and is shown.
- **Its font is small:** only A B F K L M, the digits and `- + * / . : [ ]` draw (om-emu; anything else is a filled
  block, and K L M are small capitals). So the sign reads **"A-L"** (Auto WB locked, as AEL / AFL), not "AWB Lock".
- **Making it show at the press:** the information view updates its items when the camera writes the shooting
  screen's record, data store item 38 (464 B; the camera does at an ISO change, and `lv_end` uses the same for the
  Picture Mode label). The screen runs on the GUI task, the key dispatcher on another (om-emu: different stack
  roots), so the key code does not touch the widgets: after its message it reads item 38 and writes it back
  (`ds_get` / `ds_put`), and the GUI task draws. Tried and not enough (om-emu): the WB mode (1578) written with its
  own value, Custom WB Kelvin (107) moved a step and back, item 31 written back.
- **Emulator:** with the hold byte set, a press of the key puts "A-L" under the Picture Mode label at once, and with it
  cleared the next press takes it away; test `wb-lock-key-sends-the-hold-message` now also checks it (wi_n). The suite
  passes (29 tests); the same on the camera test image, with WB Lock chosen for Delete in the menu.
- **Camera test package 7:** 6096 B at `0x60fb4d00`; hooks `0x61083041`, `0x60545933`, `0x6118cc43`, `.hook_dl`,
  `.hook_str`; loader end word 0x60fb7000; sha256 `50b65e14…a6e1`.
- **Not known (camera):** the viewfinder and the other information styles (INFO); whether the sign stays right
  through a photo, playback and back, and a mode change; the sign with a preset WB (the hold has no effect then, and
  no sign shows: the Kelvin is there).

## WB lock sign: "ABL" (test 8)
- 2026-11-17, ryanbughuang. Emulator only.
- The user asked for "wb-L", or "ABL" / "AWL". The Kelvin text's font has no lower case at all and no W (om-emu:
  a to z and W draw as blocks), so the sign is **"ABL"** (the L is one of the font's small capitals). Nothing else
  changed from test 7. The suite passes (29 tests). Camera test package 8: sha256 `4e80d135…39b0`.

## WB lock sign as a picture, "WB Lock"; the lock only with Auto WB (test 9)
- 2026-11-18, ryanbughuang. Emulator only for the screen and the Auto-only rule.
- **Camera (test package 8, `4e80d135…`; camera-tested):** the Button Function entries ("ISO Auto", "WB Lock") and the
  "ABL" sign work. The user: "ABL" is ugly; wants "WB Lock", made the way the author makes text.
- **How the author puts text on the shooting screen:** as pictures. `firmware/mkicons.py` draws the words with DejaVu
  Sans Condensed in the camera's label style (palette 10 fill, 7 / 8 / 9 edge, 11 / 12 soft; `_lv_glyph`: cap 24,
  baseline 33, squeezed 0.8), `encode11` packs an OSD type-11 stream, and the picture lookup hook (`.hook_ic`,
  `0x610f5611`: id -> a slot holding a `<6H3I>` descriptor {14, w, h, 8, 0, 0, length, uncached address, 0}) answers
  the camera's own id with it ("COLOR k", 15706.., -> "FILM n": `fl_lvp`).
- **Why "ABL" looked as it did:** the Kelvin text is drawn from pictures, one per character (16 x 30: the digits 104..,
  K 13718, 12722 / 12725 / 12726 the digits 3 / 6 / 7 ...); only A B F K L M, the digits and a few signs exist.
- **The WB display's pictures (om-emu dumps):** the icon widget at (32,sp) of `0x6118cc4d` shows 11223 "WB Auto"
  (86 x 44), 11224 / 11229 / 11234 / 11235 One-touch 1 to 4, 11230 underwater (76 x 44); 56 x 44: 11233 sunny, 11231
  shade, 11232 flash, 11236 CWB, 11237 cloudy, 11238 incandescent, 11239 fluorescent. Choice 0 is "WB Auto", which the
  LCD's shooting screen never shows with Auto WB (the widget is hidden; the lookup still runs).
- **Test 9:** `wi_lv` (with the hold on and Auto WB) sets that widget to choice 0, places it (`0x6128b45f(widget, 0)`)
  and shows it, and sets `wi_on`; `wi_ic` (`.hook_ic`, before `cv_ic`) answers 11223 with our picture while `wi_on`
  is set. The picture: `firmware/isoauto.py` `lock_picture`, "WB" and "Lock" 4 px apart in `_lv_glyph`'s style, 86 x 44.
  The widget shows 86 px and cuts a wider picture on its left (a first 104 px one read "/B Lock"), so the words are
  squeezed to 0.66.
- **Only with Auto WB:** the key starts a hold only when the WB mode (setting 1578) is Auto; `wi_lv` ends a hold
  (message 11, sent from the GUI task) when the WB display is updated with another mode. Before: live view kept the
  held gains under a preset too (the task's getter answers with the snapshot whatever the mode), while the photo took
  the preset's (`wd_cap` acts on type 0 / 4 only).
- **Emulator:** "WB Lock" under the Picture Mode label, in its lettering, at the press; gone at the next; a preset
  shows its own icon and Kelvin. New test `wb-lock-only-with-auto-wb`. The suite passes (30 tests); the same on the
  camera test image. Camera test package 9: 9312 B at `0x60fb4d00`, loader end word 0x60fb8000; hooks as test 7 plus
  `.hook_ic`; sha256 `af86bc0d…82ec`.
- **Camera (2026-11-18): package 9 works** (the sign, the viewfinder and INFO styles, the Auto-only rule: see the
  summary section above). Not known: the hold ending when a film brings its own WB mode.

## WB lock in the multi-shot modes (camera tests 9 and 10)
- 2026-11-18, ryanbughuang.
- **Camera, test package 9 (`af86bc0d…`):** during a hold, burst (normal and SH2) and AE BKT photos take the held
  white balance; **High Res and Live ND do not**.
- **Why (static):** the capture module has three WB set-ups that call the image processor's WB (`0x60546b11`):
  1. `0x605456a6..`, gains at (132 / 134 / 136 / 138,sp), met at `0x60545933` (`.hook_wd`, since test 4);
  2. its twin `0x605459a5..` (one caller, `0x6054b08a`), gains at (136 / 138 / 140 / 142,sp), met at `0x60545b1c`;
  3. a task loop around `0x60545326..`: after the call at `0x60545514` the gains at (200 / 202 / 204 / 206,sp) are
     stored into the capture's parameters at +37608 (R), +37610 (B), +37612, +37614, with +37632 = 1.
- **Test 10** (`test/wb-lock-composite`, package `8964b53c…`): the same lock at 2 (`.hook_wd2`, `0x60545b1c`, 7
  bytes, stock `f8 bc 88 fa 93 a8 01`) and 3 (`.hook_wd3`, `0x60545522`, 6 bytes, stock `82 f8 bd c8 80 01`), the ring
  of noted captures grown to 16 with the set-up's number, and the measurement file written at a press again.
- **Camera, test package 10: High Res, Live ND and Live GND photos take the held white balance** (the contributor).
- **Which set-up each mode uses** (a second run of package 10, `WBDIAG.BIN` and PB180023..25, kept privately; held at
  R 334 / B 208, the scene worked out as about R 262 / B 256):

  | Photo | Mode (StackedImage) | Set-up | Worked out R / B | Used R / B | WB_RBLevels |
  |---|---|---|---|---|---|
  | PB180023 | High Res, hand-held, 5760 x 4320 (11 12) | **2** | 264 / 254 | 334 / 208 | 668 416 |
  | PB180024 | Live ND (3 2) | **2** | 260 / 256 | 334 / 208 | 668 416 |
  | PB180025 | Live GND (0 0) | **1** | 262 / 256 | 334 / 208 | 668 416 |

  All three JPEGs have the same cast (mean R/G 1.30, B/G 0.75). So High Res and Live ND go through the twin set-up
  (`0x60545b1c`), which is why package 9 missed them; Live GND goes through the first, as single shots, burst and AE
  BKT do. **Set-up 3 (`0x60545522`) was not used by any mode tried**: its hook has no camera evidence and does not
  go into `feature/wb-lock-key`.
- **Done in `feature/wb-lock-key` (2026-11-18):** `.hook_wd2` is in, the ring and the file write are out, the branch
  is on main at e32363a and its symbols are `wk_`. Emulator-tested; the camera test of that build is in the summary
  section.
- **Camera, test package 10 again, the other modes** (the contributor; judged from the photos' WB_RBLevels and
  colour, the files kept privately): held at R 337 / B 212 under one light and shot under another (Auto WB there:
  R 244 / B 334, WB_RBLevels 488 668, neutral), every photo read 674 424 and has the held cast: HDR1 (5 4), High
  Res on a tripod (8 8), focus bracketing (two runs, 24 and 25 frames), Live Composite (1 n), Live Time (4 n), Bulb,
  interval shooting (3 frames), focus stacking (9 n: the frames and the composite). The measurement file kept one
  capture only, because the camera was switched off and on during the run: **focus stacking, set-up 2**. Which set-up
  the others use was not measured.
- **Camera, test package 11 (`b07f0780…`) = this branch's code** (`feature/wb-lock-key`, two hooks, no hook at set-up
  3, no measurement), the contributor, 2026-11-18. Held under the first light (WB_RBLevels 668 428, later 674 424
  after a new hold), shot under the second:

  | Photos | Mode (StackedImage) | WB_RBLevels | Colour |
  |---|---|---|---|
  | PB180121..146 | Focus bracketing, 26 frames | 668 428 | held |
  | PB180147 | HDR1 (5 4) | 668 428 | held |
  | PB180148 | High Res on a tripod (8 8) | 674 424 | held |
  | PB180149 | Live Composite (1 13) | 674 424 | held |
  | PB180150 | Live Time (4 6) | 674 424 | held |
  | PB180151..152 | Bulb | 674 424 | held |
  | PB180153..163 | Focus stacking, 10 frames and the composite (9 10) | 674 424 | held |
  | PB180120 | Multiple exposure, hold on | 256 256 | held |
  | PB180164 | Multiple exposure, no hold | 256 256 | neutral |

  **So no mode tried needs the hook at set-up 3.** A multiple exposure's file reads WB_RBLevels 256 256 with and
  without the hold (the camera's own way, it seems), so that mode is judged by colour alone: the held cast with the
  hold, neutral without. The hold stayed over the mode dial's turn to B (Live Composite read the same levels as the
  shot before it) and over sleep and wake (the sign was still there). `WBDIAG.BIN` on the card kept its old time:
  package 11 writes no file.
- **A film that brings its own WB during a hold** (camera, package 11, the contributor; om-emu, this branch's build):
  - Picked in the Picture Mode screen, from a film on Auto WB to a film that keeps Custom WB: the film's WB comes and
    the hold ends (camera). om-emu the same with a film that keeps Sunny: "WB Lock" on COLOR 1, then FILM 2 with
    Sunny 5300K and no sign.
  - **A Creative Dial turn into COLOR, to a film that keeps Custom WB: the screen still reads "WB Lock", the WB stays
    Auto and the film has its `*`** (camera). om-emu (a temporary `inject:1906=V` token in the test driver, as
    `tools/emulator/sess7.mjs` has it; FILM 2 keeps CWB 5400K; a turn to ART, WB set to Auto by hand, a turn back to
    COLOR): the WB stays Auto **with the hold and without it**. So the film's WB does not come at a dial turn back
    into COLOR, hold or no hold (emulator only for "without"; `fw_apply` runs from `fl_set` after a change of look or
    COLOR), and the hold stays because the WB mode is still Auto. Not the key's doing; left as it is.
- **Not tried:** interval shooting with package 11 (held in package 10); HDR2; what set-up 3 is for.
