# Film Simulation Roadmap

**Goal:** make the OM-3 with Caduceus the best film-replicating camera available: looks that render like real film
stock straight out of the camera, and that load and shoot like a roll of film.

Last updated 2026-11-09 (v0.26.1 released with the tuned 20; halation parked). Update the status column as work moves, and add findings to the research log at the end
(details go in [`research/NOTES.md`](../research/NOTES.md)). The general roadmap is [`ROADMAP.md`](../ROADMAP.md).

**Effort:** Low = a few sessions on known hooks · Medium = new firmware work on parts we already understand ·
Large = a new area of the firmware · Hard = no camera feature to borrow, everything drawn or computed by us.
**Status:** Not started · Researching · Proven possible · Building · Camera testing · Done · Parked.
Efforts are estimates from what we know of the firmware today.

**Gate for most items: firmware space.** The space proven safe is almost full. The firmware-space probe
(branch [`experiment/firmware-space-probe`](../../../tree/experiment/firmware-space-probe)) ran on the camera on
2026-11-07: moving a section's loaded end works. **64 KiB proven** (section 6, with photos, video and Wi-Fi in use), so
new features have room; more can be opened up the same way.

## Next steps

0. **Tune the 20 film sims from the owner's camera photos** (released in v0.25, tuned on the preview). **Draft 1 in
   the Control Panel (2026-11-09):** the owner's tuned colours, WB and tone (`TUNED` in `films.py`); Contrast, Sharp
   and the split tones of seven films kept from the recipes. In v0.26.1's optional `LOOKS.BIN`. Owner's plan
   (2026-11-09): a colour checker card, fixed light, one photo per film (FILM 1–20) plus a neutral reference; measure
   each patch against the reference and adjust the recipes in `webapp/scripts/films.py`.
1. **Our own grain texture** (after v0.25's fast colour grain with every setting): colour speckle and grain size from the
   Grain Lab design, through the same texture route. Plan: project doc `fast-grain-plan`, `research/NOTES.md`.
2. **Halation** (parked by the
   owner 2026-11-09; port the E-P7's method, our own code, onto the Glow row's route). (Split toning research done 2026-11-07: see the table; building it can now use the proven 64 KiB.)
3. **White balance mode and exposure compensation per look:** quick wins that make a look behave like a roll.

## The film look itself

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| Split toning: colour by brightness | Teal shadows and warm highlights (cinema), cool shadows (Portra), green shadows (Superia). The colour wheel works by hue only. | Medium | **Released in v0.26** (camera-tested 2026-11-09: photos and live view) | Cross Process and (likely) Vintage do it with three different R/G/B tone curves in the camera's RGB gamma stage. The job keeps its own copy of the curves, so a look can bend them: 6 bytes per look, about 100-150 B of code. Emulator-checked on the stock code; not camera-tested. Blocked by code space (needs a hook in sections 1-5, or the space probe). |
| Coloured glow (halation) | The red glow around lights of CineStill and other cinema film. | Medium | Parked (owner, 2026-11-09: after split toning) | Caduceus for the E-P7 v0.31 has it camera-tested: a CPU pass on the CPU grain route (our OM-3 route, ported there) adds a tinted glow around lights. Feasible here on the Glow row's route; ~1.8 KB of code (ext11 has ~3 KB); OM-3 chroma byte order unproven. `research/NOTES.md` 2026-11-09. |
| Highlight roll-off and toe | Film compresses highlights gently and has a soft toe in the blacks. | Medium | Not started | We already hook the tone curve builder (Highlights / Shadows / Midtones, Blacks / Whites). Add a shoulder setting, and colour that fades toward white. |
| Grain by brightness, size and roughness | Film grain is strongest in the midtones and depends on the stock. | Medium | Not started | Today: the camera's Monochrome grain (Low / Med / High), the same everywhere. Look for its size and strength parameters. |
| Faster grain with Glow or Art Effects | Grain plus glow costs about 3 s per photo and blocks burst shooting. | Medium | Researching | On the main roadmap. The v0.21 timing work on the slow route is the starting point. |

## Shooting like a roll of film

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| White balance mode per look | Tungsten film (CineStill 800T) shoots at 3200 K, daylight film at 5500 K. Today a look can only shift WB. | Low | Not started | Looks already write 18 camera settings when chosen; WB mode and Kelvin are more of the same kind. |
| Exposure compensation per look | Overexposed Portra, pushed Tri-X. Optional per look. | Low | Not started | Same route. Decide whether it adds to the user's exposure dial or sets it. |
| ISO per look | "Load" Portra 400 and the camera shoots at ISO 400. Optional. | Low | Not started | Same route. Off by default. |
| Frame shape per look | XPan 65:24, square 6×6, 4:5 for 6×7, half-frame. | Medium | Not started | Ties into the crop modes on the main roadmap (Caduceus for the E-P7 has XPan and 21:9). |
| Film borders | A black film-edge or an instant-print border, besides today's white Frame. | Medium | Not started | The Frame Art Effect already draws our own border. New borders are generic shapes, not copies of film-stock markings. |

## Bigger projects

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| Black-and-white film looks | Tri-X, HP5, Delta 3200, Acros. Looks are COLOR-only today. | Large | Not started | Needs the Monochrome profiles: colour filter, toning, grain, contrast and the Film-page bank. Their editor is separate from the COLOR wheel. |
| Film looks in video | Rare among cameras. | Large | Not started | On the main roadmap. v0.22's Sharp is photos only; the video path was not traced. |
| Light leaks and date stamps | Point-and-shoot touches. | Hard | Parked | No camera feature to borrow. Lowest priority. |

## Control Panel

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| A preview calibrated to the camera | Film sims and photo-matched looks are only as good as the preview's model of the OM-3. | Medium | Not started | Shoot a colour chart and scenes on the OM-3 at each setting step, then fit the preview to them. |
| Photo-to-look instructions | Build a look from any photo, opened by a link. | Low | Done | [`docs/PHOTO_TO_LOOK.md`](PHOTO_TO_LOOK.md), tested end to end 2026-11-07. |

## Already done

| Date | Item | What it gives film looks |
|---|---|---|
| 2026-11-09 | v0.26.1 released | The 20 film sims tuned from colour-checker photos (draft 1) in the release's `LOOKS.BIN`; WB shift up to ±7 per film. |
| 2026-11-09 | v0.26 released (split toning) | Shadows and Highlights wheel pages: tint by brightness toward any of the 12 colours, −5..+5, in photos and live view; ten of the 20 films carry a light split tone. Also fixes a restart after changing the drive mode. |
| 2026-11-09 | The camera's 20 films (in v0.25) | 20 film sims rewritten in the owner's order, FILM 1–20 on the camera and in the Control Panel (one list). |
| 2026-11-09 | v0.25 released (fast colour grain) | Film grain from the image processor in colour, as fast as no grain, with Shading and Glow / Clarity; a Glow row (+ Glow, − Clarity), a WB grid row, no Art Effects; film choice and changes now kept over power off. |
| 2026-11-08 | v0.24.1 films in the list | Films (FILM n) in the Picture Mode list with their names; changes kept per film; the Extras as Picture Mode rows. Glow / Clarity and Art Effects off and the Shading row hidden for now. (v0.24 was withdrawn the same day: Film Grain High rebooted the camera.) |
| 2026-11-07 | v0.22 Sharp | Sharpening per look, −5 (Off) to +2; film sims set it. |
| 2026-11-07 | Photo-to-look instructions | A look built from any photo, loaded by a link. |
| 2026-11-06 | 60 film sims | Our own looks, one per film, in five groups. |
| 2026-11-06 | v0.21 Grain and VigFix | The camera's own grain on colour photos; lens vignette correction off per look. |
| 2026-11-05 | v0.20 Extras page | NR per look, Glow / Clarity, WB shift, Art Effects, Blacks / Whites, white Frame. |
| 2026-11-05 | v0.19 Looks | Five complete looks per COLOR with names, chosen on the Film page. |

## Research log

Newest first. Full details in [`research/NOTES.md`](../research/NOTES.md).

| Date | Topic | Finding |
|---|---|---|
| 2026-11-08 | WB grid (camera) | Test 12: a new A-B / G-M row opens the camera's own WB fine-tune grid with the look's values (emulator); on the camera OK went back to live view instead. Owner: the grid should sit on the Picture Mode screen itself. |
| 2026-11-08 | Picture-mode sliders | Tests 8-11: Blacks / Whites rows. Fixed on the camera: arrows ran backwards, several cells highlighted with 11 rows, values wrapped from +5 to -5. Our own "Blk" / "Wht" pictures now sit in the S icon's place with the camera's own value next to them (firmware/mkicons.py, free font). Owner: "this is perfect!". |
| 2026-11-08 | Picture-mode sliders (camera) | Tests 5-7: new choice rows Vignette Correction (Off / On, camera icons, our own title) and Noise Filter (Off / Low / Std / High in the camera's font; the look's NR gains High, also on the Extras wheel and in the Control Panel on the branch). Test 7 works on the camera. Test 8 adds Blacks / Whites sliders (emulator only). |
| 2026-11-08 | WB grid (analysis) | The camera's A-B / G-M grid is the WB± row of its own WB screen, a bespoke screen; three ways to port it are in the notebook. |
| 2026-11-07 | Picture-mode sliders (camera) | Test 4 works on the camera: the code runs from the proven 64 KiB; Sharp on the Sharpness slider (−5 to +2, ends line up, 0 on the centre mark) and Grain on the camera's own Film Grain Effect row (Off / Low / Med / High) on COLOR 1–4, in step with the Extras wheel. |
| 2026-11-07 | Firmware space (camera) | 64 KiB probe: section 6 loads 64 KiB more; all 16248 pattern words intact after photos and a video. New features can use that space. |
| 2026-11-07 | Firmware space (camera) | Probe on the camera: moving section 6's loaded end by 4 KiB works; the code there ran, its pattern stayed intact over 45 checks (photos, video and Wi-Fi in use), and nothing wrote into any gap. Gaps hold no file bytes unless a loaded end is moved. |
| 2026-11-07 | Split toning | Cross Process (and likely Vintage) tint by brightness with separate R/G/B tone curves in the RGB gamma stage. COLOR photos use one curve for all three; the job copies it, so our code could bend each channel after the copy. Emulator-checked on stock code; a design and preview model exist; building needs code space. |
| 2026-11-07 | Firmware space | The camera does not load the empty stretches between firmware sections; the sliders test put code in one and must not be flashed. |
| 2026-11-07 | Picture-mode sliders | Camera slider rows can be pointed at our own values with their own range, readout and end stops. Sharp works this way in the emulator. |
| 2026-11-07 | Sharp and video | Sharp changes the photo capture path only; video most likely keeps the hidden stock Sharpness. Not tested. |
| 2026-11-06 | Firmware space | About 2.3 MiB of empty space sits between sections; nothing wrote to it in the emulator. The probe build tests whether the camera can load and use it. |
