# Film in the photo (EXIF): text layout and the om3.1 code

Caduceus for OM-3 v0.27 writes the film a JPEG was taken with into two EXIF text fields, so photos can be sorted by
film and a shared photo can give its film back to LookLab.

| Field | Text |
|---|---|
| ImageDescription (0x010e) | `FILM 19 Astia 100F` |
| UserComment (0x9286; character code blank, then ASCII) | `Caduceus FILM 19 Astia 100F om3.1.AAAAAAAAAQAAAAAADwAAEQAAAAAPABDwABAAAAAAAAA` |

| UserComment from om3.2 (below): the code alone | `om3.2.ARAAEQABHxAAIxDwDw_-8A_wAAIAADEQABPwAAAAAAAQ48UAYKCQAgc_BLKU` |

Photos without a film (COLOR 1–4 with the user's own settings, CRT, ART, MONO, …) keep the camera's blank fields.

## om3.2: `om3.2.` + 60 characters (2026-11-24)

Status: branch `feature/photo-code-3` (on test build v0.41-a6), emulator only: the camera test is pending. Not released.

Owner, 2026-11-24: a new code that carries every Picture Mode row the user set, and nothing else in the comment (no
"Caduceus", no film number, no name: "drop all name"). ImageDescription keeps `FILM n Name`, as before. The code is
66 characters of the comment's 117.

The 60 characters are 45 bytes in base64url (no padding is needed):

| Byte | Field | Notes |
|---|---|---|
| 0–31 | The 64 values of `om3.1`, unchanged | Every rule of the om3.1 code holds for them: its first 43 characters are an om3.1 code's |
| 32–43 | 24 more values, coded the same way (4 bits each, the first in the high half), all signed −7…7 | A curves slot as the camera keeps it. Values 0–5 the red RGB curve, 6–11 green, 12–17 blue: a curve's 5 points (0 / 25 / 50 / 75 / 100 %) are its values 0, 2, 3, 4, 5; value 1 is spare (0, not read). Values 18–23 the colour mix: hue R, strength R, hue G, strength G, hue B, strength B |
| 44 | The grain byte, whole | Bit 7 set = given. Bits 0–2: Film Grain strength 1–5 (0 = the level's). Bits 3–4: Grain Size 0 Fine, 1 Medium, 2 Coarse. Bit 7 clear (a film as built), or value 51 = 0 (grain Off): the level's strength (Low 2, Medium 3, High 5) and Medium |

- **What the camera writes:** COLOR k as set at the half-press before the shot (the record, its curves and mix, its
  grain byte); with no half-press read, the film as built (its LOOKS.BIN record, its `CURVES.BIN` values, grain byte
  0), as om3.1 did.
- **Readers:** an om3.1 reader finds no code in an om3.2 photo (its pattern asks for `om3.1.`); it has to be updated.
  A reader of both: `om3\.(?:1\.([A-Za-z0-9_-]{43})|2\.((?:[A-Za-z0-9_-]{4}){15,}))(?![A-Za-z0-9_-])`. For an om3.1
  code: flat curves, no mix, the level's strength, Medium.
- **Growing it:** more groups of 4 characters (3 bytes) after the 60, with 0 = off / not given; 51 characters of the
  comment are free. A reader takes the bytes it knows and accepts a longer code.
- Reference: `firmware/photocode.py` (`encode2`, `extras`, `decode`); firmware `ex_cd1` / `ex_fill`
  (`firmware/src/editor.s`); LookLab `lookFromPhotoCode` / `photoCodeOf`; the developer kit `devkit/photo-code/`.
- Not built: the add-on form `om3.1.<43>.<16>` of 2026-11-23 (branch `feature/photo-code-2`, test builds only).

The rest of this page is the om3.1 code, which om3.2's first 64 values follow.

## The code: `om3.1.` + 43 characters

- A 64-byte LOOKS.BIN record of the film (layout: `card/mkprofiles.py`, `webapp/src/om3.ts` `profilesBin`).
  v0.27: the film as built (its LOOKS.BIN record). **v0.28: the film as it is set when the photo is taken**, with the
  changes made on the camera and the camera's WB (read at the half-press before the shot, `ex_live`; the film as built
  when there was none).
- One nibble per byte (`value & 15`), two to a byte (32 bytes), base64url (`A-Z a-z 0-9 - _`), no padding.
- Signed fields read back as -8..7; unsigned ones (WB on, NR, VigFix, Grain, split-toning colours, Halation, the
  split-toning half steps) as 0..15.
- v0.28 bytes (spare in v0.27, so a v0.27 reader skips them): **57** Halation 0..5, **58** Tone Balance -5..5,
  **59 / 60** Custom WB Kelvin and **61 / 62** the WB mode, each pair a value v = lo + 11 hi (lo, hi -5..5): Kelvin =
  2000 + 100 (v + 60) when the mode is Custom WB, the mode = its place in the camera's list (0 Auto, 1 Sunny, 2 Shade,
  3 Cloudy, 4 Incandescent, 5 Fluorescent, 6 Underwater, 7 Flash, 8–11 One-touch 1–4, 12 Custom WB).
- **Split toning** (bytes 53–56) keeps the v0.26 meaning in the code, so older readers still read it: strength 0..5 in
  v0.26 steps (a v0.26 / v0.27 photo may have -5..-1 = the opposite colour). v0.28's wheels have half steps (0..10):
  the half step is in **byte 63** (bit 0 Shadows, bit 1 Highlights), strength on the v0.28 scale = 2 x byte + bit. An
  older reader rounds it down by half a step. (In LOOKS.BIN v0.28 stores these strengths as a different code; the
  camera converts it for the photo code.)
- **v0.40: byte 48 is the Border**, -5..5 (minus = a black border, plus = white, 0 = none), read signed. It was the
  Art Effect byte, which v0.25 removed, so every older code has 0 there. **Byte 51** stays the grain level 0..3: v0.40's
  Film Grain 1..5 is written as 1-2 Low, 3 Medium, 4-5 High; Grain Size is not in the code.
- **Halation Radius** (branch `halation/v0.40-radius`, not released): **byte 63 bits 2..3** = the radius, 0 Bloom (the
  default, and every older code), 1 Tight, 2 Medium, 3 Wide. Bits a reader did not know about, with 0 = as before, so
  older readers (bits 0..1 only) are unaffected.
- **Compatibility rule:** new settings go into spare bytes with 0 = off. An older LookLab then still opens a
  newer code (it skips what it doesn't know), and a newer one reads an older code's spare bytes as "off". Only a change
  that cannot follow that rule gets a new version (`om3.2.`). **v0.28 used the last spare byte (63)**: the next new
  setting needs `om3.2.`.
- The camera is in the name, so another body can have its own code (for example `ep7.1.` for Caduceus on the E-P7)
  with the same text layout.
- Reference: `firmware/photocode.py`; firmware `ex_cd1` / `ex_fill` (`firmware/src/editor.s`); LookLab
  `recordFromPhotoCode` / `lookFromPhotoCode` (paste the comment into the import box, or open the JPEG).
- Developer kit for other sites and apps (field table, a standalone JavaScript reader, test examples, a demo page):
  `devkit/photo-code/`.
