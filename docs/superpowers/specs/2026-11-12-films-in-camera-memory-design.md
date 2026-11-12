# Films and edits in the camera's own memory: design of the final solution

Status: **design, 2026-11-12. Not built. No camera test has been run, and the owner has said he will not run camera tests for
this** (2026-11-12). So everything below marked "unproven" stays unproven until someone with an OM-3 tests it; see "Verification
and release". Research: `research/NOTES.md`, the six sections of 2026-11-12 from "Where the camera keeps its settings: trace 1" to "Trace 6".

## Intent

Swap SD cards on the fly with no computer. Today the 20 films, their edits and the mod's code block live on the card: a new card
means missing films, lost edits and "copy the right files first". The owner's wish: **everything that does not change is in the
firmware; the user's films and edits live in the camera; the card is only a way to bring new films in.**

## Goals

- Any SD card, or none, works: film list, film looks, the user's on-camera edits and the Extras-wheel settings come from the camera.
- New films from the Control Panel still arrive on a card (`LOOKS.BIN`) and are copied into the camera by an import step.
- Nothing that works today is lost: Film Grain, Glow / Clarity, split toning, edits per film (`*` and hold OK), the photo code, the Creative Dial rows.
- Cards from today's releases keep working: their `LOOKS.BIN` / `EDITS.BIN` / `BUNDLES.BIN` are imported once.

## Non-goals

- Our code never writes to the camera's flash itself (no flash driver calls, no new flash area, no change to the flash layout).
- No change to how the camera stores its own settings; COLOR 1-4 and the rest stay as they are.
- No use of the unloaded gaps of the firmware file; only proven space (CLAUDE.md "Firmware safety").
- The card is not removed from the picture: it stays the way to bring films in, to back up, and for the debug log.

## Anti-goals (a failure even if it "works")

- The camera not starting, or the owner's camera settings being reset by accident.
- A card swap, a settings reset or a firmware update silently destroying the user's films or edits (it may drop them, but the next import from a card must be easy and the user told).
- An old card's older files silently overwriting newer films in the camera.

## What the camera does (found by reading the OM-3 firmware 1.1 and its emulator; analysis, not camera-proven)

1. **The camera keeps its user settings in its own internal flash.** The block is the **M store**: 256 KiB, 1215 small items, kept in two
   alternating flash copies (wear levelling). Layout, header and trailer: 8-byte header {store id u16, checksum u16, counter u32} + items +
   4-byte trailer. Its RAM image is at `0x62920700`.
2. **When it is saved:** the GUI sets a "save setup" flag when the camera leaves a menu or the direct-select screens; when the camera
   next goes to the shooting-ready state it calls `saveUserSetup`, which writes M **if the byte `0xa32bfb32` is 1**. That byte is set by
   the camera's data-object write function when it changes a byte inside M.
3. **How it is saved and loaded:** load copies the whole image. Save compares the data area with the current flash copy (nothing written
   when equal), stamps a counter and a checksum (the 16-bit sum of the whole image is 0) and writes the whole image to the other copy.
   So any byte in M, listed or not, is loaded, checksummed and saved like the camera's own items.
4. **Room:** the camera's items end at image offset `0x39465`; the usable end is `0x3fff4`. **27,535 bytes of M belong to no item.**
   (E has about 37 KB spare but is not saved on the regular path; F about 122 KB, also not saved regularly; B is full.)
5. **The camera lists its items in a table** (list at `0x600e4bec`, entries `{u16 code, u16 count, defaults}`, 1215 items, ending in a zero code), used
   to register items at start-up and to build the default image; the size check is "items must fit in size - 12" (error 7427). A list entry of ours would
   have to be chained in (see approach B); the unlisted tail needs none of that.

Not proven on a camera: that a tail-only change is saved at the next menu exit, survives power-off and a battery pull, and loads back, and that the camera does not reset
the image because of it. That is the one assumption the whole design rests on.

## Approaches considered

| | What | Trade |
|---|---|---|
| **A (chosen by the owner)** | Our data is raw bytes at a fixed offset in M's unused tail; our code sets the changed byte after writing. | No change in start-up code. The camera does not know the block exists (fine for the final firmware 1.1). |
| B (kept in reserve) | Chain a short list of ours after M's list so the block is an official item (two hooks in start-up code, decoded in Trace 6). | Official slot, defaults and size accounting, at the price of two hooks in code that runs at boot. Only if A turns out to have a problem. |
| C | Our own flash writes. | Ruled out: unproven, could damage the camera. |

## The solution

### Where things live

| What | Where | Source today |
|---|---|---|
| The 20 default films (1,632 B) | **Firmware** (read-only, ext12 or the proven 256 KiB) | `LOOKS.BIN` |
| Code block, button / guide pictures, Extras labels, tone guides (about 46 KB) | **Firmware** | `GUIDES.BIN`, `LABELS.BIN`, `TONES.BIN` |
| The user's film bank, edits per film, Extras-wheel settings | **User block in M's tail** | `LOOKS.BIN`, `EDITS.BIN`, `BUNDLES.BIN` |
| Imports, backups, debug log | SD card (optional) | same |

### The user block

- **Base:** M image offset `0x3A000` = RAM `0x6295a700` (uncached alias `0xa295a700`). `0x39465..0x3A000` stays empty as a margin. Room to `0x3fff4`: 24,564 B; the block is
  limited to 8 KB (`0x3A000..0x3C000`), the rest is reserved for later. *(My call.)*
- **Layout (version 1):**

  | Offset | Size | Field |
  |---|---|---|
  | 0 | 4 | magic `OM3U` |
  | 4 | 2 | format version (1) |
  | 6 | 2 | length of the block |
  | 8 | 4 | CRC-32 of bytes 16.. to the end of the block |
  | 12 | 4 | generation (+1 at every change; for the import rule) |
  | 16 | 4 | CRC-32 of the `LOOKS.BIN` file the film bank was imported from (0 = built-in films) |
  | 20 | 4 | source stamp of that file (see "Import rule") |
  | 24 | 1632 | film bank, in the `LOOKS.BIN` format (header + 20 records of 64 B + names) |
  | next | 1648 | edits, in the `EDITS.BIN` format (24 records of 68 B with their check words) |
  | next | 544 | Extras-wheel settings, in the `BUNDLES.BIN` format |
  | rest | | zero, reserved |

  The existing formats are reused byte for byte, so the Control Panel, `docs/FORMATS.md` and today's parsers (`pf_*`, `ed_*`) are reused with a different source; only the container is new.
- **Writing:** plain stores to the cached address **and** the uncached alias (as the camera's own write function does), then store 1 in `0xa32bfb32`. We never call the camera's flash
  save; the camera saves at the next return to shooting (menu exit). The block is rewritten as a whole after its CRC-32 is updated, never half.
- **Reading at start-up (the first half-press, as the films load today):** valid block (magic, version, CRC) -> use it. Invalid or empty -> use the built-in films with no edits, and
  try the card import below. A bad block is never trusted and never blocks start-up.

### Import rule (new films from a card) *(my call; to confirm)*

- **First run / empty block:** if the card has `OM3MOD/LOOKS.BIN` (and optionally `EDITS.BIN`, `BUNDLES.BIN`) that pass today's checks, import them (migration from today's releases). Otherwise
  use the built-in films.
- **Later runs:** import only when the card's `LOOKS.BIN` is **newer** than the one the block came from, and only then. "Newer" needs a stamp: `LOOKS.BIN` v1 has no date, so the Control
  Panel adds a **saved-at stamp** (seconds since 2026-01-01, u32, in reserved bytes of the header; CRC and version rules keep old files valid) and the camera compares stamps, not contents. A card with a
  `LOOKS.BIN` without a stamp imports only into an empty block. This protects against an old card overwriting newer films.
- **What an import does to edits:** the existing rule is kept: each film's saved changes carry the CRC-32 of the `LOOKS.BIN` record they were made from; a film that changed in the
  Control Panel loses its on-camera changes, the others keep them.
- The import is silent on the camera (a line in `CADLOG.TXT`, a `*` as today). *(An on-screen message is possible later; not in version 1.)*

### What the card still does

- Optional backup: the camera keeps writing `EDITS.BIN` / `BUNDLES.BIN` to the card **when the card has an `OM3MOD` folder**, as a copy for the Control Panel and for recovery (today's behaviour,
  but never required and never read back except by the import rule above). *(My call: keeps the Control Panel's "read my edits" working.)*
- `CADLOG.TXT` / `DEBUG.TXT`, `OM3MOD` as the place for imports.

### What changes in the firmware (the builder's list)

1. Build step: link the default `LOOKS.BIN` content, the `GUIDES.BIN` code block and pictures, `LABELS.BIN`, `TONES.BIN` into firmware space instead of making them card files
   (`card/` makers become build inputs; `patch.py` still builds from the user's own firmware copy, nothing of OM's goes into the repo). Retire the "GUIDES.BIN must match the firmware" rule.
2. A small block layer (new code, ext12): `ub_load` (validate, set the data pointers `LPTR` / edits / bundles to the block or to the built-in copy), `ub_commit` (CRC, write both aliases, set `0xa32bfb32`),
   `ub_import` (read the card files, check them with today's checks, copy into the block).
3. Point the existing loaders (`pf_open` / `pf_load`, `gd_load`, `x_load`, the EDITS and BUNDLES readers and writers) at the block or the built-in copy; the SD file code stays for imports and backups.
4. `lg_pr` / the half-press path calls `ub_load` once per power-on and `ub_commit` where `ed_trig` saves today.
5. The Control Panel: write the saved-at stamp into `LOOKS.BIN`; optional: say "copy to the card, then switch the camera on with it" in the help.

### Failure and recovery

- Block invalid, wiped by a settings reset or a firmware update, or never written: the built-in films appear and the next card with a stamped `LOOKS.BIN` (or any `LOOKS.BIN` when the block is empty) repopulates it. The user's on-camera edits are lost in that case; the
  optional card backup (`EDITS.BIN`) lets the import restore them when the card has them. *(Documented in the FAQ when built.)*
- The camera's checksum / counter are never touched by us; the camera's own save seals the image.
- If the image were ever refused by the camera at start-up, the camera resets its settings to defaults (all of them, not only ours). This is the main risk and the reason for the verification below.

## Verification and release

- **Emulator (possible):** that the build registers nothing new, that the block lands at the right RAM address, that `0xa32bfb32` is set, that import and fallback behave, that the tail bytes are untouched by
  the camera's start-up code. The emulator stubs the flash write and does not power off, so it **cannot** show persistence.
- **Camera (not possible with the owner's camera, by his decision):** persistence over save, battery pull and card swap; no reset of the camera's other settings. Per CLAUDE.md nothing is **released** without
  a camera result. So this design stays unreleased until a tester with an OM-3 runs the checklist below and reports. *(A volunteer tester is a suggestion, not agreed.)*
- **Checklist for a tester (about 15 minutes):** (1) card A with the build and `DEBUG.TXT`: power on, half-press, open the MENU and leave it, half-press, check `CADLOG.TXT` says the block was written and saved (changed byte back to 0); (2) power off, pull the battery 30 s;
  (3) card B with no `LOOKS.BIN`: power on, half-press: the films from card A's import must be there, and `CADLOG.TXT` must say "block valid"; (4) check that COLOR 1-4, Picture Mode and the buttons are as before; (5) edit a film, leave the menu, swap cards, battery pull, check the edit is still there.
  Note the camera's important settings first: a bad image resets them.

## Milestones (each needs its own plan)

1. User block with the existing card files as the source (migration + import + backup), camera-tested by a tester.
2. Built-in default films and the code block, pictures, labels, tones in the firmware (no card files needed for a working camera).
3. Control Panel: saved-at stamp, wording, FAQ.

## Open questions

- Is a tail-only change saved at the next menu exit and loaded back? (The assumption; unproven.)
- Does a "Reset" in the camera's menu or a firmware update wipe the M tail? (Probably yes; documented.)
- Is an on-screen note for "imported N films" wanted? (Not in version 1.)
- Does anything else write M's tail? Not in the 1.1 firmware as far as read (all 1215 items end at `0x39465`); a different firmware version would need the layout checked again (`patch.py` should refuse other firmware, as today).
