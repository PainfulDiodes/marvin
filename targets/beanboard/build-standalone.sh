#!/usr/bin/env bash

# Build standalone Marvin for BeanBoard target (monitor only, no BBC BASIC)
# Run from repo root: ./targets/beanboard/build-standalone.sh [org]
# Default org: 0x0000

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/../.."

org=${1:-0x0000}
outdir="$REPO_DIR/targets/beanboard/output"
mkdir -p "$outdir"

cd "$REPO_DIR/asm"
z88dk-z80asm -l -b -m -I.. -DMARVINORG=$org \
    entry_beanboard.asm \
    console_beanboard.asm \
    init_beanboard.asm \
    drivers/um245r.asm \
    monitor.asm \
    hex.asm \
    drivers/hd44780.asm \
    drivers/keymatrix.asm \
    messages_small.asm \
    -O"$outdir"

hexdump -C "$outdir/entry_beanboard.bin" > "$outdir/marvin_standalone.hex"
mv "$outdir/entry_beanboard.bin" "$outdir/marvin_standalone.bin"
z88dk-appmake +hex --org $org -b "$outdir/marvin_standalone.bin" -o "$outdir/marvin_standalone.ihx"
