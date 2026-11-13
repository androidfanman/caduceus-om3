# Branch feature/film-chart-grade: status

**Status (2026-11-13): analysis / camera model only. Not shot on the camera, not merged.** Delete this file when merged.

Every film on the colour-chart reference (18 films: 24-patch chart, daylight, +0 EV, one lab scanner, Kodak and Fuji
in two sessions) is now graded against it, and only those. The reference numbers stay outside the repo (owner's
private project notes), as for v6. Target: each film relative to its session's average, applied to the camera's
COLOR default from the v6 chart shoot. Solver: `research/film-grading/grade.py`'s camera model (colours, tone, WB,
split; Contrast kept >= 0; clipped scan patches barely count).

- The camera's 20 (base = the measured v6 chart shoot): Portra 400, Portra 800, Gold 200, Ektar 100, ColorPlus 200,
  Ektachrome E100, Pro 400H, Velvia 50, Superia 400, Fuji C200, Provia 100F.
- Other films already in the list (base = model only): Portra 160, Fujifilm 200.
- New films (the reference has them, the list didn't): Fujifilm 400, Natura 1600, NHG II 800, NPS 160, Pro 160S
  (67 films now). Descriptions are ours, partly from what their charts show.
- New film-browser filters: "Colour matched" (these 18, also tagged in the list) and "Hand-tuned" (the other 49,
  designed from public descriptions). `matched` flag from `MATCHED` in `webapp/scripts/films.py`.

Double check (2026-11-13), two models: (1) grade.py, (2) the Control Panel's own camera-fitted preview run over the
chart (an independent model). Both say all 13 existing films get closer to their film chart. Preview, mean colour
error on unclipped patches, old -> new: Ektachrome 16.1 -> 8.3, Provia 15.1 -> 9.6, Gold 9.9 -> 4.8, Fujifilm 200
10.9 -> 6.0, Portra 400 9.2 -> 6.2, Pro 400H 8.0 -> 3.9, C200 7.5 -> 5.0, Ektar 7.1 -> 4.8, Portra 160 7.1 -> 4.4,
ColorPlus 6.7 -> 5.0, Superia 400 6.3 -> 4.4, Portra 800 5.7 -> 4.9, Velvia 13.9 -> 13.1. New films 4.3-6.4.
Velvia: the two models disagree (skin and sky blue); the camera can't turn the cyan patch as far as Velvia does.
The camera chart shoot decides. Portra 400's grey tint: preview says slightly warmer than the film (2.6 -> 3.0).

- Test file: LOOKS_CP1.BIN (sha256 87c84364…), the standard 20 with the 11 camera films changed.
- Next: owner shoots the chart with it (as for v6); measure, then keep, adjust or drop per film.
