#!/bin/bash
# shoot.sh NAME 'tokens ... shot:X.png ...'  ->  $SHOWCASE_WORK/shots/NAME/*.png in real colours, plus session.log
# Drives tools/emulator/session_ed1.mjs (keys, dials, shot:FILE.png). om-emu's raw shots hold Y / Cb / Cr bytes, not
# RGB: ycc2rgb.py converts them as om-emu's own PNG writer does. Needs the workspace (research/setup.sh, then
# `. ~/om3-work/env.sh`). IMG = the firmware's main.bin (default: the build setup.sh checks, out-check);
# CARD = an emulator card image (default: the one make.sh writes).
set -e
H="$(cd "$(dirname "$0")" && pwd)"
: "${OM3_REPO:?load ~/om3-work/env.sh first}"
WORK=${SHOWCASE_WORK:-$OM3_WORK/showcase}
NAME=$1; TOKENS=$2; IMG=${IMG:-$OM3_WORK/out-check/main.bin}; CARD=${CARD:-$WORK/card.omsd}
D="$WORK/shots/$NAME"; rm -rf "$D"; mkdir -p "$D"; cd "$D"
node "$OM3_REPO/tools/emulator/session_ed1.mjs" "$OM3_EMU" "$IMG" "$CARD" out.json saved.omsd "$TOKENS" > session.log 2>&1 || { tail -5 session.log; exit 1; }
grep -o '"step":"[^"]*","state":[0-9]*,"gui":"[^"]*"' session.log | sed 's/"state":[0-9]*,//'
shopt -s nullglob
for f in *.png; do case $f in *.rgb.png) ;; *) python3 "$H/ycc2rgb.py" "$f"; mv "${f%.png}.rgb.png" "$f";; esac; done
