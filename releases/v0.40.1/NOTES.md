# Caduceus for OM-3 v0.40.1

**Rounder film grain with fewer repeats, and a film's WB Compensation now shows in the super control panel (#88).**
v0.40 plus two changes, camera-tested together on 2026-11-19 (the build before its release name).

**New since v0.40**
- **Round film grain.** Medium and Coarse were built from little squares, which showed as fine horizontal and vertical
  lines up close. The grain's clumps are now round and soft, and the grain picture repeats about five times less.
  Fine is still single-pixel grain. Film Grain 1 to 5, the grain's colour and its strength are unchanged; Coarse is a
  touch bigger and softer. Camera photos: the square pattern and the repeats are down to the camera's own noise.
- **A film's WB Compensation is the camera's own** ([#88](https://github.com/androidfanman/caduceus-om3/issues/88),
  reported by novaldemar). Picking a film sets its compensation in the camera, so the super control panel's White
  Balance screen shows what the film uses (before, it was added quietly to each photo). Change it there and the film
  remembers it (it gets a "*"), as it already remembers its WB mode; resetting the film brings its own back.

**Fixed since v0.40**
- **A new film set and the film you're on:** when a new `LOOKS.BIN` changed the film on screen, the camera kept the old
  film's white balance, and leaving the film saved it into the new one with a "*". The new film's WB mode, Kelvin and
  compensation now go in straight away (#88).

**Differences to know**
- **One compensation per WB mode:** the camera keeps a separate compensation for each WB mode. A film sets it for its
  own WB mode; if you switch the WB mode by hand, that mode's own compensation applies.
- **The camera's own picture modes** (Natural, Vivid…) keep whatever compensation the last film set. In v0.40 the
  film's shift never reached them.
- At the first half-press after switching on, the camera gets the on-screen film's compensation back. Video's white
  balance is left alone.
- Coarse grain takes a little longer to prepare per photo (about 320 ms against 270 ms on the camera).
- **LookLab:** the grain preview uses the round grain, and the WB Compensation help says how it works now.

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.40.1`). Copy
`DCOLYMP` and flash it (hold OK, then switch the camera on). Your films, changes, custom modes, button settings and
screen-info choices stay in the camera. **Coming from v0.29.x or older?** Also put `CURVES.BIN` in the `OM3MOD` folder
for the regraded films.

Going back: make v0.40 and copy its `DCOLYMP`.

The files here are the patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the optional extras
(`CURVES.BIN`, `LOOKS.BIN`, `DEBUG.TXT` and the photo code kit, as in v0.40) and the expected checksums.
Full list of changes: [CHANGELOG](../../CHANGELOG.md#v0401).
