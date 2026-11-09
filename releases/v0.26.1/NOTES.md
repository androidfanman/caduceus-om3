# Caduceus for OM-3 v0.26.1

**WB shift up to ±7 in your films, and the 20 film sims tuned on the camera.**

- **WB −7..+7:** a film's WB shift can now go to ±7 each way, like the camera's own WB fine-tune. v0.26 and older
  refused a `LOOKS.BIN` with a WB shift past ±5 (none of the films loaded); v0.26.1 takes it. In the Control Panel,
  export with **Firmware on the camera: v0.26.1 or later**.
- **The 20 film sims, tuned** (optional `LOOKS.BIN`): new colours, WB and tone for all 20 from photos of a colour
  checker taken with every film in the same light (first round), and new split tones on Gold 200, Portra 800,
  CineStill 800T and Fuji Eterna.
- Everything from v0.26 stays: split toning (Shadows and Highlights pages), the drive-mode restart fix, fast colour
  grain, the WB grid and Glow rows, settings kept over power off.
- Firmware camera-tested (2026-11-09, build wb7).

**Control Panel** (same day): the editor now looks like the camera's Picture Mode screen (the HSL wheel with its five
pages, the Highlight & Shadow box, the WB fine-tune grid, the rows in the camera's order; the wheel, curve and WB
marker can be dragged), and the grain preview matches the camera better.

**Copy to the card:** `DCOLYMP` (flash it) and the `OM3MOD` files `GUIDES.BIN` (made for this firmware: always copy
it with it), `LABELS.BIN` and `TONES.BIN`. Keep your `EDITS.BIN`, `NAMES.BIN` and `BUNDLES.BIN`.
**To get the tuned 20 films:** also copy this release's `LOOKS.BIN` to `OM3MOD`. This **replaces your own films**, so
keep a copy of your old `LOOKS.BIN` if you want it. Or start from them in the Control Panel (**New › Reset looks to
standard**).

**Going back to v0.26 or older:** flash that version with its own `GUIDES.BIN`. A `LOOKS.BIN` with a WB shift past ±5
won't load there: export it again for that version (the Control Panel saves the shift as ±5 for it).

Make it: run the launcher and press Return (or `python3 firmware/patch.py --release v0.26.1`). The files here are the
patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the card files and the expected checksums. Full list of
changes: [CHANGELOG](../../CHANGELOG.md#v0261).
