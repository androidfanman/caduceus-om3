# Roadmap

What's planned for Caduceus for OM-3. Nothing here is promised or dated: features land when they work on a real camera.
Ideas and requests are welcome in [Issues](https://github.com/androidfanman/caduceus-om3/issues).

The order (owner, 2026-11-09): first finish the colour profiles, then video. The lens, focus and button requests
below are planned too; their place in that order isn't set yet.


Feature parity with Caduceus for the E-P7 (what both have, what lines up, what to do): [docs/PARITY.md](docs/PARITY.md).
## Next: finishing the colour profiles

The goal is for Color Profile mode to be the best JPEG maker of any camera. Halation and custom crop modes are the
last two pieces: with them the colour profiles are complete.

| Feature | What it means | Status |
|---|---|---|
| **v0.27: button customisation** | All four arrow keys settable in Button Function with the full Fn list; a button that opens the film list straight away, then a toggle that makes the front dial step through films ([#30](https://github.com/androidfanman/caduceus-om3/issues/30)); the front Creative Dial's positions mapped to any COLOR / FILM / MONO, set in the camera's Custom Menu next to the button functions. Branch `feature/v0.27-buttons`. Arrow keys camera-tested (ak6). Dial mapping camera-tested with a fixed map; its four Button Function rows (CRT / ART / COLOR / MONO) work in the emulator (dr1), camera test next. | In progress |
| **Halation** | The red glow around bright lights of cinema film (CineStill and others), as a film setting. Caduceus for the E-P7 has it; the OM-3 version would ride on the Glow row's route. | Next |
| **Quick film switching** ([#30](https://github.com/androidfanman/caduceus-om3/issues/30)) | One button to get straight to COLOR 1–4 / FILM 1–20 (and MONO / ART) and pick with the front dial, as on the E-P7: first a button function that opens the Picture Mode list directly; then, if possible, a toggle (button or Fn lever) that turns the front dial into a profile dial. Owner: a must. | Researching |
| **Debug log** | Copy `DEBUG.TXT` into `OM3MOD` and the camera writes a plain-text `OM3MOD/CADLOG.TXT` at each shutter-button event: the build, which card files loaded, the picture mode, the last save result, whether every card file matches the firmware (naming any that doesn't) and the last 32 events. For testing new features and for users' bug reports. Uses the new 256 KiB space (GX3). Branch `feature/debug-log`; later maybe a menu command. | Works on the camera; to ship in the next release |
| **Gentler Shading** | Shading is much too strong in both directions. Make the camera's own Shading steps weaker so that −5 / +5 look like today's −2 / +2 (owner, 2026-11-10), with finer steps in between; match the Control Panel preview. Likely a small change to the camera's Shading strength data (needs research, then a flash and a before / after camera test). | Planned |
| **Custom crop modes** | Extra aspect ratios such as XPan 65:24 and 21:9 (as in Caduceus for the E-P7), and your own. | Planned |
| **Colour chart with changeable light** (Control Panel) | A drawn colour chart to judge a film in sun at different times of day, shade, lamp light and at different camera WB / Kelvin. Built and tried on 2026-11-09, then taken out: it needs a clearer design first. Notes and the kept code: [docs/CHART_LIGHTBOX.md](docs/CHART_LIGHTBOX.md). | Parked |
| **Our own grain texture** | The fast grain uses the camera's ready-made grain picture; ours could add colour speckle and grain size, still at no extra time. | Investigating |

## Bugs being looked at

| Bug | What happens | Status |
|---|---|---|
| **Film Grain with RAW+JPEG** | With image quality set to RAW+JPEG, a photo with Film Grain was saved, then the screen went black and the camera froze (battery out). v0.25 to v0.26.1. A RAW+JPEG photo develops a second, smaller picture for the RAW file, and that upset the grain. Probably the cause of [#12](https://github.com/androidfanman/caduceus-om3/issues/12). | Fixed in v0.26.2 |
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
| **All arrow keys configurable** | Every arrow key can be a custom button, not only right and down ([#9](https://github.com/androidfanman/caduceus-om3/issues/9)). The up key (▲) for stills is done as research by ryanbughuang ([#26](https://github.com/androidfanman/caduceus-om3/pull/26), camera-tested on their OM-3 as a test build on v0.26.2; `research/BUTTONS.md`). Before a release: proven code space, its own menu entries, the up key in video mode, and a build inside `firmware/`. | Research |
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
| **Films load at power-on** (no half-press; from [fernandezk26](https://github.com/fernandezk26/camera-stuff)'s fork); the super control panel dials step through the films; fixes for Film Grain with RAW+JPEG, the shooting-screen label and `EDITS.BIN` | v0.26.2 (released 2026-11-09) |
| **WB shift ±7 in films** (`LOOKS.BIN` −7..+7, like the camera's fine-tune); the 20 film sims tuned (draft 1) | v0.26.1 (released 2026-11-09) |
| **Split toning**: Shadows and Highlights wheel pages (12 colours, −5..+5), in photos and live view; `TONES.BIN` guides; fix for a restart after changing the drive mode | v0.26 (released 2026-11-09) |
| **Fast colour grain with every setting** (image processor, Grainy Film's texture route): Shading back; Glow row (+ Glow, − Clarity); WB row with the camera's own WB grid (OK opens the fine-tune screen on the look's A-B / G-M); no Art Effects (Frame removed); saving over power off fixed | v0.25 (released 2026-11-09) |
| **Films in the Picture Mode list**: FILM 1, FILM 2, … after COLOR 1–4 with their names (title, quick menu, shooting screen); changes kept per film (`EDITS.BIN`); hold OK = as built; `*` = changed | v0.24.1 |
| **Picture Mode rows**: Blacks, Whites, A-B, G-M, Sharp, Noise Filter (High new), Vignette Correction and Film Grain on the camera's own screen; HSL wheel Color → Color All → Hue → Luminance | v0.24.1 |
| **Sharpness per look**: Sharp on the Extras page (−5 Off..+2), replacing the camera's Sharpness row on COLOR 1–4 | v0.22 |
| **Colour grain**: Off / Low / Med / High on the COLOR profiles, from the camera's own grain engine | v0.21 |

See the [changelog](CHANGELOG.md) for what each release already contains.
