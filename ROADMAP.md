# Roadmap

**[See this roadmap as a page, with the GitHub issues](https://androidfanman.github.io/caduceus-om3/pages/roadmap/)** (it reads this file).

What's planned for Caduceus for OM-3. Nothing here is promised or dated: features land when they work on a real camera.
Ideas and requests are welcome in [Issues](https://github.com/androidfanman/caduceus-om3/issues).

The order (owner, 2026-11-09): first finish the colour profiles, then video. v0.27 (2026-11-11) added the button customisation (arrow keys, Creative Dial modes) and the film recipe in the photo's EXIF. The lens, focus and button requests
below are planned too; their place in that order isn't set yet.


Feature parity with Caduceus for the E-P7 (what both have, what lines up, what to do): [docs/PARITY.md](docs/PARITY.md).
## Next: finishing the colour profiles

The goal is for Color Profile mode to be the best JPEG maker of any camera. With v0.28 (halation, finer split toning,
WB per film, the Blacks / Whites grid) the colour profiles are complete for now; custom crop modes are set aside.

| Feature | What it means | Status |
|---|---|---|
| **Films in the camera (any card works)** ([#35](https://github.com/androidfanman/caduceus-om3/issues/35)) | The films, the changes made on the camera and the Extras settings kept in the camera's own settings memory; the guide pictures, the Glow / grain code, labels and tone pictures built into the firmware. A card brings in only films the camera never had; nothing is copied back to the card. Research and design by iancw ([#36](https://github.com/androidfanman/caduceus-om3/pull/36)). Camera-tested. | **Done (v0.29)** |
| **Films from your own LUTs and Lightroom presets** (LookLab) | Pick a `.cube` LUT or a Lightroom preset (`.xmp`, `.lrtemplate`) and LookLab finds the camera settings that come closest, shown side by side with a match score; Log-video LUTs are flagged. An approximation; the file stays in the browser. Live 2026-11-13; tested with made-up grades, real LUTs and presets being tried by the owner. | Testing |
| **Halation** | The red glow around bright lights of cinema film (CineStill and others): its own Picture Mode row (0–5), with or without Glow. Method after Caduceus for the E-P7. Camera-tested (soft fade, works with grain and bursts); LookLab slider and preview. | **Done (v0.28)** |
| **Quick film switching** ([#30](https://github.com/androidfanman/caduceus-om3/issues/30)) | One button to get straight to COLOR 1–4 / FILM 1–20 (and MONO / ART) and pick with the front dial, as on the E-P7: a button function that opens the Picture Mode list directly, then, if possible, a toggle (button or Fn lever) that turns the front dial into a profile dial. Owner: a must. The films in your own order on the camera ([#32](https://github.com/androidfanman/caduceus-om3/issues/32)) is not planned (owner, 2026-11-13). The Creative Dial part ([#21](https://github.com/androidfanman/caduceus-om3/issues/21)) shipped in v0.27. | Tabled (owner, 2026-11-11) |
| **Gentler Shading** ([#22](https://github.com/androidfanman/caduceus-om3/issues/22)) | Shading is much too strong in both directions; the wish was −5 / +5 like today's −2 / +2, with finer steps, and the camera's vignette like LookLab's. Two camera test builds (2026-11-12) showed the camera fades the corners toward black or white through a mask whose strength it sets out of reach (even −1 leaves the very corners nearly black); drawing our own vignette would cost the viewfinder preview and save speed. Difficult: parked until there is a new lead (owner, 2026-11-12). Notes: `research/NOTES.md`. | Difficult (parked) |
| **Custom crop modes** | Extra aspect ratios such as XPan 65:24 and 21:9 (as in Caduceus for the E-P7), and your own. Looked into 2026-11-12: the E-P7 took about 10 camera rounds (menus, sizes, live view, then AF, metering and overlays that look things up by aspect); not worth it for now (owner, 2026-11-12). Notes: `research/NOTES.md`. | Set aside |
| **Our version in the camera's menu** | The firmware screen shows OM's version and, below it, the Caduceus version. More work than expected (the screen is built from layout data); moved to a later update (owner, 2026-11-12). Notes: `research/NOTES.md`. | Later |
| **Colour chart with changeable light** (LookLab) | A drawn colour chart to judge a film in sun at different times of day, shade, lamp light and at different camera WB / Kelvin. Built and tried on 2026-11-09, then taken out: it needs a clearer design first. Notes and the kept code: [docs/CHART_LIGHTBOX.md](docs/CHART_LIGHTBOX.md). | Parked |
| **Our own grain texture** | The fast grain uses the camera's ready-made grain picture; ours could add colour speckle and grain size, still at no extra time. On hold: the owner first compares today's grain with Lightroom / DxO (2026-11-12). | On hold |
| **Split toning: finer steps and balance** | The wheels run 0–10 in half steps (10 = the old +5) and only add a colour; a **Tone Balance** row under HSL (−5 the shadow colour reaches further, +5 the highlight colour). Camera-tested; in LookLab too. A midtones wheel ([#23](https://github.com/androidfanman/caduceus-om3/issues/23)) is not planned (owner, 2026-11-12: not a photo-editing norm). | **Done (v0.28)** |
| **Blacks / Whites as one grid** | The Blacks and Whites sliders became one Picture Mode row with a grid like the WB shift grid (Blacks left / right, Whites up / down), −7…+7 each with the same step size, the values in the row's cell under a "B/W ±" icon. Camera-tested; a grid in LookLab too. | **Done (v0.28)** |
| **Film settings when you pick a film** | **WB:** each film and COLOR remembers the WB last used with it (any mode, Custom WB with its Kelvin), like its HSL; picking it brings that WB back, one that never had one gets Auto. Camera-tested; a WB mode per film in LookLab. **Exposure compensation and ISO per film:** not planned (owner, 2026-11-12: on a digital camera ISO does not change a film's look, and the film's own tone settings brighten it without changing the exposure). | **WB done (v0.28)**; exposure / ISO not planned |
| **Film Mode (a roll of film)** | Off by default: pick a roll length (e.g. 24 / 36 / 72) and the film you're on is locked until the roll is shot, like Fujifilm's X half "Film Camera Mode" (without hiding photo review). Looked into 2026-11-12: doable with pieces already camera-tested (the film lock, a per-photo counter, saving at the half-press); showing the frames left on the shooting screen is the open part. Notes: `research/NOTES.md`. | Tabled (owner, 2026-11-12) |
| **Cleaner JPEGs** | Less JPEG compression blocking at high ISO ([#17](https://github.com/androidfanman/caduceus-om3/issues/17)). Out of scope: Caduceus leaves the camera's JPEG compression as it is (owner, 2026-11-12). | Not planned |

## Bugs being looked at

| Bug | What happens | Status |
|---|---|---|
| **Custom modes change films** ([#41](https://github.com/androidfanman/caduceus-om3/issues/41)) | Turning to a custom mode (C1–C5) swapped in its saved picture settings while the film stayed selected: the camera shot the film mixed with them, and the next film pick saved them into the film (a "*"); a custom mode also didn't keep its film. Now each custom mode brings back the films and picture mode it was assigned with (Save Settings: Hold and Recall too). | Fixed in v0.29.2 |
| **No films without a card** ([#38](https://github.com/androidfanman/caduceus-om3/issues/38)) | v0.29: with no card in the camera the films never loaded (the Picture Mode list showed COLOR 1–4 only), although they are kept in the camera: the load at the first half-press still waited for a card. The films loading at switch-on, without the half-press (the other half of #38), is not planned: tried, it lagged at switch-on, and the owner doesn't want the camera's start-up changed (2026-11-13). | Fixed in v0.29.1 |
| **Film Grain with RAW+JPEG** | With image quality set to RAW+JPEG, a photo with Film Grain was saved, then the screen went black and the camera froze (battery out). v0.25 to v0.26.1. A RAW+JPEG photo develops a second, smaller picture for the RAW file, and that upset the grain. Probably the cause of [#12](https://github.com/androidfanman/caduceus-om3/issues/12). | Fixed in v0.26.2 |
| **Glow with grain** | Reported: the camera shuts down after taking a photo with Glow and grain together ([#12](https://github.com/androidfanman/caduceus-om3/issues/12)), and Med grain is much stronger when Glow is on ([#16](https://github.com/androidfanman/caduceus-om3/issues/16)). | Fixed in v0.26.1 |
| **Playback while saving** | Pressing playback while the photo is still being written could freeze the camera (dark grey screen; only taking the battery out helped; the photo was fine), reported on v0.26.1 ([#15](https://github.com/androidfanman/caduceus-om3/issues/15)). No fix is recorded in the changelog or the notes. | Closed (2026-11-13) |
| **Creative dial freeze** | Turning the creative dial away from COLOR while a film is on can freeze live view (IS and level still update); sometimes only taking the battery out helps. v0.26.2. Reporter: mostly with Glow and / or grain on, most often CineStill 800T with grain, RAW+JPEG. Not reproduced on the owner's camera or by another user so far ([#27](https://github.com/androidfanman/caduceus-om3/issues/27)). | Investigating |
| **Grain + Glow freeze in burst** ([#28](https://github.com/androidfanman/caduceus-om3/issues/28)) | On v0.26.2 one user's camera freezes after a photo with grain and Glow / Clarity, in sequential (burst) shooting with the mechanical shutter; Single is fine, and the camera gets warm. Not reproduced on the owner's camera, also with the reporter's card files and in bursts of up to 27 frames incl. RAW+JPEG (camera-tested 2026-11-10); another user says it no longer happens for them. Remaining differences: card, lens or the camera itself. The reporter thinks their card may be old or damaged and will try a faster one (2026-11-10). | Waiting on reporter |

## Lenses and focus

| Feature | What it means | Status |
|---|---|---|
| **Focus stacking with any lens** | The camera's focus stacking (and focus bracketing) with any autofocus lens, not only OM's listed ones. | Planned |
| **Panasonic lenses work properly** | The aperture ring on Panasonic lenses that have one sets the aperture ([#29](https://github.com/androidfanman/caduceus-om3/issues/29)). Waiting for focus before the picture with lenses like the Panasonic 20mm f/1.7 ([#13](https://github.com/androidfanman/caduceus-om3/issues/13)) is not planned (owner, 2026-11-13). | Planned |

## Buttons and controls

| Feature | What it means | Status |
|---|---|---|
| **More button functions** | Button functions to switch S-AF / C-AF, and to switch between normal and high-speed sequential shooting ([#10](https://github.com/androidfanman/caduceus-om3/issues/10)). | Requested |
| **Quick WB / ISO page** | A button that opens a quick WB / ISO page as on the PEN-F and E-P7 ([#8](https://github.com/androidfanman/caduceus-om3/issues/8)). | Requested |
| **ISO-Auto slowest shutter speed on a dial** | Change the ISO-Auto lowest shutter speed quickly with a dial, or a button that steps through presets ([#25](https://github.com/androidfanman/caduceus-om3/issues/25)). | Requested |
| **Fn lever stores more settings** | Each Fn lever position can also keep its own subject detection and drive mode ([#31](https://github.com/androidfanman/caduceus-om3/issues/31)). | Requested |
| **Electronic shutter sound** | An optional shutter click from the speaker when the electronic shutter is used ([#19](https://github.com/androidfanman/caduceus-om3/issues/19)). | Not planned (owner, 2026-11-13) |
| **Remappable Delete button** | The Delete button, unused while shooting, gets the same choice of functions as the Fn button ([#37](https://github.com/androidfanman/caduceus-om3/issues/37)). | Requested |
| **Power lever as an Fn lever** | When the Fn lever is set to On / Off, the power lever takes over the Fn lever's job ([#34](https://github.com/androidfanman/caduceus-om3/issues/34)). | Requested |

## Video (after the photo side is finished)

| Feature | What it means | Status |
|---|---|---|
| **Colour profiles in video** | The colour profiles, your films and their settings also apply when recording video, baked in, like real-time LUTs ([#3](https://github.com/androidfanman/caduceus-om3/issues/3)). | Planned |
| **10-bit beyond Log and HLG** | Today the OM-3 records 10-bit only with OM-Log400 or HLG; the other profiles are 8-bit H.264, which bands and blocks when graded. Allow 10-bit (and other log / bit-depth choices) with the standard and COLOR profiles, or failing that, cleaner 8-bit encoding ([#1](https://github.com/androidfanman/caduceus-om3/issues/1), [#3](https://github.com/androidfanman/caduceus-om3/issues/3)). | Planned |
| **Sharpness in video** | The look's Sharpness (down to Off) also for video; today video stays at the camera's normal sharpening ([#6](https://github.com/androidfanman/caduceus-om3/issues/6)). | Planned |
| **Wider C-AF settings for video** | C-AF speed and sensitivity beyond −2..+2 (for example −5..+5) so subject detection holds on to people without hunting ([#14](https://github.com/androidfanman/caduceus-om3/issues/14)). | Requested |
| **Open gate video** | Record video from the whole sensor height (open gate) ([#24](https://github.com/androidfanman/caduceus-om3/issues/24)). | Requested |

## Done

| Feature | Released |
|---|---|
| **Custom modes keep their films:** each custom mode (C1–C5) brings back the films it was assigned with, and no longer changes your films ([#41](https://github.com/androidfanman/caduceus-om3/issues/41)) | v0.29.2 (released 2026-11-14) |
| **Films with no card:** the films load from the camera's memory with no card in the camera ([#38](https://github.com/androidfanman/caduceus-om3/issues/38)) | v0.29.1 (released 2026-11-13) |
| **Films in the camera:** films, on-camera changes and Extras kept in the camera's own memory, guide pictures / code / labels / tone pictures built into the firmware: any card works ([#35](https://github.com/androidfanman/caduceus-om3/issues/35)) | v0.29 (released 2026-11-13) |
| **Start-up freeze fix:** films load at the first half-press again (the automatic load could freeze the camera at switch-on) | v0.27.1 (released 2026-11-11) |
| **Buttons and the film in the photo:** all four arrow keys in Button Function ([#9](https://github.com/androidfanman/caduceus-om3/issues/9)); the Creative Dial positions each set to CRT / ART / COLOR / MONO, with each COLOR position keeping its own film ([#21](https://github.com/androidfanman/caduceus-om3/issues/21)); the film's name and recipe code in each JPEG's EXIF, read by LookLab and a kit for other sites ([#20](https://github.com/androidfanman/caduceus-om3/issues/20)); an optional debug log | v0.27 (released 2026-11-11) |
| **Films load at power-on** (no half-press; from [fernandezk26](https://github.com/fernandezk26/camera-stuff)'s fork); the super control panel dials step through the films; fixes for Film Grain with RAW+JPEG, the shooting-screen label and `EDITS.BIN` | v0.26.2 (released 2026-11-09) |
| **WB shift ±7 in films** (`LOOKS.BIN` −7..+7, like the camera's fine-tune); the 20 film sims tuned (draft 1) | v0.26.1 (released 2026-11-09) |
| **Split toning**: Shadows and Highlights wheel pages (12 colours, −5..+5), in photos and live view; `TONES.BIN` guides; fix for a restart after changing the drive mode | v0.26 (released 2026-11-09) |
| **Fast colour grain with every setting** (image processor, Grainy Film's texture route): Shading back; Glow row (+ Glow, − Clarity); WB row with the camera's own WB grid (OK opens the fine-tune screen on the look's A-B / G-M); no Art Effects (Frame removed); saving over power off fixed | v0.25 (released 2026-11-09) |
| **Films in the Picture Mode list**: FILM 1, FILM 2, … after COLOR 1–4 with their names (title, quick menu, shooting screen); changes kept per film (`EDITS.BIN`); hold OK = as built; `*` = changed | v0.24.1 |
| **Picture Mode rows**: Blacks, Whites, A-B, G-M, Sharp, Noise Filter (High new), Vignette Correction and Film Grain on the camera's own screen; HSL wheel Color → Color All → Hue → Luminance | v0.24.1 |
| **Sharpness per look**: Sharp on the Extras page (−5 Off..+2), replacing the camera's Sharpness row on COLOR 1–4 | v0.22 |
| **Colour grain**: Off / Low / Med / High on the COLOR profiles, from the camera's own grain engine | v0.21 |

See the [changelog](CHANGELOG.md) for what each release already contains.
