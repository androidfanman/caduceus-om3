# Caduceus for OM-3 v0.40.3-beta2 (test version)

**Withdrawn (2026-11-20):** on some start-ups the camera could get stuck restarting (a boot loop), and a film change
after the Creative Dial's centre could restart it. Use [v0.40.3-beta3](../v0.40.3-beta3/NOTES.md), which fixes both.

**Three fixes on top of v0.40.3-beta.** A test version (a GitHub pre-release): v0.40.2 stays the current version.
Camera-tested on an OM-3 (2026-11-20) as test build fixes2; this package is that build under its release name.

**Fixed**
- **No shut-down with Film Grain on Drive Priority (#91, found by fernandezk26):** with Film Grain on, Sequential
  drive and JPEG only, the camera switched itself off on the first photo at ISO 1600 and below when **Low ISO
  Processing** was **Drive Priority**. Photos with Film Grain now get the camera's Detail processing, as single shots
  already do. Photos without grain are unchanged. On Drive Priority, long bursts with grain may slow down a little
  sooner, as on Detail Priority. The debug log shows the setting and how many photos were switched.
- **Magnify in the crop modes (#97, reported by 6pwnbvfdcb-collab):** in 5:4, XPan and 21:9, Magnify (and MF Assist)
  gave a black screen and the camera got stuck. It now works: 5:4 uses 4:3's magnify area, XPan and 21:9 use 16:9's,
  so at XPan and 21:9 the magnify frame can move a little above or below the strip.
- **The Image Aspect screen (#97):** scrolling onto 5:4, XPan or 21:9 showed "3:4" and lost the size list. It now
  shows each crop's name and sizes (for example 5184 x 1920 for XPan). The sizes appear from the first half-press.
- **The camera's own picture modes keep their own WB compensation (#99, reported by crombach):** since v0.40.1 a film's
  WB Compensation stayed on when you turned the Creative Dial to the camera's own modes (Natural, Vivid…). Now each
  white balance mode's compensation comes back as it was there, and a change you make there is theirs. As with the
  camera's own settings, it's kept over a power-off, and each custom mode (C1–C5) keeps its own. Films keep their own
  compensation, as in v0.40.1. COLOR 1–4 without a film count as films. Video is unchanged. The first time after
  updating, the camera's modes may start with no compensation (nothing saved yet).
- **Firmware Version screen:** shows "Caduceus : 0.40.3-b2".

**Start-up:** nothing of ours runs while the camera starts.

Everything else is as in [v0.40.3-beta](../v0.40.3-beta/NOTES.md).

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.40.3-beta2`).
Copy `DCOLYMP` and flash it (hold OK, then switch the camera on). Your films, changes, custom modes, button settings
and screen-info choices stay in the camera. **Coming from v0.29.x or older?** Also put `CURVES.BIN` in the `OM3MOD`
folder for the regraded films.
