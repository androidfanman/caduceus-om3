# Questions and answers

Short answers to what people ask most. Something missing? Ask in
[GitHub issues](https://github.com/androidfanman/caduceus-om3/issues).

## Before you install

### Which cameras does it work on?

Only the **OM SYSTEM OM-3 on firmware 1.1**. To check, open *Setup › Firmware* on the camera. For the Olympus PEN
E-P7 there's a sister project, [Caduceus for the E-P7](https://github.com/cakelesscoder/caduceus-ep7). Other cameras
aren't supported.

### Is it safe for my camera?

It's experimental, so there's some risk: it can crash or freeze the camera, and you use it at your own risk. Every
change is tested in an emulator of the camera before it goes on a real OM-3, and the camera's own SD card update is
proven for both installing and going back. You can always go back to the camera's own firmware. See
[Safety](../README.md#safety).

### What about my warranty?

It's an unofficial change to the camera's firmware, so it may affect your warranty with OM Digital Solutions. Going
back to the official firmware puts the camera exactly as it came from OM.

### Why do I have to make the update file myself?

OM's licence doesn't allow anyone to share their firmware. This project only publishes its own changes, and the
launcher adds them to your copy of OM's official file. It downloads that file from OM's own server for you.

### Can I go back to the camera's own firmware?

Yes, at any time: see [going back](INSTALL.md#going-back-to-the-cameras-own-firmware). It takes about two minutes.

## Films and settings

### Does it change the Monochrome profiles?

No. Caduceus works on COLOR 1–4 and your films, FILM 1–20. The Monochrome profiles keep the camera's own settings.

### Does it work for video?

Not yet: video keeps the camera's normal look. Films in video are on the
[roadmap](https://androidfanman.github.io/caduceus-om3/roadmap/), after the photo side is finished.

### What does the `*` mean?

Something has changed. After FILM n, something differs from how the film was built. After COLOR n, something differs
from the camera's factory settings. A row with its own `*` is one of the changes. **Hold OK** on the film (or the
COLOR) to put it back.

### Can I use my own presets or LUTs?

Not directly. Films are made only from the camera's own settings (colours, tone, WB shift and so on), so a LUT or a
Lightroom preset can't be loaded. You can rebuild a look in the [Control Panel](https://androidfanman.github.io/caduceus-om3/)
with its preview, or have an AI assistant build one from a photo you like with
[these instructions](PHOTO_TO_LOOK.md).

### Can I share films?

Yes. Send a `LOOKS.BIN`, or use **Share** in the Control Panel to send a link. Copying a `LOOKS.BIN` onto a card
replaces all the films on that camera.

### Does grain slow the camera down?

No. Film Grain is added by the camera's own image processor while it develops the photo, in colour, with no extra
wait.

## Updating

### Will a new version lose my films?

No. When you update, keep `LOOKS.BIN`, `EDITS.BIN` and `BUNDLES.BIN` on the card, and copy the new `GUIDES.BIN`,
`LABELS.BIN` and `TONES.BIN` with the new firmware. See [updating](INSTALL.md#updating-from-an-earlier-version).

### I'm coming from v0.16–v0.18.

Your films were in `PROFILES.BIN`: rename it to `LOOKS.BIN`.

### Do I still need to half-press after switching on?

Not from v0.26.2: your films load by themselves a moment after the camera starts. On v0.26.1 and older, half-press
once after switching on.

## Problems

### There are no films in the Picture Mode list.

Check that `OM3MOD/LOOKS.BIN` is on the card (step 3 of the [install guide](INSTALL.md#step-3-copy-the-files-to-the-sd-card)).
If it is, it may be damaged: download it again, or save it again from the Control Panel.

### A setting changes on the camera but the photo doesn't.

The card's `GUIDES.BIN` must come from the same version as the firmware. Copy it again from the `SD card files`
folder the launcher made.

### The camera froze or switched off after a photo.

Take the battery out for a few seconds. Check that the firmware and `OM3MOD/GUIDES.BIN` come from the same version
(`VERSION.txt` in `SD card files` says which one you made). If it happens again, turn Film Grain off on that film and
[tell us](https://github.com/androidfanman/caduceus-om3/issues), with your `OM3MOD` files if you can. Reports being
looked into are listed under Bugs on the [roadmap](https://androidfanman.github.io/caduceus-om3/roadmap/).

### My changes were lost.

They're saved at the next half-press, and only when the card has the `OM3MOD` folder at its top level. A locked or
full card can't be written.

### Something else is wrong.

See [if something goes wrong](INSTALL.md#if-something-goes-wrong) in the install guide, or
[ask in GitHub issues](https://github.com/androidfanman/caduceus-om3/issues).
