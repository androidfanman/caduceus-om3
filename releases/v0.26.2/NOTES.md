# Caduceus for OM-3 v0.26.2

**Films load at power-on, the dials step through the films, and three fixes.**

- **No half-press any more:** your films and changes load from the card by themselves a moment after the camera
  starts, and live view and the labels follow. (A half-press or OK still loads them too.) This comes from
  [fernandezk26](https://github.com/fernandezk26/camera-stuff)'s fork: thank you.
- **Super control panel:** with the Picture Mode cell selected, the dials go COLOR 1–4, then FILM 1–20, and the label
  follows.
- **Fix: Film Grain with RAW+JPEG.** In v0.25 to v0.26.1 a photo with Film Grain and image quality RAW+JPEG was
  saved, then the screen went black and the camera froze. Fixed: grain works the same with RAW+JPEG and JPEG only.
- **Fix: "FILM N" on the shooting screen and in the viewfinder** was replaced by "COLOR n" when COLOR n's own
  settings had been changed.
- **Fix: bad bytes in `EDITS.BIN`** that could make a film's saved changes unreadable (found by fernandezk26).
- Everything from v0.26.1 stays.
- Firmware camera-tested (2026-11-09, build sd4).

**Copy to the card:** `DCOLYMP` (flash it: hold OK, then switch the camera on) and the `OM3MOD` file `GUIDES.BIN`
(made for this firmware: always copy it with it). `LABELS.BIN`, `TONES.BIN` and the optional `LOOKS.BIN` (the tuned 20
film sims; it replaces your own films) are the same as v0.26.1. Keep your `EDITS.BIN`, `NAMES.BIN` and `BUNDLES.BIN`.

**Going back to v0.26.1 or older:** flash that version with its own `GUIDES.BIN`; your files still work. Half-press
once after switching on again.

Make it: run the launcher and press Return (or `python3 firmware/patch.py --release v0.26.2`). The files here are the
patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the card files and the expected checksums. Full list of
changes: [CHANGELOG](../../CHANGELOG.md#v0262).
