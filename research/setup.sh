#!/usr/bin/env bash
# One-step workspace for Caduceus for OM-3 firmware work (a fresh Claude session or a new computer).
#
#   research/setup.sh [PATH/TO/OLY_E_147_1100_0000_0000.BIN, or the folder that holds it]
#
# Makes, in $OM3_WORK (default ~/om3-work, outside the repo), and skips whatever is already there:
#   toolchain/   GNU binutils 2.42 for MN10300 (as, ld, objcopy, objdump, nm), built from the GNU release
#   stock/       the official OM-3 firmware 1.1 (checked by sha256)
#   decoded/     its decoded main block (for tools/dis.sh and analysis)
#   om-emu/      the emulator (github.com/flatpanda/om-emu) with the OM-3 (E147) blocks unpacked
#   out-check/   a build of this checkout, compared with the newest release
#   env.sh       paths for later commands:  . ~/om3-work/env.sh
#
# The firmware is OM's: it is never committed, and each person supplies their own copy. The script uses the copy
# already in $OM3_WORK/stock, else the argument (the file or its folder), else $OM3_STOCK; at a terminal it asks for
# the path (or offers to download it from OM's update server). Without any of these it stops at that step and says
# what to do; run it again with the path. Everything else is fetched from Ubuntu's archive and GitHub.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=${OM3_WORK:-$HOME/om3-work}
STOCK_SHA=8c133084414533159f587bf46bfb4152714c4074312a47c8d8503e33d605696d
MAIN_SHA=5e8d376e9111a44ac0352f26030d7c1b17026d42c45f3600cfa02a0e8c5b7d59
BU_URL=http://archive.ubuntu.com/ubuntu/pool/main/b/binutils/binutils_2.42.orig.tar.xz
BU_SHA=f6e4d41fd5fc778b06b7891457b3620da5ecea1006c6a4a41ae998109f85a800
EMU_GIT=https://github.com/flatpanda/om-emu

mkdir -p "$WORK"
say() { printf '\n== %s\n' "$*"; }
sha() { sha256sum "$1" | cut -d' ' -f1; }

say "1/6 prerequisites"
missing=()
for c in python3 node git make gcc g++ xz curl mcopy; do command -v "$c" >/dev/null || missing+=("$c"); done
if ((${#missing[@]})); then echo "missing: ${missing[*]} (install them, e.g. apt-get install build-essential nodejs git xz-utils curl mtools)"; exit 1; fi
python3 -c 'import PIL, numpy, scipy' 2>/dev/null || pip install --quiet --break-system-packages pillow numpy scipy \
  || pip install --quiet pillow numpy scipy
echo "python $(python3 -V 2>&1 | cut -d' ' -f2), node $(node --version)"

say "2/6 toolchain (binutils 2.42 for mn10300-elf)"
TC=$WORK/toolchain/build
if [ -x "$TC/gas/as-new" ] && [ -x "$TC/ld/ld-new" ] && [ -x "$TC/binutils/objcopy" ]; then
  echo "already built: $TC"
else
  mkdir -p "$WORK/toolchain" && cd "$WORK/toolchain"
  [ -f binutils_2.42.orig.tar.xz ] || curl -fsSL -o binutils_2.42.orig.tar.xz "$BU_URL"
  [ "$(sha binutils_2.42.orig.tar.xz)" = "$BU_SHA" ] || { echo "binutils download does not match its checksum"; exit 1; }
  [ -d binutils-2.42 ] || tar -xJf binutils_2.42.orig.tar.xz
  mkdir -p build && cd build
  [ -f Makefile ] || ../binutils-2.42/configure --target=mn10300-elf --prefix="$WORK/toolchain/install" --disable-nls \
    --disable-werror --disable-gdb --disable-sim --disable-gprof --disable-gold --disable-libctf --disable-gprofng \
    --disable-shared >configure.log 2>&1
  make -j"$(nproc)" MAKEINFO=true all-gas all-ld all-binutils >make.log 2>&1 || { echo "build failed: see $TC/make.log"; exit 1; }
  echo "built: $TC"
fi

say "3/6 official OM-3 firmware 1.1"
mkdir -p "$WORK/stock"
STOCK=$WORK/stock/OLY_E_147_1100_0000_0000.BIN
if [ -f "$STOCK" ] && [ "$(sha "$STOCK")" != "$STOCK_SHA" ]; then rm -f "$STOCK"; fi     # a wrong or damaged copy
# take PATH: PATH is the firmware file, or a folder holding it; copied in when its checksum is right
take() {
  local p=$1 f
  [ -n "$p" ] || return 1
  p=${p/#\~/$HOME}
  if [ -d "$p" ]; then
    for f in "$p"/OLY_E_147_1100_0000_0000*.BIN "$p"/*/OLY_E_147_1100_0000_0000*.BIN; do
      [ -f "$f" ] && [ "$(sha "$f")" = "$STOCK_SHA" ] && { cp "$f" "$STOCK"; return 0; }
    done
    echo "  no OLY_E_147_1100_0000_0000.BIN with the right checksum in $p"; return 1
  fi
  [ -f "$p" ] || { echo "  not found: $p"; return 1; }
  [ "$(sha "$p")" = "$STOCK_SHA" ] || { echo "  $p is not the OM-3 firmware 1.1 (checksum differs)"; return 1; }
  cp "$p" "$STOCK"
}
if [ ! -f "$STOCK" ]; then
  take "${1:-}" || take "${OM3_STOCK:-}" || true
fi
if [ ! -f "$STOCK" ] && [ -t 0 ]; then                  # someone at a terminal: ask
  echo "Where is the official OM-3 firmware 1.1 (OLY_E_147_1100_0000_0000.BIN, about 240 MB)?"
  echo "Type its path or the folder it is in, or press Enter to try downloading it from OM."
  while [ ! -f "$STOCK" ]; do
    read -r -p "> " ans || break
    if [ -z "$ans" ]; then
      echo "asking OM's update server ..."
      (python3 "$REPO/firmware/patch.py" --download --out "$WORK/stock/patched-tmp" >/dev/null 2>&1) || true
      take "$WORK/stock/patched-tmp/restore/E1479999.BIN" >/dev/null || echo "  the download did not work here: type a path instead"
      rm -rf "$WORK/stock/patched-tmp"
    else
      take "$ans" || true
    fi
  done
fi
if [ ! -f "$STOCK" ]; then
  cat <<'MSG'
This step needs the official OM-3 firmware 1.1 file, OLY_E_147_1100_0000_0000.BIN (about 240 MB, from OM's website
or OM Workspace). It is never stored in the repository. Run the script again with the file or the folder it is in:
  research/setup.sh PATH/TO/OLY_E_147_1100_0000_0000.BIN      (or the folder that holds it)
(For a Claude session: ask the person where their copy is; they can attach it to the chat or link the session to the
computer that has it. Steps 1-2 are done and will be skipped.)
MSG
  exit 2
fi
echo "ok: $STOCK"

say "4/6 decoded main block"
MAIN=$WORK/decoded/00_0100_50000000.decoded.bin
if [ -f "$MAIN" ] && [ "$(sha "$MAIN")" = "$MAIN_SHA" ]; then echo "already there: $MAIN"
else
  rm -rf "$WORK/decoded"
  python3 "$REPO/research/tools/oe_decode.py" "$STOCK" --out "$WORK/decoded" --expect-sha256 "$STOCK_SHA" >/dev/null
  [ "$(sha "$MAIN")" = "$MAIN_SHA" ] || { echo "decoded main block does not match its checksum"; exit 1; }
  echo "ok: $MAIN"
fi

say "5/6 emulator (om-emu, OM-3 = E147)"
EMU=$WORK/om-emu
[ -d "$EMU/.git" ] || git clone --quiet --depth 1 "$EMU_GIT" "$EMU"
mkdir -p "$EMU/fw" && { [ -f "$EMU/fw/OLY_E_147_1100_0000_0000.BIN" ] || cp "$STOCK" "$EMU/fw/"; }
(cd "$EMU" && node emu/bin/fetch-fw.mjs --model E147 --bin fw/OLY_E_147_1100_0000_0000.BIN >/dev/null 2>&1 \
  || node emu/bin/fetch-fw.mjs --model E147 --bin fw/OLY_E_147_1100_0000_0000.BIN)
echo "ok: $EMU (unpacked/E147)"

say "6/6 build check"
OUT=$WORK/out-check
rm -rf "$OUT"
python3 "$REPO/firmware/build.py" --stock "$STOCK" --toolchain "$TC" --out "$OUT" >"$WORK/build-check.log" 2>&1 \
  || { echo "build failed: see $WORK/build-check.log"; exit 1; }
got=$(python3 -c "import json;print(json.load(open('$OUT/build.json'))['package_sha256'])")
latest=$(python3 -c "
import pathlib, sys
def k(v):                                          # as firmware/patch.py: v0.28-alpha sorts before v0.28
    n, _, p = v.lstrip('v').partition('-'); return [int(x) for x in n.split('.')], p == '', p
print(max((d for d in pathlib.Path(sys.argv[1]).iterdir() if d.name.startswith('v')), key=lambda d: k(d.name)))
" "$REPO/releases")
want=$(grep 'DCOLYMP/E1479999.BIN' "$latest/SHA256SUMS" | cut -d' ' -f1)
if [ "$got" = "$want" ]; then echo "this checkout rebuilds $(basename "$latest") byte for byte ($got)"
else echo "built $got; $(basename "$latest") is $want (expected if this branch changes the firmware)"; fi
rm -f "$OUT/E1479999.BIN"      # keep main.bin and the card files for the emulator; the package is 240 MB

# an emulator SD card: blank, formatted by the firmware, then this build's OM3MOD card files
CARD=$WORK/card.omsd
if [ ! -f "$WORK/card-blank.omsd" ]; then
  (OM_EMU_MODEL=E147 node "$REPO/research/emulator/session_probe2.mjs" "$EMU/emu" "$OUT/main.bin" blank \
    "$WORK/card-blank.json" "$WORK/card-blank.omsd" >/dev/null 2>&1) || { echo "could not make the blank card"; exit 1; }
fi
python3 "$REPO/tools/emulator/card_add_file.py" "$WORK/card-blank.omsd" "$CARD.tmp" "$OUT/GUIDES.BIN" OM3MOD GUIDES.BIN >/dev/null
python3 "$REPO/tools/emulator/card_add_file.py" "$CARD.tmp" "$CARD" "$OUT/LABELS.BIN" OM3MOD LABELS.BIN >/dev/null
rm -f "$CARD.tmp"
echo "emulator card: $CARD (OM3MOD/GUIDES.BIN and LABELS.BIN of this build)"

cat >"$WORK/env.sh" <<EOF
# Caduceus for OM-3 workspace (made by research/setup.sh)
export OM3_REPO="$REPO" OM3_WORK="$WORK" OM3_STOCK="$STOCK" OM3_MAIN="$MAIN"
export OM3_TOOLCHAIN="$TC" OBJDUMP="$TC/binutils/objdump" OM3_EMU="$EMU/emu" OM_EMU_MODEL=E147 OM3_CARD="$CARD"
EOF
say "ready"
cat <<EOF
  . $WORK/env.sh
  build:     python3 \$OM3_REPO/firmware/build.py --stock \$OM3_STOCK --toolchain \$OM3_TOOLCHAIN --out \$OM3_WORK/out-NAME
  emulator:  node \$OM3_REPO/tools/emulator/session_ed1.mjs \$OM3_EMU \$OM3_WORK/out-check/main.bin \$OM3_CARD out.json saved.omsd 's1 ok ok down shot:a.png'
             (a different build: put its GUIDES.BIN on the card with tools/emulator/card_add_file.py)
  disasm:    \$OM3_REPO/research/tools/dis.sh 0x60513d00 0x60513d40
EOF
