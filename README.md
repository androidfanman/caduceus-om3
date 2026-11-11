<h1 align="center">Caduceus for OM-3</h1>

<p align="center"><strong>Film looks and a colour editor, built into the OM SYSTEM OM-3.</strong></p>

<p align="center">
  <a href="https://github.com/androidfanman/caduceus-om3/releases/latest"><b>Download</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/pages/install/"><b>Install</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/pages/using/"><b>Using it</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/"><b>Control Panel</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/pages/faq/"><b>FAQ</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/pages/roadmap/"><b>Roadmap</b></a> &nbsp;&nbsp;
</p>

<p align="center">
  Latest: <b>v0.26.2</b> (2026-11-09)
</p>

## What it does

- **Your films in Picture Mode:** FILM 1–20 appear after COLOR 1–4, each with its own name. 20 film sims come with it.
- **A colour editor on the camera:** hue, saturation and brightness for 12 colours, split toning, Blacks and Whites,
  WB shift, Sharpness, Noise Filter, Shading, Glow / Clarity and Color Grain.
- **Make films on your computer** in the [Control Panel](https://androidfanman.github.io/caduceus-om3/), with a preview, then copy them to the card.
- **Your changes are kept** for each film, even when the camera is switched off.

Open-source firmware patches for the OM-3 on firmware 1.1, part of the
[Caduceus](https://github.com/cakelesscoder/caduceus-ep7) family with cakelesscoder.

> [!CAUTION]
> ### ⚠️ Experimental firmware: use at your own risk
> This is an **unofficial change to your camera's firmware**. It can **crash or freeze the camera**, and **no
> responsibility is accepted for any damage or data loss**. It may affect your warranty with OM Digital Solutions.
>
> You can always go back to the camera's own firmware. Read [Safety](#safety) before you install.

## Install

About 15 minutes. **[Step-by-step install guide](https://androidfanman.github.io/caduceus-om3/pages/install/)**. In short:

1. **Check** the camera is an OM-3 on firmware **1.1** (*Setup › Firmware*), with a fully charged battery.
2. **Download** this project (**Code › Download ZIP**) and unzip it.
3. **Make the update file:** double-click `Make SD card files (Mac).command` or `Make SD card files (Windows).bat`.
   It gets OM's official firmware from OM's server and adds Caduceus to it.
4. **Copy** the `DCOLYMP` and `OM3MOD` folders to the top of the SD card, and the film sims (`LOOKS.BIN`, from the
   [latest release](https://github.com/androidfanman/caduceus-om3/releases/latest)) into `OM3MOD`.
5. **Update the camera:** camera off, **hold OK** and switch on. Steady light = writing (about two minutes, don't touch
   anything); blinking = done.

To undo: [go back to the camera's own firmware](https://androidfanman.github.io/caduceus-om3/pages/install/#going-back-to-the-cameras-own-firmware). Problems:
[if something goes wrong](https://androidfanman.github.io/caduceus-om3/pages/install/#if-something-goes-wrong).

## Using it

**[How to use it on the camera](https://androidfanman.github.io/caduceus-om3/pages/using/)**. In short:

- Turn the creative dial to **COLOR** and open **Picture Mode**: after COLOR 1–4 you'll find your films, **FILM 1–20**.
- The rows below change the film at once: the colour wheel (HSL, with split toning), Contrast, Highlight & Shadow,
  Blacks / Whites, WB shift, Sharpness, Noise Filter, Vignette Correction, Shading, Glow and Film Grain.
- Your changes stay with each film, also over power off. **Hold OK** on a film to put it back as built.
- Caduceus works on COLOR 1–4 and the films. The Monochrome profiles keep the camera's own settings.

## The Control Panel

The **[Control Panel](https://androidfanman.github.io/caduceus-om3/)** is a web page for making and changing your films, with a preview on sample photos or
your own. It starts with the 20 film sims and has 61 film looks to choose from. Save your films as `LOOKS.BIN` and copy
it to the card's `OM3MOD` folder. Nothing is uploaded: your work stays in your browser.
**[How to use the Control Panel](docs/CONTROL_PANEL.md)**.

## The 20 film sims

Our own looks, designed from what each film is known for and made only from the camera's own settings. None uses
grain or Glow, so you can add those yourself. The names say what inspired each look; they aren't the film makers'
products or presets. In camera order:

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

## What's in it

Everything here is camera-tested on a real OM-3 unless it says otherwise.

| Feature | Since |
|---|---|
| Films FILM 1–20 in the Picture Mode list, with their names on the title, quick menu, shooting screen and viewfinder | v0.24.1 |
| Changes kept per film and per COLOR, over power off; **hold OK** to reset; `*` marks what's changed | v0.25 |
| Hue and Luminance for each of the 12 colours, next to the camera's Saturation | v0.11 |
| Picture Mode rows: Blacks / Whites, WB shift grid, Sharpness (−5 Off..+2), Noise Filter (incl. High), Vignette Correction, Shading, Glow / Clarity, Film Grain | v0.25 |
| Film grain in colour, from the camera's image processor: as fast as a photo without grain | v0.25 |
| Split toning: Shadows and Highlights pages, 12 colours, −5..+5, also in live view | v0.26 |
| WB shift up to ±7 per film | v0.26.1 |
| Films load at power-on; the super control panel's dials step through the films | v0.26.2 |

Coming next: see the [roadmap](https://androidfanman.github.io/caduceus-om3/pages/roadmap/).

## Safety

- Only the OM-3 on firmware **1.1** is supported. The launcher refuses any other firmware file, and checks its result
  against the expected checksum before writing it.
- Every change is tested in an emulator of the camera before it goes on a camera. The camera's SD update (hold
  **OK** while switching on) is proven on the OM-3, for Caduceus and for going back to the official firmware.
- Use a full battery and don't interrupt the update. A failed write can leave the camera unable to start.
- Keep the restore file the launcher makes (`restore/E1479999.BIN`): flashing it puts the camera back to stock 1.1.
- If something misbehaves, copy the card's `OM3MOD` folder to your computer (your films are in it), delete it from the
  card and try again. If that doesn't help, flash the restore file.

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
- [docs/FILM_SIMULATION_ROADMAP.md](docs/FILM_SIMULATION_ROADMAP.md) and [ROADMAP.md](ROADMAP.md) (shown as the [roadmap page](https://androidfanman.github.io/caduceus-om3/pages/roadmap/)): plans and status.
- `pages/`: the guide pages on GitHub Pages (install, using, faq, roadmap, changelog; shared style in `pages/site/`); they show `docs/INSTALL.md`, `docs/USING.md`, `docs/FAQ.md`, `ROADMAP.md` and `CHANGELOG.md`, so edit those files.
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
