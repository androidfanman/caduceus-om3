# Automatic SD loading (v0.25.1-sdload)

**Status: emulator only. Not camera-qualified by this project.** The worker's design and its offline qualification come
from a separate research track (its hardware unknowns are listed below); this document records what the patch does and what
has and has not been shown.

## What it does

Upstream v0.25 loads the card block (`OM3MOD/BUNDLES.BIN`, `GUIDES.BIN`, `LABELS.BIN`, `LOOKS.BIN`, `NAMES.BIN`) from the
shutter-event hook (`pr_hook`, stock `0x60415216`) through `pr_gate`: nothing loads until the first half-press (or other
shutter event) after power-on. This patch adds a small worker task that loads it **without a key press**:

- `sdl_worker_entry` (task `SDLOAD`, priority 56, 2 KiB heap stack) polls every ~100 ms until the loader's section masks
  (`0xa32de590 & 0x3ff`, `0xa32de58c & 0x2e9`) and the kind-4 medium word (`0x60369308 == 0xf000`) allow a load, then sends
  one zero-timeout wake message (`{0, 0x0100f7ed, 0}`) to the HLS_EVENT task's queue (`0x60043180`); after a send it skips
  ten polls. It stands down (`ext_tsk`) as soon as `STATE` (`0x62b4dd16`) is non-zero.
- The HLS_EVENT receive boundary (`0x60af101c`) runs `sdl_receive_probe`: on the wake it checks the masks and the medium
  again, asks the drive status (`0x608e7b48`, `0x1080` after masking `0x10bf`), and calls **the same `pr_gate`** the
  half-press hook uses (so the once-per-power-on `STATE` claim and every other check are unchanged). It also loads on the
  OK key message `0x02000004` when a medium is mounted. Every other message goes to the stock classifier.
- Two stock 5-byte `call`s are replaced by `jmp`s: `0x60af0fb9` (HLS_EVENT entry, creates the worker) and `0x60af101c`
  (the receive boundary). Stock bytes are asserted by `firmware/build.py` (`.hook_hb`, `.hook_hr`).
- The half-press hook and the OK trigger remain, so there are three triggers for one gate.

## Where the code lives

`firmware/src/editor.s`, last block (`sdl_*`, section `.ext4`); `firmware/src/editor.ld` (two hook sections and twelve stock
function addresses); `firmware/build.py` (`HOOKS`). The block is `research/sdload/native2.s` renamed with
`research/sdload/port_native2.py` (`sdl_` prefix, sections mapped onto `.hook_hb` / `.hook_hr` / `.ext4`, `STATE` and the
medium words reused from `editor.ld`); the original keeps its own gate (`gate`) which here is `pr_gate`.

**Room.** `.ext4` had 16 free bytes; the worker is 391 bytes. `nm_load`, `nm_pick` and `nm_path` (the `NAMES.BIN` loader)
moved from `.ext4` to `.ext11`: they run only after `pr_gate`, when every section is loaded, so `NAMES.BIN` still works.
`.ext4` is now 1,564 of 1,776 bytes, `.ext11` 63,200 of 65,536.

## What was checked

- Builds (`firmware/build.py`; stock bytes at both hook sites asserted; all six container checksums hold; components 1-5
  equal to the release's).
- Emulator (om-emu `147ca89c`, `tools/emulator/session_autoload.mjs`; the harness writes the section masks and the medium
  word as the lab runs neither loader): without the worker `STATE` stays 0; with it `STATE` is published within 500 ms with
  no key press, to the same block address an S1-triggered load gives. The lab needs the worker's entry on its task
  allow-list (`entry - 0x10021020`).
- Upstream's WB-grid restart recipe (previous commit) completes on this build.

## What was not checked (hardware-only)

AF / capture starvation from the poll, cross-core cache visibility of the published block, real section load order,
the poll's cost with no card over a long session, card removal after the load, power-cycle behaviour. The WB-fix is the only
part another party has camera-tested (upstream, as its v0.26 build).

## Build note: graphics

`firmware/mkicons.py` and `card/mk*.py` render pictures with DejaVu Sans Condensed. Rendering differs slightly between
FreeType/Pillow versions, so a source build on another machine is not byte-identical to a release's pictures
(and the length constants that follow them). Use `patch.py --release v0.25.1-sdload` for the exact package.
