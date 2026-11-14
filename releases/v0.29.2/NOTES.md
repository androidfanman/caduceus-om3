# Caduceus for OM-3 v0.29.2

**v0.29.1 with one fix: custom modes (C1–C5) now work with your films.** Firmware camera-tested (2026-11-14, build k6;
only its name was changed to v0.29.2).

**Fixed** ([#41](https://github.com/androidfanman/caduceus-om3/issues/41))
- **Custom modes no longer change your films.** Turning the mode dial to a custom mode swaps in the picture settings
  saved in it. Before, your film stayed selected, so the camera shot the film mixed with those settings, and the next
  film you picked saved them into the film you left (it got a "*"). Now each film keeps its own settings in every mode.
- **Each custom mode brings back the films it was assigned with.** When you Assign a custom mode (Shooting menu 1 ›
  Custom Mode › C1–C5 › Assign › Set), the films you're using then (and which COLOR you're on) are kept with it.
  Turning to that custom mode brings them back right away; turning back to P / A / S / M brings back the films you had
  there. Also after switching off and on, even with the dial moved while the camera was off.
- **Save Settings: Hold** is followed too: a custom mode set to Hold keeps the films you pick while in it; one set to
  Reset (the camera's default) goes back to its assigned films when you leave it.
- **Recall** (Custom Mode › C1–C5 › Recall) brings that custom mode's films into the mode you're in.
- The Creative Dial's own film memory (v0.27) now only acts when you turn the Creative Dial, so it no longer undoes a
  custom mode's films.

**After updating:** assign your custom modes once more (Shooting menu 1 › Custom Mode › Cn › Assign › Set) so they
note their films; custom modes assigned before v0.29.2 keep the films you're on.

**Make it and copy it:** run the launcher and press Return (or `python3 firmware/patch.py --release v0.29.2`). Copy only
`DCOLYMP` and flash it (hold OK, then switch the camera on). Your films stay in the camera.

Everything else, including the optional extras (`LOOKS.BIN` with the colour-matched standard 20, `DEBUG.TXT`, the photo
code kit), is as in [v0.29.1](../v0.29.1/NOTES.md). Going back: make v0.29.1 and copy its `DCOLYMP`; the films stay in
the camera either way.

The files here are the patch (only the bytes Caduceus for OM-3 adds; no OM firmware), the optional extras and the
expected checksums. Full list of changes: [CHANGELOG](../../CHANGELOG.md#v0292).
