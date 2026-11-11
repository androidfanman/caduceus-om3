# Film in the photo (EXIF): text layout and the om3.1 code

Caduceus for OM-3 v0.27 writes the film a JPEG was taken with into two EXIF text fields, so photos can be sorted by
film and a shared photo can give its film back to the Control Panel.

| Field | Text |
|---|---|
| ImageDescription (0x010e) | `FILM 19 Astia 100F` |
| UserComment (0x9286; character code blank, then ASCII) | `Caduceus FILM 19 Astia 100F om3.1.AAAAAAAAAQAAAAAADwAAEQAAAAAPABDwABAAAAAAAAA` |

Photos without a film (COLOR 1–4 with the user's own settings, CRT, ART, MONO, …) keep the camera's blank fields.

## The code: `om3.1.` + 43 characters

- The film's whole 64-byte LOOKS.BIN record (layout: `card/mkprofiles.py`, `webapp/src/om3.ts` `profilesBin`).
- One nibble per byte (`value & 15`), two to a byte (32 bytes), base64url (`A-Z a-z 0-9 - _`), no padding.
- Signed fields read back as -8..7; unsigned ones (WB on, Art Effect, NR, VigFix, Grain, split-toning colours) and the
  spare bytes 57..63 as 0..15.
- **Compatibility rule:** new settings go into the spare bytes with 0 = off. An older Control Panel then still opens a
  newer code (it skips what it doesn't know), and a newer one reads an older code's spare bytes as "off". Only a change
  that cannot follow that rule gets a new version (`om3.2.`).
- The camera is in the name, so another body can have its own code (for example `ep7.1.` for Caduceus on the E-P7)
  with the same text layout.
- Reference: `firmware/photocode.py`; firmware `ex_cd1` / `ex_fill` (`firmware/src/editor.s`); Control Panel
  `recordFromPhotoCode` / `lookFromPhotoCode` (paste the comment into the import box, or open the JPEG).
- Developer kit for other sites and apps (field table, a standalone JavaScript reader, test examples, a demo page):
  `devkit/photo-code/`.
