# Caduceus for OM-3 v0.29.1

**v0.29 with one fix: your films now load with no card in the camera.** Firmware camera-tested (2026-11-13, build n1;
only its name was changed to v0.29.1).

**Fixed**
- **No films without a card** ([#38](https://github.com/androidfanman/caduceus-om3/issues/38)): in v0.29 the films are
  kept in the camera, but with no card in it the Picture Mode list showed only COLOR 1–4. The film load at the first
  half-press still waited for the camera to report a card. Now, with no card, the films, your changes and the Extras load
  from the camera's own memory at the first half-press. With a card in, everything works as in v0.29.

Small side effect: if a card with **new** films (`LOOKS.BIN`) isn't ready yet at that first half-press, the camera takes
the new films at the next switch-on instead.

Still the same: the films load at the first half-press after switching on, not at switch-on itself. Loading them at
switch-on is planned, but the automatic load of v0.26.2 / v0.27 could rarely freeze the camera at start-up, so it needs
another way in.

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.29.1`). Copy only
`DCOLYMP` and flash it (hold OK, then switch the camera on). Coming from v0.29: nothing else to do, your films stay in
the camera. Coming from v0.28 or older: as for v0.29, leave your `OM3MOD` files on the card for the first start (see the
[v0.29 notes](../v0.29/NOTES.md)).

Everything else, including the optional extras (`LOOKS.BIN` with the colour-matched standard 20, `DEBUG.TXT`, the photo
code kit), is as in [v0.29](../v0.29/NOTES.md). Going back to v0.29: make v0.29 and copy its `DCOLYMP`; the films stay
in the camera either way.

The files here are the patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the optional extras and the
expected checksums. Full list of changes: [CHANGELOG](../../CHANGELOG.md#v0291).
