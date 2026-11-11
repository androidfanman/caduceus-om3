# Fitting the Control Panel preview to the camera (2026-11-11)

`webapp/src/preview.ts` `OM3_CAL` came from here. `port.py` is a Python copy of the preview's colour path (WB, tone
curve, 12-sector engine, split bend; checked against the real preview to 1 level in 8 bits). `fit.py` fits per-colour
saturation gains (up / down), hue degrees per step (camera Hue − / +), a luminance scale, WB gains per channel and the
split scale to the single-slider chart tests; `fit2.py` adds the 80 film shots (release, v3, v5, v6) and checks each
shoot left out. Result `om3_cal.json` (fitted on everything); Red keeps the old numbers (no chart patch).

These are working scripts: they read the measurement files of the 2026-11-11 session (Lab of each shot, the test
looks, the films' preview tone curves), which are summarised in `../camera_response.json` but not all kept in the
repo; read them as the record of how the numbers were made.

Results (analysis on camera-tested shots): per slider, preview vs camera on the changed patches ΔE saturation 6.6 →
4.5, hue 5.1 → 3.6, luminance 3.4 → 2.5, WB 3.0 → 2.2, split 1.4 → 1.3. Film shots left out of the fit: 4.4 → 3.8
(two camera shoots of the same film differ by 2.3, so that is the floor). The preview of the 62 looks moves by ΔE 1.7
on the chart on average (most 3.7).
