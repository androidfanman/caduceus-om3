# Caduceus for OM-3 v0.26

**Split toning, and a fix for a restart after changing the drive mode.**

- **Split toning:** two new pages on the HSL wheel, **Shadows** and **Highlights** (press **INFO** after Luminance).
  Each tints the shadows or the highlights toward one of the wheel's 12 colours: as on the other wheel pages, the
  front dial picks the colour and the rear dial sets the strength −5..+5 (minus tints toward the opposite colour). It shows in live view and in the photo,
  and is kept per film and over power off like the other settings. **Hold OK** resets it with the rest of the look,
  and the `*` marks it only when a strength is set.
- **Fix: restart after changing the drive mode.** In v0.25, changing the drive mode (for example to silent shooting)
  and then opening a COLOR or film to change it could restart the camera. Fixed.
- **The 20 film sims** (optional `LOOKS.BIN`) now carry a light split tone on ten films: Portra 400, Portra 800,
  CineStill 400D and Vision3 250D (blue-cyan shadows, orange highlights), CineStill 800T (cyan / orange, stronger),
  Kodachrome 64 (blue / yellow), Pro 400H (cyan shadows), Superia 400 (green shadows), Fuji C200 and Fuji Eterna
  (green-cyan shadows). The other films are as in v0.25. Tuned on the Control Panel's preview: check them in live
  view and adjust to taste.
- The dial label on the Color page stays the camera's own.
- Everything from v0.25 stays: fast colour grain, the WB grid row, the Glow row, Shading, settings kept over power off.
- Firmware camera-tested (2026-11-09, build sp4: photos, live view, the drive-mode restart, the `*` and Hold OK).

**Copy to the card:** `DCOLYMP` (flash it) and the `OM3MOD` files `GUIDES.BIN` (made for this firmware: always copy
it with it), `LABELS.BIN` and **`TONES.BIN` (new: the guides for the Shadows and Highlights pages)**. Keep your
`EDITS.BIN`, `NAMES.BIN` and `BUNDLES.BIN`.
**To get the 20 films with their split tones:** also copy this release's `LOOKS.BIN` to `OM3MOD`. This **replaces
your own films**, so keep a copy of your old `LOOKS.BIN` if you want it. Or build your own set in the Control Panel
(**New › Reset looks to standard** gives the same 20) and export with **Firmware on the camera: v0.26 or later**,
which is what saves split toning. Your v0.25 `LOOKS.BIN` works as it is (no split toning).

**Going back to v0.25 or older:** flash that version with its own `GUIDES.BIN`; your files still work (older firmware
ignores split toning).

Make it: run the launcher and press Return (or `python3 firmware/patch.py --release v0.26`). The files here are the
patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the card files and the expected checksums. Full list of
changes: [CHANGELOG](../../CHANGELOG.md#v026).
