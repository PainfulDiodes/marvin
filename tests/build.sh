#!/usr/bin/env bash

# Build all Marvin ABI target tests
# Usage: ./build.sh [org]   (default: 0x8000)
#
# Outputs per target: output/<target>/<target>.bin/.hex/.ihx/.lis/.map
# Load <target>.ihx into RAM via Marvin ':' command, execute with 'x'.

org=${1:-0x8000}

mkdir -p output

for target in beanzee beanboard beandeck; do
    echo "Building $target..."
    z88dk-z80asm -l -b -m -DORGDEF=$org $target.asm -Ooutput
    hexdump -C output/$target/$target.bin > output/$target.hex
    z88dk-appmake +hex --org $org -b output/$target.bin -o output/$target.ihx
done
echo "Done."
