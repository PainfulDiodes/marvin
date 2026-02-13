#!/usr/bin/env bash

# Build Marvin for BeanBoard target
# Run from repo root: ./targets/beanboard/build.sh [org]
# Default org: 0x0000

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/../.."

org=${1:-0x0000}
outdir=targets/beanboard/output
mkdir -p "$outdir"

z88dk-z80asm -l -b -m -DMODULAR -DMARVINORG=$org \
    asm/boot_beanboard.asm \
    asm/console_beanboard.asm \
    asm/beanboard_init.asm \
    asm/UM245R.asm \
    asm/marvin.asm \
    asm/strings.asm \
    asm/HD44780LCD.asm \
    asm/keymatrix.asm \
    asm/messages_small.asm \
    -O"$outdir"

# z88dk-z80asm preserves source path structure under -O
bindir="$outdir/asm"
hexdump -C "$bindir/boot_beanboard.bin" > "$outdir/marvin.hex"
z88dk-appmake +hex --org $org -b "$bindir/boot_beanboard.bin" -o "$outdir/marvin.ihx"
