# Caduceus for OM-3 v0.27.1

**A fix for a rare freeze at switch-on.**

- Now and then the camera could start with the live view on but nothing else loaded, and the power switch didn't turn it
  off (a battery pull fixed it). It came from loading the films automatically while the camera was still starting.
  v0.27.1 loads them at your **first half-press** instead, as up to v0.26.1: switch on, half-press once, and your films
  are there. Until then the screen may show the plain COLOR look.
- Everything else is v0.27: all four arrow keys in Button Function, the Creative Dial modes with a film per position,
  the film's name and recipe in every JPEG, the optional debug log.
- Firmware camera-tested (2026-11-11, build na1).

**Copy to the card:** `DCOLYMP` (flash it: hold OK, then switch the camera on) and the `OM3MOD` file `GUIDES.BIN`
(made for this firmware: always copy it with it). `LABELS.BIN`, `TONES.BIN` and the optional `LOOKS.BIN` are the same as
v0.27. Keep your `EDITS.BIN`, `NAMES.BIN` and `BUNDLES.BIN`.

**Optional extras:** `DEBUG.TXT` (copy it into `OM3MOD` only if you're asked for a log) and
`caduceus-om3-photo-code-kit.zip` (for developers; now with a real camera sample photo).

Make it: run the launcher and press Return (or `python3 firmware/patch.py --release v0.27.1`). The files here are the
patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the card files, the optional extras and the expected
checksums. Full list of changes: [CHANGELOG](../../CHANGELOG.md#v0271).
