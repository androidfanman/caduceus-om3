# Instructions: turn a photo into a Caduceus for OM-3 look

You are helping me build a colour look for my OM SYSTEM OM-3 running the Caduceus for OM-3 firmware mod. I will give you a photo (attached, or a link). Study how that photo looks, then build a look that brings my camera's colour photos as close to that look as the camera's settings allow. Then give me a link that opens the look in the Caduceus LookLab.

## What to do

1. **Get the photo.** Use the attached image. If I give a link you can't open, ask me to attach the file instead. If there are several photos, ask whether they should share one look.
2. **Study it.** Look at the image yourself. If you can run Python, also measure it (script below). Work out:
   - the white balance cast (warm/cool, green/magenta), judged on things that should be neutral (grey, white, concrete, clouds)
   - the black point (crushed or lifted/faded), the highlight roll-off, the overall contrast and the midtone brightness
   - the overall saturation, and per colour family: skin/orange, reds, yellows, greens, cyans/teals, blues, magentas
   - hue shifts against "normal" colour (greens leaning yellow or teal, skies leaning cyan, reds leaning orange or magenta, and so on)
   - softness or crispness, and any glow, grain or vignetting
3. **Translate into settings** using the reference below. Stay inside the ranges exactly. Prefer a few deliberate moves over many tiny ones. The camera starts from its own neutral rendering, so set only what makes the difference.
4. **Leave these off by default:** grain, Glow / Clarity, Art Effects and noise reduction (NR stays on Camera). If the photo clearly has grain, glow or a vignette, say so in the notes and tell me which setting would add it. Don't set them unless I ask.
5. **Output**, in this order:
   - a short description of the look you saw (2–4 sentences)
   - a table of the settings you chose, each with a one-line reason
   - the look as JSON
   - the **LookLab link** (made with the script below), plus the bare `op1_…` code
   - one or two honest notes on what the camera can't reproduce (for example, separate colour in shadows and highlights). The look is an approximation: tell me to check it in LookLab's preview on its sample photos or my own, and adjust.

## How I load it

- **Click the link.** It opens LookLab and adds the look to the first free number. If all 20 are in use, it asks which one to replace.
- **Or paste the code:** in LookLab (OM-3 mode), choose **Paste a code…** and paste either the whole link or the `op1_…` code.

LookLab: https://androidfanman.github.io/caduceus-om3/looklab/

## The look format (JSON)

```json
{
  "name": "Dusk Harbour",
  "kind": "colour",
  "notes": "Warm low sun, lifted shadows, teal-leaning water.",
  "hue":   [0,0,0,0,0,0,0,0,0,0,0,0],
  "light": [0,0,0,0,0,0,0,0,0,0,0,0],
  "sat":   [0,0,0,0,0,0,0,0,0,0,0,0],
  "tone": {"highlights": 0, "shadows": 0, "midtones": 0, "blacks": 0, "whites": 0},
  "advice": {"contrast": 0, "sharpness": 0},
  "vignette": 0,
  "wb": null,
  "grain": "off",
  "effect": null,
  "art_effect": "off"
}
```

Every number is a whole number (integer).

| Field | Range | Meaning |
|---|---|---|
| `name` | 1–15 characters | Shown on the camera. Plain ASCII only (letters, digits, spaces, punctuation), no space at the start or end. |
| `notes` | up to ~200 characters | For me; not sent to the camera. |
| `hue[12]` | −5..+5 | Per colour slice: **+ turns that colour toward the next slice in the order below** (Yellow → Orange, Green → Yellow-green, Cyan → Green-cyan, Blue → Blue-cyan, Red → Magenta). − turns it the other way. About 5–6° of hue per step. |
| `light[12]` | −5..+5 | Per slice: darker (−) or brighter (+). Steps grow toward the ends; ±1–2 is subtle, ±4–5 is strong. |
| `sat[12]` | −5..+5 | Per slice saturation. Most looks set overall saturation by moving all 12 together, then adjust single families. ±1 is subtle, ±3 strong, ±5 extreme. |
| `tone.highlights` / `shadows` / `midtones` | −7..+7 | + brighter, − darker, in that tonal range. |
| `tone.blacks` | −5..+5 | + lifts the black point (faded, film-like), − crushes it. |
| `tone.whites` | −5..+5 | + brighter whites, − dimmer, softer whites. |
| `advice.contrast` | −2..+2 | The camera's Contrast. |
| `advice.sharpness` | −5..+2 | Sharp, in the camera's own numbers: 0 is its normal, +1/+2 crisper, −1..−4 softer, −5 = Off (no sharpening). Soft film or vintage looks: −1 to −3. |
| `vignette` | −5..+5 | The camera's Shading: − darker corners, + lighter corners. |
| `wb` | `null` or `{"a_b": n, "g_m": n}`, each −5..+5 | White balance shift on top of the camera's WB: `a_b` + amber / − blue, `g_m` + green / − magenta. About 1.5% per step. |
| `grain` | `"off"` | Noise reduction: `"off"` = Camera (leave it). Others: `"standard"` = Std, `"fine"` = Low, `"film"` = NR Off. |
| `effect` | `null` | Glow / Clarity: `{"type": "bloom", "strength": 1..5}` (glow) or `{"type": "clarity", "strength": 1..5}`. Leave `null` unless I ask. |
| `art_effect` | `"off"` | `"star_light"`, `"pin_hole"`, `"white_edge"`, `"frame"`. Leave `"off"` unless I ask. |
| `film_grain` | omit | Optional: 1 Low, 2 Med, 3 High. Omit unless I ask. |
| `lens_correction` | omit | Omit (the look then turns the lens's vignette correction off). Add `true` only if I want the camera's correction kept. |

**Slice order** for `hue`, `light` and `sat` (index 0–11, clockwise on the camera's wheel from 12 o'clock), with rough equivalent hues in HSV degrees:

| Index | Slice | ≈ HSV hue |
|---|---|---|
| 0 | Yellow | 60° |
| 1 | Orange (skin) | 35° |
| 2 | Orange-red | 15° |
| 3 | Red | 355° |
| 4 | Magenta | 320° |
| 5 | Violet | 280° |
| 6 | Blue | 235° |
| 7 | Blue-cyan | 205° |
| 8 | Cyan | 180° |
| 9 | Green-cyan | 155° |
| 10 | Green | 120° |
| 11 | Yellow-green | 85° |

**What the camera can't do:** separate colours in shadows and highlights (split toning), per-channel curves, local adjustments or HSL masks beyond these 12 slices. Teal-and-orange and similar looks are approximated with the WB shift plus per-slice hue and saturation. Say when something is out of reach.

## Measuring the photo (Python, if you can run code)

```python
from PIL import Image
import numpy as np, colorsys
im = Image.open("photo.jpg").convert("RGB"); im.thumbnail((800, 800))
a = np.asarray(im).astype(np.float32) / 255
Y = 0.299*a[...,0] + 0.587*a[...,1] + 0.114*a[...,2]
print("luma percentiles 1/5/25/50/75/95/99:", np.percentile(Y, [1,5,25,50,75,95,99]).round(3))
hsv = np.array([colorsys.rgb_to_hsv(*p) for p in a.reshape(-1,3)[::7]])
centres = [60,35,15,355,320,280,235,205,180,155,120,85]
names = ["Yellow","Orange","Orange-red","Red","Magenta","Violet","Blue","Blue-cyan","Cyan","Green-cyan","Green","Yellow-green"]
h, s, v = hsv[:,0]*360, hsv[:,1], hsv[:,2]
for c, n in zip(centres, names):
    d = np.abs((h - c + 180) % 360 - 180); m = (d < 15) & (s > 0.12) & (v > 0.12)
    if m.sum() > 50:
        mh = np.degrees(np.angle(np.exp(1j*np.radians(h[m])).mean())) % 360   # circular mean hue
        print(f"{n:12s} share {m.mean():.1%}  mean sat {s[m].mean():.2f}  mean hue {mh:.0f}° (centre {c}°)")
low = (s < 0.12) & (v > 0.2) & (v < 0.9)                 # near-neutral pixels: their cast is the WB shift
if low.sum() > 100:
    px = a.reshape(-1,3)[::7][low]; print("neutral cast R-B, G-(R+B)/2:", (px[:,0]-px[:,2]).mean().round(3), (px[:,1]-(px[:,0]+px[:,2])/2).mean().round(3))
```

Read it like this:
- A lifted 1st percentile (above about 0.06) means `blacks` +.
- A low 99th percentile (below about 0.9) means `whites` −.
- A wide 5–95 spread means more contrast; a narrow spread means less.
- A positive R−B on neutral pixels means amber (`a_b` +); a positive G−(R+B)/2 means green (`g_m` +).
- Compare each family's saturation with the others to find the ones to boost or mute.
- A family's mean hue sitting off its centre suggests a hue move toward that side.

## Making the code and link (Python)

```python
import json, zlib, base64
look = { ... }                      # the JSON above, filled in
def check(l):
    assert 1 <= len(l["name"]) <= 15 and l["name"] == l["name"].strip() and all(32 <= ord(c) < 127 for c in l["name"])
    for k in ("hue", "light", "sat"):
        assert len(l[k]) == 12 and all(isinstance(x, int) and -5 <= x <= 5 for x in l[k]), k
    t = l["tone"]
    assert all(-7 <= t[k] <= 7 for k in ("highlights", "shadows", "midtones")) and all(-5 <= t[k] <= 5 for k in ("blacks", "whites"))
    assert -2 <= l["advice"].get("contrast", 0) <= 2 and -5 <= l["advice"].get("sharpness", 0) <= 2
    assert -5 <= l["vignette"] <= 5
    assert l["wb"] is None or all(-5 <= l["wb"][k] <= 5 for k in ("a_b", "g_m"))
check(look)
code = "op1_" + base64.urlsafe_b64encode(zlib.compress(json.dumps(look, separators=(",", ":")).encode(), 9)).decode().rstrip("=")
print(code)
print("https://androidfanman.github.io/caduceus-om3/looklab/?camera=om3#" + code)
```

The look may start with `"schema": "caduceus-om3-look/1"` (optional; looks without it are read as that format). Any `"min_fw"` you add is ignored: LookLab works the minimum firmware out from the settings itself.

The code is the look's JSON compressed with zlib (deflate with the zlib header) and written as URL-safe base64 without `=` padding, after `op1_`. Always make it with code, never by hand.

**If you can't run code:** give me the JSON. I can save it as a file in this format and open it with **Open…** in LookLab, which replaces my current looks (Undo brings them back):

```json
{"schema": "caduceus-om3-bank/1", "name": "From a photo",
 "bank": [[<the look>, null, null, null, null], [null,null,null,null,null], [null,null,null,null,null], [null,null,null,null,null]]}
```

## Ground rules

- The look must be your own reading of the photo. Don't copy settings from published presets, LUTs or other people's recipes.
- Keep every value in range. A look with any value out of range can't be exported to the camera.
- If I ask for changes ("warmer", "less contrast", "softer skin"), adjust the JSON and give me a new link each time.
