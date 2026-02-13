#!/usr/bin/env bash

# Build Marvin for BeanZee target
# Run from repo root: ./targets/beanzee/build.sh [org]
# Default org: 0x0000

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/../.."

org=${1:-0x0000}
outdir="$REPO_DIR/targets/beanzee/output"
mkdir -p "$outdir"

cd "$REPO_DIR/asm"
z88dk-z80asm -l -b -m -I.. -DMARVINORG=$org \
    marvin_beanzee.asm \
    console_usb.asm \
    um245r.asm \
    monitor.asm \
    hex.asm \
    messages.asm \
    -O"$outdir"

hexdump -C "$outdir/marvin_beanzee.bin" > "$outdir/marvin_beanzee.hex"
z88dk-appmake +hex --org $org -b "$outdir/marvin_beanzee.bin" -o "$outdir/marvin_beanzee.ihx"
