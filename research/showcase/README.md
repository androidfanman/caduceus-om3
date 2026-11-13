# The tour page's pictures (`pages/showcase/`)

`make.sh` makes every picture of [the tour](../../pages/showcase/) from scratch (about three minutes) and writes them
to `pages/showcase/img/`. It needs the workspace (`research/setup.sh`, then `. ~/om3-work/env.sh`) and
`cd webapp && npm install`. Run it again when the films, the firmware's screens or the preview change.

```
IMG=$OM3_WORK/out-NAME/main.bin research/showcase/make.sh     # IMG defaults to the latest release's build
```

| Folder | What | How it's made | Status |
|---|---|---|---|
| `img/screens/` | The camera's screens | om-emu runs the firmware (`shoot.sh`, driving `tools/emulator/session_ed1.mjs`) on a blank card with the standard 20 `LOOKS.BIN`; v0.29 needs nothing else on the card | Emulator, the firmware's own drawing |
| `img/screens/hsl-*.png` | The five colour-wheel pages | As above, then `wheel.py` draws the wheel (om-emu doesn't) from the values on the screen, in the Control Panel's style (`webapp/src/main.ts` `hslPanel`), and puts our own guide picture (`card/mkguides.py`) in the box om-emu leaves blank | Approximation: the page says so |
| `img/films/` | The standard 20 films on four samples (`-00` = original) | `mklooks.ts` (the Control Panel's standard 20, also the card's `LOOKS.BIN`), `films.ts` (`webapp/src/preview.ts`) | Control Panel preview |
| `img/demos/` | A before / after photo per setting | `demos.ts`: a neutral look with only that setting changed, at the value the screen shows | Control Panel preview; Noise Filter and Vignette Correction are illustrations (`illus.py`), the preview doesn't model them |
| `img/halation/` | CineStill 800T, Halation 0 and 5 | `films.ts` | Control Panel preview |

Samples: `webapp/public/samples/` (public domain / CC0, credited on the page and in `CREDITS.md`).

**Emulator keys** (`shoot.sh NAME 'tokens'`): `s1 ok ok` opens Picture Mode on COLOR 1; `right` steps COLOR 1–4, then
FILM 1–20; `down` steps the rows (HSL, Tone Balance, Contrast, Highlight & Shadow, B/W, WB, Sharpness, Noise Filter,
Vignette Correction, Shading, Glow, Halation, Film Grain); `main±1` / `sub±1` change a value (which way is + differs per
row; on the wheel one token is one step, whatever its number); `ok` on B/W or WB opens the grid, arrows move it. On the
wheel `info` steps Color → Color All → Hue → Luminance → Shadows → Highlights, `sub-1` moves to the next colour
clockwise from Yellow (`sub+1` from Yellow goes to ALL first). After leaving Picture Mode, `ok` opens the super
control panel. om-emu's raw shots hold Y / Cb / Cr bytes: `ycc2rgb.py` converts them as om-emu's PNG writer does.

Not on the page yet: the Button Function and Creative Dial menus (not tried in the emulator).
