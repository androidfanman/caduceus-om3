# Caduceus for OM-3 v0.40.3

**Halation Radius, faster Halation, separate WB shifts for films and the camera's own picture modes, and four fixes.**
Everything from the v0.40.3 test versions (beta, beta2, beta3, beta4), camera-tested in each of them; this package is
v0.40.3-beta4's firmware under its release name (2026-11-23).

**New since v0.40.2**
- **Halation Radius** (by fernandezk26, discussion #92): a new Picture Mode row under Halation Effect. **Bloom** is
  v0.40's halo and stays the default; **Tight**, **Medium** and **Wide** spread the glow about 32, 64 and 128 pixels
  from bright lights. The radius is separate from Halation's strength, and each film keeps its own. Film Grain, Grain
  Size and Border are one row further down. LookLab can't set the radius yet (its preview stays Bloom).
- **Faster Halation:** the work every Halation photo pays is about half what it was, and photos look exactly as in
  v0.40.2. In a burst, photos with Halation save sooner.
- **Films and the camera's own picture modes keep their WB shifts apart
  ([#99](https://github.com/androidfanman/caduceus-om3/issues/99), reported by crombach):** each film and COLOR has
  one WB compensation (A-B / G-M) of its own, and the camera's own setting is only ever the camera's: Caduceus never
  writes it.
  - On a film, the super control panel's White Balance screen and Picture Mode's WB row show the film's shift. A
    change there goes straight into the film (it gets its "*"; resetting the film brings its own back). Live view and
    your photos use the film's shift in place of the camera's.
  - On the camera's own modes (Natural, Vivid…), everything is as on a stock camera.
  - No half-press is needed, and nothing of ours runs at a Creative Dial turn or a film pick for the WB shift.
  - **After updating from v0.40.1 or later, set the camera's own shift once:** the camera may still hold a film's
    shift in its own setting. On the camera's own modes, open the WB screen and set the compensation you want there
    (0 if you never set one). Films keep theirs.
  - On a film with a shift, the WB menu shows a "*" on every WB mode: the film's one shift applies on all of them.
    Your shifts and photos are right.

**Fixed**
- **No shut-down with Film Grain on Drive Priority
  ([#91](https://github.com/androidfanman/caduceus-om3/issues/91), found by fernandezk26):** with Film Grain on,
  Sequential drive and JPEG only, the camera switched itself off on the first photo at ISO 1600 and below when Low ISO
  Processing was Drive Priority. Photos with Film Grain now get the camera's Detail processing, as single shots
  already do. On Drive Priority, long bursts with grain may slow down a little sooner.
- **Magnify and the Image Aspect screen in the crop modes
  ([#97](https://github.com/androidfanman/caduceus-om3/issues/97), reported by 6pwnbvfdcb-collab):** in 5:4, XPan and
  21:9, Magnify and MF Assist gave a black screen and the camera got stuck. They now work (5:4 uses 4:3's magnify
  area, XPan and 21:9 use 16:9's), and the Image Aspect screen shows each crop's name and sizes.
- **Playback shows each photo's own film
  ([#93](https://github.com/androidfanman/caduceus-om3/issues/93)):** after switching a COLOR to another film, older
  photos no longer show the new film's name. A photo taken on a COLOR with no film shows "COLOR n".
- **Delete's long press ([#101](https://github.com/androidfanman/caduceus-om3/issues/101), reported by
  ourparhelion-collab):** a function on the Delete button does on a long press what it does on AF-ON (for example,
  Keystone Compensation turns off). Playback's Delete still erases.

**Not fixed:** on ▲ ▼ ◀ ▶ a long press still does nothing: the camera never reports a long press on the arrows.

**Firmware Version screen:** shows "Caduceus : 0.40.3". The debug log also records Halation's slowest photo and the
Low ISO Processing setting.

**Start-up:** nothing of ours runs while the camera starts. Video is unchanged.

**LookLab** (already on the site since 2026-11-21): Open… reads `CURVES.BIN` and look `.json` files, and "+ Your
photos" takes up to 12 photos at once.

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.40.3`). Copy
`DCOLYMP` and flash it (hold OK, then switch the camera on; it can take up to about five minutes). Your films,
changes, custom modes, button settings and screen-info choices stay in the camera. **Coming from v0.29.x or older?**
Also put `CURVES.BIN` in the `OM3MOD` folder for the regraded films.

Going back: make v0.40.2 and copy its `DCOLYMP`.

The files here are the patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the optional extras
(`CURVES.BIN`, `LOOKS.BIN`, `DEBUG.TXT` and the photo code kit, as in v0.40.2) and the expected checksums.
Full list of changes: [CHANGELOG](../../CHANGELOG.md#v0403).
