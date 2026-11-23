# Caduceus for OM-3 v0.41-alpha (test version)

**New Picture Mode pages on top of v0.40.3: the H / S / L bar on the colour wheel, a five-point tone curve, and Split
toning on its own row.** An early test version (a GitHub pre-release): v0.40.3 stays the current version.
Camera-tested on an OM-3 (2026-11-23) as test build p4; this package is that build under its release name.

**New (on a film, COLOR 1-4)**
- **Colour wheel: the H / S / L bar.** Under the wheel, a bar shows the selected colour's Hue, Saturation and
  Lightness together. INFO steps H, S, L. Turning the front dial past the first colour gives all colours at once
  ("Sat. All"). Delete does nothing on the wheel any more.
- **Highlight & Shadow: a five-point tone curve.** Blacks and Whites are now the curve's two end points, on a new
  Blk / Wht page: INFO steps Sh / Hi, Mid, Blk / Wht. The top line shows all five values and one curve runs through
  all five points on every page. The row's "*" shows only when a value differs from the film's own, and holding OK
  puts the values back to the film's.
- **Split toning on its own row.** The Shadows and Highlights tints have their own row under the colour wheel, with
  a bar showing the tint's colour, S (Shadows), B (Balance) and H (Highlights). INFO steps Shadows, Balance,
  Highlights. On Balance the rear dial sets Tone Balance and the wheel is hidden.

**Changed**
- **The Blacks / Whites row and the Tone Balance row are gone from Picture Mode's list:** they are the tone curve's
  Blk / Wht page and the Split toning row's Balance. Your films' saved values are kept, and photos use them as before.

**Firmware Version screen:** shows "Caduceus : 0.41-a1".

**Start-up:** nothing of ours runs while the camera starts. Video is unchanged.

Everything else is as in [v0.40.3](../v0.40.3/NOTES.md).

**Make it and copy it:** run the launcher from this version's download and press Return (or
`python3 firmware/patch.py --release v0.41-alpha`). Copy `DCOLYMP` and flash it (hold OK, then switch the camera on;
it can take up to about five minutes). Your films, changes, custom modes, button settings and screen-info choices
stay in the camera. **Coming from v0.29.x or older?** Also put `CURVES.BIN` in the `OM3MOD` folder for the regraded
films.

Going back: make v0.40.3 and copy its `DCOLYMP`.

If something looks wrong, please open an issue with a [debug log](../../debug-log/README.md).
