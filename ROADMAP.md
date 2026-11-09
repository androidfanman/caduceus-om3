# Roadmap

What's planned for Caduceus for OM-3. Nothing here is promised or dated: features land when they work on a real camera.
Ideas and requests are welcome in [Issues](https://github.com/androidfanman/caduceus-om3/issues).

| Feature | What it means | Status |
|---|---|---|
| **More crop modes** | Extra aspect ratios such as XPan 65:24 and 21:9, as in Caduceus for the E-P7. | Planned |
| **Panasonic aperture rings** | The aperture ring on Panasonic lenses that have one sets the aperture on the OM-3. | Planned |
| **Our own grain texture** | The fast grain uses the camera's ready-made grain picture; ours could add colour speckle and grain size (Grain Lab design), still at no extra time. | Planned |
| **Glow / Clarity + Frame + Grain fast** | That one combination still takes the slower route (the fast one wrote no picture). | Researching |

## Video

| Feature | What it means | Status |
|---|---|---|
| **Colour profiles in video** | The colour profiles and their wheels (Hue, Light, Extras) also apply when recording video. | Planned |
| **10-bit beyond Log and HLG** | Today the OM-3 records 10-bit only with OM-Log400 or HLG; the other profiles are 8-bit H.264, which bands and blocks when graded. Allow 10-bit with the standard and COLOR profiles, or failing that, cleaner 8-bit encoding ([#1](https://github.com/androidfanman/caduceus-om3/issues/1)). | Investigating |

## Done

| Feature | Released |
|---|---|
| **Split toning**: Shadows and Highlights wheel pages (12 colours, −5..+5), in photos and live view; `TONES.BIN` guides; fix for a restart after changing the drive mode | v0.26 (released 2026-11-09) |
| **Fast colour grain with every setting** (image processor, Grainy Film's texture route): Shading back; Glow row (+ Glow, − Clarity); WB row with the camera's own WB grid (OK opens the fine-tune screen on the look's A-B / G-M); no Art Effects (Frame removed); saving over power off fixed | v0.25 (released 2026-11-09) |
| **Films in the Picture Mode list**: FILM 1, FILM 2, … after COLOR 1–4 with their names (title, quick menu, shooting screen); changes kept per film (`EDITS.BIN`); hold OK = as built; `*` = changed | v0.24.1 |
| **Picture Mode rows**: Blacks, Whites, A-B, G-M, Sharp, Noise Filter (High new), Vignette Correction and Film Grain on the camera's own screen; HSL wheel Color → Color All → Hue → Luminance | v0.24.1 |
| **Sharpness per look**: Sharp on the Extras page (−5 Off..+2), replacing the camera's Sharpness row on COLOR 1–4 | v0.22 |
| **Colour grain**: Off / Low / Med / High on the COLOR profiles, from the camera's own grain engine | v0.21 |

See the [changelog](CHANGELOG.md) for what each release already contains.
