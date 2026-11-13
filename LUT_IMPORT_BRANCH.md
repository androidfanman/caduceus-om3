# Branch feature/lut-import: status

**Status (2026-11-13): built and tested in the browser and with unit tests; not merged, not on the live Control Panel.**
Delete this file when the branch is merged.

- `webapp/src/convert.ts`: reads `.cube` (3D / 1D) and Lightroom presets (`.xmp`, `.lrtemplate`), approximates a
  preset's grade, and fits the OM-3's own settings to a grade on a fixed set of test colours, using the camera-fitted
  preview (`renderLook`, `OM3_CAL`).
- `webapp/src/main.ts`: "From LUT / preset…" button (and Open… accepts the files); a dialog shows the grade and the
  film side by side, a Close / Fair / Rough match, carried-over and left-out preset settings, then adds the film.
- `webapp/tests/convert.test.ts`: made-up grades only (no real LUTs or presets in the repo).
- Results on made-up grades (analysis, preview model): warm faded LUT ΔE 11.8 -> 3.4 (close); teal / orange LUT
  12.4 -> 5.5-6.0 (fair); test preset 13.1 -> 6.5 (fair).
- Not done: a check on the camera (a film made this way, shot next to the grade applied to the same photo);
  `looklab/` not rebuilt (do it when merging).
