# Caduceus for OM-3 v0.41-beta (test version)

**v0.41-alpha's new Picture Mode pages, cleaned up, plus a new photo code that carries the RGB curves and Color Mix.**
A test version (a GitHub pre-release): v0.40.3 stays the current version. Camera-tested on an OM-3 (2026-11-23 and
2026-11-24) as test builds a2 to a6 and pc3; this package is that build under its release name.

**Changed since v0.41-alpha**
- **INFO hints on the two bars.** "H/S/L INFO" sits over the colour wheel's H / S / L bar and "Split Tone INFO" over
  the Split toning bar, in the style of the camera's own guides, so you can see that INFO steps to the next setting
  (suggested by Fanatic).
- **Split toning, Balance step:** only the bar shows. The wheel, "Color", "Tint" and the dial mark are gone on that
  step, and come back on Shadows and Highlights.
- **One style for the INFO guides:** "Color INFO" on the Color Mix and RGB curves rows now looks like the others.

**New: photo code `om3.2`**
- The code the camera writes into each JPEG taken on a film now also carries the **RGB curves**, the **Color Mix**,
  **Film Grain's exact strength** (1-5) and the **Grain Size**, next to everything the old code had. A look opened
  from a photo comes back with its curves and mix.
- The photo's comment is now the code alone (`om3.2.` and 60 characters). The film's name is still in the photo's
  description ("FILM n Name").
- **LookLab** (on the site since 2026-11-24) opens photos with the new code and with the old one.
- **Other readers need updating:** apps that read the old `om3.1.` code find no code in photos from this version until
  they are updated. The developer kit in this release reads both
  ([format](../../docs/PHOTO_CODE.md)).

Everything else is as in [v0.41-alpha](../v0.41-alpha/NOTES.md): the H / S / L bar on the colour wheel, the
five-point tone curve, and Split toning on its own row with Balance.

**Firmware Version screen:** shows "Caduceus : 0.41-b1".

**Start-up:** nothing of ours runs while the camera starts. Video is unchanged.

**Make it and copy it:** run the launcher from this version's download and press Return (or
`python3 firmware/patch.py --release v0.41-beta`). Copy `DCOLYMP` and flash it (hold OK, then switch the camera on;
it can take up to about five minutes). Your films, changes, custom modes, button settings and screen-info choices
stay in the camera. **Coming from v0.29.x or older?** Also put `CURVES.BIN` in the `OM3MOD` folder for the regraded
films.

Going back: make v0.40.3 and copy its `DCOLYMP`.

If something looks wrong, please open an issue with a [debug log](../../debug-log/README.md).
