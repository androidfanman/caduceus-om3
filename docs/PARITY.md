# Caduceus parity: E-P7 and OM-3

What each Caduceus project has, what lines up and what doesn't, so the look format, share links and Control Panel can stay shared. Compared 2026-11-09 from [cakelesscoder/caduceus-ep7](https://github.com/cakelesscoder/caduceus-ep7) at `78dbbc4 (v0.31b)` (read only) and this repo at `edbb130 (v0.26.2)`. Statuses are as each project reports them; "not researched" means nobody has looked yet.

Update this page when either project ships a feature, and regenerate the page with `research/tools/parity/make.py`.

| Same | Both, different | E-P7 only | OM-3 only | Neither yet |
|---|---|---|---|---|
| 12 | 18 | 11 | 6 | 2 |

## What to do for parity

1. **Agree the panel plan with cakelesscoder.** The E-P7 project wants one shared Control Panel with each camera as a profile; ours went OM-3-only on 2026-11-09. Pick one path before the two panels drift further. Your call; nothing is sent without your OK.
2. **Make share links open both ways.** Their panel opens our op1_ / ob1_ links; ours no longer opens their pk1_ packs or look codes. Bringing that reader back costs little and means any shared look opens anywhere.
3. **Propose schema and min_fw upstream.** Added to our looks today. Their rules ask for new fields to be proposed there first, and their copy of our om3.ts will need one more line at their next sync.
4. **Settle the hue direction.** The two projects report opposite directions for + hue. One same-scene test on both bodies decides whether shared looks turn hue the right way.
5. **Line up where Grain, NR and Sharp live.** On the E-P7 they are COLOR profile settings, here they are part of the film. A shared look carries them either way, but the two cameras apply them differently.
6. **Trade features.** To the OM-3: halation (Next), XPan / 21:9, video colour profile, button functions. To the E-P7: split toning, fast colour grain, loading at power-on, the RAW+JPEG grain lesson.

## Control Panel and formats

| Feature | E-P7 | OM-3 | Parity | Notes |
|---|---|---|---|---|
| **Which cameras the panel serves** | E-P7 and OM-3: one panel, pick the camera in setup; exports OM-3 LOOKS.BIN with our om3.ts (copied unchanged, last synced to our v0.26.1) | OM-3 only since 2026-11-09 (the E-P7 side was removed) | Both, different | The E-P7 project's stated aim (its AGENTS.md) is one shared panel hosted there, with each camera as a profile. Decide with cakelesscoder whether ours stays separate or becomes the OM-3 profile in theirs. |
| **Look settings (the JSON fields)** | name, notes, kind, hue, light, sat, grain (NR), wb, effect (+ tint for halo), vignette, lens_correction, art_effect, tone, advice, film_grain, split | The same fields, without effect tint and mono looks; plus schema and min_fw (new today) | Same | Already one shared vocabulary. Keep it that way: new fields should be agreed in both repos before shipping. |
| **Look format version and minimum firmware** | None | "schema": "caduceus-om3-look/1" and "min_fw" on every look in links and files (2026-11-09) | OM-3 only | Propose upstream (their AGENTS.md asks for new fields to be proposed there first). Their panel ignores unknown top-level fields, so our new links should still open there (analysis, not tested). Their copy of our om3.ts will need LOOK_SCHEMA from pack.ts at their next sync. |
| **File that holds a set of looks** | Pack: caduceus-pack/1 (a list of looks + which slot holds which + per-profile Grain / NR) | Bank: caduceus-om3-bank/1 (4 COLORs x 5 films) | Both, different | Two containers for the same looks. Their panel reads ours; ours does not read a pack. |
| **Share codes** | pk1_ (packs) and look codes v1-v8; also opens OM-3 op1_ / ob1_ links | op1_ (one look) and ob1_ (all 20); does not open pk1_ or E-P7 look codes (removed 2026-11-09) | Both, different | One-way today: E-P7 links don't open in our panel. Restoring pk1_ / look-code reading would make any shared look open in both. |
| **Editor style** | Sliders and lists | Camera-style screen: HSL wheel with 5 pages, Highlight & Shadow curve, WB grid, all draggable (2026-11-09) | OM-3 only | Could be offered upstream if the panels merge. |
| **Saved lists of looks** | Not found | Named lists kept in the browser | OM-3 only |  |
| **RapidRAW presets** | Yes (.rrpreset per look, zip of all) | Yes (from the shared code) | Same |  |
| **Install firmware guide in the panel** | Yes | Yes | Same |  |
| **Film name in the photo's EXIF** | No | v0.27 (in test): Description "FILM n Name", User Comment "Caduceus FILM n Name om3.1.<code>" ([PHOTO_CODE.md](PHOTO_CODE.md)) | OM-3 only | Proposed text layout to share; an E-P7 code would carry its own name (e.g. ep7.1.). Owner decides whether to propose it upstream. |

## Look settings

| Feature | E-P7 | OM-3 | Parity | Notes |
|---|---|---|---|---|
| **Hue per colour (12 colours)** | -7..+7; camera-tested | -5..+5; camera-tested | Both, different | Range differs. Open question in the E-P7 notes: + may turn hue the opposite way on the two bodies. Needs one same-scene test on both. |
| **Luminance per colour** | -7..+7 (Light page); camera-tested | -5..+5 (Luminance page); camera-tested | Both, different | Range only. |
| **Saturation per colour** | Camera's own wheel; camera-tested | Camera's own wheel; camera-tested | Same |  |
| **Highlights / Midtones / Shadows** | Set by the look on the camera's tone screen | Set by the film; Highlight & Shadow box | Same |  |
| **Blacks / Whites** | -5..+5 (Extras 6 / 7); camera-tested | -5..+5 (Blk / Wht rows); camera-tested | Same |  |
| **WB shift A-B / G-M** | -7..+7 (Extras 3 / 4) | -7..+7 (WB grid row, v0.26.1) | Same |  |
| **Glow / Clarity** | One slider (Extras 2); camera-tested | Glow row (+ Glow, - Clarity); camera-tested | Same |  |
| **Tinted halation** | v0.31: Off / Low / Med / High, Red / Amber; set by the look | Not yet (roadmap: Next) | E-P7 only | Our export turns a halation look into plain glow today. Ours would use the Glow route; keep the same field (effect + tint). |
| **Split toning** | No (E-P7 notes: portable, 1-2 sessions) | v0.26: Shadows / Highlights pages, 12 colours, -5..+5; camera-tested | OM-3 only | Field already shared (split); the E-P7 keeps it in packs but its card files ignore it. |
| **Film grain** | v0.27: CPU grain on brightness only, 3-5 s extra per photo, stills; a COLOR profile setting, not part of the look | v0.25: colour grain by the image processor, no extra time; part of the film (film_grain) | Both, different | Biggest difference: speed, colour, and where it lives (profile vs look). The E-P7 notes rate our fast-grain route portable (2-3 sessions). |
| **Grain with RAW+JPEG** | Not tested yet (reports welcome) | Freeze fixed in v0.26.2; camera-tested | Both, different | Worth telling the E-P7 project the cause: a RAW+JPEG shot runs a second development. |
| **Noise Filter** | Per COLOR profile: Camera / Std / Low / Off (a look's NR is ignored since v0.27) | Per film: Off / Low / Std / High (High from v0.24.1) | Both, different | Profile setting vs look setting; no High on the E-P7. |
| **Sharpening** | Per COLOR profile: Camera / Off (v0.28) | Per film: -5 (Off) .. +2 (v0.22) | Both, different | Profile vs look, and range. |
| **Contrast** | Advice only (preview, not saved to the camera) | Per film -2..+2, saved to the camera | Both, different |  |
| **Shading (vignette)** | Stored in the look only | Per film (Shading row) | Both, different |  |
| **Lens vignette correction off** | Per look (v0.25; effect on photos not yet confirmed) | Per film (Vignette Correction row, v0.21) | Same |  |
| **Art Effects (Star Light, Pin Hole)** | Yes | None since v0.25 (too many issues) | E-P7 only | Our export writes them as Off. |
| **Monochrome looks** | 10 mono film presets (Pan F .. Cyanotype); camera-tested | COLOR only | E-P7 only |  |

## Films and menus

| Feature | E-P7 | OM-3 | Parity | Notes |
|---|---|---|---|---|
| **Built-in films** | 29 colour + 10 mono (some inspired by other people's recipes, credited) | 20 colour, our own designs, tuned from colour-checker photos; 61 to choose from in the panel | Both, different | Different sets. The E-P7 notes suggest adding our 20 to their library, with credit. |
| **How a film is picked** | Film page on the colour wheel; one look per COLOR 1-4 slot; name in Picture Mode | FILM 1-20 as entries in the Picture Mode list (5 per COLOR); name as the title | Both, different | Different UI on each body; the look data is the same. |
| **Changes kept per film** | Each slot keeps its edits (BUNDLES.BIN), * when changed | Each film keeps its edits (EDITS.BIN), * when changed, hold OK = as built | Same | Same idea, different files. |
| **When films load** | First half-press (retries since v0.31a) | At power-on (v0.26.2, from fernandezk26's fork) | Both, different | A port candidate for the E-P7. |
| **Saving to the card safely** | Yes, with a .BAK | Yes: .NEW read back, then .BAK | Same |  |
| **Super control panel steps through films** | Not found | v0.26.2: dials go COLOR 1-4, FILM 1-20 | OM-3 only |  |
| **Film name on the shooting screen / viewfinder** | Name in the Picture Mode list | FILM N on the shooting screen and viewfinder | Both, different |  |
| **Live view shows the look** | Hue, light and bloom | The look, incl. split toning and glow | Same |  |
| **Code loaded from the card (GUIDES.BIN block)** | Idea to assess (E-P7 notes) | Yes, since v0.20 | OM-3 only | Eases firmware space; the E-P7 notes list it as worth assessing. |

## Camera features

| Feature | E-P7 | OM-3 | Parity | Notes |
|---|---|---|---|---|
| **Colour profile for video** | Movie Vivid becomes its own profile (MOVIE.BIN); camera-tested | Planned (#3) | E-P7 only |  |
| **Colour profile in AP modes** | v0.30 (AP.BIN) | Not researched | E-P7 only |  |
| **Log video** | Hidden log curve via Muted; camera-tested | OM-Log400 is stock; 10-bit for other profiles planned | Both, different |  |
| **XPan 65:24 and 21:9 stills** | Camera-tested (v0.29 fixes) | Planned (custom crop modes) | E-P7 only | Their docs/ASPECT.md is the map to follow. |
| **Live ND** | ND3 / ND4 via Multiple Exposure (early alpha) | Stock camera feature (the E-P7 notes confirm the OM module) | Both, different | Nothing to port. |
| **Lowest shutter speed setting** | v0.30 (Custom Menu E1) | Not researched | E-P7 only |  |
| **Button functions** | v0.29: more REC / Fn choices, right and down arrows settable | Requested (#8, #9, #10) | E-P7 only |  |
| **Panasonic aperture ring** | Built, emulator only | Planned | Both, different | Their docs/APERTURE_RING.md may shorten our work. |
| **Focus stacking with any lens** | Lead: focus bracketing looks stock | Planned | Neither yet |  |
| **Vertical video rotation** | Camera-tested | Not researched | E-P7 only |  |
| **Video recording limit raised** | 9 hours (camera-tested) | Not researched | E-P7 only |  |
| **Rear screen colour fix** | v0.20 (screen only) | Not requested | E-P7 only |  |
