# Using the Control Panel

The **[Caduceus Control Panel](https://androidfanman.github.io/caduceus-om3/)** is a web page where you make and change
your films (FILM 1–20 on the camera) on your computer, with a preview. Your work stays in your browser: nothing is
uploaded.

## Making and changing films

1. **The list on the left is FILM 1–20**, in the same order as on the camera. Click a film to edit it. Drag a film to
   another place, or use ↑ ↓; × empties a place (empty places are left out of the camera's list and the films after
   them move up a number).
2. **Start from the 20 film sims.** The first time you open it, the list holds the [20 film sims](../README.md#the-20-film-sims). Already used it
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

## More

- **Lists** keep whole sets of 20 films under a name, like playlists: **Save as…** stores the current set, the **List**
  menu switches between them, **Rename** / **Delete** manage them. Lists stay in this browser; export one to put it on
  the card.
- **Open…** the card's `OM3MOD/LOOKS.BIN` to edit the films on your card, then save them back.
- **Share looks** / **Share** make a link to all your films or to one; **Paste link** opens one.
- **From the built-in library** (on an empty place) adds one of the starter looks from Caduceus for the E-P7, converted
  for the OM-3. E-P7 files, packs and look codes are no longer opened (the E-P7 side of the tool was removed
  2026-11-09: use cakelesscoder's own tool for the E-P7).

## Good to know

The preview is an approximation of the camera, good for direction and strength: judge the final look in live view. On a Mac, Safari's **File › Add to Dock** makes the Control
Panel an app.
