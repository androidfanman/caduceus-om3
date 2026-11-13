# Caduceus for OM-3 v0.29-beta (test version)

**Your films, edits and Extras settings now live inside the camera, so any SD card works.** A test version of v0.29
for trying it early: v0.28 stays the main release. The firmware is the build tested on the camera on 2026-11-13
(build f2, after f1 and the probe mp1); only its name was changed to v0.29-beta.

**New on the camera**
- **Films in the camera's own memory:** the 20 films, the changes you make to them on the camera and the Extras
  settings are kept in the camera, in the memory where it keeps its own menu settings (a part of it OM's firmware
  1.1 doesn't use). The camera saves it when you go back to shooting from a menu or Picture Mode, and when you switch
  off. On the first start with this version the camera copies your card's `LOOKS.BIN`, `EDITS.BIN` and `BUNDLES.BIN`
  into its memory once; after that a card without them, or a blank card, still has your films.
- **Everything else is built into the firmware:** `GUIDES.BIN` (guide pictures and the code for Glow / Clarity, grain
  and the Extras), `LABELS.BIN` and `TONES.BIN` are part of the firmware now. Copies on a card are ignored. A card with
  no `OM3MOD` folder at all works in full (camera-tested: films, Glow and grain).
- **New films from the Control Panel:** export `LOOKS.BIN` as before and copy just that file to `OM3MOD` on the card.
  At the next half-press the camera takes the films **if it never had that set** (any change in the Control Panel
  makes a set new), keeping your selection, your Extras and the changes you made on the camera to films you didn't
  change. A card with films the camera already had, like an old card, is ignored, so it can't put old films back.
- **No copies on the card:** the camera no longer writes `LOOKS.BIN`, `EDITS.BIN` or `BUNDLES.BIN` to the card. So the
  Control Panel can't read changes you made on the camera from the card any more; it works from your saved list.
- **Debug log** (`DEBUG.TXT` in `OM3MOD`): says where the films came from ("the camera", "the card (films the camera
  never had)", "the card (first time)"); missing film files on the card are normal now.

**Redesigned films:** the optional `LOOKS.BIN` holds the 20 film sims redesigned as "signature" looks, compared with
real photos taken on each film (CineStill 800T sets Custom WB 3200 K and has Halation 3; CineStill 400D Halation 2).
It replaces your films; the camera takes it once. The live Control Panel keeps v0.28's films until v0.29 is the main
release; exporting `LOOKS.BIN` from it works with this version as before.

**Make it and copy it:** in this version's download, run the launcher and press Return (it makes v0.29-beta), or
`python3 firmware/patch.py --release v0.29-beta`. Copy only `DCOLYMP` and flash it (hold OK, then switch the camera
on). Leave your `OM3MOD` files on the card for the first start (the camera copies them in once); after that the card
needs nothing of ours.

**Good to know (test version):**
- A camera **Reset** in the menu or an **OM firmware update** probably clears this memory: the camera then copies a
  card's `LOOKS.BIN` (and `EDITS.BIN`, `BUNDLES.BIN`) again as on a first start. Keep a `LOOKS.BIN` of your films.
- Pulling the battery right after a change, before leaving the menu or switching off, can lose that last change.
- If the camera ever refused its saved settings it would reset **all** its own settings; that never happened in the
  tests (two battery pulls and many restarts on the owner's OM-3), but it is why this is a test version.

**Going back to v0.28:** make v0.28 and copy all its files (`DCOLYMP`, `GUIDES.BIN`, `LABELS.BIN`, `TONES.BIN`).
v0.28 reads the films from the card again: your card's `LOOKS.BIN`, `EDITS.BIN` and `BUNDLES.BIN` as they were when you
installed v0.29-beta. Changes made under v0.29-beta stay in the camera's memory, which v0.28 doesn't read.

**Thanks:** the research and design behind this (where the camera keeps its settings, and keeping our data there) are
by iancw ([#35](https://github.com/androidfanman/caduceus-om3/issues/35),
[#36](https://github.com/androidfanman/caduceus-om3/pull/36)).

The files here are the patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the optional extras
(`LOOKS.BIN`, `DEBUG.TXT`, the photo code kit, unchanged from v0.28) and the expected checksums. Full list of changes:
[CHANGELOG](../../CHANGELOG.md#v029-beta-test-version).
