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
    boot_beanzee.asm \
    console_usb.asm \
    UM245R.asm \
    marvin.asm \
    strings.asm \
    messages.asm \
    -O"$outdir"

hexdump -C "$outdir/boot_beanzee.bin" > "$outdir/marvin.hex"
z88dk-appmake +hex --org $org -b "$outdir/boot_beanzee.bin" -o "$outdir/marvin.ihx"
