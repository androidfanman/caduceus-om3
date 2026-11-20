# Using Caduceus for OM-3

This page is for **v0.40.2**, the latest version. Not installed yet? Start with [Install](INSTALL.md).

> [!NOTE]
> Caduceus works on the **COLOR** profiles (COLOR 1–4) and your **films** (FILM 1–20). The Monochrome profiles keep
> the camera's own settings.

## In one minute

- Your films are ready as soon as you switch on (from v0.30; earlier versions loaded them at the first half-press).
- Turn the creative dial to **COLOR** and open **Picture Mode**. After COLOR 1–4 the list shows your films,
  **FILM 1–20**. Pick one: its name becomes the big title, and the shooting screen and viewfinder show it.
- Change anything on the rows below: the film changes at once, and so does live view (from v0.40-beta split toning,
  Split Tone Balance, the RGB curves and B/W too; before, they showed after a half-press).
- Your changes stay with that film, even after you switch the camera off.
- **Hold OK** on a film to put it back the way it was built.

<!-- picture: Picture Mode list with FILM 1 (Portra 400) selected -->

## Choosing a film

1. Turn the creative dial to **COLOR**.
2. Open **Picture Mode** (from the super control panel or the menu).
3. The top row lists **COLOR 1–4, then FILM 1–20**. Turn to the film you want.

Your films load from the camera's own memory as it starts. New card files (a `LOOKS.BIN` or `CURVES.BIN`) are read at
the first half-press. The camera remembers the film you were on when you switch it off.

What each of the 20 film sims looks like: [the film sims](../README.md#the-20-film-sims).

From v0.40-alpha Picture Mode stays open 30 s when you leave it alone (8 s before); other screens still close after 8 s.

**Quicker:** on the super control panel, select the Picture Mode cell and turn a dial. It steps through COLOR 1–4, then
FILM 1–20.

<!-- picture: super control panel with the Picture Mode cell showing a film name -->

## Changing a film

The rows under Picture Mode change the film (or the COLOR) you're on, straight away:

| Row | What it does |
|---|---|
| **Color Mix** | Red, green and blue as dots on a ring: the rear dial makes the chosen colour stronger or weaker (Sat), the front dial turns it toward its neighbour (Hue), −7 to +7; **INFO** picks the colour. Greys stay grey. Photos only. |
| **RGB** | A tone curve for each of red, green and blue, five points from black to white: the front dial picks the point, the rear dial moves it (−7 to +7); **INFO** picks the colour. Photos only. |
| **Color wheel (HSL)** | The colour wheel: change each colour's saturation, hue and brightness, and split toning (see below). |
| **Split Tone Balance** | Where the split toning's two colours meet, −5 to +5: minus lets the shadow colour reach further up, plus the highlight colour further down. Only does something when the film has a split tone. |
| **WB Compensation** | Shifts the colour balance: A–B (amber to blue) and G–M (green to magenta), −7 to +7. It is the camera's own WB compensation for the film's white balance mode, so the super control panel's White Balance screen shows the same value. Press **OK** to open the camera's own grid; **MENU** or **OK** brings you back. |
| **Highlight & Shadow** | The camera's own tone curve: brighter or darker shadows, midtones and highlights. |
| **B/W** | Blacks and Whites on one grid, −7 to +7 each: left / right for Blacks, up / down for Whites. Plus lifts the blacks or brightens the whites; minus deepens or softens them. Press **OK** to open the grid; the row shows the values under its icon (e.g. +3/−2). |
| **Contrast** | The camera's own contrast. |
| **Sharpness** | −5 = off, −4 to −1 softer, 0 the camera's normal, +1 and +2 crisper. |
| **Noise Filter** | Off, Low, Std or High. On a COLOR without a film, a "*" shows when it differs from the camera's own Noise Filter setting. |
| **Vignette Correction** | Off = the lens's natural darker corners. On = the camera corrects them. |
| **Shading** | Darker or lighter corners, as an effect. |
| **Glow Effect** | +1 to +5 adds a soft glow. −1 to −5 adds Clarity (crisper local contrast). 0 = off. |
| **Halation Effect** | 0 to 5: a red-orange glow around bright lights, as on cinema film (CineStill). Works with or without Glow; fades out in bright daylight scenes. The halo fades away from the light. Saving takes a little longer with it on (much less since v0.30.3, and less again since v0.40-beta3). |
| **Film Grain Effect** | Off, Low, Med or High. Added in colour, with no extra wait after the photo. From v0.40-alpha: our own colour grain, Off and 1 to 5 (a film's Low / Med / High become 2 / 3 / 5); highlights stay white and Halation keeps its glow. |
| **Grain Size** | From v0.40-alpha: Fine, Medium or Coarse, for Film Grain. From v0.40.1 the clumps are round, with fewer repeats; from v0.40.2 the colour speckle is smoother, with less red-green. |
| **Border** | From v0.40-alpha: a white border, 0 (off) to 5, the same width on every side; from v0.40-beta the row runs from −5 to +5: minus is black, plus is white. JPEG only: the photo keeps its size and the border covers its outer edge; RAW is untouched. In live view a thin frame line shows where its inner edge will be (from the first half-press; not in video). |

The rows come five to a page in this order, as the camera works on a photo: the film and its colour, then white
balance and tone, then detail, lens and light effects, then grain (and from v0.40-alpha the border). The 20 film sims have their own Color Mix and RGB
curves once the camera has taken `CURVES.BIN` (from v0.30); changing them on a film gives it a "*" like any other row.

<!-- picture: the Picture Mode rows for one film -->

## The colour wheel (HSL)

1. Go to the **HSL** row and press **INFO**.
2. Press **INFO** again to move through the pages: **Color** (saturation of one colour) → **Color All** → **Hue** →
   **Luminance** → **Shadows** → **Highlights** → back to Color.
3. On each page the **front dial** picks the colour and the **rear dial** sets the value. The label under the wheel
   names the page (Sat, Hue, Lum or Tint; from v0.30.4-alpha). Off the Color page the front dial goes round the 12 colours without
   stopping on Color All.

The 12 colours run clockwise from Yellow at 12 o'clock: Yellow, Orange, Orange-red, Red, Magenta, Violet, Blue,
Blue-cyan, Cyan, Green-cyan, Green, Yellow-green.

- **Hue**, −5 to +5: plus turns a colour toward its clockwise neighbour (Yellow toward Orange).
- **Luminance**, −5 to +5: makes that colour darker or brighter.

**Split toning** uses the **Shadows** and **Highlights** pages. Each tints the dark or the bright parts of the photo
toward one colour. The front dial picks the colour, the rear dial the strength (0 to 10; 0 = off). For a classic
split tone, use both: for example blue shadows and orange highlights. The **Tone Balance** row (under HSL) moves where
the two meet.

<!-- picture: the HSL wheel on the Hue page; the Shadows page -->

## Your changes are kept

- Change a film and the change stays: switch to another film and back, or switch the camera off and on, and it's
  still there. COLOR 1–4 keep their own changes the same way.
- Changes are saved to the card at the next half-press.
- A **`*`** after a name means it's changed: after FILM n, something differs from how the film was built; after
  COLOR n, something differs from the camera's factory settings. A row with its own `*` is one of the changes.

**To start over:**

- **Hold OK on a film** in the Picture Mode list: the film goes back to how it was built.
- **Hold OK on COLOR n:** that COLOR goes back to the camera's factory settings.

## Buttons and the Creative Dial

Both are in the camera's **Button Function** menu, with the other buttons.

- **Arrow keys:** set the arrow pad (✥) to **Direct Function**. Then ▲ ◀ ▶ ▼ each have their own row: pick any function
  for each.
- **Delete button** (v0.29.3): its row (the trash can, after ▼) takes any function Fn can, in photo and video mode.
  Playback still erases with it; Off keeps it as before.
- **Creative Dial:** the rows **CRT, ART, COLOR and MONO** are the four positions of the front dial. Set each to
  **Normal** (its usual mode), **CRT**, **ART**, **COLOR** or **MONO**.
- **A film per position:** every position set to COLOR remembers the COLOR 1–4 or FILM 1–20 you pick while the dial is
  on it. Set all four to COLOR and you have four films on the dial.
- After you switch the camera on, half-press once: that loads your films, and the dial position's setting takes effect
  (a dial turn does it too).

## The film's white balance

Each film and COLOR remembers the white balance you last used with it (any mode, Custom WB with its Kelvin, and its
WB compensation), as it keeps its HSL. Picking the film brings that white balance back; one that never had its own
gets Auto with no compensation. Set a film's white balance in LookLab, or just change it on the camera while you're on
that film: a change in the super control panel's White Balance screen goes into the film (it gets a "*"), and
resetting the film brings its own back. The camera keeps one compensation per white balance mode, so if you switch
the mode by hand, that mode's own compensation applies. The camera's own picture modes (Natural, Vivid, ...) keep the
white balance the last film left.

## The film in your photos

Every JPEG taken on a FILM keeps the film in its EXIF: the name (Image Description, for example `FILM 9 Velvia 50`) and
the whole recipe as a short code in the User Comment: the film as it was set when you took the photo, with your
changes on the camera and the white balance. Open the JPEG in LookLab (**Open...**), or paste the
comment with **Paste link**, and the film is added to your films. Photos on COLOR 1–4 with your own settings, CRT, ART
and MONO don't get one.

## New films from LookLab

The [LookLab](https://androidfanman.github.io/caduceus-om3/looklab/) is a web page for making and changing films on your
computer, with a preview. It starts with the same 20 film sims.

1. Make or change your films in LookLab.
2. Save them as **`LOOKS.BIN`**, with *Firmware on the camera* set to **v0.28 or later**.
3. Copy `LOOKS.BIN` into the card's `OM3MOD` folder, then switch on and half-press once.

From v0.29 the camera takes the films into its own memory if it never had that set (an old `LOOKS.BIN` is ignored, so
change anything to make a set new). A film you changed in LookLab starts again as you built it there; the
other films keep the changes you made on the camera, and your selection and Extras stay. To put one film back as built,
hold OK on it in Picture Mode.

More on LookLab: [how to use it](CONTROL_PANEL.md).

## Crop modes: XPan, 21:9 and 5:4 (v0.40-alpha)

Image Aspect has three more choices, on the super control panel and in the Image Aspect menus: **5:4**, **XPan**
(65:24, the panoramic film camera's shape) and **21:9**.

- **Photos:** JPEGs are saved at that shape: XPan 5184 × 1920, 21:9 5184 × 2224, 5:4 4864 × 3888. RAW keeps the whole
  sensor with the crop marked, as for the camera's own ratios.
- **Shooting:** live view shows the crop; the grid lines, the focus target and the histogram fit inside it, and a
  film's Border is drawn inside the crop.
- **Image review and playback** show XPan, 21:9 or 5:4 with the quality (for example LSF+RAW). A photo trimmed to one
  of those shapes in the camera gets the same label.
- **Switching on:** from v0.40-beta the crop is back as soon as the camera has started, with no half-press. (In
  v0.40-alpha the camera showed 16:9 or 4:3 until your first half-press.) The camera's green frame lines sit at the
  crop's edges.
- Photos only. LookLab doesn't know the crops yet.

## Choosing what the shooting screen shows (v0.40-beta)

Custom menu → **4. Information** → **Camera Info Settings** → **Information 1**, **2** or **3** (press ▶): after the
camera's own four rows come 17 tick rows (Shooting Mode, Shutter Speed, Aperture Value, Exposure Comp., Exposure Level
Meter, ISO, WB, Picture Mode, Image Stabilizer, AF Mode, Subject Detection, Drive Mode, Metering, Image Aspect, Record
Mode, Remaining Files, Touch screen; Exposure Level Meter, Subject Detection and Image Aspect from v0.40-beta2). Untick
a row and that item leaves that display; INFO steps through your displays as before. Rear screen only, from the first
half-press after switch-on; the viewfinder, video and playback are unchanged.

The camera's **Firmware Version** page (wrench tab, page 6) shows Caduceus's version under OM's.

## Questions

See the [questions and answers](FAQ.md): no films in the list, settings that don't show in the photo, freezes, lost changes, video and more.

## The files on the card

From v0.29 the camera keeps your films, your changes and the Extras settings in its own memory, and Caduceus's code,
labels and guides are part of the firmware. The card only brings films in, in the `OM3MOD` folder at its top:

| File | What it is | Where it comes from |
|---|---|---|
| `LOOKS.BIN` | Films FILM 1–20, with their names: the camera takes them once, if it never had that set | The release or LookLab |
| `EDITS.BIN`, `BUNDLES.BIN` | Your changes and Extras from versions before v0.29: copied into the camera at the first start | Written by the camera before v0.29 |
| `GUIDES.BIN`, `LABELS.BIN`, `TONES.BIN` | Code, labels and guides of versions before v0.29 (ignored from v0.29) | The release, before v0.29 |

[`DEBUG.TXT`](https://github.com/androidfanman/caduceus-om3/releases/latest/download/DEBUG.TXT) (optional) turns on a debug log: the camera then writes `CADLOG.TXT`. Only
add it if you're asked for a log, and delete it afterwards. Older versions also used `NAMES.BIN`; it's harmless. Technical details: [FORMATS.md](FORMATS.md).
