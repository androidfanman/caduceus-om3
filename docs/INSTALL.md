# Install Caduceus for OM-3

> [!WARNING]
> This is an unofficial, experimental change to the camera's firmware. You use it at your own risk (see
> [Safety](../README.md#safety)). Read this page once all the way through before you start.

Installing takes about 15 minutes. You make the update file on your computer, copy it to the SD card, and the camera
installs it from the card. You can go back to the camera's own firmware at any time.

## Before you start

You need:

- **An OM SYSTEM OM-3 on firmware 1.1.** To check, open the camera's menu: *Setup › Firmware*. If it shows another
  version, update the camera to 1.1 with OM Workspace first. Other cameras don't work.
- **A fully charged battery.** The camera must not switch off while it installs.
- **An SD card.** Your photos on it are not touched, but back them up anyway.
- **A computer** (Mac, Windows or Linux) with an internet connection.

<!-- picture: the camera's Setup › Firmware screen showing 1.1 -->

## Step 1. Download Caduceus

1. Open the [project page on GitHub](https://github.com/androidfanman/caduceus-om3).
2. Click the green **Code** button, then **Download ZIP**.
3. Unzip the file anywhere, for example on your Desktop. You get a folder called `caduceus-om3-main`.

<!-- picture: GitHub's Code button with Download ZIP -->

## Step 2. Make the update file

OM's licence doesn't allow anyone to share their firmware. So the update file is made on your own computer, from OM's
official OM-3 firmware 1.1. A small program (the "launcher") does this for you: it downloads OM's file from OM's own
server, checks it, adds the Caduceus changes and checks the result.

**On a Mac**

1. In the unzipped folder, right-click **`Make SD card files (Mac).command`** and choose **Open**. (The first time,
   macOS warns that it's from an unidentified developer. Right-clicking and choosing Open lets it run. If macOS still
   blocks it, open *System Settings › Privacy & Security*, scroll down and click **Open Anyway**.)
2. If macOS offers to install the *Command Line Tools*, accept, wait until they're installed, then do step 1 again.
   They include Python, which the launcher needs.
3. A Terminal window opens and asks which version to make. Press **Return** for the newest.
4. Wait until it says **Done**, then press any key to close the window.

**On Windows**

1. Install Python from [python.org](https://www.python.org/downloads/). In the installer, tick **Add python.exe to
   PATH** before you click Install.
2. In the unzipped folder, double-click **`Make SD card files (Windows).bat`**. If Windows SmartScreen warns, click
   **More info**, then **Run anyway**.
3. It asks which version to make. Press **Enter** for the newest.
4. Wait until it says **Done**, then close the window.

**On Linux:** in the unzipped folder, run `python3 firmware/patch.py`.

The launcher makes a new folder, **`SD card files`**, next to it:

```
SD card files/
  DCOLYMP/      the update for the camera        → copy to the card
  OM3MOD/       Caduceus's files                 → copy to the card
  restore/      the camera's original firmware   → keep (to undo Caduceus)
  VERSION.txt   which version you made
```

If it says **Stopped** instead of Done, nothing was written: see [If something goes wrong](#if-something-goes-wrong).

<!-- picture: the launcher window showing Done -->

## Step 3. Copy the files to the SD card

1. Put the camera's SD card in your computer.
2. Copy the **`DCOLYMP`** and **`OM3MOD`** folders from `SD card files` to the **top of the card**, next to the
   `DCIM` folder (not inside it).
3. **Get the films.** The 20 film sims are a separate file, `LOOKS.BIN`. Download it from the
   [latest release](https://github.com/androidfanman/caduceus-om3/releases/latest) (under *Assets*), or make your own in
   the [Control Panel](https://androidfanman.github.io/caduceus-om3/). Put it in the card's **`OM3MOD`** folder.
4. Eject the card properly before you take it out.

The card should now look like this:

```
DCIM/
DCOLYMP/E1479999.BIN
OM3MOD/GUIDES.BIN
OM3MOD/LABELS.BIN
OM3MOD/TONES.BIN
OM3MOD/LOOKS.BIN
```

<!-- picture: the SD card's folders in Finder / Explorer -->

## Step 4. Update the camera

1. Put the card in the camera. Check the battery is **fully charged**. Switch the camera **off**.
2. **Hold the OK button** and switch the camera **on**. Keep holding OK until the update starts.
3. The light stays **on (steady)** while the update is written. This takes about **two minutes**.
   **Don't switch off, open the battery door or take the card out.**
4. When the light starts **blinking**, it's finished. Switch the camera off.

If the light blinks straight away, without a steady phase, the camera didn't accept the file and nothing changed. Make
the files again (step 2), copy them again (step 3) and try once more.

<!-- picture: the camera's light during and after the update -->

## Step 5. Tidy the card and start shooting

1. Put the card back in your computer and delete **`DCOLYMP/E1479999.BIN`**, so the camera isn't updated again by
   accident. **Keep the `OM3MOD` folder**: your films and changes live there.
2. Put the card in the camera and switch it on.
3. Turn the mode dial to the COLOR position and open **Picture Mode**. After COLOR 1–4 you'll find **FILM 1–20**.

Next: [how to use it](USING.md).

## Updating from an earlier version

Do steps 1–5 again with the new version. On the card:

- **Replace** `GUIDES.BIN`, `LABELS.BIN` and `TONES.BIN` in `OM3MOD` with the new ones. `GUIDES.BIN` is made for
  each firmware version: always copy it together with the firmware.
- **Keep** `LOOKS.BIN`, `EDITS.BIN` and `BUNDLES.BIN`: they hold your films and your changes. Only copy a new
  `LOOKS.BIN` if you want the new film sims: it replaces your films.

## Going back to an older version

Run the launcher again and type the version you want instead of pressing Return (all versions are listed in
[releases](../releases/README.md)). Copy `DCOLYMP` and the version's own `GUIDES.BIN`, `LABELS.BIN` and `TONES.BIN`
to the card, and update the camera as in step 4. Your films keep working.

On v0.26.1 and older, half-press the shutter once after switching on: that's when those versions load your films.

## Going back to the camera's own firmware

1. Copy `restore/E1479999.BIN` from your computer's `SD card files` folder into the card's `DCOLYMP` folder.
2. Update the camera exactly as in [step 4](#step-4-update-the-camera).
3. If you like, delete the `OM3MOD` folder: the camera's own firmware ignores it.

The camera is then exactly as it came from OM, on firmware 1.1.

## If something goes wrong

**The camera freezes or switches off.** Take the battery out for a few seconds. Then check that the firmware and
`OM3MOD/GUIDES.BIN` come from the same version (`VERSION.txt` in `SD card files` says which one you made). If it keeps
happening, turn Film Grain off on that film and [tell us](https://github.com/androidfanman/caduceus-om3/issues), with
your `OM3MOD` files if you can.

**Holding OK doesn't start the update.** Check that the file is at `DCOLYMP/E1479999.BIN` at the top of the card (not
inside another folder), that the battery is full, and that you hold OK *before* switching on.

**There are no films in Picture Mode.** Check that `OM3MOD/LOOKS.BIN` is on the card (step 3). If it is, it may be
damaged: download it again, or save it again from the Control Panel.

**Settings change on the camera but the photo doesn't.** The card's `GUIDES.BIN` isn't the one made with this
firmware. Copy it again from `SD card files/OM3MOD`.

**My changes don't stay.** They're saved at the next half-press, and only when the card has the `OM3MOD` folder at its
top level. A locked or full card can't be written.

**The launcher says "Stopped: this is not the official …".** The firmware file it found is damaged, renamed or for
another camera. Delete it and run the launcher again, so it downloads a fresh copy.

**The launcher says "Stopped: download failed" or "OM server offered …".** OM's server couldn't be reached, or it now
offers another firmware version. Get the official OM-3 1.1 file (`OLY_E_147_1100_0000_0000.BIN`) another way, put it
in Downloads or next to the launcher, and run the launcher again.

**On a Mac, nothing happens when I open the launcher.** Open Terminal, type `cd ` (with a space), drag the unzipped
folder onto the Terminal window, press Return, then type `python3 firmware/patch.py` and press Return.

**Something else.** Copy the card's `OM3MOD` folder to your computer (your films are in it), delete it from the card
and switch on again. If that doesn't help, [go back to the camera's own firmware](#going-back-to-the-cameras-own-firmware).

## Questions

**Will a new version lose my films?** No, as long as you keep `LOOKS.BIN`, `EDITS.BIN` and `BUNDLES.BIN` on the card
(see [Updating](#updating-from-an-earlier-version)).

**Does it change the Monochrome profiles?** No. Caduceus works on COLOR 1–4 and the films. MONO keeps the camera's own
settings.

**Can I share films?** Yes. Send a `LOOKS.BIN`, or use **Share** in the Control Panel to send a link. Copying a
`LOOKS.BIN` onto a card replaces all the films on that camera.

**Why do I have to make the update file myself?** OM's licence doesn't allow sharing their firmware. This project only
publishes its own changes, and the launcher adds them to your copy of OM's file.

**I'm coming from v0.16–v0.18.** Your films were in `PROFILES.BIN`: rename it to `LOOKS.BIN`.
