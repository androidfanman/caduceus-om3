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
[roadmap](https://androidfanman.github.io/caduceus-om3/pages/roadmap/), after the photo side is finished.

### What does the `*` mean?

Something has changed. After FILM n, something differs from how the film was built. After COLOR n, something differs
from the camera's factory settings. A row with its own `*` is one of the changes. **Hold OK** on the film (or the
COLOR) to put it back.

### Can I use my own presets or LUTs?

Yes, as a starting point, in LookLab. Choose **From LUT / preset…** and pick a `.cube`
LUT or a Lightroom preset (`.xmp` or the older `.lrtemplate`). LookLab finds the camera settings that come
closest, shows your grade and the film side by side, and says how close they are. It's an approximation: the camera
has 12 colour sectors, a tone curve, a WB shift and split toning, while a LUT can do much more. LUTs made for Log
video are flagged, since they're far too strong on a photo. Your file stays on your computer.

You can also have an AI assistant build a look from a photo you like with [these instructions](PHOTO_TO_LOOK.md).

### Can I share films?

Yes. Send a `LOOKS.BIN`, or use **Share** in LookLab to send a link. Copying a `LOOKS.BIN` onto a card
replaces all the films on that camera (from v0.29 when the camera never had that set; it keeps the selection and Extras).

From v0.27 a JPEG taken on a FILM carries the film too: whoever has the photo can open it in LookLab
(**Open...**) and get the film. Sites can read it with the [developer kit](../devkit/photo-code/).

### Does grain slow the camera down?

No. Film Grain is added by the camera's own image processor while it develops the photo, in colour, with no extra
wait.

## Updating

### Will a new version lose my films?

No. From v0.29 your films and changes live in the camera, and an update of Caduceus keeps them. Updating to v0.29
from an older version, keep `LOOKS.BIN`, `EDITS.BIN` and `BUNDLES.BIN` on the card for the first start: the camera copies
them in once. See [updating](INSTALL.md#updating-from-an-earlier-version).

### Can I use any SD card?

From v0.29, yes: your films, your changes and the Extras are in the camera, and the rest is built into the firmware, so
a card with nothing of ours works in full. A card only brings new films in (`OM3MOD/LOOKS.BIN`), and only films the
camera never had. From v0.29.1 the films also load with no card in the camera. A Reset in the camera's menu or an OM firmware update probably clears the films from the camera:
keep a `LOOKS.BIN` of your films to bring them back.

### I'm coming from v0.16–v0.18.

Your films were in `PROFILES.BIN`: rename it to `LOOKS.BIN`.

### Do custom modes (C1–C5) keep my films?

Yes, from v0.29.2. When you Assign a custom mode (Shooting menu 1 › Custom Mode › Cn › Assign › Set), the films you're
using then are kept with it, and turning to it brings them back; P / A / S / M keep their own. A custom mode set to Save
Settings: Hold keeps the films you pick in it, one set to Reset goes back to its assigned films. Assign your custom modes
once after updating to v0.29.2.

### Do I still need to half-press after switching on?

Yes, once. From v0.27.1 your films load at the first half-press after switching on. v0.26.2 and v0.27 loaded them by
themselves, but that could rarely freeze the camera at start-up, so v0.27.1 went back to the half-press.

## Problems

### There are no films in the Picture Mode list.

Half-press the shutter once after switching on: that's when the films load. (With no card in the camera, v0.29 never
loaded them: update to v0.29.1.) The first time with v0.29 (or after a
Reset in the camera's menu), check that `OM3MOD/LOOKS.BIN` is on the card (step 3 of the [install guide](INSTALL.md#step-3-copy-the-files-to-the-sd-card))
and is exactly 1,632 bytes; if not, download it again, or save it again from LookLab. Then check the update
really went on: v0.27 adds rows called CRT, ART, COLOR and MONO to the camera's Button Function menu. If they aren't
there, flash again (install step 4). Still no films? Send us a [debug log](https://github.com/androidfanman/caduceus-om3/tree/main/debug-log).

### A setting changes on the camera but the photo doesn't.

Before v0.29: the card's `GUIDES.BIN` must come from the same version as the firmware; copy it again from the
`SD card files` folder the launcher made. From v0.29 it's built into the firmware: send a [debug log](https://github.com/androidfanman/caduceus-om3/tree/main/debug-log).

### The camera froze or switched off after a photo.

Take the battery out for a few seconds. Check that the firmware and `OM3MOD/GUIDES.BIN` come from the same version
(`VERSION.txt` in `SD card files` says which one you made). If it happens again, turn Film Grain off on that film and
[tell us](https://github.com/androidfanman/caduceus-om3/issues), with your `OM3MOD` files if you can. Reports being
looked into are listed under Bugs on the [roadmap](https://androidfanman.github.io/caduceus-om3/pages/roadmap/).

### My changes were lost.

From v0.29 they're kept in the camera: it saves when you go back to shooting from a menu or Picture Mode and when you
switch off, so pulling the battery right after a change can lose that change. Before v0.29 they were saved on the card
at the next half-press (a locked or full card can't be written).

### Can I send a log with a bug report?

Yes, from v0.27. Download [`DEBUG.TXT`](https://github.com/androidfanman/caduceus-om3/releases/latest/download/DEBUG.TXT) (also under *Assets* on the
[latest release](https://github.com/androidfanman/caduceus-om3/releases/latest)), put it in the card's `OM3MOD` folder, switch the camera on and use it until the problem happens. The
camera writes `OM3MOD/CADLOG.TXT`: attach it to your report. Then delete `DEBUG.TXT` from the card.

### Something else is wrong.

See [if something goes wrong](INSTALL.md#if-something-goes-wrong) in the install guide, or
[ask in GitHub issues](https://github.com/androidfanman/caduceus-om3/issues).
