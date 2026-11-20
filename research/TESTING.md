# Deterministic firmware tests

Research, 2026-11-15. Status: analysis, with emulator runs where marked. Nothing here is camera-tested. The suite is
built: seven emulator tests, the patch audit, and six static build checks, all run by `tools/test/emu_test.py`.

A deterministic regression suite for the firmware is possible and cheap to start. The emulator, om-emu, gave
byte-identical screenshots, card images, and settings files when one build ran the same script twice. om-emu also
ships a patch audit and a scripted session runner, so the suite is a small runner around om-emu, not a new harness.

Of 17 past regressions, the full proposed suite would have caught 7 and might have caught 4 more. It cannot replace the owner's
camera test. Start-up timing, stills, and video stay camera-only.

Read "Running the tests" to use the suite, and "Proposed suite" for what is built and what is not. Later sections hold the
evidence and the open questions.

## Running the tests

Build the firmware, then point the runner at the build folder and at om-emu:

```sh
python3 firmware/build.py --stock $OM3_STOCK --toolchain $OM3_TOOLCHAIN --out $OM3_WORK/out-NAME
OM3_EMU=$OM3_WORK/om-emu/emu python3 tools/test/emu_test.py $OM3_WORK/out-NAME
```

The static checks need the stock firmware. The runner takes it from `--stock`, else `$OM3_STOCK`, else
`$OM3_WORK/stock`. A check that cannot run counts as `FAIL`.

Use host paths for `OM3_EMU` and the build folder. A workspace made inside Docker writes `/work/...` paths into
`env.sh`, and those do not exist on the host.

The runner makes an emulator card from the build's `GUIDES.BIN` and `LABELS.BIN`, the newest release's `LOOKS.BIN`,
and `debug-log/DEBUG.TXT`. Each test then boots the build one or more times on a blank camera, carrying the card and
the camera's settings from boot to boot. It checks the debug log the firmware writes at each half-press. A first
boot that two or more tests share runs once, and each of those tests starts from its card and settings. Four tests
run side by side (`--jobs`), and the whole suite takes about a minute and a half: 85 s on a 32 GB Mac, against 153 s with
two jobs and no shared boots. It prints `pass`, `known`, or `FAIL` per test, with the
reason, and exits 1 on any `FAIL`. Each test's boots, logs, and cards stay in the `--out` folder.

Options:

| Option | Does |
|---|---|
| `--only NAME ...` | Runs only the named tests. A run with `--only` records no pass. |
| `--repeat N` | Runs each test N times, in `run1/`, `run2/`, and so on, and fails if any run fails. |
| `--without BUILD` | Needs `--only`. Runs those tests on a build without the fix and requires each to fail. It prints `caught` or `MISSED`, exits 1 on any `MISSED`, never records a pass, and ignores `KNOWN_FAILURES`. |
| `--stock PATH` | The official firmware file, for the static checks. |

`--without` shows whether a test can tell a fixed build from a broken one. Checked, emulator only:
`--without out-M295 --only film-kept-with-no-half-press-after-pick` on EL13 is caught, and `boot-smoke` is `MISSED`.

`known` marks a test listed in `KNOWN_FAILURES` in `tools/test/emu_test.py`, a bug the current release has. It does
not fail the run. When a listed test passes, the runner says to remove it from the list.

### Before a pull request

A pull request that changes `firmware/`, `card/`, `tools/emulator/`, or `tools/test/` needs a pass on its last commit:

1. Commit everything.
2. Build that commit with `firmware/build.py`.
3. Run the whole suite on the build, with no `--only`.

A full run that exits 0 on a clean checkout records the commit in `emu-test-pass.json` in the git folder. A
`FAIL` removes the record. The hook in `.claude/settings.json` runs `tools/test/pr_gate.py` before `gh pr create`
and before an MCP tool that creates a pull request. It refuses the call when the record is missing or names
another commit.

`firmware/build.py` writes `source_sha256` into the build's `build.json`. It is `source_digest(repo)` from
`firmware/provenance.py`, a sha256 over every file in `firmware/` and `card/` (it skips `__pycache__` and `*.pyc`).
The runner records a pass only when that digest equals the checkout's and the tree is clean, so a build from another
commit cannot record one.

The gate and the digest have unit tests that need no firmware:
`python3 -m unittest tools/test/test_pr_gate.py tools/test/test_provenance.py` (12 and 4 tests, standard library only).

| Test | Checks |
|---|---|
| `boot-smoke` | One boot with a half-press: the card files match the build, and the films load from the card |
| `films-from-camera-memory` | Two boots: the second takes the films from camera memory, not the card |
| `film-kept-with-half-press-after-pick` | A film picked and then half-pressed is still picked after a power-off |
| `film-kept-with-no-half-press-after-pick` | A film picked with no half-press after it is still picked after a power-off |
| `custom-mode-film-over-dial-turn-while-off` | Each custom mode keeps its own film when the dial turns while the camera is off, and the first look has a valid record |
| `dial-turn-before-first-half-press` | A dial turn before the first half-press lands in the right group, with the custom mode's film |
| `live-dial-turn-waits-for-the-mode-code` | A live dial turn from M to C1 switches the films only at the camera's real mode code, not at the dial's in-between code (#54). om-emu reports the real code at once, so the test writes the in-between state into memory |
| `live-dial-turn-back-keeps-the-mode-choice` | A live turn from M to C1 and back brings M back on its own film and picture mode |
| `live-dial-turn-to-b-switches-the-films` | A live turn from C1 to B switches to the P / A / S / M / B films, though B has no mode code of its own (#54) |
| `live-dial-turn-holds-the-label` | During a live turn's wait for the mode code, the shooting screen's label holds no picture, and the hold clears once the mode is real (#54) |
| `new-film-set-made-again-in-a-custom-mode` | A new film set taken in P: C1 (assigned on the old set, Save Settings: Reset) shows the new set's film with no '*' at the next turn, and again at the turn after a power-off (#86) |
| `new-film-set-made-again-in-p` | A new film set taken in P: P keeps its selection, its COLORs are made from the new films with no '*', also after a power-off (#86) |
| `new-film-set-taken-in-video-made-again-in-photo` | A new film set taken in video, then off: the next power-on in P and the turn to C1 make their films from the new set, no '*' (#86) |
| `new-film-set-keeps-changes-to-films-it-left` | A new set that changes only films 19 and 20: FILM 2 on COLOR 1 keeps its Contrast change and its '*' (#86, what stays) |
| `film-wb-mode-and-kelvin-set-on-pick` | A film with Custom WB 3200 K, picked: the camera's Kelvin (107, 1632) and the log's WB line say 3200 K (v0.28 film WB, kept as it was by #88) |
| `film-wb-shift-set-in-the-camera-fine-tune` | Four films picked in turn (Custom WB A3 M2, Shade G4, Auto B5, Sunny none): each sets its shift as the camera's own fine-tune of its WB mode, the one with none 0 / 0, and video's fine-tune stays 0 (#88) |
| `film-wb-shift-counts-once` | After a pick, the photo's WB reads (keys 34041 / 38521 through `wb_get`) get the film's shift once, not twice (#88) |
| `wb-reads-add-no-film-shift` | `wb_get` called directly with each slot set-up gives the camera's own read and calls the getter once (#88; v0.21..v0.40 added the slot's shift there) |
| `film-keeps-a-wb-shift-changed-in-the-panel` | The film's A-B changed in the super control panel's WB screen (A3 -> A4), another film, back: A4 again, and the film has a '*' (#88, owner's choice) |
| `picture-mode-row-shows-the-panel-wb-shift` | After that change, Picture Mode opened with no half-press between: COLOR 1's slot holds A4 (#88) |
| `picture-mode-row-wb-shift-sets-the-camera` | The WB Compensation row's fine-tune screen, A-B one step: the slot and the camera's own fine-tune both A4 (#88) |
| `new-film-set-sets-the-film-wb` | A new set that changes the film on screen (3200 K -> 5000 K, new shift): the camera gets the new film's Kelvin and shift at once; after a power-off, leaving the film gives no '*' (#88, a v0.40 bug) |
| `video-boot-after-photo-boot` | A video boot after a photo boot does no film or custom-mode work (#53) |
| `debug-log-written-at-releases-only` | Three half-presses: the debug log is written at the three releases only, not at the half-presses (v0.30.3; the burst rule needs photos: camera-only) |
| `debug-log-card-write-off-the-shutter-task` | Three half-presses with `DEBUG.TXT`: `CADLOG.TXT` is opened by the log's own writer task, never inside `lg_write` and never in the shutter's task (HLS_EVENT), and the log still says three writes (#85; the shot timing on a busy card is camera-only) |
| `debug-log-times-the-shutter-events-and-writes` | Three half-presses with `DEBUG.TXT`: the log's "Shot timing" line is there, every logged shutter event is timed (`lg_ptm`) in the shutter's task after `lg_write`, and every background `CADLOG.TXT` write is timed in the writer's task (glow-shots-1; the times themselves are camera-only: om-emu's counter barely moves and it takes no photos) |
| `halation-pauses-only-while-half-pressed` | `hl_yld` called directly: with the button up it returns, half-pressed it reaches the one-tick sleep (`sdl_dly_tsk` 1) and counts it, at 800 sleeps it returns; then a boot: a release clears `hl_hp` (glow-shots-2; the sleep, the AF and the shots are camera-only) |
| `noise-filter-row-follows-the-camera-setting` | A COLOR profile without a film, its Noise Filter on Camera: the Noise Filter row has no '*' with the camera's own Noise Filter on Standard or on Off, and gets one when Standard is chosen while the camera is on Off (v0.30 test 13) |
| `curves-file-kept-in-camera` | v0.30 `CURVES.BIN`: taken at the first half-press, a film picked shows its values, kept over a boot with no file, the same file again changes nothing |
| `curves-file-new-values-follow-edits-stay` | A new `CURVES.BIN` reaches a film you never changed; a curve changed on the RGB page stays when another file comes |
| `curves-file-none-or-not-valid` | No `CURVES.BIN`, or one with a wrong CRC: nothing taken, no film gets values (as test 8) |
| `color-wheel-dial-label-follows-the-page` | On the Color wheel, the dial label reads Sat, Sat (ALL), Hue, Lum, Tint, Tint as INFO steps through the pages, then Sat again (#64) |
| `color-wheel-dial-label-resets-with-the-page` | The wheel left on Hue: after the half-press the page and its dial label are back on Saturation (#64) |
| `color-wheel-front-dial-skips-all-colors-off-saturation` | The front dial stops on all colors (cursor 255) on Saturation only. On Hue it steps 1 -> 12 -> 1 over it (#64) |
| `color-wheel-readout-keeps-the-callers-a2` | On Hue, ed_get gives its caller a2 back after the label code. v0.20..v0.30.3 returned the call's return address in a2 (#64) |
| `color-wheel-tone-readout-keeps-the-callers-a2` | On Shadows, tn_get gives its caller a2 back after the label code (#64) |
| `color-wheel-saturation-guide-names-the-page` | The Saturation guide reads "Saturation [INFO]" with one color and "Sat. All [INFO]" with ALL, from the dial or INFO. The ALL guide is the camera's again off Saturation (#64) |
| `color-wheel-dial-step-writes-the-cursor-only` | A rear dial click on Hue and on Shadows writes only COLOR 1's cursor (2197) through the settings manager, the frame changes, and a click back gives the frame before it (experiment/wheel-speed) |
| `mix-and-rgb-dial-step-writes-the-panel-mode-only` | A dial click on the Mix page (both dials) and on the RGB page writes only the H&S panel's mode (2191) through the settings manager, the frame changes, and a click back gives the frame before it (experiment/rgb-cal-speed) |
| `border-dial-steps-as-contrast` | A rear and a front dial click step the Border row the way they step the camera's Contrast row: rear +1 up, front +1 down (experiment/border-dial-direction) |
| `glow-dial-steps-as-contrast` | The same for the Glow row, after Contrast: rear +1 up, front +1 down (experiment/perf-040, 2026-11-18) |
| `halation-dial-steps-as-contrast` | The same for the Halation row, after Contrast: rear +1 up, front +1 down (experiment/perf-040, 2026-11-18) |
| `tone-balance-dial-steps-as-contrast` | The same for the Split Tone Balance row, after Contrast: rear +1 up, front +1 down (experiment/perf-040, 2026-11-18) |
| `grain-dial-steps-as-contrast` | The same for the Film Grain row, after Contrast: rear +1 up, front +1 down, and the debug log names the strength it ends on (experiment/perf-040, 2026-11-18) |
| `look-tables-match-the-model` | `st_run`'s R, G and B tables on a fake COLOR job match the Python models for split toning, curves and both together, and `sd_crc` matches zlib's CRC-32 |
| `live-view-gates-wait-for-section-6` | The three live-view hook sites (hook_mx, hook_tone, hook_lv), called directly with the camera's ready word at 0x1f, reach the stock code (lv_skip with d0 = 11), and at 0x3f our code (fix/section-gates, 2026-11-17) |
| `patch-audit` | om-emu's audit finds no patched byte the camera does not load, and no task started at power-on |
| `static:release-rebuild` | `firmware/patch.py` rebuilds the newest release byte for byte, and `SHA256SUMS` matches |
| `static:hook-list` | The build's hooks equal `tools/test/hooks.json` |
| `static:hook-sections` | Each `.hook_*` section in `firmware/src/editor.s` has a hook entry, and the reverse |
| `static:changed-bytes` | Every byte that differs from stock lies in a place the build may write |
| `static:loader-end` | The loader's end word, read from the image, covers every section that uses it |
| `static:section-order` | No hook or patch site in sections 1..5 reaches our code or data in a later section (copied later while the camera starts), unless behind the camera's own ready check for that section |
| `static:comment-swallow` | No instruction line (one space, then a mnemonic) starts inside a `/* */` comment in `firmware/src/*.s`: a comment opened on the line above swallows it and it is never assembled (2026-11-18: a `blt` and a `bne` of the day's work, and two older ones) |

Results, emulator only:

| Build | Result |
|---|---|
| v0.29.5 (`out-M295`, the release byte for byte) | Exit 0. `film-kept-with-no-half-press-after-pick` is `known`, v0.29.5's bug. |
| EL13 (`feature/early-load`, which fixes that bug) | Exit 0, all pass |
| v0.29.5 with 4 bytes patched into the gap after section 1 | `patch-audit` fails and names the address `0x6031f010` |

Add a test as a list of `Boot` entries in `TESTS` in `tools/test/emu_test.py`. Each `Boot` takes a token string
for `tools/emulator/session_ed1.mjs` and regular expressions the debug log must match (`expect`) or must not match
(`reject`). A film pick needs a half-press earlier in the same boot, because the films load only at a half-press.
The debug log is written only at a half-press. The runner removes each boot's log from the card after reading
it, so a boot with no half-press has no log and cannot pass on an earlier boot's lines. Give such a boot no `expect`
or `reject`.

A `Boot` can also put files on the card before it boots: `card={'CURVES.BIN': 'CURVES_A'}` puts the `FIXTURES` entry
of that name into `OM3MOD/`, `None` removes the file (v0.30 test 9). Fixtures are made at run time in `--out/fixtures/`
from the newest release's `LOOKS.BIN` (`card/mkcurves.py`).

A `Boot` can count what the code does, for a change that leaves the log as it was. `watch=('fopen',)` names build
symbols, and `hits=fn` gets each time the code reached one, in run order, as `(symbol, string at a0)`, from power-on
on (`WATCH`, `WSTR` and `WBOOT` in `session_ed1.mjs`). `fn` returns the errors. `debug-log-off-writes-no-log` counts
`hl_ok` inside `lg_write` (and that the log's writer task is never made), and
`card-edits-and-bundles-unused-with-films-in-camera` names the files `fopen` opens. With `tids=True` each hit is
`(symbol, string at a0, task id, the HLS_EVENT task's id)` (`WTID`): `debug-log-card-write-off-the-shutter-task` checks
which task opens `CADLOG.TXT`. A task of ours that the firmware starts (#85's `lg_wk`) must be allowed in om-emu: the
runner passes its entry as `OM_WORKER_ENTRY` to every boot, and `session_ed1.mjs` adds it to the application's tasks. An
`ncall` call takes `count`, addresses whose hits during the call come back in its result's `count`. The WB and
Hue / Lightness tests count the getter calls that way.

`session_ed1.mjs` takes `PSET0` and `MODE0` in its environment, the photo/video switch and mode dial positions
before boot, and the tokens `pset:N` and `mode:N` to move them during a run. A `Boot` sets them with `photo_switch`
and `mode_dial`. `photo_switch=None` leaves `PSET0` unset. om-emu 0819080 (2026-11-14) reads an unset switch as
photo, so the video test sets the movie position (1) explicitly (v0.30 test 8).

The token `poke:ADDR=HEX` writes bytes into memory between keys, and `poke:ADDR+OFF*=HEX` writes them at the pointer
stored at ADDR, plus OFF. All numbers are hex. A token may name a build symbol in braces, such as `{rc_pend}`, and the
runner fills in its address from the build's `p.elf`. Use a poke only for a state om-emu cannot reach, and say which
camera state it stands for. The token `expect:mem:ADDR=HEX` ends the run with exit 1 unless the bytes at ADDR are
HEX, and fails the test.
The token `expect:isdef:FN:ID=V` calls FN (hex, usually `{ed_isdef}`) as the camera calls its "is at default" check
for a row id ID (hex), and ends the run with exit 1 unless it answers V: 1 for no '*', 0 for a '*' (v0.30 test 13).

The two custom-mode tests pass on v0.29.5, EL13, and C10 (an older early-load build), emulator only. They are weak:
neither fails on any build tried. `video-boot-after-photo-boot` does catch its bug: it passes with the #53 fix
(`2595c98`) and fails on v0.29.5, and `--without` reports it as `caught`.

- `dial-turn-before-first-half-press` passes on C10, which has the camera bug it targets, so om-emu does not
  reproduce that bug.
- `video-boot-after-photo-boot` checks the custom-mode line for `record writes: 0`. With the fix, video does no
  custom-mode work. v0.29.5 writes the record. The early load reads the mode code in video, so the line shows mode
  code 194 on either build. The test shows the code path the fix removes, not the freeze itself, which only the
  camera shows.
- `live-dial-turn-waits-for-the-mode-code` passes with the #54 fix and fails on EL14 (`main` before it), where the
  switch runs at code `C7` and the log reports 22 changed COLOR values in C1. The camera's in-between state is poked
  in: mode code 0 with the dial on C1.
- `live-dial-turn-back-keeps-the-mode-choice` passes with and without the second #54 fix. During a live turn the camera
  sets a picture mode of its own, and the fix keeps M from noting it as M's choice. om-emu's camera sets no picture
  mode at a turn, so the test checks only that the turn back lands on M's choice.
- `live-dial-turn-holds-the-label` checks the hold byte `lv_hold` with `expect:mem` during each wait and after each
  turn. om-emu's camera draws no label at a turn, so the byte stands for the picture. `--without` on DS2 prints
  `caught` only because DS2 has no `lv_hold`, so the flash itself is camera only.
- `noise-filter-row-follows-the-camera-setting` passes on test 13 and is `caught` on test 12 (the row starred at Off,
  `expect:isdef 7e11: 0, not 1`). The camera's own Noise Filter is poked into its byte (0x6295942d in om-emu, read by
  the stock getter 0x60063380); a setting write through the settings manager from the driver does not return.
- The film numbers (`COLOR 1, FILM 1` for C1, `COLOR 2, FILM 6` for P) break when `BOOT1_ASSIGN_C1` or the newest
  `LOOKS.BIN` changes. `BOOT1_ASSIGN_C1` is a constant in `tools/test/emu_test.py`.

### The om-emu version

`tools/emulator/om-emu.pin` names the om-emu commit that every workspace uses, and the date someone last checked
upstream. `research/setup.sh` checks out that commit, and `tools/test/emu_test.py` stops when om-emu is at another
one. After 7 days, setup and the runner warn that the pin is stale.

To move the pin, run `tools/emulator/bump_om_emu.sh` on a branch made from `main`. It builds the checkout, runs the
suite with the pinned om-emu and with upstream's newest commit, and prints each `pass`, `known`, or `FAIL` line that
changed. Then it writes the new pin.

- If no line changed, commit the pin file.
- If a line changed, find out why. A test that depends on how om-emu models the camera may need a change of its
  own. Commit that change with the pin file.
- To keep the old pin, run `git checkout tools/emulator/om-emu.pin`, then `research/setup.sh`.

The pin file is under `tools/emulator/`, so a pull request that changes it needs a suite pass.

## What a run can check

om-emu runs the patched main block on a model of the OM-3 (model `E147`). A script presses keys, turns dials, and
reads the result.

| A test can | How (om-emu `emu/bin/session.mjs` token) |
|---|---|
| Press, hold, or release a key | `s1`, `ok`, `menu`, `hold:ok:2000`, `ok:down` |
| Turn a dial or move a switch | `main_dial:+2`, `switch:mode_dial=3`, `switch:creative_dial=1` |
| Power off and start again | `power:off`, then `restart` (keeps the settings file and card) |
| Check the screen state | `expect:gui=SS_MENU/ID_ST_MENU`, `expect:gui~MENU` |
| Check memory | `read:ADDR:LEN`, `expect:mem:ADDR=HEX` |
| Check the card | `expect:card:OM3MOD/CADLOG.TXT`, `card-get:DOS/PATH=LOCAL` |
| Save a screenshot | `shot:FILE.png`, plus a frame hash on every step's JSON line |

Each step prints one JSON line with the lab time, the screen state name, and the frame hash. A failed `expect:` stops
the run with exit code 1. Settings persist across runs with `--nvram FILE`. The default is a blank camera.

Our own driver, `tools/emulator/session_ed1.mjs`, prints the editor's heap fields per step: the four slots' hue,
light, white balance (WB), black and white (B/W), glow, and effects values. `session.mjs` does not print these, so
tests on the editor read them with `read:` or keep using `session_ed1.mjs`.

Two om-emu features match bug classes this project has hit before.

- **Unloaded ranges.** `session.mjs` defaults to `--loaded auto`. Its summary lists, under `patch_audit.unloaded`,
  every patched byte the camera's boot does not load. On the camera those bytes are stale RAM. The sliders test in
  `research/NOTES.md` put code there and passed in the emulator.
- **Start-up tasks.** `patch_audit.tasks` lists firmware tasks a patch starts at power-on. The om-emu README names
  v0.27's film loader as its example. That loader broke the start-up rule in `CLAUDE.md`.

## Determinism results

Emulator only, on the C10 test build (`~/om3-work-linux/out-C10/main.bin`), two runs of each script side by side.

| Script | Runner | Same in both runs | Time per run | Peak memory |
|---|---|---|---|---|
| Start, menu, down, screenshot | `session_ed1.mjs` | Screenshot, card image, editor JSON | 12 s | about 1 GB |
| 30 tokens of menu moves, then power off | `session_ed1.mjs` | Screenshot, card image, settings file, editor JSON | 24 s | 1.3 GB |
| Second boot on the first boot's settings and card | `session_ed1.mjs` | Screenshot, settings file, editor JSON | 8 s | 1 GB |
| Start, half-press, menu, two `expect:` checks | `session.mjs` | Screenshot, frame hashes, lab times, card image | 11 s | 0.8 GB |

The only difference in any output was the screenshot path, which names the run. The deliberately wrong `expect:` in
the last script failed both runs with the same message and exit code 1.

Lab time moves only through script tokens (`--idle off`). The host clock is read once at start, and only when a
settings file is kept. A blank camera reads no clock. Two settings files from different days could therefore differ.
Tests should start blank, or from a stored settings file.

The remap-delete-button work compared C9 against C10, and C10 against EL11. It saw pixel-identical screenshots and
identical debug logs wherever the code paths matched. It never ran one build twice on purpose. The table above is the
first run of that kind.

## Proposed suite

Three layers, cheapest first. A change must pass each layer before the next one runs, and before the camera test.

| Layer | Runs | Time | Catches |
|---|---|---|---|
| Static build checks | `firmware/build.py` asserts, plus `tools/test/static_check.py` | Seconds | Wrong stock bytes, code outside proven space, stray writes, a changed hook list |
| Release rebuild | `static:release-rebuild`, from `firmware/patch.py --release vX` | Seconds | An unintended change to a shipped release |
| Emulator tests | `tools/test/emu_test.py` | 10–30 s each, several side by side | Menu flow, saved settings across boots, card-file handling, start-up tasks, unloaded code |

`emu_test.py` runs the static checks too, as the `static:*` tests. Built: all three layers. Not built: the card-file
size and checksum check, and the editor, no-card, and damaged-`LOOKS.BIN` emulator tests under "Tests to add next".

### Static build checks

`firmware/build.py` already asserts the following:

- The stock file's and decoded main block's sha256.
- Each hook's stock bytes at its address, and that its patch has the same length.
- Each patched data word's stock value, and how often it appears.
- Each section tail: the code fits, and the stock bytes there are all `0xFF`.
- `GUIDES.BIN` is at most 16448 B, the camera's malloc cap.
- The loader end word site, and `vf_end <= 0x6103f000`.
- The final package checksums, and that only components 0 and 2 differ from stock.

`tools/test/static_check.py` adds the checks below. They need the stock firmware, and numpy to decode it (the
script falls back to `$OM3_WORK/venv/bin/python`). A check that cannot run counts as a failure. It runs alone as:

```sh
python3 tools/test/static_check.py BUILD_DIR [--stock PATH] [--all-releases] [--write-hooks]
```

The stock path comes from `--stock`, else `$OM3_STOCK`, else `$OM3_WORK/stock`. It takes about 3 s for the newest
release. `--all-releases` rebuilt all 23 releases byte for byte in 44 s. All pass on v0.29.5 and EL13 (emulator only).

| Check | Catches | Limit |
|---|---|---|
| `static:changed-bytes`: every byte that differs from stock lies in a hook section, an `.ext*` section, the loader end word, the built-in files region (0x60f99800 up to the loader end word), or a patch site in `hooks.json` | A stray write anywhere in the image | The 322 patch sites are a reviewed snapshot from the v0.29.5 build, not derived from source. A new stray write is caught. A byte changed inside an existing site's run is not, and a run may shrink when a patched pointer into our code moves and one of its bytes matches stock. |
| `static:hook-list`: the build's hooks equal `tools/test/hooks.json` | A new hook nobody reviewed, such as one on the start-up path | `hooks.json` holds names, addresses, and lengths for 40 hooks, and no firmware bytes. |
| `static:hook-sections`: every `.hook_*` section in `firmware/src/editor.s` has a hook entry, and the reverse | A hook assembled but not placed, or placed but not built | |
| `static:loader-end`: the loader's end word, read back from the image, covers every section that uses it | Code past the loaded end, such as `.ext11` beyond 0x60f99800 | |
| `static:section-order` (crop round 7b, 2026-11-17; fix/section-gates): from each hook and changed patch site in sections 1..5, follows our code's direct jumps, calls and branches (objdump of `p.elf`, `-z`) and flags any later-section address reached or named, and any pointer into our later code. It keeps going past each crossing, with the later section as the new floor, so a path from section 5 on into 6 is found (hook_tone -> tone -> st_run). A jump or call right after `mov (0xa32de58c),dN; and MASK,dN; beq/bne` passes for any section up to MASK's lowest bit (the camera marks sections ready in order) | A hook on a path that runs while the camera starts jumping into code not copied yet, such as crop round 7's 0x6057fb1b, which boot-looped the camera; on main 78a809e: hook_mx, hook_tone (and its st_run), hook_lv | Indirect jumps and calls (`jmp (aN)`, `calls (aN)`) are not followed. The released paths it finds besides those three are listed in `LATE_RELEASED` (the shutter hook's, behind `hl_ok` / STATE; the stills hooks; the validator words): audited in research/NOTES.md "Section order audit" (2026-11-17), not proven. Needs the toolchain's objdump. |
| `static:release-rebuild`: `firmware/patch.py --release` rebuilds the newest release, and the `SHA256SUMS` line matches | An unintended change to a shipped release | |
| `static:section-order` (crop round 7b, 2026-11-17): from each hook and changed patch site in sections 1..5, follows our code's direct jumps, calls and branches (objdump of `p.elf`) and flags any later-section address reached or named, and any pointer into our later code; a jump or call right after `mov (0xa32de58c),dN; and BIT,dN; beq/bne` with that section's bit is a gate and passes | A hook on a path that runs while the camera starts jumping into code not copied yet, such as crop round 7's 0x6057fb1b, which boot-looped the camera | Indirect jumps and calls (`jmp (aN)`, `calls (aN)`) are not followed. The released paths it finds (21 entries in v0.30.x and border preview 1: the shutter hook, the picture pipeline's hooks, 13 menu and grain words) are listed in `LATE_RELEASED`, not proven: they start normally on the camera. Needs the toolchain's objdump. |

After a reviewed hook change, regenerate the list with `--write-hooks` and read each difference first.

Planted faults the checks caught (emulator only): a stray byte, a lowered loader word, corrupted hook bytes, an
edited `hooks.json`, an extra or renamed hook section, and a wrong `SHA256SUMS` line.

Not built: a check of `LABELS.BIN`, `LOOKS.BIN`, and `BUNDLES.BIN` sizes and checksums. A card file the camera rejects
is still found only on the camera.

### Emulator tests

`tools/test/emu_test.py` runs the boots with `session_ed1.mjs`, because it can set the photo/video switch and print
the editor's fields. It runs `session.mjs` once for the patch audit. `halation-matches-the-model` (2026-11-16, the
faster halation h7) boots no camera: `research/halation/emu_check.py` calls the halation pass (`hl_run`) directly on
ten small test frames and checks every byte against `research/halation/model.py`, the callee-saved registers and sp,
and a guard after the frame. Moving the boots to `session.mjs` would add its
`expect:` checks and frame hashes, once it can set the photo/video switch.

Store only state in the repo: screen state names, memory values, debug log lines, and frame hashes. The repo rule on
camera graphics keeps screenshots out, so a screenshot comparison runs against a local file from a known-good build.

Keep each script short, with few screenshots. The remap-delete-button work saw runs killed with exit code 137, which
is a SIGKILL. One killed run had about 30 tokens and 7 screenshots, with two runs side by side. The same boot cut to
14 tokens and 3 screenshots, run alone, passed in 17 s at 1.13 GB peak memory. Chain boots with `restart` instead of
writing one long script.

## Tests to add next

Ordered by how many past regressions each would have caught. Pass conditions name debug log lines where one exists.
The three tests built from this list (custom mode film over a dial turn, dial turn before the first half-press, video boot after a photo boot) are under "Running the tests".

| Test | Boots | Pass condition |
|---|---|---|
| Custom modes C1–C5 | Assign a different film to each mode, visit each | Each mode keeps its own film, and no `*` leaks between modes |
| Creative Dial positions | Boot at each `creative_dial` position | `Creative Dial family` matches the position |
| Editor slot edits | Open the editor, change hue, light, B/W, and effects rows, half-press | The editor's slot fields match the edits, and `Last save result` reports a save |
| Hold OK reset | Edit a film, `hold:ok` | The slot fields equal the film's defaults, and the `*` marker clears |
| No card | Boot 1 with the card, boot 2 with none | Films load from camera memory, and no firmware error |
| Damaged `LOOKS.BIN` | Truncated, wrong checksum, or bad header | `LOOKS.BIN: MISMATCH - damaged or the wrong format`, and films come from camera memory |

A damaged `LOOKS.BIN` test needs a known-bad file first. Old `EDITS.BIN` or `BUNDLES.BIN` files need no test:
v0.29.1 stopped reading them.

The calling-convention bugs (`call` overwrites the word at `(0,sp)` and MDR) caught three past regressions. A test
for them would watch the stack word and callee-saved registers across each hook with the om-emu debugger. That needs
more work than the tests above.

## What stays camera-only

- **Start-up timing.** Lag or a freeze at power-on came from work done while the camera starts (v0.26.2, v0.27, the
  films at switch-on). The `tasks` audit catches a task started at power-on. It cannot measure lag. It
  also misses start-up work a hook does in an existing task. EL13's early film load on `feature/early-load` passes it.
- **Stills.** om-emu has no sensor or capture pipeline, so grain, glow, halation, RAW+JPEG, and Pin Hole regressions
  need the camera. The halation pass's bytes are the exception (`halation-matches-the-model`, a direct call on test
  frames in plain DRAM); its timing, the bus window path it takes on the camera, and the capture route stay
  camera-only. Likewise our grain tile's bytes (`grain-tile-matches-the-model`, `tg_fill` called directly, against
  `research/grain/tile_model.py`); its time, the window path and the look on photos stay camera-only.
- **Video.** om-emu does not model movie recording. A camera video boot puts films back, and an om-emu one does not.
  The v0.29.5 live view freeze (#53) itself is camera-only. `video-boot-after-photo-boot` checks the code path its
  fix removes.
- **A live mode dial turn.** The camera reports an in-between mode code (`0xC0` plus the raw dial position) before
  the real one. om-emu jumps straight to the final code (#54).
- **Sporadic freezes.** A rare power-on hang does not show in a deterministic run, by design.
- **Cache effects.** The lk7 reboot at every half-press came from code run from an uncached heap block. The emulator
  ran it fine.
- **Card file system.** The camera's `fopen` with `"w"` does not truncate a file. The emulator's stand-in card does.

## Past regressions

From `git log` on all branches, `CHANGELOG.md`, `research/NOTES.md`, and the GitHub issues. "Catchable" means an
emulator test as proposed here would have failed. "Maybe" means it depends on a path the emulator models in part.

| Where | Symptom | Catchable | Test that would catch it |
|---|---|---|---|
| v0.29.5, #53 | Video live view freezes at the first half-press after a photo session | Yes, the code path | `video-boot-after-photo-boot` |
| v0.29.5, #54 | A live dial turn between M and a custom mode gives COLOR profiles "*" | Yes, with the in-between state poked in | `live-dial-turn-waits-for-the-mode-code` |
| DS1, #54 | After a live turn to C1 and back, M shows COLOR 1 instead of its own picture mode | No | None, the camera's own picture-mode write at a turn |
| DS2, #54 | A live turn from C1 back to M briefly shows "COLOR1*" before M's film | No | None, the camera's own picture-mode write at a turn. `live-dial-turn-holds-the-label` checks the hold |
| DS3, #54 | The same flash: at the turn the camera reads as video and makes no 901 write, so no hold is set | No | None, the emulator draws no label while the mode code is in between |
| e9b954f | Start-up path overwrote its caller's saved registers | Yes | Boot smoke, register watch |
| crop round 7 (2026-11-17) | Boot loop at every start: a section-2 hook (0x6057fb1b) jumped into section 6's extension before section 6 was copied | No in om-emu (it maps every section at once); yes statically | `static:section-order` |
| fix/section-gates (2026-11-17) | Live view's first picture set-up at power-on could jump into section 6 (hook_mx, hook_tone via st_run, hook_lv) before the camera marks it ready: never seen on a camera | No (om-emu maps every section at once and runs no live-view set-up); yes statically | `static:section-order`; `live-view-gates-wait-for-section-6` calls the sites directly |
| v0.28–v0.30.1, #65 (#27) | With Image Review on, a Glow or Halation photo gives a black review picture, then the Creative Dial to a standard picture mode freezes live view | No | None, om-emu develops no photos (the review picture is one of the shot's small extra developments) |
| v0.41-dev test 3 (2026-11-18) | A black Border (-1..-5) left the photo without a border: the capture's route check (xb_cap) sent only a Border above 0 through the Soft Focus passes where xb_gs draws it | No | None, om-emu takes no photos (xb_cap runs at a capture); `border-matches-the-model` covers the drawing itself |
| v0.41-dev test 4 (2026-11-18) | At 16:9, 3:2, 1:1, 3:4, 5:4, XPan and 21:9 the camera's 1600 px preview inside the JPEG (camera playback, phones) showed a 1 px line of picture at its cut edges: the camera cuts the preview a few px wider than the photo, past the border | Yes for the drawing (`border-matches-the-model` with the margin past a crop's cut sides; test 4's build `caught`); No for the preview itself (om-emu makes no JPEGs) | `border-matches-the-model` |
| v0.27..v0.40-beta2, #85 | With `DEBUG.TXT` on the card, a quick second shot in Single / Silent Single fired only once the card had written the last photo (worst on slow cards): the shutter's task (HLS_EVENT) wrote `CADLOG.TXT` at each release and waited for the camera's file task | No for the shot timing (om-emu takes no photos and its card is never busy); Yes for the cause, where the write runs | `debug-log-card-write-off-the-shutter-task` (v0.40-beta2's build `caught`) |
| v0.40-beta2 (owner, 2026-11-19), with #85 | With Glow or Halation on, only one picture in a row in Single: the next shot waited until the slow photo was saved. Analysis: #85's release-time `CADLOG.TXT` write in the shutter's task, waiting behind a photo that Glow's Soft Focus passes and our halation pass make seconds slower to develop and save | No (om-emu takes no photos, its card is never busy and its counter barely moves) | None for the timing; `debug-log-card-write-off-the-shutter-task` for where the write runs, `debug-log-times-the-shutter-events-and-writes` for the log's camera timing |
| glow-shots-1 (owner, 2026-11-19) | With Halation on, presses in Single during the photo's 1.4-1.7 s halation pass took no shot, while Glow shot freely and the shutter handler ran at once. Analysis: `hl_run` holds the lock (interrupts and dispatch off) for nearly all of it on the CPU that also builds live view's requests, and Single (S-AF) waits for the AF | No (om-emu takes no photos, runs no AF and its counter barely moves) | `halation-pauses-only-while-half-pressed` for the pause's gate (glow-shots-1's build `caught`); `halation-matches-the-model` for the picture |
| v0.40-alpha .. v0.40b, #83 | After a power-off in XPan or 21:9 the camera started in 16:9 (5:4: in 4:3) until the first half-press: the crop came back only at the first shutter event | Yes | `crop-xpan-back-at-start-up` (Image Aspect before any half-press); `crop-start-up-restore-photo-only` (cr_el's gates, the half-press fallback) |
| test 8 = crop83-2 (2026-11-18), #83 | XPan not kept through one power cycle: the camera saved M without a callback while on ("save patches 2"), cr_sin left the live Image Aspect at the crop's base, and the power-off save sealed no tag | Yes, with the camera's own save of M called mid-session | `crop-kept-over-a-save-of-m-while-on` (crop83-2's build `caught`) |
| crop83-1 (2026-11-18), #83 | The crop put back at start-up was undone later in the same power-on (log: "then 3, set to 6, after 6, now 3"); the next start showed 16:9 | No for the cause (om-emu's start-up is over before the GUI's first state change and it runs no live view); Yes for the put-back, with the base poked back | `crop-kept-when-the-camera-puts-the-base-back` (crop83-1's build `caught`); `crop-xpan-21-9-5-4-kept-over-power-cycles`, `crop-user-pick-after-start-up-kept` |
| v0.30, menu-flicker | Leaving Blacks / Whites or WB compensation flashes the old row's bottom bar for a frame | No | None, om-emu draws only after the screen update. `grid-row-gives-the-bottom-bar-back` checks the bar comes back |
| v0.30.1 and later, tone-page-flash | Moving between WB Compensation and Highlight & Shadow shows one frame with an empty table area: no grid, no curve | No | om-emu draws both passes inside one key event, before its next frame, so the frame itself is camera-only. `wb-to-highlight-shadow-sets-the-scene-in-the-row-refresh` checks the cause: no `sc_set` between `gr_upd` / `gr_end` and the update's end |
| v0.30–v0.30.3, #72 | Switching films fast in the Picture Mode list (holding the arrow, or FILM 1 <-> FILM 2) reboots the camera | Yes | om-emu does not reboot; the cause (the group's record kept at every step, camera probe J) is counted: `film-list-keeps-the-record-once-as-it-closes`, `control-panel-dial-keeps-the-record-once-as-it-closes` |
| v0.26..v0.40b (live look, 2026-11-18) | Split toning, Tone Balance, Blacks / Whites and the RGB curves reach live view only at the next half-press / AF: the camera rebuilds a job's tone tables only when its context's mask (C+60) asks | Yes for the cause (the camera's development function run whole on a fake live-view job: test 7 `caught`); No for the live view picture (om-emu runs no live view jobs) | `live-view-tone-tables-follow-a-change` |
| 331691c | Custom mode showed the previous mode's films until a half-press | Yes | Custom modes |
| 6438628, ea8b97c | A film picked with no half-press was lost at power-off | Yes | Film picked before the first half-press |
| v0.29.2, #41 | C1–C5 mixed films with saved settings, `*` leaked | Yes | Custom modes |
| v0.29-beta | Card-less load brought back the start-up freeze | Maybe | Boot smoke, no card |
| v0.29.4, #50 | Photo not saved after changing film grain | No | None, stills |
| v0.27.1 | Rare power-on freeze, battery pull needed | No | None, sporadic timing |
| v0.27 | Dial mapping at power-on | Maybe | `tasks` audit |
| v0.26.2 | Film Grain with RAW+JPEG froze after a photo (#18) | No | None, stills |
| v0.26.1 | `EDITS.BIN` unused bytes saved as `0xFF` made edits unreadable | Yes | Static file checks, two boots |
| v0.26 | Restart after a drive mode change, then COLOR or FILM | Maybe | Menu flow |
| v0.25 fx | Noise, Vignette, and Grain option lists wrong | Yes | Editor slot edits |
| v0.25 fx3 | Settings not saved, `gd_set` overwrote saved `a2` | Yes | Film kept over power-off |
| v0.24 | Film Grain High photo rebooted the camera | No | None, stills |
| lk6, lk7 | Reboot at every half-press, 1 s hang on COLOR switch | No | None, cache |
| #11, #12 | Video with a new film crashed, grain with glow crashed | No | None, video and stills |

Of these 20, 8 are catchable, 4 maybe, and 8 not. The owner's camera or a user found every one of them first.

Two classes recur. Start-up and first half-press work accounts for six of the 18. The
calling convention accounts for three. Settings kept per mode and across boots is the most testable class.

## Open questions

- **Exit code 137.** The killed runs used Node on the macOS host, not in Docker, so no container limit applied. A
  V8 heap overflow exits with 134, so something outside Node sent the kill. The shell tool's 600 s timeout was not
  it, because the runs ended well before it. The likely cause is macOS jetsam, the low-memory killer, but no one has
  confirmed it in the system log yet.
- **Node version.** The om-emu README asks for Node 26 or newer. The runs above used Node 24.22.1 without a problem.
- **om-emu version.** `research/setup.sh` clones om-emu at its newest commit (`--depth 1`). A suite needs a pinned
  commit, so an upstream change cannot alter results. The checkout used above is `7063b53` (2026-11-13).
- **om-emu license.** The repository has no license file. Ask upstream before vendoring or redistributing it.
- **Continuous integration.** The tests need the stock firmware, which cannot be in the repo or in a public CI
  runner. The suite runs locally, or on a self-hosted runner that holds each person's own copy.
- **Two workspaces.** `~/om3-work` on this machine is incomplete: it has no `env.sh`, no card image, and no om-emu
  sources. The working one is `~/om3-work-linux`. It builds firmware in a Docker `ubuntu:24.04` container and runs om-emu on
  the host. The runner should take
  the workspace from `env.sh` and fail clearly when it is missing.

## Sources

- om-emu `emu/README.md`: the "Scripted sessions" section and the patch audit.
- om-emu `emu/bin/session.mjs`: its usage comment.
- `tools/emulator/session_ed1.mjs`, `research/setup.sh`, and `firmware/build.py`.
- `research/NOTES.md`: the sliders test, lk6 and lk7, the strips regression, C9 and C10, and the video freeze.
- `CHANGELOG.md`, `git log --all`, and GitHub issues #5 to #53.
- The remap-delete-button session's emulator runs, 2026-11-15.
