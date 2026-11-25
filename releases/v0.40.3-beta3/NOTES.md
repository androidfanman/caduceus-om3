# Caduceus for OM-3 v0.40.3-beta3 (test version)

**Four fixes on top of v0.40.3-beta.** A test version (a GitHub pre-release): v0.40.2 stays the current version.
Camera-tested on an OM-3 (2026-11-21) as test build f9; this package is that build under its release name.
It replaces **v0.40.3-beta2**, which was withdrawn: on some start-ups it could get stuck restarting (a boot loop), and
a film change after the Creative Dial's centre could restart the camera. Both are fixed here.

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
- **The camera's own picture modes keep their own WB compensation (#99, reported by crombach):** since v0.40.1 a
  film's WB Compensation stayed on when you turned the Creative Dial to the camera's own modes (Natural, Vivid…).
  - Now each white balance mode's compensation comes back as it was there, and a change you make there is theirs.
  - It's kept over a power-off, and each custom mode (C1–C5) keeps its own.
  - Films keep their own compensation, as in v0.40.1. COLOR 1–4 without a film count as films. Video is unchanged.
  - The switch happens at the first half-press after you turn the dial. A WB change you make before that half-press
    stays where you made it: on the camera's modes it stays theirs, and on a film it stays the film's (it gets its "*").
  - The first time after updating, the camera's modes may start with no compensation (nothing saved yet).
- **Delete's long press (#101, reported by ourparhelion-collab):** a function on the Delete button now does on a
  long press what it does on AF-ON. For example, Keystone Compensation turns off when you hold Delete. This holds for
  every function: with Magnify on Delete, holding it opens the frame and then closes it, as on AF-ON. Playback's
  Delete still erases.
- **Firmware Version screen:** shows "Caduceus : 0.40.3-b3".

**Not fixed:** on ▲ ▼ ◀ ▶ a long press still does nothing. The camera never reports a long press on the arrows, so
functions that turn off or open their settings with a long press (Keystone Compensation, Magnify, Multi Function,
HDR, Live ND, High Res) work fully only on Delete, AF-ON, Fn and the camera's other function buttons.

**Start-up:** nothing of ours runs while the camera starts.

Everything else is as in [v0.40.3-beta](../v0.40.3-beta/NOTES.md).

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.40.3-beta3`).
Copy `DCOLYMP` and flash it (hold OK, then switch the camera on). Your films, changes, custom modes, button settings
and screen-info choices stay in the camera. **Coming from v0.29.x or older?** Also put `CURVES.BIN` in the `OM3MOD`
folder for the regraded films.
