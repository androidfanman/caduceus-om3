# OM-3 photo code: developer kit

From v0.27, [Caduceus for OM-3](../../README.md) writes the film a JPEG was taken with into the photo's EXIF, with a
short code holding the film's full recipe. A website or app can read the code and rebuild the recipe: for example, a
user uploads a photo and the site shows (or imports) the settings that made it.

This folder is everything needed to read it:

| File | What it is |
|---|---|
| `om3code.js` | A reader in plain JavaScript: no dependencies, runs in browsers and Node 18+ (ES module). |
| `examples.json` | Test codes with the exact values they must decode to: the 20 default films, one written by the firmware, one from a "future" firmware. |
| `test.mjs` | `node test.mjs` checks the reader against the examples. |
| `demo.html` | A one-page reader: open a JPEG or paste a comment. Serve the folder over http (ES modules don't load from `file://`). |

Other implementations in the [repository](https://github.com/androidfanman/caduceus-om3): Python `firmware/photocode.py`;
the Control Panel's `recordFromPhotoCode` / `lookFromPhotoCode` in `webapp/src/om3.ts` (its Open and Paste link take
a JPEG or a code).

The same files come as a zip with each release (`caduceus-om3-photo-code-kit.zip` on the
[Releases page](https://github.com/androidfanman/caduceus-om3/releases/latest)).

## Where it is in the photo

Only photos taken on a FILM (FILM 1–20) carry it. COLOR 1–4 with the user's own settings, CRT, ART and MONO keep the
camera's blank fields.

| EXIF field | Example |
|---|---|
| ImageDescription (0x010E) | `FILM 9 Velvia 50` |
| UserComment (0x9286, `ASCII` character code) | `Caduceus FILM 9 Velvia 50 om3.1.ERAP____ABAAAPD_MO7xMzNVEP4CANDQABAQAAAAAAA` |

The name is the one the user gave the film on their card, so two people's "FILM 9" can differ; the code is what counts.
You don't need an EXIF parser: the code is plain ASCII, so searching the first 128 KB of the file for
`om3\.1\.([A-Za-z0-9_-]{43})` finds it (that is what `om3code.js` does).

## Using the reader

```js
import { readPhoto, describe } from './om3code.js';

const recipe = readPhoto(await file.arrayBuffer());  // or readPhoto(userCommentText)
if (recipe) {
  recipe.film;          // 9
  recipe.name;          // "Velvia 50"
  recipe.contrast;      // 2
  recipe.saturation;    // { Yellow: 3, Orange: 0, ... }
  describe(recipe);     // ["Hue: Yellow +1, ...", "Contrast +2", ...]  (settings at 0 left out)
}
```

`decode(code)` gives the same object from a bare code, and `decodeBytes(code)` the 64 raw values.

## The code

`om3.1.` followed by 43 characters:

1. The film's 64 settings bytes (the record the camera stores the film in), in the order of the table below.
2. Each byte reduced to 4 bits (`value & 15`); two to a byte, the first in the high half: 32 bytes.
3. Base64url (`A–Z a–z 0–9 - _`) without padding: 43 characters.

Reading back: undo base64url, split each byte into two 4-bit values, and read each as signed (8–15 → −8…−1) unless the
table marks it unsigned.

### Fields

| Byte | Field | Range | Notes |
|---|---|---|---|
| 0–11 | Hue, per colour | −5…5 | Colour wheel order below |
| 12–23 | Lightness, per colour | −5…5 | |
| 24–35 | Saturation, per colour | −5…5 | |
| 36 | White balance shift on | 0 / 1 (unsigned) | 0: the camera's white balance, ignore 37–38 |
| 37 | WB Amber–Blue | −7…7 | |
| 38 | WB Green–Magenta | −7…7 | |
| 39 | Blacks | −5…5 | |
| 40 | Whites | −5…5 | |
| 41 | Contrast | −2…2 | |
| 42 | Sharpness (firmware before v0.22) | −2…2 | 0 from v0.22 on: byte 52 holds it |
| 43 | Shading (vignette) | −5…5 | |
| 44 | Shadows | −7…7 | |
| 45 | Midtones | −7…7 | |
| 46 | Highlights | −7…7 | |
| 47 | Glow / Clarity | −5…5 | Negative = Glow 1–5, positive = Clarity 1–5 |
| 48 | Art Effect (unsigned) | 0 Off, 1 Star Light, 2 Pin Hole, 4 White Edge, 5 Frame | |
| 49 | Noise reduction (unsigned) | 0 Camera setting, 1 Standard, 2 Low, 3 Off, 4 High | |
| 50 | Lens shading correction (unsigned) | 0 Camera (on), 1 Off | |
| 51 | Grain (unsigned) | 0 Off, 1 Low, 2 Medium, 3 High | |
| 52 | Sharpness | −5…2 | −5 = Off |
| 53 | Split toning: shadow colour (unsigned) | 0–11 | Colour wheel order |
| 54 | Split toning: shadow strength | −5…5 | Negative = the opposite colour |
| 55 | Split toning: highlight colour (unsigned) | 0–11 | |
| 56 | Split toning: highlight strength | −5…5 | |
| 57–63 | Spare (unsigned) | 0 | Future settings; 0 = off |

Colour wheel (clockwise from 12 o'clock, as on the camera): 0 Yellow, 1 Orange, 2 Orange-red, 3 Red, 4 Magenta,
5 Violet, 6 Blue, 7 Blue-cyan, 8 Cyan, 9 Green-cyan, 10 Green, 11 Yellow-green.

### Compatibility

- **Forward:** new settings go into the spare bytes 57–63, with 0 = off. A reader written today keeps working on photos
  from later firmware: it reads everything it knows and can ignore (or show) the spare values. `examples.json`
  includes such a code.
- **Backward:** a newer reader treats an older photo's spare bytes (all 0) as "off".
- **Breaking changes** get a new version in the prefix (`om3.2.`). A reader should only accept the versions it knows.
- The camera is in the prefix, so another body can have its own code with the same layout.

## License and credit

Apache License 2.0, like the rest of this repository (`LICENSE`, `NOTICE`). Use it in any site or app, commercial
or not. A credit line such as "Photo codes from Caduceus for OM-3" with a link to the repository is appreciated.
