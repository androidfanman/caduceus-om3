# Film grading on the camera (2026-11-11)

How the Control Panel's film looks were graded so the OM-3 gives what was meant, from colour-checker photos taken on
the owner's camera. Lab notebook entry: `../NOTES.md`, "Film sims graded on the camera".

## Files

| File | What it is |
|---|---|
| `camera_response.json` | The measurements: for every test shot, the look's sliders and the change it made on each of the 24 chart patches (lightness, chroma, hue). Also the split-toning tests, the camera's default chart colours, the vignette correction and the v6 shoot (not yet used in the fit). Numbers only, no photos. |
| `grade.py` | The camera model (sliders → chart colours) and the solver that matches a look's Control Panel preview. |
| `preview_chart.ts` | Runs the Control Panel's own preview on the chart's colours for every look. |

## What was measured (camera-tested; 1/40 s, f/1.8, ISO 1000, fixed WB, Datacolor 24-patch chart)

- Six test sets of 20 looks, each changing one thing: every wheel colour's Hue up and down, Luminance, Saturation up
  and down, Contrast ±1, Highlights / Shadows / Midtones, Blacks / Whites, WB A-B and G-M, and split toning (each
  wheel, both sides, strengths −2..4). Also the release films, v3, v5 and v6 of the camera's 20.
- Main findings: saturation down is stronger than up (−1 ≈ −12..−18% chroma, +1 ≈ +7%); hue up turns more than
  hue down (Cyan most); Red reaches no chart patch; split toning is a tint whose strength follows brightness (Shadows
  wheel strongest on the darker greys, Highlights wheel on light-mid greys), linear in strength, and a minus strength
  gives the opposite colour.
- The model predicts a left-out film's chart colours with an error of about 0.9 (lightness / chroma units) against
  changes of 3.5; the split-toning part to about 0.8 against changes of 7.

## How the looks were graded

- **The camera's 20 (FILM 1–20):** graded against reference photos of each film (statistics kept outside the repo),
  shot on the camera three times (v3, v5, v6). v6 is in `webapp/scripts/films.py` `GRADED`; the Control Panel's
  `LOOKS.BIN` for the 20 is byte for byte the camera-tested v6 file.
- **The other looks:** each recipe was rendered on the chart with the Control Panel preview; the solver then picked
  the sliders, WB and split tone that make the *camera* give that result (Red and the recipe's tone and Contrast are
  kept). Camera model only, not yet shot. Predicted camera-vs-preview difference: 3.5 → 1.9 (ΔE per patch), grey
  tint 1.2 → 0.7. The preview of each look barely changes (ΔE 1.5).

## Redoing it

From `webapp/` (after `npm install`):

```
python3 scripts/films.py --recipes /tmp/recipes.json
./node_modules/.bin/esbuild ../research/film-grading/preview_chart.ts --bundle --platform=node --format=esm --outfile=/tmp/pc.mjs
node /tmp/pc.mjs /tmp/recipes.json /tmp/preview_chart.json
python3 ../research/film-grading/grade.py /tmp/recipes.json /tmp/preview_chart.json /tmp/graded.json
```

`/tmp/graded.json` then goes into `GRADED` in `films.py` (a new or changed recipe: grade it and add its line). With
today's data this reproduces `GRADED` for the other looks exactly.

## Limits

- One chart under one light. Colours outside the chart (deep reds near the Red sector, very bright or very dark
  colours) are not measured; Red keeps the recipe's value.
- The preview itself is an approximation: the other looks match what the preview showed, not a film reference.
- Shoot-to-shoot noise (light, WB) is about ±2–4% per film on the chart, as large as what is left to fix.
