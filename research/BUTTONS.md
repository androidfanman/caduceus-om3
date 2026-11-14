# OM-3 1.1: arrow keys and Button Function (research, 2026-11-09)

Static analysis of the decoded main block (sha256 `5e8d376e…7d59`, CPU base `0x60021020`): data tables read with
byte-pattern scripts, code read with the repo's `research/tools/dis.sh` (binutils 2.42 mn10300 objdump).
**No emulator run and no camera test**; every result here is "static". Method and layouts follow Caduceus for the
E-P7 (cakelesscoder/caduceus-ep7, `docs/BUTTONS.md`, Apache-2.0): the OM-3 uses the same button sids and the same
press pipeline.

## Press pipeline (code)

`0x61083022` (event -> action), the same steps as the E-P7 dispatcher `0x60cc872f`:

1. `0x61083219(event)`: fixed event map `0x612f1e80` (13 x `{u32 event, u32 action}`: magnify, AFL, preview, REC,
   recording slot, movie effects). **No arrow events in it.** Non-zero result is returned directly.
2. `0x610830c9(event)`: key table walk (28 records) -> sid; `+4` stills sid, `+8` movie sid when the mode checks
   (`0x61085dbb(534)`, `0x61094313`, `0x610ab989`) say movie. 3200 = no key -> return 0.
3. `0x610833b3(sid)`: value. Special cases for 3413, 3412, 48, 49; every other sid -> `0x61085dbb(sid)` (plain getter).
4. `0x610831c2(sid)` -> `full`; only `full == 1` goes through `0x610834ba` (AEL / movie filter). Arrows are 0.
5. `0x610831e6(value)`: function table walk (80 records) -> action (`+12` alt action when `0x61094313() == 1`).

**Nothing checks which key a function code came from.** Any listed function code stored in sid 50–53 is executed.

## Tables (data)

| Table | Address | Layout |
|---|---|---|
| Action names | `0x612f17e0`, 142 | `{u32 string ptr, u32 id, u32 2}`; id 1 NONE .. 141 CAF_SUBJECT_TRACKING; reader `0x610830ab` |
| Fixed event map | `0x612f1e80`, 13 | `{u32 event, u32 action}` |
| **Key table** | `0x612f1ee8`, 28 | `{u32 key event, u32 stills sid, u32 movie sid, u32 full}`; readers `0x610830c9`, `0x61083148`, `0x610831c2` |
| **Function table** | `0x612f20a8`, 80 | `{u32 code, u32 action, u32 alt action, u32 flags}`; name id = action + 1; reader `0x610831e6` |
| **Validator** | `0x6061912c`, 1712 | 20 B `{u16 sid, u16 attr, u32 list, u32 alt, u16 bytes, u16 elem, u8 sub, u8 type, u16 0}` |
| Validator hash | RAM `0x62a84970` (128 buckets), nodes `0x62a84b70` (8 B `{rec, next}`) | built by `0x60405865` (count `1712` at `0x604058b3`), lookup `0x604058bc(sid)` and `0x604058e6(sid, attr)` |
| **Menu row lists** | mode table `0x61529ba4..` (12 B `{id, ptr, n}`) | mode 365 at `0x6152a108` -> `0x61529b76` (stills), mode 366 at `0x6152a114` -> `0x61529b88` (movie) |
| **Row item-info** | two trees: `0x6153aa90..`, `0x61568e44..` (28 B) | `{u32 sid, u32 title (string << 16 | 0xc), u32 ?, u32 value-label list, u32 n, u32 help/icon, u32 ?}` |
| Value labels | arrows `0x6153a1a8` (10), Fn `0x6153a220` (50) | 12 B `{u32 code, u32 string << 16 | type, u32 ptr}` |

## Arrow keys

| event | stills sid | validator | movie sid | validator | menu row | item-info |
|---|---|---|---|---|---|---|
| 4 (up, E-P7 mapping) | 50 | **none** | 1280 | **none** | no | **none** |
| 5 (down) | 51 | 9 codes `0x60615ac2` | 1281 | 7 codes `0x60615f4c` | yes | `0x6153ab54` |
| 6 (left) | 52 | **none** | 1282 | **none** | no | **none** |
| 7 (right) | 53 | 9 codes `0x60615ad4` | 1283 | 7 codes `0x60615f5a` | yes | `0x6153ab38` |
| 53 / 55 | 1294 / 1296 | none | 1287 / 1289 | none | no | ? |
| 54 / 56 | 1295 / 1297 | 9 codes | 1288 / 1290 | 7 codes | no | ? |

Stills row list (mode 365): `[47, 48, 1292, 49, 1964, 158, 53, 51, 56]`; movie (366):
`[1272, 1273, 1278, 1274, 1965, 1279, 1283, 1281, 1291]`. 158 / 1279 = arrow-pad mode rows (3 values).

Down / right options: WB (9), ISO (6), Exp comp (3341), Flash (16), Drive (3265), MF (88), e-zoom (3409), touch
lock (425), Off (3200); movie without Flash and Drive. The arrow label list also has 85 (AF area): likely the left
key's fixed function. Fn-only codes (candidates for the arrows): Myset 1–5, REC, RAW, one-touch WB, AEL, AFL, flicker
scan, IS mode, CP, High Res, Live ND, Live GND, focus stacking, HDR, multiple exposure, digital zoom, keystone, fisheye
correction, six BKT kinds, preset MF, subject select / detect, AF limiter, AF area, AF home, Peaking, focus ring
lock, Magnify, Preview, OVF simulation, night view, Level, LV state, lens info, Multi Function, test picture.

## Patch plan

All new data goes in the proven section-6 extension (`0x60f49800..0x60f59800`, after `.ext11`).

1. **Down / right: more functions (data only).** New shared u16 list (9 arrow codes + chosen Fn codes); point the
   51 and 53 validator records at it, `bytes = 2·n`. New merged label list (arrow 10 + the Fn entries copied from
   `0x6153a220`); point the 51 / 53 item-info records in both trees at it, `n` updated. Movie 1281 / 1283 the same
   way. Each added code is in the function table, in the Fn label list and allowed on a stock button.
2. **Up / left: rows (data).** New mode-365 list with 50 and 52 (e.g. `[47, 48, 1292, 49, 1964, 158, 50, 53, 51, 52,
   56]`), repoint `0x6152a108` ptr, n 9 -> 11 (366 likewise with 1280 / 1282). New item-info records for 50 / 52 in
   both trees (copy 53's; title string for "up / left function" not found yet: check the string ids next to 0x776 /
   0x777, or reuse 0x777 at first). How the row builder finds an item's record (count, search) is not traced yet.
3. **Up / left: value lists (code, ~30–60 B).** Hook the validator lookups `0x604058bc` / `0x604058e6`: when the
   chain has no record and sid is 50 / 52 / 1280 / 1282, return a record in our space (copy of 51's with our list).
   Other code may walk the 1712-record table directly: check before relying on the hook.
4. **Arrow-pad mode (158).** Not traced: if it is set to AF target, the arrows may move the AF point and never reach
   the dispatcher. Test with Direct Function.
5. **Restore note.** A value outside the stock list stays stored after flashing stock; reset Button Function first.

## Emulator results (2026-11-09; om-emu E147, stock main, blank card; emulator only)

Workspace: Node 26.12.0 in `~/om3-work/node`, om-emu `d24ff9d`, driver `drive.mjs` (session_ed1 bring-up, plus
`lever`, `mode:NAME`, PC tracing with stack, register-value range tracing).

- **The keys read the `+8` sids in P, A and M** (1280 up, 1281 down, 1282 left, 1283 right): in `0x610830c9` the
  vtable `(80)` call returns 5 and `0x610ab989()` returns 0, which selects `+8`. So `+8` is not "movie"; what
  selects `+4` (sids 50–53) is not known yet.
- Stored values at power-on: up 3341 (Exp comp), down 9 (WB, opens `ID_ST_DIRECT_WB`), right 88 (MF), left 85
  (AF area).
- Settings setter: `0x603f1b24(sid = d0, value = d1)` -> `0x6041992d` (also `0x603f1b76`, `0x603f1bc8`).

### Why up / left are fixed: the settings rule engine

The up / left values are written by rules, not by the user. Rule records (20 B `{u16 target, u16 default, u32 cond
list, u32 n, u32 0}`) near `0x605d9b80` / `0x605da120`; conditions 16 B `{u32 cond ptr -> (u16 sid, u16 value), u32 1,
u32 value-object ptr, u16 kind, u16 sid}`; a value object is a list of `(current -> new)` u16 pairs.

| rule | target | depends on | value when 0 | when 1 | when 2 |
|---|---|---|---|---|---|
| `0x605da148` | 1280 up | 1279 (arrow-pad mode) | 3200 Off | 85 AF area | **3341 Exp comp** (`0x605ce7ac`: 3341, 85, 3200 -> 3341) |
| `0x605da15c` | 1282 left | 1279 | 85 | 85 | 85 |
| `0x605d9b80` / `0x605d9b94` | 50 / 52 | (158, not decoded yet) | | | |
| `0x605da120` / `0x605da134` | 1294 / 1296 | 1293 | same objects as 1280 / 1282 | | |
| `0x605da170` | 1287 | 1286 | same as 1280 | | |

Value objects are shared between rules (`0x605ce7ac` serves 1280, 1294 and 1287): a patch must not edit them in
place. A user value written to 1280 would be overwritten the next time the rule runs.

Toggling the Fn lever ran the engine over hundreds of settings (callers `0x603fc1f9`, `0x603fc467`, `0x603fc5ab`,
`0x603f3531`, …): every arrow sid (50, 51, 53, 1280, 1281, 1283, 1294, 1295, 1297) became 85, and up stayed 85 after
the lever went back. Why the arrow-pad state changed is not traced (lever function setting unknown; blank-card
defaults).

### ISO/WB and WB/ISO

Function codes exist: 3403 -> SELECT_MODE_ISO_WB, 3404 -> SELECT_MODE_WB_ISO (also actions ISO_WB_DIAL /
WB_ISO_DIAL with no function code). **No button validator list contains 3403 / 3404, and no value-label entry exists
for them** (the E-P7 lists have its ISO/WB 3552). Adding them to a button needs a list entry and a label (string id
not found yet).

#### ISO/WB in the button menu: emulator proof of concept (2026-11-09, emulator only)

- Strings: the active string table is `u32(0x603794a0 + 4 · u8(0x6036f980))` (4848 ids). **2440 =
  `@A060@ISO/@A053@WB`, 2441 = `@A060@WB/@A053@ISO`** exist in stock; no label list uses them.
- Label field `(id << 16) | type`: type 4 = string (0x99 "ISO"), type 0xc = picture (the grid icons).
- Menu path: MENU, left x5 (custom tab page 1 "Operations") › Button Settings › stills / movie Button Function. Stills
  rows = mode 365 (sids 47, 48, 1292, 49, 1964, 158, 53, 51, 56): the stills menu writes the `+4` sids (traced: sid 47 =
  3462 through `0x603f0111` -> `0x603f1637`). ✥ (158) options: Off / Direct Function (±, [·:·], ▶, ▼) / [·:·]; ▶ / ▼
  are grey unless Direct Function. The movie menu writes the `+8` sids; in om-emu the dispatcher reads `+8` in P, so
  the stills choice did not reach a press there (what selects `+4` on the camera is still open).
- `~/om3-work/tools/poc_isowb.py` (emulator image only, 16 in-place edits, 48 bytes): in the down / right lists of both
  sets 3409 (e-zoom) -> 3403 ISO/WB and 425 (touch lock) -> 3404 WB/ISO; in the label lists `0x6153a1a8`,
  `0x6156855c`, `0x6153a700`, `0x61568ab4` the same entries -> codes 3403 / 3404 with strings 2440 / 2441, type 4.
- Result:
  - The picker accepts and stores the code; the row then reads "▶ : SO/▦WB" (the inline `@A060@` eats the "I",
    `@A053@` draws as an icon). **The two new picker cells, the picker title and the help text are blank.**
  - Movie Button Function ▶ = ISO/WB, then in shooting: right -> sid 1283 = 3403 -> action **SELECT_MODE_ISO_WB**, GUI
    `SS_REC/ID_ST_SETVAL`.
  - Dials after that: no setter call in the emulator, but the stock WB key's direct screen shows none either, so this
    proves nothing. **Whether the dials then change ISO / WB needs the camera.**
- For a real build: a picture (type 0xc) or a clean string for the label, the per-code title / help entries, and
  lists in the proven section-6 extension instead of replacing e-zoom / touch lock.

#### ISO/WB label search (2026-11-09, emulator only)

- **No ISO/WB picture found.** Dial Function (lever position 2) shows separate "ISO" / "WB" cells. The unused
  picture ids inside the button block (0x23ae..0x23c4) render as: 0x23b2 lock, 0x23b3–0x23b5 Wi-Fi bars, 0x23c5
  movie-format text, 0x23b9 / 0x23ac / 0x23ad blank.
- **The picker is drawn from separate per-code tables**, not from the row label list (a known picture there left the
  cell blank but drew the row):
  - grid cell: list `0x6153b2c0` (29 entries, object `0x6153b1a8`; type 3 picture or type 4 string, e.g. 3265 =
    string `@A00D@/@A00E@`);
  - title / picture / help: lists of 288 entries with object `0x61570e04` (e.g. 3409: title 0x503 "Electronic
    Zoom" at `0x61570fc4` / `0x615711e0`, picture `0x61571444` / `0x61571660`, help 0xf81 at `0x615718c4` /
    `0x61571abc`).
- **Stock strings cover ISO/WB completely**: 2440 / 2441 (`@A060@ISO/@A053@WB`, `@A060@WB/@A053@ISO`; `@A060@` =
  front dial, `@A053@` = rear dial) and help texts **2397 / 2398** ("Dials are assigned to following when button is
  pressed: front: ISO, rear: WB" and the WB/ISO one).
- `poc_isowb.py` with `POC_V2=1` (30 in-place edits) also rewrites the 3409 / 425 entries of those tables (grid, 2
  titles, 2 pictures, 2 helps each) to 3403 / 3404 with strings 2440 / 2441 and help 2397 / 2398 (type 4).
  Result: **title and help text complete and correct; grid cells show "ISO/▦W" / "WB/▦IS" (too wide, cut); the row
  value reads "SO/▦WB" (right-aligned, cut).** A shorter text (e.g. plain "ISO/WB") would need a new string: the
  active string table is in RAM (`0x603794a0` -> `0xa516c0cc` in the emulator), so Caduceus code could point an unused
  id at its own text at runtime.

#### Plain "ISO/WB" / "WB/ISO" text (2026-11-09, emulator only)

- No plain "ISO/WB" string exists (only "ISO", "WB", the icon variants and 2440 / 2441).
- 2440 / 2441 are UTF-16 in the resource component (`01_0101_41ec0000`), 18 copies each (one per language), e.g.
  English at offsets `0x12879a` / `0x1287c0`. 36 bytes each, so "ISO/WB" (12 bytes) fits in place, NUL-padded.
- Emulator: `drive.mjs` token `strset:ID=TEXT` overwrites the loaded string in RAM. With `POC_V2` and
  `strset:2440=ISO/WB strset:2441=WB/ISO`: **title "▶ : ISO/WB", grid cells "ISO/WB" / "WB/ISO", row value
  "▶ : ISO/WB", all uncut**; the help texts 2397 / 2398 keep their dial icons.
- Are 2440 / 2441 / 2397 / 2398 used anywhere else? `drive.mjs` `WREAD=` watches reads of their string-table slots
  (positive control: the patched picker reads them through `0x610f56b8`). Stock tours with no read: live view (INFO x5,
  SCP, lever, dials, every mode, arrow keys; 48 steps), all menu pages twice (125 steps), Dial Function P/A/S/M and Fn
  Lever Settings sub-screens (169 steps). Not proof, but no stock screen seen uses them.
- Two ways to ship the text: (a) edit the 18 copies in component 1 of the update file (in place, then fix that
  component's checksum as `patch.py` does for component 2; camera behaviour of a component-1 change untested); (b)
  Caduceus code overwrites the loaded strings in RAM at the first half-press (like `strset`; no resource change).

### ISO/WB build (branch feature/isowb-arrows, 2026-11-10; emulator-tested, not camera-tested)

- `editor.s`: `.hook_str` -> `iw_get` (2440 -> "ISO/WB", 2441 -> "WB/ISO", else `st_get`) and the lists in a new
  section `.isowb` at `0x60f58800` (last 4 KiB of the proven extension; 3028 B), so no existing symbol moves.
  `build.py`: validator records 51 / 53 -> `iw_vs` (11 codes, ISO/WB and WB/ISO before Off); row labels (both trees)
  12 entries; the 28 grid records -> `iw_g` (50); the 15 stills picker variants -> `iw_t/p/h` (57, help 2397 / 2398).
  Stills only (movie sids 1281 / 1283 would not fit with the rest).
- A build on macOS is not byte-identical to the release (pictures differ; not Pillow / FreeType version, not the DejaVu
  file: Ubuntu's 2.37-8 TTFs give the same output), and the code-block tag is a hash of the whole main block. So
  `~/om3-work/tools/layer_isowb.py` lays the change onto the release: BASE = local build of `main`, NEW = local build of
  the branch, every changed run (53 runs, 3391 B) checked equal in the release and BASE, then the tag recomputed
  (method verified on BASE) into the main block and the release GUIDES.BIN (CRC redone); LABELS.BIN as released.
- Emulator on the layered main: ▶ picker page 1 = the stock 8, page 2 = ISO/WB, WB/ISO, Off; titles and help correct;
  choosing stores it and the row reads "▶ : ISO/WB". Not run with GUIDES.BIN on the emulator card (no mtools).

- Help texts (2026-11-10): the stock 2397 / 2398 name the dials with `@A060@` / `@A053@`, which the OM-3 font draws
  as other symbols. Glyph sheet (all `@A0xx@` rendered in the emulator): 0x00–0x8F defined, 0x90+ printed as text;
  **0x4C = rear dial (∪, as the Dial Function picture)**, 0x51 = a whole dial, 0x0B / 0x0C = rear dial with turn arrows;
  **no front-dial (∩) glyph** (the Dial Function screen's ∩ is a picture). `iw_get` now answers 2397 / 2398 with our
  text "…|Front dial: ISO|Rear dial: WB" (and the swap), words as in stock strings 3478 / 3479. `.isowb` 3412 B.
  Layered test package 2: E1479999.BIN `cac0f2f9…`, GUIDES.BIN `27854338…` (tag 0x588b1aef).

### ISO/WB camera test 1: no ISO/WB screen (2026-11-10)

- **Camera** (test package 2): ISO/WB is offered and can be chosen; pressing the key shows no ISO/WB screen.
- Emulator, explained: om-emu's "Fn lever" switch is the OM-3's **stills / movie switch** (the shooting screen turns to
  the movie icon, F2.8). **In stills mode om-emu is not faithful for keys and dials**: the dispatcher reads the `+8`
  sids and the front dial does not change Exp comp. In movie mode both work (front dial: Exp comp 0.0 -> +1.0; the
  stock ISO key opens `ID_ST_MUTE_CONTROL_2ND` and the dial writes sid 1859 = 5, 6, 7). Earlier stills-mode
  emulator results about presses and dials are void.
- Movie mode, ▶ = ISO/WB: the press dispatches action 51 SELECT_MODE_ISO_WB, GUI `SS_REC/ID_ST_SETVAL`, the ISO box
  appears, the dials stop changing Exp comp, but **no setting is written** (only sid 2137 at the half-press). The same
  with 3403 / 3404 mapped to the dial actions 53 / 54 (SELECT_MODE_ISO_WB_DIAL / _WB_ISO_DIAL). **The OM-3 1.1
  firmware has no working ISO/WB key mode**: it enters a set-value state with no dial handlers; the OM-3 does ISO/WB
  only through the Fn lever's dial-function set (Dial Function, lever position 2).
- A working ISO/WB key would need code: e.g. the key toggles a lever-position override so the dial-function lookup
  uses set 2 (`SubAppModuleLeverSwitch`, `getLeverSwitchState`, `checkDialFuncChange`; not traced yet).

### Fn lever and dial functions: research for a key that switches the dials to ISO/WB (2026-11-10)

Goal: a key that puts ISO / WB on the dials while the Fn lever keeps another job (the owner's: AF, mode2).

- **Fn Lever Function** (custom menu page 1 › Fn Lever Settings; stills and movie rows, plus "Fn Lever / Power
  Lever"): Off / **mode1 "Changes dial function"** / **mode2 "Switches AF mode / AF target mode / AF target point
  according to Fn lever position"** (om-emu default: mode2 for both).
- **With mode2 the Dial Function screen greys out the lever-position-2 cells**; with mode1 they are live. So with the
  lever on AF the firmware does not use dial set 2 at all.
- Dial Function sids (validator lists `[3200, 86|1697|1699, 2, 17, 1701, 1578, 1632]`):

  | mode | position 1 front / rear | position 2 front / rear |
  |---|---|---|
  | P | 70 / 71 | 1302 / 1303 |
  | A | 72 / 73 | 1306 / 1307 |
  | S | 74 / 75 | 1304 / 1305 |
  | M | 76 / 77 | 1308 / 1309 |

  Codes: **1578 = ISO, 1701 = WB** (P position 2 stock), 86 = Ps, 1697 / 1699 = shutter / aperture (by mode).
- **sid 534 = the lever state**: the read made for `CameraCommon::getLeverSwitchState` (method name table
  `0x60367898`) is `GetValue(534)`; the key dispatcher compares 534 with 5 / 7 (`0x610830c9`) and the lever module
  (`0x6108c...`) reads it most. om-emu: 534 = 4 throughout.
- **om-emu does not model the OM-3 Fn lever**: its "Fn lever" switch (UI 0x1223) is the **stills / movie switch**, and
  the lever's real input is not wired. In stills mode its keys and dials are not faithful either. So the lever-position
  -> dial-set path cannot be exercised there; only movie-mode dials work.
- Not found yet: the code that turns (mode, lever function, lever position) into the active dial functions. Leads:
  the 35 `mov 1302/1303` sites (the `0x6070f...` cluster is a camera-API property list, not it), `checkDialFuncChange`
  (`0x6108c8f7` area), the method behind `getLeverSwitchState`.
- Feasible design if that code is found: Caduceus keeps an "ISO/WB on" flag toggled by the key (a new function code
  or a reuse of 3403); a hook in the dial-function resolution returns ISO (1578) / WB (1701) for front / rear while the
  flag is set, before the lever-function check, so the lever stays on AF. Verification would have to be on the camera
  (or in movie mode in om-emu, whose dial functions are separate settings).

### Dial-function resolver found (2026-11-10; static + om-emu movie mode)

Traced from the movie-mode front dial: the facade reads sid 1310 (movie P, position 1, front) with the stack
`0x6109e1xx/e6xx/e7xx` (dial handlers) -> `0x610835bd` -> `0x61085e0e` (GetValue via vtable +20).

- **`0x610834f4(event)`** -> function code for a dial event. Events 0x0100000a..0x010000e0 go through a hash table
  (`0x612f2b00`, `jmp (a0)`); the dial events call **`0x610835de(event)`**, which returns a table pointer:
  - `0x61084a53(event)`: 0 = front, 1 = rear;
  - lever state: **sid 534** (stills) or **sid 1326** (movie, when sid 44 == 1 or `0x610b6882()` == 1);
  - **state == 8 -> position-2 table, else position-1 table** (`cmp 8` at `0x6108364d` / `0x61083645`, front;
    `0x6108366f` / `0x61083667`, rear).
  Back in `0x610834f4`: the entry for the shooting mode (sid 109; 3 P, 4 S, 5 A, 6 M; movie 76 / 77 / 89 / 90);
  entry `{mode, fixed code, sid}`: fixed != 3200 -> that code, else GetValue(sid). Then `0x610a0a2d` maps the code
  (1579 -> 1578), `ret` at `0x610835db`.
- Tables (12 B entries, end 3200):

  | table | dial / position | P / S / A / M | movie P / A / S / M |
  |---|---|---|---|
  | `0x612f2788` | front 1 | 70 / 74 / 72 / 76 | 1310 / 1314 / 1318 / 1322 |
  | `0x612f2800` | rear 1 | 71 / 75 / 73 / 77 | 1311 / 1315 / 1319 / 1323 |
  | `0x612f2878` | front 2 | 1302 / 1304 / 1306 / 1308 | 1312 / 1316 / 1320 / 1324 |
  | `0x612f28f0` | rear 2 | 1303 / 1305 / 1307 / 1309 | 1313 / 1317 / 1321 / 1325 |
  | `0x612f2968` / `0x612f29e0` | fixed sets | Ps / shutter / aperture; Exp comp | |

- om-emu, movie P, table entries patched to fixed movie ISO (1579) / WB (1702): the resolver returns 1578 / 1702 for
  front / rear and the dials no longer change Exp comp. Whether ISO / WB values then change could not be read in
  om-emu (no reads of the movie ISO sid 1859 on this path; menu control run inconclusive).
- **Design for a key that puts ISO / WB on the dials, lever untouched**: a Caduceus flag toggled by the key
  (intercept codes 3403 / 3404 before `0x610831e6`, e.g. redirect the call at `0x61083065`, and return action 0);
  a hook at the end of `0x610835de` that, while the flag is set, returns our two tables with fixed ISO (1578) / WB
  (1701) for every mode (WB/ISO: swapped). sid 534 is never touched, so the Fn lever keeps AF (mode2). Open: the
  screen refresh when the flag changes, and when to clear it (second press; maybe power-off).
- Cheapest camera check before writing code: a data-only test build whose stills P position-1 entries are fixed ISO /
  WB (`0x612f2788` / `0x612f2800`, mode 3). If the P-mode dials then set ISO and WB, the table route is proven.

- **Camera-tested (2026-11-10): the table route works.** Data-only test on v0.24.1 (`~/om3-work/tools/
  make_dialtest.py`: the P entries of the four tables -> fixed 1578 / 1701; 19 bytes incl. the tag; package
  `c4cd8eea…`, GUIDES `188edfa7…`): in stills P mode the front dial changes ISO and the rear dial changes WB.

### Up key, round 2 (2026-11-10; om-emu menus, which are faithful; emulator-only test images)

The ISO/WB route is dropped (owner: on the dials WB only switches presets, no fine adjustment). Back to an
assignable up key.

- **Rules**: `0x605d9b80` target 50 depends on **sid 158 (stills arrow-pad mode: 0 Off, 1 [·:·], 2 Direct
  Function)**: 0 -> Off, 1 -> AF area (85), 2 -> Exp comp (3341) (value objects `0x605ce794 / 7a0 / 7ac`, shared).
  `0x605d9b94` target 52 (left): 85 / 85 / 85. `0x605da148` target 1280 is the same as 50 on sid 1279.
- **Menu rows**: the stills Button Function rows are the **mode-365 list** (`0x6152a108` -> `0x61529b76`, 9 sids, the
  on-screen order), and each row's record is found by sid in the **item-info tree 2**, whose header is
  `0x61569064` (20 B: `{variant 0 stills / 1 movie, records, count 9, label ptr, label ptr}`, read by `0x611f2374`).
  Tree 1 (`0x6153aa90`) has no reference found.
- Item-info record (28 B): `+0 sid`, **`+4 row icon picture (type 0xc)`** (▶ 0x777, ▼ 0x776; Fn 0x788, ◉ 0x71b, ✥
  0xa43, L-Fn 0xa4d), `+12 value labels`, `+16 n`; `+20` (0x3f7b.. per row) is not the row icon.
- **No ▲ / ◀ picture** in 0x700–0x7ff (sweep: 0x776 ▼, 0x777 ▶; 0x76d/0x76e/0x76f/0x771 are boxed arrows);
  a ▲ icon would be our own (Caduceus' `.hook_ic` already supplies own pictures).
- Emulator steps (each image adds to the last):
  1. records copy + a sid-50 record (copy of 53's) and header count 10: no new row (rows come from the mode list);
  2. **+ mode-365 list with 50 (count 10): the ▲ row appears and shows sid 50's value (±)**;
  3. + validator record for 50 (emulator hack: record of sid 1966 renamed): OK on ▲ -> "cannot be selected: ✥
     Function" with ✥ = [·:·], **"Camera Settings or Status" with ✥ = Direct** (the rule owns sid 50);
  4. **+ rule 50 count 3 -> 2 (drop the Direct branch): no message any more**, but OK opens no picker, also with ▲
     appended last (index 9, so the per-index picker variants are unchanged).
- Open: what OK needs to open a row's picker (a per-sid or per-item table; the u16 list at `0x61540a14` contains
  50 and 52 and may be it); a real validator record for 50 (lookup hook, the table is fixed at 1712); the ▲ icon;
  which key set (sid 50 or 1280) the camera's stills dispatcher reads (om-emu stills is not faithful).
- om-emu setter calls (`drive.mjs set:SID=VAL`, `0x603f1b24`) do not show up in `get:` reads (even for sid 53); the
  menu writes through `0x603f0111` -> `0x603f1637`. Use the menus for write tests.

### Up key, round 3: the picker opens (2026-11-10; om-emu menus)

- What OK needs: the row's sid -> **row table** `0x6150ce18` (32 x 24 B `{sid, 0, group, item id, 0, 1}`; 53 ->
  group 8 item 733) -> **item descriptors**, a two-level directory at `0x615cc934` (14 x 12 B `{group, table, n}`;
  group 8 = `0x615c540c`, 416 x 24 B `{item id, 68, sid, 96, picker key, 0}`; 53 = item 733, key 7), searched by
  `0x6124f4e5` (group d0, item d1) -> `0x6124f11a` opens the picker with the key; `0x611f64b5` finds the picker
  variant whose low half equals the key (`0x61571ba0`, 32 x 24 B). (The `{sid, 0x611be844}` table at `0x6153368c`,
  38 pairs, bound `cmp 38` at `0x611be684 / 0x611be687`, is not on the OK path.)
- sid 1957 (a button of other bodies: in validator, row and descriptor tables, item 730, key 4, but not in the OM-3
  key table or the row lists; code does name it, e.g. `0x6125ceaa`) lends all three entries to sid 50 in the test.
- **Emulator, layered on v0.24.1 (`~/om3-work/tools/make_uptest.py`, 320 bytes + tag; package `54b1b1ef…`, GUIDES
  `3bfac2f2…`)**: ✥ = Direct Function, the last row ▲ (icon picture 0x76d, a boxed up arrow) opens the full button
  picker (47 codes); choosing Focus Stacking stores sid 50 = 1356 and it stays after leaving the menu and a half-press;
  ▶ / ▼ unchanged. Cosmetic: the body diagram's pointer for the row still points at the right key.
- To check on the camera: the stills up key runs the chosen function (sid 50 vs 1280 question); [·:·] still moves
  the AF point; the setting survives power-off.

### Up key, camera test 1 and fixes (2026-11-10)

Camera test 1 (owner): WB works; ISO changes the value but with another screen than ▶'s ISO; MF needs a
half-press between two up presses; Magnify and Multi Function do nothing; with ✥ = [·:·] the up key still runs the
assigned function.

- **Release handling.** Functions that act on key release are run by per-state event blocks: 16 B entries
  `{event, a, b, handler}`, referrer `{handler, state id, block, n}`. Most shooting states (0x51xx, 0x53xx, 0x58xx,
  0x5axx, 0x5b00) already give the up release (0x0100000b) the same handler as the right release (0x01000017); **seven
  0x59xx states list only down / right releases**: 0x5900 (`0x610a8fb4`), 0x5911 (`0x610a4209`), 0x5917
  (`0x610a63de`), 0x591b (`0x610a8459`), 0x5927 (`0x610ab42a`), 0x5936 (`0x610a8d32`), 0x593a (`0x610a4209`). om-emu,
  movie mode, up and right both = MF: before, up dispatched 4–5 times and a second press did nothing; with the seven
  blocks copied + `{0x0100000b, 1, 1, handler}`, up = right (22 dispatches, release dispatch, refresh, repeatable).
  (Up-only event compares and the three "(32,a2) = 13 / 19" sites `0x610a84ff / 0x610a9040 / 0x610ab4eb` were not it.)
- **Arrow-pad mode.** The rule's value objects only map 3341 / 85 / 3200, so an assigned value survives [·:·] / Off.
  Hook (`~/om3-work/tools/upget/up.s`, 59 B at `0x60f594c0`; `jmp` over the 5 stock bytes at `0x610833b3`, the
  dispatcher's value read): sid 50 by sid 158 (sid 1280 by 1279): 2 -> the assigned value, 1 -> 85, 0 -> 3200. om-emu
  movie: Direct -> MF (15), [·:·] -> AF area (action 59), Off -> 0; the assigned value is kept.
- Test 2 = test 1 + both (`make_uptest.py`; 3090 bytes; layout 0x60f58800 records, 0x60f58a00 rows,
  0x60f58a40..0x60f594b0 state blocks, 0x60f594c0 hook, all below 0x60f59800). Package `4c4a6b90…`, GUIDES
  `c225114e…`. Not verified in om-emu: stills ISO screen, Magnify, Multi Function (om-emu stills keys are not faithful;
  its movie lists lack Magnify).

### Up key, camera test 2 (2026-11-10)

- Camera: ISO, MF (repeatable without a half-press) and Peaking behave as on ▶; the arrow-pad modes ([·:·] moves the
  AF point, Off does nothing, Direct restores the assigned function) work. **Magnify, Multi Function, HDR, Live ND,
  High Res do not.** None of the five is offered on ▶ / ▼ in stock.
- om-emu, movie ▲ = Magnify: the press dispatches action 26 (LV_MAGNIFY) but nothing starts. No om-emu key that
  reaches a full button (Fn / ◉ / AF-ON...) is wired (`rec`, `afon`, `exp`, `lvkey`: no key-table event; the rest
  "not wired"), so there is no working reference to diff against.
- Key events (event -> keycode table `0x612f3100`, 259 x 20 B `{event, keycode, phase, group mask, code}`): each key
  has press / release / hold / +3; arrows: up 0x0100000a.., down ..0e, left ..12, right ..16 (masks 0x8 / 0x10 / 0x20 /
  0x40); Fn 0x01000036.., ◉ 0x01000006.., AF-ON ..32, |●| ..3e, CP ..42, 571 ..4e, 572 ..52, ISO key (55) ..ab, +/- key
  (54) ..af, 1966 ..b3, L-Fn ..b7 (group masks 0x2000 / 0x400 / 0x40000).
- No state block has a handler entry for any Fn event (they take the states' default path), while many blocks turn
  arrow events into navigation codes (`{event, code, 1, 0}`). The five failing functions are the ones that work by
  press / hold / second press with arrows meaning something else meanwhile (Magnify: frame, then the arrows move it,
  then a second press zooms; Multi Function: hold + dial; HDR / ND / High Res: "press to switch, hold to configure").
  Likely the reason the camera never offers them on an arrow; making them work on ▲ would mean changing the arrow
  handling inside those states.

### Up key, test 3 (2026-11-10): ▶'s list and a ▲ icon (`tools/make_uptest3.py`)

- Option list: sid 50's validator record (the borrowed 1957 slot) = a copy of 53's (list `0x60615ad4`, 9 codes: WB,
  ISO, Exp comp, flash, drive / self-timer, MF, W↔T, touch, Off). **The picker grid follows the validator list**: the
  picker variants of key 4 (`0x61571c18`) and ▶'s key 7 (`0x61571c60`) share their title / picture / help lists, so
  item 730 keeps key 4. The row record keeps 53's value labels.
- Picker title key icon: picture list `0x6139e26c` (16 x `{0xffff, 7, 7, id}`), index = variant `+2` - 1 (read at
  `0x611f686a` into the picker's `+2460`): 0 Fn 0x788, 2 ◉ 0x71b, 6 ✥ 0xa43, 7 ▶ 0x777, 8 ▼ 0x776, 14 L-Fn 0xa4d;
  index 4 (key 4's) was blank (0x1) -> our ▲.
- ▲ picture: 0x776 (▼, format 14, 40 x 40, type-11 stream, palette 7/8/9/13/14/15) flipped upside down, id 0x7fa0,
  descriptor `0x60f59540`, payload `0x60f59560` (uncached alias in the descriptor); `up_ic` (`tools/upget/upic.s`,
  `0x60f59500`) takes over Caduceus' `jmp ic_get` at `0x610f5611` and answers 0x7fa0, else jumps on to `ic_get`
  (`0x60f4a904`). om-emu `pic:ID:FILE` dumps a picture.
- om-emu: row "▲ : WB", picker title "▲ : Exposure Comp." / "▲ : WB", the 9 ▶ codes; a choice is kept.
  Package `OM3-upkey-test3-v0.24.1` (E1479999.BIN `f1f15928…`, GUIDES `25ae351a…`).

### Up key, test 3 on v0.26.2 (2026-11-10; `research/upkey/make_upkey.py`; camera-tested)

- Release files made with v0.26.2's own `firmware/patch.py` from the stock 1.1 file (package `4add99d3…`, GUIDES
  `92b67919…`). All the up-key tables, the rule, the 7 state blocks, the dispatcher hook site `0x610833b3` and the
  picture lists are where they were in v0.24.1. Moved: tag reference `0x60f497cf`, `ic_get` `0x60f4afb5` (jmp at
  `0x610f5611` = `dca459e5ff`).
- **Space:** v0.26.2 fills Caduceus' 64 KiB section-6 extension (FF only from `0x60f59770`). The test moves section
  6's loaded end once more, `0x60f59800` -> `0x60f5a800` (loader word `0x60045e9c`, as build.py / GX2), and puts the
  same layout 0x1000 higher (records `0x60f59800`, blocks `0x60f59a40`, `up_get` `0x60f5a4c0`, `up_ic` `0x60f5a500`,
  picture `0x60f5a540` / `0x60f5a560`; sources in `research/upkey/`). GX1 saw nothing write into that gap; the extra 4 KiB
  itself is not camera-proven (om-emu maps the whole image, so it cannot show it).
- om-emu needs `OM_WORKER_ENTRY=60a8f623` for v0.25+ (the power-on worker task; `drive.mjs` takes it now). Boots to
  live view; ▲ row / picker title / 9 codes / a kept choice as on v0.24.1.
- Package `OM3-upkey-test3-v0.26.2`: E1479999.BIN `01470487…`, GUIDES `cf37801e…`, LABELS / TONES as the release.
- **Camera (2026-11-10): works.** On v0.26.2 the ▲ row, its picker and ▲ itself behave as in test 3 on v0.24.1
  (▶'s functions, arrow-pad modes), and v0.26.2's films (with the release `LOOKS.BIN`) work alongside. Nothing went
  wrong in that use; a longer run (photos, video, Wi-Fi) is still to do for the extra 4 KiB of section 6.
- Rebuild: `research/upkey/` holds the hooks (`up.s`, `upic.s`, their `.ld`), `assemble.sh`, `make_upkey.py` and the
  om-emu driver `drive.mjs` (tokens as `research/emulator/` plus `pic:ID:FILE`, `get:` / `set:` / `robj:`, `strset:`,
  `strings:`, env `WATCH` / `WREAD` / `WMEM`, `OM_WORKER_ENTRY`). Earlier rounds' scripts (`make_uptest*.py`,
  `poc_isowb.py`, `layer_isowb.py`, `make_dialtest.py`) stayed in the local workspace; their edits are written above.
- **Camera bug, fixed 2026-11-10:** FILM 17's list picture showed ▲. Our picture id 0x7fa0 is one of Caduceus' own:
  v0.25+ gives film j's list cell the id `IC_FM0` (0x7f90) + j, and the row's left cell `IC_FL0` (0x7fb0) + j, so
  Caduceus uses 0x7f80..0x7fc3. `up_ic` answers first, so it took film 17's id. ▲ is now 0x7fe0 (package
  `be17717a…`, GUIDES `5c06ddb1…`); om-emu: ▲ row and picker title as before (the film list itself needs a card image
  with `LOOKS.BIN`, which needs mtools; not checked there). **Camera-tested 2026-11-10: FILM 17 shows its own
  picture again, ▲ still shows in Button Function.**
- Before a release: own validator / row / descriptor records instead of sid 1957's (lookup hooks; the validator table
  is fixed at 1712), the movie up key (1280), and space that a probe has proven (or code in the GUIDES.BIN block).

### ISO and +/- buttons (static; om-emu does not wire them for E147)

Correction: om-emu's `iso` control (UI code 0x1230) is "not wired" for E147; that is an emulator gap, not a missing
key. In the key table, **key 32 -> sid 55 / movie 1285 (default 6 = ISO)** and **key 33 -> sid 54 / movie 1284 (default
3341 = Exp comp)**, `full = 1`, 47-code validator lists, and neither sid is in the Button Function row lists (modes
365 / 366): very likely the OM-3's dedicated ISO and +/- buttons, fixed in the UI. Keys 22 / 28 are fixed functions
3413 (SELECT_MODE_AE_AF) / 3412 (SELECT_MODE_STB_MANUALSTB). om-emu's `front1`, `front2`, `afmeter`, `ael`, `bkt`,
`drive` are not wired either; `exp`, `afon`, `lvkey` reach no key-table event. Needs the camera to confirm.

### Fn lever

Firmware module `SubAppModuleLeverSwitch` (function names in debug strings `0x612fcf12..`, code `0x6108c100..`):
receive / check / change lever switch, `checkDialFuncChange` (dial functions per lever position),
`MODE_LEVER_SWITCH_TYPE`, recording focus change, `changeFunctionButton key=%d lever=%d`. It reads sid 534 most
(mode / state), plus 1326, 1338, 15130, 15260. In om-emu the "Fn lever" switch input did not hit the traced entry
points of that module, but did run the rule engine (above). Not traced further.

### Up-key patch plan (revised)

1. Rule: give the 1280 rule (and 50's) its own value objects; in the Direct Function branch keep the user's value
   (map 85 / 3200 -> 3341, leave others). Unmatched-value semantics of the engine must be checked in the emulator first.
2. Validator: hook `0x604058bc` / `0x604058e6` for sid 1280 (and 50) -> a record with a list (3341 + chosen codes).
3. Menu: add 1280 to the row list that the stills Button Function uses (mode 366 list `0x61529b88` if the `+8` set
   is the stills set; check in the emulator) and an item-info record (both trees).

## Open

- Default stored values of sids 50 / 52 (expected 3341 Exp comp and 85 AF area).
- Item-info search and the row builder for mode 365 (emulator: open Button Function, `WATCH` the item lookups).
- The 15-entry u16 list at `0x61540a14` (`[47, 49, 48, 570, 571, 572, 54, 55, 56, 158, 50, 52, 53, 51, 1292, …]`),
  no direct pointer found.
- Physical control behind events 53–56 (second four-way set).
- Free camera check first: the OM-3's own Button Function menu and its ▼ / ▶ options.

### Delete button (2026-11-13, static and emulator, #37)

- Keycode 14 (`API_DEL_KEY`), events 0x01000026 press, ..27 release, ..28 long press, ..29 repeat. No key-table
  record, so the dispatcher drops it in shooting mode (om-emu, P live view).
- Free setting for it: sid 570 (stills) / 1276 (movie). Both are another body's button, with validators and stored
  values but no key, row or item-info record on the OM-3.
- Details and the patch route: `research/NOTES.md`, "Delete button remap (#37)".
