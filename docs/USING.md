# Using Caduceus for OM-3 on the camera (v0.26.2)

> **Color profiles only:** this is for Picture Mode COLOR 1–4. The Monochrome profiles keep the camera's own editor.
> For v0.20–v0.22 (Film page, Extras page on the wheel) see this page as it was at
> [v0.22](https://github.com/androidfanman/caduceus-om3/blob/v0.22/docs/USING.md).

**Your films and changes load from the card by themselves when the camera starts** (v0.26.2). On v0.26.1 and older,
half-press the shutter once after switching on.

## Films

Films are your creative profiles: up to 20, **FILM 1–20**, after COLOR 1–4. v0.25 comes with 20 film sims (Portra
400, Gold 200, Kodachrome 64, Portra 800, CineStill 800T, Ektar 100, Ultramax 400, Pro 400H, Velvia 50, Superia 400,
ColorPlus 200, CineStill 400D, Fuji C200, Ektachrome E100, Reala 100, Provia 100F, Vision3 250D, Fuji Eterna, Astia
100F, Agfa Ultra 100: what each looks like is in the [README](../README.md#the-20-film-sims)). Copy the release's
`LOOKS.BIN` to `OM3MOD`, or make and change films in the [Control Panel](https://androidfanman.github.io/caduceus-om3/)
(it starts with the same 20, in the same order) and export `LOOKS.BIN` with **Firmware on the camera: v0.26.1 or later**.

On the camera, Picture Mode › the COLOR position: the top row lists **COLOR 1–4, then FILM 1–20** (empty places
skipped). Turn to a film: its **name** is the big title; the quick menu, the shooting screen and the viewfinder show it
from then on. The camera remembers the film you were on over power off.

## Changing a film

Every row under Picture Mode changes the film (or the COLOR) you're on, at once:

| Row | What it does |
|---|---|
| **HSL** | The colour wheel (below) |
| Contrast, Highlight & Shadow | The camera's own |
| **Blk** / **Wht** | Blacks / Whites, −5..+5: + lifts / brightens, − crushes / softens |
| **WB** | The WB shift (A-B amber / blue, G-M green / magenta, −7..+7), in every WB mode (Auto WB included). The row shows a small grid with the dot where the shift is, and the numbers under WB± (like "A2.G1"). **OK**, left / right or a dial opens the camera's own WB fine-tune screen; MENU or OK comes back |
| Sharpness | Sharp: the camera's sharpening, −5 = Off, −4..−1 softer, 0 its normal, +1 / +2 crisper |
| **Noise Filter** | Off / Low / Std / High for photos with this film |
| **Vignette Correction** | Off = the lens's natural corners, On = the camera's correction |
| Shading | The camera's own (darker or lighter corners) |
| **Glow** | +1..+5 Glow (a soft glow), −1..−5 Clarity (local contrast), 0 off |
| **Film Grain** | Off / Low / Med / High: film grain on the colour photo |

Picture Mode always opens on the top row. There are no Art Effects from v0.25 (Shading does the dark corners).

**The HSL wheel:** on the HSL row press **INFO**. INFO goes **Color** (the camera's saturation, one colour at a time)
→ **Color All** → **Hue** → **Luminance** → **Shadows** → **Highlights** → Color. The front dial picks the colour, the rear dial the value. Colours
run clockwise from Yellow at 12 o'clock: Yellow, Orange, Orange-red, Red, Magenta, Violet, Blue, Blue-cyan, Cyan,
Green-cyan, Green, Yellow-green. **Hue** (−5..+5): + turns a colour toward its clockwise neighbour (Yellow → Orange,
Blue → Blue-cyan). **Luminance** (−5..+5): darker or brighter for that colour.

**Split toning (v0.26):** the **Shadows** and **Highlights** pages tint the dark or the bright parts of the photo
toward one colour. The front dial picks the colour on the wheel, the rear dial the strength (−5..+5; minus tints toward
the opposite colour, 0 = off). Live view shows it. Each page holds one colour at a time; set both for a classic split
tone (for example blue-cyan shadows with orange highlights). The guides on these pages come from `OM3MOD/TONES.BIN`.

Your changes stay with the film: switch to another film and back, or switch the camera off and on, and they're still
there. COLOR 1–4 keep their own
changes the same way. The camera keeps them in `OM3MOD/EDITS.BIN` (saved at the next half-press); `LOOKS.BIN` is never
changed by the camera.

## Resets and the `*`

- **Hold OK on a film** in the list (or on its HSL wheel): the film goes back to how it was built.
- **Hold OK on COLOR n:** the COLOR goes back to the camera's factory settings.
- A **`*`** after COLOR n: something differs from the factory settings. After FILM n: something differs from how the
  film was built. A row with its own `*` is one of the changed settings.

## Grain

Grain is added by the camera's image processor while it develops the photo (the way its Grainy Film Art Filter adds
grain), in colour and at no extra time, with every other setting.

## Card files

`LOOKS.BIN` (your films, from the Control Panel or the release), `EDITS.BIN` (your camera changes, written by the camera),
`BUNDLES.BIN` (written by the camera), `GUIDES.BIN`, `LABELS.BIN` and `TONES.BIN` (from the release, always with its
firmware).
`NAMES.BIN` is only used by v0.17–v0.22. Formats: [FORMATS.md](FORMATS.md).
