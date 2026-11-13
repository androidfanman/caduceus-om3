#!/bin/bash
# Every picture of the show-and-tell page (pages/showcase/img/), from scratch, in about three minutes:
#   1. the standard 20 films (LookLab's, webapp/src/data/om3films.json) as LOOKS.BIN on a blank card;
#   2. the camera screens: emulator runs on that card (shoot.sh), the HSL wheels drawn in (wheel.py), quantized;
#   3. the photos: each film and each setting on CC0 / public-domain samples with LookLab's own preview
#      (films.ts, demos.ts); Noise Filter and Vignette Correction as illustrations (illus.py).
# Needs the workspace (`. ~/om3-work/env.sh`) and `cd webapp && npm install`. The firmware is IMG (default: the
# build research/setup.sh checks, i.e. the latest release; the page shows v0.29's behaviour, films kept in the camera
# with nothing else on the card). Work files go to SHOWCASE_WORK (default $OM3_WORK/showcase).
set -e
H="$(cd "$(dirname "$0")" && pwd)"
: "${OM3_REPO:?load ~/om3-work/env.sh first}"
export SHOWCASE_WORK=${SHOWCASE_WORK:-$OM3_WORK/showcase}
W=$SHOWCASE_WORK; OUT=$OM3_REPO/pages/showcase/img; S=$W/shots; D=$OUT/screens
mkdir -p "$W" "$OUT/films" "$OUT/demos" "$OUT/halation" "$D"
r() { local s=""; for i in $(seq 1 $2); do s="$s $1"; done; echo $s; }

# 1. the standard 20 on a blank card (+ img/films/films.js for the page)
(cd "$OM3_REPO/webapp" && npx vite-node ../research/showcase/mklooks.ts -- "$W" "$OUT" > /dev/null)
python3 "$OM3_REPO/tools/emulator/card_add_file.py" "$OM3_WORK/card-blank.omsd" "$W/card.omsd" "$W/LOOKS.BIN" OM3MOD LOOKS.BIN > /dev/null

# 2. camera screens. Keys: s1 ok ok = Picture Mode on COLOR 1; right = next COLOR / FILM; down = next row; on the
# wheel, info = next page, sub-1 = next colour clockwise from Yellow, one main+1 / main-1 per step.
L='s1 ok ok right right right right shot:f01.png'; for i in $(seq -w 2 20); do L="$L right shot:f$i.png"; done
"$H/shoot.sh" list "$L" > /dev/null
# the five wheel pages on COLOR 1, one change each (Color: Blue + Blue-cyan -5; Hue: Yellow +5; Luminance: the three
# blues -5; Shadows: Blue 10; Highlights: Orange 10)
"$H/shoot.sh" wheels "s1 ok ok down $(r sub-1 7) $(r main-1 5) sub+1 $(r main-1 5) shot:w1.png info info $(r sub+1 6) $(r main+1 5) shot:w2.png info $(r sub-1 6) $(r main-1 5) sub-1 $(r main-1 5) sub-1 $(r main-1 5) sub+1 sub+1 shot:w3.png info $(r main+1 10) shot:w4.png info $(r sub+1 5) $(r main+1 10) shot:w5.png" > /dev/null
# the other rows on COLOR 1 at each demo's "after" value (Vignette Correction: its default On, no dial)
"$H/shoot.sh" rows "s1 ok ok down down $(r main-1 5) shot:bal.png down $(r main+1 2) shot:con.png down $(r main+1 7) $(r sub+1 7) shot:curve.png down down down $(r main+1 2) shot:sharp.png down main+1 shot:noise.png down main+1 shot:vigoff.png down $(r main-1 5) shot:shade.png down $(r main-1 5) shot:glow.png down $(r main-1 5) shot:halo.png down $(r main+1 3) shot:grain.png" > /dev/null
"$H/shoot.sh" vig "s1 ok ok $(r down 9) shot:vig.png" > /dev/null
"$H/shoot.sh" bwgrid "s1 ok ok $(r down 5) ok $(r right 7) shot:bw.png" > /dev/null
"$H/shoot.sh" wbgrid "s1 ok ok $(r down 6) ok $(r right 7) shot:wb.png" > /dev/null
# FILM 1 changed on the camera: the stars, then the shooting screen and the super control panel
"$H/shoot.sh" kept "s1 ok ok right right right right down down main+2 down main+1 down main+1 sub+1 shot:star.png ok shot:lv.png ok shot:scp.png" > /dev/null
rm -f "$D"/*.png
for i in $(seq -w 1 20); do cp "$S/list/f$i.png" "$D/film-$i.png"; done
cp "$S/rows/bal.png" "$D/row-tone-balance.png"; cp "$S/rows/con.png" "$D/row-contrast.png"; cp "$S/rows/curve.png" "$D/row-curve.png"
cp "$S/rows/sharp.png" "$D/row-sharpness.png"; cp "$S/rows/noise.png" "$D/row-noise.png"; cp "$S/vig/vig.png" "$D/row-vignette.png"
cp "$S/rows/shade.png" "$D/row-shading.png"; cp "$S/rows/glow.png" "$D/row-glow.png"; cp "$S/rows/halo.png" "$D/row-halation.png"
cp "$S/rows/grain.png" "$D/row-grain.png"; cp "$S/bwgrid/bw.png" "$D/row-blacks-whites.png"; cp "$S/wbgrid/wb.png" "$D/row-wb.png"
cp "$S/kept/star.png" "$D/kept-star.png"; cp "$S/kept/lv.png" "$D/liveview.png"; cp "$S/kept/scp.png" "$D/scp.png"
python3 "$H/wheel.py" "$S/wheels/w1.png" "$D/hsl-color.png" sat 6 0,0,0,0,0,0,-5,-5,0,0,0,0 -
python3 "$H/wheel.py" "$S/wheels/w2.png" "$D/hsl-hue.png" hue 0 5,0,0,0,0,0,0,0,0,0,0,0 Hue
python3 "$H/wheel.py" "$S/wheels/w3.png" "$D/hsl-luminance.png" light 6 0,0,0,0,0,0,-5,-5,-5,0,0,0 Luminance
python3 "$H/wheel.py" "$S/wheels/w4.png" "$D/hsl-shadows.png" sh 6 0,0,0,0,0,0,10,0,0,0,0,0 Shadows
python3 "$H/wheel.py" "$S/wheels/w5.png" "$D/hsl-highlights.png" hl 1 0,10,0,0,0,0,0,0,0,0,0,0 Highlights
(cd "$D" && python3 - <<'PY'
from PIL import Image
import glob
for f in glob.glob('*.png'):
    im = Image.open(f).convert('RGB')
    if f.startswith('hsl-'): im.save(f, optimize=True)                 # the drawn wheels: full colour
    else: im.quantize(colors=256, method=Image.MEDIANCUT, dither=Image.NONE).save(f, optimize=True)
PY
)

# 3. photos
P=$OM3_REPO/webapp/public/samples; RAW=$W/raw; rm -rf "$RAW"; mkdir -p "$RAW"
for n in meadow portrait paris taxi bluehour ocean neon; do python3 "$H/raw.py" in "$P/$n.jpg" "$RAW/$n.rgba" 1000; done
python3 "$H/raw.py" crop "$P/meadow.jpg" "$RAW/meadow-crop.rgba" 700 500 900 600
python3 "$H/raw.py" crop "$P/portrait.jpg" "$RAW/portrait-crop.rgba" 700 250 900 600
(cd "$OM3_REPO/webapp" && npx vite-node ../research/showcase/films.ts -- "$RAW" > /dev/null && npx vite-node ../research/showcase/demos.ts -- "$RAW" > /dev/null)
rm -f "$OUT/films/"*.jpg "$OUT/demos/"*.jpg "$OUT/halation/"*.jpg
for f in "$RAW"/out/*.rgba; do b=$(basename "$f" .rgba); case $b in hal-*) python3 "$H/raw.py" out "$f" "$OUT/halation/${b#hal-}.jpg";; *) python3 "$H/raw.py" out "$f" "$OUT/films/$b.jpg";; esac; done
for n in meadow portrait paris taxi; do python3 "$H/raw.py" out "$RAW/$n.rgba" "$OUT/films/$n-00.jpg"; done
for f in "$RAW"/demo/*.rgba; do python3 "$H/raw.py" out "$f" "$OUT/demos/$(basename "$f" .rgba).jpg"; done
python3 "$H/illus.py" "$P" "$OUT/demos"
echo "pages/showcase/img: $(find "$OUT" -type f | wc -l | tr -d ' ') files"
