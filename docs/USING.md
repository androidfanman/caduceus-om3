# Using Caduceus for OM-3

This page is for **v0.27**, the latest version. Not installed yet? Start with [Install](INSTALL.md).

> [!NOTE]
> Caduceus works on the **COLOR** profiles (COLOR 1–4) and your **films** (FILM 1–20). The Monochrome profiles keep
> the camera's own settings.

## In one minute

- Turn the creative dial to **COLOR** and open **Picture Mode**. After COLOR 1–4 the list shows your films,
  **FILM 1–20**. Pick one: its name becomes the big title, and the shooting screen and viewfinder show it.
- Change anything on the rows below: the film changes at once, and so does live view.
- Your changes stay with that film, even after you switch the camera off.
- **Hold OK** on a film to put it back the way it was built.

<!-- picture: Picture Mode list with FILM 1 (Portra 400) selected -->

## Choosing a film

1. Turn the creative dial to **COLOR**.
2. Open **Picture Mode** (from the super control panel or the menu).
3. The top row lists **COLOR 1–4, then FILM 1–20**. Turn to the film you want.

Your films load from the card by themselves a moment after the camera starts. The camera remembers the film you were on
when you switch it off.

What each of the 20 film sims looks like: [the film sims](../README.md#the-20-film-sims).

**Quicker:** on the super control panel, select the Picture Mode cell and turn a dial. It steps through COLOR 1–4, then
FILM 1–20.

<!-- picture: super control panel with the Picture Mode cell showing a film name -->

## Changing a film

The rows under Picture Mode change the film (or the COLOR) you're on, straight away:

| Row | What it does |
|---|---|
| **HSL** | The colour wheel: change each colour's saturation, hue and brightness, and split toning (see below). |
| **Contrast** | The camera's own contrast. |
| **Highlight & Shadow** | The camera's own tone curve: brighter or darker shadows, midtones and highlights. |
| **Blk** / **Wht** | Blacks and Whites, −5 to +5. Plus lifts the blacks or brightens the whites; minus deepens or softens them. |
| **WB** | Shifts the colour balance: A–B (amber to blue) and G–M (green to magenta), −7 to +7. Works in every white balance mode, Auto included. Press **OK** to open the camera's own grid; **MENU** or **OK** brings you back. |
| **Sharpness** | −5 = off, −4 to −1 softer, 0 the camera's normal, +1 and +2 crisper. |
| **Noise Filter** | Off, Low, Std or High. |
| **Vignette Correction** | Off = the lens's natural darker corners. On = the camera corrects them. |
| **Shading** | Darker or lighter corners, as an effect. |
| **Glow** | +1 to +5 adds a soft glow. −1 to −5 adds Clarity (crisper local contrast). 0 = off. |
| **Film Grain** | Off, Low, Med or High. Added in colour, with no extra wait after the photo. |

<!-- picture: the Picture Mode rows for one film -->

## The colour wheel (HSL)

1. Go to the **HSL** row and press **INFO**.
2. Press **INFO** again to move through the pages: **Color** (saturation of one colour) → **Color All** → **Hue** →
   **Luminance** → **Shadows** → **Highlights** → back to Color.
3. On each page the **front dial** picks the colour and the **rear dial** sets the value.

The 12 colours run clockwise from Yellow at 12 o'clock: Yellow, Orange, Orange-red, Red, Magenta, Violet, Blue,
Blue-cyan, Cyan, Green-cyan, Green, Yellow-green.

- **Hue**, −5 to +5: plus turns a colour toward its clockwise neighbour (Yellow toward Orange).
- **Luminance**, −5 to +5: makes that colour darker or brighter.

**Split toning** uses the **Shadows** and **Highlights** pages. Each tints the dark or the bright parts of the photo
toward one colour. The front dial picks the colour, the rear dial the strength (−5 to +5; minus tints toward the
opposite colour; 0 = off). For a classic split tone, use both: for example blue shadows and orange highlights.

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
- **Creative Dial:** the rows **CRT, ART, COLOR and MONO** are the four positions of the front dial. Set each to
  **Normal** (its usual mode), **CRT**, **ART**, **COLOR** or **MONO**.
- **A film per position:** every position set to COLOR remembers the COLOR 1–4 or FILM 1–20 you pick while the dial is
  on it. Set all four to COLOR and you have four films on the dial.
- After you switch the camera on, the dial position's setting takes effect at the first half-press or dial turn.

## The film in your photos

Every JPEG taken on a FILM keeps the film in its EXIF: the name (Image Description, for example `FILM 9 Velvia 50`) and
the whole recipe as a short code in the User Comment. Open the JPEG in the Control Panel (**Open...**), or paste the
comment with **Paste link**, and the film is added to your films. Photos on COLOR 1–4 with your own settings, CRT, ART
and MONO don't get one.

## New films from the Control Panel

The [Control Panel](https://androidfanman.github.io/caduceus-om3/) is a web page for making and changing films on your
computer, with a preview. It starts with the same 20 film sims.

1. Make or change your films in the Control Panel.
2. Save them as **`LOOKS.BIN`**, with *Firmware on the camera* set to **v0.26.1 or later**.
3. Copy `LOOKS.BIN` into the card's `OM3MOD` folder, replacing the old one.

A film you changed in the Control Panel starts again as you built it there; the other films keep the changes you made
on the camera. Deleting `OM3MOD/EDITS.BIN` puts every film back as built.

More on the Control Panel: [how to use it](CONTROL_PANEL.md).

## Questions

See the [questions and answers](FAQ.md): no films in the list, settings that don't show in the photo, freezes, lost changes, video and more.

## The files on the card

All in the `OM3MOD` folder at the top of the card:

| File | What it is | Where it comes from |
|---|---|---|
| `LOOKS.BIN` | Your films FILM 1–20, with their names | The release or the Control Panel |
| `EDITS.BIN` | The changes you made on the camera | Written by the camera |
| `BUNDLES.BIN` | The camera's current values (`.NEW` and `.BAK` are its safety copies) | Written by the camera |
| `GUIDES.BIN` | Caduceus's code and labels | The release: always with its own firmware |
| `LABELS.BIN`, `TONES.BIN` | Labels, and the split toning guides | The release |

`DEBUG.TXT` (optional, from the release's downloads) turns on a debug log: the camera then writes `CADLOG.TXT`. Only
add it if you're asked for a log, and delete it afterwards. Older versions also used `NAMES.BIN`; it's harmless. Technical details: [FORMATS.md](FORMATS.md).
