> [!WARNING]
> **Experiment branch `experiment/firmware-space-probe-256k` (GX3), not a release.** On top of v0.26.2: section 6 loads
> 256 KiB more (0x60f59800 -> 0x60f99800) holding a probe and a known pattern; at half-presses the probe checks the
> pattern and that nothing writes into the unloaded gaps, and writes `OM3MOD/GAPTEST.BIN`. Emulator: 19 passes, 0 bad
> of 65400 words. Camera: pending. Afterwards flash v0.26.2 again with its own `GUIDES.BIN`.

# Caduceus for OM-3

**Caduceus for OM-3** is the OM SYSTEM OM-3 member of the [Caduceus](https://github.com/cakelesscoder/caduceus-ep7)
family, made together with cakelesscoder: open-source firmware patches for the **OM SYSTEM OM-3** (firmware 1.1). It puts
**your films in the camera's Picture Mode list** (FILM 1–20 after COLOR 1–4, each with its name; 20 film sims come
with it), turns the Color Profile wheel into a colour editor (per-colour Hue and Luminance next to the camera's
Saturation), and adds the look's settings to the camera's own Picture Mode screen: Blacks, Whites, a WB grid, Sharp,
Noise Filter, lens vignette correction, Shading, Glow / Clarity and fast colour film grain. Films are made in the browser with the **Caduceus Control
Panel**; changes you make on the camera are kept per film.

**Latest: v0.26.2** ([changelog](CHANGELOG.md)) · **▶ [Control Panel](https://androidfanman.github.io/caduceus-om3/)** · **[Install guide](docs/INSTALL.md)** ·
**[Using it](#using-it)** · **[Roadmap](ROADMAP.md)** · Caduceus for the E-P7: [cakelesscoder/caduceus-ep7](https://github.com/cakelesscoder/caduceus-ep7).

> [!WARNING]
> **Early development, use at your own risk.** This is an unofficial, experimental firmware modification. Bugs will
> turn up, and flashing modified firmware can crash or freeze the camera, corrupt photos or the card's data, or leave
> the camera needing a restore. **No responsibility is accepted for any damage, data loss or other harm.** It is
> provided "as is", without warranty of any kind (see the [Apache License 2.0](LICENSE), sections 7–8). Using it may
> affect your warranty with OM Digital Solutions.
>
> Every change is checked in an emulator of the camera's CPU before it goes on a camera, the SD update and restore
> path is proven on a real OM-3, and features marked **camera-tested** below have run on a real camera. Read
> [Safety](#safety) before flashing.

> [!NOTE]
> **Color profiles only.** Everything here works on Picture Mode **COLOR 1–4**. The **Monochrome** profiles are not
> changed: they keep the camera's own editor.

## Features

| Feature | What you get | Status |
|---|---|---|
| **Films in the Picture Mode list** | After COLOR 1–4, Picture Mode lists your films as **FILM 1–20** (from `LOOKS.BIN`). The film's name is the big title; the quick menu, the shooting screen and the viewfinder show it. | Camera-tested (v0.25) |
| **20 film sims** | Portra 400, Gold 200, Kodachrome 64, Portra 800, CineStill 800T, Ektar 100, Ultramax 400, Pro 400H, Velvia 50, Superia 400, ColorPlus 200, CineStill 400D, Fuji C200, Ektachrome E100, Reala 100, Provia 100F, Vision3 250D, Fuji Eterna, Astia 100F, Agfa Ultra 100: our own looks, in this order as FILM 1–20 (see [the list](#the-20-film-sims)). | New in v0.25 (tuned on the Control Panel preview) |
| **Changes kept** | What you change on a film, or on COLOR 1–4, stays when you switch away and back and **over power off**, with the film you were on (kept by the camera in `EDITS.BIN` and `LOOKS.BIN`). **Hold OK** on a film: back as built; on COLOR n: back to the factory. A `*` marks what is changed. | Camera-tested (v0.25) |
| **Hue and Luminance** | The Color Profile wheel (the **HSL** row) gains pages: **INFO** goes Color → Color All → Hue → Luminance. Hue turns a colour toward its neighbour; Luminance brightens or darkens it, for each of the 12 colours. | Camera-tested |
| **Films load at power-on** | Your films and changes load from the card by themselves when the camera starts: no half-press first (from [fernandezk26](https://github.com/fernandezk26/camera-stuff)'s fork). | Camera-tested (v0.26.2) |
| **Dials step through the films** | On the super control panel, the dials on the Picture Mode cell go COLOR 1–4, then FILM 1–20, and the label follows. | Camera-tested (v0.26.2) |
| **WB shift ±7 in films** | A film's WB shift goes −7..+7 each way, like the camera's own fine-tune (v0.26 stopped `LOOKS.BIN` at ±5). | Camera-tested (v0.26.1) |
| **Split toning** | Two more wheel pages, **Shadows** and **Highlights** (INFO after Luminance): tint the shadows and the highlights toward any of the wheel's 12 colours, strength −5..+5. Shows in live view; kept per film. | Camera-tested (v0.26) |
| **Picture Mode rows** | On COLOR 1–4 and films: **Blk** / **Wht** (Blacks / Whites −5..+5), **WB** (a grid with the film's A-B / G-M shift; OK opens the camera's own WB fine-tune screen; works in every WB mode, Auto WB included), **Sharpness** (−5 Off..+2), **Noise Filter** (Off / Low / Std / High), **Vignette Correction** (Off / On), **Shading**, **Glow** (+ Glow, − Clarity) and **Film Grain**, next to the camera's Contrast and Highlight & Shadow. | Camera-tested (v0.25) |
| **Film grain on COLOR** | Low / Med / High grain, in colour, made by the camera's image processor as the photo develops (the way its Grainy Film Art Filter adds grain): **as fast as a photo without grain**, with every other setting. | Camera-tested (v0.25) |
| **Saved on the card** | Your changes save to `OM3MOD` on the SD card at the next half-press, written to a new file and read back before the old one is replaced. | Camera-tested |
| **Control Panel** | The Caduceus Control Panel for the OM-3 (it began as Caduceus for the E-P7's tool; since 2026-11-09 it is OM-3 only). It makes and previews your FILM 1–20 on test photos (or your own), starting from the 20 film sims (61 to choose from), then saves them for the card. | Works in any browser |

## Install

You need: an OM-3 on firmware **1.1** (check *Setup › Firmware*), a **fully charged battery**, an SD card, and a
computer with [Python 3.8+](https://www.python.org/downloads/) (Windows, macOS or Linux; a Mac offers to install it).

### 1. Get Caduceus for OM-3

On this page click **Code › Download ZIP** and unzip it (or `git clone` the repo).

### 2. Make the update file on your computer

OM's licence doesn't allow anyone to share their firmware, so the update file is made on your own computer from OM's
official OM-3 1.1 firmware (`OLY_E_147_1100_0000_0000.BIN`, or `…_3.BIN` from an earlier download). The patcher checks it byte for byte, applies the
Caduceus for OM-3 changes and checks the result.

- **Easiest:** in the unzipped folder, double-click the launcher for your system:
  - macOS: `Make SD card files (Mac).command` (the first time: right-click › **Open**)
  - Windows: `Make SD card files (Windows).bat`
- **Or from a terminal** in that folder: `python3 firmware/patch.py` (Windows: `py firmware\patch.py`).

If the official file is in the folder or in Downloads, the patcher uses it; otherwise it asks OM's update server for
it. It refuses any other file or firmware version. It makes the newest version; press Return, or type an older
version (for example `v0.16`) to go back to it. Every version is in [releases](releases/README.md). It creates a folder **`SD card files`** with:

```
DCOLYMP/E1479999.BIN   the patched firmware update      → goes on the SD card
OM3MOD/                GUIDES.BIN (page labels + Extras code), LABELS.BIN and TONES.BIN; your edits and looks are saved here → goes on the SD card
restore/E1479999.BIN   the original OM firmware 1.1     → keep on your computer (to undo Caduceus for OM-3)
```

### 3. Copy to the SD card

Put the camera's SD card in your computer and copy the **`DCOLYMP`** and **`OM3MOD`** folders to the top level of
the card (next to the `DCIM` folder). Eject the card properly.

### 4. Flash the camera

1. Put the card in the camera. **Battery fully charged**, camera **off**.
2. **Hold the OK button** and switch the camera **on**. Keep holding OK until the update starts.
3. The light stays **steady** while the update is written (about two minutes). **Do not switch off, open the battery
   door or remove the card.**
4. When the light starts **blinking**, it's finished. Switch the camera off.
5. Switch it on normally.
6. On a computer, delete `DCOLYMP/E1479999.BIN` from the card. Keep `OM3MOD`: that's where your edits and looks
   live.

### 5. Shoot

Switch on (your films and settings load from the card by themselves; before v0.26.2: half-press the shutter once
first), then open Picture
Mode: your films follow COLOR 1–4 in the list. See [Using it](#using-it).

### Go back to an earlier version

Run the launcher again and type the version you want (see [releases](releases/README.md)), then copy `DCOLYMP` to
the card and flash as in step 4. Keep `OM3MOD`: every version reads your `LOOKS.BIN` and `BUNDLES.BIN`. Always copy
the release's own `GUIDES.BIN` (and from v0.20 `LABELS.BIN`) with its firmware: from v0.20 `GUIDES.BIN` carries code
built for that exact firmware. Coming from v0.16–v0.18, rename your `PROFILES.BIN` to `LOOKS.BIN` (same format; v0.19
did this by itself, v0.20 no longer does).

### Undo / go back to stock

Copy `restore/E1479999.BIN` from your computer to the card's `DCOLYMP` folder (replacing the patched one) and flash
it exactly as in step 4. The camera is then completely stock 1.1 again.

More detail, troubleshooting and FAQ: **[docs/INSTALL.md](docs/INSTALL.md)**.

## Make your own looks: the Control Panel

The **[Caduceus Control Panel](https://androidfanman.github.io/caduceus-om3/)** is where you make and edit your
films (the creative profiles the camera lists as FILM 1–20) in your browser:

1. **The list on the left is FILM 1–20**, in the same order as on the camera. Click a film to edit it. Drag a film to
   another place, or use ↑ ↓; × empties a place (empty places are left out of the camera's list and the films after
   them move up a number).
2. **Start from the 20 film sims.** The first time you open it, the list holds the 20 films below. Already used it
   before? **New › Reset looks to standard** puts the 20 back (Undo brings your old list back).
3. **Film sims** opens all 61 film looks: **The 20** first, in FILM order, then more under "More" (other slide and
   negative films, Fujifilm-style simulations, instant films and cinema print stocks). Click one to preview it on your
   photo; **+ Add** puts it in an empty place (or offers to replace one when all 20 are used).
4. **Edit** a film, laid out like the camera's Picture Mode screen: the HSL wheel with the camera's five pages (Color,
   Hue, Luminance, Shadows, Highlights; drag a colour on the wheel or use the slider), the Highlight & Shadow curve
   (drag its handles), the WB grid (click or drag) and the rows below. In short: Hue, Lightness and Saturation for each of the 12 colours; the tone (Highlights, Shadows,
   Midtones, Blacks, Whites); the camera's Contrast and Shading; the WB shift (A-B / G-M); and the Extras (Noise
   Filter, lens vignette correction, Grain, Sharp, Glow ↔ Clarity). The preview on the test photos (or your own: drag
   the line on the photo to compare before and after) shows grain, glow and clarity; Noise Filter and the lens
   correction are not previewed. Art Effects are not used from v0.25. **Split toning** (two wheels, Shadows and Highlights)
   shows in the preview too.
5. **Export › Save to card…** (Chrome or Edge on a computer) writes `OM3MOD/LOOKS.BIN` (and `NAMES.BIN`) straight
   onto the card; **Card folder (.zip)** downloads them. Keep **Firmware on the camera: v0.26.1 or later** (it saves split toning and WB past ±5).
6. On the camera: switch on, and your films are FILM 1–20 in Picture Mode. A film you changed in the
   Control Panel starts as built on the camera; the others keep the changes you made on the camera.

More:
- **Lists** keep whole sets of 20 films under a name, like playlists: **Save as…** stores the current set, the **List**
  menu switches between them, **Rename** / **Delete** manage them. Lists stay in this browser; export one to put it on
  the card.
- **Open…** the card's `OM3MOD/LOOKS.BIN` to edit the films on your card, then save them back.
- **Share looks** / **Share** make a link to all your films or to one; **Paste link** opens one.
- **From the built-in library** (on an empty place) adds one of the starter looks from Caduceus for the E-P7, converted
  for the OM-3. E-P7 files, packs and look codes are no longer opened (the E-P7 side of the tool was removed
  2026-11-09: use cakelesscoder's own tool for the E-P7).

Your work stays in the browser (nothing is uploaded). The preview is an approximation of the camera, good for
direction and strength: judge the final look in live view. On a Mac, Safari's **File › Add to Dock** makes the Control
Panel an app.

### The 20 film sims

Our own looks, designed from what each film is known for and made only of the camera's settings. None uses grain,
Glow / Clarity or an Art Effect, so you can add those yourself. The names describe what inspired each look; they
aren't the film makers' products or presets. This is the standard set, in camera order (also in the release as
an optional `LOOKS.BIN`; from v0.26 ten of them carry a light split tone, and v0.26.1 has them tuned from
colour-checker photos):

| FILM | Name | The look |
|---|---|---|
| 1 | Portra 400 | Warm, soft contrast, natural skin, bright and airy |
| 2 | Gold 200 | Warm and golden, rich yellows |
| 3 | Kodachrome 64 | Deep reds, golden yellows, dark rich blues, dense shadows |
| 4 | Portra 800 | Warmer and richer than Portra 400 |
| 5 | CineStill 800T | Cool, teal-leaning night look with warm skin and strong reds |
| 6 | Ektar 100 | Saturated and punchy, bold reds, clean blues |
| 7 | Ultramax 400 | Warm, saturated, punchy |
| 8 | Pro 400H | Soft pastels, airy highlights, minty greens, cyan skies |
| 9 | Velvia 50 | Very saturated landscape slide, deep blues, lush greens |
| 10 | Superia 400 | Green-leaning, cyan skies, snappy |
| 11 | ColorPlus 200 | Warm, yellow-golden, softer and more muted than Gold |
| 12 | CineStill 400D | Soft, warm daylight, pastel colour |
| 13 | Fuji C200 | Cool greens and blues, clear and airy |
| 14 | Ektachrome E100 | Clean, neutral slide colour, crisp, clear blues |
| 15 | Reala 100 | Natural, accurate colour |
| 16 | Provia 100F | Accurate slide colour, clean skies, crisp |
| 17 | Vision3 250D | Natural, very soft daylight cinema look, open shadows |
| 18 | Fuji Eterna | Muted, understated cinema look, soft contrast |
| 19 | Astia 100F | Soft slide film for people, gentle contrast |
| 20 | Agfa Ultra 100 | Extremely saturated, bold reds and blues |

## Using it

**On the card** (`OM3MOD` at the card's top level):

```
OM3MOD/LOOKS.BIN      your films FILM 1–20, with their names (from the Control Panel or the release)
OM3MOD/EDITS.BIN      the changes you made on the camera, per film and per COLOR (the camera writes it)
OM3MOD/BUNDLES.BIN    the wheels' current values (the camera writes it; .NEW and .BAK are its safety copies)
OM3MOD/GUIDES.BIN     the labels under the wheel + Caduceus code (from the release, with its firmware)
OM3MOD/LABELS.BIN     labels (from the release)
OM3MOD/TONES.BIN      the split toning pages' guides (from the release, v0.26)
OM3MOD/NAMES.BIN      name pictures for v0.17–v0.22 (not needed from v0.24; harmless)
```

**Every time you switch on:** your films and changes load from the card by themselves a moment after the camera
starts (v0.26.2; a half-press or OK loads them too). Before v0.26.2: half-press the shutter once first.

**Choosing a film:** Picture Mode › the COLOR position. The top row lists **COLOR 1–4, then FILM 1–20**: turn to a
film and its name shows as the big title; the quick menu, the shooting screen and the viewfinder show it from then on.
The camera remembers the film you were on over power off. (Behind the scenes FILM 1–5 use COLOR 1, FILM 6–10 COLOR 2,
and so on.)

**The rows** under Picture Mode: **HSL** (the colour wheel), Contrast, Highlight & Shadow, **Blk** (Blacks), **Wht**
(Whites), **WB** (the WB shift: the small grid shows where it is and the numbers sit under WB±, like "A2.G1"; press
**OK**, left / right or turn a dial to open the camera's own WB fine-tune screen, then MENU or OK to come back),
Sharpness (Sharp, −5 = Off .. +2), **Noise Filter** (Off / Low / Std / High), **Vignette Correction** (Off = natural
corners, On = the camera's correction), **Shading**, **Glow** (+1..+5 Glow, a soft glow; −1..−5 Clarity, local
contrast) and **Film Grain** (Off / Low / Med / High). They change the film or COLOR you're on, and the photo straight
away. Picture Mode always opens on the top row.

**The HSL wheel:** on the HSL row press **INFO**. INFO goes **Color** (the camera's saturation, one colour) → **Color
All** → **Hue** → **Luminance** → Color. The front dial picks the colour, the rear dial the value. Colours run
clockwise from Yellow at 12 o'clock: Yellow, Orange, Orange-red, Red, Magenta, Violet, Blue, Blue-cyan, Cyan,
Green-cyan, Green, Yellow-green. Hue + turns a colour toward its clockwise neighbour (Yellow → Orange); Luminance
makes it brighter or darker (−5..+5).

**Your changes are kept:** change anything on a film (or on COLOR 1–4) and it stays when you switch to another film
and back, and over power off. The camera keeps the changes in `EDITS.BIN` (saved at the next half-press); the film as built stays as it is
in `LOOKS.BIN`.

**Hold OK:**
- **On a film in the list** (or on the HSL wheel of a film): the film goes back to how it was built.
- **On COLOR n:** the whole COLOR goes back to the camera's factory settings.

A **`*`** means changed: after COLOR n, something differs from the factory settings; after FILM n, something differs
from how the film was built. Rows show their own `*` too.

**Grain:** grain is added by the camera's image processor while it develops the photo, in colour, at no extra time,
with every other setting.

**Quick answers**
- *No films in the list?* Check `OM3MOD/LOOKS.BIN` is on the card.
- *Settings change but nothing happens in the photo?* The card's `GUIDES.BIN` must come from the same release as the
  firmware. Copy the release's `GUIDES.BIN` again.
- *The camera freezes or switches off after a photo?* Take the battery out for a few seconds. Check that the firmware
  and `OM3MOD/GUIDES.BIN` come from the same release (the launcher's `SD card files` folder has both; `VERSION.txt` in
  it says which). If it keeps happening, turn Film Grain off on that film and
  [report it](https://github.com/androidfanman/caduceus-om3/issues) with your `OM3MOD` files.
- *My changes were lost?* They save at the next half-press, and only when the card has an `OM3MOD` folder.
- *New films from the Control Panel?* Export `LOOKS.BIN` (choose "v0.26.1 or later") and copy it to `OM3MOD`. A film
  you changed in the Control Panel starts again as built; the others keep your camera changes. Deleting `EDITS.BIN`
  puts every film back as built.
- *Monochrome?* Not supported: the MONO profiles keep the camera's own editor.
- *Want stock back for good?* Flash the restore file (see [Undo](#undo--go-back-to-stock)).

More: [docs/USING.md](docs/USING.md). Card file formats: [docs/FORMATS.md](docs/FORMATS.md).

## Safety

- **No responsibility is accepted for damage of any kind.** You flash this at your own risk. This is
  early-development software: expect bugs.
- Only the OM-3 on firmware **1.1** is supported. The patcher refuses any other firmware file, and checks its result
  against the expected checksum before writing it.
- The camera's SD updater (hold **OK** while switching on, file at `DCOLYMP/E1479999.BIN`) is confirmed working on
  the OM-3: steady light while writing, then blinking when done. Every test build has been flashed through it, one
  over another, and the official file goes on the same way.
- A full battery and an uninterrupted write are essential. A failed write can leave the camera unbootable.
- Keep the restore file the patcher makes (`restore/E1479999.BIN`). Flashing it returns the camera completely to
  stock 1.1.
- If something misbehaves: remove the `OM3MOD` folder from the card first (your settings are in it: copy it to your
  computer). If that doesn't help, flash the restore file.

## For developers

- `firmware/src/editor.s`, `editor.ld`: the patch source (MN10300 / AM33 assembly). `firmware/src/xblock.s`: the
  Extras code block (relocatable, appended to `GUIDES.BIN` and loaded from the card at power-on, from v0.26.2).
- `firmware/frames.py`: the white Frame layers (our own JPEGs, written into the resource component).
- `firmware/build.py`: builds the update file from source (needs binutils built for `--target=mn10300-elf`):
  `python3 firmware/build.py --stock OLY_E_147_1100_0000_0000_3.BIN --toolchain BINUTILS_BUILD --out NEW_DIR`.
- `firmware/patch.py` + `releases/vX/patch.json`: the user-side patcher (pure Python) and each release's prebuilt patch (only
  the bytes this project writes).
- `card/`: generators for `GUIDES.BIN` (page labels), `LABELS.BIN` (Extras labels) and `LOOKS.BIN`.
- `tools/mkpatch.py`: makes a release's `patch.json` from a build.
- `webapp/`: the Caduceus Control Panel source (TypeScript + Vite, started from cakelesscoder/caduceus-ep7's tool;
  OM-3 only since 2026-11-09; see [webapp/README.md](webapp/README.md)). `looklab/` is its build, served by GitHub Pages
  (`VITE_DEFAULT_CAMERA=om3 npm run build`, then copy `dist/` to `looklab/`).
- `tools/emulator/`: test harness for [om-emu](https://github.com/flatpanda/om-emu) (E147 model).
- [docs/DEVELOPER_NOTES.md](docs/DEVELOPER_NOTES.md): addresses, hooks and the test history.
- [research/](research/README.md): the full lab notebook (`research/NOTES.md`: every address, test and dead end),
  firmware and emulator tools, and archived experiments.
- [docs/FILM_SIMULATION_ROADMAP.md](docs/FILM_SIMULATION_ROADMAP.md): planned film-look features, effort and status.
- [CLAUDE.md](CLAUDE.md): working rules for AI-assisted sessions on this repo (useful for any contributor).

## Credits

Built on **[Caduceus](https://github.com/cakelesscoder/caduceus-ep7)** by cakelesscoder (Apache-2.0), firmware patches
for the Olympus PEN E-P7: the on-camera editor design, the bundle-table layout, the Caduceus Control Panel this tool started from, its tone
model and the starter film looks. Loading the films at power-on (no half-press) and the fix for bad bytes in `EDITS.BIN` come from **[fernandezk26](https://github.com/fernandezk26/camera-stuff)**'s fork (v0.26.2). Sample photos are public domain (CC0), except the sunset by Joonas Lyytinen (CC BY 2.0); see [webapp/public/samples/CREDITS.md](webapp/public/samples/CREDITS.md). Camera emulation by
[om-emu](https://github.com/flatpanda/om-emu).

"OM SYSTEM", "Olympus" and "OM-3" are trademarks of their owners, as are the film names used for the starter looks.
Not affiliated with OM Digital Solutions, Fujifilm or Kodak.

## License

[Apache License 2.0](LICENSE). See [NOTICE](NOTICE).
