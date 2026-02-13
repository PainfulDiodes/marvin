#!/usr/bin/env bash

# Build Marvin for BeanBoard target
# Run from repo root: ./targets/beanboard/build.sh [org]
# Default org: 0x0000

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/../.."

org=${1:-0x0000}
outdir="$REPO_DIR/targets/beanboard/output"
mkdir -p "$outdir"

cd "$REPO_DIR/asm"
z88dk-z80asm -l -b -m -I.. -DMARVINORG=$org \
    marvin_beanboard.asm \
    console_beanboard.asm \
    beanboard_init.asm \
    um245r.asm \
    monitor.asm \
    hex.asm \
    hd44780.asm \
    keymatrix.asm \
    messages_small.asm \
    -O"$outdir"

hexdump -C "$outdir/marvin_beanboard.bin" > "$outdir/marvin.hex"
z88dk-appmake +hex --org $org -b "$outdir/marvin_beanboard.bin" -o "$outdir/marvin.ihx"
