# Caduceus for OM-3 v0.29.3

**v0.29.2 plus a remappable Delete button.** Firmware camera-tested (2026-11-14, build d1: v0.29.2 with pull request
[#40](https://github.com/androidfanman/caduceus-om3/pull/40); only its name was changed to v0.29.3).

**New** ([#37](https://github.com/androidfanman/caduceus-om3/issues/37))
- **The Delete button takes a function while shooting.** In photo and video mode, Button Function has a new Delete row
  (the trash can, right after ▼) with the same choices as Fn: for example Magnify, High Res, Digital Teleconverter,
  Subject Detection or movie Start / Stop. Set to Off it does what it always did (for example Multiple Exposure's frame
  delete).
- **Unchanged:** in playback Delete still erases photos, and in text entry (like naming a custom mode) it still deletes
  a letter.

**Thanks:** the Delete button is by [crombach](https://github.com/crombach), who also opened #37 and tested it on their
own OM-3.

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.29.3`). Copy only
`DCOLYMP` and flash it (hold OK, then switch the camera on). Your films, custom modes and button settings stay in the
camera.

Everything else, including the custom-mode fix of [v0.29.2](../v0.29.2/NOTES.md) and the optional extras (`LOOKS.BIN`
with the colour-matched standard 20, `DEBUG.TXT`, the photo code kit), is as in v0.29.2. Going back: make v0.29.2 and
copy its `DCOLYMP`.

The files here are the patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the optional extras and the
expected checksums. Full list of changes: [CHANGELOG](../../CHANGELOG.md#v0293).
