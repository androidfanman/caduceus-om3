# Caduceus for OM-3 v0.27

**Your buttons, your Creative Dial, and the film saved in every photo.**

- **All four arrow keys in Button Function:** set the arrow pad (✥) to Direct Function and each of ▲ ◀ ▶ ▼ gets its
  own row with the full list of functions. Built on the up-key research by
  [ryanbughuang](https://github.com/androidfanman/caduceus-om3/pull/26): thank you.
- **Creative Dial modes:** four new rows in Button Function, **CRT, ART, COLOR and MONO**, one for each position of the
  front Creative Dial. Set any position to CRT, ART, COLOR or MONO (Normal = its usual mode). Every position set to
  COLOR remembers its own COLOR or FILM, so you can have four COLOR positions with four different films. After you
  switch the camera on, a position's setting takes effect at the first half-press or dial turn.
- **The new rows look like the camera's own**, and the body pictures beside them highlight the right control and point
  to the right row.
- **The film in the photo:** every JPEG taken on a FILM keeps the film's name in its EXIF (Image Description:
  `FILM 9 Velvia 50`) and its whole recipe as a short code in the User Comment (`... om3.1.ERAP____ABAA...`).
  Open the JPEG in the Control Panel (Open..., or paste the comment with Paste link) and the film is added to your
  films. Codes stay readable by future versions.
- **For developers:** `caduceus-om3-photo-code-kit.zip` reads the recipe from a photo on any website or app (a
  JavaScript reader, test examples, a demo page, the field table). Also in the repository at `devkit/photo-code/`.
- **Optional debug log:** copy `DEBUG.TXT` into `OM3MOD` only if you're asked for a log; the camera then writes
  `OM3MOD/CADLOG.TXT`. Delete `DEBUG.TXT` to turn it off. It isn't part of the normal card files.
- Everything from v0.26.2 stays. The movie menu is unchanged.
- Firmware camera-tested (2026-11-11, build dr7).

**Copy to the card:** `DCOLYMP` (flash it: hold OK, then switch the camera on) and the `OM3MOD` file `GUIDES.BIN`
(made for this firmware: always copy it with it). `LABELS.BIN` and `TONES.BIN` are the same as v0.26.2. The optional
`LOOKS.BIN` (the 20 film sims; it replaces your own films) has Gold 200's and CineStill 800T's split tone moved to the
Highlights wheel, as designed; the other 18 are as v0.26.2. Keep your `EDITS.BIN`, `NAMES.BIN` and `BUNDLES.BIN`.

**Going back to v0.26.2 or older:** flash that version with its own `GUIDES.BIN`; your files still work. The extra arrow key
and dial rows go away with it.

Make it: run the launcher and press Return (or `python3 firmware/patch.py --release v0.27`). The files here are the
patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the card files, the optional extras and the expected
checksums. Full list of changes: [CHANGELOG](../../CHANGELOG.md#v027).
