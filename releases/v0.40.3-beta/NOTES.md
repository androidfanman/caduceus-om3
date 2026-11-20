# Caduceus for OM-3 v0.40.3-beta (test version)

**Faster Halation, a Halation Radius choice, and the right film name in playback.** A test version (a GitHub
pre-release): v0.40.2 stays the current version. Camera-tested on an OM-3 (2026-11-20) as test build r5; this package
is that build under its release name.

**New**
- **Halation Radius** (by fernandezk26, discussion #92): a new Picture Mode row under Halation Effect. **Bloom** is
  v0.40's halo and stays the default; **Tight**, **Medium** and **Wide** spread the glow about 32, 64 and 128 pixels
  from bright lights, as a filmic fringe. The radius is separate from Halation's strength, and each film keeps its
  own. Film Grain, Grain Size and Border are now one row further down. LookLab can't set the radius yet (its preview
  stays Bloom).

**Faster and fixed**
- **Halation is faster:** the work every Halation photo pays is about half what it was, and photos look exactly as
  in v0.40.2.
- **Bursts with Halation:** while the shutter button is held, Halation's pauses (which keep single shots quick) now
  stop after 0.3 s a photo, so burst photos save sooner.
- **Playback shows each photo's own film (#93):** after switching a COLOR to another film, older photos no longer
  show the new film's name. A photo taken on a COLOR with no film shows "COLOR n".
- **#91** (the camera switching off on the first photo with Film Grain, in sequential with JPEG only): we couldn't
  make it happen here, and this version changes how the grain and Halation use the camera's memory. If you had #91,
  please try this version and tell us on #91 whether it still happens.
- **Debug log:** also records Halation's slowest photo of each power-on.
- **Firmware Version screen:** shows "Caduceus : 0.40.3-b".

**Start-up:** nothing of ours runs while the camera starts. The camera copies about 376 KB more of the firmware into
memory at switch-on (the Halation Radius work area).

Everything else is as in [v0.40.2](../v0.40.2/NOTES.md).

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.40.3-beta`).
Copy `DCOLYMP` and flash it (hold OK, then switch the camera on). Your films, changes, custom modes, button settings
and screen-info choices stay in the camera. **Coming from v0.29.x or older?** Also put `CURVES.BIN` in the `OM3MOD`
folder for the regraded films.
