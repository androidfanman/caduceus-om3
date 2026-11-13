# Branch feature/film-chart-grade: status

**Status (2026-11-13): analysis / camera model only. Not shot on the camera, not merged.** Delete this file when merged.

- 11 of the camera's 20 films regraded in `webapp/scripts/films.py` `GRADED`: Portra 400, Portra 800, Gold 200,
  Ektar 100, ColorPlus 200, Ektachrome E100, Pro 400H, Velvia 50, Superia 400, Fuji C200, Provia 100F.
- Target: chart scans of the real films (24-patch chart, daylight, +0 EV, one lab scanner), each film taken relative to
  the average of its scan session and applied to the camera's COLOR default from the v6 chart shoot. The reference
  numbers are kept outside the repo (owner's private project notes), as for v6.
- Solver: `research/film-grading/grade.py`'s camera model; colours, tone, WB and split per film; Contrast kept >= 0;
  clipped patches in the scans barely count. Prediction = measured v6 + model change.
- Predicted (model) chroma gap to the film charts, v6 -> this branch: Ektachrome 29.7 -> 9.6 %, Velvia 26.9 -> 13.5,
  Provia 25.9 -> 9.5, Portra 400 16.1 -> 4.6, Gold 14.5 -> 4.2, Ektar 14.4 -> 5.7, ColorPlus 13.9 -> 5.8,
  C200 13.6 -> 4.5, Superia 11.9 -> 4.1, Pro 400H 10.9 -> 4.7, Portra 800 9.9 -> 6.0.
- Test file for the owner: LOOKS_CP1.BIN (sha256 87c84364…), the Control Panel's standard 20 with these 11 changed.
- Next: owner shoots the chart with it (as for v6); measure, then keep, adjust or drop per film.
