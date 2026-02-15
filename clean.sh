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
