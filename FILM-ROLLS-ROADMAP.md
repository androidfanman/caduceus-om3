# Film Rolls on the SD card: roadmap

Written 2026-11-24. **Phase 2 started 2026-11-24** (owner: "start from the newest version: .41 beta"). Worktree
`caduceus-rollscard`, branch `feature/film-rolls-card` on the tag `v0.41-beta` (27f1553). Nothing committed.

The goal is the poll mock-up (`film-rolls-poll-mockup-v12.png`, private folder). Load a film roll, shoot it, the
shutter stops at the end, no peeking until you rewind, then review. **Everything lives on the SD card**, like OMKit:
the flashed firmware only carries small hooks that do nothing unless the card has the Film Rolls files. A card without
them gives a normal OM-3.

## What's left (2026-11-25, after test 35)

- ~~**The strip's jump** on each rear-dial click~~: **fixed, camera-tested** (test 29: the dial's own step plus an arrow
  back; test 30: the film held meanwhile, no flicker; owner: "that looks great!").
- ~~**Bursts past the roll's end**~~ (owner, test 33: "I was able to take 55 photos after selecting 24 shots"):
  **fixed, camera-tested** (test 35: the camera's burst limit capped at the frames left; two 24 rolls, 24 photos each).
- ~~**The rewind, a frame a click**~~ (owner: "every click be worth 2 rewinds"): **2 frames a click, camera-tested**
  (test 34).
- ~~**The strip moving on each click**~~ (owner, test 32: "still moves through the film sims"): **the click no longer
  reaches the strip, camera-tested** (test 33).
- **D4 Review:** an optional "Roll 05 · frame 17" tag in Playback after the rewind (the mock-up's screen 6).
- **"Not developed" in Playback** (the mock-up's screen 4): tried, froze the camera on leaving Playback; Playback does
  nothing during a roll instead (owner OK'd). Could be tried again another way.
- **Before a release** (owner, 2026-11-25: "Tidy for release"):
  - ~~take out the test-only code~~ (fr61): the E1 probe's Color Creator hook and the two counting-only renderer
    hooks, DRAW.TXT and "Not developed" (SCREENS.BIN 372 KB -> 195 KB), the diagnostic counters; ~~the hidden Film
    Roll row~~ out of the firmware (Picture Mode as v0.41-beta again; the card file's pm_color hook gone).
    **Needs a reflash and a camera test** (release candidate fr7).
  - ~~#105's crop fix~~ (owner, 2026-11-26: "implement the span fix in this as well"): fix105-1's crop.s and its tests
    (`fix/105-xpan-early-half-press` c1ffb3f) added uncommitted; ftell / fclose moved to .ext13 so .ext12 fits
    (Film Rolls + the fix ran it 16 B over). Release candidate 2, fr8 (not on the card).
  - ~~rt1~~ (owner, 2026-11-26: "Add rt1 to this test build as well"): `feature/screen-info-rec-time` 05ed79e added
    uncommitted (Remaining Movie Time as its own row); its si_tab in .ext11, si_str and the string in .ext13 (rt1's
    .ext4 is full with Film Rolls). Release candidate 3, **fr9**: on the card 2026-11-26 (sha256 checked); **flashed 2026-11-26** (test 38: the log
    says fr9, card files match, a 24 roll shot to its end, the shutter stopped there, wound back and out, no restart).
    **Camera-tested, PASS** (owner, 2026-11-26: XPan and the two Information rows "Yes, both work"; the roll as test 35).
  - ~~the ISO from before the roll back after it~~ (owner, 2026-11-26, test 38: "when the roll finishes it should go
    back to the previous iso (in this example auto iso)"): the card file keeps the ISO (6 and 1701) at the half-press
    that sets the roll's, in the roll's record (version 3, 28 B; version 2 still read), and puts both back at the
    half-press where the roll comes out. Card file only (FILMROLL.BIN; the firmware stays fr9's). Test 39: on the card 2026-11-26 (sha256 checked);
    **camera-tested, PASS** (owner: "Yes, all good"; the log: put back twice, no restart).
  - the full suite and the static checks' new hooks for the owner's review;
  - ~~user docs~~ (docs/USING.md "Film Rolls", the card files table; ROADMAP.md) and release notes (draft below);
  - commit (nothing committed yet: the owner's word first);
  - ~~the release itself~~ (owner, 2026-11-26: "push the filmrolls to github as .41 beta2"): **v0.41-beta2**, a test
    version (GitHub pre-release, `try/v0.41-beta2`); LookLab's Film Rolls export went live on main the same day
    (6954629). The full release (and `hooks.json` for the two hooks) still to come.
- **Release notes (draft, for CHANGELOG.md):** *Film Rolls (on the SD card): shoot a roll of 24, 36 or 72 exposures.
  Pick the film and the length on Picture Mode's film selection row (the rear dial picks the length; the canister
  shows the film, its ISO and the length). During a roll the film and ISO stay the roll's (the film's box speed, at
  least 200; COLOR 1-4: 400; the ISO you had comes back after the roll), the shots-remaining number counts the frames left, Playback and Image Review wait for
  the rewind, and a burst stops at the last frame. At the end the shutter locks; OK opens the film row and the rear
  dial winds the roll back (two frames a click). Every roll is listed in OM3MOD/FILMROLL/ROLLS.TXT. Copy the
  release's FILMROLL folder into OM3MOD to turn it on.*
- **LookLab films on a roll** (owner, 2026-11-25: "you could create a custom film sim in the looklab and set a custom
  ISO and you could load the film sim into the film roll"): the LookLab session (`feature/looklab-film-rolls`) writes
  ROLLART.BIN with each film's canister and ISO; FILMROLL.BIN reads the roll's ISO from that file's table (fr56,
  emulator only).
- **Later ideas (owner deferred):** your own film shelf from the card (B2, FILMS.TXT) and a canister designer in
  LookLab.

## Status (2026-11-24)

| | Tasks |
|---|---|
| Done and passing in the emulator | A1 loader, A2 thin hooks, A3 r2b's logic on the card, A4 shutter stop at 0, D1 version 1 (Playback does nothing during a roll), B1 the roll kept on the card, D3 version 1 (OK rewinds at the roll's end), B3 the roll log (with photo numbers), D2 Image Review off, E2 screens from the card, C4 the film window (20 Film Rolls tests pass; full suite on fr6: 176 pass, only the two review checks fail) |
| Camera-tested (2026-11-25, test 7: owner "everything worked") | A1–A4, B1, B3 (photo numbers match the files), C4 the film window, D1, D2, D3 |
| E1 / E2 the drawing (2026-11-25) | **Camera-tested: the loaded film's canister on the Film Roll row** (test 13, owner: "that looks wonderful"), following None / 24 / 36 / 72, card file only. Test 8's restart traced to fb_one's frame (fixed). **Camera-tested: the rewind crank on the row** (tests 16–19): one Left / Right per frame shot with the rewind panel drawn, the bottom bar invisible and "Scroll to rewind film" during a roll, None / 24 / 36 / 72 back after "Rewound" (test 19, owner: "that looks good"). **The end-of-roll slip on the shooting screen** (2026-11-25, om-emu; camera test 20 pending): at 0 the film window turns into the slip, in the label's widened box (camera test 20: "the banner shows up"). **OK no longer rewinds** (owner, test 20: "I want to have to go the the roll and phyiscally rewind the roll"): the slip reads "Shutter locked · rewind on the Film Roll row" (camera test 21: "that worked!"). **The film window is taken out** (owner, test 21: "its pretty useless"): the label is the camera's own during a roll; test 22 pending. **OK at the end opens Picture Mode on the Film Roll row** (owner, test 21; the camera's own request for its control panel turned into Picture Mode's, then one Up): **camera-tested** (test 22: "it works!!"). The slip says "Shutter locked · press OK to rewind" again (test 23: "looks good"). **The canister on the film selection row too** (owner, test 23; camera test 24: "that looks pretty good"): the picked film at the roll's length, no length shown without a roll; the drawings at the screen's right, clear of the Reset text (test 26: "that looks great!"). **The length on the film selection row** (owner: "combine it with the film selction row"; "Combine, rear dial"): the rear dial picks None / 24 / 36 / 72 and winds a roll back there; OK at the end opens that row (test 27: "that is looking good"). Test 28: the Film Roll row left out, a "Rear dial / 36 exposures" label over the roll (camera: "looking good! This is working well"); open: the strip jumps to the middle on each rear-dial click. **The jump fixed** (test 29: "it works", but a flicker) **and the flicker fixed** (test 30: the film held through each click's step and arrow back; camera: "that looks great!"). |
| Fixed (2026-11-25) | The roll's ISO showed as "Auto 1792" in the super control panel: setting 1701 (ISO as picked) is written too now. **Camera-tested** (test 14: "iso shows 400 now"). |
| To do | C1–C4 (all from the card now), D4, E1–E2, F1–F2 (B2 not needed for now: owner, Q8) |
| Waiting on the owner | Q3–Q11 (each blocks the task it names); Q2 (this page's name) |

**Build:** `v0.41-fr6`, package `94730fcb…710c`, card file `OM3MOD/FILMROLL/FILMROLL.BIN` 14,200 B (`df21d9b8…46a1`). D2 changed only the card file.

**Full suite (fr4, 2026-11-24):** 174 pass, 3 FAIL, all static:
- `static:section-order`: the loader's file name and log label were in section 8: **fixed in fr5** (moved to sections 4 and 6; passes).
- `static:hook-list`: the three new hooks (hook_rv 0x610cd5c4, hook_rel 0x60b0cdad, hook_pk 0x610beb1a). **For the owner's review** (start-up rule: each only reads `fc_tab` / goes on as stock until the card file is loaded at a half-press); not recorded in hooks.json by Claude.
- `static:changed-bytes`: v0.41-beta itself already fails it (21 runs: the Picture Mode pages' sites, not yet recorded). Film Rolls adds 16 runs, all in the Picture Mode row-switch tables (the Film Roll row's entries, as r1). **For the owner's review**, as above.

**Files changed (uncommitted):**
- `firmware/src/frcard.s` (new: loader and stubs)
- `firmware/src/frblock.s` (new: the card file)
- `firmware/src/editor.s` (the row and the hook sites)
- `firmware/src/screeninfo.s`
- `firmware/src/editor.ld`
- `firmware/build.py` (make_frblock, hooks, the row)
- `firmware/VERSION`
- `tools/test/emu_test.py` (7 tests, card sub-folders, the block's fields)

**One change to an existing part:** two of the camera's Picture Mode lookup tables had a single slot left after the
Split toning row. The Film Roll row takes the slot of the Tone Balance row, which p4 removed from Picture Mode (owner,
2026-11-23). Nothing visible changes.

**Space used in the flashed firmware:** .ext4 1744/1776, .ext8 452/512, .ext15 139192/139264. Little is left.

**Lab notebook:** `research/NOTES.md`, "Film Rolls on the SD card, A1-A4 and D1" (and the Film Rolls v2 notes carried over from the old branch).

## Flash once (owner, 2026-11-24)

Owner: "I only want to have to flash once, then edit/change/even remove the film rolls from the sd card and the camera
still works as normal". OK'd: "Yes, rework it".

**The design:**
- **The flash** (frcard.s) carries what must be flashed:
  - the loader;
  - small sockets for the places Film Rolls joins the camera: each one asks "is the card file loaded? then its code,
    else as stock";
  - the Film Roll row's table entries.

  fr6 is meant to be the build that stays flashed.
- **The card file** carries all of Film Rolls' code, and any **new hook** it needs. It puts those in itself when it
  loads (fb_hooks, OMKit's method):
  - a 5-byte jump written through the uncached view, under the firmware lock;
  - the stock bytes checked first;
  - never across a 16-byte cache line.

  The key handler's hook (Playback lock, OK rewinds) already works this way; it is no longer in the flash.
- **Without the card file** nothing is written anywhere: the camera's code stays stock.
- **Limits:**
  - A new Caduceus release is itself a flash.
  - The card file is matched to the firmware build (its tag), so a release ships its own FILMROLL.BIN.
  - The sockets already in fr6 (hook_rv, hook_rel and the call sites inside our code) stay flashed: two are on busy
    paths, where flashed code is the safer place. Moving them changes no feature.

## How Phase 2 will work (the owner's rules for this job)

- Build and check everything possible in the emulator (om-emu, `tools/test/emu_test.py`).
- A task that needs the camera: finish its code, mark it **NEEDS CAMERA TEST** here with exact test steps (what to
  flash, what to do, what counts as pass or fail), then move on.
- An unanswered question: ask, keep working on tasks that don't depend on it, never decide it myself.
- **Never flash, never write to the camera or to a real SD card.** Test packages go in the private `test-builds/`
  folder only.
- **No commits.** Everything stays uncommitted in this worktree for the owner's review. (This replaces the repo rule of
  committing locally, for this job only.)
- The repo rules that still apply: the start-up rule (nothing of ours while the camera starts), only proven code space,
  an emulator test for every feature, images need the owner's approval, no OM firmware in the repo.

## What we start from

- **Film Rolls v2 r2b** (`try/film-rolls-r2b`, on v0.40.3-beta3), camera-tested in r1 and r2 except its last fix:
  - What works: frames are counted, the film and ISO are locked during a roll, and frames left show on the rear
    screen and in the viewfinder.
  - Rewind is done by picking None or a new length on the Film Roll row.
  - r2 froze the camera when Playback was opened during a roll. r2b's fix only writes the number on the shooting
    screen; it has passed the emulator but not the camera.
  - r3 adds the shutter stop at 0. It was made before the fix, so it gets redone.
- **Loading code from the card already works.** GUIDES.BIN has carried a code block since v0.20: it is checked,
  relocated and run from the camera's memory (camera-tested). That block is full (16,4xx of the 16,448 B the camera
  can hand out at once), so Film Rolls needs **its own file**.
- **Writing a file on the card already works** (the debug log). Its lesson (#85): never write from the shutter's own
  task, or the next shot waits for the card.
- **The flashed code space is almost full** on the newest builds: about 300 to 460 B are left in `.ext15`. Film Rolls'
  ~8 KB of flashed code from r2 does not fit there. Moving it to the card is the only way, not just the nicer one.

## Before we start (owner)

- **Q1. Which build to start from?** **Answered (owner, 2026-11-24): v0.41-beta.**
  - (a) v0.41-alpha, the newest published build. *My suggestion.*
  - (b) The five-point-curve build c7. It is newer, but local only and not released.
  - (c) Stay on beta3, where Film Rolls was built.

  With (a) or (b), the r2b code is carried over as uncommitted changes into a new worktree, and this page moves with it.
- **Q2. This page's file name.** The repo already has a `ROADMAP.md` at its root: the public roadmap that the website
  shows. I did not overwrite it. This page is `FILM-ROLLS-ROADMAP.md` next to it. Say if you want it named or placed
  differently.

## The tasks, in order

Each task lists what it needs first ("After"), how it is checked, and why. **Emulator** = om-emu can show it.
**Camera** = only the OM-3 can, for the reason given.

### Part A: the card version of what r2b already does

**A1. A loader for a second card code file, `OM3MOD/FILMROLL/FILMROLL.BIN`.** *Done in the emulator; NEEDS CAMERA TEST (fr1, now fr2).*
- **How it works:** loaded at the first half-press, like GUIDES.BIN: size check (≤ 16,448 B), its own tag, relocation,
  then a pointer the hooks read. No file, a bad file or no memory means the pointer stays empty, Film Rolls is off and
  the debug log says why.
- **After:** Q1.
- **Emulator:** boots with no file, a good file, a wrong-tag file and a too-big file. Checks that the entry points match
  a direct link and that nothing runs before the first half-press (as `ext15-code-waits-for-the-first-look` does).
- **Camera:** start-up feel and the first half-press with a real card. *Why:* om-emu can't measure lag, and its card
  is never slow.

**A2. Thin hooks in the flashed firmware.** *Done in the emulator; NEEDS CAMERA TEST (fr1, now fr2).*
- **How it works:** every Film Rolls hook becomes a few bytes: "is FILMROLL.BIN loaded? then call it, otherwise do
  what the camera did". These hooks are the same ones r2/r3 used:
  - the shot counter (ex_hook)
  - the film and ISO writes (sx_set, rc_go)
  - the row (st_get, sl_*)
  - the screen number (si_upd tail, hook_rv)
  - the half-press (lg_pr)
  - the release check (hook_rel)
- **After:** A1.
- **Emulator:**
  - the static checks (hook list, stock bytes, section order)
  - **a run without the card file that behaves exactly like the base build** (the whole suite)
  - the staged start-up check
- **Camera:** start-up and normal shooting with no Film Rolls files on the card. *Why:* hook_rv runs very often,
  including while the camera starts, so lag or freezes only show on the camera.
- **Space:** stubs only, a few hundred bytes. Where they go is checked at build time. If they don't fit, I stop and
  ask; I won't reach for unproven space.

**A3. Move r2b's logic into FILMROLL.BIN.** *Done in the emulator; NEEDS CAMERA TEST (fr1, now fr2).*
- **What moves:** loading a roll, counting, the film and ISO lock, frames left on the rear screen and in the
  viewfinder, rewind by the row, and the Playback-freeze fix.
- **After:** A2.
- **Emulator:** the six existing film-roll tests, now against the card file, plus the "number only on the shooting
  screen" test that r2's freeze build fails.
- **Camera:** real photos, bursts, RAW+JPEG, each viewfinder style, and **opening Playback during a roll** (r2's
  freeze). *Why:* om-emu takes no photos, and the freeze involved the camera's two processors, which om-emu doesn't run.

**A4. The shutter stops at 0.** *Done in the emulator; NEEDS CAMERA TEST (fr1, now fr2).*
- **How it works:** r3's release check, rebuilt on A3.
- **After:** A3.
- **Emulator:** the existing stop test, and the shutter still free with no roll, in video, and on another card.
- **Camera:** a real press at 0, a burst that reaches 0, and video still free. *Why:* real shutter and bursts are
  camera-only.
- **Unknown:** what a burst started with 3 frames left does. The check runs per release; whether it stops mid-burst is
  unknown.

### Part B: everything lives on the card

**B1. The roll is kept on the card (`OM3MOD/FILMROLL/ROLL.BIN` and its copy `ROLL2.BIN`, 20 B each; binary, not text).** *Done in the emulator (3 tests); NEEDS CAMERA TEST (in the next package). The camera's memory holds nothing of the roll any more. Written by the debug log's writer task (lg_wk) at a quiet poll; Film Rolls makes that task itself when DEBUG.TXT is off.*
- **What it holds:** film, ISO, length, frames shot and a roll number.
- **How it's written:**
  - Read at the first half-press.
  - Written after each photo and at each rewind, from the same place as the debug log (not the shutter's task).
  - A fixed size, because the camera's "w" does not empty a file first.
  - Two copies with a check number, so a battery pull mid-write leaves the other copy.
- **After:** A3; Q5.
- **Emulator:**
  - read and write
  - a torn write (one copy broken, so the other one is used)
  - a garbage file, which counts as no roll
  - a swapped card, i.e. another ROLL.TXT
- **Camera:**
  - shot-to-shot speed with a slow card
  - a battery pull right after a shot
  - the file on a real card
  - *Why:* the camera's file system differs from om-emu's stand-in (truncation, timing).

**B2. Your film shelf from the card (`FILMS.TXT`).** *Owner (Q8): for now the shelf is FILM 1–20 as they are; no FILMS.TXT needed yet (a canister designer in LookLab later, a follow-up).*
- **What it holds:** which films are on the shelf (FILM 1–20 and the COLOR profiles), each roll's label colour and box
  ISO, and the default length.
- **How it works:** read at the first half-press. A missing or bad file uses a built-in shelf and logs a line.
- **After:** B1; Q8.
- **Emulator:** good, missing, bad and over-long files.
- **Camera:** only as part of the other tests.

**B3. A roll log (`ROLLS.TXT`).** *Done in the emulator; NEEDS CAMERA TEST (fr4 + the new card file). A line per finished roll ("Roll 001, FILM 15, ISO 400, 24 exp, 24 shot"), newest last, oldest dropped past 3 KB. Photo numbers added (2026-11-25, owner: "Do the photo numbers"): ", photos 5178 to 5201, folder 100" from the camera's file counter (settings 41298 / 41282) read before the roll's first photo; the camera test checks the numbers match the files.*
- **What it holds:** one line per finished roll: roll number, film, frames, the first and last photo's file number.
- **After:** B1.
- **Emulator:** full.
- **Camera:** the file on a real card.
- **Unknown:** whether the camera's file calls can append. If not, the log is a fixed-size list (the last 50 rolls).

### Part C: the look, simplest first

**C1. Roll pictures (`ROLLS.BIN`).** *Set aside (owner, 2026-11-24: drafts 1–3 in the 62 px cells "still look bad"; private folder film-rolls-poll/roll-pictures-1..3). The rolls come with E (smooth, full colour).*
- **How they're made:** by a maker script (like LABELS.BIN), in the mock-up's style and the camera's sizes and
  colours.
- **After:** B2.
- **Emulator:** the maker's output, and the pictures drawn in place.
- **Owner:** approves every picture before it goes anywhere (repo rule).

**C2. Load screen, version 1.**
- **How it works:** the Film Roll row shows the roll pictures in its cells, the film and ISO in the title, and 24 / 36
  / 72. This uses machinery the camera has already shown in our Picture Mode cells.
- **After:** C1.
- **Emulator:** screenshots of every state.
- **Camera:** looks and dial feel.

**C3. End of the roll, version 1.**
- **How it works:** at 0 the number is orange (the camera's own colour) and the shutter is locked (A4). Research: can
  the camera's own message box show "End of the roll"?
- **After:** A4.
- **Emulator:** the GUI side.
- **Camera:** the look.

**C4. Film window on the shooting screen.**
- **Taken out (owner, test 21, 2026-11-25: "its pretty useless. I think you should just keep it as it works for standard .41b").** Was: **Built (2026-11-25, om-emu):** while a roll is in, the shooting screen's "COLOR 1" / "FILM N" reads the roll's box
  end ("Portra 400" over "36 exp"), from the card (WINDOW.BIN). Design approved by the owner (2026-11-25: "Window design looks good"). **Camera-tested
  2026-11-25 (test 7).**
- **How it works:** research first. The shooting screen draws each item through value-to-picture tables, so we could
  point a spare item at a roll picture.
- **After:** C1.
- **Emulator:** the shooting screen is drawn on the GUI side, so om-emu can show it.
- **Camera:** rear screen and viewfinder. This is not promised until the research works.

### Part D: no peeking, rewind, review

**D1. Playback locked during a roll, version 1.** *Done in the emulator as "does nothing" (the button is dropped in the camera's own key handling, hook at 0x610beb1a); NEEDS CAMERA TEST (fr2). Whether it should show a message instead is Q10.*
- **How it works:** the Playback button does nothing (or shows the camera's own message) while a roll has frames and
  isn't rewound. Research first: where the camera turns key code 26 into Playback.
- **After:** A3; Q3, Q10.
- **Emulator:** the key posted, the screen staying on shooting, no hang, and Playback normal again after the rewind.
- **Camera:** **the riskiest step** (r2's freeze was in this area). A go-back package is ready in the same folder.
  *Why:* the switch to Playback involves both processors.

**D2. Image Review during a roll.** *Done in the emulator (card file only); NEEDS CAMERA TEST (fr6). Image Review is setting 19 (Off 0, tenths of a second, Auto 255); Off at the half-press with a roll loaded, the user's value kept in the roll's record (on the card) and put back after the rewind.*
- **The issue:** with Image Review on, the camera shows each photo right after it is taken, which is a peek.
- **How it works:** depends on Q3.
- **After:** Q3.
- **Emulator:** the setting's value during and after a roll.
- **Camera:** that it holds.

**D3. Rewind, version 1.** *Camera-tested (test 7), then **taken out** (owner, test 20, 2026-11-25: "I want to have to go the the roll and phyiscally rewind the roll"): OK at the roll's end is the camera's own again; the roll is wound back on the Film Roll row (the crank).* (Was: at the roll's end, OK on the shooting screen rewound it at once.)
- **How it works:** the row as now, plus the button from Q4. Frames count back in the row's title. The roll goes in
  the log (B3), and Playback opens.
- **After:** D1, B3; Q4.
- **Emulator:** full.
- **Camera:** feel.

**D4. Review.**
- **How it works:** after the rewind Playback is normal, which comes free with D1. An optional extra is a "Roll 05 ·
  frame 17" tag in Playback, from the crop work's playback-label research.
- **After:** D1.
- **Emulator:** the label code by direct calls.
- **Camera:** the look on real photos (om-emu shows "No Picture" in Playback).

### Part E: our own screens (research, may not be possible)

**E1. Spike: draw with the Color Creator renderer, as OMKit does on the OM-5 II.** *Started 2026-11-24 (owner: "Yes, start it", after the cell pictures "still look bad"). Found: the same engine (OpenVG, EGL, C3D); the Color Creator renderer at 0x610507ba, starting as OMKit's hook site does; the drawing functions' addresses. The probe is built (card file only): stage 1 counts all four of the camera's drawing routines (which draws Color Creator, which the Picture Mode wheel), stage 2 (with DRAW.TXT) draws the loaded film's own roll (lettered, from ROLLART.BIN: every film x 24 / 36 / 72) in one of them. **NEEDS CAMERA TEST** (fr6 package, Part D). Camera-only (om-emu does not run the renderer).*
- **What it is:** find the OM-3's renderer entry and its "background" kinds, then draw one roll shape in Picture Mode.
- **After:** C2.
- **Emulator:** only the GUI side's order, because the renderer runs on the other processor.
- **Camera:** the drawing itself. *Why:* om-emu doesn't run it. OMKit had to test theirs on the camera for the same
  reason.
- **Time limit:** a fixed time limit. If it doesn't work, Part E stops and the version 1 screens stay.

**E2. Version 2 screens** (only if E1 works): the shelf, the rewind screen and the "Not developed" grid, all inside the
Picture Mode area OMKit proved. Full-screen versions go further than anyone has shown, and stay a question.
- **Designs approved (owner, 2026-11-24):** draft 1 of `firmware/mkscreens.py`: the end-of-roll slip (big amber
  frame count, "End of the roll", "Shutter locked · press OK to rewind"), the rewind panel (the film's roll, frames
  left, progress bar) and "Not developed" (gold label, a tile per frame, the counts).
- **Fitted in (2026-11-24, emulator: loading only):** the card file `OM3MOD/FILMROLL/SCREENS.BIN` (443 small pieces,
  368 KB; points closer than 0.15 px to the outline dropped) and the card file's code put each screen together from up
  to 4 pieces (panel, roll, numbers, frames / bar) in a 10 KB page. With DRAW.TXT: rewinding → the rewind panel; the
  roll's end → the slip; DRAW.TXT starting with `N` → Not developed (a test only: its real place is Playback). The
  flashed firmware is unchanged (fr6's 94730fcb…). **NEEDS CAMERA TEST** (the drawing is camera-only), and showing
  them on the shooting screen is still research.
- **Not developed in Playback (2026-11-24, om-emu):** during a roll Playback opens the camera's own empty-card screen,
  its text "Not developed: 17 exposed, 7 to go"; photos stay hidden until the rewind. Card file only (three hooks
  it puts in). **Camera (2026-11-24): FAIL** — the line shows, but leaving Playback with a half-press or the shutter
  freezes the camera (battery pull). Not in om-emu. Card back on v0.41-beta. **Owner: "im ok with playback doing
  nothing"**: taken out again; D1 (Playback does nothing during a roll) stays.

### Part F: finish

**F1.** Test steps for every NEEDS CAMERA TEST task, collected in order, and the packages in `test-builds/`.
**F2.** Docs for users (`docs/USING.md`, a release-notes draft). Nothing is published without the owner.

## Open questions for the owner

Answers (owner, 2026-11-24):

| # | Question | Answer |
|---|---|---|
| Q1 | Which build to start from | v0.41-beta |
| Q2 | This page's name and place | "yes that is great": `FILM-ROLLS-ROADMAP.md` |
| Q3 | Image Review during a roll | **Off during a roll** ("you can't preview shots on a real roll of film"), back after the rewind |
| Q4 | The rewind button | ~~As the mock-up: at the end of the roll, OK rewinds~~ **Changed (owner, test 20):** no OK to rewind; the roll is wound back on the Film Roll row (the crank: one click a frame, tests 16–19); the slip says so |
| Q5 | The roll belongs to the card | **Yes.** "very little to nothing on the camera. it should all be on the sd card": no roll record in the camera's memory |
| Q6 | A folder per roll | **A roll log** (owner, 2026-11-24: "Yes, use a roll log"): photos stay where the camera puts them |
| Q7 | ISO lock strict | Yes. **The roll's ISO (owner, 2026-11-24):** a film's box speed, never below 200; COLOR 1-4: 400; set at the half-press after loading, whatever ISO was set |
| Q8 | The default shelf and roll colours | **FILM 1–20 as they are**; the user chooses. Later maybe a film-roll canister designer in LookLab |
| Q9 | Delete during a roll | Delete only deletes in Playback; with no Playback during a roll it must do nothing on whatever screen Playback shows (depends on Q10) |
| Q10 | What Playback shows during a roll | Owner asks: a screen like the mock-up's ("Not developed")? *Answered 2026-11-24: not at once (own screens are task E). Version 1.5 to research: Playback opens on the camera's own "No Picture" screen during a roll (nothing to show, nothing to delete).* |
| Q11 | Lengths 24 / 36 / 72 | Yes |

## Unknowns I expect to hit

- Whether a refused release stops a burst partway (A4).
- Whether the camera's file calls can append to a file (B3), and how fast a small write is on a slow card (B1).
- Where the camera handles the Playback key, and whether blocking it is clean (D1).
- Whether the camera's own message box can carry our text (C3).
- How to put a picture on the shooting screen (C4): done (the picture-mode name's place).
- Whether the OM-3 has the same Color Creator renderer path as the OM-5 II, at what addresses (E1).
- Space for the flashed stubs on the chosen base (A2).

## Risks to the camera and how they're avoided

**Bricking (the camera won't start or can't be updated).**
- Only a firmware flash could do this. I never flash; you do.
- Every package keeps the camera's update path untouched.
- Every package comes with a go-back package (the base release).
- Before any package:
  - static checks of every hook's stock bytes
  - section order (two past boot loops came from code jumping into a section not loaded yet)
  - only proven code space
  - the staged start-up check
- No new code space past what the camera has proven.

**Boot loops or start-up lag.**
- The start-up rule: nothing of Film Rolls runs before the first half-press. The card file is only read then.
- Hooks that also run at start-up (hook_rv) check that the section is ready and the file is loaded first.
- Emulator tests watch for any early run.

**Freezes (r2's Playback freeze).**
- Each hook does its work only on the screen it belongs to (shooting screen = GUI state 0x0801 / 0x0108).
- The Playback lock (D1) is tested alone, with a go-back package next to it.

**SD card corruption or lost photos.**
- We only ever write inside `OM3MOD/FILMROLL/`: never DCIM, never the camera's settings files (BUNDLES / LOOKS /
  EDITS), never delete or rename.
- Writes use the camera's own file calls (proven by the debug log), off the shutter's task, small and fixed-size, two
  copies with a check number.
- Photos themselves are never touched.

**Stuck with the shutter locked.**
- Ways out: rewind always works; a card without the Film Rolls files gives a normal camera; video is never blocked.
- The stop only happens with a loaded roll at 0.

**Memory.**
- The card file must fit one allocation (≤ 16,448 B). If it doesn't, it isn't loaded and the log says so.
- Code runs from a normal (cached) block, as GUIDES.BIN does. The lk7 reboot came from code run uncached.
