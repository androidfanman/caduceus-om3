# Film Simulation Roadmap

**Goal:** make the OM-3 with Caduceus the best film-replicating camera available: looks that render like real film
stock straight out of the camera, and that load and shoot like a roll of film.

Last updated 2026-11-19 (checked against v0.40, the latest release). Update the
status column as work moves, and add findings to the research log at the end (details go in
[`research/NOTES.md`](../research/NOTES.md)). The general roadmap is [`ROADMAP.md`](../ROADMAP.md).

**Effort:** Low = a few sessions on known hooks · Medium = new firmware work on parts we already understand ·
Large = a new area of the firmware · Hard = no camera feature to borrow, everything drawn or computed by us.
**Status:** Not started · Researching · Building · Camera testing · Test version · Done.
Efforts are estimates from what we know of the firmware today.

## What v0.30.3 can do (camera-tested)

- **20 film sims on the camera** as FILM 1–20 in the Picture Mode list, after COLOR 1–4, with their names on the
  title, quick menu, shooting screen and viewfinder. They are ready when the camera starts, and the super control
  panel's dials step COLOR 1–4, then FILM 1–20. LookLab has 67 films to choose from (18 colour matched).
- **Per film:** colour (hue, saturation, luminance for 12 colours), Color Mix, RGB curves, Highlights / Midtones /
  Shadows, Blacks / Whites grid (±7), Contrast, Sharp, Noise Filter, Vignette Correction, Shading, WB shift and WB mode,
  split toning (0–10 with Tone Balance), Halation (0–5).
- **Added by the user per film, never in a sim:** Film Grain, the Glow row (+ Glow, − Clarity).
- **Changes kept per film** (`*` = changed, hold OK = back to as built); each custom mode keeps its own copy.
- **Live view** shows the look. Photos only: video keeps the camera's normal look.
- **Film in the photo:** each JPEG taken on a FILM has the film's name and the whole recipe as a short code in its EXIF;
  LookLab opens it as a film ([`docs/PHOTO_CODE.md`](PHOTO_CODE.md)).
- **Creative Dial:** each of the four positions can be set to COLOR and keep its own film.

## Next steps

1. **After v0.40** (crop modes, black and white borders, our own grain, live-view looks and LookLab matched to the
   camera, released 2026-11-19): see [`ROADMAP.md`](../ROADMAP.md).

## The film look itself

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| Split toning: colour by brightness | Teal shadows and warm highlights (cinema), cool shadows (Portra), green shadows (Superia). | Medium | **Done (v0.26)** | v0.28: wheels 0..10 in half steps plus a Tone Balance row; in LookLab too. |
| Coloured glow (halation) | The red glow around lights of CineStill and other cinema film. | Medium | **Done (v0.28)** | Its own Picture Mode row, 0..5; faster with a smoother fade in v0.30.3; LookLab slider and preview. |
| Color Mix and RGB curves | Shape colour and tone like a film lab: each colour's strength and hue, and a tone curve per channel. | Medium | **Done (v0.30)** | Two Picture Mode rows; the 20 films regraded with them; in LookLab too. |
| Film grain: size, colour speckle, by brightness | Film grain depends on the stock: size, colour and where it shows. | Medium | **Done (v0.40)** | Our own colour grain, strength 1–5, and a Grain Size row; round clumps with fewer repeats from v0.40.1; smoother colour grain with less red-green, made faster, from v0.40.2. |
| Faster grain with Glow | Grain plus glow cost about 3 s per photo and blocked burst shooting. | Medium | **Done (v0.25)** | Grain from the image processor's texture route: as fast as no grain, with Glow / Clarity and Shading. |

## Shooting like a roll of film

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| Films in the Picture Mode list | Pick a film like loading a roll. | Medium | **Done (v0.24.1, v0.26.2, v0.27, v0.30)** | FILM 1–20 after COLOR 1–4 with their names; the dials step through them; each Creative Dial position can be COLOR with its own film ([#21](https://github.com/androidfanman/caduceus-om3/issues/21)); ready at switch-on (v0.30); each custom mode keeps its own copy (v0.29.5). |
| White balance mode per film | Tungsten film (CineStill 800T) shoots at 3200 K, daylight film at 5500 K. | Low | **Done (v0.28)** | Each film remembers its WB (any mode, Custom WB with its Kelvin); a WB mode per film in LookLab. |
| Film name in the photo's EXIF | Photos say which film and settings made them, for sharing and sorting ([#20](https://github.com/androidfanman/caduceus-om3/issues/20)). | Medium | **Done (v0.27)** | The film's name and the whole recipe as an `om3.1.` code; LookLab opens a film from a JPEG or a pasted code; [devkit/photo-code](../devkit/photo-code/) reads it for other sites. Spec: [PHOTO_CODE.md](PHOTO_CODE.md). |
| Frame shape | XPan 65:24, 21:9 and 5:4, like wide-format film cameras. | Large | **Done (v0.40)** | Image Aspect choices saved at that shape; live view, grid, focus target and playback labels fit. Idea from Caduceus for the E-P7. |
| Film borders | A film edge or an instant-print border. | Medium | **Done (v0.40)** | A Border row per film: −5 (black) to +5 (white), at every aspect ratio. |

## Bigger projects

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| Film looks in video | Rare among cameras. | Large | Requested | Main roadmap: Colour profiles in video ([#3](https://github.com/androidfanman/caduceus-om3/issues/3)). Our looks stay out of video for now. |

## LookLab

| Feature | Why it matters for film | Effort | Status | Research notes |
|---|---|---|---|---|
| Camera-style editor | Edit a film the way the camera shows it. | Medium | **Done (2026-11-09)** | HSL wheel with the camera's five pages, Highlight & Shadow box, WB grid, all draggable. |
| Photo-to-look instructions | Build a look from any photo, opened by a link. | Low | Done | [`docs/PHOTO_TO_LOOK.md`](PHOTO_TO_LOOK.md), tested end to end 2026-11-07. |
| Preview matched to the camera | LookLab shows what the OM-3 will give. | Low | **Done (2026-11-11, live)** | Fitted to the camera's measured slider response; a closer match for Shading, grain, Border, Glow, Sharpness and Contrast from calibration cards on the camera in v0.40. |
| Film looks graded on the camera | Every film look measured and fitted to the OM-3's own response, so the camera gives what was meant. | Medium | **Camera testing (2026-11-11)** | The 20 were camera-tested on a colour chart, then regraded with Color Mix and RGB curves in v0.30; the other 42 are fitted with the camera model, not yet shot. [`research/film-grading/`](../research/film-grading/README.md). |
| Colour-matched films | 18 films graded against film scans of a colour chart; the standard 20 = these 18 + CineStill 800T and Kodachrome 64. | Medium | **In LookLab (2026-11-13); camera testing** | `research/NOTES.md` "Colour-matched films". |

## Already done

| Date | Item | What it gives film looks |
|---|---|---|
| 2026-11-19 | v0.40 released | Crop modes, black and white borders at every ratio, our own grain, looks in live view as you adjust them, faster Halation; LookLab matched to the camera. |
| 2026-11-17 | v0.40-alpha (test version) | Crop modes XPan, 21:9 and 5:4; a white Border per film; our own colour grain (strength 1–5, Grain Size). |
| 2026-11-17 | v0.30.3 released | Faster Halation with a smoother fade. |
| 2026-11-16 | v0.30 released | Color Mix and RGB curves; the 20 films regraded with them; films ready at switch-on. |
| 2026-11-15 | v0.29.5 released | Each custom mode keeps its own copy of the films and all their changes. |
| 2026-11-13 | v0.29 released | The films, edits and Extras kept in the camera's own memory, so any card works; the colour-matched standard 20 in the optional LOOKS.BIN and LookLab. |
| 2026-11-13 | v0.29-beta (test version) | The 20 films redesigned as signature looks, each compared with real photos taken on the film (Wikimedia Commons; CineStill 800T with Custom WB 3200 K and Halation 3, 400D Halation 2; Cuban Negative reworked); the films, edits and Extras kept in the camera's own memory so any card works. |
| 2026-11-12 | v0.28 released | Halation (its own row), split toning 0..10 with Tone Balance, WB remembered per film, Blacks / Whites as one grid (±7), the film as set in each photo's code; LookLab knows all of it. |
| 2026-11-11 | v0.27 released | The film's name and recipe in every JPEG (opens in LookLab); Creative Dial positions with their own film; Gold 200 and CineStill 800T split tone on the Highlights wheel in `LOOKS.BIN`. |
| 2026-11-09 | v0.26.2 released | Films load at power-on (no half-press); the super control panel dials step through COLOR 1–4 and FILM 1–20; fixes for Film Grain with RAW+JPEG, the FILM N label and `EDITS.BIN`. |
| 2026-11-09 | v0.26.1 released | The 20 film sims tuned from colour-checker photos (draft 1) in the release's `LOOKS.BIN`; WB shift up to ±7 per film. |
| 2026-11-09 | v0.26 released (split toning) | Shadows and Highlights wheel pages: tint by brightness toward any of the 12 colours, −5..+5, in photos and live view; ten of the 20 films carry a light split tone. Also fixes a restart after changing the drive mode. |
| 2026-11-09 | The camera's 20 films (in v0.25) | 20 film sims rewritten in the owner's order, FILM 1–20 on the camera and in LookLab (one list). |
| 2026-11-13 | Colour-matched films | 18 films graded against film chart scans (5 new: Fujifilm 400, Natura 1600, NHG II 800, NPS 160, Pro 160S; 67 films); Colour matched / Hand-tuned filters; new standard 20 in LookLab. |
| 2026-11-11 | Cuban Negative | Film sim 62, our own design (warm, golden, sun-faded reds, turquoise blues); replaces the E-P7 starter look "Cuban Neg" in LookLab. |
| 2026-11-09 | v0.25 released (fast colour grain) | Film grain from the image processor in colour, as fast as no grain, with Shading and Glow / Clarity; a Glow row (+ Glow, − Clarity), a WB grid row, no Art Effects; film choice and changes now kept over power off. |
| 2026-11-08 | v0.24.1 films in the list | Films (FILM n) in the Picture Mode list with their names; changes kept per film; the Extras as Picture Mode rows. Glow / Clarity and Art Effects off and the Shading row hidden for now. (v0.24 was withdrawn the same day: Film Grain High rebooted the camera.) |
| 2026-11-07 | v0.22 Sharp | Sharpening per look, −5 (Off) to +2; film sims set it. |
| 2026-11-07 | Photo-to-look instructions | A look built from any photo, loaded by a link. |
| 2026-11-06 | 60 film sims | Our own looks, one per film, in five groups (62 in LookLab today). |
| 2026-11-06 | v0.21 Grain and VigFix | The camera's own grain on colour photos; lens vignette correction off per look. |
| 2026-11-05 | v0.20 Extras page | NR per look, Glow / Clarity, WB shift, Art Effects, Blacks / Whites, white Frame. |
| 2026-11-05 | v0.19 Looks | Five complete looks per COLOR with names, chosen on the Film page. |

## Research log

Newest first. Full details in [`research/NOTES.md`](../research/NOTES.md).

| Date | Topic | Finding |
|---|---|---|
| 2026-11-14 | spektrafilm (analysis) | A spectral film / print simulation (GPLv3 code, CC BY-SA 4.0 film data) could be a second reference for our films, mainly Kodachrome 64 and CineStill 800T; it cannot make the preview closer to the camera. Options and licence notes in the notebook. |
| 2026-11-11 | Film in the photo (camera) | The `om3.1` code writes the whole 64-byte film record into the JPEG's User Comment, with spare bytes so newer settings stay readable by older readers (dr4 to dr7). |
| 2026-11-10 | Firmware space (camera) | GX3 probe: section 6 loads 256 KiB more (0x60f59800..0x60f99800); 72 passes, 0 bad words, with RAW+JPEG bursts and a video. Room for halation and the next features. |
| 2026-11-09 | Film name in EXIF | The EXIF writer and a hook point are found (analysis only); Image Description and User Comment are free in JPEGs. |
| 2026-11-08 | WB grid (camera) | Test 12: a new A-B / G-M row opens the camera's own WB fine-tune grid with the look's values (emulator); on the camera OK went back to live view instead. Owner: the grid should sit on the Picture Mode screen itself. |
| 2026-11-08 | Picture-mode sliders | Tests 8-11: Blacks / Whites rows. Fixed on the camera: arrows ran backwards, several cells highlighted with 11 rows, values wrapped from +5 to -5. Our own "Blk" / "Wht" pictures now sit in the S icon's place with the camera's own value next to them (firmware/mkicons.py, free font). Owner: "this is perfect!". |
| 2026-11-08 | Picture-mode sliders (camera) | Tests 5-7: new choice rows Vignette Correction (Off / On, camera icons, our own title) and Noise Filter (Off / Low / Std / High in the camera's font; the look's NR gains High, also on the Extras wheel and in LookLab on the branch). Test 7 works on the camera. Test 8 adds Blacks / Whites sliders (emulator only). |
| 2026-11-08 | WB grid (analysis) | The camera's A-B / G-M grid is the WB± row of its own WB screen, a bespoke screen; three ways to port it are in the notebook. |
| 2026-11-07 | Picture-mode sliders (camera) | Test 4 works on the camera: the code runs from the proven 64 KiB; Sharp on the Sharpness slider (−5 to +2, ends line up, 0 on the centre mark) and Grain on the camera's own Film Grain Effect row (Off / Low / Med / High) on COLOR 1–4, in step with the Extras wheel. |
| 2026-11-07 | Firmware space (camera) | 64 KiB probe: section 6 loads 64 KiB more; all 16248 pattern words intact after photos and a video. New features can use that space. |
| 2026-11-07 | Firmware space (camera) | Probe on the camera: moving section 6's loaded end by 4 KiB works; the code there ran, its pattern stayed intact over 45 checks (photos, video and Wi-Fi in use), and nothing wrote into any gap. Gaps hold no file bytes unless a loaded end is moved. |
| 2026-11-07 | Split toning | Cross Process (and likely Vintage) tint by brightness with separate R/G/B tone curves in the RGB gamma stage. COLOR photos use one curve for all three; the job copies it, so our code could bend each channel after the copy. Emulator-checked on stock code; a design and preview model exist; building needs code space. |
| 2026-11-07 | Firmware space | The camera does not load the empty stretches between firmware sections; the sliders test put code in one and must not be flashed. |
| 2026-11-07 | Picture-mode sliders | Camera slider rows can be pointed at our own values with their own range, readout and end stops. Sharp works this way in the emulator. |
| 2026-11-07 | Sharp and video | Sharp changes the photo capture path only; video most likely keeps the hidden stock Sharpness. Not tested. |
| 2026-11-06 | Firmware space | About 2.3 MiB of empty space sits between sections; nothing wrote to it in the emulator. The probe build tests whether the camera can load and use it. |
