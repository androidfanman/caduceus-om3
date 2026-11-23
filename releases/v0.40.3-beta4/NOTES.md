# Caduceus for OM-3 v0.40.3-beta4 (test version)

**Separate WB shifts for films and the camera's own picture modes, on top of v0.40.3-beta3.** A test version (a GitHub
pre-release): v0.40.2 stays the current version. Camera-tested on an OM-3 (2026-11-21) as test build w1; this package
is that build under its release name.

**Changed: WB compensation (the A-B / G-M shift)**
- **Films and the camera's own picture modes each keep their own shift.** Each film and COLOR has one shift of its
  own. The camera's own setting is only ever the camera's: Caduceus never writes it.
- **On a film,** the super control panel's White Balance screen and Picture Mode's WB row show the film's shift. A
  change there goes straight into the film (it gets its "*"; resetting the film brings its own back). Live view and
  your photos use the film's shift in place of the camera's.
- **On the camera's own modes** (Natural, Vivid…), everything is as on a stock camera.
- **No half-press needed** any more, and nothing of ours runs at a Creative Dial turn or a film pick for the WB shift.
  This replaces the switch at the half-press from beta3 (#99), and the film's shift no longer goes into the camera's
  own fine-tune (#88's way since v0.40.1).
- **After updating, set the centre's shift once:** the camera may still hold a film's shift in its own setting from
  an earlier version. At the camera's own modes, open the WB screen and set the compensation you want there (0 if you
  never set one). Films keep theirs.
- Video is unchanged.

**Firmware Version screen:** shows "Caduceus : 0.40.3-b4".

**Start-up:** nothing of ours runs while the camera starts.

Everything else is as in [v0.40.3-beta3](../v0.40.3-beta3/NOTES.md).

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.40.3-beta4`).
Copy `DCOLYMP` and flash it (hold OK, then switch the camera on). Your films, changes, custom modes, button settings
and screen-info choices stay in the camera. **Coming from v0.29.x or older?** Also put `CURVES.BIN` in the `OM3MOD`
folder for the regraded films.
