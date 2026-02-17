#!/usr/bin/env bash

# Build standalone Marvin for BeanZee target (monitor only, no BBC BASIC)
# Run from repo root: ./targets/beanzee/build-standalone.sh [org]
# Default org: 0x0000

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$SCRIPT_DIR/../.."

org=${1:-0x0000}
outdir="$REPO_DIR/targets/beanzee/output"
mkdir -p "$outdir"

cd "$REPO_DIR/asm"
z88dk-z80asm -l -b -m -I.. -DMARVINORG=$org \
    entry_beanzee.asm \
    console_beanzee.asm \
    drivers/um245r.asm \
    monitor.asm \
    hex.asm \
    messages.asm \
    -O"$outdir"

hexdump -C "$outdir/entry_beanzee.bin" > "$outdir/marvin_standalone.hex"
mv "$outdir/entry_beanzee.bin" "$outdir/marvin_standalone.bin"
z88dk-appmake +hex --org $org -b "$outdir/marvin_standalone.bin" -o "$outdir/marvin_standalone.ihx"
