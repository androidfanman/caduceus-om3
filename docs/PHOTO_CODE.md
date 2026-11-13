# Film in the photo (EXIF): text layout and the om3.1 code

Caduceus for OM-3 v0.27 writes the film a JPEG was taken with into two EXIF text fields, so photos can be sorted by
film and a shared photo can give its film back to LookLab.

| Field | Text |
|---|---|
| ImageDescription (0x010e) | `FILM 19 Astia 100F` |
| UserComment (0x9286; character code blank, then ASCII) | `Caduceus FILM 19 Astia 100F om3.1.AAAAAAAAAQAAAAAADwAAEQAAAAAPABDwABAAAAAAAAA` |

Photos without a film (COLOR 1–4 with the user's own settings, CRT, ART, MONO, …) keep the camera's blank fields.

## The code: `om3.1.` + 43 characters

- A 64-byte LOOKS.BIN record of the film (layout: `card/mkprofiles.py`, `webapp/src/om3.ts` `profilesBin`).
  v0.27: the film as built (its LOOKS.BIN record). **v0.28: the film as it is set when the photo is taken**, with the
  changes made on the camera and the camera's WB (read at the half-press before the shot, `ex_live`; the film as built
  when there was none).
- One nibble per byte (`value & 15`), two to a byte (32 bytes), base64url (`A-Z a-z 0-9 - _`), no padding.
- Signed fields read back as -8..7; unsigned ones (WB on, Art Effect, NR, VigFix, Grain, split-toning colours,
  Halation, the split-toning half steps) as 0..15.
- v0.28 bytes (spare in v0.27, so a v0.27 reader skips them): **57** Halation 0..5, **58** Tone Balance -5..5,
  **59 / 60** Custom WB Kelvin and **61 / 62** the WB mode, each pair a value v = lo + 11 hi (lo, hi -5..5): Kelvin =
  2000 + 100 (v + 60) when the mode is Custom WB, the mode = its place in the camera's list (0 Auto, 1 Sunny, 2 Shade,
  3 Cloudy, 4 Incandescent, 5 Fluorescent, 6 Underwater, 7 Flash, 8–11 One-touch 1–4, 12 Custom WB).
- **Split toning** (bytes 53–56) keeps the v0.26 meaning in the code, so older readers still read it: strength 0..5 in
  v0.26 steps (a v0.26 / v0.27 photo may have -5..-1 = the opposite colour). v0.28's wheels have half steps (0..10):
  the half step is in **byte 63** (bit 0 Shadows, bit 1 Highlights), strength on the v0.28 scale = 2 x byte + bit. An
  older reader rounds it down by half a step. (In LOOKS.BIN v0.28 stores these strengths as a different code; the
  camera converts it for the photo code.)
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
