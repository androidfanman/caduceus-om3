#!/bin/sh
# Assemble the up-key hooks into build/ (MN10300 binutils from research/setup.sh: TC = its build folder).
#   TC=~/om3-work/toolchain/build sh assemble.sh
set -e
cd "$(dirname "$0")"; mkdir -p build
: "${TC:?set TC to the binutils build folder}"
"$TC/gas/as-new" -o build/up.o up.s && "$TC/ld/ld-new" -T up.ld -o build/up.elf build/up.o
"$TC/gas/as-new" -o build/upic.o upic.s && "$TC/ld/ld-new" -T upic.ld -o build/upic.elf build/upic.o
for s in upget hookv; do "$TC/binutils/objcopy" -O binary -j .$s build/up.elf build/$s.bin; done
for s in upic hooki; do "$TC/binutils/objcopy" -O binary -j .$s build/upic.elf build/$s.bin; done
ls -l build/*.bin
