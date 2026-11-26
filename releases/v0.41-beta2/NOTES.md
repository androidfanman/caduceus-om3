# Caduceus for OM-3 v0.41-beta2 (test version)

**Film Rolls: shoot your OM-3 like a roll of film. Plus XPan kept at start-up (#105) and the movie time as its own
screen-info row.** A test version (a GitHub pre-release): v0.40.3 stays the current version. Camera-tested on an OM-3
(2026-11-26) as test builds fr9 and test 39; this package is that build under its release name.

**New: Film Rolls (turn it on with its folder)**
- **Load:** on Picture Mode's film row, pick a film as always, then turn the rear dial for 24, 36 or 72 exposures. A
  canister on the right shows the film, its ISO and the length. The first photo starts the roll.
- **Shoot:** the shots-remaining number counts the frames left, on the rear screen and in the viewfinder. The film and
  the ISO stay the roll's: the film's box speed, at least 200 (COLOR 1-4: ISO 400).
- **No peeking:** Playback and Image Review wait for the rewind. A burst stops at the roll's last frame.
- **End and rewind:** at the end the shutter locks and a slip says so. Press OK: the film row opens, and the rear dial
  winds the roll back, two frames a click.
- **After:** the roll comes out, your own ISO comes back, Playback opens as normal, and the roll is listed in
  `OM3MOD/FILMROLL/ROLLS.TXT` (film, ISO, length, frames shot, photo numbers).
- The roll is kept on the card, so you can switch off in the middle of one. Video works as always and isn't counted.
- **Your own films:** in LookLab (on the site since 2026-11-26), Export › Film Rolls gives each film its own canister
  name, colour and ISO.
- How to use it: [docs/USING.md, Film Rolls](../../docs/USING.md#film-rolls).

**Fixed: XPan back to 16:9 (#105, reported by jirimachovec)**
- A half-press while the camera is still starting no longer lets XPan (or 21:9, 5:4) fall back to 16:9.
- A custom mode (C1-C4) saved with its own ratio keeps that ratio when you turn the dial to it.

**New: Remaining Movie Time as its own row**
- Custom menu › Information › Camera Info Settings › Information 1 / 2 / 3: **Remaining Files** now hides only the photos
  left, and a new row under it, **Remaining Movie Time**, hides only the video time.
- **Different from before:** if you had Remaining Files unticked, the video time shows again after flashing; untick
  Remaining Movie Time to hide it.

Everything else is as in [v0.41-beta](../v0.41-beta/NOTES.md).

**Firmware Version screen:** shows "Caduceus : 0.41-b2".

**Start-up:** nothing of ours runs while the camera starts. Film Rolls loads at the first half-press, and only with
its folder on the card. Video is unchanged.

**Make it and copy it:** run the launcher from this version's download and press Return (or
`python3 firmware/patch.py --release v0.41-beta2`). Copy `DCOLYMP` and flash it (hold OK, then switch the camera on;
it can take up to about five minutes). Your films, changes, custom modes, button settings and screen-info choices
stay in the camera.

**To try Film Rolls:** download `FILMROLL.zip` from the release (or take `releases/v0.41-beta2/FILMROLL` from the
download) and put the `FILMROLL` folder in the `OM3MOD` folder on the card. Its `FILMROLL.BIN` is made for this
firmware only. Without the folder the camera is a normal OM-3.

Going back: make v0.41-beta or v0.40.3 and copy its `DCOLYMP`. Other versions ignore the `FILMROLL` folder.

If something looks wrong, please open an issue with a [debug log](../../debug-log/README.md).
