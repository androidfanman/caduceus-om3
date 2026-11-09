# OM-3 1.1 (build 1100) firmware port — working notes

All addresses: OM-3 runtime (decoded main + 0x60021020). E-P7 1.1 base 0x60020020.
Stock: OLY_E_147_1100_0000_0000_3.BIN sha 8c133084…696d, main 5e8d376e…7d59.

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
- om-emu (github.com/flatpanda/om-emu, Node 26); modelcheck needs --no-port.
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
  Emulator (session_ed1.mjs IMAGE = out-ed16/main.bin, EMU = an om-emu checkout; new token `vals` reads the
  18 settings x 4 through the getter; snap shows lptr/lidx): switching saves/loads all 18 + slot (incl. +-7, +-2, -5),
  COLOR2 separate, write-back after S-page-only edits, save/reload with sel, bad CRC ignored, recipe bank loads exactly.
  Negative dial values show as -1..-5 but mean 0. Look Lab artifact seq 12: profiles UI, PROFILES.BIN export (sel 0) and
  import (replaces); older LOOKS/BUNDLES import as wheel-only profiles.
- Test 16b (out-ed16, pkg sha 4894d1f9...): Profiles dial limited to 0..5. The dial's value list is rebuilt from facade
  count (+28 word 0x60e57490, stock 0x60b86e09) and value-by-index (+32 word 0x60e57494, stock 0x60b87031) at every
  children refresh (editor open, each INFO page change; seen with WATCH). pf_cnt (ext10) / pf_vbi (ext8) return 6 /
  index 0..5 for the 12 o'clock id when AXIS 4 (shared check pf_is, ext1, macro PROFID); else stock. Emulator: stops at
  0 and 5, Saturation page still -5..5. Camera: test 16 confirmed working before this change.

## Control Panel (webapp/)

- `webapp/` is cakelesscoder/caduceus-ep7's `webapp/` at de53ffe plus an OM-3 mode, so both cameras share one tool.
  A camera switch sits above the header (`?camera=om3|ep7`, then localStorage `caduceus.camera`, then the build
  default `VITE_DEFAULT_CAMERA`; this repo builds with `om3`, upstream's default stays `ep7`). E-P7 mode is upstream
  unchanged: its LOOKS.BIN export is byte-identical to releases/v0.24 and all upstream tests pass with this webapp in
  an upstream checkout (they read `../bundles`, `../tools`, `../releases`, so outside that tree they fail).
- OM-3 additions: `src/om3.ts` (bank 4 x 5 positional, `toOm3` conversion, `profilesBin` / `readProfiles`,
  validation, first-visit bank of 20 library looks, `fromOldLookLab` for localStorage `om3-looklab` of the old
  single-page Look Lab), `src/om3names.ts` (NAMES.BIN, ported 1:1 from the old Look Lab, font `public/fonts/
  om3label.woff2` as a file because the CSP forbids data: fonts), `src/preview.ts` (`camera: 'om3'`: hue negated,
  no grain / effect, unsharp + shading from Sharpness / Shading), `src/pack.ts` (`advice.sharpness`), and the OM-3
  section of `src/main.ts`. Storage: `caduceus.om3.bank.v1`. Links: `ob1_` bank, `op1_` one profile
  (base64url(deflate(JSON))). Names: 15 characters (OM3_NAME_MAX).
- `tests/om3.test.ts`: PROFILES.BIN round trip and byte check against `card/mkprofiles.py`. Emulator check
  (out-ed18): a Control Panel PROFILES.BIN + NAMES.BIN load; Profiles 1 and 2 show descriptors of 2604 / 2188 B, the
  NAMES.BIN entry lengths, and load the profile's wheels.
- Pages: `looklab/` is the build (`cd webapp && npm ci && VITE_DEFAULT_CAMERA=om3 npm run build`, copy `dist/*`).

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
  zero padding. Masks are exact binary rectangles (not 8-aligned). New layers (firmware/frames.py): white outside the
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

## v0.20 release (repo)
- Sources: `firmware/src/editor.s` / `editor.ld` (= test 7 sources), `firmware/src/xblock.s` (the code block),
  `firmware/frames.py` (white frame layers), `card/mklabels.py` (LABELS.BIN v2), `card/mkguides.py` (pages Hue, Light,
  Extras, Film). `firmware/build.py` builds DCOLYMP + GUIDES.BIN (+ block) + LABELS.BIN, byte-identical to
  releases/v0.20 (pkg 6eb202d3…, GUIDES ea1b9009…, LABELS 4fdee1ff…).
- `tools/mkpatch.py` writes patch.json format `om3-patch-2`: main-image runs (gap-16 merge, 46 runs / 7540 B), plus
  `frames` {component 2, base, layers} that `firmware/patch.py` regenerates (region-only decode, checksum moved by the
  word-sum delta), plus `card_files`. Older patch.json files (format 1) build unchanged.


## v0.21 release (repo)
- Build: `firmware/build.py` makes pkg 9c423edb…, GUIDES.BIN d991fecd… (block relinked against this firmware: always
  pair them), LABELS.BIN 73a28cb9… (24 labels: + "Vig Cam", "Vig Off", "Grain"); releases/v0.21 patch.json 62 runs /
  7613 B. All three are the camera-tested files.
- Extras slices 8 VigFix (slot +52, record +50, 0..1) and 9 Grain (slot +53, record +51, 0..3); `xt_tab` holds each
  slice's slot byte and range. Shading Comp. (key 0x8c21) reads go through s_nr → block +32 (VigFix: 1 → 0).
- Grain, camera route (`xb_dev` at the s_cl hook 0x604955f1): on the COLOR still development request (kind 0, +14
  0x1000, +10 11) with Grain 1..3 and no Glow/Clarity/Art: request +1751 = level, +10 = 12 and context +48 = 12 (both
  needed), the stock MONO grain pass. The tone hook's gate accepts key 12 when +1731 == 0 (MONO has 0xa0), so
  Blacks / Whites still apply; WB / NR / VigFix are unaffected.
- Grain, CPU route (block +56, `xb_gs`, after the Soft Focus blend setup) only when Glow/Clarity or an Art Effect is
  on: luma-only, `research/grain/model.py` bit-exact, through the bus window per row, ~3 s per photo. Its loops run
  from the block's cached alias; only code without PC-relative calls into the firmware may (relocations assume the
  uncached address).
- Lessons: `fb`-prefixed AM33 forms (e.g. `movbu (d8,An),Am`, `movhu (d8,An),Am`) misbehave on the camera and fault
  in om-emu: use data registers (the build should show 0 `fb` opcodes in the block). Hooks on the capture / AE / WB
  paths stay in flash (a block-resident wb_get rebooted at half-press). Dial list answers (facade +28 / +32, `pf_cnt` /
  `pf_vbi` → block +96 / +104 through cached trampolines) must be frameless leaves: deeper frames restarted the camera
  on switching to COLOR.
- Looks: `lk_hold` (ed_event) → block +88 `xb_lkh`: event 0x903e on the Film page with a look selected → `pf_cap`
  (save), 0xf881 (OK held on "COLOR n") → LIDX 0 + reset; every reset goes through `xb_rpre`, which re-reads children
  1..12 with AXIS 0 first (the Film / Extras dial lists clamped the stock reset's values: COLOR4 12 o'clock −4 → 0).
- `*`: `ed_pmod` = stock loop through `ed_isd0` (factory compare on every page; `ed_isdef` itself still says
  "default" on the Film page so no Reset guide shows there). Film 0 = `pf_dflt`: the stock GetDefault 0x60b86e44
  (not facade +156, which `ed_default` answers 0 on non-Saturation pages).
- AWB fine-tune keys 7401/7433 (A-B) and 7417/7449 (G-M) added to `wb_get` (capture branch 0x60457d22 / 0x60457ae4,
  population 0x618e6610..).

## v0.22 Sharp (branch v022-sharp)
- Extras slice 10 Sharp: slot +54, record +52, −5..+2 (`xt_tab` .byte 54,-5,2; `pf_bt` 52→30 of the slot block;
  `pf_lo[52]` −5; label mode 3 in `xb_vt`: −5 → "Sharp Off", labels 24/25, LABELS.BIN n 26).
- Capture: the stills Sharpness read 0x603e767f (`call getter`, d0 0x8119, sid 7; result halfword → capture +37648)
  goes through `s_nr` (`.hook_sh`) → block +32 `xb_nr`: for a COLOR 1–4 still the slot's Sharp, −5 sent as −7. The
  value feeds the gain helper ~0x60513d10 (index = class base 4..7 + sharp, clamped 0..10: −7 → index 0 for every
  class) and the other copies of +37648 (0x6054fbfa, 0x60553d33, 0x60560da1, 0x604569c7); the readers seen clamp or
  map it. Camera test 1: Off clearly softer than 0, +2 crisper, fine with quick grain.
- Stock row: the Picture Mode column builder 0x611bd814 switches on the picture mode through the table at 0x61533520
  (key mode + 1); COLOR 1–4 (54/55/56/64) went to 0x611bd8fd (`mov 0x61530758,a3` then the shared `mov 6,d0`).
  Their four table words now point at `pm_color` (ext8: same list, 5 rows), and the list's last two words are
  swapped at build time (`DATA` in build.py) to [111, 5397, 5398, 5399, 8 Contrast, 7 Sharpness], so item 7
  (Sharpness) drops off. The hold-OK reset list (0x61536324 table, used by 0x611c3bd5) is unchanged, so a reset still
  zeroes the hidden stock Sharpness. `ed_pmod` skips ids 904..907 for the `*`.
- Control Panel: `advice.sharpness` is the Sharp value (−5..+2); `profilesBin(bank, fw)` with fw 22 / 21 / 20
  (localStorage `caduceus.om3.fw`); `readProfiles` takes +52, else +42.

## Film sims (Control Panel, after v0.21)
- 60 looks in `webapp/src/data/om3films.json`, one per film, made by `python3 webapp/scripts/films.py` from short
  hand-written recipes (overall and per-family saturation, hue and lightness, WB shift, Contrast and tone). They're
  our own designs, from public descriptions of each film (maker data sheets, reviews, sample photos) and tuned by eye
  on the sample photos in the preview model; no LUTs, presets or other people's looks are used. Edit the recipes,
  not the JSON.
- Sharp (v0.22): `SHARP` in films.py (name → −4..+2, unlisted 0), written as `sharp` in the JSON and set by `filmLook`.
  main.ts gives film looks already in a list their film's Sharp once (localStorage `caduceus.om3.filmsharp`), only
  where the look's own value is still 0.
- No grain, Glow / Clarity or Art Effect in any film sim or in the start-up looks (`defaultBank` clears them from the
  library looks it uses); those stay the user's choice.
- Older film sim names (from earlier lists) map to the film that replaced them (`aliases` in the data), so looks added
  before keep their film for Reset look and the in-list marks.
- Not included: films the OM-3 controls can't make convincingly (redscale, cross-processing, heavily expired instant
  film).
- The looks are only as good as the preview model (`src/preview.ts`) is of the camera; check a film on the camera
  before trusting it for anything critical.

## v0.26 release (branch feature/v0.26-split-tone; build sp4, camera-tested 2026-11-09)

- **Split toning engine** (`st_run`, ext11): the tone hook's exit jumps to it (`jmp st_run`, back via `tone_next`). It
  bends the job's R / G / B gamma tables in place (O+1252 / 1892 / 2532: 256 + 64 entries, 12-bit):
  t' = t + ((Ks·ws + Kh·wh) >> 8), ws = ((t·s>>12)·s)>>12, wh = ((t·t>>12)·s)>>12, s = 4095 − t, with a running max so
  each curve keeps rising (main and fine parts separately). K = `st_k`[colour] × strength (12 colours, 4.8 Cb / Cr
  units per step at the peak). Gates: request key 11 (or 12 with +1731 = 0); the copier pointers O+3172 / 3176 / 3180
  equal the tables; the profile from getter 63153; a strength set; R = G = B (no double bend). `ST_STILL 0`: no
  still-only gate, so live view is toned too (camera-tested sp4).
- **Look bytes:** slot +55 Shadows colour 0..11, +56 strength −5..5, +57 / +58 Highlights. `LOOKS.BIN` record
  +53..+56 (`pf_lo` / `pf_bt` pairs 53,31 .. 56,34; `pf_bt` moved to ext3). BUNDLES range table 'sh_col', 'sh_str',
  'hl_col', 'hl_str'. `ed_isdef` reads the strengths (+56, +58), not the colours; `e_rst` clears +0..58.
- **Wheel pages:** axes 5 (Shadows) and 6 (Highlights); INFO cycle Luminance → 5 → 6 → Color. `tn_get` / `tn_set` /
  `tn_poly` (ext11) sit in front of `ed_get` / `ed_set` / `ed_poly`; `tn_set` zeroes the colour with the strength.
  Guides from `OM3MOD/TONES.BIN` ('OM3S', 8380 B, loaded at the half-press by `tg_load`; `tg_sel` for pages 5 / 6;
  `gd_sel` resets the descriptor first). The dial label stays the camera's; `LABELS.BIN` is v0.25's (27 labels).
- **Fix (also in v0.25):** after a drive-mode change, `sc_cap` captured the drive screen's layer-456 holder as the WB
  grid's (crash at `gr_is` with a0 = 0x20041001 when a COLOR was opened). `gx_map`'s exit stores the next GUI state in
  `gr_st`; `sc_cap` captures only when it is 0x0418 (Picture Mode).
- Firmware `E1479999.BIN` 34df5bf6…, `GUIDES.BIN` 1189c811…, `LABELS.BIN` d6c1b4ab…, `TONES.BIN` a5cd04e9…; ext11
  63904 of 65536, ext10 full. Optional `LOOKS.BIN` e742c70b… = the Control Panel's standard 20 (fw 25 export; the fw 24
  export of the same bank is v0.25's b7e4262a…). `patch.py` copies `TONES.BIN`; the release workflow attaches it.
- **Control Panel:** split toning wheels (`src/split.ts`, same `st_k` table), saved with "v0.26 or later" (fw 25, the
  default now); OM-3 only from 2026-11-09.

## v0.25 release (branch feature/v0.25-fast-grain; build fx3, camera-tested 2026-11-08)

Full trail: `research/NOTES.md` ("Grainy Film's grain path in the firmware", ft1..ft9, rc1..rc2c; "WB grid again",
wbg1..3, bw1 reverted; "v0.25 fixes", fx1..fx3; "The camera's 20 film sims"), decoded camera logs
`research/grain/fg3_logs.txt`.

- **Texture:** for a COLOR still with Grain, `xb_tex` gets Grainy Film's grain texture object (0x604cd921, the cached
  texture builder, with Grainy Film's 6-byte parameter block) into job+8324; the stock clean-up 0x604b9cd9 releases it.
- **Work list:** `.hook_wl` (0x604b8d91, the builder's key read) -> block +136 `xb_wl` (S at the builder's (4,sp)):
  makes the texture there (the list is built before the set-up) and answers Grainy Film II's key 0x01020068 for the
  list pick only (handler 0x604b8ddc: development with the texture hook 0x604bc0cf, then the effect as its own
  stage-0x0101 pass). The job keeps key 11, so the colours stay COLOR's. Not with Glow / Clarity + Frame together.
- **Development:** `xb_dev` (s_cl) re-attaches the texture (+780 descriptor, +12 = 0x0100) and answers combiner 1;
  `.hook_sel2` (0x60504b5d, the combiner set-up's own selector call) -> block +120 answers combiner 1 there too;
  `.hook_c1e` (0x605053cc, end of combiner 1's set-up) -> block +128 `xb_c1e` puts COLOR's chroma gains back (+96 =
  0x04000400, +100 = 1024; Grainy Film's 1024 / 0 = its black and white), the texture gain (+148: Low 448, Med 832,
  High 1280) and the Y offset (+180 low half = -0.102 x gain: the texture is not zero-mean).
- **Set-up:** `.hook_su` (0x604b7730) -> block +112 `xb_su` (marks a texture made earlier, or makes it).
- **Rows** (`pm_list` 111, 5397, 8, 5398, Blk, Wht, WB, 7, NR, VigFix, 5399 Shading, Glow, 5400 Grain): Glow (GL_IT,
  slider class 9, slot +49; the row shows the slot negated: + Glow, − Clarity); Shading (5399) back, its readout picture
  16244 redrawn 6 px lower (`sh_build`). Frame row removed; Art Effects off (`XB_ART 0`: the Art Effect reads as 0).
- **WB row** (AB_IT, class 11, one row for A-B / G-M): the camera's 2-D control (scene 498 captured by `sc_cap`
  0x610cdf05; `gr_upd` / `gr_pub` property 256 / `gr_ref` from `pu_hook` 0x611d04ec) shows the dot; `pm_ev`
  (0x6125becc) opens GUI state 0x0408 (the camera's WB fine-tune screen) for OK / left / right / dials; `gr_id` maps
  the screen's ids 1580..1605 to the look's slot +26 / +27; `gx_map` (0x610f6016) leaves it (MENU back to our row).
  Left cell WB± over "A2.G1": `wb_draw` (SL_VAL class 11) -> block +144 `xb_wbc`, glyphs in LABELS.BIN v3 'WBG1'.
- **Fixes:** `gd_set`'s `call gd_sel` had no return-address slot (overwrote its saved a2, so the half-press save
  stopped once the editor was used): settings and the film choice are kept over power off now; the same slot fix in
  `gr_upd` / `gr_pub` / `gr_ref` / `gr_now` / `wb_draw` / `sh_build` and the facade's `gr_id` calls. The editor's
  first use no longer clears DIRTY. Row memory (setting 2148): Picture Mode opens on its top row.
- **Fallback:** the CPU grain (xb_gs) stays for the case the texture cannot be made (no Art Effects remain to need it).
- Firmware `E1479999.BIN` db189ca6…, `GUIDES.BIN` 1edf66bd… (16308 of 16448 B), `LABELS.BIN` d6c1b4ab… (v3, 12160 B).
  ext11 ~62.4 of 64 KB. Optional `LOOKS.BIN` b7e4262a… = the Control Panel's standard 20 (fw 24 export).
- **Control Panel:** one list FILM 1–20 (`renderBank`), the 20 films first in the film browser (`CAMERA_FILMS`, from
  `films.py` `CAMERA`), `defaultBank` = the 20; export "v0.25 or later" (fw 24: Shading kept, Art Effect 0).

## v0.24.1 (branch hotfix/v0.24.1; camera-tested 2026-11-08)

v0.24 (below) with two changes; v0.24 itself was withdrawn and `releases/v0.24` removed.

- **Reboot fix (`firmware/src/xblock.s`, `XB_SHG 0`):** film test 11 made `xb_cap` call the settings getter `AGET`
  (0x603f039d) for Shading (setting 911 + k) while the photo is taken; with Film Grain High that rebooted the camera
  (the fg1 log showed the COLOR mark but no development request). The check is now behind `.if XB_SHG` and off, so the
  grain route is v0.22's again (camera-tested: High no longer reboots).
- **Shading row hidden (`firmware/src/editor.s`, `pm_list`):** 5399 left out of the Picture Mode rows (Shading with
  the camera-route grain gives a mono photo: combiner 33 in its MONO set-up). Films still load their record `+43` into
  setting 912 + k; the Control Panel writes 0 there for "v0.24.1 or later" (`profilesBin` fw 23).
- Firmware `E1479999.BIN` 6fbc80b8…, `GUIDES.BIN` 112e8f93… (7 bytes differ from the GUIDES-only hotfix: code
  addresses after `pm_list` moved by one word), `LABELS.BIN` unchanged.

## v0.24 films in the Picture Mode list (branch feature/v0.24-film-list; camera-tested 2026-11-08)

Includes the v0.23 Picture Mode rows (never released alone). Full trail: `research/NOTES.md` ("Picture-mode sliders",
"v0.24 film list", film tests 1–12).

- **List:** setting 901 (the COLOR position) gets 24 value records (`fl_rec`: COLOR 1–4, then film values FV0 + j,
  j = 0..19); item 111's three picture lists point at `fl_l0/1/2` (titles, left cell, strip). Film j sits on COLOR
  k = j / 5 as look n = j % 5 + 1 (P+LIDX+k). Facade GetValue/SetValue/selectable go through `fl_get` / `fl_set` /
  `fl_sel`; only the list builder (0x611b32ae) and the row's left cell (0x611d08f4) see the film value, everything
  else sees COLOR k.
- **Pictures:** our own, drawn by the camera from packed parts (`fl_rc` with layouts `fl_L0/1/2`: 100 × 76 list cell,
  "FILM*", 82 × 62 left cell; `fl_sp` with `fl_LS` 160 × 48 quick menu and `fl_LVL` 96 × 44 shooting screen,
  ids 15746..15753 / 15706..15709 via `fl_scp` / `fl_lvp`); `firmware/mkicons.py` is the reference, byte-identical in
  emulator dumps. Titles: string hook `fl_tt` (2755/2756/2757/4769) and `fl_pm` (string 203 on GUI 0x0418).
- **Changes kept:** `fl_sw` captures what COLOR k leaves (own settings record 20 + k, or film j) into the EDITS.BIN
  image (P+TORG) and loads the new one (saved changes if valid, else as built). `fl_save` writes `EDITS.BIN` at the
  half-press (format: FORMATS.md).
- **Resets:** reset table `fl_rtab` (stock 8 + 20 films, rows = 5397 only); `xb_lkh` (code block): OK held on a film
  (0xf881) or on its wheel (0x903e) = the film as built (skip-capture flag, SetValue(901, film)); the wheel then
  re-reads its children (e_lk). `.hook_rsp` 0x611c3cb5 -> `rs_pos`: the strip keeps its scroll after a reset.
- **`*`:** `fl_pmod` (stock "COLOR changed?" 0x6129ba07): COLOR k with a film -> its own flag, the row check
  (return 0x611d1837) -> `fl_live`; `fl_isdef` (7 "is at default" sites): the 18 settings and our own rows
  (GRB..GMB via `fl_xr`) against the film as built.
- **Wheel:** stock order (Color → Color All → Hue → Luminance); W_FILM / W_EXTRAS / W_SALL / W_SONE / W_HSL = 0
  (films tests 7–11 code kept, switched off). The Luminance guide is GUIDES.BIN stream 2; the hidden Film page's guide
  stream is left out (16 KB loader limit).
- **Effects:** XB_FX 0 in xblock.s: Glow / Clarity and Art Effect read 0 where they act. Grain: camera route (key 12)
  unless the COLOR's Shading (setting 912 + k) is not 0, then the CPU route (Shading + key 12 = monochrome, owner test).
- Space: ext11 (proven 64 KiB) ~60.9 KB used; GUIDES.BIN 14200 B of the 16448 B malloc cap.
