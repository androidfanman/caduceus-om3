<h1 align="center">Caduceus for OM-3</h1>

<p align="center"><strong>Film looks and a color editor, built into the OM SYSTEM OM-3.</strong></p>

<p align="center">
  <a href="https://github.com/androidfanman/caduceus-om3/releases/latest"><b>Download</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/"><b>Tour</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/pages/changelog/"><b>Changelog</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/pages/install/"><b>Install</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/pages/using/"><b>Using it</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/looklab/"><b>LookLab</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/pages/faq/"><b>FAQ</b></a> &nbsp;·&nbsp;
  <a href="https://androidfanman.github.io/caduceus-om3/pages/roadmap/"><b>Roadmap</b></a> &nbsp;·&nbsp;
  <a href="https://github.com/androidfanman/caduceus-om3/tree/main/devkit/photo-code"><b>Developers</b></a> &nbsp;·&nbsp;
  <a href="https://discord.gg/fKpcKGsNPY"><b>Discord</b></a>
</p>

<p align="center">
  Latest: <b>v0.40.3</b> (2026-11-23)
</p>

## What it does

**[Take the tour](https://androidfanman.github.io/caduceus-om3/)** to see the films and every setting on the camera's own screens, with before and after
photos.

- **Your films in Picture Mode:** FILM 1–20 come after COLOR 1–4, each with its own name. Caduceus comes with 20 film
  sims.
- **A color editor on the camera:** Color Mix, RGB curves, and hue, saturation, and brightness for 12 colors. Also
  split toning, Blacks and Whites, WB compensation, Sharpness, Noise Filter, Shading, Glow / Clarity, Halation, Film
  Grain, and Border.
- **Looks in live view:** you see each change while you make it.
- **Crop modes:** XPan (65:24), 21:9, and 5:4, with frame lines in live view.
- **Make films on your computer** in [LookLab](https://androidfanman.github.io/caduceus-om3/looklab/), with a preview. Copy one file (`LOOKS.BIN`) to the card,
  and the camera takes the films it doesn't have yet.
- **Your films live in the camera:** the camera keeps the films, your changes, and the Extras settings in its own
  memory. Any SD card works, even a blank one, or no card at all.
- **Custom modes:** C1–C5 each keep their own films and settings.
- **Your buttons and Creative Dial:** all four arrow keys and the Delete button take a function in Button Function.
  Each Creative Dial position can be CRT, ART, COLOR, or MONO, with its own film.
- **Your choice of screen info:** you pick which items the shooting screen shows.
- **The film in every photo:** each JPEG's EXIF holds the film's name and recipe. LookLab, or a recipe site with the
  [developer kit](devkit/photo-code/), can open the film from the photo. Playback shows each photo's own film.

Open-source firmware patches for the OM-3 on firmware 1.1, part of the
[Caduceus](https://github.com/cakelesscoder/caduceus-ep7) family.

> [!CAUTION]
> ### ⚠️ Experimental firmware: use at your own risk
> This is an **unofficial change to your camera's firmware**. It can **crash or freeze the camera**, and **no
> responsibility is accepted for any damage or data loss**. It may affect your warranty with OM Digital Solutions.
>
> You can always go back to the camera's own firmware. Read [Safety](#safety) before you install.

## Install

About 15 minutes. **[Step-by-step install guide](https://androidfanman.github.io/caduceus-om3/pages/install/)**. In short:

1. **Check** that the camera is an OM-3 on firmware **1.1** (*Setup › Firmware*), with a fully charged battery.
2. **Download** this project (**Code › Download ZIP**) and unzip it.
3. **Make the update file.** Double-click `Make SD card files (Mac).command` or `Make SD card files (Windows).bat`.
   It gets OM's official firmware from OM's server and adds Caduceus to it.
4. **Copy** the `DCOLYMP` folder to the top of the SD card.
5. **Add the films.** Download `LOOKS.BIN` and `CURVES.BIN` from the
   [latest release](https://github.com/androidfanman/caduceus-om3/releases/latest). Put both in a folder named `OM3MOD`
   on the card. Updating from v0.30 or later? Your films stay in the camera, so skip this step.
6. **Update the camera.** With the camera off, **hold OK** and switch on. A steady light means the camera is writing.
   That takes up to about five minutes, so don't touch anything. A blinking light means it is done.

To undo, [go back to the camera's own firmware](https://androidfanman.github.io/caduceus-om3/pages/install/#going-back-to-the-cameras-own-firmware). For
problems, see [if something goes wrong](https://androidfanman.github.io/caduceus-om3/pages/install/#if-something-goes-wrong).

**Reporting a problem?** Send a debug log. Put
[`DEBUG.TXT`](https://github.com/androidfanman/caduceus-om3/releases/latest/download/DEBUG.TXT) in the card's `OM3MOD`
folder and use the camera until the problem happens. Then attach the `OM3MOD/CADLOG.TXT` file it writes.
[How, step by step](debug-log/).

## Using it

**[How to use it on the camera](https://androidfanman.github.io/caduceus-om3/pages/using/)**. In short:

- Switch on, and your films are ready. Turn the Creative Dial to **COLOR** and open **Picture Mode**. Your films,
  **FILM 1–20**, come after COLOR 1–4.
- The rows below the film change it at once: Color Mix, RGB, the color wheel (HSL), Split Tone Balance, WB
  Compensation, Highlight & Shadow, B/W, Contrast, Sharpness, Noise Filter, Vignette Correction, Shading, Glow,
  Halation, Halation Radius, Film Grain, Grain Size, and Border.
- Each film keeps your changes, also over power off. **Hold OK** on a film to put it back the way it was built.
- Caduceus works on COLOR 1–4 and the films. The Monochrome profiles keep the camera's own settings.

## LookLab

**[LookLab](https://androidfanman.github.io/caduceus-om3/looklab/)** is a web page where you make and change your films, with a preview on sample photos or
your own. It starts with the 20 film sims and has 67 film looks to choose from. Save your films as `LOOKS.BIN` and copy
the file to the card's `OM3MOD` folder. LookLab uploads nothing, so your work stays in your browser.
**[How to use LookLab](docs/CONTROL_PANEL.md)**.

## The 20 film sims

These are our own looks. Each one comes from what its film is known for and uses only settings on the camera. None
uses grain or Glow, so you can add those yourself. The names say what inspired each look. They aren't the film makers'
products or presets. The set is 18 color-matched films plus CineStill 800T and Kodachrome 64, in camera order:

| FILM | Name | The look |
|---|---|---|
| 1 | Portra 400 | Warm, soft contrast, natural skin, bright and airy |
| 2 | Portra 160 | The finest Portra: gentle, natural color and skin, low contrast |
| 3 | Portra 800 | Warmer and richer than Portra 400 |
| 4 | Gold 200 | Warm and golden, rich yellows |
| 5 | ColorPlus 200 | Warm, yellow-golden, softer and more muted than Gold |
| 6 | Ektar 100 | Saturated and punchy, bold reds, clean blues |
| 7 | Ektachrome E100 | Clean, neutral slide color, crisp, clear blues |
| 8 | Kodachrome 64 | Deep reds, golden yellows, dark rich blues, dense shadows |
| 9 | CineStill 800T | Cool, teal-leaning night look with warm skin and strong reds |
| 10 | Velvia 50 | Very saturated landscape slide, deep blues, lush greens |
| 11 | Provia 100F | Accurate slide color, clean skies, crisp |
| 12 | Pro 400H | Soft pastels, airy highlights, minty greens, cyan skies |
| 13 | Pro 160S | Natural portrait color, smooth skin, clean greens |
| 14 | NPS 160 | Soft studio portrait film, gentle skin, cool greens |
| 15 | NHG II 800 | Fast pro film, natural skin, clear greens, deep cool blues |
| 16 | Superia 400 | Green-leaning, cyan skies, snappy |
| 17 | Fuji C200 | Cool greens and blues, clear and airy |
| 18 | Fujifilm 200 | Close to Gold but softer, slightly warm |
| 19 | Fujifilm 400 | Warm and punchy, bright reds, golden yellows |
| 20 | Natura 1600 | Fast, clean and slightly cool, lively reds, soft blacks |

## Safety

- Caduceus supports only the OM-3 on firmware **1.1**. The launcher refuses any other firmware file. It also checks
  its result against the expected checksum before it writes the file.
- Every change runs in an emulator of the camera before it goes on a camera. The camera's SD update (hold **OK** while
  you switch on) is proven on the OM-3, both for Caduceus and for going back to the official firmware.
- Use a full battery and don't interrupt the update. A failed write can leave the camera unable to start.
- Keep the restore file that the launcher makes (`restore/E1479999.BIN`). Flash it to put the camera back to stock 1.1.
- If something misbehaves, copy the card's `OM3MOD` folder to your computer, delete it from the card, and try again.
  Your films are in the camera, so you don't lose them. If that doesn't help, flash the restore file.

## Other cameras

Caduceus for OM-3 works only on the **OM-3 with firmware 1.1**. I get asked about other cameras a lot, so here is
why that's hard, and why it isn't something I can do.

- **Every camera and every firmware version is different inside.** Caduceus changes the OM-3's firmware at several
  hundred exact places: where the menus are drawn, where the color settings are read, where the photo is developed.
  None of those places are the same on another model, or even on another firmware version of the OM-3. A port to
  another camera means finding all of them again, from scratch.
- **It starts from OM's own firmware update.** The launcher takes the official update file that OM SYSTEM
  publishes, adds Caduceus's changes and makes a new update for the card. A camera that has never had a firmware
  update has no such file to start from.
- **It has to be tested on the real camera.** Every change runs in an emulator of the OM-3 first, but nothing is
  released until it has worked on a real OM-3. A firmware change that goes wrong can freeze a camera or stop it
  starting. I only own an OM-3, so I can't test, or safely release, anything for other cameras.
- **It's a lot of work.** The OM-3 version took many rounds of test builds on the camera for each feature, and every
  model would need the same again.

**The new OM SYSTEM PEN (2026):** it has the same name and look as the PEN line, but inside it is a different camera
from both the OM-3 and the older PEN E-P7 (a different image processor, TruePic IX instead of the OM-3's TruePic X).
As far as we know, OM SYSTEM hasn't published a firmware update for it yet, so there is no firmware file to start a
port from. Even when one comes out, it would be a new port, done by someone who owns the camera.

**Other options:**
- **PEN E-P7:** there's a sister project, [Caduceus for the E-P7](https://github.com/cakelesscoder/caduceus-ep7), by
  cakelesscoder. Caduceus for OM-3 grew out of it.
- **Want to port it yourself?** If you own another OM SYSTEM or Olympus camera and are comfortable with low-level
  work, the research notes ([`research/NOTES.md`](research/NOTES.md)), the tools and the emulator setup here are a
  good starting point. Say hello on [Discord](https://discord.gg/fKpcKGsNPY) or in a GitHub issue.

Please don't flash an OM-3 file on any other camera. The launcher refuses other firmware files, and a wrong file can
stop a camera from starting.

## For developers

- `firmware/src/editor.s`, `editor.ld`: the patch source (MN10300 / AM33 assembly).
- `firmware/src/xblock.s`: the Extras code block, appended to `GUIDES.BIN`. The firmware has `GUIDES.BIN`,
  `LABELS.BIN`, and `TONES.BIN` built in, and the films live in the camera's settings memory
  ([docs/FORMATS.md](docs/FORMATS.md)).
- `firmware/frames.py`: the white Frame layers (our own JPEGs, written into the resource component).
- `firmware/build.py`: builds the update file from source. It needs binutils built for `--target=mn10300-elf`.
  Run `python3 firmware/build.py --stock OLY_E_147_1100_0000_0000.BIN --toolchain BINUTILS_BUILD --out NEW_DIR`.
- `firmware/patch.py` and `releases/vX/patch.json`: the user-side patcher (pure Python) and each release's prebuilt
  patch. A patch holds only the bytes this project writes.
- `card/`: makers for `GUIDES.BIN` (page labels), `LABELS.BIN` (Extras labels), `LOOKS.BIN` (films), and `CURVES.BIN`
  (Color Mix and RGB curves).
- `tools/mkpatch.py`: makes a release's `patch.json` from a build.
- `webapp/`: the LookLab source, in TypeScript and Vite ([webapp/README.md](webapp/README.md)). It started from
  cakelesscoder's tool. `looklab/` is its build, which GitHub Pages serves. To rebuild it, run `npm run build` in
  `webapp/`, then copy `webapp/dist/` to `looklab/`.
- `tools/emulator/`: test harness for [om-emu](https://github.com/flatpanda/om-emu) (E147 model).
  [research/TESTING.md](research/TESTING.md) describes the emulator test suite.
- [docs/DEVELOPER_NOTES.md](docs/DEVELOPER_NOTES.md): addresses, hooks, and the test history.
- [research/](research/README.md): the lab notebook (`research/NOTES.md` has every address, test, and dead end),
  firmware and emulator tools, and old experiments.
- [docs/FILM_SIMULATION_ROADMAP.md](docs/FILM_SIMULATION_ROADMAP.md) and [ROADMAP.md](ROADMAP.md): plans and status,
  shown on the [roadmap page](https://androidfanman.github.io/caduceus-om3/pages/roadmap/).
- `pages/`: the guide pages on GitHub Pages, with shared style in `pages/site/`. They show `docs/INSTALL.md`,
  `docs/USING.md`, `docs/FAQ.md`, `ROADMAP.md`, and `CHANGELOG.md`, so edit those files, not the pages.
- [CLAUDE.md](CLAUDE.md): working rules for AI-assisted sessions on this repo, useful for any contributor.

## Credits

Built on **[Caduceus](https://github.com/cakelesscoder/caduceus-ep7)** by cakelesscoder (Apache-2.0), firmware patches
for the Olympus PEN E-P7. From it came the on-camera editor design, the bundle-table layout, the LookLab this tool
started from, its tone model, and the starter film looks.

Sample photos are public domain (CC0), except the sunset by Joonas Lyytinen (CC BY 2.0). See
[webapp/public/samples/CREDITS.md](webapp/public/samples/CREDITS.md). Camera emulation by
[om-emu](https://github.com/flatpanda/om-emu).

"OM SYSTEM", "Olympus" and "OM-3" are trademarks of their owners, as are the film names used for the starter looks.
Not affiliated with OM Digital Solutions, Fujifilm or Kodak.

## License

[Apache License 2.0](LICENSE). See [NOTICE](NOTICE).
