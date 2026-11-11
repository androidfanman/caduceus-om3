# Sending a debug log

If something goes wrong with Caduceus for OM-3 (v0.27 or later), a debug log tells us what the camera loaded.

1. **Download [`DEBUG.TXT`](https://github.com/androidfanman/caduceus-om3/releases/latest/download/DEBUG.TXT)**
   (or the [`DEBUG.TXT`](DEBUG.TXT) in this folder: open it, then *Download raw file*).
2. Put it in the card's **`OM3MOD`** folder (next to `GUIDES.BIN` and `LOOKS.BIN`).
3. Put the card in the camera, switch on, and use it until the problem happens. Half-press the shutter a few times.
4. Put the card back in your computer: there is now an **`OM3MOD/CADLOG.TXT`**. Attach it to your report in
   [Issues](https://github.com/androidfanman/caduceus-om3/issues).
5. **Delete `DEBUG.TXT` from the card** afterwards, so the camera stops writing the log.

The log is plain text: the firmware build, which card files loaded and whether each one matches the firmware, the
picture mode and film, the last save result and the last 32 shutter-button events. It holds no photos and nothing
personal. The contents of `DEBUG.TXT` don't matter: the camera only checks that it's there.

**No `CADLOG.TXT` after switching on and half-pressing?** Then the camera isn't running Caduceus v0.27 or later: the
update didn't install. See [Install, step 4](https://androidfanman.github.io/caduceus-om3/pages/install/#step-4-update-the-camera).
