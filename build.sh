#!/usr/bin/env bash

# Build Marvin + BBC BASIC firmware
# Usage: ./build.sh [target]
# Examples:
#   ./build.sh              # build all targets
#   ./build.sh beanzee      # build beanzee only
#
# Requires: z88dk (z88dk-z80asm)

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
MARVIN_ASM="$REPO_DIR/asm"
DRIVER_DIR="$REPO_DIR/asm/drivers"
BASIC_SRC="$REPO_DIR/BBCZ80/src"
SHARED_DIR="$REPO_DIR/shared"

CODE_ORG="0x0000"
DATA_ORG="0x8000"
OUTPUT_NAME="marvin"

BASIC_MODULES="MAIN EXEC EVAL ASMB MATH DATA"

# ---- Per-target module lists ----

modules_for_target() {
    case $1 in
        beanzee)
            MARVIN_MODULES="console_beanzee monitor hex messages"
            DRIVER_MODULES="um245r"
            ;;
        beanboard)
            MARVIN_MODULES="console_beanboard init_beanboard monitor hex messages_small"
            DRIVER_MODULES="um245r hd44780 keymatrix"
            ;;
        beandeck)
            MARVIN_MODULES="console_beanboard init_beanboard monitor hex messages_small"
            DRIVER_MODULES="um245r hd44780 keymatrix"
            ;;
        *)
            echo "Error: unknown target '$1'"
            echo "Valid targets: beanzee, beanboard, beandeck"
            exit 1
            ;;
    esac
}

# ---- Build a single target ----

build_target() {
    local target=$1
    local TARGET_DIR="$REPO_DIR/targets/$target"
    local OUTDIR="$TARGET_DIR/output"

    modules_for_target "$target"

    echo "Building Marvin ($target)"
    echo "==========================="

    mkdir -p "$OUTDIR"
    rm -f "$OUTDIR"/*.o "$OUTDIR"/*.lis

    # ---- Marvin modules ----

    echo ""
    echo "Assembling Marvin modules..."
    for module in $MARVIN_MODULES; do
        echo "  $module.asm"
        z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/$module.o" "$MARVIN_ASM/$module.asm"
    done

    echo ""
    echo "Assembling driver modules..."
    for module in $DRIVER_MODULES; do
        echo "  $module.asm"
        z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/$module.o" "$DRIVER_DIR/$module.asm"
    done

    # ---- BBC BASIC core modules ----

    echo ""
    echo "Assembling BBC BASIC modules..."
    for module in $BASIC_MODULES; do
        EXTRA_FLAGS=""
        if [ "$module" = "DATA" ]; then
            EXTRA_FLAGS="-DDATA_ORG=$DATA_ORG"
        fi
        echo "  $module.asm"
        z88dk-z80asm -l -m $EXTRA_FLAGS -o"$OUTDIR/$module.o" "$BASIC_SRC/$module.asm"
    done

    echo "  BHOOK.asm"
    z88dk-z80asm -l -m -o"$OUTDIR/BHOOK.o" "$SHARED_DIR/BBCZ80/BHOOK.asm"

    echo "  BMOS.asm"
    z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/BMOS.o" "$SHARED_DIR/BBCZ80/BMOS.asm"

    # ---- Target entry point ----

    echo ""
    echo "Assembling target entry point..."
    echo "  ENTRY.asm"
    z88dk-z80asm -l -m -I"$REPO_DIR" -o"$OUTDIR/ENTRY.o" "$TARGET_DIR/BBCZ80/ENTRY.asm"

    # ---- Link ----
    # ENTRY must be first (contains ORG 0x0000 and jump table)

    ALL_OBJS="$OUTDIR/ENTRY.o"
    for module in $MARVIN_MODULES; do
        ALL_OBJS="$ALL_OBJS $OUTDIR/$module.o"
    done
    for module in $DRIVER_MODULES; do
        ALL_OBJS="$ALL_OBJS $OUTDIR/$module.o"
    done
    for module in $BASIC_MODULES; do
        ALL_OBJS="$ALL_OBJS $OUTDIR/$module.o"
    done
    ALL_OBJS="$ALL_OBJS $OUTDIR/BHOOK.o"
    ALL_OBJS="$ALL_OBJS $OUTDIR/BMOS.o"

    echo ""
    echo "Linking all modules at $CODE_ORG..."
    z88dk-z80asm -b -m \
        -o"$OUTDIR/$OUTPUT_NAME.bin" \
        -r$CODE_ORG \
        $ALL_OBJS

    # Remove DATA section binary - it lives in RAM, not ROM
    rm -f "$OUTDIR/${OUTPUT_NAME}_data.bin"

    BIN_SIZE=$(wc -c < "$OUTDIR/$OUTPUT_NAME.bin" | tr -d ' ')

    xxd "$OUTDIR/$OUTPUT_NAME.bin" > "$OUTDIR/$OUTPUT_NAME.hex"

    echo ""
    echo "Build complete:"
    echo "  ROM image: output/$OUTPUT_NAME.bin ($BIN_SIZE bytes at $CODE_ORG)"
    echo "  Hex dump:  output/$OUTPUT_NAME.hex"
    echo "  Map file:  output/$OUTPUT_NAME.map"
    echo ""
    echo "Memory layout:"
    echo "  ROM: $CODE_ORG - code ($BIN_SIZE bytes)"
    echo "  RAM: $DATA_ORG - data segment (initialised at runtime)"
}

# ---- Main ----

# Check BBCZ80 submodule is initialised
if [ ! -f "$REPO_DIR/BBCZ80/build.sh" ]; then
    echo "Error: BBCZ80 submodule not initialised."
    echo "Run: git submodule update --init"
    exit 1
fi

# Convert BBC BASIC sources if not already done
if [ ! -f "$BASIC_SRC/MAIN.asm" ]; then
    echo "=== Converting BBC BASIC sources ==="
    cd "$REPO_DIR/BBCZ80"
    ./convert.sh
    cd "$REPO_DIR"
    echo ""
fi

if [ $# -gt 0 ]; then
    build_target "$1"
else
    for target in beanzee beanboard beandeck; do
        build_target "$target"
        echo ""
    done
fi
