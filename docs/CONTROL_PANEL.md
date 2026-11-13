# Using LookLab

The **[Caduceus LookLab](https://androidfanman.github.io/caduceus-om3/looklab/)** is a web page where you make and change
your films (FILM 1–20 on the camera) on your computer, with a preview. Your work stays in your browser: nothing is
uploaded.

## Making and changing films

1. **The list on the left is FILM 1–20**, in the same order as on the camera. Click a film to edit it. Drag a film to
   another place, or use ↑ ↓; × empties a place (empty places are left out of the camera's list and the films after
   them move up a number).
2. **Start from the 20 film sims.** The first time you open it, the list holds the [20 film sims](../README.md#the-20-film-sims). Already used it
   before? **New › Reset looks to standard** puts the 20 back (Undo brings your old list back).
3. **Film sims** opens all 67 film looks: **The 20** first, in FILM order, then more under "More" (other slide and
   negative films, Fujifilm-style simulations, instant films and cinema print stocks). **Colour matched** shows the 18
   films graded against film scans of a colour chart; **Hand-tuned** the others, designed from descriptions. Click one to preview it on your
   photo; **+ Add** puts it in an empty place (or offers to replace one when all 20 are used).
4. **Edit** a film, laid out like the camera's Picture Mode screen: the HSL wheel with the camera's five pages (Color,
   Hue, Luminance, Shadows, Highlights; drag a colour on the wheel or use the slider), the Highlight & Shadow curve
   (drag its handles), the Blacks / Whites grid and the WB grid (click or drag) and the rows below. In short: Hue,
   Lightness and Saturation for each of the 12 colours; split toning (Shadows / Highlights, 0–10) and its Tone Balance;
   the tone (Highlights, Shadows, Midtones, Blacks, Whites to ±7); the camera's Contrast and Shading; the WB shift (A-B /
   G-M) and the film's WB mode (Auto, Sunny, … Custom WB with its Kelvin); and the Extras (Noise Filter, lens vignette
   correction, Grain, Sharp, Glow ↔ Clarity, Halation). The preview on the test photos (or your own: drag
   the line on the photo to compare before and after) shows grain, glow and clarity; Noise Filter and the lens
   correction are not previewed. Art Effects are not used from v0.25. **Split toning** and **Tone Balance** show in the
   preview too; the **WB mode** as if the photo was taken in daylight; **Halation** around bright lights in night
   photos (as on the camera, it fades out in bright daylight photos).
5. **Export › Save to card…** (Chrome or Edge on a computer) writes `OM3MOD/LOOKS.BIN` (and `NAMES.BIN`) straight
   onto the card; **Card folder (.zip)** downloads them. From v0.29 only `LOOKS.BIN` matters, and the camera takes a set
   of films only if it never had it (change anything to make it new). Keep **Firmware on the camera: v0.28 or later** (older choices leave Halation, Tone Balance, the WB mode and
   Blacks / Whites past ±5 out).
6. On the camera: switch on and half-press the shutter once (that loads your films): they are FILM 1–20 in Picture Mode. A film you changed in the
   LookLab starts as built on the camera; the others keep the changes you made on the camera.

## A film from your own LUT or Lightroom preset

1. Choose **From LUT / preset…** at the top and pick a `.cube` file (a 3D or 1D LUT for normal pictures) or a
   Lightroom preset (`.xmp`, or `.lrtemplate` from older Lightroom). **Open…** takes these files too.
2. LookLab tries the camera's own settings on a set of test colours (greys, skin, sky, foliage and every
   hue) and keeps the ones that come closest: the 12 colours' saturation, hue and brightness, Contrast, Highlights /
   Shadows / Midtones, Blacks / Whites, the WB shift, split toning and Tone Balance.
3. It shows your grade and the film side by side on the preview photo, with a **Close / Fair / Rough match** and a
   colour difference (lower is closer).
4. From a Lightroom preset, Grain, Vignette and Clarity become Film Grain, Shading and Clarity / Glow; settings with no
   camera match (such as Dehaze or Texture) are listed as left out.
5. Name the film and choose **Add as a film**. It's a normal film from then on: change it as you like.

Good to know: the result is an approximation. Warm, faded, soft-contrast and teal-and-orange grades usually carry over
well; grades that move one shade of a colour differently from its neighbours don't. LUTs made for Log video (V-Log,
S-Log, Log to Rec.709) expect flat footage and are flagged. Your file stays in your browser.

## More

- **Lists** keep whole sets of 20 films under a name, like playlists: **Save as…** stores the current set, the **List**
  menu switches between them, **Rename** / **Delete** manage them. Lists stay in this browser; export one to put it on
  the card.
- **Open…** a `LOOKS.BIN` to edit those films, then save them back. Before v0.29 the card's `OM3MOD/LOOKS.BIN` held the
  camera's films; from v0.29 the camera keeps its films and your on-camera changes in its own memory and writes nothing
  to the card, so work from your saved list here.
- **Share looks** / **Share** make a link to all your films or to one; **Paste link** opens one. Both also show the
  **recipe code** (`Caduceus FILM 5 CineStill 800T om3.1.…`), the same short code the camera writes into each photo:
  copy it to post a film anywhere; **Paste link** (or opening a photo) turns it back into the film.
- **From the built-in library** (on an empty place) adds one of the starter looks from Caduceus for the E-P7, converted
  for the OM-3. E-P7 files, packs and look codes are no longer opened (the E-P7 side of the tool was removed
  2026-11-09: use cakelesscoder's own tool for the E-P7).

## Good to know

The preview is an approximation of the camera, good for direction and strength: judge the final look in live view. On a Mac, Safari's **File › Add to Dock** makes the Control
Panel an app.
