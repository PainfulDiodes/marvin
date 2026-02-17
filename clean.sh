#!/usr/bin/env bash

# Clean all target build outputs

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for target in beanzee beanboard beandeck; do
    outdir="$SCRIPT_DIR/targets/$target/output"
    if [ -d "$outdir" ]; then
        echo "Cleaning $target"
        rm -rf "$outdir"
    fi
done

# Clean assembler listing files
rm -f "$SCRIPT_DIR"/asm/*.lis
rm -f "$SCRIPT_DIR"/asm/drivers/*.lis
rm -f "$SCRIPT_DIR"/targets/shared/BBCZ80/*.lis
rm -f "$SCRIPT_DIR"/targets/*/BBCZ80/*.lis
