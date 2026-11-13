# Caduceus for OM-3 v0.28

**Halation, finer split toning, a WB for every film, Blacks / Whites as one grid, and each photo's code now records
the film as you set it.** Firmware camera-tested (2026-11-12, build pc1; only its name was changed to v0.28).

**New on the camera**
- **Halation:** the red glow around bright lights of cinema film (CineStill and others), as its own Picture Mode row
  "Halation", 0 to 5, with or without Glow. A soft glow that fades in bright daylight scenes, with grain and bursts
  too. Saving a photo with Halation on takes a little longer. Method after Caduceus for the E-P7 by cakelesscoder.
- **Gentler, finer split toning:** the Shadows and Highlights wheels run 0 to 10 in half steps and only add a colour.
  10 is the old +5, so your films keep their look (a 2 now reads 4). New **Tone Balance** row right under HSL, −5 to
  +5: minus lets the shadow colour reach further into the picture, plus the highlight colour.
- **Each film remembers its WB:** every FILM and COLOR keeps the WB you last used with it (any mode, Custom WB with
  its Kelvin), as it keeps its HSL. Picking it brings that WB back; one that never had its own WB gets Auto.
- **Blacks / Whites as one grid:** the Blacks and Whites rows become one row with a grid like the WB shift grid
  (Blacks left / right, Whites up / down), now −7 to +7 each with the same step size. The row shows a "B/W ±" icon
  with the values under it; at 0 / 0 the B/W and WB rows show their icon alone, bigger.
- **The film in the photo, as you set it:** the code in each FILM photo's EXIF (om3.1) now holds the film as it was set
  when you took the photo, with your changes on the camera, Halation, Tone Balance and the camera's WB. Older readers
  still read it.
- **The `*` for a changed film** now also counts split toning, Halation, Tone Balance and WB, and shows on the super
  control panel too (FILM N\*).

**Control Panel** ([the site](https://androidfanman.github.io/caduceus-om3/)): Halation, Tone Balance, the 0–10
wheels, a WB mode per film (previewed as if the photo was taken in daylight) and the Blacks / Whites grid, with
previews. Choose **v0.28 or later** under Export › Firmware on the camera (older choices leave the new settings out).

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.28`). Copy
`DCOLYMP` (flash it: hold OK, then switch the camera on) and the `OM3MOD` files `GUIDES.BIN` and `LABELS.BIN` (both
new: always copy them with this firmware) and `TONES.BIN` (as v0.27.1). Keep your `EDITS.BIN`, `NAMES.BIN` and
`BUNDLES.BIN`. The optional `LOOKS.BIN` holds the 20 film sims as in v0.27.1 (it replaces your films).

**Going back to v0.27.1:** first set Blacks and Whites within ±5 on COLOR 1–4 (v0.27.1 resets a COLOR's saved
settings when they are past ±5). Then make v0.27.1 and copy all its files, its `GUIDES.BIN` and `LABELS.BIN` included.
v0.27.1 doesn't use Halation, Tone Balance or the films' WB memory and may clear them from your saved film changes,
and a split tone set to an odd number (1, 3, 5, 7, 9) shows as the opposite colour there.

**Optional extras:** `DEBUG.TXT` (copy it into `OM3MOD` only if you're asked for a log) and
`caduceus-om3-photo-code-kit.zip` (for developers: now reads Halation, Tone Balance, the WB and split toning 0–10).

The files here are the patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the card files, the optional
extras and the expected checksums. Full list of changes: [CHANGELOG](../../CHANGELOG.md#v028).
