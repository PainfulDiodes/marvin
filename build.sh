#!/usr/bin/env bash

# Build Marvin firmware for all targets or a named target
# Usage: ./build.sh [target]
# Examples:
#   ./build.sh              # build all targets
#   ./build.sh beanzee      # build beanzee only

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Check bbcbasic submodule is initialised
if [ ! -f "$SCRIPT_DIR/bbcbasic/build.sh" ]; then
    echo "Error: bbcbasic submodule not initialised."
    echo "Run: git submodule update --init"
    exit 1
fi

# Convert BBC BASIC sources if not already done
if [ ! -f "$SCRIPT_DIR/bbcbasic/src/MAIN.asm" ]; then
    echo "=== Converting BBC BASIC sources ==="
    cd "$SCRIPT_DIR/bbcbasic"
    ./convert.sh
    cd "$SCRIPT_DIR"
    echo ""
fi

if [ $# -gt 0 ]; then
    target=$1
    shift
    echo "=== Building Marvin ($target) ==="
    "$SCRIPT_DIR/targets/$target/build.sh" "$@"
else
    echo "=== Building Marvin (all targets) ==="
    "$SCRIPT_DIR/targets/beanzee/build.sh"
    echo ""
    "$SCRIPT_DIR/targets/beanboard/build.sh"
    echo ""
    "$SCRIPT_DIR/targets/beandeck/build.sh"
fi
