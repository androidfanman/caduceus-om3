# Roadmap

What's planned for Caduceus for OM-3. Nothing here is promised or dated: features land when they work on a real camera.
Ideas and requests are welcome in [Issues](https://github.com/androidfanman/caduceus-om3/issues).

The order (owner, 2026-11-09): first finish the colour profiles, then video. The lens, focus and button requests
below are planned too; their place in that order isn't set yet.

## Next: finishing the colour profiles

The goal is for Color Profile mode to be the best JPEG maker of any camera. Halation and custom crop modes are the
last two pieces: with them the colour profiles are complete.

| Feature | What it means | Status |
|---|---|---|
| **Halation** | The red glow around bright lights of cinema film (CineStill and others), as a film setting. Caduceus for the E-P7 has it; the OM-3 version would ride on the Glow row's route. | Next |
| **Custom crop modes** | Extra aspect ratios such as XPan 65:24 and 21:9 (as in Caduceus for the E-P7), and your own. | Planned |
| **Our own grain texture** | The fast grain uses the camera's ready-made grain picture; ours could add colour speckle and grain size, still at no extra time. | Planned |

## Bugs being looked at

| Bug | What happens | Status |
|---|---|---|
| **Film Grain with RAW+JPEG** | With image quality set to RAW+JPEG, a photo with Film Grain is saved, then the screen goes black and the camera freezes (battery out). Found 2026-11-09; v0.25 to v0.26.1 are most likely all affected. **Until fixed: use Film Grain with JPEG only, or switch Film Grain off for RAW+JPEG.** Probably the cause of [#12](https://github.com/androidfanman/caduceus-om3/issues/12). | Being fixed |
| **Glow with grain** | Reported: the camera shuts down after taking a photo with Glow and grain together ([#12](https://github.com/androidfanman/caduceus-om3/issues/12)), and Med grain is much stronger when Glow is on ([#16](https://github.com/androidfanman/caduceus-om3/issues/16)). | Fixed in v0.26.1 |
| **Playback while saving** | Pressing playback while the photo is still being written can freeze the camera (dark grey screen; only taking the battery out helps; the photo is fine) ([#15](https://github.com/androidfanman/caduceus-om3/issues/15)). | Fixed in v0.26.1 |

## Lenses and focus

| Feature | What it means | Status |
|---|---|---|
| **Focus stacking with any lens** | The camera's focus stacking (and focus bracketing) with any autofocus lens, not only OM's listed ones. | Planned |
| **Panasonic lenses work properly** | The aperture ring on Panasonic lenses that have one sets the aperture; and the camera waits for focus before it takes the picture with lenses like the Panasonic 20mm f/1.7, as Panasonic bodies do ([#13](https://github.com/androidfanman/caduceus-om3/issues/13)). | Planned |

## Buttons and controls

| Feature | What it means | Status |
|---|---|---|
| **More button functions** | Button functions to switch S-AF / C-AF, and to switch between normal and high-speed sequential shooting ([#10](https://github.com/androidfanman/caduceus-om3/issues/10)). | Requested |
| **All arrow keys configurable** | Every arrow key can be a custom button, not only right and down ([#9](https://github.com/androidfanman/caduceus-om3/issues/9)). | Requested |
| **Quick WB / ISO page** | A button that opens a quick WB / ISO page as on the PEN-F and E-P7 ([#8](https://github.com/androidfanman/caduceus-om3/issues/8)). | Requested |

## Video (after the photo side is finished)

| Feature | What it means | Status |
|---|---|---|
| **Colour profiles in video** | The colour profiles, your films and their settings also apply when recording video, baked in, like real-time LUTs ([#3](https://github.com/androidfanman/caduceus-om3/issues/3)). | Planned |
| **10-bit beyond Log and HLG** | Today the OM-3 records 10-bit only with OM-Log400 or HLG; the other profiles are 8-bit H.264, which bands and blocks when graded. Allow 10-bit (and other log / bit-depth choices) with the standard and COLOR profiles, or failing that, cleaner 8-bit encoding ([#1](https://github.com/androidfanman/caduceus-om3/issues/1), [#3](https://github.com/androidfanman/caduceus-om3/issues/3)). | Investigating |
| **Sharpness in video** | The look's Sharpness (down to Off) also for video; today video stays at the camera's normal sharpening ([#6](https://github.com/androidfanman/caduceus-om3/issues/6)). | Planned |
| **Wider C-AF settings for video** | C-AF speed and sensitivity beyond −2..+2 (for example −5..+5) so subject detection holds on to people without hunting ([#14](https://github.com/androidfanman/caduceus-om3/issues/14)). | Requested |

## Done

| Feature | Released |
|---|---|
| **WB shift ±7 in films** (`LOOKS.BIN` −7..+7, like the camera's fine-tune); the 20 film sims tuned (draft 1) | v0.26.1 (released 2026-11-09) |
| **Split toning**: Shadows and Highlights wheel pages (12 colours, −5..+5), in photos and live view; `TONES.BIN` guides; fix for a restart after changing the drive mode | v0.26 (released 2026-11-09) |
| **Fast colour grain with every setting** (image processor, Grainy Film's texture route): Shading back; Glow row (+ Glow, − Clarity); WB row with the camera's own WB grid (OK opens the fine-tune screen on the look's A-B / G-M); no Art Effects (Frame removed); saving over power off fixed | v0.25 (released 2026-11-09) |
| **Films in the Picture Mode list**: FILM 1, FILM 2, … after COLOR 1–4 with their names (title, quick menu, shooting screen); changes kept per film (`EDITS.BIN`); hold OK = as built; `*` = changed | v0.24.1 |
| **Picture Mode rows**: Blacks, Whites, A-B, G-M, Sharp, Noise Filter (High new), Vignette Correction and Film Grain on the camera's own screen; HSL wheel Color → Color All → Hue → Luminance | v0.24.1 |
| **Sharpness per look**: Sharp on the Extras page (−5 Off..+2), replacing the camera's Sharpness row on COLOR 1–4 | v0.22 |
| **Colour grain**: Off / Low / Med / High on the COLOR profiles, from the camera's own grain engine | v0.21 |

See the [changelog](CHANGELOG.md) for what each release already contains.
