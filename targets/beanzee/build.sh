#!/usr/bin/env bash

# Build Marvin for BeanZee target
# Run from repo root: ./targets/beanzee/build.sh [org]
# Default org: 0x0000

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../.."

org=${1:-0x0000}
outdir=targets/beanzee/output
mkdir -p "$outdir"

z88dk-z80asm -l -b -m -DMODULAR -DMARVINORG=$org \
    asm/boot_beanzee.asm \
    asm/console_usb.asm \
    asm/UM245R.asm \
    asm/marvin.asm \
    asm/strings.asm \
    asm/messages.asm \
    -O"$outdir"

# z88dk-z80asm preserves source path structure under -O
bindir="$outdir/asm"
hexdump -C "$bindir/boot_beanzee.bin" > "$outdir/marvin.hex"
z88dk-appmake +hex --org $org -b "$bindir/boot_beanzee.bin" -o "$outdir/marvin.ihx"
