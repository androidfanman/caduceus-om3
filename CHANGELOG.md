# Changelog

Versions are named v0.N from v0.18 on. Earlier builds were called "test N" while they were tried on the camera; the
same number is used here (test 17 = v0.17).

## v0.26.2
Films load at power-on, the dials step through the films, and three fixes. Firmware camera-tested (2026-11-09, build
sd4).

**Firmware**
- **Films load at power-on:** the card files load by themselves a moment after the camera starts; no half-press
  first. Live view and the labels follow as soon as they are loaded. A half-press or OK still loads them too.
  From [fernandezk26](https://github.com/fernandezk26/camera-stuff)'s fork (the loader task); see [docs/SD_LOADER.md](docs/SD_LOADER.md).
- **Super control panel:** the dials on the Picture Mode cell step COLOR 1–4, then FILM 1–20 (and back round); the
  cell and the title follow.
- **Fix: Film Grain with RAW+JPEG froze the camera** after the photo (v0.25 to v0.26.1). A RAW+JPEG photo develops a
  second picture (the RAW's preview), which reset the grain's state while the JPEG was still being made.
- **Fix: "FILM N" on the shooting screen and in the viewfinder** was replaced by "COLOR n" when COLOR n's own
  settings had been changed.
- **Fix: bad bytes in `EDITS.BIN`** (unused bytes saved as 0xFF could make a film's saved changes unreadable): they
  are cleaned when saved and when read. Found and first fixed by [fernandezk26](https://github.com/fernandezk26/camera-stuff).
- `GUIDES.BIN` is new (always copy it with the firmware); `LABELS.BIN`, `TONES.BIN` and the optional `LOOKS.BIN` are
  as v0.26.1.

## v0.26.1
WB shift up to ±7 in films, and the 20 film sims tuned from colour-checker photos. Firmware camera-tested (2026-11-09,
build wb7).

**Firmware**
- `LOOKS.BIN` accepts a WB shift of −7..+7 (record +37 / +38), like the camera's own fine-tune. v0.26 and older
  refused the whole file past ±5, so none of the films loaded.

**Film sims and Control Panel**
- **Control Panel: the editor looks like the camera's Picture Mode screen** (2026-11-09): the HSL wheel with the
  camera's five pages (Color, Hue, Luminance, Shadows, Highlights) drawn as a colour ring with a value outline, the
  Highlight & Shadow box with Sh / Mid / Hi, the WB fine-tune box, and the rows in the camera's order. The wheel, the
  curve's handles and the WB marker can be dragged with the mouse; every slider has − / + ends and stays as well.
- **Control Panel: the 20 film sims tuned** (draft 1, 2026-11-09): new colours, WB and tone for all 20 from the owner's
  colour checker photos, and new split tones on Gold 200, Portra 800, CineStill 800T and Fuji Eterna. Contrast and
  Sharp are as before (Gold 200 now Sharp −1). **New › Reset looks to standard** gives the new set.
- **Control Panel: grain preview** matches the camera better (owner, 2026-11-09: the preview's Med looked like the
  camera's High). High is now drawn as Med was, and Low / Med follow the camera's own steps.
- **Control Panel: WB shift −7..+7**, as on the camera. LOOKS.BIN carries past ±5 only with Export › Firmware on the
  camera › "v0.26.1 or later" (now the default): v0.26 and older refuse the whole file beyond ±5, so for them it is
  saved as ±5 and the export says which looks.
- The release's optional `LOOKS.BIN` is the tuned 20.

## v0.26
Split toning, and a fix for a restart after changing the drive mode. Firmware camera-tested (2026-11-09, build sp4).

**Split toning**
- Two new pages on the HSL wheel, **Shadows** and **Highlights** (INFO after Luminance): each tints the shadows or
  the highlights toward one of the wheel's 12 colours (front dial), with a strength −5..+5 (rear dial; minus = the
  opposite colour). Shown in live view and in the photo; kept per film and over power off (`LOOKS.BIN` / `EDITS.BIN`
  record +53..+56). Hold OK resets it; the `*` shows only when a strength is set.
- New card file `OM3MOD/TONES.BIN`: the guides shown on the two pages (without it the camera's own guide shows).
- How: the look's tint bends the photo's R / G / B tone curves (peak in the shadows or the highlights, each curve
  kept rising), at the end of the tone stage, for photos and live view alike.
- The 20 film sims (optional `LOOKS.BIN`): ten carry a light split tone (strength 1–2); the rest are as in v0.25.

**Fixes**
- Changing the drive mode (for example to silent shooting) and then opening a COLOR or film to change it could
  restart the camera (in v0.25 too): the WB grid row picked up a screen element from the drive-mode screen. It now
  only uses the Picture Mode screen's.

**Control Panel**
- **Split toning** (2026-11-09): two colour wheels, Shadows and Highlights, with the strength, shown in the preview.
  Export › Firmware on the camera now defaults to "v0.26 or later", which saves it; older settings leave it out.
- **Control Panel: OM-3 only** (2026-11-09): the E-P7 side is gone (camera switch, E-P7 packs and `LOOKS.BIN`, look
  codes, export targets). OM-3 looks are shared as links (`op1_` / `ob1_`), as before. The built-in library's starter
  looks from Caduceus for the E-P7 (credited) are still offered on an empty place.

## v0.25
Fast colour film grain, a WB grid row, a Glow row, settings kept over power off, and 20 new film sims. Firmware
camera-tested (2026-11-08, build fx3); the 20 film sims were tuned on the Control Panel's preview.

**Film grain**
- Film Grain on COLOR photos is now made by the camera's **image processor while it develops the photo**, the way the
  Grainy Film Art Filter adds its grain (its ready-made grain texture), but kept in colour. It saves **as fast as a
  photo without grain**, with every other setting (Shading and Glow / Clarity included).
- Three clearly different strengths (Low / Med / High). The texture's slight brightening is taken back, so grain no
  longer lifts the photo, and colours stay as they are.
- The v0.21–v0.24 grain (the camera's Monochrome grain forced on COLOR photos) is gone with its limits: no more black
  and white with Shading, no grain lost with Glow.

**Picture Mode screen**
- **WB row:** one row in place of A-B and G-M. It shows a small grid with the dot where the film's shift is, and
  "A2.G1"-style numbers under WB±. **OK**, left / right or a dial opens the camera's own WB fine-tune screen on the
  film's A-B / G-M, with the camera's own directions.
- **Shading** is back (v0.24.1 hid it), and its number sits in line with the other rows.
- **Glow row:** + is Glow (soft glow), − is Clarity (local contrast), −5..+5.
- **No Art Effects any more:** Star Light, Pin Hole, White Edge and Frame are gone (Shading does the dark corners).
- Picture Mode always opens on its top row.

**Kept over power off**
- Changes to films and to COLOR 1–4 and the film you were on are now kept when you switch the camera off and on
  (a v0.24 bug stopped the half-press save once the editor had been used).
- The viewfinder's info screen shows the film you're on.

**Film sims and the Control Panel**
- **20 new film sims**, our own designs, rewritten with every setting the camera now has (colour per slice, WB shift,
  Contrast, Highlights / Shadows / Midtones, Blacks / Whites, Sharp), in this order as FILM 1–20: Portra 400,
  Gold 200, Kodachrome 64, Portra 800, CineStill 800T, Ektar 100, Ultramax 400, Pro 400H, Velvia 50, Superia 400,
  ColorPlus 200, CineStill 400D, Fuji C200, Ektachrome E100, Reala 100, Provia 100F, Vision3 250D, Fuji Eterna,
  Astia 100F, Agfa Ultra 100. None uses grain, Glow / Clarity or an Art Effect. The release has them as an optional
  `LOOKS.BIN`.
- The Control Panel's list is now **one list, FILM 1–20**, the same order as the camera (no COLOR 1–4 groups). New
  visitors start with the 20 films; **New › Reset looks to standard** gives them to existing users.
- **Film sims** shows **The 20** first, in FILM order; the other films follow under "More". Renamed: Fuji 400H →
  Pro 400H, Superia Reala → Reala 100 (looks using the old names still work); new: Fuji Eterna (the cinema film).
- Export › Firmware on the camera: **v0.25 or later** (new default; Shading kept, Art Effect Off), v0.24.1 (Shading 0),
  v0.22, v0.21, v0.20 or older.

## v0.24.1
v0.24 with the reboot fixed and the Shading row hidden. Camera-tested (2026-11-08). Everything listed under v0.24
below is in this version, except where this section says otherwise.

- **Fixed:** with **Film Grain High**, taking a picture restarted the camera. The grain code no longer asks the
  camera's settings for Shading while the photo is being taken (that call is what restarted it).
- **Shading row hidden** on COLOR 1–4 for now: Shading together with Film Grain turned the photo black and white. A
  Shading value set before flashing stays in effect, so set it to 0 first. Grain with Shading is therefore not added
  the slow way any more (as in v0.22).
- **Control Panel:** Export › Firmware on the camera: **v0.24.1 or later** saves every look with Shading 0; the editor
  warns when a look has Grain together with Shading, and the slow-grain note is only about v0.20–v0.22.
- `releases/v0.24` is removed (it rebooted the camera); v0.24.1 replaces it.

## v0.24 (withdrawn)
Published and withdrawn on 2026-11-08: on the owner's camera, a photo with Film Grain High rebooted the camera.
Replaced by v0.24.1. What it added (all in v0.24.1):

Your films in the camera's Picture Mode list, and the look's settings on the camera's own Picture Mode screen.
v0.23 was never released on its own: its Picture Mode rows are part of this version.

**Films in the Picture Mode list**
- After COLOR 1–4 the list shows every film on the card (`LOOKS.BIN`, up to five per COLOR) as **FILM 1, FILM 2, …**,
  in the same style as the COLOR cells. Choosing one loads it onto the COLOR it belongs to. Its **name** is the big
  title, and the quick menu (super control panel) and the **shooting screen** show **FILM n**.
- **Changes are kept:** whatever you change on a film, or on COLOR 1–4 themselves, stays when you switch away and
  back. The camera keeps them in a new file, `OM3MOD/EDITS.BIN`; the films as built stay untouched in `LOOKS.BIN`.
- **Hold OK** on a film: back to the film as built (on the HSL wheel too). On COLOR 1–4: back to the factory.
- **`*` means changed:** COLOR n from the factory, a film from how it was built; also on each changed row (Blacks,
  Whites, A-B, G-M, Noise Filter … compared with the film).
- The colour wheel row reads **HSL**. Its pages are the camera's own: Color → Color All → Hue → **Luminance** (was
  Light).

**Picture Mode rows (was the Extras page)**
- COLOR 1–4 get the look's settings as rows on the camera's Picture Mode screen: Picture Mode, HSL, Contrast,
  Highlight & Shadow, **Blacks**, **Whites** (−5..+5), **A-B**, **G-M** (WB shift −7..+7), **Sharpness** (Sharp,
  −5 Off..+2), **Noise Filter** (Off / Low / Std / **High**, High is new), **Vignette Correction** (lens correction
  Off / On), Shading and **Film Grain** (Off / Low / Med / High).
- The Film and Extras pages of the wheel are gone (their jobs moved to the list and the rows).

**Switched off for now**
- **Glow / Clarity and Art Effects** are off: with them, grain can only be added the slow way. They stay in your looks
  (and work again on v0.20–v0.22) until fast grain works with them.
- **Grain with Shading** is added the slow way (about 3 s more per photo, no fast burst): the camera's fast grain
  turned such photos black and white. Grain with every other setting is as fast as normal. Faster grain with every
  effect is the next project ([plan](ROADMAP.md)).

**Control Panel**
- Export › Firmware on the camera: **v0.24 or later** (new default; NR High), v0.22, v0.21, v0.20 or older.
- A note in the editor that Glow / Clarity and Art Effects are off on v0.24, and the slow-grain note now also covers
  Shading.

## v0.22
Sharpness as part of the look. Camera-tested.

**Sharp (Extras sector 10)**
- **Sharp −5..+2** per look, in the camera's own sharpness numbers: **0 is its normal**, +1 / +2 crisper, −1 and −2
  as the stock menu's, **−3 and −4 softer than the menu goes**, and **−5 = Off** (no sharpening; the label reads
  "Sharp Off"). It works with Grain and every other Extra. On the camera, Off is clearly softer than 0.
- The camera's own **Sharpness row is gone from the COLOR 1–4 screen** (Contrast is now the last row), so the two
  never overlap. Its stored value is ignored for COLOR photos and no longer counts toward the `*`.
- LOOKS.BIN records keep Sharp in `+52` (BUNDLES slot `+54`). Older firmware rejects a non-zero `+52`.

**Control Panel**
- Sharp replaces the Sharpness slider and moves to the Extras (−5..+2, "Off" at −5). Looks you already have keep
  their sharpness (same numbers).
- Export › Firmware on the camera: **v0.22 or later** (new default), v0.21 (Sharp goes to the camera's Sharpness
  setting, −2..+2), v0.20 or older.
- **Film sims set Sharp:** fine-grained slide and negative films (Velvia, Provia 100F, Ektachrome E100, Kodachrome 25,
  Ektar) a step crisper (+1); portrait, cinema and fast films softer (Portra, 400H, Eterna, Vision3 250D, CineStill
  800T, Superia 800: −1; Superia 1600, LomoChrome 92, Candido 800, Polachrome, FP-100C: −2); Polaroid 600 and SX-70
  softest (−3). None uses Off. Film looks already in your lists get their film's value once, unless you had set
  Sharp yourself; Reset look puts it back too.

## Control Panel updates after v0.21
No firmware change: these work with v0.21 as released.

- **Film sims:** a new button (and "From the film sims…" on an empty number) with 60 film looks, one for each film,
  in five groups: Fujifilm simulations, slide film, colour negative, instant film and cinema print. They're our own
  looks, designed by hand from what each film is known for and tuned on the sample photos, using only the OM-3's
  colour settings (Hue, Light and Saturation per colour, Highlights / Shadows / Midtones, Blacks / Whites, Contrast,
  WB shift). No grain, Glow / Clarity or Art Effects: add those yourself if you like. Preview on your photo, add to
  any empty number, remove like any look.
- The grain preview is gentler, closer to how the photo looks on screen.
- **New sample photos** in OM-3 mode: public-domain (CC0) photos at higher resolution, picked for skin, strong
  colour, greens, blues, night light and sunset, next to the colour-frames photo. The preview is sharp on Retina
  screens and the right size in Safari.
- **Lists:** save all four COLORs' looks as a named list and switch between lists (Save as…, Rename, Delete above
  the looks). The list you're on is the one you edit; the looks you already had are the list "Default". When all 20
  numbers are used, adding a film sim asks first and then lets you pick the look to replace.
- **New standard set** (first visit, and New › Reset looks to standard): one theme per COLOR, all film sims except
  Bleach Bypass, with no grain, Glow or Art Effects. COLOR 1 Fujifilm (Classic Chrome, Classic Neg, Reala Ace, Eterna, Pro Neg Std),
  COLOR 2 slide (Velvia 50, Kodachrome 64, Ektachrome E100, Provia 100F, Astia 100F), COLOR 3 negative (Portra 400,
  Portra 160, Ektar 100, Gold 200, Fuji 400H), COLOR 4 cinema and instant (CineStill 800T, Kodak 2383, Vision3 250D,
  FP-100C, Bleach Bypass). Existing lists are not changed.
- Film sims already in the list you're on are marked in Film sims with where they are ("✓ COLOR 2 · 1"), even after
  renaming or editing them, and **Reset look** on a film sim puts that film's values back.

## v0.21
Film grain on colour photos, looks you save on purpose, and a `*` that means "not factory". Camera-tested.

**Grain (Extras sector 9)**
- **Grain 0 Off, 1 Low, 2 Med, 3 High** on COLOR photos: the camera's own Monochrome grain (same texture, its Low /
  Medium / High strengths), on colour. The label reads "Grain" and the value shows the level.
- On its own, or with NR, the WB shift, Blacks / Whites or VigFix, the grain is made by the camera's image
  processor while it develops the photo: no extra time, and every other setting still applies.
- **With Glow / Clarity or an Art Effect** in the same look, the camera's processor can't add it there, so it is
  added to the finished photo in software (brightness only, the same pattern and strengths). **Each photo then takes
  about 3 seconds longer to save, and fast sequential (burst) shooting isn't possible with that look.** Making this
  fast is on the roadmap.
- Grain shows in the saved photo, not in live view.

**VigFix (Extras sector 8)**
- 0 Camera (your Shading Comp. menu setting) or 1 Off: the lens's vignette correction turned off for photos with this
  look, for natural corners, without changing the menu setting (as Caduceus's VigFix). Labels "Vig Cam" / "Vig Off".

**Saving looks on purpose**
- **Hold OK on the Film page** (a look 1–5 selected) saves the COLOR's current settings into that look. This is now
  the only way a look changes: turn to another look without it and your changes are dropped, so the saved look
  stays as it was. You can try things out without losing a look.
- The Film page never resets, and shows no "Reset" hint.
- **Hold OK on Saturation, Hue, Light or Extras** resets the wheels and Extras as before; the selected look stays.
- **Hold OK on the "COLOR n" item** resets the whole COLOR to the factory settings, Picture Mode settings included,
  and sets the Film page back to 0.

**The `*`**
- The `*` after "COLOR n" now means **something differs from the camera's factory settings** for that COLOR, on every
  page (the Film page included). After a reset, or on Film 0, it's gone; change anything and it's back. A selected
  look usually shows one, since the look changes settings.
- **Film 0** now loads the COLOR's own factory settings. Before, it set everything to 0, which on COLOR 2–4 (whose
  factory saturation and tone aren't 0) left a `*` that wouldn't go away.

**Fixes and smaller changes**
- **WB amber / blue and green / magenta now work with Auto WB.** Before, the WB shift was ignored in Auto WB and only
  applied to the other white balance modes.
- The rear dial stops at each Extras sector's first and last value (before, it could go past the end, and the next
  turns back did nothing).
- A reset could leave a saturation value off its factory setting when the wheel was last on the Film or Extras page
  (COLOR 4 kept a `*` after a reset on "COLOR 4"). The wheel now switches to Saturation for the reset and back
  afterwards.

**Control Panel**
- **Grain** (Off / Low / Med / High) and the **lens vignette correction** in the Extras, both written to `LOOKS.BIN`.
- The preview shows the grain as the photo looks at that size.
- **Drag the line on the photo** to compare before and after (it replaces the "Hold: original" button).
- A note under Grain when a look combines it with Glow / Clarity or an Art Effect: slower saving and no fast burst.
- Looks files keep Grain and the lens correction setting (the lens correction setting was lost on reopening before).
- Export › **Firmware on the camera**: v0.20 or older leaves Grain and the lens correction out of `LOOKS.BIN`
  (older firmware would ignore a file with them set).

**Card files and upgrading**
- Copy `DCOLYMP` (flash it) and both new `OM3MOD` files: `GUIDES.BIN` (the Extras code, made for this firmware) and
  `LABELS.BIN` (adds the VigFix and Grain labels). Keep your `LOOKS.BIN`, `NAMES.BIN` and `BUNDLES.BIN`: looks from
  v0.20 load with Grain off and the lens correction as before.
- Going back to v0.20 or older: those reject a `LOOKS.BIN` with Grain or VigFix set. Save it from the Control Panel
  with **v0.20 or older** chosen in Export.
- `patch.py` accepts the official firmware under the name OM's server uses now, `OLY_E_147_1100_0000_0000.BIN`, as
  well as the earlier `…_3.BIN` (issue #2).

## v0.20
The Color Profile wheel now matches Caduceus for the E-P7: a **Film** page, the colour pages and one **Extras** page
with the look's effects. Camera-tested.

**Pages**
- INFO order: **Film** → Saturation → (All) → **Hue** → **Light** → **Extras** → **Film**. The **Looks** page is now
  called **Film** on the camera (the card file is still `LOOKS.BIN`). The **WB/BW** page is gone: its four values
  moved onto the Extras page.
- **INFO changes page from any slice.** Before, INFO away from 12 o'clock switched to "all colours" instead. The
  editor now reads the camera's own "all colours" state the way the stock INFO does (the camera keeps it in one of two
  settings, depending on the slice it was entered from), so Saturation → All → Hue also works from any slice.

**Extras page** (sector 1 at 12 o'clock, then clockwise)
- **1 NR**: the camera's noise reduction for photos with this look: 0 Camera (your menu setting), 1 Standard, 2 Low,
  3 Off (most texture). It is applied at every photo (the stills Noise Filter reads at capture and in the photo's
  recorded settings) and follows a profile switch; the menu setting itself is never changed.
- **2 Glow ← → Clarity**: −1..−5 glow, the camera's Soft Focus passes on a COLOR photo with Caduceus's five strengths
  (−5 is about the stock Soft Focus); +1..+5 clarity, the same passes with a negative blur weight (an unsharp mask
  with a large radius, as Caduceus). 0 is off.
- **3 WB amber / blue** and **4 WB green / magenta** (−5..+5), added to the camera's own white balance.
- **5 Art Effect**: 1 Star Light, 2 Pin Hole, 4 White Edge, 5 Frame on COLOR photos without an Art Filter (the
  numbers are Caduceus's; 3 does nothing).
- **6 Blacks** and **7 Whites** (−5..+5), the ends of the tone curve.
- **8**: reserved (Caduceus's VigFix is not built for the OM-3 yet).
- **Dial labels:** on Extras, the label next to the value (stock: "Vivid") names the sector and what its value does:
  NR / NR Std / NR Low / NR Off, Glow / Clarity / Glo/Cla, A / B / A/B, G / M / G/M, Art Off / Star / Pin Hole /
  W. Edge / Frame, Blacks, Whites. Other pages keep "Vivid". From the new `OM3MOD/LABELS.BIN`.
- Every Extras value is part of the look: it saves into `LOOKS.BIN` (record bytes +47..+49) and `BUNDLES.BIN`, loads
  with a Film pick, counts for the `*`, and is cleared by the hold-OK reset.

**Live view**
- Glow and the Art Effects now show in live view on COLOR profiles, through the same switch the camera uses for Art
  Filter previews. Clarity shows only in the saved photo (as in Caduceus). Movies recorded with such a look get the
  effect too.

**White frame**
- The Frame Art Effect draws a clean **white** border of the stock size instead of the rough black film edge. The
  firmware's 13 frame pictures are replaced by our own JPEGs (white outside the stock window, nothing copied from OM),
  so this applies everywhere the Frame effect is used, Art Filters included.

**Fixes**
- Hold-OK reset works on the Extras values, and from any page (before, a look whose only change was an Extras value
  looked unchanged, so neither the `*` nor the reset reacted).
- The `*` appears for Extras changes.

**Card files and upgrading**
- New `OM3MOD/GUIDES.BIN` (labels "Extras" and "Film") that also carries the **Extras code**: the firmware had no room
  left, so the effects run from a block of code at the end of this file, loaded and checked at the first half-press.
  The block only runs on the firmware it was built with: always copy the release's `GUIDES.BIN` with its firmware.
  Without it the editor still works and saves the Extras values, but the effects are off.
- New `OM3MOD/LABELS.BIN` (the Extras labels; optional).
- `PROFILES.BIN` is no longer read (v0.19 converted it): coming from v0.16–v0.18, rename it to `LOOKS.BIN`.
- Looks saved by earlier versions load with every Extras value at 0. A test-build card with "Frame" at 1 shows Star
  Light now: set sector 5 to 5.

**Control Panel**
- OM-3 mode has the Extras: **NR** (Camera / Std / Low / Off), **Glow ↔ Clarity** and **Art Effect** (Off, Star Light,
  Pin Hole, White Edge, Frame), saved in `LOOKS.BIN`; the preview shows glow and clarity. Caduceus looks bring their
  NR, glow / clarity and Star Light / Pin Hole along (a halation glow becomes a plain glow; Blur is left out). Text
  says Film and Extras.

**Installer and project**
- `firmware/patch.py` makes v0.20 including the white frames (it draws the 13 pictures itself and patches only those
  bytes of the resource component) and writes `GUIDES.BIN` and `LABELS.BIN` to `OM3MOD`. Older releases build as
  before. `tools/mkpatch.py` makes a release's `patch.json`; `firmware/build.py` builds everything from source,
  byte-identical to the release.

## v0.19
- **Profiles are now Looks**, matching Caduceus: the wheel page is labelled **Looks** (new `GUIDES.BIN`) and the
  bank is `OM3MOD/LOOKS.BIN` (same format). With no `LOOKS.BIN` yet, the camera reads the `PROFILES.BIN` of
  v0.16–v0.18 and the next save writes `LOOKS.BIN`. The Control Panel's OM-3 mode says Looks and exports
  `LOOKS.BIN` (plus a `PROFILES.BIN` button for v0.17–v0.18).

## Control Panel (no new firmware)
- The OM-3 Look Lab is now the **Caduceus Control Panel**, the same tool as Caduceus for the E-P7, with a camera
  switch at the very top: **Olympus PEN E-P7** shows cakelesscoder's panel unchanged, **OM SYSTEM OM-3** the version
  for this firmware (COLOR 1–4 × profiles 1–5, OM-3 ranges, Contrast / Sharpness / Shading, `PROFILES.BIN` +
  `NAMES.BIN` export, Caduceus looks converted). Profiles from the old Look Lab are brought over. Works with v0.17+.

## v0.18
- The Color Profile wheel opens on the **Profiles** page, with the selected profile's name. INFO order unchanged:
  Profiles → Saturation → (All) → Hue → Light → WB/BW → Profiles. Camera-tested.

## v0.17
- **Profile names** under the wheel on the Profiles page ("Velvia", "Empty" …), from `OM3MOD/NAMES.BIN`, drawn by
  the Look Lab in the camera's own label style. Camera-tested.

## v0.16 (test 16 / 16b)
- **Profile bank:** 5 profiles for each of COLOR 1–4 in `OM3MOD/PROFILES.BIN`, each holding every wheel plus
  Contrast, Sharpness, Shading and Shadows/Midtones/Highlights. Profiles page dial 0–5 (0 = neutral); changes made on
  the camera are kept in the selected profile and saved at the half-press. Camera-tested.

## v0.15
- Per-COLOR looks page (wheels only); replaced by the profile bank in v0.16.

## v0.11
- On-camera **Hue**, **Light** and **WB/BW** pages (A/B, G/M, Blacks, Whites) for COLOR 1–4, saved to
  `OM3MOD/BUNDLES.BIN`; page labels from `GUIDES.BIN`. Camera-tested.
