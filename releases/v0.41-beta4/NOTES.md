# Caduceus for OM-3 v0.41-beta4 (test version)

**Centre lines in the grid list (#104) and no more restarts with ART BKT (#114).** A test version (a GitHub
pre-release): v0.40.3 stays the current version. v0.41-beta3 plus these two changes, camera-tested on an OM-3
(2026-11-27) as test build framing-lines-3; this package is that build under its release name.

**New: Cross and Ticks in Displayed Grid (#104, asked for by jirimachovec)**
- Custom menu → **5. Grid/Other Displays** → **Grid Settings** → **Displayed Grid** has two more choices after the
  camera's own, each with its own icon: **Cross** (a line down the middle and one across) and **Ticks** (short marks at
  the middle of each edge and a small cross in the centre).
- They help keep the horizon level. In XPan, 21:9 and 5:4 they sit inside the crop. With a film's Border on, Ticks
  shows only its centre cross. Like the camera's own grids, they also show in video.

**Fixed: the camera restarted with a film's Film Grain and ART BKT (#114, reported by ourparhelion-collab)**
- With a film that has Film Grain and Art Filter Bracketing (ART BKT) on, the shutter could restart the camera and
  nothing was saved.
- **Different from before:** the ART BKT Setting list (Shooting Menu 2 → Bracketing → ART BKT) no longer offers
  COLOR 1-4, where the films live, so a bracket never makes a film picture. If you had a COLOR ticked there, the tick is
  removed at your first half-press. The camera's own picture modes and Art Filters stay in the list.
- Your films keep their grain in normal shooting. Our grain, Halation, Border and Shading are never put on ART BKT's
  Art Filter pictures.

**Known: EVF Style 1 does not work correctly.** With the viewfinder set to Style 1, the view is misaligned
(shifted off centre). We are looking for a fix.

**Known, being looked into:** RAW Data Edit of a RAW taken with a film came out without its Film Grain once on the
camera. Shoot JPEG or RAW+JPEG for the full film look.

Everything else is as in [v0.41-beta3](../v0.41-beta3/NOTES.md), Film Rolls included.

**Firmware Version screen:** shows "Caduceus : 0.41-b4".

**Start-up:** nothing of ours runs while the camera starts. The camera now loads a little more of its update file
(744 bytes of icons in room an earlier test showed it loads safely). Video is unchanged.

**Make it and copy it:** run the launcher from this version's download and press Return (or
`python3 firmware/patch.py --release v0.41-beta4`). Copy `DCOLYMP` and flash it (hold OK, then switch the camera on;
it can take up to about five minutes). Your films, changes, custom modes, button settings and screen-info choices
stay in the camera.

**Film Rolls users:** take the new `FILMROLL.BIN` too (in `FILMROLL.zip` on the release, or
`releases/v0.41-beta4/FILMROLL`): it is made for this firmware only, and beta3's is not loaded by it. The other three
files in the folder are as in beta3.

Going back: make v0.41-beta3 (and put its `FILMROLL.BIN` back) or v0.40.3 and copy its `DCOLYMP`.

If something looks wrong, please open an issue with a [debug log](../../debug-log/README.md).
