# Installing Caduceus for OM-3

> [!WARNING]
> Unofficial, experimental firmware modification: use at your own risk (see [Safety](../README.md#safety)). Read this
> page once all the way through before you start.

## Quick version

1. **Code › Download ZIP** on the project page, unzip it.
2. Double-click `Make SD card files (Mac).command` (Mac, first time: right-click › **Open**) or
   `Make SD card files (Windows).bat`.
3. Copy `SD card files/DCOLYMP` and `SD card files/OM3MOD` to the top of the SD card.
4. Camera off, full battery: **hold OK and switch on**. Steady light = writing (about two minutes, don't touch
   anything); blinking = done. Switch off and on again.
5. Delete `DCOLYMP/E1479999.BIN` from the card, keep `OM3MOD`.
6. Switch on (before v0.26.2: half-press once after every power-on), then Picture Mode › COLOR 1–4 › **▼**: the wheel opens on the Looks
   page, and **INFO** steps through the others.

To undo: flash `SD card files/restore/E1479999.BIN` the same way.

## Requirements

- An **OM SYSTEM OM-3 on firmware 1.1**: *Setup › Firmware* shows the version. If it shows anything else, update to
  1.1 with OM Workspace first, or wait for a matching release of this project. Other cameras are not supported.
- A **fully charged** battery.
- An SD card (any card the camera takes). Your photos on it are not touched, but back them up anyway.
- A computer with **Python 3.8 or newer**: Windows, macOS or Linux.
- The official firmware 1.1 file, `OLY_E_147_1100_0000_0000.BIN` (a copy downloaded earlier may be named
  `OLY_E_147_1100_0000_0000_3.BIN`: the same file, either name works). The patcher fetches it from OM's update server
  for you; you only need it yourself if that fails (see [Troubleshooting](#troubleshooting)).

## Get the files and Python

1. On the project page click **Code › Download ZIP**, then unzip it anywhere (Desktop is fine). Or `git clone` it.
2. Python:
   - **Mac:** nothing to do in advance. The first time you double-click the launcher, macOS may offer to install the
     *Command Line Tools*, which include Python 3: accept, wait for it to finish, then double-click the launcher again.
   - **Windows:** install Python from [python.org](https://www.python.org/downloads/). In the installer, tick
     **Add python.exe to PATH**.
   - **Linux:** Python 3 is almost always installed already.

## Make the update file

Double-click the launcher in the unzipped folder:

- **Mac:** `Make SD card files (Mac).command`. The first time, macOS says it's from an unidentified developer: close
  that, **right-click › Open**, then **Open** again. A Terminal window shows the progress.
- **Windows:** `Make SD card files (Windows).bat`. If Windows SmartScreen warns, click **More info › Run anyway**.
- **Terminal / command prompt** (any system), in the unzipped folder: `python3 firmware/patch.py`
  (Windows: `py firmware\patch.py`). Options: `--release v0.16` for an earlier version, `--stock FILE` to use a
  firmware file you have, `--out DIR` for another output folder.

The launcher asks which version to make: press Return for the newest, or type an older one (for example `v0.16`).
All versions are listed in [releases](../releases/README.md); `SD card files/VERSION.txt` says which one you made.

What it does:

1. Finds the official file: next to the launcher, in the project folder or in Downloads. If it isn't there, it asks
   OM's update server for it, the way OM Workspace does, and keeps a copy in the project folder for next time.
2. Checks the file's size and SHA-256 against the official OM-3 1.1 firmware. **Any other file is refused.**
3. Applies the chosen release's patch (`releases/vX/patch.json`: only the bytes this project adds, nothing of OM's;
   from v0.20 it also draws the white Frame pictures itself), rebuilds the
   update package and checks the result against its expected SHA-256.
4. Writes the folder **`SD card files`** next to the launcher:

```
SD card files/
  DCOLYMP/E1479999.BIN   the patched firmware update        → copy to the card
  OM3MOD/GUIDES.BIN      the page labels + Extras code       → copy to the card
  OM3MOD/LABELS.BIN      the Extras labels (v0.20)           → copy to the card
  OM3MOD/TONES.BIN       the split toning guides (v0.26)     → copy to the card
  restore/E1479999.BIN   the official firmware 1.1           → keep on your computer
```

"Done" at the end means everything checked out. "Stopped: …" says what was wrong; nothing is written then.

## Copy to the card

1. Put the camera's SD card in your computer.
2. Copy the **`DCOLYMP`** and **`OM3MOD`** folders from `SD card files` to the **top level** of the card, next to
   `DCIM`. If the card already has an `OM3MOD` folder from an earlier version, keep its `LOOKS.BIN`, `NAMES.BIN`
   and `BUNDLES.BIN` (your looks and edits) and replace `GUIDES.BIN`, `LABELS.BIN` and `TONES.BIN` with the new ones. From v0.20
   `GUIDES.BIN` carries code for that exact firmware: always copy it with the firmware.
3. Eject the card properly before taking it out.

The card should look like this:

```
DCIM/
DCOLYMP/E1479999.BIN
OM3MOD/GUIDES.BIN
OM3MOD/LABELS.BIN
OM3MOD/TONES.BIN
```

## Flash

1. Card in the camera, **battery fully charged**, camera **off**.
2. **Hold OK** and switch the camera **on**. Keep holding OK until the update starts.
3. The light stays **steady** while the firmware is written: about **two minutes**. **Don't switch off, open the
   battery door or remove the card** during this time.
4. When the light starts **blinking**, it's done. Switch the camera off.
5. Switch on normally.
6. On a computer, delete `DCOLYMP/E1479999.BIN` from the card so it isn't flashed again by accident. **Keep
   `OM3MOD`.**

If the light blinks straight away with no steady phase, the camera most likely rejected the file without writing
anything (that is how the same updater behaves on the E-P7): make the files again, copy them again and retry.

## First use

1. Switch on. Your settings load from the card by themselves a moment after the camera starts (v0.26.2). Before
   v0.26.2: **half-press the shutter once**; until then the wheel works exactly as stock.
2. Picture Mode › **COLOR 1** (or 2–4) › press **▼** to open the Color Profile wheel.
3. It opens on the **Film** page with the selected look's name. Press **INFO** for the others: Saturation →
   Saturation (All) → **Hue** → **Light** → **Extras** → back to **Film**. The label under the wheel names the page.
4. Change something, leave the editor and **half-press**: it's saved to `OM3MOD` on the card. To keep changes in the
   selected look, go back to the Film page and **hold OK** first (turning to another look without that drops them).

To bring in looks from the [Control Panel](https://androidfanman.github.io/caduceus-om3/) (OM SYSTEM OM-3 selected at
the top): save `LOOKS.BIN` and `NAMES.BIN` there, put them in the card's `OM3MOD` folder, then on the Film page turn the 12 o'clock spot to 1–5. See
[USING.md](USING.md) for every page.

## Restore stock firmware

1. Copy `SD card files/restore/E1479999.BIN` (the official file the patcher saved) into the card's `DCOLYMP` folder,
   replacing the patched one.
2. Flash it exactly as in [Flash](#flash).
3. Optionally remove the `OM3MOD` folder: stock firmware ignores it.

The camera is then completely stock 1.1. Your COLOR profiles keep the camera's own settings (Saturation, Contrast and
so on); the Hue, Light and Extras values only exist while Caduceus for OM-3 is installed. The stock Frame Art
Effect gets its original picture back too.

## Troubleshooting

**"Stopped: this is not the official OLY_E_147_1100_0000_0000_3.BIN"**: the file is damaged, renamed from another
version, or for another camera. Delete it and run the launcher again so it downloads a fresh copy.

**"Stopped: download failed" / "OM server offered …"**: OM's server couldn't be reached, or it now offers a newer
firmware this patch doesn't support. Get the official OM-3 **1.1** file another way, put it next to the launcher or
in Downloads under its official name, and run the launcher again.

**Mac: nothing happens / "permission denied" on the launcher**: open Terminal, type `cd ` (with a space), drag the
unzipped folder onto the Terminal window, press Return, then run `python3 firmware/patch.py`.

**The camera doesn't start the update when I hold OK**: check the file is at `DCOLYMP/E1479999.BIN` on the card's
top level (not inside another folder), the battery is full, and you hold OK *before* switching on.

**The new pages don't appear**: half-press once after switching on (needed before v0.26.2). If they still don't, check *Setup › Firmware*
says 1.1 and that the flash finished (steady, then blinking).

**My changes don't stay**: they save at the next half-press, and only when the card has an `OM3MOD` folder at its top
level. A locked or full card can't be written. Changes to a look stay in the look only after **holding OK on the Film
page**; turning to another look without that puts the look back as it was saved.

**The Extras values change but the photo doesn't**: the card's `GUIDES.BIN` isn't the one made with this firmware
(it carries the Extras code). Copy the release's `GUIDES.BIN` again. **The Extras label says "Vivid"**: copy
`LABELS.BIN` too.

**The Film page is missing**: the card's `LOOKS.BIN` failed the camera's check (damaged or edited by hand), so
the camera ignored it and left it alone. Open it in the Control Panel and save it again, or delete it: with no file, the
camera starts a fresh, neutral bank. Went back to v0.20 or older? Those can't read a `LOOKS.BIN` with Grain or the
lens correction set: in the Control Panel's Export, choose **v0.20 or older** and save it again.

**Something else is wrong**: remove the `OM3MOD` folder (copy it to your computer first: your settings are in it) and
switch on again. If that doesn't help, [restore stock firmware](#restore-stock-firmware).

## FAQ

**Will updating to a new version lose my looks?** No. Flash the new firmware the same way and keep the card's
`OM3MOD/LOOKS.BIN` and `BUNDLES.BIN`, and copy the new `GUIDES.BIN`, `LABELS.BIN` and `TONES.BIN`. Coming from v0.16–v0.18,
where the bank was called `PROFILES.BIN`: rename it to `LOOKS.BIN` (same format). (v0.19 read `PROFILES.BIN` by
itself; v0.20 needed that room for the Extras.) Looks saved by v0.19 or earlier have every Extras value at 0, and
looks from v0.20 have Grain off and the lens correction as before.

**Does it change the Monochrome profiles?** No. Only COLOR 1–4. The MONO profiles keep the camera's own editor.

**Can I share looks?** Yes: send a `LOOKS.BIN`, or use **Share looks** in the Control Panel to send a link.
Copying one onto a card replaces that camera's whole bank.

**Can I use Caduceus looks?** Yes: it's the same Control Panel. In OM-3 mode, **Paste code** takes Caduceus look
codes and pack links, and **Open…** takes packs and E-P7 `LOOKS.BIN` files; each colour look becomes an OM-3 look.

**Why do I have to make the file myself?** OM's licence doesn't allow sharing their firmware, so this project only
publishes its own changes and the patcher applies them to your copy of the official file.
