# Film Simulation Roadmap

**Goal:** make the OM-3 with Caduceus the best film-replicating camera available: looks that render like real film
stock straight out of the camera, and that load and shoot like a roll of film.

Last updated 2026-11-11 (checked against v0.27, the latest release). Update the status column as work moves, and add
findings to the research log at the end (details go in [`research/NOTES.md`](../research/NOTES.md)). The general
roadmap is [`ROADMAP.md`](../ROADMAP.md).

**Effort:** Low = a few sessions on known hooks · Medium = new firmware work on parts we already understand ·
Large = a new area of the firmware · Hard = no camera feature to borrow, everything drawn or computed by us.
**Status:** Not started · Researching · Proven possible · Building · Camera testing · Done · Parked.
Efforts are estimates from what we know of the firmware today.

## What v0.27.1 can do (camera-tested)

- **20 film sims on the camera** as FILM 1–20 in the Picture Mode list, after COLOR 1–4, with their names on the
  title, quick menu, shooting screen and viewfinder. They load at the first half-press after switching on (until
  then the screen may show the plain COLOR look), and the super control panel's dials step COLOR 1–4, then
  FILM 1–20. The Control Panel has 62 films to choose from.
- **Per film:** colour (hue, saturation, luminance for 12 colours), Highlights / Midtones / Shadows, Blacks / Whites,
  Contrast, Sharp (−5 Off..+2), Noise Filter (Off / Low / Std / High), Vignette Correction on / off, Shading, WB shift
  A-B / G-M −7..+7 (the camera's own WB grid), split toning (Shadows and Highlights wheels, 12 colours, −5..+5).
- **Added by the user per film, never in a sim:** Film Grain Off / Low / Med / High (colour, from the image
  processor, no extra time), the Glow row (+ Glow, − Clarity).
- **Changes kept per film** (`EDITS.BIN`, `*` = changed, hold OK = back to as built), kept over power off.
- **Live view** shows the look, split toning and glow included. Photos only: video keeps the camera's normal look.
- **Film in the photo (v0.27):** each JPEG taken on a FILM has the film's name in its EXIF and the whole recipe as a
  short code; the Control Panel opens it as a film ([`docs/PHOTO_CODE.md`](PHOTO_CODE.md)).
- **Creative Dial (v0.27):** each of the four positions can be set to COLOR and keep its own film, so the dial
  switches between up to four films.
- **Not in v0.27:** Art Effects (removed in v0.25), mono films (parked), a WB mode / exposure / ISO per film, halation.

**Firmware space.** The 64 KiB of section 6 proven on 2026-11-07 is used up. The 256 KiB proven on 2026-11-10
(GX3, 0x60f59800..0x60f99800, camera-tested) is in use from v0.27: v0.27.1 leaves about 15 KB of it free (the button
pictures and body diagrams take most of it). v0.28 work sizes the button pictures' area to fit (about 76 KB free) and
probes the rest of section 6 (about 660 KB more, GX4); see `research/NOTES.md`, "v0.28 code space".

## Next steps

1. **Halation** (Next, owner 2026-11-09: halation and custom crop modes finish the colour profiles). Port the E-P7's
   method, our own code, onto the Glow row's route; can use the new 256 KiB.
2. **Our own grain texture:** colour speckle and grain size from the Grain Lab design, through the same fast texture
   route. Plan: project doc `fast-grain-plan`, `research/NOTES.md`.
3. **Fine-tune the 20 film sims** (draft 1, from the owner's colour checker photos, is in the optional `LOOKS.BIN` of
   v0.26.1 to v0.27). Gold 200 and CineStill 800T now carry their split tone on the Highlights wheel, as in the approved
   drafts (Control Panel 2026-11-10, `LOOKS.BIN` from v0.27). Seven films keep
   split tones from the older recipes.
4. **White balance mode and exposure compensation per film:** quick wins that make a film behave like a roll.

## The film look itself

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| Split toning: colour by brightness | Teal shadows and warm highlights (cinema), cool shadows (Portra), green shadows (Superia). | Medium | **Done (v0.26)** | Shadows and Highlights wheel pages, 12 colours, −5..+5, in photos and live view; camera-tested 2026-11-09. Asked for: a Midtones control ([#23](https://github.com/androidfanman/caduceus-om3/issues/23), not planned) and finer steps (film-sim drafts, 2026-11-09). **v0.28 (camera-tested in test builds 2026-11-12):** wheels 0..10 in half steps (10 = v0.26's +5), positive only, and a Tone Balance row; the Control Panel part to do. |
| Coloured glow (halation) | The red glow around lights of CineStill and other cinema film. | Medium | Building (v0.28) | Caduceus for the E-P7 v0.31 has it camera-tested: a CPU pass adds a tinted glow around lights. Here it would ride on the Glow row's route; ~1.8 KB of code, fits the new 256 KiB; OM-3 chroma byte order unproven. `research/NOTES.md` 2026-11-09. |
| Highlight roll-off and toe | Film compresses highlights gently and has a soft toe in the blacks. | Medium | Not planned | Covered by what exists (owner, 2026-11-12): Blacks + Shadows give the toe, Whites − and Highlights − a soft shoulder (Highlight & Shadow is the camera's own tone curve). |
| Film grain: size, colour speckle, by brightness | Film grain depends on the stock: size, colour and where it shows. | Medium | On hold (owner compares with Lightroom / DxO first) | Today (v0.25 on): the camera's own Grainy Film texture laid on COLOR photos, Low / Med / High by strength only, no extra time, works with Glow and Shading. Next: our own texture with colour speckle and size (Grain Lab browser model, 2026-11-07; nothing built). |
| Faster grain with Glow | Grain plus glow cost about 3 s per photo and blocked burst shooting. | Medium | **Done (v0.25)** | Grain from the image processor's texture route: as fast as no grain, with Glow / Clarity and Shading. Art Effects were removed in v0.25. |

## Shooting like a roll of film

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| Films in the Picture Mode list | Pick a film like loading a roll. | Medium | **Done (v0.24.1, v0.26.2, v0.27)** | FILM 1–20 after COLOR 1–4 with their names; dial stepping in v0.26.2 (v0.26.2 and v0.27 also loaded the films at power-on; v0.27.1 went back to the first half-press because that could rarely freeze the camera at start-up); in v0.27 each Creative Dial position can be COLOR with its own film ([#21](https://github.com/androidfanman/caduceus-om3/issues/21)). Asked for: reorder films on the camera ([#32](https://github.com/androidfanman/caduceus-om3/issues/32)), one button / front dial to switch films ([#30](https://github.com/androidfanman/caduceus-om3/issues/30), main roadmap: tabled 2026-11-11). |
| White balance mode per film | Tungsten film (CineStill 800T) shoots at 3200 K, daylight film at 5500 K. | Low | **Building (v0.28)**: camera-tested 2026-11-12 | Each film and COLOR remembers the WB last used with it (camera setting 1578 mode, 107 Custom WB Kelvin; LOOKS / EDITS record +59..+62); none = Auto. The Control Panel part is to do. |
| Exposure compensation per film | Overexposed Portra, pushed Tri-X. Optional per film. | Low | Not planned (owner, 2026-11-12: the film's tone settings give the brighter look without changing the exposure) | Same route. Decide whether it adds to the user's exposure dial or sets it. |
| ISO per film | "Load" Portra 400 and the camera shoots at ISO 400. Optional. | Low | Not planned (owner, 2026-11-12: ISO does not change a film's look on a digital camera; Auto ISO does better) | Same route. Off by default. |
| Film name in the photo's EXIF | Photos say which film and settings made them, for sharing and sorting ([#20](https://github.com/androidfanman/caduceus-om3/issues/20)). | Medium | **Done (v0.27)** | Image Description `FILM n Name`; User Comment with the name and the whole recipe as an `om3.1.` code. The Control Panel opens a film from a JPEG or a pasted code; [devkit/photo-code](../devkit/photo-code/) reads it for other sites. Spec: [PHOTO_CODE.md](PHOTO_CODE.md). Camera-tested 2026-11-11 (dr7). |
| Frame shape per film | XPan 65:24, square 6×6, 4:5 for 6×7, half-frame. | Medium | Not started | Ties into custom crop modes on the main roadmap (set aside 2026-11-12; Caduceus for the E-P7 has XPan and 21:9). |
| Film borders | A black film edge or an instant-print border. | Medium | Not planned | Owner (2026-11-12): borders can be added in editing afterwards. |

## Bigger projects

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| Black-and-white film looks | Tri-X, HP5, Delta 3200, Acros. Films are COLOR-only today. | Large | Parked | Needs the Monochrome profiles: colour filter, toning, grain, contrast and their own film bank. Their editor is separate from the COLOR wheel. Caduceus for the E-P7 has 10 mono films. Parked by the owner 2026-11-10. |
| Film looks in video | Rare among cameras. | Large | Not started | Main roadmap: Colour profiles in video, Planned ([#3](https://github.com/androidfanman/caduceus-om3/issues/3)). No video work started (owner, 2026-11-10). Sharp is photos only today. |
| Light leaks and date stamps | Point-and-shoot touches. | Hard | Parked | No camera feature to borrow. Lowest priority. |

## Control Panel

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| Camera-style editor | Edit a film the way the camera shows it. | Medium | **Done (2026-11-09)** | HSL wheel with the camera's five pages, Highlight & Shadow box, WB grid, all draggable. Look links carry a format version and minimum firmware. |
| Photo-to-look instructions | Build a look from any photo, opened by a link. | Low | Done | [`docs/PHOTO_TO_LOOK.md`](PHOTO_TO_LOOK.md), tested end to end 2026-11-07. |
| Preview matched to the camera | The Control Panel shows what the OM-3 will give: its colour engine fitted to the camera's measured slider response (WB, saturation and hue per colour, luminance, split). | Low | **Done (2026-11-11, live)** | Branch `feature/preview-camera-match`; `research/film-grading/preview-fit/`. Film shots left out of the fit: preview vs camera ΔE 4.4 → 3.8. |
| Film looks graded on the camera | Every film look measured and fitted to the OM-3's own response, so the camera gives what was meant (the camera's sliders are stronger than the preview, and uneven). | Medium | **Camera testing (2026-11-11)** | The 20: v6, camera-tested on a colour chart. The other 42: fitted to their preview with the camera model, not yet shot. Branch `feature/camera-graded-films`; [`research/film-grading/`](../research/film-grading/README.md), `research/NOTES.md` "Film sims graded on the camera". |

## Already done

| Date | Item | What it gives film looks |
|---|---|---|
| 2026-11-11 | v0.27 released | The film's name and recipe in every JPEG (opens in the Control Panel); Creative Dial positions with their own film; Gold 200 and CineStill 800T split tone on the Highlights wheel in `LOOKS.BIN`. |
| 2026-11-09 | v0.26.2 released | Films load at power-on (no half-press); the super control panel dials step through COLOR 1–4 and FILM 1–20; fixes for Film Grain with RAW+JPEG, the FILM N label and `EDITS.BIN`. |
| 2026-11-09 | v0.26.1 released | The 20 film sims tuned from colour-checker photos (draft 1) in the release's `LOOKS.BIN`; WB shift up to ±7 per film. |
| 2026-11-09 | v0.26 released (split toning) | Shadows and Highlights wheel pages: tint by brightness toward any of the 12 colours, −5..+5, in photos and live view; ten of the 20 films carry a light split tone. Also fixes a restart after changing the drive mode. |
| 2026-11-09 | The camera's 20 films (in v0.25) | 20 film sims rewritten in the owner's order, FILM 1–20 on the camera and in the Control Panel (one list). |
| 2026-11-11 | Cuban Negative | Film sim 62, our own design (warm, golden, sun-faded reds, turquoise blues); replaces the E-P7 starter look "Cuban Neg" in the Control Panel. |
| 2026-11-09 | v0.25 released (fast colour grain) | Film grain from the image processor in colour, as fast as no grain, with Shading and Glow / Clarity; a Glow row (+ Glow, − Clarity), a WB grid row, no Art Effects; film choice and changes now kept over power off. |
| 2026-11-08 | v0.24.1 films in the list | Films (FILM n) in the Picture Mode list with their names; changes kept per film; the Extras as Picture Mode rows. Glow / Clarity and Art Effects off and the Shading row hidden for now. (v0.24 was withdrawn the same day: Film Grain High rebooted the camera.) |
| 2026-11-07 | v0.22 Sharp | Sharpening per look, −5 (Off) to +2; film sims set it. |
| 2026-11-07 | Photo-to-look instructions | A look built from any photo, loaded by a link. |
| 2026-11-06 | 60 film sims | Our own looks, one per film, in five groups (62 in the Control Panel today). |
| 2026-11-06 | v0.21 Grain and VigFix | The camera's own grain on colour photos; lens vignette correction off per look. |
| 2026-11-05 | v0.20 Extras page | NR per look, Glow / Clarity, WB shift, Art Effects, Blacks / Whites, white Frame. |
| 2026-11-05 | v0.19 Looks | Five complete looks per COLOR with names, chosen on the Film page. |

## Research log

Newest first. Full details in [`research/NOTES.md`](../research/NOTES.md).

| Date | Topic | Finding |
|---|---|---|
| 2026-11-11 | Film in the photo (camera) | The `om3.1` code writes the whole 64-byte film record into the JPEG's User Comment, with spare bytes so newer settings stay readable by older readers (dr4 to dr7). |
| 2026-11-10 | Owner decisions | Mono film looks parked. A preview calibrated to the camera dropped: not needed, the OM-3 already matches the preview well. |
| 2026-11-10 | Firmware space (camera) | GX3 probe: section 6 loads 256 KiB more (0x60f59800..0x60f99800); 72 passes, 0 bad words, with RAW+JPEG bursts and a video. Room for halation and the next features. |
| 2026-11-09 | Film name in EXIF | The EXIF writer and a hook point are found (analysis only); Image Description and User Comment are free in JPEGs. |
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
