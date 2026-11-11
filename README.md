# Caduceus for OM-3

**Caduceus for OM-3** is the OM SYSTEM OM-3 member of the [Caduceus](https://github.com/cakelesscoder/caduceus-ep7)
family, made together with cakelesscoder: open-source firmware patches for the **OM SYSTEM OM-3** (firmware 1.1). It puts
**your films in the camera's Picture Mode list** (FILM 1–20 after COLOR 1–4, each with its name; 20 film sims come
with it), turns the Color Profile wheel into a colour editor (per-colour Hue and Luminance next to the camera's
Saturation), and adds the look's settings to the camera's own Picture Mode screen: Blacks, Whites, a WB grid, Sharp,
Noise Filter, lens vignette correction, Shading, Glow / Clarity and fast colour film grain. Films are made in the browser with the **Caduceus Control
Panel**; changes you make on the camera are kept per film.

**Latest: v0.26.2** ([changelog](CHANGELOG.md)) · **▶ [Control Panel](https://androidfanman.github.io/caduceus-om3/)** · **[Install guide](https://androidfanman.github.io/caduceus-om3/install/)** ·
**[Using it](https://androidfanman.github.io/caduceus-om3/using/)** · **[Roadmap](https://androidfanman.github.io/caduceus-om3/roadmap/)** · Caduceus for the E-P7: [cakelesscoder/caduceus-ep7](https://github.com/cakelesscoder/caduceus-ep7).

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

**[Step-by-step install guide](https://androidfanman.github.io/caduceus-om3/install/)** (about 15 minutes). In short:

1. **Check** the camera is an OM-3 on firmware **1.1** (*Setup › Firmware*), with a fully charged battery.
2. **Download** this project (**Code › Download ZIP**) and unzip it.
3. **Make the update file:** double-click `Make SD card files (Mac).command` or `Make SD card files (Windows).bat`.
   It gets OM's official firmware from OM's server and adds Caduceus to it.
4. **Copy** the `DCOLYMP` and `OM3MOD` folders to the top of the SD card, and the film sims (`LOOKS.BIN`, from the
   [latest release](https://github.com/androidfanman/caduceus-om3/releases/latest)) into `OM3MOD`.
5. **Update the camera:** camera off, **hold OK** and switch on. Steady light = writing (about two minutes, don't touch
   anything); blinking = done.

To undo, flash the original firmware the same way: see [going back](https://androidfanman.github.io/caduceus-om3/install/#going-back-to-the-cameras-own-firmware).
Problems: [if something goes wrong](https://androidfanman.github.io/caduceus-om3/install/#if-something-goes-wrong).

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

**[How to use it on the camera](https://androidfanman.github.io/caduceus-om3/using/)**. In short:

- Turn the creative dial to **COLOR** and open **Picture Mode**: after COLOR 1–4 you'll find your films, **FILM 1–20**.
- The rows below change the film at once: the colour wheel (HSL, with split toning), Contrast, Highlight & Shadow,
  Blacks / Whites, WB shift, Sharpness, Noise Filter, Vignette Correction, Shading, Glow and Film Grain.
- Your changes stay with each film, also over power off. **Hold OK** on a film to put it back as built.
- Make new films in the [Control Panel](https://androidfanman.github.io/caduceus-om3/) and copy its `LOOKS.BIN` to the card's `OM3MOD` folder.

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
