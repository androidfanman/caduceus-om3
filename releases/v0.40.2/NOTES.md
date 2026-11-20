# Caduceus for OM-3 v0.40.2

**Smoother colour grain with less red-green speckle, and grain that keeps up with long bursts.** v0.40.1 plus one
change to Film Grain, camera-tested on 2026-11-19 (the build before its release name).

**New since v0.40.1**
- **Smoother colour grain.** The grain's colour speckle is now made on every row instead of every other row, so it has
  no 2-row steps (they showed as faint bands in the colour of Coarse grain, in camera photos too). At Coarse the colour
  specks are now the size of the brightness clumps, a little finer than before.
- **Less red-green.** Real colour film's colour grain is mostly blue-yellow (measured on public-domain 35 mm scans), so
  the red-green speckle is now about half as strong as the blue-yellow. Skin and grey skies show fewer pink and green
  flecks.
- **Faster grain.** The camera makes the grain picture for each photo with less work than in v0.40.1 at every size
  (about 5 to 12 % less, emulator count), and 17 to 25 % less than the first test of this grain. A long fast burst
  with Film Grain had rebooted the camera with that first test; with this build it worked (camera-tested).

**Unchanged:** the brightness grain (the same round clumps as v0.40.1), Film Grain 1 to 5, Fine / Medium / Coarse, the
menus and start-up.

**LookLab:** the grain preview has the new colour grain.

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.40.2`). Copy
`DCOLYMP` and flash it (hold OK, then switch the camera on). Your films, changes, custom modes, button settings and
screen-info choices stay in the camera. **Coming from v0.29.x or older?** Also put `CURVES.BIN` in the `OM3MOD` folder
for the regraded films.

Going back: make v0.40.1 and copy its `DCOLYMP`.

The files here are the patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the optional extras
(`CURVES.BIN`, `LOOKS.BIN`, `DEBUG.TXT` and the photo code kit, as in v0.40.1) and the expected checksums.
Full list of changes: [CHANGELOG](../../CHANGELOG.md#v0402).
