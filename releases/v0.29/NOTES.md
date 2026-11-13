# Caduceus for OM-3 v0.29

**Your films, edits and Extras settings now live inside the camera, so any SD card works.** Firmware camera-tested
(2026-11-13, build f2; only its name was changed to v0.29), the same firmware as the v0.29-beta test version.

**New on the camera**
- **Films in the camera's own memory:** the 20 films, the changes you make to them on the camera and the Extras
  settings are kept in the camera, in the memory where it keeps its own menu settings (a part of it OM's firmware
  1.1 doesn't use). The camera saves it when you go back to shooting from a menu or Picture Mode, and when you switch
  off. On the first start with this version the camera copies your card's `LOOKS.BIN`, `EDITS.BIN` and `BUNDLES.BIN`
  into its memory once; after that a card without them, or a blank card, still has your films.
- **Everything else is built into the firmware:** `GUIDES.BIN` (guide pictures and the code for Glow / Clarity, grain
  and the Extras), `LABELS.BIN` and `TONES.BIN` are part of the firmware now. Copies on a card are ignored. A card with
  no `OM3MOD` folder at all works in full.
- **New films from the Control Panel:** export `LOOKS.BIN` and copy just that file to `OM3MOD` on the card. At the next
  half-press the camera takes the films **if it never had that set** (any change in the Control Panel makes a set
  new), keeping your selection, your Extras and the changes you made on the camera to films you didn't change. A card
  with films the camera already had, like an old card, is ignored, so it can't put old films back.
- **No copies on the card:** the camera no longer writes `LOOKS.BIN`, `EDITS.BIN` or `BUNDLES.BIN` to the card. So the
  Control Panel can't read changes you made on the camera from the card; it works from your saved list.
- **Debug log** (`DEBUG.TXT` in `OM3MOD`): says where the films came from; missing film files on the card are normal.

All of this was tested on the camera: two battery pulls with the camera's own settings unchanged, a card without
films, a card with no `OM3MOD` folder (films, Glow and grain), and new films from a Control Panel export.

**Films and Control Panel:** the optional `LOOKS.BIN` holds the **standard 20 as in the Control Panel now**: 18 films
colour-matched to film scans of a colour chart (Portra 160 / 400 / 800, Gold 200, ColorPlus 200, Ektar 100, Ektachrome
E100, Velvia 50, Provia 100F, Pro 400H, Pro 160S, NPS 160, NHG II 800, Superia 400, Fuji C200, Fujifilm 200 / 400,
Natura 1600) plus CineStill 800T and Kodachrome 64. These looks are new and previewed in the Control Panel; they
haven't been shot on a camera yet. Copying it replaces your films (the camera takes it once). The Control Panel also
draws the Shadows / Highlights wheels as the camera does now, opens a film from your own LUT or Lightroom preset, and
explains the v0.29 card rules under Install and Export.

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.29`). Copy only
`DCOLYMP` and flash it (hold OK, then switch the camera on). Updating from an earlier version: leave your `OM3MOD`
files on the card for the first start (the camera copies them in once); after that the card needs nothing of ours.
Coming from v0.29-beta: your camera already has its films; flashing v0.29 keeps them.

**Good to know:**
- A camera **Reset** in the menu or an **OM firmware update** probably clears this memory: the camera then copies a
  card's `LOOKS.BIN` (and `EDITS.BIN`, `BUNDLES.BIN`) again as on a first start. Keep a `LOOKS.BIN` of your films.
- Pulling the battery right after a change, before leaving the menu or switching off, can lose that last change.

**Going back to v0.28:** make v0.28 and copy all its files (`DCOLYMP`, `GUIDES.BIN`, `LABELS.BIN`, `TONES.BIN`).
v0.28 reads the films from the card again: your card's `LOOKS.BIN`, `EDITS.BIN` and `BUNDLES.BIN` as they were when you
installed v0.29. Changes made under v0.29 stay in the camera's memory, which v0.28 doesn't read.

**Thanks:** the research and design behind keeping the films in the camera are by iancw
([#35](https://github.com/androidfanman/caduceus-om3/issues/35), [#36](https://github.com/androidfanman/caduceus-om3/pull/36)).

The files here are the patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the optional extras
(`LOOKS.BIN`, `DEBUG.TXT`, the photo code kit, unchanged from v0.28) and the expected checksums. Full list of changes:
[CHANGELOG](../../CHANGELOG.md#v029).
