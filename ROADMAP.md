# Roadmap

**[See this roadmap as a page, with the GitHub issues](https://androidfanman.github.io/caduceus-om3/pages/roadmap/)** (it reads this file).

What's planned for Caduceus for OM-3. Nothing here is promised or dated: features land when they work on a real camera.
Ideas and requests are welcome in [Issues](https://github.com/androidfanman/caduceus-om3/issues).

The order (owner, 2026-11-09): colour profiles first, then video. The colour profiles are now complete; video is next.
The lens and button requests below are planned too; their place in that order isn't set yet.

Feature parity with Caduceus for the E-P7: [docs/PARITY.md](docs/PARITY.md).

## Colour profiles

| Feature | What it means | Status |
|---|---|---|
| **Films in the camera** ([#35](https://github.com/androidfanman/caduceus-om3/issues/35)) | Films, edits and Extras kept in the camera's own memory, so any SD card works. Research by iancw. | **Done (v0.29)** |
| **Films from your own LUTs and Lightroom presets** (LookLab) | Make a film from a `.cube` LUT or a Lightroom preset; the file stays in your browser. | Testing |
| **Halation** | The red glow around bright lights, its own Picture Mode row (0–5). | **Done (v0.28)** |
| **Split toning** | Shadows and Highlights wheels in half steps, plus a Tone Balance row. | **Done (v0.28)** |
| **Blacks / Whites grid** | One grid row, −7 to +7 each. | **Done (v0.28)** |
| **White balance per film** | Each film remembers its own WB. | **Done (v0.28)** |
| **One control panel for all Caduceus cameras** ([#71](https://github.com/androidfanman/caduceus-om3/issues/71)) | One shared panel with each camera as a profile, proposed by cakelesscoder (Caduceus for the E-P7). | In progress |

## Bugs being looked at

| Bug | What happens | Status |
|---|---|---|
| **Quick single shots held up** ([#85](https://github.com/androidfanman/caduceus-om3/issues/85)) | With `DEBUG.TXT` on (or Halation on), a quick second press in Single waited for the card. | Fixed in v0.40 (reporter to confirm) |
| **Custom modes and a new film set** ([#86](https://github.com/androidfanman/caduceus-om3/issues/86)) | A new `LOOKS.BIN` showed the new names with a "*" over the old films' colours. | Fixed in v0.40 |
| **Video crash** ([#74](https://github.com/androidfanman/caduceus-om3/issues/74)) | Video crashed once on the video dial; no debug log. | Closed (2026-11-18), fixed in v0.40 |
| **Photos not saved with Film Grain** ([#50](https://github.com/androidfanman/caduceus-om3/issues/50)) | One user's camera takes the photo but saves nothing; never reproduced here. | Marked fixed for v0.40 (reporter to confirm) |
| **Reboot when switching films fast** ([#72](https://github.com/androidfanman/caduceus-om3/issues/72)) | Holding the arrow in the film list restarted the camera. | Fixed in v0.40 |
| **Debug log slows the shutter** | With `DEBUG.TXT` on, the shutter fired late. | Fixed in v0.30.3 |
| **Black review, frozen live view** ([#65](https://github.com/androidfanman/caduceus-om3/issues/65)) | A Glow photo gave a black review, then live view froze. | Fixed in v0.30.2 |
| **Menu flash in Picture Mode** ([#66](https://github.com/androidfanman/caduceus-om3/issues/66)) | One-frame flash leaving the B/W or WB row. | Fixed in v0.30.1 |
| **Live dial turns change films** ([#54](https://github.com/androidfanman/caduceus-om3/issues/54)) | Turning the mode dial put a "*" on films nobody changed. | Fixed in v0.30 |
| **Video freeze** ([#53](https://github.com/androidfanman/caduceus-om3/issues/53)) | A half-press soon after switching on in video froze live view. | Fixed in v0.30 |
| **Picture Mode stars and saving** | Wrong "*" on rows; changes lost if you switched off right after leaving Picture Mode. | Fixed in v0.29.4 |
| **Film WB lost in the WB screen** | A film's Custom WB Kelvin jumped back to an old value. | Fixed in v0.29.4 |
| **Custom modes change films** ([#41](https://github.com/androidfanman/caduceus-om3/issues/41)) | Custom modes mixed their settings into your films. | Fixed in v0.29.2 |
| **No films without a card** ([#38](https://github.com/androidfanman/caduceus-om3/issues/38)) | With no card in the camera the films didn't load. | Fixed in v0.29.1 |
| **Film Grain with RAW+JPEG** ([#12](https://github.com/androidfanman/caduceus-om3/issues/12)) | The camera froze after a RAW+JPEG photo with grain. | Fixed in v0.26.2 |
| **Glow with grain** ([#12](https://github.com/androidfanman/caduceus-om3/issues/12), [#16](https://github.com/androidfanman/caduceus-om3/issues/16)) | The camera shut down after a photo with Glow and grain; Med grain was too strong. | Fixed in v0.26.1 |
| **Playback while saving** ([#15](https://github.com/androidfanman/caduceus-om3/issues/15)) | Playback right after a shot could freeze the camera. | Closed (2026-11-13) |
| **Creative dial freeze** ([#27](https://github.com/androidfanman/caduceus-om3/issues/27)) | Turning the Creative Dial could freeze live view; not reproduced. | Closed (2026-11-15) |
| **Grain + Glow freeze in burst** ([#28](https://github.com/androidfanman/caduceus-om3/issues/28)) | One user's camera froze in bursts with grain and Glow; not reproduced on v0.29. | Closed (2026-11-14) |

## Lenses and focus

| Feature | What it means | Status |
|---|---|---|
| **Focus stacking with more lenses** ([#79](https://github.com/androidfanman/caduceus-om3/pull/79), by Bensonson) | Focus stacking with more autofocus lenses. [Details](docs/FOCUS_STACKING.md). | **Done (v0.40)** |
| **Panasonic lenses work properly** ([#29](https://github.com/androidfanman/caduceus-om3/issues/29)) | The aperture ring on Panasonic lenses sets the aperture. | Requested |
| **Sync image stabilisation with Panasonic lenses** ([#47](https://github.com/androidfanman/caduceus-om3/issues/47)) | Camera and lens stabilisation working together. | Requested |

## Buttons and controls

| Feature | What it means | Status |
|---|---|---|
| **Fn lever stores more settings** ([#31](https://github.com/androidfanman/caduceus-om3/issues/31)) | Each Fn lever position keeps its own subject detection and drive mode. | Requested |
| **ISO Auto and WB Lock keys** ([#52](https://github.com/androidfanman/caduceus-om3/issues/52), [#77](https://github.com/androidfanman/caduceus-om3/pull/77), [#78](https://github.com/androidfanman/caduceus-om3/pull/78), by ryanbughuang) | Two new button functions, offered as pull requests. | In progress |
| **Touchscreen Delete button in Playback** ([#49](https://github.com/androidfanman/caduceus-om3/issues/49)) | A touch Delete button in playback. | Requested |

## Video (after the photo side is finished)

| Feature | What it means | Status |
|---|---|---|
| **Colour profiles in video** ([#3](https://github.com/androidfanman/caduceus-om3/issues/3)) | Your films also apply when recording video. | Requested |
| **10-bit beyond Log and HLG** ([#1](https://github.com/androidfanman/caduceus-om3/issues/1), [#3](https://github.com/androidfanman/caduceus-om3/issues/3)) | 10-bit with the standard and COLOR profiles, or cleaner 8-bit. | Requested |
| **H.265 and a bitrate setting** ([#51](https://github.com/androidfanman/caduceus-om3/pull/51), by buburun) | H.265 for every picture mode, plus a bitrate choice. | Requested |
| **Sharpness in video** ([#6](https://github.com/androidfanman/caduceus-om3/issues/6)) | Sharpness down to Off in video. | Requested |
| **Wider C-AF settings for video** ([#14](https://github.com/androidfanman/caduceus-om3/issues/14)) | C-AF speed and sensitivity beyond −2..+2. | Requested |
| **Open gate video** ([#24](https://github.com/androidfanman/caduceus-om3/issues/24)) | Record from the whole sensor height. | Requested |

## Done

| Feature | Released |
|---|---|
| **Smoother colour grain** with less red-green speckle, made faster (long bursts with grain keep up) | v0.40.2 (2026-11-19) |
| **Round film grain** with fewer repeats; a film's **WB Compensation shown in the super control panel** ([#88](https://github.com/androidfanman/caduceus-om3/issues/88)) | v0.40.1 (2026-11-19) |
| **Crop modes XPan, 21:9 and 5:4** (crops back at switch-on, [#83](https://github.com/androidfanman/caduceus-om3/issues/83)), a **black or white Border** per film at every ratio, **our own grain** with Grain Size, **looks in live view** as you adjust them, **your own choice of screen info**, our version on the Firmware Version screen, Picture Mode open 30 s ([#76](https://github.com/androidfanman/caduceus-om3/pull/76), by crombach), faster looks ([#82](https://github.com/androidfanman/caduceus-om3/pull/82), by crombach), faster Halation, focus stacking with more lenses ([#79](https://github.com/androidfanman/caduceus-om3/pull/79), by Bensonson), LookLab matched to the camera | v0.40 (2026-11-19) |
| **Fast-switching reboot fixed** ([#72](https://github.com/androidfanman/caduceus-om3/issues/72)); the colour wheel's label names the page ([#70](https://github.com/androidfanman/caduceus-om3/pull/70)); our looks stay out of video ([#73](https://github.com/androidfanman/caduceus-om3/pull/73)), both by crombach | v0.40 (2026-11-19) |
| **Faster Halation** with a smoother fade; faster dial clicks and saves ([#69](https://github.com/androidfanman/caduceus-om3/pull/69), by crombach) | v0.30.3 (2026-11-17) |
| **Color Mix and RGB curves**, the 20 films regraded, a new Picture Mode order, films ready at switch-on ([#56](https://github.com/androidfanman/caduceus-om3/pull/56), by crombach) | v0.30 (2026-11-16) |
| **Custom modes keep their own copy** of everything | v0.29.5 (2026-11-15) |
| **Remappable Delete button** ([#37](https://github.com/androidfanman/caduceus-om3/issues/37), [#40](https://github.com/androidfanman/caduceus-om3/pull/40) by crombach) | v0.29.3 (2026-11-14) |
| **Custom modes keep their films** ([#41](https://github.com/androidfanman/caduceus-om3/issues/41)) | v0.29.2 (2026-11-14) |
| **Films with no card** ([#38](https://github.com/androidfanman/caduceus-om3/issues/38)) | v0.29.1 (2026-11-13) |
| **Films in the camera's own memory**, any card works ([#35](https://github.com/androidfanman/caduceus-om3/issues/35)) | v0.29 (2026-11-13) |
| **Start-up freeze fix**: films load at the first half-press again | v0.27.1 (2026-11-11) |
| **All four arrow keys** in Button Function ([#9](https://github.com/androidfanman/caduceus-om3/issues/9)); Creative Dial modes with a film each ([#21](https://github.com/androidfanman/caduceus-om3/issues/21)); the film's name and recipe in each JPEG ([#20](https://github.com/androidfanman/caduceus-om3/issues/20)); an optional debug log | v0.27 (2026-11-11) |
| **Films load at power-on** (from [fernandezk26](https://github.com/fernandezk26/camera-stuff)'s fork); the dials step through the films | v0.26.2 (2026-11-09) |
| **WB shift ±7 in films**; the 20 film sims tuned | v0.26.1 (2026-11-09) |
| **Split toning**: Shadows and Highlights pages | v0.26 (2026-11-09) |
| **Fast colour grain** with every setting; Glow and WB rows | v0.25 (2026-11-09) |
| **Films in the Picture Mode list**, and the look's settings as Picture Mode rows | v0.24.1 (2026-11-08) |
| **Sharpness per look** | v0.22 |
| **Colour grain** on the COLOR profiles | v0.21 |

See the [changelog](CHANGELOG.md) for what each release already contains.
