# Caduceus for OM-3 v0.41-beta3 (test version)

**C5 keeps its own films again (#116, #117).** A test version (a GitHub pre-release): v0.40.3 stays the current
version. v0.41-beta2 plus the C5 fixes, camera-tested on an OM-3 (2026-11-26) as test build fix116-1; this package is
that build under its release name.

**Fixed: C5 showing the film of the mode before it (#116, #117, reported by zhaochanghaotw-boop)**
- The camera numbers C5 differently from C1-C4, and Caduceus didn't recognise C5's number. Since v0.30, turning the
  dial into C5 with the camera on left the previous mode's films in place (C5 -> C4 -> C5 showed C4's film). Switching
  on with the dial already on C5 was fine, so it came and went. Now C5 brings back its own films at every dial turn,
  like C1-C4. C1-C4 were not affected.
- **Save Settings: Hold on C5** now works: a film you pick while on C5 stays there. Before, C5 always acted as if set
  to Reset (C5 keeps that setting in a different place from C1-C4). **Different from before** if you had C5 on Hold.
- **Color Mix and the RGB curves in C5:** C5 photos didn't get them, so the regraded films didn't look like themselves
  there. Now they do, as in every other mode.
- **Film Rolls in C5:** a roll now counts frames and keeps its film in C5 too.

Everything else is as in [v0.41-beta2](../v0.41-beta2/NOTES.md), Film Rolls included.

**Firmware Version screen:** shows "Caduceus : 0.41-b3".

**Start-up:** nothing of ours runs while the camera starts. Video is unchanged.

**Make it and copy it:** run the launcher from this version's download and press Return (or
`python3 firmware/patch.py --release v0.41-beta3`). Copy `DCOLYMP` and flash it (hold OK, then switch the camera on;
it can take up to about five minutes). Your films, changes, custom modes, button settings and screen-info choices
stay in the camera.

**Film Rolls users:** take the new `FILMROLL.BIN` too (in `FILMROLL.zip` on the release, or
`releases/v0.41-beta3/FILMROLL`): it is made for this firmware only, and beta2's is not loaded by it. The other three
files in the folder are as in beta2.

Going back: make v0.41-beta2 (and put its `FILMROLL.BIN` back) or v0.40.3 and copy its `DCOLYMP`.

If something looks wrong, please open an issue with a [debug log](../../debug-log/README.md).
