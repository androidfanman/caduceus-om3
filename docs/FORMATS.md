# Card file formats (`C:\OM3MOD\`)

All multi-byte values little-endian. CRC-32 = zlib/PNG CRC-32. Signed values are s8.

## LOOKS.BIN v1 (1632 bytes)

Called `PROFILES.BIN` in v0.16–v0.18 (same format). v0.19 reads `LOOKS.BIN`, or `PROFILES.BIN` when there is no
`LOOKS.BIN`, and always writes `LOOKS.BIN`. v0.20 reads only `LOOKS.BIN` and adds the Extras bytes `+47..+49` (zero in
older files, which therefore load unchanged).

| Offset | Size | Field |
|---|---|---|
| 0 | 4 | magic `OM3P` |
| 4 | 4 | total length 1632 |
| 8 | 4 | CRC-32 of bytes 12..1631 |
| 12 | 2 | version 1 |
| 14 | 2 | record count 20 |
| 16 | 4 | selection per COLOR 1..4 (0..5; the camera writes what is selected, the Control Panel writes 0) |
| 20 | 12 | zero |
| 32 | 20 × 64 | records: COLOR k (0..3) look v (1..5) at index 5k + v − 1 |
| 1312 | 20 × 16 | names, ASCII, zero-padded (up to 15 characters) |

Record (64 bytes): `+0` hue[12], `+12` light[12], `+24` saturation[12] (all −5..5, slices clockwise from Yellow),
`+36` WB shift on (0/1), `+37` A/B, `+38` G/M, `+39` Blacks, `+40` Whites (−5..5), `+41` Contrast (−2..2),
`+42` Sharpness (−2..2; 0 from v0.22, see `+52`), `+43` Shading (−5..5), `+44` Shadows, `+45` Midtones, `+46` Highlights (−7..7),
v0.20: `+47` Glow (−5..−1) / Clarity (1..5), `+48` Art Effect (0 Off, 1 Star Light, 2 Pin Hole, 3 none, 4 White Edge,
5 Frame: the Caduceus ids), `+49` NR (0 Camera, 1 Standard, 2 Low, 3 Off), v0.21: `+50` VigFix (0 Camera: the lens
shading correction as set, 1 Off), `+51` Grain (0 Off, 1 Low, 2 Med, 3 High), v0.22: `+52` Sharp (−5..+2, the
camera's own sharpness numbers, 0 its normal, −5 Off; the Control Panel's v0.22 export leaves `+42` at 0), v0.26: `+53` Shadows
colour (0..11, the wheel's colours clockwise from Yellow), `+54` its strength, `+55` Highlights colour, `+56` its
strength (checked as −5..5; from v0.28 0..5, half the v0.26 step, and below 0 = off), `+59..63` zero.
v0.28: `+57` Halation (0 Off, 1..5; checked as −5..5, 0 and below = Off), `+58` Tone Balance (−5..5: − the shadow
colour reaches further, + the highlight colour). Firmware before v0.28 needs `+57` and `+58` to be 0 and ignores the
whole file otherwise, so the Control Panel's older exports leave them out. Bytes `+47..+49` and `+51` are checked as −5..5 by the camera, `+50` as −1..1, `+52` as −5..2; the editor keeps
them in the ranges above. v0.20 and older require `+50` and `+51` to be 0, and v0.21 and older `+52` (they ignore the
whole file otherwise), so the Control Panel's older exports leave them out; its v0.21 export puts the look's sharpness
in `+42` instead (−2..+2, softer values as −2).

The camera checks size, magic, CRC, version, selection range and every record byte's range; a file that fails is
ignored and left alone (the Looks page is then hidden). With no file, the camera starts a neutral bank and
writes the file the first time a look is used. Writes go to `LOOKS.NEW`, are read back, then to `LOOKS.BIN`.

Generators: `card/mkprofiles.py` (JSON → file) and the Control Panel (`webapp/src/om3.ts`: `profilesBin` / `readProfiles`), byte-identical
(`webapp/tests/om3.test.ts`).

## EDITS.BIN (1648 bytes, v0.24)

Written by the camera only (at the half-press save, when something changed); the changes you make to each film and
COLOR 1–4's own settings while a film sits on that COLOR. The films as built stay in `LOOKS.BIN`.

| Offset | Size | Field |
|---|---|---|
| 0 | 4 | magic `OM3T` |
| 4 | 4 | total length 1648 |
| 8 | 4 | CRC-32 of bytes 12..1647 |
| 12 | 4 | valid bits: bit r = record r holds saved settings |
| 16 | 24 × 68 | record r: 64 bytes in the `LOOKS.BIN` record format, then a u32 check |

Records 0..19 = film j (the `LOOKS.BIN` record of the same number; its check is the CRC-32 of that `LOOKS.BIN`
record when the changes were saved, so a film rebuilt in the Control Panel starts again as built). Records 20..23 =
COLOR 1–4's own settings (check 0). A file that fails the size, magic or CRC check is ignored. Deleting it puts every
film back as built.

## BUNDLES.BIN (544 bytes)

Caduceus BUNDLES.BIN v1 layout with OM-3 identity: `OM3B` | u16 version 1 | u16 header 32 | u32 firmware build 1100 |
u32 payload 512 | u32 CRC-32 over bytes 0..15 + 20..543 | 4 bytes decoded-firmware SHA-256 prefix | 8 zero |
8 slots × 64 bytes (slot k = COLOR k+1): hue[12] `+0`, light[12] `+12`, `+25` WB flags (bit 0 on), `+26` A/B,
`+27` G/M, `+31` flags (bit 1 = Hue/Light on), `+47` Blacks, `+48` Whites, v0.20 Extras: `+49` Glow/Clarity,
`+50` Art Effect, `+51` NR (as the LOOKS.BIN record's `+47..+49`), v0.21: `+52` VigFix, `+53` Grain (the record's
`+50`, `+51`), v0.22: `+54` Sharp (the record's `+52`), v0.26: `+55..+58` split toning (the record's `+53..+56`). v0.28: `+30`
Halation 0..5 (the record's `+57`; the shared layout's `vignette` byte, −5..5 to every OM-3 firmware, unused before),
`+33` Tone Balance −5..5 (the record's `+58`; the shared layout's first `sat` byte, −5..5 to every OM-3 firmware,
unused on COLOR slots).

## GUIDES.BIN v4

`OM3G` | u32 total | u32 CRC-32 of bytes 12.. | u16 width 175 | u16 height 50 | u32 length of streams 1..4 |
streams (Hue, Light, Extras, Film; before v0.20: Hue, Light, WB/BW, Looks), each padded to 4 bytes. Streams are OM-3
OSD type-11 pictures (palette indices, run-length tokens); see `card/mkguides.py`.

From v0.20 the file ends with the **Extras code block** (our code, built from `firmware/src/xblock.s` by
`firmware/build.py`): code (linked at 0x10000000) | u32 relocations (bit 31 set: absolute, + delta; else
PC-relative to the firmware, − delta) | {u32 tag, u32 end − code, u32 code length, u32 count}. The firmware loads it
with the pictures, checks the tag (made from the firmware image, so a block only runs on the firmware it was built
with), relocates it in its heap buffer and runs the Extras effects from it. A `GUIDES.BIN` without a matching block
still gives the page labels; the Extras values then save but don't change the photo.

## LABELS.BIN v2 (5686 bytes, v0.20)

The Extras labels next to the value (the stock "Vivid" picture, 70 × 30). `OM3V` | u32 total | u32 CRC-32 of bytes
12.. | u32 count 21 | 21 bitmaps of 30 rows × 9 bytes (70 px, MSB first, 1 = letter). The camera draws the picture
from the bitmap (white letters, a 1 px dark edge, grey out to 2 px) and encodes it only when the label changes.
Labels, in order: NR, NR Std, NR Low, NR Off · Glow, Clarity, Glo/Cla · B, A, A/B · M, G, G/M · Art Off, Star,
Pin Hole, Art Off, W. Edge, Frame · Blacks, Whites. See `card/mklabels.py`.

## NAMES.BIN v1

Pictures of the look names, shown under the wheel on the Film page. Written by the Control Panel (`webapp/src/om3names.ts`: `namesBin`)
together with `LOOKS.BIN`, in the camera's label style (`card/mkguides.py` metrics).

| Offset | Size | Field |
|---|---|---|
| 0 | 4 | magic `OM3N` |
| 4 | 4 | total length |
| 8 | 4 | CRC-32 of bytes 12..end |
| 12 | 2 | version 1 |
| 14 | 2 | entry count 20 |
| 16 | 2 | picture width 175 |
| 18 | 2 | picture height 50 |
| 20 | 12 | zero |
| 32 | 4 × 8 | groups {u32 offset, u32 length}: COLOR k's five pictures, contiguous from 144, each group ≤ 16384 bytes |
| 64 | 20 × 4 | entries {u16 offset in its group, u16 length}: COLOR k look v at 5k + v − 1 (length 0 = none) |
| 144 | … | group data: OSD type-11 pictures, 175 × 50, each 4-byte aligned |

The camera loads each group into its own buffer at the first half-press and checks the CRC and every picture's
header; a file that fails is ignored (the label then says "Film").
